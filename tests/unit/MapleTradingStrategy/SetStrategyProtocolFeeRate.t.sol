// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import { IMapleTradingStrategy } from "../../../contracts/interfaces/IMapleTradingStrategy.sol";

import { MapleTradingStrategy } from "../../../contracts/MapleTradingStrategy.sol";

import { TestBase } from "../../utils/TestBase.sol";

contract SetStrategyProtocolFeeRateFailureTests is TestBase {

    function setUp() public override {
        super.setUp();

        strategy.__setFeeRates(0, 0);
    }

    function test_setStrategyProtocolFeeRate_revert_functionPaused() external {
        uint32 strategyProtocolFeeRate = 0.04e6;  // 4% protocol fee

        globals.__setIsFunctionPaused(MapleTradingStrategy.setStrategyProtocolFeeRate.selector, true);

        vm.prank(governor);
        vm.expectRevert("MTS:PAUSED");
        strategy.setStrategyProtocolFeeRate(strategyProtocolFeeRate);
    }

    function test_setStrategyProtocolFeeRate_revert_reentrancy() external {
        uint32 strategyProtocolFeeRate = 0.04e6;  // 4% protocol fee

        strategy.__setLocked(2);

        vm.prank(governor);
        vm.expectRevert("MTS:LOCKED");
        strategy.setStrategyProtocolFeeRate(strategyProtocolFeeRate);
    }

    function test_setStrategyProtocolFeeRate_revert_notAdmin() external {
        uint32 strategyProtocolFeeRate = 0.04e6;  // 4% protocol fee

        vm.expectRevert("MTS:NOT_ADMIN");
        strategy.setStrategyProtocolFeeRate(strategyProtocolFeeRate);
    }

    function test_setStrategyProtocolFeeRate_revert_notAdmin_strategyDelegate() external {
        uint32 strategyProtocolFeeRate = 0.04e6;  // 4% protocol fee

        vm.prank(strategyDelegate);
        vm.expectRevert("MTS:NOT_ADMIN");
        strategy.setStrategyProtocolFeeRate(strategyProtocolFeeRate);
    }

    function test_setStrategyProtocolFeeRate_revert_noChange() external {
        uint32 strategyDelegateFeeRate = 0.02e6;  // 2% delegate fee
        uint32 strategyProtocolFeeRate = 0.05e6;  // 5% protocol fee

        strategy.__setFeeRates(strategyDelegateFeeRate, strategyProtocolFeeRate);

        vm.prank(governor);
        vm.expectRevert("MTS:SSPFR:NO_CHANGE");
        strategy.setStrategyProtocolFeeRate(strategyProtocolFeeRate);
    }

    function test_setStrategyProtocolFeeRate_revert_invalidFeeRate() external {
        uint32 strategyProtocolFeeRate = 1.5e6;  // 150% protocol fee

        vm.prank(governor);
        vm.expectRevert("MTS:SSPFR:INVALID_FEE_RATE");
        strategy.setStrategyProtocolFeeRate(strategyProtocolFeeRate);
    }

    function test_setStrategyProtocolFeeRate_revert_invalidSumFeeRate() external {
        uint32 strategyDelegateFeeRate = 0.03e6;      // 3% delegate fee
        uint32 strategyProtocolFeeRate = 0.97e6 + 1;  // > 97% protocol fee

        strategy.__setFeeRates(strategyDelegateFeeRate, 0);

        vm.prank(governor);
        vm.expectRevert("MTS:SSPFR:INVALID_SUM_FEE_RATE");
        strategy.setStrategyProtocolFeeRate(strategyProtocolFeeRate);
    }

}

