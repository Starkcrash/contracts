use starknet::ContractAddress;

/// Interface for the Safe contract
/// Provides methods for securely managing casino funds
#[starknet::interface]
pub trait ISafe<TContractState> {
    /// Deposit a bet into the safe
    /// # Arguments
    /// * `amount` - The bet amount in wei
    /// # Returns
    /// * `true` if the deposit was successful
    /// # Reverts
    /// * If caller is not the controller
    /// * If contract is paused
    fn deposit_bet(ref self: TContractState, amount: u256) -> bool;

    /// Process a payout from the safe
    /// # Arguments
    /// * `player` - The address of the player receiving the payout
    /// * `amount` - The payout amount in wei
    /// # Returns
    /// * `true` if the payout was successful
    /// # Reverts
    /// * If caller is not the controller
    /// * If contract is paused
    /// * If there is insufficient liquidity in the safe
    fn process_payout(ref self: TContractState, player: ContractAddress, amount: u256) -> bool;

    /// Get the total liquidity in the safe
    /// # Returns
    /// * The total amount of ETH held by the safe in wei
    fn get_total_liquidity(self: @TContractState) -> u256;

    /// Get the controller address
    /// # Returns
    /// * The address of the controller contract
    fn get_controller(self: @TContractState) -> ContractAddress;

    /// Set the controller address
    /// # Arguments
    /// * `controller` - The address of the controller contract
    fn set_controller(ref self: TContractState, controller: ContractAddress);

    /// Withdraw funds to the multisig address
    /// # Arguments
    /// * `amount` - The amount to withdraw in wei
    /// # Returns
    /// * `true` if the withdrawal was successful
    /// # Reverts
    /// * If caller is not the multisig
    /// * If there is insufficient liquidity in the safe
    /// * If multisig is not set
    fn withdraw_to_multisig(ref self: TContractState, amount: u256) -> bool;

    /// Get the multisig address
    /// # Returns
    /// * The address of the multisig contract
    fn get_multisig(self: @TContractState) -> ContractAddress;

    /// Set the multisig address
    /// # Arguments
    /// * `multisig` - The address of the multisig contract
    fn set_multisig(ref self: TContractState, multisig: ContractAddress);
}

/// Internal interface for Safe contract security checks
#[starknet::interface]
trait ISafeInternal<TContractState> {
    /// Verify that the caller is the controller
    /// # Reverts
    /// * If caller is not the controller
    fn assert_only_controller(self: @TContractState);
}

/// The Safe contract securely holds all funds for the casino
/// It only allows the controller to deposit and withdraw funds,
/// providing a secure isolation layer for casino liquidity
#[starknet::contract]
pub mod Safe {
    use openzeppelin::upgrades::UpgradeableComponent;
    use openzeppelin::upgrades::interface::IUpgradeable;
    use openzeppelin_access::ownable::OwnableComponent;
    use openzeppelin_security::PausableComponent;
    use openzeppelin_token::erc20::interface::{ERC20ABIDispatcher, ERC20ABIDispatcherTrait};
    use starknet::{ClassHash, ContractAddress, get_caller_address, get_contract_address};
    use crate::safe::errors::Errors;
    use super::ISafe;

    component!(path: OwnableComponent, storage: ownable, event: OwnableEvent);
    component!(path: PausableComponent, storage: pausable, event: PausableEvent);
    component!(path: UpgradeableComponent, storage: upgradeable, event: UpgradeableEvent);

    // Ownable Mixin
    #[abi(embed_v0)]
    impl OwnableMixinImpl = OwnableComponent::OwnableMixinImpl<ContractState>;
    impl OwnableInternalImpl = OwnableComponent::InternalImpl<ContractState>;

    // Pausable
    #[abi(embed_v0)]
    impl PausableImpl = PausableComponent::PausableImpl<ContractState>;
    impl PausableInternalImpl = PausableComponent::InternalImpl<ContractState>;

    impl UpgradeableInternalImpl = UpgradeableComponent::InternalImpl<ContractState>;


    // Ethereum token address on Starknet
    const ETH_ADDRESS: felt252 = 0x049d36570d4e46f48e99674bd3fcc84644ddd6b96f7c741b1562b82f9e004dc7;


    /// Storage for the Safe contract
    #[storage]
    struct Storage {
        #[substorage(v0)]
        ownable: OwnableComponent::Storage,
        #[substorage(v0)]
        pausable: PausableComponent::Storage,
        #[substorage(v0)]
        upgradeable: UpgradeableComponent::Storage,
        controller: ContractAddress, // Address of the controller contract
        multisig: ContractAddress // Address of the multisig contract
    }

