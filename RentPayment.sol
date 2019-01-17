pragma solidity ^0.4.24;

import './SafeMath.sol';

contract RentPayment {
	using SafeMath for uint256;

	address public payer;
	address public receiver;
	uint256 public rentPerRound;	// how much should be paid each payDuration
	uint256 public round;			// how many rounds has been paid
	uint256 public payDuration = 1 hours;
	uint256 public lastPayment = now;

	constructor (address landlord, uint256 amount) public payable {
		require(landlord != address(0));
		payer = msg.sender;
		receiver = landlord;
		rentPerRound = amount;
	}

	modifier onlyPayer() {
		require(msg.sender == payer);
		_;
	}

	modifier onlyReceiver() {
		require(msg.sender == receiver);
		_;
	}

	modifier onlyWhenEnough() {
		require(address(this).balance >= rentPerRound, 'Available rent is not enough for paying a round.');
		_;
	}

	modifier onlyWhenReach12Rounds() {
		require(round >= 12);
		_;
	}

	function getAvailableRent() public view returns (uint256 availableRent) {
		return address(this).balance;
	}

	event Deposit(address indexed depositor, uint256 amount);

	function deposit() public payable onlyPayer returns (bool success){
		emit Deposit(msg.sender, msg.value);

		return true;
	}

	event Withdraw(address indexed withdrawler, uint256 amount);

	/* Simplify the amount be multiple of rentPerRound */
	// Notice: Better to call getAvailableRent() to check if the balance is enough.
	function withdraw() public onlyReceiver onlyWhenEnough returns (bool success) {
		uint256 deltaRound = (now - lastPayment) / payDuration;
		require (deltaRound > 0, 'Less than 1 hour after last payment.');

		uint256 deltaRent = deltaRound.mul(rentPerRound);

		if (address(this).balance < deltaRent) {
			deltaRound = address(this).balance.div(rentPerRound);
			deltaRent = deltaRound.mul(rentPerRound);
		}

		round = round.add(deltaRound);
		lastPayment = now;
		msg.sender.transfer(deltaRent);
		emit Withdraw(msg.sender, deltaRent);

		return true;
	}

	function close() public onlyPayer onlyWhenReach12Rounds {
		selfdestruct(msg.sender);
	}
}