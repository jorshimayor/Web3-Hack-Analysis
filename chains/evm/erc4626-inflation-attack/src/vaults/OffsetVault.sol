// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {ERC4626} from "@openzeppelin/contracts/token/ERC20/extensions/ERC4626.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/// @dev Defence 2: OpenZeppelin's virtual shares. OFFSET = 0 is the library
///      default; OFFSET = 6 is the override most teams forget. Unaudited, test only.
contract OffsetVault is ERC4626 {
    uint8 private immutable _offset;

    constructor(IERC20 asset_, uint8 offset_) ERC20("Offset Vault", "oVAULT") ERC4626(asset_) {
        _offset = offset_;
    }

    function _decimalsOffset() internal view override returns (uint8) {
        return _offset;
    }
}
