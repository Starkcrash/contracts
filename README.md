# Starkcrash Smart Contract

A Starknet smart contract implementation of a Crash Game where players can bet and attempt to cash out before the game crashes.

## Overview

Starkcrash is a multiplayer betting game where players place bets during a betting phase and try to cash out during the playing phase before the game crashes. The crash point is determined by a provably fair random number system using commit-reveal scheme.

## Game Flow

1. **Transition Phase**: Initial state for a new game
2. **Committed Seed Phase**: Operator commits a hashed seed for randomness
3. **Betting Phase**: Players can place their bets
4. **Playing Phase**: Game is live, multiplier increases, players can cash out
5. **Crashed Phase**: Game ends, next game begins

## Features

- Provably fair randomness using commit-reveal scheme
- Configurable casino fee (max 6%)
- Adjustable maximum bet limits
- Multiple bets per player allowed (configurable)
- Pausable functionality for emergencies
- Upgradeable design
- ETH-based betting system

## Core Functions

### Player Functions
- `place_bet(game_id, amount)`: Place a bet during betting phase
- `get_player_bet(player, game_id)`: Query bet amount for a player
- `get_game_state(game_id)`: Check current game state

### Operator Functions
- `commit_seed(seed_hash)`: Commit the seed hash for the next game
- `start_betting()`: Open betting phase
- `start_game()`: Start playing phase
- `end_game(seed)`: End game and reveal seed
- `process_cashout(game_id, player, multiplier)`: Process player cashout

### Management Functions
- `set_max_bet(max_bet)`: Set maximum bet amount
- `set_max_amount_of_bets(max_amount_of_bets)`: Set maximum bets per player
- `set_casino_fee_basis_points(casino_fee_basis_points)`: Set casino fee (max 6%)
- `set_casino_address(casino_address)`: Set casino fee recipient
- `set_operator(operator)`: Set operator address
- `pause()/unpause()`: Emergency pause/unpause

## Events

- `BetPlaced`: Emitted when a player places a bet
- `CashoutProcessed`: Emitted when a player successfully cashes out
- `GameStarted`: Emitted when a new game starts
- `GameEnded`: Emitted when a game ends
- `CasinoCut`: Emitted when casino fee is collected

## Security Features

- Ownership management using OpenZeppelin's Ownable pattern
- Pausable functionality for emergency situations
- Input validation for all parameters
- Protection against multiple cashouts
- Maximum bet limits
- Casino fee capped at 6%

## Dependencies

- OpenZeppelin Contracts (Ownable, Pausable, Upgradeable)
- Starknet Standard Library
- Poseidon Hash function for commit-reveal scheme

## Getting Started

1. Deploy the contract with initial operator and casino addresses
2. Set desired parameters (max bet, max bets per player, casino fee)
3. Start operating games following the game flow pattern

## Testing

Comprehensive test suite available covering all major functionality:
- Game state transitions
- Betting mechanics
- Cashout processing
- Management functions
- Error cases and security checks

## License

