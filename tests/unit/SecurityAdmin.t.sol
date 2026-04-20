// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import { TestBase } from "../utils/TestBase.sol";

contract SecurityAdminTests is TestBase {

    function test_securityAdmin_success() external view {
        assertEq(strategy.securityAdmin(), address(securityAdmin));
    }

}
