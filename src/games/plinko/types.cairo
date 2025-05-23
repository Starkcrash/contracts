use starknet::ContractAddress;

#[derive(Copy, Drop, PartialEq, Serde, starknet::Store)]
pub enum GameState {
    #[default]
    Betting,
    Spinning,
    Finished,
}

#[derive(Copy, Drop, Serde, starknet::Store, PartialEq)]
pub struct Bet {
    pub amount: u256,
    pub multiplier: u256,
    pub user_address: ContractAddress,
}
