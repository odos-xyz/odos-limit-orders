// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import {UniversalSigValidator} from "./UniversalSigValidator.sol";

error InvalidEip1271Signature(bytes32 orderHash, address account, bytes signature);
error OrderNotPresigned(bytes32 orderHash, address account);
error InvalidPresignLength(uint256 expectedLength, uint256 actualLength);

/// @notice Limit order signature validator
contract SignatureValidator is UniversalSigValidator {

  /// @dev Storage for keeping pre-signed orders
  mapping(address account => mapping(bytes32 orderHash => bool preSigned)) public preSignedOrders;

  /// @dev Keeps the signature and the signature validation method
  struct Signature {
    /// Depending on the validationMethod value, the signature format is:
    /// EIP712 - 65 bytes signature represented as abi.encodePacked(r, s, v)
    /// EIP1271 - the first 20 bytes contain the order owner address and the remaining part contains the signature
    /// PreSign - 20 bytes which contain the order owner address
    bytes signature;
    SignatureValidationMethod validationMethod;
  }

  /// @dev Order signature validation methods
  /// EIP712
  /// EIP1271
  /// PreSign - The order hash expected to be added via the setPreSignature() function prior to execution
  enum SignatureValidationMethod {
    EIP712,
    EIP1271,
    PreSign
  }

  /// @dev Event for setting pre-signature for an order hash
  event OrderPreSigned(
    bytes32 indexed orderHash,
    address indexed account,
    bool preSigned
  );

  /// @dev Validates the signature and decodes the order owner address
  /// @param orderHash Order hash
  /// @param encodedSignature order signature or account address or account address and order signature, depending on the validationMethod value
  /// @return account Order owner address
  function _getOrderOwnerOrRevert(
    bytes32 orderHash,
    bytes calldata encodedSignature,
    SignatureValidationMethod validationMethod
  )
  internal
  returns (address account)
  {
    if (validationMethod == SignatureValidationMethod.EIP712) {
      account = ECDSA.recover(orderHash, encodedSignature);
    } else if (validationMethod == SignatureValidationMethod.EIP1271) {
      assembly {
        // account = address(encodedSignature[0:20])
        account := shr(96, calldataload(encodedSignature.offset))
      }
      // the first 20 bytes of the encodedSignature contain the account address,
      // and the remaining part of the bytes array contains the signature.
      bytes calldata signature = encodedSignature[20:];

      if (!isValidSig(account, orderHash, signature)) {
        revert InvalidEip1271Signature(orderHash, account, signature);
      }
    } else { // validationMethod == SignatureValidationMethod.PreSign
      if (encodedSignature.length != 20) {
        revert InvalidPresignLength(20, encodedSignature.length);
      }
      assembly {
        // account = address(encodedSignature[0:20])
        account := shr(96, calldataload(encodedSignature.offset))
      }

      if (!preSignedOrders[account][orderHash]) {
        revert OrderNotPresigned(orderHash, account);
      }
    }
  }

  /// @notice Sets a pre-signature for the specified order hash
  /// @param orderHash EIP712 encoded order hash of single or multi input limit order
  /// @param preSigned True to set the order as enabled for filling with pre-sign, false to unset it
  function setPreSignature(
    bytes32 orderHash,
    bool preSigned
  )
  external
  {
    preSignedOrders[msg.sender][orderHash] = preSigned;
    emit OrderPreSigned(orderHash, msg.sender, preSigned);
  }
}
