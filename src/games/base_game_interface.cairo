use starknet::ContractAddress;

/// Base interface that all casino games must implement
/// This ensures consistent interaction between games, the controller, and players
#[starknet::interface]
pub trait IBaseGame<TContractState> {
    /// Get the current game instance ID
    /// # Returns
    /// * The current game ID being played or prepared
    fn get_current_game(self: @TContractState) -> u64;

    /// Get the game's state
    /// # Arguments
    /// * `game_id` - The specific game instance ID to query
    /// # Returns
    /// * The current state of the specified game as a game-specific enum
    fn get_game_state(self: @TContractState, game_id: u64) -> felt252;

    /// Get the bet amount placed by a player in a specific game
    /// # Arguments
    /// * `player` - The address of the player
    /// * `game_id` - The ID of the game to query
    /// # Returns
    /// * The bet amount in wei
    fn get_player_bet(self: @TContractState, player: ContractAddress, game_id: u64) -> u256;

    /// Place a bet in the current game
    /// # Arguments
    /// * `amount` - The amount to bet in wei
    /// # Returns
    /// * true if the bet was successfully placed
    /// # Reverts
    /// * If amount exceeds max bet or is below min bet
    /// * If contract is paused
    /// * If game is not in a state that allows betting
    /// * If total bet exceeds max allowed
    fn place_bet(ref self: TContractState, amount: u256) -> bool;

    /// Process a cashout for a player (typically called by operator)
    /// # Arguments
    /// * `game_id` - The game instance ID
    /// * `player` - The address of the player to receive payout
    /// * `multiplier` - The multiplier to apply to player's bet (in basis points, >10000)
    /// # Reverts
    /// * If caller is not authorized
    /// * If player has already processed their cashout
    /// * If multiplier is invalid
    fn process_cashout(
        ref self: TContractState, game_id: u64, player: ContractAddress, multiplier: u256,
    );
}

/// Management interface for game configuration
#[starknet::interface]
pub trait IGameManagement<TContractState> {
    /// Get the maximum bet allowed for this game
    /// # Returns
    /// * The maximum bet amount in wei
    fn get_max_bet(self: @TContractState) -> u256;

    /// Get the minimum bet allowed for this game
    /// # Returns
    /// * The minimum bet amount in wei
    fn get_min_bet(self: @TContractState) -> u256;

    /// Get the address of the controller contract
    /// # Returns
    /// * The controller contract address
    fn get_controller_address(self: @TContractState) -> ContractAddress;
}

/// Common events that all games should emit for consistent tracking
/// Games may emit additional game-specific events as needed
#[starknet::interface]
pub trait IBaseGameEvents<TContractState> {
    /// Event emitted when a player places a bet
    fn emit_bet_placed(
        ref self: TContractState, game_id: u64, player: ContractAddress, amount: u256,
    );

    /// Event emitted when a player receives a payout
    fn emit_cashout_processed(
        ref self: TContractState,
        game_id: u64,
        player: ContractAddress,
        amount: u256,
        multiplier: u256,
    );

    /// Event emitted when a game starts
    fn emit_game_started(ref self: TContractState, game_id: u64);

    /// Event emitted when a game ends
    fn emit_game_ended(ref self: TContractState, game_id: u64);
}

/// Basic implementation of the game lifecycle
#[starknet::interface]
pub trait IGameLifecycle<TContractState> {
    /// Start the betting phase for the current game
    /// # Reverts
    /// * If caller is not authorized
    /// * If game is not in the correct state
    fn start_betting(ref self: TContractState);

    /// Start the game play phase
    /// # Reverts
    /// * If caller is not authorized
    /// * If game is not in the correct state
    fn start_game(ref self: TContractState);

    /// End the current game and prepare for the next one
    /// # Arguments
    /// * Game-specific ending parameters
    /// # Reverts
    /// * If caller is not authorized
    /// * If game is not in the correct state
    fn end_game(ref self: TContractState);
}

/// Utility functions and recommendations for game developers implementing this interface
pub mod base_game_utils {
    use openzeppelin_token::erc20::interface::{ERC20ABIDispatcher, ERC20ABIDispatcherTrait};
    use starknet::{ContractAddress, get_contract_address};
    use crate::controller::controller::{IControllerDispatcher, IControllerDispatcherTrait};

    /// Ethereum token address on Starknet
    const ETH_ADDRESS: felt252 = 0x049d36570d4e46f48e99674bd3fcc84644ddd6b96f7c741b1562b82f9e004dc7;
    /// Basis points denominator for fee and multiplier calculations (10000 = 100%)
    const BASIS_POINTS: u256 = 10000;

    /// Process a bet through the controller
    /// # Arguments
    /// * `controller_address` - The address of the controller contract
    /// * `player` - The player's address
    /// * `amount` - The bet amount in wei
    /// # Returns
    /// * true if the bet was successfully processed
    pub fn process_bet_through_controller(
        controller_address: ContractAddress, player: ContractAddress, amount: u256,
    ) -> bool {
        // Transfer tokens from the player to the game contract
        let eth = ERC20ABIDispatcher { contract_address: ETH_ADDRESS.try_into().unwrap() };
        eth.transfer_from(player, get_contract_address(), amount);

        // Process the bet through the controller
        let controller = IControllerDispatcher { contract_address: controller_address };
        controller.process_bet(amount)
    }

    /// Process a cashout through the controller
    /// # Arguments
    /// * `controller_address` - The address of the controller contract
    /// * `player` - The player's address to receive the payout
    /// * `amount` - The payout amount in wei
    /// # Returns
    /// * true if the cashout was successfully processed
    pub fn process_cashout_through_controller(
        controller_address: ContractAddress, player: ContractAddress, amount: u256,
    ) -> bool {
        let controller = IControllerDispatcher { contract_address: controller_address };
        controller.process_cashout(player, amount)
    }

    /// Calculate a payout amount based on a bet and multiplier
    /// # Arguments
    /// * `bet_amount` - The original bet amount
    /// * `multiplier` - The multiplier in basis points (10000 = 1x)
    /// # Returns
    /// * The calculated payout amount
    pub fn calculate_payout(bet_amount: u256, multiplier: u256) -> u256 {
        (bet_amount * multiplier) / BASIS_POINTS
    }

    /// Get the game limits from the controller
    /// # Arguments
    /// * `controller_address` - The address of the controller contract
    /// # Returns
    /// * (min_bet, max_bet) tuple of game limits
    pub fn get_game_limits(
        controller_address: ContractAddress, game_address: ContractAddress,
    ) -> (u256, u256) {
        let controller = IControllerDispatcher { contract_address: controller_address };
        let min_bet = controller.get_min_bet(game_address);
        let max_bet = controller.get_max_bet(game_address);
        (min_bet, max_bet)
    }
}
/// Common implementation recommendations:
///
/// 1. All games should store player bets mapped by game_id and player address
/// 2. Track whether a player's bet has been processed to prevent double payouts
/// 3. Maintain a clear state machine for game lifecycle
/// 4. Use the controller for all fund transfers to maintain security
/// 5. Emit standardized events for all key actions
/// 6. Implement proper access controls using OpenZeppelin's Ownable pattern
/// 7. Add pausable functionality for emergency scenarios
/// 8. Include upgrade mechanisms for future improvements


