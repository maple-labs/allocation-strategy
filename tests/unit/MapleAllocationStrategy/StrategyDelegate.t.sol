// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import { TestBase } from "../../utils/TestBase.sol";

contract StrategyDelegateTests is TestBase {

    function test_strategyDelegate_success() external view {
        assertEq(strategy.strategyDelegate(), strategyDelegate);
    }

    function test_strategyDelegate_changed() external {
        assertEq(strategy.strategyDelegate(), strategyDelegate);

        address newStrategyDelegate = makeAddr("newStrategyDelegate");

        manager.__setStrategyDelegate(newStrategyDelegate);

        assertEq(strategy.strategyDelegate(), newStrategyDelegate);
    }

}
