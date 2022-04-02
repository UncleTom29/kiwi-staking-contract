// SPDX-License-Identifier: MIT

pragma solidity 0.8.10;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "./KiwiETH.sol";

// Pool settings
struct Pool {
    // Address of the token hosted by the pool
    address token;
    // Minimum time in seconds before the tokens staked can be withdrew
    uint32 lockTime;
    // Amount of tokens that give access to 1 reward every block
    uint64 amountPerReward;
    // Value of 1 reward per block
    uint40 rewardPerBlock;
    // Minimum amount of token to deposit per user
    uint72 minimumDeposit;
    // Percentage of the deposit that is collected by the pool, with one decimal
    // Eg. for 34.3 percents, depositFee will have a value of 343
    uint104 depositFee;
    // Last block where the reward will take effect
    // Not taken into account if equals 0
    uint40 lastRewardedBlock;
}

// User deposit informations
struct Deposit {
    // Cumulated amount deposited
    uint176 amount;
    // Block number from when to compute next reward
    uint40 rewardBlockStart;
    // Timestamp in seconds when the deposit is available for withdraw
    uint40 lockTimeEnd;
}

/**
 * @notice Staking contract to earn KiwiETH tokens
 */
contract Kiwi is Ownable {
    using SafeERC20 for IERC20;

    // KiwiETH token address
    address public immutable KiwiETH;
    // List of all the pools created with their settings
    Pool[] public pools;

    // Associate pool id to user address to deposit informations
    mapping(uint256 => mapping(address => Deposit)) public deposits;
    // Associate pool id to the amount of fees collected
    mapping(uint256 => uint256) public collectedFees;

    event AmountPerRewardUpdated(uint256 indexed poolId, uint256 newAmountPerReward);
    event RewardPerBlockUpdated(uint256 indexed poolId, uint256 newRewardPerBlock);
    event DepositFeeUpdated(uint256 indexed poolId, uint256 newDepositFee);
    event MinimumDepositUpdated(uint256 indexed poolId, uint256 newMinimumDeposit);
    event LockTimeUpdated(uint256 indexed poolId, uint256 newLockTime);
    event PoolCreated(
        address indexed token,
        uint256 id,
        uint256 amountPerReward,
        uint256 rewardPerBlock,
        uint256 depositFee,
        uint256 minimumDeposit,
        uint256 lockTime
    );
    event PoolClosed(uint256 indexed poolId, uint256 lastRewardedBlock);
    event Deposited(uint256 indexed poolId, address indexed account, uint256 amount);
    event Withdrew(uint256 indexed poolId, address indexed account, uint256 amount);
    event WithdrewFees(uint256 indexed poolId, uint256 amount);
    event Harvested(uint256 indexed poolId, address indexed account, uint256 amount);

    /**
     @notice Check that percentage is less or equal to 1000 to not exceed 100.0%
     */
    modifier checkPercentage(uint256 percentage) {
        require(percentage <= 1000, "Kiwi: percentage should be equal to or lower than 1000");
        _;
    }

    /**
     * @param _KiwiETH Address of the KiwiETH token that users will be rewarded with.
     */
    constructor(address _KiwiETH) {
        KiwiETH = _KiwiETH;
    }

    /**
     * @notice Get the number of pools created.
     * @return Number of pools.
     */
    function numberOfPools() external view returns (uint256) {
        return pools.length;
    }

    /**
     * @notice Get all the pools at once.
     * @return An array of the pools settings.
     */
    function getPools() external view returns (Pool[] memory) {
        return pools;
    }

    /**
     * @notice Enable to update the amount of tokens that give access to 1 reward every block for a specific pool.
     * @dev Only accessible to owner.
     * @param poolId Id of the pool to update.
     * @param newAmountPerReward New amount of tokens that give access to 1 reward
     */
    function setAmountPerReward(uint256 poolId, uint64 newAmountPerReward) external onlyOwner {
        pools[poolId].amountPerReward = newAmountPerReward;
        emit AmountPerRewardUpdated(poolId, newAmountPerReward);
    }

    /**
     * @notice Enable to update the amount of KiwiETH received as staking reward every block for a specific pool.
     * @dev Only accessible to owner.
     * @param poolId Id of the pool to update.
     * @param newRewardPerBlock New amount of KiwiETH received as staking reward every block.
     */
    function setRewardPerBlock(uint256 poolId, uint40 newRewardPerBlock) external onlyOwner {
        pools[poolId].rewardPerBlock = newRewardPerBlock;
        emit RewardPerBlockUpdated(poolId, newRewardPerBlock);
    }

    /**
     * @notice Enable to update the deposit fee of a specific pool.
     * @dev Only accessible to owner.
     * @param poolId Id of the pool to update.
     * @param newDepositFee New percentage of the deposit that is collected by the pool, with one decimal.
     * Eg. for 34.3 percents, depositFee will have a value of 343
     */
    function setDepositFee(uint256 poolId, uint104 newDepositFee)
        external
        onlyOwner
        checkPercentage(newDepositFee)
    {
        pools[poolId].depositFee = newDepositFee;
        emit DepositFeeUpdated(poolId, newDepositFee);
    }

    /**
     * @notice Enable to update the minimum deposit amount of a specific pool.
     * @dev Only accessible to owner.
     * @param poolId Id of the pool to update.
     * @param newMinimumDeposit New minimum token amount to be deposited in the pool by each user.
     */
    function setMinimumDeposit(uint256 poolId, uint72 newMinimumDeposit) external onlyOwner {
        pools[poolId].minimumDeposit = newMinimumDeposit;
        emit MinimumDepositUpdated(poolId, newMinimumDeposit);
    }

    /**
     * @notice Enable to update the lock time of a specific pool.
     * @dev Only accessible to owner.
     * @param poolId Id of the pool to update.
     * @param newLockTime New amount of seconds that users will have to wait after a deposit to be able to withdraw.
     */
    function setLockTime(uint256 poolId, uint32 newLockTime) external onlyOwner {
        pools[poolId].lockTime = newLockTime;
        emit LockTimeUpdated(poolId, newLockTime);
    }

    /**
     * @notice Enable to create a new pool for a token.
     * @dev Only accessible to owner.
     * @param token Addres of the token that can be staked in the pool.
     * @param amountPerReward Amount of tokens that give access to 1 reward every block.
     * @param rewardPerBlock Value of 1 reward per block.
     * @param depositFee Percentage of the deposit that is collected by the pool, with one decimal.
     * Eg. for 34.3 percents, depositFee will have a value of 343
     * @param minimumDeposit Minimum amount of token to deposit per user.
     * @param lockTime Minimum time in seconds before the tokens staked can be withdrew.
     */
    function createPool(
        address token,
        uint64 amountPerReward,
        uint40 rewardPerBlock,
        uint104 depositFee,
        uint72 minimumDeposit,
        uint32 lockTime
    ) external onlyOwner checkPercentage(depositFee) {
        pools.push(
            Pool({
                token: token,
                amountPerReward: amountPerReward,
                rewardPerBlock: rewardPerBlock,
                depositFee: depositFee,
                minimumDeposit: minimumDeposit,
                lockTime: lockTime,
                lastRewardedBlock: 0
            })
        );
        emit PoolCreated(
            token,
            pools.length - 1,
            amountPerReward,
            rewardPerBlock,
            depositFee,
            minimumDeposit,
            lockTime
        );
    }

    /**
     * @notice Enable to close a new pool by determining the last block that is going to be rewarded.
     * @dev Only accessible to owner.
     * @param poolId Id of the pool to terminate.
     * @param lastRewardedBlock Last block where the reward will take effect.
     */
    function closePool(uint256 poolId, uint40 lastRewardedBlock) external onlyOwner {
        require(
            lastRewardedBlock > block.number,
            "Kiwi: last rewarded block must be greater than current"
        );
        pools[poolId].lastRewardedBlock = lastRewardedBlock;
        emit PoolClosed(poolId, lastRewardedBlock);
    }

    /**
     * @notice Enable users to stake their tokens in the pool.
     * @param poolId Id of pool where to deposit tokens.
     * @param depositAmount Amount of tokens to deposit.
     */
    function deposit(uint256 poolId, uint176 depositAmount) external {
        Pool memory pool = pools[poolId]; // gas savings

        // Check if the user deposits enough tokens
        require(
            deposits[poolId][msg.sender].amount + depositAmount >= pool.minimumDeposit,
            "Kiwi: cannot deposit less that minimum deposit value"
        );

        // Send the reward the user accumulated so far and updates deposit state
        harvest(poolId);

        // Compute the fees to collected and update the deposit state
        uint176 fees = (depositAmount * pool.depositFee) / 1000;
        collectedFees[poolId] += fees;
        deposits[poolId][msg.sender].amount += depositAmount - fees;
        deposits[poolId][msg.sender].lockTimeEnd = uint40(block.timestamp + pool.lockTime);

        emit Deposited(poolId, msg.sender, depositAmount);
        IERC20(pools[poolId].token).safeTransferFrom(msg.sender, address(this), depositAmount);
    }

    /**
     * @notice Enable users to with withdraw their stake after end of lock time with reward.
     * @param poolId Id of pool where to withdraw tokens.
     * @param withdrawAmount Amount of tokens to withdraw.
     */
    function withdraw(uint256 poolId, uint176 withdrawAmount) external {
        // Check if the stake is available to withdraw
        require(
            block.timestamp >= deposits[poolId][msg.sender].lockTimeEnd,
            "Kiwi: cannot withdraw before lock time end"
        );

        // Send the reward the user accumulated so far and updates deposit state
        harvest(poolId);
        deposits[poolId][msg.sender].amount -= withdrawAmount;

        emit Withdrew(poolId, msg.sender, withdrawAmount);
        IERC20(pools[poolId].token).safeTransfer(msg.sender, withdrawAmount);
    }

    /**
     * @notice Enable users to with withdraw their stake before end of lock time without reward.
     * @param poolId Id of pool where to withdraw tokens.
     * @param withdrawAmount Amount of tokens to withdraw.
     */
    function emergencyWithdraw(uint256 poolId, uint176 withdrawAmount) external {
        deposits[poolId][msg.sender].amount -= withdrawAmount;

        emit Withdrew(poolId, msg.sender, withdrawAmount);
        IERC20(pools[poolId].token).safeTransfer(msg.sender, withdrawAmount);
    }

    /**
     * @notice Enable the admin to withdraw the fees collected on a specific pool.
     * @dev Only accessible to owner.
     * @param poolId Id of the pool where to withdraw the fees collected.
     * @param receiver Address that will receive the fees.
     * @param amount Amount of fees to withdraw, in number of tokens.
     */
    function withdrawFees(
        uint256 poolId,
        address receiver,
        uint256 amount
    ) external onlyOwner {
        // Check that the amount required in equal or lower to the amount of fees collected
        require(
            amount <= collectedFees[poolId],
            "Kiwi: cannot withdraw more than collected fees"
        );

        collectedFees[poolId] -= amount;

        emit WithdrewFees(poolId, amount);
        IERC20(pools[poolId].token).safeTransfer(receiver, amount);
    }

    /**
     * @notice Enable the users to withdraw their reward without unstaking their deposit.
     * @param poolId Id of the pool where to withdraw the reward.
     */
    function harvest(uint256 poolId) public {
        // Get the amount of tokens to reward the user with
        uint256 reward = pendingReward(poolId, msg.sender);
        // Update the deposit state
        deposits[poolId][msg.sender].rewardBlockStart = uint40(block.number);

        emit Harvested(poolId, msg.sender, reward);
    //     KiwiETH(kiwiETH).mint(msg.sender, reward);
    // }

    /**
     * @notice Computes the reward a user is entitled of.
     * @dev Avaible as an external function for frontend as well as internal for harvest function.
     * @param poolId Id of the pool where to get the reward.
     * @param account Address of the account to get the reward for.
     * @return The amount of KiwiETH token the user is entitled to as a staking reward.
     */
    function pendingReward(uint256 poolId, address account) public view returns (uint256) {
        Pool memory poolInfos = pools[poolId]; // gas savings
        // Checks if pool is close or not
        uint256 lastBlock = poolInfos.lastRewardedBlock != 0 &&
            poolInfos.lastRewardedBlock < block.number
            ? poolInfos.lastRewardedBlock
            : block.number;
        Deposit memory deposited = deposits[poolId][account]; // gas savings

        // Handles the case where user already withdrew reward after lastRewardedBlock
        if (lastBlock < deposited.rewardBlockStart) return 0;
        // Following computation is an optimised version of this:
        // reward = amountStaked / amountPerReward * rewardPerBlock * numberOfElapsedBlocks
        return
            ((deposited.amount * poolInfos.rewardPerBlock) *
                (lastBlock - deposited.rewardBlockStart)) / poolInfos.amountPerReward;
    }
}
