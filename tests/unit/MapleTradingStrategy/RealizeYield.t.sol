// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import { IMapleTradingStrategy } from "../../../contracts/interfaces/IMapleTradingStrategy.sol";

import { TestBase } from "../../utils/TestBase.sol";

contract RealizeYieldTestBase is TestBase {

    address tradingAddress = makeAddr("tradingAddress");

    uint256 newYieldAmount       = 75_000e6;  // Amount of yield to realize during the test.
    uint256 strategyBalance      = 30_000e6;  // Amount of cash sitting in the strategy initially.
    uint256 scheduledYieldAssets = 25_000e6;  // Amount of yield assets in the initial buffer.
    uint256 tinyYieldAmount      = 33;        // Amount of yield which will round fees down to zero.

    uint32 newYieldDuration = 0.5 days;  // Duration over which yield will be realized during the test.
    uint32 yieldDuration    = 3 days;    // Duration over which the initial buffer will be fully realized.

    uint32 delegateFeeRate = 0.02e6;  // Delegate fee rate: 2%
    uint32 protocolFeeRate = 0.03e6;  // Protocol fee rate: 3%

    uint32 yieldStart;     // Timestamp at which the initial yield buffer will be set.
    uint32 yieldAccruing;  // Timestamp at which a portion of the initial buffer will be realized.
    uint32 yieldDeadline;  // Timestamp at which the entire initial buffer will be realized.
    uint32 yieldFinished;  // Timestamp past the point at which the entire initial buffer will be realized.

    function setUp() public override {
        super.setUp();

        // Whitelist the trading address.
        globals.__setIsGovernedInstanceOf("TRADING_ADDRESS", tradingAddress, true);
        strategy.__setPermissions(tradingAddress, true);

        // Set the initial yield buffer to accrue over 3 days.
        yieldStart    = startingTime;
        yieldAccruing = startingTime + yieldDuration - 1 days;
        yieldDeadline = startingTime + yieldDuration;
        yieldFinished = startingTime + yieldDuration + 1 days;

        // Assert initial state.
        assertEq(asset.balanceOf(address(strategy)),         0);
        assertEq(asset.balanceOf(address(tradingAddress)),   0);
        assertEq(asset.balanceOf(address(strategyDelegate)), 0);
        assertEq(asset.balanceOf(address(mapleTreasury)),    0);

        assertEq(strategy.scheduledYieldAssets(), 0);
        assertEq(strategy.yieldStart(),           0);
        assertEq(strategy.yieldDeadline(),        0);

        assertEq(strategy.realizedAssets(),      0);
        assertEq(strategy.unrealizedAssets(),    0);
        assertEq(strategy.availableToWithdraw(), 0);

        // Prepare assets for the trading address and the strategy.
        asset.mint(address(strategy),       strategyBalance - scheduledYieldAssets);
        asset.mint(address(tradingAddress), scheduledYieldAssets + newYieldAmount);

        vm.prank(tradingAddress);
        asset.approve(address(strategy), type(uint256).max);

        // Set up the initial yield buffer without fees.
        strategy.__setFeeRates(0, 0);

        vm.prank(tradingAddress);
        strategy.realizeYield(scheduledYieldAssets, yieldDuration, "GG");
        strategy.__setFeeRates(delegateFeeRate, protocolFeeRate);

        // Assert state after setup.
        assertEq(asset.balanceOf(address(strategy)),         strategyBalance);
        assertEq(asset.balanceOf(address(tradingAddress)),   newYieldAmount);
        assertEq(asset.balanceOf(address(strategyDelegate)), 0);
        assertEq(asset.balanceOf(address(mapleTreasury)),    0);

        assertEq(strategy.scheduledYieldAssets(), scheduledYieldAssets);
        assertEq(strategy.yieldStart(),           yieldStart);
        assertEq(strategy.yieldDeadline(),        yieldDeadline);

        assertEq(strategy.realizedAssets(),      0);
        assertEq(strategy.unrealizedAssets(),    scheduledYieldAssets);
        assertEq(strategy.availableToWithdraw(), strategyBalance - scheduledYieldAssets);
    }

}

contract RealizeYieldFailureTests is RealizeYieldTestBase {

    function test_realizeYield_revert_functionPaused() external {
        globals.__setIsFunctionPaused(IMapleTradingStrategy.realizeYield.selector, true);

        vm.prank(tradingAddress);
        vm.expectRevert("MTS:PAUSED");
        strategy.realizeYield(newYieldAmount, newYieldDuration, "");
    }

    function test_realizeYield_revert_reentrancy() external {
        strategy.__setLocked(2);

        vm.prank(tradingAddress);
        vm.expectRevert("MTS:LOCKED");
        strategy.realizeYield(newYieldAmount, newYieldDuration, "");
    }

    function test_realizeYield_revert_notTradingAddress() external {
        globals.__setIsGovernedInstanceOf("TRADING_ADDRESS", tradingAddress, false);

        vm.prank(tradingAddress);
        vm.expectRevert("MTS:RY:NOT_TRADING_ADDRESS");
        strategy.realizeYield(newYieldAmount, newYieldDuration, "");
    }

    function test_realizeYield_revert_notAllowed() external {
        strategy.__setPermissions(tradingAddress, false);

        vm.prank(tradingAddress);
        vm.expectRevert("MTS:RY:NOT_ALLOWED");
        strategy.realizeYield(newYieldAmount, newYieldDuration, "");
    }

    function test_realizeYield_revert_transferFromFailed() external {
        asset.__setTransferFromReverts(true);

        vm.prank(tradingAddress);
        vm.expectRevert("MTS:RY:TRANSFER_FROM_FAILED");
        strategy.realizeYield(newYieldAmount, newYieldDuration, "");
    }

    function test_realizeYield_revert_delegateFeeTransferFailed() external {
        strategy.__setFeeRates(delegateFeeRate, 0);
        asset.__setTransferReverts(true);

        vm.prank(tradingAddress);
        vm.expectRevert("MTS:CF:DELEGATE_TRANSFER_FAILED");
        strategy.realizeYield(newYieldAmount, newYieldDuration, "");
    }

    function test_realizeYield_revert_protocolFeeTransferFailed() external {
        strategy.__setFeeRates(0, protocolFeeRate);
        asset.__setTransferReverts(true);

        vm.prank(tradingAddress);
        vm.expectRevert("MTS:CF:PROTOCOL_TRANSFER_FAILED");
        strategy.realizeYield(newYieldAmount, newYieldDuration, "");
    }

}

