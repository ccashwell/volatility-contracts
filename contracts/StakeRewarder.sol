// SPDX-License-Identifier: MIT
pragma solidity ^0.8.5;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "./VestingMultiVault.sol";

/**
 * @title StakeRewarder
 * @dev This contract distributes rewards to depositors of supported tokens.
 * It's based on Sushi's MasterChef v1, but notably only serves what's already
 * available: no new tokens can be created. It's just a restaurant, not a farm.
 */
contract StakeRewarder is Ownable {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;
    
    struct UserInfo {
        uint256 amount;     // Quantity of tokens the user has staked.
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
        IERC20 token;            // Address of the token contract.
        uint256 weight;          // Weight points assigned to this pool.
        uint256 power;           // The multiplier for determining "staking power".
        uint256 total;           // Total number of tokens staked.
        uint256 accPerShare;     // Accumulated rewards per share (times 1e12).
        uint256 lastRewardBlock; // Last block where rewards were calculated.
    }
    
    // Distribution vault.
    VestingMultiVault public immutable vault;
    
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
    
    event TokenAdded(address indexed token, uint256 weight, uint256 totalWeight);
    event Deposit(address indexed user, uint256 indexed pid, uint256 amount);
    event Withdraw(address indexed user, uint256 indexed pid, uint256 amount);
    event Claim(address indexed user, uint256 amount);
    event EmergencyReclaim(address indexed user, address token, uint256 amount);
    event EmergencyWithdraw(address indexed user, uint256 indexed pid, uint256 amount);

    /**
     * @dev Create a staking contract that rewards depositors using its own token balance
     * and optionally vests rewards over time.
     * @param _rewardToken The token to be distributed as rewards.
     * @param _rewardPerBlock The quantity of reward tokens accrued per block.
     * @param _startBlock The first block at which staking is allowed.
     * @param _vestingCliff The number of seconds until issued rewards begin vesting.
     * @param _vestingDuration The number of seconds after issuance until vesting is completed.
     * @param _vault The VestingMultiVault that is ultimately responsible for reward distribution.
     */
    constructor(
        IERC20 _rewardToken,
        uint256 _rewardPerBlock,
        uint256 _startBlock,
        uint256 _vestingCliff,
        uint256 _vestingDuration,
        VestingMultiVault _vault
    ) {
        // Set the initial reward config
        rewardPerBlock = _rewardPerBlock;
        startBlock = _startBlock;
        vestingCliff = _vestingCliff;
        vestingDuration = _vestingDuration;
        
        // Set the vault and reward token (immutable after creation)
        vault = _vault;
        rewardToken = _rewardToken;
        
        // Approve the vault to pull reward tokens
        _rewardToken.approve(address(_vault), 2**256 - 1);
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

        uint256 lastRewardBlock = block.number > startBlock ? block.number : startBlock;
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
        
        totalWeight = totalWeight.sub(poolInfo[_pid].weight).add(
            _weight
        );

        poolInfo[_pid].weight = _weight;
        poolInfo[_pid].power = _power;
    }
    
    /**
     * @dev Update the reward per block. Can only be called by the owner.
     * @param _rewardPerBlock The total quantity to distribute per block.
     */
    function setRewardPerBlock(
        uint256 _rewardPerBlock
    ) public onlyOwner {
        rewardPerBlock = _rewardPerBlock;
    }
    
    /**
     * @dev Update the vesting rules for rewards. Can only be called by the owner.
     * @param _duration the number of seconds over which vesting occurs (see VestingMultiVault)
     * @param _cliff the number of seconds before any release occurs (see VestingMultiVault)
     */
    function setVestingRules(
        uint256 _duration,
        uint256 _cliff
    ) public onlyOwner {
        vestingDuration = _duration;
        vestingCliff = _cliff;
    }

    /**
     * @dev Calculate elapsed blocks between `_from` and `_to`.
     * @param _from The starting block.
     * @param _to The ending block.
     */
    function duration(
        uint256 _from,
        uint256 _to
    ) public pure returns (uint256) {
        return _to.sub(_from);
    }
    
    function totalPendingRewards(
        address _beneficiary
    ) public view returns (uint256 total) {
        for (uint256 pid = 0; pid < poolInfo.length; pid++) {
            total = total.add(pendingRewards(pid, _beneficiary));
        }

        return total;
    }

    /**
     * @dev View function to see pending rewards for an address. Likely gas intensive.
     * @param _pid The pool identifier.
     * @param _beneficiary The address to check.
     */
    function pendingRewards(
        uint256 _pid,
        address _beneficiary
    ) public view returns (uint256 amount) {
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][_beneficiary];
        uint256 accPerShare = pool.accPerShare;
        uint256 tokenSupply = pool.total;
        
        if (block.number > pool.lastRewardBlock && tokenSupply != 0) {
            uint256 reward = duration(pool.lastRewardBlock, block.number)
                .mul(rewardPerBlock)
                .mul(pool.weight)
                .div(totalWeight);

            accPerShare = accPerShare.add(
                reward.mul(1e12).div(tokenSupply)
            );
        }

        return user.amount.mul(accPerShare).div(1e12).sub(user.rewardDebt);
    }

    /**
     * @dev Gets the sum of power for every pool. Likely gas intensive.
     * @param _beneficiary The address to check.
     */
    function totalPower(
        address _beneficiary
    ) public view returns (uint256 total) {
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
    function power(
        uint256 _pid,
        address _beneficiary
    ) public view returns (uint256 amount) {
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][_beneficiary];
        return pool.power.mul(user.amount);
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
    function pokePool(
        uint256 _pid
    ) public {
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
    function claim(
        uint256 _pid,
        address _beneficiary
    ) public {
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
    function claimMultiple(
        uint256[] calldata _pids,
        address _beneficiary
    ) external {
        for (uint256 i = 0; i < _pids.length; i++) {
            claim(_pids[i], _beneficiary);
        }
    }

    /**
     * @dev Stake tokens to earn a share of rewards.
     * @param _pid The pool identifier.
     * @param _amount The number of tokens to deposit.
     */
    function deposit(
        uint256 _pid,
        uint256 _amount
    ) public {
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
    function withdraw(
        uint256 _pid,
        uint256 _amount
    ) public {
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
    function emergencyWithdraw(
        uint256 _pid
    ) public {
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
    function emergencyReclaim(
        IERC20 _token,
        uint256 _amount
    ) public onlyOwner {
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
            uint256 pending = user.amount
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
    function _safelyDistribute(
        address _to,
        uint256 _amount
    ) internal returns (uint256 amount) {
        uint256 available = rewardToken.balanceOf(address(this));
        amount = _amount > available ? available : _amount;
        
        vault.issue(
            _to,           // address _beneficiary,
            _amount,       // uint256 _amount,
            block.timestamp, // uint256 _startAt,
            vestingCliff,    // uint256 _cliff,
            vestingDuration, // uint256 _duration,
            0                // uint256 _initialPct
        );
        
        return amount;
    }
}