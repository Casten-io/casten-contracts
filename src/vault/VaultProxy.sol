pragma solidity 0.7.6;
import "../../lib/openzeppelin-contracts/contracts/proxy/TransparentUpgradeableProxy.sol";
contract VaultProxy is TransparentUpgradeableProxy {

    constructor(
        address _logic, 
        address admin_, 
        bytes memory _data
    ) TransparentUpgradeableProxy(_logic, admin_, _data) {}
}