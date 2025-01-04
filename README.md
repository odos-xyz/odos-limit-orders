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

## V2 Deployment Addresses

| Chain | Limit Order Router Address |
| :-: | :-: |
| <img src="https://assets.odos.xyz/chains/ethereum.png" width="50" height="50"><br>Ethereum | [`0xC6A5e5b46ea58D2DAdb150c7A53BEC8E7d3326A6`](https://etherscan.io/address/0xC6A5e5b46ea58D2DAdb150c7A53BEC8E7d3326A6) |
| <img src="https://assets.odos.xyz/chains/optimism.png" width="50" height="50"><br>Optimism | [`0x8525E1A0494877aF744E33C5982e9dfBe417B2F8`](https://optimistic.etherscan.io/address/0x8525E1A0494877aF744E33C5982e9dfBe417B2F8) |
| <img src="https://assets.odos.xyz/chains/bnb.png" width="50" height="50"><br>BNB | [`0x5b8A43645A73f8D82f09722A6CA3b65B0Fb092d5`](https://bscscan.com/address/0x5b8A43645A73f8D82f09722A6CA3b65B0Fb092d5) |
| <img src="https://assets.odos.xyz/chains/polygon.png" width="50" height="50"><br>Polygon | [`0xb182Bdd72F0D32C1b0cd191B87530bB1e0e04E28`](https://polygonscan.com/address/0xb182Bdd72F0D32C1b0cd191B87530bB1e0e04E28) |
| <img src="https://assets.odos.xyz/chains/sonic.png" width="50" height="50"><br>Sonic | [`0x64815baaF1230e84416f58D29608a538c52f072e`](https://sonicscan.org/address/0x64815baaF1230e84416f58D29608a538c52f072e) |
| <img src="https://assets.odos.xyz/chains/fantom.png" width="50" height="50"><br>Fantom | [`0x965eb9798c1cC5431c84CA5bCA4b8dae71074C84`](https://ftmscan.com/address/0x965eb9798c1cC5431c84CA5bCA4b8dae71074C84) |
| <img src="https://assets.odos.xyz/chains/fraxtal.png" width="50" height="50"><br>Fraxtal | [`0x168C5348f8f945E14dAaA3077EE397c8B4431F44`](https://fraxscan.com/address/0x168C5348f8f945E14dAaA3077EE397c8B4431F44) |
| <img src="https://assets.odos.xyz/chains/zksync.png" width="50" height="50"><br>zkSync Era | [`0x713BFe68dCb8586D1C2741e7E2a1f2aE5F06159b`](https://era.zksync.network/address/0x713BFe68dCb8586D1C2741e7E2a1f2aE5F06159b) |
| <img src="https://assets.odos.xyz/chains/mantle.png" width="50" height="50"><br>Mantle | [`0xAd2a6508D1f42f5Da43BACF3EA2972aCA609cbD6`](https://mantlescan.xyz/address/0xAd2a6508D1f42f5Da43BACF3EA2972aCA609cbD6) |
| <img src="https://assets.odos.xyz/chains/base.png" width="50" height="50"><br>Base | [`0xB6333E994Fd02a9255E794C177EfBDEB1FE779C7`](https://basescan.org/address/0xB6333E994Fd02a9255E794C177EfBDEB1FE779C7) |
| <img src="https://assets.odos.xyz/chains/mode.png" width="50" height="50"><br>Mode | [`0x3574b916A92102F221Ba270Ea06B39EF174c0E50`](https://explorer.mode.network/address/0x3574b916A92102F221Ba270Ea06B39EF174c0E50) |
| <img src="https://assets.odos.xyz/chains/arbitrum.png" width="50" height="50"><br>Arbitrum | [`0x5e4EC180fA2BaBE43a97E40354fad873D4f2A05F`](https://arbiscan.io/address/0x5e4EC180fA2BaBE43a97E40354fad873D4f2A05F) |
| <img src="https://assets.odos.xyz/chains/avalanche.png" width="50" height="50"><br>Avalanche | [`0xfBb60699757967fa695766E1DdbbC345bFC1f030`](https://snowscan.xyz/address/0xfBb60699757967fa695766E1DdbbC345bFC1f030) |
| <img src="https://assets.odos.xyz/chains/linea.png" width="50" height="50"><br>Linea | [`0x1A616e15f16100fc6C98949d0cCbb76f6F841Ffc`](https://lineascan.build/address/0x1A616e15f16100fc6C98949d0cCbb76f6F841Ffc) |
| <img src="https://assets.odos.xyz/chains/scroll.png" width="50" height="50"><br>Scroll | [`0x27783F3f5B533564412FcfEfB50Ff7aff286B566`](https://scrollscan.com/address/0x27783F3f5B533564412FcfEfB50Ff7aff286B566) |

## V1 Deployment Addresses

| Chain | Limit Order Router Address |
| :-: | :-: |
| <img src="https://assets.odos.xyz/chains/ethereum.png" width="50" height="50"><br>Ethereum | [`0x0F26B03961eb5D625BD6001278F0DB13f3e583d8`](https://etherscan.io/address/0x0f26b03961eb5d625bd6001278f0db13f3e583d8) |
| <img src="https://assets.odos.xyz/chains/optimism.png" width="50" height="50"><br>Optimism | [`0xafF142fBc8FA5B1885FE54E4C889985F8a579b24`](https://optimistic.etherscan.io/address/0xafF142fBc8FA5B1885FE54E4C889985F8a579b24) |
| <img src="https://assets.odos.xyz/chains/bnb.png" width="50" height="50"><br>BNB | [`0xFA198dF5167dc5fb7DDA2Ad413310Be67394bF3d`](https://bscscan.com/address/0xFA198dF5167dc5fb7DDA2Ad413310Be67394bF3d) |
| <img src="https://assets.odos.xyz/chains/polygon.png" width="50" height="50"><br>Polygon | [`0xBefe4BC7f39771CF7C2CcCE6E4e7Ef393deb6704`](https://polygonscan.com/address/0xBefe4BC7f39771CF7C2CcCE6E4e7Ef393deb6704) |
| <img src="https://assets.odos.xyz/chains/fantom.png" width="50" height="50"><br>Fantom | [`0x275278CEA8d36b879917B51d250F04Be95F905Ed`](https://ftmscan.com/address/0x275278CEA8d36b879917B51d250F04Be95F905Ed) |
| <img src="https://assets.odos.xyz/chains/fraxtal.png" width="50" height="50"><br>Fraxtal | [`0x926fAAfcE6148884CD5cF98Cd1878f865E8911Bf`](https://fraxscan.com/address/0x926fAAfcE6148884CD5cF98Cd1878f865E8911Bf) |
| <img src="https://assets.odos.xyz/chains/zksync.png" width="50" height="50"><br>zkSync Era | [`0xa688F1d16b44b9A3110C3b4413b6081F271A643B`](https://era.zksync.network/address/0xa688F1d16b44b9A3110C3b4413b6081F271A643B) |
| <img src="https://assets.odos.xyz/chains/mantle.png" width="50" height="50"><br>Mantle | [`0x51Ea3db8b67462b0A66b3F1fF50cA87C076Acc7a`](https://mantlescan.xyz/address/0x51Ea3db8b67462b0A66b3F1fF50cA87C076Acc7a) |
| <img src="https://assets.odos.xyz/chains/base.png" width="50" height="50"><br>Base | [`0x8c8c3E8465B911186aDeC83a53C7De8c587eDDaB`](https://basescan.org/address/0x8c8c3E8465B911186aDeC83a53C7De8c587eDDaB) |
| <img src="https://assets.odos.xyz/chains/mode.png" width="50" height="50"><br>Mode | [`0x65005f4Bea4005D48eE9Bdaae960832c6CECC557`](https://explorer.mode.network/address/0x65005f4Bea4005D48eE9Bdaae960832c6CECC557) |
| <img src="https://assets.odos.xyz/chains/arbitrum.png" width="50" height="50"><br>Arbitrum | [`0x83564b903c0311877accEE8f99e6BEb712AD8E43`](https://arbiscan.io/address/0x83564b903c0311877accEE8f99e6BEb712AD8E43) |
| <img src="https://assets.odos.xyz/chains/avalanche.png" width="50" height="50"><br>Avalanche | [`0xD10634297961fEa132ac7b6e7451BC4E5B17359b`](https://snowscan.xyz/address/0xD10634297961fEa132ac7b6e7451BC4E5B17359b) |
| <img src="https://assets.odos.xyz/chains/linea.png" width="50" height="50"><br>Linea | [`0x5Ab73021e0648f46Da303cE7f5a0F2F15a3944c6`](https://lineascan.build/address/0x5Ab73021e0648f46Da303cE7f5a0F2F15a3944c6) |
| <img src="https://assets.odos.xyz/chains/scroll.png" width="50" height="50"><br>Scroll | [`0x014F335e0161B4EdDf3fF5b297BA6A31004Ca528`](https://scrollscan.com/address/0x014F335e0161B4EdDf3fF5b297BA6A31004Ca528) |

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
