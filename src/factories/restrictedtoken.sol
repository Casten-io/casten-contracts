// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.7.6;

import { RestrictedToken } from "./../token/restricted.sol";

interface RestrictedTokenFactoryLike {
    function newRestrictedToken(string calldata, string calldata) external returns (address);
}

contract RestrictedTokenFactory {
    function newRestrictedToken(string memory symbol, string memory name) public returns (address token) {
        RestrictedToken restrictedToken = new RestrictedToken(symbol, name);

        restrictedToken.rely(msg.sender);
        restrictedToken.deny(address(this));

        return (address(restrictedToken));
    }
}
