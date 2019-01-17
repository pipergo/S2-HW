pragma solidity ^0.4.24;

import "../openzeppelin-solidity-2.0.0/contracts/ownership/Ownable.sol";
import "../openzeppelin-solidity-2.0.0/contracts/access/Roles.sol";
import "../openzeppelin-solidity-2.0.0/contracts/token/ERC20/ERC20.sol";

contract SimpleToken is Ownable, ERC20 {
    // 使用 SafeMath
    using SafeMath for uint256;
    // 使用 Roles
    using Roles for Roles.Role;

    string public constant name    = "SPT";
    string public constant symbol  = "SPT";
    uint8 public constant decimals = 18;

    // 发行量总量 100 亿
    uint256 public constant INITIAL_SUPPLY              = 10000000000 * (10 ** uint256(decimals));
    // 私募额度 60 亿
    uint256 public constant PRIVATE_SALE_AMOUNT         = 6000000000 * (10 ** uint256(decimals));
    // 私募代理人额度上限 9 亿
    uint256 public constant PRIVATE_SALE_AGENT_AMOUNT   = 900000000 * (10 ** uint256(decimals));
    // 单独地址持有上限 3 亿
    uint256 public constant ADDRESS_HOLDING_AMOUNT      = 300000000 * (10 ** uint256(decimals));

    // 私募中的 Ether 兑换比率，1 Ether = 100000 SPT
    uint256 public constant EXCHANGE_RATE_IN_PRIVATE_SALE = 100000;

    // 一周时间的时间戳增量常数
    uint256 public constant TIMESTAMP_INCREMENT_OF_WEEK     = 604800;
    // 两个月时间的时间戳增量常数（60天）
    uint256 public constant TIMESTAMP_INCREMENT_OF_2MONTH   = 5184000;

    // 私募代理人的 Role 常量
    string public constant ROLE_PRIVATESALEWHITELIST = "privateSaleWhitelist";

    // 代理人角色名单
    Roles.Role private agents;
    // 添加代理人
    event AgentAdded(address indexed account);
    // 移除代理人
    event AgentRemoved(address indexed account);

    // 合约创建的时间戳
    uint256 public contractStartTime;

    // 所有私募代理人的已分发数额总数
    uint256 public totalPrivateSalesReleased;

    // 私募代理人实际转出（售出）的 token 数量映射
    mapping (address => uint256) private privateSalesReleased;

    // Owner 的钱包地址
    address ownerWallet;

    // deleted by piper.
    // 如果在添加代理时就检查额度，会比较麻烦，因为代理可以随时添加/删除，额度维护起来很繁琐。改为实际分发时检查。

/*     // 当前已添加的私募代理人的总额度
    uint256 private totalPrivateSales;

    // 每个私募代理人可以分发的额度
    mapping (address => uint256) private privateSales; */
    // end deleted

    /**
     * @dev 构造函数时需传入 Owner 指定的钱包地址
     * @param _ownerWallet Owner 的钱包地址
     */
    constructor(address _ownerWallet) public {
        ownerWallet = _ownerWallet;
        contractStartTime = block.timestamp;
        _mint(msg.sender, INITIAL_SUPPLY);
    }

    modifier onlyAgent() {
        require(isAgent(msg.sender), "Only agents can call the function.");
        _;
    }

    function isAgent(address account) public view returns (bool) {
        return agents.has(account);
    }

    /**
     * @dev 添加私募代理人地址到白名单并设置其限额
     * @param _account 私募代理人地址
     * @param _amount 私募代理人的转账限额
     */
    function addAgent(address _account, uint256 _amount) public onlyOwner {
        // deleted by piper
        // _amount 不能超过单个私募代理人的代理限额
/*         require(_amount <= PRIVATE_SALE_AGENT_AMOUNT);
        // 新增代理人不能使总代理额度超过 60 亿
        totalPrivateSales = totalPrivateSales.add(_amount);
        require(totalPrivateSales <= PRIVATE_SALE_AMOUNT); */
        // end deleted.
        
        _addAgent(_account);
        // 授权 _account 可以代理的额度
        approve(_account, _amount);
    }

    /**
     * @dev 将私募代理人地址从白名单移除
     * @param _account 私募代理人地址
     */
    function removeAgent(address _account) public onlyOwner {
        _removeAgent(_account);
        // 取消 _account 的代理授权
        approve(_account, 0);
    }

    /**
     * @dev 私募代理人自己放弃代理人权限
     */
    function renounceAgent() public onlyAgent {
        _removeAgent(msg.sender);
        // better to reset approval
    }

    function _addAgent(address account) internal {
        agents.add(account);
        emit AgentAdded(account);
    }

    function _removeAgent(address account) internal {
        agents.remove(account);
        emit AgentRemoved(account);
    }

    /**
     * @dev 变更 Owner 的钱包地址
     * @param _ownerWallet Owner 的钱包地址
     */
    function changeOwnerWallet(address _ownerWallet) public onlyOwner {
        ownerWallet = _ownerWallet;
    }

    /**
     * @dev 允许接受转账的 fallback 函数
     */
    function() external payable {
        privateSale(msg.sender);
    }

    function _isInPrivateSalePeriod() private returns (bool) {
        if (block.timestamp <= contractStartTime.add(TIMESTAMP_INCREMENT_OF_2MONTH)) {
            return true;
        }

        return false;
    }

    /**
     * @dev 计算能兑换 SPT 数量，均是按最小单位计算
     */
    function _calcExchangedTokenAmount(uint256 value) private returns (uint256) {
        if (block.timestamp <= contractStartTime.add(TIMESTAMP_INCREMENT_OF_WEEK)) {
            // 7 折优惠
            return value.mul(EXCHANGE_RATE_IN_PRIVATE_SALE).mul(10).div(7);
        } else if (block.timestamp <= contractStartTime.add(TIMESTAMP_INCREMENT_OF_WEEK.mul(2))) {
            // 8 折优惠
            return value.mul(EXCHANGE_RATE_IN_PRIVATE_SALE).mul(10).div(8);
        } else if (block.timestamp <= contractStartTime.add(TIMESTAMP_INCREMENT_OF_WEEK.mul(3))) {
            // 9 折优惠
            return value.mul(EXCHANGE_RATE_IN_PRIVATE_SALE).mul(10).div(9);
        } else {
            // 第四周(含)之后无优惠
            return value.mul(EXCHANGE_RATE_IN_PRIVATE_SALE);
        }
    }

    // 从 owner 名下转移 _amount 数量的 SPT 到 _beneficiary 账号下
    // 根据传参， _beneficiary 可能为私募代理人，是否也应该受单个地址持币数不超过 3 亿的限制？
    // 暂时忽略这个问题 ( owner 持币也超过 3 亿，且可认为代理人转到自己地址后会马上分发给投资人)
    function _settlePrivateSale(address _beneficiary, uint256 _amount) private onlyAgent returns (bool) {
        // 限制单个私募代理人的额度
        uint256 singlePrivateSalesAmount = privateSalesReleased[msg.sender].add(_amount);
        require(singlePrivateSalesAmount <= PRIVATE_SALE_AGENT_AMOUNT, 'Each agent can sell as many as 900 million tokens.');

        // 限制私募代理人总额度
        uint256 totalPrivateSalesAmount = totalPrivateSalesReleased.add(_amount);
        require(totalPrivateSalesAmount <= PRIVATE_SALE_AMOUNT, 'All agents can totally sell as many as 6 billion tokens.');

        // 转移 token
        require(super.transferFrom(owner(), _beneficiary, _amount), 'Failed to transferFrom.');

        // 更新 privateSalesReleased 和 totalPrivateSalesReleased
        privateSalesReleased[msg.sender] = singlePrivateSalesAmount;
        totalPrivateSalesReleased = totalPrivateSalesAmount;

        return true;
    }

    /**
     * @dev 私募处理
     * @param _beneficiary 收取 token 地址
     */
    function privateSale(address _beneficiary) public payable onlyAgent
    {
        // 检查是否已过售卖期
        require(_isInPrivateSalePeriod(), 'Private sale was over.');

        // 计算当前可以兑换的 token 数量
        uint256 exchangedAmount = _calcExchangedTokenAmount(msg.value);

        // 将兑换的 SPT 从 owner 转移到 _beneficiary 账号下
        _settlePrivateSale(_beneficiary, exchangedAmount);
    }

    /**
     * @dev 人工私募处理，即直接用私募代理人的额度进行转账
     * @param _addr 收取 token 地址
     * @param _amount 转账 token 数量
     */
    // 私募代理人可以通过线下转账方式进行销售
    function withdrawPrivateSaleCoins(address _addr, uint256 _amount) public onlyAgent
    {
        // 检查是否已过售卖期
        require(_isInPrivateSalePeriod(), 'Private sale was over.');

        // 检查是否已超过单个地址持币额度
        require(balanceOf(_addr).add(_amount) <= ADDRESS_HOLDING_AMOUNT, 'A single account can hold as many as 300 million tokens.');

        // 转移 token
        _settlePrivateSale(_addr, _amount);
    }

    /**
     * @dev 合约余额提取
     */
    function withdrawFunds() public onlyOwner {
         // 售卖期结束后才能提取
         require(_isInPrivateSalePeriod() == false, 'Waiting for private sale over');

         ownerWallet.transfer(address(this).balance);
    }

    /**
     * @dev 获得私募代理人地址已转出（售出）的 token 数量
     * @param _addr 私募代理人地址
     * @return 私募代理人地址的已转出的 token 数量
     */
    function privateSaleReleased(address _addr) public view returns(uint256) {
        return privateSalesReleased[_addr];
    }

    /**
     * @dev 重写基础合约的 transfer 函数
     */
    function transfer(address _to, uint256 _value) public returns (bool) {
        // 记得调用 super.transfer 函数
        bool result;
        // 检查是否已超过单个地址持币额度
        require(balanceOf(_to).add(_value) <= ADDRESS_HOLDING_AMOUNT, 'A single account can hold as many as 300 million tokens.');

        // 仅有合约管理员在私募期间内可以向其他地址发放 token
        bool isInPrivateSalePeriod = _isInPrivateSalePeriod();
        if (isInPrivateSalePeriod) {
            require(msg.sender == owner(), 'Only owner can call transfer function in private sale period.');

            // 合约管理员在私募期间向其他地址发放 token 与其他私募代理人共享 60 亿额度限制
            uint256 totalPrivateSalesAmount = totalPrivateSalesReleased.add(_amount);
            require(totalPrivateSalesAmount <= PRIVATE_SALE_AMOUNT, 'All agents can totally sell as many as 6 billion tokens.');
            
            result = super.transfer(_to, _value);

            // 更新 totalPrivateSalesReleased
            totalPrivateSalesReleased = totalPrivateSalesAmount;
        } else {
            result = super.transfer(_to, _value);
        }

        return result;
    }

    /**
     * @dev 重写基础合约的 transferFrom 函数
     */
    function transferFrom(
        address _from,
        address _to,
        uint256 _value
    )
        public
        returns (bool)
    {
        // 记得调用 super.transferFrom 函数
        // 检查是否已超过单个地址持币额度
        require(balanceOf(_to).add(_value) <= ADDRESS_HOLDING_AMOUNT, 'A single account can hold as many as 300 million tokens.');

        // 仅有私募代理人在私募期间内可以调用 transferFrom 函数
        bool isInPrivateSalePeriod = _isInPrivateSalePeriod();
        if (isInPrivateSalePeriod) {
            require(isAgent(msg.sender), 'Only owner can call transfer function in private sale period.');

            return _settlePrivateSale(_to, _value);
        } else {
            return super.transferFrom(_from, _to, _value);
        }
    }

}