// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import { stdError } from "../../../modules/forge-std/src/StdError.sol";

import { TestBase } from "../../utils/TestBase.sol";

contract AvailableToWithdrawTests is TestBase {

    uint256 strategyBalance = 1_000_000e6;
    uint256 yieldAssets     = 625_000e6;

    function setUp() public override {
        super.setUp();

        asset.mint(address(strategy), strategyBalance);
    }

    function test_availableToWithdraw_zero() external {
        asset.burn(address(strategy), strategyBalance);

        assertEq(strategy.availableToWithdraw(), 0);
    }

    function test_availableToWithdraw_zero_dueToYieldBuffer() external {
        strategy.__setYieldBuffer(strategyBalance, startingTime, startingTime + 1 days);

        assertEq(strategy.availableToWithdraw(), 0);
    }

    function test_availableToWithdraw_noYieldBuffer() external view {
        assertEq(strategy.availableToWithdraw(), strategyBalance);
    }

    function test_availableToWithdraw_allUnrealized() external {
        strategy.__setYieldBuffer(yieldAssets, startingTime, startingTime + 1 days);

        assertEq(strategy.availableToWithdraw(), strategyBalance - yieldAssets);
    }

    function test_availableToWithdraw_partiallyRealized() external {
        strategy.__setYieldBuffer(yieldAssets, startingTime, startingTime + 3 days);

        vm.warp(startingTime + 2 days);

        uint256 realizedYield   = yieldAssets * 2 / 3;
        uint256 unrealizedYield = yieldAssets - realizedYield;

        assertEq(strategy.availableToWithdraw(), strategyBalance - unrealizedYield);
    }

    function test_availableToWithdraw_fullyRealized() external {
        strategy.__setYieldBuffer(yieldAssets, startingTime, startingTime + 1 days);

        vm.warp(startingTime + 1 days);

        assertEq(strategy.availableToWithdraw(), strategyBalance);
    }

    function test_availableToWithdraw_pastFullyRealized() external {
        strategy.__setYieldBuffer(yieldAssets, startingTime, startingTime + 1 days);

        vm.warp(startingTime + 3 days);

        assertEq(strategy.availableToWithdraw(), strategyBalance);
    }

    function test_availableToWithdraw_instantlyRealized() external {
        strategy.__setYieldBuffer(yieldAssets, startingTime, startingTime);

        assertEq(strategy.availableToWithdraw(), strategyBalance);
    }

    // NOTE: Unreachable since yield can't be withdrawn before it realizes.
    function test_availableToWithdraw_underflow() external {
        strategy.__setYieldBuffer(strategyBalance + 1, startingTime, startingTime + 1 days);

        vm.expectRevert(stdError.arithmeticError);
        strategy.availableToWithdraw();
    }

}
