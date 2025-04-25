// SPDX-License-Idenifier: MIT

pragma solidity 0.8.28;

import {BookManager} from "../src/BookManager.sol";
import {Test, console2} from "forge-std/Test.sol";

abstract contract Base_Test is Test {
    BookManager bookManagerContract;
    address owner;
    address alice;
    // address bob;

    function setUp() public virtual {
        owner = address(this); // The test contract is the deployer/owner.
        alice = address(0x1);
        // bob = address(0x2);
        bookManagerContract = new BookManager(0, "cloneable blank", owner);
        
    }

    function testLoadVerses() public virtual {
        uint256[] memory _verseNumbers = new uint256[](10);
        uint256[] memory _chapterNumbers = new uint256[](10);
        string[] memory _verseContent = new string[](10);

        for (uint256 i = 0; i < 10; i++) {
            _verseNumbers[i] = i + 1;
            _chapterNumbers[i] = 1;
            _verseContent[i] = "TEST";
        }

        bytes memory _bookId = abi.encodePacked("0x1234567890abcdef");

        bookManagerContract.addBatchVerses(_bookId, _verseNumbers, _chapterNumbers, _verseContent);

        //bookManagerContract.getLastVerseAdded()
        // assertEq()
    }
}
