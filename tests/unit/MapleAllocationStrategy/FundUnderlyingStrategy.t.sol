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
        asset.mint(address(strategy), assetsIn);

        assertEq(asset.balanceOf(address(strategy)), assetsIn);

        assertEq(strategy.recordedAssets(),        0);
        assertEq(strategy.unrecordedAssets(),      assetsIn);
        assertEq(strategy.availableToWithdraw(),   0);
        assertEq(strategy.assetsUnderManagement(), 0);

        vm.expectEmit();
        emit IMapleAllocationStrategy.StrategyFunded(address(manager), assetsIn, assetsIn);

        vm.prank(address(manager));
        uint256 assetsOut = strategy.fundUnderlyingStrategy(assetsIn, "");

        assertEq(assetsOut, assetsIn);

        assertEq(asset.balanceOf(address(strategy)), assetsIn);

        assertEq(strategy.recordedAssets(),        assetsIn);
        assertEq(strategy.unrecordedAssets(),      0);
        assertEq(strategy.availableToWithdraw(),   assetsIn);
        assertEq(strategy.assetsUnderManagement(), assetsIn);
    }

    function test_fundUnderlyingStrategy_success_multipleFundings() external {
        asset.mint(address(strategy), assetsIn * 2);

        assertEq(asset.balanceOf(address(strategy)), assetsIn * 2);

        assertEq(strategy.recordedAssets(),        0);
        assertEq(strategy.unrecordedAssets(),      assetsIn * 2);
        assertEq(strategy.availableToWithdraw(),   0);
        assertEq(strategy.assetsUnderManagement(), 0);

        vm.prank(address(manager));
        strategy.fundUnderlyingStrategy(assetsIn, "");

        assertEq(asset.balanceOf(address(strategy)), assetsIn * 2);

        assertEq(strategy.recordedAssets(),        assetsIn);
        assertEq(strategy.unrecordedAssets(),      assetsIn);
        assertEq(strategy.availableToWithdraw(),   assetsIn);
        assertEq(strategy.assetsUnderManagement(), assetsIn);

        vm.prank(address(manager));
        strategy.fundUnderlyingStrategy(assetsIn, "");

        assertEq(asset.balanceOf(address(strategy)), assetsIn * 2);

        assertEq(strategy.recordedAssets(),        assetsIn * 2);
        assertEq(strategy.unrecordedAssets(),      0);
        assertEq(strategy.availableToWithdraw(),   assetsIn * 2);
        assertEq(strategy.assetsUnderManagement(), assetsIn * 2);
    }

}
