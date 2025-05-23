pub mod Errors {
    pub const GAME_NOT_IN_TRANSITION_STATE: felt252 = 'Game not in Transition state';
    pub const GAME_NOT_IN_BETTING_STATE: felt252 = 'Game not in Betting state';
    pub const GAME_NOT_IN_FINISHED_STATE: felt252 = 'Game not in Finished state';
    pub const USER_ALREADY_PLACED_BET: felt252 = 'User already placed bet';
    pub const ALREADY_COMMITTED_SEED: felt252 = 'Seed already committed';
    pub const AMOUNT_EXCEEDS_MAX_BET: felt252 = 'Bet amount exceeds max bet';
    pub const TOTAL_BET_EXCEEDS_MAX_BET: felt252 = 'Total bet exceeds x max bet';
    pub const AMOUNT_BELOW_MIN_BET: felt252 = 'Amount below minimum bet';
    pub const NO_BETS_PLACED: felt252 = 'No bets placed';
    pub const INVALID_OUTCOME: felt252 = 'Invalid outcome';
    pub const ALREADY_PROCESSED: felt252 = 'Already processed';
    pub const TRANSFER_FAILED: felt252 = 'Transfer failed';
    pub const CONTROLLER_CALL_FAILED: felt252 = 'Controller call failed';
    pub const VRF_FAILED: felt252 = 'VRF failed';
    pub const TOO_MANY_BETS: felt252 = 'Bet limit is 10';
    pub const NOT_ENOUGH_FUNDS: felt252 = 'Casino: Not enough funds';
}
