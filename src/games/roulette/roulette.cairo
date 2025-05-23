use core::result::Result;
use starknet::ContractAddress;
use super::types::{Bet, GameState};

#[starknet::interface]
pub trait IRouletteGame<TContractState> {
    fn get_game_state(self: @TContractState, game_id: u64, player: ContractAddress) -> GameState;
    fn get_game_outcome(self: @TContractState, game_id: u64, player: ContractAddress) -> u256;
    fn get_player_bets(self: @TContractState, player: ContractAddress, game_id: u64) -> Array<Bet>;
    fn get_total_player_bet_amount(
        self: @TContractState, player: ContractAddress, game_id: u64,
    ) -> u256;
    fn get_current_game(self: @TContractState, player: ContractAddress) -> u64;
    fn play_game(
        ref self: TContractState, bet: Array<Bet>,
    ); // place bet + vrf + resolve game + process cashout
}

#[starknet::interface]
pub trait IManagement<TContractState> {
    fn get_max_bet(self: @TContractState) -> u256;
    fn get_min_bet(self: @TContractState) -> u256;
    fn get_controller_address(self: @TContractState) -> ContractAddress;
}

#[starknet::contract]
pub mod RouletteGame {
    use alexandria_data_structures::span_ext::SpanTraitExt;
    use cartridge_vrf::{IVrfProviderDispatcher, IVrfProviderDispatcherTrait, Source};
    use openzeppelin::upgrades::UpgradeableComponent;
    use openzeppelin::upgrades::interface::IUpgradeable;
    use openzeppelin_access::ownable::OwnableComponent;
    use openzeppelin_security::PausableComponent;
    use openzeppelin_token::erc20::interface::{ERC20ABIDispatcher, ERC20ABIDispatcherTrait};
    use starknet::storage::{
        Map, MutableVecTrait, StorageMapReadAccess, StorageMapWriteAccess,
        StoragePathEntry, StoragePointerReadAccess, StoragePointerWriteAccess, Vec, VecTrait,
    };
    use starknet::{ClassHash, ContractAddress, get_caller_address, get_contract_address};
    component!(path: PausableComponent, storage: pausable, event: PausableEvent);
    component!(path: OwnableComponent, storage: ownable, event: OwnableEvent);
    component!(path: UpgradeableComponent, storage: upgradeable, event: UpgradeableEvent);
    use crate::controller::controller::{
        IControllerDispatcher, IControllerDispatcherTrait, IControllerManagementDispatcher,
        IControllerManagementDispatcherTrait,
    };
    use crate::games::roulette::errors::Errors;
    use crate::games::roulette::types::GameState;
    use super::{Bet, IManagement, IRouletteGame};

    // CONSTANTS
    const ETH_ADDRESS: felt252 = 0x049d36570d4e46f48e99674bd3fcc84644ddd6b96f7c741b1562b82f9e004dc7;
    const BASIS_POINTS: u256 = 10000;
    const RED_NUMBERS: [u256; 18] = [
        1, 3, 5, 7, 9, 12, 14, 16, 18, 19, 21, 23, 25, 27, 30, 32, 34, 36,
    ];
    const BLACK_NUMBERS: [u256; 18] = [
        2, 4, 6, 8, 10, 11, 13, 15, 17, 20, 22, 24, 26, 28, 29, 31, 33, 35,
    ];

    const VRF_PROVIDER_ADDRESS: felt252 =
        0x051fea4450da9d6aee758bdeba88b2f665bcbf549d2c61421aa724e9ac0ced8f;

    // Ownable Mixin
    #[abi(embed_v0)]
    impl OwnableMixinImpl = OwnableComponent::OwnableMixinImpl<ContractState>;
    impl OwnableInternalImpl = OwnableComponent::InternalImpl<ContractState>;

    // Pausable
    #[abi(embed_v0)]
    impl PausableImpl = PausableComponent::PausableImpl<ContractState>;
    impl PausableInternalImpl = PausableComponent::InternalImpl<ContractState>;

    impl UpgradeableInternalImpl = UpgradeableComponent::InternalImpl<ContractState>;

