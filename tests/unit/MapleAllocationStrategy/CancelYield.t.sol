// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import { IMapleAllocationStrategy } from "../../../contracts/interfaces/IMapleAllocationStrategy.sol";

import { TestBase } from "../../utils/TestBase.sol";

contract CancelYieldTestBase is TestBase {

    address recipient = makeAddr("recipient");

    uint256 strategyBalance = 35_200e6;  // Total initial balance, includes yieldAssets.
    uint256 yieldAssets     = 10_001e6;  // Net yield assets in the buffer (post-fee).
    uint256 cancelAmount    = 3_000e6;   // Partial cancellation amount used in partial cancel tests.

    uint32 yieldDuration = 3 days;  // Yield buffer window.

    uint32 yieldStart;     // Timestamp at which the buffer is initialized.
    uint32 yieldAccruing;  // Timestamp at which 67% of the buffer has been realized.
    uint32 yieldDeadline;  // Timestamp at which the entire buffer has been realized.

    function setUp() public override {
        super.setUp();

        yieldStart    = startingTime;
        yieldAccruing = startingTime + 2 days;
        yieldDeadline = startingTime + yieldDuration;

        asset.mint(address(strategy), strategyBalance);
        strategy.__setRecordedAssets(strategyBalance);

        strategy.__setYieldBuffer(yieldAssets, yieldStart, yieldDeadline);
        globals.__setIsInstanceOf("MAPLE_MANAGED_WALLET", recipient, true);
    }

}

contract CancelYieldFailureTests is CancelYieldTestBase {

    function test_cancelYield_revert_functionPaused() external {
        globals.__setIsFunctionPaused(IMapleAllocationStrategy.cancelYield.selector, true);

        vm.prank(strategyDelegate);
        vm.expectRevert("MAS:PAUSED");
        strategy.cancelYield(yieldAssets, recipient);
    }

    function test_cancelYield_revert_reentrancy() external {
        strategy.__setLocked(2);

        vm.prank(strategyDelegate);
        vm.expectRevert("MAS:LOCKED");
        strategy.cancelYield(yieldAssets, recipient);
    }

    function test_cancelYield_revert_notAuthorized() external {
        vm.prank(makeAddr("notAuthorized"));
        vm.expectRevert("MAS:NOT_AUTHORIZED");
        strategy.cancelYield(yieldAssets, recipient);
    }

    function test_cancelYield_revert_notAuthorized_operationalAdmin() external {
        vm.prank(operationalAdmin);
        vm.expectRevert("MAS:NOT_AUTHORIZED");
        strategy.cancelYield(yieldAssets, recipient);
    }

    function test_cancelYield_revert_zeroAssets() external {
        vm.prank(strategyDelegate);
        vm.expectRevert("MAS:CY:ZERO_ASSETS");
        strategy.cancelYield(0, recipient);
    }

    function test_cancelYield_revert_emptyBuffer_allAssets() external {
        strategy.__setYieldBuffer(0, 0, 0);

        vm.prank(strategyDelegate);
        vm.expectRevert("MAS:CY:ZERO_ASSETS");
        strategy.cancelYield(type(uint256).max, recipient);
    }

    function test_cancelYield_revert_atDeadline_allAssets() external {
        vm.warp(yieldDeadline);

        vm.prank(strategyDelegate);
        vm.expectRevert("MAS:CY:ZERO_ASSETS");
        strategy.cancelYield(type(uint256).max, recipient);
    }

    function test_cancelYield_revert_afterDeadline_allAssets() external {
        vm.warp(yieldDeadline + 1 seconds);

        vm.prank(strategyDelegate);
        vm.expectRevert("MAS:CY:ZERO_ASSETS");
        strategy.cancelYield(type(uint256).max, recipient);
    }

    function test_cancelYield_revert_emptyBuffer() external {
        strategy.__setYieldBuffer(0, 0, 0);

        vm.prank(strategyDelegate);
        vm.expectRevert("MAS:CY:EXCEEDS_UNREALIZED");
        strategy.cancelYield(1, recipient);
    }

    function test_cancelYield_revert_atDeadline() external {
        vm.warp(yieldDeadline);

        vm.prank(strategyDelegate);
        vm.expectRevert("MAS:CY:EXCEEDS_UNREALIZED");
        strategy.cancelYield(1, recipient);
    }

    function test_cancelYield_revert_afterDeadline() external {
        vm.warp(yieldDeadline + 1 seconds);

        vm.prank(strategyDelegate);
        vm.expectRevert("MAS:CY:EXCEEDS_UNREALIZED");
        strategy.cancelYield(1, recipient);
    }

    function test_cancelYield_revert_exceedsRemaining() external {
        vm.warp(yieldAccruing);

        uint256 realizedYield   = yieldAssets * (yieldAccruing - yieldStart) / (yieldDeadline - yieldStart);
        uint256 unrealizedYield = yieldAssets - realizedYield;

        vm.prank(strategyDelegate);
        vm.expectRevert("MAS:CY:EXCEEDS_UNREALIZED");
        strategy.cancelYield(unrealizedYield + 1, recipient);
    }

    function test_cancelYield_revert_invalidRecipient() external {
        address invalidRecipient = makeAddr("invalidRecipient");

        vm.prank(strategyDelegate);
        vm.expectRevert("MAS:CY:INVALID_RECIPIENT");
        strategy.cancelYield(yieldAssets, invalidRecipient);
    }

    function test_cancelYield_revert_transferFailed() external {
        asset.__setTransferReverts(true);

        vm.prank(strategyDelegate);
        vm.expectRevert("MAS:CY:TRANSFER_FAILED");
        strategy.cancelYield(yieldAssets, recipient);
    }

}

