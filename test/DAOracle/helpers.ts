import { BigNumberish } from "ethers";
import { parseEther } from "@ethersproject/units";
import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers";
import { ContractTransaction } from "ethers";
import * as hre from "hardhat";
import { SkinnyDAOracle } from "../../typechain";

import {
  giveEther,
  impersonate,
  increaseTime,
  lastBlock,
  toUnits,
} from "../utils";

export const DAI = "0x6B175474E89094C44Da98b954EedeAC495271d0F";
export const DAI_WARD = "0x9759A6Ac90977b93B58547b4A71c78317f391A28";
export const ORACLE = "0x4060dba72344da74edaeeae51a71a57f7e96b6b4";
export const INDEX_ID = hre.ethers.utils.formatBytes32String("MFIV-14D-ETH");

export async function giveDai(receivers: string[], amount = toUnits(100000)) {
  const daiMinter = "0x9759A6Ac90977b93B58547b4A71c78317f391A28";
  const daiToken = await hre.ethers.getContractAt(
    ["function mint(address usr, uint wad)"],
    "0x6B175474E89094C44Da98b954EedeAC495271d0F",
    await impersonate("0x9759A6Ac90977b93B58547b4A71c78317f391A28")
  );

  await giveEther(daiMinter);
  for (const receiver of receivers) await daiToken.mint(receiver, amount);
}

export type Proposal = {
  indexId: string;
  timestamp: number;
  value: number;
  data: string;
};

export async function getProposal(
  options: Partial<Proposal> = {}
): Promise<Proposal> {
  let { indexId, timestamp, value, data } = options;
  return {
    indexId: indexId ?? INDEX_ID,
    timestamp: timestamp ?? (await lastBlock()).timestamp,
    value: value ?? Math.round(Math.random() * 250),
    data: data ?? hre.ethers.utils.formatBytes32String(`id:MFIV-14D-ETH`),
  };
}

export async function configureIndex(
  daoracle: SkinnyDAOracle,
  as?: SignerWithAddress,
  config?: {
    bondToken?: string;
    bondAmount?: BigNumberish;
    indexId?: string;
    disputePeriod?: BigNumberish;
    floor?: BigNumberish;
    ceiling?: BigNumberish;
    tilt?: BigNumberish;
    drop?: BigNumberish;
    creatorAmount?: BigNumberish;
    creatorAddress?: string;
    sponsor?: string;
  }
): Promise<ContractTransaction> {
  if (as) {
    daoracle = daoracle.connect(as);
  }

  return daoracle.configureIndex(
    config?.bondToken ?? DAI, // bondToken = DAI
    config?.bondAmount ?? parseEther("1"), // bondAmount = 1 DAI
    config?.indexId ?? INDEX_ID, // indexId = bytes32("MFIV")
    config?.disputePeriod ?? 600, // disputePeriod = 600 seconds
    config?.floor ?? parseEther("0.3"), // reporter floor = 30%
    config?.ceiling ?? parseEther("0.5"), // reporter ceiling = 50%
    config?.tilt ?? parseEther("0.01"), // change rate = 1%/sec
    config?.drop ?? parseEther("1"), // drip = 1 DAI/sec
    config?.creatorAmount ?? parseEther("0.01"), // creatorAmount = 1% of pool reward
    config?.creatorAddress ?? hre.ethers.constants.AddressZero,
    config?.sponsor ?? daoracle.address
  );
}

export async function setMaxOutstandingDisputes(
	daoracle: SkinnyDAOracle,
  maxOutstandingDisputes?: BigNumberish,
	as?: SignerWithAddress,
  ): Promise<ContractTransaction> {
	if (as) {
	  daoracle = daoracle.connect(as);
	}
  
	return daoracle.setMaxOutstandingDisputes(
    maxOutstandingDisputes ?? parseEther("3")
	);
}

export async function setExternalIdentifier(
	daoracle: SkinnyDAOracle,
	externalIdentifier?: string,
	as?: SignerWithAddress,
  ): Promise<ContractTransaction> {
	if (as) {
	  daoracle = daoracle.connect(as);
	}
  
	return daoracle.setExternalIdentifier(
		externalIdentifier ?? hre.ethers.utils.formatBytes32String("VolatilityDAOracle")
	);
}
/*
export async function setMaxOutstandingDisputes(
	daoracle: SkinnyDAOracle,
	maxOutstandingDisputes?: BigNumberish,
	as?: SignerWithAddress,
  ): Promise<ContractTransaction> {
	if (as) {
	  daoracle = daoracle.connect(as);
	}
  
	return daoracle.setMaxOutstandingDisputes(
		maxOutstandingDisputes ?? parseEther("3")
	);
}
*/
export const signProposal = async (
  daoracle: SkinnyDAOracle,
  proposal: Proposal,
  signer?: SignerWithAddress
) => {
  const lastBlockTimestamp = (await hre.ethers.provider.getBlock("latest"))
    .timestamp;
  if (lastBlockTimestamp < proposal.timestamp) {
    await increaseTime(proposal.timestamp - lastBlockTimestamp);
  }

  if (!signer) {
    [signer] = await hre.ethers.getSigners();
  }

  const signature = signer._signTypedData(
    {
      name: "DAOracle",
      version: "1",
      chainId: (await hre.ethers.provider.getNetwork()).chainId,
      verifyingContract: daoracle.address,
    },
    {
      Proposal: [
        { name: "indexId", type: "bytes32" },
        { name: "timestamp", type: "uint32" },
        { name: "value", type: "int256" },
        { name: "data", type: "bytes32" },
      ],
    },
    {
		indexId: proposal.indexId,
      timestamp: proposal.timestamp,
      value: proposal.value,
      data: proposal.data,
    }
  );

  return signature;
};
