// SPDX-License-Identifier: MIT

pragma solidity ^0.8.7;

import "forge-std/Test.sol";
import "forge-std/StdCheats.sol";
import "../contracts/TestToken.sol";

contract TokenTest is Test {
    TestToken public token;
    address owner = makeAddr("owner");
    address john = makeAddr("john");
    address kelly = makeAddr("kelly");

    function setUp() public {
        vm.startPrank(owner);
        token = new TestToken(); // Deploy token contract
        token.mint(john, 100*10**18);
        assertEq(token.balanceOf(john), 100*10**18);
        vm.stopPrank();
    }

    /* Checking  a) Non-owner tries to mint and fails.
     *           b) Owner tries to mint and succeeds.
     */
    function test_tokenMinting_onlyOwner() public {
        vm.prank(john);
        vm.expectRevert(bytes("Ownable: caller is not the owner"));
        token.mint(john, 100*10**18);        
        vm.prank(owner);
        token.mint(kelly, 10*10**18);
        assertEq(token.balanceOf(kelly), 10*10**18);
    }

    /* Checking  a) Non-owner tries to burn and fails.
     *           b) Owner tries to burn and succeeds.
     */
    function test_tokenBurning_onlyOwner() public {
        vm.prank(john);
        vm.expectRevert(bytes("Ownable: caller is not the owner"));
        token.burn(john, 100*10**18);        
        vm.prank(owner);
        token.burn(john, 10*10**18);
        assertEq(token.balanceOf(john), 90*10**18);
    }

    /* Checking if erc20 transfer function is working properly*/
    function test_erc20transfer() public {
        vm.prank(john);
        token.transfer(kelly,10*10**18);
        assertEq(token.balanceOf(john), 90*10**18);
        assertEq(token.balanceOf(kelly),10*10**18);
    }
}
  