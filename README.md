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
| <img src="https://assets.odos.xyz/chains/ethereum.png" width="50" height="50"><br>Ethereum | [`0x5F79636fa7bc622eA48802E6cf80A5dae814daE1`](https://etherscan.io/address/0x5F79636fa7bc622eA48802E6cf80A5dae814daE1) |
| <img src="https://assets.odos.xyz/chains/optimism.png" width="50" height="50"><br>Optimism | [`0xcbF3822A63B7867cD602317fB4aE3ca864826ef8`](https://optimistic.etherscan.io/address/0xcbF3822A63B7867cD602317fB4aE3ca864826ef8) |
| <img src="https://assets.odos.xyz/chains/bnb.png" width="50" height="50"><br>BNB | [`0x0D4aB12E62D17f037D43F018Da18FF623e1AF3B2`](https://bscscan.com/address/0x0D4aB12E62D17f037D43F018Da18FF623e1AF3B2) |
| <img src="https://assets.odos.xyz/chains/polygon.png" width="50" height="50"><br>Polygon | [`0x93052961c75c92Fd5d6362655936C239EF2D5336`](https://polygonscan.com/address/0x93052961c75c92Fd5d6362655936C239EF2D5336) |
| <img src="https://assets.odos.xyz/chains/sonic.png" width="50" height="50"><br>Sonic | [`0xB9CBD870916e9Ffc52076Caa714f85a022B7f330`](https://sonicscan.org/address/0xB9CBD870916e9Ffc52076Caa714f85a022B7f330) |
| <img src="https://assets.odos.xyz/chains/fantom.png" width="50" height="50"><br>Fantom | [`0x5E0aFaD0f658f9689806296e0509AfFC191d9a09`](https://ftmscan.com/address/0x5E0aFaD0f658f9689806296e0509AfFC191d9a09) |
| <img src="https://assets.odos.xyz/chains/fraxtal.png" width="50" height="50"><br>Fraxtal | [`0x5E0aFaD0f658f9689806296e0509AfFC191d9a09`](https://fraxscan.com/address/0x5E0aFaD0f658f9689806296e0509AfFC191d9a09) |
| <img src="https://assets.odos.xyz/chains/zksync.png" width="50" height="50"><br>zkSync Era | [`0x74ab8c1247aE3C5FFFD9F85781F31751bdd98E73`](https://era.zksync.network/address/0x74ab8c1247aE3C5FFFD9F85781F31751bdd98E73) |
| <img src="https://assets.odos.xyz/chains/mantle.png" width="50" height="50"><br>Mantle | [`0xa05A88037402d869b7CA69F5bEc098E19BeDaFbB`](https://mantlescan.xyz/address/0xa05A88037402d869b7CA69F5bEc098E19BeDaFbB) |
| <img src="https://assets.odos.xyz/chains/base.png" width="50" height="50"><br>Base | [`0xeDeAfdEf0901eF74Ee28c207BE8424D3B353D97A`](https://basescan.org/address/0xeDeAfdEf0901eF74Ee28c207BE8424D3B353D97A) |
| <img src="https://assets.odos.xyz/chains/mode.png" width="50" height="50"><br>Mode | [`0x8073e286DaDc6d92BefC8f436c5BcDFcE213e681`](https://explorer.mode.network/address/0x8073e286DaDc6d92BefC8f436c5BcDFcE213e681) |
| <img src="https://assets.odos.xyz/chains/arbitrum.png" width="50" height="50"><br>Arbitrum | [`0x7432657cDda02226ac2aAc9d8f552Ee9613B064e`](https://arbiscan.io/address/0x7432657cDda02226ac2aAc9d8f552Ee9613B064e) |
| <img src="https://assets.odos.xyz/chains/avalanche.png" width="50" height="50"><br>Avalanche | [`0xcc0126349d1bD892D1C53381E68dBF0c8F0E045e`](https://snowscan.xyz/address/0xcc0126349d1bD892D1C53381E68dBF0c8F0E045e) |
| <img src="https://assets.odos.xyz/chains/linea.png" width="50" height="50"><br>Linea | [`0xb3a9B56056a5c93F468dF62579b9A5BEa1741069`](https://lineascan.build/address/0xb3a9B56056a5c93F468dF62579b9A5BEa1741069) |
| <img src="https://assets.odos.xyz/chains/scroll.png" width="50" height="50"><br>Scroll | [`0x468633515c46EfFCC77Caa949ce8775505e5deDA`](https://scrollscan.com/address/0x468633515c46EfFCC77Caa949ce8775505e5deDA) |

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
