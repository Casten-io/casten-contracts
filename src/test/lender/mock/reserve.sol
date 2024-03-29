// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.7.6;

import "../../../lib/ds-test/src/test.sol";
import "../../../lib/casten-auth/src/auth.sol";
import "../../../test/mock/mock.sol";

interface CurrencyLike {
    function transferFrom(address from, address to, uint amount) external;
    function balanceOf(address usr) external returns (uint);
}

contract ReserveMock is Mock, Auth {
    CurrencyLike public currency;
    constructor(address currency_) {
        wards[msg.sender] = 1;
        currency = CurrencyLike(currency_);
    }

    function file(bytes32 , uint currencyAmount) public {
        values_uint["borrow_amount"] = currencyAmount;
    }

    function balance() public returns (uint) {
        return call("balance");
    }

    function totalBalance() public view returns (uint) {
        return values_return["balance"];
    }

    function totalBalanceAvailable() public view returns (uint) {
        return values_return["totalBalanceAvailable"];
    }

    function hardDeposit(uint amount) public {
        values_uint["deposit_amount"] = amount;
        currency.transferFrom(msg.sender, address(this), amount);
    }

    function hardPayout(uint amount) public {
        values_uint["deposit_amount"] = amount;
        currency.transferFrom(address(this), msg.sender, amount);
    }

    function deposit(uint amount) public {
        values_uint["deposit_amount"] = amount;
        currency.transferFrom(msg.sender, address(this), amount);
    }

    function payout(uint amount) public {
        values_uint["deposit_amount"] = amount;
        currency.transferFrom(address(this), msg.sender, amount);
    }

    function payoutForLoans(uint amount) public {
        values_uint["deposit_amount"] = amount;
        currency.transferFrom(address(this), msg.sender, amount);
    }

    function originationFeePerc() public view returns (uint) {
        return values_return["originationFeePerc"];
    }

    function treasury() public view returns (address) {
        return values_address_return["treasury"];
    }

    function feeOnInterestPerc() public view returns (uint) {
        return values_return["feeOnInterestPerce"];
    }

    function transferFeeOnInterest(uint amount) public {
        values_uint["transferFeeOnInterest"] = amount;
        currency.transferFrom(address(this), values_address_return["treasury"], amount);
    }
}

