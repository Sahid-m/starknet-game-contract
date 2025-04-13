// SPDX-License-Identifier: MIT
// Compatible with OpenZeppelin Contracts for Cairo ^1.0.0

#[starknet::contract]
mod IBAD {
    use ERC20Component::InternalTrait;
    use openzeppelin::access::ownable::OwnableComponent;
    use openzeppelin::token::erc20::{ERC20Component, ERC20HooksEmptyImpl};
    use starknet::storage::{Map, StorageMapReadAccess, StorageMapWriteAccess};
    use starknet::{ContractAddress, get_caller_address};

    component!(path: ERC20Component, storage: erc20, event: ERC20Event);
    component!(path: OwnableComponent, storage: ownable, event: OwnableEvent);

    // External
    #[abi(embed_v0)]
    impl ERC20MixinImpl = ERC20Component::ERC20MixinImpl<ContractState>;
    #[abi(embed_v0)]
    impl OwnableMixinImpl = OwnableComponent::OwnableMixinImpl<ContractState>;

    // Internal
    impl ERC20InternalImpl = ERC20Component::InternalImpl<ContractState>;
    impl OwnableInternalImpl = OwnableComponent::InternalImpl<ContractState>;

    #[storage]
    struct Storage {
        #[substorage(v0)]
        erc20: ERC20Component::Storage,
        #[substorage(v0)]
        ownable: OwnableComponent::Storage,
        GamesHistory: Map<ContractAddress, (u64, u64)>,
        GamesRunning: Map<ContractAddress, u256>,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        #[flat]
        ERC20Event: ERC20Component::Event,
        #[flat]
        OwnableEvent: OwnableComponent::Event,
    }

    #[constructor]
    fn constructor(ref self: ContractState, owner: ContractAddress) {
        self.erc20.initializer("IBAD", "IBU");
        self.ownable.initializer(owner);
    }

    #[generate_trait]
    #[abi(per_item)]
    impl ExternalImpl of ExternalTrait {
        #[external(v0)]
        fn burn(ref self: ContractState, value: u256) {
            self.erc20.burn(get_caller_address(), value);
        }

        #[external(v0)]
        fn mint(ref self: ContractState, recipient: ContractAddress, amount: u256) {
            self.ownable.assert_only_owner();
            self.erc20.mint(recipient, amount);
        }


        #[external(v0)]
        fn games_start(ref self: ContractState, player: ContractAddress, bet: u256) {
            self.ownable.assert_only_owner();
            self.erc20.burn(player, bet);
            self.GamesRunning.write(player, bet);
        }

        #[external(v0)]
        fn game_end(ref self: ContractState, player: ContractAddress, won: bool) {
            self.ownable.assert_only_owner();

            let gameBet = self.GamesRunning.read(player);

            assert(gameBet != 0, 'No Game running');

            // Read existing game history, or default to (0, 0) if none
            let (games_won, games_loss) = self.GamesHistory.read(player);

            // Update values
            let updated_history = if won {
                self.erc20.mint(player, gameBet * 2);
                (games_won + 1, games_loss)
            } else {
                (games_won, games_loss + 1)
            };

            // Write back to storage
            self.GamesHistory.write(player, updated_history);
        }
    }
}
