// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import { IMapleAllocationStrategy } from "../../../contracts/interfaces/IMapleAllocationStrategy.sol";

import { TestBase } from "../../utils/TestBase.sol";

contract DeployAssetsTestBase is TestBase {

    address managedWallet  = makeAddr("managedWallet");
    address managedWallet2 = makeAddr("managedWallet2");

    uint256 assetsToDeploy = 1_250_000e6;
    uint256 deployedAssets = 500_000e6;

    function setUp() public override {
        super.setUp();

        globals.__setIsInstanceOf("MAPLE_MANAGED_WALLET", managedWallet,  true);
        globals.__setIsInstanceOf("MAPLE_MANAGED_WALLET", managedWallet2, true);

        strategy.__setPermissions(managedWallet,  true);
        strategy.__setPermissions(managedWallet2, true);

        strategy.__setDeploymentCapOf(managedWallet,  deployedAssets + assetsToDeploy);
        strategy.__setDeploymentCapOf(managedWallet2, type(uint256).max);

        asset.mint(address(strategy), assetsToDeploy);
        strategy.__setRecordedAssets(assetsToDeploy);
    }

}

contract DeployAssetsFailureTests is DeployAssetsTestBase {

    function test_deployAssets_revert_functionPaused() external {
        globals.__setIsFunctionPaused(IMapleAllocationStrategy.deployAssets.selector, true);

        vm.prank(managedWallet);
        vm.expectRevert("MAS:PAUSED");
        strategy.deployAssets(assetsToDeploy, "");
    }

    function test_deployAssets_revert_reentrancy() external {
        strategy.__setLocked(2);

        vm.prank(managedWallet);
        vm.expectRevert("MAS:LOCKED");
        strategy.deployAssets(assetsToDeploy, "");
    }

    function test_deployAssets_revert_notManagedWallet() external {
        globals.__setIsInstanceOf("MAPLE_MANAGED_WALLET", managedWallet, false);

        vm.prank(managedWallet);
        vm.expectRevert("MAS:NOT_MAPLE_MANAGED_WALLET");
        strategy.deployAssets(assetsToDeploy, "");
    }

    function test_deployAssets_revert_notDeployer() external {
        strategy.__setPermissions(managedWallet, false);

        vm.prank(managedWallet);
        vm.expectRevert("MAS:DA:NOT_ALLOWED");
        strategy.deployAssets(assetsToDeploy, "");
    }

    function test_deployAssets_revert_zeroAssets() external {
        vm.prank(managedWallet);
        vm.expectRevert("MAS:DA:ZERO_ASSETS");
        strategy.deployAssets(0, "");
    }

    function test_deployAssets_revert_insufficientAssets() external {
        strategy.__setRecordedAssets(assetsToDeploy - 1);

        vm.prank(managedWallet);
        vm.expectRevert("MAS:DA:INSUFFICIENT_ASSETS");
        strategy.deployAssets(assetsToDeploy, "");
    }

    function test_deployAssets_revert_unrealizedYield() external {
        strategy.__setYieldBuffer(assetsToDeploy, startingTime, startingTime + 1 days);

        vm.warp(startingTime + 1 days - 1 seconds);
        vm.prank(managedWallet);
        vm.expectRevert("MAS:DA:INSUFFICIENT_ASSETS");
        strategy.deployAssets(assetsToDeploy, "");
    }

    function test_deployAssets_revert_zeroCap() external {
        strategy.__setDeploymentCapOf(managedWallet, 0);

        vm.prank(managedWallet);
        vm.expectRevert("MAS:DA:CAP_EXCEEDED");
        strategy.deployAssets(1, "");
    }

    function test_deployAssets_revert_exceedsCap() external {
        strategy.__setDeploymentCapOf(managedWallet, assetsToDeploy - 1);

        vm.prank(managedWallet);
        vm.expectRevert("MAS:DA:CAP_EXCEEDED");
        strategy.deployAssets(assetsToDeploy, "");
    }

    function test_deployAssets_revert_exceedsCap_withPriorDeployment() external {
        strategy.__setDeployedAssetsOf(managedWallet, deployedAssets + 1);

        vm.prank(managedWallet);
        vm.expectRevert("MAS:DA:CAP_EXCEEDED");
        strategy.deployAssets(assetsToDeploy, "");
    }

    function test_deployAssets_revert_transferFailed() external {
        asset.__setTransferReverts(true);

        vm.prank(managedWallet);
        vm.expectRevert("MAS:DA:TRANSFER_FAILED");
        strategy.deployAssets(assetsToDeploy, "");
    }

}

