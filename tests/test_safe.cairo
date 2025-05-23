use openzeppelin_security::interface::{IPausableDispatcher, IPausableDispatcherTrait};
use openzeppelin_token::erc20::interface::{ERC20ABIDispatcher, ERC20ABIDispatcherTrait};
use raindinner_contracts::controller::controller::{
    IControllerDispatcher, IControllerDispatcherTrait, IControllerManagementDispatcher,
    IControllerManagementDispatcherTrait,
};
use raindinner_contracts::safe::safe::{ISafeDispatcher, ISafeDispatcherTrait};
use snforge_std::{map_entry_address, start_cheat_caller_address, stop_cheat_caller_address, store};
use starknet::ContractAddress;
use crate::utils::{
    BASIS_POINTS, CASINO_ADDRESS, CONTROLLER_ADDRESS, DEFAULT_MAX_BET, DEFAULT_MIN_BET, ETH_ADDRESS,
    GAME_ADDRESS, GAME_ADDRESS_2, ONE_ETH, OPERATOR_ADDRESS, PLAYER_ADDRESS, SAFE_ADDRESS,
    deploy_erc20, setup_controller, setup_crash, setup_erc20, setup_safe, setup_safe_and_controller,
};

#[test]
fn test_constructor() {
    let (_, safe) = setup_safe();
    let _ = deploy_erc20();

    assert(safe.get_total_liquidity() == 0_u256, 'Wrong total liquidity');
}

#[test]
fn test_get_total_liquidity() {
    let (safe_address, safe) = setup_safe();
    let eth = deploy_erc20();

    store(
        eth,
        map_entry_address(selector!("ERC20_balances"), array![safe_address.into()].span()),
        array![ONE_ETH.into()].span(),
    );
    assert(safe.get_total_liquidity() == ONE_ETH.into(), 'Wrong total liquidity');
}

#[test]
fn test_set_controller() {
    let (_, safe) = setup_safe();
    let dummy_address: ContractAddress = 'dummy'.try_into().unwrap();
    start_cheat_caller_address(safe.contract_address, OPERATOR_ADDRESS());
    safe.set_controller(dummy_address);
    stop_cheat_caller_address(safe.contract_address);
    assert(safe.get_controller() == dummy_address, 'Wrong controller address');
}

#[test]
#[should_panic(expected: 'Caller is not the owner')]
fn test_set_controller_not_owner() {
    let (safe_address, safe) = setup_safe();
    let dummy_address: ContractAddress = 'dummy'.try_into().unwrap();
    start_cheat_caller_address(safe_address, PLAYER_ADDRESS());
    safe.set_controller(dummy_address);
    stop_cheat_caller_address(safe_address);
}

#[test]
fn test_deposit() {
    let (eth, eth_dispatcher) = setup_erc20();

    let (safe, _) = setup_safe_and_controller();
    let amount = 100_u128;

    store(
        eth,
        map_entry_address(selector!("ERC20_balances"), array![CONTROLLER_ADDRESS().into()].span()),
        array![amount.into()].span(),
    );

    start_cheat_caller_address(eth, CONTROLLER_ADDRESS());
    eth_dispatcher.approve(safe.contract_address, amount.into());
    stop_cheat_caller_address(eth);

    start_cheat_caller_address(safe.contract_address, CONTROLLER_ADDRESS());
    safe.deposit_bet(amount.into());
    stop_cheat_caller_address(safe.contract_address);

    assert(safe.get_total_liquidity() == amount.into(), 'Wrong total liquidity');
}

#[test]
#[should_panic(expected: 'Only controller allowed')]
fn test_deposit_not_controller() {
    let (eth, eth_dispatcher) = setup_erc20();

    let (safe, _) = setup_safe_and_controller();
    let amount = 100_u128;

    store(
        eth,
        map_entry_address(selector!("ERC20_balances"), array![PLAYER_ADDRESS().into()].span()),
        array![amount.into()].span(),
    );

    start_cheat_caller_address(eth, PLAYER_ADDRESS());
    eth_dispatcher.approve(safe.contract_address, amount.into());
    stop_cheat_caller_address(eth);

    start_cheat_caller_address(safe.contract_address, PLAYER_ADDRESS());
    safe.deposit_bet(amount.into());
    stop_cheat_caller_address(safe.contract_address);

    assert(safe.get_total_liquidity() == amount.into(), 'Wrong total liquidity');
}

#[test]
fn test_cashout() {
    let (eth, eth_dispatcher) = setup_erc20();

    let (safe, _) = setup_safe_and_controller();
    let amount = 100_u128;

    store(
        eth,
        map_entry_address(selector!("ERC20_balances"), array![safe.contract_address.into()].span()),
        array![amount.into()].span(),
    );

    start_cheat_caller_address(safe.contract_address, CONTROLLER_ADDRESS());
    safe.process_payout(PLAYER_ADDRESS(), amount.into());
    stop_cheat_caller_address(safe.contract_address);

    assert(safe.get_total_liquidity() == 0, 'Liquidity not 0');
    assert(eth_dispatcher.balance_of(PLAYER_ADDRESS()) == amount.into(), 'Player not paid');
}

#[test]
#[should_panic(expected: 'Insufficient liquidity')]
fn test_cashout_insufficient_liquidity() {
    let (eth, eth_dispatcher) = setup_erc20();

    let (safe, _) = setup_safe_and_controller();
    let amount = 100_u128;

    store(
        eth,
        map_entry_address(selector!("ERC20_balances"), array![safe.contract_address.into()].span()),
        array![amount.into()].span(),
    );

    start_cheat_caller_address(safe.contract_address, CONTROLLER_ADDRESS());
    safe.process_payout(PLAYER_ADDRESS(), amount.into() * 2);
    stop_cheat_caller_address(safe.contract_address);
}

#[test]
#[should_panic(expected: 'Only controller allowed')]
fn test_cashout_not_controller() {
    let (eth, eth_dispatcher) = setup_erc20();

    let (safe, _) = setup_safe_and_controller();
    let amount = 100_u128;

    store(
        eth,
        map_entry_address(selector!("ERC20_balances"), array![safe.contract_address.into()].span()),
        array![amount.into()].span(),
    );

    start_cheat_caller_address(safe.contract_address, PLAYER_ADDRESS());
    safe.process_payout(PLAYER_ADDRESS(), amount.into());
    stop_cheat_caller_address(safe.contract_address);
}

