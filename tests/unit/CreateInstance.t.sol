// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import { IMapleTradingStrategyInitializer } from "../../contracts/interfaces/IMapleTradingStrategyInitializer.sol";

import { MapleTradingStrategyHarness } from "../utils/Harnesses.sol";
import { TestBase }                    from "../utils/TestBase.sol";

contract CreateInstanceTests is TestBase {

    function test_createInstance_invalidDeployer() external {
        globals.__setCanDeploy(deployer, false);

        vm.prank(deployer);
        vm.expectRevert("MTSF:CI:CANNOT_DEPLOY");
        factory.createInstance(abi.encode(params), "");
    }

    function test_createInstance_protocolPaused() external {
        globals.__setProtocolPaused(true);

        vm.prank(deployer);
        vm.expectRevert("MPF:PROTOCOL_PAUSED");
        factory.createInstance(abi.encode(params), "");
    }

    function test_createInstance_success() external {
        vm.expectEmit();
        emit IMapleTradingStrategyInitializer.Initialized(params);

        vm.prank(deployer);
        strategy = MapleTradingStrategyHarness(factory.createInstance(abi.encode(params), ""));

        assertEq(strategy.manager(), address(manager));
    }

}
