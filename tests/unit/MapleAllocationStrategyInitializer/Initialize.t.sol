// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import { IMapleAllocationStrategyInitializer } from "../../../contracts/interfaces/IMapleAllocationStrategyInitializer.sol";

import { MapleAllocationStrategyInitializerHarness } from "../../utils/Harnesses.sol";
import { TestBase } from "../../utils/TestBase.sol";

contract InitializeTests is TestBase {

    MapleAllocationStrategyInitializerHarness proxy = MapleAllocationStrategyInitializerHarness(initializer);

    function setUp() public override {
        super.setUp();

        manager.__setUnderlyingStrategy(address(proxy));
    }

    function test_initialize_revert_zeroStrategyManager() external {
        vm.expectRevert("MASI:I:ZERO_STRATEGY_MANAGER");
        vm.prank(address(strategyFactory));
        proxy.__initialize(address(0), params);
    }

    function test_initialize_revert_invalidAsset() external {
        params.fundsAsset = makeAddr("invalidAsset");

        vm.expectRevert("MASI:I:INVALID_ASSET");
        vm.prank(address(strategyFactory));
        proxy.__initialize(address(manager), params);
    }

    function test_initialize_revert_invalidFactory() external {
        globals.__setIsInstanceOf("STRATEGY_MANAGER_FACTORY", address(managerFactory), false);

        vm.expectRevert("MASI:I:INVALID_FACTORY");
        vm.prank(address(strategyFactory));
        proxy.__initialize(address(manager), params);
    }

    function test_initialize_revert_invalidInstance() external {
        managerFactory.__setIsInstance(address(manager), false);

        vm.expectRevert("MASI:I:INVALID_INSTANCE");
        vm.prank(address(strategyFactory));
        proxy.__initialize(address(manager), params);
    }

    function test_initialize_revert_invalidUnderlying() external {
        manager.__setUnderlyingStrategy(makeAddr("wrongStrategy"));

        vm.expectRevert("MASI:I:INVALID_UNDERLYING");
        vm.prank(address(strategyFactory));
        proxy.__initialize(address(manager), params);
    }

    function test_initialize_revert_invalidSumFeeRate() external {
        params.strategyDelegateFeeRate = 0.5e6;
        params.strategyProtocolFeeRate = 0.5e6 + 1;

        vm.expectRevert("MASI:I:INVALID_SUM_FEE_RATE");
        vm.prank(address(strategyFactory));
        proxy.__initialize(address(manager), params);
    }

    function test_initialize_success() external {
        vm.expectEmit();
        emit IMapleAllocationStrategyInitializer.Initialized(address(manager), params);

        vm.prank(address(strategyFactory));
        proxy.__initialize(address(manager), params);

        assertEq(proxy.fundsAsset(),              address(asset));
        assertEq(proxy.yieldLastRealized(),       0);
        assertEq(proxy.locked(),                  1);
        assertEq(proxy.strategyDelegateFeeRate(), 0.02e6);
        assertEq(proxy.strategyProtocolFeeRate(), 0.03e6);
        assertEq(proxy.strategyManager(),         address(manager));
        assertEq(proxy.strategyMetadata(),        "MacAttack - 02a");
        assertEq(proxy.yieldCap(),                1_000_000e6);
    }

}
