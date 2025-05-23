use core::traits::{Into, TryInto};
use openzeppelin_token::erc20::interface::{ERC20ABIDispatcher, ERC20ABIDispatcherTrait};
use raindinner_contracts::controller::controller::{
    IControllerDispatcher, IControllerManagementDispatcher, IControllerManagementDispatcherTrait,
};
use raindinner_contracts::games::crashgame::crashgame::{
    ICrashGameDispatcher, ICrashGameDispatcherTrait, IManagementDispatcher,
    IManagementDispatcherTrait,
};
use raindinner_contracts::games::roulette::roulette::{
    IManagementDispatcher as IRouletteManagementDispatcher,
    IManagementDispatcherTrait as IRouletteManagementDispatcherTrait, IRouletteGameDispatcher,
    IRouletteGameDispatcherTrait,
};
use raindinner_contracts::safe::safe::{ISafeDispatcher, ISafeDispatcherTrait};
use snforge_std::{
    ContractClassTrait, DeclareResultTrait, declare, start_cheat_caller_address,
    stop_cheat_caller_address,
};
use starknet::ContractAddress;


pub fn ETH_ADDRESS() -> ContractAddress {
    0x049d36570d4e46f48e99674bd3fcc84644ddd6b96f7c741b1562b82f9e004dc7.try_into().unwrap()
}

pub fn OPERATOR_ADDRESS() -> ContractAddress {
    'operator'.try_into().unwrap()
}

pub fn CASINO_ADDRESS() -> ContractAddress {
    'casino'.try_into().unwrap()
}

pub fn SAFE_ADDRESS() -> ContractAddress {
    'safe'.try_into().unwrap()
}

pub fn CONTROLLER_ADDRESS() -> ContractAddress {
    'controller'.try_into().unwrap()
}

pub fn PLAYER_ADDRESS() -> ContractAddress {
    'player'.try_into().unwrap()
}

pub fn GAME_ADDRESS() -> ContractAddress {
    'game'.try_into().unwrap()
}

pub fn GAME_ADDRESS_2() -> ContractAddress {
    'game2'.try_into().unwrap()
}

pub const ONE_ETH: u128 = 1_000_000_000_000_000_000;
pub const DEFAULT_MIN_BET: u256 = 1_000_000_000_000_000;
pub const DEFAULT_MAX_BET: u256 = 1_000_000_000_000_000_00;
pub const BASIS_POINTS: u256 = 10000;

pub fn deploy_safe() -> ContractAddress {
    let contract = declare("Safe").unwrap().contract_class();
    let constructor_args = array![OPERATOR_ADDRESS().into()];
    let (contract_address, _) = contract.deploy_at(@constructor_args, SAFE_ADDRESS()).unwrap();
    contract_address
}

pub fn setup_safe() -> (ContractAddress, ISafeDispatcher) {
    let contract_address = deploy_safe();
    let dispatcher = ISafeDispatcher { contract_address };
    (contract_address, dispatcher)
}

pub fn deploy_controller() -> ContractAddress {
    let contract = declare("Controller").unwrap().contract_class();
    let constructor_args = array![
        OPERATOR_ADDRESS().into(), SAFE_ADDRESS().into(), CASINO_ADDRESS().into(), 500, 0,
    ];
    let (contract_address, _) = contract
        .deploy_at(@constructor_args, CONTROLLER_ADDRESS())
        .unwrap();
    contract_address
}

pub fn setup_controller() -> (ContractAddress, IControllerDispatcher) {
    let contract_address = deploy_controller();
    let dispatcher = IControllerDispatcher { contract_address };
    (contract_address, dispatcher)
}

pub fn setup_safe_and_controller() -> (ISafeDispatcher, IControllerDispatcher) {
    let (_, safe_dispatcher) = setup_safe();
    let (controller_address, controller_dispatcher) = setup_controller();

    start_cheat_caller_address(safe_dispatcher.contract_address, OPERATOR_ADDRESS());
    safe_dispatcher.set_controller(controller_address);
    stop_cheat_caller_address(safe_dispatcher.contract_address);

    (safe_dispatcher, controller_dispatcher)
}

