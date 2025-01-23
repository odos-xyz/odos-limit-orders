// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import "forge-std/Test.sol";
import "@openzeppelin/contracts/utils/cryptography/EIP712.sol";
import {OdosLimitOrderRouterHarness} from "./OdosLimitOrderRouterHarness.sol";
import {MockSmartContractWallet} from "./MockSmartContractWallet.sol";
import {OdosLimitOrderRouter} from "../contracts/OdosLimitOrderRouter.sol";
import {InvalidEip1271Signature, InvalidPresignLength} from "../contracts/SignatureValidator.sol";
import "./OdosLimitOrderHelper.t.sol";
import "./Create2Factory.sol";
import "../contracts/SignatureValidator.sol";


contract SignatureValidationsTest is OdosLimitOrderHelperTest {

  /// @dev Router with exposed getOrderOwnerOrRevert internal function
  OdosLimitOrderRouterHarness ROUTER2;
  MockSmartContractWallet SCW;
  OdosLimitOrderRouter.LimitOrder defaultOrder;

  bytes32 orderHash;

  event OrderPreSigned(
    bytes32 indexed orderHash,
    address indexed orderOwner,
    bool preSigned
  );

  function setUp() override public {
    OdosLimitOrderHelperTest.setUp();

    ROUTER2 = new OdosLimitOrderRouterHarness();

    // construct order with default test parameters
    defaultOrder = createDefaultLimitOrder();

    orderHash = ROUTER2.getLimitOrderHash(defaultOrder);

    SignatureValidator.Signature memory signature = getOrderSignature(defaultOrder);

    SCW = new MockSmartContractWallet(orderHash, signature.signature);
  }

  function test_EIP1271_succeeds() public {
    address accountAddress = address(SCW);

    SignatureValidator.Signature memory signature = getOrderSignature(defaultOrder);

    bytes memory encodedSignature = abi.encodePacked(accountAddress, signature.signature);

    address orderOwner = ROUTER2.exposed_getOrderOwnerOrRevert(
      orderHash,
      encodedSignature,
      SignatureValidator.SignatureValidationMethod.EIP1271
    );

    assertEq(accountAddress, orderOwner);
  }

  function test_EIP1271_reverts() public {
    address accountAddress = address(SCW);

    // generate 65 bytes signature
    (uint8 v, bytes32 r, bytes32 s) = vm.sign(SIGNER_PK, orderHash);
    bytes memory wrongOrderSignature = abi.encodePacked(r, s, v);


    bytes memory encodedSignature = abi.encodePacked(accountAddress, wrongOrderSignature);

    vm.expectRevert(abi.encodeWithSelector(InvalidEip1271Signature.selector, accountAddress, orderHash, wrongOrderSignature));
    ROUTER2.exposed_getOrderOwnerOrRevert(
      orderHash,
      encodedSignature,
      SignatureValidator.SignatureValidationMethod.EIP1271
    );
  }

  function test_PreSign_OrderPreSigned_event_true() public {
    vm.expectEmit(true, true, true, true);
    emit OrderPreSigned(orderHash, address(this), true);

    ROUTER2.setPreSignature(orderHash, true);
  }

  function test_PreSign_OrderPreSigned_event_false() public {
    vm.expectEmit(true, true, true, true);
    emit OrderPreSigned(orderHash, address(this), false);

    ROUTER2.setPreSignature(orderHash, false);
  }

  function test_PreSign_succeeds() public {
    address accountAddress = address(SCW);

    // encode account address to 20 bytes
    bytes memory encodedSignature = abi.encodePacked(accountAddress);

    vm.prank(accountAddress);
    ROUTER2.setPreSignature(orderHash, true);

    address orderOwner = ROUTER2.exposed_getOrderOwnerOrRevert(
      orderHash,
      encodedSignature,
      SignatureValidator.SignatureValidationMethod.PreSign
    );

    assertEq(accountAddress, orderOwner);
  }

  function test_PreSign_reverts() public {
    address accountAddress = address(SCW);

    // encode account address to 32 bytes instead of 20
    bytes memory encodedSignature = abi.encode(accountAddress);

    vm.expectRevert(abi.encodeWithSelector(InvalidPresignLength.selector, 20, 32));
    ROUTER2.exposed_getOrderOwnerOrRevert(
      orderHash,
      encodedSignature,
      SignatureValidator.SignatureValidationMethod.PreSign
    );
  }

  /// Verifies CREATE2 smart contract wallet arguments via deployment
  function test_Create2Factory_succeeds() public {
    Create2Factory factory = new Create2Factory();
    bytes32 salt = keccak256("SOME_RANDOM_SALT");

    // Prepare the bytecode of SimpleContract with constructor argument
    bytes memory bytecode = type(MockSmartContractWallet).creationCode;
    SignatureValidator.Signature memory signature = getOrderSignature(defaultOrder);
    bytes memory bytecodeWithArgs = abi.encodePacked(bytecode, abi.encode(orderHash, signature.signature));

    // Deploy SimpleContract using Create2Factory
    address deployedAddress = factory.deploy(salt, bytecodeWithArgs);

    // bytes4(keccak256("isValidSignature(bytes32,bytes)")
    bytes4 EIP1271_MAGICVALUE = 0x1626ba7e;

    assertTrue(MockSmartContractWallet(deployedAddress).isValidSignature(orderHash, signature.signature) == EIP1271_MAGICVALUE);

    // Optionally, compute and assert the expected address
    bytes32 hash = keccak256(abi.encodePacked(bytes1(0xff), address(factory), salt, keccak256(bytecodeWithArgs)));
    address expectedAddress = address(uint160(uint(hash)));
    assertEq(deployedAddress, expectedAddress);
  }
}
