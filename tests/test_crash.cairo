use core::traits::Into;

// use core::poseidon::PoseidonTrait;
// use core::hash::{HashStateTrait};

use openzeppelin_token::erc20::interface::{ERC20ABIDispatcher, ERC20ABIDispatcherTrait};
use raindinner_contracts::controller::controller::{
    IControllerDispatcher, IControllerDispatcherTrait, IControllerManagementDispatcher,
    IControllerManagementDispatcherTrait,
};
use raindinner_contracts::games::crashgame::crashgame::{
    ICrashGameDispatcherTrait, IManagementDispatcherTrait,
};
use raindinner_contracts::games::crashgame::types::GameState;
use raindinner_contracts::safe::safe::ISafeDispatcherTrait;
use snforge_std::{map_entry_address, start_cheat_caller_address, stop_cheat_caller_address, store};
use crate::utils::{
    BASIS_POINTS, CASINO_ADDRESS, CONTROLLER_ADDRESS, DEFAULT_MAX_BET, DEFAULT_MIN_BET, ETH_ADDRESS,
    ONE_ETH, OPERATOR_ADDRESS, PLAYER_ADDRESS, setup_crash, setup_erc20, setup_safe_and_controller,
    setup_start_betting, whitelist_game_utils,
};

#[test]
fn test_constructor() {
    let (_, _) = setup_safe_and_controller();
    let (dispatcher, management_dispatcher) = setup_crash();

    let game_id = dispatcher.get_current_game();
    assert(game_id == 0, 'Wrong initial game id');

    assert(management_dispatcher.get_max_bet() == DEFAULT_MAX_BET, 'Wrong max bet');
    assert(management_dispatcher.get_min_bet() == DEFAULT_MIN_BET, 'Wrong min bet');
    assert(
        management_dispatcher.get_controller_address() == CONTROLLER_ADDRESS(),
        'Wrong controller address',
    );
    let game_state = dispatcher.get_game_state(game_id);
    assert(game_state == GameState::Transition, 'Wrong initial game state');
}

#[test]
fn test_commit_seed() {
    let (_, _) = setup_safe_and_controller();
    let (dispatcher, _) = setup_crash();
    let seed_hash = 0x123456789;

    start_cheat_caller_address(dispatcher.contract_address, OPERATOR_ADDRESS());
    dispatcher.commit_seed(seed_hash);
    stop_cheat_caller_address(dispatcher.contract_address);

    let game_id = dispatcher.get_current_game();
    assert(dispatcher.get_seed_hash(game_id) == seed_hash, 'Seed hash mismatch');
}

#[test]
fn test_start_betting() {
    let (_, _) = setup_safe_and_controller();
    let (dispatcher, _) = setup_crash();
    let seed_hash = 0x123456789;

    start_cheat_caller_address(dispatcher.contract_address, OPERATOR_ADDRESS());
    dispatcher.commit_seed(seed_hash);
    stop_cheat_caller_address(dispatcher.contract_address);

    start_cheat_caller_address(dispatcher.contract_address, OPERATOR_ADDRESS());
    dispatcher.start_betting();
    stop_cheat_caller_address(dispatcher.contract_address);

    let game_id = dispatcher.get_current_game();
    assert(dispatcher.get_game_state(game_id) == GameState::Betting, 'Game state mismatch');
}

#[test]
#[should_panic(expected: 'Game not in CommittedSeed state')]
fn test_start_betting_fail_not_committed() {
    let (_, _) = setup_safe_and_controller();
    let (dispatcher, _) = setup_crash();

    start_cheat_caller_address(dispatcher.contract_address, OPERATOR_ADDRESS());
    dispatcher.start_betting();
    stop_cheat_caller_address(dispatcher.contract_address);

    let game_id = dispatcher.get_current_game();
    assert(dispatcher.get_game_state(game_id) == GameState::Betting, 'Game state mismatch');
}

#[test]
fn test_start_game() {
    let (_, _) = setup_safe_and_controller();
    let (dispatcher, _, _, _) = setup_start_betting();

    start_cheat_caller_address(dispatcher.contract_address, OPERATOR_ADDRESS());
    dispatcher.start_game();
    stop_cheat_caller_address(dispatcher.contract_address);
    let game_id = dispatcher.get_current_game();

    let game_state = dispatcher.get_game_state(game_id);
    assert(game_state == GameState::Playing, 'Wrong game state');
}

