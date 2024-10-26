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

    vm.expectRevert(abi.encodeWithSelector(InvalidEip1271Signature.selector, orderHash, accountAddress, wrongOrderSignature));
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

  function prepare_EIP6492_deployment(bytes memory expectedOrderSignature, bytes memory actualOrderSignature)
  public
  returns (bytes memory eip6492sig, address expectedAddress) {
    Create2Factory factory = new Create2Factory();
    bytes32 salt = keccak256("SOME_RANDOM_SALT");

    // Prepare the bytecode of MockSmartContractWallet with constructor argument
    bytes memory bytecode = type(MockSmartContractWallet).creationCode;
    bytes memory bytecodeWithArgs = abi.encodePacked(bytecode, abi.encode(orderHash, expectedOrderSignature));

    // prepare factory calldata
    bytes memory factoryCalldata = abi.encodeWithSelector(
      factory.deploy.selector,
      salt,
      bytecodeWithArgs
    );

    // Compute the smart contract wallet expected address
    bytes32 hash = keccak256(abi.encodePacked(bytes1(0xff), address(factory), salt, keccak256(bytecodeWithArgs)));
    expectedAddress = address(uint160(uint(hash)));

    // As per ERC-6492: create2Factory, factoryCalldata, originalSig
    // The address, bytes, and bytes parameters to be encoded
    bytes memory encodedData = abi.encode(address(factory), factoryCalldata, actualOrderSignature);

    // The magic suffix to be appended
    bytes memory magicSuffix = hex"6492649264926492649264926492649264926492649264926492649264926492";

    // Concatenate the encodedData with the magicSuffix
    eip6492sig = bytes.concat(encodedData, magicSuffix);
  }

  function test_EIP1271_EIP6492_succeeds() public {
    SignatureValidator.Signature memory signature = getOrderSignature(defaultOrder);

    // Actual order signature is equal to expected
    (bytes memory eip6492sig, address expectedAddress) = prepare_EIP6492_deployment(signature.signature, signature.signature);

    // Prepend the signature with the smart contract wallet address
    bytes memory encodedSignature = abi.encodePacked(expectedAddress, eip6492sig);

    address orderOwner = ROUTER2.exposed_getOrderOwnerOrRevert(
      orderHash,
      encodedSignature,
      SignatureValidator.SignatureValidationMethod.EIP1271
    );

    assertEq(expectedAddress, orderOwner);
  }

  function test_EIP1271_EIP6492_reverts() public {
    SignatureValidator.Signature memory expectedSignature = getOrderSignature(defaultOrder);

    defaultOrder.salt = 2;
    SignatureValidator.Signature memory actualSignature = getOrderSignature(defaultOrder);

    (bytes memory eip6492sig, address expectedAddress) = prepare_EIP6492_deployment(expectedSignature.signature, actualSignature.signature);

    // Prepend the signature with the smart contract wallet address
    bytes memory encodedSignature = abi.encodePacked(expectedAddress, eip6492sig);

    vm.expectRevert(abi.encodeWithSelector(InvalidEip1271Signature.selector, orderHash, expectedAddress, eip6492sig));
    ROUTER2.exposed_getOrderOwnerOrRevert(
      orderHash,
      encodedSignature,
      SignatureValidator.SignatureValidationMethod.EIP1271
    );
  }

  // Check the situation when the user set SignatureValidationMethod.EIP1271,
  // but instead of SCW there is EOA. In this case we use ECDSA.recover() to
  // to get the signer address
  function test_EIP1271_EIP712_succeeds() public {
    address accountAddress = SIGNER_ADDRESS;
    SignatureValidator.Signature memory signature = getOrderSignature(defaultOrder);

    bytes memory encodedSignature = abi.encodePacked(accountAddress, signature.signature);

    address orderOwner = ROUTER2.exposed_getOrderOwnerOrRevert(
      ROUTER.getLimitOrderHash(defaultOrder),
      encodedSignature,
      SignatureValidator.SignatureValidationMethod.EIP1271
    );

    assertEq(accountAddress, orderOwner);
  }
}
