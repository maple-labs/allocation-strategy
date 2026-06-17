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

    function _initialize(address strategyManager_, IMapleTradingStrategyInitializer.Parameters memory params_) internal {
        require(strategyManager_ != address(0), "MTSI:I:ZERO_STRATEGY_MANAGER");

        address globals_ = IProxyFactoryLike(msg.sender).mapleGlobals();
        address factory_ = IStrategyManagerLike(strategyManager_).factory();

        require(IGlobalsLike(globals_).isPoolAsset(params_.fundsAsset), "MTSI:I:INVALID_ASSET");

        require(IGlobalsLike(globals_).isInstanceOf("STRATEGY_MANAGER_FACTORY", factory_),    "MTSI:I:INVALID_FACTORY");
        require(IProxyFactoryLike(factory_).isInstance(strategyManager_),                     "MTSI:I:INVALID_INSTANCE");
        require(IStrategyManagerLike(strategyManager_).underlyingStrategy() == address(this), "MTSI:I:INVALID_UNDERLYING");

        require(params_.strategyDelegateFeeRate + params_.strategyProtocolFeeRate <= 1e6, "MTSI:I:INVALID_SUM_FEE_RATE");

        fundsAsset              = params_.fundsAsset;
        strategyManager         = strategyManager_;
        strategyMetadata        = params_.strategyMetadata;
        strategyDelegateFeeRate = params_.strategyDelegateFeeRate;
        strategyProtocolFeeRate = params_.strategyProtocolFeeRate;

        _locked = 1;

        emit Initialized(strategyManager_, params_);
    }

    fallback() external {
        address           strategyManager_ = abi.decode(msg.data[:32], (address));
        Parameters memory params_          = abi.decode(msg.data[32:], (Parameters));

        _initialize(strategyManager_, params_);
    }

}