pub fn deploy_crash() -> ContractAddress {
    let contract = declare("CrashGame").unwrap().contract_class();
    let constructor_args = array![OPERATOR_ADDRESS().into(), CONTROLLER_ADDRESS().into()];
    let (contract_address, _) = contract.deploy_at(@constructor_args, GAME_ADDRESS()).unwrap();
    contract_address
}

pub fn setup_crash() -> (ICrashGameDispatcher, IManagementDispatcher) {
    // Deploy with caller as operator
    let contract_address = deploy_crash();
    let dispatcher = ICrashGameDispatcher { contract_address };
    let management_dispatcher = IManagementDispatcher { contract_address };
    whitelist_game_utils(CONTROLLER_ADDRESS(), contract_address, DEFAULT_MIN_BET, DEFAULT_MAX_BET);
    (dispatcher, management_dispatcher)
}

pub fn deploy_roulette() -> ContractAddress {
    let contract = declare("RouletteGame").unwrap().contract_class();
    let constructor_args = array![OPERATOR_ADDRESS().into(), CONTROLLER_ADDRESS().into()];
    let (contract_address, _) = contract.deploy_at(@constructor_args, GAME_ADDRESS_2()).unwrap();
    contract_address
}

pub fn setup_roulette() -> (IRouletteGameDispatcher, IRouletteManagementDispatcher) {
    let contract_address = deploy_roulette();
    let dispatcher = IRouletteGameDispatcher { contract_address };
    let management_dispatcher = IRouletteManagementDispatcher { contract_address };
    whitelist_game_utils(CONTROLLER_ADDRESS(), contract_address, DEFAULT_MIN_BET, DEFAULT_MAX_BET);
    (dispatcher, management_dispatcher)
}

pub fn deploy_erc20() -> ContractAddress {
    let contract = declare("MyToken").unwrap().contract_class();
    let constructor_args = array![];
    let (contract_address, _) = contract.deploy_at(@constructor_args, ETH_ADDRESS()).unwrap();
    contract_address
}

pub fn setup_erc20() -> (ContractAddress, ERC20ABIDispatcher) {
    let contract_address = deploy_erc20();
    let dispatcher = ERC20ABIDispatcher { contract_address };
    (contract_address, dispatcher)
}

pub fn setup_start_betting() -> (ICrashGameDispatcher, IManagementDispatcher, felt252, felt252) {
    // Deploy with caller as operator
    let (dispatcher, management_dispatcher) = setup_crash();
    let seed_hash = 447081709482894523534661633867505801754022196930481080379856883095486108589;
    let secret_seed = 357603085394972;

    start_cheat_caller_address(dispatcher.contract_address, OPERATOR_ADDRESS());
    dispatcher.commit_seed(seed_hash);
    stop_cheat_caller_address(dispatcher.contract_address);

    start_cheat_caller_address(dispatcher.contract_address, OPERATOR_ADDRESS());
    dispatcher.start_betting();
    stop_cheat_caller_address(dispatcher.contract_address);

    (dispatcher, management_dispatcher, seed_hash, secret_seed)
}

// pub fn setup_start_betting_roulette() -> (
//     IRouletteGameDispatcher, IRouletteManagementDispatcher, felt252, felt252,
// ) {
//     // Deploy with caller as operator
//     let (dispatcher, management_dispatcher) = setup_roulette();
//     let seed_hash = 447081709482894523534661633867505801754022196930481080379856883095486108589;
//     let secret_seed = 357603085394972;

//     start_cheat_caller_address(dispatcher.contract_address, OPERATOR_ADDRESS());
//     dispatcher.commit_seed(seed_hash);
//     stop_cheat_caller_address(dispatcher.contract_address);

//     start_cheat_caller_address(dispatcher.contract_address, OPERATOR_ADDRESS());
//     dispatcher.start_betting();
//     stop_cheat_caller_address(dispatcher.contract_address);

//     (dispatcher, management_dispatcher, seed_hash, secret_seed)
// }

pub fn whitelist_game_utils(
    controller_address: ContractAddress,
    game_address: ContractAddress,
    min_bet: u256,
    max_bet: u256,
) {
    let controller = IControllerManagementDispatcher { contract_address: controller_address };

    start_cheat_caller_address(controller.contract_address, OPERATOR_ADDRESS());
    controller.whitelist_game(game_address, DEFAULT_MIN_BET, DEFAULT_MAX_BET);
    stop_cheat_caller_address(controller.contract_address);
}
