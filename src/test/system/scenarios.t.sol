// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.7.6;
pragma experimental ABIEncoderV2;

import "./base_system.sol";
import "./users/borrower.sol";
import "./users/admin.sol";

contract ScenarioTest is BaseSystemTest {

    function setUp() public {
        hevm = Hevm(HEVM_ADDRESS);
        hevm.warp(1234567);
        baseSetup();
        createTestUsers();
        // setup hevm
        navFeed_ = NAVFeedLike(address(nftFeed));
    }

    // --- Tests ---
    function testBorrowTransaction() public {
        // collateralNFT value
        (uint nftPrice, uint riskGroup) = defaultCollateral();
        // create borrower collateral collateralNFT
        uint tokenId = collateralNFT.issue(borrower_);
        // price nft
        priceNFTandSetRisk(tokenId, nftPrice, riskGroup);
        // borrower issue loan
        uint loan =  borrower.issue(collateralNFT_, tokenId);
        uint ceiling = navFeed_.ceiling(loan);

        borrower.approveNFT(collateralNFT, address(shelf));
        fundLender(ceiling);
        borrower.borrowAction(loan, ceiling);
        checkAfterBorrow(tokenId, ceiling);
    }

    function testBorrowAndRepay() public {
        (uint nftPrice, uint riskGroup) = defaultCollateral();
        borrowRepay(nftPrice, riskGroup);
    }


    function testMediumSizeLoans() public {
        (uint nftPrice, uint riskGroup) = defaultCollateral();
        nftPrice = 20000 ether;
        borrowRepay(nftPrice, riskGroup);
    }

     function testHighSizeLoans() public {
        (uint nftPrice, uint riskGroup) = defaultCollateral();
        nftPrice = 20000000 ether;
        borrowRepay(nftPrice, riskGroup);
     }

    function testRepayFullAmount() public {
        (uint loan, uint tokenId,) = setupOngoingLoan();

        hevm.warp(block.timestamp + 1 days);

        // borrower needs some currency to pay rate
        setupRepayReq();
        uint reserveShould = pile.debt(loan) + currReserveBalance();
        // close without defined amount
        borrower.doClose(loan);
        uint totalT = uint(currency.totalSupply());
        checkAfterRepay(loan, tokenId, totalT, reserveShould);
    }

    function testLongOngoing() public {
        (uint loan, uint tokenId, ) = setupOngoingLoan();

        // interest 5% per day 1.05^300 ~ 2273996.1286 chi
        hevm.warp(block.timestamp + 300 days);

        // borrower needs some currency to pay rate
        setupRepayReq();

        uint reserveShould = pile.debt(loan) + currReserveBalance();

        // close without defined amount
        borrower.doClose(loan);

        uint totalT = uint(currency.totalSupply());
        checkAfterRepay(loan, tokenId, totalT, reserveShould);
    }

    function testMultipleBorrowAndRepay() public {
        uint nftPrice = 10 ether;
        uint riskGroup = 2;
        // uint rate = uint(1000000564701133626865910626);

        fundLender(1000 ether);
        uint tBorrower = 0;
        // borrow
        for (uint i = 1; i <= 10; i++) {

            nftPrice = i * 100;

            // create borrower collateral collateralNFT
            uint tokenId = collateralNFT.issue(borrower_);
            // collateralNFT whitelist
            uint loan = setupLoan(tokenId, collateralNFT_, nftPrice, riskGroup);
            uint ceiling = navFeed_.ceiling(i);

            borrower.approveNFT(collateralNFT, address(shelf));


            borrower.borrowAction(loan, ceiling);
            tBorrower += ceiling;
            checkAfterBorrow(i, tBorrower);
        }

        // repay
        uint tTotal = currency.totalSupply();

        // allow pile full control over borrower tokens
        borrower.doApproveCurrency(address(shelf), type(uint256).max);

        uint reserveBalance = currency.balanceOf(address(reserve));
        for (uint i = 1; i <= 10; i++) {
            nftPrice = i * 100;
            uint ceiling = computeCeiling(riskGroup, nftPrice);
            // repay transaction
            borrower.repayAction(i, ceiling);

            reserveBalance += ceiling;
            checkAfterRepay(i, i, tTotal, reserveBalance);
        }
    }

    function testFailBorrowSameTokenIdTwice() public {
        // collateralNFT value
        (uint nftPrice, uint riskGroup) = defaultCollateral();
        // create borrower collateral collateralNFT
        uint tokenId = collateralNFT.issue(borrower_);
        // price nft and set risk
        priceNFTandSetRisk(tokenId, nftPrice, riskGroup);
        // borrower issue loans
        uint loan =  borrower.issue(collateralNFT_, tokenId);
        uint ceiling = navFeed_.ceiling(loan);

        borrower.approveNFT(collateralNFT, address(shelf));
        borrower.borrowAction(loan, ceiling);
        checkAfterBorrow(tokenId, ceiling);

        // should fail
        borrower.borrowAction(loan, ceiling);
    }

    function testFailBorrowNonExistingToken() public {
        borrower.borrowAction(42, 100);
    }

    function testFailBorrowNotWhitelisted() public {
        collateralNFT.issue(borrower_);
        borrower.borrowAction(1, 100);
    }

    function testFailAdmitNonExistingcollateralNFT() public {
        // borrower issue loan
        uint loan =  borrower.issue(collateralNFT_, 123);

        (uint nftPrice, uint riskGroup) = defaultCollateral();
        // price nft and set risk
        priceNFTandSetRisk(20, nftPrice, riskGroup);
        uint ceiling = computeCeiling(riskGroup, nftPrice);
        borrower.borrowAction(loan, ceiling);
    }

    function testFailBorrowcollateralNFTNotApproved() public {
        defaultCollateral();
        uint tokenId = collateralNFT.issue(borrower_);
        // borrower issue loans
        uint loan =  borrower.issue(collateralNFT_, tokenId);
        uint ceiling = navFeed_.ceiling(loan);
        borrower.borrowAction(loan, ceiling);
    }
}
