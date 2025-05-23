pub mod Errors {
    pub const NO_COMMITTED_SEED: felt252 = 'No committed seed';
    pub const GAME_NOT_WHITELISTED: felt252 = 'Not game / game not whitelisted';
    pub const GAME_ALREADY_WHITELISTED: felt252 = 'Game already whitelisted';
    pub const AMOUNT_BELOW_MIN_BET: felt252 = 'Amount below min bet';
    pub const AMOUNT_EXCEEDS_MAX_BET: felt252 = 'Amount exceeds max bet';
    pub const INSUFFICIENT_SAFE_BALANCE: felt252 = 'Insufficient safe balance';
    pub const UNAUTHORIZED_ACCESS: felt252 = 'Unauthorized access';
    pub const ONLY_GAME_CAN_CALL: felt252 = 'Only game can call this';
    pub const MIN_BET_GREATER_THAN_MAX_BET: felt252 = 'Min bet ge max bet';
    pub const MAX_BET_LESS_THAN_MIN_BET: felt252 = 'Max bet le min bet';
}
