// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import { IMapleAllocationStrategy } from "../../../contracts/interfaces/IMapleAllocationStrategy.sol";

import { MapleAllocationStrategy } from "../../../contracts/MapleAllocationStrategy.sol";

import { TestBase } from "../../utils/TestBase.sol";

contract SetStrategyDelegateFeeRateFailureTests is TestBase {

    function setUp() public override {
        super.setUp();

        strategy.__setFeeRates(0, 0);
    }

    function test_setStrategyDelegateFeeRate_revert_functionPaused() external {
        uint32 strategyDelegateFeeRate = 0.04e6;  // 4% delegate fee

        globals.__setIsFunctionPaused(MapleAllocationStrategy.setStrategyDelegateFeeRate.selector, true);

        vm.prank(strategyDelegate);
        vm.expectRevert("MAS:PAUSED");
        strategy.setStrategyDelegateFeeRate(strategyDelegateFeeRate);
    }

    function test_setStrategyDelegateFeeRate_revert_reentrancy() external {
        uint32 strategyDelegateFeeRate = 0.04e6;  // 4% delegate fee

        strategy.__setLocked(2);

        vm.prank(strategyDelegate);
        vm.expectRevert("MAS:LOCKED");
        strategy.setStrategyDelegateFeeRate(strategyDelegateFeeRate);
    }

    function test_setStrategyDelegateFeeRate_revert_notStrategyDelegate() external {
        uint32 strategyDelegateFeeRate = 0.04e6;  // 4% delegate fee

        vm.expectRevert("MAS:NOT_STRATEGY_DELEGATE");
        strategy.setStrategyDelegateFeeRate(strategyDelegateFeeRate);
    }

    function test_setStrategyDelegateFeeRate_revert_notStrategyDelegate_governor() external {
        uint32 strategyDelegateFeeRate = 0.04e6;  // 4% delegate fee

        vm.prank(governor);
        vm.expectRevert("MAS:NOT_STRATEGY_DELEGATE");
        strategy.setStrategyDelegateFeeRate(strategyDelegateFeeRate);
    }

    function test_setStrategyDelegateFeeRate_revert_notStrategyDelegate_operationalAdmin() external {
        uint32 strategyDelegateFeeRate = 0.04e6;  // 4% delegate fee

        vm.prank(operationalAdmin);
        vm.expectRevert("MAS:NOT_STRATEGY_DELEGATE");
        strategy.setStrategyDelegateFeeRate(strategyDelegateFeeRate);
    }

    function test_setStrategyDelegateFeeRate_revert_noChange() external {
        uint32 strategyDelegateFeeRate = 0.04e6;  // 4% delegate fee
        uint32 strategyProtocolFeeRate = 0.03e6;  // 3% protocol fee

        strategy.__setFeeRates(strategyDelegateFeeRate, strategyProtocolFeeRate);

        vm.prank(strategyDelegate);
        vm.expectRevert("MAS:SSDFR:NO_CHANGE");
        strategy.setStrategyDelegateFeeRate(strategyDelegateFeeRate);
    }

    function test_setStrategyDelegateFeeRate_revert_invalidFeeRate() external {
        uint32 strategyDelegateFeeRate = 1.5e6;  // 150% delegate fee

        vm.prank(strategyDelegate);
        vm.expectRevert("MAS:SSDFR:INVALID_FEE_RATE");
        strategy.setStrategyDelegateFeeRate(strategyDelegateFeeRate);
    }

    function test_setStrategyDelegateFeeRate_revert_invalidSumFeeRate() external {
        uint32 strategyDelegateFeeRate = 0.97e6 + 1;  // > 97% delegate fee
        uint32 strategyProtocolFeeRate = 0.03e6;      // 3% protocol fee

        strategy.__setFeeRates(0, strategyProtocolFeeRate);

        vm.prank(strategyDelegate);
        vm.expectRevert("MAS:SSDFR:INVALID_SUM_FEE_RATE");
        strategy.setStrategyDelegateFeeRate(strategyDelegateFeeRate);
    }

}