contract RealizeYieldSuccessTests is RealizeYieldTestBase {

    /**************************************************************************************************************************************/
    /*** Zero Yield — Zero Duration - With Fees                                                                                         ***/
    /**************************************************************************************************************************************/

    function test_realizeYield_success_zeroYield_zeroDuration_withFees_noBuffer() external {
        vm.prank(tradingAddress);
        strategy.realizeYield(0, 0, "FLUSH");

        assertEq(asset.balanceOf(address(strategy)),         strategyBalance);
        assertEq(asset.balanceOf(address(tradingAddress)),   newYieldAmount);
        assertEq(asset.balanceOf(address(strategyDelegate)), 0);
        assertEq(asset.balanceOf(address(mapleTreasury)),    0);

        assertEq(strategy.scheduledYieldAssets(), scheduledYieldAssets);
        assertEq(strategy.yieldStart(),           yieldStart);
        assertEq(strategy.yieldDeadline(),        yieldStart);

        assertEq(strategy.realizedAssets(),        scheduledYieldAssets);
        assertEq(strategy.unrealizedAssets(),      0);
        assertEq(strategy.availableToWithdraw(),   strategyBalance);
        assertEq(strategy.assetsUnderManagement(), strategyBalance);

        vm.expectEmit();
        emit IMapleTradingStrategy.YieldRealized(tradingAddress, 0, 0, 0, 0, 0, "");

        vm.prank(tradingAddress);
        strategy.realizeYield(0, 0, "");

        assertEq(asset.balanceOf(address(strategy)),         strategyBalance);
        assertEq(asset.balanceOf(address(tradingAddress)),   newYieldAmount);
        assertEq(asset.balanceOf(address(strategyDelegate)), 0);
        assertEq(asset.balanceOf(address(mapleTreasury)),    0);

        assertEq(strategy.scheduledYieldAssets(), 0);
        assertEq(strategy.yieldStart(),           yieldStart);
        assertEq(strategy.yieldDeadline(),        yieldStart);

        assertEq(strategy.realizedAssets(),        0);
        assertEq(strategy.unrealizedAssets(),      0);
        assertEq(strategy.availableToWithdraw(),   strategyBalance);
        assertEq(strategy.assetsUnderManagement(), strategyBalance);
    }

    function test_realizeYield_success_zeroYield_zeroDuration_withFees_bufferAtStart() external {
        assertEq(asset.balanceOf(address(strategy)),         strategyBalance);
        assertEq(asset.balanceOf(address(tradingAddress)),   newYieldAmount);
        assertEq(asset.balanceOf(address(strategyDelegate)), 0);
        assertEq(asset.balanceOf(address(mapleTreasury)),    0);

        assertEq(strategy.scheduledYieldAssets(), scheduledYieldAssets);
        assertEq(strategy.yieldStart(),           yieldStart);
        assertEq(strategy.yieldDeadline(),        yieldDeadline);

        assertEq(strategy.realizedAssets(),        0);
        assertEq(strategy.unrealizedAssets(),      scheduledYieldAssets);
        assertEq(strategy.availableToWithdraw(),   strategyBalance - scheduledYieldAssets);
        assertEq(strategy.assetsUnderManagement(), strategyBalance - scheduledYieldAssets);

        vm.expectEmit();
        emit IMapleTradingStrategy.YieldRealized(tradingAddress, scheduledYieldAssets, 0, 0, 0, 0, "");

        vm.prank(tradingAddress);
        strategy.realizeYield(0, 0, "");

        assertEq(asset.balanceOf(address(strategy)),         strategyBalance);
        assertEq(asset.balanceOf(address(tradingAddress)),   newYieldAmount);
        assertEq(asset.balanceOf(address(strategyDelegate)), 0);
        assertEq(asset.balanceOf(address(mapleTreasury)),    0);

        assertEq(strategy.scheduledYieldAssets(), scheduledYieldAssets);
        assertEq(strategy.yieldStart(),           yieldStart);
        assertEq(strategy.yieldDeadline(),        yieldStart);

        assertEq(strategy.realizedAssets(),        scheduledYieldAssets);
        assertEq(strategy.unrealizedAssets(),      0);
        assertEq(strategy.availableToWithdraw(),   strategyBalance);
        assertEq(strategy.assetsUnderManagement(), strategyBalance);
    }

    function test_realizeYield_success_zeroYield_zeroDuration_withFees_bufferAccruing() external {
        uint256 elapsedDuration  = yieldAccruing - yieldStart;
        uint256 totalDuration    = yieldDeadline - yieldStart;

        uint256 realizedAssets   = scheduledYieldAssets * elapsedDuration / totalDuration;
        uint256 unrealizedAssets = scheduledYieldAssets - realizedAssets;

        vm.warp(yieldAccruing);

        assertEq(asset.balanceOf(address(strategy)),         strategyBalance);
        assertEq(asset.balanceOf(address(tradingAddress)),   newYieldAmount);
        assertEq(asset.balanceOf(address(strategyDelegate)), 0);
        assertEq(asset.balanceOf(address(mapleTreasury)),    0);

        assertEq(strategy.scheduledYieldAssets(), scheduledYieldAssets);
        assertEq(strategy.yieldStart(),           yieldStart);
        assertEq(strategy.yieldDeadline(),        yieldDeadline);

        assertEq(strategy.realizedAssets(),        realizedAssets);
        assertEq(strategy.unrealizedAssets(),      unrealizedAssets);
        assertEq(strategy.availableToWithdraw(),   strategyBalance - unrealizedAssets);
        assertEq(strategy.assetsUnderManagement(), strategyBalance - unrealizedAssets);

        vm.expectEmit();
        emit IMapleTradingStrategy.YieldRealized(tradingAddress, unrealizedAssets, 0, 0, 0, 0, "");

        vm.prank(tradingAddress);
        strategy.realizeYield(0, 0, "");

        assertEq(asset.balanceOf(address(strategy)),         strategyBalance);
        assertEq(asset.balanceOf(address(tradingAddress)),   newYieldAmount);
        assertEq(asset.balanceOf(address(strategyDelegate)), 0);
        assertEq(asset.balanceOf(address(mapleTreasury)),    0);

        assertEq(strategy.scheduledYieldAssets(), unrealizedAssets);
        assertEq(strategy.yieldStart(),           yieldAccruing);
        assertEq(strategy.yieldDeadline(),        yieldAccruing);

        assertEq(strategy.realizedAssets(),        unrealizedAssets);
        assertEq(strategy.unrealizedAssets(),      0);
        assertEq(strategy.availableToWithdraw(),   strategyBalance);
        assertEq(strategy.assetsUnderManagement(), strategyBalance);
    }

    function test_realizeYield_success_zeroYield_zeroDuration_withFees_bufferAtDeadline() external {
        vm.warp(yieldDeadline);

        assertEq(asset.balanceOf(address(strategy)),         strategyBalance);
        assertEq(asset.balanceOf(address(tradingAddress)),   newYieldAmount);
        assertEq(asset.balanceOf(address(strategyDelegate)), 0);
        assertEq(asset.balanceOf(address(mapleTreasury)),    0);

        assertEq(strategy.scheduledYieldAssets(), scheduledYieldAssets);
        assertEq(strategy.yieldStart(),           yieldStart);
        assertEq(strategy.yieldDeadline(),        yieldDeadline);

        assertEq(strategy.realizedAssets(),      scheduledYieldAssets);
        assertEq(strategy.unrealizedAssets(),    0);
        assertEq(strategy.availableToWithdraw(), strategyBalance);

        vm.expectEmit();
        emit IMapleTradingStrategy.YieldRealized(tradingAddress, 0, 0, 0, 0, 0, "");

        vm.prank(tradingAddress);
        strategy.realizeYield(0, 0, "");

        assertEq(asset.balanceOf(address(strategy)),         strategyBalance);
        assertEq(asset.balanceOf(address(tradingAddress)),   newYieldAmount);
        assertEq(asset.balanceOf(address(strategyDelegate)), 0);
        assertEq(asset.balanceOf(address(mapleTreasury)),    0);

        assertEq(strategy.scheduledYieldAssets(), 0);
        assertEq(strategy.yieldStart(),           yieldDeadline);
        assertEq(strategy.yieldDeadline(),        yieldDeadline);

        assertEq(strategy.realizedAssets(),      0);
        assertEq(strategy.unrealizedAssets(),    0);
        assertEq(strategy.availableToWithdraw(), strategyBalance);
    }

    function test_realizeYield_success_zeroYield_zeroDuration_withFees_bufferPastDeadline() external {
        vm.warp(yieldFinished);

        assertEq(asset.balanceOf(address(strategy)),         strategyBalance);
        assertEq(asset.balanceOf(address(tradingAddress)),   newYieldAmount);
        assertEq(asset.balanceOf(address(strategyDelegate)), 0);
        assertEq(asset.balanceOf(address(mapleTreasury)),    0);

        assertEq(strategy.scheduledYieldAssets(), scheduledYieldAssets);
        assertEq(strategy.yieldStart(),           yieldStart);
        assertEq(strategy.yieldDeadline(),        yieldDeadline);

        assertEq(strategy.realizedAssets(),        scheduledYieldAssets);
        assertEq(strategy.unrealizedAssets(),      0);
        assertEq(strategy.availableToWithdraw(),   strategyBalance);
        assertEq(strategy.assetsUnderManagement(), strategyBalance);

        vm.expectEmit();
        emit IMapleTradingStrategy.YieldRealized(tradingAddress, 0, 0, 0, 0, 0, "");

        vm.prank(tradingAddress);
        strategy.realizeYield(0, 0, "");

        assertEq(asset.balanceOf(address(strategy)),         strategyBalance);
        assertEq(asset.balanceOf(address(tradingAddress)),   newYieldAmount);
        assertEq(asset.balanceOf(address(strategyDelegate)), 0);
        assertEq(asset.balanceOf(address(mapleTreasury)),    0);

        assertEq(strategy.scheduledYieldAssets(), 0);
        assertEq(strategy.yieldStart(),           yieldFinished);
        assertEq(strategy.yieldDeadline(),        yieldFinished);

        assertEq(strategy.realizedAssets(),        0);
        assertEq(strategy.unrealizedAssets(),      0);
        assertEq(strategy.availableToWithdraw(),   strategyBalance);
        assertEq(strategy.assetsUnderManagement(), strategyBalance);
    }

    /**************************************************************************************************************************************/
    /*** Zero Yield — Non-Zero Duration — With Fees                                                                                     ***/
    /**************************************************************************************************************************************/

    function test_realizeYield_success_zeroYield_nonZeroDuration_withFees_noBuffer() external {
        vm.prank(tradingAddress);
        strategy.realizeYield(0, 0, "FLUSH");

        assertEq(asset.balanceOf(address(strategy)),         strategyBalance);
        assertEq(asset.balanceOf(address(tradingAddress)),   newYieldAmount);
        assertEq(asset.balanceOf(address(strategyDelegate)), 0);
        assertEq(asset.balanceOf(address(mapleTreasury)),    0);

        assertEq(strategy.scheduledYieldAssets(), scheduledYieldAssets);
        assertEq(strategy.yieldStart(),           yieldStart);
        assertEq(strategy.yieldDeadline(),        yieldStart);

        assertEq(strategy.realizedAssets(),        scheduledYieldAssets);
        assertEq(strategy.unrealizedAssets(),      0);
        assertEq(strategy.availableToWithdraw(),   strategyBalance);
        assertEq(strategy.assetsUnderManagement(), strategyBalance);

        vm.expectEmit();
        emit IMapleTradingStrategy.YieldRealized(tradingAddress, 0, 0, 0, 0, newYieldDuration, "");

        vm.prank(tradingAddress);
        strategy.realizeYield(0, newYieldDuration, "");

        assertEq(asset.balanceOf(address(strategy)),         strategyBalance);
        assertEq(asset.balanceOf(address(tradingAddress)),   newYieldAmount);
        assertEq(asset.balanceOf(address(strategyDelegate)), 0);
        assertEq(asset.balanceOf(address(mapleTreasury)),    0);

        assertEq(strategy.scheduledYieldAssets(), 0);
        assertEq(strategy.yieldStart(),           yieldStart);
        assertEq(strategy.yieldDeadline(),        yieldStart + newYieldDuration);

        assertEq(strategy.realizedAssets(),        0);
        assertEq(strategy.unrealizedAssets(),      0);
        assertEq(strategy.availableToWithdraw(),   strategyBalance);
        assertEq(strategy.assetsUnderManagement(), strategyBalance);
    }

    function test_realizeYield_success_zeroYield_nonZeroDuration_withFees_bufferAtStart() external {
        assertEq(asset.balanceOf(address(strategy)),         strategyBalance);
        assertEq(asset.balanceOf(address(tradingAddress)),   newYieldAmount);
        assertEq(asset.balanceOf(address(strategyDelegate)), 0);
        assertEq(asset.balanceOf(address(mapleTreasury)),    0);

        assertEq(strategy.scheduledYieldAssets(), scheduledYieldAssets);
        assertEq(strategy.yieldStart(),           yieldStart);
        assertEq(strategy.yieldDeadline(),        yieldDeadline);

        assertEq(strategy.realizedAssets(),        0);
        assertEq(strategy.unrealizedAssets(),      scheduledYieldAssets);
        assertEq(strategy.availableToWithdraw(),   strategyBalance - scheduledYieldAssets);
        assertEq(strategy.assetsUnderManagement(), strategyBalance - scheduledYieldAssets);

        vm.expectEmit();
        emit IMapleTradingStrategy.YieldRealized(tradingAddress, scheduledYieldAssets, 0, 0, 0, newYieldDuration, "");

        vm.prank(tradingAddress);
        strategy.realizeYield(0, newYieldDuration, "");

        assertEq(asset.balanceOf(address(strategy)),         strategyBalance);
        assertEq(asset.balanceOf(address(tradingAddress)),   newYieldAmount);
        assertEq(asset.balanceOf(address(strategyDelegate)), 0);
        assertEq(asset.balanceOf(address(mapleTreasury)),    0);

        assertEq(strategy.scheduledYieldAssets(), scheduledYieldAssets);
        assertEq(strategy.yieldStart(),           yieldStart);
        assertEq(strategy.yieldDeadline(),        yieldStart + newYieldDuration);

        assertEq(strategy.realizedAssets(),        0);
        assertEq(strategy.unrealizedAssets(),      scheduledYieldAssets);
        assertEq(strategy.availableToWithdraw(),   strategyBalance - scheduledYieldAssets);
        assertEq(strategy.assetsUnderManagement(), strategyBalance - scheduledYieldAssets);
    }

    function test_realizeYield_success_zeroYield_nonZeroDuration_withFees_bufferAccruing() external {
        uint256 elapsedDuration  = yieldAccruing - yieldStart;
        uint256 totalDuration    = yieldDeadline - yieldStart;

        uint256 realizedAssets   = scheduledYieldAssets * elapsedDuration / totalDuration;
        uint256 unrealizedAssets = scheduledYieldAssets - realizedAssets;

        vm.warp(yieldAccruing);

        assertEq(asset.balanceOf(address(strategy)),         strategyBalance);
        assertEq(asset.balanceOf(address(tradingAddress)),   newYieldAmount);
        assertEq(asset.balanceOf(address(strategyDelegate)), 0);
        assertEq(asset.balanceOf(address(mapleTreasury)),    0);

        assertEq(strategy.scheduledYieldAssets(), scheduledYieldAssets);
        assertEq(strategy.yieldStart(),           yieldStart);
        assertEq(strategy.yieldDeadline(),        yieldDeadline);

        assertEq(strategy.realizedAssets(),        realizedAssets);
        assertEq(strategy.unrealizedAssets(),      unrealizedAssets);
        assertEq(strategy.availableToWithdraw(),   strategyBalance - unrealizedAssets);
        assertEq(strategy.assetsUnderManagement(), strategyBalance - unrealizedAssets);

        vm.expectEmit();
        emit IMapleTradingStrategy.YieldRealized(tradingAddress, unrealizedAssets, 0, 0, 0, newYieldDuration, "");

        vm.prank(tradingAddress);
        strategy.realizeYield(0, newYieldDuration, "");

        assertEq(asset.balanceOf(address(strategy)),         strategyBalance);
        assertEq(asset.balanceOf(address(tradingAddress)),   newYieldAmount);
        assertEq(asset.balanceOf(address(strategyDelegate)), 0);
        assertEq(asset.balanceOf(address(mapleTreasury)),    0);

        assertEq(strategy.scheduledYieldAssets(), unrealizedAssets);
        assertEq(strategy.yieldStart(),           yieldAccruing);
        assertEq(strategy.yieldDeadline(),        yieldAccruing + newYieldDuration);

        assertEq(strategy.realizedAssets(),        0);
        assertEq(strategy.unrealizedAssets(),      unrealizedAssets);
        assertEq(strategy.availableToWithdraw(),   strategyBalance - unrealizedAssets);
        assertEq(strategy.assetsUnderManagement(), strategyBalance - unrealizedAssets);
    }

    function test_realizeYield_success_zeroYield_nonZeroDuration_withFees_bufferAtDeadline() external {
        vm.warp(yieldDeadline);

        assertEq(asset.balanceOf(address(strategy)),         strategyBalance);
        assertEq(asset.balanceOf(address(tradingAddress)),   newYieldAmount);
        assertEq(asset.balanceOf(address(strategyDelegate)), 0);
        assertEq(asset.balanceOf(address(mapleTreasury)),    0);

        assertEq(strategy.scheduledYieldAssets(), scheduledYieldAssets);
        assertEq(strategy.yieldStart(),           yieldStart);
        assertEq(strategy.yieldDeadline(),        yieldDeadline);

        assertEq(strategy.realizedAssets(),      scheduledYieldAssets);
        assertEq(strategy.unrealizedAssets(),    0);
        assertEq(strategy.availableToWithdraw(), strategyBalance);

        vm.expectEmit();
        emit IMapleTradingStrategy.YieldRealized(tradingAddress, 0, 0, 0, 0, newYieldDuration, "");

        vm.prank(tradingAddress);
        strategy.realizeYield(0, newYieldDuration, "");

        assertEq(asset.balanceOf(address(strategy)),         strategyBalance);
        assertEq(asset.balanceOf(address(tradingAddress)),   newYieldAmount);
        assertEq(asset.balanceOf(address(strategyDelegate)), 0);
        assertEq(asset.balanceOf(address(mapleTreasury)),    0);

        assertEq(strategy.scheduledYieldAssets(), 0);
        assertEq(strategy.yieldStart(),           yieldDeadline);
        assertEq(strategy.yieldDeadline(),        yieldDeadline + newYieldDuration);

        assertEq(strategy.realizedAssets(),      0);
        assertEq(strategy.unrealizedAssets(),    0);
        assertEq(strategy.availableToWithdraw(), strategyBalance);
    }

    function test_realizeYield_success_zeroYield_nonZeroDuration_withFees_bufferPastDeadline() external {
        vm.warp(yieldFinished);

        assertEq(asset.balanceOf(address(strategy)),         strategyBalance);
        assertEq(asset.balanceOf(address(tradingAddress)),   newYieldAmount);
        assertEq(asset.balanceOf(address(strategyDelegate)), 0);
        assertEq(asset.balanceOf(address(mapleTreasury)),    0);

        assertEq(strategy.scheduledYieldAssets(), scheduledYieldAssets);
        assertEq(strategy.yieldStart(),           yieldStart);
        assertEq(strategy.yieldDeadline(),        yieldDeadline);

        assertEq(strategy.realizedAssets(),        scheduledYieldAssets);
        assertEq(strategy.unrealizedAssets(),      0);
        assertEq(strategy.availableToWithdraw(),   strategyBalance);
        assertEq(strategy.assetsUnderManagement(), strategyBalance);

        vm.expectEmit();
        emit IMapleTradingStrategy.YieldRealized(tradingAddress, 0, 0, 0, 0, newYieldDuration, "");

        vm.prank(tradingAddress);
        strategy.realizeYield(0, newYieldDuration, "");

        assertEq(asset.balanceOf(address(strategy)),         strategyBalance);
        assertEq(asset.balanceOf(address(tradingAddress)),   newYieldAmount);
        assertEq(asset.balanceOf(address(strategyDelegate)), 0);
        assertEq(asset.balanceOf(address(mapleTreasury)),    0);

        assertEq(strategy.scheduledYieldAssets(), 0);
        assertEq(strategy.yieldStart(),           yieldFinished);
        assertEq(strategy.yieldDeadline(),        yieldFinished + newYieldDuration);

        assertEq(strategy.realizedAssets(),        0);
        assertEq(strategy.unrealizedAssets(),      0);
        assertEq(strategy.availableToWithdraw(),   strategyBalance);
        assertEq(strategy.assetsUnderManagement(), strategyBalance);
    }

    /**************************************************************************************************************************************/
    /*** Non-Zero Yield — Zero Duration — No Fees                                                                                       ***/
    /**************************************************************************************************************************************/

    function test_realizeYield_success_nonZeroYield_zeroDuration_noFees_noBuffer() external {
        strategy.__setFeeRates(0, 0);

        vm.prank(tradingAddress);
        strategy.realizeYield(0, 0, "FLUSH");

        assertEq(asset.balanceOf(address(strategy)),         strategyBalance);
        assertEq(asset.balanceOf(address(tradingAddress)),   newYieldAmount);
        assertEq(asset.balanceOf(address(strategyDelegate)), 0);
        assertEq(asset.balanceOf(address(mapleTreasury)),    0);

        assertEq(strategy.scheduledYieldAssets(), scheduledYieldAssets);
        assertEq(strategy.yieldStart(),           yieldStart);
        assertEq(strategy.yieldDeadline(),        yieldStart);

        assertEq(strategy.realizedAssets(),        scheduledYieldAssets);
        assertEq(strategy.unrealizedAssets(),      0);
        assertEq(strategy.availableToWithdraw(),   strategyBalance);
        assertEq(strategy.assetsUnderManagement(), strategyBalance);

        vm.expectEmit();
        emit IMapleTradingStrategy.YieldRealized(tradingAddress, 0, newYieldAmount, 0, 0, 0, "");

        vm.prank(tradingAddress);
        strategy.realizeYield(newYieldAmount, 0, "");

        assertEq(asset.balanceOf(address(strategy)),         strategyBalance + newYieldAmount);
        assertEq(asset.balanceOf(address(tradingAddress)),   0);
        assertEq(asset.balanceOf(address(strategyDelegate)), 0);
        assertEq(asset.balanceOf(address(mapleTreasury)),    0);

        assertEq(strategy.scheduledYieldAssets(), newYieldAmount);
        assertEq(strategy.yieldStart(),           yieldStart);
        assertEq(strategy.yieldDeadline(),        yieldStart);

        assertEq(strategy.realizedAssets(),        newYieldAmount);
        assertEq(strategy.unrealizedAssets(),      0);
        assertEq(strategy.availableToWithdraw(),   strategyBalance + newYieldAmount);
        assertEq(strategy.assetsUnderManagement(), strategyBalance + newYieldAmount);
    }

    function test_realizeYield_success_nonZeroYield_zeroDuration_noFees_bufferAtStart() external {
        strategy.__setFeeRates(0, 0);

        assertEq(asset.balanceOf(address(strategy)),         strategyBalance);
        assertEq(asset.balanceOf(address(tradingAddress)),   newYieldAmount);
        assertEq(asset.balanceOf(address(strategyDelegate)), 0);
        assertEq(asset.balanceOf(address(mapleTreasury)),    0);

        assertEq(strategy.scheduledYieldAssets(), scheduledYieldAssets);
        assertEq(strategy.yieldStart(),           yieldStart);
        assertEq(strategy.yieldDeadline(),        yieldDeadline);

        assertEq(strategy.realizedAssets(),        0);
        assertEq(strategy.unrealizedAssets(),      scheduledYieldAssets);
        assertEq(strategy.availableToWithdraw(),   strategyBalance - scheduledYieldAssets);
        assertEq(strategy.assetsUnderManagement(), strategyBalance - scheduledYieldAssets);

        vm.expectEmit();
        emit IMapleTradingStrategy.YieldRealized(tradingAddress, scheduledYieldAssets, newYieldAmount, 0, 0, 0, "");

        vm.prank(tradingAddress);
        strategy.realizeYield(newYieldAmount, 0, "");

        assertEq(asset.balanceOf(address(strategy)),         strategyBalance + newYieldAmount);
        assertEq(asset.balanceOf(address(tradingAddress)),   0);
        assertEq(asset.balanceOf(address(strategyDelegate)), 0);
        assertEq(asset.balanceOf(address(mapleTreasury)),    0);

        assertEq(strategy.scheduledYieldAssets(), scheduledYieldAssets + newYieldAmount);
        assertEq(strategy.yieldStart(),           yieldStart);
        assertEq(strategy.yieldDeadline(),        yieldStart);

        assertEq(strategy.realizedAssets(),        scheduledYieldAssets + newYieldAmount);
        assertEq(strategy.unrealizedAssets(),      0);
        assertEq(strategy.availableToWithdraw(),   strategyBalance + newYieldAmount);
        assertEq(strategy.assetsUnderManagement(), strategyBalance + newYieldAmount);
    }

    function test_realizeYield_success_nonZeroYield_zeroDuration_noFees_bufferAccruing() external {
        strategy.__setFeeRates(0, 0);

        uint256 elapsedDuration  = yieldAccruing - yieldStart;
        uint256 totalDuration    = yieldDeadline - yieldStart;

        uint256 realizedAssets   = scheduledYieldAssets * elapsedDuration / totalDuration;
        uint256 unrealizedAssets = scheduledYieldAssets - realizedAssets;

        vm.warp(yieldAccruing);

        assertEq(asset.balanceOf(address(strategy)),         strategyBalance);
        assertEq(asset.balanceOf(address(tradingAddress)),   newYieldAmount);
        assertEq(asset.balanceOf(address(strategyDelegate)), 0);
        assertEq(asset.balanceOf(address(mapleTreasury)),    0);

        assertEq(strategy.scheduledYieldAssets(), scheduledYieldAssets);
        assertEq(strategy.yieldStart(),           yieldStart);
        assertEq(strategy.yieldDeadline(),        yieldDeadline);

        assertEq(strategy.realizedAssets(),        realizedAssets);
        assertEq(strategy.unrealizedAssets(),      unrealizedAssets);
        assertEq(strategy.availableToWithdraw(),   strategyBalance - unrealizedAssets);
        assertEq(strategy.assetsUnderManagement(), strategyBalance - unrealizedAssets);

        vm.expectEmit();
        emit IMapleTradingStrategy.YieldRealized(tradingAddress, unrealizedAssets, newYieldAmount, 0, 0, 0, "");

        vm.prank(tradingAddress);
        strategy.realizeYield(newYieldAmount, 0, "");

        assertEq(asset.balanceOf(address(strategy)),         strategyBalance + newYieldAmount);
        assertEq(asset.balanceOf(address(tradingAddress)),   0);
        assertEq(asset.balanceOf(address(strategyDelegate)), 0);
        assertEq(asset.balanceOf(address(mapleTreasury)),    0);

        assertEq(strategy.scheduledYieldAssets(), unrealizedAssets + newYieldAmount);
        assertEq(strategy.yieldStart(),           yieldAccruing);
        assertEq(strategy.yieldDeadline(),        yieldAccruing);

        assertEq(strategy.realizedAssets(),        unrealizedAssets + newYieldAmount);
        assertEq(strategy.unrealizedAssets(),      0);
        assertEq(strategy.availableToWithdraw(),   strategyBalance + newYieldAmount);
        assertEq(strategy.assetsUnderManagement(), strategyBalance + newYieldAmount);
    }

    function test_realizeYield_success_nonZeroYield_zeroDuration_noFees_bufferAtDeadline() external {
        strategy.__setFeeRates(0, 0);

        vm.warp(yieldDeadline);

        assertEq(asset.balanceOf(address(strategy)),         strategyBalance);
        assertEq(asset.balanceOf(address(tradingAddress)),   newYieldAmount);
        assertEq(asset.balanceOf(address(strategyDelegate)), 0);
        assertEq(asset.balanceOf(address(mapleTreasury)),    0);

        assertEq(strategy.scheduledYieldAssets(), scheduledYieldAssets);
        assertEq(strategy.yieldStart(),           yieldStart);
        assertEq(strategy.yieldDeadline(),        yieldDeadline);

        assertEq(strategy.realizedAssets(),      scheduledYieldAssets);
        assertEq(strategy.unrealizedAssets(),    0);
        assertEq(strategy.availableToWithdraw(), strategyBalance);

        vm.expectEmit();
        emit IMapleTradingStrategy.YieldRealized(tradingAddress, 0, newYieldAmount, 0, 0, 0, "");

        vm.prank(tradingAddress);
        strategy.realizeYield(newYieldAmount, 0, "");

        assertEq(asset.balanceOf(address(strategy)),         strategyBalance + newYieldAmount);
        assertEq(asset.balanceOf(address(tradingAddress)),   0);
        assertEq(asset.balanceOf(address(strategyDelegate)), 0);
        assertEq(asset.balanceOf(address(mapleTreasury)),    0);

        assertEq(strategy.scheduledYieldAssets(), newYieldAmount);
        assertEq(strategy.yieldStart(),           yieldDeadline);
        assertEq(strategy.yieldDeadline(),        yieldDeadline);

        assertEq(strategy.realizedAssets(),      newYieldAmount);
        assertEq(strategy.unrealizedAssets(),    0);
        assertEq(strategy.availableToWithdraw(), strategyBalance + newYieldAmount);
    }

    function test_realizeYield_success_nonZeroYield_zeroDuration_noFees_bufferPastDeadline() external {
        strategy.__setFeeRates(0, 0);

        vm.warp(yieldFinished);

        assertEq(asset.balanceOf(address(strategy)),         strategyBalance);
        assertEq(asset.balanceOf(address(tradingAddress)),   newYieldAmount);
        assertEq(asset.balanceOf(address(strategyDelegate)), 0);
        assertEq(asset.balanceOf(address(mapleTreasury)),    0);

        assertEq(strategy.scheduledYieldAssets(), scheduledYieldAssets);
        assertEq(strategy.yieldStart(),           yieldStart);
        assertEq(strategy.yieldDeadline(),        yieldDeadline);

        assertEq(strategy.realizedAssets(),        scheduledYieldAssets);
        assertEq(strategy.unrealizedAssets(),      0);
        assertEq(strategy.availableToWithdraw(),   strategyBalance);
        assertEq(strategy.assetsUnderManagement(), strategyBalance);

        vm.expectEmit();
        emit IMapleTradingStrategy.YieldRealized(tradingAddress, 0, newYieldAmount, 0, 0, 0, "");

        vm.prank(tradingAddress);
        strategy.realizeYield(newYieldAmount, 0, "");

        assertEq(asset.balanceOf(address(strategy)),         strategyBalance + newYieldAmount);
        assertEq(asset.balanceOf(address(tradingAddress)),   0);
        assertEq(asset.balanceOf(address(strategyDelegate)), 0);
        assertEq(asset.balanceOf(address(mapleTreasury)),    0);

        assertEq(strategy.scheduledYieldAssets(), newYieldAmount);
        assertEq(strategy.yieldStart(),           yieldFinished);
        assertEq(strategy.yieldDeadline(),        yieldFinished);

        assertEq(strategy.realizedAssets(),        newYieldAmount);
        assertEq(strategy.unrealizedAssets(),      0);
        assertEq(strategy.availableToWithdraw(),   strategyBalance + newYieldAmount);
        assertEq(strategy.assetsUnderManagement(), strategyBalance + newYieldAmount);
    }

    /**************************************************************************************************************************************/
    /*** Non-Zero Yield — Zero Duration — With Fees                                                                                     ***/
    /**************************************************************************************************************************************/

    function test_realizeYield_success_nonZeroYield_zeroDuration_withFees_noBuffer() external {
        vm.prank(tradingAddress);
        strategy.realizeYield(0, 0, "FLUSH");

        uint256 delegateFee    = newYieldAmount * delegateFeeRate / 1e6;
        uint256 protocolFee    = newYieldAmount * protocolFeeRate / 1e6;
        uint256 netYieldAmount = newYieldAmount - delegateFee - protocolFee;

        assertEq(asset.balanceOf(address(strategy)),         strategyBalance);
        assertEq(asset.balanceOf(address(tradingAddress)),   newYieldAmount);
        assertEq(asset.balanceOf(address(strategyDelegate)), 0);
        assertEq(asset.balanceOf(address(mapleTreasury)),    0);

        assertEq(strategy.scheduledYieldAssets(), scheduledYieldAssets);
        assertEq(strategy.yieldStart(),           yieldStart);
        assertEq(strategy.yieldDeadline(),        yieldStart);

        assertEq(strategy.realizedAssets(),        scheduledYieldAssets);
        assertEq(strategy.unrealizedAssets(),      0);
        assertEq(strategy.availableToWithdraw(),   strategyBalance);
        assertEq(strategy.assetsUnderManagement(), strategyBalance);

        vm.expectEmit();
        emit IMapleTradingStrategy.YieldRealized(tradingAddress, 0, netYieldAmount, delegateFee, protocolFee, 0, "");

        vm.prank(tradingAddress);
        strategy.realizeYield(newYieldAmount, 0, "");

        assertEq(asset.balanceOf(address(strategy)),         strategyBalance + netYieldAmount);
        assertEq(asset.balanceOf(address(tradingAddress)),   0);
        assertEq(asset.balanceOf(address(strategyDelegate)), delegateFee);
        assertEq(asset.balanceOf(address(mapleTreasury)),    protocolFee);

        assertEq(strategy.scheduledYieldAssets(), netYieldAmount);
        assertEq(strategy.yieldStart(),           yieldStart);
        assertEq(strategy.yieldDeadline(),        yieldStart);

        assertEq(strategy.realizedAssets(),        netYieldAmount);
        assertEq(strategy.unrealizedAssets(),      0);
        assertEq(strategy.availableToWithdraw(),   strategyBalance + netYieldAmount);
        assertEq(strategy.assetsUnderManagement(), strategyBalance + netYieldAmount);
    }

    function test_realizeYield_success_nonZeroYield_zeroDuration_withFees_bufferAtStart() external {
        uint256 delegateFee    = newYieldAmount * delegateFeeRate / 1e6;
        uint256 protocolFee    = newYieldAmount * protocolFeeRate / 1e6;
        uint256 netYieldAmount = newYieldAmount - delegateFee - protocolFee;

        assertEq(asset.balanceOf(address(strategy)),         strategyBalance);
        assertEq(asset.balanceOf(address(tradingAddress)),   newYieldAmount);
        assertEq(asset.balanceOf(address(strategyDelegate)), 0);
        assertEq(asset.balanceOf(address(mapleTreasury)),    0);

        assertEq(strategy.scheduledYieldAssets(), scheduledYieldAssets);
        assertEq(strategy.yieldStart(),           yieldStart);
        assertEq(strategy.yieldDeadline(),        yieldDeadline);

        assertEq(strategy.realizedAssets(),        0);
        assertEq(strategy.unrealizedAssets(),      scheduledYieldAssets);
        assertEq(strategy.availableToWithdraw(),   strategyBalance - scheduledYieldAssets);
        assertEq(strategy.assetsUnderManagement(), strategyBalance - scheduledYieldAssets);

        vm.expectEmit();
        emit IMapleTradingStrategy.YieldRealized(tradingAddress, scheduledYieldAssets, netYieldAmount, delegateFee, protocolFee, 0, "");

        vm.prank(tradingAddress);
        strategy.realizeYield(newYieldAmount, 0, "");

        assertEq(asset.balanceOf(address(strategy)),         strategyBalance + netYieldAmount);
        assertEq(asset.balanceOf(address(tradingAddress)),   0);
        assertEq(asset.balanceOf(address(strategyDelegate)), delegateFee);
        assertEq(asset.balanceOf(address(mapleTreasury)),    protocolFee);

        assertEq(strategy.scheduledYieldAssets(), scheduledYieldAssets + netYieldAmount);
        assertEq(strategy.yieldStart(),           yieldStart);
        assertEq(strategy.yieldDeadline(),        yieldStart);

        assertEq(strategy.realizedAssets(),        scheduledYieldAssets + netYieldAmount);
        assertEq(strategy.unrealizedAssets(),      0);
        assertEq(strategy.availableToWithdraw(),   strategyBalance + netYieldAmount);
        assertEq(strategy.assetsUnderManagement(), strategyBalance + netYieldAmount);
    }

    function test_realizeYield_success_nonZeroYield_zeroDuration_withFees_bufferAccruing() external {
        uint256 elapsedDuration  = yieldAccruing - yieldStart;
        uint256 totalDuration    = yieldDeadline - yieldStart;

        uint256 realizedAssets   = scheduledYieldAssets * elapsedDuration / totalDuration;
        uint256 unrealizedAssets = scheduledYieldAssets - realizedAssets;

        uint256 delegateFee    = newYieldAmount * delegateFeeRate / 1e6;
        uint256 protocolFee    = newYieldAmount * protocolFeeRate / 1e6;
        uint256 netYieldAmount = newYieldAmount - delegateFee - protocolFee;

        vm.warp(yieldAccruing);

        assertEq(asset.balanceOf(address(strategy)),         strategyBalance);
        assertEq(asset.balanceOf(address(tradingAddress)),   newYieldAmount);
        assertEq(asset.balanceOf(address(strategyDelegate)), 0);
        assertEq(asset.balanceOf(address(mapleTreasury)),    0);

        assertEq(strategy.scheduledYieldAssets(), scheduledYieldAssets);
        assertEq(strategy.yieldStart(),           yieldStart);
        assertEq(strategy.yieldDeadline(),        yieldDeadline);

        assertEq(strategy.realizedAssets(),        realizedAssets);
        assertEq(strategy.unrealizedAssets(),      unrealizedAssets);
        assertEq(strategy.availableToWithdraw(),   strategyBalance - unrealizedAssets);
        assertEq(strategy.assetsUnderManagement(), strategyBalance - unrealizedAssets);

        vm.expectEmit();
        emit IMapleTradingStrategy.YieldRealized(tradingAddress, unrealizedAssets, netYieldAmount, delegateFee, protocolFee, 0, "");

        vm.prank(tradingAddress);
        strategy.realizeYield(newYieldAmount, 0, "");

        assertEq(asset.balanceOf(address(strategy)),         strategyBalance + netYieldAmount);
        assertEq(asset.balanceOf(address(tradingAddress)),   0);
        assertEq(asset.balanceOf(address(strategyDelegate)), delegateFee);
        assertEq(asset.balanceOf(address(mapleTreasury)),    protocolFee);

        assertEq(strategy.scheduledYieldAssets(), unrealizedAssets + netYieldAmount);
        assertEq(strategy.yieldStart(),           yieldAccruing);
        assertEq(strategy.yieldDeadline(),        yieldAccruing);

        assertEq(strategy.realizedAssets(),        unrealizedAssets + netYieldAmount);
        assertEq(strategy.unrealizedAssets(),      0);
        assertEq(strategy.availableToWithdraw(),   strategyBalance + netYieldAmount);
        assertEq(strategy.assetsUnderManagement(), strategyBalance + netYieldAmount);
    }

    function test_realizeYield_success_nonZeroYield_zeroDuration_withFees_bufferAtDeadline() external {
        uint256 delegateFee    = newYieldAmount * delegateFeeRate / 1e6;
        uint256 protocolFee    = newYieldAmount * protocolFeeRate / 1e6;
        uint256 netYieldAmount = newYieldAmount - delegateFee - protocolFee;

        vm.warp(yieldDeadline);

        assertEq(asset.balanceOf(address(strategy)),         strategyBalance);
        assertEq(asset.balanceOf(address(tradingAddress)),   newYieldAmount);
        assertEq(asset.balanceOf(address(strategyDelegate)), 0);
        assertEq(asset.balanceOf(address(mapleTreasury)),    0);

        assertEq(strategy.scheduledYieldAssets(), scheduledYieldAssets);
        assertEq(strategy.yieldStart(),           yieldStart);
        assertEq(strategy.yieldDeadline(),        yieldDeadline);

        assertEq(strategy.realizedAssets(),      scheduledYieldAssets);
        assertEq(strategy.unrealizedAssets(),    0);
        assertEq(strategy.availableToWithdraw(), strategyBalance);

        vm.expectEmit();
        emit IMapleTradingStrategy.YieldRealized(tradingAddress, 0, netYieldAmount, delegateFee, protocolFee, 0, "");

        vm.prank(tradingAddress);
        strategy.realizeYield(newYieldAmount, 0, "");

        assertEq(asset.balanceOf(address(strategy)),         strategyBalance + netYieldAmount);
        assertEq(asset.balanceOf(address(tradingAddress)),   0);
        assertEq(asset.balanceOf(address(strategyDelegate)), delegateFee);
        assertEq(asset.balanceOf(address(mapleTreasury)),    protocolFee);

        assertEq(strategy.scheduledYieldAssets(), netYieldAmount);
        assertEq(strategy.yieldStart(),           yieldDeadline);
        assertEq(strategy.yieldDeadline(),        yieldDeadline);

        assertEq(strategy.realizedAssets(),      netYieldAmount);
        assertEq(strategy.unrealizedAssets(),    0);
        assertEq(strategy.availableToWithdraw(), strategyBalance + netYieldAmount);
    }

    function test_realizeYield_success_nonZeroYield_zeroDuration_withFees_bufferPastDeadline() external {
        uint256 delegateFee    = newYieldAmount * delegateFeeRate / 1e6;
        uint256 protocolFee    = newYieldAmount * protocolFeeRate / 1e6;
        uint256 netYieldAmount = newYieldAmount - delegateFee - protocolFee;

        vm.warp(yieldFinished);

        assertEq(asset.balanceOf(address(strategy)),         strategyBalance);
        assertEq(asset.balanceOf(address(tradingAddress)),   newYieldAmount);
        assertEq(asset.balanceOf(address(strategyDelegate)), 0);
        assertEq(asset.balanceOf(address(mapleTreasury)),    0);

        assertEq(strategy.scheduledYieldAssets(), scheduledYieldAssets);
        assertEq(strategy.yieldStart(),           yieldStart);
        assertEq(strategy.yieldDeadline(),        yieldDeadline);

        assertEq(strategy.realizedAssets(),        scheduledYieldAssets);
        assertEq(strategy.unrealizedAssets(),      0);
        assertEq(strategy.availableToWithdraw(),   strategyBalance);
        assertEq(strategy.assetsUnderManagement(), strategyBalance);

        vm.expectEmit();
        emit IMapleTradingStrategy.YieldRealized(tradingAddress, 0, netYieldAmount, delegateFee, protocolFee, 0, "");

        vm.prank(tradingAddress);
        strategy.realizeYield(newYieldAmount, 0, "");

        assertEq(asset.balanceOf(address(strategy)),         strategyBalance + netYieldAmount);
        assertEq(asset.balanceOf(address(tradingAddress)),   0);
        assertEq(asset.balanceOf(address(strategyDelegate)), delegateFee);
        assertEq(asset.balanceOf(address(mapleTreasury)),    protocolFee);

        assertEq(strategy.scheduledYieldAssets(), netYieldAmount);
        assertEq(strategy.yieldStart(),           yieldFinished);
        assertEq(strategy.yieldDeadline(),        yieldFinished);

        assertEq(strategy.realizedAssets(),        netYieldAmount);
        assertEq(strategy.unrealizedAssets(),      0);
        assertEq(strategy.availableToWithdraw(),   strategyBalance + netYieldAmount);
        assertEq(strategy.assetsUnderManagement(), strategyBalance + netYieldAmount);
    }

    /**************************************************************************************************************************************/
    /*** Non-Zero Yield — Zero Duration — Fees Round to Zero                                                                            ***/
    /**************************************************************************************************************************************/

    function test_realizeYield_success_nonZeroYield_zeroDuration_feesRoundToZero_noBuffer() external {
        vm.prank(tradingAddress);
        strategy.realizeYield(0, 0, "FLUSH");

        assertEq(asset.balanceOf(address(strategy)),         strategyBalance);
        assertEq(asset.balanceOf(address(tradingAddress)),   newYieldAmount);
        assertEq(asset.balanceOf(address(strategyDelegate)), 0);
        assertEq(asset.balanceOf(address(mapleTreasury)),    0);

        assertEq(strategy.scheduledYieldAssets(), scheduledYieldAssets);
        assertEq(strategy.yieldStart(),           yieldStart);
        assertEq(strategy.yieldDeadline(),        yieldStart);

        assertEq(strategy.realizedAssets(),        scheduledYieldAssets);
        assertEq(strategy.unrealizedAssets(),      0);
        assertEq(strategy.availableToWithdraw(),   strategyBalance);
        assertEq(strategy.assetsUnderManagement(), strategyBalance);

        vm.expectEmit();
        emit IMapleTradingStrategy.YieldRealized(tradingAddress, 0, tinyYieldAmount, 0, 0, 0, "");

        vm.prank(tradingAddress);
        strategy.realizeYield(tinyYieldAmount, 0, "");

        assertEq(asset.balanceOf(address(strategy)),         strategyBalance + tinyYieldAmount);
        assertEq(asset.balanceOf(address(tradingAddress)),   newYieldAmount - tinyYieldAmount);
        assertEq(asset.balanceOf(address(strategyDelegate)), 0);
        assertEq(asset.balanceOf(address(mapleTreasury)),    0);

        assertEq(strategy.scheduledYieldAssets(), tinyYieldAmount);
        assertEq(strategy.yieldStart(),           yieldStart);
        assertEq(strategy.yieldDeadline(),        yieldStart);

        assertEq(strategy.realizedAssets(),        tinyYieldAmount);
        assertEq(strategy.unrealizedAssets(),      0);
        assertEq(strategy.availableToWithdraw(),   strategyBalance + tinyYieldAmount);
        assertEq(strategy.assetsUnderManagement(), strategyBalance + tinyYieldAmount);
    }

    function test_realizeYield_success_nonZeroYield_zeroDuration_feesRoundToZero_bufferAtStart() external {
        assertEq(asset.balanceOf(address(strategy)),         strategyBalance);
        assertEq(asset.balanceOf(address(tradingAddress)),   newYieldAmount);
        assertEq(asset.balanceOf(address(strategyDelegate)), 0);
        assertEq(asset.balanceOf(address(mapleTreasury)),    0);

        assertEq(strategy.scheduledYieldAssets(), scheduledYieldAssets);
        assertEq(strategy.yieldStart(),           yieldStart);
        assertEq(strategy.yieldDeadline(),        yieldDeadline);

        assertEq(strategy.realizedAssets(),        0);
        assertEq(strategy.unrealizedAssets(),      scheduledYieldAssets);
        assertEq(strategy.availableToWithdraw(),   strategyBalance - scheduledYieldAssets);
        assertEq(strategy.assetsUnderManagement(), strategyBalance - scheduledYieldAssets);

        vm.expectEmit();
        emit IMapleTradingStrategy.YieldRealized(tradingAddress, scheduledYieldAssets, tinyYieldAmount, 0, 0, 0, "");

        vm.prank(tradingAddress);
        strategy.realizeYield(tinyYieldAmount, 0, "");

        assertEq(asset.balanceOf(address(strategy)),         strategyBalance + tinyYieldAmount);
        assertEq(asset.balanceOf(address(tradingAddress)),   newYieldAmount - tinyYieldAmount);
        assertEq(asset.balanceOf(address(strategyDelegate)), 0);
        assertEq(asset.balanceOf(address(mapleTreasury)),    0);

        assertEq(strategy.scheduledYieldAssets(), scheduledYieldAssets + tinyYieldAmount);
        assertEq(strategy.yieldStart(),           yieldStart);
        assertEq(strategy.yieldDeadline(),        yieldStart);

        assertEq(strategy.realizedAssets(),        scheduledYieldAssets + tinyYieldAmount);
        assertEq(strategy.unrealizedAssets(),      0);
        assertEq(strategy.availableToWithdraw(),   strategyBalance + tinyYieldAmount);
        assertEq(strategy.assetsUnderManagement(), strategyBalance + tinyYieldAmount);
    }

    function test_realizeYield_success_nonZeroYield_zeroDuration_feesRoundToZero_bufferAccruing() external {
        uint256 elapsedDuration  = yieldAccruing - yieldStart;
        uint256 totalDuration    = yieldDeadline - yieldStart;

        uint256 realizedAssets   = scheduledYieldAssets * elapsedDuration / totalDuration;
        uint256 unrealizedAssets = scheduledYieldAssets - realizedAssets;

        vm.warp(yieldAccruing);

        assertEq(asset.balanceOf(address(strategy)),         strategyBalance);
        assertEq(asset.balanceOf(address(tradingAddress)),   newYieldAmount);
        assertEq(asset.balanceOf(address(strategyDelegate)), 0);
        assertEq(asset.balanceOf(address(mapleTreasury)),    0);

        assertEq(strategy.scheduledYieldAssets(), scheduledYieldAssets);
        assertEq(strategy.yieldStart(),           yieldStart);
        assertEq(strategy.yieldDeadline(),        yieldDeadline);

        assertEq(strategy.realizedAssets(),        realizedAssets);
        assertEq(strategy.unrealizedAssets(),      unrealizedAssets);
        assertEq(strategy.availableToWithdraw(),   strategyBalance - unrealizedAssets);
        assertEq(strategy.assetsUnderManagement(), strategyBalance - unrealizedAssets);

        vm.expectEmit();
        emit IMapleTradingStrategy.YieldRealized(tradingAddress, unrealizedAssets, tinyYieldAmount, 0, 0, 0, "");

        vm.prank(tradingAddress);
        strategy.realizeYield(tinyYieldAmount, 0, "");

        assertEq(asset.balanceOf(address(strategy)),         strategyBalance + tinyYieldAmount);
        assertEq(asset.balanceOf(address(tradingAddress)),   newYieldAmount - tinyYieldAmount);
        assertEq(asset.balanceOf(address(strategyDelegate)), 0);
        assertEq(asset.balanceOf(address(mapleTreasury)),    0);

        assertEq(strategy.scheduledYieldAssets(), unrealizedAssets + tinyYieldAmount);
        assertEq(strategy.yieldStart(),           yieldAccruing);
        assertEq(strategy.yieldDeadline(),        yieldAccruing);

        assertEq(strategy.realizedAssets(),        unrealizedAssets + tinyYieldAmount);
        assertEq(strategy.unrealizedAssets(),      0);
        assertEq(strategy.availableToWithdraw(),   strategyBalance + tinyYieldAmount);
        assertEq(strategy.assetsUnderManagement(), strategyBalance + tinyYieldAmount);
    }

    function test_realizeYield_success_nonZeroYield_zeroDuration_feesRoundToZero_bufferAtDeadline() external {
        vm.warp(yieldDeadline);

        assertEq(asset.balanceOf(address(strategy)),         strategyBalance);
        assertEq(asset.balanceOf(address(tradingAddress)),   newYieldAmount);
        assertEq(asset.balanceOf(address(strategyDelegate)), 0);
        assertEq(asset.balanceOf(address(mapleTreasury)),    0);

        assertEq(strategy.scheduledYieldAssets(), scheduledYieldAssets);
        assertEq(strategy.yieldStart(),           yieldStart);
        assertEq(strategy.yieldDeadline(),        yieldDeadline);

        assertEq(strategy.realizedAssets(),      scheduledYieldAssets);
        assertEq(strategy.unrealizedAssets(),    0);
        assertEq(strategy.availableToWithdraw(), strategyBalance);

        vm.expectEmit();
        emit IMapleTradingStrategy.YieldRealized(tradingAddress, 0, tinyYieldAmount, 0, 0, 0, "");

        vm.prank(tradingAddress);
        strategy.realizeYield(tinyYieldAmount, 0, "");

        assertEq(asset.balanceOf(address(strategy)),         strategyBalance + tinyYieldAmount);
        assertEq(asset.balanceOf(address(tradingAddress)),   newYieldAmount - tinyYieldAmount);
        assertEq(asset.balanceOf(address(strategyDelegate)), 0);
        assertEq(asset.balanceOf(address(mapleTreasury)),    0);

        assertEq(strategy.scheduledYieldAssets(), tinyYieldAmount);
        assertEq(strategy.yieldStart(),           yieldDeadline);
        assertEq(strategy.yieldDeadline(),        yieldDeadline);

        assertEq(strategy.realizedAssets(),      tinyYieldAmount);
        assertEq(strategy.unrealizedAssets(),    0);
        assertEq(strategy.availableToWithdraw(), strategyBalance + tinyYieldAmount);
    }

    function test_realizeYield_success_nonZeroYield_zeroDuration_feesRoundToZero_bufferPastDeadline() external {
        vm.warp(yieldFinished);

        assertEq(asset.balanceOf(address(strategy)),         strategyBalance);
        assertEq(asset.balanceOf(address(tradingAddress)),   newYieldAmount);
        assertEq(asset.balanceOf(address(strategyDelegate)), 0);
        assertEq(asset.balanceOf(address(mapleTreasury)),    0);

        assertEq(strategy.scheduledYieldAssets(), scheduledYieldAssets);
        assertEq(strategy.yieldStart(),           yieldStart);
        assertEq(strategy.yieldDeadline(),        yieldDeadline);

        assertEq(strategy.realizedAssets(),        scheduledYieldAssets);
        assertEq(strategy.unrealizedAssets(),      0);
        assertEq(strategy.availableToWithdraw(),   strategyBalance);
        assertEq(strategy.assetsUnderManagement(), strategyBalance);

        vm.expectEmit();
        emit IMapleTradingStrategy.YieldRealized(tradingAddress, 0, tinyYieldAmount, 0, 0, 0, "");

        vm.prank(tradingAddress);
        strategy.realizeYield(tinyYieldAmount, 0, "");

        assertEq(asset.balanceOf(address(strategy)),         strategyBalance + tinyYieldAmount);
        assertEq(asset.balanceOf(address(tradingAddress)),   newYieldAmount - tinyYieldAmount);
        assertEq(asset.balanceOf(address(strategyDelegate)), 0);
        assertEq(asset.balanceOf(address(mapleTreasury)),    0);

        assertEq(strategy.scheduledYieldAssets(), tinyYieldAmount);
        assertEq(strategy.yieldStart(),           yieldFinished);
        assertEq(strategy.yieldDeadline(),        yieldFinished);

        assertEq(strategy.realizedAssets(),        tinyYieldAmount);
        assertEq(strategy.unrealizedAssets(),      0);
        assertEq(strategy.availableToWithdraw(),   strategyBalance + tinyYieldAmount);
        assertEq(strategy.assetsUnderManagement(), strategyBalance + tinyYieldAmount);
    }

    /**************************************************************************************************************************************/
    /*** Non-Zero Yield — Non-Zero Duration — No Fees                                                                                   ***/
    /**************************************************************************************************************************************/

    function test_realizeYield_success_nonZeroYield_nonZeroDuration_noFees_noBuffer() external {
        strategy.__setFeeRates(0, 0);

        vm.prank(tradingAddress);
        strategy.realizeYield(0, 0, "FLUSH");

        assertEq(asset.balanceOf(address(strategy)),         strategyBalance);
        assertEq(asset.balanceOf(address(tradingAddress)),   newYieldAmount);
        assertEq(asset.balanceOf(address(strategyDelegate)), 0);
        assertEq(asset.balanceOf(address(mapleTreasury)),    0);

        assertEq(strategy.scheduledYieldAssets(), scheduledYieldAssets);
        assertEq(strategy.yieldStart(),           yieldStart);
        assertEq(strategy.yieldDeadline(),        yieldStart);

        assertEq(strategy.realizedAssets(),        scheduledYieldAssets);
        assertEq(strategy.unrealizedAssets(),      0);
        assertEq(strategy.availableToWithdraw(),   strategyBalance);
        assertEq(strategy.assetsUnderManagement(), strategyBalance);

        vm.expectEmit();
        emit IMapleTradingStrategy.YieldRealized(tradingAddress, 0, newYieldAmount, 0, 0, newYieldDuration, "");

        vm.prank(tradingAddress);
        strategy.realizeYield(newYieldAmount, newYieldDuration, "");

        assertEq(asset.balanceOf(address(strategy)),         strategyBalance + newYieldAmount);
        assertEq(asset.balanceOf(address(tradingAddress)),   0);
        assertEq(asset.balanceOf(address(strategyDelegate)), 0);
        assertEq(asset.balanceOf(address(mapleTreasury)),    0);

        assertEq(strategy.scheduledYieldAssets(), newYieldAmount);
        assertEq(strategy.yieldStart(),           yieldStart);
        assertEq(strategy.yieldDeadline(),        yieldStart + newYieldDuration);

        assertEq(strategy.realizedAssets(),        0);
        assertEq(strategy.unrealizedAssets(),      newYieldAmount);
        assertEq(strategy.availableToWithdraw(),   strategyBalance);
        assertEq(strategy.assetsUnderManagement(), strategyBalance);
    }

    function test_realizeYield_success_nonZeroYield_nonZeroDuration_noFees_bufferAtStart() external {
        strategy.__setFeeRates(0, 0);

        assertEq(asset.balanceOf(address(strategy)),         strategyBalance);
        assertEq(asset.balanceOf(address(tradingAddress)),   newYieldAmount);
        assertEq(asset.balanceOf(address(strategyDelegate)), 0);
        assertEq(asset.balanceOf(address(mapleTreasury)),    0);

        assertEq(strategy.scheduledYieldAssets(), scheduledYieldAssets);
        assertEq(strategy.yieldStart(),           yieldStart);
        assertEq(strategy.yieldDeadline(),        yieldDeadline);

        assertEq(strategy.realizedAssets(),        0);
        assertEq(strategy.unrealizedAssets(),      scheduledYieldAssets);
        assertEq(strategy.availableToWithdraw(),   strategyBalance - scheduledYieldAssets);
        assertEq(strategy.assetsUnderManagement(), strategyBalance - scheduledYieldAssets);

        vm.expectEmit();
        emit IMapleTradingStrategy.YieldRealized(tradingAddress, scheduledYieldAssets, newYieldAmount, 0, 0, newYieldDuration, "");

        vm.prank(tradingAddress);
        strategy.realizeYield(newYieldAmount, newYieldDuration, "");

        assertEq(asset.balanceOf(address(strategy)),         strategyBalance + newYieldAmount);
        assertEq(asset.balanceOf(address(tradingAddress)),   0);
        assertEq(asset.balanceOf(address(strategyDelegate)), 0);
        assertEq(asset.balanceOf(address(mapleTreasury)),    0);

        assertEq(strategy.scheduledYieldAssets(), scheduledYieldAssets + newYieldAmount);
        assertEq(strategy.yieldStart(),           yieldStart);
        assertEq(strategy.yieldDeadline(),        yieldStart + newYieldDuration);

        assertEq(strategy.realizedAssets(),        0);
        assertEq(strategy.unrealizedAssets(),      scheduledYieldAssets + newYieldAmount);
        assertEq(strategy.availableToWithdraw(),   strategyBalance - scheduledYieldAssets);
        assertEq(strategy.assetsUnderManagement(), strategyBalance - scheduledYieldAssets);
    }

    function test_realizeYield_success_nonZeroYield_nonZeroDuration_noFees_bufferAccruing() external {
        strategy.__setFeeRates(0, 0);

        uint256 elapsedDuration  = yieldAccruing - yieldStart;
        uint256 totalDuration    = yieldDeadline - yieldStart;

        uint256 realizedAssets   = scheduledYieldAssets * elapsedDuration / totalDuration;
        uint256 unrealizedAssets = scheduledYieldAssets - realizedAssets;

        vm.warp(yieldAccruing);

        assertEq(asset.balanceOf(address(strategy)),         strategyBalance);
        assertEq(asset.balanceOf(address(tradingAddress)),   newYieldAmount);
        assertEq(asset.balanceOf(address(strategyDelegate)), 0);
        assertEq(asset.balanceOf(address(mapleTreasury)),    0);

        assertEq(strategy.scheduledYieldAssets(), scheduledYieldAssets);
        assertEq(strategy.yieldStart(),           yieldStart);
        assertEq(strategy.yieldDeadline(),        yieldDeadline);

        assertEq(strategy.realizedAssets(),        realizedAssets);
        assertEq(strategy.unrealizedAssets(),      unrealizedAssets);
        assertEq(strategy.availableToWithdraw(),   strategyBalance - unrealizedAssets);
        assertEq(strategy.assetsUnderManagement(), strategyBalance - unrealizedAssets);

        vm.expectEmit();
        emit IMapleTradingStrategy.YieldRealized(tradingAddress, unrealizedAssets, newYieldAmount, 0, 0, newYieldDuration, "");

        vm.prank(tradingAddress);
        strategy.realizeYield(newYieldAmount, newYieldDuration, "");

        assertEq(asset.balanceOf(address(strategy)),         strategyBalance + newYieldAmount);
        assertEq(asset.balanceOf(address(tradingAddress)),   0);
        assertEq(asset.balanceOf(address(strategyDelegate)), 0);
        assertEq(asset.balanceOf(address(mapleTreasury)),    0);

        assertEq(strategy.scheduledYieldAssets(), unrealizedAssets + newYieldAmount);
        assertEq(strategy.yieldStart(),           yieldAccruing);
        assertEq(strategy.yieldDeadline(),        yieldAccruing + newYieldDuration);

        assertEq(strategy.realizedAssets(),        0);
        assertEq(strategy.unrealizedAssets(),      unrealizedAssets + newYieldAmount);
        assertEq(strategy.availableToWithdraw(),   strategyBalance - unrealizedAssets);
        assertEq(strategy.assetsUnderManagement(), strategyBalance - unrealizedAssets);
    }

    function test_realizeYield_success_nonZeroYield_nonZeroDuration_noFees_bufferAtDeadline() external {
        strategy.__setFeeRates(0, 0);

        vm.warp(yieldDeadline);

        assertEq(asset.balanceOf(address(strategy)),         strategyBalance);
        assertEq(asset.balanceOf(address(tradingAddress)),   newYieldAmount);
        assertEq(asset.balanceOf(address(strategyDelegate)), 0);
        assertEq(asset.balanceOf(address(mapleTreasury)),    0);

        assertEq(strategy.scheduledYieldAssets(), scheduledYieldAssets);
        assertEq(strategy.yieldStart(),           yieldStart);
        assertEq(strategy.yieldDeadline(),        yieldDeadline);

        assertEq(strategy.realizedAssets(),      scheduledYieldAssets);
        assertEq(strategy.unrealizedAssets(),    0);
        assertEq(strategy.availableToWithdraw(), strategyBalance);

        vm.expectEmit();
        emit IMapleTradingStrategy.YieldRealized(tradingAddress, 0, newYieldAmount, 0, 0, newYieldDuration, "");

        vm.prank(tradingAddress);
        strategy.realizeYield(newYieldAmount, newYieldDuration, "");

        assertEq(asset.balanceOf(address(strategy)),         strategyBalance + newYieldAmount);
        assertEq(asset.balanceOf(address(tradingAddress)),   0);
        assertEq(asset.balanceOf(address(strategyDelegate)), 0);
        assertEq(asset.balanceOf(address(mapleTreasury)),    0);

        assertEq(strategy.scheduledYieldAssets(), newYieldAmount);
        assertEq(strategy.yieldStart(),           yieldDeadline);
        assertEq(strategy.yieldDeadline(),        yieldDeadline + newYieldDuration);

        assertEq(strategy.realizedAssets(),      0);
        assertEq(strategy.unrealizedAssets(),    newYieldAmount);
        assertEq(strategy.availableToWithdraw(), strategyBalance);
    }

    function test_realizeYield_success_nonZeroYield_nonZeroDuration_noFees_bufferPastDeadline() external {
        strategy.__setFeeRates(0, 0);

        vm.warp(yieldFinished);

        assertEq(asset.balanceOf(address(strategy)),         strategyBalance);
        assertEq(asset.balanceOf(address(tradingAddress)),   newYieldAmount);
        assertEq(asset.balanceOf(address(strategyDelegate)), 0);
        assertEq(asset.balanceOf(address(mapleTreasury)),    0);

        assertEq(strategy.scheduledYieldAssets(), scheduledYieldAssets);
        assertEq(strategy.yieldStart(),           yieldStart);
        assertEq(strategy.yieldDeadline(),        yieldDeadline);

        assertEq(strategy.realizedAssets(),        scheduledYieldAssets);
        assertEq(strategy.unrealizedAssets(),      0);
        assertEq(strategy.availableToWithdraw(),   strategyBalance);
        assertEq(strategy.assetsUnderManagement(), strategyBalance);

        vm.expectEmit();
        emit IMapleTradingStrategy.YieldRealized(tradingAddress, 0, newYieldAmount, 0, 0, newYieldDuration, "");

        vm.prank(tradingAddress);
        strategy.realizeYield(newYieldAmount, newYieldDuration, "");

        assertEq(asset.balanceOf(address(strategy)),         strategyBalance + newYieldAmount);
        assertEq(asset.balanceOf(address(tradingAddress)),   0);
        assertEq(asset.balanceOf(address(strategyDelegate)), 0);
        assertEq(asset.balanceOf(address(mapleTreasury)),    0);

        assertEq(strategy.scheduledYieldAssets(), newYieldAmount);
        assertEq(strategy.yieldStart(),           yieldFinished);
        assertEq(strategy.yieldDeadline(),        yieldFinished + newYieldDuration);

        assertEq(strategy.realizedAssets(),        0);
        assertEq(strategy.unrealizedAssets(),      newYieldAmount);
        assertEq(strategy.availableToWithdraw(),   strategyBalance);
        assertEq(strategy.assetsUnderManagement(), strategyBalance);
    }

    /**************************************************************************************************************************************/
    /*** Non-Zero Yield — Non-Zero Duration — With Fees                                                                                 ***/
    /**************************************************************************************************************************************/

    function test_realizeYield_success_nonZeroYield_nonZeroDuration_withFees_noBuffer() external {
        vm.prank(tradingAddress);
        strategy.realizeYield(0, 0, "FLUSH");

        uint256 delegateFee    = newYieldAmount * delegateFeeRate / 1e6;
        uint256 protocolFee    = newYieldAmount * protocolFeeRate / 1e6;
        uint256 netYieldAmount = newYieldAmount - delegateFee - protocolFee;

        assertEq(asset.balanceOf(address(strategy)),         strategyBalance);
        assertEq(asset.balanceOf(address(tradingAddress)),   newYieldAmount);
        assertEq(asset.balanceOf(address(strategyDelegate)), 0);
        assertEq(asset.balanceOf(address(mapleTreasury)),    0);

        assertEq(strategy.scheduledYieldAssets(), scheduledYieldAssets);
        assertEq(strategy.yieldStart(),           yieldStart);
        assertEq(strategy.yieldDeadline(),        yieldStart);

        assertEq(strategy.realizedAssets(),        scheduledYieldAssets);
        assertEq(strategy.unrealizedAssets(),      0);
        assertEq(strategy.availableToWithdraw(),   strategyBalance);
        assertEq(strategy.assetsUnderManagement(), strategyBalance);

        vm.expectEmit();
        emit IMapleTradingStrategy.YieldRealized(tradingAddress, 0, netYieldAmount, delegateFee, protocolFee, newYieldDuration, "");

        vm.prank(tradingAddress);
        strategy.realizeYield(newYieldAmount, newYieldDuration, "");

        assertEq(asset.balanceOf(address(strategy)),         strategyBalance + netYieldAmount);
        assertEq(asset.balanceOf(address(tradingAddress)),   0);
        assertEq(asset.balanceOf(address(strategyDelegate)), delegateFee);
        assertEq(asset.balanceOf(address(mapleTreasury)),    protocolFee);

        assertEq(strategy.scheduledYieldAssets(), netYieldAmount);
        assertEq(strategy.yieldStart(),           yieldStart);
        assertEq(strategy.yieldDeadline(),        yieldStart + newYieldDuration);

        assertEq(strategy.realizedAssets(),        0);
        assertEq(strategy.unrealizedAssets(),      netYieldAmount);
        assertEq(strategy.availableToWithdraw(),   strategyBalance);
        assertEq(strategy.assetsUnderManagement(), strategyBalance);
    }

    function test_realizeYield_success_nonZeroYield_nonZeroDuration_withFees_bufferAtStart() external {
        uint256 delegateFee    = newYieldAmount * delegateFeeRate / 1e6;
        uint256 protocolFee    = newYieldAmount * protocolFeeRate / 1e6;
        uint256 netYieldAmount = newYieldAmount - delegateFee - protocolFee;

        assertEq(asset.balanceOf(address(strategy)),         strategyBalance);
        assertEq(asset.balanceOf(address(tradingAddress)),   newYieldAmount);
        assertEq(asset.balanceOf(address(strategyDelegate)), 0);
        assertEq(asset.balanceOf(address(mapleTreasury)),    0);

        assertEq(strategy.scheduledYieldAssets(), scheduledYieldAssets);
        assertEq(strategy.yieldStart(),           yieldStart);
        assertEq(strategy.yieldDeadline(),        yieldDeadline);

        assertEq(strategy.realizedAssets(),        0);
        assertEq(strategy.unrealizedAssets(),      scheduledYieldAssets);
        assertEq(strategy.availableToWithdraw(),   strategyBalance - scheduledYieldAssets);
        assertEq(strategy.assetsUnderManagement(), strategyBalance - scheduledYieldAssets);

        vm.expectEmit();
        emit IMapleTradingStrategy.YieldRealized(
            tradingAddress,
            scheduledYieldAssets,
            netYieldAmount,
            delegateFee,
            protocolFee,
            newYieldDuration,
            ""
        );

        vm.prank(tradingAddress);
        strategy.realizeYield(newYieldAmount, newYieldDuration, "");

        assertEq(asset.balanceOf(address(strategy)),         strategyBalance + netYieldAmount);
        assertEq(asset.balanceOf(address(tradingAddress)),   0);
        assertEq(asset.balanceOf(address(strategyDelegate)), delegateFee);
        assertEq(asset.balanceOf(address(mapleTreasury)),    protocolFee);

        assertEq(strategy.scheduledYieldAssets(), scheduledYieldAssets + netYieldAmount);
        assertEq(strategy.yieldStart(),           yieldStart);
        assertEq(strategy.yieldDeadline(),        yieldStart + newYieldDuration);

        assertEq(strategy.realizedAssets(),        0);
        assertEq(strategy.unrealizedAssets(),      scheduledYieldAssets + netYieldAmount);
        assertEq(strategy.availableToWithdraw(),   strategyBalance - scheduledYieldAssets);
        assertEq(strategy.assetsUnderManagement(), strategyBalance - scheduledYieldAssets);
    }

    function test_realizeYield_success_nonZeroYield_nonZeroDuration_withFees_bufferAccruing() external {
        uint256 elapsedDuration  = yieldAccruing - yieldStart;
        uint256 totalDuration    = yieldDeadline - yieldStart;

        uint256 realizedAssets   = scheduledYieldAssets * elapsedDuration / totalDuration;
        uint256 unrealizedAssets = scheduledYieldAssets - realizedAssets;

        uint256 delegateFee    = newYieldAmount * delegateFeeRate / 1e6;
        uint256 protocolFee    = newYieldAmount * protocolFeeRate / 1e6;
        uint256 netYieldAmount = newYieldAmount - delegateFee - protocolFee;

        vm.warp(yieldAccruing);

        assertEq(asset.balanceOf(address(strategy)),         strategyBalance);
        assertEq(asset.balanceOf(address(tradingAddress)),   newYieldAmount);
        assertEq(asset.balanceOf(address(strategyDelegate)), 0);
        assertEq(asset.balanceOf(address(mapleTreasury)),    0);

        assertEq(strategy.scheduledYieldAssets(), scheduledYieldAssets);
        assertEq(strategy.yieldStart(),           yieldStart);
        assertEq(strategy.yieldDeadline(),        yieldDeadline);

        assertEq(strategy.realizedAssets(),        realizedAssets);
        assertEq(strategy.unrealizedAssets(),      unrealizedAssets);
        assertEq(strategy.availableToWithdraw(),   strategyBalance - unrealizedAssets);
        assertEq(strategy.assetsUnderManagement(), strategyBalance - unrealizedAssets);

        vm.expectEmit();
        emit IMapleTradingStrategy.YieldRealized(
            tradingAddress,
            unrealizedAssets,
            netYieldAmount,
            delegateFee,
            protocolFee,
            newYieldDuration,
            ""
        );

        vm.prank(tradingAddress);
        strategy.realizeYield(newYieldAmount, newYieldDuration, "");

        assertEq(asset.balanceOf(address(strategy)),         strategyBalance + netYieldAmount);
        assertEq(asset.balanceOf(address(tradingAddress)),   0);
        assertEq(asset.balanceOf(address(strategyDelegate)), delegateFee);
        assertEq(asset.balanceOf(address(mapleTreasury)),    protocolFee);

        assertEq(strategy.scheduledYieldAssets(), unrealizedAssets + netYieldAmount);
        assertEq(strategy.yieldStart(),           yieldAccruing);
        assertEq(strategy.yieldDeadline(),        yieldAccruing + newYieldDuration);

        assertEq(strategy.realizedAssets(),        0);
        assertEq(strategy.unrealizedAssets(),      unrealizedAssets + netYieldAmount);
        assertEq(strategy.availableToWithdraw(),   strategyBalance - unrealizedAssets);
        assertEq(strategy.assetsUnderManagement(), strategyBalance - unrealizedAssets);
    }

    function test_realizeYield_success_nonZeroYield_nonZeroDuration_withFees_bufferAtDeadline() external {
        uint256 delegateFee    = newYieldAmount * delegateFeeRate / 1e6;
        uint256 protocolFee    = newYieldAmount * protocolFeeRate / 1e6;
        uint256 netYieldAmount = newYieldAmount - delegateFee - protocolFee;

        vm.warp(yieldDeadline);

        assertEq(asset.balanceOf(address(strategy)),         strategyBalance);
        assertEq(asset.balanceOf(address(tradingAddress)),   newYieldAmount);
        assertEq(asset.balanceOf(address(strategyDelegate)), 0);
        assertEq(asset.balanceOf(address(mapleTreasury)),    0);

        assertEq(strategy.scheduledYieldAssets(), scheduledYieldAssets);
        assertEq(strategy.yieldStart(),           yieldStart);
        assertEq(strategy.yieldDeadline(),        yieldDeadline);

        assertEq(strategy.realizedAssets(),      scheduledYieldAssets);
        assertEq(strategy.unrealizedAssets(),    0);
        assertEq(strategy.availableToWithdraw(), strategyBalance);

        vm.expectEmit();
        emit IMapleTradingStrategy.YieldRealized(tradingAddress, 0, netYieldAmount, delegateFee, protocolFee, newYieldDuration, "");

        vm.prank(tradingAddress);
        strategy.realizeYield(newYieldAmount, newYieldDuration, "");

        assertEq(asset.balanceOf(address(strategy)),         strategyBalance + netYieldAmount);
        assertEq(asset.balanceOf(address(tradingAddress)),   0);
        assertEq(asset.balanceOf(address(strategyDelegate)), delegateFee);
        assertEq(asset.balanceOf(address(mapleTreasury)),    protocolFee);

        assertEq(strategy.scheduledYieldAssets(), netYieldAmount);
        assertEq(strategy.yieldStart(),           yieldDeadline);
        assertEq(strategy.yieldDeadline(),        yieldDeadline + newYieldDuration);

        assertEq(strategy.realizedAssets(),      0);
        assertEq(strategy.unrealizedAssets(),    netYieldAmount);
        assertEq(strategy.availableToWithdraw(), strategyBalance);
    }

    function test_realizeYield_success_nonZeroYield_nonZeroDuration_withFees_bufferPastDeadline() external {
        uint256 delegateFee    = newYieldAmount * delegateFeeRate / 1e6;
        uint256 protocolFee    = newYieldAmount * protocolFeeRate / 1e6;
        uint256 netYieldAmount = newYieldAmount - delegateFee - protocolFee;

        vm.warp(yieldFinished);

        assertEq(asset.balanceOf(address(strategy)),         strategyBalance);
        assertEq(asset.balanceOf(address(tradingAddress)),   newYieldAmount);
        assertEq(asset.balanceOf(address(strategyDelegate)), 0);
        assertEq(asset.balanceOf(address(mapleTreasury)),    0);

        assertEq(strategy.scheduledYieldAssets(), scheduledYieldAssets);
        assertEq(strategy.yieldStart(),           yieldStart);
        assertEq(strategy.yieldDeadline(),        yieldDeadline);

        assertEq(strategy.realizedAssets(),        scheduledYieldAssets);
        assertEq(strategy.unrealizedAssets(),      0);
        assertEq(strategy.availableToWithdraw(),   strategyBalance);
        assertEq(strategy.assetsUnderManagement(), strategyBalance);

        vm.expectEmit();
        emit IMapleTradingStrategy.YieldRealized(tradingAddress, 0, netYieldAmount, delegateFee, protocolFee, newYieldDuration, "");

        vm.prank(tradingAddress);
        strategy.realizeYield(newYieldAmount, newYieldDuration, "");

        assertEq(asset.balanceOf(address(strategy)),         strategyBalance + netYieldAmount);
        assertEq(asset.balanceOf(address(tradingAddress)),   0);
        assertEq(asset.balanceOf(address(strategyDelegate)), delegateFee);
        assertEq(asset.balanceOf(address(mapleTreasury)),    protocolFee);

        assertEq(strategy.scheduledYieldAssets(), netYieldAmount);
        assertEq(strategy.yieldStart(),           yieldFinished);
        assertEq(strategy.yieldDeadline(),        yieldFinished + newYieldDuration);

        assertEq(strategy.realizedAssets(),        0);
        assertEq(strategy.unrealizedAssets(),      netYieldAmount);
        assertEq(strategy.availableToWithdraw(),   strategyBalance);
        assertEq(strategy.assetsUnderManagement(), strategyBalance);
    }

    /**************************************************************************************************************************************/
    /*** Non-Zero Yield — Non-Zero Duration — Fees Round to Zero                                                                        ***/
    /**************************************************************************************************************************************/

    function test_realizeYield_success_nonZeroYield_nonZeroDuration_feesRoundToZero_noBuffer() external {
        vm.prank(tradingAddress);
        strategy.realizeYield(0, 0, "FLUSH");

        assertEq(asset.balanceOf(address(strategy)),         strategyBalance);
        assertEq(asset.balanceOf(address(tradingAddress)),   newYieldAmount);
        assertEq(asset.balanceOf(address(strategyDelegate)), 0);
        assertEq(asset.balanceOf(address(mapleTreasury)),    0);

        assertEq(strategy.scheduledYieldAssets(), scheduledYieldAssets);
        assertEq(strategy.yieldStart(),           yieldStart);
        assertEq(strategy.yieldDeadline(),        yieldStart);

        assertEq(strategy.realizedAssets(),        scheduledYieldAssets);
        assertEq(strategy.unrealizedAssets(),      0);
        assertEq(strategy.availableToWithdraw(),   strategyBalance);
        assertEq(strategy.assetsUnderManagement(), strategyBalance);

        vm.expectEmit();
        emit IMapleTradingStrategy.YieldRealized(tradingAddress, 0, tinyYieldAmount, 0, 0, newYieldDuration, "");

        vm.prank(tradingAddress);
        strategy.realizeYield(tinyYieldAmount, newYieldDuration, "");

        assertEq(asset.balanceOf(address(strategy)),         strategyBalance + tinyYieldAmount);
        assertEq(asset.balanceOf(address(tradingAddress)),   newYieldAmount - tinyYieldAmount);
        assertEq(asset.balanceOf(address(strategyDelegate)), 0);
        assertEq(asset.balanceOf(address(mapleTreasury)),    0);

        assertEq(strategy.scheduledYieldAssets(), tinyYieldAmount);
        assertEq(strategy.yieldStart(),           yieldStart);
        assertEq(strategy.yieldDeadline(),        yieldStart + newYieldDuration);

        assertEq(strategy.realizedAssets(),        0);
        assertEq(strategy.unrealizedAssets(),      tinyYieldAmount);
        assertEq(strategy.availableToWithdraw(),   strategyBalance);
        assertEq(strategy.assetsUnderManagement(), strategyBalance);
    }

    function test_realizeYield_success_nonZeroYield_nonZeroDuration_feesRoundToZero_bufferAtStart() external {
        assertEq(asset.balanceOf(address(strategy)),         strategyBalance);
        assertEq(asset.balanceOf(address(tradingAddress)),   newYieldAmount);
        assertEq(asset.balanceOf(address(strategyDelegate)), 0);
        assertEq(asset.balanceOf(address(mapleTreasury)),    0);

        assertEq(strategy.scheduledYieldAssets(), scheduledYieldAssets);
        assertEq(strategy.yieldStart(),           yieldStart);
        assertEq(strategy.yieldDeadline(),        yieldDeadline);

        assertEq(strategy.realizedAssets(),        0);
        assertEq(strategy.unrealizedAssets(),      scheduledYieldAssets);
        assertEq(strategy.availableToWithdraw(),   strategyBalance - scheduledYieldAssets);
        assertEq(strategy.assetsUnderManagement(), strategyBalance - scheduledYieldAssets);

        vm.expectEmit();
        emit IMapleTradingStrategy.YieldRealized(tradingAddress, scheduledYieldAssets, tinyYieldAmount, 0, 0, newYieldDuration, "");

        vm.prank(tradingAddress);
        strategy.realizeYield(tinyYieldAmount, newYieldDuration, "");

        assertEq(asset.balanceOf(address(strategy)),         strategyBalance + tinyYieldAmount);
        assertEq(asset.balanceOf(address(tradingAddress)),   newYieldAmount - tinyYieldAmount);
        assertEq(asset.balanceOf(address(strategyDelegate)), 0);
        assertEq(asset.balanceOf(address(mapleTreasury)),    0);

        assertEq(strategy.scheduledYieldAssets(), scheduledYieldAssets + tinyYieldAmount);
        assertEq(strategy.yieldStart(),           yieldStart);
        assertEq(strategy.yieldDeadline(),        yieldStart + newYieldDuration);

        assertEq(strategy.realizedAssets(),        0);
        assertEq(strategy.unrealizedAssets(),      scheduledYieldAssets + tinyYieldAmount);
        assertEq(strategy.availableToWithdraw(),   strategyBalance - scheduledYieldAssets);
        assertEq(strategy.assetsUnderManagement(), strategyBalance - scheduledYieldAssets);
    }

    function test_realizeYield_success_nonZeroYield_nonZeroDuration_feesRoundToZero_bufferAccruing() external {
        uint256 elapsedDuration  = yieldAccruing - yieldStart;
        uint256 totalDuration    = yieldDeadline - yieldStart;

        uint256 realizedAssets   = scheduledYieldAssets * elapsedDuration / totalDuration;
        uint256 unrealizedAssets = scheduledYieldAssets - realizedAssets;

        vm.warp(yieldAccruing);

        assertEq(asset.balanceOf(address(strategy)),         strategyBalance);
        assertEq(asset.balanceOf(address(tradingAddress)),   newYieldAmount);
        assertEq(asset.balanceOf(address(strategyDelegate)), 0);
        assertEq(asset.balanceOf(address(mapleTreasury)),    0);

        assertEq(strategy.scheduledYieldAssets(), scheduledYieldAssets);
        assertEq(strategy.yieldStart(),           yieldStart);
        assertEq(strategy.yieldDeadline(),        yieldDeadline);

        assertEq(strategy.realizedAssets(),        realizedAssets);
        assertEq(strategy.unrealizedAssets(),      unrealizedAssets);
        assertEq(strategy.availableToWithdraw(),   strategyBalance - unrealizedAssets);
        assertEq(strategy.assetsUnderManagement(), strategyBalance - unrealizedAssets);

        vm.expectEmit();
        emit IMapleTradingStrategy.YieldRealized(tradingAddress, unrealizedAssets, tinyYieldAmount, 0, 0, newYieldDuration, "");

        vm.prank(tradingAddress);
        strategy.realizeYield(tinyYieldAmount, newYieldDuration, "");

        assertEq(asset.balanceOf(address(strategy)),         strategyBalance + tinyYieldAmount);
        assertEq(asset.balanceOf(address(tradingAddress)),   newYieldAmount - tinyYieldAmount);
        assertEq(asset.balanceOf(address(strategyDelegate)), 0);
        assertEq(asset.balanceOf(address(mapleTreasury)),    0);

        assertEq(strategy.scheduledYieldAssets(), unrealizedAssets + tinyYieldAmount);
        assertEq(strategy.yieldStart(),           yieldAccruing);
        assertEq(strategy.yieldDeadline(),        yieldAccruing + newYieldDuration);

        assertEq(strategy.realizedAssets(),        0);
        assertEq(strategy.unrealizedAssets(),      unrealizedAssets + tinyYieldAmount);
        assertEq(strategy.availableToWithdraw(),   strategyBalance - unrealizedAssets);
        assertEq(strategy.assetsUnderManagement(), strategyBalance - unrealizedAssets);
    }

    function test_realizeYield_success_nonZeroYield_nonZeroDuration_feesRoundToZero_bufferAtDeadline() external {
        vm.warp(yieldDeadline);

        assertEq(asset.balanceOf(address(strategy)),         strategyBalance);
        assertEq(asset.balanceOf(address(tradingAddress)),   newYieldAmount);
        assertEq(asset.balanceOf(address(strategyDelegate)), 0);
        assertEq(asset.balanceOf(address(mapleTreasury)),    0);

        assertEq(strategy.scheduledYieldAssets(), scheduledYieldAssets);
        assertEq(strategy.yieldStart(),           yieldStart);
        assertEq(strategy.yieldDeadline(),        yieldDeadline);

        assertEq(strategy.realizedAssets(),      scheduledYieldAssets);
        assertEq(strategy.unrealizedAssets(),    0);
        assertEq(strategy.availableToWithdraw(), strategyBalance);

        vm.expectEmit();
        emit IMapleTradingStrategy.YieldRealized(tradingAddress, 0, tinyYieldAmount, 0, 0, newYieldDuration, "");

        vm.prank(tradingAddress);
        strategy.realizeYield(tinyYieldAmount, newYieldDuration, "");

        assertEq(asset.balanceOf(address(strategy)),         strategyBalance + tinyYieldAmount);
        assertEq(asset.balanceOf(address(tradingAddress)),   newYieldAmount - tinyYieldAmount);
        assertEq(asset.balanceOf(address(strategyDelegate)), 0);
        assertEq(asset.balanceOf(address(mapleTreasury)),    0);

        assertEq(strategy.scheduledYieldAssets(), tinyYieldAmount);
        assertEq(strategy.yieldStart(),           yieldDeadline);
        assertEq(strategy.yieldDeadline(),        yieldDeadline + newYieldDuration);

        assertEq(strategy.realizedAssets(),      0);
        assertEq(strategy.unrealizedAssets(),    tinyYieldAmount);
        assertEq(strategy.availableToWithdraw(), strategyBalance);
    }

    function test_realizeYield_success_nonZeroYield_nonZeroDuration_feesRoundToZero_bufferPastDeadline() external {
        vm.warp(yieldFinished);

        assertEq(asset.balanceOf(address(strategy)),         strategyBalance);
        assertEq(asset.balanceOf(address(tradingAddress)),   newYieldAmount);
        assertEq(asset.balanceOf(address(strategyDelegate)), 0);
        assertEq(asset.balanceOf(address(mapleTreasury)),    0);

        assertEq(strategy.scheduledYieldAssets(), scheduledYieldAssets);
        assertEq(strategy.yieldStart(),           yieldStart);
        assertEq(strategy.yieldDeadline(),        yieldDeadline);

        assertEq(strategy.realizedAssets(),        scheduledYieldAssets);
        assertEq(strategy.unrealizedAssets(),      0);
        assertEq(strategy.availableToWithdraw(),   strategyBalance);
        assertEq(strategy.assetsUnderManagement(), strategyBalance);

        vm.expectEmit();
        emit IMapleTradingStrategy.YieldRealized(tradingAddress, 0, tinyYieldAmount, 0, 0, newYieldDuration, "");

        vm.prank(tradingAddress);
        strategy.realizeYield(tinyYieldAmount, newYieldDuration, "");

        assertEq(asset.balanceOf(address(strategy)),         strategyBalance + tinyYieldAmount);
        assertEq(asset.balanceOf(address(tradingAddress)),   newYieldAmount - tinyYieldAmount);
        assertEq(asset.balanceOf(address(strategyDelegate)), 0);
        assertEq(asset.balanceOf(address(mapleTreasury)),    0);

        assertEq(strategy.scheduledYieldAssets(), tinyYieldAmount);
        assertEq(strategy.yieldStart(),           yieldFinished);
        assertEq(strategy.yieldDeadline(),        yieldFinished + newYieldDuration);

        assertEq(strategy.realizedAssets(),        0);
        assertEq(strategy.unrealizedAssets(),      tinyYieldAmount);
        assertEq(strategy.availableToWithdraw(),   strategyBalance);
        assertEq(strategy.assetsUnderManagement(), strategyBalance);
    }

}
