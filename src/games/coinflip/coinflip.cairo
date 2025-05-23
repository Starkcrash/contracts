use starknet::ContractAddress;
use super::types::{Bet, GameState};

#[starknet::interface]
pub trait ICoinFlipGame<TContractState> {
    fn get_game_state(self: @TContractState, player: ContractAddress, game_id: u64) -> GameState;
    fn get_player_bet(self: @TContractState, player: ContractAddress, game_id: u64) -> Bet;
    fn get_current_game(self: @TContractState, player: ContractAddress) -> u64;
    fn play_game(ref self: TContractState, bet: Bet);
}

#[starknet::interface]
pub trait IManagement<TContractState> {
    fn get_max_bet(self: @TContractState) -> u256;
    fn get_min_bet(self: @TContractState) -> u256;
    fn get_controller_address(self: @TContractState) -> ContractAddress;
}

#[starknet::contract]
pub mod CoinFlipGame {
    use cartridge_vrf::{IVrfProviderDispatcher, IVrfProviderDispatcherTrait, Source};
    use openzeppelin::upgrades::UpgradeableComponent;
    use openzeppelin::upgrades::interface::IUpgradeable;
    use openzeppelin_access::ownable::OwnableComponent;
    use openzeppelin_security::PausableComponent;
    use openzeppelin_token::erc20::interface::{ERC20ABIDispatcher, ERC20ABIDispatcherTrait};
    use starknet::storage::Map;
    use starknet::{ClassHash, ContractAddress, get_caller_address, get_contract_address};
    use crate::controller::controller::{
        IControllerManagementDispatcher, IControllerManagementDispatcherTrait,
    };
    component!(path: PausableComponent, storage: pausable, event: PausableEvent);
    component!(path: OwnableComponent, storage: ownable, event: OwnableEvent);
    component!(path: UpgradeableComponent, storage: upgradeable, event: UpgradeableEvent);
    //use core::hash::HashStateTrait;
    //use core::poseidon::PoseidonTrait;
    use crate::controller::controller::{IControllerDispatcher, IControllerDispatcherTrait};
    use crate::games::coinflip::errors::Errors;
    use crate::games::coinflip::types::{Bet, GameState, Outcome};
    use super::{ICoinFlipGame, IManagement};

    // CONSTANTS
    const ETH_ADDRESS: felt252 = 0x049d36570d4e46f48e99674bd3fcc84644ddd6b96f7c741b1562b82f9e004dc7;
    const BASIS_POINTS: u256 = 10000;
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
        player_bet: Map<(u64, ContractAddress), Bet>,
        player_games: Map<ContractAddress, u64>,
        player_game_states: Map<(ContractAddress, u64), GameState>,
        player_seeds: Map<(ContractAddress, u64), felt252>,
        processed: Map<(u64, ContractAddress), bool>,
        controller_address: ContractAddress,
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
        outcome: Outcome,
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
    impl ICoinFlipGameImpl of ICoinFlipGame<ContractState> {
        /// Get the current state of a specific game
        /// # Arguments
        /// * `game_id` - The ID of the game to query
        /// # Returns
        /// * The GameState enum value for the specified game
        fn get_game_state(
            self: @ContractState, player: ContractAddress, game_id: u64,
        ) -> GameState {
            self.player_game_states.read((player, game_id))
        }

        /// Get the bet amount placed by a player in a specific game
        /// # Arguments
        /// * `player` - The address of the player
        /// * `game_id` - The ID of the game to query
        /// # Returns
        /// * The bet amount in wei
        fn get_player_bet(self: @ContractState, player: ContractAddress, game_id: u64) -> Bet {
            self.player_bet.read((game_id, player))
        }

        /// Get the ID of the current active game
        /// # Returns
        /// * The current game ID
        fn get_current_game(self: @ContractState, player: ContractAddress) -> u64 {
            self.player_games.read(player)
        }

