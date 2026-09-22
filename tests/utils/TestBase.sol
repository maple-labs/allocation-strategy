// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import { Test } from "../../modules/forge-std/src/Test.sol";

import { AllocationStrategyInitializerParams } from "../../contracts/interfaces/IMapleAllocationStrategyInitializer.sol";

import { MapleAllocationStrategyFactory } from "../../contracts/MapleAllocationStrategyFactory.sol";

import { MapleAllocationStrategyHarness, MapleAllocationStrategyInitializerHarness } from "./Harnesses.sol";

import { MockAsset, MockFactory, MockGlobals, MockStrategyManager } from "./Mocks.sol";

contract TestBase is Test {

    address deployer         = makeAddr("deployer");
    address governor         = makeAddr("governor");
    address mapleTreasury    = makeAddr("mapleTreasury");
    address operationalAdmin = makeAddr("operationalAdmin");
    address securityAdmin    = makeAddr("securityAdmin");
    address strategyDelegate = makeAddr("strategyDelegate");

    address implementation = address(new MapleAllocationStrategyHarness());
    address initializer    = address(new MapleAllocationStrategyInitializerHarness());

    uint32 startingTime;

    AllocationStrategyInitializerParams params;

    MockAsset           asset          = new MockAsset();
    MockFactory         managerFactory = new MockFactory();
    MockGlobals         globals        = new MockGlobals();
    MockStrategyManager manager        = new MockStrategyManager();

    MapleAllocationStrategyFactory strategyFactory;
    MapleAllocationStrategyHarness strategy;

    function setUp() public virtual {
        startingTime = uint32(block.timestamp);

        globals.__setCanDeploy(deployer, true);
        globals.__setGovernor(governor);
        globals.__setMapleTreasury(mapleTreasury);
        globals.__setOperationalAdmin(operationalAdmin);
        globals.__setSecurityAdmin(securityAdmin);
        globals.__setIsPoolAsset(address(asset), true);
        globals.__setIsInstanceOf("STRATEGY_MANAGER_FACTORY", address(managerFactory), true);

        manager.__setFactory(address(managerFactory));
        manager.__setStrategyDelegate(strategyDelegate);
        managerFactory.__setIsInstance(address(manager), true);

        strategyFactory = new MapleAllocationStrategyFactory(address(globals));

        vm.startPrank(governor);
        strategyFactory.registerImplementation(100, implementation, initializer);
        strategyFactory.setDefaultVersion(100);
        vm.stopPrank();

        params = AllocationStrategyInitializerParams({
            fundsAsset:              address(asset),
            strategyMetadata:        "MacAttack - 02a",
            strategyDelegateFeeRate: 0.02e6,
            strategyProtocolFeeRate: 0.03e6,
            yieldCap:                1_000_000e6
        });

        manager.__setStrategyDelegate(strategyDelegate);
        manager.__setUnderlyingStrategy(strategyFactory.getInstanceAddress(initializationArguments(), "DEFAULT"));

        vm.prank(deployer);
        strategy = MapleAllocationStrategyHarness(strategyFactory.createInstance(initializationArguments(), "DEFAULT"));
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

    function array(bool element_) internal pure returns (bool[] memory array_) {
        array_    = new bool[](1);
        array_[0] = element_;
    }

    function array(bool a_, bool b_) internal pure returns (bool[] memory array_) {
        array_    = new bool[](2);
        array_[0] = a_;
        array_[1] = b_;
    }

    function array(bool a_, bool b_, bool c_) internal pure returns (bool[] memory array_) {
        array_    = new bool[](3);
        array_[0] = a_;
        array_[1] = b_;
        array_[2] = c_;
    }

    function assertPermissions(
        address account_,
        bool expectedCanDeployAssets_,
        bool expectedCanReturnAssets_,
        bool expectedCanRealizeYield_
    )
        internal
        view
    {
        (bool actualCanDeployAssets_, bool actualCanReturnAssets_, bool actualCanRealizeYield_) = strategy.permissions(account_);

        assertEq(actualCanDeployAssets_, expectedCanDeployAssets_);
        assertEq(actualCanReturnAssets_, expectedCanReturnAssets_);
        assertEq(actualCanRealizeYield_, expectedCanRealizeYield_);
    }

    function initializationArguments() internal view returns (bytes memory arguments_) {
        arguments_ = bytes.concat(abi.encode(address(manager)), abi.encode(params));
    }

}
