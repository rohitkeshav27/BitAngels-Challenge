pragma solidity 0.7.0;


import "./IERC20.sol";
import "./IMintableToken.sol";
import "./IDividends.sol";
import "./SafeMath.sol";


contract Token is IERC20, IMintableToken, IDividends {
 using SafeMath for uint256;


 // ------------------------------------------ //
 // ----- BEGIN: DO NOT EDIT THIS SECTION ---- //
 // ------------------------------------------ //
 uint256 public totalSupply;
 uint256 public decimals = 18;
 string public name = "Test token";
 string public symbol = "TEST";
 mapping (address => uint256) public balanceOf;
 // ------------------------------------------ //
 // ----- END: DO NOT EDIT THIS SECTION ------ //
 // ------------------------------------------ //


 // ===== ERC20 allowance =====
 mapping(address => mapping(address => uint256)) private _allowances;


 // ===== Holder tracking (1-indexed) =====
 address[] private _holders;
 mapping(address => uint256) private _holderIndex;


 // ===== Dividend balances (exact) =====
 mapping(address => uint256) private _withdrawableDividend;


 constructor() {
   _holders.push(address(0));
 }


 // =====================================================
 // ----------------- ERC20 -----------------------------
 // =====================================================


 function allowance(address owner, address spender)
   external
   view
   override
   returns (uint256)
 {
   return _allowances[owner][spender];
 }


 function approve(address spender, uint256 value)
   external
   override
   returns (bool)
 {
   _allowances[msg.sender][spender] = value;
   return true;
 }


 function transfer(address to, uint256 value)
   external
   override
   returns (bool)
 {
   _transfer(msg.sender, to, value);
   return true;
 }


 function transferFrom(address from, address to, uint256 value)
   external
   override
   returns (bool)
 {
   uint256 allowed = _allowances[from][msg.sender];
   require(allowed >= value, "allowance");
   _allowances[from][msg.sender] = allowed.sub(value);


   _transfer(from, to, value);
   return true;
 }


 function _transfer(address from, address to, uint256 value) internal {
 
   require(balanceOf[from] >= value, "balance");


   balanceOf[from] = balanceOf[from].sub(value);
   balanceOf[to] = balanceOf[to].add(value);


   _updateHolder(from);
   _updateHolder(to);
 }


 // =====================================================
 // ----------------- Mint / Burn -----------------------
 // =====================================================


 function mint() external payable override {
   require(msg.value > 0, "empty mint");


   uint256 amount = msg.value;


   totalSupply = totalSupply.add(amount);
   balanceOf[msg.sender] = balanceOf[msg.sender].add(amount);


   _updateHolder(msg.sender);
 }


 function burn(address payable dest) external override {
   require(dest != address(0), "dest=0");


   uint256 amount = balanceOf[msg.sender];
   require(amount > 0, "nothing to burn");


   balanceOf[msg.sender] = 0;
   totalSupply = totalSupply.sub(amount);


   _updateHolder(msg.sender);


   (bool ok, ) = dest.call{ value: amount }("");
   require(ok, "eth transfer failed");
 }


 // =====================================================
 // ----------------- Holders ---------------------------
 // =====================================================


 function _updateHolder(address account) internal {
   if (balanceOf[account] > 0 && _holderIndex[account] == 0) {
     _holders.push(account);
     _holderIndex[account] = _holders.length - 1;
   }


   if (balanceOf[account] == 0 && _holderIndex[account] != 0) {
     uint256 index = _holderIndex[account];
     uint256 lastIndex = _holders.length - 1;


     if (index != lastIndex) {
       address last = _holders[lastIndex];
       _holders[index] = last;
       _holderIndex[last] = index;
     }


     _holders.pop();
     _holderIndex[account] = 0;
   }
 }


 function getNumTokenHolders()
   external
   view
   override
   returns (uint256)
 {
   if (_holders.length == 0) return 0;
   return _holders.length - 1;
 }


 function getTokenHolder(uint256 index)
   external
   view
   override
   returns (address)
 {
  
   if (index == 0 || index >= _holders.length) return address(0);
   return _holders[index];
 }


 // =====================================================
 // ----------------- Dividends -------------------------
 // =====================================================


 function recordDividend() external payable override {
   require(msg.value > 0, "empty dividend");
   require(totalSupply > 0, "no supply");


  
   uint256 remaining = msg.value;


   uint256 n = _holders.length - 1;
   for (uint256 i = 1; i <= n; i++) {
     address holder = _holders[i];
     uint256 bal = balanceOf[holder];


   
     uint256 share = msg.value.mul(bal).div(totalSupply);


     if (share > 0) {
       _withdrawableDividend[holder] = _withdrawableDividend[holder].add(share);
       remaining = remaining.sub(share);
     }
   }


 
   if (remaining > 0 && n > 0) {
     address first = _holders[1];
     _withdrawableDividend[first] = _withdrawableDividend[first].add(remaining);
   }
 }


 function getWithdrawableDividend(address payee)
   external
   view
   override
   returns (uint256)
 {
   return _withdrawableDividend[payee];
 }


 function withdrawDividend(address payable dest)
   external
   override
 {
   require(dest != address(0), "dest=0");


   uint256 amount = _withdrawableDividend[msg.sender];
   require(amount > 0, "nothing");


   _withdrawableDividend[msg.sender] = 0;


   (bool ok, ) = dest.call{ value: amount }("");
   require(ok, "eth transfer failed");
 }


 receive() external payable {}
}