contract DeployAssetsSuccessTests is DeployAssetsTestBase {

    function test_deployAssets_success_minimumDeployment() external {
        assertEq(asset.balanceOf(address(strategy)), assetsToDeploy);
        assertEq(strategy.recordedAssets(),          assetsToDeploy);
        assertEq(asset.balanceOf(managedWallet),     0);

        assertEq(strategy.totalDeployedAssets(),           0);
        assertEq(strategy.deployedAssetsOf(managedWallet), 0);
        assertEq(strategy.assetsUnderManagement(),         assetsToDeploy);

        vm.expectEmit();
        emit IMapleAllocationStrategy.AssetsDeployed(managedWallet, 1, assetsToDeploy - 1, "a");

        vm.prank(managedWallet);
        strategy.deployAssets(1, "a");

        assertEq(asset.balanceOf(address(strategy)), assetsToDeploy - 1);
        assertEq(strategy.recordedAssets(),          assetsToDeploy - 1);
        assertEq(asset.balanceOf(managedWallet),     1);

        assertEq(strategy.totalDeployedAssets(),           1);
        assertEq(strategy.deployedAssetsOf(managedWallet), 1);
        assertEq(strategy.assetsUnderManagement(),         assetsToDeploy);
    }

    function test_deployAssets_success_firstDeployment() external {
        assertEq(asset.balanceOf(address(strategy)), assetsToDeploy);
        assertEq(strategy.recordedAssets(),          assetsToDeploy);
        assertEq(asset.balanceOf(managedWallet),     0);

        assertEq(strategy.totalDeployedAssets(),           0);
        assertEq(strategy.deployedAssetsOf(managedWallet), 0);
        assertEq(strategy.assetsUnderManagement(),         assetsToDeploy);

        vm.expectEmit();
        emit IMapleAllocationStrategy.AssetsDeployed(managedWallet, assetsToDeploy, 0, "a");

        vm.prank(managedWallet);
        strategy.deployAssets(assetsToDeploy, "a");

        assertEq(asset.balanceOf(address(strategy)), 0);
        assertEq(strategy.recordedAssets(),          0);
        assertEq(asset.balanceOf(managedWallet),     assetsToDeploy);

        assertEq(strategy.totalDeployedAssets(),           assetsToDeploy);
        assertEq(strategy.deployedAssetsOf(managedWallet), assetsToDeploy);
        assertEq(strategy.assetsUnderManagement(),         assetsToDeploy);
    }

    function test_deployAssets_success_exactDeployment() external {
        strategy.__setDeploymentCapOf(managedWallet, assetsToDeploy);

        assertEq(asset.balanceOf(address(strategy)), assetsToDeploy);
        assertEq(strategy.recordedAssets(),          assetsToDeploy);
        assertEq(asset.balanceOf(managedWallet),     0);

        assertEq(strategy.totalDeployedAssets(),           0);
        assertEq(strategy.deployedAssetsOf(managedWallet), 0);
        assertEq(strategy.assetsUnderManagement(),         assetsToDeploy);

        vm.expectEmit();
        emit IMapleAllocationStrategy.AssetsDeployed(managedWallet, assetsToDeploy, 0, "a");

        vm.prank(managedWallet);
        strategy.deployAssets(assetsToDeploy, "a");

        assertEq(asset.balanceOf(address(strategy)), 0);
        assertEq(strategy.recordedAssets(),          0);
        assertEq(asset.balanceOf(managedWallet),     assetsToDeploy);

        assertEq(strategy.totalDeployedAssets(),           assetsToDeploy);
        assertEq(strategy.deployedAssetsOf(managedWallet), assetsToDeploy);
        assertEq(strategy.deploymentCapOf(managedWallet),  assetsToDeploy);
        assertEq(strategy.assetsUnderManagement(),         assetsToDeploy);
    }

    function test_deployAssets_success_unrealizedYield() external {
        strategy.__setYieldBuffer(assetsToDeploy, startingTime, startingTime + 3 days);

        vm.warp(startingTime + 2 days);

        uint256 realizedYield   = assetsToDeploy * 2 / 3;
        uint256 unrealizedYield = assetsToDeploy - realizedYield;

        assertEq(asset.balanceOf(address(strategy)), assetsToDeploy);
        assertEq(strategy.recordedAssets(),          assetsToDeploy);
        assertEq(asset.balanceOf(managedWallet),     0);

        assertEq(strategy.availableToWithdraw(),           realizedYield);
        assertEq(strategy.totalDeployedAssets(),           0);
        assertEq(strategy.deployedAssetsOf(managedWallet), 0);
        assertEq(strategy.assetsUnderManagement(),         realizedYield);

        vm.expectEmit();
        emit IMapleAllocationStrategy.AssetsDeployed(managedWallet, realizedYield, unrealizedYield, "");

        vm.prank(managedWallet);
        strategy.deployAssets(realizedYield, "");

        assertEq(asset.balanceOf(address(strategy)), unrealizedYield);
        assertEq(strategy.recordedAssets(),          unrealizedYield);
        assertEq(asset.balanceOf(managedWallet),     realizedYield);

        assertEq(strategy.availableToWithdraw(),           0);
        assertEq(strategy.totalDeployedAssets(),           realizedYield);
        assertEq(strategy.deployedAssetsOf(managedWallet), realizedYield);
        assertEq(strategy.assetsUnderManagement(),         realizedYield);
    }

    function test_deployAssets_success_existingDeployment() external {
        strategy.__setDeployedAssetsOf(managedWallet, deployedAssets);

        assertEq(asset.balanceOf(address(strategy)), assetsToDeploy);
        assertEq(strategy.recordedAssets(),          assetsToDeploy);
        assertEq(asset.balanceOf(managedWallet),     0);

        assertEq(strategy.totalDeployedAssets(),           deployedAssets);
        assertEq(strategy.deployedAssetsOf(managedWallet), deployedAssets);
        assertEq(strategy.assetsUnderManagement(),         deployedAssets + assetsToDeploy);

        vm.expectEmit();
        emit IMapleAllocationStrategy.AssetsDeployed(managedWallet, assetsToDeploy, 0, "a");

        vm.prank(managedWallet);
        strategy.deployAssets(assetsToDeploy, "a");

        assertEq(asset.balanceOf(address(strategy)), 0);
        assertEq(strategy.recordedAssets(),          0);
        assertEq(asset.balanceOf(managedWallet),     assetsToDeploy);

        assertEq(strategy.totalDeployedAssets(),           deployedAssets + assetsToDeploy);
        assertEq(strategy.deployedAssetsOf(managedWallet), deployedAssets + assetsToDeploy);
        assertEq(strategy.assetsUnderManagement(),         deployedAssets + assetsToDeploy);
    }

    function test_deployAssets_success_multipleDeployments() external {

        assertEq(asset.balanceOf(address(strategy)), assetsToDeploy);
        assertEq(strategy.recordedAssets(),          assetsToDeploy);
        assertEq(asset.balanceOf(managedWallet),     0);

        assertEq(strategy.totalDeployedAssets(),           0);
        assertEq(strategy.deployedAssetsOf(managedWallet), 0);
        assertEq(strategy.assetsUnderManagement(),         assetsToDeploy);

        uint256 firstDeploymentAmount  = assetsToDeploy / 4;
        uint256 secondDeploymentAmount = assetsToDeploy / 3;

        /**********************************************************************************************************************************/
        /*** Step 1: First Deployment                                                                                                   ***/
        /**********************************************************************************************************************************/

        vm.expectEmit();
        emit IMapleAllocationStrategy.AssetsDeployed(managedWallet, firstDeploymentAmount, assetsToDeploy - firstDeploymentAmount, "a");

        vm.prank(managedWallet);
        strategy.deployAssets(firstDeploymentAmount, "a");

        assertEq(asset.balanceOf(address(strategy)), assetsToDeploy - firstDeploymentAmount);
        assertEq(strategy.recordedAssets(),          assetsToDeploy - firstDeploymentAmount);
        assertEq(asset.balanceOf(managedWallet),     firstDeploymentAmount);

        assertEq(strategy.totalDeployedAssets(),           firstDeploymentAmount);
        assertEq(strategy.deployedAssetsOf(managedWallet), firstDeploymentAmount);
        assertEq(strategy.assetsUnderManagement(),         assetsToDeploy);

        /**********************************************************************************************************************************/
        /*** Step 2: Second Deployment                                                                                                  ***/
        /**********************************************************************************************************************************/

        vm.expectEmit();
        emit IMapleAllocationStrategy.AssetsDeployed(
            managedWallet,
            secondDeploymentAmount,
            assetsToDeploy - firstDeploymentAmount - secondDeploymentAmount,
            "a"
        );

        vm.prank(managedWallet);
        strategy.deployAssets(secondDeploymentAmount, "a");

        assertEq(asset.balanceOf(address(strategy)), assetsToDeploy - firstDeploymentAmount - secondDeploymentAmount);
        assertEq(strategy.recordedAssets(),          assetsToDeploy - firstDeploymentAmount - secondDeploymentAmount);
        assertEq(asset.balanceOf(managedWallet),     firstDeploymentAmount + secondDeploymentAmount);

        assertEq(strategy.totalDeployedAssets(),           firstDeploymentAmount + secondDeploymentAmount);
        assertEq(strategy.deployedAssetsOf(managedWallet), firstDeploymentAmount + secondDeploymentAmount);
    }

    function test_deployAssets_success_multipleDeployers() external {
        assertEq(asset.balanceOf(address(strategy)), assetsToDeploy);
        assertEq(strategy.recordedAssets(),          assetsToDeploy);
        assertEq(asset.balanceOf(managedWallet),     0);
        assertEq(asset.balanceOf(managedWallet2),    0);

        assertEq(strategy.totalDeployedAssets(),            0);
        assertEq(strategy.deployedAssetsOf(managedWallet),  0);
        assertEq(strategy.deployedAssetsOf(managedWallet2), 0);
        assertEq(strategy.assetsUnderManagement(),          assetsToDeploy);

        uint256 firstDeploymentAmount  = assetsToDeploy / 3;
        uint256 secondDeploymentAmount = assetsToDeploy / 7;

        /**********************************************************************************************************************************/
        /*** Step 1: First Deployment                                                                                                   ***/
        /**********************************************************************************************************************************/

        vm.expectEmit();
        emit IMapleAllocationStrategy.AssetsDeployed(managedWallet, firstDeploymentAmount, assetsToDeploy - firstDeploymentAmount, "a");

        vm.prank(managedWallet);
        strategy.deployAssets(firstDeploymentAmount, "a");

        assertEq(asset.balanceOf(address(strategy)), assetsToDeploy - firstDeploymentAmount);
        assertEq(strategy.recordedAssets(),          assetsToDeploy - firstDeploymentAmount);
        assertEq(asset.balanceOf(managedWallet),     firstDeploymentAmount);
        assertEq(asset.balanceOf(managedWallet2),    0);

        assertEq(strategy.totalDeployedAssets(),            firstDeploymentAmount);
        assertEq(strategy.deployedAssetsOf(managedWallet),  firstDeploymentAmount);
        assertEq(strategy.deployedAssetsOf(managedWallet2), 0);
        assertEq(strategy.assetsUnderManagement(),          assetsToDeploy);

        /**********************************************************************************************************************************/
        /*** Step 2: Second Deployment                                                                                                  ***/
        /**********************************************************************************************************************************/

        vm.expectEmit();
        emit IMapleAllocationStrategy.AssetsDeployed(
            managedWallet2,
            secondDeploymentAmount,
            assetsToDeploy - firstDeploymentAmount - secondDeploymentAmount,
            "b"
        );

        vm.prank(managedWallet2);
        strategy.deployAssets(secondDeploymentAmount, "b");

        assertEq(asset.balanceOf(address(strategy)), assetsToDeploy - firstDeploymentAmount - secondDeploymentAmount);
        assertEq(strategy.recordedAssets(),          assetsToDeploy - firstDeploymentAmount - secondDeploymentAmount);
        assertEq(asset.balanceOf(managedWallet),     firstDeploymentAmount);
        assertEq(asset.balanceOf(managedWallet2),    secondDeploymentAmount);

        assertEq(strategy.totalDeployedAssets(),            firstDeploymentAmount + secondDeploymentAmount);
        assertEq(strategy.deployedAssetsOf(managedWallet),  firstDeploymentAmount);
        assertEq(strategy.deployedAssetsOf(managedWallet2), secondDeploymentAmount);
        assertEq(strategy.assetsUnderManagement(),          assetsToDeploy);
    }

    // NOTE: Assets sent back outside of returnAssets() are not recorded, and therefore cannot be deployed again.
    function test_deployAssets_cannotRedeployUnrecordedAssets() external {
        vm.prank(managedWallet);
        strategy.deployAssets(assetsToDeploy, "");

        /**********************************************************************************************************************************/
        /*** Step: Managed Wallet Returns The Assets With A Plain Transfer                                                              ***/
        /**********************************************************************************************************************************/

        vm.prank(managedWallet);
        asset.transfer(address(strategy), assetsToDeploy);

        assertEq(asset.balanceOf(address(strategy)), assetsToDeploy);

        assertEq(strategy.recordedAssets(),                0);
        assertEq(strategy.unrecordedAssets(),              assetsToDeploy);
        assertEq(strategy.availableToWithdraw(),           0);
        assertEq(strategy.totalDeployedAssets(),           assetsToDeploy);
        assertEq(strategy.deployedAssetsOf(managedWallet), assetsToDeploy);
        assertEq(strategy.assetsUnderManagement(),         assetsToDeploy);

        /**********************************************************************************************************************************/
        /*** Step: The Same Assets Cannot Be Deployed A Second Time                                                                     ***/
        /**********************************************************************************************************************************/

        vm.prank(managedWallet);
        vm.expectRevert("MAS:DA:INSUFFICIENT_ASSETS");
        strategy.deployAssets(1, "");
    }

    // NOTE: Deployments draw only from recorded assets, even while unrecorded assets sit in the strategy.
    function test_deployAssets_onlyConsumesRecordedAssets() external {
        uint256 partialDeployment = assetsToDeploy / 2;
        uint256 unrecordedAssets  = deployedAssets;

        // Assets transferred to the strategy outside of a recorded flow.
        asset.mint(address(strategy), unrecordedAssets);

        assertEq(asset.balanceOf(address(strategy)), assetsToDeploy + unrecordedAssets);

        assertEq(strategy.recordedAssets(),        assetsToDeploy);
        assertEq(strategy.unrecordedAssets(),      unrecordedAssets);
        assertEq(strategy.availableToWithdraw(),   assetsToDeploy);
        assertEq(strategy.assetsUnderManagement(), assetsToDeploy);

        /**********************************************************************************************************************************/
        /*** Step: A Partial Deployment Leaves The Unrecorded Assets Untouched                                                          ***/
        /**********************************************************************************************************************************/

        vm.prank(managedWallet);
        strategy.deployAssets(partialDeployment, "");

        assertEq(asset.balanceOf(address(strategy)), assetsToDeploy + unrecordedAssets - partialDeployment);

        assertEq(strategy.recordedAssets(),        assetsToDeploy - partialDeployment);
        assertEq(strategy.unrecordedAssets(),      unrecordedAssets);
        assertEq(strategy.availableToWithdraw(),   assetsToDeploy - partialDeployment);
        assertEq(strategy.assetsUnderManagement(), assetsToDeploy);

        /**********************************************************************************************************************************/
        /*** Step: Deploying The Remaining Recorded Assets Exhausts The Availability                                                    ***/
        /**********************************************************************************************************************************/

        vm.prank(managedWallet);
        strategy.deployAssets(assetsToDeploy - partialDeployment, "");

        assertEq(asset.balanceOf(address(strategy)), unrecordedAssets);

        assertEq(strategy.recordedAssets(),        0);
        assertEq(strategy.unrecordedAssets(),      unrecordedAssets);
        assertEq(strategy.availableToWithdraw(),   0);
        assertEq(strategy.assetsUnderManagement(), assetsToDeploy);

        /**********************************************************************************************************************************/
        /*** Step: The Unrecorded Assets Cannot Be Deployed                                                                             ***/
        /**********************************************************************************************************************************/

        vm.prank(managedWallet);
        vm.expectRevert("MAS:DA:INSUFFICIENT_ASSETS");
        strategy.deployAssets(1, "");
    }

}
