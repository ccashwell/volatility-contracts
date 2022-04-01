/* Autogenerated file. Do not edit manually. */
/* tslint:disable */
/* eslint-disable */

import {
  ethers,
  EventFilter,
  Signer,
  BigNumber,
  BigNumberish,
  PopulatedTransaction,
  BaseContract,
  ContractTransaction,
  Overrides,
  CallOverrides,
} from "ethers";
import { BytesLike } from "@ethersproject/bytes";
import { Listener, Provider } from "@ethersproject/providers";
import { FunctionFragment, EventFragment, Result } from "@ethersproject/abi";
import type { TypedEventFilter, TypedEvent, TypedListener } from "./common";

interface OptimisticOracleInterfaceInterface extends ethers.utils.Interface {
  functions: {
    "ancillaryBytesLimit()": FunctionFragment;
    "disputePrice(address,bytes32,uint256,bytes)": FunctionFragment;
    "disputePriceFor(address,address,bytes32,uint256,bytes)": FunctionFragment;
    "getRequest(address,bytes32,uint256,bytes)": FunctionFragment;
    "getState(address,bytes32,uint256,bytes)": FunctionFragment;
    "hasPrice(address,bytes32,uint256,bytes)": FunctionFragment;
    "proposePrice(address,bytes32,uint256,bytes,int256)": FunctionFragment;
    "proposePriceFor(address,address,bytes32,uint256,bytes,int256)": FunctionFragment;
    "requestPrice(bytes32,uint256,bytes,address,uint256)": FunctionFragment;
    "setBond(bytes32,uint256,bytes,uint256)": FunctionFragment;
    "setCustomLiveness(bytes32,uint256,bytes,uint256)": FunctionFragment;
    "setRefundOnDispute(bytes32,uint256,bytes)": FunctionFragment;
    "settle(address,bytes32,uint256,bytes)": FunctionFragment;
    "settleAndGetPrice(bytes32,uint256,bytes)": FunctionFragment;
    "stampAncillaryData(bytes,address)": FunctionFragment;
  };

  encodeFunctionData(
    functionFragment: "ancillaryBytesLimit",
    values?: undefined
  ): string;
  encodeFunctionData(
    functionFragment: "disputePrice",
    values: [string, BytesLike, BigNumberish, BytesLike]
  ): string;
  encodeFunctionData(
    functionFragment: "disputePriceFor",
    values: [string, string, BytesLike, BigNumberish, BytesLike]
  ): string;
  encodeFunctionData(
    functionFragment: "getRequest",
    values: [string, BytesLike, BigNumberish, BytesLike]
  ): string;
  encodeFunctionData(
    functionFragment: "getState",
    values: [string, BytesLike, BigNumberish, BytesLike]
  ): string;
  encodeFunctionData(
    functionFragment: "hasPrice",
    values: [string, BytesLike, BigNumberish, BytesLike]
  ): string;
  encodeFunctionData(
    functionFragment: "proposePrice",
    values: [string, BytesLike, BigNumberish, BytesLike, BigNumberish]
  ): string;
  encodeFunctionData(
    functionFragment: "proposePriceFor",
    values: [string, string, BytesLike, BigNumberish, BytesLike, BigNumberish]
  ): string;
  encodeFunctionData(
    functionFragment: "requestPrice",
    values: [BytesLike, BigNumberish, BytesLike, string, BigNumberish]
  ): string;
  encodeFunctionData(
    functionFragment: "setBond",
    values: [BytesLike, BigNumberish, BytesLike, BigNumberish]
  ): string;
  encodeFunctionData(
    functionFragment: "setCustomLiveness",
    values: [BytesLike, BigNumberish, BytesLike, BigNumberish]
  ): string;
  encodeFunctionData(
    functionFragment: "setRefundOnDispute",
    values: [BytesLike, BigNumberish, BytesLike]
  ): string;
  encodeFunctionData(
    functionFragment: "settle",
    values: [string, BytesLike, BigNumberish, BytesLike]
  ): string;
  encodeFunctionData(
    functionFragment: "settleAndGetPrice",
    values: [BytesLike, BigNumberish, BytesLike]
  ): string;
  encodeFunctionData(
    functionFragment: "stampAncillaryData",
    values: [BytesLike, string]
  ): string;

