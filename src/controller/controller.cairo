use starknet::ContractAddress;

/// Interface for game interactions with the controller
/// Provides methods for games to verify status, retrieve limits, and process bets
#[starknet::interface]
pub trait IController<TContractState> {
    /// Check if a game is whitelisted
    /// # Arguments
    /// * `game` - The address of the game contract to check
    /// # Returns
    /// * `true` if the game is whitelisted, `false` otherwise
    fn is_game_whitelisted(self: @TContractState, game: ContractAddress) -> bool;

    /// Get the maximum bet allowed for a game
    /// # Arguments
    /// * `game` - The address of the game contract
    /// # Returns
    /// * The maximum bet amount in wei
    /// # Reverts
    /// * If the game is not whitelisted
    fn get_max_bet(self: @TContractState, game: ContractAddress) -> u256;

    /// Get the minimum bet allowed for a game
    /// # Arguments
    /// * `game` - The address of the game contract
    /// # Returns
    /// * The minimum bet amount in wei
    /// # Reverts
    /// * If the game is not whitelisted
    fn get_min_bet(self: @TContractState, game: ContractAddress) -> u256;

    /// Process a bet placement through the controller
    /// # Arguments
    /// * `amount` - The bet amount in wei
    /// # Returns
    /// * `true` if the bet was successfully processed
    /// # Reverts
    /// * If the game is not whitelisted
    /// * If the bet amount is below minimum or above maximum
    /// * If the contract is paused
    fn process_bet(ref self: TContractState, amount: u256) -> bool;

    /// Process a cashout through the controller
    /// # Arguments
    /// * `player` - The address of the player cashing out
    /// * `amount` - The payout amount in wei
    /// # Returns
    /// * `true` if the cashout was successfully processed
    /// # Reverts
    /// * If caller is not the game contract
    /// * If the game is not whitelisted
    /// * If the contract is paused
    /// * If the safe has insufficient liquidity
    fn process_cashout(ref self: TContractState, player: ContractAddress, amount: u256) -> bool;
}

/// Interface for administrative management of the controller
/// Provides methods for owners to configure games, fees, and view system state
#[starknet::interface]
pub trait IControllerManagement<TContractState> {
    /// Get the current balance of the safe
    /// # Returns
    /// * The total liquidity in the safe in wei
    fn get_safe_balance(self: @TContractState) -> u256;

    /// Whitelist a new game
    /// # Arguments
    /// * `game` - The address of the game contract to whitelist
    /// * `min_bet` - The minimum bet amount for this game in wei
    /// * `max_bet` - The maximum bet amount for this game in wei
    /// # Reverts
    /// * If the game is already whitelisted
    /// * If min_bet >= max_bet
    /// * If caller is not the owner
    fn whitelist_game(
        ref self: TContractState, game: ContractAddress, min_bet: u256, max_bet: u256,
    );

    /// Remove a game from the whitelist
    /// # Arguments
    /// * `game` - The address of the game contract to remove
    /// # Reverts
    /// * If the game is not whitelisted
    /// * If caller is not the owner
    fn remove_game(ref self: TContractState, game: ContractAddress);

    /// Get the address of the safe contract
    /// # Returns
    /// * The address of the safe contract
    fn get_safe_address(self: @TContractState) -> ContractAddress;


    /// Set the minimum bet for a whitelisted game
    /// # Arguments
    /// * `game` - The address of the game contract
    /// * `min_bet` - The new minimum bet amount in wei
    /// # Reverts
    /// * If the game is not whitelisted
    fn set_min_bet(ref self: TContractState, game: ContractAddress, min_bet: u256);

    /// Set the maximum bet for a whitelisted game
    /// # Arguments
    /// * `game` - The address of the game contract
    /// * `max_bet` - The new maximum bet amount in wei
    /// # Reverts
    fn set_max_bet(ref self: TContractState, game: ContractAddress, max_bet: u256);
}

/// The Controller is the central component of the casino system
/// It mediates interactions between games and the safe,
/// enforces security policies, and manages game whitelist
#[starknet::contract]
pub mod Controller {
    use openzeppelin::upgrades::UpgradeableComponent;
    use openzeppelin::upgrades::interface::IUpgradeable;
    use openzeppelin_access::ownable::OwnableComponent;
    use openzeppelin_security::PausableComponent;
    use openzeppelin_token::erc20::interface::{ERC20ABIDispatcher, ERC20ABIDispatcherTrait};
    use starknet::storage::Map;
    use starknet::{ClassHash, ContractAddress, get_caller_address};
    use crate::controller::errors::Errors;
    use crate::safe::safe::{ISafeDispatcher, ISafeDispatcherTrait};
    use super::{IController, IControllerManagement};

