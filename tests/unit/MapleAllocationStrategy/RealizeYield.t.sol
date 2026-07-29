// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import { IMapleAllocationStrategy } from "../../../contracts/interfaces/IMapleAllocationStrategy.sol";

import { TestBase } from "../../utils/TestBase.sol";

contract RealizeYieldTestBase is TestBase {

    address managedWallet = makeAddr("managedWallet");

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

        // Whitelist the managed wallet.
        globals.__setIsInstanceOf("MAPLE_MANAGED_WALLET", managedWallet, true);
        strategy.__setPermissions(managedWallet, true);

        // Set the initial yield buffer to accrue over 3 days.
        yieldStart    = startingTime;
        yieldAccruing = startingTime + yieldDuration - 1 days;
        yieldDeadline = startingTime + yieldDuration;
        yieldFinished = startingTime + yieldDuration + 1 days;

        // Assert initial state.
        assertEq(asset.balanceOf(address(strategy)),         0);
        assertEq(asset.balanceOf(address(managedWallet)),    0);
        assertEq(asset.balanceOf(address(strategyDelegate)), 0);
        assertEq(asset.balanceOf(address(mapleTreasury)),    0);

        assertEq(strategy.yieldLastRealized(),    0);
        assertEq(strategy.scheduledYieldAssets(), 0);
        assertEq(strategy.yieldStart(),           0);
        assertEq(strategy.yieldDeadline(),        0);

        assertEq(strategy.realizedYield(),       0);
        assertEq(strategy.unrealizedYield(),     0);
        assertEq(strategy.availableToWithdraw(), 0);

        // Prepare assets for the managed wallet and the strategy.
        asset.mint(address(strategy),       strategyBalance - scheduledYieldAssets);
        asset.mint(address(managedWallet), scheduledYieldAssets + newYieldAmount);

        vm.prank(managedWallet);
        asset.approve(address(strategy), type(uint256).max);

        // Set up the initial yield buffer without fees.
        strategy.__setFeeRates(0, 0);

        vm.prank(managedWallet);
        strategy.realizeYield(scheduledYieldAssets, yieldDuration, "GG");
        strategy.__setFeeRates(delegateFeeRate, protocolFeeRate);

        // Elapse the cooldown without advancing the yield schedule.
        strategy.__setYieldLastRealized(yieldStart - 1 hours);

        // Assert state after setup.
        assertEq(asset.balanceOf(address(strategy)),         strategyBalance);
        assertEq(asset.balanceOf(address(managedWallet)),    newYieldAmount);
        assertEq(asset.balanceOf(address(strategyDelegate)), 0);
        assertEq(asset.balanceOf(address(mapleTreasury)),    0);

        assertEq(strategy.yieldLastRealized(),    yieldStart - 1 hours);
        assertEq(strategy.scheduledYieldAssets(), scheduledYieldAssets);
        assertEq(strategy.yieldStart(),           yieldStart);
        assertEq(strategy.yieldDeadline(),        yieldDeadline);

        assertEq(strategy.realizedYield(),       0);
        assertEq(strategy.unrealizedYield(),     scheduledYieldAssets);
        assertEq(strategy.availableToWithdraw(), strategyBalance - scheduledYieldAssets);
    }

}

contract RealizeYieldFailureTests is RealizeYieldTestBase {

    function test_realizeYield_revert_functionPaused() external {
        globals.__setIsFunctionPaused(IMapleAllocationStrategy.realizeYield.selector, true);

        vm.prank(managedWallet);
        vm.expectRevert("MAS:PAUSED");
        strategy.realizeYield(newYieldAmount, newYieldDuration, "");
    }

    function test_realizeYield_revert_reentrancy() external {
        strategy.__setLocked(2);

        vm.prank(managedWallet);
        vm.expectRevert("MAS:LOCKED");
        strategy.realizeYield(newYieldAmount, newYieldDuration, "");
    }

    function test_realizeYield_revert_notManagedWallet() external {
        globals.__setIsInstanceOf("MAPLE_MANAGED_WALLET", managedWallet, false);

        vm.prank(managedWallet);
        vm.expectRevert("MAS:NOT_MAPLE_MANAGED_WALLET");
        strategy.realizeYield(newYieldAmount, newYieldDuration, "");
    }

    function test_realizeYield_revert_notAllowed() external {
        strategy.__setPermissions(managedWallet, false);

        vm.prank(managedWallet);
        vm.expectRevert("MAS:RY:NOT_ALLOWED");
        strategy.realizeYield(newYieldAmount, newYieldDuration, "");
    }

    function test_realizeYield_revert_zeroCap() external {
        strategy.__setYieldCap(0);

        vm.prank(managedWallet);
        vm.expectRevert("MAS:RY:CAP_EXCEEDED");
        strategy.realizeYield(1, 0, "");
    }

    function test_realizeYield_revert_capExceeded() external {
        strategy.__setYieldCap(newYieldAmount - 1);

        vm.prank(managedWallet);
        vm.expectRevert("MAS:RY:CAP_EXCEEDED");
        strategy.realizeYield(newYieldAmount, newYieldDuration, "");
    }

    function test_realizeYield_revert_cooldown() external {
        vm.prank(managedWallet);
        strategy.realizeYield(0, 0, "");

        vm.warp(yieldStart + 1 hours - 1);

        assertEq(strategy.yieldCooldown(), 1 seconds);

        vm.prank(managedWallet);
        vm.expectRevert("MAS:RY:COOLDOWN");
        strategy.realizeYield(0, 0, "");
    }

    function test_realizeYield_revert_cooldown_differentManagedWallet() external {
        address secondManagedWallet = makeAddr("secondManagedWallet");

        globals.__setIsInstanceOf("MAPLE_MANAGED_WALLET", secondManagedWallet, true);
        strategy.__setPermissions(secondManagedWallet, true);

        vm.prank(managedWallet);
        strategy.realizeYield(0, 0, "");

        assertEq(strategy.yieldCooldown(), 1 hours);

        vm.prank(secondManagedWallet);
        vm.expectRevert("MAS:RY:COOLDOWN");
        strategy.realizeYield(0, 0, "");
    }

    function test_realizeYield_revert_transferFromFailed() external {
        asset.__setTransferFromReverts(true);

        vm.prank(managedWallet);
        vm.expectRevert("MAS:RY:TRANSFER_FROM_FAILED");
        strategy.realizeYield(newYieldAmount, newYieldDuration, "");
    }

    function test_realizeYield_revert_delegateFeeTransferFailed() external {
        strategy.__setFeeRates(delegateFeeRate, 0);
        asset.__setTransferReverts(true);

        vm.prank(managedWallet);
        vm.expectRevert("MAS:CF:DELEGATE_TRANSFER_FAILED");
        strategy.realizeYield(newYieldAmount, newYieldDuration, "");
    }

    function test_realizeYield_revert_protocolFeeTransferFailed() external {
        strategy.__setFeeRates(0, protocolFeeRate);
        asset.__setTransferReverts(true);

        vm.prank(managedWallet);
        vm.expectRevert("MAS:CF:PROTOCOL_TRANSFER_FAILED");
        strategy.realizeYield(newYieldAmount, newYieldDuration, "");
    }

}

