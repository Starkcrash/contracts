use openzeppelin_security::interface::{IPausableDispatcher, IPausableDispatcherTrait};
use openzeppelin_token::erc20::interface::{ERC20ABIDispatcher, ERC20ABIDispatcherTrait};
use raindinner_contracts::controller::controller::{
    IControllerDispatcher, IControllerDispatcherTrait, IControllerManagementDispatcher,
    IControllerManagementDispatcherTrait,
};
use raindinner_contracts::games::crashgame::crashgame::IManagementDispatcherTrait;
use raindinner_contracts::safe::safe::ISafeDispatcherTrait;
use snforge_std::{map_entry_address, start_cheat_caller_address, stop_cheat_caller_address, store};
use starknet::ContractAddress;
use crate::utils::{
    BASIS_POINTS, CASINO_ADDRESS, CONTROLLER_ADDRESS, DEFAULT_MAX_BET, DEFAULT_MIN_BET, ETH_ADDRESS,
    GAME_ADDRESS, GAME_ADDRESS_2, ONE_ETH, OPERATOR_ADDRESS, PLAYER_ADDRESS, SAFE_ADDRESS,
    deploy_erc20, setup_controller, setup_crash, setup_erc20, setup_safe, setup_safe_and_controller,
    whitelist_game_utils,
};

#[test]
fn test_constructor() {
    let (controller_address, _) = setup_controller();
    let controller = IControllerManagementDispatcher { contract_address: controller_address };
    assert(controller.get_casino_fee() == 500_u256, 'Wrong casino fee');
    assert(controller.get_safe_address() == SAFE_ADDRESS(), 'Wrong safe address');
}

#[test]
fn test_multiple_games_whitelisted() {
    // Setup
    let (controller_address, controller_dispatcher) = setup_controller();
    let controller = IControllerManagementDispatcher { contract_address: controller_address };
    let game1_address = GAME_ADDRESS();
    let game2_address = GAME_ADDRESS_2();

    // Whitelist two different games with different bet limits
    start_cheat_caller_address(controller.contract_address, OPERATOR_ADDRESS());
    controller.whitelist_game(game1_address, DEFAULT_MIN_BET, DEFAULT_MAX_BET);

    let min_bet2 = DEFAULT_MIN_BET * 2;
    let max_bet2 = DEFAULT_MAX_BET * 2;
    controller.whitelist_game(game2_address, min_bet2, max_bet2);
    stop_cheat_caller_address(controller.contract_address);

    assert(
        controller_dispatcher.is_game_whitelisted(game1_address), 'Game 1 should be whitelisted',
    );
    assert(
        controller_dispatcher.is_game_whitelisted(game2_address), 'Game 2 should be whitelisted',
    );

    assert(
        controller_dispatcher.get_min_bet(game1_address) == DEFAULT_MIN_BET,
        'Wrong min bet for game 1',
    );
    assert(
        controller_dispatcher.get_max_bet(game1_address) == DEFAULT_MAX_BET,
        'Wrong max bet for game 1',
    );

    assert(
        controller_dispatcher.get_min_bet(game2_address) == min_bet2, 'Wrong min bet for game 2',
    );
    assert(
        controller_dispatcher.get_max_bet(game2_address) == max_bet2, 'Wrong max bet for game 2',
    );

    start_cheat_caller_address(controller.contract_address, OPERATOR_ADDRESS());
    controller.remove_game(game1_address);
    stop_cheat_caller_address(controller.contract_address);

    assert(
        !controller_dispatcher.is_game_whitelisted(game1_address), 'Gameshould not be whitelisted',
    );
    assert(controller_dispatcher.is_game_whitelisted(game2_address), 'Game should  be whitelisted');
}

#[test]
fn test_process_bet() {
    let (eth, eth_dispatcher) = setup_erc20();

    let (safe, controller) = setup_safe_and_controller();
    whitelist_game_utils(
        controller.contract_address, GAME_ADDRESS(), DEFAULT_MIN_BET, DEFAULT_MAX_BET,
    );
    let amount: u128 = DEFAULT_MAX_BET.try_into().unwrap();

    store(
        eth,
        map_entry_address(selector!("ERC20_balances"), array![CONTROLLER_ADDRESS().into()].span()),
        array![amount.into()].span(),
    );

    start_cheat_caller_address(controller.contract_address, GAME_ADDRESS());
    controller.process_bet(amount.into());
    stop_cheat_caller_address(controller.contract_address);

    let controller_management = IControllerManagementDispatcher {
        contract_address: controller.contract_address,
    };

    let casino_fee = (amount.into() * controller_management.get_casino_fee()) / BASIS_POINTS;

    assert(eth_dispatcher.balance_of(CASINO_ADDRESS()) == casino_fee, 'Wrong casino fee');
    assert(
        eth_dispatcher.balance_of(safe.contract_address) == amount.into() - casino_fee,
        'Wrong safe balance',
    );
}

