// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

/// @dev Minimal lender adapter: deposit the underlying, get a 1:1 receipt token,
///      redeem the receipt for the underlying. Stands in for Fulcrum/Aave style iTokens.
contract MockLender is ERC20 {
    using SafeERC20 for IERC20;

    IERC20 public immutable underlying;

    constructor(IERC20 underlying_, string memory name_) ERC20(name_, name_) {
        underlying = underlying_;
    }

    function mint(uint256 amount) external {
        underlying.safeTransferFrom(msg.sender, address(this), amount);
        _mint(msg.sender, amount);
    }

    function redeemAll() external returns (uint256 amount) {
        amount = balanceOf(msg.sender);
        _burn(msg.sender, amount);
        underlying.safeTransfer(msg.sender, amount);
    }
}

/// @dev Replicates the shape of the iearn yUSDT (April 2023) and yTUSD (December 2025)
///      incidents: a share vault whose pool value is the sum of its lender receipts,
///      with one lender slot hardcoded to a receipt token for the WRONG underlying.
///
///      - `goodLender` returns `asset` on redeem.
///      - `badLender` returns `wrongToken` on redeem, which the vault does not price.
///      - `rebalance()` is permissionless and redeems every lender position.
///
///      Unaudited teaching mock. Not the real contracts.
contract MisconfiguredLenderVault is ERC20 {
    using SafeERC20 for IERC20;

    IERC20 public immutable asset;
    MockLender public immutable goodLender; // correct underlying
    MockLender public immutable badLender; // misconfigured: wrong underlying

    constructor(IERC20 asset_, MockLender good_, MockLender bad_) ERC20("yVault", "yV") {
        asset = asset_;
        goodLender = good_;
        badLender = bad_;
    }

    /// Pool value counts the asset balance and every lender receipt at face value,
    /// including receipts of the misconfigured lender. Anything else is invisible.
    function calcPoolValueInToken() public view returns (uint256) {
        return asset.balanceOf(address(this)) + goodLender.balanceOf(address(this)) + badLender.balanceOf(address(this));
    }

    function getPricePerFullShare() external view returns (uint256) {
        return totalSupply() == 0 ? 1e18 : (calcPoolValueInToken() * 1e18) / totalSupply();
    }

    function deposit(uint256 amount) external returns (uint256 shares) {
        uint256 pool = calcPoolValueInToken();
        asset.safeTransferFrom(msg.sender, address(this), amount);
        shares = totalSupply() == 0 ? amount : (amount * totalSupply()) / pool;
        _mint(msg.sender, shares);
    }

    function withdraw(uint256 shares) external returns (uint256 amount) {
        amount = (calcPoolValueInToken() * shares) / totalSupply();
        _burn(msg.sender, shares);
        uint256 idle = asset.balanceOf(address(this));
        if (idle < amount) {
            // pull from the correct lender first
            goodLender.redeemAll();
            // re-lend what is not needed is omitted for brevity
        }
        asset.safeTransfer(msg.sender, amount);
    }

    /// Lend idle assets to the correct lender (what a keeper would do).
    function lendIdle() external {
        uint256 idle = asset.balanceOf(address(this));
        asset.forceApprove(address(goodLender), idle);
        goodLender.mint(idle);
    }

    /// Permissionless, like the original: redeem every lender position back to the vault.
    /// The bad lender hands back `wrongToken`, which calcPoolValueInToken() ignores.
    function rebalance() external {
        goodLender.redeemAll();
        badLender.redeemAll();
    }
}
