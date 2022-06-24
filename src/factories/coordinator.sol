// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.7.6;

import { EpochCoordinator } from "./../EpochCoordinator.sol";
import "../lib/casten-erc20/src/erc20.sol";
import "../EpochCoordinator.sol";

interface CoordinatorFactoryLike {
    function newCoordinator(uint) external returns (address);
}

contract CoordinatorFactory {
    function newCoordinator(uint challengeTime) public returns (address) {
        EpochCoordinator coordinator = new EpochCoordinator(challengeTime);
        coordinator.rely(msg.sender);
        coordinator.deny(address(this));
        return address(coordinator);
    }
}
