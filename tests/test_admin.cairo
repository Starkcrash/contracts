use snforge_std::{start_cheat_caller_address, stop_cheat_caller_address};

use crash_contracts::crashgame::crashgame::IManagementDispatcherTrait;

use crate::utils::{setup, OPERATOR_ADDRESS};

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