contract SetStrategyDelegateFeeRateSuccessTests is TestBase {

    address managedWallet = makeAddr("managedWallet");

    function setUp() public override {
        super.setUp();

        strategy.__setFeeRates(0, 0);
    }

    function test_setStrategyDelegateFeeRate_success() external {
        uint32 strategyDelegateFeeRate = 0.04e6;  // 4% delegate fee

        assertEq(strategy.strategyDelegateFeeRate(), 0);
        assertEq(strategy.strategyProtocolFeeRate(), 0);

        vm.expectEmit();
        emit IMapleAllocationStrategy.StrategyDelegateFeeRateSet(strategyDelegateFeeRate);

        vm.prank(strategyDelegate);
        strategy.setStrategyDelegateFeeRate(strategyDelegateFeeRate);

        assertEq(strategy.strategyDelegateFeeRate(), strategyDelegateFeeRate);
        assertEq(strategy.strategyProtocolFeeRate(), 0);
    }

    function test_setStrategyDelegateFeeRate_success_maxSumFeeRate() external {
        uint32 strategyDelegateFeeRate = 0.97e6;  // 97% delegate fee
        uint32 strategyProtocolFeeRate = 0.03e6;  // 3% protocol fee

        strategy.__setFeeRates(0, strategyProtocolFeeRate);

        assertEq(strategy.strategyDelegateFeeRate(), 0);
        assertEq(strategy.strategyProtocolFeeRate(), strategyProtocolFeeRate);

        vm.expectEmit();
        emit IMapleAllocationStrategy.StrategyDelegateFeeRateSet(strategyDelegateFeeRate);

        vm.prank(strategyDelegate);
        strategy.setStrategyDelegateFeeRate(strategyDelegateFeeRate);

        assertEq(strategy.strategyDelegateFeeRate(), strategyDelegateFeeRate);
        assertEq(strategy.strategyProtocolFeeRate(), strategyProtocolFeeRate);
    }

    function test_setStrategyDelegateFeeRate_success_maxFeeRate() external {
        uint32 strategyDelegateFeeRate = 1e6;  // 100% delegate fee

        assertEq(strategy.strategyDelegateFeeRate(), 0);
        assertEq(strategy.strategyProtocolFeeRate(), 0);

        vm.expectEmit();
        emit IMapleAllocationStrategy.StrategyDelegateFeeRateSet(strategyDelegateFeeRate);

        vm.prank(strategyDelegate);
        strategy.setStrategyDelegateFeeRate(strategyDelegateFeeRate);

        assertEq(strategy.strategyDelegateFeeRate(), strategyDelegateFeeRate);
        assertEq(strategy.strategyProtocolFeeRate(), 0);
    }

    function test_setStrategyDelegateFeeRate_success_minFeeRate() external {
        uint32 strategyDelegateFeeRate = 1;  // Minimum non-zero delegate fee

        assertEq(strategy.strategyDelegateFeeRate(), 0);
        assertEq(strategy.strategyProtocolFeeRate(), 0);

        vm.expectEmit();
        emit IMapleAllocationStrategy.StrategyDelegateFeeRateSet(strategyDelegateFeeRate);

        vm.prank(strategyDelegate);
        strategy.setStrategyDelegateFeeRate(strategyDelegateFeeRate);

        assertEq(strategy.strategyDelegateFeeRate(), strategyDelegateFeeRate);
        assertEq(strategy.strategyProtocolFeeRate(), 0);
    }

    function test_setStrategyDelegateFeeRate_success_zeroFeeRate() external {
        uint32 strategyDelegateFeeRate = 0.04e6;  // 4% delegate fee
        uint32 strategyProtocolFeeRate = 0.03e6;  // 3% protocol fee

        strategy.__setFeeRates(strategyDelegateFeeRate, strategyProtocolFeeRate);

        assertEq(strategy.strategyDelegateFeeRate(), strategyDelegateFeeRate);
        assertEq(strategy.strategyProtocolFeeRate(), strategyProtocolFeeRate);

        vm.expectEmit();
        emit IMapleAllocationStrategy.StrategyDelegateFeeRateSet(0);

        vm.prank(strategyDelegate);
        strategy.setStrategyDelegateFeeRate(0);

        assertEq(strategy.strategyDelegateFeeRate(), 0);
        assertEq(strategy.strategyProtocolFeeRate(), strategyProtocolFeeRate);
    }

    function test_setStrategyDelegateFeeRate_success_noFeeCollection() external {
        uint32 newStrategyDelegateFeeRate = 0.04e6;  // 4% delegate fee
        uint32 strategyDelegateFeeRate    = 0.02e6;  // 2% delegate fee
        uint32 strategyProtocolFeeRate    = 0.03e6;  // 3% protocol fee

        uint256 strategyBalance      = 30_000e6;
        uint256 scheduledYieldAssets = 20_000e6;
        uint32  yieldStart           = startingTime;
        uint32  yieldDeadline        = startingTime + 3 days;

        asset.mint(address(strategy), strategyBalance);
        strategy.__setRecordedAssets(strategyBalance);

        strategy.__setFeeRates(strategyDelegateFeeRate, strategyProtocolFeeRate);
        strategy.__setYieldBuffer(scheduledYieldAssets, yieldStart, yieldDeadline);

        assertEq(asset.balanceOf(address(strategy)),         strategyBalance);
        assertEq(strategy.recordedAssets(),                  strategyBalance);
        assertEq(asset.balanceOf(address(strategyDelegate)), 0);
        assertEq(asset.balanceOf(address(mapleTreasury)),    0);

        assertEq(strategy.scheduledYieldAssets(), scheduledYieldAssets);
        assertEq(strategy.yieldStart(),           yieldStart);
        assertEq(strategy.yieldDeadline(),        yieldDeadline);

        vm.expectEmit();
        emit IMapleAllocationStrategy.StrategyDelegateFeeRateSet(newStrategyDelegateFeeRate);

        vm.prank(strategyDelegate);
        strategy.setStrategyDelegateFeeRate(newStrategyDelegateFeeRate);

        assertEq(asset.balanceOf(address(strategy)),         strategyBalance);
        assertEq(strategy.recordedAssets(),                  strategyBalance);
        assertEq(asset.balanceOf(address(strategyDelegate)), 0);
        assertEq(asset.balanceOf(address(mapleTreasury)),    0);

        assertEq(strategy.scheduledYieldAssets(), scheduledYieldAssets);
        assertEq(strategy.yieldStart(),           yieldStart);
        assertEq(strategy.yieldDeadline(),        yieldDeadline);

        assertEq(strategy.strategyDelegateFeeRate(), newStrategyDelegateFeeRate);
        assertEq(strategy.strategyProtocolFeeRate(), strategyProtocolFeeRate);
    }

    function test_setStrategyDelegateFeeRate_success_appliesToSubsequentRealizeYield() external {
        uint32 strategyDelegateFeeRate = 0.04e6;  // 4% delegate fee
        uint32 strategyProtocolFeeRate = 0.03e6;  // 3% protocol fee
        uint32 yieldDuration           = 1 days;

        uint256 yieldAmount = 100_000e6;
        uint256 delegateFee = 4_000e6;
        uint256 protocolFee = 3_000e6;
        uint256 netYield    = 93_000e6;

        globals.__setIsInstanceOf("MAPLE_MANAGED_WALLET", managedWallet, true);
        strategy.__setPermissions(managedWallet, true);
        strategy.__setFeeRates(0, strategyProtocolFeeRate);

        asset.mint(managedWallet, yieldAmount);

        vm.prank(managedWallet);
        asset.approve(address(strategy), type(uint256).max);

        vm.prank(strategyDelegate);
        strategy.setStrategyDelegateFeeRate(strategyDelegateFeeRate);

        vm.expectEmit();
        emit IMapleAllocationStrategy.YieldRealized(
            managedWallet,
            0,
            netYield,
            delegateFee,
            protocolFee,
            netYield,
            yieldDuration,
            "SETTER"
        );

        vm.prank(managedWallet);
        strategy.realizeYield(yieldAmount, yieldDuration, "SETTER");

        assertEq(asset.balanceOf(address(strategy)),         netYield);
        assertEq(strategy.recordedAssets(),                  netYield);
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
