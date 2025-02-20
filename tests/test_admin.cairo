use snforge_std::{start_cheat_caller_address, stop_cheat_caller_address};

use crash_contracts::crashgame::crashgame::IManagementDispatcherTrait;

use crate::utils::{setup, OPERATOR_ADDRESS, PLAYER_ADDRESS};

#[test]
fn test_set_casino_fee() {
    let (_, management) = setup();
    let new_fee = 500_u256; // 5%

    start_cheat_caller_address(management.contract_address, OPERATOR_ADDRESS());
    management.set_casino_fee_basis_points(new_fee);
    stop_cheat_caller_address(management.contract_address);

    assert(management.get_casino_fee() == new_fee, 'Wrong casino fee');
}

#[test]
#[should_panic(expected: 'Casino fee must be <= 600')]
fn test_set_casino_fee_too_high() {
    let (_, management) = setup();

    start_cheat_caller_address(management.contract_address, OPERATOR_ADDRESS());
    management.set_casino_fee_basis_points(700_u256); // 7% > 6% max
    stop_cheat_caller_address(management.contract_address);
}

#[test]
fn test_set_max_bet() {
    let (_, management) = setup();
    let new_max_bet = 2_000_000_000_000_000_0_u256;

    start_cheat_caller_address(management.contract_address, OPERATOR_ADDRESS());
    management.set_max_bet(new_max_bet);
    stop_cheat_caller_address(management.contract_address);

    assert(management.get_max_bet() == new_max_bet, 'Wrong max bet');
}

#[test]
fn test_set_max_amount_of_bets() {
    let (_, management) = setup();
    let new_max_amount = 3_u8;

    start_cheat_caller_address(management.contract_address, OPERATOR_ADDRESS());
    management.set_max_amount_of_bets(new_max_amount);
    stop_cheat_caller_address(management.contract_address);

    assert(management.get_max_amount_of_bets() == new_max_amount, 'Wrong max amount of bets');
}

#[test]
fn test_min_bet_default() {
    let (_, management) = setup();
    let min_bet = management.get_min_bet();
    assert(min_bet == 100_000_000_000_000, 'Wrong default min bet');
}

#[test]
fn test_set_min_bet() {
    let (_, management) = setup();
    let new_min_bet = 200_000_000_000_000_u256;

    start_cheat_caller_address(management.contract_address, OPERATOR_ADDRESS());
    management.set_min_bet(new_min_bet);
    stop_cheat_caller_address(management.contract_address);

    assert(management.get_min_bet() == new_min_bet, 'Wrong min bet');
}

#[test]
#[should_panic(expected: 'Min bet must be <= max bet')]
fn test_set_min_bet_above_max() {
    let (_, management) = setup();
    let max_bet = management.get_max_bet();
    let invalid_min_bet = max_bet + 1;

    start_cheat_caller_address(management.contract_address, OPERATOR_ADDRESS());
    management.set_min_bet(invalid_min_bet);
    stop_cheat_caller_address(management.contract_address);
}

#[test]
#[should_panic(expected: 'Caller is not the owner')]
fn test_set_min_bet_not_owner() {
    let (_, management) = setup();
    let new_min_bet = 200_000_000_000_000_u256;

    start_cheat_caller_address(management.contract_address, PLAYER_ADDRESS());
    management.set_min_bet(new_min_bet);
    stop_cheat_caller_address(management.contract_address);
}
