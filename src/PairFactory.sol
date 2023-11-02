// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import {Ownable2Step} from "openzeppelin-contracts/contracts/access/Ownable2Step.sol";
import {IPairFactory} from "./interfaces/IPairFactory.sol";

/**
 * @title Factory for AMM Pairs
 * @author Walter Cavinaw
 * @notice A factory for creating AMM Liquidity Pairs
 * @dev Factory owner can create a new contract which uses AMM to allow trading pairs
 */
contract PairFactory is Ownable2Step, IPairFactory {
    struct TradingPair {
        address tokenA;
        address tokenB;
        address liquidityPair;
    }

    mapping(address => TradingPair) _tradingPairs;

    /**
     * @notice returns the address of the AMM for the trading pair
     * @param tokenA the address of token A contract
     * @param tokenB the address of token B contract
     * @dev should throw an error if the pair is not available
     */
    function getPair(address tokenA, address tokenB) external view returns (address pair) {
        // TODO: order the pairs
        (address token0, address token1) = tokenA < tokenB ? (tokenA, tokenB) : (tokenB, tokenA);
        address pairHash = abi.encodePacked(token0, token1);
        TradingPair pair = _tradingPairs[pairHash];
        require(pair != 0, "pair should exist");
        return pair.liquidityPair;
    }

    /**
     * @notice creates a new AMM trading pair
     * @dev creates a new AMM for the pair if it does not already exist
     */
    function createPair(address tokenA, address tokenB) external returns (address pair) {
        // TODO: check that pair does not already exist

        require(tokenA != tokenB, "tokens in pair must be different");
        // TODO: order the token addresses
        // TODO: create a hash of the encoding
        // TODO: create the new contract
        // TODO: map the hash to the new pair contract address
        // TODO: return the pair contract address
    }
}