#[test]
fn test_end_game() {
    let (_, _) = setup_safe_and_controller();
    let (dispatcher, _, _, secret_seed) = setup_start_betting();

    start_cheat_caller_address(dispatcher.contract_address, OPERATOR_ADDRESS());
    dispatcher.start_game();
    stop_cheat_caller_address(dispatcher.contract_address);

    start_cheat_caller_address(dispatcher.contract_address, OPERATOR_ADDRESS());
    dispatcher.end_game(secret_seed);
    stop_cheat_caller_address(dispatcher.contract_address);

    let game_state = dispatcher.get_game_state(0);
    assert(game_state == GameState::Crashed, 'Wrong game state');

    let game_id = dispatcher.get_current_game();
    assert(game_id == 1, 'Wrong game id');
}

#[test]
#[should_panic(expected: 'Invalid seed')]
fn test_end_game_invalid_seed() {
    let (_, _) = setup_safe_and_controller();
    let (dispatcher, _, _, _) = setup_start_betting();

    start_cheat_caller_address(dispatcher.contract_address, OPERATOR_ADDRESS());
    dispatcher.start_game();
    stop_cheat_caller_address(dispatcher.contract_address);

    start_cheat_caller_address(dispatcher.contract_address, OPERATOR_ADDRESS());
    dispatcher.end_game(123456789); // Wrong seed
    stop_cheat_caller_address(dispatcher.contract_address);
}


#[test]
fn test_place_bet() {
    // Setup initial game state
    let (safe, controller) = setup_safe_and_controller();

    let (dispatcher, _, _, _) = setup_start_betting();
    let (eth, eth_dispatcher) = setup_erc20();
    store(
        eth,
        map_entry_address(selector!("ERC20_balances"), array![safe.contract_address.into()].span()),
        array![ONE_ETH.into()].span(),
    );

    let initial_safe_balance = eth_dispatcher.balance_of(safe.contract_address);
    assert(initial_safe_balance == ONE_ETH.into(), 'Safe balance mismatch');

    let game_id = dispatcher.get_current_game();
    let amount: u128 = 1000000000000000;
    let amount_u256: u256 = amount.into();
    // Setup player address
    let player = PLAYER_ADDRESS();
    // Setup ETH token and give balance to player
    store(
        eth,
        map_entry_address(selector!("ERC20_balances"), array![player.into()].span()),
        array![amount.into() * 2].span() // Higher balance than amount
    );
    let bal_player_before = eth_dispatcher.balance_of(player);
    assert(bal_player_before == (amount * 2).into(), 'Player balance mismatch');

    // Verify game state is still betting
    let game_state = dispatcher.get_game_state(game_id);
    assert(game_state == GameState::Betting, 'Game state not betting');

    start_cheat_caller_address(eth, player);
    eth_dispatcher.approve(dispatcher.contract_address, amount.into());
    stop_cheat_caller_address(eth);
    // Place bet as player
    start_cheat_caller_address(dispatcher.contract_address, player);
    dispatcher.place_bet(amount_u256);
    stop_cheat_caller_address(dispatcher.contract_address);
    // Verify player bet amount
    let player_bet = dispatcher.get_player_bet(player, game_id);
    assert(player_bet == amount_u256, 'Player bet mismatch');

    let bal_player_after = eth_dispatcher.balance_of(player);
    assert(bal_player_after == amount_u256, 'Player balance mismatch');

    let bal_safe = safe.get_total_liquidity();
    let controller_management = IControllerManagementDispatcher {
        contract_address: controller.contract_address,
    };
    let casino_fee = (amount.into() * controller_management.get_casino_fee()) / BASIS_POINTS;
    assert(
        bal_safe == initial_safe_balance + (amount_u256 - casino_fee).into(),
        'Contract balance mismatch',
    );

    // Check casino fee
    let bal_casino = eth_dispatcher.balance_of(CASINO_ADDRESS());
    assert(bal_casino == casino_fee, 'Casino fee mismatch');

    start_cheat_caller_address(eth_dispatcher.contract_address, player);
    eth_dispatcher.approve(dispatcher.contract_address, amount.into());
    stop_cheat_caller_address(eth_dispatcher.contract_address);

    // Place bet as player
    start_cheat_caller_address(dispatcher.contract_address, player);
    dispatcher.place_bet(amount_u256);
    stop_cheat_caller_address(dispatcher.contract_address);

    let player_bet = dispatcher.get_player_bet(player, game_id);
    assert(player_bet == amount_u256 * 2, 'Player bet mismatch');
}
#[test]
#[should_panic(expected: 'Bet amount exceeds max bet')]
fn test_place_bet_fail_max_bet() {
    // Setup initial game state
    let (safe, controller) = setup_safe_and_controller();

    let (dispatcher, _, _, _) = setup_start_betting();
    let (eth, eth_dispatcher) = setup_erc20();
    store(
        eth,
        map_entry_address(selector!("ERC20_balances"), array![safe.contract_address.into()].span()),
        array![ONE_ETH.into()].span(),
    );

    let initial_safe_balance = eth_dispatcher.balance_of(safe.contract_address);
    assert(initial_safe_balance == ONE_ETH.into(), 'Safe balance mismatch');

    let game_id = dispatcher.get_current_game();
    let amount: u128 = DEFAULT_MAX_BET.try_into().unwrap() + 1;
    let amount_u256: u256 = amount.into();
    // Setup player address
    let player = PLAYER_ADDRESS();
    // Setup ETH token and give balance to player
    store(
        eth,
        map_entry_address(selector!("ERC20_balances"), array![player.into()].span()),
        array![amount.into() * 2].span() // Higher balance than amount
    );
    let bal_player_before = eth_dispatcher.balance_of(player);
    assert(bal_player_before == (amount * 2).into(), 'Player balance mismatch');

    // Verify game state is still betting
    let game_state = dispatcher.get_game_state(game_id);
    assert(game_state == GameState::Betting, 'Game state not betting');

    start_cheat_caller_address(eth, player);
    eth_dispatcher.approve(dispatcher.contract_address, amount.into());
    stop_cheat_caller_address(eth);
    // Place bet as player
    start_cheat_caller_address(dispatcher.contract_address, player);
    dispatcher.place_bet(amount_u256);
    stop_cheat_caller_address(dispatcher.contract_address);
}

