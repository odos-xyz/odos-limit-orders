// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import "forge-std/Test.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "../interfaces/IOdosExecutor.sol";
import {MockERC20} from "./MockERC20.sol";

contract MockOdosExecutor is IOdosExecutor, Test {

  using SafeERC20 for IERC20;

  constructor() {}

  function executePath(
    bytes calldata bytecode,
    uint256[] memory /*inputAmount*/,
    address /*msgSender*/
  )
  external
  payable
  {
    // deserialize token addresses and amounts
    (address[] memory outputAddresses, uint256[] memory outputAmounts) = abi.decode(bytecode, (address[], uint256[]));

    // sanity check
    require(outputAddresses.length == outputAmounts.length, "outputAddresses.length should be equal to outputAmounts.length");

    // mint tokens
    for (uint256 i = 0; i < outputAddresses.length; i++) {
      if (outputAddresses[i] == address(0)) {
        vm.deal(msg.sender, outputAmounts[i]);
      }
      else {
        MockERC20(outputAddresses[i]).faucet(msg.sender, outputAmounts[i]);
      } 
    }
  }
}
