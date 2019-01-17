pragma solidity ^0.4.24;

contract SimpleShop {
    address public seller;
    enum State { Created, Locked, Closed }
    
    struct Order {
        State state;
        uint256 value;  // the order's price
        address buyer;  // the purchaser
        uint256 purchaseAt; // when the purchase happened at
    }
    
    Order[] public orders;  // one seller could manage multiple orders
    
    function() public payable {
        
    }
    
    constructor() public payable evenValue(msg.value) {
        seller = msg.sender;
        orders.push(Order({
            state: State.Created,
            value: msg.value / 2,
            buyer: address(0),
            purchaseAt: 0
        }));
    }
    
    modifier evenValue(uint256 _value) {
        uint value = _value / 2;
        require(2 * value == _value, 'Value has to be even.');
        _;
    }
    
    modifier onlyBuyer(address buyer) {
        require(msg.sender == buyer, 'Only corresponding buyer can call this');
        _;
    }
    
    modifier onlySeller() {
        require(msg.sender == seller, 'Only seller can call this.');
        _;
    }
    
    modifier inState(State state, State _state) {
        require(state == _state, 'Invalid state.');
        _;
    }
    
    // check if the order exists
    // actually contract works fine without this modifier, but the error message may be a help to debug. 
    modifier onlyValidOrder(uint256 orderIndex) {
        require(orderIndex < orders.length, 'Invalid order.');
        _;
    }
    
    event OrderAdded(uint256 orderIndex, uint256 value);
    
    // seller can create orders
    // TODO: addOrders could be taken into consideration in the next version.
    function addOrder() public payable onlySeller evenValue(msg.value) {
        uint value = msg.value / 2;
        emit OrderAdded(value, orders.length);
        orders.push(Order({
            state: State.Created,
            value: value,
            buyer: address(0),
            purchaseAt: 0
        }));
    }
    
    event Aborted(uint256 orderIndex);
    
    function abort(uint256 orderIndex) 
        public 
        onlySeller 
        onlyValidOrder(orderIndex) 
        inState(State.Created, orders[orderIndex].state)
    {
        emit Aborted(orderIndex);
        
        Order storage order = orders[orderIndex];
        order.state = State.Closed;
        seller.transfer(2 * order.value);
    }
    
    event PurchaseConfirmed(uint256 orderIndex, address buyer);
    
    function confirmPurchase(uint256 orderIndex) 
        public 
        payable 
        onlyValidOrder(orderIndex) 
        inState(State.Created, orders[orderIndex].state)
    {
        Order storage order = orders[orderIndex];
        require(msg.value == 2 * order.value, 'Invalid order value.');
        
        emit PurchaseConfirmed(orderIndex, msg.sender);
        order.state = State.Locked;
        order.buyer = msg.sender;
        order.purchaseAt = now;
    }
    
    event ItemReceived(uint256 orderIndex, address buyer);
    
    function confirmReceived(uint256 orderIndex) 
        public 
        onlyValidOrder(orderIndex) 
        // If only the corresponding buyer could comfirmReceived
        //onlyBuyer(orders[orderIndex].buyer)
        inState(State.Locked, orders[orderIndex].state)
    {
        Order storage order = orders[orderIndex];
        // Take auto-confirmReceived into consideration
        require(msg.sender == order.buyer || (msg.sender == seller && now - 1 days >= order.purchaseAt ));
        emit ItemReceived(orderIndex, order.buyer);
        
        order.state = State.Closed;
        
        order.buyer.transfer(order.value);
        seller.transfer(3 * order.value);
    }
}
