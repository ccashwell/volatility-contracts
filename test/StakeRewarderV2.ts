import "@nomiclabs/hardhat-ethers";
import { ethers } from "hardhat";
import chai, { expect } from "chai";
import { solidity } from "ethereum-waffle";
import { constants, BigNumber, Signer } from "ethers";
import { RewardToken } from "../typechain/RewardToken";
import { StakeRewarderV2 } from "../typechain/StakeRewarderV2";
import { advanceBlocks, blockNumber, increaseTime } from "./utils";

const BN = BigNumber.from;
chai.use(solidity);

describe("StakeRewarderV2 contract", () => {
  let owner: Signer;
  let outsider: Signer;
  let stakeRewarder: StakeRewarderV2;
  let testToken: RewardToken;
  let ownerAdd: string;
  let rewardPerBlock = 10,
    startBlock = 0,
    vestingCliff = 0,
    vestingDuration = 100;

  beforeEach("should setup the contract instances", async () => {
    // Get owner
    [owner, outsider] = await ethers.getSigners();
    ownerAdd = await owner.getAddress();
    // Get RewardToken contract and deploy
    const TestToken = await ethers.getContractFactory("RewardToken");
    testToken = (await TestToken.deploy(
      await owner.getAddress()
    )) as RewardToken;
    // Deploy StakeRewarderV2
    const StakeFactory = await ethers.getContractFactory("StakeRewarderV2");
    stakeRewarder = (await StakeFactory.deploy(
      testToken.address,
      rewardPerBlock,
      startBlock,
      vestingCliff,
      vestingDuration
    )) as StakeRewarderV2;
    await testToken.transfer(stakeRewarder.address, 1000);
  });

  it("should createPool only for owner", async () => {
    let weight = 1,
      power = 1,
      shouldUpdate = false;
    await expect(
      stakeRewarder
        .connect(outsider)
        .createPool(testToken.address, weight, power, shouldUpdate)
    ).to.be.reverted;
    await stakeRewarder.createPool(
      testToken.address,
      weight,
      power,
      shouldUpdate
    );
  });

  it("should stake to the pool and claim", async () => {
    let weight = 1,
      power = 1,
      shouldUpdate = false;
    const depositAmount = 1000;
    await stakeRewarder.createPool(
      testToken.address,
      weight,
      power,
      shouldUpdate
    );
    await testToken.approve(stakeRewarder.address, constants.MaxUint256);
    await stakeRewarder.deposit(0, depositAmount);
    let oldNum = await blockNumber();
    await advanceBlocks(oldNum + 10);
    expect(await stakeRewarder.pendingRewards(0, ownerAdd)).to.equal(
      10 * rewardPerBlock
    );
    await stakeRewarder.claim(0, ownerAdd);
    expect(await stakeRewarder.totalLocked(0, ownerAdd)).to.equal(
      11 * rewardPerBlock + depositAmount
    );
  });

  it("should stake to the pool and release", async () => {
    let weight = 1,
      power = 1,
      shouldUpdate = false;
    const depositAmount = 1000;
    await stakeRewarder.createPool(
      testToken.address,
      weight,
      power,
      shouldUpdate
    );
    await testToken.approve(stakeRewarder.address, constants.MaxUint256);
    await stakeRewarder.deposit(0, depositAmount);
    let oldNum = await blockNumber();
    await advanceBlocks(oldNum + 10);
    expect(await stakeRewarder.pendingRewards(0, ownerAdd)).to.equal(
      10 * rewardPerBlock
    );
    await stakeRewarder.claim(0, ownerAdd);
    expect(await stakeRewarder.totalLocked(0, ownerAdd)).to.equal(
      11 * rewardPerBlock + depositAmount
    );
    const prevBalance = await testToken.balanceOf(ownerAdd);

    await increaseTime(vestingDuration);
    await stakeRewarder.release(ownerAdd, 0);
    expect(await testToken.balanceOf(ownerAdd)).to.equal(
      prevBalance.add(BN(11 * rewardPerBlock))
    );
  });
});