contract SetStrategyProtocolFeeRateSuccessTests is TestBase {

    address managedWallet = makeAddr("managedWallet");

    function setUp() public override {
        super.setUp();

        globals.__setOperationalAdmin(operationalAdmin);

        strategy.__setFeeRates(0, 0);
    }

    function test_setStrategyProtocolFeeRate_success_governor() external {
        uint32 strategyProtocolFeeRate = 0.04e6;  // 4% protocol fee

        assertEq(strategy.strategyDelegateFeeRate(), 0);
        assertEq(strategy.strategyProtocolFeeRate(), 0);

        vm.expectEmit();
        emit IMapleTradingStrategy.StrategyProtocolFeeRateSet(strategyProtocolFeeRate);

        vm.prank(governor);
        strategy.setStrategyProtocolFeeRate(strategyProtocolFeeRate);

        assertEq(strategy.strategyDelegateFeeRate(), 0);
        assertEq(strategy.strategyProtocolFeeRate(), strategyProtocolFeeRate);
    }

    function test_setStrategyProtocolFeeRate_success_operationalAdmin() external {
        uint32 strategyProtocolFeeRate = 0.05e6;  // 5% protocol fee

        assertEq(strategy.strategyDelegateFeeRate(), 0);
        assertEq(strategy.strategyProtocolFeeRate(), 0);

        vm.expectEmit();
        emit IMapleTradingStrategy.StrategyProtocolFeeRateSet(strategyProtocolFeeRate);

        vm.prank(operationalAdmin);
        strategy.setStrategyProtocolFeeRate(strategyProtocolFeeRate);

        assertEq(strategy.strategyDelegateFeeRate(), 0);
        assertEq(strategy.strategyProtocolFeeRate(), strategyProtocolFeeRate);
    }

    function test_setStrategyProtocolFeeRate_success_maxSumFeeRate() external {
        uint32 strategyDelegateFeeRate = 0.02e6;  // 2% delegate fee
        uint32 strategyProtocolFeeRate = 0.98e6;  // 98% protocol fee

        strategy.__setFeeRates(strategyDelegateFeeRate, 0);

        assertEq(strategy.strategyDelegateFeeRate(), strategyDelegateFeeRate);
        assertEq(strategy.strategyProtocolFeeRate(), 0);

        vm.expectEmit();
        emit IMapleTradingStrategy.StrategyProtocolFeeRateSet(strategyProtocolFeeRate);

        vm.prank(governor);
        strategy.setStrategyProtocolFeeRate(strategyProtocolFeeRate);

        assertEq(strategy.strategyDelegateFeeRate(), strategyDelegateFeeRate);
        assertEq(strategy.strategyProtocolFeeRate(), strategyProtocolFeeRate);
    }

    function test_setStrategyProtocolFeeRate_success_maxFeeRate() external {
        uint32 strategyProtocolFeeRate = 1e6;  // 100% protocol fee

        assertEq(strategy.strategyDelegateFeeRate(), 0);
        assertEq(strategy.strategyProtocolFeeRate(), 0);

        vm.expectEmit();
        emit IMapleTradingStrategy.StrategyProtocolFeeRateSet(strategyProtocolFeeRate);

        vm.prank(governor);
        strategy.setStrategyProtocolFeeRate(strategyProtocolFeeRate);

        assertEq(strategy.strategyDelegateFeeRate(), 0);
        assertEq(strategy.strategyProtocolFeeRate(), strategyProtocolFeeRate);
    }

    function test_setStrategyProtocolFeeRate_success_minFeeRate() external {
        uint32 strategyProtocolFeeRate = 1;  // Minimum non-zero protocol fee

        assertEq(strategy.strategyDelegateFeeRate(), 0);
        assertEq(strategy.strategyProtocolFeeRate(), 0);

        vm.expectEmit();
        emit IMapleTradingStrategy.StrategyProtocolFeeRateSet(strategyProtocolFeeRate);

        vm.prank(governor);
        strategy.setStrategyProtocolFeeRate(strategyProtocolFeeRate);

        assertEq(strategy.strategyDelegateFeeRate(), 0);
        assertEq(strategy.strategyProtocolFeeRate(), strategyProtocolFeeRate);
    }

    function test_setStrategyProtocolFeeRate_success_zeroFeeRate() external {
        uint32 strategyDelegateFeeRate = 0.02e6;  // 2% delegate fee
        uint32 strategyProtocolFeeRate = 0.05e6;  // 5% protocol fee

        strategy.__setFeeRates(strategyDelegateFeeRate, strategyProtocolFeeRate);

        assertEq(strategy.strategyDelegateFeeRate(), strategyDelegateFeeRate);
        assertEq(strategy.strategyProtocolFeeRate(), strategyProtocolFeeRate);

        vm.expectEmit();
        emit IMapleTradingStrategy.StrategyProtocolFeeRateSet(0);

        vm.prank(governor);
        strategy.setStrategyProtocolFeeRate(0);

        assertEq(strategy.strategyDelegateFeeRate(), strategyDelegateFeeRate);
        assertEq(strategy.strategyProtocolFeeRate(), 0);
    }

    function test_setStrategyProtocolFeeRate_success_noFeeCollection() external {
        uint32 strategyDelegateFeeRate    = 0.02e6;  // 2% delegate fee
        uint32 newStrategyProtocolFeeRate = 0.05e6;  // 5% protocol fee
        uint32 strategyProtocolFeeRate    = 0.03e6;  // 3% protocol fee

        uint256 strategyBalance      = 30_000e6;
        uint256 scheduledYieldAssets = 20_000e6;
        uint32  yieldStart           = startingTime;
        uint32  yieldDeadline        = startingTime + 3 days;

        asset.mint(address(strategy), strategyBalance);

        strategy.__setFeeRates(strategyDelegateFeeRate, strategyProtocolFeeRate);
        strategy.__setYieldBuffer(scheduledYieldAssets, yieldStart, yieldDeadline);

        assertEq(asset.balanceOf(address(strategy)),         strategyBalance);
        assertEq(asset.balanceOf(address(strategyDelegate)), 0);
        assertEq(asset.balanceOf(address(mapleTreasury)),    0);

        assertEq(strategy.scheduledYieldAssets(), scheduledYieldAssets);
        assertEq(strategy.yieldStart(),           yieldStart);
        assertEq(strategy.yieldDeadline(),        yieldDeadline);

        vm.expectEmit();
        emit IMapleTradingStrategy.StrategyProtocolFeeRateSet(newStrategyProtocolFeeRate);

        vm.prank(governor);
        strategy.setStrategyProtocolFeeRate(newStrategyProtocolFeeRate);

        assertEq(asset.balanceOf(address(strategy)),         strategyBalance);
        assertEq(asset.balanceOf(address(strategyDelegate)), 0);
        assertEq(asset.balanceOf(address(mapleTreasury)),    0);

        assertEq(strategy.scheduledYieldAssets(), scheduledYieldAssets);
        assertEq(strategy.yieldStart(),           yieldStart);
        assertEq(strategy.yieldDeadline(),        yieldDeadline);

        assertEq(strategy.strategyDelegateFeeRate(), strategyDelegateFeeRate);
        assertEq(strategy.strategyProtocolFeeRate(), newStrategyProtocolFeeRate);
    }

    function test_setStrategyProtocolFeeRate_success_appliesToSubsequentRealizeYield() external {
        uint32 strategyDelegateFeeRate = 0.02e6;  // 2% delegate fee
        uint32 strategyProtocolFeeRate = 0.05e6;  // 5% protocol fee
        uint32 yieldDuration           = 1 days;

        uint256 yieldAmount = 100_000e6;
        uint256 delegateFee = 2_000e6;
        uint256 protocolFee = 5_000e6;
        uint256 netYield    = 93_000e6;

        globals.__setIsInstanceOf("MAPLE_MANAGED_WALLET", managedWallet, true);
        strategy.__setPermissions(managedWallet, true);
        strategy.__setFeeRates(strategyDelegateFeeRate, 0);

        asset.mint(managedWallet, yieldAmount);

        vm.prank(managedWallet);
        asset.approve(address(strategy), type(uint256).max);

        vm.prank(governor);
        strategy.setStrategyProtocolFeeRate(strategyProtocolFeeRate);

        vm.expectEmit();
        emit IMapleTradingStrategy.YieldRealized(managedWallet, 0, netYield, delegateFee, protocolFee, yieldDuration, "SETTER");

        vm.prank(managedWallet);
        strategy.realizeYield(yieldAmount, yieldDuration, "SETTER");

        assertEq(asset.balanceOf(address(strategy)),         netYield);
        assertEq(asset.balanceOf(address(managedWallet)),    0);
        assertEq(asset.balanceOf(address(strategyDelegate)), delegateFee);
        assertEq(asset.balanceOf(address(mapleTreasury)),    protocolFee);

        assertEq(strategy.scheduledYieldAssets(), netYield);
        assertEq(strategy.yieldStart(),           startingTime);
        assertEq(strategy.yieldDeadline(),        startingTime + yieldDuration);

        assertEq(strategy.strategyDelegateFeeRate(), strategyDelegateFeeRate);
        assertEq(strategy.strategyProtocolFeeRate(), strategyProtocolFeeRate);
    }

}
