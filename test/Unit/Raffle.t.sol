// SPDX-License-Identifier: MIT

pragma solidity ^0.8.19;

import {DeployRaffle} from "../../script/DeployRaffle.s.sol";
import {Raffle} from "../../src/Raffle.sol";
import {HelperConfig} from "../../script/HelperConfig.s.sol";
import {Test, console} from "../../lib/forge-std/src/Test.sol";
import {Vm} from "forge-std/Vm.sol";
import {VRFCoordinatorV2Mock} from "@chainlink/contracts/src/v0.8/mocks/VRFCoordinatorV2Mock.sol";

contract RaffleTest is Test {
    /* Errors */
    event RaffleEnter(address indexed player);

    Raffle public raffle;
    HelperConfig public helperConfig;

    uint256 entranceFee;
    uint256 interval;
    address vrfcoordinator;
    bytes32 gaslane;
    uint64 subscriptionId;
    uint32 callbackgaslimit;
    address link;

    address public PLAYER = makeAddr("player");
    uint256 public constant STARTING_USER_BALANCE = 10 ether;

    function setUp() external {
        DeployRaffle deployer = new DeployRaffle();
        (raffle, helperConfig) = deployer.run();
        vm.deal(PLAYER, STARTING_USER_BALANCE);

        (
            entranceFee,
            interval,
            vrfcoordinator,
            gaslane,
            subscriptionId,
            callbackgaslimit,
            link,

        ) = helperConfig.ActiveNetworkConfig();
    }

    function testRaffleInitializesInOpenState() public view {
        assert(raffle.getRaffleState() == Raffle.RaffleState.OPEN);
    }

    /////////////////////////
    // enterRaffle         //
    /////////////////////////

    function testRaffleRevertsWHenYouDontPayEnought() public {
        // Arrange
        vm.prank(PLAYER);
        // Act / Assert
        vm.expectRevert(Raffle.Raffle__Notenoughcashstranger.selector);
        raffle.enterRaffle();
    }

    function testRaffleRecordsPlayerWhenTheyEnter() public {
        // Arrange
        vm.prank(PLAYER);
        // Act
        raffle.enterRaffle{value: entranceFee}();
        // Assert
        address playerRecorded = raffle.getPlayer(0);
        assert(playerRecorded == PLAYER);
    }

    // function testEmitsEventOnEntrance() public {
    //Arrange
    //vm.prank(PLAYER);

    // Act / Assert
    // vm.expectEmit(true, false, false, false, address(raffle));
    //emit RaffleEnter(PLAYER);
    //raffle.enterRaffle{value: entranceFee}();
    //}

    function testenterrafflecalculatinState() public {
        vm.prank(PLAYER);
        raffle.enterRaffle{value: entranceFee}();
        vm.warp(block.timestamp + 1 + interval);
        vm.roll(block.number + 1);

        raffle.performUpkeep("");
        vm.prank(PLAYER);
        vm.expectRevert(Raffle.Raffle__NotOpened.selector);
        raffle.enterRaffle{value: entranceFee}();
    }

    /////////////////
    // checkUpkeep //
    ////////////////

    function testCheckUpKeepreturnsFalseifNobalance() public {
        // arrange
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);

        // act
        (bool UpkeepNeeded, ) = raffle.checkUpkeep("");
        //Assert
        assert(!UpkeepNeeded);
    }

    function testCheckUpKeepreturnsFalseifRaffleNotOpen() public {
        // arrange
        vm.prank(PLAYER);
        raffle.enterRaffle{value: entranceFee}();
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);
        raffle.performUpkeep("");

        //Act

        (bool upkeepNeeded, ) = raffle.checkUpkeep("");
        assert(upkeepNeeded == false);
    }

    //////////////////
    // perfomUpkeep //
    //////////////////

    function testperfomUpkeepcanOnlyRunifCheckUpkeepisTrue() public {
        vm.prank(PLAYER);
        raffle.enterRaffle{value: entranceFee}();
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);

        // AAAct /assert
        raffle.performUpkeep("");
    }

    function testperfomUpkeepRevertsifCheckupkeepisFalse() public {
        // arrange
        uint256 currentbalance = 0;
        uint256 numplayers = 0;
        uint256 raffleState = 0;

        vm.expectRevert(
            abi.encodeWithSelector(
                Raffle.Raffle__Nottimeyet.selector,
                currentbalance,
                numplayers,
                raffleState
            )
        );
        raffle.performUpkeep("");
    }

    modifier raffleEnteredandTimePassed() {
        vm.prank(PLAYER);
        raffle.enterRaffle{value: entranceFee}();
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);
        _;
    }

    function testperfomUpkeepRaffleStateAndEmitsRequestId()
        public
        raffleEnteredandTimePassed
    {
        // act
        vm.recordLogs();
        raffle.performUpkeep("");
        Vm.Log[] memory entries = vm.getRecordedLogs();
        bytes32 requestId = entries[1].topics[1];

        //assert
        Raffle.RaffleState state = raffle.getRaffleState();

        assert(uint256(requestId) > 0);
        assert(uint256(state) == 1);
    }

    ////////////////////
    // RandomWords /////
    ////////////////////

    function testfullfillrandomwordsCanONLYbecalledAfterPerfom(
        uint256 randomRequestId
    ) public raffleEnteredandTimePassed {
        //Arrange
        vm.expectRevert("nonexistent request");
        VRFCoordinatorV2Mock(vrfcoordinator).fulfillRandomWords(
            randomRequestId,
            address(raffle)
        );
        //Act
        //Assert
    }

    function testfullfillrandomwordspicksawinnerresetstozeroAndPays()
        public
        raffleEnteredandTimePassed
    {
        uint256 entrance = 5;
        uint256 starting = 1;
        for (uint256 i = starting; i < starting + entrance; i++) {
            address player = address(uint160(i));
            hoax(player, STARTING_USER_BALANCE);
            raffle.enterRaffle{value: entranceFee}();
        }

        uint256 prize = (entranceFee * (entrance + 1));

        vm.recordLogs();
        raffle.performUpkeep("");
        Vm.Log[] memory entries = vm.getRecordedLogs();
        bytes32 requestId = entries[1].topics[1];

        uint256 previousTimeStamp = raffle.getLastTimeStamp();

        VRFCoordinatorV2Mock(vrfcoordinator).fulfillRandomWords(
            uint256(requestId),
            address(raffle)
        );
        // Be the vrf

        //assert
        assert(uint256(raffle.getRaffleState()) == 0);
        assert(raffle.getrecentWinner() != address(0));
        assert(raffle.getLengthofPlayer() == 0);
        assert(previousTimeStamp < raffle.getLastTimeStamp());
        assert(
            raffle.getrecentWinner().balance ==
                STARTING_USER_BALANCE + prize - entranceFee
        );
    }
}
