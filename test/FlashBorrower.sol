// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import {ITradingPair} from "../src/interfaces/ITradingPair.sol";
import {IERC20} from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";
import {IERC3156FlashBorrower} from "openzeppelin-contracts/contracts/interfaces/IERC3156FlashBorrower.sol";

contract TestFlashBorrower is IERC3156FlashBorrower {
    using SafeERC20 for IERC20;

    ITradingPair private _tradingPair;

    event Borrowed(address initiator, address token, uint256 amount, uint256 fee);

    constructor(address tradingPair) {
        _tradingPair = ITradingPair(tradingPair);
    }

    function triggerBorrow(uint256 amount, address tokenToBorrow) external {
        _tradingPair.flashLoan(IERC3156FlashBorrower(this), tokenToBorrow, amount, "");
    }

    function onFlashLoan(address initiator, address token, uint256 amount, uint256 fee, bytes calldata data)
        external
        returns (bytes32)
    {
        // do some activity with the funds...
        emit Borrowed(initiator, token, amount, fee);
        // now send the borrowed amount back to the lender.
        SafeERC20.safeTransfer(IERC20(token), initiator, amount + fee);
        return keccak256("ERC3156FlashBorrower.onFlashLoan");
    }
}
