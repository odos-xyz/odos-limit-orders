// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import "forge-std/Test.sol";
import {EIP712} from "@openzeppelin/contracts/utils/cryptography/EIP712.sol";
import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC20Errors} from "../interfaces/draft-IERC6093.sol";

import "../contracts/OdosLimitOrderRouter.sol";
import "../interfaces/IOdosExecutor.sol";
import {MockOdosExecutor} from "./MockOdosExecutor.sol";
import {MockERC20} from "./MockERC20.sol";
import "./OdosLimitOrderHelper.t.sol";
import "./MockSmartContractWallet.sol";


/// @notice This contract tests single limit order functionality
contract OdosLimitOrderSingleTest is OdosLimitOrderHelperTest {

  event LimitOrderFilled(
    bytes32 indexed orderHash,
    address indexed orderOwner,
    address inputToken,
    address outputToken,
    uint256 filledInputAmount,
    uint256 filledOutputAmount,
    uint256 surplus,
    uint64 referralCode,
    uint64 referralFee,
    address referralFeeRecipient,
    uint256 orderType
  );

  event LimitOrderCancelled(
    bytes32 indexed orderHash,
    address indexed orderOwner
  );

  struct TestHelper {
    uint256 beneficiaryAmount;
    uint256 usdcBalanceBefore;
  }

  function test_Signature() public {
    // construct order with default test parameters
    OdosLimitOrderRouter.LimitOrder memory order = createDefaultLimitOrder();

    // sign order
    SignatureValidator.Signature memory signature = getOrderSignature(order);

    bytes32 orderHash = ROUTER.getLimitOrderHash(order);

    address recoveredAddress = ECDSA.recover(orderHash, signature.signature);
    assertTrue(SIGNER_ADDRESS == recoveredAddress);
  }

// 1. Check msg.sender allowed
  function test_msgSenderCheck_succeeds() public {
    // construct order with default test parameters
    OdosLimitOrderRouter.LimitOrder memory order = createDefaultLimitOrder();

    // sign order
    SignatureValidator.Signature memory signature = getOrderSignature(order);

    // get default executor context, executor output amount is equal to order output amount
    OdosLimitOrderRouter.LimitOrderContext memory context = getDefaultContext(order.output.tokenAmount);

    // mint input token
    mintToken(order.input.tokenAddress, order.input.tokenAmount);

    // whitelist this address
    ROUTER.addAllowedFiller(address(this));

    uint256 usdcBalanceBefore = IERC20(USDC).balanceOf(SIGNER_ADDRESS);

    bytes32 orderHash = ROUTER.getLimitOrderHash(order);

    // check that event is emitted, check all topics
    vm.expectEmit(true, true, true, true);
    emit LimitOrderFilled(
      orderHash,
      SIGNER_ADDRESS,
      DAI,
      USDC,
      2001 * 1e18,
      2001 * 1e6,
      0,
      0,
      0,
      address(0),
      0
    );

    // run test
    ROUTER.fillLimitOrder(order, signature, context);

    uint256 usdcBalanceDiff = IERC20(USDC).balanceOf(SIGNER_ADDRESS) - usdcBalanceBefore;
    assertTrue(usdcBalanceDiff == 2001 * 1e6);

    assertTrue(ROUTER.limitOrders(SIGNER_ADDRESS, orderHash) == order.input.tokenAmount);
  }

  function test_eth_output_succeeds() public {
    // construct order with default test parameters
    OdosLimitOrderRouter.LimitOrder memory order = createDefaultLimitOrder();

    order.output = OdosLimitOrderRouter.TokenInfo(address(0), 2001 * 1e18);

    // sign order
    SignatureValidator.Signature memory signature = getOrderSignature(order);

    // get default executor context, executor output amount is equal to order output amount
    OdosLimitOrderRouter.LimitOrderContext memory context = getDefaultContext(order.output.tokenAmount);

    address[] memory tokensOut = new address[](1);
    tokensOut[0] = address(0);

    uint256[] memory amountsOut = new uint256[](1);
    amountsOut[0] = 2001 * 1e18;

    context.pathDefinition = abi.encode(tokensOut, amountsOut);

    // mint input token
    mintToken(order.input.tokenAddress, order.input.tokenAmount);

    // whitelist this address
    ROUTER.addAllowedFiller(address(this));

    uint256 balanceBefore = SIGNER_ADDRESS.balance;

    bytes32 orderHash = ROUTER.getLimitOrderHash(order);

    // check that event is emitted, check all topics
    vm.expectEmit(true, true, true, true);
    emit LimitOrderFilled(
      orderHash,
      SIGNER_ADDRESS,
      DAI,
      address(0),
      2001 * 1e18,
      2001 * 1e18,
      0,
      0,
      0,
      address(0),
      0
    );

    // run test
    ROUTER.fillLimitOrder(order, signature, context);

    uint256 balanceDiff = SIGNER_ADDRESS.balance - balanceBefore;
    assertTrue(balanceDiff == 2001 * 1e18);

    assertTrue(ROUTER.limitOrders(SIGNER_ADDRESS, orderHash) == order.input.tokenAmount);
  }

  function test_orderType_emitted() public {
    // construct order with default test parameters
    OdosLimitOrderRouter.LimitOrder memory order = createDefaultLimitOrder();

    // sign order
    SignatureValidator.Signature memory signature = getOrderSignature(order);

    // get default executor context, executor output amount is equal to order output amount
    OdosLimitOrderRouter.LimitOrderContext memory context = getDefaultContext(order.output.tokenAmount);

    uint256 expectedOrderType = 1234567890;
    context.orderType = expectedOrderType;

    // mint input token
    mintToken(order.input.tokenAddress, order.input.tokenAmount);

    // whitelist this address
    ROUTER.addAllowedFiller(address(this));

    uint256 usdcBalanceBefore = IERC20(USDC).balanceOf(SIGNER_ADDRESS);

    bytes32 orderHash = ROUTER.getLimitOrderHash(order);

    // check that event is emitted, check all topics
    vm.expectEmit(true, true, true, true);
    emit LimitOrderFilled(
      orderHash,
      SIGNER_ADDRESS,
      DAI,
      USDC,
      2001 * 1e18,
      2001 * 1e6,
      0,
      0,
      0,
      address(0),
      expectedOrderType
    );

    // run test
    ROUTER.fillLimitOrder(order, signature, context);

    uint256 usdcBalanceDiff = IERC20(USDC).balanceOf(SIGNER_ADDRESS) - usdcBalanceBefore;
    assertTrue(usdcBalanceDiff == 2001 * 1e6);

    assertTrue(ROUTER.limitOrders(SIGNER_ADDRESS, orderHash) == order.input.tokenAmount);
  }

// 1. Check msg.sender allowed
  function test_msgSenderCheck_reverts() public {
    // construct order with default test parameters
    OdosLimitOrderRouter.LimitOrder memory order = createDefaultLimitOrder();

    // sign order
    SignatureValidator.Signature memory signature = getOrderSignature(order);

    // get default executor context, executor output amount is equal to order output amount
    OdosLimitOrderRouter.LimitOrderContext memory context = getDefaultContext(order.output.tokenAmount);

    // mint input token
    mintToken(order.input.tokenAddress, order.input.tokenAmount);

    // DO NOT add to whitelist
    // ROUTER.addAllowedFiller(address(this));

    // run test, revert expected
    vm.expectRevert(abi.encodeWithSelector(AddressNotAllowed.selector, address(this)));
    ROUTER.fillLimitOrder(order, signature, context);
  }

  function test_feeToHigh_reverts() public {
    // construct order with default test parameters
    OdosLimitOrderRouter.LimitOrder memory order = createDefaultLimitOrder();

    order.referralCode = 1;
    order.referralFee = 1e18 / 50 + 1;
    order.referralFeeRecipient = address(this);

    // sign order
    SignatureValidator.Signature memory signature = getOrderSignature(order);

    // get default executor context, executor output amount is equal to order output amount
    OdosLimitOrderRouter.LimitOrderContext memory context = getDefaultContext(order.output.tokenAmount);

    // mint input token
    mintToken(order.input.tokenAddress, order.input.tokenAmount);

    // whitelist this address
    ROUTER.addAllowedFiller(address(this));

    // run test, revert expected
    vm.expectRevert(abi.encodeWithSelector(InvalidReferralFee.selector, order.referralFee));
    ROUTER.fillLimitOrder(order, signature, context);
  }

// 2. Check if order still valid
  function test_orderExpiry_reverts() public {
    // construct order with default test parameters
    OdosLimitOrderRouter.LimitOrder memory order = createDefaultLimitOrder();

    // make order expired
    order.expiry = block.timestamp - 1;

    // sign order
    SignatureValidator.Signature memory signature = getOrderSignature(order);

    // get default executor context, executor output amount is equal to order output amount
    OdosLimitOrderRouter.LimitOrderContext memory context = getDefaultContext(order.output.tokenAmount);

    // mint input token
    mintToken(order.input.tokenAddress, order.input.tokenAmount);

    // whitelist this address
    ROUTER.addAllowedFiller(address(this));

    // run test, revert expected
    vm.expectRevert(abi.encodeWithSelector(OrderExpired.selector, order.expiry, block.timestamp));
    ROUTER.fillLimitOrder(order, signature, context);
  }

// 3. Check tokens, amounts
  function test_tokens_revertsIfInputTokenEth() public {
    // construct order with default test parameters
    OdosLimitOrderRouter.LimitOrder memory order = createDefaultLimitOrder();

    // set input token to _ETH, but only ERC20 is allowed, so it should revert
    order.input.tokenAddress = _ETH;

    // sign order
    SignatureValidator.Signature memory signature = getOrderSignature(order);

    // get default executor context, executor output amount is equal to order output amount
    OdosLimitOrderRouter.LimitOrderContext memory context = getDefaultContext(order.output.tokenAmount);

    // mint input token
    mintToken(order.input.tokenAddress, order.input.tokenAmount);

    // whitelist this address
    ROUTER.addAllowedFiller(address(this));

    // run test, revert expected
    vm.expectRevert();
    ROUTER.fillLimitOrder(order, signature, context);
  }

// 3. Check tokens, amounts
  function test_tokens_revertsIfOutputTokenEth() public {
    // construct order with default test parameters
    OdosLimitOrderRouter.LimitOrder memory order = createDefaultLimitOrder();

    // set output token to _ETH, but only ERC20 is allowed, so it should revert
    order.output.tokenAddress = _ETH;

    // sign order
    SignatureValidator.Signature memory signature = getOrderSignature(order);

    // get default executor context, executor output amount is equal to order output amount
    OdosLimitOrderRouter.LimitOrderContext memory context = getDefaultContext(order.output.tokenAmount);

    // mint input token
    mintToken(order.input.tokenAddress, order.input.tokenAmount);

    // whitelist this address
    ROUTER.addAllowedFiller(address(this));

    // run test, revert expected
    vm.expectRevert();
    ROUTER.fillLimitOrder(order, signature, context);
  }

// 3. Check tokens, amounts
  function test_tokens_revertsIfInputTokenEqualToOutputToken() public {
    // construct order with default test parameters
    OdosLimitOrderRouter.LimitOrder memory order = createDefaultLimitOrder();

    // set output token equal to input token, which is not allowed
    order.output.tokenAddress = order.input.tokenAddress;

    // sign order
    SignatureValidator.Signature memory signature = getOrderSignature(order);

    // get default executor context, executor output amount is equal to order output amount
    OdosLimitOrderRouter.LimitOrderContext memory context = getDefaultContext(order.output.tokenAmount);

    // mint input token
    mintToken(order.input.tokenAddress, order.input.tokenAmount);

    // whitelist this address
    ROUTER.addAllowedFiller(address(this));

    // run test, revert expected
    vm.expectRevert(abi.encodeWithSelector(ArbitrageNotAllowed.selector, order.output.tokenAddress));
    ROUTER.fillLimitOrder(order, signature, context);
  }

// 6. Check if fill possible:
//   - If not partiallyFillable - it was not filled previously
  function test_partiallyFillableFalse_revertsIfAlreadyFilled() public {
    // construct order with default test parameters
    OdosLimitOrderRouter.LimitOrder memory order = createDefaultLimitOrder();

    // sign order
    SignatureValidator.Signature memory signature = getOrderSignature(order);

    // get default executor context, executor output amount is equal to order output amount
    OdosLimitOrderRouter.LimitOrderContext memory context = getDefaultContext(order.output.tokenAmount);

    // mint input token
    mintToken(order.input.tokenAddress, order.input.tokenAmount);

    // whitelist this address
    ROUTER.addAllowedFiller(address(this));

    uint256 usdcBalanceBefore = IERC20(USDC).balanceOf(SIGNER_ADDRESS);

    // check that event is emitted, check all topics
    vm.expectEmit(true, true, true, true);
    emit LimitOrderFilled(
      ROUTER.getLimitOrderHash(order),
      SIGNER_ADDRESS,
      DAI,
      USDC,
      2001 * 1e18,
      2001 * 1e6,
      0,
      0,
      0,
      address(0),
      0
    );
    // run test
    ROUTER.fillLimitOrder(order, signature, context);

    uint256 usdcBalanceDiff = IERC20(USDC).balanceOf(SIGNER_ADDRESS) - usdcBalanceBefore;

    assertTrue(usdcBalanceDiff == order.output.tokenAmount);

    // second execution attempt reverts because the order is already filled
    vm.expectRevert(abi.encodeWithSelector(CurrentAmountMismatch.selector,
      order.input.tokenAddress,
      order.input.tokenAmount,
      2001 * 1e18,
      context.currentAmount));
    ROUTER.fillLimitOrder(order, signature, context);
  }

// 6. Check if fill possible:
//   - If not partiallyFillable - it was not filled previously
  function test_partiallyFillableFalse_revertsIfcurrentAmountNotEqualToInputAmount() public {
    // construct order with default test parameters
    OdosLimitOrderRouter.LimitOrder memory order = createDefaultLimitOrder();

    // sign order
    SignatureValidator.Signature memory signature = getOrderSignature(order);

    // get default executor context, executor output amount is equal to order output amount
    OdosLimitOrderRouter.LimitOrderContext memory context = getDefaultContext(order.output.tokenAmount);

    // currentAmount is NOT equal to order input amount
    context.currentAmount -= 1;

    // mint input token
    mintToken(order.input.tokenAddress, order.input.tokenAmount);

    // whitelist this address
    ROUTER.addAllowedFiller(address(this));

    // run test
    vm.expectRevert(abi.encodeWithSelector(CurrentAmountMismatch.selector,
      order.input.tokenAddress,
      order.input.tokenAmount,
      0,
      context.currentAmount));
    ROUTER.fillLimitOrder(order, signature, context);
  }

// 7. Transfer tokens from account
  function test_partiallyFillableFalse_revertIfNotEnoughInputTokens() public {
    // construct order with default test parameters
    OdosLimitOrderRouter.LimitOrder memory order = createDefaultLimitOrder();

    // sign order
    SignatureValidator.Signature memory signature = getOrderSignature(order);

    // get default executor context, executor output amount is equal to order output amount
    OdosLimitOrderRouter.LimitOrderContext memory context = getDefaultContext(order.output.tokenAmount);

    // DO NOT mint input token
    // mintToken(inputToken, inputAmount);

    // add to whitelist
    ROUTER.addAllowedFiller(address(this));

    // run test, revert expected
    vm.expectRevert("ERC20: insufficient allowance");
    ROUTER.fillLimitOrder(order, signature, context);
  }

// 12. Check slippage, adjust amountOut
  function test_partiallyFillableFalse_revertIfAmountOutSmaller() public {
    // construct order with default test parameters
    OdosLimitOrderRouter.LimitOrder memory order = createDefaultLimitOrder();

    // sign order
    SignatureValidator.Signature memory signature = getOrderSignature(order);

    // get default executor context, executor output amount is NOT equal to order output amount
    OdosLimitOrderRouter.LimitOrderContext memory context = getDefaultContext(order.output.tokenAmount - 1);

    // mint input token
    mintToken(order.input.tokenAddress, order.input.tokenAmount);

    // whitelist this address
    ROUTER.addAllowedFiller(address(this));

    // run test, revert expected
    vm.expectRevert(abi.encodeWithSelector(SlippageLimitExceeded.selector,
      order.output.tokenAddress,
      order.output.tokenAmount,
      order.output.tokenAmount - 1
    ));
    ROUTER.fillLimitOrder(order, signature, context);
  }

// 12. Check slippage, adjust amountOut
  function test_partiallyFillableFalse_amountOutBigger() public {
    // construct order with default test parameters
    OdosLimitOrderRouter.LimitOrder memory order = createDefaultLimitOrder();

    // sign order
    SignatureValidator.Signature memory signature = getOrderSignature(order);

    // get default executor context, executor output amount is equal to order output amount
    OdosLimitOrderRouter.LimitOrderContext memory context = getDefaultContext(order.output.tokenAmount + 4 * 1e6);

    // mint input token
    mintToken(order.input.tokenAddress, order.input.tokenAmount);

    // whitelist this address
    ROUTER.addAllowedFiller(address(this));

    uint256 usdcBalanceBefore = IERC20(USDC).balanceOf(SIGNER_ADDRESS);

    // check that event is emitted, check all topics
    vm.expectEmit(true, true, true, true);
    emit LimitOrderFilled(
      ROUTER.getLimitOrderHash(order),
      SIGNER_ADDRESS,
      DAI,
      USDC,
      2001 * 1e18,
      2001 * 1e6,
      4 * 1e6,
      0,
      0,
      address(0),
      0
    );

    // run test, revert expected
    ROUTER.fillLimitOrder(order, signature, context);

    // account got expected amount
    uint256 usdcBalanceDiff = IERC20(USDC).balanceOf(SIGNER_ADDRESS) - usdcBalanceBefore;
    assertTrue(usdcBalanceDiff == 2001 * 1e6);

    // amount left to the ROUTER
    assertTrue(IERC20(USDC).balanceOf(address(ROUTER)) == order.output.tokenAmount + 4 * 1e6 - order.output.tokenAmount);
  }

// 6. Check if fill possible:
//   - If partiallyFillable, total amount do not exceed
  function test_partiallyFillableTrue_partialFillSuccessful() public {
    // construct order with default test parameters
    OdosLimitOrderRouter.LimitOrder memory order = createDefaultLimitOrder();

    order.partiallyFillable = true;

    // sign order
    SignatureValidator.Signature memory signature = getOrderSignature(order);

    // get default executor context, executor output amount is PROPORTIONAL to currentAmount
    OdosLimitOrderRouter.LimitOrderContext memory context = getDefaultContext(1000 * 1e6);

    context.currentAmount = 1000 * 1e18;

    // mint input token
    mintToken(order.input.tokenAddress, order.input.tokenAmount);

    // whitelist this address
    ROUTER.addAllowedFiller(address(this));

    uint256 usdcBalanceBefore = IERC20(USDC).balanceOf(SIGNER_ADDRESS);

    bytes32 orderHash = ROUTER.getLimitOrderHash(order);

    // check that event is emitted, check all topics
    vm.expectEmit(true, true, true, true);
    emit LimitOrderFilled(
      orderHash,
      SIGNER_ADDRESS,
      DAI,
      USDC,
      1000 * 1e18,
      1000 * 1e6,
      0,
      0,
      0,
      address(0),
      0
    );

    // run test
    ROUTER.fillLimitOrder(order, signature, context);

    uint256 usdcBalanceDiff = IERC20(USDC).balanceOf(SIGNER_ADDRESS) - usdcBalanceBefore;

    assertTrue(usdcBalanceDiff == 1000 * 1e6);

    assertTrue(ROUTER.limitOrders(SIGNER_ADDRESS, orderHash) == context.currentAmount);
  }

// 6. Check if fill possible:
//   - If partiallyFillable, total amount do not exceed
  function test_partiallyFillableTrue_revertsIfAmountExceeds() public {
    // construct order with default test parameters
    OdosLimitOrderRouter.LimitOrder memory order = createDefaultLimitOrder();

    // sign order
    SignatureValidator.Signature memory signature = getOrderSignature(order);

    // get default executor context, executor output amount is equal to order output amount
    OdosLimitOrderRouter.LimitOrderContext memory context = getDefaultContext(order.output.tokenAmount);

    // set currentAmount bigger than orderAmount
    context.currentAmount = order.input.tokenAmount + 1 * 1e18;

    // mint input token
    mintToken(order.input.tokenAddress, order.input.tokenAmount);

    // whitelist this address
    ROUTER.addAllowedFiller(address(this));

    // run test
    vm.expectRevert(abi.encodeWithSelector(CurrentAmountMismatch.selector,
      order.input.tokenAddress,
      order.input.tokenAmount,
      0,
      context.currentAmount));
    ROUTER.fillLimitOrder(order, signature, context);
  }

// 6. Check if fill possible:
//   - If partiallyFillable, total amount do not exceed
  function test_partiallyFillableTrue_secondPartialFillSuccessful() public {
    // first fill
    test_partiallyFillableTrue_partialFillSuccessful();

    // construct order with default test parameters
    OdosLimitOrderRouter.LimitOrder memory order = createDefaultLimitOrder();

    order.partiallyFillable = true;

    // sign order
    SignatureValidator.Signature memory signature = getOrderSignature(order);

    // get default executor context, executor output amount is PROPORTIONAL to order output amount
    OdosLimitOrderRouter.LimitOrderContext memory context = getDefaultContext(1000 * 1e6);

    // partial fill amount
    context.currentAmount = 1000 * 1e18;

    // mint input token
    mintToken(order.input.tokenAddress, order.input.tokenAmount);

    // whitelist this address
    ROUTER.addAllowedFiller(address(this));

    uint256 usdcBalanceBefore = IERC20(USDC).balanceOf(SIGNER_ADDRESS);

    bytes32 orderHash = ROUTER.getLimitOrderHash(order);

    // check that event is emitted, check all topics
    vm.expectEmit(true, true, true, true);
    // only 1 DAI left unfilled
    emit LimitOrderFilled(
      orderHash,
      SIGNER_ADDRESS,
      DAI,
      USDC,
      1000 * 1e18,
      1000 * 1e6,
      0,
      0,
      0,
      address(0),
      0
    );
    // run test
    ROUTER.fillLimitOrder(order, signature, context);

    uint256 usdcBalanceDiff = IERC20(USDC).balanceOf(SIGNER_ADDRESS) - usdcBalanceBefore;

    assertTrue(usdcBalanceDiff == 1000 * 1e6);

    assertTrue(ROUTER.limitOrders(SIGNER_ADDRESS, orderHash) == 2 * context.currentAmount);
  }

// 6. Check if fill possible:
//   - If partiallyFillable, total amount do not exceed
  function test_partiallyFillableTrue_revertsIfSecondPartialFillExceeds() public {
    // first fill
    test_partiallyFillableTrue_partialFillSuccessful();

    // construct order with default test parameters
    OdosLimitOrderRouter.LimitOrder memory order = createDefaultLimitOrder();

    order.partiallyFillable = true;

    // sign order
    SignatureValidator.Signature memory signature = getOrderSignature(order);

    // get default executor context, executor output amount is equal to order output amount
    OdosLimitOrderRouter.LimitOrderContext memory context = getDefaultContext(order.output.tokenAmount);

    // second fill amount is bigger than total order amount
    context.currentAmount = 1002 * 1e18;

    // mint input token
    mintToken(order.input.tokenAddress, order.input.tokenAmount);

    // whitelist this address
    ROUTER.addAllowedFiller(address(this));

    // run test
    vm.expectRevert(abi.encodeWithSelector(CurrentAmountMismatch.selector,
      order.input.tokenAddress,
      order.input.tokenAmount,
      1000 * 1e18,
      context.currentAmount));
    ROUTER.fillLimitOrder(order, signature, context);
  }

// 6. Check if fill possible:
//   - If partiallyFillable, total amount do not exceed
  function test_partiallyFillableTrue_revertsIfCancelled() public {
    // first fill
    test_partiallyFillableTrue_partialFillSuccessful();

    // construct order with default test parameters
    OdosLimitOrderRouter.LimitOrder memory order = createDefaultLimitOrder();

    order.partiallyFillable = true;

    // sign order
    SignatureValidator.Signature memory signature = getOrderSignature(order);

    // get default executor context, executor output amount is equal to order output amount
    OdosLimitOrderRouter.LimitOrderContext memory context = getDefaultContext(order.output.tokenAmount);

    // second fill amount is within the range of the total order amount
    context.currentAmount = 1000 * 1e18;

    // mint input token
    mintToken(order.input.tokenAddress, order.input.tokenAmount);

    // whitelist this address
    ROUTER.addAllowedFiller(address(this));

    bytes32 orderHash = ROUTER.getLimitOrderHash(order);

    // check that event is emitted, check all topics
    vm.expectEmit(true, true, true, true);
    emit LimitOrderCancelled(orderHash, SIGNER_ADDRESS);

    // cancel order by the account
    vm.prank(SIGNER_ADDRESS);
    ROUTER.cancelLimitOrder(orderHash);

    // run test
    vm.expectRevert(abi.encodeWithSelector(OrderCancelled.selector, orderHash));
    ROUTER.fillLimitOrder(order, signature, context);
  }

//  Only order account can cancel the order
  function test_noCancelByAnotherAddress() public {
    // construct order with default test parameters
    OdosLimitOrderRouter.LimitOrder memory order = createDefaultLimitOrder();

    // sign order
    SignatureValidator.Signature memory signature = getOrderSignature(order);

    // get default executor context, executor output amount is equal to order output amount
    OdosLimitOrderRouter.LimitOrderContext memory context = getDefaultContext(order.output.tokenAmount);

    context.currentAmount = order.input.tokenAmount;

    // mint input token
    mintToken(order.input.tokenAddress, order.input.tokenAmount);

    // whitelist this address
    ROUTER.addAllowedFiller(address(this));

    bytes32 orderHash = ROUTER.getLimitOrderHash(order);

    // check that event is emitted, check all topics
    vm.expectEmit(true, true, true, true);
    emit LimitOrderCancelled(orderHash, address(this));

    // try to cancel order by another address
    // it WILL NOT cancel the order for the original account
    ROUTER.cancelLimitOrder(orderHash);

    // check that event is emitted, check all topics
    vm.expectEmit(true, true, true, true);
    emit LimitOrderFilled(
      orderHash,
      SIGNER_ADDRESS,
      DAI,
      USDC,
      2001 * 1e18,
      2001 * 1e6,
      0,
      0,
      0,
      address(0),
      0
    );

    // run test
    ROUTER.fillLimitOrder(order, signature, context);
  }

  function test_permit2_succeeds() public {
    // construct order with default test parameters
    OdosLimitOrderRouter.LimitOrder memory order = createDefaultLimitOrder();

    // get default executor context, executor output amount is equal to order output amount
    OdosLimitOrderRouter.LimitOrderContext memory context = getDefaultContext(order.output.tokenAmount);

    // whitelist this address
    ROUTER.addAllowedFiller(address(this));

    // mint input token
    // no ERC20 approve
    MockERC20(order.input.tokenAddress).faucet(SIGNER_ADDRESS, order.input.tokenAmount);

    // get permit2
    bytes32 orderStructHash = ROUTER.getLimitOrderStructHash(order);
    OdosLimitOrderRouter.Permit2Info memory swap_permit = createLimitOrderPermit2(order, context, orderStructHash, SIGNER_ADDRESS);

    // approve Permit2 contract
    vm.prank(SIGNER_ADDRESS);
    MockERC20(order.input.tokenAddress).approve(address(PERMIT2), type(uint256).max);

    // get balance before the swap
    uint256 usdcBalanceBefore = IERC20(USDC).balanceOf(SIGNER_ADDRESS);

    bytes32 orderHash = ROUTER.getLimitOrderHash(order);

    // check that event is emitted, check all topics
    vm.expectEmit(true, true, true, true);
    emit LimitOrderFilled(
      orderHash,
      SIGNER_ADDRESS,
      DAI,
      USDC,
      2001 * 1e18,
      2001 * 1e6,
      0,
      0,
      0,
      address(0),
      0
    );

    // run test
    ROUTER.fillLimitOrderPermit2(order, context, swap_permit);

    uint256 usdcBalanceDiff = IERC20(USDC).balanceOf(SIGNER_ADDRESS) - usdcBalanceBefore;
    assertTrue(usdcBalanceDiff == 2001 * 1e6);

    assertTrue(ROUTER.limitOrders(SIGNER_ADDRESS, orderHash) == order.input.tokenAmount);
  }

  function test_permit2_reverts() public {
    // construct order with default test parameters
    OdosLimitOrderRouter.LimitOrder memory order = createDefaultLimitOrder();

    // get default executor context, executor output amount is equal to order output amount
    OdosLimitOrderRouter.LimitOrderContext memory context = getDefaultContext(order.output.tokenAmount);

    // whitelist this address
    ROUTER.addAllowedFiller(address(this));

    // try another order owner address, not the signer
    address wrongAddress = vm.addr(2);

    // mint input token
    // no ERC20 approve
    MockERC20(order.input.tokenAddress).faucet(wrongAddress, order.input.tokenAmount);

    // get permit2, wrong owner address
    bytes32 orderStructHash = ROUTER.getLimitOrderStructHash(order);
    OdosLimitOrderRouter.Permit2Info memory swap_permit = createLimitOrderPermit2(order, context, orderStructHash, wrongAddress);

    // approve Permit2 contract
    vm.prank(wrongAddress);
    MockERC20(order.input.tokenAddress).approve(address(PERMIT2), type(uint256).max);

    // run test
    vm.expectRevert(InvalidSigner.selector);
    ROUTER.fillLimitOrderPermit2(order, context, swap_permit);
  }

  function test_permit2_EIP1271_succeeds() public {
    // construct order with default test parameters
    OdosLimitOrderRouter.LimitOrder memory order = createDefaultLimitOrder();

    // get default executor context, executor output amount is equal to order output amount
    OdosLimitOrderRouter.LimitOrderContext memory context = getDefaultContext(order.output.tokenAmount);

    // whitelist this address
    ROUTER.addAllowedFiller(address(this));

    // deploy a smart contract wallet
    MockSmartContractWallet SCW = new MockSmartContractWallet("", "");
    address SCW_ADDRESS = address(SCW);

    // mint input token to SCW
    // no ERC20 approve
    MockERC20(order.input.tokenAddress).faucet(SCW_ADDRESS, order.input.tokenAmount);

    // get order hash
    bytes32 orderStructHash = ROUTER.getLimitOrderStructHash(order);

    // get permit2
    OdosLimitOrderRouter.Permit2Info memory swap_permit = createLimitOrderPermit2(order, context, orderStructHash, SCW_ADDRESS);

    // get Permit2 with witness hash
    bytes32 permit2Hash = getPermitWitnessHash(order, context, swap_permit, orderStructHash, address(ROUTER));

    // set expected hash and signature
    SCW.setExpected(permit2Hash, swap_permit.signature);

    // approve Permit2 contract for SCW
    vm.prank(SCW_ADDRESS);
    MockERC20(order.input.tokenAddress).approve(address(PERMIT2), type(uint256).max);

    // get balance before the swap
    uint256 usdcBalanceBefore = IERC20(USDC).balanceOf(SCW_ADDRESS);

    bytes32 orderHash = ROUTER.getLimitOrderHash(order);

    // check that event is emitted, check all topics
    vm.expectEmit(true, true, true, true);
    emit LimitOrderFilled(
      orderHash,
      SCW_ADDRESS,
      DAI,
      USDC,
      2001 * 1e18,
      2001 * 1e6,
      0,
      0,
      0,
      address(0),
      0
    );

    // run test
    ROUTER.fillLimitOrderPermit2(order, context, swap_permit);

    uint256 usdcBalanceDiff = IERC20(USDC).balanceOf(SCW_ADDRESS) - usdcBalanceBefore;
    assertTrue(usdcBalanceDiff == 2001 * 1e6);

    assertTrue(ROUTER.limitOrders(SCW_ADDRESS, orderHash) == order.input.tokenAmount);
  }

  function test_permit2_EIP1271_reverts() public {
    // construct order with default test parameters
    OdosLimitOrderRouter.LimitOrder memory order = createDefaultLimitOrder();

    // get default executor context, executor output amount is equal to order output amount
    OdosLimitOrderRouter.LimitOrderContext memory context = getDefaultContext(order.output.tokenAmount);

    // whitelist this address
    ROUTER.addAllowedFiller(address(this));

    // deploy a smart contract wallet
    MockSmartContractWallet SCW = new MockSmartContractWallet("", "");
    address SCW_ADDRESS = address(SCW);

    // mint input token
    // no ERC20 approve
    MockERC20(order.input.tokenAddress).faucet(SCW_ADDRESS, order.input.tokenAmount);

    // get order hash
    bytes32 orderStructHash = ROUTER.getLimitOrderStructHash(order);

    // get permit2
    OdosLimitOrderRouter.Permit2Info memory swap_permit = createLimitOrderPermit2(order, context, orderStructHash, SCW_ADDRESS);

    // set wrong signature, should fail
    SCW.setExpected(orderStructHash, "");

    // approve Permit2 contract
    vm.prank(SCW_ADDRESS);
    MockERC20(order.input.tokenAddress).approve(address(PERMIT2), type(uint256).max);

    // run test
    vm.expectRevert(InvalidContractSignature.selector);
    ROUTER.fillLimitOrderPermit2(order, context, swap_permit);
  }


  function test_referralCodeFee_succeeds() public {
    TestHelper memory helper = TestHelper(0, 0);
    // construct order with default test parameters
    OdosLimitOrderRouter.LimitOrder memory order = createDefaultLimitOrder();

    // set the referral code with fee
    order.referralCode = REFERRAL_CODE_FEE;
    order.referralFee = REFERRAL_FEE;
    order.referralFeeRecipient = REFERRAL_BENEFICIARY_ADDRESS_FEE;

    // set amount out which takes into account beneficiary fee
    uint256 swapAmountOut = 2004 * 1e6;

    // calculate beneficiary amount
    helper.beneficiaryAmount = swapAmountOut * REFERRAL_FEE * 8 / (FEE_DENOM * 10);

    // sign order
    SignatureValidator.Signature memory signature = getOrderSignature(order);

    // get default executor context, executor output amount is equal to order output amount
    OdosLimitOrderRouter.LimitOrderContext memory context = getDefaultContext(swapAmountOut);

    // mint input token
    mintToken(order.input.tokenAddress, order.input.tokenAmount);

    // whitelist this address
    ROUTER.addAllowedFiller(address(this));

    helper.usdcBalanceBefore = IERC20(USDC).balanceOf(SIGNER_ADDRESS);

    bytes32 orderHash = ROUTER.getLimitOrderHash(order);

    // check that event is emitted, check all topics
    vm.expectEmit(true, true, true, true);
    emit LimitOrderFilled(
      orderHash,
      SIGNER_ADDRESS,
      DAI,
      USDC,
      2001 * 1e18,
      2001 * 1e6,
      swapAmountOut - swapAmountOut * REFERRAL_FEE / FEE_DENOM - order.output.tokenAmount,
      REFERRAL_CODE_FEE,
      REFERRAL_FEE,
      REFERRAL_BENEFICIARY_ADDRESS_FEE,
      0
    );

    // run test
    ROUTER.fillLimitOrder(order, signature, context);

    // beneficiaryAmount
    assert(IERC20(order.output.tokenAddress).balanceOf(REFERRAL_BENEFICIARY_ADDRESS_FEE) == helper.beneficiaryAmount);

    // user amount
    assert(IERC20(USDC).balanceOf(SIGNER_ADDRESS) - helper.usdcBalanceBefore == order.output.tokenAmount);

    assertTrue(ROUTER.limitOrders(SIGNER_ADDRESS, orderHash) == order.input.tokenAmount);
  }

  function test_referralCodeFee_reverts() public {
    // construct order with default test parameters
    OdosLimitOrderRouter.LimitOrder memory order = createDefaultLimitOrder();

    // set the referral code with fee
    order.referralCode = REFERRAL_CODE_FEE;
    order.referralFee = REFERRAL_FEE;
    order.referralFeeRecipient = REFERRAL_BENEFICIARY_ADDRESS_FEE;

    // set amount out which is smaller than required for execution with fee
    uint256 swapAmountOut = 2002 * 1e6;

    // sign order
    SignatureValidator.Signature memory signature = getOrderSignature(order);

    // get default executor context, executor output amount is equal to order output amount
    OdosLimitOrderRouter.LimitOrderContext memory context = getDefaultContext(swapAmountOut);

    // mint input token
    mintToken(order.input.tokenAddress, order.input.tokenAmount);

    // whitelist this address
    ROUTER.addAllowedFiller(address(this));

    // run test
    vm.expectRevert(abi.encodeWithSelector(SlippageLimitExceeded.selector, order.output.tokenAddress,
      order.output.tokenAmount, swapAmountOut * (FEE_DENOM - REFERRAL_FEE) / FEE_DENOM));
    ROUTER.fillLimitOrder(order, signature, context);
  }

  function test_referralCodeTrack_succeeds() public {
    // construct order with default test parameters
    OdosLimitOrderRouter.LimitOrder memory order = createDefaultLimitOrder();

    // set the referral code with track only
    order.referralCode = REFERRAL_CODE_TRACK;
    order.referralFeeRecipient = REFERRAL_BENEFICIARY_ADDRESS_TRACK;

    // sign order
    SignatureValidator.Signature memory signature = getOrderSignature(order);

    // get default executor context, executor output amount is equal to order output amount
    OdosLimitOrderRouter.LimitOrderContext memory context = getDefaultContext(order.output.tokenAmount);

    // mint input token
    mintToken(order.input.tokenAddress, order.input.tokenAmount);

    // whitelist this address
    ROUTER.addAllowedFiller(address(this));

    uint256 usdcBalanceBefore = IERC20(USDC).balanceOf(SIGNER_ADDRESS);

    bytes32 orderHash = ROUTER.getLimitOrderHash(order);

    // check that event is emitted, check all topics
    vm.expectEmit(true, true, true, true);
    emit LimitOrderFilled(
      orderHash,
      SIGNER_ADDRESS,
      DAI,
      USDC,
      2001 * 1e18,
      2001 * 1e6,
      0,
      REFERRAL_CODE_TRACK,
      0,
      REFERRAL_BENEFICIARY_ADDRESS_TRACK,
      0
    );

    // run test
    ROUTER.fillLimitOrder(order, signature, context);

    uint256 usdcBalanceDiff = IERC20(USDC).balanceOf(SIGNER_ADDRESS) - usdcBalanceBefore;
    assertTrue(usdcBalanceDiff == 2001 * 1e6);

    assertTrue(ROUTER.limitOrders(SIGNER_ADDRESS, orderHash) == order.input.tokenAmount);
  }


  function test_surplusCheck_reverts() public {
    // construct order with default test parameters
    OdosLimitOrderRouter.LimitOrder memory order = createDefaultLimitOrder();

    // sign order
    SignatureValidator.Signature memory signature = getOrderSignature(order);

    // get default executor context, executor output amount is equal to order output amount
    // 1 as surplus
    OdosLimitOrderRouter.LimitOrderContext memory context = getDefaultContext(order.output.tokenAmount + 1);
    context.minSurplus = 1000;

    // mint input token
    mintToken(order.input.tokenAddress, order.input.tokenAmount);

    // whitelist this address
    ROUTER.addAllowedFiller(address(this));

    // run test
    vm.expectRevert(abi.encodeWithSelector(MinSurplusCheckFailed.selector, order.output.tokenAddress, context.minSurplus, 1));
    ROUTER.fillLimitOrder(order, signature, context);
  }

}
