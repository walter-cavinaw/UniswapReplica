// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import {Test} from "forge-std/Test.sol";
import "forge-std/console.sol";
import {PairFactory} from "../src/PairFactory.sol";
import {TradingPair} from "../src/TradingPair.sol";
import {IERC20} from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {TestToken} from "./TestToken.sol";

contract UniswapReplicaTest is Test {
    address internal alice;
    address internal bob;
    TradingPair internal ABpair;
    address internal ABpairAddr;
    PairFactory internal factory;
    TestToken internal tokenA;
    TestToken internal tokenB;
    TestToken internal tokenC;

    function setUp() public {
        alice = makeAddr("alice");
        bob = makeAddr("bob");

        factory = new PairFactory();

        tokenA = new TestToken("A", "Token A");
        tokenB = new TestToken("B", "Token B");
        tokenC = new TestToken("C", "Token C");

        ABpair = TradingPair(factory.createPair(address(tokenA), address(tokenB)));
        ABpairAddr = address(ABpair);

        tokenA.mint(alice, 1e10);
        tokenB.mint(alice, 1e10);
        vm.startPrank(alice);
        tokenA.approve(ABpairAddr, 1e10);
        tokenB.approve(ABpairAddr, 1e10);
        vm.stopPrank();

        tokenA.mint(bob, 1e10);
        //tokenB.mint(bob, 1e3);
    }

    function testCreateTradingPair() public {
        address createdPair = factory.createPair(address(tokenA), address(tokenC));
        address retrievedPair = factory.getPair(address(tokenA), address(tokenC));
        assertEq(createdPair, retrievedPair);
    }

    function testPairDoesntExist() public {
        vm.expectRevert("UniswapReplica: PAIR_DOES_NOT_EXIST");
        factory.getPair(address(tokenA), address(tokenC));
    }

    function testPairAlreadyExist() public {
        vm.expectRevert("UniswapReplica: PAIR_ALREADY_EXIST");
        factory.createPair(address(tokenA), address(tokenB));
    }

    function testCannotSwapBoth() public {
        vm.startPrank(alice);
        vm.expectRevert("UniswapReplica: CANNOT_SWAP_BOTH");
        ABpair.swap(2, 2, 2, 2);
    }

    function testSwapGivesOtherToken() public {
        vm.prank(alice);
        ABpair.deposit(1e7, 1e5, 0, 0);
        uint256 bobStartBal0 = tokenA.balanceOf(bob);
        uint256 bobStartBal1 = tokenB.balanceOf(bob);
        vm.startPrank(bob);
        tokenA.approve(ABpairAddr, 1e10);
        (uint256 token0Taken, uint256 token1Taken) = ABpair.swap(0, 1e3, 2e5, 0);
        vm.stopPrank();
        uint256 bobEndingBal0 = tokenA.balanceOf(bob);
        uint256 bobEndingBal1 = tokenB.balanceOf(bob);
        assertEq(1e3, bobEndingBal1 - bobStartBal1);
        assertGt(token0Taken / 1e3, 1e2);
    }

    function testSwapLimitExceeded() public {
        vm.prank(alice);
        ABpair.deposit(1e7, 1e5, 0, 0);
        uint256 bobStartBal0 = tokenA.balanceOf(bob);
        uint256 bobStartBal1 = tokenB.balanceOf(bob);
        vm.startPrank(bob);
        tokenA.approve(ABpairAddr, 1e10);
        vm.expectRevert("UniswapReplica: SLIPPAGE_EXCEEDED");
        ABpair.swap(0, 1e3, 1e5, 0);
        vm.stopPrank();
    }

    function testDepositCreatesLPToken() public {
        vm.startPrank(alice);
        uint256 liquidityTokens = ABpair.deposit(1e5, 1e3, 1, 1);
        assertGt(liquidityTokens, 0);
        uint256 registeredLiquidityTokens = ABpair.balanceOf(alice);
        assertEq(liquidityTokens, registeredLiquidityTokens);
        assertEq(liquidityTokens, 1e4 - 1e3);
    }

    function testDepositRemovesTokensCorrectly() public {
        uint256 aliceStartingBalA = tokenA.balanceOf(alice);
        uint256 aliceStartingBalB = tokenB.balanceOf(alice);
        vm.startPrank(alice);
        uint256 liquidityTokens = ABpair.deposit(1e4, 1e3, 1, 1);
        uint256 aliceEndingBalA = tokenA.balanceOf(alice);
        uint256 aliceEndingBalB = tokenB.balanceOf(alice);
        assertEq(aliceStartingBalA - aliceEndingBalA, 1e4);
        assertEq(aliceStartingBalB - aliceEndingBalB, 1e3);
    }

    function testDepositAfterFirstDeposit() public {
        vm.startPrank(alice);
        tokenA.approve(ABpairAddr, 1e10);
        tokenB.approve(ABpairAddr, 1e10);
        ABpair.deposit(1e5, 1e3, 1, 1);
        (uint256 reserve0, uint256 reserve1) = ABpair.getReserves();
        uint256 tokenSupply = ABpair.totalSupply();
        uint256 liquidityTokens = ABpair.deposit(1e4, 1e4, 1, 1);
        assertEq(liquidityTokens, 1e4 * tokenSupply / reserve0);
    }

    function testDepositInsufficientToken1() public {
        vm.startPrank(alice);
        tokenA.approve(ABpairAddr, 1e10);
        tokenB.approve(ABpairAddr, 1e10);
        ABpair.deposit(1e5, 1e3, 1, 1);
        vm.expectRevert("UniswapReplica: INSUFFICIENT_AMOUNT_TOKEN_1");
        uint256 liquidityTokens = ABpair.deposit(1e4, 1e4, 1e4, 1e4);
    }

    function testDepositInsufficientToken0() public {
        vm.startPrank(alice);
        tokenA.approve(ABpairAddr, 1e10);
        tokenB.approve(ABpairAddr, 1e10);
        ABpair.deposit(1e5, 1e3, 1, 1);
        vm.expectRevert("UniswapReplica: INSUFFICIENT_AMOUNT_TOKEN_0");
        uint256 liquidityTokens = ABpair.deposit(1e4, 1e1, 1e4, 1);
    }

    function testLPWithdrawalAmount() public {
        vm.startPrank(alice);
        tokenA.approve(ABpairAddr, 1e10);
        tokenB.approve(ABpairAddr, 1e10);
        uint256 liquidity = ABpair.deposit(1e5, 1e3, 1, 1);
        (uint256 amount0, uint256 amount1) = ABpair.withdraw(liquidity);
        assertGt(amount0, amount1);
        assertEq(amount0, 90000);
    }

    function testOraclePrice() public {
        revert();
    }

    function testFlashLoan() public {
        revert();
    }
}
