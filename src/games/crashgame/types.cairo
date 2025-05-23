#[derive(Drop, starknet::Store, Serde, PartialEq)]
pub enum GameState {
    Betting, // Players can place bets
    Playing, // Game in progress, players can cash out
    Crashed, // Game ended, no more actions allowed
    #[default]
    Transition,
    CommittedSeed,
}
