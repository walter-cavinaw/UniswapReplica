// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import {Ownable2Step} from "openzeppelin-contracts/contracts/access/Ownable2Step.sol";

/**
 * @title Factory for AMM Pairs
 * @author Walter Cavinaw
 * @notice A factory for creating AMM Liquidity Pairs
 * @dev Factory owner can create a new contract which uses AMM to allow trading pairs
 */
contract NFTCollateralBank is Ownable2Step {
    using SafeERC20 for StakingReward;
}
