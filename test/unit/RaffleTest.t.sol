// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {DeployRaffle} from "../../script/DeployRaffle.s.sol";
import {Raffle} from "../../src/Raffle.sol";
import {Test, console} from "forge-std/Test.sol";
import {HelperConfig} from "../../script/HelperConfig.s.sol";
import {Vm} from "forge-std/Vm.sol";
import {VRFCoordinatorV2Mock} from "@chainlink/contracts/src/v0.8/mocks/VRFCoordinatorV2Mock.sol";

contract RaffleTest is Test {
    /* events */

    event EnteredRaffle(address indexed player);

    Raffle raffle; // this is a setup of what we will deploy later, a placeholder
    HelperConfig helperConfig; // this is a setup of what we will deploy later, a placeholder

    // these variables will be our state variables
    uint256 entranceFee;
    uint256 interval;
    address vrfCoordinator;
    bytes32 gasLane;
    uint64 subscriptionId;
    uint32 callBackGasLimit;
    address link;

    address public PLAYER = makeAddr("player"); // we utilize a user address to test the raffle contract
    uint public constant START_USER_BALANCE = 10 ether; // we set the user balance to 10 ether, this is not yet implemented in the contract.
    uint public constant TIME_GREATER_THAN_INTERVAL = 10;

    function setUp() external {
        DeployRaffle deployer = new DeployRaffle(); // our deployRaffle is going to be a new instance of the deployRaffle contract, which deploys both raffle and helperConfig.
        // When we run the deployer, we need to pass in the constructor parameters that were present in our deployRaffle contract, deployRaffle took constructor from the helperConfig.
        (raffle, helperConfig) = deployer.run();
        vm.deal(PLAYER, START_USER_BALANCE);
        // When I see .run, it is returning two values, those two values are being returned to the variables raffle and helperConfig respectively.
        (
            entranceFee,
            interval,
            vrfCoordinator,
            gasLane,
            subscriptionId,
            callBackGasLimit,
            link,

        ) = helperConfig.activeNetworkConfig(); // we are going to get the active network config from the helperConfig contract, and we are going to deconstruct the network config into the underlying parameters
    }

    function testRaffleInitializeInOpenState() public view {
        assert(raffle.getRaffleState() == Raffle.RaffleState.OPEN); // we can get the state of our raffle states, this assert means that the raffle state is open then it is true.
    }

    // enter raffle
    function testRaffleRevertsWhenYouDontPayEnough() public {
        vm.prank(PLAYER); // simulates a user interacting with the contract
        vm.expectRevert(Raffle.Raffle__NotEnoughEthSent.selector); // we expect a revert, on the next transaction. The user tries to enter without the entrance fee
        raffle.enterRaffle();
    }

    function testRaffleRecordsPlayerWhenTheyEnter() public {
        vm.prank(PLAYER); // this is how we're going to select a user to interact with the contract
        raffle.enterRaffle{value: entranceFee}();
        address playerRecorded = raffle.getPlayer(0); // we address the array of players and get the first player on the list, we pass in the index, we want to assert that the player recorded is the player
        assert(playerRecorded == PLAYER);
    }

    function testEmitsEventsOnEntrance() public {
        vm.prank(PLAYER);
        vm.expectEmit(true, false, false, false, address(raffle)); // remember our emit events can hold up to 5 parameters, 3 of which are indexed, 1 that is reading data like logs and the last one is the address of the contract where we're seeing the event.
        emit EnteredRaffle(PLAYER); // We simulate the raffle by entereing the raffle, we have to do this in our test unfortunately, but we then utilize the enterRaffle function in our contract to emit the event.
        raffle.enterRaffle{value: entranceFee}();
    }

    function testCantEnterWhenRaffleIsCalculating() public {
        vm.prank(PLAYER);
        raffle.enterRaffle{value: entranceFee}(); // the user enters the raffle to fufill that players are in the raffle
        vm.warp(block.timestamp + interval + 1); // we simulate that enough time has passed for the raffle to be calculating, upkeep is not needed.
        vm.roll(block.number + 1); // we simulate the next blocknumber
        raffle.performUpkeep(""); // we perform the upkeep which will only state that the return value of checkupkeep is true, because of our previous warp, enterRaffle, we fufill the true booleans to make checkupkeep return the boolean true, which we passed through be upKeepNeeded, this is calculating
        vm.expectRevert(Raffle.Raffle__RaffleNotOpen.selector); //we expect an error, because the raffle is calculating and not open here, the next transaction will revert
        vm.prank(PLAYER); // we simulate another user interaction
        raffle.enterRaffle{value: entranceFee}(); // the user tries to enter the raffle, which should deploy an revet
    }

    ///////
    //checkupkeep//
    ///////
    function testCheckUpKeepReturnsFalseIfItHasNoBalance() public {
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1); // the reason we do vm.roll here is to simulate the next block number to ensure enough time has passed
        (bool upkeepNeeded, ) = raffle.checkUpkeep("");

        //assert
        assert(!upkeepNeeded);
    }

    function testCheckUpKeepReturnsFalseIfRaffleNotOpen() public {
        //arrange
        vm.prank(PLAYER);
        raffle.enterRaffle{value: entranceFee}();
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);
        raffle.performUpkeep("");
        // act
        (bool upkeepNeeded, ) = raffle.checkUpkeep("");
        //assert
        assert(upkeepNeeded == false);
    }

    // test checkupkeepreturnfalse if enough time hasn't passed
    function testCheckUpKeepReturnsFalseIfNotEnoughTime() public {
        //arrange
        vm.prank(PLAYER);
        raffle.enterRaffle{value: entranceFee}(); // player is in raffle, raffle has balance
        assert(raffle.getRaffleState() == Raffle.RaffleState.OPEN); // raffle state is open
        // act
        uint256 notEnoughTime = block.timestamp +
            interval -
            TIME_GREATER_THAN_INTERVAL; //we set time to be less than interval
        vm.warp(notEnoughTime); // we warp to the time that is less than the interval.
        // player successfully joins in raffle.
        (bool upkeepNeeded, ) = raffle.checkUpkeep("");
        assert(!upkeepNeeded);
    }

    function testCheckUpKeepReturnsTrueWhenAllConditionsAreMet() public {
        //arrange
        vm.prank(PLAYER);
        raffle.enterRaffle{value: entranceFee}(); // condition to players in raffle and our contract with a balance.
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);
        // act
        (bool upkeepNeeded, ) = raffle.checkUpkeep("");
        //assert
        assert(upkeepNeeded == true);
    }

    function testPerformUpKeepCanOnlyRunIfCheckUpkeepIsTrue() public {
        vm.prank(PLAYER);
        raffle.enterRaffle{value: entranceFee}();
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);
        //Act
        raffle.performUpkeep("");
    }

    function testPerformUpkeepRevertIfCheckUpkeepIsFalse() public {
        uint256 currentBalance = address(raffle).balance;
        uint256 numPlayers = 0;
        uint256 raffleState = 0; // we know based on our numerical values on what open and closed mean
        vm.expectRevert(
            abi.encodeWithSelector(
                Raffle.Raffle__UpkeepNotNeeded.selector,
                currentBalance,
                numPlayers,
                raffleState
            )
        );
        raffle.performUpkeep("");
    }

    modifier raffleEnteredAndTimePassed() {
        vm.prank(PLAYER);
        raffle.enterRaffle{value: entranceFee}();
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);
        _;
    }

    // what if I need to test using the output of an event, events are not accessible with our smart contracts.
    function testPerformUpkeepUpdatesRaffleStateandEmitsRequestId()
        public
        raffleEnteredAndTimePassed
    {
        // act
        vm.recordLogs(); // automatically saves all the log outputs
        raffle.performUpkeep(""); // emit requestId
        Vm.Log[] memory entries = vm.getRecordedLogs();
        bytes32 requestId = entries[1].topics[1];
        Raffle.RaffleState rState = raffle.getRaffleState();
        assert(uint256(requestId) > 0);
        assert(uint256(rState) == 1);
    }

    //////////////////////
    // fufillRandomWords//
    //////////////////////
    modifier skipFork() {
        if (block.chainid != 31337) {
            return;
        }
        _;
    }

    function testFulfillRandomWordsCanOnlyBeCalledAfterPerformUpkeep(
        uint256 randomRequestId
    ) public raffleEnteredAndTimePassed skipFork {
        // arrange
        vm.expectRevert("nonexistent request");
        VRFCoordinatorV2Mock(vrfCoordinator).fulfillRandomWords(
            randomRequestId,
            address(raffle)
        );
    }

    function testFufillRandomWordsPicksaWinnerResetsAndSendsMoney()
        public
        raffleEnteredAndTimePassed
        skipFork
    {
        // arrange
        uint256 additionalEntrants = 5;
        uint256 startingIndex = 1;
        for (
            uint256 i = startingIndex;
            i < startingIndex + additionalEntrants;
            i++
        ) {
            address player = address(uint160(i)); // similar to address(1) , 2 and so on
            hoax(player, START_USER_BALANCE);
            raffle.enterRaffle{value: entranceFee}();
        }

        uint256 prize = entranceFee * (additionalEntrants + 1);

        vm.recordLogs(); // automatically saves all the log outputs
        raffle.performUpkeep(""); // emit requestId
        Vm.Log[] memory entries = vm.getRecordedLogs();
        bytes32 requestId = entries[1].topics[1];

        uint256 previousTimeStamp = raffle.getLastTimeStamp();

        // pretend to be the chainlink node
        VRFCoordinatorV2Mock(vrfCoordinator).fulfillRandomWords(
            uint256(requestId),
            address(raffle)
        );
        //assert
        assert(uint256(raffle.getRaffleState()) == 0);
        assert(raffle.getRecentWinner() != address(0));
        assert(raffle.getLengthOfPlayers() == 0);
        assert(previousTimeStamp < raffle.getLastTimeStamp());
        assert(
            raffle.getRecentWinner().balance ==
                START_USER_BALANCE + prize - entranceFee
        );
    }
}