  decodeFunctionResult(
    functionFragment: "ancillaryBytesLimit",
    data: BytesLike
  ): Result;
  decodeFunctionResult(
    functionFragment: "disputePrice",
    data: BytesLike
  ): Result;
  decodeFunctionResult(
    functionFragment: "disputePriceFor",
    data: BytesLike
  ): Result;
  decodeFunctionResult(functionFragment: "getRequest", data: BytesLike): Result;
  decodeFunctionResult(functionFragment: "getState", data: BytesLike): Result;
  decodeFunctionResult(functionFragment: "hasPrice", data: BytesLike): Result;
  decodeFunctionResult(
    functionFragment: "proposePrice",
    data: BytesLike
  ): Result;
  decodeFunctionResult(
    functionFragment: "proposePriceFor",
    data: BytesLike
  ): Result;
  decodeFunctionResult(
    functionFragment: "requestPrice",
    data: BytesLike
  ): Result;
  decodeFunctionResult(functionFragment: "setBond", data: BytesLike): Result;
  decodeFunctionResult(
    functionFragment: "setCustomLiveness",
    data: BytesLike
  ): Result;
  decodeFunctionResult(
    functionFragment: "setRefundOnDispute",
    data: BytesLike
  ): Result;
  decodeFunctionResult(functionFragment: "settle", data: BytesLike): Result;
  decodeFunctionResult(
    functionFragment: "settleAndGetPrice",
    data: BytesLike
  ): Result;
  decodeFunctionResult(
    functionFragment: "stampAncillaryData",
    data: BytesLike
  ): Result;

  events: {};
}

export class OptimisticOracleInterface extends BaseContract {
  connect(signerOrProvider: Signer | Provider | string): this;
  attach(addressOrName: string): this;
  deployed(): Promise<this>;

  listeners<EventArgsArray extends Array<any>, EventArgsObject>(
    eventFilter?: TypedEventFilter<EventArgsArray, EventArgsObject>
  ): Array<TypedListener<EventArgsArray, EventArgsObject>>;
  off<EventArgsArray extends Array<any>, EventArgsObject>(
    eventFilter: TypedEventFilter<EventArgsArray, EventArgsObject>,
    listener: TypedListener<EventArgsArray, EventArgsObject>
  ): this;
  on<EventArgsArray extends Array<any>, EventArgsObject>(
    eventFilter: TypedEventFilter<EventArgsArray, EventArgsObject>,
    listener: TypedListener<EventArgsArray, EventArgsObject>
  ): this;
  once<EventArgsArray extends Array<any>, EventArgsObject>(
    eventFilter: TypedEventFilter<EventArgsArray, EventArgsObject>,
    listener: TypedListener<EventArgsArray, EventArgsObject>
  ): this;
  removeListener<EventArgsArray extends Array<any>, EventArgsObject>(
    eventFilter: TypedEventFilter<EventArgsArray, EventArgsObject>,
    listener: TypedListener<EventArgsArray, EventArgsObject>
  ): this;
  removeAllListeners<EventArgsArray extends Array<any>, EventArgsObject>(
    eventFilter: TypedEventFilter<EventArgsArray, EventArgsObject>
  ): this;

  listeners(eventName?: string): Array<Listener>;
  off(eventName: string, listener: Listener): this;
  on(eventName: string, listener: Listener): this;
  once(eventName: string, listener: Listener): this;
  removeListener(eventName: string, listener: Listener): this;
  removeAllListeners(eventName?: string): this;

