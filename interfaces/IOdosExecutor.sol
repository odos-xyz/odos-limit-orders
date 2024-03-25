// SPDX-License-Identifier: MIT

pragma solidity ^0.8.21;

/// @title Odos executor interface
interface IOdosExecutor {
  function executePath (
    bytes calldata bytecode,
    uint256[] memory inputAmount,
    address msgSender
  ) external payable;
}
