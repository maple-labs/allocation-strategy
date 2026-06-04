// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import { stdError } from "../../../modules/forge-std/src/StdError.sol";

import { TestBase } from "../../utils/TestBase.sol";

contract AssetsUnderManagementTests is TestBase {

    address tradingAddress = makeAddr("tradingAddress");

    uint256 deployedAssets  = 2_500_000e6;
    uint256 strategyBalance = 1_000_000e6;
    uint256 yieldAssets     = 600_000e6;

    uint32 yieldDuration = 3 days;

    /**************************************************************************************************************************************/
    /*** Buffer Not Set                                                                                                                 ***/
    /**************************************************************************************************************************************/

    function test_assetsUnderManagement_noYield_zeroDeployed_zeroBalance() external view {
        assertEq(strategy.assetsUnderManagement(), 0);
    }

    function test_assetsUnderManagement_noYield_zeroDeployed_nonZeroBalance() external {
        asset.mint(address(strategy), strategyBalance);

        assertEq(strategy.assetsUnderManagement(), strategyBalance);
    }

    function test_assetsUnderManagement_noYield_nonZeroDeployed_zeroBalance() external {
        strategy.__setDeployedAssetsOf(tradingAddress, deployedAssets);

        assertEq(strategy.assetsUnderManagement(), deployedAssets);
    }

    function test_assetsUnderManagement_noYield_nonZeroDeployed_nonZeroBalance() external {
        asset.mint(address(strategy), strategyBalance);

        strategy.__setDeployedAssetsOf(tradingAddress, deployedAssets);

        assertEq(strategy.assetsUnderManagement(), deployedAssets + strategyBalance);
    }

    /**************************************************************************************************************************************/
    /*** Buffer Started                                                                                                                 ***/
    /**************************************************************************************************************************************/

    // NOTE: Unreachable since yield can't be withdrawn before it realizes.
    function test_assetsUnderManagement_yieldBuffer_elapsedZero_zeroDeployed_zeroBalance() external {
        strategy.__setYieldBuffer(yieldAssets, startingTime, startingTime + yieldDuration);

        vm.expectRevert(stdError.arithmeticError);
        strategy.assetsUnderManagement();
    }

    function test_assetsUnderManagement_yieldBuffer_elapsedZero_zeroDeployed_nonZeroBalance() external {
        asset.mint(address(strategy), strategyBalance);

        strategy.__setYieldBuffer(yieldAssets, startingTime, startingTime + yieldDuration);

        assertEq(strategy.assetsUnderManagement(), strategyBalance - yieldAssets);
    }

    // NOTE: Unreachable since yield can't be withdrawn before it realizes.
    function test_assetsUnderManagement_yieldBuffer_elapsedZero_nonZeroDeployed_zeroBalance() external {
        strategy.__setDeployedAssetsOf(tradingAddress, deployedAssets);
        strategy.__setYieldBuffer(yieldAssets, startingTime, startingTime + yieldDuration);

        vm.expectRevert(stdError.arithmeticError);
        strategy.assetsUnderManagement();
    }

    function test_assetsUnderManagement_yieldBuffer_elapsedZero_nonZeroDeployed_nonZeroBalance() external {
        asset.mint(address(strategy), strategyBalance);

        strategy.__setDeployedAssetsOf(tradingAddress, deployedAssets);
        strategy.__setYieldBuffer(yieldAssets, startingTime, startingTime + yieldDuration);

        assertEq(strategy.assetsUnderManagement(), deployedAssets + strategyBalance - yieldAssets);
    }

    /**************************************************************************************************************************************/
    /*** Buffer Partially Elapsed                                                                                                       ***/
    /**************************************************************************************************************************************/

    // NOTE: Unreachable since yield can't be withdrawn before it realizes.
    function test_assetsUnderManagement_yieldBuffer_partialElapsed_zeroDeployed_zeroBalance() external {
        strategy.__setYieldBuffer(yieldAssets, startingTime, startingTime + yieldDuration);

        vm.warp(startingTime + yieldDuration / 3);

        vm.expectRevert(stdError.arithmeticError);
        strategy.assetsUnderManagement();
    }

    function test_assetsUnderManagement_yieldBuffer_partialElapsed_zeroDeployed_nonZeroBalance() external {
        asset.mint(address(strategy), strategyBalance);

        strategy.__setYieldBuffer(yieldAssets, startingTime, startingTime + yieldDuration);

        vm.warp(startingTime + yieldDuration / 3);

        uint256 realizedAssets   = yieldAssets / 3;
        uint256 unrealizedAssets = yieldAssets - realizedAssets;

        assertEq(strategy.assetsUnderManagement(), strategyBalance - unrealizedAssets);
    }

    // NOTE: Unreachable since yield can't be withdrawn before it realizes.
    function test_assetsUnderManagement_yieldBuffer_partialElapsed_nonZeroDeployed_zeroBalance() external {
        strategy.__setDeployedAssetsOf(tradingAddress, deployedAssets);
        strategy.__setYieldBuffer(yieldAssets, startingTime, startingTime + yieldDuration);

        vm.warp(startingTime + yieldDuration / 3);

        vm.expectRevert(stdError.arithmeticError);
        strategy.assetsUnderManagement();
    }

    function test_assetsUnderManagement_yieldBuffer_partialElapsed_nonZeroDeployed_nonZeroBalance() external {
        asset.mint(address(strategy), strategyBalance);

        strategy.__setDeployedAssetsOf(tradingAddress, deployedAssets);
        strategy.__setYieldBuffer(yieldAssets, startingTime, startingTime + yieldDuration);

        vm.warp(startingTime + yieldDuration / 3);

        uint256 realizedAssets   = yieldAssets / 3;
        uint256 unrealizedAssets = yieldAssets - realizedAssets;

        assertEq(strategy.assetsUnderManagement(), deployedAssets + strategyBalance - unrealizedAssets);
    }

    /**************************************************************************************************************************************/
    /*** Buffer Fully Elapsed                                                                                                           ***/
    /**************************************************************************************************************************************/

    function test_assetsUnderManagement_yieldBuffer_fullyElapsed_zeroDeployed_zeroBalance() external {
        strategy.__setYieldBuffer(yieldAssets, startingTime, startingTime + yieldDuration);

        vm.warp(startingTime + yieldDuration);

        assertEq(strategy.assetsUnderManagement(), 0);
    }

    function test_assetsUnderManagement_yieldBuffer_fullyElapsed_zeroDeployed_nonZeroBalance() external {
        asset.mint(address(strategy), strategyBalance);

        strategy.__setYieldBuffer(yieldAssets, startingTime, startingTime + yieldDuration);

        vm.warp(startingTime + yieldDuration);

        assertEq(strategy.assetsUnderManagement(), strategyBalance);
    }

    function test_assetsUnderManagement_yieldBuffer_fullyElapsed_nonZeroDeployed_zeroBalance() external {
        strategy.__setDeployedAssetsOf(tradingAddress, deployedAssets);
        strategy.__setYieldBuffer(yieldAssets, startingTime, startingTime + yieldDuration);

        vm.warp(startingTime + yieldDuration);

        assertEq(strategy.assetsUnderManagement(), deployedAssets);
    }

    function test_assetsUnderManagement_yieldBuffer_fullyElapsed_nonZeroDeployed_nonZeroBalance() external {
        asset.mint(address(strategy), strategyBalance);

        strategy.__setDeployedAssetsOf(tradingAddress, deployedAssets);
        strategy.__setYieldBuffer(yieldAssets, startingTime, startingTime + yieldDuration);

        vm.warp(startingTime + yieldDuration);

        assertEq(strategy.assetsUnderManagement(), deployedAssets + strategyBalance);
    }

    function test_assetsUnderManagement_yieldBuffer_pastDeadline_nonZeroDeployed_nonZeroBalance() external {
        asset.mint(address(strategy), strategyBalance);

        strategy.__setDeployedAssetsOf(tradingAddress, deployedAssets);
        strategy.__setYieldBuffer(yieldAssets, startingTime, startingTime + yieldDuration);

        vm.warp(startingTime + yieldDuration + 1 days);

        assertEq(strategy.assetsUnderManagement(), deployedAssets + strategyBalance);
    }

    /**************************************************************************************************************************************/
    /*** Buffer Instantly Realized                                                                                                      ***/
    /**************************************************************************************************************************************/

    function test_assetsUnderManagement_yieldBuffer_zeroDuration_zeroDeployed_zeroBalance() external {
        strategy.__setYieldBuffer(yieldAssets, startingTime, startingTime);

        assertEq(strategy.assetsUnderManagement(), 0);
    }

    function test_assetsUnderManagement_yieldBuffer_zeroDuration_zeroDeployed_nonZeroBalance() external {
        asset.mint(address(strategy), strategyBalance);

        strategy.__setYieldBuffer(yieldAssets, startingTime, startingTime);

        assertEq(strategy.assetsUnderManagement(), strategyBalance);
    }

    function test_assetsUnderManagement_yieldBuffer_zeroDuration_nonZeroDeployed_zeroBalance() external {
        strategy.__setDeployedAssetsOf(tradingAddress, deployedAssets);
        strategy.__setYieldBuffer(yieldAssets, startingTime, startingTime);

        assertEq(strategy.assetsUnderManagement(), deployedAssets);
    }

    function test_assetsUnderManagement_yieldBuffer_zeroDuration_nonZeroDeployed_nonZeroBalance() external {
        asset.mint(address(strategy), strategyBalance);

        strategy.__setDeployedAssetsOf(tradingAddress, deployedAssets);
        strategy.__setYieldBuffer(yieldAssets, startingTime, startingTime);

        assertEq(strategy.assetsUnderManagement(), deployedAssets + strategyBalance);
    }

}
