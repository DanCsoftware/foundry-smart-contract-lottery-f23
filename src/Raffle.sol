// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {VRFCoordinatorV2Interface} from "@chainlink/contracts/src/v0.8/interfaces/VRFCoordinatorV2Interface.sol";
import {VRFConsumerBaseV2} from "@chainlink/contracts/src/v0.8/VRFConsumerBaseV2.sol";

/**
 * @title A sample raffle contract`
 * @author Daniel Cha
 * @notice This contract is for creating a sample raffle
 * @dev implements chainlink VRFv2
 */

contract Raffle is VRFConsumerBaseV2 {
    error Raffle__NotEnoughEthSent();
    error Raffle__TransferFailed();
    error Raffle__RaffleNotOpen();
    error Raffle__UpkeepNotNeeded(
        uint256 currentBalance,
        uint256 numPlayers,
        uint256 raffleState
    );

    /** Type Declarations */
    enum RaffleState {
        OPEN, // 0
        CALCULATING // 1
    }

    /** State Variables */
    uint16 private constant REQUEST_CONFIRMATIONS = 3;
    uint32 private constant NUM_WORDS = 1;

    uint256 private immutable i_entranceFee;
    uint256 private immutable i_interval;
    VRFCoordinatorV2Interface private immutable i_vrfCoordinator;
    bytes32 private immutable i_gasLane;
    uint64 private immutable i_subscriptionId;
    uint32 private immutable i_callBackGasLimit;
    address payable[] private s_players;
    address private s_recentWinner;
    // @dev duration of the lottery in second
    uint256 private s_lastTimeStamp;
    RaffleState private s_raffleState;

    /** Events */
    event EnteredRaffle(address indexed player);
    event PickedWinner(address indexed winner);
    event RequestedRaffleWinner(uint256 indexed requestId);

    // constants will save the most gas
    // immutables will also be cheaper <-- we want to update and change the entrance fee, so we'll create a constructor
    // storages will notxw

    constructor(
        uint256 entranceFee,
        uint256 interval,
        address vrfCoordinator,
        bytes32 gasLane,
        uint64 subscriptionId,
        uint32 callBackGasLimit
    ) VRFConsumerBaseV2(vrfCoordinator) {
        i_entranceFee = entranceFee;
        i_interval = interval;
        i_vrfCoordinator = VRFCoordinatorV2Interface(vrfCoordinator);
        i_gasLane = gasLane;
        i_subscriptionId = subscriptionId;
        i_callBackGasLimit = callBackGasLimit;
        s_lastTimeStamp = block.timestamp;
        s_raffleState = RaffleState.OPEN;
        // right when contract is initialized, lastTimeStamp will capture this moment.
    }

    function enterRaffle() public payable {
        // require(msg.value >= i_entranceFee, "Not enough ETH");
        if (msg.value < i_entranceFee) {
            revert Raffle__NotEnoughEthSent();
        }
        if (s_raffleState != RaffleState.OPEN) {
            revert Raffle__RaffleNotOpen(); //
        }
        s_players.push(payable(msg.sender));
        emit EnteredRaffle(msg.sender);
    }

    // check upkeep should return when the winner needs to be picked

    /**
     * @dev This is the fucntion that the chainlink automation nodes call to check if the time to perform the upkeep is needed
     * The following shoul dbe true for this to retun true:
     * 1. Time interval has passed between raffle runs
     * 2. Raffle is in open state
     * 3. Contract has ETH (AKA Players)
     * 4. Subscription is funded with LINK
     */

    function checkUpkeep(
        bytes memory /* checkData */
    ) public view returns (bool upkeepNeeded, bytes memory /* performData */) {
        bool timeHasPassed = ((block.timestamp - s_lastTimeStamp) > i_interval); // if the current time minus the last time stamp is greater than the interval, than time has passed is true.
        bool isOpen = RaffleState.OPEN == s_raffleState;
        bool hasBalance = address(this).balance > 0;
        bool hasPlayers = s_players.length > 0;
        upkeepNeeded = (timeHasPassed && isOpen && hasBalance && hasPlayers);
        return (upkeepNeeded, "0x0"); // <- this "0x0" is a placeholder for our empty byte set"
    }

    // Get a random number
    // This random number needs to pick a player
    // Be automatically called
    // Send the user the money
    // Reset the players entry pool

    function performUpkeep(bytes calldata /* performData */) external {
        (bool upkeepNeeded, ) = checkUpkeep(""); //"" is a checkdata parameter that could be used to pass in extra information needed for the upkeep check. But for our purposes, we are assining the first return value of the variable upkeepNeeded. checkUpKeeps first return value will be upkeepNeeded, they're both boolean.
        if (!upkeepNeeded) {
            // if that boolean value is not true, we want to use a custom error, to show our users that the balance might be too low, or there are no players, or the raffle state is not open.
            revert Raffle__UpkeepNotNeeded(
                address(this).balance,
                s_players.length,
                uint256(s_raffleState)
            );
        }
        // however if upkeepNeeded is true, we imply that our raffle is open, and we have enough players, and we have enough balance, and the interval has passed. We reassign rafflestate to calculating, and we send the chainlink node a request for a random number.
        s_raffleState = RaffleState.CALCULATING;
        uint256 requestId = i_vrfCoordinator.requestRandomWords(
            i_gasLane, // gas lane
            i_subscriptionId, // id that we funded with link
            REQUEST_CONFIRMATIONS, // number of block confirmations
            i_callBackGasLimit, // gas limit to prevent overspend
            NUM_WORDS // random numbers
        ); // requestRandomWords is actually returning a uint256 requestID
        // request the rng <-were going to send the request
        // get the random number <- chainlink node will send us the number
        emit RequestedRaffleWinner(requestId);
    }

    function fulfillRandomWords(
        uint256 /* requestId, */,
        uint256[] memory randomWords
    ) internal override {
        // s_players = 10
        // rng = 12
        // 12 % 10 = 2 (index 2 is the winner)
        uint256 indexOfWinner = randomWords[0] % s_players.length;
        address payable winner = s_players[indexOfWinner];
        s_recentWinner = winner;
        s_raffleState = RaffleState.OPEN;
        s_players = new address payable[](0);
        s_lastTimeStamp = block.timestamp;
        emit PickedWinner(winner);
        (bool success, ) = s_recentWinner.call{value: address(this).balance}(
            ""
        );
        if (!success) {
            revert Raffle__TransferFailed();
        }
    }

    //* getter function */
    function getEntranceFee() external view returns (uint256) {
        return i_entranceFee;
    }

    function getRaffleState() external view returns (RaffleState) {
        return s_raffleState;
    }

    function getPlayer(uint256 indexOfPlayer) external view returns (address) {
        return s_players[indexOfPlayer];
    }

    function getRecentWinner() external view returns (address) {
        return s_recentWinner;
    }

    function getLengthOfPlayers() external view returns (uint256) {
        return s_players.length;
    }

    function getLastTimeStamp() external view returns (uint256) {
        return s_lastTimeStamp;
    }
}
