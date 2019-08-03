pragma solidity >=0.4.21 <0.6.0;


/**
 * ERC20 基类
 * 总量, 账户余额， 转账操作
 * 转账事件
 */
contract ERC20Basic {
  function totalSupply() public view returns (uint256);
  function balanceOf(address who) public view returns (uint256);
  function transfer(address to, uint256 value) public returns (bool);
  event Transfer(address indexed from, address indexed to, uint256 value);
}
