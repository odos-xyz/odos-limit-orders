// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract Create2Factory {
    function deploy(bytes32 salt, bytes memory bytecode) public returns (address) {
        address deployedAddress;
        assembly {
            deployedAddress := create2(0, add(bytecode, 0x20), mload(bytecode), salt)
        }
        require(deployedAddress != address(0), "Failed to deploy contract");
        return deployedAddress;
    }
}