#[test]
#[should_panic(expected: 'Amount below minimum bet')]
fn test_place_bet_fail_min_bet() {
    // Setup initial game state
    let (safe, controller) = setup_safe_and_controller();

    let (dispatcher, _, _, _) = setup_start_betting();
    let (eth, eth_dispatcher) = setup_erc20();
    store(
        eth,
        map_entry_address(selector!("ERC20_balances"), array![safe.contract_address.into()].span()),
        array![ONE_ETH.into()].span(),
    );

    let initial_safe_balance = eth_dispatcher.balance_of(safe.contract_address);
    assert(initial_safe_balance == ONE_ETH.into(), 'Safe balance mismatch');

    let game_id = dispatcher.get_current_game();
    let amount: u128 = DEFAULT_MIN_BET.try_into().unwrap() - 1;
    let amount_u256: u256 = amount.into();
    // Setup player address
    let player = PLAYER_ADDRESS();
    // Setup ETH token and give balance to player
    store(
        eth,
        map_entry_address(selector!("ERC20_balances"), array![player.into()].span()),
        array![amount.into() * 2].span() // Higher balance than amount
    );
    let bal_player_before = eth_dispatcher.balance_of(player);
    assert(bal_player_before == (amount * 2).into(), 'Player balance mismatch');

    // Verify game state is still betting
    let game_state = dispatcher.get_game_state(game_id);
    assert(game_state == GameState::Betting, 'Game state not betting');

    start_cheat_caller_address(eth, player);
    eth_dispatcher.approve(dispatcher.contract_address, amount.into());
    stop_cheat_caller_address(eth);
    // Place bet as player
    start_cheat_caller_address(dispatcher.contract_address, player);
    dispatcher.place_bet(amount_u256);
    stop_cheat_caller_address(dispatcher.contract_address);
}

