# Odos Limit Order Smart Contract

## Summary

This product allows users to place orders that will be executed at a specified limit price. Orders are placed gaslessly via signed EIP-712 data, and support multiple inputs and multiple outputs.

### Limit order execution flow

1. Check if msg.sender is allowed
2. Check if order still valid
3. Check tokens, amounts
4. Get order hash
5. Recover order owner account (and validate the signature)
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
| <img src="https://assets.odos.xyz/chains/ethereum.png" width="50" height="50"><br>Ethereum | [`0x2Bd1E23a2Cd5c52334501B6a1F188009290D84a5`](https://etherscan.io/address/0x2Bd1E23a2Cd5c52334501B6a1F188009290D84a5) |
| <img src="https://assets.odos.xyz/chains/optimism.png" width="50" height="50"><br>Optimism | [`0x08F161354c15CF0F2fF2039dC6b85A1B42AaF48b`](https://optimistic.etherscan.io/address/0x08F161354c15CF0F2fF2039dC6b85A1B42AaF48b) |
| <img src="https://assets.odos.xyz/chains/bnb.png" width="50" height="50"><br>BNB | [`0x41a42adA966Cbfa5BD71225F32E44FEA66b285ac`](https://bscscan.com/address/0x41a42adA966Cbfa5BD71225F32E44FEA66b285ac) |
| <img src="https://assets.odos.xyz/chains/polygon.png" width="50" height="50"><br>Polygon | [`0xf3f8C59cb5343eEaaE205FDE5C90B6Ce476494d7`](https://polygonscan.com/address/0xf3f8C59cb5343eEaaE205FDE5C90B6Ce476494d7) |
| <img src="https://assets.odos.xyz/chains/fantom.png" width="50" height="50"><br>Fantom | [`0x0857dE010f6583a88A0114de1611392F85f84527`](https://ftmscan.com/address/0x0857dE010f6583a88A0114de1611392F85f84527) |
| <img src="https://assets.odos.xyz/chains/fraxtal.png" width="50" height="50"><br>Fraxtal | [`0xf78b2432F77aEa2A3e35263E017fFcC20EB5F075`](https://fraxscan.com/address/0xf78b2432F77aEa2A3e35263E017fFcC20EB5F075) |
| <img src="https://assets.odos.xyz/chains/zksync.png" width="50" height="50"><br>zkSync Era | [`0x6a45535b8480eD943a85916e5f3b4F75c95D9fd3`](https://era.zksync.network/address/0x6a45535b8480eD943a85916e5f3b4F75c95D9fd3) |
| <img src="https://assets.odos.xyz/chains/mantle.png" width="50" height="50"><br>Mantle | [`0x327327bAaf17688cB8F1501023b5482dca2851Bb`](https://mantlescan.xyz/address/0x327327bAaf17688cB8F1501023b5482dca2851Bb) |
| <img src="https://assets.odos.xyz/chains/base.png" width="50" height="50"><br>Base | [`0x7091202dAa037CDC9F157DB82653f4d90E6FaaD4`](https://basescan.org/address/0x7091202dAa037CDC9F157DB82653f4d90E6FaaD4) |
| <img src="https://assets.odos.xyz/chains/mode.png" width="50" height="50"><br>Mode | [`0x0f95b0ec022216150637102AbF1503cEb69fCDAd`](https://explorer.mode.network/address/0x0f95b0ec022216150637102AbF1503cEb69fCDAd) |
| <img src="https://assets.odos.xyz/chains/arbitrum.png" width="50" height="50"><br>Arbitrum | [`0x71a40B9104043c04C808389d89dC932406459a09`](https://arbiscan.io/address/0x71a40B9104043c04C808389d89dC932406459a09) |
| <img src="https://assets.odos.xyz/chains/avalanche.png" width="50" height="50"><br>Avalanche | [`0x95077184FFB22964a9375cF435b82358d6DC0289`](https://snowscan.xyz/address/0x95077184FFB22964a9375cF435b82358d6DC0289) |
| <img src="https://assets.odos.xyz/chains/linea.png" width="50" height="50"><br>Linea | [`0x9Ed9Df32aBDE10341026631487Fa8cB20Ab69c86`](https://lineascan.build/address/0x9Ed9Df32aBDE10341026631487Fa8cB20Ab69c86) |
| <img src="https://assets.odos.xyz/chains/scroll.png" width="50" height="50"><br>Scroll | [`0xc94840Dff7Fa56E56BA0a9fbc49013BC5291fE91`](https://scrollscan.com/address/0xc94840Dff7Fa56E56BA0a9fbc49013BC5291fE91) |

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
