// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {NaiveVault} from "./NaiveVault.sol";

/// @dev Defence 1: the Uniswap V2 approach. The deployer makes a real seed
///      deposit in the constructor and its shares go to a dead address, so
///      totalSupply() never drops below DEAD_SHARES. Unaudited, test only.
contract DeadSharesVault is NaiveVault {
    using SafeERC20 for IERC20;

    address public constant DEAD = 0x000000000000000000000000000000000000dEaD;
    uint256 public constant DEAD_SHARES = 1000;

    constructor(IERC20 asset_) NaiveVault(asset_, false) {
        // First deposit mints 1:1, so DEAD_SHARES wei of asset buys DEAD_SHARES shares.
        asset_.safeTransferFrom(msg.sender, address(this), DEAD_SHARES);
        _mint(DEAD, DEAD_SHARES);
    }
}
