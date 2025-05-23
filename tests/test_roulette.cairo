use openzeppelin_token::erc20::interface::{ERC20ABIDispatcher, ERC20ABIDispatcherTrait};
use raindinner_contracts::controller::controller::{
    IControllerDispatcher, IControllerDispatcherTrait, IControllerManagementDispatcher,
    IControllerManagementDispatcherTrait,
};
use raindinner_contracts::games::roulette::roulette::{
    IManagementDispatcherTrait, IRouletteGameDispatcherTrait,
};
use raindinner_contracts::games::roulette::types::{Bet, GameState};
use raindinner_contracts::safe::safe::ISafeDispatcherTrait;
use snforge_std::{map_entry_address, start_cheat_caller_address, stop_cheat_caller_address, store};
use crate::utils::{
    BASIS_POINTS, CASINO_ADDRESS, CONTROLLER_ADDRESS, DEFAULT_MAX_BET, DEFAULT_MIN_BET, ETH_ADDRESS,
    ONE_ETH, OPERATOR_ADDRESS, PLAYER_ADDRESS, setup_crash, setup_erc20, setup_roulette,
    setup_safe_and_controller, whitelist_game_utils,
};

#[test]
fn test_constructor() {
    let (_, _) = setup_safe_and_controller();
    let (dispatcher, management_dispatcher) = setup_roulette();

    let game_id = dispatcher.get_current_game(PLAYER_ADDRESS());
    println!("game_id: {}", game_id);
    assert(game_id == 0, 'Wrong initial game id');

    assert(management_dispatcher.get_max_bet() == DEFAULT_MAX_BET, 'Wrong max bet');
    assert(management_dispatcher.get_min_bet() == DEFAULT_MIN_BET, 'Wrong min bet');
    assert(
        management_dispatcher.get_controller_address() == CONTROLLER_ADDRESS(),
        'Wrong controller address',
    );
    let game_state = dispatcher.get_game_state(game_id, PLAYER_ADDRESS());
    assert(game_state == GameState::Betting, 'Wrong initial game state');
}

#[test]
fn test_play_internal() {
    let (safe, controller) = setup_safe_and_controller();
    let (dispatcher, management_dispatcher) = setup_roulette();
    let (eth, eth_dispatcher) = setup_erc20();

    store(
        eth,
        map_entry_address(selector!("ERC20_balances"), array![safe.contract_address.into()].span()),
        array![ONE_ETH.into()].span(),
    );

    let initial_safe_balance = eth_dispatcher.balance_of(safe.contract_address);
    assert(initial_safe_balance == ONE_ETH.into(), 'Safe balance mismatch');

    let amount: u128 = 1000000000000000;
    let amount_u256: u256 = amount.into();
    let player = PLAYER_ADDRESS();
    let game_id = dispatcher.get_current_game(player);
    let bet1 = Bet {
        game_id,
        user_address: player,
        bet_type: 1,
        bet_value: 0,
        amount: amount_u256,
        split_bet: false,
        split_bet_value: [0, 0],
        corner_bet: false,
        corner_bet_value: [0, 0, 0, 0],
    };
    let bet2 = Bet {
        game_id,
        user_address: player,
        bet_type: 6,
        bet_value: 0,
        amount: amount_u256,
        split_bet: true,
        split_bet_value: [1, 2],
        corner_bet: false,
        corner_bet_value: [0, 0, 0, 0],
    };

    // let bet_array = array![bet1, bet2];
    let bet_array = array![bet1];

    store(
        eth,
        map_entry_address(selector!("ERC20_balances"), array![player.into()].span()),
        array![amount.into() * 2].span() // Higher balance than amount
    );
    let bal_player_before = eth_dispatcher.balance_of(player);
    assert(bal_player_before == (amount * 2).into(), 'Player balance mismatch');

    let amount_to_approve = amount_u256 * 2;
    start_cheat_caller_address(eth, player);
    eth_dispatcher.approve(dispatcher.contract_address, amount_to_approve);
    stop_cheat_caller_address(eth);

    start_cheat_caller_address(dispatcher.contract_address, player);
    dispatcher.play_game(bet_array);
    stop_cheat_caller_address(dispatcher.contract_address);

    let player_bet = dispatcher.get_total_player_bet_amount(player, game_id);
    assert(player_bet == amount_u256, 'Player bet mismatch');
}

