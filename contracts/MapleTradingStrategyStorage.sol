// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import { IMapleTradingStrategyStorage } from "./interfaces/IMapleTradingStrategyStorage.sol";

contract MapleTradingStrategyStorage is IMapleTradingStrategyStorage {

    bool transient internal _locked;  // Used as a reentrancy guard.

    address public override manager;

}
