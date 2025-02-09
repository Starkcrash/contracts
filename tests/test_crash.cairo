use core::traits::Into;

use snforge_std::{start_cheat_caller_address, stop_cheat_caller_address, store, map_entry_address};

use crash_contracts::crashgame::crashgame::{ICrashGameDispatcherTrait, IManagementDispatcherTrait};
use crash_contracts::types::GameState;

// use core::poseidon::PoseidonTrait;
// use core::hash::{HashStateTrait};

use openzeppelin_token::erc20::interface::{ERC20ABIDispatcher, ERC20ABIDispatcherTrait};

use crate::utils::{
    setup, setup_start_betting, ETH_ADDRESS, OPERATOR_ADDRESS, CASINO_ADDRESS, PLAYER_ADDRESS,
    ONE_ETH, BASIS_POINTS,
};

#[test]
fn test_constructor() {
    let (dispatcher, management_dispatcher) = setup();

    let game_id = dispatcher.get_current_game();
    assert(game_id == 0, 'Wrong initial game id');

    let game_state = dispatcher.get_game_state(game_id);
    assert(game_state == GameState::Transition, 'Wrong initial game state');

    assert(management_dispatcher.get_max_bet() == 1_000_000_000_000_000_0, 'Wrong max bet');
    assert(management_dispatcher.get_casino_fee() == 0, 'Wrong casino fee');
}


#[test]
fn test_commit_seed() {
    let (dispatcher, _) = setup();
    let seed_hash = 0x123456789;

    start_cheat_caller_address(dispatcher.contract_address, OPERATOR_ADDRESS());
    dispatcher.commit_seed(seed_hash);
    stop_cheat_caller_address(dispatcher.contract_address);

    let game_id = dispatcher.get_current_game();
    assert(dispatcher.get_seed_hash(game_id) == seed_hash, 'Seed hash mismatch');
}

#[test]
fn test_start_betting() {
    let (dispatcher, _) = setup();
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
    let (dispatcher, _) = setup();

    start_cheat_caller_address(dispatcher.contract_address, OPERATOR_ADDRESS());
    dispatcher.start_betting();
    stop_cheat_caller_address(dispatcher.contract_address);

    let game_id = dispatcher.get_current_game();
    assert(dispatcher.get_game_state(game_id) == GameState::Betting, 'Game state mismatch');
}


