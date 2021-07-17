// SPDX-License-Identifier: GPL-3.0

pragma solidity >=0.7.0 <0.9.0;

import "./ReentrancyGuard.sol";

contract MultiSigWallet is ReentrancyGuard {

    event Deposit(address indexed sender, uint amount, uint balance);
    event SubmitTransaction(address indexed owner, uint indexed txIndex, address indexed to, uint value, bytes data);
    event ConfirmTransaction(address indexed owner, uint indexed txIndex);
    event RevokeConfirmation(address indexed owner, uint indexed txIndex);
    event ExecuteTransaction(address indexed owner, uint indexed txIndex);
    
    struct Transaction {
        address to;
        uint value;
        bytes data;
        bool executed;
        uint numberOfConfirmations;
    }

    mapping(uint => mapping(address => bool)) public isConfirmed;
    
    address[] public owners;
    mapping (address => bool) public isOwner;
    uint public numberConfirmationsRequired;
    Transaction[] public transactions;
    
    constructor (address[] memory _owners, uint _numberConfirmationsRequired) public {
        require(_owners.length > 0, "Owners required");
        require(_numberConfirmationsRequired > 0 && _numberConfirmationsRequired <= _owners.length, "Invalid number of required confirmations");
        
        for (uint i = 0; i < _owners.length; i++) {
            address owner = _owners[i];
            
            require(owner != address(0), "Invalid owner");
            require(!isOwner[owner], "Owner already exists");
            
            isOwner[owner] = true;
            owners.push(owner);
        }
        numberConfirmationsRequired = _numberConfirmationsRequired;
    }
    
    receive() payable external {
        emit Deposit(msg.sender, msg.value, address(this).balance);
    }
    
    modifier onlyOwner() {
        require(isOwner[msg.sender], "Not an owner");
        _;
    }
    
    modifier txExists(uint _txIndex) {
        require(_txIndex < transactions.length, "Transaction already exists");
        _;
    }
    
    modifier notExecuted(uint _txIndex) {
        require(!transactions[_txIndex].executed, "Transaction already executed");
        _;
    }
    
    modifier notConfirmed(uint _txIndex) {
        require(!isConfirmed[_txIndex][msg.sender], "tx already confirmed");
        _;
    }
    
    function submitTransaction(address _to, uint _value, bytes memory _data) public onlyOwner { 
        uint txIndex = transactions.length;
        
        transactions.push(
            Transaction({
                to: _to,
                value: _value,
                data: _data,
                executed: false,
                numberOfConfirmations: 0
            })
        );
        
        emit SubmitTransaction(msg.sender, txIndex, _to, _value, _data);
    }
    
    function confirmTransaction(uint _txIndex) public onlyOwner txExists(_txIndex) notExecuted(_txIndex) notConfirmed(_txIndex) {
        Transaction storage transaction = transactions[_txIndex];
        
        transaction.numberOfConfirmations += 1;
        isConfirmed[_txIndex][msg.sender] = true;
        
        emit ConfirmTransaction(msg.sender, _txIndex);
    }
    
    function executeTransaction(uint _txIndex) public nonReentrant onlyOwner txExists(_txIndex) notExecuted(_txIndex) {
        Transaction storage transaction = transactions[_txIndex];
        
        require(transaction.numberOfConfirmations >= numberConfirmationsRequired, "Number of confirmations not reached yet");
        
        transaction.executed = true;
        
        (bool success, ) = transaction.to.call{value: transaction.value}(transaction.data);
        
        require(success, "Transaction failed");
        
        emit ExecuteTransaction(msg.sender, _txIndex);
    }
    
    function revokeConfirmation(uint _txIndex) public onlyOwner txExists(_txIndex) notExecuted(_txIndex) {
        Transaction storage transaction = transactions[_txIndex];

        require(isConfirmed[_txIndex][msg.sender], "tx not confirmed");

        transaction.numberOfConfirmations -= 1;
        isConfirmed[_txIndex][msg.sender] = false;

        emit RevokeConfirmation(msg.sender, _txIndex);
    }
}