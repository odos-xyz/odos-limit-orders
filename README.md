# Odos Limit Order Smart Contract

### Limit order execution flow

1. Check if msg.sender is allowed 
2. Check if order still valid 
3. Check tokens, amounts
4. Get order hash
5. Recover order owner account [and validate the signature]
6. Extract previously filled amounts for order from storage, or create
7. Check if fill possible:
  - If partiallyFillable, total amount do not exceed
  - If not partiallyFillable - it was not filled previously
8. Transfer tokens from order owner
9. Update order filled amounts in storage
10. Get output token balances before
11. Execute path with the OdosExecutor
12. Get output token balances difference
13. Calculate and transfer referral fee if any
14. Check slippage, adjust amountOut
15. Check surplus
16. Transfer tokens to order owner account
17. Emit LimitOrderFilled (MultiLimitOrderFilled) event



## Smart Contracts

### Build

```shell
forge build
```

### Test

```shell
forge test
```

Test the EIP-712 hash generation to ensure that the Solidity hash is generated correctly.

```shell
cd test/eip712test
chmod +x ./runTest.sh
./runTest.sh
```

### Gas report

```shell
forge test --gas-report
```

### Linter

```
npm install -g solhint
solhint 'contracts/*.sol' 'interfaces/*.sol'
```

### Coverage

```shell
forge coverage --report lcov
genhtml -o report lcov.info
```

Then open the `report/index.html` in the browser.


### Audit tools

Install [Mythril](https://github.com/Consensys/mythril)

```shell
myth analyze contracts/OdosLimitOrderRouter.sol --solc-json ./mythril.config.json
```
