// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import { TestBase } from "../../utils/TestBase.sol";

contract GlobalsTests is TestBase {

    function test_globals_success() external view {
        assertEq(strategy.globals(), address(globals));
    }

}
