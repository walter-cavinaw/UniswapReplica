// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import {Ownable2Step} from "openzeppelin-contracts/contracts/access/Ownable2Step.sol";
import {IPairFactory} from "./interfaces/IPairFactory.sol";
import {TradingPair} from "./TradingPair.sol";
import {ERC20} from "solady/tokens/ERC20.sol";
import {IERC20} from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";

/**
 * @title Factory for AMM Pairs
 * @author Walter Cavinaw
 * @notice A factory for creating AMM Liquidity Pairs
 * @dev Factory owner can create a new contract which uses AMM to allow trading pairs
 */
contract PairFactory is Ownable2Step, IPairFactory {
    struct TradingPairInfo {
        IERC20 tokenA;
        IERC20 tokenB;
        address liquidityPair;
    }

    mapping(bytes32 => TradingPairInfo) _tradingPairs;

    /**
     * @notice returns the address of the AMM for the trading pair
     * @param tokenA the address of token A contract
     * @param tokenB the address of token B contract
     * @dev should throw an error if the pair is not available
     */
    function getPair(address tokenA, address tokenB) external view returns (address pairAddress) {
        (address token0, address token1) = tokenA < tokenB ? (tokenA, tokenB) : (tokenB, tokenA);
        bytes32 pairHash = keccak256(abi.encodePacked(token0, token1));
        TradingPairInfo memory pairInfo = _tradingPairs[pairHash];
        require(pairInfo.liquidityPair != address(0), "UniswapReplica: PAIR_DOES_NOT_EXIST");
        return pairInfo.liquidityPair;
    }

    /**
     * @notice creates a new AMM trading pair
     * @dev creates a new AMM for the pair if it does not already exist
     */
    function createPair(address tokenA, address tokenB) external returns (address pair) {
        // check that pair does not already exist
        require(tokenA != tokenB, "tokens in pair must be different");
        // order the token addresses
        (address token0, address token1) = tokenA < tokenB ? (tokenA, tokenB) : (tokenB, tokenA);

        // create a hash of the encoding
        bytes32 pairHash = keccak256(abi.encodePacked(token0, token1));
        // ensure it doesn't already exist
        TradingPairInfo memory pairInfo;
        pairInfo = _tradingPairs[pairHash];
        require(pairInfo.liquidityPair == address(0), "UniswapReplica: PAIR_ALREADY_EXIST");
        // create the new contract
        string memory symbol0 = ERC20(token0).symbol();
        string memory symbol1 = ERC20(token1).symbol();
        TradingPair liquidityPair = new TradingPair(address(token0), address(token1), string.concat(symbol0, symbol1));
        pairInfo.tokenA = IERC20(token0);
        pairInfo.tokenB = IERC20(token1);
        pairInfo.liquidityPair = address(liquidityPair);
        // map the hash to the new pair contract address
        _tradingPairs[pairHash] = pairInfo;
        // return the pair contract address
        return address(liquidityPair);
    }
}