    #[storage]
    struct Storage {
        #[substorage(v0)]
        ownable: OwnableComponent::Storage,
        #[substorage(v0)]
        pausable: PausableComponent::Storage,
        #[substorage(v0)]
        upgradeable: UpgradeableComponent::Storage,
        player_bets: Map<
            (ContractAddress, u64), Vec<Bet>,
        >, // For a given contract address, returns his bets for a given game ID
        processed: Map<(u64, ContractAddress), bool>,
        total_bets: Map<(u64, ContractAddress), u256>,
        controller_address: ContractAddress,
        player_games: Map<ContractAddress, u64>,
        player_game_states: Map<(ContractAddress, u64), GameState>,
        player_seeds: Map<(ContractAddress, u64), felt252>,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        #[flat]
        OwnableEvent: OwnableComponent::Event,
        #[flat]
        PausableEvent: PausableComponent::Event,
        #[flat]
        UpgradeableEvent: UpgradeableComponent::Event,
        BetPlaced: BetPlaced,
        CashoutProcessed: CashoutProcessed,
        GameEnded: GameEnded,
    }

    #[derive(Drop, starknet::Event)]
    struct BetPlaced {
        game_id: u64,
        player: ContractAddress,
        amount: u256,
    }

    #[derive(Drop, starknet::Event)]
    struct CashoutProcessed {
        game_id: u64,
        player: ContractAddress,
        amount: u256,
    }

    #[derive(Drop, starknet::Event)]
    struct GameEnded {
        game_id: u64,
        player: ContractAddress,
        seed: felt252,
    }


    #[constructor]
    fn constructor(
        ref self: ContractState, operator: ContractAddress, controller_address: ContractAddress,
    ) {
        self.ownable.initializer(operator);
        self.controller_address.write(controller_address);
    }

    #[generate_trait]
    #[abi(per_item)]
    impl ExternalImpl of ExternalTrait {
        #[external(v0)]
        fn pause(ref self: ContractState) {
            self.ownable.assert_only_owner();
            self.pausable.pause();
        }
        #[external(v0)]
        fn unpause(ref self: ContractState) {
            self.ownable.assert_only_owner();
            self.pausable.unpause();
        }
    }

    #[abi(embed_v0)]
    impl IRouletteGameImpl of IRouletteGame<ContractState> {
        /// Get the current state of a specific game
        /// # Arguments
        /// * `game_id` - The ID of the game to query
        /// * `player` - The address of the player
        /// # Returns
        /// * The GameState enum value for the specified game
        fn get_game_state(
            self: @ContractState, game_id: u64, player: ContractAddress,
        ) -> GameState {
            self.player_game_states.read((player, game_id))
        }

        /// Get the outcome (0-36) for a specific game
        /// # Arguments
        /// * `game_id` - The ID of the game to query
        /// * `player` - The address of the player
        /// # Returns
        /// * The outcome number (0-36)
        fn get_game_outcome(self: @ContractState, game_id: u64, player: ContractAddress) -> u256 {
            assert(
                self.player_game_states.read((player, game_id)) == GameState::Finished,
                Errors::GAME_NOT_IN_FINISHED_STATE,
            );

            let seed = self.player_seeds.read((player, game_id));
            let seed_u256: u256 = seed.into();
            seed_u256 % 37_u256
        }

        /// Get the bets placed by a player for a specific game
        /// # Arguments
        /// * `player` - The address of the player
        /// * `game_id` - The ID of the game to query
        /// # Returns
        /// * An array of Bet structs representing the player's bets
        fn get_player_bets(
            self: @ContractState, player: ContractAddress, game_id: u64,
        ) -> Array<Bet> {
            let mut bet_array = array![];
            let bet_vec = self.player_bets.entry((player, game_id));
            let bet_len = bet_vec.len();

            for i in 0..bet_len {
                let storage_bet = bet_vec.get(i).unwrap();
                let bet = Bet {
                    bet_type: storage_bet.bet_type.read(),
                    bet_value: storage_bet.bet_value.read(),
                    amount: storage_bet.amount.read(),
                    user_address: player,
                    split_bet: storage_bet.split_bet.read(),
                    split_bet_value: storage_bet.split_bet_value.read(),
                    corner_bet: storage_bet.corner_bet.read(),
                    corner_bet_value: storage_bet.corner_bet_value.read(),
                };
                bet_array.append(bet);
            }
            bet_array
        }

        /// Get the total amount of bets placed by a player for a specific game
        /// # Arguments
        /// * `player` - The address of the player
        /// * `game_id` - The ID of the game to query
        /// # Returns
        /// * The total amount of bets placed by the player for the specified game
        fn get_total_player_bet_amount(
            self: @ContractState, player: ContractAddress, game_id: u64,
        ) -> u256 {
            let bet_vec = self.player_bets.entry((player, game_id));
            let mut total_bet = 0;
            for i in 0..bet_vec.len() {
                let new_amount: u256 = bet_vec.get(i).unwrap().amount.read();
                total_bet += new_amount;
            }
            total_bet
        }

