// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import { MapleProxiedInternals } from "../modules/proxy-factory/contracts/MapleProxiedInternals.sol";

import { IMapleTradingStrategy }           from "./interfaces/IMapleTradingStrategy.sol";
import { IGlobalsLike, IProxyFactoryLike } from "./interfaces/Interfaces.sol";

import { MapleTradingStrategyStorage } from "./MapleTradingStrategyStorage.sol";

contract MapleTradingStrategy is IMapleTradingStrategy, MapleTradingStrategyStorage, MapleProxiedInternals {

    /**************************************************************************************************************************************/
    /*** Constants                                                                                                                      ***/
    /**************************************************************************************************************************************/

    /**************************************************************************************************************************************/
    /*** Modifiers                                                                                                                      ***/
    /**************************************************************************************************************************************/

    modifier onlyFactory() {
        require(msg.sender == _factory(), "MTS:NOT_FACTORY");

        _;
    }

    modifier onlyStrategyManager() {
        require(msg.sender == strategyManager, "MTS:NOT_STRATEGY_MANAGER");

        _;
    }

    modifier whenNotPaused() {
        require(!IGlobalsLike(globals()).isFunctionPaused(msg.sig), "MTS:PAUSED");

        _;
    }

    /**************************************************************************************************************************************/
    /*** Proxy Functions                                                                                                                ***/
    /**************************************************************************************************************************************/

    function migrate(address migrator_, bytes calldata arguments_) external override whenNotPaused onlyFactory {
        require(_migrate(migrator_, arguments_), "MTS:M:FAILED");
    }

    function setImplementation(address implementation_) external override whenNotPaused onlyFactory {
        _setImplementation(implementation_);
    }

    function upgrade(uint256 version_, bytes calldata arguments_) external override whenNotPaused {
        require(msg.sender == securityAdmin(), "MTS:U:NOT_AUTHORIZED");

        IProxyFactoryLike(_factory()).upgradeInstance(version_, arguments_);

        emit Upgraded(version_, arguments_);
    }

    /**************************************************************************************************************************************/
    /*** State-Changing Functions                                                                                                       ***/
    /**************************************************************************************************************************************/

    function fundUnderlyingStrategy(
        uint256 assetsIn_,
        bytes calldata
    )
        external override whenNotPaused onlyStrategyManager returns (uint256 assetsOut_)
    {
        // TODO: Check if validation for zero asset amounts is needed.
        // TODO: Check if validation related to transferred asset balances is needed.

        assetsOut_ = assetsIn_;

        emit StrategyFunded(strategyManager, assetsIn_);
    }

    /**************************************************************************************************************************************/
    /*** View Functions                                                                                                                 ***/
    /**************************************************************************************************************************************/

    function factory() external view override returns (address factory_) {
        factory_ = _factory();
    }

    function globals() public view override returns (address globals_) {
        globals_ = IProxyFactoryLike(_factory()).mapleGlobals();
    }

    function implementation() external view override returns (address implementation_) {
        implementation_ = _implementation();
    }

    function securityAdmin() public view override returns (address securityAdmin_) {
        securityAdmin_ = IGlobalsLike(globals()).securityAdmin();
    }

    /**************************************************************************************************************************************/
    /*** Internal Functions                                                                                                             ***/
    /**************************************************************************************************************************************/

}
