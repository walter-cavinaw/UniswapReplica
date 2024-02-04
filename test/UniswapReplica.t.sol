// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import {Test} from "forge-std/Test.sol";
import "forge-std/console.sol";
import {PairFactory} from "../src/PairFactory.sol";
import {TradingPair} from "../src/TradingPair.sol";
import {ERC20} from "openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";

contract UniswapReplicaTest is Test {
    address internal _alice;
    PairFactory internal _factory;
    ERC20 internal _tokenA;
    ERC20 internal _tokenB;
    ERC20 internal _tokenC;

    function setUp() public {
        _alice = address(1);

        _factory = new PairFactory();

        _tokenA = new ERC20("A", "Token A");
        _tokenB = new ERC20("B", "Token B");
        _tokenC = new ERC20("C", "Token C");
    }

    function testCreateTradingPair() public {
        revert();
    }

    function testSwapGivesOtherToken() public {
        revert();
    }

    function testDepositCreatesLPToken() public {
        revert();
    }

    function testOraclePrice() public {
        revert();
    }

    function testPreventReentrency() public {
        revert();
    }

    function testFlashLoan() public {
        revert();
    }

    function testLPWithdrawalAmount() public {
        revert();
    }
}
