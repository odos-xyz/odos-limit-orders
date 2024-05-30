// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import "forge-std/Test.sol";
import "@openzeppelin/contracts/utils/cryptography/EIP712.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC20Errors} from "../interfaces/draft-IERC6093.sol";
import "../interfaces/IOdosExecutor.sol";
import "../interfaces/ISignatureTransfer.sol";
import {MockOdosExecutor} from "./MockOdosExecutor.sol";
import {MockERC20} from "./MockERC20.sol";
import "../contracts/OdosLimitOrderRouter.sol";
import "../contracts/SignatureValidator.sol";
import "./MockPermit2.sol";
import "./MockOdosRouterV2.sol";


contract OdosLimitOrderHelperTest is Test, EIP712("OdosLimitOrders", "1"), IERC20Errors {

  // Uniswap Permit2 errors
  /// @notice Thrown when the recovered contract signature is incorrect
  error InvalidContractSignature();

  /// @notice Thrown when the recovered signer does not equal the claimedSigner
  error InvalidSigner();

  MockOdosExecutor immutable ODOS_EXECUTOR;
  ISignatureTransfer immutable PERMIT2;
  IOdosRouterV2 immutable ODOS_ROUTER_V2;
  OdosLimitOrderRouter immutable ROUTER;

  address constant _ETH = address(0);
  uint256 constant FEE_DENOM = 1e18;

  address immutable USDC = address(new MockERC20("USDC"));
  address immutable DAI = address(new MockERC20("DAI"));
  address immutable FRAX = address(new MockERC20("FRAX"));
  address immutable USDT = address(new MockERC20("USDT"));

  uint256 constant SIGNER_PK = 1;
  address immutable SIGNER_ADDRESS = vm.addr(SIGNER_PK);

  // Code for a fee https://docs.odos.xyz/product/sor/v2/referral-code/
  uint32 constant public REFERRAL_CODE_FEE = 2147483649;
  uint64 constant public REFERRAL_FEE = 1000000000000000;
  address constant public REFERRAL_BENEFICIARY_ADDRESS_FEE = 0x7758341fbe130d09132aa630fCC9a3c4523376C9;

  // Code for tracking
  uint32 constant public REFERRAL_CODE_TRACK = 2147483648;
  address constant public REFERRAL_BENEFICIARY_ADDRESS_TRACK = 0x8858341fBE130D09132Aa630fcc9a3c4523376C7;

  bytes32 public constant TOKEN_PERMISSIONS_TYPEHASH = keccak256("TokenPermissions(address token,uint256 amount)");

  constructor() {
    ODOS_EXECUTOR = new MockOdosExecutor();
    PERMIT2 = new MockPermit2();
    ODOS_ROUTER_V2 = new MockOdosRouterV2();
    ROUTER = new OdosLimitOrderRouter(address(ODOS_ROUTER_V2));
  }


  function setUp() virtual public {
    ODOS_ROUTER_V2.registerReferralCode(REFERRAL_CODE_FEE, REFERRAL_FEE, REFERRAL_BENEFICIARY_ADDRESS_FEE);
    ODOS_ROUTER_V2.registerReferralCode(REFERRAL_CODE_TRACK, 0, REFERRAL_BENEFICIARY_ADDRESS_TRACK);
  }

  /// Creates a limit order with default parameters which can be overridden if necessary before signing the order
  function getLimitOrderWitnessTypeHash()
  public
  view
  returns (
    bytes32 typeHash
  )
  {
    return keccak256(abi.encodePacked(
      "PermitWitnessTransferFrom(TokenPermissions permitted,address spender,uint256 nonce,uint256 deadline,",
      ROUTER.LIMIT_ORDER_WITNESS_TYPE_STRING()
    ));
  }
  /// Creates a limit order with default parameters which can be overridden if necessary before signing the order
  function getMultiLimitOrderWitnessTypeHash()
  public
  view
  returns (
    bytes32 typeHash
  )
  {
    return keccak256(abi.encodePacked(
      "PermitBatchWitnessTransferFrom(TokenPermissions[] permitted,address spender,uint256 nonce,uint256 deadline,",
      ROUTER.MULTI_LIMIT_ORDER_WITNESS_TYPE_STRING()
    ));
  }

  /// Creates a limit order with default parameters which can be overridden if necessary before signing the order
  function createDefaultLimitOrder()
  public
  view
  returns (
    OdosLimitOrderRouter.LimitOrder memory order
  )
  {
    // default test parameters
    address inputToken = DAI;
    uint256 inputAmount = 2001 * 1e18;

    address outputToken = USDC;
    uint256 outputAmount = 2001 * 1e6;

    // create default limit order
    order = OdosLimitOrderRouter.LimitOrder({
      input: OdosLimitOrderRouter.TokenInfo(inputToken, inputAmount),
      output: OdosLimitOrderRouter.TokenInfo(outputToken, outputAmount),
      salt: 1,
      expiry: block.timestamp + 86400,
      referralCode: 0,
      partiallyFillable: false
    });
  }

  /// Creates default executor context
  function getDefaultContext(uint256 amountOut)
  public
  view
  returns (
    OdosLimitOrderRouter.LimitOrderContext memory context
  ) {
    address[] memory tokensOut = new address[](1);
    tokensOut[0] = USDC;

    uint256[] memory amountsOut = new uint256[](1);
    amountsOut[0] = amountOut;

    // fill the default executor context
    // the pathDefinition tells the executor which token and amount it should return
    // the currentAmount corresponds to the inputAmount of the order
    context = OdosLimitOrderRouter.LimitOrderContext({
      pathDefinition: abi.encode(tokensOut, amountsOut),
      odosExecutor: address(ODOS_EXECUTOR),
      currentAmount: 2001 * 1e18,
      inputReceiver: address(ROUTER),
      minSurplus: 0
    });
  }

  function getOrderSignature(
    OdosLimitOrderRouter.LimitOrder memory order
  )
  public
  view
  returns (
    SignatureValidator.Signature memory signature
  ) {
    // get order hash
    bytes32 orderHash = ROUTER.getLimitOrderHash(order);

    // get signature
    (uint8 v, bytes32 r, bytes32 s) = vm.sign(SIGNER_PK, orderHash);

    // combine signature components
    signature = SignatureValidator.Signature({
      signature: abi.encodePacked(r, s, v),
      validationMethod: SignatureValidator.SignatureValidationMethod.EIP712
    });
  }


  function createDefaultMultiLimitOrder()
  public
  view
  returns (
    OdosLimitOrderRouter.MultiLimitOrder memory order
  ) {
    // Construct Limit Order
    OdosLimitOrderRouter.TokenInfo[] memory inputs = new OdosLimitOrderRouter.TokenInfo[](2);
    inputs[0] = OdosLimitOrderRouter.TokenInfo(DAI, 1999 * 1e18);
    inputs[1] = OdosLimitOrderRouter.TokenInfo(FRAX, 2001 * 1e18);

    OdosLimitOrderRouter.TokenInfo[] memory outputs = new OdosLimitOrderRouter.TokenInfo[](2);
    outputs[0] = OdosLimitOrderRouter.TokenInfo(USDC, 2002 * 1e6);
    outputs[1] = OdosLimitOrderRouter.TokenInfo(USDT, 1998 * 1e18);

    order = OdosLimitOrderRouter.MultiLimitOrder({
      inputs: inputs,
      outputs: outputs,
      salt: 1,
      expiry: block.timestamp + 86400,
      referralCode: 0,
      partiallyFillable: false
    });
  }

  function getDefaultMultiContext(
    uint256 amountOut1,
    uint256 amountOut2
  )
  public
  view
  returns (
    OdosLimitOrderRouter.MultiLimitOrderContext memory context
  ) {
    // prepare executor outcome
    address[] memory tokensOut = new address[](2);
    tokensOut[0] = USDC;
    tokensOut[1] = USDT;

    uint256[] memory amountsOut = new uint256[](2);
    amountsOut[0] = amountOut1;
    amountsOut[1] = amountOut2;

    uint256[] memory currentAmounts = new uint256[](2);
    currentAmounts[0] = 1999 * 1e18;
    currentAmounts[1] = 2001 * 1e18;

    address[] memory inputReceivers = new address[](2);
    inputReceivers[0] = address(ROUTER);
    inputReceivers[1] = address(ROUTER);

    uint256[] memory minSurplus = new uint256[](2);

    // fill the executor context
    context = OdosLimitOrderRouter.MultiLimitOrderContext({
      pathDefinition: abi.encode(tokensOut, amountsOut),
      odosExecutor: address(ODOS_EXECUTOR),
      currentAmounts: currentAmounts,
      inputReceivers: inputReceivers,
      minSurplus: minSurplus
    });
  }

  function getMultiOrderSignature(
    OdosLimitOrderRouter.MultiLimitOrder memory order
  )
  public
  view
  returns (
    SignatureValidator.Signature memory signature
  ) {
    // get order hash
    bytes32 orderHash = ROUTER.getMultiLimitOrderHash(order);

    // get signature
    (uint8 v, bytes32 r, bytes32 s) = vm.sign(SIGNER_PK, orderHash);

    // combine signature components
    signature = SignatureValidator.Signature({
      signature: abi.encodePacked(r, s, v),
      validationMethod: SignatureValidator.SignatureValidationMethod.EIP712
    });
  }

  function mintToken(address tokenAddress, uint256 tokenAmount) public {
    if (tokenAddress != _ETH) {
      // mint tokens to account
      MockERC20(tokenAddress).faucet(SIGNER_ADDRESS, tokenAmount);

      // approve spend
      vm.prank(SIGNER_ADDRESS);
      IERC20(tokenAddress).approve(address(ROUTER), tokenAmount);
    }
  }

  function mintTokens(address to) public {
    address inputToken1 = DAI;
    uint256 inputAmount1 = 2001 * 1e18;
    address inputToken2 = FRAX;
    uint256 inputAmount2 = 2001 * 1e18;

    // mint tokens to account
    MockERC20(inputToken1).faucet(to, inputAmount1);
    MockERC20(inputToken2).faucet(to, inputAmount2);

    // approve spend
    vm.startPrank(to);
    IERC20(inputToken1).approve(address(ROUTER), inputAmount1);
    IERC20(inputToken2).approve(address(ROUTER), inputAmount2);
    vm.stopPrank();
  }

  // Generate a signature for a permit message
  function signPermitWitnessTransfer(
    ISignatureTransfer.PermitTransferFrom memory permit,
    address spender,
    uint256 signerKey,
    bytes32 witness
  )
  internal
  view
  returns (bytes memory sig)
  {
    bytes32 msgHash = keccak256(abi.encodePacked(
      "\x19\x01",
      ISignatureTransfer(address(PERMIT2)).DOMAIN_SEPARATOR(),
      keccak256(abi.encode(
        getLimitOrderWitnessTypeHash(),
        keccak256(abi.encode(
          TOKEN_PERMISSIONS_TYPEHASH,
          ISignatureTransfer.TokenPermissions(
            permit.permitted.token,
            permit.permitted.amount
          )
        )),
        spender,
        permit.nonce,
        permit.deadline,
        witness
      ))
    ));

    (uint8 v, bytes32 r, bytes32 s) = vm.sign(signerKey, msgHash);
    return abi.encodePacked(r, s, v);
  }

  // Generate a signature for a batch permit message
  function signPermitBatchTransfer(
    ISignatureTransfer.PermitBatchTransferFrom memory permit,
    address spender,
    uint256 privateKey,
    bytes32 witness
  )
  internal
  view
  returns (bytes memory sig) {
    bytes32[] memory tokenPermissions = new bytes32[](permit.permitted.length);
    for (uint256 i = 0; i < permit.permitted.length; ++i) {
      tokenPermissions[i] = keccak256(abi.encode(TOKEN_PERMISSIONS_TYPEHASH, permit.permitted[i]));
    }
    bytes32 msgHash = keccak256(
      abi.encodePacked(
        "\x19\x01",
        ISignatureTransfer(address(PERMIT2)).DOMAIN_SEPARATOR(),
        keccak256(
          abi.encode(
            getMultiLimitOrderWitnessTypeHash(),
            keccak256(abi.encodePacked(tokenPermissions)),
            spender,
            permit.nonce,
            permit.deadline,
            witness
          )
        )
      )
    );

    (uint8 v, bytes32 r, bytes32 s) = vm.sign(privateKey, msgHash);
    return abi.encodePacked(r, s, v);
  }

  function createLimitOrderPermit2(
    OdosLimitOrderRouter.LimitOrder memory order,
    OdosLimitOrderRouter.LimitOrderContext memory context,
    bytes32 orderHash,
    address orderOwner
  )
  public
  view
  returns (
    OdosLimitOrderRouter.Permit2Info memory odos_swap_permit
  ) {
    // create standard permit2
    ISignatureTransfer.PermitTransferFrom memory swap_permit = ISignatureTransfer.PermitTransferFrom({
            permitted: ISignatureTransfer.TokenPermissions({
                token: order.input.tokenAddress,
                amount: context.currentAmount
            }),
            nonce: 1,
            deadline: block.timestamp
    });

    // create Odos permit2
    odos_swap_permit = OdosLimitOrderRouter.Permit2Info({
      contractAddress: address(PERMIT2),
      nonce: swap_permit.nonce,
      deadline: swap_permit.deadline,
      orderOwner: orderOwner,
      signature: signPermitWitnessTransfer(swap_permit, address(ROUTER), SIGNER_PK, orderHash)
    });
  }

  function createMultiLimitOrderPermit2(
    OdosLimitOrderRouter.MultiLimitOrder memory order,
    OdosLimitOrderRouter.MultiLimitOrderContext memory context,
    bytes32 orderHash,
    address orderOwner
  )
  public
  view
  returns (
    OdosLimitOrderRouter.Permit2Info memory odos_swap_permit
  ) {
    // create standard permit2
    ISignatureTransfer.PermitBatchTransferFrom memory swap_permit = ISignatureTransfer.PermitBatchTransferFrom(
      new ISignatureTransfer.TokenPermissions[](order.inputs.length),
      1,
      block.timestamp
    );
    ISignatureTransfer.SignatureTransferDetails[] memory transferDetails
      = new ISignatureTransfer.SignatureTransferDetails[](order.inputs.length);

    for (uint256 i = 0; i < order.inputs.length; i++) {
      swap_permit.permitted[i].token = order.inputs[i].tokenAddress;
      swap_permit.permitted[i].amount = context.currentAmounts[i];

      transferDetails[i].to = context.inputReceivers[i];
      transferDetails[i].requestedAmount = context.currentAmounts[i];
    }

    // create Odos permit2
    odos_swap_permit = OdosLimitOrderRouter.Permit2Info({
      contractAddress: address(PERMIT2),
      nonce: swap_permit.nonce,
      deadline: swap_permit.deadline,
      orderOwner: orderOwner,
      signature: signPermitBatchTransfer(swap_permit, address(ROUTER), SIGNER_PK, orderHash)
    });
  }

  /// @notice Constructs Permit2 with the single input limit order as a witness
  /// @param order Single input limit order struct
  /// @param context Order execution context
  /// @param permit2 Permit2 struct
  /// @param orderHash Order hash
  /// @return permit2Hash Hash of standard Permit2 struct with witness
  function getPermitWitnessHash(
    OdosLimitOrderRouter.LimitOrder memory order,
    OdosLimitOrderRouter.LimitOrderContext memory context,
    OdosLimitOrderRouter.Permit2Info memory permit2,
    bytes32 orderHash,
    address spender
  )
  public
  view
  returns(
    bytes32 permit2Hash
  )
  {
    permit2Hash = keccak256(abi.encodePacked(
      "\x19\x01",
      ISignatureTransfer(permit2.contractAddress).DOMAIN_SEPARATOR(),
      keccak256(abi.encode(
        getLimitOrderWitnessTypeHash(),
        keccak256(abi.encode(
          TOKEN_PERMISSIONS_TYPEHASH,
          ISignatureTransfer.TokenPermissions({token: order.input.tokenAddress, amount:context.currentAmount})
        )),
        spender,
        permit2.nonce,
        permit2.deadline,
        orderHash
      ))
    ));
  }

  /// @notice Constructs Permit2 with the multi input limit order as a witness
  /// @param order Multi input limit order struct
  /// @param context Order execution context
  /// @param permit2 Permit2 struct
  /// @param orderHash Order hash
  /// @return permit2Hash Hash of standard Permit2 batch struct with witness
  function getBatchPermitWitnessHash(
    OdosLimitOrderRouter.MultiLimitOrder memory order,
    OdosLimitOrderRouter.MultiLimitOrderContext memory context,
    OdosLimitOrderRouter.Permit2Info memory permit2,
    bytes32 orderHash,
    address spender
  )
  public
  view
  returns(
    bytes32 permit2Hash
  )
  {
    bytes32[] memory tokenPermissions = new bytes32[](order.inputs.length);
    for (uint256 i = 0; i < order.inputs.length; ++i) {
      tokenPermissions[i] = keccak256(abi.encode(TOKEN_PERMISSIONS_TYPEHASH, order.inputs[i].tokenAddress, context.currentAmounts[i]));
    }
    permit2Hash = keccak256(
      abi.encodePacked(
        "\x19\x01",
        ISignatureTransfer(permit2.contractAddress).DOMAIN_SEPARATOR(),
        keccak256(
          abi.encode(
            getMultiLimitOrderWitnessTypeHash(),
            keccak256(abi.encodePacked(tokenPermissions)),
            spender,
            permit2.nonce,
            permit2.deadline,
            orderHash
          )
        )
      )
    );
  }

}
