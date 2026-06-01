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
    MockStrategyManager
} from "./Mocks.sol";

contract TestBase is Test {

    address deployer         = makeAddr("deployer");
    address governor         = makeAddr("governor");
    address securityAdmin    = makeAddr("securityAdmin");
    address strategyDelegate = makeAddr("strategyDelegate");

    address implementation = address(new MapleTradingStrategyHarness());
    address initializer    = address(new MapleTradingStrategyInitializerHarness());

    uint32 startingTime;

    IMapleTradingStrategyInitializer.Parameters params;

    MockAsset           asset          = new MockAsset();
    MockFactory         managerFactory = new MockFactory();
    MockGlobals         globals        = new MockGlobals();
    MockStrategyManager manager        = new MockStrategyManager();

    MapleTradingStrategyFactory strategyFactory;
    MapleTradingStrategyHarness strategy;

    function setUp() public virtual {
        startingTime = uint32(block.timestamp);

        globals.__setCanDeploy(deployer, true);
        globals.__setGovernor(governor);
        globals.__setSecurityAdmin(securityAdmin);
        globals.__setIsPoolAsset(address(asset), true);
        globals.__setIsInstanceOf("STRATEGY_MANAGER_FACTORY", address(managerFactory), true);

        manager.__setFactory(address(managerFactory));
        manager.__setStrategyDelegate(strategyDelegate);
        managerFactory.__setIsInstance(address(manager), true);

        strategyFactory = new MapleTradingStrategyFactory(address(globals));

        vm.startPrank(governor);
        strategyFactory.registerImplementation(100, implementation, initializer);
        strategyFactory.setDefaultVersion(100);
        vm.stopPrank();

        params = IMapleTradingStrategyInitializer.Parameters({
            fundsAsset:              address(asset),
            strategyManager:         address(manager),
            strategyMetadata:        "MacAttack - 02a",
            strategyDelegateFeeRate: 0.02e6,
            strategyProtocolFeeRate: 0.03e6
        });

        manager.__setUnderlyingStrategy(strategyFactory.getInstanceAddress(abi.encode(params), "DEFAULT"));

        vm.prank(deployer);
        strategy = MapleTradingStrategyHarness(strategyFactory.createInstance(abi.encode(params), "DEFAULT"));
    }

    function array(address element_) internal pure returns (address[] memory array_) {
        array_    = new address[](1);
        array_[0] = element_;
    }

    function array(uint256 element_) internal pure returns (uint256[] memory array_) {
        array_    = new uint256[](1);
        array_[0] = element_;
    }

    function array(address a_, address b_) internal pure returns (address[] memory array_) {
        array_    = new address[](2);
        array_[0] = a_;
        array_[1] = b_;
    }

    function array(uint256 a_, uint256 b_) internal pure returns (uint256[] memory array_) {
        array_    = new uint256[](2);
        array_[0] = a_;
        array_[1] = b_;
    }

    function array(address a_, address b_, address c_) internal pure returns (address[] memory array_) {
        array_    = new address[](3);
        array_[0] = a_;
        array_[1] = b_;
        array_[2] = c_;
    }

    function array(uint256 a_, uint256 b_, uint256 c_) internal pure returns (uint256[] memory array_) {
        array_    = new uint256[](3);
        array_[0] = a_;
        array_[1] = b_;
        array_[2] = c_;
    }

}