#[test]
fn test_cashout() {
    // SETUP CONTRACTS
    let (safe, controller) = setup_safe_and_controller();
    let (dispatcher, _, _, secret_seed) = setup_start_betting();
    let (eth, eth_dispatcher) = setup_erc20();
    // SAFE BALANCE
    store(
        eth,
        map_entry_address(selector!("ERC20_balances"), array![safe.contract_address.into()].span()),
        array![ONE_ETH.into()].span(),
    );

    let initial_safe_balance = eth_dispatcher.balance_of(safe.contract_address);
    assert(initial_safe_balance == ONE_ETH.into(), 'Safe balance mismatch');

    let game_id = dispatcher.get_current_game();
    let amount: u128 = DEFAULT_MAX_BET.try_into().unwrap();
    let amount_u256: u256 = amount.into();
    let player = PLAYER_ADDRESS();

    // PLAYER BALANCE
    store(
        eth,
        map_entry_address(selector!("ERC20_balances"), array![player.into()].span()),
        array![amount.into() * 2].span() // Higher balance than amount
    );
    let bal_player_before = eth_dispatcher.balance_of(player);
    assert(bal_player_before == (amount * 2).into(), 'Player balance mismatch');

    // Verify game state is still betting
    let game_state = dispatcher.get_game_state(game_id);
    assert(game_state == GameState::Betting, 'Game state not betting');

    start_cheat_caller_address(eth, player);
    eth_dispatcher.approve(dispatcher.contract_address, amount.into());
    stop_cheat_caller_address(eth);
    // Place bet as player
    start_cheat_caller_address(dispatcher.contract_address, player);
    dispatcher.place_bet(amount_u256);
    stop_cheat_caller_address(dispatcher.contract_address);

    start_cheat_caller_address(dispatcher.contract_address, OPERATOR_ADDRESS());
    dispatcher.start_game();
    stop_cheat_caller_address(dispatcher.contract_address);

    start_cheat_caller_address(dispatcher.contract_address, OPERATOR_ADDRESS());
    dispatcher.end_game(secret_seed);
    stop_cheat_caller_address(dispatcher.contract_address);

    let multiplier = 11000_u256; // 1.1x
    start_cheat_caller_address(dispatcher.contract_address, OPERATOR_ADDRESS());
    dispatcher.process_cashout(game_id, player, multiplier);
    stop_cheat_caller_address(dispatcher.contract_address);
    let bal_player_after = eth_dispatcher.balance_of(player);
    assert(
        bal_player_after == amount_u256 + (amount_u256 * multiplier / BASIS_POINTS),
        'Player balance
        mismatch',
    );

    let bal_safe = eth_dispatcher.balance_of(safe.contract_address);
    let controller_management = IControllerManagementDispatcher {
        contract_address: controller.contract_address,
    };
    let casino_fee = (amount_u256 * controller_management.get_casino_fee()) / BASIS_POINTS;
    assert(
        bal_safe == (ONE_ETH.into()
            - (amount_u256 * multiplier / 10000 - amount_u256)
            - casino_fee),
        'Contract balance mismatch',
    );
    let bal_casino = eth_dispatcher.balance_of(CASINO_ADDRESS());
    assert(bal_casino == casino_fee, 'Casino fee mismatch');
}
#[test]
#[should_panic(expected: 'Caller is not the owner')]
fn test_cashout_fail_not_owner() {
    // SETUP CONTRACTS
    let (safe, _) = setup_safe_and_controller();
    let (dispatcher, _, _, secret_seed) = setup_start_betting();
    let (eth, eth_dispatcher) = setup_erc20();
    // SAFE BALANCE
    store(
        eth,
        map_entry_address(selector!("ERC20_balances"), array![safe.contract_address.into()].span()),
        array![ONE_ETH.into()].span(),
    );

    let initial_safe_balance = eth_dispatcher.balance_of(safe.contract_address);
    assert(initial_safe_balance == ONE_ETH.into(), 'Safe balance mismatch');

    let game_id = dispatcher.get_current_game();
    let amount: u128 = DEFAULT_MAX_BET.try_into().unwrap();
    let amount_u256: u256 = amount.into();
    let player = PLAYER_ADDRESS();

    // PLAYER BALANCE
    store(
        eth,
        map_entry_address(selector!("ERC20_balances"), array![player.into()].span()),
        array![amount.into() * 2].span() // Higher balance than amount
    );
    let bal_player_before = eth_dispatcher.balance_of(player);
    assert(bal_player_before == (amount * 2).into(), 'Player balance mismatch');

    // Verify game state is still betting
    let game_state = dispatcher.get_game_state(game_id);
    assert(game_state == GameState::Betting, 'Game state not betting');

    start_cheat_caller_address(eth, player);
    eth_dispatcher.approve(dispatcher.contract_address, amount.into());
    stop_cheat_caller_address(eth);
    // Place bet as player
    start_cheat_caller_address(dispatcher.contract_address, player);
    dispatcher.place_bet(amount_u256);
    stop_cheat_caller_address(dispatcher.contract_address);

    start_cheat_caller_address(dispatcher.contract_address, OPERATOR_ADDRESS());
    dispatcher.start_game();
    stop_cheat_caller_address(dispatcher.contract_address);

    start_cheat_caller_address(dispatcher.contract_address, OPERATOR_ADDRESS());
    dispatcher.end_game(secret_seed);
    stop_cheat_caller_address(dispatcher.contract_address);

    let multiplier = 11000_u256; // 1.1x
    start_cheat_caller_address(dispatcher.contract_address, player);
    dispatcher.process_cashout(game_id, player, multiplier);
    stop_cheat_caller_address(dispatcher.contract_address);
}

