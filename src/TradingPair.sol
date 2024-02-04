// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import {Ownable2Step} from "openzeppelin-contracts/contracts/access/Ownable2Step.sol";
import {ITradingPair} from "./interfaces/ITradingPair.sol";
import {ERC20} from "solady/tokens/ERC20.sol";
import {FixedPointMathLib} from "solady/utils/FixedPointMathLib.sol";

/**
 * @title AMM Trading Pair
 * @author Walter Cavinaw
 * @notice An AMM for Pair Liquidity
 */
contract TradingPair is Ownable2Step, ITradingPair, ERC20 {
    using FixedPointMathLib for uint256;

    address private _token0;
    address private _token1;
    string private _name;

    constructor(address token0_, address token1_, string memory name_) {
        _token0 = token0_;
        _token1 = token1_;
        _name = name_;
    }

    function name() public view override returns (string memory) {
        return _name;
    }

    function symbol() public view override returns (string memory) {
        return _name;
    }

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
