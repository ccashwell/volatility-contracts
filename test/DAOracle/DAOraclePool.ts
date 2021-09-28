import "@nomiclabs/hardhat-ethers";
import { ethers } from "hardhat";
import chai, { assert, expect } from "chai";
import { solidity } from "ethereum-waffle";
import { BigNumber, Signer } from "ethers";
import { RewardToken } from "../../typechain/RewardToken";
import { DAOraclePool } from "../../typechain/DAOraclePool";

const BN = BigNumber.from;
chai.use(solidity);

describe("DAOraclePool", () => {
  let testToken: RewardToken;
  let pool: DAOraclePool;

  beforeEach("setup contracts", async () => {
    const [admin, user1, user2, user3]: Signer[] = await ethers.getSigners();
    const TestToken = await ethers.getContractFactory("RewardToken");
    testToken = (await TestToken.deploy(
      await admin.getAddress()
    )) as RewardToken;

    for (const user of [user1, user2, user3]) {
      await testToken.transfer(await user.getAddress(), 100000000);
    }

    const Pool = await ethers.getContractFactory("DAOraclePool");
    pool = (await Pool.deploy(
      testToken.address,
      0,
      0,
      await admin.getAddress()
    )) as DAOraclePool;
  });

  describe("Initial state", () => {
    it("is owned by the admin", async () => {
      const [admin]: Signer[] = await ethers.getSigners();
      expect(await pool.owner()).to.equal(await admin.getAddress());
    });

    it("has the correct underlying", async () => {
      expect(await pool.underlying()).to.equal(testToken.address);
    });

    it("has no shares", async () => {
      expect(await pool.totalSupply()).to.equal(BN(0));
    });
  });

  describe("Minting", () => {
    beforeEach(async () => {
      const [admin, user1, user2, user3]: Signer[] = await ethers.getSigners();
      for (let user of [user1, user2, user3]) {
        await testToken.connect(user).approve(pool.address, 10 ** 5);
      }
    });

    it("assigns 1,000 shares for the first deposit", async () => {
      const [admin, user]: Signer[] = await ethers.getSigners();
      await pool.connect(user).mint(100);
      expect(await pool.balanceOf(await user.getAddress())).to.equal(BN(1000));
    });

    it("mints a proportional number of shares for new stakers", async () => {
      const [admin, user1, user2, user3]: Signer[] = await ethers.getSigners();
      await pool.connect(user1).mint(100);
      expect(await pool.totalSupply()).to.equal(BN(1000));

      await pool.connect(user2).mint(10);
      expect(await pool.totalSupply()).to.equal(BN(1100));
      expect(await pool.balanceOf(await user2.getAddress())).to.equal(BN(100));

      await pool.connect(user3).mint(10);
      expect(await pool.totalSupply()).to.equal(BN(1200));
      expect(await pool.balanceOf(await user3.getAddress())).to.equal(BN(100));
    });

    it("charges a fee if one is set", async () => {
      const [admin, user]: Signer[] = await ethers.getSigners();
      await pool.connect(admin).setFees(
        100, // 100 bps = 1%
        0,
        await admin.getAddress()
      );

      const balance = await testToken.balanceOf(await admin.getAddress());
      await pool.connect(user).mint(1000);
      expect(await testToken.balanceOf(await admin.getAddress())).to.equal(
        balance.add(10)
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

      assert((await pool.totalSupply()).eq(3000));
      await pool.connect(user1).burn(shares);
      expect(await pool.totalSupply()).to.equal(2000);
    });

    it("reduces the staker's balance", async () => {
      const [admin, user1]: Signer[] = await ethers.getSigners();
      const shares: BigNumber = await pool.balanceOf(await user1.getAddress());

      assert(shares.eq(1000));
      await pool.connect(user1).burn(shares.div(2));

      expect(await pool.balanceOf(await user1.getAddress())).to.equal(500);
    });

    it("returns underlying tokens", async () => {
      const [admin, user1]: Signer[] = await ethers.getSigners();
      const user: string = await user1.getAddress();

      const initialBalance: BigNumber = await testToken.balanceOf(user);
      await pool.connect(user1).burn(1000);

      expect(await testToken.balanceOf(user)).to.equal(initialBalance.add(100));
    });

    it("charges a fee if one is set", async () => {
      const [admin, user]: Signer[] = await ethers.getSigners();
      await pool.connect(admin).setFees(
        0,
        100, // 100 bps = 1%
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
