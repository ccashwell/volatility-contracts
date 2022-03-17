# Volatility Smart Contracts

Our smart contracts are as follows:

## DAOracle
The Volatility DAOracle is a collection of methodologies and implementations for indices and benchmarks. Each index can be verified by decentralized users through its data endpoint, open-source code, and methodology paper. This information can be looked up through the `requestAndProposePriceFor` call to the [SkinnyOO](https://docs-git-doc-updates-uma.vercel.app/contracts/oracle/implementation/SkinnyOptimisticOracle#parameters-4) where the following parameters can be used to query any of the indices in the Volatility DAOracle:

* `identifier`: price identifier to identify the existing request.
* `timestamp`: timestamp of the data snapshot to identify the existing request.
* `ancillaryData`: ancillary data of the price being requested.

### Ethereum Mainnet Contracts
| Contract Name | Address | Etherscan |
| --- | --- | --- |
| SkinnyDAOracle | `0xe828850f4439603fE8b1C05e7Ec72ae378A96498` | [Link](https://etherscan.io/address/0xe828850f4439603fE8b1C05e7Ec72ae378A96498) |
| DAOracleHelpers | `0x31B678C26bEf78D6958989469eeB327D6c7f0c58` | [Link](https://etherscan.io/address/0x31B678C26bEf78D6958989469eeB327D6c7f0c58) |
| VestingVault | `0xC964d591Fc1B2825471F5F6c7630241368599671` | [Link](https://etherscan.io/address/0xC964d591Fc1B2825471F5F6c7630241368599671) |
| SponsorPool | `0x59AE6ccc5de8457Df67664AC7A9B019eE32c71f8` | [Link](https://etherscan.io/address/0x59AE6ccc5de8457Df67664AC7A9B019eE32c71f8) |


### Development
If you'd like to run our contracts locally or test them, you'll need [Hardhat](https://hardhat.org/) installed. 

1. Run `yarn` to get set up.
2. Run `yarn compile` to compile the latest smart contracts.
3. Run `yarn test` to run the test suite and get metrics such as gas estimates for the contracts.

If you'd like to contribute, have questions, ideas, or concerns about the Volatility DAOracle, please reach out to us on our [Discord](https://discord.gg/KswTYYKu).