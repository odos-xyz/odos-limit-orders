// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {OdosLimitOrderRouter} from "../contracts/OdosLimitOrderRouter.sol";


/// @dev This contract is required for exposing the internal function getOrderOwnerOrRevert for tests
contract OdosLimitOrderRouterHarness is OdosLimitOrderRouter {

  constructor()
  OdosLimitOrderRouter() {}

  function exposed_getOrderOwnerOrRevert(
    bytes32 orderHash,
    bytes calldata encodedSignature,
    SignatureValidationMethod validationMethod
  )
  public
  returns (address orderOwner) {
    return _getOrderOwnerOrRevert(
      orderHash,
      encodedSignature,
      validationMethod
    );
  }
}
