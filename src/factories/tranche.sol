// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.7.6;

import { Tranche } from "./../tranche.sol";

interface TrancheFactoryLike {
    function newTranche(address, address) external returns (address);
}

contract TrancheFactory {
    function newTranche(address currency, address restrictedToken) public returns (address token) {
        Tranche tranche = new Tranche(currency, restrictedToken);

        tranche.rely(msg.sender);
        tranche.deny(address(this));

        return (address(tranche));
    }
}
