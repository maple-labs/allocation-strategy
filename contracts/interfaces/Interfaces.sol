// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

interface IGlobalsLike {

    function canDeploy(address caller) external view returns (bool);

    function isFunctionPaused(bytes4 signature) external view returns (bool);

    function isInstanceOf(bytes32 key, address instance) external view returns (bool);

    function isPoolAsset(address asset) external view returns (bool);

    function isValidTradingAddress(address tradingAddress) external view returns (bool);

    function operationalAdmin() external view returns (address);

    function securityAdmin() external view returns (address);

    function strategyDelegateOf(address strategyManager) external view returns (address);

}

interface IProxyFactoryLike {

    function isInstance(address instance) external view returns (bool);

    function mapleGlobals() external view returns (address);

    function upgradeInstance(uint256 version, bytes calldata arguments) external;

}

interface IStrategyManagerLike {

    function factory() external view returns (address);

    function underlyingStrategy() external view returns (address);

}
