// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.7.6;
pragma experimental ABIEncoderV2;

import "../../base_system.sol";

contract PrincipalRepayTest is BaseSystemTest {

    function setUp() public {
        baseSetup();
        createTestUsers();
        hevm = Hevm(HEVM_ADDRESS);
        hevm.warp(1234567);
        fundTranches();
    }


    function fundTranches() public {
        uint defaultAmount = 1000 ether;
        defaultInvest(defaultAmount);
        hevm.warp(block.timestamp + 1 days);
        coordinator.closeEpoch();
    }

    function repay(uint loanId, uint tokenId, uint amount, uint expectedDebt) public {
        uint initialBorrowerBalance = currency.balanceOf(borrower_);
        uint initialTrancheBalance = currency.balanceOf(address(reserve));
        uint initialCeiling = nftFeed.ceiling(loanId);
        borrower.repay(loanId, amount);
        assertPostCondition(loanId, tokenId, amount, initialBorrowerBalance, initialTrancheBalance, expectedDebt, initialCeiling);
    }

    function assertPreCondition(uint loanId, uint tokenId, uint repayAmount, uint expectedDebt) public {
        // assert: borrower loanOwner
        assertEq(title.ownerOf(loanId), borrower_);
        // assert: shelf nftOwner
        assertEq(collateralNFT.ownerOf(tokenId), address(shelf));
        // assert: loan has no open balance
        assertEq(shelf.balances(loanId), 0);
        // assert: loan has open debt
        assert(pile.debt(loanId) > 0);
        // assert: debt includes accrued interest (tolerance +/- 1)
        assertEq(pile.debt(loanId), expectedDebt, 10);
        // assert: borrower has enough funds
        assert(currency.balanceOf(borrower_) >= repayAmount);
    }

    function assertPostCondition(uint loanId, uint tokenId, uint repaidAmount, uint initialBorrowerBalance, uint initialTrancheBalance, uint expectedDebt, uint initialCeiling) public {
        // assert: borrower still loanOwner
        assertEq(title.ownerOf(loanId), borrower_);
        // assert: shelf still nftOwner
        assertEq(collateralNFT.ownerOf(tokenId), address(shelf));
        // assert: borrower funds decreased by the smaller of repaidAmount or totalLoanDebt
        if (repaidAmount > expectedDebt) {
            // make sure borrower did not pay more then hs debt
            repaidAmount = expectedDebt;

        }
        uint newBorrowerBalance = safeSub(initialBorrowerBalance, repaidAmount);
        assert(safeSub(newBorrowerBalance, currency.balanceOf(borrower_)) <= 1); // (tolerance +/- 1)
        // assert: shelf/tranche received funds
        // since we are calling balance inside repay, money is directly transferred to the tranche through shelf
        uint newTrancheBalance = safeAdd(initialTrancheBalance, repaidAmount);
        assertEq(currency.balanceOf(address(reserve)), newTrancheBalance, 10); // (tolerance +/- 1)
        // assert: debt amounts reduced by repayAmount (tolerance +/- 1)
        uint newDebt = safeSub(expectedDebt, repaidAmount);
        assert(safeSub(pile.debt(loanId), newDebt) <= 1);
        // aseert: initialCeiling did not increase
        assertEq(initialCeiling, nftFeed.ceiling(loanId));
    }

    function borrowAndRepay(address usr, uint nftPrice, uint riskGroup, uint expectedDebt, uint repayAmount) public {
        (uint loanId, uint tokenId) = createLoanAndWithdraw(usr, nftPrice, riskGroup);
        // supply borrower with additional funds to pay for accrued interest
        topUp(usr);
        // borrower allows shelf full control over borrower tokens
        Borrower(usr).doApproveCurrency(address(shelf), type(uint256).max);
        //repay after 1 year
        hevm.warp(block.timestamp + 365 days);
        assertPreCondition(loanId, tokenId, repayAmount, expectedDebt);
      //  repay(loanId, tokenId, repayAmount, expectedDebt);
    }

    function testRepayFullDebt() public {
        uint nftPrice = 200 ether; // -> ceiling 100 ether
        uint riskGroup = 1; // -> 12% per year

        // expected debt after 1 year of compounding
        uint expectedDebt = 112 ether;
        uint repayAmount = expectedDebt;
        borrowAndRepay(borrower_, nftPrice, riskGroup, expectedDebt, repayAmount);
    }

    function testRepayMaxLoanDebt() public {
        uint nftPrice = 200 ether; // -> ceiling 100 ether
        uint riskGroup = 1; // -> 12% per year


        // expected debt after 1 year of compounding
        uint expectedDebt = 112 ether;
        // borrower tries to repay twice his debt amount
        uint repayAmount = safeMul(expectedDebt, 2);
        borrowAndRepay(borrower_, nftPrice, riskGroup, expectedDebt, repayAmount);
    }

    function testPartialRepay() public {
        uint nftPrice = 200 ether; // -> ceiling 100 ether
        uint riskGroup = 1; // -> 12% per year

        // expected debt after 1 year of compounding
        uint expectedDebt = 112 ether;
        uint repayAmount = safeDiv(expectedDebt, 2);
        borrowAndRepay(borrower_, nftPrice, riskGroup, expectedDebt, repayAmount);
    }

    function testRepayDebtNoRate() public {
        uint nftPrice = 100 ether; // -> ceiling 100 ether
        uint riskGroup = 0; // -> no interest rate

        // expected debt after 1 year of compounding
        uint expectedDebt =  60 ether;
        uint repayAmount = expectedDebt;
        (uint loanId, uint tokenId) = createLoanAndWithdraw(borrower_, nftPrice, riskGroup);
        // borrower allows shelf full control over borrower tokens
        borrower.doApproveCurrency(address(shelf), type(uint256).max);
        //repay after 1 year
        hevm.warp(block.timestamp + 365 days);
        assertPreCondition(loanId, tokenId, repayAmount, expectedDebt);
        repay(loanId, tokenId, repayAmount, expectedDebt);
    }

    function testFailRepayNotLoanOwner() public {
        uint nftPrice = 200 ether; // -> ceiling 100 ether
        uint riskGroup = 1; // -> 12% per year

        // expected debt after 1 year of compounding
        uint expectedDebt = 112 ether;
        uint repayAmount = expectedDebt;

         // supply borrower with additional funds to pay for accrued interest
        topUp(borrower_);
        borrowAndRepay(randomUser_, nftPrice, riskGroup, expectedDebt, repayAmount);
    }

    function testFailRepayNotEnoughFunds() public {
        uint nftPrice = 200 ether; // -> ceiling 100 ether
        uint riskGroup = 1; // -> 12% per year

        // expected debt after 1 year of compounding
        uint expectedDebt = 112 ether;
        uint repayAmount = expectedDebt;
        (uint loanId, uint tokenId) = createLoanAndWithdraw(borrower_, nftPrice, riskGroup);

        hevm.warp(block.timestamp + 365 days);

        // do not supply borrower with additional funds to repay interest

        // borrower allows shelf full control over borrower tokens
        borrower.doApproveCurrency(address(shelf), type(uint256).max);
        repay(loanId, tokenId, repayAmount, expectedDebt);
    }

    function testFailRepayLoanNotFullyWithdrawn() public {
       uint nftPrice = 200 ether; // -> ceiling 100 ether
       uint riskGroup = 1; // -> 12% per year

       uint ceiling = computeCeiling(riskGroup, nftPrice); // 50% 100 ether
       uint borrowAmount = ceiling;
       uint withdrawAmount = safeSub(ceiling, 2); // half the borrowAmount
       uint repayAmount = ceiling;
       uint expectedDebt = 56 ether; // borrowamount + interest

       (uint loanId, uint tokenId) = issueNFTAndCreateLoan(borrower_);
        // lock nft
        lockNFT(loanId, borrower_);
        // priceNFT
        priceNFTandSetRisk(tokenId, nftPrice, riskGroup);
        // borrower add loan balance of full ceiling
        borrower.borrow(loanId, borrowAmount);
        // borrower just withdraws half of ceiling -> loanBalance remains
        borrower.withdraw(loanId, withdrawAmount, borrower_);
        hevm.warp(block.timestamp + 365 days);

        // supply borrower with additional funds to pay for accrued interest
        topUp(borrower_);
        // borrower allows shelf full control over borrower tokens
        borrower.doApproveCurrency(address(shelf), type(uint256).max);
        repay(loanId, tokenId, repayAmount, expectedDebt);
    }

    function testFailRepayZeroDebt() public {
        uint nftPrice = 200 ether; // -> ceiling 100 ether
        uint riskGroup = 1; // -> 12% per year

        // expected debt after 1 year of compounding
        uint expectedDebt = 112 ether;
        uint repayAmount = expectedDebt;
        (uint loanId, uint tokenId) = issueNFTAndCreateLoan(borrower_);
        // lock nft
        lockNFT(loanId, borrower_);
         // priceNFT
        priceNFTandSetRisk(tokenId, nftPrice, riskGroup);

        // borrower does not borrow

        // supply borrower with additional funds to pay for accrued interest
        topUp(borrower_);
        // borrower allows shelf full control over borrower tokens
        borrower.doApproveCurrency(address(shelf), type(uint256).max);
        repay(loanId, tokenId, repayAmount, expectedDebt);
    }

    function testFailRepayCurrencyNotApproved() public {
        uint nftPrice = 200 ether; // -> ceiling 100 ether
        uint riskGroup = 1; // -> 12% per year

        // expected debt after 1 year of compounding
        uint expectedDebt = 112 ether;
        uint repayAmount = expectedDebt;
        (uint loanId, uint tokenId) = createLoanAndWithdraw(borrower_, nftPrice, riskGroup);

        //repay after 1 year
        hevm.warp(block.timestamp + 365 days);

         // supply borrower with additional funds to pay for accrued interest
        topUp(borrower_);
        repay(loanId, tokenId, repayAmount, expectedDebt);
    }

    function testFailBorowFullAmountTwice() public {
        uint nftPrice = 200 ether; // -> ceiling 100 ether
        uint riskGroup = 1; // -> 12% per year

        uint ceiling = computeCeiling(riskGroup, nftPrice);

        // expected debt after 1 year of compounding
        uint expectedDebt = 112 ether;
        uint repayAmount = expectedDebt;

        (uint loanId, uint tokenId) = createLoanAndWithdraw(borrower_, nftPrice, riskGroup);
        // supply borrower with additional funds to pay for accrued interest
        topUp(borrower_);
        // borrower allows shelf full control over borrower tokens
        borrower.doApproveCurrency(address(shelf), type(uint256).max);
        //repay after 1 year
        hevm.warp(block.timestamp + 365 days);
        assertPreCondition(loanId, tokenId, repayAmount, expectedDebt);
        repay(loanId, tokenId, repayAmount, expectedDebt);

        // should fail -> principal = 0
        borrower.borrow(loanId, ceiling);
    }
}