contract CancelYieldSuccessTests is CancelYieldTestBase {

    /**************************************************************************************************************************************/
    /*** No Elapsed Time                                                                                                                ***/
    /**************************************************************************************************************************************/

    function test_cancelYield_success_noElapsedTime_partialCancel() external {
        assertEq(asset.balanceOf(address(strategy)),  strategyBalance);
        assertEq(strategy.recordedAssets(),           strategyBalance);
        assertEq(asset.balanceOf(address(recipient)), 0);

        assertEq(strategy.scheduledYieldAssets(), yieldAssets);
        assertEq(strategy.yieldStart(),           yieldStart);
        assertEq(strategy.yieldDeadline(),        yieldDeadline);

        assertEq(strategy.realizedYield(),         0);
        assertEq(strategy.unrealizedYield(),       yieldAssets);
        assertEq(strategy.availableToWithdraw(),   strategyBalance - yieldAssets);
        assertEq(strategy.assetsUnderManagement(), strategyBalance - yieldAssets);

        vm.expectEmit();
        emit IMapleAllocationStrategy.YieldCancelled(strategyDelegate, recipient, cancelAmount, strategyBalance - cancelAmount);

        vm.prank(strategyDelegate);
        strategy.cancelYield(cancelAmount, recipient);

        assertEq(asset.balanceOf(address(strategy)),  strategyBalance - cancelAmount);
        assertEq(strategy.recordedAssets(),           strategyBalance - cancelAmount);
        assertEq(asset.balanceOf(address(recipient)), cancelAmount);

        assertEq(strategy.scheduledYieldAssets(), yieldAssets - cancelAmount);
        assertEq(strategy.yieldStart(),           yieldStart);
        assertEq(strategy.yieldDeadline(),        yieldDeadline);

        assertEq(strategy.realizedYield(),         0);
        assertEq(strategy.unrealizedYield(),       yieldAssets - cancelAmount);
        assertEq(strategy.availableToWithdraw(),   strategyBalance - yieldAssets);
        assertEq(strategy.assetsUnderManagement(), strategyBalance - yieldAssets);
    }

    function test_cancelYield_success_noElapsedTime_fullCancel_explicit() external {
        assertEq(asset.balanceOf(address(strategy)),  strategyBalance);
        assertEq(strategy.recordedAssets(),           strategyBalance);
        assertEq(asset.balanceOf(address(recipient)), 0);

        assertEq(strategy.scheduledYieldAssets(), yieldAssets);
        assertEq(strategy.yieldStart(),           yieldStart);
        assertEq(strategy.yieldDeadline(),        yieldDeadline);

        assertEq(strategy.realizedYield(),         0);
        assertEq(strategy.unrealizedYield(),       yieldAssets);
        assertEq(strategy.availableToWithdraw(),   strategyBalance - yieldAssets);
        assertEq(strategy.assetsUnderManagement(), strategyBalance - yieldAssets);

        vm.expectEmit();
        emit IMapleAllocationStrategy.YieldCancelled(securityAdmin, recipient, yieldAssets, strategyBalance - yieldAssets);

        vm.prank(securityAdmin);
        strategy.cancelYield(yieldAssets, recipient);

        assertEq(asset.balanceOf(address(strategy)),  strategyBalance - yieldAssets);
        assertEq(strategy.recordedAssets(),           strategyBalance - yieldAssets);
        assertEq(asset.balanceOf(address(recipient)), yieldAssets);

        assertEq(strategy.scheduledYieldAssets(), 0);
        assertEq(strategy.yieldStart(),           yieldStart);
        assertEq(strategy.yieldDeadline(),        yieldDeadline);

        assertEq(strategy.realizedYield(),         0);
        assertEq(strategy.unrealizedYield(),       0);
        assertEq(strategy.availableToWithdraw(),   strategyBalance - yieldAssets);
        assertEq(strategy.assetsUnderManagement(), strategyBalance - yieldAssets);
    }

    function test_cancelYield_success_noElapsedTime_fullCancel_maxUint() external {
        assertEq(asset.balanceOf(address(strategy)),  strategyBalance);
        assertEq(strategy.recordedAssets(),           strategyBalance);
        assertEq(asset.balanceOf(address(recipient)), 0);

        assertEq(strategy.scheduledYieldAssets(), yieldAssets);
        assertEq(strategy.yieldStart(),           yieldStart);
        assertEq(strategy.yieldDeadline(),        yieldDeadline);

        assertEq(strategy.realizedYield(),         0);
        assertEq(strategy.unrealizedYield(),       yieldAssets);
        assertEq(strategy.availableToWithdraw(),   strategyBalance - yieldAssets);
        assertEq(strategy.assetsUnderManagement(), strategyBalance - yieldAssets);

        vm.expectEmit();
        emit IMapleAllocationStrategy.YieldCancelled(strategyDelegate, recipient, yieldAssets, strategyBalance - yieldAssets);

        vm.prank(strategyDelegate);
        strategy.cancelYield(type(uint256).max, recipient);

        assertEq(asset.balanceOf(address(strategy)),  strategyBalance - yieldAssets);
        assertEq(strategy.recordedAssets(),           strategyBalance - yieldAssets);
        assertEq(asset.balanceOf(address(recipient)), yieldAssets);

        assertEq(strategy.scheduledYieldAssets(), 0);
        assertEq(strategy.yieldStart(),           yieldStart);
        assertEq(strategy.yieldDeadline(),        yieldDeadline);

        assertEq(strategy.realizedYield(),         0);
        assertEq(strategy.unrealizedYield(),       0);
        assertEq(strategy.availableToWithdraw(),   strategyBalance - yieldAssets);
        assertEq(strategy.assetsUnderManagement(), strategyBalance - yieldAssets);
    }

    /**************************************************************************************************************************************/
    /*** Partial Elapsed Time                                                                                                           ***/
    /**************************************************************************************************************************************/

    function test_cancelYield_success_partialElapsed_partialCancel() external {
        vm.warp(yieldAccruing);

        uint256 realizedYield   = yieldAssets * (yieldAccruing - yieldStart) / (yieldDeadline - yieldStart);
        uint256 unrealizedYield = yieldAssets - realizedYield;

        assertEq(asset.balanceOf(address(strategy)),  strategyBalance);
        assertEq(strategy.recordedAssets(),           strategyBalance);
        assertEq(asset.balanceOf(address(recipient)), 0);

        assertEq(strategy.scheduledYieldAssets(), yieldAssets);
        assertEq(strategy.yieldStart(),           yieldStart);
        assertEq(strategy.yieldDeadline(),        yieldDeadline);

        assertEq(strategy.realizedYield(),         realizedYield);
        assertEq(strategy.unrealizedYield(),       unrealizedYield);
        assertEq(strategy.availableToWithdraw(),   strategyBalance - unrealizedYield);
        assertEq(strategy.assetsUnderManagement(), strategyBalance - unrealizedYield);

        vm.expectEmit();
        emit IMapleAllocationStrategy.YieldCancelled(securityAdmin, recipient, cancelAmount, strategyBalance - cancelAmount);

        vm.prank(securityAdmin);
        strategy.cancelYield(cancelAmount, recipient);

        assertEq(asset.balanceOf(address(strategy)),  strategyBalance - cancelAmount);
        assertEq(strategy.recordedAssets(),           strategyBalance - cancelAmount);
        assertEq(asset.balanceOf(address(recipient)), cancelAmount);

        assertEq(strategy.scheduledYieldAssets(), unrealizedYield - cancelAmount);
        assertEq(strategy.yieldStart(),           yieldAccruing);
        assertEq(strategy.yieldDeadline(),        yieldDeadline);

        assertEq(strategy.realizedYield(),         0);
        assertEq(strategy.unrealizedYield(),       unrealizedYield - cancelAmount);
        assertEq(strategy.availableToWithdraw(),   strategyBalance - unrealizedYield);
        assertEq(strategy.assetsUnderManagement(), strategyBalance - unrealizedYield);

        vm.warp(yieldDeadline);

        assertEq(asset.balanceOf(address(strategy)),  strategyBalance - cancelAmount);
        assertEq(strategy.recordedAssets(),           strategyBalance - cancelAmount);
        assertEq(asset.balanceOf(address(recipient)), cancelAmount);

        assertEq(strategy.scheduledYieldAssets(), unrealizedYield - cancelAmount);
        assertEq(strategy.yieldStart(),           yieldAccruing);
        assertEq(strategy.yieldDeadline(),        yieldDeadline);

        assertEq(strategy.realizedYield(),         unrealizedYield - cancelAmount);
        assertEq(strategy.unrealizedYield(),       0);
        assertEq(strategy.availableToWithdraw(),   strategyBalance - cancelAmount);
        assertEq(strategy.assetsUnderManagement(), strategyBalance - cancelAmount);
    }

    function test_cancelYield_success_partialElapsed_fullCancel_explicit() external {
        vm.warp(yieldAccruing);

        uint256 realizedYield   = yieldAssets * (yieldAccruing - yieldStart) / (yieldDeadline - yieldStart);
        uint256 unrealizedYield = yieldAssets - realizedYield;

        assertEq(asset.balanceOf(address(strategy)),  strategyBalance);
        assertEq(strategy.recordedAssets(),           strategyBalance);
        assertEq(asset.balanceOf(address(recipient)), 0);

        assertEq(strategy.scheduledYieldAssets(), yieldAssets);
        assertEq(strategy.yieldStart(),           yieldStart);
        assertEq(strategy.yieldDeadline(),        yieldDeadline);

        assertEq(strategy.realizedYield(),         realizedYield);
        assertEq(strategy.unrealizedYield(),       unrealizedYield);
        assertEq(strategy.availableToWithdraw(),   strategyBalance - unrealizedYield);
        assertEq(strategy.assetsUnderManagement(), strategyBalance - unrealizedYield);

        vm.expectEmit();
        emit IMapleAllocationStrategy.YieldCancelled(strategyDelegate, recipient, unrealizedYield, strategyBalance - unrealizedYield);

        vm.prank(strategyDelegate);
        strategy.cancelYield(unrealizedYield, recipient);

        assertEq(asset.balanceOf(address(strategy)),  strategyBalance - unrealizedYield);
        assertEq(strategy.recordedAssets(),           strategyBalance - unrealizedYield);
        assertEq(asset.balanceOf(address(recipient)), unrealizedYield);

        assertEq(strategy.scheduledYieldAssets(), 0);
        assertEq(strategy.yieldStart(),           yieldAccruing);
        assertEq(strategy.yieldDeadline(),        yieldDeadline);

        assertEq(strategy.realizedYield(),         0);
        assertEq(strategy.unrealizedYield(),       0);
        assertEq(strategy.availableToWithdraw(),   strategyBalance - unrealizedYield);
        assertEq(strategy.assetsUnderManagement(), strategyBalance - unrealizedYield);
    }

    function test_cancelYield_success_partialElapsed_fullCancel_maxUint() external {
        vm.warp(yieldAccruing);

        uint256 realizedYield   = yieldAssets * (yieldAccruing - yieldStart) / (yieldDeadline - yieldStart);
        uint256 unrealizedYield = yieldAssets - realizedYield;

        assertEq(asset.balanceOf(address(strategy)),  strategyBalance);
        assertEq(strategy.recordedAssets(),           strategyBalance);
        assertEq(asset.balanceOf(address(recipient)), 0);

        assertEq(strategy.scheduledYieldAssets(), yieldAssets);
        assertEq(strategy.yieldStart(),           yieldStart);
        assertEq(strategy.yieldDeadline(),        yieldDeadline);

        assertEq(strategy.realizedYield(),         realizedYield);
        assertEq(strategy.unrealizedYield(),       unrealizedYield);
        assertEq(strategy.availableToWithdraw(),   strategyBalance - unrealizedYield);
        assertEq(strategy.assetsUnderManagement(), strategyBalance - unrealizedYield);

        vm.expectEmit();
        emit IMapleAllocationStrategy.YieldCancelled(securityAdmin, recipient, unrealizedYield, strategyBalance - unrealizedYield);

        vm.prank(securityAdmin);
        strategy.cancelYield(type(uint256).max, recipient);

        assertEq(asset.balanceOf(address(strategy)),  strategyBalance - unrealizedYield);
        assertEq(strategy.recordedAssets(),           strategyBalance - unrealizedYield);
        assertEq(asset.balanceOf(address(recipient)), unrealizedYield);

        assertEq(strategy.scheduledYieldAssets(), 0);
        assertEq(strategy.yieldStart(),           yieldAccruing);
        assertEq(strategy.yieldDeadline(),        yieldDeadline);

        assertEq(strategy.realizedYield(),         0);
        assertEq(strategy.unrealizedYield(),       0);
        assertEq(strategy.availableToWithdraw(),   strategyBalance - unrealizedYield);
        assertEq(strategy.assetsUnderManagement(), strategyBalance - unrealizedYield);
    }

}
