// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import { IMapleTradingStrategy } from "../../../contracts/interfaces/IMapleTradingStrategy.sol";

import { TestBase } from "../../utils/TestBase.sol";

contract DeployAssetsTestBase is TestBase {

    address tradingAddress  = makeAddr("tradingAddress");
    address tradingAddress2 = makeAddr("tradingAddress2");

    uint256 assetsToDeploy = 1_250_000e6;
    uint256 deployedAssets = 500_000e6;

    function setUp() public override {
        super.setUp();

        globals.__setIsGovernedInstanceOf("TRADING_ADDRESS", tradingAddress,  true);
        globals.__setIsGovernedInstanceOf("TRADING_ADDRESS", tradingAddress2, true);

        strategy.__setPermissions(tradingAddress,  true);
        strategy.__setPermissions(tradingAddress2, true);

        strategy.__setDeploymentCapOf(tradingAddress,  deployedAssets + assetsToDeploy);
        strategy.__setDeploymentCapOf(tradingAddress2, type(uint256).max);

        asset.mint(address(strategy), assetsToDeploy);
    }

}

contract DeployAssetsFailureTests is DeployAssetsTestBase {

    function test_deployAssets_revert_functionPaused() external {
        globals.__setIsFunctionPaused(IMapleTradingStrategy.deployAssets.selector, true);

        vm.prank(tradingAddress);
        vm.expectRevert("MTS:PAUSED");
        strategy.deployAssets(assetsToDeploy, "");
    }

    function test_deployAssets_revert_reentrancy() external {
        strategy.__setLocked(2);

        vm.prank(tradingAddress);
        vm.expectRevert("MTS:LOCKED");
        strategy.deployAssets(assetsToDeploy, "");
    }

    function test_deployAssets_revert_notTradingAddress() external {
        globals.__setIsGovernedInstanceOf("TRADING_ADDRESS", tradingAddress, false);

        vm.prank(tradingAddress);
        vm.expectRevert("MTS:DA:NOT_TRADING_ADDRESS");
        strategy.deployAssets(assetsToDeploy, "");
    }

    function test_deployAssets_revert_notDeployer() external {
        strategy.__setPermissions(tradingAddress, false);

        vm.prank(tradingAddress);
        vm.expectRevert("MTS:DA:NOT_ALLOWED");
        strategy.deployAssets(assetsToDeploy, "");
    }

    function test_deployAssets_revert_zeroAssets() external {
        vm.prank(tradingAddress);
        vm.expectRevert("MTS:DA:ZERO_ASSETS");
        strategy.deployAssets(0, "");
    }

    function test_deployAssets_revert_insufficientAssets() external {
        asset.burn(address(strategy), 1);

        vm.prank(tradingAddress);
        vm.expectRevert("MTS:DA:INSUFFICIENT_ASSETS");
        strategy.deployAssets(assetsToDeploy, "");
    }

    function test_deployAssets_revert_unrealizedAssets() external {
        strategy.__setYieldBuffer(assetsToDeploy, startingTime, startingTime + 1 days);

        vm.warp(startingTime + 1 days - 1 seconds);
        vm.prank(tradingAddress);
        vm.expectRevert("MTS:DA:INSUFFICIENT_ASSETS");
        strategy.deployAssets(assetsToDeploy, "");
    }

    function test_deployAssets_revert_zeroCap() external {
        strategy.__setDeploymentCapOf(tradingAddress, 0);

        vm.prank(tradingAddress);
        vm.expectRevert("MTS:DA:CAP_EXCEEDED");
        strategy.deployAssets(1, "");
    }

    function test_deployAssets_revert_exceedsCap() external {
        strategy.__setDeploymentCapOf(tradingAddress, assetsToDeploy - 1);

        vm.prank(tradingAddress);
        vm.expectRevert("MTS:DA:CAP_EXCEEDED");
        strategy.deployAssets(assetsToDeploy, "");
    }

    function test_deployAssets_revert_exceedsCap_withPriorDeployment() external {
        strategy.__setDeployedAssetsOf(tradingAddress, deployedAssets + 1);

        vm.prank(tradingAddress);
        vm.expectRevert("MTS:DA:CAP_EXCEEDED");
        strategy.deployAssets(assetsToDeploy, "");
    }

    function test_deployAssets_revert_transferFailed() external {
        asset.__setTransferReverts(true);

        vm.prank(tradingAddress);
        vm.expectRevert("MTS:DA:TRANSFER_FAILED");
        strategy.deployAssets(assetsToDeploy, "");
    }

}

