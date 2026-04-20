// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import { Test } from "../../modules/forge-std/src/Test.sol";

import { IMapleTradingStrategyInitializer } from "../../contracts/interfaces/IMapleTradingStrategyInitializer.sol";

import { MapleTradingStrategyFactory } from "../../contracts/MapleTradingStrategyFactory.sol";

import {
    MapleTradingStrategyHarness,
    MapleTradingStrategyInitializerHarness
} from "./Harnesses.sol";

import {
    MockAsset,
    MockFactory,
    MockGlobals,
    MockManager
} from "./Mocks.sol";

contract TestBase is Test {

    address deployer      = makeAddr("deployer");
    address governor      = makeAddr("governor");
    address securityAdmin = makeAddr("securityAdmin");

    address implementation = address(new MapleTradingStrategyHarness());
    address initializer    = address(new MapleTradingStrategyInitializerHarness());

    uint32 startingTime;

    IMapleTradingStrategyInitializer.Parameters params;

    MockAsset   asset   = new MockAsset();
    MockGlobals globals = new MockGlobals();
    MockManager manager = new MockManager();

    MapleTradingStrategyFactory factory;
    MapleTradingStrategyHarness strategy;

    function setUp() public virtual {
        startingTime = uint32(block.timestamp);

        globals.__setCanDeploy(deployer, true);
        globals.__setGovernor(governor);
        globals.__setSecurityAdmin(securityAdmin);

        factory = new MapleTradingStrategyFactory(address(globals));

        vm.startPrank(governor);
        factory.registerImplementation(100, implementation, initializer);
        factory.setDefaultVersion(100);
        vm.stopPrank();

        params = IMapleTradingStrategyInitializer.Parameters({
            manager: address(manager)
        });

        vm.prank(deployer);
        strategy = MapleTradingStrategyHarness(factory.createInstance(abi.encode(params), "DEFAULT"));
    }

}