        /// Play a game
        /// # Arguments
        /// * `bet` - The bet to play
        /// # Returns
        /// * Play and Resolve the game
        fn play_game(ref self: ContractState, bet: Bet) {
            // Checks and asserts
            self.pausable.assert_not_paused();
            let player = get_caller_address();
            let game_id = self.player_games.read(player);
            assert(
                self.player_game_states.read((player, game_id)) == GameState::Betting,
                Errors::GAME_NOT_IN_BETTING_STATE,
            );
            assert(
                self.player_bet.read((game_id, player)).outcome == Outcome::None,
                Errors::ALREADY_PLACED_BET,
            );
            assert(!self.processed.read((game_id, player)), Errors::ALREADY_PROCESSED);
            assert(
                bet.outcome == Outcome::Heads
                    || bet.outcome == Outcome::Tails
                    || bet.outcome == Outcome::Edge,
                Errors::INVALID_BET,
            );
            let bet_amount = bet.amount;
            assert(bet_amount <= self.get_max_bet(), Errors::AMOUNT_EXCEEDS_MAX_BET);
            assert(bet_amount >= self.get_min_bet(), Errors::AMOUNT_BELOW_MIN_BET);
            let safe_balance = IControllerManagementDispatcher {
                contract_address: self.controller_address.read(),
            }
                .get_safe_balance();
            assert(bet_amount * 18 <= safe_balance, Errors::INSUFFICIENT_SAFE_BALANCE);

            // Effect - storage update
            self.player_bet.write((game_id, player), bet);

            self.player_game_states.write((player, game_id), GameState::Flipping);

            let eth = ERC20ABIDispatcher { contract_address: ETH_ADDRESS.try_into().unwrap() };
            assert(
                eth.transfer_from(player, self.controller_address.read(), bet_amount),
                'transfer failed',
            );

            assert(
                IControllerDispatcher { contract_address: self.controller_address.read() }
                    .process_bet(bet_amount),
                'process bet failed',
            );

            self.emit(BetPlaced { game_id, player, amount: bet_amount });

            let vrf_provider = IVrfProviderDispatcher {
                contract_address: VRF_PROVIDER_ADDRESS.try_into().unwrap(),
            };

            let game_source = Source::Nonce(player);
            let random_value = vrf_provider.consume_random(game_source);
            assert(random_value != 0, Errors::INVALID_RANDOM_VALUE);
            // Store the outcome as the seed
            self.player_seeds.write((player, game_id), random_value);

            let random_value_u256: u256 = random_value.try_into().expect('Failed convert to u256');
            let outcome: u256 = random_value_u256 % 100_u256;
            assert(outcome < 100, Errors::INVALID_OUTCOME); // 0 - 99

            // 48% chance for heads, 48% chance for tails, 4% chance for edge
            let mut coin_side = Outcome::None;
            if outcome < 48 {
                coin_side = Outcome::Heads;
            } else if outcome < 96 {
                coin_side = Outcome::Tails;
            } else {
                coin_side = Outcome::Edge;
            }

            assert(coin_side != Outcome::None, Errors::INVALID_OUTCOME);

            // Change game state to finished
            self.player_game_states.write((player, game_id), GameState::Finished);

            self.processed.write((game_id, player), true);

            let mut payout = 0;

            if bet.outcome == coin_side {
                if (bet.outcome == Outcome::Edge) {
                    payout = bet.amount * 22;
                } else if (bet.outcome == Outcome::Heads || bet.outcome == Outcome::Tails) {
                    payout = bet.amount * 2;
                } else {
                    assert(false, 'Invalid bet outcome');
                }
                if payout > safe_balance {
                    payout = safe_balance;
                }
                IControllerDispatcher { contract_address: self.controller_address.read() }
                    .process_cashout(player, payout);
            }

            // Setup next game
            let next_game = game_id + 1;
            self.player_games.write(player, next_game);
            self.player_game_states.write((player, next_game), GameState::Betting);

            self.emit(CashoutProcessed { game_id, player, amount: payout, outcome: coin_side });
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
