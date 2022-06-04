// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.7.6;

import { Reserve } from "./../reserve.sol";

interface ReserveFactoryLike {
    function newReserve(address) external returns (address);
}

contract ReserveFactory {
    function newReserve(address currency) public returns (address) {
        Reserve reserve = new Reserve(currency);
        reserve.rely(msg.sender);
        reserve.deny(address(this));
        return address(reserve);
    }
}
