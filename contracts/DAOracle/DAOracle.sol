// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.7;

// External dependencies (via OpenZeppelin)
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

// Internal dependencies
import "./DAOraclePool.sol";
import "../interfaces/IVestingVault.sol";

/**
 * @title DAOracle
 * @dev This contract is the core of the Volatility Protocol DAOracle System.
 * It is responsible for rewarding stakers and issues bonds using staked tokens
 * which act as a decentralized risk pool. Bonds are issued against qualified
 * oracle proposals. These proposal bonds are funded by the DAOracle and
 * stakers provide insurance against lost bonds through the risk pool. Stakers
 * receive rewards for the data assurances they help provide. 
 */
contract DAOracle is AccessControl {
  using SafeMath for uint256;
  using EnumerableSet for EnumerableSet.Bytes32Set;

  bytes32 public constant MANAGER = keccak256("MANAGER");

  event Created(address poolAddress, address underlying);

  // Feeds are backed by bonds which are insured by stakers who receive rewards
  // for backstopping the risk of those bonds being slashed. The reward token
  // is the same as the bond token for simplicity. Whenever a bond is resolved,
  // any delta between the initial bond amount and tokens received is "slashed"
  // from the staking pool. A portion of rewards are distributed to each of two
  // buckets: Stakers and Reporters. Every time targetFrequency elapses, the
  // weight shifts from Stakers to Reporters until it reaches the stakerFloor.
  //
  // Example:
  // Assuming targetFrequency = 10, rCeiling = 100, rFloor = 33 and changePerBlock = 1,
  // rewards start at 67%/33% and shift by 1% every 10th block until reaching 0%/100%.
  struct Feed {
    IERC20 bondToken;         // The token to be used for bonds
    bytes32 identifier;       // The price feed identifier known to the Optimistic Oracle
    uint256 lastUpdated;      // The block number of the last successful update
    uint256 targetFrequency;  // The target update frequency (in blocks)
    uint256 dripPerBlock;     // The reward token drip rate (in base units)
    uint256 rFloor;           // The minimum reward weighting for reporters (in bps)
    uint256 rCeiling;         // The maximum reward weighting for reporters (in bps)
    uint256 changePerBlock;   // The rate of change per block from rFloor->rCeiling
  }
  mapping(bytes32 => Feed) public feedFor;
  EnumerableSet.Bytes32Set private supportedFeeds;

  // Staking pools
  uint256 public poolCount;
  mapping(IERC20 => DAOraclePool) public poolFor;

  // Rewards payout vault
  IVestingVault public vestingVault;

  // Reward funding addresses (expected to have approval for `transferFrom`)
  mapping(IERC20 => address) public rewardFunder;

  // Bond funding addresses (expected to have approval for `transferFrom`)
  mapping(IERC20 => address) public bondFunder;

  constructor(IVestingVault _vestingVault) {
    _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
    _setupRole(MANAGER, msg.sender);
    _setupRole(MANAGER, address(this));

    vestingVault = _vestingVault;
  }

  function feedCount() public view returns (uint256 count) {
    count = supportedFeeds.length();
  }

  function isFeedSupported(bytes32 _identifier) public view returns (bool supported) {
    supported = supportedFeeds.contains(_identifier);
  }

  function getFeed(bytes32 _identifier) public view returns (Feed memory feed) {
    return feedFor[_identifier];
  }

  // Administrative Functionality

  function createFeed(
    IERC20 _bondToken,
    bytes32 _identifier,
    uint256 _targetFrequency,
    uint256 _dripPerBlock,
    uint256 _rFloor,
    uint256 _rCeiling,
    uint256 _rChange
  ) public onlyRole(MANAGER) {
    require(supportedFeeds.add(_identifier), "createFeed: identifier already registered");

    feedFor[_identifier] = Feed({
      bondToken: _bondToken,
      identifier: _identifier,
      lastUpdated: block.number,
      targetFrequency: _targetFrequency,
      dripPerBlock: _dripPerBlock,
      rFloor: _rFloor,
      rCeiling: _rCeiling,
      changePerBlock: _rChange
    });

    if (address(poolFor[_bondToken]) == address(0)) {
      _createPool(_bondToken);
    }
  }

  /**
	 * @dev Adds a new staking pool. Can only be called by managers.
	 * @param _underlying The token to be staked.
   * @return deployed The pool's deployed address
	 */
	function createPool(
		IERC20 _underlying
	) public onlyRole(MANAGER) returns (address deployed) {
    deployed = _createPool(_underlying);
  }

  function _createPool(
    IERC20 _underlying
  ) internal returns (address deployed) {
    require(
      address(poolFor[_underlying]) == address(0),
      "createPool: pool for underlying already exists"
    );

    poolFor[_underlying] = new DAOraclePool(_underlying, 0, 0, address(this));
    poolCount++;

    emit Created(
      deployed = address(poolFor[_underlying]),
      address(_underlying)
    );
  }
}