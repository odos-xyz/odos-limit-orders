// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

interface IEIP712 {
    // solhint-disable-next-line func-name-mixedcase
    function DOMAIN_SEPARATOR() external view returns (bytes32);
}
