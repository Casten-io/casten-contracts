// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.7.6;

import "./lib/casten-math/src/math.sol";
import "./lib/casten-auth/src/auth.sol";

import { TitleOwned, TitleLike } from "./lib/casten-title/src/title.sol";

interface NFTLike {
    function ownerOf(uint256 tokenId) external view returns (address owner);
    function transferFrom(address from, address to, uint256 tokenId) external;
}

interface TokenLike {
    function totalSupply() external view returns(uint);
    function balanceOf(address) external view returns (uint);
    function transferFrom(address,address,uint) external returns (bool);
    function transfer(address, uint) external returns (bool);
    function approve(address, uint) external;
}

interface PileLike {
    function total() external view returns(uint);
    function debt(uint) external returns (uint);
    function accrue(uint) external;
    function increaseDebt(uint, uint) external;
    function deccreaseDebt(uint, uint) external;

    function previousDebt(uint loan) external view returns (uint);
    function setLoanInfo(uint256 _loan, uint256 _debt, uint256 _newInterest) external;
    function getTotalInterestAccrued(uint loan) external view returns (uint);
}

interface NAVFeedLike {
    function borrow(uint loan, uint currencyAmount) external;
    function repay(uint loan, uint currencyAmount) external;
    function presentValue(uint loan) external view returns (uint);
    function futureValue(uint loan) external view returns (uint);
    function zeroPV(uint loan) external view returns (bool);
}

interface ReserveLike {
    function deposit(uint currencyAmount) external;
    function payoutForLoans(uint currencyAmount) external;
    function transferFeeOnInterest(uint _amt) external;
    function treasury() external view returns(address);
    function originationFeePerc() external view returns(uint256);
    function feeOnInterestPerc() external view returns(uint256);
}

interface SubscriberLike {
    function borrowEvent(uint loan, uint amount) external;
    function repayEvent(uint loan, uint amount) external;
    function lockEvent(uint loan) external;
    function unlockEvent(uint loan) external;
}

interface AssessorLike {
    function reBalance() external;
}

///@title Shelf
///@notice Shelf is the borrower-facing contract. The borrower can interact with this contract to borrow, repay.

