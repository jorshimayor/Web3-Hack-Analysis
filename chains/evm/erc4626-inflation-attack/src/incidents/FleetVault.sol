// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {ERC4626} from "@openzeppelin/contracts/token/ERC20/extensions/ERC4626.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/// @dev A strategy adapter ("Ark") that holds some strategy token and reports its value
///      at a fixed price. Stands in for the impaired Silo Ark in the Lazy Summer incident:
///      the token it holds is valued above what it can actually be sold for.
contract StaleArk {
    IERC20 public immutable strategyToken;
    uint256 public immutable pricePerToken; // in asset units, scaled 1e18. Stale on purpose.
    uint256 public depositCap;

    constructor(IERC20 strategyToken_, uint256 pricePerToken_) {
        strategyToken = strategyToken_;
        pricePerToken = pricePerToken_;
        depositCap = type(uint256).max;
    }

    function setDepositCap(uint256 cap) external {
        depositCap = cap;
    }

    /// Reports whatever sits at this address, at the stale price. A plain transfer counts.
    function totalAssets() external view returns (uint256) {
        return (strategyToken.balanceOf(address(this)) * pricePerToken) / 1e18;
    }
}

/// @dev Replicates the shape of the Lazy Summer FleetCommander (July 2026):
///      an ERC-4626 vault whose totalAssets() is the buffer plus the sum of every
///      ACTIVE ark's reported value. Capping an ark (depositCap = 0) does not remove
///      it from the active set, so its stale valuation still moves the share price.
///
///      Payouts come from the liquid buffer, never from the ark.
///      Unaudited teaching mock. Not the real contracts.
contract FleetVault is ERC4626 {
    StaleArk[] public activeArks;

    constructor(IERC20 asset_) ERC20("Fleet", "FLEET") ERC4626(asset_) {}

    function addArk(StaleArk ark) external {
        activeArks.push(ark);
    }

    /// The incomplete offboarding: cap it, leave it in the active set.
    function capArk(uint256 i) external {
        activeArks[i].setDepositCap(0);
    }

    /// The complete offboarding: drop it from the active set.
    function removeArk(uint256 i) external {
        activeArks[i] = activeArks[activeArks.length - 1];
        activeArks.pop();
    }

    function totalAssets() public view override returns (uint256 total) {
        total = IERC20(asset()).balanceOf(address(this)); // the buffer
        for (uint256 i; i < activeArks.length; i++) {
            total += activeArks[i].totalAssets();
        }
    }
}