  queryFilter<EventArgsArray extends Array<any>, EventArgsObject>(
    event: TypedEventFilter<EventArgsArray, EventArgsObject>,
    fromBlockOrBlockhash?: string | number | undefined,
    toBlock?: string | number | undefined
  ): Promise<Array<TypedEvent<EventArgsArray & EventArgsObject>>>;

  interface: OptimisticOracleInterfaceInterface;

  functions: {
    ancillaryBytesLimit(overrides?: CallOverrides): Promise<[BigNumber]>;

    disputePrice(
      requester: string,
      identifier: BytesLike,
      timestamp: BigNumberish,
      ancillaryData: BytesLike,
      overrides?: Overrides & { from?: string | Promise<string> }
    ): Promise<ContractTransaction>;

    disputePriceFor(
      disputer: string,
      requester: string,
      identifier: BytesLike,
      timestamp: BigNumberish,
      ancillaryData: BytesLike,
      overrides?: Overrides & { from?: string | Promise<string> }
    ): Promise<ContractTransaction>;

    getRequest(
      requester: string,
      identifier: BytesLike,
      timestamp: BigNumberish,
      ancillaryData: BytesLike,
      overrides?: CallOverrides
    ): Promise<
      [
        [
          string,
          string,
          string,
          boolean,
          boolean,
          BigNumber,
          BigNumber,
          BigNumber,
          BigNumber,
          BigNumber,
          BigNumber,
          BigNumber
        ] & {
          proposer: string;
          disputer: string;
          currency: string;
          settled: boolean;
          refundOnDispute: boolean;
          proposedPrice: BigNumber;
          resolvedPrice: BigNumber;
          expirationTime: BigNumber;
          reward: BigNumber;
          finalFee: BigNumber;
          bond: BigNumber;
          customLiveness: BigNumber;
        }
      ]
    >;

    getState(
      requester: string,
      identifier: BytesLike,
      timestamp: BigNumberish,
      ancillaryData: BytesLike,
      overrides?: CallOverrides
    ): Promise<[number]>;

    hasPrice(
      requester: string,
      identifier: BytesLike,
      timestamp: BigNumberish,
      ancillaryData: BytesLike,
      overrides?: CallOverrides
    ): Promise<[boolean]>;

    proposePrice(
      requester: string,
      identifier: BytesLike,
      timestamp: BigNumberish,
      ancillaryData: BytesLike,
      proposedPrice: BigNumberish,
      overrides?: Overrides & { from?: string | Promise<string> }
    ): Promise<ContractTransaction>;

    proposePriceFor(
      proposer: string,
      requester: string,
      identifier: BytesLike,
      timestamp: BigNumberish,
      ancillaryData: BytesLike,
      proposedPrice: BigNumberish,
      overrides?: Overrides & { from?: string | Promise<string> }
    ): Promise<ContractTransaction>;

    requestPrice(
      identifier: BytesLike,
      timestamp: BigNumberish,
      ancillaryData: BytesLike,
      currency: string,
      reward: BigNumberish,
      overrides?: Overrides & { from?: string | Promise<string> }
    ): Promise<ContractTransaction>;

    setBond(
      identifier: BytesLike,
      timestamp: BigNumberish,
      ancillaryData: BytesLike,
      bond: BigNumberish,
      overrides?: Overrides & { from?: string | Promise<string> }
    ): Promise<ContractTransaction>;

    setCustomLiveness(
      identifier: BytesLike,
      timestamp: BigNumberish,
      ancillaryData: BytesLike,
      customLiveness: BigNumberish,
      overrides?: Overrides & { from?: string | Promise<string> }
    ): Promise<ContractTransaction>;

    setRefundOnDispute(
      identifier: BytesLike,
      timestamp: BigNumberish,
      ancillaryData: BytesLike,
      overrides?: Overrides & { from?: string | Promise<string> }
    ): Promise<ContractTransaction>;

    settle(
      requester: string,
      identifier: BytesLike,
      timestamp: BigNumberish,
      ancillaryData: BytesLike,
      overrides?: Overrides & { from?: string | Promise<string> }
    ): Promise<ContractTransaction>;

    settleAndGetPrice(
      identifier: BytesLike,
      timestamp: BigNumberish,
      ancillaryData: BytesLike,
      overrides?: Overrides & { from?: string | Promise<string> }
    ): Promise<ContractTransaction>;

    stampAncillaryData(
      ancillaryData: BytesLike,
      requester: string,
      overrides?: CallOverrides
    ): Promise<[string]>;
  };

