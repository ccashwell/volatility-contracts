// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "./VestingMultiVault.sol";
import "./interfaces/IVestingVault.sol";
import "hardhat/console.sol";

/**
 * @title StakeRewarderV2
 * @dev This contract distributes rewards to depositors of supported tokens.
 * It's based on Sushi's MasterChef v1, but notably only serves what's already
 * available: no new tokens can be created. It's just a restaurant, not a farm.
 */
contract StakeRewarderV2 is Ownable, AccessControl, IVestingVault {
	using SafeMath for uint256;
	using SafeERC20 for IERC20;

	struct UserInfo {
		uint256 amount; // Quantity of tokens the user has staked.
		uint256 rewardDebt; // Reward debt. See explanation below.
		// We do some fancy math here. Basically, any point in time, the
		// amount of rewards entitled to a user but is pending to be distributed is:
		//
		//   pendingReward = (stakedAmount * pool.accPerShare) - user.rewardDebt
		//
		// Whenever a user deposits or withdraws tokens in a pool:
		//   1. The pool's `accPerShare` (and `lastRewardBlock`) gets updated.
		//   2. User's pending rewards are issued (greatly simplifies accounting).
		//   3. User's `amount` gets updated.
		//   4. User's `rewardDebt` gets updated.
	}

	struct PoolInfo {
		IERC20 token; // Address of the token contract.
		uint256 weight; // Weight points assigned to this pool.
		uint256 power; // The multiplier for determining "staking power".
		uint256 total; // Total number of tokens staked.
		uint256 accPerShare; // Accumulated rewards per share (times 1e12).
		uint256 lastRewardBlock; // Last block where rewards were calculated.
	}

	// Reward configuration.
	IERC20 public immutable rewardToken;
	uint256 public rewardPerBlock;
	uint256 public vestingCliff;
	uint256 public vestingDuration;

	// Housekeeping for each pool.
	PoolInfo[] public poolInfo;

	// Info of each user that stakes tokens.
	mapping(uint256 => mapping(address => UserInfo)) public userInfo;

	// Underpaid rewards owed to a user.
	mapping(address => uint256) public underpayment;

	// The sum of weights across all staking tokens.
	uint256 public totalWeight = 0;

	// The block number when staking starts.
	uint256 public startBlock;

	// The amount unclaimed for an address, whether or not vested.
	mapping(address => uint256) public totalUserVestedAmount;

	// The allocations assigned to an address.
	mapping(address => Allocation[]) public userAllocations;

	// The precomputed hash of the "ISSUER" role.
	bytes32 public constant ISSUER = keccak256("ISSUER");

	event TokenAdded(
		address indexed token,
		uint256 weight,
		uint256 totalWeight
	);
	event Deposit(address indexed user, uint256 indexed pid, uint256 amount);
	event Withdraw(address indexed user, uint256 indexed pid, uint256 amount);
	event Claim(address indexed user, uint256 amount);
	event EmergencyReclaim(address indexed user, address token, uint256 amount);
	event EmergencyWithdraw(
		address indexed user,
		uint256 indexed pid,
		uint256 amount
	);

	/**
	 * @dev Create a staking contract that rewards depositors using its own token balance
	 * and optionally vests rewards over time.
	 * @param _rewardToken The token to be distributed as rewards.
	 * @param _rewardPerBlock The quantity of reward tokens accrued per block.
	 * @param _startBlock The first block at which staking is allowed.
	 * @param _vestingCliff The number of seconds until issued rewards begin vesting.
	 * @param _vestingDuration The number of seconds after issuance until vesting is completed.
	 */
	constructor(
		IERC20 _rewardToken,
		uint256 _rewardPerBlock,
		uint256 _startBlock,
		uint256 _vestingCliff,
		uint256 _vestingDuration
	) {
		// Set the initial reward config
		rewardPerBlock = _rewardPerBlock;
		startBlock = _startBlock;
		vestingCliff = _vestingCliff;
		vestingDuration = _vestingDuration;

		rewardToken = _rewardToken;

		// Approve the vault to pull reward tokens
		_rewardToken.approve(address(this), 2**256 - 1);

		_setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
		_setupRole(ISSUER, msg.sender);
	}

	/**
	 * @dev Adds a new staking pool to the stack. Can only be called by the owner.
	 * @param _token The token to be staked.
	 * @param _weight The weight of this pool (used to determine proportion of rewards relative to the total weight).
	 * @param _power The power factor of this pool (used as a multiple of tokens staked, e.g. for determining voting power).
	 * @param _shouldUpdate Whether to update all pools first.
	 */
	function createPool(
		IERC20 _token,
		uint256 _weight,
		uint256 _power,
		bool _shouldUpdate
	) public onlyOwner {
		if (_shouldUpdate) {
			pokePools();
		}

		uint256 lastRewardBlock = block.number > startBlock
			? block.number
			: startBlock;
		totalWeight = totalWeight.add(_weight);
		poolInfo.push(
			PoolInfo({
				token: _token,
				weight: _weight,
				power: _power,
				total: 0,
				accPerShare: 0,
				lastRewardBlock: lastRewardBlock
			})
		);
	}

	/**
	 * @dev Update the given staking pool's weight and power. Can only be called by the owner.
	 * @param _pid The pool identifier.
	 * @param _weight The weight of this pool (used to determine proportion of rewards relative to the total weight).
	 * @param _power The power of this pool's token (used as a multiplier of tokens staked, e.g. for voting).
	 * @param _shouldUpdate Whether to update all pools first.
	 */
	function updatePool(
		uint256 _pid,
		uint256 _weight,
		uint256 _power,
		bool _shouldUpdate
	) public onlyOwner {
		if (_shouldUpdate) {
			pokePools();
		}

		totalWeight = totalWeight.sub(poolInfo[_pid].weight).add(_weight);

		poolInfo[_pid].weight = _weight;
		poolInfo[_pid].power = _power;
	}

	/**
	 * @dev Update the reward per block. Can only be called by the owner.
	 * @param _rewardPerBlock The total quantity to distribute per block.
	 */
	function setRewardPerBlock(uint256 _rewardPerBlock) public onlyOwner {
		rewardPerBlock = _rewardPerBlock;
	}

	/**
	 * @dev Update the vesting rules for rewards. Can only be called by the owner.
	 * @param _duration the number of seconds over which vesting occurs (see VestingMultiVault)
	 * @param _cliff the number of seconds before any release occurs (see VestingMultiVault)
	 */
	function setVestingRules(uint256 _duration, uint256 _cliff)
		public
		onlyOwner
	{
		vestingDuration = _duration;
		vestingCliff = _cliff;
	}

	/**
	 * @dev Calculate elapsed blocks between `_from` and `_to`.
	 * @param _from The starting block.
	 * @param _to The ending block.
	 */
	function duration(uint256 _from, uint256 _to)
		public
		pure
		returns (uint256)
	{
		return _to.sub(_from);
	}

	function totalPendingRewards(address _beneficiary)
		public
		view
		returns (uint256 total)
	{
		for (uint256 pid = 0; pid < poolInfo.length; pid++) {
			total = total.add(pendingRewards(pid, _beneficiary));
		}

		return total;
	}

	/**
	 * @dev View function to see total locked amount for an address.
	 * @param _pid The pool identifier.
	 * @param _beneficiary The address to check.
	 */
	function totalLocked(uint256 _pid, address _beneficiary)
		external
		view
		returns (uint256 total)
	{
		UserInfo memory user = userInfo[_pid][_beneficiary];
		return user.amount.add(totalUserVestedAmount[_beneficiary]);
	}

	/**
	 * @dev View function to see pending rewards for an address. Likely gas intensive.
	 * @param _pid The pool identifier.
	 * @param _beneficiary The address to check.
	 */
	function pendingRewards(uint256 _pid, address _beneficiary)
		public
		view
		returns (uint256 amount)
	{
		PoolInfo storage pool = poolInfo[_pid];
		UserInfo storage user = userInfo[_pid][_beneficiary];
		uint256 accPerShare = pool.accPerShare;
		uint256 tokenSupply = pool.total;

		if (block.number > pool.lastRewardBlock && tokenSupply != 0) {
			uint256 reward = duration(pool.lastRewardBlock, block.number)
				.mul(rewardPerBlock)
				.mul(pool.weight)
				.div(totalWeight);

			accPerShare = accPerShare.add(reward.mul(1e12).div(tokenSupply));
		}

		return
			user
				.amount
				.add(totalUserVestedAmount[_beneficiary])
				.mul(accPerShare)
				.div(1e12)
				.sub(user.rewardDebt);
	}

	/**
	 * @dev Gets the sum of power for every pool. Likely gas intensive.
	 * @param _beneficiary The address to check.
	 */
	function totalPower(address _beneficiary)
		public
		view
		returns (uint256 total)
	{
		for (uint256 pid = 0; pid < poolInfo.length; pid++) {
			total = total.add(power(pid, _beneficiary));
		}

		return total;
	}

	/**
	 * @dev Gets power for a single pool.
	 * @param _pid The pool identifier.
	 * @param _beneficiary The address to check.
	 */
	function power(uint256 _pid, address _beneficiary)
		public
		view
		returns (uint256 amount)
	{
		PoolInfo storage pool = poolInfo[_pid];
		UserInfo storage user = userInfo[_pid][_beneficiary];
		return
			pool.power.mul(
				user.amount.add(totalUserVestedAmount[_beneficiary])
			);
	}

	/**
	 * @dev Update all pools. Callable by anyone. Could be gas intensive.
	 */
	function pokePools() public {
		uint256 length = poolInfo.length;
		for (uint256 pid = 0; pid < length; ++pid) {
			pokePool(pid);
		}
	}

	/**
	 * @dev Update rewards of the given pool to be up-to-date. Callable by anyone.
	 * @param _pid The pool identifier.
	 */
	function pokePool(uint256 _pid) public {
		PoolInfo storage pool = poolInfo[_pid];

		if (block.number <= pool.lastRewardBlock) {
			return;
		}

		uint256 tokenSupply = pool.total;
		if (tokenSupply == 0) {
			pool.lastRewardBlock = block.number;
			return;
		}

		uint256 reward = duration(pool.lastRewardBlock, block.number)
			.mul(rewardPerBlock)
			.mul(pool.weight)
			.div(totalWeight);

		pool.accPerShare = pool.accPerShare.add(
			reward.mul(1e12).div(tokenSupply)
		);

		pool.lastRewardBlock = block.number;
	}

	/**
	 * @dev Claim rewards not yet distributed for an address. Callable by anyone.
	 * @param _pid The pool identifier.
	 * @param _beneficiary The address to claim for.
	 */
	function claim(uint256 _pid, address _beneficiary) public {
		// make sure the pool is up-to-date
		pokePool(_pid);

		PoolInfo storage pool = poolInfo[_pid];
		UserInfo storage user = userInfo[_pid][_beneficiary];

		// claim the rewards
		_claim(pool, user, _beneficiary);

		// update the user reward info
		user.rewardDebt = user.amount.mul(pool.accPerShare).div(1e12);
	}

	/**
	 * @dev Claim rewards from multiple pools. Callable by anyone.
	 * @param _pids An array of pool identifiers.
	 * @param _beneficiary The address to claim for.
	 */
	function claimMultiple(uint256[] calldata _pids, address _beneficiary)
		external
	{
		for (uint256 i = 0; i < _pids.length; i++) {
			claim(_pids[i], _beneficiary);
		}
	}

	/**
	 * @dev Stake tokens to earn a share of rewards.
	 * @param _pid The pool identifier.
	 * @param _amount The number of tokens to deposit.
	 */
	function deposit(uint256 _pid, uint256 _amount) public {
		require(_amount > 0, "deposit: only non-zero amounts allowed");

		// make sure the pool is up-to-date
		pokePool(_pid);

		PoolInfo storage pool = poolInfo[_pid];
		UserInfo storage user = userInfo[_pid][msg.sender];

		// deliver any pending rewards
		_claim(pool, user, msg.sender);

		// pull in user's staked assets
		pool.token.safeTransferFrom(
			address(msg.sender),
			address(this),
			_amount
		);

		// update the pool's total deposit
		pool.total = pool.total.add(_amount);

		// update user's deposit and reward info
		user.amount = user.amount.add(_amount);
		user.rewardDebt = user.amount.mul(pool.accPerShare).div(1e12);

		emit Deposit(msg.sender, _pid, _amount);
	}

	/**
	 * @dev Withdraw staked tokens and any pending rewards.
	 */
	function withdraw(uint256 _pid, uint256 _amount) public {
		require(_amount > 0, "withdraw: only non-zero amounts allowed");

		// make sure the pool is up-to-date
		pokePool(_pid);

		PoolInfo storage pool = poolInfo[_pid];
		UserInfo storage user = userInfo[_pid][msg.sender];

		require(user.amount >= _amount, "withdraw: amount too large");

		// deliver any pending rewards
		_claim(pool, user, msg.sender);

		// update the pool's total deposit
		pool.total = pool.total.sub(_amount);

		// update the user's deposit and reward info
		user.amount = user.amount.sub(_amount);
		user.rewardDebt = user.amount.mul(pool.accPerShare).div(1e12);

		// send back the staked assets
		pool.token.safeTransfer(address(msg.sender), _amount);

		emit Withdraw(msg.sender, _pid, _amount);
	}

	/**
	 * @dev Withdraw staked tokens and forego any unclaimed rewards. This is a fail-safe.
	 */
	function emergencyWithdraw(uint256 _pid) public {
		PoolInfo storage pool = poolInfo[_pid];
		UserInfo storage user = userInfo[_pid][msg.sender];
		uint256 amount = user.amount;

		// reset everything to zero
		user.amount = 0;
		user.rewardDebt = 0;
		underpayment[msg.sender] = 0;

		// update the pool's total deposit
		pool.total = pool.total.sub(amount);

		// send back the staked assets
		pool.token.safeTransfer(address(msg.sender), amount);
		emit EmergencyWithdraw(msg.sender, _pid, amount);
	}

	/**
	 * @dev Reclaim stuck tokens (e.g. unexpected external rewards). This is a fail-safe.
	 */
	function emergencyReclaim(IERC20 _token, uint256 _amount) public onlyOwner {
		if (_amount == 0) {
			_amount = _token.balanceOf(address(this));
		}

		_token.transfer(msg.sender, _amount);
		emit EmergencyReclaim(msg.sender, address(_token), _amount);
	}

	/**
	 * @dev Gets the length of the pools array.
	 */
	function poolLength() external view returns (uint256 length) {
		return poolInfo.length;
	}

	/**
	 * @dev Claim rewards not yet distributed for an address.
	 * @param pool The staking pool issuing rewards.
	 * @param user The staker who earned them.
	 * @param to The address to pay.
	 */
	function _claim(
		PoolInfo storage pool,
		UserInfo storage user,
		address to
	) internal {
		if (user.amount > 0) {
			// calculate the pending reward
			uint256 pending = user
				.amount
				.add(totalUserVestedAmount[to])
				.mul(pool.accPerShare)
				.div(1e12)
				.sub(user.rewardDebt)
				.add(underpayment[to]);

			// send the rewards out
			uint256 payout = _safelyDistribute(to, pending);
			if (payout < pending) {
				underpayment[to] = pending.sub(payout);
			} else {
				underpayment[to] = 0;
			}

			emit Claim(to, payout);
		}
	}

	/**
	 * @dev Safely distribute at most the amount of tokens in holding.
	 */
	function _safelyDistribute(address _to, uint256 _amount)
		internal
		returns (uint256 amount)
	{
		uint256 available = rewardToken.balanceOf(address(this));
		amount = _amount > available ? available : _amount;

		_issue(
			_to, // address _beneficiary,
			_amount, // uint256 _amount,
			block.timestamp, // uint256 _startAt,
			vestingCliff, // uint256 _cliff,
			vestingDuration, // uint256 _duration,
			0, // uint256 _initialPct
			address(this)
		);

		return amount;
	}

	/**
	 * @dev Creates a new allocation for a beneficiary. Tokens are released
	 * linearly over time until a given number of seconds have passed since the
	 * start of the vesting schedule. Callable only by issuers.
	 * @param _beneficiary The address to which tokens will be released
	 * @param _amount The amount of the allocation (in wei)
	 * @param _startAt The unix timestamp at which the vesting may begin
	 * @param _cliff The number of seconds after _startAt before which no vesting occurs
	 * @param _duration The number of seconds after which the entire allocation is vested
	 * @param _initialPct The percentage of the allocation initially available (integer, 0-100)
	 */
	function issue(
		address _beneficiary,
		uint256 _amount,
		uint256 _startAt,
		uint256 _cliff,
		uint256 _duration,
		uint256 _initialPct
	) external override onlyRole(ISSUER) {
		_issue(
			_beneficiary,
			_amount,
			_startAt,
			_cliff,
			_duration,
			_initialPct,
			msg.sender
		);
	}

	/**
	 * @dev Creates a batch allocation. Tokens are released
	 * linearly over time until a given number of seconds have passed since the
	 * start of the vesting schedule. Callable only by issuers.
	 * @param _beneficiary The address array to which tokens will be released
	 * @param _amount The amount array of the allocation (in wei)
	 * @param _startAt The unix timestamp array at which the vesting may begin
	 * @param _cliff The number of seconds array after _startAt before which no vesting occurs
	 * @param _duration The number of seconds array after which the entire allocation is vested
	 * @param _initialPct The percentage of the allocation array initially available (integer, 0-100)
	 */
	function batchIssue(
		address[] memory _beneficiary,
		uint256[] memory _amount,
		uint256[] memory _startAt,
		uint256[] memory _cliff,
		uint256[] memory _duration,
		uint256[] memory _initialPct
	) external onlyRole(ISSUER) {
		for (uint256 i = 0; i < _beneficiary.length; i++) {
			_issue(
				_beneficiary[i],
				_amount[i],
				_startAt[i],
				_cliff[i],
				_duration[i],
				_initialPct[i],
				msg.sender
			);
		}
	}

	/**
	 * @dev Creates a new allocation for a beneficiary. Tokens are released
	 * linearly over time until a given number of seconds have passed since the
	 * start of the vesting schedule. Callable only by issuers.
	 * @param _beneficiary The address to which tokens will be released
	 * @param _amount The amount of the allocation (in wei)
	 * @param _startAt The unix timestamp at which the vesting may begin
	 * @param _cliff The number of seconds after _startAt before which no vesting occurs
	 * @param _duration The number of seconds after which the entire allocation is vested
	 * @param _initialPct The percentage of the allocation initially available (integer, 0-100)
	 */
	function _issue(
		address _beneficiary,
		uint256 _amount,
		uint256 _startAt,
		uint256 _cliff,
		uint256 _duration,
		uint256 _initialPct,
		address _from
	) internal {
		require(
			rewardToken.allowance(_from, address(this)) >= _amount,
			"Token allowance not sufficient"
		);
		require(
			_beneficiary != address(0),
			"Cannot grant tokens to the zero address"
		);
		require(_cliff <= _duration, "Cliff must not exceed duration");
		require(
			_initialPct <= 100,
			"Initial release percentage must be an integer 0 to 100 (inclusive)"
		);

		// Pull the number of tokens required for the allocation.
		rewardToken.safeTransferFrom(_from, address(this), _amount);

		// Increase the total pending for the address.
		totalUserVestedAmount[_beneficiary] = totalUserVestedAmount[
			_beneficiary
		].add(_amount);

		// Push the new allocation into the stack.
		userAllocations[_beneficiary].push(
			Allocation({
				claimed: 0,
				cliff: _cliff,
				duration: _duration,
				initial: _amount.mul(_initialPct).div(100),
				start: _startAt,
				total: _amount
			})
		);

		emit Issued(
			_beneficiary,
			userAllocations[_beneficiary].length - 1,
			_amount,
			_startAt,
			_cliff,
			_duration
		);
	}

	/**
	 * @dev Revokes an existing allocation. Any unclaimed tokens are recalled
	 * and sent to the caller. Callable only be issuers.
	 * @param _beneficiary The address whose allocation is to be revoked
	 * @param _id The allocation ID to revoke
	 */
	function revoke(address _beneficiary, uint256 _id)
		external
		override
		onlyRole(ISSUER)
	{
		_revoke(_beneficiary, _id);
	}

	/**
	 * @dev Revokes an existing allocation. Any unclaimed tokens are recalled
	 * and sent to the caller. Callable only be issuers.
	 * @param _beneficiary The address whose allocation is to be revoked
	 * @param _id The allocation ID to revoke
	 */
	function _revoke(address _beneficiary, uint256 _id) internal {
		Allocation storage allocation = userAllocations[_beneficiary][_id];

		// Calculate the remaining amount.
		uint256 total = allocation.total;
		uint256 remainder = total.sub(allocation.claimed);

		// Update the total pending for the address.
		totalUserVestedAmount[_beneficiary] = totalUserVestedAmount[
			_beneficiary
		].sub(remainder);

		// Update the allocation to be claimed in full.
		allocation.claimed = total;

		// Transfer the tokens vested
		rewardToken.safeTransfer(msg.sender, remainder);
		emit Revoked(_beneficiary, _id, total, remainder);
	}

	/**
	 * @dev Transfers vested tokens from an allocation to its beneficiary. Callable by anyone.
	 * @param _beneficiary The address that has vested tokens
	 * @param _id The vested allocation index
	 */
	function release(address _beneficiary, uint256 _id) public {
		Allocation storage allocation = userAllocations[_beneficiary][_id];

		// Calculate the releasable amount.
		uint256 amount = _releasableAmount(allocation);
		require(amount > 0, "Nothing to release");

		// Add the amount to the allocation's total claimed.
		allocation.claimed = allocation.claimed.add(amount);

		// Subtract the amount from the beneficiary's total pending.
		totalUserVestedAmount[_beneficiary] = totalUserVestedAmount[
			_beneficiary
		].sub(amount);

		// Transfer the tokens to the beneficiary.
		rewardToken.safeTransfer(_beneficiary, amount);

		emit Released(
			_beneficiary,
			_id,
			amount,
			allocation.total.sub(allocation.claimed)
		);
	}

	/**
	 * @dev Transfers vested tokens from any number of allocations to their beneficiary. Callable by anyone. May be gas-intensive.
	 * @param _beneficiary The address that has vested tokens
	 * @param _ids The vested allocation indexes
	 */
	function releaseMultiple(address _beneficiary, uint256[] calldata _ids)
		external
		override
	{
		for (uint256 i = 0; i < _ids.length; i++) {
			release(_beneficiary, _ids[i]);
		}
	}

	/**
	 * @dev Gets the number of allocations issued for a given address.
	 * @param _beneficiary The address to check for allocations
	 */
	function allocationCount(address _beneficiary)
		public
		view
		returns (uint256 count)
	{
		return userAllocations[_beneficiary].length;
	}

	/**
	 * @dev Calculates the amount that has already vested but has not yet been released for a given address.
	 * @param _beneficiary Address to check
	 * @param _id The allocation index
	 */
	function releasableAmount(address _beneficiary, uint256 _id)
		public
		view
		returns (uint256 amount)
	{
		Allocation memory allocation = userAllocations[_beneficiary][_id];
		return _releasableAmount(allocation);
	}

	/**
	 * @dev Gets the total releasable for a given address. Likely gas-intensive, not intended for contract use.
	 * @param _beneficiary Address to check
	 */
	function totalReleasableAount(address _beneficiary)
		external
		view
		override
		returns (uint256 amount)
	{
		for (uint256 i = 0; i < allocationCount(_beneficiary); i++) {
			amount = amount.add(releasableAmount(_beneficiary, i));
		}
		return amount;
	}

	/**
	 * @dev Calculates the amount that has vested to date.
	 * @param _beneficiary Address to check
	 * @param _id The allocation index
	 */
	function vestedAmount(address _beneficiary, uint256 _id)
		public
		view
		returns (uint256)
	{
		Allocation memory allocation = userAllocations[_beneficiary][_id];
		return _vestedAmount(allocation);
	}

	/**
	 * @dev Gets the total ever vested for a given address. Likely gas-intensive, not intended for contract use.
	 * @param _beneficiary Address to check
	 */
	function totalVestedAmount(address _beneficiary)
		external
		view
		override
		returns (uint256 amount)
	{
		for (uint256 i = 0; i < allocationCount(_beneficiary); i++) {
			amount = amount.add(vestedAmount(_beneficiary, i));
		}
		return amount;
	}

	/**
	 * @dev Calculates the amount that has already vested but hasn't been released yet.
	 * @param allocation Allocation to calculate against
	 */
	function _releasableAmount(Allocation memory allocation)
		internal
		view
		returns (uint256)
	{
		return _vestedAmount(allocation).sub(allocation.claimed);
	}

	/**
	 * @dev Calculates the amount that has already vested.
	 * @param allocation Allocation to calculate against
	 */
	function _vestedAmount(Allocation memory allocation)
		internal
		view
		returns (uint256 amount)
	{
		if (block.timestamp < allocation.start.add(allocation.cliff)) {
			// Nothing is vested until after the start time + cliff length.
			amount = 0;
		} else if (
			block.timestamp >= allocation.start.add(allocation.duration)
		) {
			// The entire amount has vested if the entire duration has elapsed.
			amount = allocation.total;
		} else {
			// The initial tranche is available once the cliff expires, plus any portion of
			// tokens which have otherwise become vested as of the current block's timestamp.
			amount = allocation.initial.add(
				allocation
					.total
					.sub(allocation.initial)
					.sub(amount)
					.mul(block.timestamp.sub(allocation.start))
					.div(allocation.duration)
			);
		}

		return amount;
	}
}
