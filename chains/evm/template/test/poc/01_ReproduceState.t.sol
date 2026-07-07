// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {BaseForkTest} from "../helpers/BaseForkTest.sol";

contract ReproduceStateTest is BaseForkTest {
    function setUp() public {
        createFork("mainnet", 0);
    }

    function testScaffold() public {
        assertTrue(true);
    }
}