#[test]
#[should_panic(expected: 'Invalid bet value')]
fn test_play_internal_wrong_value() {
    let (safe, controller) = setup_safe_and_controller();
    let (dispatcher, management_dispatcher) = setup_roulette();
    let (eth, eth_dispatcher) = setup_erc20();

    store(
        eth,
        map_entry_address(selector!("ERC20_balances"), array![safe.contract_address.into()].span()),
        array![ONE_ETH.into()].span(),
    );

    let initial_safe_balance = eth_dispatcher.balance_of(safe.contract_address);
    assert(initial_safe_balance == ONE_ETH.into(), 'Safe balance mismatch');

    let amount: u128 = 1000000000000000;
    let amount_u256: u256 = amount.into();
    let player = PLAYER_ADDRESS();
    let game_id = dispatcher.get_current_game(player);
    let bet1 = Bet {
        game_id,
        user_address: player,
        bet_type: 0,
        bet_value: 37,
        amount: amount_u256,
        split_bet: false,
        split_bet_value: [0, 0],
        corner_bet: false,
        corner_bet_value: [0, 0, 0, 0],
    };

    let bet_array = array![bet1];

    store(
        eth,
        map_entry_address(selector!("ERC20_balances"), array![player.into()].span()),
        array![amount.into() * 2].span() // Higher balance than amount
    );
    let bal_player_before = eth_dispatcher.balance_of(player);
    assert(bal_player_before == (amount * 2).into(), 'Player balance mismatch');

    let amount_to_approve = amount_u256 * 2;
    start_cheat_caller_address(eth, player);
    eth_dispatcher.approve(dispatcher.contract_address, amount_to_approve);
    stop_cheat_caller_address(eth);

    start_cheat_caller_address(dispatcher.contract_address, player);
    dispatcher.play_game(bet_array);
    stop_cheat_caller_address(dispatcher.contract_address);
}

#[test]
#[should_panic(expected: 'Invalid bet type')]
fn test_play_internal_wrong_type() {
    let (safe, controller) = setup_safe_and_controller();
    let (dispatcher, management_dispatcher) = setup_roulette();
    let (eth, eth_dispatcher) = setup_erc20();

    store(
        eth,
        map_entry_address(selector!("ERC20_balances"), array![safe.contract_address.into()].span()),
        array![ONE_ETH.into()].span(),
    );

    let initial_safe_balance = eth_dispatcher.balance_of(safe.contract_address);
    assert(initial_safe_balance == ONE_ETH.into(), 'Safe balance mismatch');

    let amount: u128 = 1000000000000000;
    let amount_u256: u256 = amount.into();
    let player = PLAYER_ADDRESS();
    let game_id = dispatcher.get_current_game(player);
    let bet1 = Bet {
        game_id,
        user_address: player,
        bet_type: 7,
        bet_value: 0,
        amount: amount_u256,
        split_bet: false,
        split_bet_value: [0, 0],
        corner_bet: false,
        corner_bet_value: [0, 0, 0, 0],
    };

    let bet_array = array![bet1];

    store(
        eth,
        map_entry_address(selector!("ERC20_balances"), array![player.into()].span()),
        array![amount.into() * 2].span() // Higher balance than amount
    );
    let bal_player_before = eth_dispatcher.balance_of(player);
    assert(bal_player_before == (amount * 2).into(), 'Player balance mismatch');

    let amount_to_approve = amount_u256 * 2;
    start_cheat_caller_address(eth, player);
    eth_dispatcher.approve(dispatcher.contract_address, amount_to_approve);
    stop_cheat_caller_address(eth);

    start_cheat_caller_address(dispatcher.contract_address, player);
    dispatcher.play_game(bet_array);
    stop_cheat_caller_address(dispatcher.contract_address);
}

