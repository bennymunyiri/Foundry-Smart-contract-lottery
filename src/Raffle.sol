// Layout of Contract:
// version
// imports
// errors
// interfaces, libraries, contracts
// Type declarations
// State variables
// Events
// Modifiers
// Functions

// Layout of Functions:
// constructor
// receive function (if exists)
// fallback function (if exists)
// external
// public
// internal
// private
// view & pure functions

//SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import {VRFCoordinatorV2Interface} from "@chainlink/contracts/src/v0.8/interfaces/VRFCoordinatorV2Interface.sol";
import {VRFConsumerBaseV2} from "@chainlink/contracts/src/v0.8/VRFConsumerBaseV2.sol";

/**
 * @title A raffle contract
 * @author Benson Munyiri
 * @notice This contract is for creating a sample raffle contract
 * @dev  Implements chainlink vrf2
 */

contract Raffle is VRFConsumerBaseV2 {
    error Raffle__Notenoughcashstranger();
    error Raffle__TransferFailed();
    error Raffle__NotOpened();
    error Raffle__Nottimeyet(
        uint256 currentBalance,
        uint256 numplayers,
        uint256 rafflestate
    );

    enum RaffleState {
        OPEN,
        CALCULATING
    }

    uint16 private constant REQUEST_CONFIRMATIONS = 3;
    uint32 private constant NUM_WORDS = 1;

    uint256 private immutable i_entranceFee;
    VRFCoordinatorV2Interface private immutable i_vrfcoordinator;
    uint256 private immutable i_interval;
    bytes32 private immutable i_gaslane;
    uint64 private immutable i_subscriptionId;
    uint32 private immutable i_callbackgaslimit;

    address payable[] private s_players;
    uint256 private s_lastblockstamp;
    address private s_recentwinner;
    RaffleState public s_RaffleState;

    //events

    event RaffleEntered(address indexed player);
    event pickedwinner(address indexed winner);
    event RequestRaffleWinner(uint256 indexed requestId);

    constructor(
        uint256 entranceFee,
        uint256 interval,
        address vrfcoordinator,
        bytes32 gaslane,
        uint64 subscriptionId,
        uint32 callbackgaslimit
    ) VRFConsumerBaseV2(vrfcoordinator) {
        i_entranceFee = entranceFee;
        i_interval = interval;
        s_lastblockstamp = block.timestamp;
        i_vrfcoordinator = VRFCoordinatorV2Interface(vrfcoordinator);
        i_gaslane = gaslane;
        i_subscriptionId = subscriptionId;
        i_callbackgaslimit = callbackgaslimit;
        s_RaffleState = RaffleState.OPEN;
    }

    function enterRaffle() external payable {
        if (msg.value < i_entranceFee) {
            revert Raffle__Notenoughcashstranger();
        }
        if (s_RaffleState != RaffleState.OPEN) {
            revert Raffle__NotOpened();
        }
        s_players.push(payable(msg.sender));
        emit RaffleEntered(msg.sender);
    }

    /**
     * @dev This is the function that the chainlink automation nodes call
     * to see if its time to perform an upkeep.
     * the following should be true:
     * 1.The time interval has passed between raffle runs
     * 2. The raffle is in the OPEN STATE
     * 3. The contract has ETH (aka, players)
     * 4. The subscription is funded with Link
     */
    function checkUpkeep(
        bytes memory /*checkdata*/
    ) public view returns (bool upkeepNeeded, bytes memory /* perform data*/) {
        bool timehasPassed = (block.timestamp - s_lastblockstamp) >= i_interval;
        bool isOpen = RaffleState.OPEN == s_RaffleState;
        bool hasBalance = address(this).balance > 0;
        bool hasPlayers = s_players.length > 0;
        upkeepNeeded = (timehasPassed && isOpen && hasBalance && hasPlayers);
        return (upkeepNeeded, "0x0");
    }

    // automatic call winner in amount interval
    function performUpkeep(bytes calldata /* performData */) external {
        (bool upkeep, ) = checkUpkeep("");
        if (!upkeep) {
            revert Raffle__Nottimeyet(
                address(this).balance,
                s_players.length,
                uint256(s_RaffleState)
            );
        }
        s_RaffleState = RaffleState.CALCULATING;
        uint256 requestId = i_vrfcoordinator.requestRandomWords(
            i_gaslane, // gas lane
            i_subscriptionId,
            REQUEST_CONFIRMATIONS,
            i_callbackgaslimit,
            NUM_WORDS
        );
        emit RequestRaffleWinner(requestId);
    }

    function fulfillRandomWords(
        uint256 /*requestId*/,
        uint256[] memory randomWords
    ) internal override {
        // CEI Check, Events, interactions
        uint256 indexofwinner = randomWords[0] % s_players.length;
        address payable winner = s_players[indexofwinner];
        s_recentwinner = winner;
        s_RaffleState = RaffleState.OPEN;

        s_lastblockstamp = block.timestamp;
        s_players = new address payable[](0);
        (bool success, ) = winner.call{value: address(this).balance}("");
        if (!success) {
            revert Raffle__TransferFailed();
        }
        emit pickedwinner(winner);
    }

    function getentranceFee() public view returns (uint256) {
        return i_entranceFee;
    }

    function getRaffleState() external view returns (RaffleState) {
        return s_RaffleState;
    }

    function getPlayer(uint256 indexofPlayer) external view returns (address) {
        return s_players[indexofPlayer];
    }

    function getrecentWinner() external view returns (address) {
        return s_recentwinner;
    }

    function getLengthofPlayer() external view returns (uint256) {
        return s_players.length;
    }

    function getLastTimeStamp() external view returns (uint256) {
        return s_lastblockstamp;
    }
}
