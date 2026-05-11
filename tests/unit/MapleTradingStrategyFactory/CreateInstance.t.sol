// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import { IMapleProxyFactory }               from "../../../modules/proxy-factory/contracts/interfaces/IMapleProxyFactory.sol";
import { IMapleTradingStrategyInitializer } from "../../../contracts/interfaces/IMapleTradingStrategyInitializer.sol";

import { MapleTradingStrategyHarness } from "../../utils/Harnesses.sol";
import { TestBase }                    from "../../utils/TestBase.sol";

contract CreateInstanceTests is TestBase {

    function test_createInstance_revert_invalidDeployer() external {
        globals.__setCanDeploy(deployer, false);

        vm.prank(deployer);
        vm.expectRevert("MTSF:CI:CANNOT_DEPLOY");
        factory.createInstance(abi.encode(params), "");
    }

    function test_createInstance_revert_protocolPaused() external {
        globals.__setProtocolPaused(true);

        vm.prank(deployer);
        vm.expectRevert("MPF:PROTOCOL_PAUSED");
        factory.createInstance(abi.encode(params), "");
    }

    function test_createInstance_revert_createCollision() external {
        bytes memory arguments = abi.encode(params);

        vm.prank(deployer);
        factory.createInstance(arguments, "");

        vm.prank(deployer);
        vm.expectRevert();
        factory.createInstance(arguments, "");
    }

    function test_createInstance_success() external {
        bytes memory arguments = abi.encode(params);

        address proxy = factory.getInstanceAddress(arguments, "");

        vm.expectEmit();
        emit IMapleTradingStrategyInitializer.Initialized(params);

        vm.expectEmit();
        emit IMapleProxyFactory.InstanceDeployed(100, proxy, arguments);

        assertEq(factory.isInstance(proxy), false);

        vm.prank(deployer);
        strategy = MapleTradingStrategyHarness(factory.createInstance(arguments, ""));

        assertEq(address(strategy), proxy);

        assertEq(factory.isInstance(proxy), true);

        assertEq(strategy.factory(),        address(factory));
        assertEq(strategy.globals(),        address(globals));
        assertEq(strategy.implementation(), address(implementation));
        assertEq(strategy.manager(),        address(manager));
        assertEq(strategy.securityAdmin(),  address(securityAdmin));
    }

}