        /// Get the current game ID
        /// # Arguments
        /// * `player` - The address of the player
        /// # Returns
        /// * The ID of the current game
        fn get_current_game(self: @ContractState, player: ContractAddress) -> u64 {
            self.player_games.read(player)
        }


        /// Play a game
        /// # Arguments
        /// * `bet` - An array of Bet structs representing the player's bets
        /// # Returns
        /// * Play and Resolve the game
        fn play_game(ref self: ContractState, bet: Array<Bet>) {
            self.pausable.assert_not_paused();

            let player = get_caller_address();
            let game_id = self.player_games.read(player);
            assert(
                self.player_game_states.read((player, game_id)) == GameState::Betting,
                Errors::GAME_NOT_IN_BETTING_STATE,
            );
            assert(bet.len() > 0, Errors::NO_BETS_PLACED);
            assert(bet.len() <= 10, Errors::TOO_MANY_BETS);

            let mut total_bet: u256 = 0;
            let mut bet_vec = self.player_bets.entry((player, game_id));

            for i in 0..bet.len() {
                let bet_item = bet.get(i).unwrap();
                total_bet += bet_item.amount;
                let unboxed_item = bet_item.unbox();
                self.validate_bet_item(*unboxed_item, game_id, player);
                bet_vec.push(*unboxed_item);
            }

            assert(total_bet <= self.get_max_bet(), Errors::AMOUNT_EXCEEDS_MAX_BET);
            assert(total_bet >= self.get_min_bet(), Errors::AMOUNT_BELOW_MIN_BET);
            self.total_bets.write((game_id, player), total_bet);

            let eth = ERC20ABIDispatcher { contract_address: ETH_ADDRESS.try_into().unwrap() };
            let result = eth.transfer_from(player, self.controller_address.read(), total_bet);
            assert(result, Errors::TRANSFER_FAILED);

            let result = IControllerDispatcher { contract_address: self.controller_address.read() }
                .process_bet(total_bet);
            assert(result, Errors::CONTROLLER_CALL_FAILED);

            self.emit(BetPlaced { game_id, player, amount: total_bet });
            // Get random from VRF
            let vrf_provider = IVrfProviderDispatcher {
                contract_address: VRF_PROVIDER_ADDRESS.try_into().unwrap(),
            };
            let game_source = Source::Nonce(player);
            let random_value = vrf_provider.consume_random(game_source);
            assert(random_value != 0, Errors::VRF_FAILED);
            let random_value_u256: u256 = random_value.try_into().expect('Failed convert to u256');

            let outcome: u256 = random_value_u256 % 37_u256;

            assert(outcome >= 0 && outcome <= 36, Errors::INVALID_OUTCOME);

            // Store the outcome as the seed
            self.player_seeds.write((player, game_id), random_value);

            // Change game state to finished
            self.player_game_states.write((player, game_id), GameState::Finished);
            // Setup next game

            let next_game = game_id + 1;
            self.player_games.write(player, next_game);
            self.player_game_states.write((player, next_game), GameState::Betting);

            assert(!self.processed.read((game_id, player)), Errors::ALREADY_PROCESSED);
            self.processed.write((game_id, player), true);

            // Process payout
            let payout = self.payout_compute(player, game_id, outcome);
            let safe_balance = IControllerManagementDispatcher {
                contract_address: self.controller_address.read(),
            }
                .get_safe_balance();
            if payout > 0 {
                if payout >= safe_balance {
                    // edge case, if safe is empty
                    IControllerDispatcher { contract_address: self.controller_address.read() }
                        .process_cashout(player, safe_balance);
                    self.emit(CashoutProcessed { game_id, player, amount: safe_balance });
                } else {
                    IControllerDispatcher { contract_address: self.controller_address.read() }
                        .process_cashout(player, payout);
                    self.emit(CashoutProcessed { game_id, player, amount: payout });
                }
            }

            self.emit(GameEnded { game_id, player, seed: random_value });
        }
    }

