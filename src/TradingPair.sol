// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import {Ownable2Step} from "openzeppelin-contracts/contracts/access/Ownable2Step.sol";
import {IERC20} from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";
import {IERC3156FlashLender} from "openzeppelin-contracts/contracts/interfaces/IERC3156FlashLender.sol";
import {ITradingPair} from "./interfaces/ITradingPair.sol";
import {ERC20} from "solady/tokens/ERC20.sol";
import {FixedPointMathLib} from "solady/utils/FixedPointMathLib.sol";

/**
 * @title AMM Trading Pair
 * @author Walter Cavinaw
 * @notice An AMM for Token Pair Liquidity
 */
contract TradingPair is Ownable2Step, ITradingPair, ERC20 {
    using SafeERC20 for IERC20;

    IERC20 public token0;
    IERC20 public token1;
    string private _name;

    uint256 public constant MINIMUM_LIQUIDITY = 10 ** 3;

    uint256 private reserve0;
    uint256 private reserve1;
    uint256 private blockTimestampLast;

    uint256 public price0CumulativeLast;
    uint256 public price1CumulativeLast;
    uint256 public kLast; // reserve0 * reserve1 from previous event used for fees

    uint256 constant TRADING_FEE_BPS = 30;

    event Deposit(address indexed sender, uint256 amount0, uint256 amount1, uint256 lpTokens);
    event Withdrawal(address indexed sender, uint256 amount0, uint256 amount1);
    event Swap(address indexed sender, uint256 amount0In, uint256 amount1In, uint256 amount0Out, uint256 amount1Out);

    constructor(address token0_, address token1_, string memory name_) {
        token0 = IERC20(token0_);
        token1 = IERC20(token1_);
        _name = name_;
    }

    function name() public view override returns (string memory) {
        return _name;
    }

    function symbol() public view override returns (string memory) {
        return _name;
    }

    function getToken0() public view returns (address) {
        return address(token0);
    }

    function getToken1() public view returns (address) {
        return address(token1);
    }

    function getReserves() public view returns (uint256, uint256) {
        return (reserve0, reserve1);
    }

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

    function _updateState(uint256 balance0_, uint256 balance1_, uint256 reserve0_, uint256 reserve1_) private {
        // update the cumulative price indices
        if (reserve0_ > 0 && reserve1_ > 0) {
            uint256 timeElapsed = block.timestamp - blockTimestampLast;
            price0CumulativeLast += FixedPointMathLib.divUp(reserve0_, reserve1_) * timeElapsed;
            price1CumulativeLast += FixedPointMathLib.divUp(reserve1_, reserve0_) * timeElapsed;
        }
        // update the reserves from the token balances
        reserve0 = balance0_;
        reserve1 = balance1_;
        blockTimestampLast = block.timestamp;
    }

    function _mintFeeShareTokens() private {}

    function flashFee(address token, uint256 amount) external view returns (uint256) {
        return 0;
    }

    function maxFlashLoan(address token) external view returns (uint256) {
        // restrict the flashLoanAmount to some percentage of the pool size
        return 0;
    }

    function flashLoan(IERC3156FlashBorrower receiver, address token, uint256 amount, bytes calldata data)
        external
        returns (bool)
    {
        require(token == address(token0) || token == address(token1), "UniswapReplica: INCORRECT_TOKEN_ADDRESS");
        require(amount <= maxFlashLoan(token), "UniswapReplica: FLASH_LOAN_TOO_LARGE");

        // transfer tokenAmount to receiver and trigger onFlashLoan

        return true;
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
}
