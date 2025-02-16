use starknet::ContractAddress;
use crash_contracts::types::GameState;

#[starknet::interface]
pub trait ICrashGame<TContractState> {
    fn get_game_state(self: @TContractState, game_id: u64) -> GameState;
    fn get_player_bet(self: @TContractState, player: ContractAddress, game_id: u64) -> u256;
    fn get_current_game(self: @TContractState) -> u64;
    fn start_game(ref self: TContractState);
    fn end_game(ref self: TContractState, seed: felt252);
    fn place_bet(ref self: TContractState, game_id: u64, amount: u256);
    fn process_cashout(
        ref self: TContractState, game_id: u64, player: ContractAddress, multiplier: u256,
    );
    fn start_betting(ref self: TContractState);
    fn commit_seed(ref self: TContractState, seed_hash: felt252);
    fn get_seed(self: @TContractState, game_id: u64) -> felt252;
    fn get_seed_hash(self: @TContractState, game_id: u64) -> felt252;
}

#[starknet::interface]
pub trait IManagement<TContractState> {
    fn get_max_bet(self: @TContractState) -> u256;
    fn set_max_bet(ref self: TContractState, max_bet: u256);
    fn set_casino_address(ref self: TContractState, casino_address: ContractAddress);
    fn get_max_amount_of_bets(self: @TContractState) -> u8;
    fn set_max_amount_of_bets(ref self: TContractState, max_amount_of_bets: u8);
    fn get_casino_fee(self: @TContractState) -> u256;
    fn set_casino_fee_basis_points(ref self: TContractState, casino_fee_basis_points: u256);
    fn get_min_bet(self: @TContractState) -> u256;
    fn set_min_bet(ref self: TContractState, min_bet: u256);
}

#[starknet::contract]
pub mod CrashGame {
    use starknet::{ContractAddress, get_caller_address, storage::Map, ClassHash};
    use openzeppelin_token::erc20::interface::{ERC20ABIDispatcher, ERC20ABIDispatcherTrait};
    use openzeppelin_security::PausableComponent;
    use openzeppelin_access::ownable::OwnableComponent;
    use openzeppelin::upgrades::interface::IUpgradeable;
    use openzeppelin::upgrades::UpgradeableComponent;
    component!(path: PausableComponent, storage: pausable, event: PausableEvent);
    component!(path: OwnableComponent, storage: ownable, event: OwnableEvent);
    component!(path: UpgradeableComponent, storage: upgradeable, event: UpgradeableEvent);


    use super::{ICrashGame, IManagement};
    use crash_contracts::types::GameState;
    use crash_contracts::crashgame::errors::Errors;

    use core::poseidon::PoseidonTrait;
    use core::hash::{HashStateTrait};


    // CONSTANTS
    const ETH_ADDRESS: felt252 = 0x049d36570d4e46f48e99674bd3fcc84644ddd6b96f7c741b1562b82f9e004dc7;
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


    #[storage]
    struct Storage {
        #[substorage(v0)]
        ownable: OwnableComponent::Storage,
        #[substorage(v0)]
        pausable: PausableComponent::Storage,
        #[substorage(v0)]
        upgradeable: UpgradeableComponent::Storage,
        casino_address: ContractAddress,
        player_bets: Map::<(u64, ContractAddress), u256>,
        processed: Map::<(u64, ContractAddress), bool>,
        current_game_id: u64,
        game_states: Map::<u64, GameState>,
        total_bets: Map::<u64, u256>,
        committed_seeds: Map::<u64, felt252>,
        revealed_seeds: Map::<u64, felt252>,
        max_bet: u256,
        max_amount_of_bets: u8,
        casino_fee_basis_points: u256,
        min_bet: u256,
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
        GameStarted: GameStarted,
        GameEnded: GameEnded,
        CasinoCut: CasinoCut,
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
        multiplier: u256,
    }

    #[derive(Drop, starknet::Event)]
    struct GameStarted {
        game_id: u64,
        seed_hash: felt252,
    }

    #[derive(Drop, starknet::Event)]
    struct GameEnded {
        game_id: u64,
        seed: felt252,
    }

    #[derive(Drop, starknet::Event)]
    struct CasinoCut {
        game_id: u64,
        amount: u256,
    }