#[test]
#[should_panic(expected: 'Invalid split bet value')]
fn test_play_internal_wrong_split_value() {
    let (safe, controller) = setup_safe_and_controller();
    let (dispatcher, management_dispatcher) = setup_roulette();
    let (eth, eth_dispatcher) = setup_erc20();

    store(
        eth,
        map_entry_address(selector!("ERC20_balances"), array![safe.contract_address.into()].span()),
        array![ONE_ETH.into()].span(),
    );

    let initial_safe_balance = eth_dispatcher.balance_of(safe.contract_address);
    assert(initial_safe_balance == ONE_ETH.into(), 'Safe balance mismatch');

    let amount: u128 = 1000000000000000;
    let amount_u256: u256 = amount.into();
    let player = PLAYER_ADDRESS();
    let game_id = dispatcher.get_current_game(player);
    let bet1 = Bet {
        game_id,
        user_address: player,
        bet_type: 6,
        bet_value: 0,
        amount: amount_u256,
        split_bet: true,
        split_bet_value: [37, 1],
        corner_bet: false,
        corner_bet_value: [0, 0, 0, 0],
    };

    let bet_array = array![bet1];

    store(
        eth,
        map_entry_address(selector!("ERC20_balances"), array![player.into()].span()),
        array![amount.into() * 2].span() // Higher balance than amount
    );
    let bal_player_before = eth_dispatcher.balance_of(player);
    assert(bal_player_before == (amount * 2).into(), 'Player balance mismatch');

    let amount_to_approve = amount_u256 * 2;
    start_cheat_caller_address(eth, player);
    eth_dispatcher.approve(dispatcher.contract_address, amount_to_approve);
    stop_cheat_caller_address(eth);

    start_cheat_caller_address(dispatcher.contract_address, player);
    dispatcher.play_game(bet_array);
    stop_cheat_caller_address(dispatcher.contract_address);
}

#[test]
#[should_panic(expected: 'Invalid split bet value')]
fn test_play_internal_wrong_split_value_2() {
    let (safe, controller) = setup_safe_and_controller();
    let (dispatcher, management_dispatcher) = setup_roulette();
    let (eth, eth_dispatcher) = setup_erc20();

    store(
        eth,
        map_entry_address(selector!("ERC20_balances"), array![safe.contract_address.into()].span()),
        array![ONE_ETH.into()].span(),
    );

    let initial_safe_balance = eth_dispatcher.balance_of(safe.contract_address);
    assert(initial_safe_balance == ONE_ETH.into(), 'Safe balance mismatch');

    let amount: u128 = 1000000000000000;
    let amount_u256: u256 = amount.into();
    let player = PLAYER_ADDRESS();
    let game_id = dispatcher.get_current_game(player);
    let bet1 = Bet {
        game_id,
        user_address: player,
        bet_type: 6,
        bet_value: 0,
        amount: amount_u256,
        split_bet: true,
        split_bet_value: [1, 37],
        corner_bet: false,
        corner_bet_value: [0, 0, 0, 0],
    };

    let bet_array = array![bet1];

    store(
        eth,
        map_entry_address(selector!("ERC20_balances"), array![player.into()].span()),
        array![amount.into() * 2].span() // Higher balance than amount
    );
    let bal_player_before = eth_dispatcher.balance_of(player);
    assert(bal_player_before == (amount * 2).into(), 'Player balance mismatch');

    let amount_to_approve = amount_u256 * 2;
    start_cheat_caller_address(eth, player);
    eth_dispatcher.approve(dispatcher.contract_address, amount_to_approve);
    stop_cheat_caller_address(eth);

    start_cheat_caller_address(dispatcher.contract_address, player);
    dispatcher.play_game(bet_array);
    stop_cheat_caller_address(dispatcher.contract_address);
}

#[test]
#[should_panic(expected: 'Duplicate numbers in split bet')]
fn test_play_internal_duplicate_split_value() {
    let (safe, controller) = setup_safe_and_controller();
    let (dispatcher, management_dispatcher) = setup_roulette();
    let (eth, eth_dispatcher) = setup_erc20();

    store(
        eth,
        map_entry_address(selector!("ERC20_balances"), array![safe.contract_address.into()].span()),
        array![ONE_ETH.into()].span(),
    );

    let initial_safe_balance = eth_dispatcher.balance_of(safe.contract_address);
    assert(initial_safe_balance == ONE_ETH.into(), 'Safe balance mismatch');

    let amount: u128 = 1000000000000000;
    let amount_u256: u256 = amount.into();
    let player = PLAYER_ADDRESS();
    let game_id = dispatcher.get_current_game(player);
    let bet1 = Bet {
        game_id,
        user_address: player,
        bet_type: 6,
        bet_value: 0,
        amount: amount_u256,
        split_bet: true,
        split_bet_value: [1, 1],
        corner_bet: false,
        corner_bet_value: [0, 0, 0, 0],
    };

    let bet_array = array![bet1];

    store(
        eth,
        map_entry_address(selector!("ERC20_balances"), array![player.into()].span()),
        array![amount.into() * 2].span() // Higher balance than amount
    );
    let bal_player_before = eth_dispatcher.balance_of(player);
    assert(bal_player_before == (amount * 2).into(), 'Player balance mismatch');

    let amount_to_approve = amount_u256 * 2;
    start_cheat_caller_address(eth, player);
    eth_dispatcher.approve(dispatcher.contract_address, amount_to_approve);
    stop_cheat_caller_address(eth);

    start_cheat_caller_address(dispatcher.contract_address, player);
    dispatcher.play_game(bet_array);
    stop_cheat_caller_address(dispatcher.contract_address);
}

