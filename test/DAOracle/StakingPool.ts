import "@nomiclabs/hardhat-ethers";
import { ethers } from "hardhat";
import chai, { assert, expect } from "chai";
import { solidity } from "ethereum-waffle";
import { BigNumber, Signer } from "ethers";
import { RewardToken } from "../../typechain/RewardToken";
import { StakingPool } from "../../typechain/StakingPool";

const BN = BigNumber.from;
chai.use(solidity);

describe("StakingPool", () => {
  let testToken: RewardToken;
  let pool: StakingPool;

  beforeEach("setup contracts", async () => {
    const [admin, user1, user2, user3]: Signer[] = await ethers.getSigners();
    const TestToken = await ethers.getContractFactory("RewardToken");
    testToken = (await TestToken.deploy(
      await admin.getAddress()
    )) as RewardToken;

    for (const user of [user1, user2, user3]) {
      await testToken.transfer(await user.getAddress(), 100000000);
    }

    const Pool = await ethers.getContractFactory("StakingPool");
    pool = (await Pool.deploy(
      testToken.address,
      0,
      0,
      await admin.getAddress()
    )) as StakingPool;
  });

  describe("Initial state", () => {
    it("is owned by the admin", async () => {
      const [admin]: Signer[] = await ethers.getSigners();
      expect(await pool.hasRole(await pool.MANAGER(), await admin.getAddress()))
        .to.be.true;
    });

    it("has the correct underlying", async () => {
      expect(await pool.underlying()).to.equal(testToken.address);
    });

    it("has no shares", async () => {
      expect(await pool.totalSupply()).to.equal(BN(0));
    });

    it("has the correct name", async () => {
      expect(await pool.name()).to.equal(
        `StakingPool: ${await testToken.name()}`
      );
    });

    it("has the correct symbol", async () => {
      expect(await pool.symbol()).to.equal(`dp${await testToken.symbol()}`);
    });
  });

  describe("Minting", () => {
    beforeEach(async () => {
      const [admin, user1, user2, user3]: Signer[] = await ethers.getSigners();
      for (let user of [user1, user2, user3]) {
        await testToken.connect(user).approve(pool.address, 10 ** 5);
      }
    });

    it("assigns shares = deposit, for the first deposit", async () => {
      const [admin, user]: Signer[] = await ethers.getSigners();
      await pool.connect(user).mint(100);
      expect(await pool.balanceOf(await user.getAddress())).to.equal(BN(100));
    });

    it("mints a proportional number of shares for new stakers", async () => {
      const [admin, user1, user2, user3]: Signer[] = await ethers.getSigners();
      await pool.connect(user1).mint(100);
      expect(await pool.totalSupply()).to.equal(BN(100));

      await pool.connect(user2).mint(10);
      expect(await pool.totalSupply()).to.equal(BN(110));
      expect(await pool.balanceOf(await user2.getAddress())).to.equal(BN(10));

      await pool.connect(user3).mint(10);
      expect(await pool.totalSupply()).to.equal(BN(120));
      expect(await pool.balanceOf(await user3.getAddress())).to.equal(BN(10));
    });

    it("charges a fee if one is set", async () => {
      const [admin, user]: Signer[] = await ethers.getSigners();
      await pool.connect(admin).setFees(
        ethers.utils.parseEther("0.1"), // 10%
        0,
        await admin.getAddress()
      );

      const balance = await testToken.balanceOf(await admin.getAddress());
      await pool.connect(user).mint(1000);
      expect(await testToken.balanceOf(await admin.getAddress())).to.equal(
        balance.add(100)
      );
    });
  });

  describe("Burning", () => {
    beforeEach(async () => {
      const [admin, user1, user2, user3]: Signer[] = await ethers.getSigners();
      for (let user of [user1, user2, user3]) {
        await testToken.connect(user).approve(pool.address, 10 ** 5);
        await pool.connect(user).mint(100);
      }
    });

    it("reduces the total supply", async () => {
      const [admin, user1]: Signer[] = await ethers.getSigners();
      const shares: BigNumber = await pool.balanceOf(await user1.getAddress());

      assert((await pool.totalSupply()).eq(300));
      await pool.connect(user1).burn(shares);
      expect(await pool.totalSupply()).to.equal(200);
    });

    it("reduces the staker's balance", async () => {
      const [admin, user1]: Signer[] = await ethers.getSigners();
      const shares: BigNumber = await pool.balanceOf(await user1.getAddress());

      assert(shares.eq(100));
      await pool.connect(user1).burn(shares.div(2));

      expect(await pool.balanceOf(await user1.getAddress())).to.equal(50);
    });

    it("returns underlying tokens", async () => {
      const [admin, user1]: Signer[] = await ethers.getSigners();
      const user: string = await user1.getAddress();

      const balance: BigNumber = await testToken.balanceOf(user);
      await pool.connect(user1).burn(10);

      expect(await testToken.balanceOf(user)).to.be.above(balance);
    });

    it("pays out underlying tokens proportionally", async () => {
      const [admin, user1]: Signer[] = await ethers.getSigners();
      const user: string = await user1.getAddress();

      const initialBalance: BigNumber = await testToken.balanceOf(user);
      const totalStaked: BigNumber = await testToken.balanceOf(pool.address);
      const totalShares: BigNumber = await pool.totalSupply();
      const userShares: BigNumber = await pool.balanceOf(user);

      // payout should be `(userShares * totalStaked) / totalShares`
      const expectedPayout: BigNumber = userShares
        .mul(totalStaked)
        .div(totalShares);

      await pool.connect(user1).burn(100);

      expect(await testToken.balanceOf(user)).to.equal(
        initialBalance.add(expectedPayout)
      );
    });

    it("charges a fee if one is set", async () => {
      const [admin, user]: Signer[] = await ethers.getSigners();
      await pool.connect(admin).setFees(
        0,
        ethers.utils.parseEther("0.01"), // 1%
        await admin.getAddress()
      );

      const balance = await testToken.balanceOf(await admin.getAddress());
      await pool
        .connect(user)
        .burn(await pool.balanceOf(await user.getAddress()));

      expect(await testToken.balanceOf(await admin.getAddress())).to.equal(
        balance.add(1)
      );
    });
  });
});
