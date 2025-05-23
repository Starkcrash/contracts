use core::result::Result;
use starknet::ContractAddress;
use super::types::{Bet, GameState};

#[starknet::interface]
pub trait IPlinkoGame<TContractState> {
    fn get_game_state(self: @TContractState, game_id: u64, player: ContractAddress) -> GameState;
    fn get_game_outcome(
        self: @TContractState, game_id: u64, player: ContractAddress,
    ) -> Array<u256>;
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
pub mod PlinkoGame {
    use alexandria_data_structures::span_ext::SpanTraitExt;
    use cartridge_vrf::{IVrfProviderDispatcher, IVrfProviderDispatcherTrait, Source};
    use openzeppelin::upgrades::UpgradeableComponent;
    use openzeppelin::upgrades::interface::IUpgradeable;
    use openzeppelin_access::ownable::OwnableComponent;
    use openzeppelin_security::PausableComponent;
    use openzeppelin_token::erc20::interface::{ERC20ABIDispatcher, ERC20ABIDispatcherTrait};
    use starknet::storage::{
        Map, MutableVecTrait, StorageBase, StorageMapReadAccess, StorageMapWriteAccess,
        StoragePathEntry, StoragePointerReadAccess, StoragePointerWriteAccess, Vec, VecTrait,
    };
    use starknet::{ClassHash, ContractAddress, get_caller_address, get_contract_address};
    component!(path: PausableComponent, storage: pausable, event: PausableEvent);
    component!(path: OwnableComponent, storage: ownable, event: OwnableEvent);
    component!(path: UpgradeableComponent, storage: upgradeable, event: UpgradeableEvent);
    use core::keccak::keccak_u256s_be_inputs;
    use crate::controller::controller::{IControllerDispatcher, IControllerDispatcherTrait};
    use crate::games::plinko::errors::Errors;
    use crate::games::plinko::types::GameState;
    use super::{Bet, IManagement, IPlinkoGame};

    // CONSTANTS
    const ETH_ADDRESS: felt252 = 0x049d36570d4e46f48e99674bd3fcc84644ddd6b96f7c741b1562b82f9e004dc7;
    const BASIS_POINTS: u256 = 10000;

    const MULTIPLIERS: [u256; 6] = [
        2_u256, // x0.2
        5_u256, // x0.5
        10_u256, // x0.1
        20_u256, // x0.2
        50_u256, // x0.5
        100_u256 // x1
    ];

    const WEIGHTS: [u8; 6] = [50, // x0.2
    25, // x0.5
    10, // x1
    8, // x2
    6, // x5
    1 // x10
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
    impl IPlinkoGameImpl of IPlinkoGame<ContractState> {
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

        /// Get the outcome for a specific game, for plinko, its the array of multipliers (per ball)
        /// # Arguments
        /// * `game_id` - The ID of the game to query
        /// * `player` - The address of the player
        /// # Returns
        /// * The array of multipliers (per ball)
        fn get_game_outcome(
            self: @ContractState, game_id: u64, player: ContractAddress,
        ) -> Array<u256> {
            assert(
                self.player_game_states.read((player, game_id)) == GameState::Finished,
                Errors::GAME_NOT_IN_FINISHED_STATE,
            );
            let bet_vec = self.player_bets.entry((player, game_id));
            let mut outcome = array![];
            for i in 0..bet_vec.len() {
                let multiplier: u256 = bet_vec.get(i).unwrap().multiplier.read();
                outcome.append(multiplier);
            }
            outcome
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
                    amount: storage_bet.amount.read(),
                    multiplier: storage_bet.multiplier.read(),
                    user_address: player,
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
            assert(bet.len() <= 10, Errors::MAX_BALLS_EXCEEDED);

            let mut total_bet: u256 = 0;
            let mut bet_vec = self.player_bets.entry((player, game_id));

            for i in 0..bet.len() {
                let bet_item = bet.get(i).unwrap();
                total_bet += bet_item.amount;
                let unboxed_item = *bet_item.unbox();
                bet_vec.push(unboxed_item);
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
            let mut random_value_u256: u256 = random_value
                .try_into()
                .expect('Failed convert to u256');

            //Dans le front faut quon atribue directement le montant des billes, exemple
            // si un joueur achete 5 billes pour 1 ETH, faut donner 0.2 ETH par bille

            let total_balls = bet.len();
            let base = 100_u256;
            for i in 0..total_balls {
                let i_to_256: u256 = i.into();
                let span = array![random_value_u256, i_to_256].span();
                let h_felt = keccak_u256s_be_inputs(span);
                let h_u256: u256 = h_felt.try_into().unwrap();

                let percentage: u8 =
                    (h_u256 % base) // 0-99, ici ca nous permet de ponderer les multiplicateurs
                    .try_into()
                    .expect('pct usize');

                let mut cumulate = 0_u8;
                let mut idx = 0_usize;
                for j in 0..6_usize {
                    let cumulate = cumulate
                        + *WEIGHTS
                            .span()
                            .at(j); // ici c'est la somme des poids de chaque multiplicateur
                    if percentage < cumulate {
                        idx = j;
                        break;
                    }
                }

                let mult = *MULTIPLIERS.span().at(idx);
                let i_to_u64: u64 = i.into();
                bet_vec.at(i_to_u64).multiplier.write(mult);

                random_value_u256 = h_u256;
            }

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
            let payout = self.payout_compute(player, game_id);
            if payout > 0 {
                IControllerDispatcher { contract_address: self.controller_address.read() }
                    .process_cashout(player, payout);

                self.emit(CashoutProcessed { game_id, player, amount: payout });
            }

            self.emit(GameEnded { game_id, player, seed: random_value });
        }
    }

    // Internal functions
    #[generate_trait]
    impl InternalFunctions of InternalFunctionsTrait {
        fn payout_compute(self: @ContractState, player: ContractAddress, game_id: u64) -> u256 {
            let bet_vec = self.player_bets.entry((player, game_id));
            let mut total_payout: u256 = 0;
            for i in 0..bet_vec.len() {
                let amount: u256 = bet_vec.get(i).unwrap().amount.read();
                let multiplier: u256 = bet_vec.get(i).unwrap().multiplier.read();
                total_payout += (amount * multiplier) / 10;
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

