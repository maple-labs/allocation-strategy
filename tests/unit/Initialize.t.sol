// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import { IMapleTradingStrategyInitializer } from "../../contracts/interfaces/IMapleTradingStrategyInitializer.sol";

import { MapleTradingStrategyInitializerHarness } from "../utils/Harnesses.sol";
import { TestBase }                               from "../utils/TestBase.sol";

contract InitializeTests is TestBase {

    MapleTradingStrategyInitializerHarness proxy = MapleTradingStrategyInitializerHarness(initializer);

    function test_initialize_success() external {
        vm.expectEmit();
        emit IMapleTradingStrategyInitializer.Initialized(params);

        vm.prank(address(factory));
        proxy.__initialize(params);

        assertEq(proxy.manager(), address(manager));
    }

}
