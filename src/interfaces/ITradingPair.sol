// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

interface ITradingPair {
    function swap(uint256 token0amount, uint256 token1Amount) external returns (bool success);
    function deposit(uint256 token0Amount, uint256 token1Amount) external returns (uint256 lpTokens);
    function withdraw() external returns (bool success, uint256 token0Amount, uint256 token1Amount);
}