#[test]
#[should_panic(expected: 'non adjacent numbers')]
fn test_play_internal_non_adjacent_numbers_split_bet() {
    let (safe, controller) = setup_safe_and_controller();
    let (dispatcher, management_dispatcher) = setup_roulette();
    let (eth, eth_dispatcher) = setup_erc20();

    store(
        eth,
        map_entry_address(selector!("ERC20_balances"), array![safe.contract_address.into()].span()),
        array![ONE_ETH.into()].span(),
    );

    let initial_safe_balance = eth_dispatcher.balance_of(safe.contract_address);
    assert(initial_safe_balance == ONE_ETH.into(), 'Safe balance mismatch');

    let amount: u128 = 1000000000000000;
    let amount_u256: u256 = amount.into();
    let player = PLAYER_ADDRESS();
    let game_id = dispatcher.get_current_game(player);
    let bet1 = Bet {
        game_id,
        user_address: player,
        bet_type: 6,
        bet_value: 0,
        amount: amount_u256,
        split_bet: true,
        split_bet_value: [1, 25],
        corner_bet: false,
        corner_bet_value: [0, 0, 0, 0],
    };

    let bet_array = array![bet1];

    store(
        eth,
        map_entry_address(selector!("ERC20_balances"), array![player.into()].span()),
        array![amount.into() * 2].span() // Higher balance than amount
    );
    let bal_player_before = eth_dispatcher.balance_of(player);
    assert(bal_player_before == (amount * 2).into(), 'Player balance mismatch');

    let amount_to_approve = amount_u256 * 2;
    start_cheat_caller_address(eth, player);
    eth_dispatcher.approve(dispatcher.contract_address, amount_to_approve);
    stop_cheat_caller_address(eth);

    start_cheat_caller_address(dispatcher.contract_address, player);
    dispatcher.play_game(bet_array);
    stop_cheat_caller_address(dispatcher.contract_address);
}

#[test]
#[should_panic(expected: 'Invalid corner bet value')]
fn test_play_internal_invalid_corner_value() {
    let (safe, controller) = setup_safe_and_controller();
    let (dispatcher, management_dispatcher) = setup_roulette();
    let (eth, eth_dispatcher) = setup_erc20();

    store(
        eth,
        map_entry_address(selector!("ERC20_balances"), array![safe.contract_address.into()].span()),
        array![ONE_ETH.into()].span(),
    );

    let initial_safe_balance = eth_dispatcher.balance_of(safe.contract_address);
    assert(initial_safe_balance == ONE_ETH.into(), 'Safe balance mismatch');

    let amount: u128 = 1000000000000000;
    let amount_u256: u256 = amount.into();
    let player = PLAYER_ADDRESS();
    let game_id = dispatcher.get_current_game(player);
    let bet1 = Bet {
        game_id,
        user_address: player,
        bet_type: 6,
        bet_value: 0,
        amount: amount_u256,
        split_bet: false,
        split_bet_value: [0, 0],
        corner_bet: true,
        corner_bet_value: [37, 2, 3, 4],
    };

    let bet_array = array![bet1];

    store(
        eth,
        map_entry_address(selector!("ERC20_balances"), array![player.into()].span()),
        array![amount.into() * 2].span() // Higher balance than amount
    );
    let bal_player_before = eth_dispatcher.balance_of(player);
    assert(bal_player_before == (amount * 2).into(), 'Player balance mismatch');

    let amount_to_approve = amount_u256 * 2;
    start_cheat_caller_address(eth, player);
    eth_dispatcher.approve(dispatcher.contract_address, amount_to_approve);
    stop_cheat_caller_address(eth);

    start_cheat_caller_address(dispatcher.contract_address, player);
    dispatcher.play_game(bet_array);
    stop_cheat_caller_address(dispatcher.contract_address);
}
#[test]
#[should_panic(expected: 'Invalid corner bet value')]
fn test_play_internal_invalid_corner_value_2() {
    let (safe, controller) = setup_safe_and_controller();
    let (dispatcher, management_dispatcher) = setup_roulette();
    let (eth, eth_dispatcher) = setup_erc20();

    store(
        eth,
        map_entry_address(selector!("ERC20_balances"), array![safe.contract_address.into()].span()),
        array![ONE_ETH.into()].span(),
    );

    let initial_safe_balance = eth_dispatcher.balance_of(safe.contract_address);
    assert(initial_safe_balance == ONE_ETH.into(), 'Safe balance mismatch');

    let amount: u128 = 1000000000000000;
    let amount_u256: u256 = amount.into();
    let player = PLAYER_ADDRESS();
    let game_id = dispatcher.get_current_game(player);
    let bet1 = Bet {
        game_id,
        user_address: player,
        bet_type: 6,
        bet_value: 0,
        amount: amount_u256,
        split_bet: false,
        split_bet_value: [0, 0],
        corner_bet: true,
        corner_bet_value: [1, 37, 3, 4],
    };

    let bet_array = array![bet1];

    store(
        eth,
        map_entry_address(selector!("ERC20_balances"), array![player.into()].span()),
        array![amount.into() * 2].span() // Higher balance than amount
    );
    let bal_player_before = eth_dispatcher.balance_of(player);
    assert(bal_player_before == (amount * 2).into(), 'Player balance mismatch');

    let amount_to_approve = amount_u256 * 2;
    start_cheat_caller_address(eth, player);
    eth_dispatcher.approve(dispatcher.contract_address, amount_to_approve);
    stop_cheat_caller_address(eth);

    start_cheat_caller_address(dispatcher.contract_address, player);
    dispatcher.play_game(bet_array);
    stop_cheat_caller_address(dispatcher.contract_address);
}

