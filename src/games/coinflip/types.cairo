#[derive(Drop, Serde, starknet::Store, PartialEq)]
pub enum GameState {
    #[default]
    Betting, // Players can place bets
    Flipping, // Flipping the coin, no more bets can be placed
    Finished // Game is finished
}

#[derive(Drop, Copy, Serde, starknet::Store, PartialEq, Hash)]
pub enum Outcome {
    #[default]
    None,
    Heads,
    Tails,
    Edge,
}

#[derive(Drop, Copy, Serde, starknet::Store, PartialEq, Hash)]
pub struct Bet {
    pub amount: u256,
    pub outcome: Outcome,
}
