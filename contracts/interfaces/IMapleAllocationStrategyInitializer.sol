// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

/**
 *  @dev   Parameters required to initialize an allocation strategy.
 *         Initializer arguments are encoded as abi.encode(strategyManager) || abi.encode(params).
 *  @param fundsAsset              Address of the asset used by the strategy.
 *  @param strategyMetadata        Optional metadata associated with the allocation strategy.
 *  @param strategyDelegateFeeRate Percentage of yield collected by the strategy delegate.
 *  @param strategyProtocolFeeRate Percentage of yield collected by the Maple treasury.
 *  @param yieldCap                Maximum amount of assets that can be realized as yield in a single call.
 */
struct AllocationStrategyInitializerParams {
    address fundsAsset;
    string strategyMetadata;
    uint32 strategyDelegateFeeRate;
    uint32 strategyProtocolFeeRate;
    uint256 yieldCap;
}

/**
 *  @title Defines a contract used to initialize new Maple allocation strategies.
 */
interface IMapleAllocationStrategyInitializer {

    /**
     *  @dev   Emitted when the allocation strategy proxy is initialized.
     *  @param strategyManager Address of the strategy manager contract.
     *  @param params          Allocation strategy parameters set during initialization.
     */
    event Initialized(address indexed strategyManager, AllocationStrategyInitializerParams params);

}
