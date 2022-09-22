// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.7.6;

import { castenRoot } from "../../root.sol";
import { BorrowerDeployer } from "../../deployers/BorrowerDeployer.sol";
import { LenderDeployer } from "../../deployers/LenderDeployer.sol";

import "../../lib/ds-test/src/test.sol";
contract TestRoot is castenRoot {
    constructor (address deployUsr, address governance) castenRoot(deployUsr, governance) {
    }
    // Permissions
    // To simplify testing, we add helpers to authorize contracts on any component.

    // Needed for System Tests
    function relyBorrowerAdmin(address usr) public auth {
        BorrowerDeployer bD = BorrowerDeployer(address(borrowerDeployer));
        relyContract(bD.title(), usr);
        relyContract(bD.shelf(), usr);
        relyContract(bD.pile(), usr);
        relyContract(bD.feed(), usr);
    }

    // Needed for System Tests
    function relyLenderAdmin(address usr) public auth {
        LenderDeployer lD = LenderDeployer(address(lenderDeployer));
        relyContract(lD.juniorMemberlist(), usr);
        relyContract(lD.seniorMemberlist(), usr);
    }

    function denyBorrowerAdmin(address usr) public auth {
        BorrowerDeployer bD = BorrowerDeployer(address(borrowerDeployer));
        denyContract(bD.title(), usr);
        denyContract(bD.feed(), usr);
        denyContract(bD.shelf(), usr);
        denyContract(bD.pile(), usr);
    }
}
