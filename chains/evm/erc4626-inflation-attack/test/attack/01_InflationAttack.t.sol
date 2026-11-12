// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {AttackBase, IVault} from "../helpers/AttackBase.sol";
import {NaiveVault} from "../../src/vaults/NaiveVault.sol";

/// The attack vector against an unprotected vault.
contract InflationAttackTest is AttackBase {
    /// Victim deposits less than the donation: 0 shares, total loss.
    function test_fullTheft() public {
        NaiveVault vault = new NaiveVault(token, false);
        Result memory r = _attack(IVault(address(vault)), VICTIM_DEPOSIT);
        _log("naive, victim 9,000", r);
        assertEq(r.victimShares, 0);
        assertEq(r.attackerOut, DONATION + 1 + VICTIM_DEPOSIT);
        assertEq(r.attackerProfit, int256(VICTIM_DEPOSIT));
    }

    /// Victim deposits more than the donation: 1 share, and still loses 2,500 to rounding.
    function test_partialTheft() public {
        NaiveVault vault = new NaiveVault(token, false);
        Result memory r = _attack(IVault(address(vault)), 15_000e18);
        _log("naive, victim 15,000", r);
        assertEq(r.victimShares, 1);
        assertEq(r.victimValue, 12_500e18 + 1);
        assertEq(r.attackerProfit, int256(2_500e18) - 1);
    }
}
