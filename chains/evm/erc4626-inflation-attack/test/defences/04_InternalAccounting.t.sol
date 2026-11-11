// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {AttackBase, IVault} from "../helpers/AttackBase.sol";
import {InternalAccountingVault} from "../../src/vaults/InternalAccountingVault.sol";

/// Defence 3: totalAssets() is a tracked variable, so the donation never enters the formula.
contract InternalAccountingTest is AttackBase {
    function test_internalAccounting() public {
        InternalAccountingVault vault = new InternalAccountingVault(token);
        Result memory r = _attack(IVault(address(vault)), VICTIM_DEPOSIT);
        _log("internal accounting, victim 9,000", r);
        assertEq(r.victimPnl, 0);
        assertEq(r.attackerOut, 1);
        assertEq(r.attackerProfit, -int256(DONATION));
    }
}
