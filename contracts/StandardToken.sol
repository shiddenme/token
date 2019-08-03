pragma solidity >=0.4.21 <0.6.0;

import "./BasicToken.sol";
import "./ERC20.sol";


/**
 * ERC20 标准
 */
contract StandardToken is ERC20, BasicToken {

  // 记录代理账户
  // 第一个address是token的所有者，即被代理账户
  // 第二个address是token的使用者，即代理账户
  mapping (address => mapping (address => uint256)) internal allowed;

  // 代理转账事件
  // spender: 代理
  // from: token所有者
  // to: token接收账户
  // value: token的转账数量
  event TransferFrom(address indexed spender,
                     address indexed from,
                     address indexed to,
                     uint256 value);


  /**
   * 设置代理
   * _spender 代理账户
   * _value 代理额度
   */
  function approve(address _spender, uint256 _value) public returns (bool) {
    allowed[msg.sender][_spender] = _value;
    emit Approval(msg.sender, _spender, _value);
    return true;
  }

  /**
   * 查询代理额度
   * _owner token拥有者账户
   * _spender 代理账户
   */
  function allowance(
    address _owner,
    address _spender
   )
    public
    view
    returns (uint256)
  {
    return allowed[_owner][_spender];
  }

  /**
   * 提高代理额度
   * _spender 代理账户
   * _addValue 需要提高的代理额度
   */
  function increaseApproval(
    address _spender,
    uint _addedValue
  )
    public
    returns (bool)
  {
    allowed[msg.sender][_spender] = (
      allowed[msg.sender][_spender].add(_addedValue));
    emit Approval(msg.sender, _spender, allowed[msg.sender][_spender]);
    return true;
  }

  /**
   * 降低代理额度
   * _spender 代理账户
   * _subtractedValue 降低的代理额度
   */
  function decreaseApproval(
    address _spender,
    uint _subtractedValue
  )
    public
    returns (bool)
  {
    uint oldValue = allowed[msg.sender][_spender];
    if (_subtractedValue > oldValue) {
      allowed[msg.sender][_spender] = 0;
    } else {
      allowed[msg.sender][_spender] = oldValue.sub(_subtractedValue);
    }
    emit Approval(msg.sender, _spender, allowed[msg.sender][_spender]);
    return true;
  }

}
