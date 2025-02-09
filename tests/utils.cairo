use starknet::{ContractAddress};
use core::traits::Into;
use core::traits::TryInto;

use snforge_std::{
    declare, ContractClassTrait, DeclareResultTrait, start_cheat_caller_address,
    stop_cheat_caller_address,
};

use crash_contracts::crashgame::crashgame::{
    ICrashGameDispatcher, ICrashGameDispatcherTrait, IManagementDispatcher,
    IManagementDispatcherTrait,
};


pub fn ETH_ADDRESS() -> ContractAddress {
    0x049d36570d4e46f48e99674bd3fcc84644ddd6b96f7c741b1562b82f9e004dc7.try_into().unwrap()
}

pub fn OPERATOR_ADDRESS() -> ContractAddress {
    'operator'.try_into().unwrap()
}

pub fn CASINO_ADDRESS() -> ContractAddress {
    'casino'.try_into().unwrap()
}

pub fn PLAYER_ADDRESS() -> ContractAddress {
    'player'.try_into().unwrap()
}

pub const ONE_ETH: u128 = 1_000_000_000_000_000_000;
pub const BASIS_POINTS: u256 = 10000;

pub fn deploy_contract() -> ContractAddress {
    let contract = declare("CrashGame").unwrap().contract_class();
    let constructor_args = array![OPERATOR_ADDRESS().into(), CASINO_ADDRESS().into()];
    let (contract_address, _) = contract.deploy(@constructor_args).unwrap();
    contract_address
}

pub fn setup() -> (ICrashGameDispatcher, IManagementDispatcher) {
    // Deploy with caller as operator
    let contract_address = deploy_contract();
    let dispatcher = ICrashGameDispatcher { contract_address };
    let management_dispatcher = IManagementDispatcher { contract_address };
    (dispatcher, management_dispatcher)
}

pub fn deploy_erc20() -> ContractAddress {
    let contract = declare("MyToken").unwrap().contract_class();
    let constructor_args = array![];
    let (contract_address, _) = contract.deploy_at(@constructor_args, ETH_ADDRESS()).unwrap();
    contract_address
}

pub fn setup_start_betting() -> (ICrashGameDispatcher, IManagementDispatcher, felt252, felt252) {
    // Deploy with caller as operator
    let contract_address = deploy_contract();
    let dispatcher = ICrashGameDispatcher { contract_address };
    let management_dispatcher = IManagementDispatcher { contract_address };
    let seed_hash = 447081709482894523534661633867505801754022196930481080379856883095486108589;
    let secret_seed = 357603085394972;

    start_cheat_caller_address(contract_address, OPERATOR_ADDRESS());
    management_dispatcher.set_casino_fee_basis_points(400);
    stop_cheat_caller_address(contract_address);

    start_cheat_caller_address(contract_address, OPERATOR_ADDRESS());
    dispatcher.commit_seed(seed_hash);
    stop_cheat_caller_address(contract_address);

    start_cheat_caller_address(contract_address, OPERATOR_ADDRESS());
    dispatcher.start_betting();
    stop_cheat_caller_address(contract_address);

    (dispatcher, management_dispatcher, seed_hash, secret_seed)
}
