import "@nomiclabs/hardhat-ethers";
import { ethers } from "hardhat";
import chai, { assert, expect } from "chai";
import { solidity } from "ethereum-waffle";
import { BigNumber, Signer } from "ethers";
import { RewardToken } from "../../typechain/RewardToken";
import { DAOracle } from "../../typechain/DAOracle";
import { VestingMultiVault } from "../../typechain/VestingMultiVault";

chai.use(solidity);

const BN = BigNumber.from;
const toWei = ethers.utils.parseUnits;

describe("DAOracle", () => {
  let testToken: RewardToken;
  let testToken2: RewardToken;
  let daoracle: DAOracle;
  let vault: VestingMultiVault;

  let createFeed = (as?: Signer) => {
    if (as) {
      daoracle = daoracle.connect(as);
    }

    return daoracle.createFeed(
      testToken.address,
      ethers.utils.formatBytes32String("foo"),
      100,
      toWei("0.01"),
      toWei("0.3"),
      toWei("1.0"),
      toWei("0.01")
    );
  };

  beforeEach("setup contracts", async () => {
    const [admin, user1, user2, user3]: Signer[] = await ethers.getSigners();
    const TestToken = await ethers.getContractFactory("RewardToken");
    testToken = (await TestToken.deploy(
      await admin.getAddress()
    )) as RewardToken;

    testToken2 = (await TestToken.deploy(
      await admin.getAddress()
    )) as RewardToken;

    for (const user of [user1, user2, user3]) {
      await testToken.transfer(await user.getAddress(), toWei("100000"));
      await testToken2.transfer(await user.getAddress(), toWei("100000"));
    }

    const Vault = await ethers.getContractFactory("VestingMultiVault");
    vault = (await Vault.deploy(testToken.address)) as VestingMultiVault;

    const DAOracle = await ethers.getContractFactory("DAOracle");
    daoracle = (await DAOracle.deploy(vault.address)) as DAOracle;
  });

  it("goes BRRRRRRR", () => {});

  describe("Initial state", () => {
    it("is managed by the admin", async () => {
      const [admin]: Signer[] = await ethers.getSigners();
      expect(
        await daoracle.hasRole(
          ethers.utils.keccak256(ethers.utils.toUtf8Bytes("MANAGER")),
          await admin.getAddress()
        )
      ).to.be.true;
    });

    it("has a vesting vault", async () => {
      expect(await daoracle.vestingVault()).to.equal(vault.address);
    });

    it("has no pools", async () => {
      expect(await daoracle.poolCount()).to.equal(0);
    });

    it("has no feeds", async () => {
      expect(await daoracle.feedCount()).to.equal(0);
    });
  });

  describe("Creating a pool", () => {
    beforeEach(async () => {
      await daoracle.createPool(testToken.address);
    });

    it("deploys a new pool instance", async () => {
      expect(await daoracle.poolFor(testToken.address)).not.to.equal(
        ethers.constants.AddressZero
      );
    });

    it("increases the number of pools", async () => {
      expect(await daoracle.poolCount()).to.equal(1);
    });

    it("reverts when a matching pool already exists", async () => {
      await expect(daoracle.createPool(testToken.address)).to.be.revertedWith(
        "createPool: pool for underlying already exists"
      );
    });

    it("reverts when randos try to create pools", async () => {
      const [admin, rando] = await ethers.getSigners();

      const [address, role] = await Promise.all([
        rando.getAddress(),
        daoracle.MANAGER(),
      ]);

      await expect(
        daoracle.connect(rando).createPool(testToken.address)
      ).to.be.revertedWith(
        `AccessControl: account ${address.toLowerCase()} is missing role ${role}`
      );
    });
  });

  describe("Creating a feed", () => {
    it("increases the number of feeds", async () => {
      assert((await daoracle.feedCount()).eq(0));
      await createFeed();
      expect(await daoracle.feedCount()).to.equal(1);
    });

    it("correctly maps the identifier to the feed", async () => {
      await createFeed();
      expect(
        ethers.utils.parseBytes32String(
          (await daoracle.feedFor(ethers.utils.formatBytes32String("foo")))[1]
        )
      ).to.equal("foo");
    });

    it("creates a new pool for the bond token", async () => {
      await expect(createFeed()).to.emit(daoracle, "Created");
    });

    it("uses an existing bond pool if one exists", async () => {
      await daoracle.createPool(testToken.address);
      await expect(createFeed()).not.to.emit(daoracle, "Created");
    });

    it("reverts when a matching feed already exists", async () => {
      await createFeed();
      await expect(createFeed()).to.be.revertedWith(
        "createFeed: identifier already registered"
      );
    });

    it("reverts when randos try to create feeds", async () => {
      const [admin, rando] = await ethers.getSigners();

      const [address, role] = await Promise.all([
        rando.getAddress(),
        daoracle.MANAGER(),
      ]);

      await expect(createFeed(rando)).to.be.revertedWith(
        `AccessControl: account ${address.toLowerCase()} is missing role ${role}`
      );
    });
  });

  describe("Economics", () => {
    beforeEach(async () => {
      await createFeed();
    });

    describe("Rewards", () => {
      it("claimable rewards grow over time until a proposal is submitted");
      it("relayer's share of rewards grows until a proposal is submitted");
      it("pool's share of rewards grows until a proposal is submitted");
      it("staking pools earn rewards for every sucessful proposal");
      it("relayers earn vested rewards for a valid proposal submission");
      it("relayers don't earn rewards for duplicate proposal submissions");
    });

    describe("Penalties", () => {
      describe("staking pools", () => {
        it("the relevant pool gets slashed for a failed proposal");
        it("other pools don't get slashed for an unrelated proposal");
      });

      describe("relayers", () => {
        it("waste gas? is that enough?");
      });
    });
  });
});
