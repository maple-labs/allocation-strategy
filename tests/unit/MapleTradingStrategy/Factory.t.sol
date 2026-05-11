// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import { TestBase } from "../../utils/TestBase.sol";

contract FactoryTests is TestBase {

    function test_factory_success() external view {
        assertEq(strategy.factory(), address(factory));
    }

}
