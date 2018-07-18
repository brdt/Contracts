pragma solidity ^0.4.13;

/**
 * @title ERC20Basic
 * @dev Simpler version of ERC20 interface
 * @dev see https://github.com/ethereum/EIPs/issues/179
 */
contract ERC20Basic {
  uint256 public totalSupply;
  function balanceOf(address who) public constant returns (uint256);
  function transfer(address to, uint256 value) public returns (bool);
  event Transfer(address indexed from, address indexed to, uint256 value);
}

/**
 * @title ERC20 interface
 * @dev see https://github.com/ethereum/EIPs/issues/20
 */
contract ERC20 is ERC20Basic {
  function allowance(address owner, address spender) public constant returns (uint256);
  function transferFrom(address from, address to, uint256 value) public returns (bool);
  function approve(address spender, uint256 value) public returns (bool);
  event Approval(address indexed owner, address indexed spender, uint256 value);
}

/**
 * @title SafeMath
 * @dev Math operations with safety checks that throw on error
 */
library SafeMath {

  function mul(uint256 a, uint256 b) internal pure returns (uint256) {
    uint256 c = a * b;
    assert(a == 0 || c / a == b);
    return c;
  }

  function div(uint256 a, uint256 b) internal pure returns (uint256) {
    // assert(b > 0); // Solidity automatically throws when dividing by 0
    uint256 c = a / b;
    // assert(a == b * c + a % b); // There is no case in which this doesn't hold
    return c;
  }

  function sub(uint256 a, uint256 b) internal pure returns (uint256) {
    assert(b <= a);
    return a - b;
  }

  function add(uint256 a, uint256 b) internal pure returns (uint256) {
    uint256 c = a + b;
    assert(c >= a);
    return c;
  }

}

/**
 * @title Basic token
 * @dev Basic version of StandardToken, with no allowances.
 */
contract BasicToken is ERC20Basic {

  using SafeMath for uint256;

  mapping(address => uint256) balances;

  /**
  * @dev transfer token for a specified address
  * @param _to The address to transfer to.
  * @param _value The amount to be transferred.
  */
  function transfer(address _to, uint256 _value) public returns (bool) {
    balances[msg.sender] = balances[msg.sender].sub(_value);
    balances[_to] = balances[_to].add(_value);
    Transfer(msg.sender, _to, _value);
    return true;
  }

  /**
  * @dev Gets the balance of the specified address.
  * @param _owner The address to query the the balance of.
  * @return An uint256 representing the amount owned by the passed address.
  */
  function balanceOf(address _owner) public constant returns (uint256 balance) {
    return balances[_owner];
  }

}

/**
 * @title Standard ERC20 token
 *
 * @dev Implementation of the basic standard token.
 * @dev https://github.com/ethereum/EIPs/issues/20
 * @dev Based on code by FirstBlood: https://github.com/Firstbloodio/token/blob/master/smart_contract/FirstBloodToken.sol
 */
contract StandardToken is ERC20, BasicToken {

  mapping (address => mapping (address => uint256)) allowed;

  /**
   * @dev Transfer tokens from one address to another
   * @param _from address The address which you want to send tokens from
   * @param _to address The address which you want to transfer to
   * @param _value uint256 the amout of tokens to be transfered
   */
  function transferFrom(address _from, address _to, uint256 _value) public returns (bool) {
    var _allowance = allowed[_from][msg.sender];

    // Check is not needed because sub(_allowance, _value) will already throw if this condition is not met
    // require (_value <= _allowance);

    balances[_to] = balances[_to].add(_value);
    balances[_from] = balances[_from].sub(_value);
    allowed[_from][msg.sender] = _allowance.sub(_value);
    Transfer(_from, _to, _value);
    return true;
  }

  /**
   * @dev Aprove the passed address to spend the specified amount of tokens on behalf of msg.sender.
   * @param _spender The address which will spend the funds.
   * @param _value The amount of tokens to be spent.
   */
  function approve(address _spender, uint256 _value) public returns (bool) {

    // To change the approve amount you first have to reduce the addresses`
    //  allowance to zero by calling `approve(_spender, 0)` if it is not
    //  already 0 to mitigate the race condition described here:
    //  https://github.com/ethereum/EIPs/issues/20#issuecomment-263524729
    require((_value == 0) || (allowed[msg.sender][_spender] == 0));

    allowed[msg.sender][_spender] = _value;
    Approval(msg.sender, _spender, _value);
    return true;
  }

  /**
   * @dev Function to check the amount of tokens that an owner allowed to a spender.
   * @param _owner address The address which owns the funds.
   * @param _spender address The address which will spend the funds.
   * @return A uint256 specifing the amount of tokens still available for the spender.
   */
  function allowance(address _owner, address _spender) public constant returns (uint256 remaining) {
    return allowed[_owner][_spender];
  }

}

