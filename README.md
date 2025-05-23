# RainDinners

RainDinners is a casino platform built on Starknet featuring multiple betting games including Crash, Roulette and Coinflip.

## Overview

RainDinners is a comprehensive casino platform that allows players to participate in various betting games on Starknet. The platform features a modular architecture with a secure fund management system, game controller, and support for multiple game types. Currently available games include Crash, Roulette, and Coinflip, each offering unique gameplay mechanics and betting strategies.

## Platform Architecture

RainDinners consists of three main components:

1. **Safe Contract**: Securely stores all casino funds and only accepts calls from the Controller
2. **Controller Contract**: Manages game whitelisting, bet limits, and fee collection
3. **Game Contracts**: Individual game implementations (Crash, Roulette, and Coinflip)

```
Player → Game Contract → Controller Contract → Safe Contract
```

## Available Games

RainDinners currently offers three distinct betting games, each with unique mechanics:

### Crash Game

The Crash game is a multiplayer betting experience with the following flow:

### Game Flow

1. **Transition Phase**: Initial state for a new game
2. **Committed Seed Phase**: Operator commits a hashed seed for randomness
3. **Betting Phase**: Players can place their bets
4. **Playing Phase**: Game is live, multiplier increases, players can cash out
5. **Crashed Phase**: Game ends, next game begins

### Crash Game Features

- Provably fair randomness using commit-reveal scheme
- Real-time multiplier progression
- Multiple cashout opportunities
- Transparent crash point generation

### Roulette Game

A classic casino roulette implementation featuring:

- Standard roulette betting options (numbers, colors, odd/even, etc.)
- Provably fair random number generation
- Multiple bet types with varying payout ratios
- European-style single-zero roulette

### Coinflip Game

A three-outcome coin betting game featuring:

- Three possible outcomes: Heads (48%), Tails (48%), or Edge (4%)
- Strategic betting with asymmetric odds
- Quick rounds for fast-paced gameplay
- Provably fair random outcome generation

## Platform Features

- **Multi-game support**: Extensible architecture for adding new games
- **Configurable casino fees**: Maximum 6% house edge
- **Adjustable bet limits**: Per-game minimum and maximum bet configuration
- **Multiple bets per player**: Configurable limits per game
- **Emergency controls**: Pausable functionality for all games
- **Upgradeable design**: Future-proof contract architecture
- **ETH-based betting**: Native Ethereum betting system

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
- `set_min_bet(min_bet)`: Set minimum bet amount
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

## Dependencies

- OpenZeppelin Contracts (Ownable, Pausable, Upgradeable)
- Starknet Standard Library
- Poseidon Hash function for commit-reveal scheme

## Game Developer Guide

This section provides guidance for developers looking to implement new games for the RainDinners platform.

### Adding New Games to RainDinners

The RainDinners platform is designed to support multiple game types. With Crash, Roulette, and Coinflip already implemented, the modular architecture makes it easy to add additional games while maintaining security and consistency across the platform.

### Architecture Overview

All games on the RainDinners platform follow the same secure fund flow and integration pattern with the Controller and Safe contracts.

### Integration with Controller

All financial operations must go through the Controller:

1. **Bet Processing**:

   ```cairo
   // In your place_bet function:
   let eth = ERC20ABIDispatcher { contract_address: ETH_ADDRESS.try_into().unwrap() };
   eth.transferFrom(player, self.controller_address.read(), amount);
   IControllerDispatcher { contract_address: self.controller_address.read() }.process_bet(amount);
   ```

2. **Cashout Processing**:

   ```cairo
   // In your process_cashout function:
   let payout = (bet_amount * multiplier) / 10000;
   IControllerDispatcher { contract_address: self.controller_address.read() }.process_cashout(player, payout);
   ```

3. **Game Limits**:
   ```cairo
   // For getting min/max bet limits:
   IControllerDispatcher { contract_address: self.controller_address.read() }.get_min_bet(get_contract_address());
   IControllerDispatcher { contract_address: self.controller_address.read() }.get_max_bet(get_contract_address());
   ```

### Security Considerations

1. **Required Access Controls**:

   - Use OpenZeppelin's `Ownable` for owner-only functions
   - Ensure only the owner can modify game parameters
   - Include `Pausable` functionality for emergency stops

2. **Critical Checks**:

   - Validate bet amounts against min/max limits
   - Prevent duplicate processing of cashouts
   - Enforce game state transitions
   - Verify caller permissions for admin functions

3. **Funds Handling**:
   - Never store or transfer ETH directly
   - Always route funds through the Controller
   - Verify all arithmetic to prevent over/underflows
   - USE BASIS POINTS

## License
