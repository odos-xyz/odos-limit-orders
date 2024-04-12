// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

import "@openzeppelin/contracts/utils/cryptography/EIP712.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "../interfaces/IOdosExecutor.sol";
import {MockOdosExecutor} from "./MockOdosExecutor.sol";
import {MockERC20} from "./MockERC20.sol";
import {IERC20Errors} from "@openzeppelin/contracts/interfaces/draft-IERC6093.sol";

import "./OdosLimitOrderHelper.t.sol";
import "../contracts/OdosLimitOrderRouter.sol";

/// @notice This contract tests router functions besides single and multi limit order execution functions
contract OdosLimitOrderRouterTest is OdosLimitOrderHelperTest {

  event AllowedFillerAdded(address indexed _address);
  event AllowedFillerRemoved(address indexed _address);
  event LiquidatorAddressChanged(address indexed account);

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
  event Transfer(address indexed from, address indexed to, uint256 value);

  struct SwapRouterFundsHelper{
    address[] inputTokens;
    uint256[] inputAmounts;
    address[] inputReceivers;
  }

  // Fallback for receiving ETH
  receive() external payable {}

  /// @dev Tests that the executor returns the encoded amounts as expected
  function testExecutor() public {
    uint256[] memory inputAmounts = new uint256[](1);
    inputAmounts[0] = 2024;
    IOdosExecutor executor = new MockOdosExecutor();

    // prepare test path
    address[] memory tokenAddresses = new address[](2);
    tokenAddresses[0] = USDC;
    tokenAddresses[1] = DAI;

    uint256[] memory tokenAmounts = new uint256[](2);
    tokenAmounts[0] = 123 * 1e18;
    tokenAmounts[1] = 234 * 1e6;
    bytes memory bytecode = abi.encode(tokenAddresses, tokenAmounts);

    IOdosExecutor(executor).executePath(bytecode, inputAmounts, msg.sender);
    assertEq(IERC20(USDC).balanceOf(address(this)), 123 * 1e18);
    assertEq(IERC20(DAI).balanceOf(address(this)), 234 * 1e6);
  }

  function testAddAllowedFiller() public {
    // check that event is emitted, check all topics
    vm.expectEmit(true, true, true, true);
    emit AllowedFillerAdded(address(this));
    ROUTER.addAllowedFiller(address(this));
  }

  function testAddAllowedFille_reverts() public {
    // replace the sender address
    vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, 0x7E5F4552091A69125d5DfCb7b8C2659029395Bdf));
    vm.prank(SIGNER_ADDRESS);
    ROUTER.addAllowedFiller(address(this));
  }

  function testRemoveFromWhitelist() public {
    testAddAllowedFiller();
    // check that event is emitted, check all topics
    vm.expectEmit(true, true, true, true);
    emit AllowedFillerRemoved(address(this));
    ROUTER.removeAllowedFiller(address(this));
  }

  /// @dev Successfully swaps the router funds
  function testRouterSwap_succeeds() public {
    address inputToken1 = DAI;
    uint256 inputAmount1 = 2000 * 1e18;
    address inputToken2 = FRAX;
    uint256 inputAmount2 = 2001 * 1e18;
    address outputToken = USDC;
    uint256 amountOut = 4001 * 1e6;

    OdosLimitOrderRouter.TokenInfo[] memory inputs = new OdosLimitOrderRouter.TokenInfo[](2);
    inputs[0] = OdosLimitOrderRouter.TokenInfo(inputToken1, inputAmount1);
    inputs[1] = OdosLimitOrderRouter.TokenInfo(inputToken2, inputAmount2);

    // mint tokens to router
    MockERC20(inputToken1).faucet(address(ROUTER), inputAmount1);
    MockERC20(inputToken2).faucet(address(ROUTER), inputAmount2);

    address[] memory tokensOut = new address[](1);
    tokensOut[0] = outputToken;

    uint256[] memory amountsOut = new uint256[](1);
    amountsOut[0] = amountOut;

    bytes memory pathDefinition = abi.encode(tokensOut, amountsOut);

    OdosLimitOrderRouter.TokenInfo memory output = OdosLimitOrderRouter.TokenInfo({
      tokenAddress : outputToken,
      tokenAmount : amountOut
    });

    SwapRouterFundsHelper memory helper = SwapRouterFundsHelper({
      inputTokens: new address[](2),
      inputAmounts: new uint256[](2),
      inputReceivers: new address[](2)

    });
    helper.inputTokens[0] = inputToken1;
    helper.inputTokens[1] = inputToken2;
    helper.inputAmounts[0] = inputAmount1;
    helper.inputAmounts[1] = inputAmount2;
    helper.inputReceivers[0] = address(ROUTER);
    helper.inputReceivers[1] = address(ROUTER);

    uint256 usdcBalanceBefore = IERC20(outputToken).balanceOf(address(this));

    // check that event is emitted
    vm.expectEmit(true, true, true, true);
    emit SwapRouterFunds(
      address(this),
      helper.inputTokens,
      helper.inputAmounts,
      helper.inputReceivers,
      outputToken,
      amountOut,
      address(this),
      amountOut
    );

    ROUTER.swapRouterFunds(
      inputs,
      helper.inputReceivers,
      output,
      address(this),
      pathDefinition,
      address(ODOS_EXECUTOR)
    );

    uint256 usdcBalanceDiff = IERC20(outputToken).balanceOf(address(this)) - usdcBalanceBefore;
    assertTrue(usdcBalanceDiff == 4001 * 1e6);
  }

  /// @dev Reverts if the swap output amount is smaller than expected
  function testRouterSwap_reverts() public {
    address inputToken1 = DAI;
    uint256 inputAmount1 = 2000 * 1e18;
    address inputToken2 = FRAX;
    uint256 inputAmount2 = 2001 * 1e18;
    address outputToken = USDC;
    uint256 amountOut = 4001 * 1e6;

    OdosLimitOrderRouter.TokenInfo[] memory inputs = new OdosLimitOrderRouter.TokenInfo[](2);
    inputs[0] = OdosLimitOrderRouter.TokenInfo(inputToken1, inputAmount1);
    inputs[1] = OdosLimitOrderRouter.TokenInfo(inputToken2, inputAmount2);

    // mint tokens to router
    MockERC20(inputToken1).faucet(address(ROUTER), inputAmount1);
    MockERC20(inputToken2).faucet(address(ROUTER), inputAmount2);

    address[] memory tokensOut = new address[](1);
    tokensOut[0] = outputToken;

    // amountsOut is smaller than expected
    uint256[] memory amountsOut = new uint256[](1);
    amountsOut[0] = amountOut - 1;

    bytes memory pathDefinition = abi.encode(tokensOut, amountsOut);

    OdosLimitOrderRouter.TokenInfo memory output = OdosLimitOrderRouter.TokenInfo({
      tokenAddress : outputToken,
      tokenAmount : amountOut
    });

    address[] memory inputReceivers = new address[](2);
    inputReceivers[0] = address(ROUTER);
    inputReceivers[1] = address(ROUTER);

    vm.expectRevert(abi.encodeWithSelector(SlippageLimitExceeded.selector, outputToken, amountOut, amountOut - 1));
    ROUTER.swapRouterFunds(
      inputs,
      inputReceivers,
      output,
      address(this),
      pathDefinition,
      address(ODOS_EXECUTOR)
    );
  }

  /// @dev Successfully transfers ERC20 tokens
  function test_transferRouterFunds_succeeds() public {
    address[] memory tokens = new address[](3);
    uint256[] memory amounts = new uint256[](3);
    tokens[0] = DAI;
    tokens[1] = FRAX;
    tokens[2] = _ETH;
    amounts[0] = 2000 * 1e18;
    amounts[1] = 2001 * 1e18;
    amounts[2] = 1 * 1e18;

    address dest = address(this);

    // mint tokens to router
    MockERC20(tokens[0]).faucet(address(ROUTER), amounts[0]);
    MockERC20(tokens[1]).faucet(address(ROUTER), amounts[1]);
    vm.deal(address(ROUTER), 1 ether);

    uint256 balanceBefore1 = IERC20(tokens[0]).balanceOf(address(this));
    uint256 balanceBefore2 = IERC20(tokens[1]).balanceOf(address(this));
    uint256 balanceBefore3 = address(this).balance;

    // assert ERC20 Transfer events emitted
    vm.expectEmit(true, true, true, true);
    emit Transfer(address(ROUTER), address(this), amounts[0]);

    vm.expectEmit(true, true, true, true);
    emit Transfer(address(ROUTER), address(this), amounts[1]);

    ROUTER.transferRouterFunds(tokens, amounts, dest);

    uint256 balanceDiff1 = IERC20(tokens[0]).balanceOf(address(this)) - balanceBefore1;
    uint256 balanceDiff2 = IERC20(tokens[1]).balanceOf(address(this)) - balanceBefore2;
    uint256 balanceDiff3 = address(this).balance - balanceBefore3;

    assertEq(amounts[0], balanceDiff1);
    assertEq(amounts[1], balanceDiff2);
    assertEq(amounts[2], balanceDiff3);
  }

  /// @dev Reverts if not enoght ETH
  function test_transferRouterFunds_reverts() public {
    address[] memory tokens = new address[](3);
    uint256[] memory amounts = new uint256[](3);
    tokens[0] = DAI;
    tokens[1] = FRAX;
    tokens[2] = _ETH;
    amounts[0] = 2000 * 1e18;
    amounts[1] = 2001 * 1e18;
    amounts[2] = 1 * 1e18;

    address dest = address(this);

    // mint tokens to router
    MockERC20(tokens[0]).faucet(address(ROUTER), amounts[0]);
    MockERC20(tokens[1]).faucet(address(ROUTER), amounts[1]);
    // Provide less ETH than expected
    vm.deal(address(ROUTER), 0.5 ether);

    vm.expectRevert(abi.encodeWithSelector(TransferFailed.selector, dest, amounts[2]));
    ROUTER.transferRouterFunds(tokens, amounts, dest);
  }

  /// @dev Reverts if not liquidator
  function test_transferRouterFunds_revertsIfNotLiquidator() public {
    address[] memory tokens = new address[](1);
    uint256[] memory amounts = new uint256[](1);
    tokens[0] = DAI;
    amounts[0] = 2000 * 1e18;

    address dest = address(this);

    // mint tokens to router
    MockERC20(tokens[0]).faucet(address(ROUTER), amounts[0]);

    vm.expectRevert(abi.encodeWithSelector(AddressNotAllowed.selector, SIGNER_ADDRESS));
    vm.prank(SIGNER_ADDRESS);
    ROUTER.transferRouterFunds(tokens, amounts, dest);
  }

  function test_transferRouterFunds_successIfLiquidator() public {
    address[] memory tokens = new address[](1);
    uint256[] memory amounts = new uint256[](1);
    tokens[0] = DAI;
    amounts[0] = 2000 * 1e18;

    address dest = address(this);

    // mint tokens to router
    MockERC20(tokens[0]).faucet(address(ROUTER), amounts[0]);

    // check that event is emitted, check all topics
    vm.expectEmit(true, true, true, true);
    emit LiquidatorAddressChanged(SIGNER_ADDRESS);

    ROUTER.changeLiquidatorAddress(SIGNER_ADDRESS);

    vm.prank(SIGNER_ADDRESS);
    ROUTER.transferRouterFunds(tokens, amounts, dest);
  }

  function test_changeLiquidatorAddress_reverts() public {
    vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, SIGNER_ADDRESS));
    vm.prank(SIGNER_ADDRESS);
    ROUTER.changeLiquidatorAddress(SIGNER_ADDRESS);
  }


}
