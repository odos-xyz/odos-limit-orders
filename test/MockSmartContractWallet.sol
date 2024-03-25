// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/interfaces/IERC1271.sol";

contract MockSmartContractWallet is IERC1271 {

  // bytes4(keccak256("isValidSignature(bytes32,bytes)")
  bytes4 constant internal EIP1271_MAGICVALUE = 0x1626ba7e;

  bytes32 expectedHash;
  bytes expectedSignature;

  constructor(bytes32 _expectedHash, bytes memory _expectedSignature) {
    expectedHash = _expectedHash;
    expectedSignature = _expectedSignature;
  }

  function setExpected(bytes32 hash, bytes memory signature) public {
    expectedHash = hash;
    expectedSignature = signature;
  }

  function isValidSignature(bytes32 hash, bytes memory signature) external view returns (bytes4 magicValue) {
    if (expectedHash == hash && compareBytes(expectedSignature, signature)) {
      return EIP1271_MAGICVALUE;
    }
    return 0xffffffff;
  }

  /// @dev Compares two dynamic byte arrays
  function compareBytes(bytes storage refBytes, bytes memory memBytes) private view returns (bool) {
    // Solidity does not directly support the == operator for comparing dynamic byte arrays (bytes) in storage with those in memory.
    // Manually compare the bytes data by checking their length and then iterating over each byte to compare their values.

    // Compare the lengths
    if (refBytes.length != memBytes.length) {
      return false;
    }

    // Compare each byte
    for (uint i = 0; i < refBytes.length; i++) {
      if (refBytes[i] != memBytes[i]) {
        return false;
      }
    }

    return true;
  }
}
