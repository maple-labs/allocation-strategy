// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import { ERC20Helper } from "../modules/erc20-helper/src/ERC20Helper.sol";

import { MapleProxiedInternals } from "../modules/proxy-factory/contracts/MapleProxiedInternals.sol";

import {
    IERC20Like,
    IGlobalsLike,
    IProxyFactoryLike,
    IStrategyManagerLike
} from "./interfaces/Interfaces.sol";

import { IMapleAllocationStrategy } from "./interfaces/IMapleAllocationStrategy.sol";
import { Permissions }              from "./interfaces/IMapleAllocationStrategyStorage.sol";

import { MapleAllocationStrategyStorage } from "./MapleAllocationStrategyStorage.sol";

contract MapleAllocationStrategy is IMapleAllocationStrategy, MapleAllocationStrategyStorage, MapleProxiedInternals {

    /**************************************************************************************************************************************/
    /*** Constants                                                                                                                      ***/
    /**************************************************************************************************************************************/

    bytes32 internal constant INSTANCE_KEY = "MAPLE_MANAGED_WALLET";

    string public constant STRATEGY_TYPE = "ALLOCATION";

    uint256 internal constant HUNDRED_PERCENT        = 1e6;
    uint256 internal constant REALIZE_YIELD_COOLDOWN = 1 hours;

    /**************************************************************************************************************************************/
    /*** Modifiers                                                                                                                      ***/
    /**************************************************************************************************************************************/

    modifier nonReentrant() {
        require(_locked == 1, "MAS:LOCKED");

        _locked = 2;

        _;

        _locked = 1;
    }

    modifier onlyAdmin() {
        address globals_ = globals();

        require(
            msg.sender == IStrategyManagerLike(strategyManager).strategyDelegate() ||
            msg.sender == IGlobalsLike(globals_).operationalAdmin(),
            "MAS:NOT_AUTHORIZED"
        );

        _;
    }

    modifier onlyFactory() {
        require(msg.sender == _factory(), "MAS:NOT_FACTORY");

        _;
    }

    modifier onlyProtocolAdmins() {
        address globals_ = globals();

        require(
            msg.sender == IGlobalsLike(globals_).governor() ||
            msg.sender == IGlobalsLike(globals_).operationalAdmin(),
            "MAS:NOT_ADMIN"
        );

        _;
    }

    modifier onlySecurityAdminOrStrategyDelegate() {
        require(
            msg.sender == strategyDelegate() ||
            msg.sender == securityAdmin(),
            "MAS:NOT_AUTHORIZED"
        );

        _;
    }

    modifier onlyStrategyDelegate() {
        require(msg.sender == strategyDelegate(), "MAS:NOT_STRATEGY_DELEGATE");

        _;
    }

    modifier onlyStrategyManager() {
        require(msg.sender == strategyManager, "MAS:NOT_STRATEGY_MANAGER");

        _;
    }

    modifier onlyManagedWallet() {
        require(IGlobalsLike(globals()).isInstanceOf(INSTANCE_KEY, msg.sender), "MAS:NOT_MAPLE_MANAGED_WALLET");

        _;
    }

    modifier whenNotPaused() {
        require(!IGlobalsLike(globals()).isFunctionPaused(msg.sig), "MAS:PAUSED");

        _;
    }

    /**************************************************************************************************************************************/
    /*** Proxy Functions                                                                                                                ***/
    /**************************************************************************************************************************************/

    function migrate(address migrator_, bytes calldata arguments_) external override whenNotPaused onlyFactory {
        require(_migrate(migrator_, arguments_), "MAS:M:FAILED");
    }

    function setImplementation(address implementation_) external override whenNotPaused onlyFactory {
        _setImplementation(implementation_);
    }

    function upgrade(uint256 version_, bytes calldata arguments_) external override whenNotPaused {
        require(msg.sender == securityAdmin(), "MAS:U:NOT_AUTHORIZED");

        IProxyFactoryLike(_factory()).upgradeInstance(version_, arguments_);

        emit Upgraded(version_, arguments_);
    }

    /**************************************************************************************************************************************/
    /*** Management Functions                                                                                                           ***/
    /**************************************************************************************************************************************/

    function deployAssets(
        uint256 assets_,
        bytes   calldata metadata_
    )
        external override whenNotPaused nonReentrant onlyManagedWallet
    {
        require(permissions[msg.sender].canDeployAssets, "MAS:DA:NOT_ALLOWED");

        require(assets_ >  0,                     "MAS:DA:ZERO_ASSETS");
        require(assets_ <= availableToWithdraw(), "MAS:DA:INSUFFICIENT_ASSETS");

        uint256 deployedAssets_ = deployedAssetsOf[msg.sender] + assets_;

        require(deployedAssets_ <= deploymentCapOf[msg.sender], "MAS:DA:CAP_EXCEEDED");

        totalDeployedAssets          += assets_;
        deployedAssetsOf[msg.sender] += assets_;

        uint256 updatedRecordedAssets_ = recordedAssets -= assets_;

        require(ERC20Helper.transfer(fundsAsset, msg.sender, assets_), "MAS:DA:TRANSFER_FAILED");

        emit AssetsDeployed(msg.sender, assets_, updatedRecordedAssets_, metadata_);
    }

    function multicall(bytes[] calldata data_) external override {
        for (uint256 i = 0; i < data_.length; i++) {
            ( bool success_, bytes memory returnData_ ) = address(this).delegatecall(data_[i]);

            if (!success_) {
                assembly ("memory-safe") {
                    revert(add(32, returnData_), mload(returnData_))
                }
            }
        }
    }

    function returnAssets(
        uint256 assets_,
        address onBehalfOf_,
        bytes   calldata metadata_
    )
        external override whenNotPaused nonReentrant onlyManagedWallet
    {
        require(permissions[msg.sender].canReturnAssets, "MAS:RA:NOT_ALLOWED");

        require(assets_ != 0,                             "MAS:RA:ZERO_ASSETS");
        require(assets_ <= deployedAssetsOf[onBehalfOf_], "MAS:RA:EXCEEDS_ASSETS");

        totalDeployedAssets           -= assets_;
        deployedAssetsOf[onBehalfOf_] -= assets_;

        uint256 updatedRecordedAssets_ = recordedAssets += assets_;

        require(ERC20Helper.transferFrom(fundsAsset, msg.sender, address(this), assets_), "MAS:RA:TRANSFER_FAILED");

        emit AssetsReturned(msg.sender, onBehalfOf_, assets_, updatedRecordedAssets_, metadata_);
    }

    function realizeYield(
        uint256 yield_,
        uint32  duration_,
        bytes   calldata metadata_
    )
        external override whenNotPaused nonReentrant onlyManagedWallet
    {
        require(permissions[msg.sender].canRealizeYield, "MAS:RY:NOT_ALLOWED");
        require(yield_ <= yieldCap,                      "MAS:RY:CAP_EXCEEDED");
        require(yieldCooldown() == 0,                    "MAS:RY:COOLDOWN");

        address fundsAsset_ = fundsAsset;

        if (yield_ != 0) {
            require(ERC20Helper.transferFrom(fundsAsset_, msg.sender, address(this), yield_), "MAS:RY:TRANSFER_FROM_FAILED");
        }

        ( uint256 netYield_, uint256 delegateFee_, uint256 protocolFee_ ) = _accrueFees(fundsAsset_, yield_);

        uint256 unrealizedYield_       = unrealizedYield();
        uint256 updatedRecordedAssets_ = recordedAssets += netYield_;

        scheduledYieldAssets = netYield_ + unrealizedYield_;

        yieldLastRealized = uint32(block.timestamp);
        yieldStart        = uint32(block.timestamp);
        yieldDeadline     = uint32(block.timestamp) + duration_;

        emit YieldRealized(
            msg.sender,
            unrealizedYield_,
            netYield_,
            delegateFee_,
            protocolFee_,
            updatedRecordedAssets_,
            duration_,
            metadata_
        );
    }

    /**************************************************************************************************************************************/
    /*** Administrative Functions                                                                                                       ***/
    /**************************************************************************************************************************************/

    function cancelYield(
        uint256 assets_,
        address recipient_
    )
        external override whenNotPaused nonReentrant onlySecurityAdminOrStrategyDelegate
    {
        uint256 unrealizedYield_ = unrealizedYield();
        uint256 cancelledAssets_ = assets_ == type(uint256).max ? unrealizedYield_ : assets_;

        require(cancelledAssets_ != 0,                "MAS:CY:ZERO_ASSETS");
        require(cancelledAssets_ <= unrealizedYield_, "MAS:CY:EXCEEDS_UNREALIZED");

        require(IGlobalsLike(globals()).isInstanceOf(INSTANCE_KEY, recipient_), "MAS:CY:INVALID_RECIPIENT");

        uint256 updatedRecordedAssets_ = recordedAssets -= cancelledAssets_;

        scheduledYieldAssets = unrealizedYield_ - cancelledAssets_;
        yieldStart           = uint32(block.timestamp);

        require(ERC20Helper.transfer(fundsAsset, recipient_, cancelledAssets_), "MAS:CY:TRANSFER_FAILED");

        emit YieldCancelled(msg.sender, recipient_, cancelledAssets_, updatedRecordedAssets_);
    }

    function impair(uint256 assets_) external override whenNotPaused nonReentrant onlyAdmin {
        require(assets_ > 0, "MAS:I:ZERO_ASSETS");

        impairedAssets += assets_;

        emit Impaired(assets_);
    }

    function removeImpairment(uint256 assets_) public override whenNotPaused nonReentrant onlyAdmin {
        _removeImpairment(assets_);
    }

    function recognizeLoss(uint256 assets_, address deployer_) public override whenNotPaused nonReentrant onlyAdmin {
        _recognizeLoss(assets_, deployer_);
    }

    function recognizeLossAndRemoveImpairment(
        uint256 assetsLost_,
        uint256 assetsUnimpaired_,
        address deployer_
    )
        external override whenNotPaused nonReentrant onlyAdmin
    {
        _recognizeLoss(assetsLost_, deployer_);
        _removeImpairment(assetsUnimpaired_);
    }

    function setDeploymentCaps(
        address[] calldata accounts_,
        uint256[] calldata amounts_
    )
        external override whenNotPaused nonReentrant onlySecurityAdminOrStrategyDelegate
    {
        require(accounts_.length != 0,               "MAS:SDC:ZERO_LENGTH");
        require(accounts_.length == amounts_.length, "MAS:SDC:LENGTH_MISMATCH");

        address globals_ = globals();

        for (uint256 i_; i_ < accounts_.length; ++i_) {
            address account_ = accounts_[i_];
            uint256 cap_     = amounts_[i_];

            require(
                IGlobalsLike(globals_).isInstanceOf(INSTANCE_KEY, account_) || cap_ == 0,
                "MAS:SDC:NOT_MAPLE_MANAGED_WALLET"
            );

            require(deploymentCapOf[account_] != cap_, "MAS:SDC:NO_CHANGE");

            deploymentCapOf[account_] = cap_;

            emit DeploymentCapSet(account_, cap_);
        }
    }

    function setMetadata(string calldata metadata_) external override whenNotPaused nonReentrant onlyAdmin {
        require(keccak256(bytes(metadata_)) != keccak256(bytes(strategyMetadata)), "MAS:SM:NO_CHANGE");

        strategyMetadata = metadata_;

        emit StrategyMetadataSet(metadata_);
    }

    function setPermissions(
        address[] calldata accounts_,
        bool[]    calldata canDeployAssets_,
        bool[]    calldata canReturnAssets_,
        bool[]    calldata canRealizeYield_
    )
        external override whenNotPaused nonReentrant onlySecurityAdminOrStrategyDelegate
    {
        uint256 length_ = accounts_.length;

        require(length_ != 0, "MAS:SP:ZERO_LENGTH");
        require(
            length_ == canDeployAssets_.length &&
            length_ == canReturnAssets_.length &&
            length_ == canRealizeYield_.length,
            "MAS:SP:LENGTH_MISMATCH"
        );

        address globals_ = globals();

        for (uint256 i_; i_ < length_; ++i_) {
            address account_             = accounts_[i_];
            bool    canDeployAssetsFlag_ = canDeployAssets_[i_];
            bool    canReturnAssetsFlag_ = canReturnAssets_[i_];
            bool    canRealizeYieldFlag_ = canRealizeYield_[i_];
            bool    isTotalRevoke_       = !canDeployAssetsFlag_ && !canReturnAssetsFlag_ && !canRealizeYieldFlag_;

            require(IGlobalsLike(globals_).isInstanceOf(INSTANCE_KEY, account_) || isTotalRevoke_, "MAS:SP:NOT_MAPLE_MANAGED_WALLET");

            Permissions memory currentPermissions_ = permissions[account_];

            require(
                currentPermissions_.canDeployAssets != canDeployAssetsFlag_ ||
                currentPermissions_.canReturnAssets != canReturnAssetsFlag_ ||
                currentPermissions_.canRealizeYield != canRealizeYieldFlag_,
                "MAS:SP:NO_CHANGE"
            );

            permissions[account_] = Permissions({
                canDeployAssets: canDeployAssetsFlag_,
                canReturnAssets: canReturnAssetsFlag_,
                canRealizeYield: canRealizeYieldFlag_
            });

            emit PermissionSet(account_, canDeployAssetsFlag_, canReturnAssetsFlag_, canRealizeYieldFlag_);
        }
    }

    function setStrategyDelegateFeeRate(uint32 strategyDelegateFeeRate_) external override whenNotPaused nonReentrant onlyStrategyDelegate {
        require(strategyDelegateFeeRate_ != strategyDelegateFeeRate,                   "MAS:SSDFR:NO_CHANGE");
        require(strategyDelegateFeeRate_ <= HUNDRED_PERCENT,                           "MAS:SSDFR:INVALID_FEE_RATE");
        require(strategyDelegateFeeRate_ + strategyProtocolFeeRate <= HUNDRED_PERCENT, "MAS:SSDFR:INVALID_SUM_FEE_RATE");

        strategyDelegateFeeRate = strategyDelegateFeeRate_;

        emit StrategyDelegateFeeRateSet(strategyDelegateFeeRate_);
    }

    function setStrategyProtocolFeeRate(uint32 strategyProtocolFeeRate_) external override whenNotPaused nonReentrant onlyProtocolAdmins {
        require(strategyProtocolFeeRate_ != strategyProtocolFeeRate,                   "MAS:SSPFR:NO_CHANGE");
        require(strategyProtocolFeeRate_ <= HUNDRED_PERCENT,                           "MAS:SSPFR:INVALID_FEE_RATE");
        require(strategyDelegateFeeRate + strategyProtocolFeeRate_ <= HUNDRED_PERCENT, "MAS:SSPFR:INVALID_SUM_FEE_RATE");

        strategyProtocolFeeRate = strategyProtocolFeeRate_;

        emit StrategyProtocolFeeRateSet(strategyProtocolFeeRate_);
    }

    function setYieldCap(uint256 yieldCap_) external override whenNotPaused nonReentrant onlyAdmin {
        require(yieldCap_ != yieldCap, "MAS:SYC:NO_CHANGE");

        yieldCap = yieldCap_;

        emit YieldCapSet(yieldCap_);
    }

    function skim(address recipient_) external override whenNotPaused nonReentrant onlyAdmin {
        uint256 unrecordedAssets_ = unrecordedAssets();

        require(recipient_ != address(0), "MAS:S:ZERO_RECIPIENT");
        require(unrecordedAssets_ != 0,   "MAS:S:ZERO_ASSETS");

        require(ERC20Helper.transfer(fundsAsset, recipient_, unrecordedAssets_), "MAS:S:TRANSFER_FAILED");

        emit AssetsSkimmed(recipient_, unrecordedAssets_);
    }

    /**************************************************************************************************************************************/
    /*** Liquidity Functions                                                                                                            ***/
    /**************************************************************************************************************************************/

    // NOTE: Funding caps are enforced by the strategy manager.
    function fundUnderlyingStrategy(
        uint256 assetsIn_,
        bytes calldata /* data_ */
    )
        external override whenNotPaused nonReentrant onlyStrategyManager returns (uint256 assetsOut_)
    {
        uint256 updatedRecordedAssets_ = recordedAssets += assetsIn_;

        assetsOut_ = assetsIn_;

        emit StrategyFunded(strategyManager, assetsIn_, updatedRecordedAssets_);
    }

    function withdrawFromUnderlyingStrategy(
        address destination_,
        uint256 assets_,
        bytes calldata /* data_ */
    )
        external override whenNotPaused nonReentrant onlyStrategyManager
    {
        require(assets_ <= availableToWithdraw(), "MAS:WFUS:INSUFFICIENT_ASSETS");

        uint256 updatedRecordedAssets_ = recordedAssets -= assets_;

        require(ERC20Helper.transfer(fundsAsset, destination_, assets_), "MAS:WFUS:TRANSFER_FAILED");

        emit StrategyWithdrawn(strategyManager, destination_, assets_, updatedRecordedAssets_);
    }

    /**************************************************************************************************************************************/
    /*** View Functions                                                                                                                 ***/
    /**************************************************************************************************************************************/

    function availableToWithdraw() public view override returns (uint256 availableAssets_) {
        availableAssets_ = recordedAssets - unrealizedYield();
    }

    function assetsUnderManagement() public view override returns (uint256 assetsUnderManagement_) {
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

    function realizedYield() public view override returns (uint256 realizedYield_) {
        uint256 scheduledYieldAssets_ = scheduledYieldAssets;
        uint256 yieldStart_           = yieldStart;

        uint256 elapsedDuration_ = block.timestamp - yieldStart_;
        uint256 totalDuration_   = yieldDeadline - yieldStart_;

        if (totalDuration_ == 0 || elapsedDuration_ >= totalDuration_) return scheduledYieldAssets_;

        realizedYield_ = scheduledYieldAssets_ * elapsedDuration_ / totalDuration_;
    }

    function securityAdmin() public view override returns (address securityAdmin_) {
        securityAdmin_ = IGlobalsLike(globals()).securityAdmin();
    }

    function strategyDelegate() public view override returns (address strategyDelegate_) {
        strategyDelegate_ = IStrategyManagerLike(strategyManager).strategyDelegate();
    }

    function unrecordedAssets() public view override returns (uint256 unrecordedAssets_) {
        uint256 balance_ = IERC20Like(fundsAsset).balanceOf(address(this));

        unrecordedAssets_ = balance_ > recordedAssets ? balance_ - recordedAssets : 0;
    }

    function unrealizedLosses() public view override returns (uint256 unrealizedLosses_) {
        unrealizedLosses_ = _min(impairedAssets, assetsUnderManagement());
    }

    function unrealizedYield() public view override returns (uint256 unrealizedYield_) {
        unrealizedYield_ = scheduledYieldAssets - realizedYield();
    }

    function yieldCooldown() public view override returns (uint256 cooldown_) {
        uint256 cooldownEnd_ = yieldLastRealized + REALIZE_YIELD_COOLDOWN;

        if (block.timestamp < cooldownEnd_) cooldown_ = cooldownEnd_ - block.timestamp;
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
            require(ERC20Helper.transfer(fundsAsset_, strategyDelegate(), delegateFee_), "MAS:CF:DELEGATE_TRANSFER_FAILED");
        }

        if (protocolFee_ != 0) {
            require(ERC20Helper.transfer(fundsAsset_, mapleTreasury(), protocolFee_), "MAS:CF:PROTOCOL_TRANSFER_FAILED");
        }
    }

    function _min(uint256 a_, uint256 b_) internal pure returns (uint256 min_) {
        min_ = a_ < b_ ? a_ : b_;
    }

    function _removeImpairment(uint256 assets_) internal {
        require(assets_ > 0,               "MAS:RI:ZERO_ASSETS");
        require(assets_ <= impairedAssets, "MAS:RI:EXCEEDS_IMPAIRMENT");

        impairedAssets -= assets_;

        emit ImpairmentRemoved(assets_);
    }

    function _recognizeLoss(uint256 assets_, address deployer_) internal {
        require(assets_ != 0,                           "MAS:RL:ZERO_ASSETS");
        require(assets_ <= deployedAssetsOf[deployer_], "MAS:RL:EXCEEDS_DEPLOYED");

        totalDeployedAssets         -= assets_;
        deployedAssetsOf[deployer_] -= assets_;

        emit LossRecognized(msg.sender, deployer_, assets_);
    }

}
