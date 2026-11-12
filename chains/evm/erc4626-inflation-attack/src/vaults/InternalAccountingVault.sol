// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {ERC4626} from "@openzeppelin/contracts/token/ERC20/extensions/ERC4626.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/// @dev Defence 3: totalAssets() returns a storage variable that only the
///      deposit and withdraw paths update, so a plain transfer to the vault
///      changes the balance and nothing else. Offset left at the default 0 on
///      purpose, to isolate the effect of internal accounting. Unaudited, test only.
contract InternalAccountingVault is ERC4626 {
    uint256 private _accountedAssets;

    constructor(IERC20 asset_) ERC20("Accounted Vault", "aVAULT") ERC4626(asset_) {}

    function totalAssets() public view override returns (uint256) {
        return _accountedAssets;
    }

    function _deposit(address caller, address receiver, uint256 assets, uint256 shares) internal override {
        super._deposit(caller, receiver, assets, shares);
        _accountedAssets += assets;
    }

    function _withdraw(address caller, address receiver, address owner, uint256 assets, uint256 shares)
        internal
        override
    {
        _accountedAssets -= assets;
        super._withdraw(caller, receiver, owner, assets, shares);
    }
}
