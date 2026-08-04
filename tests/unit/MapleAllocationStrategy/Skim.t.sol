// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import { IMapleAllocationStrategy } from "../../../contracts/interfaces/IMapleAllocationStrategy.sol";

import { TestBase } from "../../utils/TestBase.sol";

contract SkimTestBase is TestBase {

    address recipient = makeAddr("recipient");

    uint256 recordedAssets   = 100_000e6;
    uint256 unrecordedAssets = 7_500e6;

    function setUp() public override {
        super.setUp();

        asset.mint(address(strategy), recordedAssets);
        strategy.__setRecordedAssets(recordedAssets);

        // Assets transferred to the strategy outside of a recorded flow.
        asset.mint(address(strategy), unrecordedAssets);
    }

}

contract SkimFailureTests is SkimTestBase {

    function test_skim_revert_functionPaused() external {
        globals.__setIsFunctionPaused(IMapleAllocationStrategy.skim.selector, true);

        vm.prank(strategyDelegate);
        vm.expectRevert("MAS:PAUSED");
        strategy.skim(recipient);
    }

    function test_skim_revert_reentrancy() external {
        strategy.__setLocked(2);

        vm.prank(strategyDelegate);
        vm.expectRevert("MAS:LOCKED");
        strategy.skim(recipient);
    }

    function test_skim_revert_notAuthorized() external {
        vm.prank(makeAddr("notAuthorized"));
        vm.expectRevert("MAS:NOT_AUTHORIZED");
        strategy.skim(recipient);
    }

    function test_skim_revert_zeroRecipient() external {
        vm.prank(strategyDelegate);
        vm.expectRevert("MAS:S:ZERO_RECIPIENT");
        strategy.skim(address(0));
    }

    function test_skim_revert_zeroAssets() external {
        asset.burn(address(strategy), unrecordedAssets);

        vm.prank(strategyDelegate);
        vm.expectRevert("MAS:S:ZERO_ASSETS");
        strategy.skim(recipient);
    }

    function test_skim_revert_zeroAssets_balanceShortfall() external {
        asset.burn(address(strategy), recordedAssets + unrecordedAssets);

        vm.prank(strategyDelegate);
        vm.expectRevert("MAS:S:ZERO_ASSETS");
        strategy.skim(recipient);
    }

    function test_skim_revert_transferFailed() external {
        asset.__setTransferReverts(true);

        vm.prank(strategyDelegate);
        vm.expectRevert("MAS:S:TRANSFER_FAILED");
        strategy.skim(recipient);
    }

}

contract SkimSuccessTests is SkimTestBase {

    function test_skim_success_strategyDelegate() external {
        assertEq(asset.balanceOf(address(strategy)), recordedAssets + unrecordedAssets);
        assertEq(asset.balanceOf(recipient),         0);

        assertEq(strategy.recordedAssets(),        recordedAssets);
        assertEq(strategy.unrecordedAssets(),      unrecordedAssets);
        assertEq(strategy.availableToWithdraw(),   recordedAssets);
        assertEq(strategy.assetsUnderManagement(), recordedAssets);

        vm.expectEmit();
        emit IMapleAllocationStrategy.AssetsSkimmed(recipient, unrecordedAssets);

        vm.prank(strategyDelegate);
        strategy.skim(recipient);

        assertEq(asset.balanceOf(address(strategy)), recordedAssets);
        assertEq(asset.balanceOf(recipient),         unrecordedAssets);

        assertEq(strategy.recordedAssets(),        recordedAssets);
        assertEq(strategy.unrecordedAssets(),      0);
        assertEq(strategy.availableToWithdraw(),   recordedAssets);
        assertEq(strategy.assetsUnderManagement(), recordedAssets);
    }

    function test_skim_success_operationalAdmin() external {
        assertEq(asset.balanceOf(address(strategy)), recordedAssets + unrecordedAssets);
        assertEq(asset.balanceOf(recipient),         0);

        assertEq(strategy.recordedAssets(),        recordedAssets);
        assertEq(strategy.unrecordedAssets(),      unrecordedAssets);
        assertEq(strategy.availableToWithdraw(),   recordedAssets);
        assertEq(strategy.assetsUnderManagement(), recordedAssets);

        vm.expectEmit();
        emit IMapleAllocationStrategy.AssetsSkimmed(recipient, unrecordedAssets);

        vm.prank(operationalAdmin);
        strategy.skim(recipient);

        assertEq(asset.balanceOf(address(strategy)), recordedAssets);
        assertEq(asset.balanceOf(recipient),         unrecordedAssets);

        assertEq(strategy.recordedAssets(),        recordedAssets);
        assertEq(strategy.unrecordedAssets(),      0);
        assertEq(strategy.availableToWithdraw(),   recordedAssets);
        assertEq(strategy.assetsUnderManagement(), recordedAssets);
    }

    function test_skim_success_unvestedYieldNotSkimmable() external {
        strategy.__setYieldBuffer(recordedAssets, startingTime, startingTime + 1 days);

        assertEq(strategy.recordedAssets(),      recordedAssets);
        assertEq(strategy.unrealizedYield(),     recordedAssets);
        assertEq(strategy.availableToWithdraw(), 0);
        assertEq(strategy.unrecordedAssets(),    unrecordedAssets);

        vm.prank(strategyDelegate);
        strategy.skim(recipient);

        assertEq(asset.balanceOf(address(strategy)), recordedAssets);
        assertEq(asset.balanceOf(recipient),         unrecordedAssets);

        assertEq(strategy.recordedAssets(),      recordedAssets);
        assertEq(strategy.unrealizedYield(),     recordedAssets);
        assertEq(strategy.availableToWithdraw(), 0);
        assertEq(strategy.unrecordedAssets(),    0);
    }

    // NOTE: Demonstrates if we accidentally transfer assets to the contract we can still recover and call returnAssets.
    function test_skim_success_returnedAssetsReconciliation() external {
        address managedWallet = makeAddr("managedWallet");

        globals.__setIsInstanceOf("MAPLE_MANAGED_WALLET", managedWallet, true);

        strategy.__setPermissions(managedWallet, true);
        strategy.__setDeployedAssetsOf(managedWallet, unrecordedAssets);

        /**********************************************************************************************************************************/
        /*** Step: Skim The Assets Returned With A Plain Transfer Back To A Managed Wallet                                              ***/
        /**********************************************************************************************************************************/

        vm.prank(strategyDelegate);
        strategy.skim(managedWallet);

        assertEq(asset.balanceOf(managedWallet), unrecordedAssets);

        assertEq(strategy.deployedAssetsOf(managedWallet), unrecordedAssets);
        assertEq(strategy.assetsUnderManagement(),         recordedAssets + unrecordedAssets);

        /**********************************************************************************************************************************/
        /*** Step: Managed Wallet Returns Them Through The Return Assets                                                                ***/
        /**********************************************************************************************************************************/

        vm.prank(managedWallet);
        asset.approve(address(strategy), unrecordedAssets);

        vm.prank(managedWallet);
        strategy.returnAssets(unrecordedAssets, managedWallet, "");

        assertEq(asset.balanceOf(address(strategy)), recordedAssets + unrecordedAssets);
        assertEq(asset.balanceOf(managedWallet),     0);

        assertEq(strategy.recordedAssets(),                recordedAssets + unrecordedAssets);
        assertEq(strategy.unrecordedAssets(),              0);
        assertEq(strategy.deployedAssetsOf(managedWallet), 0);
        assertEq(strategy.assetsUnderManagement(),         recordedAssets + unrecordedAssets);
    }

}