#[test]
#[should_panic(expected: 'Invalid corner bet value')]
fn test_play_internal_invalid_corner_value_3() {
    let (safe, controller) = setup_safe_and_controller();
    let (dispatcher, management_dispatcher) = setup_roulette();
    let (eth, eth_dispatcher) = setup_erc20();

    store(
        eth,
        map_entry_address(selector!("ERC20_balances"), array![safe.contract_address.into()].span()),
        array![ONE_ETH.into()].span(),
    );

    let initial_safe_balance = eth_dispatcher.balance_of(safe.contract_address);
    assert(initial_safe_balance == ONE_ETH.into(), 'Safe balance mismatch');

    let amount: u128 = 1000000000000000;
    let amount_u256: u256 = amount.into();
    let player = PLAYER_ADDRESS();
    let game_id = dispatcher.get_current_game(player);
    let bet1 = Bet {
        game_id,
        user_address: player,
        bet_type: 6,
        bet_value: 0,
        amount: amount_u256,
        split_bet: false,
        split_bet_value: [0, 0],
        corner_bet: true,
        corner_bet_value: [1, 2, 37, 4],
    };

    let bet_array = array![bet1];

    store(
        eth,
        map_entry_address(selector!("ERC20_balances"), array![player.into()].span()),
        array![amount.into() * 2].span() // Higher balance than amount
    );
    let bal_player_before = eth_dispatcher.balance_of(player);
    assert(bal_player_before == (amount * 2).into(), 'Player balance mismatch');

    let amount_to_approve = amount_u256 * 2;
    start_cheat_caller_address(eth, player);
    eth_dispatcher.approve(dispatcher.contract_address, amount_to_approve);
    stop_cheat_caller_address(eth);

    start_cheat_caller_address(dispatcher.contract_address, player);
    dispatcher.play_game(bet_array);
    stop_cheat_caller_address(dispatcher.contract_address);
}

#[test]
#[should_panic(expected: 'Invalid corner bet value')]
fn test_play_internal_invalid_corner_value_4() {
    let (safe, controller) = setup_safe_and_controller();
    let (dispatcher, management_dispatcher) = setup_roulette();
    let (eth, eth_dispatcher) = setup_erc20();

    store(
        eth,
        map_entry_address(selector!("ERC20_balances"), array![safe.contract_address.into()].span()),
        array![ONE_ETH.into()].span(),
    );

    let initial_safe_balance = eth_dispatcher.balance_of(safe.contract_address);
    assert(initial_safe_balance == ONE_ETH.into(), 'Safe balance mismatch');

    let amount: u128 = 1000000000000000;
    let amount_u256: u256 = amount.into();
    let player = PLAYER_ADDRESS();
    let game_id = dispatcher.get_current_game(player);
    let bet1 = Bet {
        game_id,
        user_address: player,
        bet_type: 6,
        bet_value: 0,
        amount: amount_u256,
        split_bet: false,
        split_bet_value: [0, 0],
        corner_bet: true,
        corner_bet_value: [1, 2, 3, 37],
    };

    let bet_array = array![bet1];

    store(
        eth,
        map_entry_address(selector!("ERC20_balances"), array![player.into()].span()),
        array![amount.into() * 2].span() // Higher balance than amount
    );
    let bal_player_before = eth_dispatcher.balance_of(player);
    assert(bal_player_before == (amount * 2).into(), 'Player balance mismatch');

    let amount_to_approve = amount_u256 * 2;
    start_cheat_caller_address(eth, player);
    eth_dispatcher.approve(dispatcher.contract_address, amount_to_approve);
    stop_cheat_caller_address(eth);

    start_cheat_caller_address(dispatcher.contract_address, player);
    dispatcher.play_game(bet_array);
    stop_cheat_caller_address(dispatcher.contract_address);
}

