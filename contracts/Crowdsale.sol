//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import "hardhat/console.sol";
import "./Token.sol";

contract Crowdsale {
    address owner;
    Token public token;
    uint256 public price;
    uint256 public maxTokens;
    uint256 public tokensSold;
    mapping(bytes32 => bool) private allowList;
    uint256 public startTime;

    uint256 public constant START_DELAY = 1 days;
    uint256 public constant MIN_PURCHASE = 10*1e18;
    uint256 public constant MAX_PURCHASE = 10000*1e18;


    event Buy(uint256 amount, address buyer);
    event Finalize(uint256 tokensSold, uint256 ethRaised);

    constructor(
        Token _token,
        uint256 _price,
        uint256 _maxTokens
    ) {
        owner = msg.sender;
        token = _token;
        price = _price;
        maxTokens = _maxTokens;
        startTime = block.timestamp + START_DELAY;
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "Caller is not the owner");
        _;
    }

    modifier hasStarted() {
        require(block.timestamp >= startTime);
        _;
    }

    // Buy tokens directly by sending Ether
    // --> https://docs.soliditylang.org/en/v0.8.15/contracts.html#receive-ether-function

    receive() external payable {
        uint256 amount = msg.value / price;
        buyTokens(amount * 1e18);
    }

    function addAddress(address _address) public onlyOwner{
        bytes32 hash = keccak256(abi.encodePacked(_address));
        allowList[hash] = true;
    }

    function isOnList(address _address) public view returns (bool){
        bytes32 hash = keccak256(abi.encodePacked(_address));
        return allowList[hash];
    }

    function buyTokens(uint256 _amount) public payable hasStarted{
        require(isOnList(msg.sender));
        require(_amount >= MIN_PURCHASE && _amount <= MAX_PURCHASE);
        require(msg.value == (_amount / 1e18) * price);
        require(token.balanceOf(address(this)) >= _amount);
        require(token.transfer(msg.sender, _amount));

        tokensSold += _amount;

        emit Buy(_amount, msg.sender);
    }

    function setPrice(uint256 _price) public onlyOwner {
        price = _price;
    }

    // Finalize Sale
    function finalize() public onlyOwner {
        require(token.transfer(owner, token.balanceOf(address(this))));

        uint256 value = address(this).balance;
        (bool sent, ) = owner.call{value: value}("");
        require(sent);

        emit Finalize(tokensSold, value);
    }
}
