// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import { IMapleAllocationStrategy } from "../../../contracts/interfaces/IMapleAllocationStrategy.sol";

import { MapleAllocationStrategy } from "../../../contracts/MapleAllocationStrategy.sol";

import { TestBase } from "../../utils/TestBase.sol";

contract FundUnderlyingStrategyTests is TestBase {

    uint256 assetsIn = 1_000e6;

    function test_fundUnderlyingStrategy_revert_functionPaused() external {
        globals.__setIsFunctionPaused(MapleAllocationStrategy.fundUnderlyingStrategy.selector, true);

        vm.prank(address(manager));
        vm.expectRevert("MAS:PAUSED");
        strategy.fundUnderlyingStrategy(assetsIn, "");
    }

    function test_fundUnderlyingStrategy_revert_reentrancy() external {
        strategy.__setLocked(2);

        vm.prank(address(manager));
        vm.expectRevert("MAS:LOCKED");
        strategy.fundUnderlyingStrategy(assetsIn, "");
    }

    function test_fundUnderlyingStrategy_revert_notStrategyManager() external {
        vm.expectRevert("MAS:NOT_STRATEGY_MANAGER");
        strategy.fundUnderlyingStrategy(assetsIn, "");
    }

    function test_fundUnderlyingStrategy_success() external {
        vm.expectEmit();
        emit IMapleAllocationStrategy.StrategyFunded(address(manager), assetsIn);

        vm.prank(address(manager));
        uint256 assetsOut = strategy.fundUnderlyingStrategy(assetsIn, "");

        assertEq(assetsOut, assetsIn);
    }

}
