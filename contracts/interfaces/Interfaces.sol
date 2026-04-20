// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

interface IGlobalsLike {

    function canDeploy(address caller) external view returns (bool);

    function isFunctionPaused(bytes4 signature) external view returns (bool);

    function securityAdmin() external view returns (address);

}

interface IProxyFactoryLike {

    function mapleGlobals() external view returns (address);

    function upgradeInstance(uint256 version, bytes calldata arguments) external;

}
