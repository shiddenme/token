pragma solidity >=0.4.21 <0.6.0;


import "./ERC20Basic.sol";
import "./SafeMath.sol";


/**
 * ERC20 基类实现
 */
contract BasicToken is ERC20Basic {
  using SafeMath for uint256;

  /**
   * 账户总余额
   * */
  mapping(address => uint256) balances;

  /**
   * 总供应量
   * */
  uint256 totalSupply_;

  /**
   * 获取总供应量
   * */
  function totalSupply() public view returns (uint256) {
    return totalSupply_;
  }

}
