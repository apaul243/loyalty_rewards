// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.17;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";


contract TestToken is ERC20,Ownable {

    constructor() ERC20("TEST_TOKEN","TST") {}

    bool ifPaused = false;

   modifier whenNotPaused() {
       require(!ifPaused, "Contract is paused");
       _;
   }
    function mint(address to, uint256 amount) public whenNotPaused onlyOwner {
        _mint(to,amount);
    }

    function burn(address _user,uint256 amount) public whenNotPaused onlyOwner {
        _burn(_user,amount);
    }

    function pause() public onlyOwner {
        ifPaused = true;
    }

    function unpause() public onlyOwner {
        ifPaused = false;
    }

}