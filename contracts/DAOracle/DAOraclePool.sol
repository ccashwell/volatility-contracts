// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.7;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/draft-ERC20Permit.sol";

import "hardhat/console.sol";

/**
 * @title DAOraclePool
 * @dev The DAOracle Network relies on decentralized risk pools. This is a
 * simple implementation of a staking pool which wraps a single arbitrary token
 * and provides a mechanism for recouping losses incurred by the deployer of
 * the underlying. Pool ownership is represented as ERC20 tokens that can be
 * freely used as the holder sees fit. Holders of pool shares may make claims
 * proportional to their stake on the underlying token balance of the pool. Any
 * rewards or penalties applied to the pool will thus impact all holders.
 */
contract DAOraclePool is ERC20, ERC20Permit, Ownable {
  using SafeERC20 for IERC20;
  using SafeMath for uint256;

  /**
   * @dev The token being staked in this pool
   */
  IERC20 public underlying;

  /**
   * @dev The mint/burn fee config.
   * fees are in bps (amount * fee / 10000)
   */
  uint256 public mintFee;
  uint256 public burnFee;
  address public feePayee;

  event FeesChanged(uint256 mintFee, uint256 burnFee, address payee);
  event Fee(uint256 feeAmount);

  event Deposit(address indexed depositor, uint256 underlyingAmount, uint256 tokensMinted);
  event Payout(address indexed beneficiary, uint256 underlyingAmount, uint256 tokensBurned);

	constructor(
    IERC20 _underlying,
    uint256 _mintFee,
    uint256 _burnFee,
    address _feePayee
  ) ERC20("DAOracle Pool Token", "DPT") ERC20Permit("DPT") {
    underlying = _underlying;
    mintFee = _mintFee;
    burnFee = _burnFee;
    feePayee = _feePayee;
  }

  /**
   * @dev Mint pool shares for a given stake amount
   * @param _stakeAmount The amount of underlying to stake
   * @return shares The number of pool shares minted
   */
  function mint(uint256 _stakeAmount) external returns (uint256 shares) {
    require(
      underlying.allowance(msg.sender, address(this)) >= _stakeAmount,
      "mint: insufficient allowance"
    );

    // Grab the pre-deposit balance and shares for comparison
    uint256 oldBalance = underlying.balanceOf(address(this));
    uint256 oldShares = totalSupply();

    // Pull user's tokens into the pool
    underlying.safeTransferFrom(msg.sender, address(this), _stakeAmount);

    // Calculate the fee for minting
    uint256 fee = _stakeAmount.mul(mintFee).div(10000);
    if (fee != 0) {
      underlying.safeTransfer(feePayee, fee);
      _stakeAmount = _stakeAmount.sub(fee);
      emit Fee(fee);
    }

    // Calculate the pool shares for the new deposit
    if (oldShares != 0) {
      // shares = stake * oldShares / oldBalance
      shares = _stakeAmount.mul(oldShares).div(oldBalance);
    } else {
      // if no shares exist, just assign 1,000 shares (it's arbitrary)
      shares = 10**3;
    }

    // Transfer shares to caller
		_mint(msg.sender, shares);
    emit Deposit(msg.sender, _stakeAmount, shares);
  }

  /**
   * @dev Burn some pool shares and claim the underlying tokens
   * @param _shareAmount The number of shares to burn
   * @return tokens The number of underlying tokens returned
   */
  function burn(uint256 _shareAmount) external returns (uint256 tokens) {
    require(
      balanceOf(msg.sender) >= _shareAmount,
      "burn: insufficient shares"
    );

    // Calculate the user's share of the underlying balance
    uint256 balance = underlying.balanceOf(address(this));
    tokens = _shareAmount.mul(balance).div(totalSupply());

    // Burn the caller's shares before anything else
    _burn(msg.sender, _shareAmount);

    // Calculate the fee for burning
    uint256 fee = getBurnFee(tokens);
    if (fee != 0) {
      tokens = tokens.sub(fee);
      underlying.safeTransfer(feePayee, fee);
      emit Fee(fee);
    }

    // Transfer underlying tokens back to caller
    underlying.safeTransfer(msg.sender, tokens);
    emit Payout(msg.sender, tokens, _shareAmount);
  }

  /**
   * @dev Calculate the minting fee
   * @param _stakeAmount The number of tokens being staked
   * @return fee The calculated fee value
   */
  function getMintFee(uint256 _stakeAmount) public view returns (uint256 fee) {
    fee = _stakeAmount.mul(mintFee).div(10000);
  }

  /**
   * @dev Calculate the burning fee
   * @param _stakeAmount The number of tokens being staked
   * @return fee The calculated fee value
   */
  function getBurnFee(uint256 _stakeAmount) public view returns (uint256 fee) {
    fee = _stakeAmount.mul(burnFee).div(10000);
  }

  /**
   * @dev Update fee configuration
   * @param _mintFee The new minting fee, in bps
   * @param _burnFee The new burning fee, in bps
   * @param _feePayee The new payee
   */
  function setFees(uint256 _mintFee, uint256 _burnFee, address _feePayee) external onlyOwner {
    mintFee = _mintFee;
    burnFee = _burnFee;
    feePayee = _feePayee;
    emit FeesChanged(_mintFee, _burnFee, _feePayee);
  }
}