  ancillaryBytesLimit(overrides?: CallOverrides): Promise<BigNumber>;

  disputePrice(
    requester: string,
    identifier: BytesLike,
    timestamp: BigNumberish,
    ancillaryData: BytesLike,
    overrides?: Overrides & { from?: string | Promise<string> }
  ): Promise<ContractTransaction>;

  disputePriceFor(
    disputer: string,
    requester: string,
    identifier: BytesLike,
    timestamp: BigNumberish,
    ancillaryData: BytesLike,
    overrides?: Overrides & { from?: string | Promise<string> }
  ): Promise<ContractTransaction>;

  getRequest(
    requester: string,
    identifier: BytesLike,
    timestamp: BigNumberish,
    ancillaryData: BytesLike,
    overrides?: CallOverrides
  ): Promise<
    [
      string,
      string,
      string,
      boolean,
      boolean,
      BigNumber,
      BigNumber,
      BigNumber,
      BigNumber,
      BigNumber,
      BigNumber,
      BigNumber
    ] & {
      proposer: string;
      disputer: string;
      currency: string;
      settled: boolean;
      refundOnDispute: boolean;
      proposedPrice: BigNumber;
      resolvedPrice: BigNumber;
      expirationTime: BigNumber;
      reward: BigNumber;
      finalFee: BigNumber;
      bond: BigNumber;
      customLiveness: BigNumber;
    }
  >;

  getState(
    requester: string,
    identifier: BytesLike,
    timestamp: BigNumberish,
    ancillaryData: BytesLike,
    overrides?: CallOverrides
  ): Promise<number>;

  hasPrice(
    requester: string,
    identifier: BytesLike,
    timestamp: BigNumberish,
    ancillaryData: BytesLike,
    overrides?: CallOverrides
  ): Promise<boolean>;

  proposePrice(
    requester: string,
    identifier: BytesLike,
    timestamp: BigNumberish,
    ancillaryData: BytesLike,
    proposedPrice: BigNumberish,
    overrides?: Overrides & { from?: string | Promise<string> }
  ): Promise<ContractTransaction>;

  proposePriceFor(
    proposer: string,
    requester: string,
    identifier: BytesLike,
    timestamp: BigNumberish,
    ancillaryData: BytesLike,
    proposedPrice: BigNumberish,
    overrides?: Overrides & { from?: string | Promise<string> }
  ): Promise<ContractTransaction>;

  requestPrice(
    identifier: BytesLike,
    timestamp: BigNumberish,
    ancillaryData: BytesLike,
    currency: string,
    reward: BigNumberish,
    overrides?: Overrides & { from?: string | Promise<string> }
  ): Promise<ContractTransaction>;

  setBond(
    identifier: BytesLike,
    timestamp: BigNumberish,
    ancillaryData: BytesLike,
    bond: BigNumberish,
    overrides?: Overrides & { from?: string | Promise<string> }
  ): Promise<ContractTransaction>;

  setCustomLiveness(
    identifier: BytesLike,
    timestamp: BigNumberish,
    ancillaryData: BytesLike,
    customLiveness: BigNumberish,
    overrides?: Overrides & { from?: string | Promise<string> }
  ): Promise<ContractTransaction>;

