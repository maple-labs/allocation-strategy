// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import { IMapleTradingStrategyInitializer } from "./interfaces/IMapleTradingStrategyInitializer.sol";

import {
    IGlobalsLike,
    IProxyFactoryLike,
    IStrategyManagerLike
}  from "./interfaces/Interfaces.sol";

import { MapleTradingStrategyStorage } from "./MapleTradingStrategyStorage.sol";

contract MapleTradingStrategyInitializer is IMapleTradingStrategyInitializer, MapleTradingStrategyStorage {

    function _initialize(IMapleTradingStrategyInitializer.Parameters memory params_) internal {
        require(params_.strategyManager != address(0), "MTSI:I:ZERO_STRATEGY_MANAGER");

        address globals_ = IProxyFactoryLike(msg.sender).mapleGlobals();
        address factory_ = IStrategyManagerLike(params_.strategyManager).factory();

        require(IGlobalsLike(globals_).isPoolAsset(params_.fundsAsset), "MTSI:I:INVALID_ASSET");

        require(IGlobalsLike(globals_).isInstanceOf("STRATEGY_MANAGER_FACTORY", factory_),           "MTSI:I:INVALID_FACTORY");
        require(IProxyFactoryLike(factory_).isInstance(params_.strategyManager),                     "MTSI:I:INVALID_INSTANCE");
        require(IStrategyManagerLike(params_.strategyManager).underlyingStrategy() == address(this), "MTSI:I:INVALID_UNDERLYING");

        require(params_.strategyDelegateFeeRate + params_.strategyProtocolFeeRate <= 1e6, "MTSI:I:INVALID_SUM_FEE_RATE");

        fundsAsset              = params_.fundsAsset;
        strategyManager         = params_.strategyManager;
        strategyMetadata        = params_.strategyMetadata;
        strategyDelegateFeeRate = params_.strategyDelegateFeeRate;
        strategyProtocolFeeRate = params_.strategyProtocolFeeRate;

        _locked = 1;

        emit Initialized(params_);
    }

    fallback() external {
        _initialize(abi.decode(msg.data, (Parameters)));
    }

}