    component!(path: OwnableComponent, storage: ownable, event: OwnableEvent);
    component!(path: PausableComponent, storage: pausable, event: PausableEvent);
    component!(path: UpgradeableComponent, storage: upgradeable, event: UpgradeableEvent);

    // Ethereum token address on Starknet
    const ETH_ADDRESS: felt252 = 0x049d36570d4e46f48e99674bd3fcc84644ddd6b96f7c741b1562b82f9e004dc7;
    // Basis points denominator for fee calculations (10000 = 100%)
    const BASIS_POINTS: u256 = 10000;

    // Ownable Mixin
    #[abi(embed_v0)]
    impl OwnableMixinImpl = OwnableComponent::OwnableMixinImpl<ContractState>;
    impl OwnableInternalImpl = OwnableComponent::InternalImpl<ContractState>;

    // Pausable
    #[abi(embed_v0)]
    impl PausableImpl = PausableComponent::PausableImpl<ContractState>;
    impl PausableInternalImpl = PausableComponent::InternalImpl<ContractState>;

    impl UpgradeableInternalImpl = UpgradeableComponent::InternalImpl<ContractState>;

    /// Storage for the Controller contract
    #[storage]
    struct Storage {
        #[substorage(v0)]
        ownable: OwnableComponent::Storage,
        #[substorage(v0)]
        pausable: PausableComponent::Storage,
        #[substorage(v0)]
        upgradeable: UpgradeableComponent::Storage,
        safe_address: ContractAddress, // Address of the safe contract
        whitelisted_games: Map<ContractAddress, bool>, // Map of whitelisted games
        game_max_bets: Map<ContractAddress, u256>, // Maximum bet per game
        game_min_bets: Map<ContractAddress, u256> // Minimum bet per game
    }