#[test]
#[should_panic(expected: 'corner not possible')]
fn test_play_internal_corner_not_possible() {
    let (safe, controller) = setup_safe_and_controller();
    let (dispatcher, management_dispatcher) = setup_roulette();
    let (eth, eth_dispatcher) = setup_erc20();

    store(
        eth,
        map_entry_address(selector!("ERC20_balances"), array![safe.contract_address.into()].span()),
        array![ONE_ETH.into()].span(),
    );

    let initial_safe_balance = eth_dispatcher.balance_of(safe.contract_address);
    assert(initial_safe_balance == ONE_ETH.into(), 'Safe balance mismatch');

    let amount: u128 = 1000000000000000;
    let amount_u256: u256 = amount.into();
    let player = PLAYER_ADDRESS();
    let game_id = dispatcher.get_current_game(player);
    let bet1 = Bet {
        game_id,
        user_address: player,
        bet_type: 6,
        bet_value: 0,
        amount: amount_u256,
        split_bet: false,
        split_bet_value: [0, 0],
        corner_bet: true,
        corner_bet_value: [3, 6, 4, 7],
    };

    let bet_array = array![bet1];

    store(
        eth,
        map_entry_address(selector!("ERC20_balances"), array![player.into()].span()),
        array![amount.into() * 2].span() // Higher balance than amount
    );
    let bal_player_before = eth_dispatcher.balance_of(player);
    assert(bal_player_before == (amount * 2).into(), 'Player balance mismatch');

    let amount_to_approve = amount_u256 * 2;
    start_cheat_caller_address(eth, player);
    eth_dispatcher.approve(dispatcher.contract_address, amount_to_approve);
    stop_cheat_caller_address(eth);

    start_cheat_caller_address(dispatcher.contract_address, player);
    dispatcher.play_game(bet_array);
    stop_cheat_caller_address(dispatcher.contract_address);
}

#[test]
#[should_panic(expected: 'invalid corner numbers')]
fn test_play_internal_invalid_corner_numbers() {
    let (safe, controller) = setup_safe_and_controller();
    let (dispatcher, management_dispatcher) = setup_roulette();
    let (eth, eth_dispatcher) = setup_erc20();

    store(
        eth,
        map_entry_address(selector!("ERC20_balances"), array![safe.contract_address.into()].span()),
        array![ONE_ETH.into()].span(),
    );

    let initial_safe_balance = eth_dispatcher.balance_of(safe.contract_address);
    assert(initial_safe_balance == ONE_ETH.into(), 'Safe balance mismatch');

    let amount: u128 = 1000000000000000;
    let amount_u256: u256 = amount.into();
    let player = PLAYER_ADDRESS();
    let game_id = dispatcher.get_current_game(player);
    let bet1 = Bet {
        game_id,
        user_address: player,
        bet_type: 6,
        bet_value: 0,
        amount: amount_u256,
        split_bet: false,
        split_bet_value: [0, 0],
        corner_bet: true,
        corner_bet_value: [1, 2, 3, 4],
    };

    let bet_array = array![bet1];

    store(
        eth,
        map_entry_address(selector!("ERC20_balances"), array![player.into()].span()),
        array![amount.into() * 2].span() // Higher balance than amount
    );
    let bal_player_before = eth_dispatcher.balance_of(player);
    assert(bal_player_before == (amount * 2).into(), 'Player balance mismatch');

    let amount_to_approve = amount_u256 * 2;
    start_cheat_caller_address(eth, player);
    eth_dispatcher.approve(dispatcher.contract_address, amount_to_approve);
    stop_cheat_caller_address(eth);

    start_cheat_caller_address(dispatcher.contract_address, player);
    dispatcher.play_game(bet_array);
    stop_cheat_caller_address(dispatcher.contract_address);
}