contract RealizeYieldSuccessTests is RealizeYieldTestBase {

    function test_realizeYield_success_cooldownElapsed() external {
        assertEq(strategy.yieldLastRealized(), yieldStart - 1 hours);
        assertEq(strategy.yieldCooldown(),     0);

        vm.prank(managedWallet);
        strategy.realizeYield(0, 0, "");

        assertEq(strategy.yieldLastRealized(), yieldStart);
        assertEq(strategy.yieldCooldown(),     1 hours);

        vm.warp(yieldStart + 1 hours);

        assertEq(strategy.yieldCooldown(), 0);

        vm.prank(managedWallet);
        strategy.realizeYield(0, 0, "");

        assertEq(strategy.yieldLastRealized(), yieldStart + 1 hours);
    }

    function test_realizeYield_success_initialCooldownTimestamp() external {
        strategy.__setYieldLastRealized(0);

        assertEq(strategy.yieldLastRealized(), 0);
        assertEq(strategy.yieldCooldown(),     0);

        vm.prank(managedWallet);
        strategy.realizeYield(0, 0, "");

        assertEq(strategy.yieldCooldown(),     1 hours);
        assertEq(strategy.yieldLastRealized(), yieldStart);
    }

    /**************************************************************************************************************************************/
    /*** Zero Yield — Zero Duration - With Fees                                                                                         ***/
    /**************************************************************************************************************************************/

    function test_realizeYield_success_zeroYield_zeroDuration_withFees_noBuffer() external {
        vm.prank(managedWallet);
        strategy.realizeYield(0, 0, "FLUSH");

        assertEq(asset.balanceOf(address(strategy)),         strategyBalance);
        assertEq(asset.balanceOf(address(managedWallet)),    newYieldAmount);
        assertEq(asset.balanceOf(address(strategyDelegate)), 0);
        assertEq(asset.balanceOf(address(mapleTreasury)),    0);

        assertEq(strategy.scheduledYieldAssets(), scheduledYieldAssets);
        assertEq(strategy.yieldStart(),           yieldStart);
        assertEq(strategy.yieldDeadline(),        yieldStart);

        assertEq(strategy.realizedYield(),         scheduledYieldAssets);
        assertEq(strategy.unrealizedYield(),       0);
        assertEq(strategy.availableToWithdraw(),   strategyBalance);
        assertEq(strategy.assetsUnderManagement(), strategyBalance);

        vm.warp(yieldStart + 2 hours);

        vm.expectEmit();
        emit IMapleAllocationStrategy.YieldRealized(managedWallet, 0, 0, 0, 0, 0, "");

        vm.prank(managedWallet);
        strategy.realizeYield(0, 0, "");

        assertEq(asset.balanceOf(address(strategy)),         strategyBalance);
        assertEq(asset.balanceOf(address(managedWallet)),    newYieldAmount);
        assertEq(asset.balanceOf(address(strategyDelegate)), 0);
        assertEq(asset.balanceOf(address(mapleTreasury)),    0);

        assertEq(strategy.scheduledYieldAssets(), 0);
        assertEq(strategy.yieldStart(),           yieldStart + 2 hours);
        assertEq(strategy.yieldDeadline(),        yieldStart + 2 hours);

        assertEq(strategy.realizedYield(),         0);
        assertEq(strategy.unrealizedYield(),       0);
        assertEq(strategy.availableToWithdraw(),   strategyBalance);
        assertEq(strategy.assetsUnderManagement(), strategyBalance);
    }

    function test_realizeYield_success_zeroYield_zeroDuration_withFees_bufferAtStart() external {
        assertEq(asset.balanceOf(address(strategy)),         strategyBalance);
        assertEq(asset.balanceOf(address(managedWallet)),    newYieldAmount);
        assertEq(asset.balanceOf(address(strategyDelegate)), 0);
        assertEq(asset.balanceOf(address(mapleTreasury)),    0);

        assertEq(strategy.scheduledYieldAssets(), scheduledYieldAssets);
        assertEq(strategy.yieldStart(),           yieldStart);
        assertEq(strategy.yieldDeadline(),        yieldDeadline);

        assertEq(strategy.realizedYield(),         0);
        assertEq(strategy.unrealizedYield(),       scheduledYieldAssets);
        assertEq(strategy.availableToWithdraw(),   strategyBalance - scheduledYieldAssets);
        assertEq(strategy.assetsUnderManagement(), strategyBalance - scheduledYieldAssets);

        vm.expectEmit();
        emit IMapleAllocationStrategy.YieldRealized(managedWallet, scheduledYieldAssets, 0, 0, 0, 0, "");

        vm.prank(managedWallet);
        strategy.realizeYield(0, 0, "");

        assertEq(asset.balanceOf(address(strategy)),         strategyBalance);
        assertEq(asset.balanceOf(address(managedWallet)),    newYieldAmount);
        assertEq(asset.balanceOf(address(strategyDelegate)), 0);
        assertEq(asset.balanceOf(address(mapleTreasury)),    0);

        assertEq(strategy.scheduledYieldAssets(), scheduledYieldAssets);
        assertEq(strategy.yieldStart(),           yieldStart);
        assertEq(strategy.yieldDeadline(),        yieldStart);

        assertEq(strategy.realizedYield(),         scheduledYieldAssets);
        assertEq(strategy.unrealizedYield(),       0);
        assertEq(strategy.availableToWithdraw(),   strategyBalance);
        assertEq(strategy.assetsUnderManagement(), strategyBalance);
    }

    function test_realizeYield_success_zeroYield_zeroDuration_withFees_bufferAccruing() external {
        uint256 elapsedDuration  = yieldAccruing - yieldStart;
        uint256 totalDuration    = yieldDeadline - yieldStart;

        uint256 realizedYield   = scheduledYieldAssets * elapsedDuration / totalDuration;
        uint256 unrealizedYield = scheduledYieldAssets - realizedYield;

        vm.warp(yieldAccruing);

        assertEq(asset.balanceOf(address(strategy)),         strategyBalance);
        assertEq(asset.balanceOf(address(managedWallet)),    newYieldAmount);
        assertEq(asset.balanceOf(address(strategyDelegate)), 0);
        assertEq(asset.balanceOf(address(mapleTreasury)),    0);

        assertEq(strategy.scheduledYieldAssets(), scheduledYieldAssets);
        assertEq(strategy.yieldStart(),           yieldStart);
        assertEq(strategy.yieldDeadline(),        yieldDeadline);

        assertEq(strategy.realizedYield(),         realizedYield);
        assertEq(strategy.unrealizedYield(),       unrealizedYield);
        assertEq(strategy.availableToWithdraw(),   strategyBalance - unrealizedYield);
        assertEq(strategy.assetsUnderManagement(), strategyBalance - unrealizedYield);

        vm.expectEmit();
        emit IMapleAllocationStrategy.YieldRealized(managedWallet, unrealizedYield, 0, 0, 0, 0, "");

        vm.prank(managedWallet);
        strategy.realizeYield(0, 0, "");

        assertEq(asset.balanceOf(address(strategy)),         strategyBalance);
        assertEq(asset.balanceOf(address(managedWallet)),    newYieldAmount);
        assertEq(asset.balanceOf(address(strategyDelegate)), 0);
        assertEq(asset.balanceOf(address(mapleTreasury)),    0);

        assertEq(strategy.scheduledYieldAssets(), unrealizedYield);
        assertEq(strategy.yieldStart(),           yieldAccruing);
        assertEq(strategy.yieldDeadline(),        yieldAccruing);

        assertEq(strategy.realizedYield(),         unrealizedYield);
        assertEq(strategy.unrealizedYield(),       0);
        assertEq(strategy.availableToWithdraw(),   strategyBalance);
        assertEq(strategy.assetsUnderManagement(), strategyBalance);
    }

    function test_realizeYield_success_zeroYield_zeroDuration_withFees_bufferAtDeadline() external {
        vm.warp(yieldDeadline);

        assertEq(asset.balanceOf(address(strategy)),         strategyBalance);
        assertEq(asset.balanceOf(address(managedWallet)),    newYieldAmount);
        assertEq(asset.balanceOf(address(strategyDelegate)), 0);
        assertEq(asset.balanceOf(address(mapleTreasury)),    0);

        assertEq(strategy.scheduledYieldAssets(), scheduledYieldAssets);
        assertEq(strategy.yieldStart(),           yieldStart);
        assertEq(strategy.yieldDeadline(),        yieldDeadline);

        assertEq(strategy.realizedYield(),       scheduledYieldAssets);
        assertEq(strategy.unrealizedYield(),     0);
        assertEq(strategy.availableToWithdraw(), strategyBalance);

        vm.expectEmit();
        emit IMapleAllocationStrategy.YieldRealized(managedWallet, 0, 0, 0, 0, 0, "");

        vm.prank(managedWallet);
        strategy.realizeYield(0, 0, "");

        assertEq(asset.balanceOf(address(strategy)),         strategyBalance);
        assertEq(asset.balanceOf(address(managedWallet)),    newYieldAmount);
        assertEq(asset.balanceOf(address(strategyDelegate)), 0);
        assertEq(asset.balanceOf(address(mapleTreasury)),    0);

        assertEq(strategy.scheduledYieldAssets(), 0);
        assertEq(strategy.yieldStart(),           yieldDeadline);
        assertEq(strategy.yieldDeadline(),        yieldDeadline);

        assertEq(strategy.realizedYield(),       0);
        assertEq(strategy.unrealizedYield(),     0);
        assertEq(strategy.availableToWithdraw(), strategyBalance);
    }

    function test_realizeYield_success_zeroYield_zeroDuration_withFees_bufferPastDeadline() external {
        vm.warp(yieldFinished);

        assertEq(asset.balanceOf(address(strategy)),         strategyBalance);
        assertEq(asset.balanceOf(address(managedWallet)),    newYieldAmount);
        assertEq(asset.balanceOf(address(strategyDelegate)), 0);
        assertEq(asset.balanceOf(address(mapleTreasury)),    0);

        assertEq(strategy.scheduledYieldAssets(), scheduledYieldAssets);
        assertEq(strategy.yieldStart(),           yieldStart);
        assertEq(strategy.yieldDeadline(),        yieldDeadline);

        assertEq(strategy.realizedYield(),         scheduledYieldAssets);
        assertEq(strategy.unrealizedYield(),       0);
        assertEq(strategy.availableToWithdraw(),   strategyBalance);
        assertEq(strategy.assetsUnderManagement(), strategyBalance);

        vm.expectEmit();
        emit IMapleAllocationStrategy.YieldRealized(managedWallet, 0, 0, 0, 0, 0, "");

        vm.prank(managedWallet);
        strategy.realizeYield(0, 0, "");

        assertEq(asset.balanceOf(address(strategy)),         strategyBalance);
        assertEq(asset.balanceOf(address(managedWallet)),    newYieldAmount);
        assertEq(asset.balanceOf(address(strategyDelegate)), 0);
        assertEq(asset.balanceOf(address(mapleTreasury)),    0);

        assertEq(strategy.scheduledYieldAssets(), 0);
        assertEq(strategy.yieldStart(),           yieldFinished);
        assertEq(strategy.yieldDeadline(),        yieldFinished);

        assertEq(strategy.realizedYield(),         0);
        assertEq(strategy.unrealizedYield(),       0);
        assertEq(strategy.availableToWithdraw(),   strategyBalance);
        assertEq(strategy.assetsUnderManagement(), strategyBalance);
    }

    /**************************************************************************************************************************************/
    /*** Zero Yield — Non-Zero Duration — With Fees                                                                                     ***/
    /**************************************************************************************************************************************/

    function test_realizeYield_success_zeroYield_nonZeroDuration_withFees_noBuffer() external {
        vm.prank(managedWallet);
        strategy.realizeYield(0, 0, "FLUSH");

        assertEq(asset.balanceOf(address(strategy)),         strategyBalance);
        assertEq(asset.balanceOf(address(managedWallet)),    newYieldAmount);
        assertEq(asset.balanceOf(address(strategyDelegate)), 0);
        assertEq(asset.balanceOf(address(mapleTreasury)),    0);

        assertEq(strategy.scheduledYieldAssets(), scheduledYieldAssets);
        assertEq(strategy.yieldStart(),           yieldStart);
        assertEq(strategy.yieldDeadline(),        yieldStart);

        assertEq(strategy.realizedYield(),         scheduledYieldAssets);
        assertEq(strategy.unrealizedYield(),       0);
        assertEq(strategy.availableToWithdraw(),   strategyBalance);
        assertEq(strategy.assetsUnderManagement(), strategyBalance);

        vm.warp(yieldStart + 2 hours);

        vm.expectEmit();
        emit IMapleAllocationStrategy.YieldRealized(managedWallet, 0, 0, 0, 0, newYieldDuration, "");

        vm.prank(managedWallet);
        strategy.realizeYield(0, newYieldDuration, "");

        assertEq(asset.balanceOf(address(strategy)),         strategyBalance);
        assertEq(asset.balanceOf(address(managedWallet)),    newYieldAmount);
        assertEq(asset.balanceOf(address(strategyDelegate)), 0);
        assertEq(asset.balanceOf(address(mapleTreasury)),    0);

        assertEq(strategy.scheduledYieldAssets(), 0);
        assertEq(strategy.yieldStart(),           yieldStart + 2 hours);
        assertEq(strategy.yieldDeadline(),        yieldStart + 2 hours + newYieldDuration);

        assertEq(strategy.realizedYield(),         0);
        assertEq(strategy.unrealizedYield(),       0);
        assertEq(strategy.availableToWithdraw(),   strategyBalance);
        assertEq(strategy.assetsUnderManagement(), strategyBalance);
    }

    function test_realizeYield_success_zeroYield_nonZeroDuration_withFees_bufferAtStart() external {
        assertEq(asset.balanceOf(address(strategy)),         strategyBalance);
        assertEq(asset.balanceOf(address(managedWallet)),    newYieldAmount);
        assertEq(asset.balanceOf(address(strategyDelegate)), 0);
        assertEq(asset.balanceOf(address(mapleTreasury)),    0);

        assertEq(strategy.scheduledYieldAssets(), scheduledYieldAssets);
        assertEq(strategy.yieldStart(),           yieldStart);
        assertEq(strategy.yieldDeadline(),        yieldDeadline);

        assertEq(strategy.realizedYield(),         0);
        assertEq(strategy.unrealizedYield(),       scheduledYieldAssets);
        assertEq(strategy.availableToWithdraw(),   strategyBalance - scheduledYieldAssets);
        assertEq(strategy.assetsUnderManagement(), strategyBalance - scheduledYieldAssets);

        vm.expectEmit();
        emit IMapleAllocationStrategy.YieldRealized(managedWallet, scheduledYieldAssets, 0, 0, 0, newYieldDuration, "");

        vm.prank(managedWallet);
        strategy.realizeYield(0, newYieldDuration, "");

        assertEq(asset.balanceOf(address(strategy)),         strategyBalance);
        assertEq(asset.balanceOf(address(managedWallet)),    newYieldAmount);
        assertEq(asset.balanceOf(address(strategyDelegate)), 0);
        assertEq(asset.balanceOf(address(mapleTreasury)),    0);

        assertEq(strategy.scheduledYieldAssets(), scheduledYieldAssets);
        assertEq(strategy.yieldStart(),           yieldStart);
        assertEq(strategy.yieldDeadline(),        yieldStart + newYieldDuration);

        assertEq(strategy.realizedYield(),         0);
        assertEq(strategy.unrealizedYield(),       scheduledYieldAssets);
        assertEq(strategy.availableToWithdraw(),   strategyBalance - scheduledYieldAssets);
        assertEq(strategy.assetsUnderManagement(), strategyBalance - scheduledYieldAssets);
    }

    function test_realizeYield_success_zeroYield_nonZeroDuration_withFees_bufferAccruing() external {
        uint256 elapsedDuration  = yieldAccruing - yieldStart;
        uint256 totalDuration    = yieldDeadline - yieldStart;

        uint256 realizedYield   = scheduledYieldAssets * elapsedDuration / totalDuration;
        uint256 unrealizedYield = scheduledYieldAssets - realizedYield;

        vm.warp(yieldAccruing);

        assertEq(asset.balanceOf(address(strategy)),         strategyBalance);
        assertEq(asset.balanceOf(address(managedWallet)),    newYieldAmount);
        assertEq(asset.balanceOf(address(strategyDelegate)), 0);
        assertEq(asset.balanceOf(address(mapleTreasury)),    0);

        assertEq(strategy.scheduledYieldAssets(), scheduledYieldAssets);
        assertEq(strategy.yieldStart(),           yieldStart);
        assertEq(strategy.yieldDeadline(),        yieldDeadline);

        assertEq(strategy.realizedYield(),         realizedYield);
        assertEq(strategy.unrealizedYield(),       unrealizedYield);
        assertEq(strategy.availableToWithdraw(),   strategyBalance - unrealizedYield);
        assertEq(strategy.assetsUnderManagement(), strategyBalance - unrealizedYield);

        vm.expectEmit();
        emit IMapleAllocationStrategy.YieldRealized(managedWallet, unrealizedYield, 0, 0, 0, newYieldDuration, "");

        vm.prank(managedWallet);
        strategy.realizeYield(0, newYieldDuration, "");

        assertEq(asset.balanceOf(address(strategy)),         strategyBalance);
        assertEq(asset.balanceOf(address(managedWallet)),    newYieldAmount);
        assertEq(asset.balanceOf(address(strategyDelegate)), 0);
        assertEq(asset.balanceOf(address(mapleTreasury)),    0);

        assertEq(strategy.scheduledYieldAssets(), unrealizedYield);
        assertEq(strategy.yieldStart(),           yieldAccruing);
        assertEq(strategy.yieldDeadline(),        yieldAccruing + newYieldDuration);

        assertEq(strategy.realizedYield(),         0);
        assertEq(strategy.unrealizedYield(),       unrealizedYield);
        assertEq(strategy.availableToWithdraw(),   strategyBalance - unrealizedYield);
        assertEq(strategy.assetsUnderManagement(), strategyBalance - unrealizedYield);
    }

    function test_realizeYield_success_zeroYield_nonZeroDuration_withFees_bufferAtDeadline() external {
        vm.warp(yieldDeadline);

        assertEq(asset.balanceOf(address(strategy)),         strategyBalance);
        assertEq(asset.balanceOf(address(managedWallet)),    newYieldAmount);
        assertEq(asset.balanceOf(address(strategyDelegate)), 0);
        assertEq(asset.balanceOf(address(mapleTreasury)),    0);

        assertEq(strategy.scheduledYieldAssets(), scheduledYieldAssets);
        assertEq(strategy.yieldStart(),           yieldStart);
        assertEq(strategy.yieldDeadline(),        yieldDeadline);

        assertEq(strategy.realizedYield(),       scheduledYieldAssets);
        assertEq(strategy.unrealizedYield(),     0);
        assertEq(strategy.availableToWithdraw(), strategyBalance);

        vm.expectEmit();
        emit IMapleAllocationStrategy.YieldRealized(managedWallet, 0, 0, 0, 0, newYieldDuration, "");

        vm.prank(managedWallet);
        strategy.realizeYield(0, newYieldDuration, "");

        assertEq(asset.balanceOf(address(strategy)),         strategyBalance);
        assertEq(asset.balanceOf(address(managedWallet)),    newYieldAmount);
        assertEq(asset.balanceOf(address(strategyDelegate)), 0);
        assertEq(asset.balanceOf(address(mapleTreasury)),    0);

        assertEq(strategy.scheduledYieldAssets(), 0);
        assertEq(strategy.yieldStart(),           yieldDeadline);
        assertEq(strategy.yieldDeadline(),        yieldDeadline + newYieldDuration);

        assertEq(strategy.realizedYield(),       0);
        assertEq(strategy.unrealizedYield(),     0);
        assertEq(strategy.availableToWithdraw(), strategyBalance);
    }

    function test_realizeYield_success_zeroYield_nonZeroDuration_withFees_bufferPastDeadline() external {
        vm.warp(yieldFinished);

        assertEq(asset.balanceOf(address(strategy)),         strategyBalance);
        assertEq(asset.balanceOf(address(managedWallet)),    newYieldAmount);
        assertEq(asset.balanceOf(address(strategyDelegate)), 0);
        assertEq(asset.balanceOf(address(mapleTreasury)),    0);

        assertEq(strategy.scheduledYieldAssets(), scheduledYieldAssets);
        assertEq(strategy.yieldStart(),           yieldStart);
        assertEq(strategy.yieldDeadline(),        yieldDeadline);

        assertEq(strategy.realizedYield(),         scheduledYieldAssets);
        assertEq(strategy.unrealizedYield(),       0);
        assertEq(strategy.availableToWithdraw(),   strategyBalance);
        assertEq(strategy.assetsUnderManagement(), strategyBalance);

        vm.expectEmit();
        emit IMapleAllocationStrategy.YieldRealized(managedWallet, 0, 0, 0, 0, newYieldDuration, "");

        vm.prank(managedWallet);
        strategy.realizeYield(0, newYieldDuration, "");

        assertEq(asset.balanceOf(address(strategy)),         strategyBalance);
        assertEq(asset.balanceOf(address(managedWallet)),    newYieldAmount);
        assertEq(asset.balanceOf(address(strategyDelegate)), 0);
        assertEq(asset.balanceOf(address(mapleTreasury)),    0);

        assertEq(strategy.scheduledYieldAssets(), 0);
        assertEq(strategy.yieldStart(),           yieldFinished);
        assertEq(strategy.yieldDeadline(),        yieldFinished + newYieldDuration);

        assertEq(strategy.realizedYield(),         0);
        assertEq(strategy.unrealizedYield(),       0);
        assertEq(strategy.availableToWithdraw(),   strategyBalance);
        assertEq(strategy.assetsUnderManagement(), strategyBalance);
    }

    /**************************************************************************************************************************************/
    /*** Non-Zero Yield — Zero Duration — No Fees                                                                                       ***/
    /**************************************************************************************************************************************/

    function test_realizeYield_success_nonZeroYield_zeroDuration_noFees_noBuffer() external {
        strategy.__setFeeRates(0, 0);

        vm.prank(managedWallet);
        strategy.realizeYield(0, 0, "FLUSH");

        assertEq(asset.balanceOf(address(strategy)),         strategyBalance);
        assertEq(asset.balanceOf(address(managedWallet)),    newYieldAmount);
        assertEq(asset.balanceOf(address(strategyDelegate)), 0);
        assertEq(asset.balanceOf(address(mapleTreasury)),    0);

        assertEq(strategy.scheduledYieldAssets(), scheduledYieldAssets);
        assertEq(strategy.yieldStart(),           yieldStart);
        assertEq(strategy.yieldDeadline(),        yieldStart);

        assertEq(strategy.realizedYield(),         scheduledYieldAssets);
        assertEq(strategy.unrealizedYield(),       0);
        assertEq(strategy.availableToWithdraw(),   strategyBalance);
        assertEq(strategy.assetsUnderManagement(), strategyBalance);

        vm.warp(yieldStart + 2 hours);

        vm.expectEmit();
        emit IMapleAllocationStrategy.YieldRealized(managedWallet, 0, newYieldAmount, 0, 0, 0, "");

        vm.prank(managedWallet);
        strategy.realizeYield(newYieldAmount, 0, "");

        assertEq(asset.balanceOf(address(strategy)),         strategyBalance + newYieldAmount);
        assertEq(asset.balanceOf(address(managedWallet)),    0);
        assertEq(asset.balanceOf(address(strategyDelegate)), 0);
        assertEq(asset.balanceOf(address(mapleTreasury)),    0);

        assertEq(strategy.scheduledYieldAssets(), newYieldAmount);
        assertEq(strategy.yieldStart(),           yieldStart + 2 hours);
        assertEq(strategy.yieldDeadline(),        yieldStart + 2 hours);

        assertEq(strategy.realizedYield(),         newYieldAmount);
        assertEq(strategy.unrealizedYield(),       0);
        assertEq(strategy.availableToWithdraw(),   strategyBalance + newYieldAmount);
        assertEq(strategy.assetsUnderManagement(), strategyBalance + newYieldAmount);
    }

    function test_realizeYield_success_nonZeroYield_zeroDuration_noFees_bufferAtStart() external {
        strategy.__setFeeRates(0, 0);

        assertEq(asset.balanceOf(address(strategy)),         strategyBalance);
        assertEq(asset.balanceOf(address(managedWallet)),    newYieldAmount);
        assertEq(asset.balanceOf(address(strategyDelegate)), 0);
        assertEq(asset.balanceOf(address(mapleTreasury)),    0);

        assertEq(strategy.scheduledYieldAssets(), scheduledYieldAssets);
        assertEq(strategy.yieldStart(),           yieldStart);
        assertEq(strategy.yieldDeadline(),        yieldDeadline);

        assertEq(strategy.realizedYield(),         0);
        assertEq(strategy.unrealizedYield(),       scheduledYieldAssets);
        assertEq(strategy.availableToWithdraw(),   strategyBalance - scheduledYieldAssets);
        assertEq(strategy.assetsUnderManagement(), strategyBalance - scheduledYieldAssets);

        vm.expectEmit();
        emit IMapleAllocationStrategy.YieldRealized(managedWallet, scheduledYieldAssets, newYieldAmount, 0, 0, 0, "");

        vm.prank(managedWallet);
        strategy.realizeYield(newYieldAmount, 0, "");

        assertEq(asset.balanceOf(address(strategy)),         strategyBalance + newYieldAmount);
        assertEq(asset.balanceOf(address(managedWallet)),    0);
        assertEq(asset.balanceOf(address(strategyDelegate)), 0);
        assertEq(asset.balanceOf(address(mapleTreasury)),    0);

        assertEq(strategy.scheduledYieldAssets(), scheduledYieldAssets + newYieldAmount);
        assertEq(strategy.yieldStart(),           yieldStart);
        assertEq(strategy.yieldDeadline(),        yieldStart);

        assertEq(strategy.realizedYield(),         scheduledYieldAssets + newYieldAmount);
        assertEq(strategy.unrealizedYield(),       0);
        assertEq(strategy.availableToWithdraw(),   strategyBalance + newYieldAmount);
        assertEq(strategy.assetsUnderManagement(), strategyBalance + newYieldAmount);
    }

    function test_realizeYield_success_nonZeroYield_zeroDuration_noFees_bufferAccruing() external {
        strategy.__setFeeRates(0, 0);

        uint256 elapsedDuration  = yieldAccruing - yieldStart;
        uint256 totalDuration    = yieldDeadline - yieldStart;

        uint256 realizedYield   = scheduledYieldAssets * elapsedDuration / totalDuration;
        uint256 unrealizedYield = scheduledYieldAssets - realizedYield;

        vm.warp(yieldAccruing);

        assertEq(asset.balanceOf(address(strategy)),         strategyBalance);
        assertEq(asset.balanceOf(address(managedWallet)),    newYieldAmount);
        assertEq(asset.balanceOf(address(strategyDelegate)), 0);
        assertEq(asset.balanceOf(address(mapleTreasury)),    0);

        assertEq(strategy.scheduledYieldAssets(), scheduledYieldAssets);
        assertEq(strategy.yieldStart(),           yieldStart);
        assertEq(strategy.yieldDeadline(),        yieldDeadline);

        assertEq(strategy.realizedYield(),         realizedYield);
        assertEq(strategy.unrealizedYield(),       unrealizedYield);
        assertEq(strategy.availableToWithdraw(),   strategyBalance - unrealizedYield);
        assertEq(strategy.assetsUnderManagement(), strategyBalance - unrealizedYield);

        vm.expectEmit();
        emit IMapleAllocationStrategy.YieldRealized(managedWallet, unrealizedYield, newYieldAmount, 0, 0, 0, "");

        vm.prank(managedWallet);
        strategy.realizeYield(newYieldAmount, 0, "");

        assertEq(asset.balanceOf(address(strategy)),         strategyBalance + newYieldAmount);
        assertEq(asset.balanceOf(address(managedWallet)),    0);
        assertEq(asset.balanceOf(address(strategyDelegate)), 0);
        assertEq(asset.balanceOf(address(mapleTreasury)),    0);

        assertEq(strategy.scheduledYieldAssets(), unrealizedYield + newYieldAmount);
        assertEq(strategy.yieldStart(),           yieldAccruing);
        assertEq(strategy.yieldDeadline(),        yieldAccruing);

        assertEq(strategy.realizedYield(),         unrealizedYield + newYieldAmount);
        assertEq(strategy.unrealizedYield(),       0);
        assertEq(strategy.availableToWithdraw(),   strategyBalance + newYieldAmount);
        assertEq(strategy.assetsUnderManagement(), strategyBalance + newYieldAmount);
    }

    function test_realizeYield_success_nonZeroYield_zeroDuration_noFees_bufferAtDeadline() external {
        strategy.__setFeeRates(0, 0);

        vm.warp(yieldDeadline);

        assertEq(asset.balanceOf(address(strategy)),         strategyBalance);
        assertEq(asset.balanceOf(address(managedWallet)),    newYieldAmount);
        assertEq(asset.balanceOf(address(strategyDelegate)), 0);
        assertEq(asset.balanceOf(address(mapleTreasury)),    0);

        assertEq(strategy.scheduledYieldAssets(), scheduledYieldAssets);
        assertEq(strategy.yieldStart(),           yieldStart);
        assertEq(strategy.yieldDeadline(),        yieldDeadline);

        assertEq(strategy.realizedYield(),       scheduledYieldAssets);
        assertEq(strategy.unrealizedYield(),     0);
        assertEq(strategy.availableToWithdraw(), strategyBalance);

        vm.expectEmit();
        emit IMapleAllocationStrategy.YieldRealized(managedWallet, 0, newYieldAmount, 0, 0, 0, "");

        vm.prank(managedWallet);
        strategy.realizeYield(newYieldAmount, 0, "");

        assertEq(asset.balanceOf(address(strategy)),         strategyBalance + newYieldAmount);
        assertEq(asset.balanceOf(address(managedWallet)),    0);
        assertEq(asset.balanceOf(address(strategyDelegate)), 0);
        assertEq(asset.balanceOf(address(mapleTreasury)),    0);

        assertEq(strategy.scheduledYieldAssets(), newYieldAmount);
        assertEq(strategy.yieldStart(),           yieldDeadline);
        assertEq(strategy.yieldDeadline(),        yieldDeadline);

        assertEq(strategy.realizedYield(),       newYieldAmount);
        assertEq(strategy.unrealizedYield(),     0);
        assertEq(strategy.availableToWithdraw(), strategyBalance + newYieldAmount);
    }

    function test_realizeYield_success_nonZeroYield_zeroDuration_noFees_bufferPastDeadline() external {
        strategy.__setFeeRates(0, 0);

        vm.warp(yieldFinished);

        assertEq(asset.balanceOf(address(strategy)),         strategyBalance);
        assertEq(asset.balanceOf(address(managedWallet)),    newYieldAmount);
        assertEq(asset.balanceOf(address(strategyDelegate)), 0);
        assertEq(asset.balanceOf(address(mapleTreasury)),    0);

        assertEq(strategy.scheduledYieldAssets(), scheduledYieldAssets);
        assertEq(strategy.yieldStart(),           yieldStart);
        assertEq(strategy.yieldDeadline(),        yieldDeadline);

        assertEq(strategy.realizedYield(),         scheduledYieldAssets);
        assertEq(strategy.unrealizedYield(),       0);
        assertEq(strategy.availableToWithdraw(),   strategyBalance);
        assertEq(strategy.assetsUnderManagement(), strategyBalance);

        vm.expectEmit();
        emit IMapleAllocationStrategy.YieldRealized(managedWallet, 0, newYieldAmount, 0, 0, 0, "");

        vm.prank(managedWallet);
        strategy.realizeYield(newYieldAmount, 0, "");

        assertEq(asset.balanceOf(address(strategy)),         strategyBalance + newYieldAmount);
        assertEq(asset.balanceOf(address(managedWallet)),    0);
        assertEq(asset.balanceOf(address(strategyDelegate)), 0);
        assertEq(asset.balanceOf(address(mapleTreasury)),    0);

        assertEq(strategy.scheduledYieldAssets(), newYieldAmount);
        assertEq(strategy.yieldStart(),           yieldFinished);
        assertEq(strategy.yieldDeadline(),        yieldFinished);

        assertEq(strategy.realizedYield(),         newYieldAmount);
        assertEq(strategy.unrealizedYield(),       0);
        assertEq(strategy.availableToWithdraw(),   strategyBalance + newYieldAmount);
        assertEq(strategy.assetsUnderManagement(), strategyBalance + newYieldAmount);
    }

    /**************************************************************************************************************************************/
    /*** Non-Zero Yield — Zero Duration — With Fees                                                                                     ***/
    /**************************************************************************************************************************************/

    function test_realizeYield_success_nonZeroYield_zeroDuration_withFees_noBuffer() external {
        vm.prank(managedWallet);
        strategy.realizeYield(0, 0, "FLUSH");

        uint256 delegateFee    = newYieldAmount * delegateFeeRate / 1e6;
        uint256 protocolFee    = newYieldAmount * protocolFeeRate / 1e6;
        uint256 netYieldAmount = newYieldAmount - delegateFee - protocolFee;

        assertEq(asset.balanceOf(address(strategy)),         strategyBalance);
        assertEq(asset.balanceOf(address(managedWallet)),    newYieldAmount);
        assertEq(asset.balanceOf(address(strategyDelegate)), 0);
        assertEq(asset.balanceOf(address(mapleTreasury)),    0);

        assertEq(strategy.scheduledYieldAssets(), scheduledYieldAssets);
        assertEq(strategy.yieldStart(),           yieldStart);
        assertEq(strategy.yieldDeadline(),        yieldStart);

        assertEq(strategy.realizedYield(),         scheduledYieldAssets);
        assertEq(strategy.unrealizedYield(),       0);
        assertEq(strategy.availableToWithdraw(),   strategyBalance);
        assertEq(strategy.assetsUnderManagement(), strategyBalance);

        vm.warp(yieldStart + 2 hours);

        vm.expectEmit();
        emit IMapleAllocationStrategy.YieldRealized(managedWallet, 0, netYieldAmount, delegateFee, protocolFee, 0, "");

        vm.prank(managedWallet);
        strategy.realizeYield(newYieldAmount, 0, "");

        assertEq(asset.balanceOf(address(strategy)),         strategyBalance + netYieldAmount);
        assertEq(asset.balanceOf(address(managedWallet)),    0);
        assertEq(asset.balanceOf(address(strategyDelegate)), delegateFee);
        assertEq(asset.balanceOf(address(mapleTreasury)),    protocolFee);

        assertEq(strategy.scheduledYieldAssets(), netYieldAmount);
        assertEq(strategy.yieldStart(),           yieldStart + 2 hours);
        assertEq(strategy.yieldDeadline(),        yieldStart + 2 hours);

        assertEq(strategy.realizedYield(),         netYieldAmount);
        assertEq(strategy.unrealizedYield(),       0);
        assertEq(strategy.availableToWithdraw(),   strategyBalance + netYieldAmount);
        assertEq(strategy.assetsUnderManagement(), strategyBalance + netYieldAmount);
    }

    function test_realizeYield_success_nonZeroYield_zeroDuration_withFees_bufferAtStart() external {
        uint256 delegateFee    = newYieldAmount * delegateFeeRate / 1e6;
        uint256 protocolFee    = newYieldAmount * protocolFeeRate / 1e6;
        uint256 netYieldAmount = newYieldAmount - delegateFee - protocolFee;

        assertEq(asset.balanceOf(address(strategy)),         strategyBalance);
        assertEq(asset.balanceOf(address(managedWallet)),    newYieldAmount);
        assertEq(asset.balanceOf(address(strategyDelegate)), 0);
        assertEq(asset.balanceOf(address(mapleTreasury)),    0);

        assertEq(strategy.scheduledYieldAssets(), scheduledYieldAssets);
        assertEq(strategy.yieldStart(),           yieldStart);
        assertEq(strategy.yieldDeadline(),        yieldDeadline);

        assertEq(strategy.realizedYield(),         0);
        assertEq(strategy.unrealizedYield(),       scheduledYieldAssets);
        assertEq(strategy.availableToWithdraw(),   strategyBalance - scheduledYieldAssets);
        assertEq(strategy.assetsUnderManagement(), strategyBalance - scheduledYieldAssets);

        vm.expectEmit();
        emit IMapleAllocationStrategy.YieldRealized(managedWallet, scheduledYieldAssets, netYieldAmount, delegateFee, protocolFee, 0, "");

        vm.prank(managedWallet);
        strategy.realizeYield(newYieldAmount, 0, "");

        assertEq(asset.balanceOf(address(strategy)),         strategyBalance + netYieldAmount);
        assertEq(asset.balanceOf(address(managedWallet)),    0);
        assertEq(asset.balanceOf(address(strategyDelegate)), delegateFee);
        assertEq(asset.balanceOf(address(mapleTreasury)),    protocolFee);

        assertEq(strategy.scheduledYieldAssets(), scheduledYieldAssets + netYieldAmount);
        assertEq(strategy.yieldStart(),           yieldStart);
        assertEq(strategy.yieldDeadline(),        yieldStart);

        assertEq(strategy.realizedYield(),         scheduledYieldAssets + netYieldAmount);
        assertEq(strategy.unrealizedYield(),       0);
        assertEq(strategy.availableToWithdraw(),   strategyBalance + netYieldAmount);
        assertEq(strategy.assetsUnderManagement(), strategyBalance + netYieldAmount);
    }

    function test_realizeYield_success_nonZeroYield_zeroDuration_withFees_bufferAccruing() external {
        uint256 elapsedDuration  = yieldAccruing - yieldStart;
        uint256 totalDuration    = yieldDeadline - yieldStart;

        uint256 realizedYield   = scheduledYieldAssets * elapsedDuration / totalDuration;
        uint256 unrealizedYield = scheduledYieldAssets - realizedYield;

        uint256 delegateFee    = newYieldAmount * delegateFeeRate / 1e6;
        uint256 protocolFee    = newYieldAmount * protocolFeeRate / 1e6;
        uint256 netYieldAmount = newYieldAmount - delegateFee - protocolFee;

        vm.warp(yieldAccruing);

        assertEq(asset.balanceOf(address(strategy)),         strategyBalance);
        assertEq(asset.balanceOf(address(managedWallet)),    newYieldAmount);
        assertEq(asset.balanceOf(address(strategyDelegate)), 0);
        assertEq(asset.balanceOf(address(mapleTreasury)),    0);

        assertEq(strategy.scheduledYieldAssets(), scheduledYieldAssets);
        assertEq(strategy.yieldStart(),           yieldStart);
        assertEq(strategy.yieldDeadline(),        yieldDeadline);

        assertEq(strategy.realizedYield(),         realizedYield);
        assertEq(strategy.unrealizedYield(),       unrealizedYield);
        assertEq(strategy.availableToWithdraw(),   strategyBalance - unrealizedYield);
        assertEq(strategy.assetsUnderManagement(), strategyBalance - unrealizedYield);

        vm.expectEmit();
        emit IMapleAllocationStrategy.YieldRealized(managedWallet, unrealizedYield, netYieldAmount, delegateFee, protocolFee, 0, "");

        vm.prank(managedWallet);
        strategy.realizeYield(newYieldAmount, 0, "");

        assertEq(asset.balanceOf(address(strategy)),         strategyBalance + netYieldAmount);
        assertEq(asset.balanceOf(address(managedWallet)),    0);
        assertEq(asset.balanceOf(address(strategyDelegate)), delegateFee);
        assertEq(asset.balanceOf(address(mapleTreasury)),    protocolFee);

        assertEq(strategy.scheduledYieldAssets(), unrealizedYield + netYieldAmount);
        assertEq(strategy.yieldStart(),           yieldAccruing);
        assertEq(strategy.yieldDeadline(),        yieldAccruing);

        assertEq(strategy.realizedYield(),         unrealizedYield + netYieldAmount);
        assertEq(strategy.unrealizedYield(),       0);
        assertEq(strategy.availableToWithdraw(),   strategyBalance + netYieldAmount);
        assertEq(strategy.assetsUnderManagement(), strategyBalance + netYieldAmount);
    }

    function test_realizeYield_success_nonZeroYield_zeroDuration_withFees_bufferAtDeadline() external {
        uint256 delegateFee    = newYieldAmount * delegateFeeRate / 1e6;
        uint256 protocolFee    = newYieldAmount * protocolFeeRate / 1e6;
        uint256 netYieldAmount = newYieldAmount - delegateFee - protocolFee;

        vm.warp(yieldDeadline);

        assertEq(asset.balanceOf(address(strategy)),         strategyBalance);
        assertEq(asset.balanceOf(address(managedWallet)),    newYieldAmount);
        assertEq(asset.balanceOf(address(strategyDelegate)), 0);
        assertEq(asset.balanceOf(address(mapleTreasury)),    0);

        assertEq(strategy.scheduledYieldAssets(), scheduledYieldAssets);
        assertEq(strategy.yieldStart(),           yieldStart);
        assertEq(strategy.yieldDeadline(),        yieldDeadline);

        assertEq(strategy.realizedYield(),       scheduledYieldAssets);
        assertEq(strategy.unrealizedYield(),     0);
        assertEq(strategy.availableToWithdraw(), strategyBalance);

        vm.expectEmit();
        emit IMapleAllocationStrategy.YieldRealized(managedWallet, 0, netYieldAmount, delegateFee, protocolFee, 0, "");

        vm.prank(managedWallet);
        strategy.realizeYield(newYieldAmount, 0, "");

        assertEq(asset.balanceOf(address(strategy)),         strategyBalance + netYieldAmount);
        assertEq(asset.balanceOf(address(managedWallet)),    0);
        assertEq(asset.balanceOf(address(strategyDelegate)), delegateFee);
        assertEq(asset.balanceOf(address(mapleTreasury)),    protocolFee);

        assertEq(strategy.scheduledYieldAssets(), netYieldAmount);
        assertEq(strategy.yieldStart(),           yieldDeadline);
        assertEq(strategy.yieldDeadline(),        yieldDeadline);

        assertEq(strategy.realizedYield(),       netYieldAmount);
        assertEq(strategy.unrealizedYield(),     0);
        assertEq(strategy.availableToWithdraw(), strategyBalance + netYieldAmount);
    }

    function test_realizeYield_success_nonZeroYield_zeroDuration_withFees_bufferPastDeadline() external {
        uint256 delegateFee    = newYieldAmount * delegateFeeRate / 1e6;
        uint256 protocolFee    = newYieldAmount * protocolFeeRate / 1e6;
        uint256 netYieldAmount = newYieldAmount - delegateFee - protocolFee;

        vm.warp(yieldFinished);

        assertEq(asset.balanceOf(address(strategy)),         strategyBalance);
        assertEq(asset.balanceOf(address(managedWallet)),    newYieldAmount);
        assertEq(asset.balanceOf(address(strategyDelegate)), 0);
        assertEq(asset.balanceOf(address(mapleTreasury)),    0);

        assertEq(strategy.scheduledYieldAssets(), scheduledYieldAssets);
        assertEq(strategy.yieldStart(),           yieldStart);
        assertEq(strategy.yieldDeadline(),        yieldDeadline);

        assertEq(strategy.realizedYield(),         scheduledYieldAssets);
        assertEq(strategy.unrealizedYield(),       0);
        assertEq(strategy.availableToWithdraw(),   strategyBalance);
        assertEq(strategy.assetsUnderManagement(), strategyBalance);

        vm.expectEmit();
        emit IMapleAllocationStrategy.YieldRealized(managedWallet, 0, netYieldAmount, delegateFee, protocolFee, 0, "");

        vm.prank(managedWallet);
        strategy.realizeYield(newYieldAmount, 0, "");

        assertEq(asset.balanceOf(address(strategy)),         strategyBalance + netYieldAmount);
        assertEq(asset.balanceOf(address(managedWallet)),    0);
        assertEq(asset.balanceOf(address(strategyDelegate)), delegateFee);
        assertEq(asset.balanceOf(address(mapleTreasury)),    protocolFee);

        assertEq(strategy.scheduledYieldAssets(), netYieldAmount);
        assertEq(strategy.yieldStart(),           yieldFinished);
        assertEq(strategy.yieldDeadline(),        yieldFinished);

        assertEq(strategy.realizedYield(),         netYieldAmount);
        assertEq(strategy.unrealizedYield(),       0);
        assertEq(strategy.availableToWithdraw(),   strategyBalance + netYieldAmount);
        assertEq(strategy.assetsUnderManagement(), strategyBalance + netYieldAmount);
    }

    /**************************************************************************************************************************************/
    /*** Non-Zero Yield — Zero Duration — Fees Round to Zero                                                                            ***/
    /**************************************************************************************************************************************/

    function test_realizeYield_success_nonZeroYield_zeroDuration_feesRoundToZero_noBuffer() external {
        vm.prank(managedWallet);
        strategy.realizeYield(0, 0, "FLUSH");

        assertEq(asset.balanceOf(address(strategy)),         strategyBalance);
        assertEq(asset.balanceOf(address(managedWallet)),    newYieldAmount);
        assertEq(asset.balanceOf(address(strategyDelegate)), 0);
        assertEq(asset.balanceOf(address(mapleTreasury)),    0);

        assertEq(strategy.scheduledYieldAssets(), scheduledYieldAssets);
        assertEq(strategy.yieldStart(),           yieldStart);
        assertEq(strategy.yieldDeadline(),        yieldStart);

        assertEq(strategy.realizedYield(),         scheduledYieldAssets);
        assertEq(strategy.unrealizedYield(),       0);
        assertEq(strategy.availableToWithdraw(),   strategyBalance);
        assertEq(strategy.assetsUnderManagement(), strategyBalance);

        vm.warp(yieldStart + 2 hours);

        vm.expectEmit();
        emit IMapleAllocationStrategy.YieldRealized(managedWallet, 0, tinyYieldAmount, 0, 0, 0, "");

        vm.prank(managedWallet);
        strategy.realizeYield(tinyYieldAmount, 0, "");

        assertEq(asset.balanceOf(address(strategy)),         strategyBalance + tinyYieldAmount);
        assertEq(asset.balanceOf(address(managedWallet)),    newYieldAmount - tinyYieldAmount);
        assertEq(asset.balanceOf(address(strategyDelegate)), 0);
        assertEq(asset.balanceOf(address(mapleTreasury)),    0);

        assertEq(strategy.scheduledYieldAssets(), tinyYieldAmount);
        assertEq(strategy.yieldStart(),           yieldStart + 2 hours);
        assertEq(strategy.yieldDeadline(),        yieldStart + 2 hours);

        assertEq(strategy.realizedYield(),         tinyYieldAmount);
        assertEq(strategy.unrealizedYield(),       0);
        assertEq(strategy.availableToWithdraw(),   strategyBalance + tinyYieldAmount);
        assertEq(strategy.assetsUnderManagement(), strategyBalance + tinyYieldAmount);
    }

    function test_realizeYield_success_nonZeroYield_zeroDuration_feesRoundToZero_bufferAtStart() external {
        assertEq(asset.balanceOf(address(strategy)),         strategyBalance);
        assertEq(asset.balanceOf(address(managedWallet)),    newYieldAmount);
        assertEq(asset.balanceOf(address(strategyDelegate)), 0);
        assertEq(asset.balanceOf(address(mapleTreasury)),    0);

        assertEq(strategy.scheduledYieldAssets(), scheduledYieldAssets);
        assertEq(strategy.yieldStart(),           yieldStart);
        assertEq(strategy.yieldDeadline(),        yieldDeadline);

        assertEq(strategy.realizedYield(),         0);
        assertEq(strategy.unrealizedYield(),       scheduledYieldAssets);
        assertEq(strategy.availableToWithdraw(),   strategyBalance - scheduledYieldAssets);
        assertEq(strategy.assetsUnderManagement(), strategyBalance - scheduledYieldAssets);

        vm.expectEmit();
        emit IMapleAllocationStrategy.YieldRealized(managedWallet, scheduledYieldAssets, tinyYieldAmount, 0, 0, 0, "");

        vm.prank(managedWallet);
        strategy.realizeYield(tinyYieldAmount, 0, "");

        assertEq(asset.balanceOf(address(strategy)),         strategyBalance + tinyYieldAmount);
        assertEq(asset.balanceOf(address(managedWallet)),    newYieldAmount - tinyYieldAmount);
        assertEq(asset.balanceOf(address(strategyDelegate)), 0);
        assertEq(asset.balanceOf(address(mapleTreasury)),    0);

        assertEq(strategy.scheduledYieldAssets(), scheduledYieldAssets + tinyYieldAmount);
        assertEq(strategy.yieldStart(),           yieldStart);
        assertEq(strategy.yieldDeadline(),        yieldStart);

        assertEq(strategy.realizedYield(),         scheduledYieldAssets + tinyYieldAmount);
        assertEq(strategy.unrealizedYield(),       0);
        assertEq(strategy.availableToWithdraw(),   strategyBalance + tinyYieldAmount);
        assertEq(strategy.assetsUnderManagement(), strategyBalance + tinyYieldAmount);
    }

    function test_realizeYield_success_nonZeroYield_zeroDuration_feesRoundToZero_bufferAccruing() external {
        uint256 elapsedDuration  = yieldAccruing - yieldStart;
        uint256 totalDuration    = yieldDeadline - yieldStart;

        uint256 realizedYield   = scheduledYieldAssets * elapsedDuration / totalDuration;
        uint256 unrealizedYield = scheduledYieldAssets - realizedYield;

        vm.warp(yieldAccruing);

        assertEq(asset.balanceOf(address(strategy)),         strategyBalance);
        assertEq(asset.balanceOf(address(managedWallet)),    newYieldAmount);
        assertEq(asset.balanceOf(address(strategyDelegate)), 0);
        assertEq(asset.balanceOf(address(mapleTreasury)),    0);

        assertEq(strategy.scheduledYieldAssets(), scheduledYieldAssets);
        assertEq(strategy.yieldStart(),           yieldStart);
        assertEq(strategy.yieldDeadline(),        yieldDeadline);

        assertEq(strategy.realizedYield(),         realizedYield);
        assertEq(strategy.unrealizedYield(),       unrealizedYield);
        assertEq(strategy.availableToWithdraw(),   strategyBalance - unrealizedYield);
        assertEq(strategy.assetsUnderManagement(), strategyBalance - unrealizedYield);

        vm.expectEmit();
        emit IMapleAllocationStrategy.YieldRealized(managedWallet, unrealizedYield, tinyYieldAmount, 0, 0, 0, "");

        vm.prank(managedWallet);
        strategy.realizeYield(tinyYieldAmount, 0, "");

        assertEq(asset.balanceOf(address(strategy)),         strategyBalance + tinyYieldAmount);
        assertEq(asset.balanceOf(address(managedWallet)),    newYieldAmount - tinyYieldAmount);
        assertEq(asset.balanceOf(address(strategyDelegate)), 0);
        assertEq(asset.balanceOf(address(mapleTreasury)),    0);

        assertEq(strategy.scheduledYieldAssets(), unrealizedYield + tinyYieldAmount);
        assertEq(strategy.yieldStart(),           yieldAccruing);
        assertEq(strategy.yieldDeadline(),        yieldAccruing);

        assertEq(strategy.realizedYield(),         unrealizedYield + tinyYieldAmount);
        assertEq(strategy.unrealizedYield(),       0);
        assertEq(strategy.availableToWithdraw(),   strategyBalance + tinyYieldAmount);
        assertEq(strategy.assetsUnderManagement(), strategyBalance + tinyYieldAmount);
    }

    function test_realizeYield_success_nonZeroYield_zeroDuration_feesRoundToZero_bufferAtDeadline() external {
        vm.warp(yieldDeadline);

        assertEq(asset.balanceOf(address(strategy)),         strategyBalance);
        assertEq(asset.balanceOf(address(managedWallet)),    newYieldAmount);
        assertEq(asset.balanceOf(address(strategyDelegate)), 0);
        assertEq(asset.balanceOf(address(mapleTreasury)),    0);

        assertEq(strategy.scheduledYieldAssets(), scheduledYieldAssets);
        assertEq(strategy.yieldStart(),           yieldStart);
        assertEq(strategy.yieldDeadline(),        yieldDeadline);

        assertEq(strategy.realizedYield(),       scheduledYieldAssets);
        assertEq(strategy.unrealizedYield(),     0);
        assertEq(strategy.availableToWithdraw(), strategyBalance);

        vm.expectEmit();
        emit IMapleAllocationStrategy.YieldRealized(managedWallet, 0, tinyYieldAmount, 0, 0, 0, "");

        vm.prank(managedWallet);
        strategy.realizeYield(tinyYieldAmount, 0, "");

        assertEq(asset.balanceOf(address(strategy)),         strategyBalance + tinyYieldAmount);
        assertEq(asset.balanceOf(address(managedWallet)),    newYieldAmount - tinyYieldAmount);
        assertEq(asset.balanceOf(address(strategyDelegate)), 0);
        assertEq(asset.balanceOf(address(mapleTreasury)),    0);

        assertEq(strategy.scheduledYieldAssets(), tinyYieldAmount);
        assertEq(strategy.yieldStart(),           yieldDeadline);
        assertEq(strategy.yieldDeadline(),        yieldDeadline);

        assertEq(strategy.realizedYield(),       tinyYieldAmount);
        assertEq(strategy.unrealizedYield(),     0);
        assertEq(strategy.availableToWithdraw(), strategyBalance + tinyYieldAmount);
    }

    function test_realizeYield_success_nonZeroYield_zeroDuration_feesRoundToZero_bufferPastDeadline() external {
        vm.warp(yieldFinished);

        assertEq(asset.balanceOf(address(strategy)),         strategyBalance);
        assertEq(asset.balanceOf(address(managedWallet)),    newYieldAmount);
        assertEq(asset.balanceOf(address(strategyDelegate)), 0);
        assertEq(asset.balanceOf(address(mapleTreasury)),    0);

        assertEq(strategy.scheduledYieldAssets(), scheduledYieldAssets);
        assertEq(strategy.yieldStart(),           yieldStart);
        assertEq(strategy.yieldDeadline(),        yieldDeadline);

        assertEq(strategy.realizedYield(),         scheduledYieldAssets);
        assertEq(strategy.unrealizedYield(),       0);
        assertEq(strategy.availableToWithdraw(),   strategyBalance);
        assertEq(strategy.assetsUnderManagement(), strategyBalance);

        vm.expectEmit();
        emit IMapleAllocationStrategy.YieldRealized(managedWallet, 0, tinyYieldAmount, 0, 0, 0, "");

        vm.prank(managedWallet);
        strategy.realizeYield(tinyYieldAmount, 0, "");

        assertEq(asset.balanceOf(address(strategy)),         strategyBalance + tinyYieldAmount);
        assertEq(asset.balanceOf(address(managedWallet)),    newYieldAmount - tinyYieldAmount);
        assertEq(asset.balanceOf(address(strategyDelegate)), 0);
        assertEq(asset.balanceOf(address(mapleTreasury)),    0);

        assertEq(strategy.scheduledYieldAssets(), tinyYieldAmount);
        assertEq(strategy.yieldStart(),           yieldFinished);
        assertEq(strategy.yieldDeadline(),        yieldFinished);

        assertEq(strategy.realizedYield(),         tinyYieldAmount);
        assertEq(strategy.unrealizedYield(),       0);
        assertEq(strategy.availableToWithdraw(),   strategyBalance + tinyYieldAmount);
        assertEq(strategy.assetsUnderManagement(), strategyBalance + tinyYieldAmount);
    }

    function test_realizeYield_success_nonZeroYield_zeroDuration_feesSumToHundredPercent_noBuffer() external {
        uint32 fullDelegateFeeRate = 0.5e6;
        uint32 fullProtocolFeeRate = 0.5e6;

        strategy.__setFeeRates(fullDelegateFeeRate, fullProtocolFeeRate);

        vm.prank(managedWallet);
        strategy.realizeYield(0, 0, "FLUSH");

        uint256 delegateFee = newYieldAmount * fullDelegateFeeRate / 1e6;
        uint256 protocolFee = newYieldAmount * fullProtocolFeeRate / 1e6;

        assertEq(asset.balanceOf(address(strategy)),         strategyBalance);
        assertEq(asset.balanceOf(address(managedWallet)),    newYieldAmount);
        assertEq(asset.balanceOf(address(strategyDelegate)), 0);
        assertEq(asset.balanceOf(address(mapleTreasury)),    0);

        assertEq(strategy.scheduledYieldAssets(), scheduledYieldAssets);
        assertEq(strategy.yieldStart(),           yieldStart);
        assertEq(strategy.yieldDeadline(),        yieldStart);

        assertEq(strategy.realizedYield(),         scheduledYieldAssets);
        assertEq(strategy.unrealizedYield(),       0);
        assertEq(strategy.availableToWithdraw(),   strategyBalance);
        assertEq(strategy.assetsUnderManagement(), strategyBalance);

        vm.warp(yieldStart + 2 hours);

        vm.expectEmit();
        emit IMapleAllocationStrategy.YieldRealized(managedWallet, 0, 0, delegateFee, protocolFee, 0, "");

        vm.prank(managedWallet);
        strategy.realizeYield(newYieldAmount, 0, "");

        assertEq(asset.balanceOf(address(strategy)),         strategyBalance);
        assertEq(asset.balanceOf(address(managedWallet)),    0);
        assertEq(asset.balanceOf(address(strategyDelegate)), delegateFee);
        assertEq(asset.balanceOf(address(mapleTreasury)),    protocolFee);

        assertEq(strategy.scheduledYieldAssets(), 0);
        assertEq(strategy.yieldStart(),           yieldStart + 2 hours);
        assertEq(strategy.yieldDeadline(),        yieldStart + 2 hours);

        assertEq(strategy.realizedYield(),         0);
        assertEq(strategy.unrealizedYield(),       0);
        assertEq(strategy.availableToWithdraw(),   strategyBalance);
        assertEq(strategy.assetsUnderManagement(), strategyBalance);
    }

    function test_realizeYield_success_nonZeroYield_zeroDuration_feesSumToHundredPercent_roundingLeavesNetYield_noBuffer() external {
        uint32 fullDelegateFeeRate = 0.5e6;
        uint32 fullProtocolFeeRate = 0.5e6;

        strategy.__setFeeRates(fullDelegateFeeRate, fullProtocolFeeRate);

        vm.prank(managedWallet);
        strategy.realizeYield(0, 0, "FLUSH");

        uint256 delegateFee    = tinyYieldAmount * fullDelegateFeeRate / 1e6;
        uint256 protocolFee    = tinyYieldAmount * fullProtocolFeeRate / 1e6;
        uint256 netYieldAmount = tinyYieldAmount - delegateFee - protocolFee;

        assertGt(netYieldAmount, 0);

        assertEq(asset.balanceOf(address(strategy)),         strategyBalance);
        assertEq(asset.balanceOf(address(managedWallet)),    newYieldAmount);
        assertEq(asset.balanceOf(address(strategyDelegate)), 0);
        assertEq(asset.balanceOf(address(mapleTreasury)),    0);

        assertEq(strategy.scheduledYieldAssets(), scheduledYieldAssets);
        assertEq(strategy.yieldStart(),           yieldStart);
        assertEq(strategy.yieldDeadline(),        yieldStart);

        assertEq(strategy.realizedYield(),         scheduledYieldAssets);
        assertEq(strategy.unrealizedYield(),       0);
        assertEq(strategy.availableToWithdraw(),   strategyBalance);
        assertEq(strategy.assetsUnderManagement(), strategyBalance);

        vm.warp(yieldStart + 2 hours);

        vm.expectEmit();
        emit IMapleAllocationStrategy.YieldRealized(managedWallet, 0, netYieldAmount, delegateFee, protocolFee, 0, "");

        vm.prank(managedWallet);
        strategy.realizeYield(tinyYieldAmount, 0, "");

        assertEq(asset.balanceOf(address(strategy)),         strategyBalance + netYieldAmount);
        assertEq(asset.balanceOf(address(managedWallet)),    newYieldAmount - tinyYieldAmount);
        assertEq(asset.balanceOf(address(strategyDelegate)), delegateFee);
        assertEq(asset.balanceOf(address(mapleTreasury)),    protocolFee);

        assertEq(strategy.scheduledYieldAssets(), netYieldAmount);
        assertEq(strategy.yieldStart(),           yieldStart + 2 hours);
        assertEq(strategy.yieldDeadline(),        yieldStart + 2 hours);

        assertEq(strategy.realizedYield(),         netYieldAmount);
        assertEq(strategy.unrealizedYield(),       0);
        assertEq(strategy.availableToWithdraw(),   strategyBalance + netYieldAmount);
        assertEq(strategy.assetsUnderManagement(), strategyBalance + netYieldAmount);
    }

    /**************************************************************************************************************************************/
    /*** Non-Zero Yield — Non-Zero Duration — No Fees                                                                                   ***/
    /**************************************************************************************************************************************/

    function test_realizeYield_success_nonZeroYield_nonZeroDuration_noFees_noBuffer() external {
        strategy.__setFeeRates(0, 0);

        vm.prank(managedWallet);
        strategy.realizeYield(0, 0, "FLUSH");

        assertEq(asset.balanceOf(address(strategy)),         strategyBalance);
        assertEq(asset.balanceOf(address(managedWallet)),    newYieldAmount);
        assertEq(asset.balanceOf(address(strategyDelegate)), 0);
        assertEq(asset.balanceOf(address(mapleTreasury)),    0);

        assertEq(strategy.scheduledYieldAssets(), scheduledYieldAssets);
        assertEq(strategy.yieldStart(),           yieldStart);
        assertEq(strategy.yieldDeadline(),        yieldStart);

        assertEq(strategy.realizedYield(),         scheduledYieldAssets);
        assertEq(strategy.unrealizedYield(),       0);
        assertEq(strategy.availableToWithdraw(),   strategyBalance);
        assertEq(strategy.assetsUnderManagement(), strategyBalance);

        vm.warp(yieldStart + 2 hours);

        vm.expectEmit();
        emit IMapleAllocationStrategy.YieldRealized(managedWallet, 0, newYieldAmount, 0, 0, newYieldDuration, "");

        vm.prank(managedWallet);
        strategy.realizeYield(newYieldAmount, newYieldDuration, "");

        assertEq(asset.balanceOf(address(strategy)),         strategyBalance + newYieldAmount);
        assertEq(asset.balanceOf(address(managedWallet)),    0);
        assertEq(asset.balanceOf(address(strategyDelegate)), 0);
        assertEq(asset.balanceOf(address(mapleTreasury)),    0);

        assertEq(strategy.scheduledYieldAssets(), newYieldAmount);
        assertEq(strategy.yieldStart(),           yieldStart + 2 hours);
        assertEq(strategy.yieldDeadline(),        yieldStart + 2 hours + newYieldDuration);

        assertEq(strategy.realizedYield(),         0);
        assertEq(strategy.unrealizedYield(),       newYieldAmount);
        assertEq(strategy.availableToWithdraw(),   strategyBalance);
        assertEq(strategy.assetsUnderManagement(), strategyBalance);
    }

    function test_realizeYield_success_nonZeroYield_nonZeroDuration_noFees_bufferAtStart() external {
        strategy.__setFeeRates(0, 0);

        assertEq(asset.balanceOf(address(strategy)),         strategyBalance);
        assertEq(asset.balanceOf(address(managedWallet)),    newYieldAmount);
        assertEq(asset.balanceOf(address(strategyDelegate)), 0);
        assertEq(asset.balanceOf(address(mapleTreasury)),    0);

        assertEq(strategy.scheduledYieldAssets(), scheduledYieldAssets);
        assertEq(strategy.yieldStart(),           yieldStart);
        assertEq(strategy.yieldDeadline(),        yieldDeadline);

        assertEq(strategy.realizedYield(),         0);
        assertEq(strategy.unrealizedYield(),       scheduledYieldAssets);
        assertEq(strategy.availableToWithdraw(),   strategyBalance - scheduledYieldAssets);
        assertEq(strategy.assetsUnderManagement(), strategyBalance - scheduledYieldAssets);

        vm.expectEmit();
        emit IMapleAllocationStrategy.YieldRealized(managedWallet, scheduledYieldAssets, newYieldAmount, 0, 0, newYieldDuration, "");

        vm.prank(managedWallet);
        strategy.realizeYield(newYieldAmount, newYieldDuration, "");

        assertEq(asset.balanceOf(address(strategy)),         strategyBalance + newYieldAmount);
        assertEq(asset.balanceOf(address(managedWallet)),    0);
        assertEq(asset.balanceOf(address(strategyDelegate)), 0);
        assertEq(asset.balanceOf(address(mapleTreasury)),    0);

        assertEq(strategy.scheduledYieldAssets(), scheduledYieldAssets + newYieldAmount);
        assertEq(strategy.yieldStart(),           yieldStart);
        assertEq(strategy.yieldDeadline(),        yieldStart + newYieldDuration);

        assertEq(strategy.realizedYield(),         0);
        assertEq(strategy.unrealizedYield(),       scheduledYieldAssets + newYieldAmount);
        assertEq(strategy.availableToWithdraw(),   strategyBalance - scheduledYieldAssets);
        assertEq(strategy.assetsUnderManagement(), strategyBalance - scheduledYieldAssets);
    }

    function test_realizeYield_success_nonZeroYield_nonZeroDuration_noFees_bufferAccruing() external {
        strategy.__setFeeRates(0, 0);

        uint256 elapsedDuration  = yieldAccruing - yieldStart;
        uint256 totalDuration    = yieldDeadline - yieldStart;

        uint256 realizedYield   = scheduledYieldAssets * elapsedDuration / totalDuration;
        uint256 unrealizedYield = scheduledYieldAssets - realizedYield;

        vm.warp(yieldAccruing);

        assertEq(asset.balanceOf(address(strategy)),         strategyBalance);
        assertEq(asset.balanceOf(address(managedWallet)),    newYieldAmount);
        assertEq(asset.balanceOf(address(strategyDelegate)), 0);
        assertEq(asset.balanceOf(address(mapleTreasury)),    0);

        assertEq(strategy.scheduledYieldAssets(), scheduledYieldAssets);
        assertEq(strategy.yieldStart(),           yieldStart);
        assertEq(strategy.yieldDeadline(),        yieldDeadline);

        assertEq(strategy.realizedYield(),         realizedYield);
        assertEq(strategy.unrealizedYield(),       unrealizedYield);
        assertEq(strategy.availableToWithdraw(),   strategyBalance - unrealizedYield);
        assertEq(strategy.assetsUnderManagement(), strategyBalance - unrealizedYield);

        vm.expectEmit();
        emit IMapleAllocationStrategy.YieldRealized(managedWallet, unrealizedYield, newYieldAmount, 0, 0, newYieldDuration, "");

        vm.prank(managedWallet);
        strategy.realizeYield(newYieldAmount, newYieldDuration, "");

        assertEq(asset.balanceOf(address(strategy)),         strategyBalance + newYieldAmount);
        assertEq(asset.balanceOf(address(managedWallet)),    0);
        assertEq(asset.balanceOf(address(strategyDelegate)), 0);
        assertEq(asset.balanceOf(address(mapleTreasury)),    0);

        assertEq(strategy.scheduledYieldAssets(), unrealizedYield + newYieldAmount);
        assertEq(strategy.yieldStart(),           yieldAccruing);
        assertEq(strategy.yieldDeadline(),        yieldAccruing + newYieldDuration);

        assertEq(strategy.realizedYield(),         0);
        assertEq(strategy.unrealizedYield(),       unrealizedYield + newYieldAmount);
        assertEq(strategy.availableToWithdraw(),   strategyBalance - unrealizedYield);
        assertEq(strategy.assetsUnderManagement(), strategyBalance - unrealizedYield);
    }

    function test_realizeYield_success_nonZeroYield_nonZeroDuration_noFees_bufferAtDeadline() external {
        strategy.__setFeeRates(0, 0);

        vm.warp(yieldDeadline);

        assertEq(asset.balanceOf(address(strategy)),         strategyBalance);
        assertEq(asset.balanceOf(address(managedWallet)),    newYieldAmount);
        assertEq(asset.balanceOf(address(strategyDelegate)), 0);
        assertEq(asset.balanceOf(address(mapleTreasury)),    0);

        assertEq(strategy.scheduledYieldAssets(), scheduledYieldAssets);
        assertEq(strategy.yieldStart(),           yieldStart);
        assertEq(strategy.yieldDeadline(),        yieldDeadline);

        assertEq(strategy.realizedYield(),       scheduledYieldAssets);
        assertEq(strategy.unrealizedYield(),     0);
        assertEq(strategy.availableToWithdraw(), strategyBalance);

        vm.expectEmit();
        emit IMapleAllocationStrategy.YieldRealized(managedWallet, 0, newYieldAmount, 0, 0, newYieldDuration, "");

        vm.prank(managedWallet);
        strategy.realizeYield(newYieldAmount, newYieldDuration, "");

        assertEq(asset.balanceOf(address(strategy)),         strategyBalance + newYieldAmount);
        assertEq(asset.balanceOf(address(managedWallet)),    0);
        assertEq(asset.balanceOf(address(strategyDelegate)), 0);
        assertEq(asset.balanceOf(address(mapleTreasury)),    0);

        assertEq(strategy.scheduledYieldAssets(), newYieldAmount);
        assertEq(strategy.yieldStart(),           yieldDeadline);
        assertEq(strategy.yieldDeadline(),        yieldDeadline + newYieldDuration);

        assertEq(strategy.realizedYield(),       0);
        assertEq(strategy.unrealizedYield(),     newYieldAmount);
        assertEq(strategy.availableToWithdraw(), strategyBalance);
    }

    function test_realizeYield_success_nonZeroYield_nonZeroDuration_noFees_bufferPastDeadline() external {
        strategy.__setFeeRates(0, 0);

        vm.warp(yieldFinished);

        assertEq(asset.balanceOf(address(strategy)),         strategyBalance);
        assertEq(asset.balanceOf(address(managedWallet)),    newYieldAmount);
        assertEq(asset.balanceOf(address(strategyDelegate)), 0);
        assertEq(asset.balanceOf(address(mapleTreasury)),    0);

        assertEq(strategy.scheduledYieldAssets(), scheduledYieldAssets);
        assertEq(strategy.yieldStart(),           yieldStart);
        assertEq(strategy.yieldDeadline(),        yieldDeadline);

        assertEq(strategy.realizedYield(),         scheduledYieldAssets);
        assertEq(strategy.unrealizedYield(),       0);
        assertEq(strategy.availableToWithdraw(),   strategyBalance);
        assertEq(strategy.assetsUnderManagement(), strategyBalance);

        vm.expectEmit();
        emit IMapleAllocationStrategy.YieldRealized(managedWallet, 0, newYieldAmount, 0, 0, newYieldDuration, "");

        vm.prank(managedWallet);
        strategy.realizeYield(newYieldAmount, newYieldDuration, "");

        assertEq(asset.balanceOf(address(strategy)),         strategyBalance + newYieldAmount);
        assertEq(asset.balanceOf(address(managedWallet)),    0);
        assertEq(asset.balanceOf(address(strategyDelegate)), 0);
        assertEq(asset.balanceOf(address(mapleTreasury)),    0);

        assertEq(strategy.scheduledYieldAssets(), newYieldAmount);
        assertEq(strategy.yieldStart(),           yieldFinished);
        assertEq(strategy.yieldDeadline(),        yieldFinished + newYieldDuration);

        assertEq(strategy.realizedYield(),         0);
        assertEq(strategy.unrealizedYield(),       newYieldAmount);
        assertEq(strategy.availableToWithdraw(),   strategyBalance);
        assertEq(strategy.assetsUnderManagement(), strategyBalance);
    }

    /**************************************************************************************************************************************/
    /*** Non-Zero Yield — Non-Zero Duration — With Fees                                                                                 ***/
    /**************************************************************************************************************************************/

    function test_realizeYield_success_nonZeroYield_nonZeroDuration_withFees_noBuffer() external {
        vm.prank(managedWallet);
        strategy.realizeYield(0, 0, "FLUSH");

        uint256 delegateFee    = newYieldAmount * delegateFeeRate / 1e6;
        uint256 protocolFee    = newYieldAmount * protocolFeeRate / 1e6;
        uint256 netYieldAmount = newYieldAmount - delegateFee - protocolFee;

        assertEq(asset.balanceOf(address(strategy)),         strategyBalance);
        assertEq(asset.balanceOf(address(managedWallet)),    newYieldAmount);
        assertEq(asset.balanceOf(address(strategyDelegate)), 0);
        assertEq(asset.balanceOf(address(mapleTreasury)),    0);

        assertEq(strategy.scheduledYieldAssets(), scheduledYieldAssets);
        assertEq(strategy.yieldStart(),           yieldStart);
        assertEq(strategy.yieldDeadline(),        yieldStart);

        assertEq(strategy.realizedYield(),         scheduledYieldAssets);
        assertEq(strategy.unrealizedYield(),       0);
        assertEq(strategy.availableToWithdraw(),   strategyBalance);
        assertEq(strategy.assetsUnderManagement(), strategyBalance);

        vm.warp(yieldStart + 2 hours);

        vm.expectEmit();
        emit IMapleAllocationStrategy.YieldRealized(managedWallet, 0, netYieldAmount, delegateFee, protocolFee, newYieldDuration, "");

        vm.prank(managedWallet);
        strategy.realizeYield(newYieldAmount, newYieldDuration, "");

        assertEq(asset.balanceOf(address(strategy)),         strategyBalance + netYieldAmount);
        assertEq(asset.balanceOf(address(managedWallet)),    0);
        assertEq(asset.balanceOf(address(strategyDelegate)), delegateFee);
        assertEq(asset.balanceOf(address(mapleTreasury)),    protocolFee);

        assertEq(strategy.scheduledYieldAssets(), netYieldAmount);
        assertEq(strategy.yieldStart(),           yieldStart + 2 hours);
        assertEq(strategy.yieldDeadline(),        yieldStart + 2 hours + newYieldDuration);

        assertEq(strategy.realizedYield(),         0);
        assertEq(strategy.unrealizedYield(),       netYieldAmount);
        assertEq(strategy.availableToWithdraw(),   strategyBalance);
        assertEq(strategy.assetsUnderManagement(), strategyBalance);
    }

    function test_realizeYield_success_nonZeroYield_nonZeroDuration_withFees_bufferAtStart() external {
        uint256 delegateFee    = newYieldAmount * delegateFeeRate / 1e6;
        uint256 protocolFee    = newYieldAmount * protocolFeeRate / 1e6;
        uint256 netYieldAmount = newYieldAmount - delegateFee - protocolFee;

        assertEq(asset.balanceOf(address(strategy)),         strategyBalance);
        assertEq(asset.balanceOf(address(managedWallet)),    newYieldAmount);
        assertEq(asset.balanceOf(address(strategyDelegate)), 0);
        assertEq(asset.balanceOf(address(mapleTreasury)),    0);

        assertEq(strategy.scheduledYieldAssets(), scheduledYieldAssets);
        assertEq(strategy.yieldStart(),           yieldStart);
        assertEq(strategy.yieldDeadline(),        yieldDeadline);

        assertEq(strategy.realizedYield(),         0);
        assertEq(strategy.unrealizedYield(),       scheduledYieldAssets);
        assertEq(strategy.availableToWithdraw(),   strategyBalance - scheduledYieldAssets);
        assertEq(strategy.assetsUnderManagement(), strategyBalance - scheduledYieldAssets);

        vm.expectEmit();
        emit IMapleAllocationStrategy.YieldRealized(
            managedWallet,
            scheduledYieldAssets,
            netYieldAmount,
            delegateFee,
            protocolFee,
            newYieldDuration,
            ""
        );

        vm.prank(managedWallet);
        strategy.realizeYield(newYieldAmount, newYieldDuration, "");

        assertEq(asset.balanceOf(address(strategy)),         strategyBalance + netYieldAmount);
        assertEq(asset.balanceOf(address(managedWallet)),    0);
        assertEq(asset.balanceOf(address(strategyDelegate)), delegateFee);
        assertEq(asset.balanceOf(address(mapleTreasury)),    protocolFee);

        assertEq(strategy.scheduledYieldAssets(), scheduledYieldAssets + netYieldAmount);
        assertEq(strategy.yieldStart(),           yieldStart);
        assertEq(strategy.yieldDeadline(),        yieldStart + newYieldDuration);

        assertEq(strategy.realizedYield(),         0);
        assertEq(strategy.unrealizedYield(),       scheduledYieldAssets + netYieldAmount);
        assertEq(strategy.availableToWithdraw(),   strategyBalance - scheduledYieldAssets);
        assertEq(strategy.assetsUnderManagement(), strategyBalance - scheduledYieldAssets);
    }

    function test_realizeYield_success_nonZeroYield_nonZeroDuration_withFees_bufferAccruing() external {
        uint256 elapsedDuration  = yieldAccruing - yieldStart;
        uint256 totalDuration    = yieldDeadline - yieldStart;

        uint256 realizedYield   = scheduledYieldAssets * elapsedDuration / totalDuration;
        uint256 unrealizedYield = scheduledYieldAssets - realizedYield;

        uint256 delegateFee    = newYieldAmount * delegateFeeRate / 1e6;
        uint256 protocolFee    = newYieldAmount * protocolFeeRate / 1e6;
        uint256 netYieldAmount = newYieldAmount - delegateFee - protocolFee;

        vm.warp(yieldAccruing);

        assertEq(asset.balanceOf(address(strategy)),         strategyBalance);
        assertEq(asset.balanceOf(address(managedWallet)),    newYieldAmount);
        assertEq(asset.balanceOf(address(strategyDelegate)), 0);
        assertEq(asset.balanceOf(address(mapleTreasury)),    0);

        assertEq(strategy.scheduledYieldAssets(), scheduledYieldAssets);
        assertEq(strategy.yieldStart(),           yieldStart);
        assertEq(strategy.yieldDeadline(),        yieldDeadline);

        assertEq(strategy.realizedYield(),         realizedYield);
        assertEq(strategy.unrealizedYield(),       unrealizedYield);
        assertEq(strategy.availableToWithdraw(),   strategyBalance - unrealizedYield);
        assertEq(strategy.assetsUnderManagement(), strategyBalance - unrealizedYield);

        vm.expectEmit();
        emit IMapleAllocationStrategy.YieldRealized(
            managedWallet,
            unrealizedYield,
            netYieldAmount,
            delegateFee,
            protocolFee,
            newYieldDuration,
            ""
        );

        vm.prank(managedWallet);
        strategy.realizeYield(newYieldAmount, newYieldDuration, "");

        assertEq(asset.balanceOf(address(strategy)),         strategyBalance + netYieldAmount);
        assertEq(asset.balanceOf(address(managedWallet)),    0);
        assertEq(asset.balanceOf(address(strategyDelegate)), delegateFee);
        assertEq(asset.balanceOf(address(mapleTreasury)),    protocolFee);

        assertEq(strategy.scheduledYieldAssets(), unrealizedYield + netYieldAmount);
        assertEq(strategy.yieldStart(),           yieldAccruing);
        assertEq(strategy.yieldDeadline(),        yieldAccruing + newYieldDuration);

        assertEq(strategy.realizedYield(),         0);
        assertEq(strategy.unrealizedYield(),       unrealizedYield + netYieldAmount);
        assertEq(strategy.availableToWithdraw(),   strategyBalance - unrealizedYield);
        assertEq(strategy.assetsUnderManagement(), strategyBalance - unrealizedYield);
    }

    function test_realizeYield_success_nonZeroYield_nonZeroDuration_withFees_bufferAtDeadline() external {
        uint256 delegateFee    = newYieldAmount * delegateFeeRate / 1e6;
        uint256 protocolFee    = newYieldAmount * protocolFeeRate / 1e6;
        uint256 netYieldAmount = newYieldAmount - delegateFee - protocolFee;

        vm.warp(yieldDeadline);

        assertEq(asset.balanceOf(address(strategy)),         strategyBalance);
        assertEq(asset.balanceOf(address(managedWallet)),    newYieldAmount);
        assertEq(asset.balanceOf(address(strategyDelegate)), 0);
        assertEq(asset.balanceOf(address(mapleTreasury)),    0);

        assertEq(strategy.scheduledYieldAssets(), scheduledYieldAssets);
        assertEq(strategy.yieldStart(),           yieldStart);
        assertEq(strategy.yieldDeadline(),        yieldDeadline);

        assertEq(strategy.realizedYield(),       scheduledYieldAssets);
        assertEq(strategy.unrealizedYield(),     0);
        assertEq(strategy.availableToWithdraw(), strategyBalance);

        vm.expectEmit();
        emit IMapleAllocationStrategy.YieldRealized(managedWallet, 0, netYieldAmount, delegateFee, protocolFee, newYieldDuration, "");

        vm.prank(managedWallet);
        strategy.realizeYield(newYieldAmount, newYieldDuration, "");

        assertEq(asset.balanceOf(address(strategy)),         strategyBalance + netYieldAmount);
        assertEq(asset.balanceOf(address(managedWallet)),    0);
        assertEq(asset.balanceOf(address(strategyDelegate)), delegateFee);
        assertEq(asset.balanceOf(address(mapleTreasury)),    protocolFee);

        assertEq(strategy.scheduledYieldAssets(), netYieldAmount);
        assertEq(strategy.yieldStart(),           yieldDeadline);
        assertEq(strategy.yieldDeadline(),        yieldDeadline + newYieldDuration);

        assertEq(strategy.realizedYield(),       0);
        assertEq(strategy.unrealizedYield(),     netYieldAmount);
        assertEq(strategy.availableToWithdraw(), strategyBalance);
    }

    function test_realizeYield_success_nonZeroYield_nonZeroDuration_withFees_bufferPastDeadline() external {
        uint256 delegateFee    = newYieldAmount * delegateFeeRate / 1e6;
        uint256 protocolFee    = newYieldAmount * protocolFeeRate / 1e6;
        uint256 netYieldAmount = newYieldAmount - delegateFee - protocolFee;

        vm.warp(yieldFinished);

        assertEq(asset.balanceOf(address(strategy)),         strategyBalance);
        assertEq(asset.balanceOf(address(managedWallet)),    newYieldAmount);
        assertEq(asset.balanceOf(address(strategyDelegate)), 0);
        assertEq(asset.balanceOf(address(mapleTreasury)),    0);

        assertEq(strategy.scheduledYieldAssets(), scheduledYieldAssets);
        assertEq(strategy.yieldStart(),           yieldStart);
        assertEq(strategy.yieldDeadline(),        yieldDeadline);

        assertEq(strategy.realizedYield(),         scheduledYieldAssets);
        assertEq(strategy.unrealizedYield(),       0);
        assertEq(strategy.availableToWithdraw(),   strategyBalance);
        assertEq(strategy.assetsUnderManagement(), strategyBalance);

        vm.expectEmit();
        emit IMapleAllocationStrategy.YieldRealized(managedWallet, 0, netYieldAmount, delegateFee, protocolFee, newYieldDuration, "");

        vm.prank(managedWallet);
        strategy.realizeYield(newYieldAmount, newYieldDuration, "");

        assertEq(asset.balanceOf(address(strategy)),         strategyBalance + netYieldAmount);
        assertEq(asset.balanceOf(address(managedWallet)),    0);
        assertEq(asset.balanceOf(address(strategyDelegate)), delegateFee);
        assertEq(asset.balanceOf(address(mapleTreasury)),    protocolFee);

        assertEq(strategy.scheduledYieldAssets(), netYieldAmount);
        assertEq(strategy.yieldStart(),           yieldFinished);
        assertEq(strategy.yieldDeadline(),        yieldFinished + newYieldDuration);

        assertEq(strategy.realizedYield(),         0);
        assertEq(strategy.unrealizedYield(),       netYieldAmount);
        assertEq(strategy.availableToWithdraw(),   strategyBalance);
        assertEq(strategy.assetsUnderManagement(), strategyBalance);
    }

    /**************************************************************************************************************************************/
    /*** Non-Zero Yield — Non-Zero Duration — Fees Round to Zero                                                                        ***/
    /**************************************************************************************************************************************/

    function test_realizeYield_success_nonZeroYield_nonZeroDuration_feesRoundToZero_noBuffer() external {
        vm.prank(managedWallet);
        strategy.realizeYield(0, 0, "FLUSH");

        assertEq(asset.balanceOf(address(strategy)),         strategyBalance);
        assertEq(asset.balanceOf(address(managedWallet)),    newYieldAmount);
        assertEq(asset.balanceOf(address(strategyDelegate)), 0);
        assertEq(asset.balanceOf(address(mapleTreasury)),    0);

        assertEq(strategy.scheduledYieldAssets(), scheduledYieldAssets);
        assertEq(strategy.yieldStart(),           yieldStart);
        assertEq(strategy.yieldDeadline(),        yieldStart);

        assertEq(strategy.realizedYield(),         scheduledYieldAssets);
        assertEq(strategy.unrealizedYield(),       0);
        assertEq(strategy.availableToWithdraw(),   strategyBalance);
        assertEq(strategy.assetsUnderManagement(), strategyBalance);

        vm.warp(yieldStart + 2 hours);

        vm.expectEmit();
        emit IMapleAllocationStrategy.YieldRealized(managedWallet, 0, tinyYieldAmount, 0, 0, newYieldDuration, "");

        vm.prank(managedWallet);
        strategy.realizeYield(tinyYieldAmount, newYieldDuration, "");

        assertEq(asset.balanceOf(address(strategy)),         strategyBalance + tinyYieldAmount);
        assertEq(asset.balanceOf(address(managedWallet)),    newYieldAmount - tinyYieldAmount);
        assertEq(asset.balanceOf(address(strategyDelegate)), 0);
        assertEq(asset.balanceOf(address(mapleTreasury)),    0);

        assertEq(strategy.scheduledYieldAssets(), tinyYieldAmount);
        assertEq(strategy.yieldStart(),           yieldStart + 2 hours);
        assertEq(strategy.yieldDeadline(),        yieldStart + 2 hours + newYieldDuration);

        assertEq(strategy.realizedYield(),         0);
        assertEq(strategy.unrealizedYield(),       tinyYieldAmount);
        assertEq(strategy.availableToWithdraw(),   strategyBalance);
        assertEq(strategy.assetsUnderManagement(), strategyBalance);
    }

    function test_realizeYield_success_nonZeroYield_nonZeroDuration_feesRoundToZero_bufferAtStart() external {
        assertEq(asset.balanceOf(address(strategy)),         strategyBalance);
        assertEq(asset.balanceOf(address(managedWallet)),    newYieldAmount);
        assertEq(asset.balanceOf(address(strategyDelegate)), 0);
        assertEq(asset.balanceOf(address(mapleTreasury)),    0);

        assertEq(strategy.scheduledYieldAssets(), scheduledYieldAssets);
        assertEq(strategy.yieldStart(),           yieldStart);
        assertEq(strategy.yieldDeadline(),        yieldDeadline);

        assertEq(strategy.realizedYield(),         0);
        assertEq(strategy.unrealizedYield(),       scheduledYieldAssets);
        assertEq(strategy.availableToWithdraw(),   strategyBalance - scheduledYieldAssets);
        assertEq(strategy.assetsUnderManagement(), strategyBalance - scheduledYieldAssets);

        vm.expectEmit();
        emit IMapleAllocationStrategy.YieldRealized(managedWallet, scheduledYieldAssets, tinyYieldAmount, 0, 0, newYieldDuration, "");

        vm.prank(managedWallet);
        strategy.realizeYield(tinyYieldAmount, newYieldDuration, "");

        assertEq(asset.balanceOf(address(strategy)),         strategyBalance + tinyYieldAmount);
        assertEq(asset.balanceOf(address(managedWallet)),    newYieldAmount - tinyYieldAmount);
        assertEq(asset.balanceOf(address(strategyDelegate)), 0);
        assertEq(asset.balanceOf(address(mapleTreasury)),    0);

        assertEq(strategy.scheduledYieldAssets(), scheduledYieldAssets + tinyYieldAmount);
        assertEq(strategy.yieldStart(),           yieldStart);
        assertEq(strategy.yieldDeadline(),        yieldStart + newYieldDuration);

        assertEq(strategy.realizedYield(),         0);
        assertEq(strategy.unrealizedYield(),       scheduledYieldAssets + tinyYieldAmount);
        assertEq(strategy.availableToWithdraw(),   strategyBalance - scheduledYieldAssets);
        assertEq(strategy.assetsUnderManagement(), strategyBalance - scheduledYieldAssets);
    }

    function test_realizeYield_success_nonZeroYield_nonZeroDuration_feesRoundToZero_bufferAccruing() external {
        uint256 elapsedDuration  = yieldAccruing - yieldStart;
        uint256 totalDuration    = yieldDeadline - yieldStart;

        uint256 realizedYield   = scheduledYieldAssets * elapsedDuration / totalDuration;
        uint256 unrealizedYield = scheduledYieldAssets - realizedYield;

        vm.warp(yieldAccruing);

        assertEq(asset.balanceOf(address(strategy)),         strategyBalance);
        assertEq(asset.balanceOf(address(managedWallet)),    newYieldAmount);
        assertEq(asset.balanceOf(address(strategyDelegate)), 0);
        assertEq(asset.balanceOf(address(mapleTreasury)),    0);

        assertEq(strategy.scheduledYieldAssets(), scheduledYieldAssets);
        assertEq(strategy.yieldStart(),           yieldStart);
        assertEq(strategy.yieldDeadline(),        yieldDeadline);

        assertEq(strategy.realizedYield(),         realizedYield);
        assertEq(strategy.unrealizedYield(),       unrealizedYield);
        assertEq(strategy.availableToWithdraw(),   strategyBalance - unrealizedYield);
        assertEq(strategy.assetsUnderManagement(), strategyBalance - unrealizedYield);

        vm.expectEmit();
        emit IMapleAllocationStrategy.YieldRealized(managedWallet, unrealizedYield, tinyYieldAmount, 0, 0, newYieldDuration, "");

        vm.prank(managedWallet);
        strategy.realizeYield(tinyYieldAmount, newYieldDuration, "");

        assertEq(asset.balanceOf(address(strategy)),         strategyBalance + tinyYieldAmount);
        assertEq(asset.balanceOf(address(managedWallet)),    newYieldAmount - tinyYieldAmount);
        assertEq(asset.balanceOf(address(strategyDelegate)), 0);
        assertEq(asset.balanceOf(address(mapleTreasury)),    0);

        assertEq(strategy.scheduledYieldAssets(), unrealizedYield + tinyYieldAmount);
        assertEq(strategy.yieldStart(),           yieldAccruing);
        assertEq(strategy.yieldDeadline(),        yieldAccruing + newYieldDuration);

        assertEq(strategy.realizedYield(),         0);
        assertEq(strategy.unrealizedYield(),       unrealizedYield + tinyYieldAmount);
        assertEq(strategy.availableToWithdraw(),   strategyBalance - unrealizedYield);
        assertEq(strategy.assetsUnderManagement(), strategyBalance - unrealizedYield);
    }

    function test_realizeYield_success_nonZeroYield_nonZeroDuration_feesRoundToZero_bufferAtDeadline() external {
        vm.warp(yieldDeadline);

        assertEq(asset.balanceOf(address(strategy)),         strategyBalance);
        assertEq(asset.balanceOf(address(managedWallet)),    newYieldAmount);
        assertEq(asset.balanceOf(address(strategyDelegate)), 0);
        assertEq(asset.balanceOf(address(mapleTreasury)),    0);

        assertEq(strategy.scheduledYieldAssets(), scheduledYieldAssets);
        assertEq(strategy.yieldStart(),           yieldStart);
        assertEq(strategy.yieldDeadline(),        yieldDeadline);

        assertEq(strategy.realizedYield(),       scheduledYieldAssets);
        assertEq(strategy.unrealizedYield(),     0);
        assertEq(strategy.availableToWithdraw(), strategyBalance);

        vm.expectEmit();
        emit IMapleAllocationStrategy.YieldRealized(managedWallet, 0, tinyYieldAmount, 0, 0, newYieldDuration, "");

        vm.prank(managedWallet);
        strategy.realizeYield(tinyYieldAmount, newYieldDuration, "");

        assertEq(asset.balanceOf(address(strategy)),         strategyBalance + tinyYieldAmount);
        assertEq(asset.balanceOf(address(managedWallet)),    newYieldAmount - tinyYieldAmount);
        assertEq(asset.balanceOf(address(strategyDelegate)), 0);
        assertEq(asset.balanceOf(address(mapleTreasury)),    0);

        assertEq(strategy.scheduledYieldAssets(), tinyYieldAmount);
        assertEq(strategy.yieldStart(),           yieldDeadline);
        assertEq(strategy.yieldDeadline(),        yieldDeadline + newYieldDuration);

        assertEq(strategy.realizedYield(),       0);
        assertEq(strategy.unrealizedYield(),     tinyYieldAmount);
        assertEq(strategy.availableToWithdraw(), strategyBalance);
    }

    function test_realizeYield_success_nonZeroYield_nonZeroDuration_feesRoundToZero_bufferPastDeadline() external {
        vm.warp(yieldFinished);

        assertEq(asset.balanceOf(address(strategy)),         strategyBalance);
        assertEq(asset.balanceOf(address(managedWallet)),    newYieldAmount);
        assertEq(asset.balanceOf(address(strategyDelegate)), 0);
        assertEq(asset.balanceOf(address(mapleTreasury)),    0);

        assertEq(strategy.scheduledYieldAssets(), scheduledYieldAssets);
        assertEq(strategy.yieldStart(),           yieldStart);
        assertEq(strategy.yieldDeadline(),        yieldDeadline);

        assertEq(strategy.realizedYield(),         scheduledYieldAssets);
        assertEq(strategy.unrealizedYield(),       0);
        assertEq(strategy.availableToWithdraw(),   strategyBalance);
        assertEq(strategy.assetsUnderManagement(), strategyBalance);

        vm.expectEmit();
        emit IMapleAllocationStrategy.YieldRealized(managedWallet, 0, tinyYieldAmount, 0, 0, newYieldDuration, "");

        vm.prank(managedWallet);
        strategy.realizeYield(tinyYieldAmount, newYieldDuration, "");

        assertEq(asset.balanceOf(address(strategy)),         strategyBalance + tinyYieldAmount);
        assertEq(asset.balanceOf(address(managedWallet)),    newYieldAmount - tinyYieldAmount);
        assertEq(asset.balanceOf(address(strategyDelegate)), 0);
        assertEq(asset.balanceOf(address(mapleTreasury)),    0);

        assertEq(strategy.scheduledYieldAssets(), tinyYieldAmount);
        assertEq(strategy.yieldStart(),           yieldFinished);
        assertEq(strategy.yieldDeadline(),        yieldFinished + newYieldDuration);

        assertEq(strategy.realizedYield(),         0);
        assertEq(strategy.unrealizedYield(),       tinyYieldAmount);
        assertEq(strategy.availableToWithdraw(),   strategyBalance);
        assertEq(strategy.assetsUnderManagement(), strategyBalance);
    }

    /**************************************************************************************************************************************/
    /*** With Yield Cap                                                                                                                 ***/
    /**************************************************************************************************************************************/

    function test_realizeYield_success_atYieldCap() external {
        uint256 delegateFee    = newYieldAmount * delegateFeeRate / 1e6;
        uint256 protocolFee    = newYieldAmount * protocolFeeRate / 1e6;
        uint256 netYieldAmount = newYieldAmount - delegateFee - protocolFee;

        strategy.__setYieldCap(newYieldAmount);

        assertEq(asset.balanceOf(address(strategy)),         strategyBalance);
        assertEq(asset.balanceOf(address(managedWallet)),    newYieldAmount);
        assertEq(asset.balanceOf(address(strategyDelegate)), 0);
        assertEq(asset.balanceOf(address(mapleTreasury)),    0);

        assertEq(strategy.scheduledYieldAssets(), scheduledYieldAssets);
        assertEq(strategy.yieldStart(),           yieldStart);
        assertEq(strategy.yieldDeadline(),        yieldDeadline);

        assertEq(strategy.realizedYield(),         0);
        assertEq(strategy.unrealizedYield(),       scheduledYieldAssets);
        assertEq(strategy.availableToWithdraw(),   strategyBalance - scheduledYieldAssets);
        assertEq(strategy.assetsUnderManagement(), strategyBalance - scheduledYieldAssets);

        vm.expectEmit();
        emit IMapleAllocationStrategy.YieldRealized(
            managedWallet,
            scheduledYieldAssets,
            netYieldAmount,
            delegateFee,
            protocolFee,
            newYieldDuration,
            ""
        );

        vm.prank(managedWallet);
        strategy.realizeYield(newYieldAmount, newYieldDuration, "");

        assertEq(asset.balanceOf(address(strategy)),         strategyBalance + netYieldAmount);
        assertEq(asset.balanceOf(address(managedWallet)),    0);
        assertEq(asset.balanceOf(address(strategyDelegate)), delegateFee);
        assertEq(asset.balanceOf(address(mapleTreasury)),    protocolFee);

        assertEq(strategy.scheduledYieldAssets(), scheduledYieldAssets + netYieldAmount);
        assertEq(strategy.yieldStart(),           yieldStart);
        assertEq(strategy.yieldDeadline(),        yieldStart + newYieldDuration);

        assertEq(strategy.realizedYield(),         0);
        assertEq(strategy.unrealizedYield(),       scheduledYieldAssets + netYieldAmount);
        assertEq(strategy.availableToWithdraw(),   strategyBalance - scheduledYieldAssets);
        assertEq(strategy.assetsUnderManagement(), strategyBalance - scheduledYieldAssets);
    }

    function test_realizeYield_success_zeroYield_zeroYieldCap() external {
        strategy.__setYieldCap(0);

        assertEq(asset.balanceOf(address(strategy)),         strategyBalance);
        assertEq(asset.balanceOf(address(managedWallet)),    newYieldAmount);
        assertEq(asset.balanceOf(address(strategyDelegate)), 0);
        assertEq(asset.balanceOf(address(mapleTreasury)),    0);

        assertEq(strategy.scheduledYieldAssets(), scheduledYieldAssets);
        assertEq(strategy.yieldStart(),           yieldStart);
        assertEq(strategy.yieldDeadline(),        yieldDeadline);

        assertEq(strategy.realizedYield(),         0);
        assertEq(strategy.unrealizedYield(),       scheduledYieldAssets);
        assertEq(strategy.availableToWithdraw(),   strategyBalance - scheduledYieldAssets);
        assertEq(strategy.assetsUnderManagement(), strategyBalance - scheduledYieldAssets);

        vm.expectEmit();
        emit IMapleAllocationStrategy.YieldRealized(managedWallet, scheduledYieldAssets, 0, 0, 0, newYieldDuration, "");

        vm.prank(managedWallet);
        strategy.realizeYield(0, newYieldDuration, "");

        assertEq(asset.balanceOf(address(strategy)),         strategyBalance);
        assertEq(asset.balanceOf(address(managedWallet)),    newYieldAmount);
        assertEq(asset.balanceOf(address(strategyDelegate)), 0);
        assertEq(asset.balanceOf(address(mapleTreasury)),    0);

        assertEq(strategy.scheduledYieldAssets(), scheduledYieldAssets);
        assertEq(strategy.yieldStart(),           yieldStart);
        assertEq(strategy.yieldDeadline(),        yieldStart + newYieldDuration);

        assertEq(strategy.realizedYield(),         0);
        assertEq(strategy.unrealizedYield(),       scheduledYieldAssets);
        assertEq(strategy.availableToWithdraw(),   strategyBalance - scheduledYieldAssets);
        assertEq(strategy.assetsUnderManagement(), strategyBalance - scheduledYieldAssets);
    }

    function test_realizeYield_success_zeroYield_capBelowScheduledBuffer() external {
        strategy.__setYieldCap(scheduledYieldAssets - 1);

        assertEq(asset.balanceOf(address(strategy)),         strategyBalance);
        assertEq(asset.balanceOf(address(managedWallet)),    newYieldAmount);
        assertEq(asset.balanceOf(address(strategyDelegate)), 0);
        assertEq(asset.balanceOf(address(mapleTreasury)),    0);

        assertEq(strategy.scheduledYieldAssets(), scheduledYieldAssets);
        assertEq(strategy.yieldStart(),           yieldStart);
        assertEq(strategy.yieldDeadline(),        yieldDeadline);

        assertEq(strategy.realizedYield(),         0);
        assertEq(strategy.unrealizedYield(),       scheduledYieldAssets);
        assertEq(strategy.availableToWithdraw(),   strategyBalance - scheduledYieldAssets);
        assertEq(strategy.assetsUnderManagement(), strategyBalance - scheduledYieldAssets);

        vm.expectEmit();
        emit IMapleAllocationStrategy.YieldRealized(managedWallet, scheduledYieldAssets, 0, 0, 0, newYieldDuration, "");

        vm.prank(managedWallet);
        strategy.realizeYield(0, newYieldDuration, "");

        assertEq(asset.balanceOf(address(strategy)),         strategyBalance);
        assertEq(asset.balanceOf(address(managedWallet)),    newYieldAmount);
        assertEq(asset.balanceOf(address(strategyDelegate)), 0);
        assertEq(asset.balanceOf(address(mapleTreasury)),    0);

        assertEq(strategy.scheduledYieldAssets(), scheduledYieldAssets);
        assertEq(strategy.yieldStart(),           yieldStart);
        assertEq(strategy.yieldDeadline(),        yieldStart + newYieldDuration);

        assertEq(strategy.realizedYield(),         0);
        assertEq(strategy.unrealizedYield(),       scheduledYieldAssets);
        assertEq(strategy.availableToWithdraw(),   strategyBalance - scheduledYieldAssets);
        assertEq(strategy.assetsUnderManagement(), strategyBalance - scheduledYieldAssets);
    }

}
