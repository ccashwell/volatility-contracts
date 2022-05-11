This document describes how to deploy and set up the DAOracle.

## Deploy Contracts and Verify Rinkeby

1. Deploy contracts to Rinkeby:

`npx hardhat run scripts/deploy.ts --network rinkeby`

Copy addresses and place them here (use find and replace):

    * Rinkeby
       * VestingVault deployed to: `0x908b00b8265ae7E1C3ba69c9B3E00e5D97b03F5F`
       * DAOracleHelpers library deployed to: `0xC44b0D7A072227ac15352D9FF35307E7873444fB`
       * SkinnyDAOracle deployed to: `0x0f98c603B7962e845ae1B00a23c836C08AA8b922`
       * SponsorPool deployed to: `0x703aA92C4628B44E2c2fAA62A5862Dcc9381c639`

2. Verify SkinnyDAOracle on Etherscan:

 `npx hardhat verify --network rinkeby SKINNY_DAORACLE_ADDRESS "PARAMETER_1" "PARAMETER_2" "PARAMETER_3"`

Example:
```
npx hardhat verify --network rinkeby "0x0f98c603B7962e845ae1B00a23c836C08AA8b922" "0x566f6c6174696c69747944414f7261636c650000000000000000000000000000" "0xAbE04Ace666294aefD65F991d78CE9F9218aFC67" "0x908b00b8265ae7E1C3ba69c9B3E00e5D97b03F5F"
```
where

PARAMETER_1 = OO_FEED_ID = `"0x566f6c6174696c69747944414f7261636c650000000000000000000000000000"` 
 
PARAMETER_2 = rSKINNY_OO_ADDRESS = `"0xAbE04Ace666294aefD65F991d78CE9F9218aFC67"`

PARAMETER_3 = Vesting Vault Address = Look up from 1. above

3. Verify SponsorPool on Etherscan:

`npx hardhat verify --network rinkeby SPONSOR_POOL_ADDRESS "PARAMETER_1"`

EXAMPLE:
```
npx hardhat verify --network rinkeby 0x703aA92C4628B44E2c2fAA62A5862Dcc9381c639 "0xc7AD46e0b8a400Bb3C915120d284AafbA8fc4735"
```

where

PARAMETER_1 = DEFAULT_TOKEN_ADDRESS = `"0xc7AD46e0b8a400Bb3C915120d284AafbA8fc4735"`

4. Verify UMA has added price identifier and DEFAULT_TOKEN_ADDRESS to the Skinny00. Only once. For mainnet, this is done through a UMIP.

5. Update daoracleUtils.ts with addresses.
    * SkinnyDAOracle
    * VestingVault

## Set Roles

1. Set DAO multi-sig as Default Admin:
    * SkinnyDAOracle on Rinkeby -> Contract -> Write Tab -> 3. grantRole
    * role(bytes32): `0x0000000000000000000000000000000000000000000000000000000000000000`
    * account(address): DAO_MULTI_SIG_ADDRESS

2. Set DAO multi-sig as Manager:
    * SkinnyDAOracle on Rinkeby -> Contract -> Write Tab -> 3. grantRole
    * role(bytes32): `0xaf290d8680820aad922855f39b306097b20e28774d6c1ad35a20325630c3a02c`
    * account(address): DAO_MULTI_SIG_ADDRESS

3. Set Proposer:
    * SkinnyDAOracle on Rinkeby -> Contract -> Write Tab -> 3. grantRole
    * role(bytes32): `0xc4338366b9cfc07901c46677a3a32746bd05d5c114e4d0d293c468cff87acde0`
    * account(address): PROPOSER_ADDRESS

## Configure Index

