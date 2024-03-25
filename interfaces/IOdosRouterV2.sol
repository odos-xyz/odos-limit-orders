// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;


/// @notice Interface for https://github.com/odos-xyz/odos-router-v2/blob/main/contracts/OdosRouterV2.sol functions used in the limit order contract
interface IOdosRouterV2 {

  /// @dev Holds all information for a given referral
  // solhint-disable-next-line contract-name-camelcase
  struct referralInfo {
    uint64 referralFee;
    address beneficiary;
    bool registered;
  }

  function referralLookup(
    uint32 referralCode
  )
  external
  view
  returns (
    referralInfo memory ri
  );

  function registerReferralCode(
    uint32 _referralCode,
    uint64 _referralFee,
    address _beneficiary
  )
  external;
}