    /// Events emitted by the Controller contract
    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        #[flat]
        OwnableEvent: OwnableComponent::Event,
        #[flat]
        PausableEvent: PausableComponent::Event,
        #[flat]
        UpgradeableEvent: UpgradeableComponent::Event,
        GameWhitelisted: GameWhitelisted,
        GameRemoved: GameRemoved,
        PayoutProcessed: PayoutProcessed,
        GameLimitsUpdated: GameLimitsUpdated,
        BetProcessed: BetProcessed,
    }

    /// Event emitted when a game is whitelisted
    #[derive(Drop, starknet::Event)]
    struct GameWhitelisted {
        game: ContractAddress,
    }

    /// Event emitted when a game is removed from the whitelist
    #[derive(Drop, starknet::Event)]
    struct GameRemoved {
        game: ContractAddress,
    }

    /// Event emitted when a payout is processed
    #[derive(Drop, starknet::Event)]
    struct PayoutProcessed {
        game: ContractAddress,
        player: ContractAddress,
        amount: u256,
    }

    /// Event emitted when a payout is processed
    #[derive(Drop, starknet::Event)]
    struct BetProcessed {
        game: ContractAddress,
        amount: u256,
    }

    /// Event emitted when game limits are updated
    #[derive(Drop, starknet::Event)]
    struct GameLimitsUpdated {
        game: ContractAddress,
        min_bet: u256,
        max_bet: u256,
    }

    /// Constructor initializes the Controller contract
    /// # Arguments
    /// * `owner` - The address that will own the contract
    /// * `safe_address` - The address of the safe contract
    #[constructor]
    fn constructor(ref self: ContractState, owner: ContractAddress, safe_address: ContractAddress) {
        self.ownable.initializer(owner);
        self.safe_address.write(safe_address);
    }

    /// Implementation of external utility functions
    #[generate_trait]
    #[abi(per_item)]
    impl ExternalImpl of ExternalTrait {
        /// Pause the contract to halt operations in emergency
        /// # Reverts
        /// * If caller is not the owner
        #[external(v0)]
        fn pause(ref self: ContractState) {
            self.ownable.assert_only_owner();
            self.pausable.pause();
        }

        /// Unpause the contract to resume operations
        /// # Reverts
        /// * If caller is not the owner
        #[external(v0)]
        fn unpause(ref self: ContractState) {
            self.ownable.assert_only_owner();
            self.pausable.unpause();
        }
    }

    /// Implementation of the main controller interface
    #[abi(embed_v0)]
    impl IControllerImpl of IController<ContractState> {
        fn is_game_whitelisted(self: @ContractState, game: ContractAddress) -> bool {
            self.whitelisted_games.read(game)
        }

        fn get_max_bet(self: @ContractState, game: ContractAddress) -> u256 {
            self.game_max_bets.read(game)
        }

        fn get_min_bet(self: @ContractState, game: ContractAddress) -> u256 {
            self.game_min_bets.read(game)
        }

        fn process_bet(ref self: ContractState, amount: u256) -> bool {
            self.pausable.assert_not_paused();

            // Ensure caller is the game contract
            let game = get_caller_address();
            assert(self.whitelisted_games.read(game), Errors::GAME_NOT_WHITELISTED);

            // Validate bet amount
            let min_bet = self.game_min_bets.read(game);
            let max_bet = self.game_max_bets.read(game);
            assert(amount >= min_bet, Errors::AMOUNT_BELOW_MIN_BET);
            assert(amount <= max_bet, Errors::AMOUNT_EXCEEDS_MAX_BET);

            // ETH from player was already transferred to controller in the game contract
            // Forward to safe
            let safe = ISafeDispatcher { contract_address: self.safe_address.read() };
            let eth = ERC20ABIDispatcher { contract_address: ETH_ADDRESS.try_into().unwrap() };

            assert(eth.approve(safe.contract_address, amount), 'Approve failed');
            let result = safe.deposit_bet(amount);
            assert(result, 'Deposit failed');
            self.emit(BetProcessed { game, amount });
            result
        }

        fn process_cashout(ref self: ContractState, player: ContractAddress, amount: u256) -> bool {
            self.pausable.assert_not_paused();

            // Ensure caller is the game contract
            let game = get_caller_address();
            assert(self.whitelisted_games.read(game), Errors::GAME_NOT_WHITELISTED);

            // Process payout through safe
            let safe = ISafeDispatcher { contract_address: self.safe_address.read() };
            let result = safe.process_payout(player, amount);
            assert(result, 'Process payout failed');
            self.emit(PayoutProcessed { game, player, amount });
            result
        }
    }

    /// Implementation of management functions for the controller
    #[abi(embed_v0)]
    impl IControllerManagementImpl of IControllerManagement<ContractState> {
        fn whitelist_game(
            ref self: ContractState, game: ContractAddress, min_bet: u256, max_bet: u256,
        ) {
            self.ownable.assert_only_owner();
            assert(!self.whitelisted_games.read(game), Errors::GAME_ALREADY_WHITELISTED);
            assert(min_bet < max_bet, Errors::MIN_BET_GREATER_THAN_MAX_BET);
            self._set_min_bet(game, min_bet);
            self._set_max_bet(game, max_bet);
            self.whitelisted_games.write(game, true);
            self.emit(GameWhitelisted { game });
        }

        fn remove_game(ref self: ContractState, game: ContractAddress) {
            self.ownable.assert_only_owner();
            assert(self.whitelisted_games.read(game), Errors::GAME_NOT_WHITELISTED);
            self._set_min_bet(game, 0);
            self._set_max_bet(game, 0);
            self.whitelisted_games.write(game, false);
            self.emit(GameRemoved { game });
        }

        fn get_safe_address(self: @ContractState) -> ContractAddress {
            self.safe_address.read()
        }

        fn get_safe_balance(self: @ContractState) -> u256 {
            let safe = ISafeDispatcher { contract_address: self.safe_address.read() };
            safe.get_total_liquidity()
        }


        fn set_min_bet(ref self: ContractState, game: ContractAddress, min_bet: u256) {
            self.ownable.assert_only_owner();
            assert(self.whitelisted_games.read(game), Errors::GAME_NOT_WHITELISTED);
            assert(min_bet < self.game_max_bets.read(game), Errors::MIN_BET_GREATER_THAN_MAX_BET);
            self._set_min_bet(game, min_bet);
            self.emit(GameLimitsUpdated { game, min_bet, max_bet: self.game_max_bets.read(game) });
        }

        fn set_max_bet(ref self: ContractState, game: ContractAddress, max_bet: u256) {
            self.ownable.assert_only_owner();
            assert(self.whitelisted_games.read(game), Errors::GAME_NOT_WHITELISTED);
            assert(max_bet > self.game_min_bets.read(game), Errors::MAX_BET_LESS_THAN_MIN_BET);
            self._set_max_bet(game, max_bet);
            self.emit(GameLimitsUpdated { game, min_bet: self.game_min_bets.read(game), max_bet });
        }
    }

    #[generate_trait]
    impl InternalImpl of InternalTrait {
        fn _set_min_bet(ref self: ContractState, game: ContractAddress, min_bet: u256) {
            self.game_min_bets.write(game, min_bet);
        }

        fn _set_max_bet(ref self: ContractState, game: ContractAddress, max_bet: u256) {
            self.game_max_bets.write(game, max_bet);
        }
    }


    /// Implementation of the upgradeable interface
    #[abi(embed_v0)]
    impl UpgradeableImpl of IUpgradeable<ContractState> {
        /// Upgrade the contract to a new implementation
        /// # Arguments
        /// * `new_class_hash` - The class hash of the new implementation
        /// # Reverts
        /// * If caller is not the owner
        fn upgrade(ref self: ContractState, new_class_hash: ClassHash) {
            self.ownable.assert_only_owner();
            self.upgradeable.upgrade(new_class_hash);
        }
    }
}