/**
 * @title Ownable
 * @dev The Ownable contract has an owner address, and provides basic authorization control
 * functions, this simplifies the implementation of "user permissions".
 */
contract Ownable {

  address public owner;

  /**
   * @dev The Ownable constructor sets the original `owner` of the contract to the sender
   * account.
   */
  function Ownable() public {
    owner = msg.sender;
  }

  /**
   * @dev Throws if called by any account other than the owner.
   */
  modifier onlyOwner() {
    require(msg.sender == owner);
    _;
  }

  /**
   * @dev Allows the current owner to transfer control of the contract to a newOwner.
   * @param newOwner The address to transfer ownership to.
   */
  function transferOwnership(address newOwner) public onlyOwner {
    require(newOwner != address(0));
    owner = newOwner;
  }

}

/**
 * @title Base Funds Token storage
 * @author Andrei Velikovskii
 * @dev The FundToken is extend Standart ERC20 token contract with trade functionality
 */
contract FundToken is StandardToken, Ownable {

  event TradeStoped();
  event TradeStarted();
  event RefillTokenBalance(address indexed who, uint256 value);
  event WithdrawTokenBalance(address indexed who, uint256 value);
  event SetRate(uint256 newRate, uint256 oldRate);

  // freezing token trading
  bool public tradeRuning = false;

  // Agent contract address, should be set before fund starting
  address public saleAgent;

  // rate = weis per 1 TKN: set to ETH2USD on start - meaning 1 TKN = 1 USD, for example 10^18/686 on	2017-12-15
  // if totalSupply == 0, rate setting to current 10^18/USDT_ETH on Bittrex
  uint public rate;

  // freezing rate changing
  bool public rateFixed = false;

  /**
   * @dev Throws if trade stopped.
   */
  modifier canTrade() {
    require(tradeRuning);
    _;
  }

  /**
   * @dev Throws if called by any account other than the owner or agent contract.
   */
  modifier onlyOwner() {
    require(msg.sender == saleAgent || msg.sender == owner);
    _;
  }

  /**
   * @notice Set new rate for trading contract tokens.
   * @param newRate The TKNs by 1 ether
   */
  function setRate(uint256 newRate) public onlyOwner {
    require(!rateFixed);
    ///uint256 oldRate = rate;
    rate = newRate;
    /// disabled, cause generate too much events,
    /// originaly fired on bakend
    ///SetRate(newRate, oldRate);
  }

  /**
   * @notice Calculate token amount by wei amount.
   * @param weiAmount The amount of wei
   * @return Amount of tokens
   */
  function getTokensByWei(uint256 weiAmount) public constant returns (uint256 tokens) {
    tokens = weiAmount.div(rate);
    return tokens;
  }

  /**
   * @notice Calculate wei amount by token amount.
   * @param tokens The amount of tokens
   * @return Amount of wei
   */
  function getWeiByTokens(uint256 tokens) public constant returns (uint256 weiAmount) {
    weiAmount = tokens.mul(rate);
    return weiAmount;
  }

  /**
   * @notice Set address of Agent Contract, should be set before fund starting.
   * @param newSaleAgnet The address of Agent Contract
   */
  function setSaleAgent(address newSaleAgnet) public {
    require(msg.sender == saleAgent || msg.sender == owner);
    saleAgent = newSaleAgnet;
  }

  /**
   * @notice Main function to enter the fund buying tokens.
   * Should be call from agent contract, not directly.
   * @param who The buyers (investor) address.
   * @param tokens The amount of buying tokens.
   */
  function buyTokens(address who, uint256 tokens) public onlyOwner canTrade returns (bool) {
    totalSupply = totalSupply.add(tokens);
    balances[who] = balances[who].add(tokens);
    Transfer(address(0), who, tokens);
    return true;
  }

  /**
   * @notice Main function to exit the fund selling tokens.
   * Should be call from agent contract, not directly.
   * @param who The buyers (investor) address.
   * @param tokens The amount of selling tokens.
   */
  function sellTokens(address who, uint256 tokens) public onlyOwner returns (bool) {
    require(tokens > 0 && balances[who] >= tokens && totalSupply >= tokens);
    totalSupply = totalSupply.sub(tokens);
    balances[who] = balances[who].sub(tokens);
    Transfer(who, address(0), tokens);
    return true;
  }

  /**
   * @notice Start token trading.
   */
  function stopTrade() public onlyOwner returns (bool) {
    tradeRuning = false;
    TradeStoped();
    return true;
  }

  /**
   * @notice Stop token trading.
   */
  function startTrade() public onlyOwner returns (bool) {
    tradeRuning = true;
    TradeStarted();
    return true;
  }

  /**
   * @notice Disable changing token rate.
   */
  function fixRate() public onlyOwner returns (bool) {
    rateFixed = true;
    return true;
  }

  /**
   * @notice Enable changing token rate.
   */
  function unfixRate() public onlyOwner returns (bool) {
    rateFixed = true;
    return true;
  }

  /**
   * @notice Refill ETH balance of token contract address.
   * @dev Since contract is immortal, it can be refilled for any reasons by owner.
   */
  function refillTokenBalance() public onlyOwner payable {
    RefillTokenBalance(msg.sender, msg.value);
  }

  /**
   * @notice Withdraw ETH balance of token contract address.
   * @param value The amount of wei.
   * @dev Since contract is immortal, it can be withdraw wrong recieved money or another use case by owner.
   */
  function withdrawTokenBalance(uint256 value) public onlyOwner payable {
    msg.sender.transfer(value);
    WithdrawTokenBalance(msg.sender, value);
  }

}

