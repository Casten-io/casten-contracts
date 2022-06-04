// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.7.6;
import { Operator } from "./../operator.sol";

interface OperatorFactoryLike {
    function newOperator(address) external returns (address);
}

contract OperatorFactory {
    function newOperator(address tranche) public returns (address) {
        Operator operator = new Operator(tranche);
        operator.rely(msg.sender);
        operator.deny(address(this));
        return address(operator);
    }
}
