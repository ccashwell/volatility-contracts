import { ethers } from "hardhat";
import { assert, expect } from "chai";
import { Signer } from "ethers";
import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers";

import {
  SkinnyDAOracle,
  DAOraclePool,
  RewardToken,
  VestingVault,
  SkinnyOptimisticOracleInterface,
} from "../../typechain";

import {
  impersonate,
  increaseTime,
  lastBlock,
  setNextBlockTimestamp,
  toUnits,
} from "../utils";

import {
  giveDai,
  getProposal,
  DAI,
  FEED_ID,
  ORACLE,
  Proposal,
  configureFeed,
  signProposal,
  setDefaultDisputePeriod,
  setExternalIdentifier,
  setDefaultMaxOutstandingDisputes
} from "./helpers";

const signedProposal = async (
  proposal: Proposal,
  signer?: SignerWithAddress
) => {
  return await signProposal(daoracle, proposal, signer);
};

let daiToken: RewardToken;
let daoracle: SkinnyDAOracle;
let vault: VestingVault;
let oracle: SkinnyOptimisticOracleInterface;

describe("SkinnyDAOracle", () => {
  beforeEach(async () => {
    const [admin, user1, user2, user3]: Signer[] = await ethers.getSigners();
    const VaultFactory = await ethers.getContractFactory("VestingVault");
    const SkinnyDAOracleFactory = await ethers.getContractFactory(
      "SkinnyDAOracle",
      {
        libraries: {
          DAOracleHelpers: (
            await (await ethers.getContractFactory("DAOracleHelpers")).deploy()
          ).address,
        },
      }
    );

    oracle = (await ethers.getContractAt(
      "SkinnyOptimisticOracleInterface",
      ORACLE
    )) as SkinnyOptimisticOracleInterface;
    vault = (await VaultFactory.deploy()) as VestingVault;

    daiToken = (await ethers.getContractAt("RewardToken", DAI)) as RewardToken;
    daoracle = (await SkinnyDAOracleFactory.deploy(
      ethers.utils.formatBytes32String("ethVIX"),
      oracle.address,
      vault.address
    )) as SkinnyDAOracle;

    await daiToken.approve(daoracle.address, ethers.constants.MaxUint256);
    await giveDai([
      daoracle.address,
      await admin.getAddress(),
      await user1.getAddress(),
      await user2.getAddress(),
      await user3.getAddress(),
    ]);
  });

  describe("Roles", () => {
    it("grants the deployer the Manager role", async () => {
      const [admin]: Signer[] = await ethers.getSigners();
      expect(
        await daoracle.hasRole(
          await daoracle.MANAGER(),
          await admin.getAddress()
        )
      ).to.be.true;
    });

    it("grants the deployer the Proposer role", async () => {
      const [admin]: Signer[] = await ethers.getSigners();
      expect(
        await daoracle.hasRole(
          await daoracle.PROPOSER(),
          await admin.getAddress()
        )
      ).to.be.true;
    });

    it("grants the oracle the Oracle role", async () => {
      expect(
        await daoracle.hasRole(
          await daoracle.ORACLE(),
          await oracle.resolvedAddress
        )
      ).to.be.true;
    });
  });

  describe("Global Configuration", () => {
    it("correctly updates the defaultDisputePeriod", async () => {
		await setDefaultDisputePeriod(daoracle, 300);
      expect(await daoracle.defaultTtl()).to.equal(300);
    });

	it("correctly updates the externalIdentifier", async () => {
		await setExternalIdentifier(daoracle, ethers.utils.formatBytes32String("volDAOracle"));
      expect(await daoracle.externalIdentifier()).to.equal(ethers.utils.formatBytes32String("volDAOracle"));
    });

	it("correctly updates the defaultMaxOutstandingDisputes", async () => {
		await setDefaultMaxOutstandingDisputes(daoracle, 5);
      expect(await daoracle.defaultMaxOutstandingDisputes()).to.equal(5);
    });

  });

  describe("Feed Configuration", () => {
    it("correctly maps the feedId to the feed", async () => {
      await configureFeed(daoracle);
      expect((await daoracle.feed(FEED_ID)).bondToken).to.equal(DAI);
    });

    it("creates a new pool for the bond token", async () => {
      assert((await daoracle.pool(DAI)) == ethers.constants.AddressZero);
      await configureFeed(daoracle);
      expect(await daoracle.pool(DAI)).not.to.equal(
        ethers.constants.AddressZero
      );
    });

    it("uses the existing bond pool if available", async () => {
      await configureFeed(daoracle);
      const existingPool = await daoracle.pool(DAI);
      assert(existingPool != ethers.constants.AddressZero);

      await configureFeed(daoracle);
      expect(await daoracle.pool(DAI)).to.equal(existingPool);
    });

    it("overwrites configs when a matching feed already exists", async () => {
      const [admin] = await ethers.getSigners();

      await configureFeed(daoracle, admin, {
        feedId: FEED_ID,
        bondToken: DAI,
        bondAmount: ethers.utils.parseEther("1"),
      });

      assert(
        (await daoracle.feed(FEED_ID)).bondAmount.eq(
          ethers.utils.parseEther("1")
        )
      );

      await configureFeed(daoracle, admin, {
        feedId: FEED_ID,
        bondToken: DAI,
        bondAmount: ethers.utils.parseEther("100"),
      });

      expect((await daoracle.feed(FEED_ID)).bondAmount).to.equal(
        ethers.utils.parseEther("100")
      );
    });

    it("reverts when randos try to create feeds", async () => {
      const [admin, rando] = await ethers.getSigners();

      const [address, role] = await Promise.all([
        rando.getAddress(),
        daoracle.MANAGER(),
      ]);

      await expect(configureFeed(daoracle, rando)).to.be.revertedWith(
        `AccessControl: account ${address.toLowerCase()} is missing role ${role}`
      );
    });
  });

  describe("Relaying", () => {
    let feedId: string;

    beforeEach(async () => {
      feedId = ethers.utils.formatBytes32String(
        Buffer.from(ethers.utils.randomBytes(8)).toString("hex")
      );
      await configureFeed(daoracle, undefined, { feedId });
      await increaseTime(1);
    });

    context("with a valid proposal", () => {
      it("is not reverted", async () => {
        const [us] = await ethers.getSigners();
        const proposal = await getProposal({ feedId });

        await expect(
          daoracle.relay(
            proposal,
            await signedProposal(proposal),
            await us.getAddress()
          )
        ).not.to.be.reverted;
      });

      it("delivers the reporter's share of rewards into vesting", async () => {
        const [us] = await ethers.getSigners();
        const proposal = await getProposal({ feedId });

        const { reporterAmount } = await daoracle.claimableRewards(feedId);

        await daoracle.relay(
          proposal,
          await signedProposal(proposal),
          await us.getAddress()
        );

        const { allocation } = await vault.allocationSummary(
          await us.getAddress(),
          0
        );
        expect(allocation.total).to.equal(reporterAmount);
      });

      it("delivers the pool's share to the pool directly", async () => {
        const [us] = await ethers.getSigners();
        const proposal = await getProposal({ feedId });

        const prevBlock = await lastBlock();
        const { poolAmount } = await daoracle.claimableRewards(feedId);

        const poolAddress = await daoracle.pool(DAI);
        const poolBalance = await daiToken.balanceOf(poolAddress);
        await setNextBlockTimestamp(prevBlock.timestamp + 1);

        await daoracle.relay(
          proposal,
          await signedProposal(proposal),
          await us.getAddress()
        );

        expect(await daiToken.balanceOf(poolAddress)).to.equal(
          poolBalance.add(poolAmount)
        );
      });
    });

    context("with an invalid proposal", () => {
      it("reverts for a proposal not signed by us", async () => {
        const [us, notUs] = await ethers.getSigners();
        const proposal = await getProposal({ feedId });

        await expect(
          daoracle.relay(
            proposal,
            await signedProposal(proposal, notUs),
            await notUs.getAddress()
          )
        ).to.be.revertedWith("unauthorized signer");
      });

      it("reverts for a proposal not signed by the reported signer", async () => {
        const [us, notUs] = await ethers.getSigners();
        const proposal = await getProposal({ feedId });

        await expect(
          daoracle.relay(
            proposal,
            await signedProposal(proposal, notUs),
            await us.getAddress()
          )
        ).to.be.revertedWith("bad signature");
      });

      it("reverts for a proposal with an unrecoverable signature", async () => {
        const proposal = await getProposal({ feedId });

        await expect(
          daoracle.relay(
            proposal,
            ethers.constants.HashZero,
            ethers.constants.AddressZero
          )
        ).to.be.revertedWith("bad signature");
      });

      it("reverts for a duplicate proposal", async () => {
        const [us] = await ethers.getSigners();
        const proposal = await getProposal({ feedId });

        const signed = await signedProposal(proposal);

        await expect(daoracle.relay(proposal, signed, await us.getAddress()))
          .not.to.be.reverted;

        await expect(
          daoracle.relay(proposal, signed, await us.getAddress())
        ).to.be.revertedWith("duplicate proposal");
      });

      it("reverts for an earlier proposal", async () => {
        const [us] = await ethers.getSigners();
        const firstProposal = await getProposal({ feedId });
        const earlierProposal = await getProposal({
          feedId,
          timestamp: firstProposal.timestamp - 1,
        });

        await expect(
          daoracle.relay(
            firstProposal,
            await signedProposal(firstProposal),
            await us.getAddress()
          )
        ).not.to.be.reverted;

        await expect(
          daoracle.relay(
            earlierProposal,
            await signedProposal(earlierProposal),
            await us.getAddress()
          )
        ).to.be.revertedWith("must be later than most recent proposal");
      });
    });

    describe("Disputing", () => {
      let proposal: Proposal;
      let proposalId: string;
      let pool: DAOraclePool;

      beforeEach(async () => {
        const [us, staker] = await ethers.getSigners();

        pool = (await ethers.getContractAt(
          "DAOraclePool",
          await daoracle.pool(DAI)
        )) as DAOraclePool;

        await daiToken.connect(staker).approve(pool.address, toUnits("5000"));
        await pool.connect(staker).mint(toUnits("5000"));

        proposal = await getProposal({ feedId });
        proposalId = await daoracle._proposalId(
          proposal.timestamp,
          proposal.value,
          proposal.data
        );
        await daoracle.relay(
          proposal,
          await signedProposal(proposal),
          await us.getAddress()
        );
      });

      it("is allowed prior to expiration", async () => {
        await expect(daoracle.dispute(proposalId)).not.to.be.reverted;
      });

      it("reverts after expiration", async () => {
        await increaseTime(10 * 60);
        await expect(daoracle.dispute(proposalId)).to.be.revertedWith(
          "proposal already disputed or expired"
        );
      });

      it("reverts for proposals that don't exist", async () => {
        await increaseTime(10 * 60);
        await expect(
          daoracle.dispute(
            await daoracle._proposalId(
              proposal.timestamp + 1,
              proposal.value,
              proposal.data
            )
          )
        ).to.be.revertedWith("proposal doesn't exist");
      });

      context("when we lose", () => {
        it("slashes the staking pool to recover the lost bond", async () => {
          await daoracle.dispute(proposalId);

          const [
            {
              args: { request },
            },
          ] = await oracle.queryFilter(
            oracle.filters.ProposePrice(daoracle.address),
            -1
          );

          const prevBalance = await daiToken.balanceOf(pool.address);
          const daoracleViaImpersonator = daoracle.connect(
            await impersonate(oracle.address)
          );

          await expect(
            daoracleViaImpersonator.priceSettled(
              feedId,
              proposal.timestamp,
              proposal.data,
              {
                ...request,
                settled: true,
                resolvedPrice: request.proposedPrice.add(1),
              },
              { from: oracle.address }
            )
          )
            .to.emit(pool, "Slash")
            .withArgs(daoracle.address, daiToken.address, request.bond);

          expect(await daiToken.balanceOf(pool.address)).to.equal(
            prevBalance.sub(request.bond)
          );
        });
      });

      context("when we win", () => {
        it("does not slash the staking pool", async () => {
          await daoracle.dispute(proposalId);

          const [
            {
              args: { request },
            },
          ] = await oracle.queryFilter(
            oracle.filters.ProposePrice(daoracle.address),
            -1
          );

          const prevBalance = await daiToken.balanceOf(pool.address);
          const daoracleViaImpersonator = daoracle.connect(
            await impersonate(oracle.address)
          );

          await expect(
            daoracleViaImpersonator.priceSettled(
              feedId,
              proposal.timestamp,
              proposal.data,
              {
                ...request,
                settled: true,
                resolvedPrice: request.proposedPrice,
              },
              { from: oracle.address }
            )
          )
            .to.emit(daoracle, "Settled")
            .and.not.to.emit(pool, "Slash");

          expect(await daiToken.balanceOf(pool.address)).to.be.above(
            prevBalance
          );
        });
      });
    });

    describe("Rewards", () => {
      let feedId: string;

      beforeEach(async () => {
        feedId = ethers.utils.formatBytes32String(
          Buffer.from(ethers.utils.randomBytes(8)).toString("hex")
        );
        await configureFeed(daoracle, undefined, { feedId });
      });

      context("before being claimed", () => {
        it("is 1x the drip reward after 1 second", async () => {
          expect((await daoracle.claimableRewards(feedId)).total).to.equal(
            (await daoracle.feed(feedId)).drop
          );
        });

        it("grows by N times the drip reward after N seconds", async () => {
          for (let seconds of [10, 20, 1 + Math.round(Math.random() * 60)]) {
            const { lastUpdated } = await daoracle.feed(feedId);
            await increaseTime(seconds);
            expect((await daoracle.claimableRewards(feedId)).total).to.equal(
              (await daoracle.feed(feedId)).drop.mul(
                (await lastBlock()).timestamp - lastUpdated
              )
            );
          }
        });
      });

      context("the relayer's share", () => {
        it("starts one tick above the floor", async () => {
          const rewards = await daoracle.claimableRewards(feedId);
          expect(rewards.reporterAmount).to.equal(
            rewards.total.mul(31).div(100)
          );
        });

        it("is ten ticks higher at ten seconds", async () => {
          await increaseTime(10);
          const rewards = await daoracle.claimableRewards(feedId);
          expect(rewards.reporterAmount).to.equal(
            rewards.total.mul(40).div(100)
          );
        });

        it("hits the ceiling at twenty seconds", async () => {
          await increaseTime(20);
          const rewards = await daoracle.claimableRewards(feedId);
          expect(rewards.reporterAmount).to.equal(rewards.total.div(2));
        });

        it("stops at the ceiling", async () => {
          await increaseTime(100);
          const rewards = await daoracle.claimableRewards(feedId);
          expect(rewards.reporterAmount).to.equal(rewards.total.div(2));
        });
      });

      context("the pool's share", () => {
        it("is the total minus the other rewards", async () => {
          const {
            poolAmount,
            reporterAmount,
            residualAmount,
            total,
          } = await daoracle.claimableRewards(feedId);

          expect(poolAmount).to.equal(
            total.sub(reporterAmount).sub(residualAmount)
          );
        });

        it("decreases over time", async () => {
          await increaseTime(50);
          const {
            poolAmount,
            reporterAmount,
            total,
          } = await daoracle.claimableRewards(feedId);
          expect(poolAmount).to.equal(
            total.sub(reporterAmount).mul(99).div(100)
          );
        });
      });

      context("the methodologist's share", () => {
        it("is 1% of the pool's share", async () => {
          const {
            poolAmount,
            residualAmount,
          } = await daoracle.claimableRewards(feedId);

          expect(residualAmount).to.equal(
            poolAmount.add(residualAmount).div(100)
          );
        });

        it("is immediately delivered to the methodologist", async () => {
          const [us, methodologist] = await ethers.getSigners();
          const feedId = ethers.utils.formatBytes32String("DUDE-1m-WTF");

          await configureFeed(daoracle, undefined, {
            feedId,
            hat: methodologist.address,
          });
          await increaseTime(1);

          const proposal = await getProposal({ feedId });
          await expect(async () =>
            daoracle.relay(
              proposal,
              await signedProposal(proposal),
              await us.getAddress()
            )
          ).to.changeTokenBalance(
            daiToken,
            methodologist,
            (await daoracle.claimableRewards(feedId)).residualAmount
          );
        });
      });
    });
  });
});