    // Internal functions
    #[generate_trait]
    impl InternalFunctions of InternalFunctionsTrait {
        fn validate_bet_item(
            self: @ContractState, bet_item: Bet, game_id: u64, player: ContractAddress,
        ) -> bool {
            assert(bet_item.amount > 0, '0 amount bet');
            assert(bet_item.user_address == player, 'Invalid bet user address');
            assert(bet_item.bet_type >= 0 && bet_item.bet_type <= 6, 'Invalid bet type');
            assert(bet_item.bet_value >= 0 && bet_item.bet_value <= 36, 'Invalid bet value');
            let split_values = bet_item.split_bet_value.span();
            assert(
                *split_values.at(0) >= 0 && *split_values.at(0) <= 36, 'Invalid split bet value',
            );
            assert(
                *split_values.at(1) >= 0 && *split_values.at(1) <= 36, 'Invalid split bet value',
            );
            if bet_item.split_bet && bet_item.bet_type == 6 {
                assert(
                    *split_values.at(0) != *split_values.at(1), 'Duplicate numbers in split bet',
                );
                Self::validate_split_bet(bet_item.split_bet_value);
            }
            let corner_values = bet_item.corner_bet_value.span();
            assert(
                *corner_values.at(0) >= 0 && *corner_values.at(0) <= 36, 'Invalid corner bet value',
            );
            assert(
                *corner_values.at(1) >= 0 && *corner_values.at(1) <= 36, 'Invalid corner bet value',
            );
            assert(
                *corner_values.at(2) >= 0 && *corner_values.at(2) <= 36, 'Invalid corner bet value',
            );
            assert(
                *corner_values.at(3) >= 0 && *corner_values.at(3) <= 36, 'Invalid corner bet value',
            );
            if bet_item.corner_bet && bet_item.bet_type == 6 {
                Self::validate_corner_bet(bet_item.corner_bet_value);
            }
            true
        }
        /// Validate a split bet to ensure the numbers are valid and adjacent
        /// # Arguments
        /// * `values` - Array of two numbers for the split bet
        fn validate_split_bet(values: [u256; 2]) -> bool {
            // Check both numbers are valid roulette numbers
            let split_values = values.span();

            // Check if numbers are adjacent horizontally
            let row1 = (*split_values.at(0) - 1) / 3;
            let row2 = (*split_values.at(1) - 1) / 3;

            let horizontally_adjacent = ((*split_values.at(0)
                + 1 == *split_values.at(1) || *split_values.at(1)
                + 1 == *split_values.at(0))
                && row1 == row2);

            // Check if numbers are adjacent vertically
            let vertically_adjacent = (*split_values.at(0)
                + 3 == *split_values.at(1) || *split_values.at(1)
                + 3 == *split_values.at(0));

            assert(horizontally_adjacent || vertically_adjacent, 'non adjacent numbers');

            true
        }

        /// Validate a corner bet to ensure the numbers form a valid corner
        /// # Arguments
        /// * `values` - Array of four numbers for the corner bet
        fn validate_corner_bet(values: [u256; 4]) -> bool {
            // Check all numbers are valid roulette numbers (1-36)
            let corner_values = values.span();

            // Find the smallest number in the corner
            let mut smallest: u256 = *corner_values.at(0);
            for i in 1_usize..4_usize {
                if *corner_values.at(i) < smallest {
                    smallest = *corner_values.at(i);
                }
            }

            // The roulette table is laid out in 3 columns and 12 rows
            // For a corner, we need to verify:
            // 1. smallest + 1 is present (number to the right)
            // 2. smallest + 3 is present (number below)
            // 3. smallest + 4 is present (number diagonally down-right)
            // AND the smallest number must not be in the right column

            assert(smallest % 3 != 0, 'corner not possible');
            assert(smallest <= 32, 'corner not possible');

            let mut has_right = false;
            let mut has_below = false;
            let mut has_diagonal = false;

            // for instance 1, 2, 4, 5
            for i in 0_usize..4_usize {
                let current = *corner_values.at(i);

                if current == smallest {
                    continue; // Skip the smallest - example: 1
                } else if current == smallest + 1 { // 2
                    has_right = true;
                } else if current == smallest + 3 { // 4
                    has_below = true;
                } else if current == smallest + 4 { // 5
                    has_diagonal = true;
                } else {
                    assert(false, 'invalid corner numbers');
                }
            }

            assert(has_right && has_below && has_diagonal, 'incomplete corner');

            true
        }

        fn is_red(outcome: u256) -> bool {
            if RED_NUMBERS.span().contains(@outcome) {
                return true;
            }
            return false;
        }

        fn is_black(outcome: u256) -> bool {
            if BLACK_NUMBERS.span().contains(@outcome) {
                return true;
            }
            return false;
        }

        fn in_column(outcome: u256, column: u64) -> bool {
            if outcome == 0 {
                return false;
            }
            if column == 0 {
                return (outcome - 1) % 3 == 0;
            } else if column == 1 {
                return (outcome - 2) % 3 == 0;
            } else if column == 2 {
                return (outcome - 3) % 3 == 0;
            }
            return false;
        }

        fn in_dozen(outcome: u256, dozen: u64) -> bool {
            if outcome == 0 {
                return false;
            }
            if dozen == 0 {
                return outcome >= 1 && outcome <= 12;
            } else if dozen == 1 {
                return outcome >= 13 && outcome <= 24;
            } else if dozen == 2 {
                return outcome >= 25 && outcome <= 36;
            }
            return false;
        }

