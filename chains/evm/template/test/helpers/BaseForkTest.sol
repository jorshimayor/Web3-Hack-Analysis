// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";

abstract contract BaseForkTest is Test {
    function createFork(string memory alias_, uint256 blockNumber_) internal {
        if (blockNumber_ == 0) {
            vm.createSelectFork(alias_);
            return;
        }

        vm.createSelectFork(alias_, blockNumber_);
    }
}