contract Shelf is Auth, TitleOwned, Math {

    // --- Data ---
    NAVFeedLike         public ceiling;
    PileLike            public pile;
    TokenLike           public currency;
    ReserveLike         public reserve;
    AssessorLike        public assessor;
    SubscriberLike      public subscriber;

    uint                public balance;

    struct Loan {
        address registry;
        uint256 tokenId;
    }

    mapping (uint => uint) public balances;
    mapping (uint => Loan) public shelf;
    mapping (bytes32 => uint) public nftlookup;

    // Events
    event Close(uint indexed loan);
    event Issue(address indexed registry_, uint indexed token_);
    event Borrow(uint indexed loan, uint currencyAmount);
    event Withdraw(uint indexed loan, uint currencyAmount, address usr);
    event Repay(uint indexed loan, uint currencyAmount);
    event Recover(uint indexed loan, address usr, uint currencyAmount);
    event Lock(uint indexed loan);
    event Unlock(uint indexed loan);
    event Claim(uint indexed loan, address usr);
    event Depend(bytes32 indexed contractName, address addr);

    constructor(address currency_, address title_, address pile_, address ceiling_) TitleOwned(title_) {
        currency = TokenLike(currency_);
        pile = PileLike(pile_);
        ceiling = NAVFeedLike(ceiling_);

        wards[msg.sender] = 1;
        emit Rely(msg.sender);
    }

    function token(uint loan) public view returns (address registry, uint nft) {
        return (shelf[loan].registry, shelf[loan].tokenId);
    }

    /**
        @notice Issues a new loan in casten - it requires the ownership of an nft.
        @dev Anyone can issue a loan as long as they own the nft. Issued loan is not valid until admin sets the loan params.
        @param registry_ address of the nft registry
        @param token_ id of the nft
        @return loan id
     */
    function issueLoan(address registry_, uint token_) external returns (uint) {
        require(NFTLike(registry_).ownerOf(token_) == msg.sender, "nft-not-owned");
        bytes32 nft = keccak256(abi.encodePacked(registry_, token_));
        require(nftlookup[nft] == 0, "nft-in-use");
        uint loan = title.issue(msg.sender);
        nftlookup[nft] = loan;
        shelf[loan].registry = registry_;
        shelf[loan].tokenId = token_;

        emit Issue(registry_, token_);
        return loan;
    }

    /**
        @notice Starts the borrow process of a loan.
        @dev The method can only be called if the nft is locked. A max ceiling needs to be defined by an oracle.
        @param loan id of the loan
        @param currencyAmount amount of currency to borrow
     */
    function borrow(uint loan, uint currencyAmount) external owner(loan) {
        require(nftLocked(loan), "nft-not-locked");

        if(address(subscriber) != address(0)) {
            subscriber.borrowEvent(loan, currencyAmount);
        }

        uint previousDebt = pile.previousDebt(loan);
        pile.accrue(loan);

        uint loanDebt = pile.debt(loan);
        uint interestAccrued = loanDebt - previousDebt;

        // payout to shelf
        reserve.payoutForLoans(currencyAmount);
        
        uint256 originationFee = safeDiv(safeMul(currencyAmount, reserve.originationFeePerc()), 100_00);
        balances[loan] = safeAdd(balances[loan], (currencyAmount - originationFee));
        balance = safeAdd(balance, (currencyAmount - originationFee));
        require(currency.transfer(reserve.treasury(), originationFee), "fee-transfer-failed");


        // increase NAV
        ceiling.borrow(loan, currencyAmount);
        pile.increaseDebt(loan, currencyAmount);

        // reBalance lender interest bearing amount based on new NAV
        assessor.reBalance();

        uint256 totalInterest = pile.getTotalInterestAccrued(loan);
        pile.setLoanInfo(loan, pile.debt(loan), safeAdd(interestAccrued, totalInterest));

        emit Borrow(loan, currencyAmount);
    }


    /// @notice transfers the borrowed amount to the borrower account
    /// @param loan id of the loan
    /// @param currencyAmount amount of currency to withdraw
    /// @param usr address of the borrower
    function withdraw(uint loan, uint currencyAmount, address usr) external owner(loan) {
        require(nftLocked(loan), "nft-not-locked");
        require(currencyAmount <= balances[loan], "withdraw-amount-too-high");

        balances[loan] = safeSub(balances[loan], currencyAmount);
        balance = safeSub(balance, currencyAmount);
        require(currency.transfer(usr, currencyAmount), "currency-transfer-failed");
        emit Withdraw(loan, currencyAmount, usr);
    }
    
    /// @notice repays the entire or partial debt of a loan
    /// @dev On every repayment, as fee is charged on the interest accrued and is transferred to the reserve.
    /// @param loan id of the loan
    /// @param currencyAmount amount of currency to repay
    function repayLoan(uint loan, uint currencyAmount) external owner(loan) {
        require(nftLocked(loan), "nft-not-locked");
        require(balances[loan] == 0, "withdraw-required-before-repay");

        if(address(subscriber) != address(0)) {
            subscriber.repayEvent(loan, currencyAmount);
        }

        uint previousDebt = pile.previousDebt(loan);
        pile.accrue(loan);
        uint loanDebt = pile.debt(loan);

        uint interestAccrued = loanDebt - previousDebt;

        // only repay max loan debt
        if (currencyAmount > loanDebt) {
            currencyAmount = loanDebt;
        }
        require(currency.transferFrom(msg.sender, address(this), currencyAmount), "currency-transfer-failed");
        ceiling.repay(loan, currencyAmount);
        pile.deccreaseDebt(loan, currencyAmount);
        reserve.deposit(currencyAmount);

        // reBalance lender interest bearing amount based on new NAV
        assessor.reBalance();

        uint debtAfterRepayment = pile.debt(loan);
        uint feeOnInterest = safeDiv(safeMul(interestAccrued, reserve.feeOnInterestPerc()), 100_00);
        reserve.transferFeeOnInterest(feeOnInterest);

        if(currencyAmount > loanDebt || debtAfterRepayment == 0) {
            pile.setLoanInfo(loan, 0, 0); //loan repaid fully, so reset the values 
        } else {
            pile.setLoanInfo(loan, debtAfterRepayment, interestAccrued); //debt after repayment
        }

        emit Repay(loan, currencyAmount);
    }

    /**
        @notice Closes the loan and returns the nft to the borrower.
        @dev The loan should be repaid in full before closing. The NFT should be unlocked before closing.
        @param loan id of the loan
     */
    function close(uint loan) external {
        require(!nftLocked(loan), "nft-locked");
        (address registry, uint tokenId) = token(loan);
        require(title.ownerOf(loan) == msg.sender || NFTLike(registry).ownerOf(tokenId) == msg.sender, "not-loan-or-nft-owner");
        title.close(loan);
        bytes32 nft = keccak256(abi.encodePacked(shelf[loan].registry, shelf[loan].tokenId));
        nftlookup[nft] = 0;
        _resetLoanBalance(loan);
        emit Close(loan);
    }

    /**
        @notice a collector can recover defaulted loans. It is not required to recover the entire loan debt
        @dev The loan should have 'claim()'ed before calling this method.
        @param loan id of the loan
        @param currencyAmount amount of currency to collect
        @param usr address of the collector
     */
    function recover(uint loan, address usr, uint currencyAmount) external auth {
        pile.accrue(loan);

        uint loanDebt = pile.debt(loan);

        require(currency.transferFrom(usr, address(this), currencyAmount), "currency-transfer-failed");

        ceiling.repay(loan, loanDebt);
        // sets loan debt to 0
        pile.deccreaseDebt(loan, loanDebt);
        _resetLoanBalance(loan);
        reserve.deposit(currencyAmount);
        // reBalance lender interest bearing amount based on new NAV
        assessor.reBalance();
        emit Recover(loan, usr, currencyAmount);
    }

    function _repay(uint loan, address usr, uint currencyAmount) internal {
        pile.accrue(loan);
        uint loanDebt = pile.debt(loan);

        // only repay max loan debt
        if (currencyAmount > loanDebt) {
            currencyAmount = loanDebt;
        }
        require(currency.transferFrom(usr, address(this), currencyAmount), "currency-transfer-failed");
        ceiling.repay(loan, currencyAmount);
        pile.deccreaseDebt(loan, currencyAmount);

        reserve.deposit(currencyAmount);
        // reBalance lender interest bearing amount based on new NAV
        assessor.reBalance();
    }


    /**
        @notice locks an nft in the shelf
        @dev requires an issued loan
        @param loan id of the loan
     */
    function lock(uint loan) external owner(loan) {
        if(address(subscriber) != address(0)) {
            subscriber.lockEvent(loan);
        }
        NFTLike(shelf[loan].registry).transferFrom(msg.sender, address(this), shelf[loan].tokenId);
        emit Lock(loan);
    }
    
    /**
        @notice unlocks an nft in the shelf. The loan should be repaid in full or 100% write off.
        @param loan id of the loan
     */
    function unlock(uint loan) external owner(loan) {
        // loans can be unlocked and closed when the debt is 0, or the loan is written off 100%
        uint debt_ = pile.debt(loan);

        require(debt_ == 0 || ceiling.zeroPV(loan), "loan-has-outstanding-debt");

        if (address(subscriber) != address(0)) {
            subscriber.unlockEvent(loan);
        }

        NFTLike(shelf[loan].registry).transferFrom(address(this), msg.sender, shelf[loan].tokenId);

        emit Unlock(loan);
    }

    ///@dev sets the dependency to another contract
    function depend(bytes32 contractName, address addr) external auth {
        if (contractName == "token") { currency = TokenLike(addr); }
        else if (contractName == "title") { title = TitleLike(addr); }
        else if (contractName == "pile") { pile = PileLike(addr); }
        else if (contractName == "ceiling") { ceiling = NAVFeedLike(addr); }
        else if (contractName == "reserve") {
            if (address(reserve) != address(0)) currency.approve(address(reserve), uint(0));
            currency.approve(addr, type(uint256).max);
            reserve = ReserveLike(addr);
        }
        else if (contractName == "assessor") { assessor = AssessorLike(addr);}
        else if (contractName == "subscriber") { subscriber = SubscriberLike(addr); }
        else revert();
        emit Depend(contractName, addr);
    }

    function nftLocked(uint loan) public view returns (bool) {
        return NFTLike(shelf[loan].registry).ownerOf(shelf[loan].tokenId) == address(this);
    }

    // a loan can be claimed by a collector if the loan debt is above the loan threshold
    // transfers the nft to the collector
    /**
        @notice claims a loan if the loan debt is above the loan threshold
        @dev The loan is assigned by admins to a collector.
        @param loan id of the loan
        @param usr address of the collector
     */
    function claim(uint loan, address usr) public auth {
        NFTLike(shelf[loan].registry).transferFrom(address(this), usr, shelf[loan].tokenId);
        emit Claim(loan, usr);
    }

    function _resetLoanBalance(uint loan) internal {
        uint loanBalance = balances[loan];
        if (loanBalance  > 0) {
            balances[loan] = 0;
            balance = safeSub(balance, loanBalance);
        }
    }

    // returns the total number of loans including closed loans
    function loanCount() public view returns (uint) {
        return title.count();
    }
}
