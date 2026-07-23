// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import { TestBase } from "../../utils/TestBase.sol";

contract YieldCooldownTests is TestBase {

    function test_yieldCooldown_neverRealized() external view {
        assertEq(strategy.yieldCooldown(), 0);
    }

    function test_yieldCooldown_justRealized() external {
        strategy.__setYieldLastRealized(startingTime);

        assertEq(strategy.yieldCooldown(), 1 hours);
    }

    function test_yieldCooldown_partiallyElapsed() external {
        strategy.__setYieldLastRealized(startingTime);

        vm.warp(startingTime + 20 minutes);

        assertEq(strategy.yieldCooldown(), 40 minutes);
    }

    function test_yieldCooldown_oneSecondRemaining() external {
        strategy.__setYieldLastRealized(startingTime);

        vm.warp(startingTime + 1 hours - 1 seconds);

        assertEq(strategy.yieldCooldown(), 1 seconds);
    }

    function test_yieldCooldown_fullyElapsed() external {
        strategy.__setYieldLastRealized(startingTime);

        vm.warp(startingTime + 1 hours);

        assertEq(strategy.yieldCooldown(), 0);
    }

    function test_yieldCooldown_pastFullyElapsed() external {
        strategy.__setYieldLastRealized(startingTime);

        vm.warp(startingTime + 1 days);

        assertEq(strategy.yieldCooldown(), 0);
    }

}
