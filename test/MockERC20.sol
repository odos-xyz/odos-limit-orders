// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract MockERC20 is ERC20 {

  constructor(string memory name) ERC20(name, name) {}

  function faucet(address to, uint256 amount) public {
    _mint(to, amount);
  }

}