        /// Check if the outcome is in the high (19-36) or low (1-18) range
        /// # Arguments
        /// * `outcome` - The outcome of the game
        /// * `high_low` - 0 for low, 1 for high
        /// # Returns
        /// * True if the outcome is in the high or low range, false otherwise
        fn in_high_low(outcome: u256, high_low: u64) -> bool {
            if outcome >= 1 && outcome <= 18 && high_low == 0 {
                return true;
            } else if outcome >= 19 && outcome <= 36 && high_low == 1 {
                return true;
            }
            return false;
        }

        fn in_split_bet(outcome: u256, split_bet_value: [u256; 2]) -> bool {
            let bet_span = split_bet_value.span();
            if bet_span.contains(@outcome) {
                return true;
            }
            return false;
        }

        fn in_corner_bet(outcome: u256, corner_bet_value: [u256; 4]) -> bool {
            let bet_span = corner_bet_value.span();
            if bet_span.contains(@outcome) {
                return true;
            }
            return false;
        }

        /// Compute the total payout for a player's bets based on the roulette outcome.
        /// # Arguments
        /// * `player` - The address of the player
        /// * `game_id` - The ID of the game to compute the payout for
        /// * `outcome` - The outcome of the game
        /// # Returns
        /// * The total payout for the player's bets
        fn payout_compute(
            ref self: ContractState, player: ContractAddress, game_id: u64, outcome: u256,
        ) -> u256 {
            let player_bet = self.player_bets.entry((player, game_id));
            assert(player_bet.len() > 0, Errors::NO_BETS_PLACED);

            let mut total_payout: u256 = 0;

            for i in 0..player_bet.len() {
                let bet = player_bet.get(i).unwrap();
                match bet.bet_type.read() {
                    0 => {
                        if outcome == bet.bet_value.read().into() {
                            total_payout += bet.amount.read() * 36;
                        }
                    },
                    1 => {
                        if outcome != 0 {
                            if bet.bet_value.read() == 0 && Self::is_red(outcome) {
                                total_payout += bet.amount.read() * 2;
                            } else if bet.bet_value.read() == 1 && Self::is_black(outcome) {
                                total_payout += bet.amount.read() * 2;
                            }
                        }
                    },
                    2 => {
                        if outcome != 0 {
                            if bet.bet_value.read() == 0 && (outcome % 2 == 0) {
                                total_payout += bet.amount.read() * 2;
                            } else if bet.bet_value.read() == 1 && (outcome % 2 == 1) {
                                total_payout += bet.amount.read() * 2;
                            }
                        }
                    },
                    3 => {
                        if outcome != 0 && Self::in_column(outcome, bet.bet_value.read()) {
                            total_payout += bet.amount.read() * 3;
                        }
                    },
                    4 => {
                        if outcome != 0 && Self::in_dozen(outcome, bet.bet_value.read()) {
                            total_payout += bet.amount.read() * 3;
                        }
                    },
                    5 => {
                        if outcome != 0 && Self::in_high_low(outcome, bet.bet_value.read()) {
                            total_payout += bet.amount.read() * 2;
                        }
                    },
                    6 => {
                        if bet.split_bet.read()
                            && Self::in_split_bet(outcome, bet.split_bet_value.read()) {
                            total_payout += bet.amount.read() * 18;
                        } else if bet.corner_bet.read()
                            && Self::in_corner_bet(outcome, bet.corner_bet_value.read()) {
                            total_payout += bet.amount.read() * 9;
                        }
                    },
                    _ => { assert(false, 'Invalid bet type'); },
                }
            }
            total_payout
        }
    }

    #[abi(embed_v0)]
    impl IManagementImpl of IManagement<ContractState> {
        fn get_max_bet(self: @ContractState) -> u256 {
            IControllerDispatcher { contract_address: self.controller_address.read() }
                .get_max_bet(get_contract_address())
        }


        fn get_min_bet(self: @ContractState) -> u256 {
            IControllerDispatcher { contract_address: self.controller_address.read() }
                .get_min_bet(get_contract_address())
        }


        fn get_controller_address(self: @ContractState) -> ContractAddress {
            self.controller_address.read()
        }
    }

    #[abi(embed_v0)]
    impl UpgradeableImpl of IUpgradeable<ContractState> {
        fn upgrade(ref self: ContractState, new_class_hash: ClassHash) {
            self.ownable.assert_only_owner();
            self.upgradeable.upgrade(new_class_hash);
        }
    }
}