#[test]
#[should_panic(expected: 'Already processed')]
fn test_cashout_fail_already_processed() {
    // SETUP CONTRACTS
    let (safe, controller) = setup_safe_and_controller();
    let (dispatcher, _, _, secret_seed) = setup_start_betting();
    let (eth, eth_dispatcher) = setup_erc20();
    // SAFE BALANCE
    store(
        eth,
        map_entry_address(selector!("ERC20_balances"), array![safe.contract_address.into()].span()),
        array![ONE_ETH.into()].span(),
    );

    let initial_safe_balance = eth_dispatcher.balance_of(safe.contract_address);
    assert(initial_safe_balance == ONE_ETH.into(), 'Safe balance mismatch');

    let game_id = dispatcher.get_current_game();
    let amount: u128 = DEFAULT_MAX_BET.try_into().unwrap();
    let amount_u256: u256 = amount.into();
    let player = PLAYER_ADDRESS();

    // PLAYER BALANCE
    store(
        eth,
        map_entry_address(selector!("ERC20_balances"), array![player.into()].span()),
        array![amount.into() * 2].span() // Higher balance than amount
    );
    let bal_player_before = eth_dispatcher.balance_of(player);
    assert(bal_player_before == (amount * 2).into(), 'Player balance mismatch');

    // Verify game state is still betting
    let game_state = dispatcher.get_game_state(game_id);
    assert(game_state == GameState::Betting, 'Game state not betting');

    start_cheat_caller_address(eth, player);
    eth_dispatcher.approve(dispatcher.contract_address, amount.into());
    stop_cheat_caller_address(eth);
    // Place bet as player
    start_cheat_caller_address(dispatcher.contract_address, player);
    dispatcher.place_bet(amount_u256);
    stop_cheat_caller_address(dispatcher.contract_address);

    start_cheat_caller_address(dispatcher.contract_address, OPERATOR_ADDRESS());
    dispatcher.start_game();
    stop_cheat_caller_address(dispatcher.contract_address);

    start_cheat_caller_address(dispatcher.contract_address, OPERATOR_ADDRESS());
    dispatcher.end_game(secret_seed);
    stop_cheat_caller_address(dispatcher.contract_address);

    let multiplier = 11000_u256; // 1.1x
    start_cheat_caller_address(dispatcher.contract_address, OPERATOR_ADDRESS());
    dispatcher.process_cashout(game_id, player, multiplier);
    stop_cheat_caller_address(dispatcher.contract_address);

    start_cheat_caller_address(dispatcher.contract_address, OPERATOR_ADDRESS());
    dispatcher.process_cashout(game_id, player, multiplier);
    stop_cheat_caller_address(dispatcher.contract_address);
}

