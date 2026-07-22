// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import { IMapleTradingStrategy } from "../../../contracts/interfaces/IMapleTradingStrategy.sol";

import { TestBase } from "../../utils/TestBase.sol";

contract SetYieldCapFailureTests is TestBase {

    uint256 oldYieldCap = 1_000_000e6;
    uint256 newYieldCap = 2_000_000e6;

    function test_setYieldCap_revert_functionPaused() external {
        globals.__setIsFunctionPaused(IMapleTradingStrategy.setYieldCap.selector, true);

        vm.prank(strategyDelegate);
        vm.expectRevert("MTS:PAUSED");
        strategy.setYieldCap(newYieldCap);
    }

    function test_setYieldCap_revert_reentrancy() external {
        strategy.__setLocked(2);

        vm.prank(strategyDelegate);
        vm.expectRevert("MTS:LOCKED");
        strategy.setYieldCap(newYieldCap);
    }

    function test_setYieldCap_revert_notAuthorized() external {
        vm.expectRevert("MTS:NOT_AUTHORIZED");
        strategy.setYieldCap(newYieldCap);
    }

    function test_setYieldCap_revert_noChange() external {
        vm.prank(strategyDelegate);
        vm.expectRevert("MTS:SYC:NO_CHANGE");
        strategy.setYieldCap(oldYieldCap);
    }

}

contract SetYieldCapSuccessTests is TestBase {

    uint256 oldYieldCap = 1_000_000e6;
    uint256 newYieldCap = 2_000_000e6;

    function test_setYieldCap_success_increase() external {
        assertEq(strategy.yieldCap(), oldYieldCap);

        vm.expectEmit();
        emit IMapleTradingStrategy.YieldCapSet(newYieldCap);

        vm.prank(strategyDelegate);
        strategy.setYieldCap(newYieldCap);

        assertEq(strategy.yieldCap(), newYieldCap);
    }

    function test_setYieldCap_success_decrease() external {
        strategy.__setYieldCap(newYieldCap);

        assertEq(strategy.yieldCap(), newYieldCap);

        vm.expectEmit();
        emit IMapleTradingStrategy.YieldCapSet(oldYieldCap);

        vm.prank(strategyDelegate);
        strategy.setYieldCap(oldYieldCap);

        assertEq(strategy.yieldCap(), oldYieldCap);
    }

    function test_setYieldCap_success_zeroCap() external {
        assertEq(strategy.yieldCap(), oldYieldCap);

        vm.expectEmit();
        emit IMapleTradingStrategy.YieldCapSet(0);

        vm.prank(strategyDelegate);
        strategy.setYieldCap(0);

        assertEq(strategy.yieldCap(), 0);
    }

    function test_setYieldCap_success_calledByOperationalAdmin() external {
        assertEq(strategy.yieldCap(), oldYieldCap);

        vm.expectEmit();
        emit IMapleTradingStrategy.YieldCapSet(newYieldCap);

        vm.prank(operationalAdmin);
        strategy.setYieldCap(newYieldCap);

        assertEq(strategy.yieldCap(), newYieldCap);
    }

}
