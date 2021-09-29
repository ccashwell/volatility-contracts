import * as hre from "hardhat";
import { RequestArguments } from "hardhat/types";

import { BigNumber, BigNumberish } from "ethers";
import { Block } from "@ethersproject/abstract-provider";
import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers";

// Mine the next block
export async function mineBlock(): Promise<void> {
  await rpc({ method: "evm_mine" });
}

export function toUnits(amount: BigNumberish, unit = "ether"): BigNumber {
  return hre.ethers.utils.parseUnits(amount.toString(), unit);
}

// Advance to a given block (must be later than current block)
export async function advanceToBlock(blockNumber: number): Promise<void> {
  await rpc({ method: "evm_mineBlockNumber", params: [blockNumber] });
}

// Mine N sequential blocks
export async function advanceBlocks(blocks: number): Promise<void> {
  for (let i = await blockNumber(); i < blocks; i++) await mineBlock();
}

// Get the current block number
export async function blockNumber(): Promise<number> {
  return parseInt((await rpc({ method: "eth_blockNumber" })) as string);
}

// Advance the clock by N seconds then mine a block at that time
export async function increaseTime(
  seconds: number,
  mine = true
): Promise<void> {
  await rpc({ method: "evm_increaseTime", params: [seconds] });
  if (mine) await rpc({ method: "evm_mine" });
}

// Set the next block to be mined at a specific timestamp (unix format)
export async function setNextBlockTimestamp(timestamp: number): Promise<void> {
  await rpc({ method: "evm_setNextBlockTimestamp", params: [timestamp] });
}

// Get the latest block (including txs and metadata)
export async function lastBlock(): Promise<Block> {
  return await hre.ethers.provider.getBlock("latest");
}

// Sends a raw RPC request to the provider
export async function rpc(request: RequestArguments): Promise<unknown> {
  return await hre.network.provider.request(request);
}

// Get all signer accounts
export async function getAccounts(): Promise<SignerWithAddress[]> {
  return await hre.ethers.getSigners();
}

// Give some ETH to the given address
export async function giveEther(
  address: string,
  amount: BigNumberish = hre.ethers.utils.parseEther("1")
): Promise<void> {
  await rpc({
    method: "hardhat_setBalance",
    params: [
      address,
      BigNumber.from(amount).toHexString().replace("0x0", "0x"),
    ],
  });
}

// Get a signer that impersonates a given address and give them some gas money
export async function impersonate(
  address: string,
  gasMoney = toUnits("2")
): Promise<SignerWithAddress> {
  await rpc({
    method: "hardhat_impersonateAccount",
    params: [address],
  });
  if (gasMoney) await giveEther(address, gasMoney);
  return hre.ethers.getSigner(address);
}

export async function resetFork(): Promise<void> {
  await rpc({
    method: "hardhat_reset",
    params: [
      {
        forking: {
          url: `https://eth-mainnet.alchemyapi.io/v2/${process.env.ALCHEMY_API_KEY}`,
          blockNumber: 14000000,
        },
      },
    ],
  });
}
