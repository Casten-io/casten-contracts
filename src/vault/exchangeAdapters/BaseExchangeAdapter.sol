pragma solidity ^0.7.0;

contract BaseExchangeAdapter {
    address public exchange;
    address spender;

    // error NOT_IMPLEMENTED();
    
    constructor(address _exchange, address _spender) {
        exchange = _exchange;
        spender = _spender;
    }   

    function getTradeData(
        address fromToken, 
        address toToken, 
        uint256 amount, 
        uint256 minReceive, 
        bytes calldata data
    ) external virtual view returns(address _exchange, uint256 _value, bytes memory _transaction) {
        // revert NOT_IMPLEMENTED(); 
        revert("NOT_INITALIZED");
    }

    function getSpender() external virtual view returns (address) {
        return spender;
    }
}