  setRefundOnDispute(
    identifier: BytesLike,
    timestamp: BigNumberish,
    ancillaryData: BytesLike,
    overrides?: Overrides & { from?: string | Promise<string> }
  ): Promise<ContractTransaction>;

  settle(
    requester: string,
    identifier: BytesLike,
    timestamp: BigNumberish,
    ancillaryData: BytesLike,
    overrides?: Overrides & { from?: string | Promise<string> }
  ): Promise<ContractTransaction>;

  settleAndGetPrice(
    identifier: BytesLike,
    timestamp: BigNumberish,
    ancillaryData: BytesLike,
    overrides?: Overrides & { from?: string | Promise<string> }
  ): Promise<ContractTransaction>;

  stampAncillaryData(
    ancillaryData: BytesLike,
    requester: string,
    overrides?: CallOverrides
  ): Promise<string>;

  callStatic: {
    ancillaryBytesLimit(overrides?: CallOverrides): Promise<BigNumber>;

    disputePrice(
      requester: string,
      identifier: BytesLike,
      timestamp: BigNumberish,
      ancillaryData: BytesLike,
      overrides?: CallOverrides
    ): Promise<BigNumber>;

    disputePriceFor(
      disputer: string,
      requester: string,
      identifier: BytesLike,
      timestamp: BigNumberish,
      ancillaryData: BytesLike,
      overrides?: CallOverrides
    ): Promise<BigNumber>;

    getRequest(
      requester: string,
      identifier: BytesLike,
      timestamp: BigNumberish,
      ancillaryData: BytesLike,
      overrides?: CallOverrides
    ): Promise<
      [
        string,
        string,
        string,
        boolean,
        boolean,
        BigNumber,
        BigNumber,
        BigNumber,
        BigNumber,
        BigNumber,
        BigNumber,
        BigNumber
      ] & {
        proposer: string;
        disputer: string;
        currency: string;
        settled: boolean;
        refundOnDispute: boolean;
        proposedPrice: BigNumber;
        resolvedPrice: BigNumber;
        expirationTime: BigNumber;
        reward: BigNumber;
        finalFee: BigNumber;
        bond: BigNumber;
        customLiveness: BigNumber;
      }
    >;

    getState(
      requester: string,
      identifier: BytesLike,
      timestamp: BigNumberish,
      ancillaryData: BytesLike,
      overrides?: CallOverrides
    ): Promise<number>;

    hasPrice(
      requester: string,
      identifier: BytesLike,
      timestamp: BigNumberish,
      ancillaryData: BytesLike,
      overrides?: CallOverrides
    ): Promise<boolean>;

    proposePrice(
      requester: string,
      identifier: BytesLike,
      timestamp: BigNumberish,
      ancillaryData: BytesLike,
      proposedPrice: BigNumberish,
      overrides?: CallOverrides
    ): Promise<BigNumber>;

    proposePriceFor(
      proposer: string,
      requester: string,
      identifier: BytesLike,
      timestamp: BigNumberish,
      ancillaryData: BytesLike,
      proposedPrice: BigNumberish,
      overrides?: CallOverrides
    ): Promise<BigNumber>;

    requestPrice(
      identifier: BytesLike,
      timestamp: BigNumberish,
      ancillaryData: BytesLike,
      currency: string,
      reward: BigNumberish,
      overrides?: CallOverrides
    ): Promise<BigNumber>;

    setBond(
      identifier: BytesLike,
      timestamp: BigNumberish,
      ancillaryData: BytesLike,
      bond: BigNumberish,
      overrides?: CallOverrides
    ): Promise<BigNumber>;

    setCustomLiveness(
      identifier: BytesLike,
      timestamp: BigNumberish,
      ancillaryData: BytesLike,
      customLiveness: BigNumberish,
      overrides?: CallOverrides
    ): Promise<void>;

    setRefundOnDispute(
      identifier: BytesLike,
      timestamp: BigNumberish,
      ancillaryData: BytesLike,
      overrides?: CallOverrides
    ): Promise<void>;

    settle(
      requester: string,
      identifier: BytesLike,
      timestamp: BigNumberish,
      ancillaryData: BytesLike,
      overrides?: CallOverrides
    ): Promise<BigNumber>;

    settleAndGetPrice(
      identifier: BytesLike,
      timestamp: BigNumberish,
      ancillaryData: BytesLike,
      overrides?: CallOverrides
    ): Promise<BigNumber>;

    stampAncillaryData(
      ancillaryData: BytesLike,
      requester: string,
      overrides?: CallOverrides
    ): Promise<string>;
  };

