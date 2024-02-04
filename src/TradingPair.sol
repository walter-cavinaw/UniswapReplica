// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import {Ownable2Step} from "openzeppelin-contracts/contracts/access/Ownable2Step.sol";
import {ITradingPair} from "./interfaces/ITradingPair.sol";

/**
 * @title AMM Trading Pair
 * @author Walter Cavinaw
 * @notice An AMM for Pair Liquidity
 */
contract TradingPair is Ownable2Step, ITradingPair {
    address _token0;
    address _token1;

    constructor(address token0, address token1) {}

    function swap(uint256 token0Amount, uint256 token1Amount) external returns (bool success) {
        return false;
    }

    function deposit(uint256 token0Amount, uint256 token1Amount) external returns (uint256 lpTokens) {
        return 0;
    }

    function withdraw() external returns (bool success, uint256 token0Amount, uint256 token1Amount) {
        success = false;
        token0Amount = 0;
        token1Amount = 0;
    }
}