#[test]
fn test_start_game() {
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
#[fork(url: "https://starknet-sepolia.public.blastapi.io/rpc/v0_7", block_tag: latest)]
fn test_place_bet() {
    // Setup initial game state
    let (dispatcher, management, _, _) = setup_start_betting();
    let game_id = dispatcher.get_current_game();
    let amount: u128 = 1000000000000000;
    let amount_u256: u256 = amount.into();
    // Setup player address
    let player = PLAYER_ADDRESS();
    // Setup ETH token and give balance to player using cheatcode
    let eth = ERC20ABIDispatcher { contract_address: ETH_ADDRESS() };
    store(
        eth.contract_address,
        map_entry_address(
            selector!("ERC20_balances"), // Providing variable name
            array![player.into()].span() // Providing mapping key
        ),
        array![amount.into() * 2].span(),
    );
    let bal_player_before = eth.balance_of(player);
    assert(bal_player_before == (amount * 2).into(), 'Player balance mismatch');

    // Verify game state is still betting
    let game_state = dispatcher.get_game_state(game_id);
    assert(game_state == GameState::Betting, 'Game state not betting');

    start_cheat_caller_address(eth.contract_address, player);
    eth.approve(dispatcher.contract_address, amount.into());
    stop_cheat_caller_address(eth.contract_address);

    // Place bet as player
    start_cheat_caller_address(dispatcher.contract_address, player);
    dispatcher.place_bet(game_id, amount_u256);
    stop_cheat_caller_address(dispatcher.contract_address);

    // Verify player bet amount
    let player_bet = dispatcher.get_player_bet(player, game_id);
    assert(player_bet == amount_u256, 'Player bet mismatch');

    let bal_player_after = eth.balance_of(player);
    assert(bal_player_after == amount_u256, 'Player balance mismatch');

    let bal_contract = eth.balance_of(dispatcher.contract_address);
    assert(
        bal_contract == (amount_u256 - amount_u256 * management.get_casino_fee() / BASIS_POINTS)
            .into(),
        'Contract balance mismatch',
    );

    // Check casino fee
    let bal_casino = eth.balance_of(CASINO_ADDRESS());
    assert(
        bal_casino == (amount_u256 * management.get_casino_fee() / BASIS_POINTS).into(),
        'Casino fee mismatch',
    );

    start_cheat_caller_address(eth.contract_address, player);
    eth.approve(dispatcher.contract_address, amount.into());
    stop_cheat_caller_address(eth.contract_address);

    // Place bet as player
    start_cheat_caller_address(dispatcher.contract_address, player);
    dispatcher.place_bet(game_id, amount_u256);
    stop_cheat_caller_address(dispatcher.contract_address);

    let player_bet = dispatcher.get_player_bet(player, game_id);
    assert(player_bet == amount_u256 * 2, 'Player bet mismatch');
}

#[test]
#[fork(url: "https://starknet-sepolia.public.blastapi.io/rpc/v0_7", block_tag: latest)]
#[should_panic(expected: 'Bet amount exceeds max bet')]
fn test_place_bet_fail_max_bet() {
    // Setup initial game state
    let (dispatcher, _, _, _) = setup_start_betting();
    let game_id = dispatcher.get_current_game();
    let amount: u128 = 1_000_000_000_000_000_000;
    let amount_u256: u256 = amount.into();
    // Setup player address
    let player = PLAYER_ADDRESS();
    // Setup ETH token and give balance to player using cheatcode
    let eth = ERC20ABIDispatcher { contract_address: ETH_ADDRESS() };
    store(
        eth.contract_address,
        map_entry_address(
            selector!("ERC20_balances"), // Providing variable name
            array![player.into()].span() // Providing mapping key
        ),
        array![amount.into() * 2].span(),
    );
    let bal_player_before = eth.balance_of(player);
    assert(bal_player_before == (amount * 2).into(), 'Player balance mismatch');

    // Verify game state is still betting
    let game_state = dispatcher.get_game_state(game_id);
    assert(game_state == GameState::Betting, 'Game state not betting');

    start_cheat_caller_address(eth.contract_address, player);
    eth.approve(dispatcher.contract_address, amount.into());
    stop_cheat_caller_address(eth.contract_address);

    // Place bet as player
    start_cheat_caller_address(dispatcher.contract_address, player);
    dispatcher.place_bet(game_id, amount_u256);
    stop_cheat_caller_address(dispatcher.contract_address);
}

#[test]
#[fork(url: "https://starknet-sepolia.public.blastapi.io/rpc/v0_7", block_tag: latest)]
fn test_cashout() {
    // Setup initial game state
    let (dispatcher, management, _, secret_seed) = setup_start_betting();
    let game_id = dispatcher.get_current_game();
    let amount: u128 = 1000000000000000;
    let amount_u256: u256 = amount.into();

    // Setup player address
    let player = PLAYER_ADDRESS();
    // Setup ETH token and give balance to player using cheatcode
    let eth = ERC20ABIDispatcher { contract_address: ETH_ADDRESS() };
    store(
        eth.contract_address,
        map_entry_address(
            selector!("ERC20_balances"), array![player.into()].span() // Providing mapping key
        ),
        array![amount.into()].span(),
    );
    store(
        eth.contract_address,
        map_entry_address(
            selector!("ERC20_balances"),
            array![dispatcher.contract_address.into()].span() // Providing mapping key
        ),
        array![ONE_ETH.into()].span(),
    );
    start_cheat_caller_address(eth.contract_address, player);
    eth.approve(dispatcher.contract_address, amount.into());
    stop_cheat_caller_address(eth.contract_address);

    // Place bet as player
    start_cheat_caller_address(dispatcher.contract_address, player);
    dispatcher.place_bet(game_id, amount_u256);
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
    let bal_player_after = eth.balance_of(player);
    assert(
        bal_player_after == (amount.into() * multiplier / BASIS_POINTS), 'Player balance mismatch',
    );

    let bal_contract = eth.balance_of(dispatcher.contract_address);
    let casino_fee = amount_u256 * management.get_casino_fee() / BASIS_POINTS;

    assert(
        bal_contract == (ONE_ETH.into()
            - (amount.into() * multiplier / 10000 - amount.into())
            - casino_fee),
        'Contract balance mismatch',
    );
}

#[test]
#[fork(url: "https://starknet-sepolia.public.blastapi.io/rpc/v0_7", block_tag: latest)]
#[should_panic(expected: 'Caller is not the owner')]
fn test_cashout_fail() {
    // Setup initial game state
    let (dispatcher, _, _, secret_seed) = setup_start_betting();
    let game_id = dispatcher.get_current_game();
    let amount: u128 = 1000000000000000;
    let amount_u256: u256 = amount.into();
    // Setup player address
    let player = PLAYER_ADDRESS();
    // Setup ETH token and give balance to player using cheatcode
    let eth = ERC20ABIDispatcher { contract_address: ETH_ADDRESS() };
    store(
        eth.contract_address,
        map_entry_address(
            selector!("ERC20_balances"), array![player.into()].span() // Providing mapping key
        ),
        array![amount.into() * 2].span(),
    );
    start_cheat_caller_address(eth.contract_address, player);
    eth.approve(dispatcher.contract_address, amount.into());
    stop_cheat_caller_address(eth.contract_address);

    // Place bet as player
    start_cheat_caller_address(dispatcher.contract_address, player);
    dispatcher.place_bet(game_id, amount_u256);
    stop_cheat_caller_address(dispatcher.contract_address);

    start_cheat_caller_address(dispatcher.contract_address, OPERATOR_ADDRESS());
    dispatcher.start_game();
    stop_cheat_caller_address(dispatcher.contract_address);

    start_cheat_caller_address(dispatcher.contract_address, OPERATOR_ADDRESS());
    dispatcher.end_game(secret_seed);
    stop_cheat_caller_address(dispatcher.contract_address);

    start_cheat_caller_address(dispatcher.contract_address, player);
    dispatcher.process_cashout(game_id, player, BASIS_POINTS);
    stop_cheat_caller_address(dispatcher.contract_address);
}

#[test]
#[fork(url: "https://starknet-sepolia.public.blastapi.io/rpc/v0_7", block_tag: latest)]
#[should_panic(expected: 'Already processed')]
fn test_cashout_fail_already_processed() {
    // Setup initial game state
    let (dispatcher, _, _, secret_seed) = setup_start_betting();
    let game_id = dispatcher.get_current_game();
    let amount: u128 = 1000000000000000;
    let amount_u256: u256 = amount.into();
    // Setup player address
    let player = starknet::contract_address_const::<'player'>();
    // Setup ETH token and give balance to player using cheatcode
    let eth = ERC20ABIDispatcher { contract_address: ETH_ADDRESS() };
    store(
        eth.contract_address,
        map_entry_address(
            selector!("ERC20_balances"), array![player.into()].span() // Providing mapping key
        ),
        array![amount.into() * 2].span(),
    );
    store(
        eth.contract_address,
        map_entry_address(
            selector!("ERC20_balances"),
            array![dispatcher.contract_address.into()].span() // Providing mapping key
        ),
        array![ONE_ETH.into()].span(),
    );

    start_cheat_caller_address(eth.contract_address, player);
    eth.approve(dispatcher.contract_address, amount.into());
    stop_cheat_caller_address(eth.contract_address);

    // Place bet as player
    start_cheat_caller_address(dispatcher.contract_address, player);
    dispatcher.place_bet(game_id, amount_u256);
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

#[test]
#[should_panic(expected: 'Invalid seed')]
fn test_end_game_invalid_seed() {
    let (dispatcher, _, _, _) = setup_start_betting();

    start_cheat_caller_address(dispatcher.contract_address, OPERATOR_ADDRESS());
    dispatcher.start_game();
    stop_cheat_caller_address(dispatcher.contract_address);

    start_cheat_caller_address(dispatcher.contract_address, OPERATOR_ADDRESS());
    dispatcher.end_game(123456789); // Wrong seed
    stop_cheat_caller_address(dispatcher.contract_address);
}