  filters: {};

  estimateGas: {
    ancillaryBytesLimit(overrides?: CallOverrides): Promise<BigNumber>;

    disputePrice(
      requester: string,
      identifier: BytesLike,
      timestamp: BigNumberish,
      ancillaryData: BytesLike,
      overrides?: Overrides & { from?: string | Promise<string> }
    ): Promise<BigNumber>;

    disputePriceFor(
      disputer: string,
      requester: string,
      identifier: BytesLike,
      timestamp: BigNumberish,
      ancillaryData: BytesLike,
      overrides?: Overrides & { from?: string | Promise<string> }
    ): Promise<BigNumber>;

    getRequest(
      requester: string,
      identifier: BytesLike,
      timestamp: BigNumberish,
      ancillaryData: BytesLike,
      overrides?: CallOverrides
    ): Promise<BigNumber>;

    getState(
      requester: string,
      identifier: BytesLike,
      timestamp: BigNumberish,
      ancillaryData: BytesLike,
      overrides?: CallOverrides
    ): Promise<BigNumber>;

    hasPrice(
      requester: string,
      identifier: BytesLike,
      timestamp: BigNumberish,
      ancillaryData: BytesLike,
      overrides?: CallOverrides
    ): Promise<BigNumber>;

    proposePrice(
      requester: string,
      identifier: BytesLike,
      timestamp: BigNumberish,
      ancillaryData: BytesLike,
      proposedPrice: BigNumberish,
      overrides?: Overrides & { from?: string | Promise<string> }
    ): Promise<BigNumber>;

    proposePriceFor(
      proposer: string,
      requester: string,
      identifier: BytesLike,
      timestamp: BigNumberish,
      ancillaryData: BytesLike,
      proposedPrice: BigNumberish,
      overrides?: Overrides & { from?: string | Promise<string> }
    ): Promise<BigNumber>;

    requestPrice(
      identifier: BytesLike,
      timestamp: BigNumberish,
      ancillaryData: BytesLike,
      currency: string,
      reward: BigNumberish,
      overrides?: Overrides & { from?: string | Promise<string> }
    ): Promise<BigNumber>;

    setBond(
      identifier: BytesLike,
      timestamp: BigNumberish,
      ancillaryData: BytesLike,
      bond: BigNumberish,
      overrides?: Overrides & { from?: string | Promise<string> }
    ): Promise<BigNumber>;

    setCustomLiveness(
      identifier: BytesLike,
      timestamp: BigNumberish,
      ancillaryData: BytesLike,
      customLiveness: BigNumberish,
      overrides?: Overrides & { from?: string | Promise<string> }
    ): Promise<BigNumber>;

    setRefundOnDispute(
      identifier: BytesLike,
      timestamp: BigNumberish,
      ancillaryData: BytesLike,
      overrides?: Overrides & { from?: string | Promise<string> }
    ): Promise<BigNumber>;

    settle(
      requester: string,
      identifier: BytesLike,
      timestamp: BigNumberish,
      ancillaryData: BytesLike,
      overrides?: Overrides & { from?: string | Promise<string> }
    ): Promise<BigNumber>;

    settleAndGetPrice(
      identifier: BytesLike,
      timestamp: BigNumberish,
      ancillaryData: BytesLike,
      overrides?: Overrides & { from?: string | Promise<string> }
    ): Promise<BigNumber>;

    stampAncillaryData(
      ancillaryData: BytesLike,
      requester: string,
      overrides?: CallOverrides
    ): Promise<BigNumber>;
  };

