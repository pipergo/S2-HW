# 第二课作业

### 编程题：

参考 Purchase.sol 合约写一个店铺订单管理合约 SimpleShop.sol，要求实现如下功能：

1. 该合约管理某个特定 seller（即合约创建者）的所有订单状态，每个订单是一个 Purchase，每个 Purchase 有 Created、Locked、Closed 三个状态，分别对应订单创建、订单确认和订单关闭；
2. 合约可以同时管理多个不同状态的订单，即支持多个 buyer 同时从 seller 处购买物品（购买物品的逻辑不用在合约中体现），流程与 Purchase.sol 合约相同即可。也就是说，seller 首先创建一个 Purchase，创建的同时把两倍价钱的 Ether 转入；然后 buyer 可以 confirmPurchase，确认时同样转入两倍价钱的 Ether；seller 可以在 buyer 确认前调用 abort 函数来取消订单；buyer 确认之后，仅 buyer 可以调用 confirmReceived 函数来确认收货，该函数将一倍价钱的 Ether 转给 buyer、把三倍价钱的 Ether 转给 seller。这几个函数中需要对应修改 Purchase 的状态。
3. 在前两个需求之上，增加自动确认收货的逻辑。即在 buyer 调用 confirmPurchase 之后，如果 1 天内没有调用 confirmReceived 函数，那么 1 天之后，seller 就可以调用此函数来完成交易。
4. Purchase.sol 合约中的三个事件需要保留（当然，你需要增加参数了），此外还应该为这个合约设计合理的查询函数，以允许外部应用查询订单状态。
5. 尽量使用 modifier 来控制相应的函数调用，增加必要的 struct 和状态变量来保存所有订单（Purchase）的状态，尽量考虑可能的情况，避免逻辑漏洞。

尝试用 truffle 编写测试程序，基于 ganache 或测试网络进行相应的测试。
