# multisafe-stages
Multisafe contract creation in stages

This repo takes the MultiSafe project (https://github.com/Trust-Machines/multiSafe) and breaks it down into 8 modules.

Each successive module builds on the previous one.

The goal is to demonstrate to the reader how a complete Clarity smart contract is created.

A side effect of this is also to help analyze the code for bugs etc.

# Pre-reqs
We expect the reader to have downloaded Clarinet. 

In addition we expect the reader to also be aware of the Clarity language. If not please refer to the book given at https://book.clarity-lang.org/ 
In this explanation we will look at understanding the use of the concepts explained in this book.

# Objective of MultiSafe contract

From the link (https://github.com/Trust-Machines/multisafe) MultiSafe is a shared crypto wallet for managing Stacks (STX) and Bitcoin (BTC).

# Division into modules 

The Multisafe project consists of 12 contracts as given in the contracts directory above. these files are given at the link https://github.com/Trust-Machines/multisafe/tree/main/contracts
 


We divide the functionality of MultiSafe is divided into the following 8 modules 
- Module 1: this consists of the sip010 fungible token template as well as an implementation of this template. The main file - verity-games is empty for this module.
- Module 2: 
