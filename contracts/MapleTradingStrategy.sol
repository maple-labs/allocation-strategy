// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import { ERC20Helper } from "../modules/erc20-helper/src/ERC20Helper.sol";

import { MapleProxiedInternals } from "../modules/proxy-factory/contracts/MapleProxiedInternals.sol";

import { IMapleTradingStrategy } from "./interfaces/IMapleTradingStrategy.sol";
import {
    IERC20Like,
    IGlobalsLike,
    IProxyFactoryLike
} from "./interfaces/Interfaces.sol";

import { MapleTradingStrategyStorage } from "./MapleTradingStrategyStorage.sol";

contract MapleTradingStrategy is IMapleTradingStrategy, MapleTradingStrategyStorage, MapleProxiedInternals {

    /**************************************************************************************************************************************/
    /*** Constants                                                                                                                      ***/
    /**************************************************************************************************************************************/

    /**************************************************************************************************************************************/
    /*** Modifiers                                                                                                                      ***/
    /**************************************************************************************************************************************/

    modifier nonReentrant() {
        require(_locked == 1, "MTS:LOCKED");

        _locked = 2;

        _;

        _locked = 1;
    }

    modifier onlyAdmin() {
        address globals_ = globals();

        require(
            msg.sender == IGlobalsLike(globals_).strategyDelegateOf(strategyManager) ||
            msg.sender == IGlobalsLike(globals_).operationalAdmin(),
            "MTS:NOT_AUTHORIZED"
        );

        _;
    }

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
    /*** Management Functions                                                                                                           ***/
    /**************************************************************************************************************************************/

    function deployAssets(uint256 assets_, bytes calldata metadata_) external override whenNotPaused nonReentrant {
        require(IGlobalsLike(globals()).isValidTradingAddress(msg.sender), "MTS:DA:NOT_TRADING_ADDRESS");
        require(permissions[msg.sender].canDeployAssets,                   "MTS:DA:NOT_DEPLOYER");

        require(assets_ >  0,                     "MTS:DA:ZERO_ASSETS");
        require(assets_ <= availableToWithdraw(), "MTS:DA:INSUFFICIENT_ASSETS");

        uint256 deployedAssets_ = deployedAssetsOf[msg.sender] + assets_;

        require(deployedAssets_ <= deploymentCapOf[msg.sender], "MTS:DA:CAP_EXCEEDED");

        outstandingAssets            += assets_;
        deployedAssetsOf[msg.sender] += assets_;

        require(ERC20Helper.transfer(fundsAsset, msg.sender, assets_), "MTS:DA:TRANSFER_FAILED");

        emit AssetsDeployed(msg.sender, assets_, metadata_);
    }

    /**************************************************************************************************************************************/
    /*** Administrative Functions                                                                                                       ***/
    /**************************************************************************************************************************************/

    function setDeploymentCaps(address[] calldata accounts_, uint256[] calldata amounts_) external override whenNotPaused onlyAdmin {
        require(accounts_.length != 0,               "MTS:SDC:ZERO_LENGTH");
        require(accounts_.length == amounts_.length, "MTS:SDC:LENGTH_MISMATCH");

        address globals_ = globals();

        for (uint256 i_; i_ < accounts_.length; ++i_) {
            address account_ = accounts_[i_];
            uint256 cap_     = amounts_[i_];

            require(IGlobalsLike(globals_).isValidTradingAddress(account_) || cap_ == 0, "MTS:SDC:INVALID_DEPLOYER");
            require(deploymentCapOf[account_] != cap_,                                   "MTS:SDC:NO_CHANGE");

            deploymentCapOf[account_] = cap_;

            emit DeploymentCapSet(account_, cap_);
        }
    }

    /**************************************************************************************************************************************/
    /*** Liquidity Functions                                                                                                            ***/
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

    function withdrawFromUnderlyingStrategy(
        address destination_,
        uint256 assets_
    )
        external override whenNotPaused nonReentrant onlyStrategyManager
    {
        // TODO: Check if validation of destination address should be added.
        // TODO: Check if validation of asset amounts should be added: <0, cash - unaccruedYield]

        require(ERC20Helper.transfer(fundsAsset, destination_, assets_), "MTS:WFUS:TRANSFER_FAILED");

        emit StrategyWithdrawn(strategyManager, destination_, assets_);
    }

    /**************************************************************************************************************************************/
    /*** View Functions                                                                                                                 ***/
    /**************************************************************************************************************************************/

    // TODO: Subtract unrealized assets once yield buffer is implemented.
    function availableToWithdraw() public view override returns (uint256 availableAssets_) {
        availableAssets_ = IERC20Like(fundsAsset).balanceOf(address(this));
    }

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
