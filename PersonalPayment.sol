pragma solidity ^0.4.24;

import "../openzeppelin-solidity-2.0.0/contracts/math/SafeMath.sol";
import "../openzeppelin-solidity-2.0.0/contracts/ownership/Ownable.sol";
import "../openzeppelin-solidity-2.0.0/contracts/payment/PullPayment.sol";

contract PersonalPayment is Ownable, PullPayment {
    // 使用 SafeMath
    using SafeMath for uint256;
    // 其他状态变量
    uint256 totalPay;

    // fallback function
    function() public payable onlyOwner {

    }

    // Note: If there are multiple payees, you'd better to calculate the whole lack of balance
    // from the nextDest and charge in one time.
    event ChargeNeeded(uint256 chargeAmount, address nextDest);

    event PayDeposited(bytes32 indexed payeeHash, uint256 payAmount);

    function _asyncPay(address _dest, uint256 _amount) private returns (bool) {
        require(_dest != address(0), 'Invalid destination address');
        require(_dest != owner(), 'Destination address can not be yourself');

        // make a deposit for _dest
        _asyncTransfer(_dest, _amount);
        // update totalPay
        totalPay = totalPay.add(_amount);

        // Actually we should modify the Escrow contract to hide payee.
        emit PayDeposited(keccak256(abi.encodePacked(_dest)), _amount);
    }

    /* function asyncPay(address[] _dest, uint256[] _amount) 
        public 
        onlyOwner 
        returns (bool chargeNeeded, address nextDest) 
    {
        require(_dest.length == _amount.length);

        uint256 newTotalPay;
        uint256 chargeAmount;
        chargeNeeded = false;

        for (uint256 i = 0; i < _dest.length; i++) {            
            if (chargeNeeded) {
                chargeAmount = chargeAmount.add(_amount[i]);
                continue;
            }

            newTotalPay = totalPay.add(_amount[i]);
            if (address(this).balance < newTotalPay) {
                (chargeNeeded, nextDest) = (true, _dest[i]);
                chargeAmount = newTotalPay.sub(address(this).balance);
            } else {
                _asyncPay(_dest[i], _amount[i]);
            }
        }

        if (chargeNeeded) {
            emit ChargeNeeded(chargeAmount);
        }

        return (chargeNeeded, nextDest);
    } */

    // Note: rewrite this function for the following reasons:
    // 1. _asyncTransfer() will send ether to Escrow contract, thus address(this).balance
    //    will decrease when _asyncPay() excutes.
    // 2. give calculation work of the whole lack of balance to the owner for gas optimization
    function asyncPay(address[] _dest, uint256[] _amount) 
        public 
        onlyOwner 
        returns (bool chargeNeeded, address nextDest) 
    {
        require(_dest.length == _amount.length);

        for (uint256 i = 0; i < _dest.length; i++) {
            if (address(this).balance < _amount[i]) {
                emit ChargeNeeded(_amount[i].sub(address(this).balance), _dest[i]);
                return (true, _dest[i]);
            } else {
                _asyncPay(_dest[i], _amount[i]);
            }
        }

        return (false, address(0));
    }

    function withdrawPayments() public {
        uint256 amount = payments(msg.sender);
        require(amount > 0, 'Sorry, you have no payment to withdraw.');

        // udate totalPay
        totalPay = totalPay.sub(amount);
        // only use super when the inherited function is override
        //super.withdrawPayments(msg.sender);
        withdrawPayments(msg.sender);
    }

    function destroy() public onlyOwner {
        require(totalPay == 0, 'You can not destroy contract as there are payments to finish.');
        selfdestruct(owner());
    }

}