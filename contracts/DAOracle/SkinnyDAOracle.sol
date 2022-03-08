// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;
pragma experimental ABIEncoderV2;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/cryptography/draft-EIP712.sol";
import "@openzeppelin/contracts/utils/cryptography/SignatureChecker.sol";

import "../vendor/uma/SkinnyOptimisticOracleInterface.sol";

import "./DAOracleHelpers.sol";
import "./vault/IVestingVault.sol";
import "./pool/DAOraclePool.sol";
import "./pool/FundingPool.sol";

/**
 * @title SkinnyDAOracle
 * @dev This contract is the core of the Volatility Protocol DAOracle System.
 * It is responsible for rewarding stakers and issuing staker-backed bonds
 * which act as a decentralized risk pool for DAOracle Feeds. Bonds and rewards
 * are authorized, issued and funded by the Volatility DAO for qualified oracle
 * proposals, and stakers provide insurance against lost bonds. In exchange for
 * backstopping risk, stakers receive rewards for the data assurances they help
 * provide. In cases where a proposal is disputed, the DAOracle leverages UMA's
 * Data Validation Mechanism (DVM) to arbitrate and resolve by determining the
 * correct value through a community-led governance vote.
 */
contract SkinnyDAOracle is AccessControl, EIP712 {
  using SafeERC20 for IERC20;
  using DAOracleHelpers for Feed;

  event Relayed(
    bytes32 indexed feedId,
    bytes32 indexed proposalId,
    Proposal proposal,
    address relayer,
    uint256 bondAmount
  );

  event Disputed(
    bytes32 indexed feedId,
    bytes32 indexed proposalId,
    address disputer
  );

  event Settled(
    bytes32 indexed feedId,
    bytes32 indexed proposalId,
    int256 proposedValue,
    int256 settledValue
  );

  event FeedConfigured(bytes32 indexed feedId, IERC20 bondToken);
  event Rewarded(address rewardee, IERC20 token, uint256 amount);

  /**
   * @dev Feeds are backed by bonds which are insured by stakers who receive
   * rewards for backstopping the risk of those bonds being slashed. The reward
   * token is the same as the bond token for simplicity. Whenever a bond is
   * resolved, any delta between the initial bond amount and tokens received is
   * "slashed" from the staking pool. A portion of rewards are distributed to
   * two groups: Stakers and Reporters. Every time targetFrequency elapses, the
   * weight shifts from Stakers to Reporters until it reaches the stakerFloor.
   */
  struct Feed {
    IERC20 bondToken; // The token to be used for bonds
    uint32 lastUpdated; // The timestamp of the last successful update
    uint256 bondAmount; // The quantity of tokens to be put up for each bond
    uint256 bondsOutstanding; // The total amount of tokens outstanding for bonds
    uint256 disputesOutstanding; // The total number of requests currently in dispute
    uint256 drop; // The reward token drip rate (in wei)
    uint64 floor; // The minimum reward weighting for reporters (in wei, 1e18 = 100%)
    uint64 ceiling; // The maximum reward weighting for reporters (in wei, 1e18 = 100%)
    uint64 tilt; // The rate of change per second from floor->ceiling (in wei, 1e18 = 100%)
    uint64 tip; // The percentage of the total reward payable to the methodologist
    uint32 ttl; // The dispute window for proposed values
    address hat; // The recipient of the methodologist rewards
    address backer; // The source of funding for the feed's bonds and rewards
  }

  /**
   * @dev Proposals are used to validate feed updates to be relayed to the UMA
   * OptimisticOracle. The ancillaryData field supports arbitrary byte arrays,
   * but we are compressing down to bytes32 which exceeds the capacity needed
   * for all currently known use cases.
   */
  struct Proposal {
    bytes32 feedId; // The feed identifier
    uint32 timestamp; // The timestamp of the value
    int256 value; // The proposed value
    bytes32 data; // Any other data needed to reproduce the proposed value
  }

  // UMA's SkinnyOptimisticOracle and registered identifier
  SkinnyOptimisticOracleInterface public immutable oracle;
  bytes32 public externalIdentifier;

  // Vesting Vault (for Rewards)
  IVestingVault public immutable vault;

  // Feeds and Proposals
  mapping(bytes32 => Feed) public feed;
  mapping(bytes32 => Proposal) public proposal;
  mapping(bytes32 => bool) public isDisputed;
  uint32 public defaultTtl = 10 minutes;
  uint32 public maxOutstandingDisputes = 3;

  // Staking Pools (bond insurance)
  mapping(IERC20 => DAOraclePool) public pool;

  // Roles (for AccessControl)
  bytes32 public constant ORACLE = keccak256("ORACLE");
  bytes32 public constant MANAGER = keccak256("MANAGER");
  bytes32 public constant PROPOSER = keccak256("PROPOSER");

  // Proposal type hash (for EIP-712 signature verification)
  bytes32 public constant PROPOSAL_TYPEHASH =
    keccak256(
      abi.encodePacked(
        "Proposal(bytes32 feedId,uint32 timestamp,int256 value,bytes32 data)"
      )
    );

  /**
   * @dev Ensures that a given EIP-712 signature matches the hashed proposal
   * and was issued by an authorized signer. Accepts signatures from both EOAs
   * and contracts that support the EIP-712 standard.
   * @param relayed a proposal that was provided by the caller
   * @param signature an EIP-712 signature (raw bytes)
   * @param signer the address that provided the signature
   */
  modifier onlySignedProposals(
    Proposal calldata relayed,
    bytes calldata signature,
    address signer
  ) {
    require(
      SignatureChecker.isValidSignatureNow(
        signer,
        _hashTypedDataV4(
          keccak256(
            abi.encode(
              PROPOSAL_TYPEHASH,
              relayed.feedId,
              relayed.timestamp,
              relayed.value,
              relayed.data
            )
          )
        ),
        signature
      ),
      "bad signature"
    );

    require(hasRole(PROPOSER, signer), "unauthorized signer");

    _;
  }

  constructor(
    bytes32 _ooIdentifier,
    SkinnyOptimisticOracleInterface _optimisticOracle,
    IVestingVault _vault
  ) EIP712("DAOracle", "1") {
    _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
    _setupRole(PROPOSER, msg.sender);
    _setupRole(MANAGER, msg.sender);
    _setupRole(ORACLE, address(_optimisticOracle));

    externalIdentifier = _ooIdentifier;
    oracle = _optimisticOracle;
    vault = _vault;
  }

  /**
   * @dev Returns the currently claimable rewards for a given feed.
   * @param feedId The feed identifier
   * @return total The total reward token amount
   * @return poolAmount The pool's share of the rewards
   * @return reporterAmount The reporter's share of the rewards
   * @return residualAmount The methodologist's share of the rewards
   * @return vestingTime The amount of time the reporter's rewards must vest (in seconds)
   */
  function claimableRewards(bytes32 feedId)
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
    return feed[feedId].claimableRewards();
  }

  /**
   * @dev Relay a feed update that has been signed by an authorized proposer.
   * The signature provided must satisfy two criteria:
   * (1) the signature must be a valid EIP-712 signature for the proposal; and
   * (2) the signer must have the "PROPOSER" role.
   * @notice See https://docs.ethers.io/v5/api/signer/#Signer-signTypedData
   * @param relayed The relayed proposal
   * @param signature An EIP-712 signature for the proposal
   * @param signer The address of the EIP-712 signature provider
   * @return bond The bond amount claimable via successful dispute
   * @return proposalId The unique ID of the proposal
   * @return expiresAt The time at which the proposal is no longer disputable
   */
  function relay(
    Proposal calldata relayed,
    bytes calldata signature,
    address signer
  )
    external
    onlySignedProposals(relayed, signature, signer)
    returns (
      uint256 bond,
      bytes32 proposalId,
      uint32 expiresAt
    )
  {
    proposalId = _proposalId(relayed.timestamp, relayed.value, relayed.data);
    require(proposal[proposalId].timestamp == 0, "duplicate proposal");

    Feed storage _feed = feed[relayed.feedId];
    require(
      _feed.disputesOutstanding < maxOutstandingDisputes,
      "feed ineligible for proposals"
    );
    require(
      _feed.lastUpdated < relayed.timestamp,
      "must be later than most recent proposal"
    );

    bond = _feed.bondAmount;
    expiresAt = uint32(block.timestamp) + _feed.ttl;

    proposal[proposalId] = relayed;
    _feed.lastUpdated = relayed.timestamp;

    _issueRewards(relayed.feedId, msg.sender);
    emit Relayed(relayed.feedId, proposalId, relayed, msg.sender, bond);
  }

  /**
   * @dev Disputes a proposal prior to its expiration. This causes a bond to be
   * posted on behalf of DAOracle stakers and an equal amount to be pulled from
   * the caller.
   * @notice This actually requests, proposes, and disputes with UMA's SkinnyOO
   * which sends the bonds and disputed proposal to UMA's DVM for settlement by
   * way of governance vote. Voters follow the specification of the DAOracle's
   * approved UMIP to determine the correct value. Once the outcome is decided,
   * the SkinnyOO will callback to this contract's `priceSettled` function.
   * @param proposalId the identifier of the proposal being disputed
   */
  function dispute(bytes32 proposalId) external {
    Proposal storage _proposal = proposal[proposalId];
    Feed storage _feed = feed[_proposal.feedId];

    require(proposal[proposalId].timestamp != 0, "proposal doesn't exist");
    require(
      !isDisputed[proposalId] &&
        block.timestamp < proposal[proposalId].timestamp + _feed.ttl,
      "proposal already disputed or expired"
    );
    isDisputed[proposalId] = true;

    _feed.dispute(_proposal, oracle, externalIdentifier);
    emit Disputed(_proposal.feedId, proposalId, msg.sender);
  }

  /**
   * @dev External callback for UMA's SkinnyOptimisticOracle. Fired whenever a
   * disputed proposal has been settled by the DVM, regardless of outcome.
   * @notice This is always called by the UMA SkinnyOO contract, not an EOA.
   * @param - identifier, ignored
   * @param timestamp The timestamp of the proposal
   * @param ancillaryData The data field from the proposal
   * @param request The entire SkinnyOptimisticOracle Request object
   */
  function priceSettled(
    bytes32, /** identifier */
    uint32 timestamp,
    bytes calldata ancillaryData,
    SkinnyOptimisticOracleInterface.Request calldata request
  ) external onlyRole(ORACLE) {
    bytes32 id = _proposalId(
      timestamp,
      request.proposedPrice,
      bytes32(ancillaryData)
    );
    Proposal storage relayed = proposal[id];
    Feed storage _feed = feed[relayed.feedId];

    _feed.bondsOutstanding -= request.bond;
    _feed.disputesOutstanding--;
    isDisputed[id] = false;

    if (relayed.value != request.resolvedPrice) {
      // failed proposal, slash pool to recoup lost bond
      pool[request.currency].slash(_feed.bondAmount, address(this));
    } else {
      // successful proposal, return bond to backer
      request.currency.safeTransfer(_feed.backer, request.bond);

      // sends the rest of the funds received to the staking pool
      request.currency.safeTransfer(
        address(pool[request.currency]),
        request.currency.balanceOf(address(this))
      );
    }

    emit Settled(relayed.feedId, id, relayed.value, request.resolvedPrice);
  }

  /**
   * @dev Adds or updates a feed. Can only be called by managers.
   * @param bondToken The token to be used for bonds
   * @param bondAmount The quantity of tokens to offer for bonds
   * @param feedId The price feed identifier
   * @param ttl The proposal dispute window
   * @param floor The starting portion of rewards payable to reporters
   * @param ceiling The maximum portion of rewards payable to reporters
   * @param tilt The rate of change from floor to ceiling per second
   * @param drop The number of reward tokens to drip (per second)
   * @param tip The portion of rewards payable to the methodologist
   * @param hat The recipient of the methodologist's rewards
   * @param backer The provider of funding for bonds and rewards
   */
  function configureFeed(
    IERC20 bondToken,
    uint256 bondAmount,
    bytes32 feedId,
    uint32 ttl,
    uint64 floor,
    uint64 ceiling,
    uint64 tilt,
    uint256 drop,
    uint64 tip,
    address hat,
    address backer
  ) external onlyRole(MANAGER) {
    Feed storage _feed = feed[feedId];

    _feed.bondToken = bondToken;
    _feed.bondAmount = bondAmount;
    _feed.lastUpdated = _feed.lastUpdated == 0
      ? uint32(block.timestamp)
      : _feed.lastUpdated;

    _feed.drop = drop;
    _feed.ceiling = ceiling;
    _feed.tilt = tilt;
    _feed.floor = floor;
    _feed.tip = tip;
    _feed.hat = hat;
    _feed.ttl = ttl == 0 ? defaultTtl : ttl;
    _feed.backer = backer == address(0)
      ? address(_feed.deployFundingPool())
      : backer;

    if (address(pool[bondToken]) == address(0)) {
      _createPool(_feed);
    }

    emit FeedConfigured(feedId, bondToken);
  }

  /**
   * @dev Update the global default TTL. Can only be called by managers.
   * @param ttl The new ttl, in seconds
   */
  function setDefaultTtl(uint32 ttl) external onlyRole(MANAGER) {
    defaultTtl = ttl;
  }

  function setExternalIdentifier(bytes32 identifier)
    external
    onlyRole(MANAGER)
  {
    externalIdentifier = identifier;
  }

  /**
   * @dev Update the global default maxOutstandingDisputes. Can only be called by managers.
   * @param outstandingDisputes The new maxOutstandingDisputes
   */
  function setMaxOutstandingDisputes(uint32 outstandingDisputes)
    external
    onlyRole(MANAGER)
  {
    maxOutstandingDisputes = outstandingDisputes;
  }

  /**
   * @dev Update the fees for a token's staking pool. Can only be called by managers.
   * @notice Fees must be scaled by 10**18 (1e18 = 100%). Example: 1000 DAI deposit * (0.1 * 10**18) = 100 DAI fee
   * @param mintFee the tax applied to new deposits
   * @param burnFee the tax applied to withdrawals
   * @param payee the recipient of fees
   */
  function setPoolFees(
    IERC20 token,
    uint256 mintFee,
    uint256 burnFee,
    address payee
  ) external onlyRole(MANAGER) {
    pool[token].setFees(mintFee, burnFee, payee);
  }

  function _proposalId(
    uint32 timestamp,
    int256 value,
    bytes32 data
  ) public pure returns (bytes32) {
    return keccak256(abi.encodePacked(timestamp, value, data));
  }

  function _createPool(Feed storage _feed) internal returns (DAOraclePool) {
    pool[_feed.bondToken] = new DAOraclePool(
      ERC20(address(_feed.bondToken)),
      0,
      0,
      address(this)
    );

    _feed.bondToken.safeApprove(address(vault), 2**256 - 1);
    _feed.bondToken.safeApprove(address(oracle), 2**256 - 1);

    return pool[_feed.bondToken];
  }

  function _issueRewards(bytes32 feedId, address reporter) internal {
    Feed storage _feed = feed[feedId];

    (
      uint256 total,
      uint256 poolAmount,
      uint256 reporterAmount,
      uint256 residualAmount,
      uint256 vestingTime
    ) = _feed.claimableRewards();

    // Pull in reward money from the backer
    _feed.bondToken.safeTransferFrom(_feed.backer, address(this), total);

    // Push rewards to pool and methodologist
    _feed.bondToken.safeTransfer(address(pool[_feed.bondToken]), poolAmount);
    _feed.bondToken.safeTransfer(_feed.hat, residualAmount);

    // Push relayer's reward to the vault for vesting
    vault.issue(
      reporter,
      _feed.bondToken,
      reporterAmount,
      block.timestamp,
      0,
      vestingTime
    );

    emit Rewarded(reporter, _feed.bondToken, reporterAmount);
  }
}
