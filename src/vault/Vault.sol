pragma solidity >=0.8.0;

interface ERC20Like {
    function balanceOf(address) external view returns (uint);
    function transferFrom(address, address, uint) external returns (bool);
    function transfer(address to, uint amount) external returns (bool);
    function mint(address, uint) external;
    function burn(address, uint) external;
    function totalSupply() external view returns (uint);
    function approve(address usr, uint amount) external;
}

interface TrancheLike{
    function supplyOrder(address usr, address funder, uint newSupplyAmount) external;
    function redeemOrder(address usr, address funder, uint newRedeemAmount) external;
    function disburse(address usr) external;
    function token() external view returns (ERC20Like);
}

interface AdapterLike {
    function getTradeData(
        address fromToken, address toToken, uint256 amount, uint256 minReceive, bytes calldata data
    ) external view returns(address exchange, uint256 value, bytes memory transaction);

    function getSpender() external view returns (address);
}

contract Vault {
    ERC20Like public currency;
    ERC20Like public baseCurrency;
    ERC20Like public juniorToken;
    ERC20Like public seniorToken;
    TrancheLike public juniorTranche;
    TrancheLike public seniorTranche;
    AdapterLike public tradeAdapter;
    address public admin;
    uint8 private _initialized;


    error CALL_FAILED();
    error NOT_AUTHORIZED();
    error ALREADY_INITALIZED();


    modifier Initializer {
        if(_initialized != 0) {
            revert ALREADY_INITALIZED();
        }
        _initialized = 1;
        _;   
    }

    modifier onlyAdmin {
        if(msg.sender != admin) {
            revert NOT_AUTHORIZED();
        }
        _;
    }

    function initalize(
        ERC20Like _vaultCurrency, 
        ERC20Like _baseCurrency, 
        TrancheLike _junior, 
        TrancheLike _senior,
        AdapterLike _tradeAdapter,
        address _admin
    ) external Initializer {
        juniorToken = _junior.token();
        seniorToken = _senior.token();

        juniorTranche = _junior;
        seniorTranche = _senior;
        currency = _vaultCurrency;
        baseCurrency = _baseCurrency;
        tradeAdapter = _tradeAdapter;
        admin = _admin;

        baseCurrency.approve(address(_junior), type(uint256).max);
        baseCurrency.approve(address(_senior), type(uint256).max);
        baseCurrency.approve(tradeAdapter.getSpender(), type(uint256).max);
        currency.approve(tradeAdapter.getSpender(), type(uint256).max);


        juniorToken.approve(address(_junior), type(uint256).max);
        seniorToken.approve(address(_junior), type(uint256).max);
    }

    function supplyJunior(uint256 amount, uint256 minCurrencyOut) external {
        currency.transferFrom(msg.sender, address(this), amount); //TODO use safeTransfer
        (
            address exchange,
            ,
            bytes memory tradeData
        ) = tradeAdapter.getTradeData(
            address(currency), address(baseCurrency), amount, minCurrencyOut, ""
        );

        _call(exchange, tradeData, 0);

        juniorTranche.supplyOrder(msg.sender, address(this), amount);

        _returnCurrency(msg.sender);
    }

    function supplySenior(uint256 amount, uint256 minCurrencyOut) external {
        currency.transferFrom(msg.sender, address(this), amount);
        
        (
            address exchange,
            ,
            bytes memory tradeData
        ) = tradeAdapter.getTradeData(
            address(currency), address(baseCurrency), amount, minCurrencyOut, ""
        );

        _call(exchange, tradeData, 0);

        seniorTranche.supplyOrder(msg.sender, address(this), amount);
        _returnCurrency(msg.sender);
    }

    function redeemSenior(uint256 amount) external {
        seniorToken.transferFrom(msg.sender, address(this), amount);
        seniorTranche.redeemOrder(msg.sender, address(this), amount);
        _returnToken(seniorToken, msg.sender);
    }

    function redeemJunior(uint256 amount) external {
        seniorToken.transferFrom(msg.sender, address(this), amount);
        seniorTranche.redeemOrder(msg.sender, address(this), amount);
        _returnToken(juniorToken, msg.sender);
    }

    function disburse() external {
        seniorDisburse();
        juniorDisburse();
    }

    function seniorDisburse() public {
        seniorTranche.disburse(msg.sender);

        //Convert USDC to MAI and transfer
        _returnCurrency(msg.sender);

        //transfer tranche tokens
        _returnToken(seniorToken, msg.sender);
    }

    function juniorDisburse() public {
        juniorTranche.disburse(msg.sender);

        //Convert USDC to MAI and transfer
        _returnCurrency(msg.sender);

        //transfer tranche tokens
        _returnToken(juniorToken, msg.sender);

    }

    ///@dev swaps the excecss USDC(if-any) to MAI and transfers it back to msg.sender
    function _returnCurrency(address _receiver) internal {
        uint256 baseCurrencyBalance = baseCurrency.balanceOf(address(this));
        if(baseCurrencyBalance > 0) {
            (
                address exchange,
                ,
                bytes memory tradeData
            ) = tradeAdapter.getTradeData(
                address(baseCurrency), address(currency), baseCurrencyBalance, 0, ""
            );

            _call(exchange, tradeData, 0);

            currency.transfer(_receiver, currency.balanceOf(address(this)));
        }
    }

    function setAdapter(AdapterLike _adapter) external onlyAdmin {
        tradeAdapter = _adapter;

        baseCurrency.approve(tradeAdapter.getSpender(), type(uint256).max);
        currency.approve(tradeAdapter.getSpender(), type(uint256).max);
    }

    function changeAdmin(address newAdmin) external onlyAdmin {
        admin = newAdmin;
    }

    ///@dev used to return the excess Tranche-tokens.
    function _returnToken(ERC20Like token, address receiver) internal {
        uint256 balance = token.balanceOf(address(this));
        if(balance > 0) {
            token.transfer(receiver, balance);
        }
    }

    function _call(address _target, bytes memory _data, uint256 _value) internal {
        (bool result, ) = _target.call{value: _value}(_data);
        if(!result) {
            revert CALL_FAILED();
        }
    }
}