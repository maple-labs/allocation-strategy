// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.34;

import {
    IGlobalsLike,
    IProxyFactoryLike,
    IStrategyManagerLike
} from "./interfaces/Interfaces.sol";

import {
    AllocationStrategyInitializerParams,
    IMapleAllocationStrategyInitializer
} from "./interfaces/IMapleAllocationStrategyInitializer.sol";

import { MapleAllocationStrategyStorage } from "./MapleAllocationStrategyStorage.sol";

contract MapleAllocationStrategyInitializer is IMapleAllocationStrategyInitializer, MapleAllocationStrategyStorage {

    function _initialize(address strategyManager_, AllocationStrategyInitializerParams memory params_) internal {
        require(strategyManager_ != address(0), "MASI:I:ZERO_STRATEGY_MANAGER");

        address globals_ = IProxyFactoryLike(msg.sender).mapleGlobals();
        address factory_ = IStrategyManagerLike(strategyManager_).factory();

        require(IGlobalsLike(globals_).isPoolAsset(params_.fundsAsset), "MASI:I:INVALID_ASSET");

        require(IGlobalsLike(globals_).isInstanceOf("STRATEGY_MANAGER_FACTORY", factory_),    "MASI:I:INVALID_FACTORY");
        require(IProxyFactoryLike(factory_).isInstance(strategyManager_),                     "MASI:I:INVALID_INSTANCE");
        require(IStrategyManagerLike(strategyManager_).underlyingStrategy() == address(this), "MASI:I:INVALID_UNDERLYING");

        require(params_.strategyDelegateFeeRate + params_.strategyProtocolFeeRate <= 1e6, "MASI:I:INVALID_SUM_FEE_RATE");

        fundsAsset              = params_.fundsAsset;
        strategyManager         = strategyManager_;
        strategyMetadata        = params_.strategyMetadata;
        strategyDelegateFeeRate = params_.strategyDelegateFeeRate;
        strategyProtocolFeeRate = params_.strategyProtocolFeeRate;
        yieldCap                = params_.yieldCap;

        _locked = 1;

        emit Initialized(strategyManager_, params_);
    }

    fallback() external {
        address                             strategyManager_ = abi.decode(msg.data[:32], (address));
        AllocationStrategyInitializerParams memory params_   = abi.decode(msg.data[32:], (AllocationStrategyInitializerParams));

        _initialize(strategyManager_, params_);
    }

}
