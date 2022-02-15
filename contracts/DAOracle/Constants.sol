// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

contract Constants {
  // Roles (for AccessControl)
  bytes32 public immutable MANAGER = keccak256("MANAGER");
  bytes32 public immutable ORACLE = keccak256("ORACLE");
  bytes32 public immutable PROPOSER = keccak256("PROPOSER");

  // Hashed Types (for EIP-712 Verification)
  bytes32 public immutable PROPOSAL_TYPEHASH =
    keccak256(
      abi.encodePacked(
        "Proposal(bytes32 feedId,uint32 timestamp,int256 value,bytes32 data)"
      )
    );
}
