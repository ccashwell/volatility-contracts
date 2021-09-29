// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

import "./SkinnyDAOracle.sol";
import "./pool/FundingPool.sol";

library DAOracleHelpers {
  using SafeERC20 for IERC20;

  function claimableRewards(SkinnyDAOracle.Feed storage feed)
    public
    view
    returns (
      uint256 total,
      uint256 poolAmount,
      uint256 reporterAmount,
      uint256 residualAmount,
      uint256 vestingTime
    )
  {
    // multiplier = distance between last proposal and current time (in seconds)
    uint256 multiplier = block.timestamp - feed.lastUpdated;

    // minimum multiplier = 1
    if (multiplier == 0) multiplier = 1;

    // reporter's share starts at floor and moves toward ceiling by tilt % per tick
    uint256 reporterShare = feed.floor + (feed.tilt * multiplier);
    if (reporterShare > feed.ceiling) reporterShare = feed.ceiling;

    total = feed.drop * multiplier;
    reporterAmount = (total * reporterShare) / 1e18;
    residualAmount = ((total - reporterAmount) * feed.tip) / 1e18;
    poolAmount = total - residualAmount - reporterAmount;
    vestingTime = 0;
  }

  function dispute(
    SkinnyDAOracle.Feed storage feed,
    SkinnyDAOracle.Proposal storage proposal,
    SkinnyOptimisticOracleInterface oracle,
    bytes32 externalIdentifier
  ) public {
    IERC20 token = feed.bondToken;

    // Pull in funds from backer to cover the proposal bond
    token.safeTransferFrom(feed.backer, address(this), feed.bondAmount);

    // Pull in funds from disputer to match the bond
    token.safeTransferFrom(msg.sender, address(this), feed.bondAmount);

    // Create the request + proposal via UMA's OO
    uint256 bond = oracle.requestAndProposePriceFor(
      externalIdentifier,
      proposal.timestamp,
      abi.encodePacked(proposal.data),
      token,
      0,
      feed.bondAmount,
      feed.ttl,
      address(this),
      proposal.value
    );

    // Build the OO request object for the above proposal
    SkinnyOptimisticOracleInterface.Request memory request;
    request.currency = token;
    request.finalFee = bond - feed.bondAmount;
    request.bond = bond - request.finalFee;
    request.proposer = address(this);
    request.proposedPrice = proposal.value;
    request.expirationTime = block.timestamp + feed.ttl;
    request.customLiveness = feed.ttl;

    // Initiate the dispute on disputer's behalf
    oracle.disputePriceFor(
      externalIdentifier,
      proposal.timestamp,
      abi.encodePacked(proposal.data),
      request,
      msg.sender,
      address(this)
    );

    // Keep track of the outstanding bond and dispute
    feed.bondsOutstanding += bond;
    feed.disputesOutstanding++;
  }

  function deployFundingPool(SkinnyDAOracle.Feed storage feed)
    public
    returns (FundingPool)
  {
    return new FundingPool(ERC20(address(feed.bondToken)));
  }
}
