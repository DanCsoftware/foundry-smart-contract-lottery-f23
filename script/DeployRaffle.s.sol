// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {Script} from "forge-std/Script.sol";
import {Raffle} from "../src/Raffle.sol";
import {HelperConfig} from "./HelperConfig.s.sol";
import {CreateSubscription} from "./Interactions.s.sol";
import {CreateSubscription, FundSubscription, AddConsumer} from "./Interactions.s.sol";

contract DeployRaffle is Script {
    function run() external returns (Raffle, HelperConfig) {
        HelperConfig helperConfig = new HelperConfig(); //based on the active network config, we are going to get all our parameters back
        (
            uint256 entranceFee,
            uint256 interval,
            address vrfCoordinator,
            bytes32 gasLane,
            uint64 subscriptionId,
            uint32 callBackGasLimit,
            address link,
            uint256 deployerKey
        ) = helperConfig.activeNetworkConfig(); // this means we are passing in these variables and running the activeNetwork config function on the helperconfig contract, which is going to return the parameter values.

        if (subscriptionId == 0) {
            CreateSubscription createSubscription = new CreateSubscription();
            subscriptionId = createSubscription.createSubscription(
                vrfCoordinator,
                deployerKey
            );
        } // we are going to say if our subscription id is 0, it implies we need to subId, we deploy a new instance of createsub, and reassign subId to be the return value of the vrfCoordinator address passed through createSubscription
        // fund it
        FundSubscription fundSubscription = new FundSubscription();
        fundSubscription.fundSubscription(
            vrfCoordinator,
            subscriptionId,
            link,
            deployerKey
        );

        // This is equal to NetworkConfig config = helperConfig.activeNetworkConfig();, but we are deconstructing the networkconfig object into underlying parameters

        vm.startBroadcast();
        Raffle raffle = new Raffle(
            entranceFee,
            interval,
            vrfCoordinator,
            gasLane,
            subscriptionId,
            callBackGasLimit
        );
        vm.stopBroadcast();
        AddConsumer addConsumer = new AddConsumer();
        addConsumer.addConsumer(
            address(raffle),
            vrfCoordinator,
            subscriptionId,
            deployerKey
        );
        return (raffle, helperConfig);
    }

    // 03/01 of the script this code is going to deploy our script to return the Raffle contract in our run function. We're going to deploy a new instance of helperconfig, which then gathers the active network paraemters that we unpackaged in our run function. We then start a broadcast, we need the broadcast because we are going to deploy a new instance of the raffle contract, in our raffle contract we then pass in the helperconfig paraemters, we then stop the broadcast and return the raffle contract.
}