    #[constructor]
    fn constructor(
        ref self: ContractState, operator: ContractAddress, casino_address: ContractAddress,
    ) {
        self.ownable.initializer(operator);
        self.casino_address.write(casino_address);
        self.game_states.write(0, GameState::Transition);
        self.max_bet.write(1_000_000_000_000_000_0); // 0.01 ETH by default
        self.max_amount_of_bets.write(2);
        self.casino_fee_basis_points.write(0);
        self.min_bet.write(100_000_000_000_000); // 0.00001 ETH by default
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
    impl ICrashGameImpl of ICrashGame<ContractState> {
        /// Get the current state of a specific game
        /// # Arguments
        /// * `game_id` - The ID of the game to query
        /// # Returns
        /// * The GameState enum value for the specified game
        fn get_game_state(self: @ContractState, game_id: u64) -> GameState {
            self.game_states.read(game_id)
        }

        /// Get the bet amount placed by a player in a specific game
        /// # Arguments
        /// * `player` - The address of the player
        /// * `game_id` - The ID of the game to query
        /// # Returns
        /// * The bet amount in wei
        fn get_player_bet(self: @ContractState, player: ContractAddress, game_id: u64) -> u256 {
            self.player_bets.read((game_id, player))
        }

        /// Get the ID of the current active game
        /// # Returns
        /// * The current game ID
        fn get_current_game(self: @ContractState) -> u64 {
            self.current_game_id.read()
        }

        /// Get the revealed seed for a completed game
        /// # Arguments
        /// * `game_id` - The ID of the completed game
        /// # Returns
        /// * The revealed seed value
        /// # Reverts
        /// * If game is not in Crashed state
        fn get_seed(self: @ContractState, game_id: u64) -> felt252 {
            assert(
                self.game_states.read(game_id) == GameState::Crashed,
                Errors::GAME_NOT_IN_CRASHED_STATE,
            );
            self.revealed_seeds.read(game_id)
        }

        /// Get the committed seed hash for a game
        /// # Arguments
        /// * `game_id` - The ID of the game
        /// # Returns
        /// * The committed seed hash
        fn get_seed_hash(self: @ContractState, game_id: u64) -> felt252 {
            self.committed_seeds.read(game_id)
        }

        /// Commit a seed hash for the current game, called by operator
        /// # Arguments
        /// * `seed_hash` - The hash of the seed to commit
        /// # Reverts
        /// * If caller is not the owner
        /// * If contract is paused
        /// * If game is not in Transition state
        /// * If seed is already committed
        /// # Effects
        /// * Sets game state to CommittedSeed
        /// * Stores the committed seed hash
        fn commit_seed(ref self: ContractState, seed_hash: felt252) {
            self.ownable.assert_only_owner();
            self.pausable.assert_not_paused();

            let game_id = self.current_game_id.read();
            assert(
                self.game_states.read(game_id) == GameState::Transition,
                Errors::GAME_NOT_IN_TRANSITION_STATE,
            );
            assert(self.committed_seeds.read(game_id) == 0, Errors::ALREADY_COMMITTED_SEED);
            self.game_states.write(game_id, GameState::CommittedSeed);
            self.committed_seeds.write(game_id, seed_hash);
        }

        /// Start the betting phase for the current game, called by operator
        /// # Reverts
        /// * If caller is not the owner
        /// * If contract is paused
        /// * If game is not in CommittedSeed state
        /// * If no seed has been committed
        /// # Effects
        /// * Sets game state to Betting
        fn start_betting(ref self: ContractState) {
            self.ownable.assert_only_owner();
            self.pausable.assert_not_paused();

            let game_id = self.current_game_id.read();
            assert(
                self.game_states.read(game_id) == GameState::CommittedSeed,
                Errors::GAME_NOT_IN_COMMITTED_SEED_STATE,
            );
            assert(self.committed_seeds.read(game_id) != 0, Errors::NO_COMMITTED_SEED);

            self.game_states.write(game_id, GameState::Betting);
        }

        /// Start the playing phase of the current game, called by operator
        /// # Reverts
        /// * If caller is not the owner
        /// * If contract is paused
        /// * If game is not in Betting state
        /// # Effects
        /// * Sets game state to Playing
        /// * Emits GameStarted event
        fn start_game(ref self: ContractState) {
            self.ownable.assert_only_owner();
            self.pausable.assert_not_paused();

            let game_id = self.current_game_id.read();

            assert(
                self.game_states.read(game_id) == GameState::Betting,
                Errors::GAME_NOT_IN_BETTING_STATE,
            );

            let seed_hash = self.committed_seeds.read(game_id);
            self.game_states.write(game_id, GameState::Playing);
            self.emit(GameStarted { game_id, seed_hash });
        }

        /// End the current game and reveal the seed, called by operator
        /// # Arguments
        /// * `seed` - The seed value to reveal
        /// # Reverts
        /// * If caller is not the owner
        /// * If contract is paused
        /// * If game is not in Playing state
        /// * If revealed seed hash doesn't match committed hash
        /// # Effects
        /// * Sets current game to Crashed state
        /// * Creates next game in Transition state
        /// * Stores revealed seed
        /// * Emits GameEnded event
        fn end_game(ref self: ContractState, seed: felt252) {
            self.ownable.assert_only_owner();
            self.pausable.assert_not_paused();

            let game_id = self.current_game_id.read();
            assert(
                self.game_states.read(game_id) == GameState::Playing,
                Errors::GAME_NOT_IN_PLAYING_STATE,
            );

            let committed_hash = self.committed_seeds.read(game_id);

            let computed_hash = PoseidonTrait::new().update(seed).finalize();
            assert(committed_hash == computed_hash, Errors::INVALID_SEED);
            // Mark current game as crashed
            self.revealed_seeds.write(game_id, seed);
            self.game_states.write(game_id, GameState::Crashed);

            // Setup next game
            let next_game = game_id + 1;
            self.current_game_id.write(next_game);
            self.game_states.write(next_game, GameState::Transition);

            self.emit(GameEnded { game_id, seed: seed });
        }

        /// Place a bet in the current game
        /// # Arguments
        /// * `game_id` - The ID of the game to bet in
        /// * `amount` - The amount to bet in wei
        /// # Reverts
        /// * If amount exceeds max bet
        /// * If contract is paused
        /// * If game is not in Betting state
        /// * If total bet exceeds max allowed
        /// # Effects
        /// * Stores player's bet
        /// * Updates total bets
        /// * Transfers bet amount from player
        /// * Transfers casino fee
        /// * Emits BetPlaced and CasinoCut events
        fn place_bet(ref self: ContractState, game_id: u64, amount: u256) {
            assert(amount <= self.max_bet.read(), Errors::AMOUNT_EXCEEDS_MAX_BET);
            assert(amount >= self.min_bet.read(), Errors::AMOUNT_BELOW_MIN_BET);

            self.pausable.assert_not_paused();

            let player = get_caller_address();

            // Verify game state
            assert(
                self.game_states.read(game_id) == GameState::Betting,
                Errors::GAME_NOT_IN_BETTING_STATE,
            );

            let existing_bet = self.player_bets.read((game_id, player));
            let total_bet = existing_bet + amount;
            assert(
                total_bet <= self.max_bet.read() * self.max_amount_of_bets.read().into(),
                Errors::TOTAL_BET_EXCEEDS_MAX_BET,
            );
            // Store bet
            self.player_bets.write((game_id, player), total_bet);
            self.processed.write((game_id, player), false);

            // Update total bets
            let current_total = self.total_bets.read(game_id);
            self.total_bets.write(game_id, current_total + amount);

            // Transfer player bet to contract
            let eth = ERC20ABIDispatcher { contract_address: ETH_ADDRESS.try_into().unwrap() };
            eth.transfer_from(player, starknet::get_contract_address(), amount);

            // Casino cut
            let casino_address = self.casino_address.read();
            let casino_fee = (amount * self.casino_fee_basis_points.read()) / BASIS_POINTS;
            eth.transfer(casino_address, casino_fee);

            self.emit(BetPlaced { game_id, player, amount });
            self.emit(CasinoCut { game_id, amount: casino_fee });
        }

        /// Process a player's cashout request for a specific game, called by the operator
        /// # Arguments
        /// * `game_id` - The ID of the game to process cashout for
        /// * `player` - The address of the player cashing out
        /// * `multiplier` - The multiplier to apply to the player's bet (in basis points, >10000)
        /// # Reverts
        /// * If caller is not the owner
        /// * If multiplier is <= 10000 (1x)
        /// * If player has already processed their cashout
        /// # Effects
        /// * Marks player's bet as processed
        /// * Transfers payout amount to player
        /// * Emits CashoutProcessed event
        fn process_cashout(
            ref self: ContractState, game_id: u64, player: ContractAddress, multiplier: u256,
        ) {
            self.ownable.assert_only_owner();
            assert(multiplier > 10000, 'Multiplier must be > than 1');
            let bet_amount = self.player_bets.read((game_id, player));
            assert(!self.processed.read((game_id, player)), 'Already processed');

            // Mark as processed and pay
            self.processed.write((game_id, player), true);
            let payout = bet_amount * multiplier / BASIS_POINTS;

            let eth = ERC20ABIDispatcher { contract_address: ETH_ADDRESS.try_into().unwrap() };
            eth.transfer(player, payout);

            self.emit(CashoutProcessed { game_id, player, amount: payout, multiplier });
        }
    }

    #[abi(embed_v0)]
    impl IManagementImpl of IManagement<ContractState> {
        fn get_max_bet(self: @ContractState) -> u256 {
            self.max_bet.read()
        }

        fn get_max_amount_of_bets(self: @ContractState) -> u8 {
            self.max_amount_of_bets.read()
        }

        fn get_casino_fee(self: @ContractState) -> u256 {
            self.casino_fee_basis_points.read()
        }

        fn get_min_bet(self: @ContractState) -> u256 {
            self.min_bet.read()
        }

        fn set_max_bet(ref self: ContractState, max_bet: u256) {
            self.ownable.assert_only_owner();
            self.max_bet.write(max_bet)
        }

        fn set_max_amount_of_bets(ref self: ContractState, max_amount_of_bets: u8) {
            self.ownable.assert_only_owner();
            self.max_amount_of_bets.write(max_amount_of_bets)
        }

        fn set_min_bet(ref self: ContractState, min_bet: u256) {
            self.ownable.assert_only_owner();
            assert(min_bet < self.max_bet.read(), 'Min bet must be <= max bet');
            self.min_bet.write(min_bet)
        }

        fn set_casino_fee_basis_points(ref self: ContractState, casino_fee_basis_points: u256) {
            self.ownable.assert_only_owner();
            assert(casino_fee_basis_points <= 600, 'Casino fee must be <= 600');
            self.casino_fee_basis_points.write(casino_fee_basis_points);
        }

        fn set_casino_address(ref self: ContractState, casino_address: ContractAddress) {
            self.ownable.assert_only_owner();
            self.casino_address.write(casino_address)
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