contract DeployAssetsSuccessTests is DeployAssetsTestBase {

    function test_deployAssets_success_minimumDeployment() external {
        assertEq(asset.balanceOf(address(strategy)), assetsToDeploy);
        assertEq(asset.balanceOf(tradingAddress),    0);

        assertEq(strategy.totalDeployedAssets(),            0);
        assertEq(strategy.deployedAssetsOf(tradingAddress), 0);
        assertEq(strategy.assetsUnderManagement(),          assetsToDeploy);

        vm.expectEmit();
        emit IMapleTradingStrategy.AssetsDeployed(tradingAddress, 1, "a");

        vm.prank(tradingAddress);
        strategy.deployAssets(1, "a");

        assertEq(asset.balanceOf(address(strategy)), assetsToDeploy - 1);
        assertEq(asset.balanceOf(tradingAddress),    1);

        assertEq(strategy.totalDeployedAssets(),            1);
        assertEq(strategy.deployedAssetsOf(tradingAddress), 1);
        assertEq(strategy.assetsUnderManagement(),          assetsToDeploy);
    }

    function test_deployAssets_success_firstDeployment() external {
        assertEq(asset.balanceOf(address(strategy)), assetsToDeploy);
        assertEq(asset.balanceOf(tradingAddress),    0);

        assertEq(strategy.totalDeployedAssets(),            0);
        assertEq(strategy.deployedAssetsOf(tradingAddress), 0);
        assertEq(strategy.assetsUnderManagement(),          assetsToDeploy);

        vm.expectEmit();
        emit IMapleTradingStrategy.AssetsDeployed(tradingAddress, assetsToDeploy, "a");

        vm.prank(tradingAddress);
        strategy.deployAssets(assetsToDeploy, "a");

        assertEq(asset.balanceOf(address(strategy)), 0);
        assertEq(asset.balanceOf(tradingAddress),    assetsToDeploy);

        assertEq(strategy.totalDeployedAssets(),            assetsToDeploy);
        assertEq(strategy.deployedAssetsOf(tradingAddress), assetsToDeploy);
        assertEq(strategy.assetsUnderManagement(),          assetsToDeploy);
    }

    function test_deployAssets_success_exactDeployment() external {
        strategy.__setDeploymentCapOf(tradingAddress, assetsToDeploy);

        assertEq(asset.balanceOf(address(strategy)), assetsToDeploy);
        assertEq(asset.balanceOf(tradingAddress),    0);

        assertEq(strategy.totalDeployedAssets(),            0);
        assertEq(strategy.deployedAssetsOf(tradingAddress), 0);
        assertEq(strategy.assetsUnderManagement(),          assetsToDeploy);

        vm.expectEmit();
        emit IMapleTradingStrategy.AssetsDeployed(tradingAddress, assetsToDeploy, "a");

        vm.prank(tradingAddress);
        strategy.deployAssets(assetsToDeploy, "a");

        assertEq(asset.balanceOf(address(strategy)), 0);
        assertEq(asset.balanceOf(tradingAddress),    assetsToDeploy);

        assertEq(strategy.totalDeployedAssets(),            assetsToDeploy);
        assertEq(strategy.deployedAssetsOf(tradingAddress), assetsToDeploy);
        assertEq(strategy.deploymentCapOf(tradingAddress),  assetsToDeploy);
        assertEq(strategy.assetsUnderManagement(),          assetsToDeploy);
    }

    function test_deployAssets_success_unrealizedAssets() external {
        strategy.__setYieldBuffer(assetsToDeploy, startingTime, startingTime + 3 days);

        vm.warp(startingTime + 2 days);

        uint256 realizedAssets   = assetsToDeploy * 2 / 3;
        uint256 unrealizedAssets = assetsToDeploy - realizedAssets;

        assertEq(asset.balanceOf(address(strategy)), assetsToDeploy);
        assertEq(asset.balanceOf(tradingAddress),    0);

        assertEq(strategy.availableToWithdraw(),            realizedAssets);
        assertEq(strategy.totalDeployedAssets(),            0);
        assertEq(strategy.deployedAssetsOf(tradingAddress), 0);
        assertEq(strategy.assetsUnderManagement(),          realizedAssets);

        vm.expectEmit();
        emit IMapleTradingStrategy.AssetsDeployed(tradingAddress, realizedAssets, "");

        vm.prank(tradingAddress);
        strategy.deployAssets(realizedAssets, "");

        assertEq(asset.balanceOf(address(strategy)), unrealizedAssets);
        assertEq(asset.balanceOf(tradingAddress),    realizedAssets);

        assertEq(strategy.availableToWithdraw(),            0);
        assertEq(strategy.totalDeployedAssets(),            realizedAssets);
        assertEq(strategy.deployedAssetsOf(tradingAddress), realizedAssets);
        assertEq(strategy.assetsUnderManagement(),          realizedAssets);
    }

    function test_deployAssets_success_existingDeployment() external {
        strategy.__setDeployedAssetsOf(tradingAddress, deployedAssets);

        assertEq(asset.balanceOf(address(strategy)), assetsToDeploy);
        assertEq(asset.balanceOf(tradingAddress),    0);

        assertEq(strategy.totalDeployedAssets(),            deployedAssets);
        assertEq(strategy.deployedAssetsOf(tradingAddress), deployedAssets);
        assertEq(strategy.assetsUnderManagement(),          deployedAssets + assetsToDeploy);

        vm.expectEmit();
        emit IMapleTradingStrategy.AssetsDeployed(tradingAddress, assetsToDeploy, "a");

        vm.prank(tradingAddress);
        strategy.deployAssets(assetsToDeploy, "a");

        assertEq(asset.balanceOf(address(strategy)), 0);
        assertEq(asset.balanceOf(tradingAddress),    assetsToDeploy);

        assertEq(strategy.totalDeployedAssets(),            deployedAssets + assetsToDeploy);
        assertEq(strategy.deployedAssetsOf(tradingAddress), deployedAssets + assetsToDeploy);
        assertEq(strategy.assetsUnderManagement(),          deployedAssets + assetsToDeploy);
    }

    function test_deployAssets_success_multipleDeployments() external {

        assertEq(asset.balanceOf(address(strategy)), assetsToDeploy);
        assertEq(asset.balanceOf(tradingAddress),    0);

        assertEq(strategy.totalDeployedAssets(),            0);
        assertEq(strategy.deployedAssetsOf(tradingAddress), 0);
        assertEq(strategy.assetsUnderManagement(),          assetsToDeploy);

        uint256 firstDeploymentAmount  = assetsToDeploy / 4;
        uint256 secondDeploymentAmount = assetsToDeploy / 3;

        /**********************************************************************************************************************************/
        /*** Step 1: First Deployment                                                                                                   ***/
        /**********************************************************************************************************************************/

        vm.expectEmit();
        emit IMapleTradingStrategy.AssetsDeployed(tradingAddress, firstDeploymentAmount, "a");

        vm.prank(tradingAddress);
        strategy.deployAssets(firstDeploymentAmount, "a");

        assertEq(asset.balanceOf(address(strategy)), assetsToDeploy - firstDeploymentAmount);
        assertEq(asset.balanceOf(tradingAddress),    firstDeploymentAmount);

        assertEq(strategy.totalDeployedAssets(),            firstDeploymentAmount);
        assertEq(strategy.deployedAssetsOf(tradingAddress), firstDeploymentAmount);
        assertEq(strategy.assetsUnderManagement(),          assetsToDeploy);

        /**********************************************************************************************************************************/
        /*** Step 2: Second Deployment                                                                                                  ***/
        /**********************************************************************************************************************************/

        vm.expectEmit();
        emit IMapleTradingStrategy.AssetsDeployed(tradingAddress, secondDeploymentAmount, "a");

        vm.prank(tradingAddress);
        strategy.deployAssets(secondDeploymentAmount, "a");

        assertEq(asset.balanceOf(address(strategy)), assetsToDeploy - firstDeploymentAmount - secondDeploymentAmount);
        assertEq(asset.balanceOf(tradingAddress),    firstDeploymentAmount + secondDeploymentAmount);

        assertEq(strategy.totalDeployedAssets(),            firstDeploymentAmount + secondDeploymentAmount);
        assertEq(strategy.deployedAssetsOf(tradingAddress), firstDeploymentAmount + secondDeploymentAmount);
    }

    function test_deployAssets_success_multipleDeployers() external {
        assertEq(asset.balanceOf(address(strategy)), assetsToDeploy);
        assertEq(asset.balanceOf(tradingAddress),    0);
        assertEq(asset.balanceOf(tradingAddress2),   0);

        assertEq(strategy.totalDeployedAssets(),             0);
        assertEq(strategy.deployedAssetsOf(tradingAddress),  0);
        assertEq(strategy.deployedAssetsOf(tradingAddress2), 0);
        assertEq(strategy.assetsUnderManagement(),           assetsToDeploy);

        uint256 firstDeploymentAmount  = assetsToDeploy / 3;
        uint256 secondDeploymentAmount = assetsToDeploy / 7;

        /**********************************************************************************************************************************/
        /*** Step 1: First Deployment                                                                                                   ***/
        /**********************************************************************************************************************************/

        vm.expectEmit();
        emit IMapleTradingStrategy.AssetsDeployed(tradingAddress, firstDeploymentAmount, "a");

        vm.prank(tradingAddress);
        strategy.deployAssets(firstDeploymentAmount, "a");

        assertEq(asset.balanceOf(address(strategy)), assetsToDeploy - firstDeploymentAmount);
        assertEq(asset.balanceOf(tradingAddress),    firstDeploymentAmount);
        assertEq(asset.balanceOf(tradingAddress2),   0);

        assertEq(strategy.totalDeployedAssets(),             firstDeploymentAmount);
        assertEq(strategy.deployedAssetsOf(tradingAddress),  firstDeploymentAmount);
        assertEq(strategy.deployedAssetsOf(tradingAddress2), 0);
        assertEq(strategy.assetsUnderManagement(),           assetsToDeploy);

        /**********************************************************************************************************************************/
        /*** Step 2: Second Deployment                                                                                                  ***/
        /**********************************************************************************************************************************/

        vm.expectEmit();
        emit IMapleTradingStrategy.AssetsDeployed(tradingAddress2, secondDeploymentAmount, "b");

        vm.prank(tradingAddress2);
        strategy.deployAssets(secondDeploymentAmount, "b");

        assertEq(asset.balanceOf(address(strategy)), assetsToDeploy - firstDeploymentAmount - secondDeploymentAmount);
        assertEq(asset.balanceOf(tradingAddress),    firstDeploymentAmount);
        assertEq(asset.balanceOf(tradingAddress2),   secondDeploymentAmount);

        assertEq(strategy.totalDeployedAssets(),             firstDeploymentAmount + secondDeploymentAmount);
        assertEq(strategy.deployedAssetsOf(tradingAddress),  firstDeploymentAmount);
        assertEq(strategy.deployedAssetsOf(tradingAddress2), secondDeploymentAmount);
        assertEq(strategy.assetsUnderManagement(),           assetsToDeploy);
    }

}
