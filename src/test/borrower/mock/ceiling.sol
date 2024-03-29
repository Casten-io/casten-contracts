// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.7.6;

import "../../../test/mock/mock.sol";

contract CeilingMock is Mock {

    function values(uint loan) public returns(uint) {
        values_uint["values_loan"] = loan;
        return call("values");
    }

    function presentValue(uint) public view returns(uint) {
        return values_return["presentValue"];
    }

    function futureValue(uint) public view returns(uint) {
        return values_return["futureValue"];
    }

    function borrow (uint loan, uint amount) public {
        bytes32 name = "borrow";
        require(method_fail[name] == false);
        calls[name]++;
        values_uint["borrow_loan"] = loan;
        values_uint["borrow_amount"] = amount;
    }

    function repay(uint loan, uint amount) public {
        calls["repay"]++;
        values_uint["repay_loan"] = loan;
        values_uint["repay_amount"] = amount;

    }

    function file(uint loan, uint amount) public {
        calls["file"]++;
        values_uint["file_loan"] = loan;
        values_uint["file_amount"] = amount;
    }
}
