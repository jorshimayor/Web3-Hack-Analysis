// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {AttackBase, IVault} from "../helpers/AttackBase.sol";
import {OffsetVault} from "../../src/vaults/OffsetVault.sol";

/// Defence 2: OpenZeppelin virtual shares. Offset 0 is the library default.
contract VirtualSharesTest is AttackBase {
    /// Default offset: attacker loses, but the victim still loses 29.6%.
    function test_offset0_default_victimStillLoses() public {
        OffsetVault vault = new OffsetVault(token, 0);
        Result memory r = _attack(IVault(address(vault)), VICTIM_DEPOSIT);
        _log("OZ offset 0 (default), victim 9,000", r);
        assertLt(r.attackerProfit, 0);
        assertLt(r.victimPnl, -int256(VICTIM_DEPOSIT / 4)); // worse than a 25% loss
    }

    /// Offset 6: the override that makes the defence hold.
    function test_offset6_holds() public {
        OffsetVault vault = new OffsetVault(token, 6);
        Result memory r = _attack(IVault(address(vault)), VICTIM_DEPOSIT);
        _log("OZ offset 6, victim 9,000", r);
        assertLt(r.attackerProfit, 0);
        assertGt(r.victimShares, 1_000_000);
        assertGt(r.victimPnl, -1e16); // under 0.01 tokens lost
    }
}
