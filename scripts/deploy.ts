import { ethers } from "hardhat";

//const SKINNY_OO_ADDRESS = "0x4060dba72344da74edaeeae51a71a57f7e96b6b4";
//const VOL_TOKEN_ADDRESS = "0x5166e09628b696285e3a151e84fb977736a83575";
const rSKINNY_OO_ADDRESS = "0xAbE04Ace666294aefD65F991d78CE9F9218aFC67";
const rDAI_TOKEN_ADDRESS = "0xc7AD46e0b8a400Bb3C915120d284AafbA8fc4735";
const OO_FEED_ID = ethers.utils.formatBytes32String("VolatilityDAOracle");

async function main() {
  // 1) Deploy the VestingVault
  const vault = await (
    await ethers.getContractFactory("VestingVault")
  ).deploy();
  console.log("VestingVault deployed to:", vault.address);

  // 2) Deploy the DAOracleHelpers library
  const helpersLib = await (
    await ethers.getContractFactory("DAOracleHelpers")
  ).deploy();
  console.log("DAOracleHelpers library deployed to:", helpersLib.address);

  // 3) Deploy the SkinnyDAOracle w/ linked helper library
  const daoracle = await (
    await ethers.getContractFactory("SkinnyDAOracle", {
      libraries: {
        DAOracleHelpers: helpersLib.address,
      },
    })
  ).deploy(OO_FEED_ID, rSKINNY_OO_ADDRESS, vault.address);
  console.log("SkinnyDAOracle deployed to:", daoracle.address);

  // 3a) Deploy a SponsorPool (this is technically optional, but useful)
  const backer = await (await ethers.getContractFactory("SponsorPool")).deploy(
    rDAI_TOKEN_ADDRESS
  );
  console.log("SponsorPool deployed to:", backer.address);

  // 4) Configure a feed
  // await daoracle.configureFeed(
  //   VOL_TOKEN_ADDRESS, // bondToken = VOL
  //   ethers.utils.parseEther("1000"), // bondAmount = 1000 VOL
  //   "MFIV-14D-ETH", // feedId = MFIV-14D-ETH
  //   10 * 60, // ttl = 10 minutes
  //   ethers.utils.parseEther("0.1"), // floor = 10%
  //   ethers.utils.parseEther("0.9"), // ceiling = 90%
  //   ethers.utils.parseEther("0.005"), // tilt = 0.5% per second
  //   ethers.utils.parseEther("1000"), // drop = 10 VOL per second
  //   ethers.utils.parseEther("0.01"), // tip = 1% of pool reward
  //   backer.address, // hat = backer's address
  //   backer.address // backer = backer's address
  // );
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
