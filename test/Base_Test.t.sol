// SPDX-License-Idenifier: MIT

pragma solidity 0.8.28;

import {BookManager} from "../src/BookManager.sol";
import {Test, console2} from "forge-std/Test.sol";

abstract contract Base_Test is Test {
    BookManager _manager;
    address owner;
    address alice;
    address bob;

    uint256 immutable indexOne = 1;
    uint256 immutable indexTwo = 2;
    string constant titleOne = "Genesis";
    string constant titleTwo = "Exodus";

    function setUp() public virtual {
        owner = address(this); // The test contract is the deployer/owner.
        alice = address(0x1);
        bob = address(0x2);
        _manager = new BookManager();        
    }

    function testStoreBook() public virtual {
        vm.expectEmit(true, true, true, true);
        emit BookManager.Book(indexOne, titleOne);
        _manager.addBook(indexOne, titleOne);
    }

    function testStoreVerses() public virtual {
        _manager.addBook(indexOne, titleOne);

        uint256[] memory _verseNumbers = new uint256[](10);
        uint256[] memory _chapterNumbers = new uint256[](10);
        string[] memory _verseContent = new string[](10);

        for (uint256 i = 0; i < 10; i++) {
            uint256 ip1 = i + 1;
            _verseNumbers[i] = ip1;
            _chapterNumbers[i] = 1;
            _verseContent[i] = string(abi.encodePacked("TEST ", vm.toString(ip1)));
        }

        bytes memory _bookId = abi.encodePacked("0x1234567890abcdef");

        _manager.addBatchVerses(indexOne, _bookId, _verseNumbers, _chapterNumbers, _verseContent);

        BookManager.VerseStr memory lastVerseAdded = _manager.getLastVerseAdded(indexOne);
        assertEq(lastVerseAdded.verseNumber, 10);
        assertEq(lastVerseAdded.verseContent, "TEST 10");
    }
}