/**
 * @title Implementation of FundToken contract with concreate ERC20 parameters.
 * @author Andrei Velikovskii
 * @dev The CCFundToken is extend FundToken contract for deploy.
 */
contract CCFundToken is FundToken {

  string public constant name = "Crypto Funds Token";

  string public constant symbol = "MCFT";

  uint32 public constant decimals = 9;

}

/**
 * @title Agent Contract for control the CCFundToken contract.
 * @author Andrei Velikovskii
 * @dev The CCFundAgent is Agent contract for deploy.
 * Mortal. Can be killed and replaced to new one if needed.
 */
contract CCFundAgent is Ownable {

  using SafeMath for uint;

  address public fund_addr;

  address public profit_addr;

  address public api_key_addr;

  CCFundToken public tokenStorage;

  struct SellOrder {
    uint256 tokens;
    uint256 rate;
  }

  mapping(address => SellOrder) sellOrders;

  uint256 public withdrawProfitOrder;

  event PluginInvestor(address indexed investor, uint256 tokens, uint256 weiAmount, uint256 rate, uint256 timestamp, uint256 dealId);
  event UnplugInvestor(address indexed investor, uint256 tokens, uint256 weiAmount, uint256 rate, uint256 timestamp, uint256 dealId);
  event RefillAgentBalance(address indexed who, uint256 value);
  event WithdrawAgentBalance(address indexed who, uint256 value);
  event ConfirmAddress(uint256 indexed confirmCode);
  event AddSellOrder(address indexed who, uint256 tokenAmount, uint256 rate);
  event AddWithdrawProfitOrder(uint256 indexed weiAmount);
  event WithdrawProfit(uint256 indexed weiAmount);
  event Buy(address indexed who, uint256 tokens, uint256 weiAmount);
  event Sell(address indexed who, uint256 tokens, uint256 weiAmount);

  /**
   * @dev Throws if called by any account other than the API address (api_key_addr).
   */
  modifier onlyApi() {
    require(msg.sender == api_key_addr);
    _;
  }

  /**
   * @notice Confirm investor ETH address in Fund System by sending correct code.
   * @param code The random value. It's obtained in Fund System GUI.
   */
  function confirmAddress(uint256 code) public {
    ConfirmAddress(code);
  }

  /**
   * @notice Plugin investor in case no chance paying ethers directly to contract.
   * @param investor The investors ETH address.
   * @param tokens The amount of tokens for buying.
   * @param rate The rate of tokens in wei for date.
   * @param timestamp The timestamp of deal.
   */
  function pluginInvestor(address investor, uint256 tokens, uint256 rate, uint256 timestamp, uint256 dealId) public onlyOwner {
    require(investor != address(0) && tokens > 0);
    tokenStorage.buyTokens(investor, tokens);
    uint256 weiAmount = tokens.mul(rate);
    PluginInvestor(investor, tokens, weiAmount, rate, timestamp, dealId);
  }

  /**
   * @notice Unplug investor in case no chance sell token throw the order.
   * @param investor The investors ETH address.
   * @param tokens The amount of tokens for selling.
   * @param rate The rate of tokens in wei for date.
   * @param timestamp The timestamp of deal.
   */
  function unplugInvestor(address investor, uint256 tokens, uint256 rate, uint256 timestamp, uint256 dealId) public onlyOwner {
    require(investor != address(0)
         && tokens >= 0
         && tokenStorage.balanceOf(investor) >= tokens
         && tokenStorage.totalSupply() >= tokens);
    tokenStorage.sellTokens(investor, tokens);
    uint256 weiAmount = tokens.mul(rate);
    UnplugInvestor(investor, tokens, weiAmount, rate, timestamp, dealId);
  }

  /**
   * @notice Encrease amount to withdraw Profit by Fund Owners.
   * @param weiAmount The amount of wei
   */
  function addWithdrawProfitOrder(uint256 weiAmount) public onlyOwner {
    require(weiAmount > 0);
    withdrawProfitOrder = withdrawProfitOrder.add(weiAmount);
    AddWithdrawProfitOrder(weiAmount);
  }

  /**
   * @notice Withdraw Profit by Fund Owners.
   */
  function withdrawProfit() public onlyOwner payable {
    require(withdrawProfitOrder > 0);
    uint weiAmount = withdrawProfitOrder;
    withdrawProfitOrder = 0;
    profit_addr.transfer(weiAmount);
    WithdrawProfit(weiAmount);
  }

  /**
   * @notice Add investors sell order after confirmation by Fund manager.
   * @param investor The address of investor.
   * @param tokenAmount The amount of token for sell.
   * @param rate The rate of token in wei for sell.
   * @dev Can't be called by investor .
   */
  function addSellOrder(address investor, uint256 tokenAmount, uint256 rate) public onlyOwner {
    require(tokenAmount > 0 && tokenStorage.balanceOf(investor) >= tokenAmount);
    sellOrders[investor] = SellOrder(tokenAmount, rate);
    AddSellOrder(investor,tokenAmount,rate);
  }

  /**
   * @notice Sell tokens.
   * @dev Should be called by investor .
   */
  function sellTokens() public payable {
    uint tokenAmount = sellOrders[msg.sender].tokens;
    uint weiAmount = tokenAmount.mul(sellOrders[msg.sender].rate);
    require(tokenAmount > 0
         && tokenStorage.balanceOf(msg.sender) >= tokenAmount
         && tokenStorage.totalSupply() >= tokenAmount
         && this.balance >= weiAmount);
    sellOrders[msg.sender] = SellOrder(0, 0);
    delete sellOrders[msg.sender];
    tokenStorage.sellTokens(msg.sender, tokenAmount);
    msg.sender.transfer(weiAmount);
    Sell(msg.sender, tokenAmount, weiAmount);
  }

  /**
   * @notice Setting tokens contract address.
   * @param tokenAddress The address of token contract.
   * @dev Should be set before fund starting.
   */
  function setTokenContract(address tokenAddress) public onlyOwner {
    tokenStorage = CCFundToken(tokenAddress);
  }

  /**
   * @notice Kill agent contract.
   * @dev Need for recreate new fund logic.
   */
  function kill() public onlyOwner() {
    selfdestruct(owner);
  }

  /**
   * @notice Set tokens rate.
   * @param newRate The value of tokens for 1 ether.
   * @dev Check rate fixing.
   */
  function setRate(uint256 newRate) public onlyOwner {
    tokenStorage.setRate(newRate);
  }

  /**
   * @notice Set ETH address to withdraw funds profit.
   * @param newProfit_addr The address of funds owners profit.
   */
  function setProfitAddr(address newProfit_addr) public onlyOwner {
    require(newProfit_addr != address(0));
    profit_addr = newProfit_addr;
  }

  /**
   * @notice Set ETH address of Fund.
   * @param newFund_addr The address of funds owners.
   * @dev This address refills every time in case of buying tokens.
   */
  function setFundAddr(address newFund_addr) public onlyOwner {
    require(newFund_addr != address(0));
    fund_addr = newFund_addr;
  }

  /**
   * @notice Set ETH address of API.
   * @param newApiKey The address of API for contract managing.
   * @dev This address should be set before start trading.
   */
  function setApiKey(address newApiKey) public onlyOwner {
    require(newApiKey != address(0));
    api_key_addr = newApiKey;
  }

  /**
   * @notice Get current state of trading.
   * @return TRUE if trading running and FALSE if not.
   */
  function tradeRuning() public constant returns(bool) {
    if(tokenStorage.tradeRuning()) return true;
    return false;
  }

  /**
   * @notice Start token trading.
   */
  function startTrade() public onlyApi {
    require(!tokenStorage.tradeRuning());
    tokenStorage.startTrade();
  }

  /**
   * @notice Stop token trading.
   */
  function stopTrade() public onlyApi {
    require(tokenStorage.tradeRuning());
    tokenStorage.stopTrade();
  }

  /**
   * @notice Disable changing token rate.
   */
  function fixRate() public onlyOwner {
    tokenStorage.fixRate();
  }

  /**
   * @notice Enable changing token rate.
   */
  function unfixRate() public onlyOwner {
    tokenStorage.unfixRate();
  }

  /**
   * @notice Refill ETH balance of agent contract address for Sell Orders and withdraw Profit.
   * @dev Should be refill by refillAgentBalance() before confirm Sell Order,
   * because agent balance actually around ZERO during trading
   * and need to refill directly before withdarw ethers from it.
   */
  function refillAgentBalance() public onlyOwner payable {
    RefillAgentBalance(msg.sender, msg.value);
  }

  /**
   * @notice Withdraw ETH balance of agent contract address.
   * @param weiAmount The amount of wei.
   */
  function withdrawAgentBalance(uint256 weiAmount) public onlyOwner payable {
    msg.sender.transfer(weiAmount);
    WithdrawAgentBalance(msg.sender, weiAmount);
  }

  /**
   * @notice Buy Tokens payable function.
   */
  function buyTokens() public payable {
    require(tokenStorage.tradeRuning() && fund_addr != address(0));
    uint256 tokens = tokenStorage.getTokensByWei(msg.value);
    tokenStorage.buyTokens(msg.sender, tokens);
    fund_addr.transfer(msg.value);
    Buy(msg.sender, tokens, msg.value);
  }

  /**
   * @notice Default payable entrypoint.
   */
  function() external payable {
    buyTokens();
  }

}
