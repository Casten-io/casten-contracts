// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.7.6;
pragma experimental ABIEncoderV2;

import "../../lib/ds-test/src/test.sol";
import "./base_system.sol";

//  Contract to manage the config variables of a Casten test deployment
contract Config {
    struct CastenConfig {
        // borrower variables
        uint discountRate;
        string titleName;
        string titleSymbol;

        // lender variables
        uint seniorInterestRate;
        uint maxReserve;
        uint maxSeniorRatio;
        uint minSeniorRatio;
        uint challengeTime;
        string seniorTokenName;
        string seniorTokenSymbol;
        string juniorTokenName;
        string juniorTokenSymbol;

        // mkr variables
        uint mkrMAT;
        uint mkrStabilityFee;
        bytes32 mkrILK;
    }

    // returns a default config for a Casten deployment
    function defaultConfig() public pure returns(CastenConfig memory t) {
        return  CastenConfig({
            // 3% per day
            discountRate: uint(1000000342100000000000000000),
            titleName: "Casten Loan Token",
            titleSymbol: "TLNT",
            // 2% per day
            seniorInterestRate: uint(1000000229200000000000000000),
            maxReserve: type(uint256).max,
            maxSeniorRatio: 0.85 *10**27,
            minSeniorRatio: 0.75 *10**27,
            challengeTime: 1 hours,
            seniorTokenName: "DROP Token",
            seniorTokenSymbol: "DROP",
            juniorTokenName: "TIN Token",
            juniorTokenSymbol: "TIN",
            mkrMAT: 1.10 * 10**27,
            mkrStabilityFee: 10**27,
            mkrILK: "drop"  
        });
    }
}
