// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {AttackBase, IVault} from "../helpers/AttackBase.sol";
import {DeadSharesVault} from "../../src/vaults/DeadSharesVault.sol";

/// Deploys DeadSharesVault and pays its seed deposit, the way a deployment
/// script would. The vault pulls the seed from msg.sender in its constructor,
/// so the deployer must approve the vault's address before it exists.
contract VaultSeeder {
    function deploy(IERC20 token, address predicted) external returns (DeadSharesVault vault) {
        token.approve(predicted, 1000);
        vault = new DeadSharesVault(token);
        require(address(vault) == predicted, "VaultSeeder: address prediction");
    }
}

/// Defence 1: seed deposit at deployment, shares burned to 0xdead (Uniswap V2 style).
contract DeadSharesTest is AttackBase {
    function test_deadShares() public {
        // Predict the CREATE address from a plain contract's nonce. Predicting it
        // under vm.prank is unreliable: Foundry versions differ on whose nonce
        // a pranked `new` uses.
        VaultSeeder seeder = new VaultSeeder();
        token.mint(address(seeder), 1000);
        address predicted = vm.computeCreateAddress(address(seeder), vm.getNonce(address(seeder)));
        DeadSharesVault vault = seeder.deploy(token, predicted);
        assertEq(vault.totalSupply(), vault.DEAD_SHARES());

        Result memory r = _attack(IVault(address(vault)), VICTIM_DEPOSIT);
        _log("dead shares (1000), victim 9,000", r);
        assertEq(r.victimShares, 900);
        assertLt(r.attackerProfit, 0);
        // the victim still gives up a sliver to rounding (under 0.1% here)
        assertGt(r.victimPnl, -int256(VICTIM_DEPOSIT / 1000));
    }
}
