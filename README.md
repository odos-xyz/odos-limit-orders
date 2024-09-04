# Odos Limit Order Smart Contract

## Summary

This product allows users to place orders that will be executed at a specified limit price. Orders are placed gaslessly via signed EIP-712 data, and support multiple inputs and multiple outputs.

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

## Deployment Addresses

| Chain | Limit Order Router Address |
| :-: | :-: |
| <img src="https://assets.odos.xyz/chains/optimism.png" width="50" height="50"><br>Optimism | [`0xafF142fBc8FA5B1885FE54E4C889985F8a579b24`](https://optimistic.etherscan.io/address/0xafF142fBc8FA5B1885FE54E4C889985F8a579b24) |
| <img src="https://assets.odos.xyz/chains/mantle.png" width="50" height="50"><br>Mantle | [`0x51Ea3db8b67462b0A66b3F1fF50cA87C076Acc7a`](https://mantlescan.xyz/address/0x51Ea3db8b67462b0A66b3F1fF50cA87C076Acc7a) |
| <img src="https://assets.odos.xyz/chains/base.png" width="50" height="50"><br>Base | [`0x8c8c3E8465B911186aDeC83a53C7De8c587eDDaB`](https://basescan.org/address/0x8c8c3E8465B911186aDeC83a53C7De8c587eDDaB) |
| <img src="https://assets.odos.xyz/chains/mode.png" width="50" height="50"><br>Mode | [`0x65005f4Bea4005D48eE9Bdaae960832c6CECC557`](https://explorer.mode.network/address/0x65005f4Bea4005D48eE9Bdaae960832c6CECC557) |
| <img src="https://assets.odos.xyz/chains/arbitrum.png" width="50" height="50"><br>Arbitrum | [`0x83564b903c0311877accEE8f99e6BEb712AD8E43`](https://arbiscan.io/address/0x83564b903c0311877accEE8f99e6BEb712AD8E43) |

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
solc-select install 0.8.19
export SOLC_VERSION=0.8.19
myth analyze contracts/OdosLimitOrderRouter.sol --solc-json ./mythril.config.json
```

## Audit

This contract was audited by [Halborn](https://www.halborn.com/) in April 2024. A link to the report can be found on the [Halborn Website](https://www.halborn.com/audits/odos/limit-orders). A copy of the report is included on this page.
