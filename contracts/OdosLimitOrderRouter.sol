// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {Ownable2Step} from "@openzeppelin/contracts/access/Ownable2Step.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {EIP712} from "@openzeppelin/contracts/utils/cryptography/EIP712.sol";

import {IOdosExecutor} from  "../interfaces/IOdosExecutor.sol";
import {ISignatureTransfer} from "../interfaces/ISignatureTransfer.sol";
import {IOdosRouterV2} from  "../interfaces/IOdosRouterV2.sol";
import {SignatureValidator} from "./SignatureValidator.sol";


using SafeERC20 for IERC20;

error AddressNotAllowed(address account);
error OrderExpired(uint256 orderExpiry, uint256 currentTimestamp);
error CurrentAmountMismatch(address tokenAddress, uint256 orderAmount, uint256 filledAmount, uint256 currentAmount);
error SlippageLimitExceeded(address tokenAddress, uint256 expectedAmount, uint256 actualAmount);
error ArbitrageNotAllowed(address tokenAddress);
error TransferFailed(address destination, uint256 amount);
error OrderCancelled(bytes32 orderHash);
error InvalidArguments();
error MinSurplusCheckFailed(address tokenAddress, uint256 expectedValue, uint256 actualValue);


/// @title Routing contract for Odos Limit Orders with single and multi input and output tokens
contract OdosLimitOrderRouter is EIP712, Ownable2Step, SignatureValidator {

  /// @dev SCALE is required for fractional proportion calculation
  uint256 private constant SCALE = 1e18;

  /// @dev The zero address is used to represent ETH due to its gas efficiency
  address private constant _ETH = address(0);

  /// @dev Constants for managing referrals and fees
  uint256 private constant REFERRAL_WITH_FEE_THRESHOLD = 1 << 31;
  uint256 private constant FEE_DENOM = 1e18;

  /// @dev OdosRouterV2 address
  address immutable private ODOS_ROUTER_V2;

  /// @dev Address which allowed to swap and transfer internal funds
  address private liquidatorAddress;

  /// @dev Event emitted on successful single input limit order execution
  event LimitOrderFilled(
    bytes32 indexed orderHash,
    address indexed orderOwner,
    address inputToken,
    address outputToken,
    uint256 orderInputAmount,
    uint256 orderOutputAmount,
    uint256 filledInputAmount,   // filled by this execution
    uint256 filledOutputAmount,  // filled by this execution
    uint256 surplus,
    uint32 referralCode
  );

  /// @dev Event emitted on successful multi input limit order execution
  event MultiLimitOrderFilled(
    bytes32 indexed orderHash,
    address indexed orderOwner,
    address[] inputTokens,
    address[] outputTokens,
    uint256[] orderInputAmounts,
    uint256[] orderOutputAmounts,
    uint256[] filledInputAmounts,   // filled by this execution
    uint256[] filledOutputAmounts,  // filled by this execution
    uint256[] surplus,
    uint32 referralCode
  );

  /// @dev Event emitted on single input limit order cancellation
  event LimitOrderCancelled(
    bytes32 indexed orderHash,
    address indexed orderOwner
  );

  /// @dev Event emitted on multi input limit order cancellation
  event MultiLimitOrderCancelled(
    bytes32 indexed orderHash,
    address indexed orderOwner
  );

  /// @dev Event emitted on adding allowed order filler
  event AllowedFillerAdded(address indexed account);

  /// @dev Event emitted on removing allowed order filler
  event AllowedFillerRemoved(address indexed account);

  /// @dev Event emitted on changing the liquidator address
  event LiquidatorAddressChanged(address indexed account);

  /// @dev Event emitted on swapping internal router funds
  event SwapRouterFunds(
    address sender,
    address[] inputTokens,
    uint256[] inputAmounts,
    address[] inputReceivers,
    address outputToken,
    uint256 outputAmount,
    address outputReceiver,
    uint256 amountOut
  );

  /// @dev Token address and amount
  struct TokenInfo {
    address tokenAddress;
    uint256 tokenAmount;
  }

  /// @dev Single input and output limit order structure
  struct LimitOrder {
    TokenInfo input;
    TokenInfo output;
    uint256 expiry;
    uint256 salt;
    uint32 referralCode;
    bool partiallyFillable;
  }

  /// @dev Multiple inputs and outputs limit order structure
  struct MultiLimitOrder {
    TokenInfo[] inputs;
    TokenInfo[] outputs;
    uint256 expiry;
    uint256 salt;
    uint32 referralCode;
    bool partiallyFillable;
  }

  /// @dev The execution context provided by the filler for single token limit order
  struct LimitOrderContext {
    bytes pathDefinition;
    address odosExecutor;
    uint256 currentAmount;
    address inputReceiver;
    uint256 minSurplus;
  }

  /// @dev The execution context provided by the filler for multi token limit order
  struct MultiLimitOrderContext {
    bytes pathDefinition;
    address odosExecutor;
    uint256[] currentAmounts;
    address[] inputReceivers;
    uint256[] minSurplus;
  }

  /// @dev A helper which is used for avoiding "Stack too deep" error with single input order
  struct LimitOrderHelper {
    uint256 balanceBefore;
    uint256 amountOut;
    uint256 surplus;
    uint256 proratedAmount;
  }

  /// @dev A helper which is used for avoiding "Stack too deep" error with multi input order
  struct MultiLimitOrderHelper {
    address[] inputTokens;
    address[] outputTokens;
    uint256[] orderInputAmounts;
    uint256[] orderOutputAmounts;
    uint256[] filledAmounts;
    uint256[] filledOutputAmounts;
    uint256[] surplus;
    uint256[] balancesBefore;
    address orderOwner;
    bytes32 orderHash;
  }

  /// @dev Contains information required for Permit2 token transfer
  struct Permit2Info {
    address contractAddress;  // Permit2 contract address
    uint256 nonce;
    uint256 deadline;
    address orderOwner;
    bytes signature;
  }

  /// @dev Holds all information for a given referral
  struct ReferralInfo {
    uint64 referralFee;
    address beneficiary;
    bool registered;
  }

  /// @dev Single token limit order storage
  mapping(address orderOwner => mapping(bytes32 orderHash => uint256 filledAmount)) public limitOrders;

  /// @dev Multi token limit order storage
  mapping(address orderOwner => mapping(bytes32 orderHash => uint256[] filledAmounts)) public multiLimitOrders;

  /// @dev Allowed order fillers
  mapping(address => bool) public allowedFillers;

  /// @dev Type hashes for EIP-712 signing
  bytes32 public constant TOKEN_INFO_TYPEHASH = keccak256(
    "TokenInfo("
      "address tokenAddress,"
      "uint256 tokenAmount"
    ")"
  );

  bytes32 public constant LIMIT_ORDER_TYPEHASH = keccak256(
    "LimitOrder("
      "TokenInfo input,"
      "TokenInfo output,"
      "uint256 expiry,"
      "uint256 salt,"
      "uint32 referralCode,"
      "bool partiallyFillable"
    ")"
    "TokenInfo("
      "address tokenAddress,"
      "uint256 tokenAmount"
    ")"
  );

  bytes32 public constant MULTI_LIMIT_ORDER_TYPEHASH = keccak256(
    "MultiLimitOrder("
      "TokenInfo[] inputs,"
      "TokenInfo[] outputs,"
      "uint256 expiry,"
      "uint256 salt,"
      "uint32 referralCode,"
      "bool partiallyFillable"
    ")"
    "TokenInfo("
      "address tokenAddress,"
      "uint256 tokenAmount"
    ")"
  );

  bytes32 public constant LIMIT_ORDER_WITNESS_TYPEHASH = keccak256(
    "PermitWitnessTransferFrom(TokenPermissions permitted,address spender,uint256 nonce,uint256 deadline,"
    "LimitOrder order)"
    "LimitOrder("
      "TokenInfo input,"
      "TokenInfo output,"
      "uint256 expiry,"
      "uint256 salt,"
      "uint32 referralCode,"
      "bool partiallyFillable"
    ")"
    "TokenInfo("
      "address tokenAddress,"
      "uint256 tokenAmount"
    ")"
    "TokenPermissions(address token,uint256 amount)"
  );

  bytes32 public constant MULTI_LIMIT_ORDER_WITNESS_TYPEHASH = keccak256(
    "PermitBatchWitnessTransferFrom(TokenPermissions[] permitted,address spender,uint256 nonce,uint256 deadline,"
    "MultiLimitOrder order)"
    "MultiLimitOrder("
      "TokenInfo[] inputs,"
      "TokenInfo[] outputs,"
      "uint256 expiry,"
      "uint256 salt,"
      "uint32 referralCode,"
      "bool partiallyFillable"
    ")"
    "TokenInfo("
      "address tokenAddress,"
      "uint256 tokenAmount"
    ")"
    "TokenPermissions(address token,uint256 amount)"
  );

  string public constant LIMIT_ORDER_WITNESS_TYPE_STRING =
    "LimitOrder order)"
    "LimitOrder("
      "TokenInfo input,"
      "TokenInfo output,"
      "uint256 expiry,"
      "uint256 salt,"
      "uint32 referralCode,"
      "bool partiallyFillable"
    ")"
    "TokenInfo("
      "address tokenAddress,"
      "uint256 tokenAmount"
    ")"
    "TokenPermissions(address token,uint256 amount)";

  string public constant MULTI_LIMIT_ORDER_WITNESS_TYPE_STRING =
    "MultiLimitOrder order)"
    "MultiLimitOrder("
      "TokenInfo[] inputs,"
      "TokenInfo[] outputs,"
      "uint256 expiry,"
      "uint256 salt,"
      "uint32 referralCode,"
      "bool partiallyFillable"
    ")"
    "TokenInfo("
      "address tokenAddress,"
      "uint256 tokenAmount"
    ")"
    "TokenPermissions(address token,uint256 amount)";

  /// @param initialOwner The initial owner of the contract
  /// @param _odosRouterV2 OdosRouterV2 address
  constructor(address initialOwner, address _odosRouterV2)
  EIP712("OdosLimitOrderRouter", "1")
  Ownable(initialOwner) {
    ODOS_ROUTER_V2 = _odosRouterV2;
    changeLiquidatorAddress(initialOwner);
  }


  /// @notice Tries to execute a single input limit order, expects the input token to be approved via the ERC20 interface
  /// @param order Single input limit order struct
  /// @param signature Order signature and signature validation method
  /// @param context Execution context
  /// @return orderHash Order hash
  function fillLimitOrder(
    LimitOrder calldata order,
    Signature calldata signature,
    LimitOrderContext calldata context
  )
  external
  returns (bytes32 orderHash)
  {
    // 1-3 Checks
    _limitOrderChecks(order);

    // 4. Get order hash
    orderHash = getLimitOrderHash(order);

    // 5. Recover the orderOwner and validate signature
    address orderOwner = _getOrderOwnerOrRevert(orderHash, signature.signature, signature.validationMethod);

    // 6,7 Try get order filled amount
    uint256 filledAmount = _getFilledAmount(order, context, orderHash, orderOwner);

    // 8. Transfer tokens from order owner
    IERC20(order.input.tokenAddress).safeTransferFrom(orderOwner, context.inputReceiver, context.currentAmount);

    // 9-17 Fill order
    _limitOrderFill(order, context, orderHash, orderOwner, filledAmount);
  }

  /// @notice Tries to execute a single input limit order, expects the input token to be approved via the Permit2 interface
  /// @param order Single input limit order struct
  /// @param context Execution context
  /// @param permit2 Permit2 struct
  /// @return orderHash Order hash
  function fillLimitOrderPermit2(
    LimitOrder calldata order,
    LimitOrderContext calldata context,
    Permit2Info calldata permit2
  )
  external
  returns (bytes32 orderHash)
  {
    // 1-3 Checks
    _limitOrderChecks(order);

    // 4. Get order hash
    orderHash = getLimitOrderHash(order);

    // 5. No need to recover address as it is set in Permit2Info

    // 6,7 Try get order filled amount
    uint256 filledAmount = _getFilledAmount(order, context, orderHash, permit2.orderOwner);

    // 8. Transfer tokens from order owner
    ISignatureTransfer(permit2.contractAddress).permitWitnessTransferFrom(
      ISignatureTransfer.PermitTransferFrom(
        ISignatureTransfer.TokenPermissions(
          order.input.tokenAddress,
          context.currentAmount
        ),
        permit2.nonce,
        permit2.deadline
      ),
      ISignatureTransfer.SignatureTransferDetails(
        context.inputReceiver,
        context.currentAmount
      ),
      permit2.orderOwner,
      orderHash,
      LIMIT_ORDER_WITNESS_TYPE_STRING,
      permit2.signature
    );

    // 9-17 Fill order
    _limitOrderFill(order, context, orderHash, permit2.orderOwner, filledAmount);
  }

  /// @notice Tries to execute a multi input limit order, expects the input tokens to be approved via the ERC20 interface
  /// @param order Multi input limit order struct
  /// @param signature Signature and signature validation method
  /// @param context Execution context
  /// @return orderHash Order hash
  function fillMultiLimitOrder(
    MultiLimitOrder calldata order,
    Signature calldata signature,
    MultiLimitOrderContext calldata context
  )
  external
  returns (bytes32 orderHash)
  {
    // 1-3 Checks
    _multiOrderChecks(order);

    // 4. Get order hash
    orderHash = getMultiLimitOrderHash(order);

    // 5. Recover the orderOwner and validate signature
    address orderOwner = _getOrderOwnerOrRevert(orderHash, signature.signature, signature.validationMethod);

    // 6,7 Try get order filled amount
    MultiLimitOrderHelper memory helper = _getMultiFilledAmount(order, context, orderHash, orderOwner);

    // 8. Transfer tokens from order owner to the receiver
    for (uint256 i = 0; i < order.inputs.length; i++) {
      IERC20(order.inputs[i].tokenAddress).safeTransferFrom(orderOwner, context.inputReceivers[i], context.currentAmounts[i]);
      // update filled amount
      helper.filledAmounts[i] += context.currentAmounts[i];
      helper.inputTokens[i] = order.inputs[i].tokenAddress;
      helper.orderInputAmounts[i] = order.inputs[i].tokenAmount;
    }

    _multiLimitOrderFill(order, context, helper);
  }

  /// @notice Tries to execute a multi input limit order, expects the input tokens to be approved via the Permit2 interface
  /// @param order Single input limit order struct
  /// @param context Execution context
  /// @param permit2 Permit2 struct
  /// @return orderHash Order hash
  function fillMultiLimitOrderPermit2(
    MultiLimitOrder calldata order,
    MultiLimitOrderContext calldata context,
    Permit2Info calldata permit2
  )
  external
  returns (bytes32 orderHash)
  {
    // 1-3 Checks
    _multiOrderChecks(order);

    // 4. Get order hash
    orderHash = getMultiLimitOrderHash(order);

    // 5. No need to recover address as it is set in Permit2Info

    // 6,7 Try get order filled amount
    MultiLimitOrderHelper memory helper = _getMultiFilledAmount(order, context, orderHash, permit2.orderOwner);

    // 8. Transfer tokens from order owner to the receiver
    ISignatureTransfer.PermitBatchTransferFrom memory permit = ISignatureTransfer.PermitBatchTransferFrom(
      new ISignatureTransfer.TokenPermissions[](order.inputs.length),
      permit2.nonce,
      permit2.deadline
    );
    ISignatureTransfer.SignatureTransferDetails[] memory transferDetails
      = new ISignatureTransfer.SignatureTransferDetails[](order.inputs.length);

    for (uint256 i = 0; i < order.inputs.length; i++) {
      permit.permitted[i].token = order.inputs[i].tokenAddress;
      permit.permitted[i].amount = context.currentAmounts[i];

      // Fill helper data
      helper.inputTokens[i] = order.inputs[i].tokenAddress;
      helper.orderInputAmounts[i] = context.currentAmounts[i];

      transferDetails[i].to = context.inputReceivers[i];
      transferDetails[i].requestedAmount = context.currentAmounts[i];

    }
    ISignatureTransfer(permit2.contractAddress).permitWitnessTransferFrom(
      permit,
      transferDetails,
      permit2.orderOwner,
      orderHash,
      MULTI_LIMIT_ORDER_WITNESS_TYPE_STRING,
      permit2.signature
    );

    // 9-15 Fill order
    _multiLimitOrderFill(order, context, helper);
  }

  /// @notice Cancels single input limit order. Only the order owner address can cancel it.
  /// @param orderHash Single input limit order hash
  function cancelLimitOrder(
    bytes32 orderHash
  )
  external
  {
    limitOrders[msg.sender][orderHash] = type(uint256).max;
    emit LimitOrderCancelled(orderHash, msg.sender);
  }

  /// @notice Cancels multi input limit order. Only the order owner address can cancel it.
  /// @param orderHash Multi input limit order hash
  function cancelMultiLimitOrder(
    bytes32 orderHash
  )
  external
  {
    uint256[] memory _filledAmounts = new uint256[](1);
    _filledAmounts[0] = type(uint256).max;
    multiLimitOrders[msg.sender][orderHash] = _filledAmounts;

    emit MultiLimitOrderCancelled(orderHash, msg.sender);
  }

  /// @notice Directly swap funds held in router, multi input tokens to one output token
  /// @param inputs List of input token structs
  /// @param inputReceivers List of addresses for swap execution
  /// @param output Output token structs
  /// @param outputReceiver Address which will receive output token
  /// @param pathDefinition Encoded path definition for executor
  /// @param odosExecutor Address of contract which will execute the path
  /// @return amountOut Amount of output token after swap
  function swapRouterFunds(
    TokenInfo[] memory inputs,
    address[] memory inputReceivers,
    TokenInfo memory output,
    address outputReceiver,
    bytes calldata pathDefinition,
    address odosExecutor
  )
  external
  returns (uint256 amountOut)
  {
    if (msg.sender != liquidatorAddress) {
      revert AddressNotAllowed(msg.sender);
    }
    uint256[] memory amountsIn = new uint256[](inputs.length);
    address[] memory tokensIn = new address[](inputs.length);

    for (uint256 i = 0; i < inputs.length; i++) {
      tokensIn[i] = inputs[i].tokenAddress;

      // Allow total amount spending
      amountsIn[i] = inputs[i].tokenAmount == 0 ?
        IERC20(tokensIn[i]).balanceOf(address(this)) : inputs[i].tokenAmount;

      // Transfer funds to the receivers
      IERC20(tokensIn[i]).safeTransfer(inputReceivers[i], amountsIn[i]);
    }
    // Get output token balances before
    uint256 balanceBefore = IERC20(output.tokenAddress).balanceOf(address(this));

    // Delegate the execution of the path to the specified Odos Executor
    IOdosExecutor(odosExecutor).executePath(pathDefinition, amountsIn, msg.sender);

    // Get output token balances difference
    amountOut = IERC20(output.tokenAddress).balanceOf(address(this)) - balanceBefore;

    if (amountOut < output.tokenAmount) {
      revert SlippageLimitExceeded(output.tokenAddress, output.tokenAmount, amountOut);
    }

    // Transfer tokens to the receiver
    IERC20(output.tokenAddress).safeTransfer(outputReceiver, amountOut);

    emit SwapRouterFunds(
      msg.sender,
      tokensIn,
      amountsIn,
      inputReceivers,
      output.tokenAddress,
      output.tokenAmount,
      outputReceiver,
      amountOut
    );
  }

  /// @notice Transfers funds held by the router contract
  /// @param tokens List of token address to be transferred
  /// @param amounts List of amounts of each token to be transferred
  /// @param dest Address to which the funds should be sent
  function transferRouterFunds(
    address[] calldata tokens,
    uint256[] calldata amounts,
    address dest
  )
  external
  onlyOwner
  {
    if (tokens.length != amounts.length) revert InvalidArguments();
    for (uint256 i = 0; i < tokens.length; i++) {
      if (tokens[i] == _ETH) {
        (bool success,) = payable(dest).call{value: amounts[i]}("");
        if (!success) {
          revert TransferFailed(dest, amounts[i]);
        }
      } else {
        IERC20(tokens[i]).safeTransfer(
          dest,
          amounts[i] == 0 ? IERC20(tokens[i]).balanceOf(address(this)) : amounts[i]
        );
      }
    }
  }

  /// @notice Adds an address to the list of allowed filler addresses
  /// @param account The address to be allowed
  function addAllowedFiller(address account) external onlyOwner {
    allowedFillers[account] = true;
    emit AllowedFillerAdded(account);
  }

  /// @notice Removes an address from the list of allowed filler addresses
  /// @param account The address to be disabled
  function removeAllowedFiller(address account) external onlyOwner {
    allowedFillers[account] = false;
    emit AllowedFillerRemoved(account);
  }

  /// @notice Changes the address which can call `swapRouterFunds()` function
  /// @param account The address of new liquidator
  function changeLiquidatorAddress(address account)
  public
  onlyOwner
  {
    liquidatorAddress = account;
    emit LiquidatorAddressChanged(account);
  }

  /// @dev Encodes TokenInfo struct according to EIP-712
  /// @param tokenInfo TokenInfo struct
  /// @return Encoded struct
  function encodeTokenInfo(
    TokenInfo calldata tokenInfo
  )
  public
  pure
  returns (bytes memory)
  {
    return abi.encode(TOKEN_INFO_TYPEHASH, tokenInfo.tokenAddress, tokenInfo.tokenAmount);
  }

  /// @notice Encodes LimitOrder struct according to EIP-712
  /// @param order LimitOrder struct
  /// @return Encoded struct
  function encodeLimitOrder(
    LimitOrder calldata order
  )
  public
  pure
  returns (bytes memory)
  {
    return
      abi.encode(
      LIMIT_ORDER_TYPEHASH,
      keccak256(encodeTokenInfo(order.input)),
      keccak256(encodeTokenInfo(order.output)),
      order.expiry,
      order.salt,
      order.referralCode,
      order.partiallyFillable
    );
  }

  /// @notice Encodes MultiLimitOrder struct according to EIP-712
  /// @param order MultiLimitOrder struct
  /// @return Encoded struct
  function encodeMultiLimitOrder(
    MultiLimitOrder calldata order
  )
  public
  pure
  returns (bytes memory)
  {
    bytes32[] memory encodedInputs = new bytes32[](order.inputs.length);
    for (uint256 i = 0; i < order.inputs.length; i++) {
      encodedInputs[i] = keccak256(encodeTokenInfo(order.inputs[i]));
    }
    bytes32[] memory encodedOutputs = new bytes32[](order.outputs.length);
    for (uint256 i = 0; i < order.outputs.length; i++) {
      encodedOutputs[i] = keccak256(encodeTokenInfo(order.outputs[i]));
    }

    return
      abi.encode(
      MULTI_LIMIT_ORDER_TYPEHASH,
      keccak256(abi.encodePacked(encodedInputs)),
      keccak256(abi.encodePacked(encodedOutputs)),
      order.expiry,
      order.salt,
      order.referralCode,
      order.partiallyFillable
    );
  }

  /// @notice Returns single input limit order hash
  /// @param order Single input limit order
  /// @return hash Order hash
  function getLimitOrderHash(LimitOrder calldata order)
  public
  view
  returns (bytes32 hash)
  {
    return _hashTypedDataV4(keccak256(encodeLimitOrder(order)));
  }

  /// @notice Returns multi input limit order hash
  /// @param order Multi input limit order
  /// @return hash Order hash
  function getMultiLimitOrderHash(
    MultiLimitOrder calldata order
  )
  public
  view
  returns (bytes32 hash)
  {
    return _hashTypedDataV4(keccak256(encodeMultiLimitOrder(order)));
  }

  /// @dev Checks order parameters and current order state before execution
  /// @param order Single input limit order struct
  function _limitOrderChecks(
    LimitOrder calldata order
  )
  internal
  view
  {
    // 1. Check msg.sender allowed
    if (!allowedFillers[msg.sender]) {
      revert AddressNotAllowed(msg.sender);
    }

    // 2. Check if order still valid
    if (order.expiry < block.timestamp) {
      revert OrderExpired(order.expiry, block.timestamp);
    }

    // 3. Check tokens, amounts
    if (order.input.tokenAddress == order.output.tokenAddress) {
      revert ArbitrageNotAllowed(order.input.tokenAddress);
    }
  }

  /// @dev Limit order checks
  /// @param order Single input limit order struct
  /// @param context Order execution context
  /// @param orderHash Limit order struct hash
  /// @param orderOwner Order owner address
  /// @return filledAmount Order amount filled by now
  function _getFilledAmount(
    LimitOrder calldata order,
    LimitOrderContext calldata context,
    bytes32 orderHash,
    address orderOwner
  )
  internal
  view
  returns (
    uint256 filledAmount
  )
  {
    // 6. Extract previously filled amounts for order from storage, or create
    filledAmount = limitOrders[orderOwner][orderHash];

    if (filledAmount == type(uint256).max) {
      revert OrderCancelled(orderHash);
    }

    // 7. Check if fill possible:
    //   - If partiallyFillable, total amount do not exceed
    //   - If not partiallyFillable - it was not filled previously
    if (order.partiallyFillable) {
      // Check that the currentAmount fits the total order amount
      if (filledAmount + context.currentAmount > order.input.tokenAmount) {
        revert CurrentAmountMismatch(order.input.tokenAddress, order.input.tokenAmount, filledAmount, context.currentAmount);
      }
    } else {
      // Revert if order was filled or currentAmount is not equal to the order amount
      if (filledAmount > 0 || context.currentAmount != order.input.tokenAmount) {
        revert CurrentAmountMismatch(order.input.tokenAddress, order.input.tokenAmount, filledAmount, context.currentAmount);
      }
    }
  }

  /// @dev Fills single input limit order
  /// @param order Single input limit order struct
  /// @param context Order execution context
  /// @param orderHash Order hash
  /// @param orderOwner Order owner address
  /// @param filledAmount Amount filled by now
  function _limitOrderFill(
    LimitOrder calldata order,
    LimitOrderContext calldata context,
    bytes32 orderHash,
    address orderOwner,
    uint256 filledAmount
  )
  internal
  {
    // 9. Update order filled amounts in storage
    filledAmount += context.currentAmount;
    limitOrders[orderOwner][orderHash] = filledAmount;

    LimitOrderHelper memory helper;

    // 10. Get output token balances before
    helper.balanceBefore = IERC20(order.output.tokenAddress).balanceOf(address(this));

    // 11. Call Odos Executor
    {
      uint256[] memory amountsIn = new uint256[](1);
      amountsIn[0] = context.currentAmount;
      IOdosExecutor(context.odosExecutor).executePath(context.pathDefinition, amountsIn, msg.sender);
    }

    // 12. Get output token balances difference
    helper.amountOut = IERC20(order.output.tokenAddress).balanceOf(address(this)) - helper.balanceBefore;

    // calculate prorated output amount in case of partial fill, otherwise it will be equal to order.output.tokenAmount
    helper.proratedAmount = SCALE * order.output.tokenAmount * context.currentAmount / order.input.tokenAmount / SCALE;

    // 13. Calculate and transfer referral fee if any
    if (order.referralCode > REFERRAL_WITH_FEE_THRESHOLD) {
      IOdosRouterV2.referralInfo memory ri = IOdosRouterV2(ODOS_ROUTER_V2).referralLookup(order.referralCode);
      uint256 beneficiaryAmount = helper.amountOut * ri.referralFee * 8 / (FEE_DENOM * 10);
      helper.amountOut = helper.amountOut * (FEE_DENOM - ri.referralFee) / FEE_DENOM;
      IERC20(order.output.tokenAddress).safeTransfer(ri.beneficiary, beneficiaryAmount);
    }

    // 14. Check slippage, adjust amountOut
    if (helper.amountOut < helper.proratedAmount) {
      revert SlippageLimitExceeded(order.output.tokenAddress, helper.proratedAmount, helper.amountOut);
    }

    // 15. Check surplus
    helper.surplus = helper.amountOut - helper.proratedAmount;
    if (helper.surplus < context.minSurplus) {
      revert MinSurplusCheckFailed(order.output.tokenAddress, context.minSurplus, helper.surplus);
    }

    // 16. Transfer tokens to the order owner
    IERC20(order.output.tokenAddress).safeTransfer(orderOwner, helper.proratedAmount);

    // 17. Emit LimitOrderFilled event
    emit LimitOrderFilled(
      orderHash,
      orderOwner,
      order.input.tokenAddress,
      order.output.tokenAddress,
      order.input.tokenAmount,
      order.output.tokenAmount,
      context.currentAmount,
      helper.proratedAmount,
      helper.surplus,
      order.referralCode
    );
  }

  /// @dev Checks order parameters and current order state before execution
  /// @param order Multi input limit order struct
  function _multiOrderChecks(
    MultiLimitOrder calldata order
  )
  internal
  view
  {
    // 1. Check msg.sender allowed
    if (!allowedFillers[msg.sender]) {
      revert AddressNotAllowed(msg.sender);
    }

    // 2. Check if order still valid
    if (order.expiry < block.timestamp) {
      revert OrderExpired(order.expiry, block.timestamp);
    }

    // 3. Check tokens, amounts
    for (uint256 i = 0; i < order.inputs.length; i++) {
      for (uint256 j = 0; j < order.outputs.length; j++) {
        if (order.inputs[i].tokenAddress == order.outputs[j].tokenAddress) {
          revert ArbitrageNotAllowed(order.inputs[i].tokenAddress);
        }
      }
    }
  }

  /// @dev Checks order parameters and current order state before execution
  /// @param order Multi input limit order struct
  /// @param context Order execution context
  /// @param orderHash Order struct hash
  /// @return helper Helper struct which contains order information
  function _getMultiFilledAmount(
    MultiLimitOrder calldata order,
    MultiLimitOrderContext calldata context,
    bytes32 orderHash,
    address orderOwner
  )
  internal
  view
  returns (
    MultiLimitOrderHelper memory helper
  )
  {
    helper = MultiLimitOrderHelper({
      inputTokens: new address[](order.inputs.length),
      outputTokens: new address[](order.outputs.length),
      orderInputAmounts: new uint256[](order.inputs.length),
      orderOutputAmounts: new uint256[](order.outputs.length),
      filledAmounts: new uint256[](order.inputs.length),
      filledOutputAmounts: new uint256[](order.outputs.length),
      surplus: new uint256[](order.outputs.length),
      balancesBefore: new uint256[](order.outputs.length),
      orderOwner : orderOwner,
      orderHash : orderHash
    });

    // 6. Extract previously filled amounts for order from storage, or create
    helper.filledAmounts = multiLimitOrders[orderOwner][orderHash];

    if (helper.filledAmounts.length > 0 && helper.filledAmounts[0] == type(uint256).max) {
      revert OrderCancelled(orderHash);
    }

    if (helper.filledAmounts.length == 0) {
      helper.filledAmounts = new uint256[](order.inputs.length);
    }

    // 7. Check if fill possible:
    //   - If partiallyFillable, total amount do not exceed
    //   - If not partiallyFillable - it was not filled previously
    if (order.partiallyFillable) {
      // Check that the currentAmount fits the total order amount
      for (uint256 i = 0; i < helper.filledAmounts.length; i++) {
        if (helper.filledAmounts[i] + context.currentAmounts[i] > order.inputs[i].tokenAmount) {
          revert CurrentAmountMismatch(order.inputs[i].tokenAddress, order.inputs[i].tokenAmount,
            helper.filledAmounts[i], context.currentAmounts[i]);
        }
      }
    } else {
      // Revert if order was filled or currentAmount is not equal to the order amount
      for (uint256 i = 0; i < helper.filledAmounts.length; i++) {
        if (helper.filledAmounts[i] > 0 || context.currentAmounts[i] != order.inputs[i].tokenAmount) {
          revert CurrentAmountMismatch(order.inputs[i].tokenAddress, order.inputs[i].tokenAmount,
            helper.filledAmounts[i], context.currentAmounts[i]);
        }
      }
    }
  }

  /// @dev Fills multi input limit order
  /// @param order Multi input limit order struct
  /// @param context Order execution context
  /// @param helper Helper struct which contains order information
  function _multiLimitOrderFill(
    MultiLimitOrder calldata order,
    MultiLimitOrderContext calldata context,
    MultiLimitOrderHelper memory helper
  )
  internal
  {
    // 9. Update order filled amounts in storage
    multiLimitOrders[helper.orderOwner][helper.orderHash] = helper.filledAmounts;

    // 10. Get output token balances before
    for (uint256 i = 0; i < order.outputs.length; i++) {
      helper.outputTokens[i] = order.outputs[i].tokenAddress;
      helper.orderOutputAmounts[i] = order.outputs[i].tokenAmount;
      helper.balancesBefore[i] = IERC20(order.outputs[i].tokenAddress).balanceOf(address(this));
    }
    // 11. Call Odos Executor
    IOdosExecutor(context.odosExecutor).executePath(context.pathDefinition, context.currentAmounts, msg.sender);

    {
      // 12. Get output token balances difference
      uint256[] memory amountsOut = new uint256[](order.outputs.length);
      for (uint256 i = 0; i < order.outputs.length; i++) {
        amountsOut[i] = IERC20(order.outputs[i].tokenAddress).balanceOf(address(this)) - helper.balancesBefore[i];
      }


      IOdosRouterV2.referralInfo memory ri;
      if (order.referralCode > REFERRAL_WITH_FEE_THRESHOLD) {
        ri = IOdosRouterV2(ODOS_ROUTER_V2).referralLookup(order.referralCode);
      }

      for (uint256 i = 0; i < order.outputs.length; i++) {
        // 13. Calculate and transfer referral fee if any
        if (order.referralCode > REFERRAL_WITH_FEE_THRESHOLD) {
          uint256 beneficiaryAmount = amountsOut[i] * ri.referralFee * 8 / (FEE_DENOM * 10);
          amountsOut[i] = amountsOut[i] * (FEE_DENOM - ri.referralFee) / FEE_DENOM;
          IERC20(order.outputs[i].tokenAddress).safeTransfer(ri.beneficiary, beneficiaryAmount);
        }

        // calculate prorated output amount in case of partial fill, otherwise it will be equal to order.output.tokenAmount
        uint256 proratedAmount = SCALE * order.outputs[i].tokenAmount * context.currentAmounts[i] / order.inputs[i].tokenAmount / SCALE;

        // 14. Check slippage, adjust amountOut
        if (amountsOut[i] < proratedAmount) {
          revert SlippageLimitExceeded(order.outputs[i].tokenAddress, proratedAmount, amountsOut[i]);
        }
        helper.filledOutputAmounts[i] = proratedAmount;

        // 15. Check surplus
        helper.surplus[i] = amountsOut[i] - proratedAmount;
        if (helper.surplus[i] < context.minSurplus[i]) {
          revert MinSurplusCheckFailed(order.outputs[i].tokenAddress, context.minSurplus[i], helper.surplus[i]);
        }

        // 16. Transfer tokens to the order owner
        IERC20(order.outputs[i].tokenAddress).safeTransfer(helper.orderOwner, proratedAmount);
      }
    }

    // 17. Emit LimitOrderFilled event
    emit MultiLimitOrderFilled(
      helper.orderHash,
      helper.orderOwner,
      helper.inputTokens,
      helper.outputTokens,
      helper.orderInputAmounts,
      helper.orderOutputAmounts,
      context.currentAmounts,
      helper.filledOutputAmounts,
      helper.surplus,
      order.referralCode
    );
  }

}
