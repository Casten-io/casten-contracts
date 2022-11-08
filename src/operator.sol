// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.7.6;

import "./lib/casten-auth/src/auth.sol";

interface TrancheLike {
    function supplyOrder(address usr, uint currencyAmount) external;
    function redeemOrder(address usr, uint tokenAmount) external;
    function disburse(address usr) external returns (uint payoutCurrencyAmount, uint payoutTokenAmount, uint remainingSupplyCurrency,  uint remainingRedeemToken);
    function disburse(address usr, uint endEpoch) external returns (uint payoutCurrencyAmount, uint payoutTokenAmount, uint remainingSupplyCurrency,  uint remainingRedeemToken);
    function currency() external view returns (address);
}

interface RestrictedTokenLike {
    function hasMember(address) external view returns (bool);
}

interface EIP2612PermitLike {
    function permit(address owner, address spender, uint value, uint deadline, uint8 v, bytes32 r, bytes32 s) external;
}

interface DaiPermitLike {
    function permit(address holder, address spender, uint256 nonce, uint256 expiry, bool allowed, uint8 v, bytes32 r, bytes32 s) external;
}
/**
    @title Operator
    @notice This contract is used to supply and redeem tokens from a tranche.
            Once a epoch is finalized, the users can 'disburse()' the tokens from the tranche.

 */
contract Operator is Auth {
    TrancheLike public tranche;
    RestrictedTokenLike public token;

    // Events
    event SupplyOrder(uint indexed amount, address indexed usr);
    event RedeemOrder(uint indexed amount, address indexed usr);
    event Depend(bytes32 indexed contractName, address addr);
    event Disburse(address indexed usr);

    constructor(address tranche_) {
        tranche = TrancheLike(tranche_);
        wards[msg.sender] = 1;
        emit Rely(msg.sender);
    }

    ///@notice disburse tokens from the tranche. Transfers the pending shares or currency to the investor.
    ///@dev Only investors that are on the memberlist can disburse
    function disburse() external
        returns(uint payoutCurrencyAmount, uint payoutTokenAmount, uint remainingSupplyCurrency,  uint remainingRedeemToken)
    {
        require((token.hasMember(msg.sender) == true), "user-not-allowed-to-hold-token");
        emit Disburse(msg.sender);
        return tranche.disburse(msg.sender);
    }

    ///@notice disburse tokens from the tranche upto a specific completed epoch. Transfers the pending shares or currency to the investor.
    ///@dev Only investors that are on the memberlist can disburse
    function disburse(uint endEpoch) external
        returns(uint payoutCurrencyAmount, uint payoutTokenAmount, uint remainingSupplyCurrency,  uint remainingRedeemToken)
    {
        require((token.hasMember(msg.sender) == true), "user-not-allowed-to-hold-token");
        emit Disburse(msg.sender);
        return tranche.disburse(msg.sender, endEpoch);
    }

    ///@notice submit a supply order to the tranche. Only investors that are on the memberlist can submit supplyOrders
    ///@param amount the amount of currency to supply.
    function supplyOrder(uint amount) public {
        require((token.hasMember(msg.sender) == true), "user-not-allowed-to-hold-token");
        tranche.supplyOrder(msg.sender, amount);
        emit SupplyOrder(amount, msg.sender);
    }

    ///@notice submit a redeem order to the tranche. Only investors that are on the memberlist can submit redeemOrders
    ///@param amount the amount of tokens(shares) to redeem.
    function redeemOrder(uint amount) public {
        require((token.hasMember(msg.sender) == true), "user-not-allowed-to-hold-token");
        tranche.redeemOrder(msg.sender, amount);
        emit RedeemOrder(amount, msg.sender);
    }

    // --- Permit Support ---
    function supplyOrderWithDaiPermit(uint amount, uint nonce, uint expiry, uint8 v, bytes32 r, bytes32 s) public {
        DaiPermitLike(tranche.currency()).permit(msg.sender, address(tranche), nonce, expiry, true, v, r, s);
        supplyOrder(amount);
    }
    function supplyOrderWithPermit(uint amount, uint value, uint deadline, uint8 v, bytes32 r, bytes32 s) public {
        EIP2612PermitLike(tranche.currency()).permit(msg.sender, address(tranche), value, deadline, v, r, s);
        supplyOrder(amount);
    }
    function redeemOrderWithPermit(uint amount, uint value, uint deadline, uint8 v, bytes32 r, bytes32 s) public {
        EIP2612PermitLike(address(token)).permit(msg.sender, address(tranche), value, deadline, v, r, s);
        redeemOrder(amount);
    }

    ///@dev sets the dependency to another contract
    function depend(bytes32 contractName, address addr) public auth {
        if (contractName == "tranche") { tranche = TrancheLike(addr); }
        else if (contractName == "token") { token = RestrictedTokenLike(addr); }
        else revert();
        emit Depend(contractName, addr);
    }
}
