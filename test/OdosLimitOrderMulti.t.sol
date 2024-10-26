// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import "forge-std/Test.sol";
import "../contracts/OdosLimitOrderRouter.sol";
import "@openzeppelin/contracts/utils/cryptography/EIP712.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "../interfaces/IOdosExecutor.sol";
import {MockOdosExecutor} from "./MockOdosExecutor.sol";
import {MockERC20} from "./MockERC20.sol";
import {IERC20Errors} from "../interfaces/draft-IERC6093.sol";
import "./MockSmartContractWallet.sol";
import "./OdosLimitOrderHelper.t.sol";


/// @notice This contract tests multi input limit order functions
contract OdosLimitOrderMultiTest is OdosLimitOrderHelperTest {

  event MultiLimitOrderFilled(
    bytes32 indexed orderHash,
    address indexed orderOwner,
    address[] inputTokens,
    address[] outputTokens,
    uint256[] filledInputAmounts,
    uint256[] filledOutputAmounts,
    uint256[] surplus,
    uint64 referralCode,
    uint64 referralFee,
    address referralFeeRecipient,
    uint256 orderType
  );

  event MultiLimitOrderCancelled(
    bytes32 indexed orderHash,
    address indexed orderOwner
  );

  struct MultiLimitOrderHelper {
    address[] inputTokens;
    address[] outputTokens;
    uint256[] orderInputAmounts;
    uint256[] orderOutputAmounts;
    uint256[] filledOutputAmounts;
    uint256[] surplus;
  }

  ///@notice returns a standard event output fields
  function getOrderHelper(OdosLimitOrderRouter.MultiLimitOrder memory order)
  public
  pure
  returns(MultiLimitOrderHelper memory helper) {
    helper = MultiLimitOrderHelper({
      inputTokens: new address[](order.inputs.length),
      outputTokens: new address[](order.outputs.length),
      orderInputAmounts: new uint256[](order.inputs.length),
      orderOutputAmounts: new uint256[](order.outputs.length),
      //filledInputAmounts: new uint256[](order.inputs.length),
      filledOutputAmounts: new uint256[](order.outputs.length),
      surplus: new uint256[](order.outputs.length)
    });

    for (uint256 i = 0; i < order.inputs.length; i++) {
      helper.inputTokens[i] = order.inputs[i].tokenAddress;
      helper.orderInputAmounts[i] = order.inputs[i].tokenAmount;
    }
    for (uint256 i = 0; i < order.outputs.length; i++) {
      helper.outputTokens[i] = order.outputs[i].tokenAddress;
      helper.orderOutputAmounts[i] = order.outputs[i].tokenAmount;
      helper.filledOutputAmounts[i] = order.outputs[i].tokenAmount;
    }
  }

  function test_multi_Signature() public {
    // construct order
    OdosLimitOrderRouter.MultiLimitOrder memory order = createDefaultMultiLimitOrder();

    // get order signature
    SignatureValidator.Signature memory signature = getMultiOrderSignature(order);
    // get order hash
    bytes32 orderHash = ROUTER.getMultiLimitOrderHash(order);

    address recoveredAddress = ECDSA.recover(orderHash, signature.signature);
    assertTrue(SIGNER_ADDRESS == recoveredAddress);
  }

// 1. Check msg.sender allowed
  function test_multi_msgSenderCheck_succeeds() public {
    // create order
    OdosLimitOrderRouter.MultiLimitOrder memory order = createDefaultMultiLimitOrder();

    uint256 amountOut1 = 2002 * 1e6;
    uint256 amountOut2 = 1998 * 1e18;

    // get order signature
    SignatureValidator.Signature memory signature = getMultiOrderSignature(order);

    // create execution context
    OdosLimitOrderRouter.MultiLimitOrderContext memory context = getDefaultMultiContext(amountOut1, amountOut2);

    // mint input tokens
    mintTokens(SIGNER_ADDRESS);
    // add to whitelist
    ROUTER.addAllowedFiller(address(this));

    uint256[] memory balancesBefore = new uint256[](2);
    for(uint256 i = 0; i < order.outputs.length; i++) {
      balancesBefore[i] = IERC20(order.outputs[i].tokenAddress).balanceOf(SIGNER_ADDRESS);
    }

    MultiLimitOrderHelper memory helper = getOrderHelper(order);

    // check that event is emitted, check all topics
    vm.expectEmit(true, true, true, true);
    emit MultiLimitOrderFilled(
      ROUTER.getMultiLimitOrderHash(order),
      SIGNER_ADDRESS,
      helper.inputTokens,
      helper.outputTokens,
      context.currentAmounts,
      helper.filledOutputAmounts,
      helper.surplus,
      0,
      0,
      address(0),
      0
    );

    // run test
    ROUTER.fillMultiLimitOrder(order, signature, context);

    assertTrue(IERC20(order.outputs[0].tokenAddress).balanceOf(SIGNER_ADDRESS) - balancesBefore[0] == amountOut1);
    assertTrue(IERC20(order.outputs[1].tokenAddress).balanceOf(SIGNER_ADDRESS) - balancesBefore[1] == amountOut2);
  }

  function test_multi_eth_output_succeeds() public {
    // create order
    OdosLimitOrderRouter.MultiLimitOrder memory order = createDefaultMultiLimitOrder();

    uint256 amountOut1 = 2002 * 1e18;
    uint256 amountOut2 = 1998 * 1e18;

    order.outputs[0] = OdosLimitOrderRouter.TokenInfo(address(0), amountOut1);

    // get order signature
    SignatureValidator.Signature memory signature = getMultiOrderSignature(order);

    // create execution context
    OdosLimitOrderRouter.MultiLimitOrderContext memory context = getDefaultMultiContext(amountOut1, amountOut2);

    address[] memory tokensOut = new address[](2);
    tokensOut[0] = address(0);
    tokensOut[1] = USDT;

    uint256[] memory amountsOut = new uint256[](2);
    amountsOut[0] = amountOut1;
    amountsOut[1] = amountOut2;

    context.pathDefinition = abi.encode(tokensOut, amountsOut);

    // mint input tokens
    mintTokens(SIGNER_ADDRESS);
    // add to whitelist
    ROUTER.addAllowedFiller(address(this));

    uint256[] memory balancesBefore = new uint256[](2);

    balancesBefore[0] = SIGNER_ADDRESS.balance;
    balancesBefore[1] = IERC20(order.outputs[1].tokenAddress).balanceOf(SIGNER_ADDRESS);

    MultiLimitOrderHelper memory helper = getOrderHelper(order);

    // check that event is emitted, check all topics
    vm.expectEmit(true, true, true, true);
    emit MultiLimitOrderFilled(
      ROUTER.getMultiLimitOrderHash(order),
      SIGNER_ADDRESS,
      helper.inputTokens,
      helper.outputTokens,
      context.currentAmounts,
      helper.filledOutputAmounts,
      helper.surplus,
      0,
      0,
      address(0),
      0
    );

    // run test
    ROUTER.fillMultiLimitOrder(order, signature, context);

    assertTrue(SIGNER_ADDRESS.balance - balancesBefore[0] == amountOut1);
    assertTrue(IERC20(order.outputs[1].tokenAddress).balanceOf(SIGNER_ADDRESS) - balancesBefore[1] == amountOut2);
  }

  function test_multi_orderType_emitted() public {
    // create order
    OdosLimitOrderRouter.MultiLimitOrder memory order = createDefaultMultiLimitOrder();

    uint256 amountOut1 = 2002 * 1e6;
    uint256 amountOut2 = 1998 * 1e18;

    // get order signature
    SignatureValidator.Signature memory signature = getMultiOrderSignature(order);

    // create execution context
    OdosLimitOrderRouter.MultiLimitOrderContext memory context = getDefaultMultiContext(amountOut1, amountOut2);

    uint256 expectedOrderType = 1234567890;
    context.orderType = expectedOrderType;

    // mint input tokens
    mintTokens(SIGNER_ADDRESS);
    // add to whitelist
    ROUTER.addAllowedFiller(address(this));

    uint256[] memory balancesBefore = new uint256[](2);
    for(uint256 i = 0; i < order.outputs.length; i++) {
      balancesBefore[i] = IERC20(order.outputs[i].tokenAddress).balanceOf(SIGNER_ADDRESS);
    }

    MultiLimitOrderHelper memory helper = getOrderHelper(order);

    // check that event is emitted, check all topics
    vm.expectEmit(true, true, true, true);
    emit MultiLimitOrderFilled(
      ROUTER.getMultiLimitOrderHash(order),
      SIGNER_ADDRESS,
      helper.inputTokens,
      helper.outputTokens,
      context.currentAmounts,
      helper.filledOutputAmounts,
      helper.surplus,
      0,
      0,
      address(0),
      expectedOrderType
    );

    // run test
    ROUTER.fillMultiLimitOrder(order, signature, context);

    assertTrue(IERC20(order.outputs[0].tokenAddress).balanceOf(SIGNER_ADDRESS) - balancesBefore[0] == amountOut1);
    assertTrue(IERC20(order.outputs[1].tokenAddress).balanceOf(SIGNER_ADDRESS) - balancesBefore[1] == amountOut2);
  }

// 1. Check msg.sender allowed
  function test_multi_msgSenderCheck_reverts() public {
    // create order
    OdosLimitOrderRouter.MultiLimitOrder memory order = createDefaultMultiLimitOrder();

    uint256 amountOut1 = 2002 * 1e6;
    uint256 amountOut2 = 1998 * 1e18;

    // get order signature
    SignatureValidator.Signature memory signature = getMultiOrderSignature(order);

    // create execution context
    OdosLimitOrderRouter.MultiLimitOrderContext memory context = getDefaultMultiContext(amountOut1, amountOut2);

    // mint input tokens
    mintTokens(SIGNER_ADDRESS);

    // DO NOT add to whitelist
    // ROUTER.addToWhitelist(address(this));

    uint256[] memory balancesBefore = new uint256[](2);
    for(uint256 i = 0; i < order.outputs.length; i++) {
      balancesBefore[i] = IERC20(order.outputs[i].tokenAddress).balanceOf(SIGNER_ADDRESS);
    }

    vm.expectRevert(abi.encodeWithSelector(AddressNotAllowed.selector, address(this)));
    ROUTER.fillMultiLimitOrder(order, signature, context);
  }

// 2. Check if order still valid
  function test_multi_orderExpiry_reverts() public {
    // create order
    OdosLimitOrderRouter.MultiLimitOrder memory order = createDefaultMultiLimitOrder();

    order.expiry = block.timestamp - 1;
    uint256 amountOut1 = 2002 * 1e6;
    uint256 amountOut2 = 1998 * 1e18;

    // get order signature
    SignatureValidator.Signature memory signature = getMultiOrderSignature(order);

    // create execution context
    OdosLimitOrderRouter.MultiLimitOrderContext memory context = getDefaultMultiContext(amountOut1, amountOut2);

    // mint input tokens
    mintTokens(SIGNER_ADDRESS);

    // add to whitelist
    ROUTER.addAllowedFiller(address(this));

    // run test, revert expected
    vm.expectRevert(abi.encodeWithSelector(OrderExpired.selector, order.expiry, block.timestamp));
    ROUTER.fillMultiLimitOrder(order, signature, context);
  }

// 3. Check tokens, amounts
  function test_multi_tokens_revertsIfInputTokenEth() public {
    // create order
    OdosLimitOrderRouter.MultiLimitOrder memory order = createDefaultMultiLimitOrder();

    order.inputs[0].tokenAddress = _ETH;
    uint256 amountOut1 = 2002 * 1e6;
    uint256 amountOut2 = 1998 * 1e18;

    // get order signature
    SignatureValidator.Signature memory signature = getMultiOrderSignature(order);

    // create execution context
    OdosLimitOrderRouter.MultiLimitOrderContext memory context = getDefaultMultiContext(amountOut1, amountOut2);

    // mint input tokens
    mintTokens(SIGNER_ADDRESS);

    // add to whitelist
    ROUTER.addAllowedFiller(address(this));

    // run test, revert expected
    vm.expectRevert();
    ROUTER.fillMultiLimitOrder(order, signature, context);
  }

// 3. Check tokens, amounts
  function test_multi_tokens_revertsIfOutputTokenEth() public {
    // create order
    OdosLimitOrderRouter.MultiLimitOrder memory order = createDefaultMultiLimitOrder();

    order.outputs[0].tokenAddress = _ETH;
    uint256 amountOut1 = 2002 * 1e6;
    uint256 amountOut2 = 1998 * 1e18;

    // get order signature
    SignatureValidator.Signature memory signature = getMultiOrderSignature(order);

    // create execution context
    OdosLimitOrderRouter.MultiLimitOrderContext memory context = getDefaultMultiContext(amountOut1, amountOut2);

    // mint input tokens
    mintTokens(SIGNER_ADDRESS);

    // add to whitelist
    ROUTER.addAllowedFiller(address(this));

    // run test, revert expected
    vm.expectRevert();
    ROUTER.fillMultiLimitOrder(order, signature, context);
  }

// 3. Check tokens, amounts
  function test_multi_tokens_revertsIfInputTokenEqualToOutputToken() public {
    // create order
    OdosLimitOrderRouter.MultiLimitOrder memory order = createDefaultMultiLimitOrder();

    order.outputs[0].tokenAddress = order.inputs[0].tokenAddress;
    uint256 amountOut1 = 2002 * 1e6;
    uint256 amountOut2 = 1998 * 1e18;

    // get order signature
    SignatureValidator.Signature memory signature = getMultiOrderSignature(order);

    // create execution context
    OdosLimitOrderRouter.MultiLimitOrderContext memory context = getDefaultMultiContext(amountOut1, amountOut2);

    // mint input tokens
    mintTokens(SIGNER_ADDRESS);

    // add to whitelist
    ROUTER.addAllowedFiller(address(this));

    // run test, revert expected
    vm.expectRevert();
    ROUTER.fillMultiLimitOrder(order, signature, context);
  }

// 6. Check if fill possible:
//   - If not partiallyFillable - it was not filled previously
  function test_multi_partiallyFillableFalse_revertsIfAlreadyFilled() public {
    // create order
    OdosLimitOrderRouter.MultiLimitOrder memory order = createDefaultMultiLimitOrder();

    uint256 amountOut1 = 2002 * 1e6;
    uint256 amountOut2 = 1998 * 1e18;

    // get order signature
    SignatureValidator.Signature memory signature = getMultiOrderSignature(order);

    // create execution context
    OdosLimitOrderRouter.MultiLimitOrderContext memory context = getDefaultMultiContext(amountOut1, amountOut2);

    // mint input tokens
    mintTokens(SIGNER_ADDRESS);

    // add to whitelist
    ROUTER.addAllowedFiller(address(this));

    MultiLimitOrderHelper memory helper = getOrderHelper(order);

    // check that event is emitted, check all topics
    vm.expectEmit(true, true, true, true);
    emit MultiLimitOrderFilled(
      ROUTER.getMultiLimitOrderHash(order),
      SIGNER_ADDRESS,
      helper.inputTokens,
      helper.outputTokens,
      context.currentAmounts,
      helper.filledOutputAmounts,
      helper.surplus,
      0,
      0,
      address(0),
      0
    );

    ROUTER.fillMultiLimitOrder(order, signature, context);

    // second execution attempt reverts because the order is already filled
    vm.expectRevert(abi.encodeWithSelector(CurrentAmountMismatch.selector,
      order.inputs[0].tokenAddress,
      order.inputs[0].tokenAmount,
      1999 * 1e18,
      context.currentAmounts[0]));
    ROUTER.fillMultiLimitOrder(order, signature, context);
  }

// 6. Check if fill possible:
//   - If not partiallyFillable - it was not filled previously
  function test_multi_partiallyFillableFalse_revertsIfcurrentAmountNotEqualToInputAmount() public {
    // create order
    OdosLimitOrderRouter.MultiLimitOrder memory order = createDefaultMultiLimitOrder();

    uint256 amountOut1 = 2002 * 1e6;
    uint256 amountOut2 = 1998 * 1e18;

    // get order signature
    SignatureValidator.Signature memory signature = getMultiOrderSignature(order);

    // create execution context
    OdosLimitOrderRouter.MultiLimitOrderContext memory context = getDefaultMultiContext(amountOut1, amountOut2);

    // currentAmount is NOT equal to order input amount
    context.currentAmounts[0] -= 1;

    // mint input tokens
    mintTokens(SIGNER_ADDRESS);

    // add to whitelist
    ROUTER.addAllowedFiller(address(this));

    // run test, revert expected
    vm.expectRevert(abi.encodeWithSelector(CurrentAmountMismatch.selector,
      order.inputs[0].tokenAddress,
      order.inputs[0].tokenAmount,
      0,
      context.currentAmounts[0]));
    ROUTER.fillMultiLimitOrder(order, signature, context);
  }

// 7. Transfer tokens from account
  function test_multi_partiallyFillableFalse_revertIfNotEnoughInputTokens() public {
    // create order
    OdosLimitOrderRouter.MultiLimitOrder memory order = createDefaultMultiLimitOrder();

    uint256 amountOut1 = 2002 * 1e6;
    uint256 amountOut2 = 1998 * 1e18;

    // get order signature
    SignatureValidator.Signature memory signature = getMultiOrderSignature(order);

    // create execution context
    OdosLimitOrderRouter.MultiLimitOrderContext memory context = getDefaultMultiContext(amountOut1, amountOut2);

    // DO NOT mint input tokens
    //mintTokens(SIGNER_ADDRESS);

    // add to whitelist
    ROUTER.addAllowedFiller(address(this));

    // run test, revert expected
    vm.expectRevert("ERC20: insufficient allowance");
    ROUTER.fillMultiLimitOrder(order, signature, context);
  }

// 12. Check slippage, adjust amountOut
  function test_multi_partiallyFillableFalse_revertIfAmountOutSmaller() public {
    // create order
    OdosLimitOrderRouter.MultiLimitOrder memory order = createDefaultMultiLimitOrder();

    uint256 amountOut1 = 2002 * 1e6;
    uint256 amountOut2 = 1998 * 1e18;

    // get order signature
    SignatureValidator.Signature memory signature = getMultiOrderSignature(order);

    // get default executor context, executor output amount is NOT equal to order output amount
    OdosLimitOrderRouter.MultiLimitOrderContext memory context = getDefaultMultiContext(amountOut1 - 1, amountOut2);

    // mint input tokens
    mintTokens(SIGNER_ADDRESS);

    // add to whitelist
    ROUTER.addAllowedFiller(address(this));

    // run test, revert expected
    vm.expectRevert(abi.encodeWithSelector(SlippageLimitExceeded.selector,
      order.outputs[0].tokenAddress,
      order.outputs[0].tokenAmount,
      order.outputs[0].tokenAmount - 1
    ));
    ROUTER.fillMultiLimitOrder(order, signature, context);
  }

// 12. Check slippage, adjust amountOut
  function test_multi_partiallyFillableFalse_amountOutBigger() public {
    // create order
    OdosLimitOrderRouter.MultiLimitOrder memory order = createDefaultMultiLimitOrder();

    // add surplus
    uint256 amountOut1 = 2002 * 1e6 + 4 * 1e6;
    uint256 amountOut2 = 1998 * 1e18;

    // get order signature
    SignatureValidator.Signature memory signature = getMultiOrderSignature(order);

    // get default executor context
    OdosLimitOrderRouter.MultiLimitOrderContext memory context = getDefaultMultiContext(amountOut1, amountOut2);

    // mint input tokens
    mintTokens(SIGNER_ADDRESS);

    // add to whitelist
    ROUTER.addAllowedFiller(address(this));

    MultiLimitOrderHelper memory helper = getOrderHelper(order);
    helper.filledOutputAmounts[0] = 2002 * 1e6;
    helper.filledOutputAmounts[1] = amountOut2;
    helper.surplus[0] = 4 * 1e6;

    // check that event is emitted, check all topics
    vm.expectEmit(true, true, true, true);
    emit MultiLimitOrderFilled(
      ROUTER.getMultiLimitOrderHash(order),
      SIGNER_ADDRESS,
      helper.inputTokens,
      helper.outputTokens,
      context.currentAmounts,
      helper.filledOutputAmounts,
      helper.surplus,
      0,
      0,
      address(0),
      0
    );

    // run test
    ROUTER.fillMultiLimitOrder(order, signature, context);
  }

// 6. Check if fill possible:
//   - If partiallyFillable, total amount do not exceed
  function test_multi_partiallyFillableTrue_partialFillSuccessful() public {
    // create order
    OdosLimitOrderRouter.MultiLimitOrder memory order = createDefaultMultiLimitOrder();

    order.partiallyFillable = true;

    // get order signature
    SignatureValidator.Signature memory signature = getMultiOrderSignature(order);

    uint256 humanAmount1 = 1000;
    uint256 humanAmount2 = 1500;

    uint256 prorationAmount1 = uint256(1e36) * humanAmount1 / order.inputs[0].tokenAmount;
    uint256 prorationAmount2 = uint256(1e36) * humanAmount2 / order.inputs[1].tokenAmount;

    uint256 prorationAmount = prorationAmount1 > prorationAmount2 ? prorationAmount1 : prorationAmount2;

    uint256 amountOut1 = prorationAmount * order.outputs[0].tokenAmount / uint256(1e18);
    uint256 amountOut2 = prorationAmount * order.outputs[1].tokenAmount / uint256(1e18);

    // get default executor context
    OdosLimitOrderRouter.MultiLimitOrderContext memory context = getDefaultMultiContext(amountOut1, amountOut2);

    context.currentAmounts[0] = humanAmount1 * 1e18;
    context.currentAmounts[1] = humanAmount2 * 1e18;

    // mint input tokens
    mintTokens(SIGNER_ADDRESS);

    // add to whitelist
    ROUTER.addAllowedFiller(address(this));

    MultiLimitOrderHelper memory helper = getOrderHelper(order);
    helper.filledOutputAmounts[0] = amountOut1;
    helper.filledOutputAmounts[1] = amountOut2;

    bytes32 orderHash = ROUTER.getMultiLimitOrderHash(order);

    // check that event is emitted, check all topics
    vm.expectEmit(true, true, true, true);
    emit MultiLimitOrderFilled(
      orderHash,
      SIGNER_ADDRESS,
      helper.inputTokens,
      helper.outputTokens,
      context.currentAmounts,
      helper.filledOutputAmounts,
      helper.surplus,
      0,
      0,
      address(0),
      0
    );

    uint256[] memory balancesBefore = new uint256[](2);
    for(uint256 i = 0; i < order.outputs.length; i++) {
      balancesBefore[i] = IERC20(order.outputs[i].tokenAddress).balanceOf(SIGNER_ADDRESS);
    }

    // run test
    ROUTER.fillMultiLimitOrder(order, signature, context);

    assertTrue(IERC20(order.outputs[0].tokenAddress).balanceOf(SIGNER_ADDRESS) - balancesBefore[0] == amountOut1);
    assertTrue(IERC20(order.outputs[1].tokenAddress).balanceOf(SIGNER_ADDRESS) - balancesBefore[1] == amountOut2);

    assertTrue(ROUTER.multiLimitOrders(SIGNER_ADDRESS, orderHash, 0) == context.currentAmounts[0]);
    assertTrue(ROUTER.multiLimitOrders(SIGNER_ADDRESS, orderHash, 1) == context.currentAmounts[1]);
  }

// 6. Check if fill possible:
//   - If partiallyFillable, total amount do not exceed
  function test_multi_partiallyFillableTrue_revertsIfAmountExceeds() public {
    // create order
    OdosLimitOrderRouter.MultiLimitOrder memory order = createDefaultMultiLimitOrder();

    uint256 amountOut1 = 2002 * 1e6;
    uint256 amountOut2 = 1998 * 1e18;

    // get order signature
    SignatureValidator.Signature memory signature = getMultiOrderSignature(order);

    // create execution context
    OdosLimitOrderRouter.MultiLimitOrderContext memory context = getDefaultMultiContext(amountOut1, amountOut2);

    // set currentAmount bigger than orderAmount
    context.currentAmounts[1] = order.inputs[1].tokenAmount + 1 * 1e18;

    // mint input tokens
    mintTokens(SIGNER_ADDRESS);

    // add to whitelist
    ROUTER.addAllowedFiller(address(this));

    // run test, revert expected
    vm.expectRevert(abi.encodeWithSelector(CurrentAmountMismatch.selector,
      order.inputs[1].tokenAddress,
      order.inputs[1].tokenAmount,
      0,
      context.currentAmounts[1]));
    ROUTER.fillMultiLimitOrder(order, signature, context);
  }

// 6. Check if fill possible:
//   - If partiallyFillable, total amount do not exceed
  function test_multi_partiallyFillableTrue_secondPartialFillSuccessful() public {
    // first fill
    test_multi_partiallyFillableTrue_partialFillSuccessful();

    // create order
    OdosLimitOrderRouter.MultiLimitOrder memory order = createDefaultMultiLimitOrder();

    order.partiallyFillable = true;

    // get order signature
    SignatureValidator.Signature memory signature = getMultiOrderSignature(order);

    uint256 humanAmount1 = 999;
    uint256 humanAmount2 = 501;

    uint256 prorationAmount1 = uint256(1e36) * humanAmount1 / order.inputs[0].tokenAmount;
    uint256 prorationAmount2 = uint256(1e36) * humanAmount2 / order.inputs[1].tokenAmount;

    uint256 prorationAmount = prorationAmount1 > prorationAmount2 ? prorationAmount1 : prorationAmount2;

    uint256 amountOut1 = prorationAmount * order.outputs[0].tokenAmount / uint256(1e18);
    uint256 amountOut2 = prorationAmount * order.outputs[1].tokenAmount / uint256(1e18);

    // get default executor context
    OdosLimitOrderRouter.MultiLimitOrderContext memory context = getDefaultMultiContext(amountOut1, amountOut2);

    context.currentAmounts[0] = humanAmount1 * 1e18;
    context.currentAmounts[1] = humanAmount2 * 1e18;

    // mint input tokens
    mintTokens(SIGNER_ADDRESS);

    // add to whitelist
    ROUTER.addAllowedFiller(address(this));

    MultiLimitOrderHelper memory helper = getOrderHelper(order);
    helper.filledOutputAmounts[0] = amountOut1;
    helper.filledOutputAmounts[1] = amountOut2;

    bytes32 orderHash = ROUTER.getMultiLimitOrderHash(order);

    // check that event is emitted, check all topics
    vm.expectEmit(true, true, true, true);
    emit MultiLimitOrderFilled(
      orderHash,
      SIGNER_ADDRESS,
      helper.inputTokens,
      helper.outputTokens,
      context.currentAmounts,
      helper.filledOutputAmounts,
      helper.surplus,
      0,
      0,
      address(0),
      0
    );

    uint256[] memory balancesBefore = new uint256[](2);
    for(uint256 i = 0; i < order.outputs.length; i++) {
      balancesBefore[i] = IERC20(order.outputs[i].tokenAddress).balanceOf(SIGNER_ADDRESS);
    }

    // run test
    ROUTER.fillMultiLimitOrder(order, signature, context);

    assertTrue(IERC20(order.outputs[0].tokenAddress).balanceOf(SIGNER_ADDRESS) - balancesBefore[0] == amountOut1);
    assertTrue(IERC20(order.outputs[1].tokenAddress).balanceOf(SIGNER_ADDRESS) - balancesBefore[1] == amountOut2);

    assertTrue(ROUTER.multiLimitOrders(SIGNER_ADDRESS, orderHash, 0) == order.inputs[0].tokenAmount);
    assertTrue(ROUTER.multiLimitOrders(SIGNER_ADDRESS, orderHash, 1) == order.inputs[1].tokenAmount);
  }

// 6. Check if fill possible:
//   - If partiallyFillable, total amount do not exceed
  function test_multi_partiallyFillableTrue_revertsIfSecondPartialFillExceeds() public {
    // first fill
    test_multi_partiallyFillableTrue_partialFillSuccessful();

    // create order
    OdosLimitOrderRouter.MultiLimitOrder memory order = createDefaultMultiLimitOrder();

    order.partiallyFillable = true;

    // get order signature
    SignatureValidator.Signature memory signature = getMultiOrderSignature(order);

    // second amount exceeds
    uint256 humanAmount1 = 999;
    uint256 humanAmount2 = 502;

    uint256 prorationAmount1 = uint256(1e36) * humanAmount1 / order.inputs[0].tokenAmount;
    uint256 prorationAmount2 = uint256(1e36) * humanAmount2 / order.inputs[1].tokenAmount;

    uint256 prorationAmount = prorationAmount1 > prorationAmount2 ? prorationAmount1 : prorationAmount2;

    uint256 amountOut1 = prorationAmount * order.outputs[0].tokenAmount / uint256(1e18);
    uint256 amountOut2 = prorationAmount * order.outputs[1].tokenAmount / uint256(1e18);

    // get default executor context
    OdosLimitOrderRouter.MultiLimitOrderContext memory context = getDefaultMultiContext(amountOut1, amountOut2);

    context.currentAmounts[0] = humanAmount1 * 1e18;
    context.currentAmounts[1] = humanAmount2 * 1e18;

    // mint input tokens
    mintTokens(SIGNER_ADDRESS);

    // add to whitelist
    ROUTER.addAllowedFiller(address(this));

    // run test, revert expected
    vm.expectRevert(abi.encodeWithSelector(CurrentAmountMismatch.selector,
      order.inputs[1].tokenAddress,
      order.inputs[1].tokenAmount,
      1500 * 1e18,
      context.currentAmounts[1]));
    ROUTER.fillMultiLimitOrder(order, signature, context);
  }

// 6. Check if fill possible:
//   - If partiallyFillable, total amount do not exceed
  function test_multi_partiallyFillableTrue_revertsIfCancelled() public {
    // first fill
    test_multi_partiallyFillableTrue_partialFillSuccessful();

    // create order
    OdosLimitOrderRouter.MultiLimitOrder memory order = createDefaultMultiLimitOrder();

    order.partiallyFillable = true;

    // get order signature
    SignatureValidator.Signature memory signature = getMultiOrderSignature(order);

    // second amount exceeds
    uint256 humanAmount1 = 999;
    uint256 humanAmount2 = 502;

    uint256 prorationAmount1 = uint256(1e36) * humanAmount1 / order.inputs[0].tokenAmount;
    uint256 prorationAmount2 = uint256(1e36) * humanAmount2 / order.inputs[1].tokenAmount;

    uint256 prorationAmount = prorationAmount1 > prorationAmount2 ? prorationAmount1 : prorationAmount2;

    uint256 amountOut1 = prorationAmount * order.outputs[0].tokenAmount / uint256(1e18);
    uint256 amountOut2 = prorationAmount * order.outputs[1].tokenAmount / uint256(1e18);

    // get default executor context
    OdosLimitOrderRouter.MultiLimitOrderContext memory context = getDefaultMultiContext(amountOut1, amountOut2);

    context.currentAmounts[0] = humanAmount1 * 1e18;
    context.currentAmounts[1] = humanAmount2 * 1e18;

    // mint input tokens
    mintTokens(SIGNER_ADDRESS);

    // add to whitelist
    ROUTER.addAllowedFiller(address(this));

    bytes32 orderHash = ROUTER.getMultiLimitOrderHash(order);

    // check that event is emitted, check all topics
    vm.expectEmit(true, true, true, true);
    emit MultiLimitOrderCancelled(orderHash, SIGNER_ADDRESS);

    // cancel order by the account
    vm.prank(SIGNER_ADDRESS);
    ROUTER.cancelMultiLimitOrder(orderHash);

    // run test
    vm.expectRevert(abi.encodeWithSelector(OrderCancelled.selector, orderHash));
    ROUTER.fillMultiLimitOrder(order, signature, context);
  }

// 1. Check msg.sender allowed
  function test_multi_noCancelByAnotherAddress() public {
    // create order
    OdosLimitOrderRouter.MultiLimitOrder memory order = createDefaultMultiLimitOrder();

    uint256 amountOut1 = 2002 * 1e6;
    uint256 amountOut2 = 1998 * 1e18;

    // get order signature
    SignatureValidator.Signature memory signature = getMultiOrderSignature(order);

    // create execution context
    OdosLimitOrderRouter.MultiLimitOrderContext memory context = getDefaultMultiContext(amountOut1, amountOut2);

    // mint input tokens
    mintTokens(SIGNER_ADDRESS);
    // add to whitelist
    ROUTER.addAllowedFiller(address(this));

    bytes32 orderHash = ROUTER.getMultiLimitOrderHash(order);

    // check that event is emitted, check all topics
    vm.expectEmit(true, true, true, true);
    emit MultiLimitOrderCancelled(orderHash, address(this));

    // try to cancel order by another address
    // it WILL NOT cancel the order for the original account
    ROUTER.cancelMultiLimitOrder(orderHash);

    MultiLimitOrderHelper memory helper = getOrderHelper(order);

    // check that event is emitted, check all topics
    vm.expectEmit(true, true, true, true);
    emit MultiLimitOrderFilled(
      orderHash,
      SIGNER_ADDRESS,
      helper.inputTokens,
      helper.outputTokens,
      context.currentAmounts,
      helper.filledOutputAmounts,
      helper.surplus,
      0,
      0,
      address(0),
      0
    );

    uint256[] memory balancesBefore = new uint256[](2);
    for(uint256 i = 0; i < order.outputs.length; i++) {
      balancesBefore[i] = IERC20(order.outputs[i].tokenAddress).balanceOf(SIGNER_ADDRESS);
    }

    // run test
    ROUTER.fillMultiLimitOrder(order, signature, context);

    assertTrue(IERC20(order.outputs[0].tokenAddress).balanceOf(SIGNER_ADDRESS) - balancesBefore[0] == amountOut1);
    assertTrue(IERC20(order.outputs[1].tokenAddress).balanceOf(SIGNER_ADDRESS) - balancesBefore[1] == amountOut2);

    assertTrue(ROUTER.multiLimitOrders(SIGNER_ADDRESS, orderHash, 0) == order.inputs[0].tokenAmount);
    assertTrue(ROUTER.multiLimitOrders(SIGNER_ADDRESS, orderHash, 1) == order.inputs[1].tokenAmount);
  }

  function test_multi_permit2_multi_succeeds() public {
    // create order
    OdosLimitOrderRouter.MultiLimitOrder memory order = createDefaultMultiLimitOrder();

    uint256 amountOut1 = 2002 * 1e6;
    uint256 amountOut2 = 1998 * 1e18;

    // create execution context
    OdosLimitOrderRouter.MultiLimitOrderContext memory context = getDefaultMultiContext(amountOut1, amountOut2);

    // add to whitelist
    ROUTER.addAllowedFiller(address(this));

    // mint input tokens
    mintTokens(SIGNER_ADDRESS);

    // get permit2
    bytes32 orderStructHash = ROUTER.getMultiLimitOrderStructHash(order);
    OdosLimitOrderRouter.Permit2Info memory swap_permit = createMultiLimitOrderPermit2(order, context, orderStructHash, SIGNER_ADDRESS);

    // approve Permit2 contract
    for (uint256 i = 0; i < order.inputs.length; i++) {
      vm.prank(SIGNER_ADDRESS);
      MockERC20(order.inputs[i].tokenAddress).approve(address(PERMIT2), type(uint256).max);
    }

    uint256[] memory balancesBefore = new uint256[](2);
    for(uint256 i = 0; i < order.outputs.length; i++) {
      balancesBefore[i] = IERC20(order.outputs[i].tokenAddress).balanceOf(SIGNER_ADDRESS);
    }

    bytes32 orderHash = ROUTER.getMultiLimitOrderHash(order);

    MultiLimitOrderHelper memory helper = getOrderHelper(order);

    // check that event is emitted, check all topics
    vm.expectEmit(true, true, true, true);
    emit MultiLimitOrderFilled(
      orderHash,
      SIGNER_ADDRESS,
      helper.inputTokens,
      helper.outputTokens,
      context.currentAmounts,
      helper.filledOutputAmounts,
      helper.surplus,
      0,
      0,
      address(0),
      0
    );

    // run test
    ROUTER.fillMultiLimitOrderPermit2(order, context, swap_permit);

    assertTrue(IERC20(order.outputs[0].tokenAddress).balanceOf(SIGNER_ADDRESS) - balancesBefore[0] == amountOut1);
    assertTrue(IERC20(order.outputs[1].tokenAddress).balanceOf(SIGNER_ADDRESS) - balancesBefore[1] == amountOut2);

    assertTrue(ROUTER.multiLimitOrders(SIGNER_ADDRESS, orderHash, 0) == order.inputs[0].tokenAmount);
    assertTrue(ROUTER.multiLimitOrders(SIGNER_ADDRESS, orderHash, 1) == order.inputs[1].tokenAmount);
  }

  function test_one_to_many_permit2_multi_succeeds() public {
    // create order
    OdosLimitOrderRouter.MultiLimitOrder memory order = createDefaultOneToManyLimitOrder();

    uint256 amountOut1 = 2002 * 1e6;
    uint256 amountOut2 = 1998 * 1e18;

    // create execution context
    OdosLimitOrderRouter.MultiLimitOrderContext memory context = getDefaultOneToManyContext(amountOut1, amountOut2);

    // add to whitelist
    ROUTER.addAllowedFiller(address(this));

    // mint input tokens
    mintTokens(SIGNER_ADDRESS);

  
    // get permit2
    bytes32 orderStructHash = ROUTER.getMultiLimitOrderStructHash(order);
    OdosLimitOrderRouter.Permit2Info memory swap_permit = createMultiLimitOrderPermit2(order, context, orderStructHash, SIGNER_ADDRESS);


    // approve Permit2 contract
    for (uint256 i = 0; i < order.inputs.length; i++) {
      vm.prank(SIGNER_ADDRESS);
      MockERC20(order.inputs[i].tokenAddress).approve(address(PERMIT2), type(uint256).max);
    }
    uint256[] memory balancesBefore = new uint256[](2);
    for(uint256 i = 0; i < order.outputs.length; i++) {
      balancesBefore[i] = IERC20(order.outputs[i].tokenAddress).balanceOf(SIGNER_ADDRESS);
    }

    bytes32 orderHash = ROUTER.getMultiLimitOrderHash(order);

    MultiLimitOrderHelper memory helper = getOrderHelper(order);

    // check that event is emitted, check all topics
    vm.expectEmit(true, true, true, true);
    emit MultiLimitOrderFilled(
      orderHash,
      SIGNER_ADDRESS,
      helper.inputTokens,
      helper.outputTokens,
      context.currentAmounts,
      helper.filledOutputAmounts,
      helper.surplus,
      0,
      0,
      address(0),
      0
    );

    // run test
    ROUTER.fillMultiLimitOrderPermit2(order, context, swap_permit);

    assertTrue(IERC20(order.outputs[0].tokenAddress).balanceOf(SIGNER_ADDRESS) - balancesBefore[0] == amountOut1);
    assertTrue(IERC20(order.outputs[1].tokenAddress).balanceOf(SIGNER_ADDRESS) - balancesBefore[1] == amountOut2);

    assertTrue(ROUTER.multiLimitOrders(SIGNER_ADDRESS, orderHash, 0) == order.inputs[0].tokenAmount);
  }

  function test_many_to_one_permit2_multi_succeeds() public {
    // create order
    OdosLimitOrderRouter.MultiLimitOrder memory order = createDefaultManyToOneLimitOrder();

    uint256 amountOut1 = 2002 * 1e6;

    // create execution context
    OdosLimitOrderRouter.MultiLimitOrderContext memory context = getDefaultManyToOneContext(amountOut1);

    // add to whitelist
    ROUTER.addAllowedFiller(address(this));

    // mint input tokens
    mintTokens(SIGNER_ADDRESS);

    // get permit2
    bytes32 orderStructHash = ROUTER.getMultiLimitOrderStructHash(order);
    OdosLimitOrderRouter.Permit2Info memory swap_permit = createMultiLimitOrderPermit2(order, context, orderStructHash, SIGNER_ADDRESS);

    // approve Permit2 contract
    for (uint256 i = 0; i < order.inputs.length; i++) {
      vm.prank(SIGNER_ADDRESS);
      MockERC20(order.inputs[i].tokenAddress).approve(address(PERMIT2), type(uint256).max);
    }

    uint256[] memory balancesBefore = new uint256[](1);
    balancesBefore[0] = IERC20(order.outputs[0].tokenAddress).balanceOf(SIGNER_ADDRESS);

    bytes32 orderHash = ROUTER.getMultiLimitOrderHash(order);

    MultiLimitOrderHelper memory helper = getOrderHelper(order);

    // check that event is emitted, check all topics
    vm.expectEmit(true, true, true, true);
    emit MultiLimitOrderFilled(
      orderHash,
      SIGNER_ADDRESS,
      helper.inputTokens,
      helper.outputTokens,
      context.currentAmounts,
      helper.filledOutputAmounts,
      helper.surplus,
      0,
      0,
      address(0),
      0
    );

    // run test
    ROUTER.fillMultiLimitOrderPermit2(order, context, swap_permit);

    assertTrue(IERC20(order.outputs[0].tokenAddress).balanceOf(SIGNER_ADDRESS) - balancesBefore[0] == amountOut1);

    assertTrue(ROUTER.multiLimitOrders(SIGNER_ADDRESS, orderHash, 0) == order.inputs[0].tokenAmount);
    assertTrue(ROUTER.multiLimitOrders(SIGNER_ADDRESS, orderHash, 1) == order.inputs[1].tokenAmount);
  }

  function test_multi_permit2_EIP1271_multi_succeeds() public {
    // create order
    OdosLimitOrderRouter.MultiLimitOrder memory order = createDefaultMultiLimitOrder();

    uint256 amountOut1 = 2002 * 1e6;
    uint256 amountOut2 = 1998 * 1e18;

    // create execution context
    OdosLimitOrderRouter.MultiLimitOrderContext memory context = getDefaultMultiContext(amountOut1, amountOut2);

    // add to whitelist
    ROUTER.addAllowedFiller(address(this));

    // deploy a smart contract wallet
    MockSmartContractWallet SCW = new MockSmartContractWallet("", "");
    address SCW_ADDRESS = address(SCW);

    // mint input tokens to SCW
    mintTokens(SCW_ADDRESS);

    // get permit2
    bytes32 orderStructHash = ROUTER.getMultiLimitOrderStructHash(order);
    OdosLimitOrderRouter.Permit2Info memory swap_permit = createMultiLimitOrderPermit2(order, context, orderStructHash, SCW_ADDRESS);

    // get Permit2 with witness hash
    bytes32 permit2Hash = getBatchPermitWitnessHash(order, context, swap_permit, orderStructHash, address(ROUTER));

    // set expected hash and signature
    SCW.setExpected(permit2Hash, swap_permit.signature);

    // approve Permit2 contract for SCW
    for (uint256 i = 0; i < order.inputs.length; i++) {
      vm.prank(SCW_ADDRESS);
      MockERC20(order.inputs[i].tokenAddress).approve(address(PERMIT2), type(uint256).max);
    }

    uint256[] memory balancesBefore = new uint256[](2);
    for(uint256 i = 0; i < order.outputs.length; i++) {
      balancesBefore[i] = IERC20(order.outputs[i].tokenAddress).balanceOf(SIGNER_ADDRESS);
    }

    bytes32 orderHash = ROUTER.getMultiLimitOrderHash(order);

    MultiLimitOrderHelper memory helper = getOrderHelper(order);

    // check that event is emitted, check all topics
    vm.expectEmit(true, true, true, true);
    emit MultiLimitOrderFilled(
      orderHash,
      SCW_ADDRESS,
      helper.inputTokens,
      helper.outputTokens,
      context.currentAmounts,
      helper.filledOutputAmounts,
      helper.surplus,
      0,
      0,
      address(0),
      0
    );

    // run test
    ROUTER.fillMultiLimitOrderPermit2(order, context, swap_permit);

    assertTrue(IERC20(order.outputs[0].tokenAddress).balanceOf(SCW_ADDRESS) - balancesBefore[0] == amountOut1);
    assertTrue(IERC20(order.outputs[1].tokenAddress).balanceOf(SCW_ADDRESS) - balancesBefore[1] == amountOut2);

    assertTrue(ROUTER.multiLimitOrders(SCW_ADDRESS, orderHash, 0) == order.inputs[0].tokenAmount);
    assertTrue(ROUTER.multiLimitOrders(SCW_ADDRESS, orderHash, 1) == order.inputs[1].tokenAmount);
  }

  function test_multi_referralCodeFee_succeeds() public {
    // create order
    OdosLimitOrderRouter.MultiLimitOrder memory order = createDefaultMultiLimitOrder();

    // set the referral code with fee
    order.referralCode = REFERRAL_CODE_FEE;
    order.referralFee = REFERRAL_FEE;
    order.referralFeeRecipient = REFERRAL_BENEFICIARY_ADDRESS_FEE;

    uint256 amountOut1 = 2005 * 1e6;
    uint256 amountOut2 = 2003 * 1e18;

    // calculate beneficiary amount
    uint256 beneficiaryAmount1 = amountOut1 * REFERRAL_FEE * 8 / (FEE_DENOM * 10);
    uint256 beneficiaryAmount2 = amountOut2 * REFERRAL_FEE * 8 / (FEE_DENOM * 10);

    // get order signature
    SignatureValidator.Signature memory signature = getMultiOrderSignature(order);

    // create execution context
    OdosLimitOrderRouter.MultiLimitOrderContext memory context = getDefaultMultiContext(amountOut1, amountOut2);

    // mint input tokens
    mintTokens(SIGNER_ADDRESS);
    // add to whitelist
    ROUTER.addAllowedFiller(address(this));

    uint256[] memory balancesBefore = new uint256[](2);
    for(uint256 i = 0; i < order.outputs.length; i++) {
      balancesBefore[i] = IERC20(order.outputs[i].tokenAddress).balanceOf(SIGNER_ADDRESS);
    }

    bytes32 orderHash = ROUTER.getMultiLimitOrderHash(order);

    MultiLimitOrderHelper memory helper = getOrderHelper(order);

    helper.surplus[0] = amountOut1 - amountOut1 * REFERRAL_FEE / FEE_DENOM - order.outputs[0].tokenAmount;
    helper.surplus[1] = amountOut2 - amountOut2 * REFERRAL_FEE / FEE_DENOM - order.outputs[1].tokenAmount;

    // check that event is emitted, check all topics
    vm.expectEmit(true, true, true, true);
    emit MultiLimitOrderFilled(
      orderHash,
      SIGNER_ADDRESS,
      helper.inputTokens,
      helper.outputTokens,
      context.currentAmounts,
      helper.filledOutputAmounts,
      helper.surplus,
      REFERRAL_CODE_FEE,
      REFERRAL_FEE,
      REFERRAL_BENEFICIARY_ADDRESS_FEE,
      0
    );

    // run test
    ROUTER.fillMultiLimitOrder(order, signature, context);

    assert(beneficiaryAmount1 == IERC20(order.outputs[0].tokenAddress).balanceOf(REFERRAL_BENEFICIARY_ADDRESS_FEE));
    assert(beneficiaryAmount2 == IERC20(order.outputs[1].tokenAddress).balanceOf(REFERRAL_BENEFICIARY_ADDRESS_FEE));

    assert(IERC20(order.outputs[0].tokenAddress).balanceOf(SIGNER_ADDRESS) - balancesBefore[0] == order.outputs[0].tokenAmount);
    assert(IERC20(order.outputs[1].tokenAddress).balanceOf(SIGNER_ADDRESS) - balancesBefore[1] == order.outputs[1].tokenAmount);

    assertTrue(ROUTER.multiLimitOrders(SIGNER_ADDRESS, orderHash, 0) == order.inputs[0].tokenAmount);
    assertTrue(ROUTER.multiLimitOrders(SIGNER_ADDRESS, orderHash, 1) == order.inputs[1].tokenAmount);
  }

  function test_multi_referralCodeFee_reverts() public {
    // create order
    OdosLimitOrderRouter.MultiLimitOrder memory order = createDefaultMultiLimitOrder();

    // set the referral code with fee
    order.referralCode = REFERRAL_CODE_FEE;
    order.referralFee = REFERRAL_FEE;
    order.referralFeeRecipient = REFERRAL_BENEFICIARY_ADDRESS_FEE;

    uint256 amountOut1 = 2002 * 1e6;
    uint256 amountOut2 = 2001 * 1e18;

    // get order signature
    SignatureValidator.Signature memory signature = getMultiOrderSignature(order);

    // create execution context
    OdosLimitOrderRouter.MultiLimitOrderContext memory context = getDefaultMultiContext(amountOut1, amountOut2);

    // mint input tokens
    mintTokens(SIGNER_ADDRESS);
    // add to whitelist
    ROUTER.addAllowedFiller(address(this));

    // run test
    vm.expectRevert(abi.encodeWithSelector(SlippageLimitExceeded.selector, order.outputs[0].tokenAddress,
      order.outputs[0].tokenAmount, amountOut1 * (FEE_DENOM - REFERRAL_FEE) / FEE_DENOM));
    ROUTER.fillMultiLimitOrder(order, signature, context);
  }

  function test_multi_referralCodeTrack_succeeds() public {
    // create order
    OdosLimitOrderRouter.MultiLimitOrder memory order = createDefaultMultiLimitOrder();

    // set the referral code with track only
    order.referralCode = REFERRAL_CODE_TRACK;
    order.referralFeeRecipient = REFERRAL_BENEFICIARY_ADDRESS_TRACK;

    uint256 amountOut1 = 2002 * 1e6;
    uint256 amountOut2 = 1998 * 1e18;

    // get order signature
    SignatureValidator.Signature memory signature = getMultiOrderSignature(order);

    // create execution context
    OdosLimitOrderRouter.MultiLimitOrderContext memory context = getDefaultMultiContext(amountOut1, amountOut2);

    // mint input tokens
    mintTokens(SIGNER_ADDRESS);
    // add to whitelist
    ROUTER.addAllowedFiller(address(this));

    uint256[] memory balancesBefore = new uint256[](2);
    for(uint256 i = 0; i < order.outputs.length; i++) {
      balancesBefore[i] = IERC20(order.outputs[i].tokenAddress).balanceOf(SIGNER_ADDRESS);
    }
    bytes32 orderHash = ROUTER.getMultiLimitOrderHash(order);

    MultiLimitOrderHelper memory helper = getOrderHelper(order);

    // check that event is emitted, check all topics
    vm.expectEmit(true, true, true, true);
    emit MultiLimitOrderFilled(
      orderHash,
      SIGNER_ADDRESS,
      helper.inputTokens,
      helper.outputTokens,
      context.currentAmounts,
      helper.filledOutputAmounts,
      helper.surplus,
      REFERRAL_CODE_TRACK,
      0,
      REFERRAL_BENEFICIARY_ADDRESS_TRACK,
      0
    );

    // run test
    ROUTER.fillMultiLimitOrder(order, signature, context);

    assertTrue(IERC20(order.outputs[0].tokenAddress).balanceOf(SIGNER_ADDRESS) - balancesBefore[0] == amountOut1);
    assertTrue(IERC20(order.outputs[1].tokenAddress).balanceOf(SIGNER_ADDRESS) - balancesBefore[1] == amountOut2);

    assertTrue(ROUTER.multiLimitOrders(SIGNER_ADDRESS, orderHash, 0) == order.inputs[0].tokenAmount);
    assertTrue(ROUTER.multiLimitOrders(SIGNER_ADDRESS, orderHash, 1) == order.inputs[1].tokenAmount);
  }

  function test_multi_surplusCheck_reverts() public {
    // create order
    OdosLimitOrderRouter.MultiLimitOrder memory order = createDefaultMultiLimitOrder();

    uint256 amountOut1 = 2002 * 1e6;
    // 2 as surplus
    uint256 amountOut2 = 1998 * 1e18 + 2;

    // get order signature
    SignatureValidator.Signature memory signature = getMultiOrderSignature(order);

    // create execution context
    OdosLimitOrderRouter.MultiLimitOrderContext memory context = getDefaultMultiContext(amountOut1, amountOut2);
    context.minSurplus[1] = 1000;

    // mint input tokens
    mintTokens(SIGNER_ADDRESS);
    // add to whitelist
    ROUTER.addAllowedFiller(address(this));

    uint256[] memory balancesBefore = new uint256[](2);
    for(uint256 i = 0; i < order.outputs.length; i++) {
      balancesBefore[i] = IERC20(order.outputs[i].tokenAddress).balanceOf(SIGNER_ADDRESS);
    }

    // run test
    vm.expectRevert(abi.encodeWithSelector(MinSurplusCheckFailed.selector, order.outputs[1].tokenAddress, context.minSurplus[1], 2));
    ROUTER.fillMultiLimitOrder(order, signature, context);
  }
}
