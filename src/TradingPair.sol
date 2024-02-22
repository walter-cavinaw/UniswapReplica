// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import {Ownable2Step} from "openzeppelin-contracts/contracts/access/Ownable2Step.sol";
import {IERC20} from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";
import {IERC3156FlashLender} from "openzeppelin-contracts/contracts/interfaces/IERC3156FlashLender.sol";
import {IERC3156FlashBorrower} from "openzeppelin-contracts/contracts/interfaces/IERC3156FlashBorrower.sol";
import {ITradingPair} from "./interfaces/ITradingPair.sol";
import {ERC20} from "solady/tokens/ERC20.sol";
import {FixedPointMathLib} from "solady/utils/FixedPointMathLib.sol";
import "./utils/UQ112x112.sol";
import "forge-std/console.sol";

/**
 * @title AMM Trading Pair
 * @author Walter Cavinaw
 * @notice An AMM for Token Pair Liquidity
 */
contract TradingPair is Ownable2Step, ITradingPair, ERC20 {
    using SafeERC20 for IERC20;
    using UQ112x112 for uint224;

    // store the token addresses for the LP Pair
    IERC20 public token0;
    IERC20 public token1;
    string private _name;

    // minimum liquidity to burn to avoid inflation attack
    uint256 public constant MINIMUM_LIQUIDITY = 10 ** 3;

    // store reserves as smaller ints to do floating point division
    // when we track cumulative price indices
    uint112 private reserve0;
    uint112 private reserve1;
    uint256 private blockTimestampLast;

    uint256 public price0CumulativeLast;
    uint256 public price1CumulativeLast;
    uint256 public kLast; // reserve0 * reserve1 from previous event used for fees

    uint256 public constant TRADING_FEE_BPS = 30;
    uint256 public constant FLASH_LOAN_FEE_BPS = 10;
    uint256 public constant FLASH_LOAN_SIZE_LIMIT_PCT = 10;

    event Deposit(address indexed sender, uint256 amount0, uint256 amount1, uint256 lpTokens);
    event Withdrawal(address indexed sender, uint256 amount0, uint256 amount1);
    event Swap(address indexed sender, uint256 amount0In, uint256 amount1In, uint256 amount0Out, uint256 amount1Out);

    /**
     * @notice creates a new AMM trading pair
     * @param token0_ the address of token A contract
     * @param token1_ the address of token B contract
     * @param name_ the name of the pair
     */
    constructor(address token0_, address token1_, string memory name_) {
        token0 = IERC20(token0_);
        token1 = IERC20(token1_);
        _name = name_;
    }

    /**
     * @notice get address of the 'first' token
     */
    function getToken0() external view returns (address) {
        return address(token0);
    }

    /**
     * @notice get address of the 'second' token
     */
    function getToken1() external view returns (address) {
        return address(token1);
    }

    /**
     * @notice get reserves of token0 and token1 in the liquidity pool
     */
    function getReserves() external view returns (uint256, uint256) {
        return (reserve0, reserve1);
    }

    function getPriceIndices() external view returns (uint256, uint256) {
        return (price0CumulativeLast, price1CumulativeLast);
    }

    /**
     * @notice swaps token0 and token1 with slippage protection
     * @param amount0Out How much of token0 is desired.
     * @param amount1Out How much of token1 is desired.
     * @param swapLimit0 The maximum amount of token0 we are willing to trade for desired token1
     * @param swapLimit1 The maximum amount of token1 we are willing to trade for desired token0
     * @dev Can only trade one token at a time. Limits protect user from paying more than expected.
     */
    function swap(uint256 amount0Out, uint256 amount1Out, uint256 swapLimit0, uint256 swapLimit1)
        external
        returns (uint256 amount0In, uint256 amount1In)
    {
        require(amount0Out > 0 || amount1Out > 0, "UniswapReplica: INSUFFICIENT_OUTPUT_AMOUNT");
        require(amount0Out * amount1Out == 0, "UniswapReplica: CANNOT_SWAP_BOTH");
        require(amount0Out < reserve0 && amount1Out < reserve1, "UniswapReplica: INSUFFICIENT_LIQUIDITY");

        // calculate the tokens needed to transfer (plus the trading fee)
        amount0In = amount1Out > 0 ? getAmountIn(amount1Out, reserve0, reserve1) : 0;
        amount1In = amount0Out > 0 ? getAmountIn(amount0Out, reserve1, reserve0) : 0;
        // check that the amount out does not go above the max token tolerance
        require(amount0In <= swapLimit0 && amount1In <= swapLimit1, "UniswapReplica: SLIPPAGE_EXCEEDED");

        uint256 balance0_ = token0.balanceOf(address(this));
        uint256 balance1_ = token1.balanceOf(address(this));

        _updateState(balance0_, balance1_, reserve0, reserve1);

        emit Swap(msg.sender, amount0In, amount1In, amount0Out, amount1Out);

        // transfer the amount in. Requires the allowance to be set. Will revert with insufficient funds.
        if (amount0In > 0) token0.safeTransferFrom(msg.sender, address(this), amount0In);
        if (amount1In > 0) token1.safeTransferFrom(msg.sender, address(this), amount1In);

        // transfer the received tokens out.
        if (amount0Out > 0) token0.safeTransfer(msg.sender, amount0Out);
        if (amount1Out > 0) token1.safeTransfer(msg.sender, amount1Out);
    }

    /**
     * @notice Flash loan for pool tokens
     * @param receiver Which contract to call for 'onFlashLoan' callback.
     * @param token which token in the pool to get a loan for.
     * @param amount loan amount.
     * @dev flash loan size limited to 10% of the token reserve
     */
    function flashLoan(IERC3156FlashBorrower receiver, address token, uint256 amount, bytes calldata data)
        external
        returns (bool)
    {
        require(token == address(token0) || token == address(token1), "UniswapReplica: INCORRECT_TOKEN_ADDRESS");
        require(amount <= this.maxFlashLoan(token), "UniswapReplica: FLASH_LOAN_TOO_LARGE");

        // transfer tokenAmount to receiver and trigger onFlashLoan
        uint256 fee = this.flashFee(token, amount);
        SafeERC20.safeTransfer(IERC20(token), address(receiver), amount);
        receiver.onFlashLoan(msg.sender, token, amount, fee, data);
        SafeERC20.safeTransferFrom(IERC20(token), address(receiver), address(this), amount + fee);
        return true;
    }

    /**
     * @notice Flash loan for pool tokens
     * @param token Which token does the fee refer to.
     * @param amount hypothetical loan amount to calculate fee for.
     * @dev fee is set via BPS relative to loan size (at 10 BPS)
     */
    function flashFee(address token, uint256 amount) external view returns (uint256) {
        require(token == address(token0) || token == address(token1), "UniswapReplica: INCORRECT_TOKEN_ADDRESS");
        if (token == address(token0)) {
            return FLASH_LOAN_FEE_BPS * amount / 10_000;
        } else {
            return FLASH_LOAN_FEE_BPS * amount / 10_000;
        }
    }

    /**
     * @notice Flash loan for pool tokens
     * @param token Which token does the limit apply to.
     */
    function maxFlashLoan(address token) external view returns (uint256) {
        // restrict the flashLoanAmount to some percentage of the pool size
        require(token == address(token0) || token == address(token1), "UniswapReplica: INCORRECT_TOKEN_ADDRESS");
        if (token == address(token0)) {
            return FLASH_LOAN_SIZE_LIMIT_PCT * reserve0 / 100;
        } else {
            return FLASH_LOAN_SIZE_LIMIT_PCT * reserve1 / 100;
        }
    }

    /**
     * @notice Deposit tokens to pool in exchange for LP tokens.
     * @param maxToken0 Maximum amount of token0 to deposit.
     * @param maxToken1 Maximum amount of token1 to deposit.
     * @param minToken0 Minimum amount of token0 to deposit. protects against unexpected changes.
     * @param minToken1 Minimum amount of token1 to deposit. protects against unexpected changes.
     * @dev the range parameters protect the user from slippage.
     */
    function deposit(uint256 maxToken0, uint256 maxToken1, uint256 minToken0, uint256 minToken1)
        external
        returns (uint256 lpTokens)
    {
        // add checks
        require(maxToken0 > 0 && maxToken1 > 0, "UniswapReplica: INSUFFICIENT_LIQUIDITY_OFFERED");
        // get the value for token0 and token1 which enables transfering the most in proportion.
        (uint256 amount0, uint256 amount1) = _calcDepositAmounts(maxToken0, maxToken1, minToken0, minToken1);

        token0.safeTransferFrom(msg.sender, address(this), amount0);
        token1.safeTransferFrom(msg.sender, address(this), amount1);

        uint256 liquidity = 0;

        // bool feeOn = _mintFee(_reserve0, _reserve1);
        uint256 _totalSupply = totalSupply();
        if (_totalSupply == 0) {
            liquidity = FixedPointMathLib.sqrt(amount0 * amount1) - MINIMUM_LIQUIDITY;
            _mint(address(0), MINIMUM_LIQUIDITY); // permanently lock the first MINIMUM_LIQUIDITY tokens
        } else {
            liquidity = FixedPointMathLib.min((amount0 * _totalSupply) / reserve0, (amount1 * _totalSupply) / reserve1);
        }
        require(liquidity > 0, "UniswapReplica: INSUFFICIENT_LIQUIDITY_MINTED");
        _mint(msg.sender, liquidity);

        uint256 balance0_ = token0.balanceOf(address(this));
        uint256 balance1_ = token1.balanceOf(address(this));

        _updateState(balance0_, balance1_, reserve0, reserve1);
        // if (feeOn) kLast = uint256(reserve0).mul(reserve1); // reserve0 and reserve1 are up-to-date
        emit Deposit(msg.sender, amount0, amount1, liquidity);
        return liquidity;
    }

    /**
     * @notice Exchange pool tokens for LP tokens.
     * @param withdrawal How many LP tokens to redeem.
     * @dev returns the amount of each token we receive.
     */
    function withdraw(uint256 withdrawal) external returns (uint256 amount0, uint256 amount1) {
        require(withdrawal > 0, "UniswapReplica: NO_WITHDRAWAL_AMOUNT");
        uint256 senderBalance = balanceOf(msg.sender);
        require(withdrawal <= senderBalance, "UniswapReplica: INSUFFICIENT_BALANCE");
        uint256 balance0 = token0.balanceOf(address(this));
        uint256 balance1 = token1.balanceOf(address(this));

        uint256 _totalSupply = totalSupply();

        amount0 = withdrawal * balance0 / _totalSupply;
        amount1 = withdrawal * balance1 / _totalSupply;

        require(amount0 > 0 && amount1 > 0, "UniswapV2: INSUFFICIENT_LIQUIDITY_BURNED");

        emit Withdrawal(msg.sender, amount0, amount1);

        _burn(msg.sender, withdrawal);

        token0.safeTransfer(msg.sender, amount0);
        token1.safeTransfer(msg.sender, amount1);

        balance0 = token0.balanceOf(address(this));
        balance1 = token1.balanceOf(address(this));

        _updateState(balance0, balance1, reserve0, reserve1);
    }

    /**
     * @notice get name of the LP pair
     */
    function name() public view override returns (string memory) {
        return _name;
    }

    /**
     * @notice get symbol of the LP pair
     */
    function symbol() public view override returns (string memory) {
        return _name;
    }

    // given an output amount of an asset and pair reserves, returns a required input amount of the other asset
    function getAmountIn(uint256 amountOut, uint256 reserveIn, uint256 reserveOut)
        internal
        pure
        returns (uint256 amountIn)
    {
        require(amountOut > 0, "UniswapReplica: INSUFFICIENT_REQUESTED_AMOUNT");
        require(reserveIn > 0 && reserveOut > 0, "UniswapReplica: INSUFFICIENT_LIQUIDITY");
        uint256 numerator = reserveIn * amountOut * 10_000;
        uint256 denominator = (reserveOut - amountOut) * (10_000 - TRADING_FEE_BPS);
        amountIn = (numerator / denominator) + 1;
    }

    /**
     * @notice Calculates the deposit amounts given an acceptable range
     * @param maxToken0 Maximum amount of token0 to deposit.
     * @param maxToken1 Maximum amount of token1 to deposit.
     * @param minToken0 Minimum amount of token0 to deposit. protects against unexpected changes.
     * @param minToken1 Minimum amount of token1 to deposit. protects against unexpected changes.
     */
    function _calcDepositAmounts(uint256 maxToken0, uint256 maxToken1, uint256 minToken0, uint256 minToken1)
        private
        view
        returns (uint256 amount0, uint256 amount1)
    {
        if (reserve0 == 0 && reserve1 == 0) {
            (amount0, amount1) = (maxToken0, maxToken1);
        } else {
            uint256 amount1Optimal = maxToken0 * reserve1 / reserve0;
            if (amount1Optimal <= maxToken1) {
                require(amount1Optimal >= minToken1, "UniswapReplica: INSUFFICIENT_AMOUNT_TOKEN_1");
                (amount0, amount1) = (maxToken0, amount1Optimal);
            } else {
                uint256 amount0Optimal = maxToken1 * reserve0 / reserve1;
                assert(amount0Optimal <= maxToken0);
                require(amount0Optimal >= minToken0, "UniswapReplica: INSUFFICIENT_AMOUNT_TOKEN_0");
                (amount0, amount1) = (amount0Optimal, maxToken1);
            }
        }
    }

    /**
     * @notice update the reserves and price indices with each swap/deposit/withdrawal
     */
    function _updateState(uint256 balance0_, uint256 balance1_, uint112 reserve0_, uint112 reserve1_) private {
        // update the cumulative price indices
        uint256 timeElapsed = block.timestamp - blockTimestampLast;
        if (reserve0_ > 0 && reserve1_ > 0) {
            unchecked {
                price0CumulativeLast += uint256(UQ112x112.encode(reserve1_).uqdiv(reserve0_)) * timeElapsed;
                price1CumulativeLast += uint256(UQ112x112.encode(reserve0_).uqdiv(reserve1_)) * timeElapsed;
            }
        }
        // update the reserves from the token balances
        reserve0 = uint112(balance0_);
        reserve1 = uint112(balance1_);
        blockTimestampLast = block.timestamp;
    }
}
