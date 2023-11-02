// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

interface IPairFactory {
    event PairCreated(address indexed tokenA, address indexed tokenB, address pair, uint256);

    function getPair(address tokenA, address tokenB) external view returns (address pair);
    function createPair(address tokenA, address tokenB) external returns (address pair);
}
