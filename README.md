# Probably random raffle contracts

## About

This code is to create a probable random start contract lottery.

## What we want it to do?

1. Users can enter by paying for a ticket.
   1.  The ticket fees are going to the winter during the draw
2. After X period of time, the lottery will automatically draw a winner
   1. And this will be done programmaticaly 
3. Using chainlink vrf & chainlink automation
   1. Chainlink VRF -> Randomness
   2. Chainlink Automation -> Time based trigger

## Tests!
1. Write some deploy scripts
2. Write our tests so that 
   1. They work on a local chain
   2. Test net
   3. forked mainnet