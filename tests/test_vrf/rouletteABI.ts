export const ABI = [
  {
    type: 'function',
    name: 'pause',
    inputs: [],
    outputs: [],
    state_mutability: 'external',
  },
  {
    type: 'function',
    name: 'unpause',
    inputs: [],
    outputs: [],
    state_mutability: 'external',
  },
  {
    type: 'impl',
    name: 'IRouletteGameImpl',
    interface_name:
      'raindinner_contracts::games::roulette::roulette::IRouletteGame',
  },
  {
    type: 'enum',
    name: 'raindinner_contracts::games::roulette::types::GameState',
    variants: [
      {
        name: 'Betting',
        type: '()',
      },
      {
        name: 'Spinning',
        type: '()',
      },
      {
        name: 'Finished',
        type: '()',
      },
      {
        name: 'Transition',
        type: '()',
      },
    ],
  },
  {
    type: 'struct',
    name: 'core::integer::u256',
    members: [
      {
        name: 'low',
        type: 'core::integer::u128',
      },
      {
        name: 'high',
        type: 'core::integer::u128',
      },
    ],
  },
  {
    type: 'enum',
    name: 'core::bool',
    variants: [
      {
        name: 'False',
        type: '()',
      },
      {
        name: 'True',
        type: '()',
      },
    ],
  },
  {
    type: 'struct',
    name: 'raindinner_contracts::games::roulette::types::Bet',
    members: [
      {
        name: 'game_id',
        type: 'core::integer::u64',
      },
      {
        name: 'user_address',
        type: 'core::starknet::contract_address::ContractAddress',
      },
      {
        name: 'bet_type',
        type: 'core::integer::u64',
      },
      {
        name: 'bet_value',
        type: 'core::integer::u64',
      },
      {
        name: 'amount',
        type: 'core::integer::u256',
      },
      {
        name: 'split_bet',
        type: 'core::bool',
      },
      {
        name: 'split_bet_value',
        type: '[core::integer::u64; 2]',
      },
      {
        name: 'corner_bet',
        type: 'core::bool',
      },
      {
        name: 'corner_bet_value',
        type: '[core::integer::u64; 4]',
      },
    ],
  },
  {
    type: 'interface',
    name: 'raindinner_contracts::games::roulette::roulette::IRouletteGame',
    items: [
      {
        type: 'function',
        name: 'get_game_state',
        inputs: [
          {
            name: 'game_id',
            type: 'core::integer::u64',
          },
          {
            name: 'player',
            type: 'core::starknet::contract_address::ContractAddress',
          },
        ],
        outputs: [
          {
            type: 'raindinner_contracts::games::roulette::types::GameState',
          },
        ],
        state_mutability: 'view',
      },
      {
        type: 'function',
        name: 'get_game_outcome',
        inputs: [
          {
            name: 'game_id',
            type: 'core::integer::u64',
          },
          {
            name: 'player',
            type: 'core::starknet::contract_address::ContractAddress',
          },
        ],
        outputs: [
          {
            type: 'core::integer::u256',
          },
        ],
        state_mutability: 'view',
      },
      {
        type: 'function',
        name: 'get_player_bets',
        inputs: [
          {
            name: 'player',
            type: 'core::starknet::contract_address::ContractAddress',
          },
          {
            name: 'game_id',
            type: 'core::integer::u64',
          },
        ],
        outputs: [
          {
            type: 'core::array::Array::<raindinner_contracts::games::roulette::types::Bet>',
          },
        ],
        state_mutability: 'view',
      },
      {
        type: 'function',
        name: 'get_total_player_bet_amount',
        inputs: [
          {
            name: 'player',
            type: 'core::starknet::contract_address::ContractAddress',
          },
          {
            name: 'game_id',
            type: 'core::integer::u64',
          },
        ],
        outputs: [
          {
            type: 'core::integer::u256',
          },
        ],
        state_mutability: 'view',
      },
      {
        type: 'function',
        name: 'get_current_game',
        inputs: [
          {
            name: 'player',
            type: 'core::starknet::contract_address::ContractAddress',
          },
        ],
        outputs: [
          {
            type: 'core::integer::u64',
          },
        ],
        state_mutability: 'view',
      },
      {
        type: 'function',
        name: 'play_game',
        inputs: [
          {
            name: 'bet',
            type: 'core::array::Array::<raindinner_contracts::games::roulette::types::Bet>',
          },
        ],
        outputs: [],
        state_mutability: 'external',
      },
    ],
  },
  {
    type: 'impl',
    name: 'IManagementImpl',
    interface_name:
      'raindinner_contracts::games::roulette::roulette::IManagement',
  },
  {
    type: 'interface',
    name: 'raindinner_contracts::games::roulette::roulette::IManagement',
    items: [
      {
        type: 'function',
        name: 'get_max_bet',
        inputs: [],
        outputs: [
          {
            type: 'core::integer::u256',
          },
        ],
        state_mutability: 'view',
      },
      {
        type: 'function',
        name: 'get_min_bet',
        inputs: [],
        outputs: [
          {
            type: 'core::integer::u256',
          },
        ],
        state_mutability: 'view',
      },
      {
        type: 'function',
        name: 'get_controller_address',
        inputs: [],
        outputs: [
          {
            type: 'core::starknet::contract_address::ContractAddress',
          },
        ],
        state_mutability: 'view',
      },
    ],
  },
  {
    type: 'impl',
    name: 'UpgradeableImpl',
    interface_name: 'openzeppelin_upgrades::interface::IUpgradeable',
  },
  {
    type: 'interface',
    name: 'openzeppelin_upgrades::interface::IUpgradeable',
    items: [
      {
        type: 'function',
        name: 'upgrade',
        inputs: [
          {
            name: 'new_class_hash',
            type: 'core::starknet::class_hash::ClassHash',
          },
        ],
        outputs: [],
        state_mutability: 'external',
      },
    ],
  },
  {
    type: 'impl',
    name: 'OwnableMixinImpl',
    interface_name: 'openzeppelin_access::ownable::interface::OwnableABI',
  },
  {
    type: 'interface',
    name: 'openzeppelin_access::ownable::interface::OwnableABI',
    items: [
      {
        type: 'function',
        name: 'owner',
        inputs: [],
        outputs: [
          {
            type: 'core::starknet::contract_address::ContractAddress',
          },
        ],
        state_mutability: 'view',
      },
      {
        type: 'function',
        name: 'transfer_ownership',
        inputs: [
          {
            name: 'new_owner',
            type: 'core::starknet::contract_address::ContractAddress',
          },
        ],
        outputs: [],
        state_mutability: 'external',
      },
      {
        type: 'function',
        name: 'renounce_ownership',
        inputs: [],
        outputs: [],
        state_mutability: 'external',
      },
      {
        type: 'function',
        name: 'transferOwnership',
        inputs: [
          {
            name: 'newOwner',
            type: 'core::starknet::contract_address::ContractAddress',
          },
        ],
        outputs: [],
        state_mutability: 'external',
      },
      {
        type: 'function',
        name: 'renounceOwnership',
        inputs: [],
        outputs: [],
        state_mutability: 'external',
      },
    ],
  },
  {
    type: 'impl',
    name: 'PausableImpl',
    interface_name: 'openzeppelin_security::interface::IPausable',
  },
  {
    type: 'interface',
    name: 'openzeppelin_security::interface::IPausable',
    items: [
      {
        type: 'function',
        name: 'is_paused',
        inputs: [],
        outputs: [
          {
            type: 'core::bool',
          },
        ],
        state_mutability: 'view',
      },
    ],
  },
  {
    type: 'constructor',
    name: 'constructor',
    inputs: [
      {
        name: 'operator',
        type: 'core::starknet::contract_address::ContractAddress',
      },
      {
        name: 'controller_address',
        type: 'core::starknet::contract_address::ContractAddress',
      },
    ],
  },
  {
    type: 'event',
    name: 'openzeppelin_access::ownable::ownable::OwnableComponent::OwnershipTransferred',
    kind: 'struct',
    members: [
      {
        name: 'previous_owner',
        type: 'core::starknet::contract_address::ContractAddress',
        kind: 'key',
      },
      {
        name: 'new_owner',
        type: 'core::starknet::contract_address::ContractAddress',
        kind: 'key',
      },
    ],
  },
  {
    type: 'event',
    name: 'openzeppelin_access::ownable::ownable::OwnableComponent::OwnershipTransferStarted',
    kind: 'struct',
    members: [
      {
        name: 'previous_owner',
        type: 'core::starknet::contract_address::ContractAddress',
        kind: 'key',
      },
      {
        name: 'new_owner',
        type: 'core::starknet::contract_address::ContractAddress',
        kind: 'key',
      },
    ],
  },
  {
    type: 'event',
    name: 'openzeppelin_access::ownable::ownable::OwnableComponent::Event',
    kind: 'enum',
    variants: [
      {
        name: 'OwnershipTransferred',
        type: 'openzeppelin_access::ownable::ownable::OwnableComponent::OwnershipTransferred',
        kind: 'nested',
      },
      {
        name: 'OwnershipTransferStarted',
        type: 'openzeppelin_access::ownable::ownable::OwnableComponent::OwnershipTransferStarted',
        kind: 'nested',
      },
    ],
  },
  {
    type: 'event',
    name: 'openzeppelin_security::pausable::PausableComponent::Paused',
    kind: 'struct',
    members: [
      {
        name: 'account',
        type: 'core::starknet::contract_address::ContractAddress',
        kind: 'data',
      },
    ],
  },
  {
    type: 'event',
    name: 'openzeppelin_security::pausable::PausableComponent::Unpaused',
    kind: 'struct',
    members: [
      {
        name: 'account',
        type: 'core::starknet::contract_address::ContractAddress',
        kind: 'data',
      },
    ],
  },
  {
    type: 'event',
    name: 'openzeppelin_security::pausable::PausableComponent::Event',
    kind: 'enum',
    variants: [
      {
        name: 'Paused',
        type: 'openzeppelin_security::pausable::PausableComponent::Paused',
        kind: 'nested',
      },
      {
        name: 'Unpaused',
        type: 'openzeppelin_security::pausable::PausableComponent::Unpaused',
        kind: 'nested',
      },
    ],
  },
  {
    type: 'event',
    name: 'openzeppelin_upgrades::upgradeable::UpgradeableComponent::Upgraded',
    kind: 'struct',
    members: [
      {
        name: 'class_hash',
        type: 'core::starknet::class_hash::ClassHash',
        kind: 'data',
      },
    ],
  },
  {
    type: 'event',
    name: 'openzeppelin_upgrades::upgradeable::UpgradeableComponent::Event',
    kind: 'enum',
    variants: [
      {
        name: 'Upgraded',
        type: 'openzeppelin_upgrades::upgradeable::UpgradeableComponent::Upgraded',
        kind: 'nested',
      },
    ],
  },
  {
    type: 'event',
    name: 'raindinner_contracts::games::roulette::roulette::RouletteGame::BetPlaced',
    kind: 'struct',
    members: [
      {
        name: 'game_id',
        type: 'core::integer::u64',
        kind: 'data',
      },
      {
        name: 'player',
        type: 'core::starknet::contract_address::ContractAddress',
        kind: 'data',
      },
      {
        name: 'amount',
        type: 'core::integer::u256',
        kind: 'data',
      },
    ],
  },
  {
    type: 'event',
    name: 'raindinner_contracts::games::roulette::roulette::RouletteGame::CashoutProcessed',
    kind: 'struct',
    members: [
      {
        name: 'game_id',
        type: 'core::integer::u64',
        kind: 'data',
      },
      {
        name: 'player',
        type: 'core::starknet::contract_address::ContractAddress',
        kind: 'data',
      },
      {
        name: 'amount',
        type: 'core::integer::u256',
        kind: 'data',
      },
    ],
  },
  {
    type: 'event',
    name: 'raindinner_contracts::games::roulette::roulette::RouletteGame::GameEnded',
    kind: 'struct',
    members: [
      {
        name: 'game_id',
        type: 'core::integer::u64',
        kind: 'data',
      },
      {
        name: 'player',
        type: 'core::starknet::contract_address::ContractAddress',
        kind: 'data',
      },
      {
        name: 'seed',
        type: 'core::felt252',
        kind: 'data',
      },
    ],
  },
  {
    type: 'event',
    name: 'raindinner_contracts::games::roulette::roulette::RouletteGame::CasinoCut',
    kind: 'struct',
    members: [
      {
        name: 'game_id',
        type: 'core::integer::u64',
        kind: 'data',
      },
      {
        name: 'amount',
        type: 'core::integer::u256',
        kind: 'data',
      },
    ],
  },
  {
    type: 'event',
    name: 'raindinner_contracts::games::roulette::roulette::RouletteGame::Event',
    kind: 'enum',
    variants: [
      {
        name: 'OwnableEvent',
        type: 'openzeppelin_access::ownable::ownable::OwnableComponent::Event',
        kind: 'flat',
      },
      {
        name: 'PausableEvent',
        type: 'openzeppelin_security::pausable::PausableComponent::Event',
        kind: 'flat',
      },
      {
        name: 'UpgradeableEvent',
        type: 'openzeppelin_upgrades::upgradeable::UpgradeableComponent::Event',
        kind: 'flat',
      },
      {
        name: 'BetPlaced',
        type: 'raindinner_contracts::games::roulette::roulette::RouletteGame::BetPlaced',
        kind: 'nested',
      },
      {
        name: 'CashoutProcessed',
        type: 'raindinner_contracts::games::roulette::roulette::RouletteGame::CashoutProcessed',
        kind: 'nested',
      },
      {
        name: 'GameEnded',
        type: 'raindinner_contracts::games::roulette::roulette::RouletteGame::GameEnded',
        kind: 'nested',
      },
      {
        name: 'CasinoCut',
        type: 'raindinner_contracts::games::roulette::roulette::RouletteGame::CasinoCut',
        kind: 'nested',
      },
    ],
  },
];
