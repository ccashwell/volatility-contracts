import { Signer } from "@ethersproject/abstract-signer";
import * as hre from "hardhat";

export const mineBlockNumber = async (blockNumber: number) => {
  return rpc({ method: "evm_mineBlockNumber", params: [blockNumber] });
};

export const mineBlock = async () => {
  return rpc({ method: "evm_mine" });
};

export const increaseTime: (seconds: number) => Promise<unknown> = async (seconds) => {
  await rpc({ method: "evm_increaseTime", params: [seconds] });
  return rpc({ method: "evm_mine" });
};

// doesn't work with hardhat
export const setTime = async (seconds: number) => {
  await rpc({ method: "evm_setTime", params: [new Date(seconds * 1000)] });
};

// doesn't work with hardhat
export const freezeTime = async (seconds: number) => {
  await rpc({ method: "evm_freezeTime", params: [seconds] });
  return rpc({ method: "evm_mine" });
};

// adapted for both truffle and hardhat
export const advanceBlocks = async (blocks: number) => {
  let currentBlockNumber = await blockNumber();
  for (let i = currentBlockNumber; i < blocks; i++) {
    await mineBlock();
  }
};

export const setNextBlockTimestamp = async (timestamp: number) => {
  await rpc({ method: "evm_setNextBlockTimestamp", params: [timestamp] });
};

export const blockNumber = async () => {
  let { result: num }: any = await rpc({ method: "eth_blockNumber" });
  if (num === undefined) num = await rpc({ method: "eth_blockNumber" });
  return parseInt(num);
};

export const lastBlock = async () => {
  return await rpc({
    method: "eth_getBlockByNumber",
    params: ["latest", true],
  });
};

// doesn't work with hardhat
export const minerStart = async () => {
  return rpc({ method: "miner_start" });
};

// doesn't work with hardhat
export const minerStop = async () => {
  return rpc({ method: "miner_stop" });
};

// adapted to work in both truffle and hardhat
export const rpc = async (request: any) => {
  try {
    return await hre.network.provider.request(request);
  } catch (e) {
    if (typeof hre.network != "undefined") console.error(e);
  }
};

export const getAccounts = async (): Promise<Signer[]> => {
  return await hre.ethers.getSigners();
}
