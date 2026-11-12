// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

/// @dev The textbook vulnerable vault. No virtual shares, no seed, and
///      totalAssets() reads the live token balance. Unaudited, test only.
contract NaiveVault is ERC20 {
    using SafeERC20 for IERC20;

    IERC20 public immutable asset;
    bool public immutable revertOnZeroShares;

    constructor(IERC20 asset_, bool revertOnZeroShares_) ERC20("Naive Vault", "nVAULT") {
        asset = asset_;
        revertOnZeroShares = revertOnZeroShares_;
    }

    function totalAssets() public view returns (uint256) {
        return asset.balanceOf(address(this));
    }

    function convertToShares(uint256 assets) public view returns (uint256) {
        uint256 supply = totalSupply();
        return supply == 0 ? assets : (assets * supply) / totalAssets();
    }

    function convertToAssets(uint256 shares) public view returns (uint256) {
        uint256 supply = totalSupply();
        return supply == 0 ? shares : (shares * totalAssets()) / supply;
    }

    function deposit(uint256 assets, address receiver) external returns (uint256 shares) {
        shares = convertToShares(assets);
        if (revertOnZeroShares) require(shares != 0, "ZERO_SHARES");
        asset.safeTransferFrom(msg.sender, address(this), assets);
        _mint(receiver, shares);
    }

    function redeem(uint256 shares, address receiver, address owner) external returns (uint256 assets) {
        require(msg.sender == owner, "NOT_OWNER");
        assets = convertToAssets(shares);
        _burn(owner, shares);
        asset.safeTransfer(receiver, assets);
    }
}
