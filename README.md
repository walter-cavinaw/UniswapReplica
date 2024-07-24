## Uniswap Replica

The src/PairFactory.sol and src/TradingPair.sol contracts replicate the basic functionality of Uniswap.

It is assumed the deposit, withdraw and swap functions are called from EOA, and have built in slippage protection.

The deposit function adds token liquidity in exchange for LP tokens. The withdraw functions burns LP tokens in exchange for pool tokens.

The swap function trades one token for the other. It protects from slippage by specifying the maximum amount of the offered token to swap.

## Using the TWAP Oracle

1. Cumulative price indices allow the user to determine TWAP by taking a beginning and ending snapshot and using the difference in the cumulative index between these snapshots to calculate the TWAP over that time period (by dividng the difference by the time that has elapsed.)
2. These cumulative indices have to be stored differently for price0 and price1, becuase there is no equivalency between the sum of reciprocals and the reciprocals of a sum. E.g. 1/(1+2) does not equal 1/1 + 1/2. It's possible to use the same ratio for each price if we used a geometric average rather than a arithmetic average over time.

## Flaws / Future improvements
1. handle fee on transfer tokens.