This document describes how to deploy and set up the DAOracle.

## Deploy Contracts and Verify Rinkeby

1. Deploy contracts to Rinkeby:

`npx hardhat run scripts/deploy.ts --network rinkeby`

2. Verify SkinnyDAOracle on Etherscan:

 `npx hardhat verify --network rinkeby SKINNY_DAORACLE_ADDRESS "PARAMETER_1" "PARAMETET_2" "PARAMETER_3"`

where

PARAMETER_1 = OO_FEED_ID = `"0x566f6c6174696c69747944414f7261636c650000000000000000000000000000"` 
 
PARAMETER_2 = rSKINNY_OO_ADDRESS = `"0xAbE04Ace666294aefD65F991d78CE9F9218aFC67"`

PARAMETER_3 = Vesting Vault Address = Look up from 1. above

3. Verify SponsorPool on Etherscan:

`npx hardhat verify --network rinkeby SPONSOR_POOL_ADDRESS "PARAMETER_1"`

where

PARAMETER_1 = DEFAULT_TOKEN_ADDRESS = `"0xc7AD46e0b8a400Bb3C915120d284AafbA8fc4735"`

4. Verify UMA has added price identifier and DEFAULT_TOKEN_ADDRESS to the Skinny00. Only once. For mainnet, this is done through a UMIP.

5. Copy addresses and place them here:

    * Rinkeby
        * VestingVault deployed to: `0x60551A9e914F661f25856A6AB2bD856D443e41a6`
        * DAOracleHelpers library deployed to: `0x4b928e28E05A4546411e7F8A229AB744BDb965BB`
        * SkinnyDAOracle deployed to: `0xb380E171C0E559335b70eC02E16b783eF59f9F1D`
        * SponsorPool deployed to: `0xCa5470656635D0321108B246922C7530af989EC1`

6. Update daoracleUtils.ts with addresses.

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

## Configure Index and Fund SponsorPool

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
        * `0xC9a27efb05eCb140DF213A5513C09417e81939d5`

3. Set approval for the SponsorPool to Spend the DAO multi-sig token. Must be sent from the DAO multi-sig.
    * DAI Contract on Rinkeby -> Contract -> Write Tab -> 1. approve
    * usr (address): `0xC9a27efb05eCb140DF213A5513C09417e81939d5`
    * wad (unit256): `115792089237316195423570985008687907853269984665640564039457584007913129639935`
    * NOTE: usr should be SponsorPool address that you look up in step 2.
    * NOTE: wad should be amount to send * 10^18 + 100
    * NOTE: Reset approval on mainnet to 0 after mint

4. Deposit into the SponsorPool with Mint:
    * SponsorPool Contract on Rinkeby -> Contract -> Write Tab -> 6. mint
    * _stakeAmount (uint256): amount to send * 10^18

## Fund StakingPool

1. Stake on the DAOracle website. Approval for the Token should be requested. If not, then follow the same steps for funding the SponsorPool. If you cannot find the StakingPool address you can relay an index. The staking pool will be the first address that the DAOracle contract sends to.

## Returning Bonds From UMA

First you must push the price from the DVM:
1. Go to Skinny OO contract: `0xAbE04Ace666294aefD65F991d78CE9F9218aFC67`
2. Contract -> Read -> 3. Finder -> Go to contract: `0xbb6206fb01fAad31e8aaFc3AD303cEA89D8c8157`
3. Contract -> Read -> 1. getImplementationAddress -> Enter 'Oracle' as byte32 = `0x4f7261636c65`
4. Go to returned contract: `0xd227E520A3328eAe29951DEc5aF8162A5Bfb7fB0`
5. Contract -> Write -> 1.Push Price:
    * Find the parameters for push price by looking at the dispute transaction that was disputed on etherscan:
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
["0xb380e171c0e559335b70ec02e16b783ef59f9f1d","0x06985aa459afaa7dd2a33f0e873bc297f2f2978f","0xc7ad46e0b8a400bb3c915120d284aafba8fc4735",false,"6441456720927799",0,1651253972,0,0,"7150000000000000000000",600]

```

## Tests

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