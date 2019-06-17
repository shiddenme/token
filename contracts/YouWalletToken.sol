pragma solidity >=0.4.21 <0.6.0;


import "./StandardToken.sol";
import "./Management.sol";


/**
 * @title YouWalletToken
 */
contract YouWalletToken is StandardToken, Management {

  string public constant name = "You Wallet"; // solium-disable-line uppercase
  string public constant symbol = "YWT"; // solium-disable-line uppercase
  uint8 public constant decimals = 18; // solium-disable-line uppercase

  /**
   * 常量
   * 单位量, 即1个token有多少wei(假定token的最小单位为wei)
   * */
  uint256 constant internal MAGNITUDE = 10 ** uint256(decimals);

  uint256 public constant INITIAL_SUPPLY = 1000000000 * MAGNITUDE;

  // 锁定期转账事件
  event TransferByDate(address indexed from, address indexed to, uint256[] values, uint256[] dates);
  event TransferFromByDate(address indexed spender, address indexed from, address indexed to, uint256[] values, uint256[] dates);
  // refresh 事件
  event Refresh(address indexed from, address indexed who);

  /**
   * 将锁定期的map做成一个list
   * value 锁定的余额
   * _next 下个锁定期的到期时间
   * */
  struct Element {
    uint256 value;
    uint256 next;
  }

  /**
   * 账户
   * lockedBalances 锁定余额
   * lockedElement 锁定期余额
   * start_date 锁定期最早到期时间
   * end_date 锁定期最晚到期时间
   * */
  struct Account {
    uint256 lockedBalances;
    mapping(uint256 => Element) lockedElement;
    uint256 start_date;
    uint256 end_date;
  }

  /**
   * 所有账户
   * */
  mapping(address => Account) public accounts;

  /**
   * 需求：owner 每年释放的金额不得超过年初余额的10%
   * curYear:  当前年初时间
   * YEAR:  一年365天的时间
   * vault: owner限制额度
   * VAULT_FLOOR_VALUE: vault 最低限值
   * */
  uint256 public curYear;
  uint256 constant internal YEAR = 365 * 24 * 3600;
  uint256 public vault;
  uint256 constant internal VAULT_FLOOR_VALUE = 10000000 * MAGNITUDE;

  /**
   * 合约构造函数
   * 初始化合约的总供应量
   */
  constructor(address _owner) public {
    // 要求_owner
    require(_owner != address(0));

    // 设置owner
    owner = _owner;

    // 初始化owner是管理员
    adminList[owner] = true;

    // 初始化发行量
    totalSupply_ = INITIAL_SUPPLY;
    balances[owner] = INITIAL_SUPPLY;
    emit Transfer(address(0), owner, INITIAL_SUPPLY);

    /**
     * 初始化owner限制额度
     * 2018/01/01 00:00:00
     * */
    vault = totalSupply_.mul(10).div(100);
    curYear = 1514736000;
  }

  /**
   * fallback函数
   * */
  function () external payable {
  }

  /**
   * 刷新owner限制余额vault
   * */
  function refreshVault(address _who, uint256 _value) internal
  {
    uint256 balance;

    // 只对owner操作
    if (_who != owner)
      return ;
    // 记录balance of owner
    balance = balances[owner];
    // 如果是新的一年, 则计算vault为当前余额的10%
    if (now >= (curYear + YEAR))
    {
      if (balance <= VAULT_FLOOR_VALUE)
        vault = balance;
      else
        vault = balance.mul(10).div(100);
      curYear = curYear.add(YEAR);
    }

    // vault 必须大于等于 _value
    require(vault >= _value);
    vault = vault.sub(_value);
    return ;
  }

  /**
   * 计算到期的锁定余额，内部接口
   * _who: 账户地址
   * */
  function computeLockedBalances(address _who) internal view returns (uint256)
  {
    uint256 tmp_date = accounts[_who].start_date;
    uint256 tmp_value = accounts[_who].lockedElement[tmp_date].value;
    uint256 tmp_balances = 0;
    uint256 tmp_var;

    // 强制自动释放打开则跳过判断，直接释放锁定期余额
    if (!forceAutoFreeLockBalance[_who])
    {
      // 强制自动释放未打开，则判断自动释放开关
      if(autoFreeLockBalance[_who])
      {
        // 自动释放开关未打开(true), 直接返回0
        return 0;
      }
    }

    // 锁定期到期
    while(tmp_date != 0 &&
          tmp_date <= now)
    {
      // 记录到期余额
      tmp_balances = tmp_balances.add(tmp_value);

      // 记录 tmp_date
      tmp_var = tmp_date;

      // 跳到下一个锁定期
      tmp_date = accounts[_who].lockedElement[tmp_date].next;
      tmp_value = accounts[_who].lockedElement[tmp_date].value;
    }

    return tmp_balances;
  }

  /**
   * 重新计算到期的锁定期余额, 内部接口
   * _who: 账户地址
   * */
  function refreshlockedBalances(address _who) internal returns (uint256)
  {
    uint256 tmp_date = accounts[_who].start_date;
    uint256 tmp_value = accounts[_who].lockedElement[tmp_date].value;
    uint256 tmp_balances = 0;
    uint256 tmp_var;

    // 强制自动释放打开则跳过判断，直接释放锁定期余额
    if (!forceAutoFreeLockBalance[_who])
    {
      // 强制自动释放未打开，则判断自动释放开关
      if(autoFreeLockBalance[_who])
      {
        // 自动释放开关未打开(true), 直接返回0
        return 0; 
      }
    }

    // 锁定期到期
    while(tmp_date != 0 &&
          tmp_date <= now)
    {
      // 记录到期余额
      tmp_balances = tmp_balances.add(tmp_value);

      // 记录 tmp_date
      tmp_var = tmp_date;

      // 跳到下一个锁定期
      tmp_date = accounts[_who].lockedElement[tmp_date].next;
      tmp_value = accounts[_who].lockedElement[tmp_date].value;

      delete accounts[_who].lockedElement[tmp_var];
    }

    // 修改锁定期数据
    accounts[_who].start_date = tmp_date;
    accounts[_who].lockedBalances = accounts[_who].lockedBalances.sub(tmp_balances);
    balances[_who] = balances[_who].add(tmp_balances);

    // 将最早和最晚时间的标志，都置0，即最初状态
    if (accounts[_who].start_date == 0)
        accounts[_who].end_date = 0;

    return tmp_balances;
  }

  /**
   * 可用余额转账，内部接口
   * _from token的拥有者
   * _to token的接收者
   * _value token的数量
   * */
  function transferAvailableBalances(
    address _from,
    address _to,
    uint256 _value
  )
    internal
  {
    // 检查可用余额
    require(_value <= balances[_from]);

    // 修改可用余额
    balances[_from] = balances[_from].sub(_value);
    balances[_to] = balances[_to].add(_value);

    emit Transfer(_from, _to, _value);
  }

  /**
   * 锁定余额转账，内部接口
   * _from token的拥有者
   * _to token的接收者
   * _value token的数量
   * */
  function transferLockedBalances(
    address _from,
    address _to,
    uint256 _value
  )
    internal
  {
    // 检查可用余额
    require(_value <= balances[_from]);

    // 修改可用余额和锁定余额
    balances[_from] = balances[_from].sub(_value);
    accounts[_to].lockedBalances = accounts[_to].lockedBalances.add(_value);
  }

  /**
   * 转账
   * */
  function transfer(
    address _to,
    uint256 _value
  )
    public
    whenNotPaused
    returns (bool)
  {
    // 不能给地址0转账
    require(_to != address(0));

    /**
     * 获取到期的锁定期余额
     * */
    refreshlockedBalances(msg.sender);
    refreshlockedBalances(_to);

    // 刷新vault余额
    refreshVault(msg.sender, _value);

    // 修改可用账户余额
    transferAvailableBalances(msg.sender, _to, _value);

    return true;
  }

  /**
   * 代理转账
   * 代理从 _from 转账 _value 到 _to
   * */
  function transferFrom(
    address _from,
    address _to,
    uint256 _value
  )
    public
    whenNotPaused
    returns (bool)
  {
    // 不能向0地址转账
    require(_to != address(0));

    /**
     * 获取到期的锁定期余额
     * */
    refreshlockedBalances(_from);
    refreshlockedBalances(_to);

    // 检查代理额度
    require(_value <= allowed[_from][msg.sender]);

    // 修改代理额度
    allowed[_from][msg.sender] = allowed[_from][msg.sender].sub(_value);

    // 刷新vault余额
    refreshVault(_from, _value);

    // 修改可用账户余额
    transferAvailableBalances(_from, _to, _value);

    return true;
  }

  /**
   * 设定代理和代理额度
   * 设定代理为 _spender 额度为 _value
   * */
  function approve(
    address _spender,
    uint256 _value
  )
    public
    whenNotPaused
    returns (bool)
  {
    return super.approve(_spender, _value);
  }

  /**
   * 提高代理的代理额度
   * 提高代理 _spender 的代理额度 _addedValue
   * */
  function increaseApproval(
    address _spender,
    uint _addedValue
  )
    public
    whenNotPaused
    returns (bool success)
  {
    return super.increaseApproval(_spender, _addedValue);
  }

  /**
   * 降低代理的代理额度
   * 降低代理 _spender 的代理额度 _subtractedValue
   * */
  function decreaseApproval(
    address _spender,
    uint _subtractedValue
  )
    public
    whenNotPaused
    returns (bool success)
  {
    return super.decreaseApproval(_spender, _subtractedValue);
  }

  /**
   * 批量转账 token
   * 批量用户 _receivers
   * 对应的转账数量 _values
   * */
  function batchTransfer(
    address[] memory _receivers,
    uint256[] memory _values
  )
    public
    whenNotPaused
  {
    // 判断接收账号和token数量为一一对应
    require(_receivers.length > 0 && _receivers.length == _values.length);

    /**
     * 获取到期的锁定期余额
     * */
    refreshlockedBalances(msg.sender);

    // 判断可用余额足够
    uint32 i = 0;
    uint256 total = 0;
    for (i = 0; i < _values.length; i ++)
    {
      total = total.add(_values[i]);
    }
    require(total <= balances[msg.sender]);

    // 刷新vault余额
    refreshVault(msg.sender, total);

    // 一一 转账
    for (i = 0; i < _receivers.length; i ++)
    {
      // 不能向0地址转账
      require(_receivers[i] != address(0));

      refreshlockedBalances(_receivers[i]);
      // 修改可用账户余额
      transferAvailableBalances(msg.sender, _receivers[i], _values[i]);
    }
  }

  /**
   * 代理批量转账 token
   * 被代理人 _from
   * 批量用户 _receivers
   * 对应的转账数量 _values
   * */
  function batchTransferFrom(
    address _from,
    address[] memory _receivers,
    uint256[] memory _values
  )
    public
    whenNotPaused
  {
    // 判断接收账号和token数量为一一对应
    require(_receivers.length > 0 && _receivers.length == _values.length);

    /**
     * 获取到期的锁定期余额
     * */
    refreshlockedBalances(_from);

    // 判断可用余额足够
    uint32 i = 0;
    uint256 total = 0;
    for (i = 0; i < _values.length; i ++)
    {
      total = total.add(_values[i]);
    }
    require(total <= balances[_from]);

    // 判断代理额度足够
    require(total <= allowed[_from][msg.sender]);

    // 修改代理额度
    allowed[_from][msg.sender] = allowed[_from][msg.sender].sub(total);

    // 刷新vault余额
    refreshVault(_from, total);

    // 一一 转账
    for (i = 0; i < _receivers.length; i ++)
    {
      // 不能向0地址转账
      require(_receivers[i] != address(0));

      refreshlockedBalances(_receivers[i]);
      // 修改可用账户余额
      transferAvailableBalances(_from, _receivers[i], _values[i]);
    }
  }

  /**
   * 带有锁定期的转账, 当锁定期到期之后，锁定token数量将转入可用余额
   * _receiver 转账接收账户
   * _values 转账数量
   * _dates 锁定期，即到期时间
   *        格式：UTC时间，单位秒，即从1970年1月1日开始到指定时间所经历的秒
   * */
  function transferByDate(
    address _receiver,
    uint256[] memory _values,
    uint256[] memory _dates
  )
    public
    whenNotPaused
  {
    // 判断接收账号和token数量为一一对应
    require(_values.length > 0 &&
        _values.length == _dates.length);

    // 不能向0地址转账
    require(_receiver != address(0));

    /**
     * 获取到期的锁定期余额
     * */
    refreshlockedBalances(msg.sender);
    refreshlockedBalances(_receiver);

    // 判断可用余额足够
    uint32 i = 0;
    uint256 total = 0;
    for (i = 0; i < _values.length; i ++)
    {
      total = total.add(_values[i]);
    }
    require(total <= balances[msg.sender]);

    // 刷新vault余额
    refreshVault(msg.sender, total);

    // 转账
    for(i = 0; i < _values.length; i ++)
    {
      transferByDateSingle(msg.sender, _receiver, _values[i], _dates[i]);
    }

    emit TransferByDate(msg.sender, _receiver, _values, _dates);
  }

  /**
   * 代理带有锁定期的转账, 当锁定期到期之后，锁定token数量将转入可用余额
   * _from 被代理账户
   * _receiver 转账接收账户
   * _values 转账数量
   * _dates 锁定期，即到期时间
   *        格式：UTC时间，单位秒，即从1970年1月1日开始到指定时间所经历的秒
   * */
  function transferFromByDate(
    address _from,
    address _receiver,
    uint256[] memory _values,
    uint256[] memory _dates
  )
    public
    whenNotPaused
  {
    // 判断接收账号和token数量为一一对应
    require(_values.length > 0 &&
        _values.length == _dates.length);

    // 不能向0地址转账
    require(_receiver != address(0));

    /**
     * 获取到期的锁定期余额
     * */
    refreshlockedBalances(_from);
    refreshlockedBalances(_receiver);

    // 判断可用余额足够
    uint32 i = 0;
    uint256 total = 0;
    for (i = 0; i < _values.length; i ++)
    {
      total = total.add(_values[i]);
    }
    require(total <= balances[_from]);

    // 判断代理额度足够
    require(total <= allowed[_from][msg.sender]);

    // 修改代理额度
    allowed[_from][msg.sender] = allowed[_from][msg.sender].sub(total);

    // 刷新vault余额
    refreshVault(_from, total);

    // 转账
    for(i = 0; i < _values.length; i ++)
    {
      transferByDateSingle(_from, _receiver, _values[i], _dates[i]);
    }

    emit TransferFromByDate(msg.sender, _from, _receiver, _values, _dates);
  }

  /**
   * _from token拥有者
   * _to 转账接收账户
   * _value 转账数量
   * _date 锁定期，即到期时间
   *       格式：UTC时间，单位秒，即从1970年1月1日开始到指定时间所经历的秒
   * */
  function transferByDateSingle(
    address _from,
    address _to,
    uint256 _value,
    uint256 _date
  )
    internal
  {
    uint256 start_date = accounts[_to].start_date;
    uint256 end_date = accounts[_to].end_date;
    uint256 tmp_var = accounts[_to].lockedElement[_date].value;
    uint256 tmp_date;

    if (_value == 0)
    {
        // 不做任何处理
        return ;
    }

    if (_date <= now)
    {
      // 到期时间比当前早，直接转入可用余额
      // 修改可用账户余额
      transferAvailableBalances(_from, _to, _value);

      return ;
    }

    if (start_date == 0)
    {
      // 还没有收到过锁定期转账
      // 最早时间和最晚时间一样
      accounts[_to].start_date = _date;
      accounts[_to].end_date = _date;
      accounts[_to].lockedElement[_date].value = _value;
    }
    else if (tmp_var > 0)
    {
      // 收到过相同的锁定期
      accounts[_to].lockedElement[_date].value = tmp_var.add(_value);
    }
    else if (_date < start_date)
    {
      // 锁定期比最早到期的还早
      // 添加锁定期，并加入到锁定期列表
      accounts[_to].lockedElement[_date].value = _value;
      accounts[_to].lockedElement[_date].next = start_date;
      accounts[_to].start_date = _date;
    }
    else if (_date > end_date)
    {
      // 锁定期比最晚到期还晚
      // 添加锁定期，并加入到锁定期列表
      accounts[_to].lockedElement[_date].value = _value;
      accounts[_to].lockedElement[end_date].next = _date;
      accounts[_to].end_date = _date;
    }
    else
    {
      /**
       * 锁定期在 最早和最晚之间
       * 首先找到插入的位置
       * 然后在插入的位置插入数据
       * tmp_var 即 tmp_next
       * */
      tmp_date = start_date;
      tmp_var = accounts[_to].lockedElement[tmp_date].next;
      while(tmp_var < _date)
      {
        tmp_date = tmp_var;
        tmp_var = accounts[_to].lockedElement[tmp_date].next;
      }

      // 记录锁定期并加入列表
      accounts[_to].lockedElement[_date].value = _value;
      accounts[_to].lockedElement[_date].next = tmp_var;
      accounts[_to].lockedElement[tmp_date].next = _date;
    }

    // 锁定期转账
    transferLockedBalances(_from, _to, _value);

    return ;
  }

  /**
   * 重新计算账号的lockbalance
   * */
  function refresh(address _who) public whenNotPaused {
    refreshlockedBalances(_who);
    emit Refresh(msg.sender, _who);
  }

  /**
   * 查询账户可用余额
   * */
  function availableBalanceOf(address _owner) public view returns (uint256) {
    return (balances[_owner] + computeLockedBalances(_owner));
  }

  /**
   * 查询账户总余额
   * */
  function balanceOf(address _owner) public view returns (uint256) {
    return balances[_owner] + accounts[_owner].lockedBalances;
  }

  /**
   * 获取锁定余额
   * */
  function lockedBalanceOf(address _who) public view returns (uint256) {
    return (accounts[_who].lockedBalances - computeLockedBalances(_who));
  }

  /**
   * 根据日期获取锁定余额
   * 返回：锁定余额，下一个锁定期
   * */
  function lockedBalanceOfByDate(address _who, uint256 date) public view returns (uint256, uint256) {
    return (accounts[_who].lockedElement[date].value, accounts[_who].lockedElement[date].next);
  }

}
