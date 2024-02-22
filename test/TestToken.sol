// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import {ERC20} from "solady/tokens/ERC20.sol";

contract TestToken is ERC20 {
    string public _symbol;
    string public _name;

    constructor(string memory name_, string memory symbol_) {
        _name = name_;
        _symbol = symbol_;
    }

    function symbol() public view override returns (string memory) {
        return _symbol;
    }

    function name() public view override returns (string memory) {
        return _name;
    }

    function mint(address to, uint256 amount) public {
        _mint(to, amount);
    }
}