    /// Events emitted by the Safe contract
    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        #[flat]
        OwnableEvent: OwnableComponent::Event,
        #[flat]
        PausableEvent: PausableComponent::Event,
        #[flat]
        UpgradeableEvent: UpgradeableComponent::Event,
        ControllerUpdated: ControllerUpdated,
        MultisigWithdrawal: MultisigWithdrawal,
    }


    /// Event emitted when the controller address is updated
    #[derive(Drop, starknet::Event)]
    struct ControllerUpdated {
        old_controller: ContractAddress,
        new_controller: ContractAddress,
    }

    /// Event emitted when the multisig withdraws funds
    #[derive(Drop, starknet::Event)]
    struct MultisigWithdrawal {
        amount: u256,
    }

    /// Constructor initializes the Safe contract
    /// # Arguments
    /// * `owner` - The address that will own the contract
    #[constructor]
    fn constructor(ref self: ContractState, owner: ContractAddress, multisig: ContractAddress) {
        self.ownable.initializer(owner);
        self.multisig.write(multisig);
    }

    /// Implementation of external utility functions
    #[generate_trait]
    #[abi(per_item)]
    impl ExternalImpl of ExternalTrait {
        /// Pause the contract to halt operations in emergency
        /// # Reverts
        /// * If caller is not the owner
        #[external(v0)]
        fn pause(ref self: ContractState) {
            self.ownable.assert_only_owner();
            self.pausable.pause();
        }

        /// Unpause the contract to resume operations
        /// # Reverts
        /// * If caller is not the owner
        #[external(v0)]
        fn unpause(ref self: ContractState) {
            self.ownable.assert_only_owner();
            self.pausable.unpause();
        }
    }

    /// Implementation of the Safe interface
    #[abi(embed_v0)]
    impl ISafeImpl of ISafe<ContractState> {
        fn deposit_bet(ref self: ContractState, amount: u256) -> bool {
            self.assert_only_controller();
            self.pausable.assert_not_paused();

            // Transfer tokens from controller to safe
            let eth = ERC20ABIDispatcher { contract_address: ETH_ADDRESS.try_into().unwrap() };
            assert(
                eth.transfer_from(self.controller.read(), starknet::get_contract_address(), amount),
                Errors::TRANSFER_FAILED,
            );

            true
        }

        fn process_payout(ref self: ContractState, player: ContractAddress, amount: u256) -> bool {
            self.assert_only_controller();
            self.pausable.assert_not_paused();

            // Verify sufficient liquidity
            assert(self.get_total_liquidity() >= amount, Errors::INSUFFICIENT_LIQUIDITY);

            // Transfer tokens to player
            let eth = ERC20ABIDispatcher { contract_address: ETH_ADDRESS.try_into().unwrap() };
            assert(eth.transfer(player, amount), Errors::TRANSFER_FAILED);

            true
        }


        fn get_total_liquidity(self: @ContractState) -> u256 {
            let eth = ERC20ABIDispatcher { contract_address: ETH_ADDRESS.try_into().unwrap() };
            let bal = eth.balance_of(get_contract_address());
            bal
        }

        fn get_controller(self: @ContractState) -> ContractAddress {
            self.controller.read()
        }

        fn set_controller(ref self: ContractState, controller: ContractAddress) {
            self.ownable.assert_only_owner();
            self.controller.write(controller);
        }

        fn withdraw_to_multisig(ref self: ContractState, amount: u256) -> bool {
            self.assert_only_multisig();

            // Verify sufficient liquidity
            assert(self.get_total_liquidity() >= amount, Errors::INSUFFICIENT_LIQUIDITY);

            // Transfer tokens to multisig
            let eth = ERC20ABIDispatcher { contract_address: ETH_ADDRESS.try_into().unwrap() };
            let multisig_address = self.multisig.read();
            assert(multisig_address.into() != 0_felt252, Errors::MULTISIG_NOT_SET);
            assert(eth.transfer(multisig_address, amount), Errors::TRANSFER_FAILED);

            self.emit(MultisigWithdrawal { amount });
            true
        }

        fn get_multisig(self: @ContractState) -> ContractAddress {
            self.multisig.read()
        }

        fn set_multisig(ref self: ContractState, multisig: ContractAddress) {
            self.assert_only_multisig();
            self.multisig.write(multisig);
        }
    }

    /// Implementation of internal security methods
    #[generate_trait]
    pub impl InternalImpl of InternalTrait {
        #[inline(always)]
        fn assert_only_controller(self: @ContractState) {
            let controller = self.controller.read();
            let caller = get_caller_address();
            assert(caller == controller, Errors::ONLY_CONTROLLER_ALLOWED);
        }

        #[inline(always)]
        fn assert_only_multisig(self: @ContractState) {
            let multisig = self.multisig.read();
            let caller = get_caller_address();
            assert(caller == multisig, Errors::ONLY_MULTISIG_ALLOWED);
        }
    }

    /// Implementation of the upgradeable interface
    #[abi(embed_v0)]
    impl UpgradeableImpl of IUpgradeable<ContractState> {
        /// Upgrade the contract to a new implementation
        /// # Arguments
        /// * `new_class_hash` - The class hash of the new implementation
        /// # Reverts
        /// * If caller is not the owner
        fn upgrade(ref self: ContractState, new_class_hash: ClassHash) {
            self.ownable.assert_only_owner();
            self.upgradeable.upgrade(new_class_hash);
        }
    }
}