#[test]
#[should_panic(expected: 'Amount exceeds max bet')]
fn test_process_bet_above_max_bet() {
    let (eth, eth_dispatcher) = setup_erc20();

    let (safe, controller) = setup_safe_and_controller();
    whitelist_game_utils(
        controller.contract_address, GAME_ADDRESS(), DEFAULT_MIN_BET, DEFAULT_MAX_BET,
    );
    let amount = ONE_ETH;
    assert(amount.into() > DEFAULT_MAX_BET, 'Amount should be ge max bet');
    store(
        eth,
        map_entry_address(selector!("ERC20_balances"), array![CONTROLLER_ADDRESS().into()].span()),
        array![amount.into()].span(),
    );

    start_cheat_caller_address(controller.contract_address, GAME_ADDRESS());
    controller.process_bet(amount.into());
    stop_cheat_caller_address(controller.contract_address);
}

#[test]
#[should_panic(expected: 'Amount below min bet')]
fn test_process_bet_below_min_bet() {
    let (eth, eth_dispatcher) = setup_erc20();

    let (safe, controller) = setup_safe_and_controller();
    whitelist_game_utils(
        controller.contract_address, GAME_ADDRESS(), DEFAULT_MIN_BET, DEFAULT_MAX_BET,
    );
    let amount: u128 = (DEFAULT_MIN_BET - 1).try_into().unwrap();
    assert(amount.into() < DEFAULT_MIN_BET, 'Amount should be lt min bet');
    store(
        eth,
        map_entry_address(selector!("ERC20_balances"), array![CONTROLLER_ADDRESS().into()].span()),
        array![amount.into()].span(),
    );

    start_cheat_caller_address(controller.contract_address, GAME_ADDRESS());
    controller.process_bet(amount.into());
    stop_cheat_caller_address(controller.contract_address);
}

#[test]
#[should_panic(expected: 'Not game / game not whitelisted')]
fn test_process_bet_not_game() {
    let (eth, _) = setup_erc20();

    let (_, controller) = setup_safe_and_controller();

    let amount: u128 = DEFAULT_MAX_BET.try_into().unwrap();

    start_cheat_caller_address(controller.contract_address, PLAYER_ADDRESS());
    controller.process_bet(amount.into());
    stop_cheat_caller_address(controller.contract_address);
}

#[test]
fn test_process_cashout() {
    let (eth, eth_dispatcher) = setup_erc20();

    let (safe, controller) = setup_safe_and_controller();
    whitelist_game_utils(
        controller.contract_address, GAME_ADDRESS(), DEFAULT_MIN_BET, DEFAULT_MAX_BET,
    );
    let amount: u128 = DEFAULT_MAX_BET.try_into().unwrap();

    store(
        eth,
        map_entry_address(selector!("ERC20_balances"), array![CONTROLLER_ADDRESS().into()].span()),
        array![amount.into()].span(),
    );

    store(
        eth,
        map_entry_address(selector!("ERC20_balances"), array![SAFE_ADDRESS().into()].span()),
        array![ONE_ETH.into()].span(),
    );

    start_cheat_caller_address(controller.contract_address, GAME_ADDRESS());
    controller.process_bet(amount.into());
    stop_cheat_caller_address(controller.contract_address);

    let balance_safe = eth_dispatcher.balance_of(safe.contract_address);
    assert(balance_safe > 0, 'Wrong safe balance');

    start_cheat_caller_address(controller.contract_address, GAME_ADDRESS());
    controller.process_cashout(PLAYER_ADDRESS(), amount.into());
    stop_cheat_caller_address(controller.contract_address);

    let balance_safe_after = eth_dispatcher.balance_of(safe.contract_address);
    assert(balance_safe_after == balance_safe - amount.into(), 'Wrong safe balance');

    let balance_player = eth_dispatcher.balance_of(PLAYER_ADDRESS());
    assert(balance_player == amount.into(), 'Wrong player balance');
}

#[test]
#[should_panic(expected: 'Not game / game not whitelisted')]
fn test_process_cashout_not_game() {
    let (eth, eth_dispatcher) = setup_erc20();

    let (safe, controller) = setup_safe_and_controller();
    whitelist_game_utils(
        controller.contract_address, GAME_ADDRESS(), DEFAULT_MIN_BET, DEFAULT_MAX_BET,
    );
    let amount: u128 = DEFAULT_MAX_BET.try_into().unwrap();

    store(
        eth,
        map_entry_address(selector!("ERC20_balances"), array![CONTROLLER_ADDRESS().into()].span()),
        array![amount.into()].span(),
    );

    store(
        eth,
        map_entry_address(selector!("ERC20_balances"), array![SAFE_ADDRESS().into()].span()),
        array![ONE_ETH.into()].span(),
    );

    start_cheat_caller_address(controller.contract_address, GAME_ADDRESS());
    controller.process_bet(amount.into());
    stop_cheat_caller_address(controller.contract_address);

    let balance_safe = eth_dispatcher.balance_of(safe.contract_address);
    assert(balance_safe > 0, 'Wrong safe balance');

    start_cheat_caller_address(controller.contract_address, PLAYER_ADDRESS());
    controller.process_cashout(PLAYER_ADDRESS(), amount.into());
    stop_cheat_caller_address(controller.contract_address);
}
