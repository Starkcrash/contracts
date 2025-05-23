use raindinner_contracts::controller::controller::{
    IControllerDispatcherTrait, IControllerManagementDispatcher,
    IControllerManagementDispatcherTrait,
};
use snforge_std::{start_cheat_caller_address, stop_cheat_caller_address};
use crate::utils::{
    DEFAULT_MAX_BET, DEFAULT_MIN_BET, GAME_ADDRESS, OPERATOR_ADDRESS, PLAYER_ADDRESS,
    setup_controller,
};

#[test]
fn test_whitelist_game() {
    let (controller_address, controller_dispatcher) = setup_controller();
    let controller = IControllerManagementDispatcher { contract_address: controller_address };

    start_cheat_caller_address(controller.contract_address, OPERATOR_ADDRESS());
    controller.whitelist_game(GAME_ADDRESS(), DEFAULT_MIN_BET, DEFAULT_MAX_BET);
    stop_cheat_caller_address(controller.contract_address);

    assert(controller_dispatcher.is_game_whitelisted(GAME_ADDRESS()), 'Game should be whitelisted');
}

#[test]
fn test_rm_game_from_whitelist() {
    let (controller_address, controller_dispatcher) = setup_controller();
    let controller = IControllerManagementDispatcher { contract_address: controller_address };

    start_cheat_caller_address(controller.contract_address, OPERATOR_ADDRESS());
    controller.whitelist_game(GAME_ADDRESS(), DEFAULT_MIN_BET, DEFAULT_MAX_BET);
    stop_cheat_caller_address(controller.contract_address);

    assert(controller_dispatcher.is_game_whitelisted(GAME_ADDRESS()), 'Game should be whitelisted');

    start_cheat_caller_address(controller.contract_address, OPERATOR_ADDRESS());
    controller.remove_game(GAME_ADDRESS());
    stop_cheat_caller_address(controller.contract_address);

    assert(
        !controller_dispatcher.is_game_whitelisted(GAME_ADDRESS()),
        'Game should not be whitelisted',
    );
}

#[test]
#[should_panic(expected: 'Not game / game not whitelisted')]
fn test_not_whitelisted_game() {
    let (controller_address, controller_dispatcher) = setup_controller();
    let controller = IControllerManagementDispatcher { contract_address: controller_address };

    assert(
        !controller_dispatcher.is_game_whitelisted(GAME_ADDRESS()),
        'Game should not be whitelisted',
    );

    start_cheat_caller_address(controller.contract_address, OPERATOR_ADDRESS());
    controller.set_max_bet(GAME_ADDRESS(), DEFAULT_MAX_BET - 10);
    stop_cheat_caller_address(controller.contract_address);
}


#[test]
fn test_set_casino_fee() {
    let (controller_address, _) = setup_controller();
    let controller = IControllerManagementDispatcher { contract_address: controller_address };
    let new_fee = 400_u256; // 4%

    start_cheat_caller_address(controller.contract_address, OPERATOR_ADDRESS());
    controller.set_casino_fee_basis_points(new_fee);
    stop_cheat_caller_address(controller.contract_address);

    assert(controller.get_casino_fee() == new_fee, 'Wrong casino fee');
}
#[test]
#[should_panic(expected: 'Casino fee must be <= 600')]
fn test_set_casino_fee_too_high() {
    let (controller_address, _) = setup_controller();
    let controller = IControllerManagementDispatcher { contract_address: controller_address };
    let new_fee = 700_u256; // 5%

    start_cheat_caller_address(controller.contract_address, OPERATOR_ADDRESS());
    controller.set_casino_fee_basis_points(new_fee);
    stop_cheat_caller_address(controller.contract_address);
}

#[test]
fn test_games_bet_limits() {
    let (controller_address, controller_dispatcher) = setup_controller();
    let controller = IControllerManagementDispatcher { contract_address: controller_address };
    let new_max_bet: u256 = 2_000_000_000_000_000_0;
    let new_min_bet: u256 = 2_000_000_000_000_000;

    start_cheat_caller_address(controller.contract_address, OPERATOR_ADDRESS());
    controller.whitelist_game(GAME_ADDRESS(), DEFAULT_MIN_BET, DEFAULT_MAX_BET);
    stop_cheat_caller_address(controller.contract_address);

    assert(
        controller_dispatcher.get_max_bet(GAME_ADDRESS()) == DEFAULT_MAX_BET, 'Wrong max
    bet',
    );
    assert(
        controller_dispatcher.get_min_bet(GAME_ADDRESS()) == DEFAULT_MIN_BET, 'Wrong min
    bet',
    );

    start_cheat_caller_address(controller.contract_address, OPERATOR_ADDRESS());
    controller.set_max_bet(GAME_ADDRESS(), new_max_bet);
    stop_cheat_caller_address(controller.contract_address);

    start_cheat_caller_address(controller.contract_address, OPERATOR_ADDRESS());
    controller.set_min_bet(GAME_ADDRESS(), new_min_bet);
    stop_cheat_caller_address(controller.contract_address);

    assert(controller_dispatcher.get_max_bet(GAME_ADDRESS()) == new_max_bet, 'Wrong max bet');
    assert(
        controller_dispatcher.get_min_bet(GAME_ADDRESS()) == new_min_bet,
        'Wrong min
    bet after update',
    );
}


#[test]
#[should_panic(expected: 'Caller is not the owner')]
fn test_set_min_bet_not_owner() {
    let (controller_address, _) = setup_controller();
    let controller = IControllerManagementDispatcher { contract_address: controller_address };

    start_cheat_caller_address(controller.contract_address, OPERATOR_ADDRESS());
    controller.whitelist_game(GAME_ADDRESS(), DEFAULT_MIN_BET, DEFAULT_MAX_BET);
    stop_cheat_caller_address(controller.contract_address);

    start_cheat_caller_address(controller.contract_address, PLAYER_ADDRESS());
    controller.set_min_bet(GAME_ADDRESS(), DEFAULT_MIN_BET);
    stop_cheat_caller_address(controller.contract_address);
}