  populateTransaction: {
    ancillaryBytesLimit(
      overrides?: CallOverrides
    ): Promise<PopulatedTransaction>;

    disputePrice(
      requester: string,
      identifier: BytesLike,
      timestamp: BigNumberish,
      ancillaryData: BytesLike,
      overrides?: Overrides & { from?: string | Promise<string> }
    ): Promise<PopulatedTransaction>;

    disputePriceFor(
      disputer: string,
      requester: string,
      identifier: BytesLike,
      timestamp: BigNumberish,
      ancillaryData: BytesLike,
      overrides?: Overrides & { from?: string | Promise<string> }
    ): Promise<PopulatedTransaction>;

    getRequest(
      requester: string,
      identifier: BytesLike,
      timestamp: BigNumberish,
      ancillaryData: BytesLike,
      overrides?: CallOverrides
    ): Promise<PopulatedTransaction>;

    getState(
      requester: string,
      identifier: BytesLike,
      timestamp: BigNumberish,
      ancillaryData: BytesLike,
      overrides?: CallOverrides
    ): Promise<PopulatedTransaction>;

    hasPrice(
      requester: string,
      identifier: BytesLike,
      timestamp: BigNumberish,
      ancillaryData: BytesLike,
      overrides?: CallOverrides
    ): Promise<PopulatedTransaction>;

    proposePrice(
      requester: string,
      identifier: BytesLike,
      timestamp: BigNumberish,
      ancillaryData: BytesLike,
      proposedPrice: BigNumberish,
      overrides?: Overrides & { from?: string | Promise<string> }
    ): Promise<PopulatedTransaction>;

    proposePriceFor(
      proposer: string,
      requester: string,
      identifier: BytesLike,
      timestamp: BigNumberish,
      ancillaryData: BytesLike,
      proposedPrice: BigNumberish,
      overrides?: Overrides & { from?: string | Promise<string> }
    ): Promise<PopulatedTransaction>;

    requestPrice(
      identifier: BytesLike,
      timestamp: BigNumberish,
      ancillaryData: BytesLike,
      currency: string,
      reward: BigNumberish,
      overrides?: Overrides & { from?: string | Promise<string> }
    ): Promise<PopulatedTransaction>;

    setBond(
      identifier: BytesLike,
      timestamp: BigNumberish,
      ancillaryData: BytesLike,
      bond: BigNumberish,
      overrides?: Overrides & { from?: string | Promise<string> }
    ): Promise<PopulatedTransaction>;

    setCustomLiveness(
      identifier: BytesLike,
      timestamp: BigNumberish,
      ancillaryData: BytesLike,
      customLiveness: BigNumberish,
      overrides?: Overrides & { from?: string | Promise<string> }
    ): Promise<PopulatedTransaction>;

    setRefundOnDispute(
      identifier: BytesLike,
      timestamp: BigNumberish,
      ancillaryData: BytesLike,
      overrides?: Overrides & { from?: string | Promise<string> }
    ): Promise<PopulatedTransaction>;

    settle(
      requester: string,
      identifier: BytesLike,
      timestamp: BigNumberish,
      ancillaryData: BytesLike,
      overrides?: Overrides & { from?: string | Promise<string> }
    ): Promise<PopulatedTransaction>;

    settleAndGetPrice(
      identifier: BytesLike,
      timestamp: BigNumberish,
      ancillaryData: BytesLike,
      overrides?: Overrides & { from?: string | Promise<string> }
    ): Promise<PopulatedTransaction>;

    stampAncillaryData(
      ancillaryData: BytesLike,
      requester: string,
      overrides?: CallOverrides
    ): Promise<PopulatedTransaction>;
  };
}
