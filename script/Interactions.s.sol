//SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import {Script, console} from "forge-std/Script.sol";
import {HelperConfig} from "./HelperConfig.s.sol";
import {VRFCoordinatorV2Mock} from "@chainlink/contracts/src/v0.8/mocks/VRFCoordinatorV2Mock.sol";
import {LinkToken} from "../test/mocks/Linktoken.sol";
import {DevOpsTools} from "lib/foundry-devops/src/DevOpsTools.sol";

contract CreateSubscription is Script {
    function createSubricptionUsingConfig() public returns (uint64) {
        HelperConfig helperConfig = new HelperConfig();

        (, , address vrfcoordinator, , , , , uint256 deployerKey) = helperConfig
            .ActiveNetworkConfig();
        return createSubscription(vrfcoordinator, deployerKey);
    }

    function createSubscription(
        address vrfcoordinator,
        uint256 deployerKey
    ) public returns (uint64) {
        console.log("Creating subscription on ChainI", block.chainid);
        vm.startBroadcast(deployerKey);
        uint64 subId = VRFCoordinatorV2Mock(vrfcoordinator)
            .createSubscription();
        vm.stopBroadcast();
        console.log("your sub Id is:", subId);
        console.log("please update subscriptionId in Helperconfig.s.sol");
        return subId;
    }

    function run() external returns (uint64) {
        return createSubricptionUsingConfig();
    }
}

contract FundSubscription is Script {
    uint96 public constant FUND_AMOUNT = 3 ether;

    function fundSubscriptionUsingConfig() public {
        HelperConfig helperConfig = new HelperConfig();
        (
            ,
            ,
            address vrfcoordinator,
            ,
            uint64 subId,
            ,
            address link,
            uint256 deployerKey
        ) = helperConfig.ActiveNetworkConfig();

        fundSubscription(vrfcoordinator, subId, link, deployerKey);
    }

    function fundSubscription(
        address vrfcoordinator,
        uint64 subId,
        address link,
        uint256 deployerKey
    ) public {
        console.log("my subscription id:", subId);
        console.log("Using VrfCoordinator:", vrfcoordinator);
        console.log("On chainID :", block.chainid);
        if (block.chainid == 31337) {
            vm.startBroadcast(deployerKey);
            VRFCoordinatorV2Mock(vrfcoordinator).fundSubscription(
                subId,
                FUND_AMOUNT
            );
            vm.stopBroadcast();
        } else {
            vm.startBroadcast(deployerKey);
            LinkToken(link).transferAndCall(
                vrfcoordinator,
                FUND_AMOUNT,
                abi.encode(subId)
            );
            vm.stopBroadcast();
        }
    }

    function run() external {
        fundSubscriptionUsingConfig();
    }
}

contract AddConsumer is Script {
    function addConsumer(
        address raffle,
        address vrfcoordinator,
        uint64 subId,
        uint256 deployerKey
    ) public {
        console.log("Adding consumer contract:", raffle);
        console.log("Using vrfcoordinator:", vrfcoordinator);
        console.log("On chainId:", block.chainid);
        vm.startBroadcast(deployerKey);
        VRFCoordinatorV2Mock(vrfcoordinator).addConsumer(subId, raffle);
        vm.stopBroadcast();
    }

    function AddConsumerUsingConfig(address raffle) public {
        HelperConfig helperConfig = new HelperConfig();
        (
            ,
            ,
            address vrfcoordinator,
            ,
            uint64 subId,
            ,
            ,
            uint256 deployerKey
        ) = helperConfig.ActiveNetworkConfig();

        addConsumer(raffle, vrfcoordinator, subId, deployerKey);
    }

    function run() external {
        address raffle = DevOpsTools.get_most_recent_deployment(
            "MyContract",
            block.chainid
        );
        AddConsumerUsingConfig(raffle);
    }
}
