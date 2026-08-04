// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import { TestBase } from "../../utils/TestBase.sol";

contract UnrecordedAssetsTests is TestBase {

    uint256 deployedAssets   = 400_000e6;
    uint256 recordedAssets   = 1_000_000e6;
    uint256 unrecordedAssets = 250_000e6;

    function setUp() public override {
        super.setUp();

        asset.mint(address(strategy), recordedAssets);
        strategy.__setRecordedAssets(recordedAssets);
    }

    /**************************************************************************************************************************************/
    /*** Nothing Unrecorded                                                                                                             ***/
    /**************************************************************************************************************************************/

    function test_unrecordedAssets_zero_emptyStrategy() external {
        asset.burn(address(strategy), recordedAssets);
        strategy.__setRecordedAssets(0);

        assertEq(asset.balanceOf(address(strategy)), 0);
        assertEq(strategy.recordedAssets(),          0);
        assertEq(strategy.unrecordedAssets(),        0);
    }

    function test_unrecordedAssets_zero_fullyRecorded() external view {
        assertEq(asset.balanceOf(address(strategy)), recordedAssets);
        assertEq(strategy.recordedAssets(),          recordedAssets);
        assertEq(strategy.unrecordedAssets(),        0);
    }

    /**************************************************************************************************************************************/
    /*** Unrecorded Assets                                                                                                              ***/
    /**************************************************************************************************************************************/

    function test_unrecordedAssets_minimumUnrecorded() external {
        asset.mint(address(strategy), 1);

        assertEq(asset.balanceOf(address(strategy)), recordedAssets + 1);
        assertEq(strategy.recordedAssets(),          recordedAssets);
        assertEq(strategy.unrecordedAssets(),        1);
    }

    function test_unrecordedAssets_partiallyUnrecorded() external {
        asset.mint(address(strategy), unrecordedAssets);

        assertEq(asset.balanceOf(address(strategy)), recordedAssets + unrecordedAssets);
        assertEq(strategy.recordedAssets(),          recordedAssets);
        assertEq(strategy.unrecordedAssets(),        unrecordedAssets);
    }

    function test_unrecordedAssets_fullyUnrecorded() external {
        strategy.__setRecordedAssets(0);

        assertEq(asset.balanceOf(address(strategy)), recordedAssets);
        assertEq(strategy.recordedAssets(),          0);
        assertEq(strategy.unrecordedAssets(),        recordedAssets);
    }

    /**************************************************************************************************************************************/
    /*** Balance Shortfall                                                                                                              ***/
    /**************************************************************************************************************************************/

    // NOTE: Clamps at zero instead of underflowing, so that a shortfall does not brick skim().
    function test_unrecordedAssets_zero_minimumShortfall() external {
        asset.burn(address(strategy), 1);

        assertEq(asset.balanceOf(address(strategy)), recordedAssets - 1);
        assertEq(strategy.recordedAssets(),          recordedAssets);
        assertEq(strategy.unrecordedAssets(),        0);
    }

    function test_unrecordedAssets_zero_fullShortfall() external {
        asset.burn(address(strategy), recordedAssets);

        assertEq(asset.balanceOf(address(strategy)), 0);
        assertEq(strategy.recordedAssets(),          recordedAssets);
        assertEq(strategy.unrecordedAssets(),        0);
    }

    function test_unrecordedAssets_zero_unrecordedBelowShortfall() external {
        asset.burn(address(strategy), unrecordedAssets);
        asset.mint(address(strategy), unrecordedAssets - 1);

        assertEq(asset.balanceOf(address(strategy)), recordedAssets - 1);
        assertEq(strategy.recordedAssets(),          recordedAssets);
        assertEq(strategy.unrecordedAssets(),        0);
    }

    function test_unrecordedAssets_unrecordedAboveShortfall() external {
        asset.burn(address(strategy), unrecordedAssets);
        asset.mint(address(strategy), unrecordedAssets + 1);

        assertEq(asset.balanceOf(address(strategy)), recordedAssets + 1);
        assertEq(strategy.recordedAssets(),          recordedAssets);
        assertEq(strategy.unrecordedAssets(),        1);
    }

    /**************************************************************************************************************************************/
    /*** Independence From Other Accounting                                                                                             ***/
    /**************************************************************************************************************************************/

    function test_unrecordedAssets_ignoresYieldBuffer() external {
        asset.mint(address(strategy), unrecordedAssets);

        strategy.__setYieldBuffer(recordedAssets, startingTime, startingTime + 1 days);

        assertEq(strategy.unrealizedYield(),     recordedAssets);
        assertEq(strategy.availableToWithdraw(), 0);
        assertEq(strategy.unrecordedAssets(),    unrecordedAssets);

        vm.warp(startingTime + 1 days);

        assertEq(strategy.unrealizedYield(),     0);
        assertEq(strategy.availableToWithdraw(), recordedAssets);
        assertEq(strategy.unrecordedAssets(),    unrecordedAssets);
    }

    function test_unrecordedAssets_ignoresDeployedAssets() external {
        asset.mint(address(strategy), unrecordedAssets);

        strategy.__setDeployedAssetsOf(makeAddr("managedWallet"), deployedAssets);

        assertEq(strategy.totalDeployedAssets(),   deployedAssets);
        assertEq(strategy.assetsUnderManagement(), deployedAssets + recordedAssets);
        assertEq(strategy.unrecordedAssets(),      unrecordedAssets);
    }

}
