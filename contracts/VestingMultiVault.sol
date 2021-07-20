// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

/**
 * @title VestingMultiVault
 * @dev A token vesting contract that will release tokens gradually like a
 * standard equity vesting schedule, with a cliff and vesting period but no
 * arbitrary restrictions on the frequency of claims. Optionally has an initial
 * tranche claimable immediately after the cliff expires (in addition to any
 * amounts that would have vested up to that point but didn't due to a cliff).
 */
contract VestingMultiVault is AccessControl {
	using SafeMath for uint256;
	using SafeERC20 for IERC20;

	event Issued(
		address indexed beneficiary,
		uint256 indexed allocationId,
		uint256 amount,
		uint256 start,
		uint256 cliff,
		uint256 duration
	);

	event Released(
		address indexed beneficiary,
		uint256 indexed allocationId,
		uint256 amount,
		uint256 remaining
	);

	event Revoked(
		address indexed beneficiary,
		uint256 indexed allocationId,
		uint256 allocationAmount,
		uint256 revokedAmount
	);

	struct Allocation {
		uint256 start;
		uint256 cliff;
		uint256 duration;
		uint256 total;
		uint256 claimed;
		uint256 initial;
	}

	// The token being vested.
	IERC20 public immutable token;

	// The amount unclaimed for an address, whether or not vested.
	mapping(address => uint256) public pendingAmount;

	// The allocations assigned to an address.
	mapping(address => Allocation[]) public userAllocations;

	// The precomputed hash of the "ISSUER" role.
	bytes32 public constant ISSUER = keccak256("ISSUER");

	/**
	 * @dev Creates a vesting contract that releases allocations of a token
	 * over an arbitrary time period with support for tranches and cliffs.
	 * @param _token The ERC-20 token to be vested
	 */
	constructor(IERC20 _token) {
		token = _token;
		_setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
		_setupRole(ISSUER, msg.sender);
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
	) public onlyRole(ISSUER) {
		require(
			token.allowance(msg.sender, address(this)) >= _amount,
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
		token.safeTransferFrom(msg.sender, address(this), _amount);

		// Increase the total pending for the address.
		pendingAmount[_beneficiary] = pendingAmount[_beneficiary].add(_amount);

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
	function revoke(address _beneficiary, uint256 _id) public onlyRole(ISSUER) {
		Allocation storage allocation = userAllocations[_beneficiary][_id];

		// Calculate the remaining amount.
		uint256 total = allocation.total;
		uint256 remainder = total.sub(allocation.claimed);

		// Update the total pending for the address.
		pendingAmount[_beneficiary] = pendingAmount[_beneficiary].sub(
			remainder
		);

		// Update the allocation to be claimed in full.
		allocation.claimed = total;

		// Transfer the tokens vested
		token.safeTransfer(msg.sender, remainder);
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
		pendingAmount[_beneficiary] = pendingAmount[_beneficiary].sub(amount);

		// Transfer the tokens to the beneficiary.
		token.safeTransfer(_beneficiary, amount);

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
		public
		view
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
		public
		view
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
