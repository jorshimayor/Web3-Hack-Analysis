// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {BaseForkTest} from "../helpers/BaseForkTest.sol";
import {Belong} from "../../src/target/Belong.sol";

contract BelongReproduceStateTest is BaseForkTest {
    function setUp() public {
        createFork("mainnet", 0);
    }

    function testScaffold() public {
        Belong target = new Belong();
        assertEq(target.name(), "Belong");
    }
}
