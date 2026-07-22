// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import { IMapleProxyFactory }               from "../../../modules/proxy-factory/contracts/interfaces/IMapleProxyFactory.sol";
import { IMapleTradingStrategyInitializer } from "../../../contracts/interfaces/IMapleTradingStrategyInitializer.sol";

import { MapleTradingStrategyHarness } from "../../utils/Harnesses.sol";
import { TestBase }                    from "../../utils/TestBase.sol";

contract CreateInstanceTests is TestBase {

    function setUp() public override {
        super.setUp();

        manager.__setUnderlyingStrategy(strategyFactory.getInstanceAddress(initializationArguments(), ""));
    }

    function test_createInstance_revert_invalidDeployer() external {
        globals.__setCanDeploy(deployer, false);

        vm.prank(deployer);
        vm.expectRevert("MTSF:CI:CANNOT_DEPLOY");
        strategyFactory.createInstance(initializationArguments(), "");
    }

    function test_createInstance_revert_protocolPaused() external {
        globals.__setProtocolPaused(true);

        vm.prank(deployer);
        vm.expectRevert("MPF:PROTOCOL_PAUSED");
        strategyFactory.createInstance(initializationArguments(), "");
    }

    function test_createInstance_revert_createCollision() external {
        bytes memory arguments = initializationArguments();

        vm.prank(deployer);
        strategyFactory.createInstance(arguments, "");

        vm.prank(deployer);
        vm.expectRevert();
        strategyFactory.createInstance(arguments, "");
    }

    function test_createInstance_revert_malformedPayload() external {
        vm.prank(deployer);
        vm.expectRevert("MPF:CI:FAILED");
        strategyFactory.createInstance(new bytes(0), "");

        bytes memory validArguments     = initializationArguments();
        bytes memory truncatedArguments = new bytes(validArguments.length - 1);

        vm.prank(deployer);
        vm.expectRevert("MPF:CI:FAILED");
        strategyFactory.createInstance(truncatedArguments, "");
    }

    function test_createInstance_success() external {
        bytes memory arguments = initializationArguments();

        address proxy = strategyFactory.getInstanceAddress(arguments, "");

        vm.expectEmit();
        emit IMapleTradingStrategyInitializer.Initialized(address(manager), params);

        vm.expectEmit();
        emit IMapleProxyFactory.InstanceDeployed(100, proxy, arguments);

        assertEq(strategyFactory.isInstance(proxy), false);

        vm.prank(deployer);
        strategy = MapleTradingStrategyHarness(strategyFactory.createInstance(arguments, ""));

        assertEq(address(strategy), proxy);

        assertEq(strategyFactory.isInstance(proxy), true);

        assertEq(strategy.factory(),                 address(strategyFactory));
        assertEq(strategy.fundsAsset(),              address(asset));
        assertEq(strategy.locked(),                  1);
        assertEq(strategy.globals(),                 address(globals));
        assertEq(strategy.implementation(),          address(implementation));
        assertEq(strategy.securityAdmin(),           address(securityAdmin));
        assertEq(strategy.strategyDelegateFeeRate(), 0.02e6);
        assertEq(strategy.strategyManager(),         address(manager));
        assertEq(strategy.strategyMetadata(),        "MacAttack - 02a");
        assertEq(strategy.strategyProtocolFeeRate(), 0.03e6);
        assertEq(strategy.yieldCap(),                1_000_000e6);
    }

}