1. Configure Index using Manager. Lookup parameters from PIP. Below are the testnet values:
    * SkinnyDAOracle on Rinkeby -> Contract -> Write Tab -> 1. configureIndex
    * bondToken (address):`0xc7AD46e0b8a400Bb3C915120d284AafbA8fc4735`
    * bondAmount (uint256): `7150000000000000000000`
    * indexId (bytes32): `0x4d4649562d3134442d455448` (MFIV-14D-ETH)
    * disputePeriod (uint32): `600`
    * floor (uint64): `800000000000000000`
    * ceiling (uint64): `950000000000000000`
    * tilt (uint64): `10000000000000`
    * drop (uint256): `627602980211511000`
    * creatorAmount (unit64): `3000000000000000`
    * creatorAddress (address): `0xf1C2Ddc3B95c7AaC5aaf31849753B1891023F5Dd`
    * sponsor(address): `0x0000000000000000000000000000000000000000`

2. 0x00 generates a new SponsorPool Address. Look up the new SponsorPool Address:
    * SkinnyDAOracle on Rinkeby -> Contract -> Read Tab -> 12. index
    * input (bytes32): `0x4d4649562d3134442d455448`(MFIV-14D-ETH)

    Copy and place new sponsor pool address here:
        * `0x78c08d7242c80279fcd712E87B7197819a7d37b9`

## Set Pool Fees

1. Set Pool Fees using Manager:
    * SkinnyDAOracle on Rinkeby -> Contract -> Write Tab -> 10. setPoolFees
    * token (address): `0xc7AD46e0b8a400Bb3C915120d284AafbA8fc4735` (the bond token)
    * mintFee (uint256): `10000000000000000` (10^16 = 1% || 10^18 = 100%)
    * burnFee (uint256): `10000000000000000` (10^16 = 1% || 10^18 = 100%)
    * payee (address): `0x78c08d7242c80279fcd712E87B7197819a7d37b9` (SponsorPool)
    * NOTE: The sponsor pool should always be the payee.
    * NOTE: Because fees are the check to keep stakers from flash removing stakes on incoming slash.

**TESTS**
-[] Can you set the pool fees to 100%: `1000000000000000000`? (FAIL)
## Fund SponsorPool

1. Set approval for the SponsorPool to Spend the DAO multi-sig token. Must be sent from the DAO multi-sig.
    * DAI Contract on Rinkeby: `0xc7AD46e0b8a400Bb3C915120d284AafbA8fc4735` -> Contract -> Write Tab -> 1. approve
    * usr (address): `0x78c08d7242c80279fcd712E87B7197819a7d37b9`
    * wad (unit256): `115792089237316195423570985008687907853269984665640564039457584007913129639935`
    * NOTE: usr should be SponsorPool address that you look up in step 2.
    * NOTE: wad should be amount to send * 10^18 + 100
    * NOTE: Reset approval on mainnet to 0 after mint

2. Deposit into the newly created SponsorPool with Mint (See TESTs below before minting):
    * SponsorPool Contract:`0x78c08d7242c80279fcd712E87B7197819a7d37b9`  on Rinkeby -> Contract -> Write Tab -> 6. mint
    * _stakeAmount (uint256): amount to send * 10^18


**TESTS**
-[ ] Fund SponsorPool with less than enough tokens to cover a bond but more than enough to pay rewards. Can you relay? (FAIL)
-[ ] Fund SponsorPool with 10 million tokens. Can you relay? (PASS)

## Fund StakingPool

1. Stake on the DAOracle website. Approval for the Token should be requested. If not, then follow the same steps for funding the SponsorPool. If you cannot find the StakingPool address you can relay an index. The staking pool will be the first address that the DAOracle contract sends to.

**TESTS**
You will need to return bonds from UMA to complete some of these tests.

-[] Stake 100 tokens. Is 1% taken and moved to the SponsorPool as a fee? (PASS)
-[] Stake 0.00000001 tokens. Is 1% taken out? (PASS)
-[] Note on above. If you relayed already, then you will have more than 100 DAI in pool. Do you get those tokens?
-[] If more than 100 tokens in unstake all and stake 100 again.
-[] Unstake all tokens. Is 1% taken and moved to the SponsorPool as a fee? (PASS)
-[] Stake 1000 tokens. Return a bond from UMA as lost. Is the entire StakingPool slashed?(PASS)
-[] Stake 100,000 tokens. Check the accounting tokens. Is there a bug? Can you withdraw your full amount?
-[] Return a bond from UMA as lost. Is the correct amount from the StakingPool slashed? (PASS)

