import "@typechain/hardhat";
import "@nomiclabs/hardhat-waffle";
import "@nomiclabs/hardhat-ethers";
import "@nomiclabs/hardhat-etherscan";
import "hardhat-docgen";
import "hardhat-gas-reporter";
import "hardhat-tracer";
import "solidity-coverage";

import { HardhatUserConfig, task } from "hardhat/config";
import * as dotenv from "dotenv";

dotenv.config();

/**
 * @type import('hardhat/config').HardhatUserConfig
 */

 task("accounts", "Prints the list of accounts", async (taskArgs, hre) => {
  const accounts = await hre.ethers.getSigners();

  for (const account of accounts) {
    console.log(account.address);
  }
});

const config: HardhatUserConfig = {
  // Your type-safe config goes here
  solidity: {
    compilers: [
      {
        version: "0.8.7",
        settings: {},
      },
    ],
  },
  networks: {
    hardhat: {},
    rinkeby: {
      url: `https://eth-rinkeby.alchemyapi.io/v2/${process.env.ALCHEMY_API_KEY}`,
      accounts: [process.env.RINKEBY_PRIVATE_KEY as string],
    },
  },
  etherscan: {
    apiKey: process.env.ETHERSCAN_API_KEY,
  },
};

export default config;
