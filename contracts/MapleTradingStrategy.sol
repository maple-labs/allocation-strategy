// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import { ERC20Helper } from "../modules/erc20-helper/src/ERC20Helper.sol";

import { MapleProxiedInternals } from "../modules/proxy-factory/contracts/MapleProxiedInternals.sol";

import { IMapleTradingStrategy } from "./interfaces/IMapleTradingStrategy.sol";
import {
    IERC20Like,
    IGlobalsLike,
    IProxyFactoryLike,
    IStrategyManagerLike
} from "./interfaces/Interfaces.sol";

import { MapleTradingStrategyStorage } from "./MapleTradingStrategyStorage.sol";

contract MapleTradingStrategy is IMapleTradingStrategy, MapleTradingStrategyStorage, MapleProxiedInternals {

    /**************************************************************************************************************************************/
    /*** Constants                                                                                                                      ***/
    /**************************************************************************************************************************************/

    bytes32 internal constant INSTANCE_KEY = "TRADING_ADDRESS";

    string public constant STRATEGY_TYPE = "TRADING";

    uint256 internal constant HUNDRED_PERCENT = 1e6;

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
            msg.sender == IStrategyManagerLike(strategyManager).strategyDelegate() ||
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

    // TODO: Add `onlyTradingAddress` modifier?

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
        require(IGlobalsLike(globals()).isGovernedInstanceOf(INSTANCE_KEY, msg.sender), "MTS:DA:NOT_TRADING_ADDRESS");
        require(permissions[msg.sender].canDeployAssets,                                "MTS:DA:NOT_ALLOWED");

        require(assets_ >  0,                     "MTS:DA:ZERO_ASSETS");
        require(assets_ <= availableToWithdraw(), "MTS:DA:INSUFFICIENT_ASSETS");

        uint256 deployedAssets_ = deployedAssetsOf[msg.sender] + assets_;

        require(deployedAssets_ <= deploymentCapOf[msg.sender], "MTS:DA:CAP_EXCEEDED");

        totalDeployedAssets          += assets_;
        deployedAssetsOf[msg.sender] += assets_;

        require(ERC20Helper.transfer(fundsAsset, msg.sender, assets_), "MTS:DA:TRANSFER_FAILED");

        emit AssetsDeployed(msg.sender, assets_, metadata_);
    }

    function returnAssets(uint256 assets_, address onBehalfOf_, bytes calldata metadata_) external override whenNotPaused nonReentrant {
        require(IGlobalsLike(globals()).isGovernedInstanceOf(INSTANCE_KEY, msg.sender), "MTS:RA:NOT_TRADING_ADDRESS");
        require(permissions[msg.sender].canReturnAssets,                                "MTS:RA:NOT_ALLOWED");

        require(assets_ != 0,                             "MTS:RA:ZERO_ASSETS");
        require(assets_ <= deployedAssetsOf[onBehalfOf_], "MTS:RA:EXCEEDS_ASSETS");

        totalDeployedAssets           -= assets_;
        deployedAssetsOf[onBehalfOf_] -= assets_;

        require(ERC20Helper.transferFrom(fundsAsset, msg.sender, address(this), assets_), "MTS:RA:TRANSFER_FAILED");

        emit AssetsReturned(msg.sender, onBehalfOf_, assets_, metadata_);
    }

    function realizeYield(uint256 yield_, uint32 duration_, bytes calldata metadata_) external override whenNotPaused nonReentrant {
        address fundsAsset_ = fundsAsset;
        address globals_    = globals();

        require(IGlobalsLike(globals_).isGovernedInstanceOf(INSTANCE_KEY, msg.sender), "MTS:RY:NOT_TRADING_ADDRESS");
        require(permissions[msg.sender].canRealizeYield,                               "MTS:RY:NOT_ALLOWED");

        if (yield_ != 0) {
            require(ERC20Helper.transferFrom(fundsAsset_, msg.sender, address(this), yield_), "MTS:RY:TRANSFER_FROM_FAILED");
        }

        ( uint256 netYield_, uint256 delegateFee_, uint256 protocolFee_ ) = _accrueFees(fundsAsset_, yield_);

        uint256 unrealizedYield_ = unrealizedAssets();
        uint32  yieldStart_      = uint32(block.timestamp);

        scheduledYieldAssets = netYield_ + unrealizedYield_;
        yieldStart           = yieldStart_;
        yieldDeadline        = yieldStart_ + duration_;

        emit YieldRealized(msg.sender, unrealizedYield_, netYield_, delegateFee_, protocolFee_, duration_, metadata_);
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

            require(
                IGlobalsLike(globals_).isGovernedInstanceOf(INSTANCE_KEY, account_) || cap_ == 0,
                "MTS:SDC:NOT_TRADING_ADDRESS"
            );

            require(deploymentCapOf[account_] != cap_, "MTS:SDC:NO_CHANGE");

            deploymentCapOf[account_] = cap_;

            emit DeploymentCapSet(account_, cap_);
        }
    }

    /**************************************************************************************************************************************/
    /*** Liquidity Functions                                                                                                            ***/
    /**************************************************************************************************************************************/

    // NOTE: Funding caps are enforced by the strategy manager.
    function fundUnderlyingStrategy(
        uint256 assetsIn_,
        bytes calldata /* data_ */
    )
        external override whenNotPaused onlyStrategyManager returns (uint256 assetsOut_)
    {
        assetsOut_ = assetsIn_;

        emit StrategyFunded(strategyManager, assetsIn_);
    }

    function withdrawFromUnderlyingStrategy(
        address destination_,
        uint256 assets_,
        bytes calldata /* data_ */
    )
        external override whenNotPaused nonReentrant onlyStrategyManager
    {
        require(assets_ <= availableToWithdraw(),                        "MTS:WFUS:INSUFFICIENT_ASSETS");
        require(ERC20Helper.transfer(fundsAsset, destination_, assets_), "MTS:WFUS:TRANSFER_FAILED");

        emit StrategyWithdrawn(strategyManager, destination_, assets_);
    }

    /**************************************************************************************************************************************/
    /*** View Functions                                                                                                                 ***/
    /**************************************************************************************************************************************/

    function availableToWithdraw() public view override returns (uint256 availableAssets_) {
        availableAssets_ = IERC20Like(fundsAsset).balanceOf(address(this)) - unrealizedAssets();
    }

    function assetsUnderManagement() external view override returns (uint256 assetsUnderManagement_) {
        assetsUnderManagement_ = totalDeployedAssets + availableToWithdraw();
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

    function mapleTreasury() public view override returns (address mapleTreasury_) {
        mapleTreasury_ = IGlobalsLike(globals()).mapleTreasury();
    }

    function realizedAssets() public view override returns (uint256 realizedAssets_) {
        uint256 scheduledYieldAssets_ = scheduledYieldAssets;
        uint256 yieldStart_           = yieldStart;

        uint256 elapsedDuration_ = block.timestamp - yieldStart_;
        uint256 totalDuration_   = yieldDeadline - yieldStart_;

        if (totalDuration_ == 0 || elapsedDuration_ >= totalDuration_) return scheduledYieldAssets_;

        realizedAssets_ = scheduledYieldAssets_ * elapsedDuration_ / totalDuration_;
    }

    function securityAdmin() public view override returns (address securityAdmin_) {
        securityAdmin_ = IGlobalsLike(globals()).securityAdmin();
    }

    function strategyDelegate() public view override returns (address strategyDelegate_) {
        strategyDelegate_ = IStrategyManagerLike(strategyManager).strategyDelegate();
    }

    function unrealizedAssets() public view override returns (uint256 unrealizedAssets_) {
        unrealizedAssets_ = scheduledYieldAssets - realizedAssets();
    }

    /**************************************************************************************************************************************/
    /*** Internal Functions                                                                                                             ***/
    /**************************************************************************************************************************************/

    function _accrueFees(
        address fundsAsset_,
        uint256 yield_
    )
        internal returns (
            uint256 netYield_,
            uint256 delegateFee_,
            uint256 protocolFee_
        )
    {
        delegateFee_ = yield_ * strategyDelegateFeeRate / HUNDRED_PERCENT;
        protocolFee_ = yield_ * strategyProtocolFeeRate / HUNDRED_PERCENT;
        netYield_    = yield_ - delegateFee_ - protocolFee_;

        if (delegateFee_ != 0) {
            require(ERC20Helper.transfer(fundsAsset_, strategyDelegate(), delegateFee_), "MTS:CF:DELEGATE_TRANSFER_FAILED");
        }

        if (protocolFee_ != 0) {
            require(ERC20Helper.transfer(fundsAsset_, mapleTreasury(), protocolFee_), "MTS:CF:PROTOCOL_TRANSFER_FAILED");
        }
    }

}