## SET VESTING TIME

1. Go to SkinnyDAOracle on Etherscan: `0x0f98c603B7962e845ae1B00a23c836C08AA8b922`

2. Contract -> Write -> Set Vesting Parameters (USE MANAGER)
    * vestingTime (uint32) = `300`
    * cliffTime (uint32) = `300` (This is one day)
    * NOTE: for cliff vesting make the vestingTime and cliffTime the same length.

3. Set cliff time to 6 months if everything passes: `15768000`

**TESTS**
-[] Set cliff to 5 minuts. Can you claim your rewards after a day?  (PASS)


## Returning Bonds From UMA

First you must push the price from the DVM:
1. Go to Skinny OO contract: `0xAbE04Ace666294aefD65F991d78CE9F9218aFC67`
2. Contract -> Read -> 3. Finder -> Go to contract: `0xbb6206fb01fAad31e8aaFc3AD303cEA89D8c8157`
3. Contract -> Read -> 1. getImplementationAddress -> Enter 'Oracle' as byte32 = `0x4f7261636c65`
4. Go to returned contract: `0xd227E520A3328eAe29951DEc5aF8162A5Bfb7fB0`
5. Contract -> Write -> 1.Push Price:
    * It is easiest to put the dispute transaction into tenderly.co -> events -> PriceRequestAdd contains all params.
    * Or look on etherscan at the dispute tx:
        1. Transaction -> Logs
        2. 9th log contains the following:
            * identifier (bytes32) -> topic 2 (NOTE: change to Hex)
            * time (uint256) -> this is labeled 
            * ancillaryData -> this is labeled (NOTE: you must place 0x in front of value & this is the appended data)
        3. If you want to return Proposer winning DVM use the following for price:
            * Go to the 4th log. It is the first log with lots of Hex.
            * Change the 7th Hex to Num.
            * Alternately you can use a tool like Tenderly to decode everything.
            * price(uint256) = 4th Log, 7th Hex to Num.
        4. If you want to return Disputer winning DVM use any other price:
            * price(uint256) = 999

Now return the price from the SkinnyOO:

1. Go to the SkinnyOO: `0xAbE04Ace666294aefD65F991d78CE9F9218aFC67`
2. Contract -> Write -> 10. Settle:
    * It's easiest to use Tenderly.co and look at the Dispute tx -> events -> DisputePrice
    * You can use the transaction log from the DVM transaction to fill out most values:
        * requester (address) = `0xb380E171C0E559335b70eC02E16b783eF59f9F1D` (SkinnyDAOracle)
        * identifier (bytes32) = topic2 as Hex
        * timestamp (uint32)  = labeled time
        * ancillaryData (bytes) = labeled add an 0x to front & Remove anything appended
        * request (tuple) = See Below

**Formatting The Tuple Parameter**

The below data (except for format) is accessible from the solidity contracts and from looking at the dispute transaction in tenderly.

The parameter is an array built from the following Struct in the SkinnyOO contract:
```
    struct Request {
        address proposer; // Address of the proposer.
        address disputer; // Address of the disputer.
        IERC20 currency; // ERC20 token used to pay rewards and fees.
        bool settled; // True if the request is settled.
        int256 proposedPrice; // Price that the proposer submitted.
        int256 resolvedPrice; // Price resolved once the request is settled.
        uint256 expirationTime; // Time at which the request auto-settles without a dispute.
        uint256 reward; // Amount of the currency to pay to the proposer on settlement.
        uint256 finalFee; // Final fee to pay to the Store upon request to the DVM.
        uint256 bond; // Bond that the proposer and disputer must pay on top of the final fee.
        uint256 customLiveness; // Custom liveness value set by the requester.
    }
```
It's derived from the request within the dispute call. Here is an example:

