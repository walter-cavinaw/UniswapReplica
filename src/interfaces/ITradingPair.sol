// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import {IERC3156FlashLender} from "openzeppelin-contracts/contracts/interfaces/IERC3156FlashLender.sol";
import {IERC20} from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";

interface ITradingPair is IERC3156FlashLender, IERC20 {
    function swap(uint256 amount0Out, uint256 amount1Out, uint256 swapLimit0, uint256 swapLimit1)
        external
        returns (uint256 amount0In, uint256 amount1In);
    function deposit(uint256 maxToken0, uint256 maxToken1, uint256 minToken0, uint256 minToken1)
        external
        returns (uint256 lpTokens);
    function withdraw(uint256 withdrawal) external returns (uint256 token0Amount, uint256 token1Amount);
    function getToken0() public view returns (address);
    function getToken1() public view returns (address);
}
