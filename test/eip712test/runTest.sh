#!/bin/sh
yarn
anvil
forge create --rpc-url http://localhost:8545 --private-key 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80 contracts/OdosLimitOrderRouter.sol:OdosLimitOrderRouter --constructor-args 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266 0x0000000000000000000000000000000000000000

npm test --no-watchman