```
"request":{
"bond":"7150000000000000000000"
"currency":"0xc7ad46e0b8a400bb3c915120d284aafba8fc4735"
"customLiveness":"600"
"disputer":"0x06985aa459afaa7dd2a33f0e873bc297f2f2978f"
"expirationTime":"1651176318"
"finalFee":"0"
"proposedPrice":"6800091699018354"
"proposer":"0xb380e171c0e559335b70ec02e16b783ef59f9f1d"
"resolvedPrice":"0"
"reward":"0"
}

```
For the most part these variable will remain the same. However, you need to format them as the Struct in an array and certain ints need to be strings. Here is an example below:

```
["0xb380e171c0e559335b70ec02e16b783ef59f9f1d",  // proposer
"0x06985aa459afaa7dd2a33f0e873bc297f2f2978f",  // disputer
"0xc7AD46e0b8a400Bb3C915120d284AafbA8fc4735",  // currency
false, // bool settled
"7183987651760616", // proposed price
0, // resolved price
1651002098, // expiration time
0, // reward
0, //final fee
"7150000000000000000000", //bond
600] // custom liveness

```

Formatted below with out comments so you can easily copy pasta:
NOTE: when filling this out it is best to look up the Dispute from the SkinnyOO and paste the tx into Tenderly.
Then look at events and copy the values from dispute price for.
NOTE:  resolvedPrice always 0

```
["0x0f98c603B7962e845ae1B00a23c836C08AA8b922","0x06985aa459afaa7dd2a33f0e873bc297f2f2978f","0xc7ad46e0b8a400bb3c915120d284aafba8fc4735",false,"7089898894349265",0,1651680969,0,0,"7150000000000000000000",600]

```

## ADDITIONAL TESTS

Verify the following checklists. (PASS / FAIL) denotes whether the test should pass or fail. E.g. FAIL means you should NOT be able to execute when testing.

### STAKING TESTS
-[] Can you stake from DAOracle website? (PASS)
    -[] Are you charged the fee for staking? (PASS)
-[] Can you unstake from the DAOracle website? (PASS)
    -[] Are you charged the fee for unstaking? (PASS)

### RELAY TESTS

-[] Can you relay from DAOracle website? (PASS)
    -[] Are tokens sent to the correct addresses?
        * Pigeon Vesting
        * Creator
        * StakingPool
-[] Can you relay if there is NOT enough tokens to cover rewards? (FAIL)
-[] Can you relay if there is enough tokens to cover rewards but NOT a bond? (FAIL)
-[] Can you relay proposals besides the most recent? (FAIL)
-[] Can you relay after maximum number of bonds are out? (FAIL)

### VESTING TESTS

-[] Can you claim tokens before waterfall period is up? (FAIL)
-[] Can you claim tokens after waterfall period is up? (PASS)

### DISPUTE TESTS
-[] Can you dispute from the website if you have enough tokens to post bond? (PASS)
-[] Can you dispute from the website if you do NOT have enough tokens to post bond? (PASS)
-[] Are the correct bond amounts taken from your wallet and SponsorPool? (PASS)

### RETURN DISPUTE TESTS

-[] On DVM win does the Sponsor Pool receive all tokens (bond + winnings)? (PASS)
-[] On DVM loss is Staking Pool slashed for bond amount and is it deposited in Sponsor Pool? (PASS)
    -[] Does the staking Pool slash all tokens if there are not enough tokens to cover the bond? 

### MIX TESTS
-[] Return a bond so one less than maximum number is out, can you relay? (PASS)

### VERIFY UI TESTS
-[] Change the index values for floor, drip, ceiling, etc. Do these reflect in the UI? (PASS)
-[] Change the vesting values. Do these reflect in the UI?