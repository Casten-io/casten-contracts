pragma solidity 0.8.13;
import "./BaseExchangeAdapter.sol"; 

contract CurveAdapter is BaseExchangeAdapter {

    address admin;
    mapping(address => int128) public curveId;

    error NOT_AUTHORIZED();

    modifier onlyAdmin {
        if(msg.sender != admin) {
            revert NOT_AUTHORIZED();
        }
        _;
    }

    constructor(
        address pool, 
        address _admin, 
        address[] memory tokens,
        int128[] memory ids    
    ) BaseExchangeAdapter(pool, pool) {
        admin = _admin;

        for(uint i=0; i< tokens.length; i++) {
            curveId[tokens[i]] = ids[i];
        }
    }

    function getTradeData(
        address fromToken, 
        address toToken, 
        uint256 amount, 
        uint256 minReceive, 
        bytes calldata data
    ) external override view returns(address _exchange, uint256 _value, bytes memory _transaction) {
        bytes memory callData = abi.encodeWithSignature(
            "exchange(int128,int128,uint256,uint256)",
            curveId[fromToken],
            curveId[toToken],
            amount,
            minReceive
        );

        return (exchange, 0, callData);
    }

    function setCurveId(address token, int128 id) external onlyAdmin {
        curveId[token] = id;
    }

    function changeAdmin(address newAdmin) external onlyAdmin {
        admin = newAdmin;
    }
}