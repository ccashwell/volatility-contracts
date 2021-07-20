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
interface IVestingVault {
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
	) external;

	/**
	 * @dev Revokes an existing allocation. Any unclaimed tokens are recalled
	 * and sent to the caller. Callable only be issuers.
	 * @param _beneficiary The address whose allocation is to be revoked
	 * @param _id The allocation ID to revoke
	 */
	function revoke(address _beneficiary, uint256 _id) external;

	/**
	 * @dev Transfers vested tokens from any number of allocations to their beneficiary. Callable by anyone. May be gas-intensive.
	 * @param _beneficiary The address that has vested tokens
	 * @param _ids The vested allocation indexes
	 */
	function releaseMultiple(address _beneficiary, uint256[] calldata _ids)
		external;

	/**
	 * @dev Gets the total releasable for a given address. Likely gas-intensive, not intended for contract use.
	 * @param _beneficiary Address to check
	 */
	function totalReleasableAount(address _beneficiary)
		external
		view
		returns (uint256 amount);

	/**
	 * @dev Gets the total ever vested for a given address. Likely gas-intensive, not intended for contract use.
	 * @param _beneficiary Address to check
	 */
	function totalVestedAmount(address _beneficiary)
		external
		view
		returns (uint256 amount);
}
