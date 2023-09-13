// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import {Script} from "forge-std/Script.sol";
import {Raffle} from "../src/Raffle.sol";
import {VRFCoordinatorV2Mock} from "@chainlink/contracts/src/v0.8/mocks/VRFCoordinatorV2Mock.sol";
import {LinkToken} from "../test/mocks/Linktoken.sol";

contract HelperConfig is Script {
    struct NetworkConfig {
        uint256 entranceFee;
        uint256 interval;
        address vrfcoordinator;
        bytes32 gaslane;
        uint64 subscriptionId;
        uint32 callbackgaslimit;
        address link;
        uint256 deployerKey;
    }

    uint256 public constant DEFAULT_ANVIL_KEY =
        0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80;

    NetworkConfig public ActiveNetworkConfig;

    constructor() {
        if (block.chainid == 1115511) {
            ActiveNetworkConfig = getSepoliaNetworkConfig();
        } else {
            ActiveNetworkConfig = getAnviNetworkConfig();
        }
    }

    function getSepoliaNetworkConfig()
        public
        view
        returns (NetworkConfig memory)
    {
        return
            NetworkConfig({
                entranceFee: 0.01 ether,
                interval: 30 seconds,
                vrfcoordinator: 0x8103B0A8A00be2DDC778e6e7eaa21791Cd364625,
                gaslane: 0x474e34a077df58807dbe9c96d3c009b23b3c6d0cce433e59bbf5b34f823bc56c,
                subscriptionId: 0, // update this with our subid
                callbackgaslimit: 500000,
                link: 0x779877A7B0D9E8603169DdbD7836e478b4624789,
                deployerKey: 0
            });
    }

    function getAnviNetworkConfig() public returns (NetworkConfig memory) {
        if (ActiveNetworkConfig.vrfcoordinator != address(0)) {
            return ActiveNetworkConfig;
        }

        uint96 basefee = 0.25 ether;
        uint96 gaspriceLink = 1e9;

        LinkToken link = new LinkToken();

        vm.startBroadcast();
        VRFCoordinatorV2Mock vrfcoordinatorv2Mock = new VRFCoordinatorV2Mock(
            basefee,
            gaspriceLink
        );
        vm.stopBroadcast();

        return
            NetworkConfig({
                entranceFee: 0.01 ether,
                interval: 30 seconds,
                vrfcoordinator: address(vrfcoordinatorv2Mock),
                gaslane: 0x474e34a077df58807dbe9c96d3c009b23b3c6d0cce433e59bbf5b34f823bc56c,
                subscriptionId: 0, // update this with our subid
                callbackgaslimit: 500000,
                link: address(link),
                deployerKey: DEFAULT_ANVIL_KEY
            });
    }
}
