// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import { TestBase } from "../../utils/TestBase.sol";

contract ImplementationTests is TestBase {

    function test_implementation_success() external view {
        assertEq(strategy.implementation(), address(implementation));
    }

}
