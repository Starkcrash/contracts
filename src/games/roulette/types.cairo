use starknet::ContractAddress;

#[derive(Copy, Drop, PartialEq, Serde, starknet::Store)]
pub enum GameState {
    #[default]
    Betting,
    Spinning,
    Finished,
}

#[derive(Drop, Copy, Serde, starknet::Store, PartialEq, Hash)]
pub struct Bet {
    pub user_address: ContractAddress,
    pub bet_type: u64, // 0 for specific number, 1 for red/black, 2 for even/odd, 3 for column, 4 for dozen, 5 for high/low, 6 for split and corner
    pub bet_value: u64, // For type 0: number (1-36); for type 1: 0 for red, 1 for black; for type 2: 0 for even, 1 for odd; for type 3: 0 for first column, 1 for second column, 2 for third column; for type 4: 0 for first dozen, 1 for second dozen, 2 for third dozen; for type 5: 0 for low (1 -18), 1 for high (19-36);
    pub amount: u256,
    pub split_bet: bool,
    pub split_bet_value: [u256; 2],
    pub corner_bet: bool,
    pub corner_bet_value: [u256; 4],
}
