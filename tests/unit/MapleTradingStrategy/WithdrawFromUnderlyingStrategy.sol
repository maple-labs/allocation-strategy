// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import { IMapleTradingStrategy } from "../../../contracts/interfaces/IMapleTradingStrategy.sol";

import { MapleTradingStrategy } from "../../../contracts/MapleTradingStrategy.sol";

import { TestBase } from "../../utils/TestBase.sol";

contract WithdrawFromUnderlyingStrategyTests is TestBase {

    address destination = makeAddr("destination");

    uint256 assets = 1_000e6;

    function setUp() public override {
        super.setUp();

        asset.mint(address(strategy), assets);
    }

    function test_withdrawFromUnderlyingStrategy_revert_functionPaused() external {
        globals.__setIsFunctionPaused(MapleTradingStrategy.withdrawFromUnderlyingStrategy.selector, true);

        vm.prank(address(manager));
        vm.expectRevert("MTS:PAUSED");
        strategy.withdrawFromUnderlyingStrategy(destination, assets);
    }

    function test_withdrawFromUnderlyingStrategy_revert_reentrancy() external {
        strategy.__setLocked(2);

        vm.prank(address(manager));
        vm.expectRevert("MTS:LOCKED");
        strategy.withdrawFromUnderlyingStrategy(destination, assets);
    }

    function test_withdrawFromUnderlyingStrategy_revert_notStrategyManager() external {
        vm.expectRevert("MTS:NOT_STRATEGY_MANAGER");
        strategy.withdrawFromUnderlyingStrategy(destination, assets);
    }

    function test_withdrawFromUnderlyingStrategy_revert_transferFailed() external {
        asset.__setTransferReverts(true);

        vm.prank(address(manager));
        vm.expectRevert("MTS:WFUS:TRANSFER_FAILED");
        strategy.withdrawFromUnderlyingStrategy(destination, assets);
    }

    function test_withdrawFromUnderlyingStrategy_revert_transferUnderflow() external {
        asset.burn(address(strategy), 1);

        vm.prank(address(manager));
        vm.expectRevert("MTS:WFUS:TRANSFER_FAILED");
        strategy.withdrawFromUnderlyingStrategy(destination, assets);
    }

    function test_withdrawFromUnderlyingStrategy_success_partialWithdrawal() external {
        uint256 withdrawalAmount = assets / 3;

        assertEq(asset.balanceOf(address(strategy)), assets);
        assertEq(asset.balanceOf(destination),       0);

        vm.expectEmit();
        emit IMapleTradingStrategy.StrategyWithdrawn(address(manager), destination, withdrawalAmount);

        vm.prank(address(manager));
        strategy.withdrawFromUnderlyingStrategy(destination, withdrawalAmount);

        assertEq(asset.balanceOf(address(strategy)), assets - withdrawalAmount);
        assertEq(asset.balanceOf(destination),       withdrawalAmount);
    }

    function test_withdrawFromUnderlyingStrategy_success_fullWithdrawal() external {
        assertEq(asset.balanceOf(address(strategy)), assets);
        assertEq(asset.balanceOf(destination),       0);

        vm.expectEmit();
        emit IMapleTradingStrategy.StrategyWithdrawn(address(manager), destination, assets);

        vm.prank(address(manager));
        strategy.withdrawFromUnderlyingStrategy(destination, assets);

        assertEq(asset.balanceOf(address(strategy)), 0);
        assertEq(asset.balanceOf(destination),       assets);
    }

}
