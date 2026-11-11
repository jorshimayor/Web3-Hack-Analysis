// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {AttackBase, IVault} from "../helpers/AttackBase.sol";
import {DeadSharesVault} from "../../src/vaults/DeadSharesVault.sol";

/// Defence 1: seed deposit at deployment, shares burned to 0xdead (Uniswap V2 style).
contract DeadSharesTest is AttackBase {
    function test_deadShares() public {
        vm.startPrank(deployer);
        address predicted = vm.computeCreateAddress(deployer, vm.getNonce(deployer));
        token.approve(predicted, 1000);
        DeadSharesVault vault = new DeadSharesVault(token);
        vm.stopPrank();

        Result memory r = _attack(IVault(address(vault)), VICTIM_DEPOSIT);
        _log("dead shares (1000), victim 9,000", r);
        assertEq(r.victimShares, 900);
        assertLt(r.attackerProfit, 0);
        // the victim still gives up a sliver to rounding (under 0.1% here)
        assertGt(r.victimPnl, -int256(VICTIM_DEPOSIT / 1000));
    }
}
