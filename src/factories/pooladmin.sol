// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.7.6;

import { PoolAdmin } from "./../admin/PoolAdmin.sol";

contract PoolAdminFactory {
    function newPoolAdmin() public returns (address) {
        PoolAdmin poolAdmin = new PoolAdmin();

        poolAdmin.rely(msg.sender);
        poolAdmin.deny(address(this));

        return address(poolAdmin);
    }
}
