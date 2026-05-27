// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import { IMapleTradingStrategyStorage } from "./interfaces/IMapleTradingStrategyStorage.sol";

contract MapleTradingStrategyStorage is IMapleTradingStrategyStorage {

    uint256 internal _locked;  // Used when checking for reentrancy.

    address public override fundsAsset;       // Address of the underlying asset.
    address public override strategyManager;  // Address of the strategy manager.

    uint256 public override totalDeployedAssets;  // Total assets deployed across all trading addresses.

    uint32 public override strategyDelegateFeeRate;  // Percentage of yield collected by the strategy delegate.
    uint32 public override strategyProtocolFeeRate;  // Percentage of yield collected by the Maple treasury.

    // TODO: Should `bytes` be used here instead?
    string public override strategyMetadata;  // Optional metadata associated with the trading strategy.

    mapping(address => uint256) public override deployedAssetsOf;  // Per-address amount currently deployed.
    mapping(address => uint256) public override deploymentCapOf;   // Per-address deployment cap.

    mapping(address => Permissions) public override permissions;  // Per-address permission flags.

}
