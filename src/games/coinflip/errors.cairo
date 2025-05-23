pub mod Errors {
    pub const NO_COMMITTED_SEED: felt252 = 'No committed seed';
    pub const GAME_NOT_IN_COMMITTED_SEED_STATE: felt252 = 'Game not in CommittedSeed state';
    pub const GAME_NOT_IN_TRANSITION_STATE: felt252 = 'Game not in Transition state';
    pub const GAME_NOT_IN_BETTING_STATE: felt252 = 'Game not in Betting state';
    pub const GAME_NOT_IN_FINISHED_STATE: felt252 = 'Game not in Finished state';
    pub const ALREADY_COMMITTED_SEED: felt252 = 'Seed already committed';
    pub const ALREADY_PLACED_BET: felt252 = 'Bet already placed';
    pub const INVALID_SEED: felt252 = 'Invalid seed';
    pub const AMOUNT_EXCEEDS_MAX_BET: felt252 = 'Bet amount exceeds max bet';
    pub const TOTAL_BET_EXCEEDS_MAX_BET: felt252 = 'Total bet exceeds x max bet';
    pub const AMOUNT_BELOW_MIN_BET: felt252 = 'Amount below minimum bet';
    pub const INVALID_OUTCOME: felt252 = 'Invalid outcome';
    pub const ALREADY_PROCESSED: felt252 = 'Already processed';
    pub const INVALID_BET: felt252 = 'Invalid bet';
    pub const INSUFFICIENT_SAFE_BALANCE: felt252 = 'Insufficient safe balance';
    pub const INVALID_RANDOM_VALUE: felt252 = 'Invalid random value';
}
