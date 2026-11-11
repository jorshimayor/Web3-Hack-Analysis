// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

/// @dev Replicates the shape of the Thetanuts legacy index token (June 2026):
///      an index share redeemable pro rata for a basket of component tokens, where
///      `mint` computes each required component as basket × amount / supply and
///      never checks that the requirement is non-zero.
///
///      Unaudited teaching mock. Not the real contract.
contract BasketIndexToken is ERC20 {
    using SafeERC20 for IERC20;

    IERC20[] public basket;
    bool public immutable rejectZeroBacking; // the one-line fix, off in the vulnerable version

    constructor(IERC20[] memory basket_, bool rejectZeroBacking_) ERC20("Index", "IDX") {
        basket = basket_;
        rejectZeroBacking = rejectZeroBacking_;
    }

    /// Seed: deposit the full basket once and mint the initial supply 1:1 with component 0.
    function seed(uint256[] calldata amounts, uint256 initialSupply) external {
        require(totalSupply() == 0, "SEEDED");
        for (uint256 i; i < basket.length; i++) {
            basket[i].safeTransferFrom(msg.sender, address(this), amounts[i]);
        }
        _mint(msg.sender, initialSupply);
    }

    /// Burn index tokens, receive each component pro rata.
    function claim(uint256 amount) external {
        uint256 supplyBefore = totalSupply();
        _burn(msg.sender, amount);
        for (uint256 i; i < basket.length; i++) {
            uint256 payout = (basket[i].balanceOf(address(this)) * amount) / supplyBefore;
            basket[i].safeTransfer(msg.sender, payout);
        }
    }

    /// Pull each component in proportion to the new supply, then mint.
    /// BUG: when the basket is empty, every `required` rounds to zero and the mint still succeeds.
    function mint(uint256 amount) external {
        uint256 supply = totalSupply();
        for (uint256 i; i < basket.length; i++) {
            uint256 required = supply == 0 ? amount : (basket[i].balanceOf(address(this)) * amount) / supply;
            if (rejectZeroBacking) require(required > 0, "ZERO_BACKING");
            if (required > 0) basket[i].safeTransferFrom(msg.sender, address(this), required);
        }
        _mint(msg.sender, amount);
    }
}
