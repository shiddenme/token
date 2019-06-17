pragma solidity >=0.4.21 <0.6.0;


import "./Ownable.sol";


/**
 * 管理合约
 * 功能：
 * 暂停合约
 * 冻结账户
 * 管理员
 */
contract Management is Ownable {

  /**
   * 暂停和取消暂停事件
   * */
  event Pause();
  event Unpause();

  /**
   * 打开锁定期自动释放事件
   * 关闭锁定期自动释放事件
   * 打开强制锁定期自动释放事件
   * */
  event OpenAutoFree(address indexed admin, address indexed who);
  event CloseAutoFree(address indexed admin, address indexed who);
  event OpenForceAutoFree(address indexed admin, address indexed who);

  /**
   * 增加和删除管理员事件
   * */
  event AddAdministrator(address indexed admin);
  event DelAdministrator(address indexed admin);

  /**
   * 合约暂停标志, True 暂停，false 未暂停
   * 锁定余额自动释放开关
   * 强制锁定余额自动释放开关
   * 合约管理员
   * */
  bool public paused = false;
  mapping(address => bool) public autoFreeLockBalance;          // false(default) for auto frce, true for not free
  mapping(address => bool) public forceAutoFreeLockBalance;     // false(default) for not force free, true for froce free
  mapping(address => bool) public adminList;

  /**
   * 构造函数
   * */
  constructor() public {
  }

  /**
   * modifier 要求合约正在运行状态
   */
  modifier whenNotPaused() {
    require(!paused);
    _;
  }

  /**
   * modifier 要求合约暂停状态
   */
  modifier whenPaused() {
    require(paused);
    _;
  }

  /**
   * 要求是管理员
   * */
  modifier whenAdministrator(address who) {
    require(adminList[who]);
    _;
  }

  /**
   * 要求不是管理员
   * */
  modifier whenNotAdministrator(address who) {
    require(!adminList[who]);
    _;
  }

  /**
   * * 暂停合约
   */
  function pause() onlyOwner whenNotPaused public {
    paused = true;
    emit Pause();
  }

  /**
   * 取消暂停合约
   */
  function unpause() onlyOwner whenPaused public {
    paused = false;
    emit Unpause();
  }

  /**
   * 打开锁定期自动释放开关
   * */
  function openAutoFree(address who) whenAdministrator(msg.sender) public {
    delete autoFreeLockBalance[who];
    emit OpenAutoFree(msg.sender, who);
  }

  /**
   * 关闭锁定期自动释放开关
   * */
  function closeAutoFree(address who) whenAdministrator(msg.sender) public {
    autoFreeLockBalance[who] = true;
    emit CloseAutoFree(msg.sender, who);
  }

  /**
   * 打开强制锁定期自动释放开关
   * 该开关只能打开，不能关闭
   * */
  function openForceAutoFree(address who) onlyOwner public {
    forceAutoFreeLockBalance[who] = true;
    emit OpenForceAutoFree(msg.sender, who);
  }

  /**
   * 添加管理员
   * */
  function addAdministrator(address who) onlyOwner public {
    adminList[who] = true;
    emit AddAdministrator(who);
  }

  /**
   * 删除管理员
   * */
  function delAdministrator(address who) onlyOwner public {
    delete adminList[who];
    emit DelAdministrator(who);
  }
}
