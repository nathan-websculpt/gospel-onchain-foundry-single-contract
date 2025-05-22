// SPDX-License-Idenifier: MIT

// forge coverage --ir-minimum
// forge coverage --ir-minimum --report debug
// forge coverage --ir-minimum --report debug > coverage.txt

pragma solidity 0.8.28;

import {BookManager} from "../src/BookManager.sol";
import {Test, console2, Vm} from "forge-std/Test.sol";

abstract contract Base_Test is Test {
    uint256 constant ARRAY_LEN = 100;
    BookManager _manager;
    address owner;
    address alice;
    address bob;

    uint256 immutable indexOne = 1;
    uint256 immutable indexTwo = 2;
    uint256 immutable indexThree = 3;
    string constant titleOne = "Genesis";
    string constant titleTwo = "Exodus";
    string constant titleThree = "Leviticus";

    function setUp() public virtual {
        owner = address(this); // The test contract is the deployer/owner.
        alice = address(0x1);
        bob = address(0x2);
        _manager = new BookManager();
    }

    // forge test --mt testLogGasIncreasePerBatch
    function testLogGasIncreasePerBatch() public virtual {
        _manager.addBook(indexOne, titleOne);
        bytes memory _bookId = abi.encodePacked("0x1234567890abcdef");

        uint256 scale = 10000; // for precision/fixed-point arithmetic
        uint256 oldGasUsed = 0;
        uint256 gas = gasleft();
        uint256 firstTxGas = 0;
        uint256 lastTxGas = 0;
        console2.log("initial gas: ", gas);

        //store 5 batches
        for (uint256 i = 0; i < 5; i++) {
            (
                uint256[] memory _verseNumbers,
                uint256[] memory _chapterNumbers,
                string[] memory _verseContent
            ) = _makeVerses(i + 1);

            _manager.addBatchVerses(
                indexOne,
                _bookId,
                _verseNumbers,
                _chapterNumbers,
                _verseContent
            );

            uint256 gasUsed = gas - gasleft();

            // percentage increase = ((newVal - oldVal) / oldVal) x 100%
            if (oldGasUsed != 0) {
                if (oldGasUsed < gasUsed) {
                    console2.log("\n");
                    uint256 diff = gasUsed - oldGasUsed;
                    uint256 scaledPercentage = (diff * scale) / oldGasUsed;
                    
                    uint256 integerPart = scaledPercentage / 100;
                    uint256 decimalPart = scaledPercentage % 100;

                    string memory rslt = string(abi.encodePacked(
                        vm.toString(integerPart),
                        ".",
                        decimalPart < 10 ? "0" : "",
                        vm.toString(decimalPart),
                        "%"
                    ));

                    string memory gasUsedStr = string(abi.encodePacked("Gas used for batch # ", vm.toString(i + 1), ":"));
                    console2.log(gasUsedStr, gasUsed);
                    console2.log("increase", diff);
                    console2.log("percentage increase", rslt);
                    console2.log("\n");
                } else {
                    console2.log("No Increase, gas used: ", gasUsed);
                }
            } else {
                firstTxGas = gas - gasleft();
                console2.log("FIRST RUN, gas used: ", vm.toString(firstTxGas));
            }
            if(i == 5) lastTxGas = gasUsed;
            oldGasUsed = gasUsed;

            gas = gasleft();
            console2.log("ENDOFLOOP gasLeft: ", gas);
        }

        //now log the entire increase (across all 5 batches)
        if(lastTxGas > firstTxGas) {
            uint256 diff = lastTxGas - firstTxGas;
            uint256 scaledPercentage = (diff * scale) / firstTxGas;
            
            uint256 integerPart = scaledPercentage / 100;
            uint256 decimalPart = scaledPercentage % 100;

            string memory rslt = string(abi.encodePacked(
                vm.toString(integerPart),
                ".",
                decimalPart < 10 ? "0" : "",
                vm.toString(decimalPart),
                "%"
            ));
            console2.log("\n");
            console2.log("entire % increase", rslt);
            console2.log("first tx gas", firstTxGas);
            console2.log("last tx gas", lastTxGas);
        } else {
            console2.log("\n");
            console2.log("First tx cost more than the final tx - no extra log needed");
            console2.log("\n");
            console2.log("\n");
        }
    }

    function testOwnershipTransfer() public virtual {
        assertEq(_manager.owner(), owner);
        _manager.transferOwnership(alice);
        assertEq(_manager.owner(), alice);

        // should revert when old owner makes a book
        vm.expectRevert();
        _manager.addBook(indexOne, titleOne);

        // make sure alice can deploy a book
        vm.expectEmit(true, true, true, true);
        emit BookManager.Book(indexOne, titleOne);
        vm.prank(alice);
        _manager.addBook(indexOne, titleOne);

        //TODO:
        // BookManager.Book[] memory _books = _manager.getBooks();
        // assertEq(_books.length, 2);
    }

    function testStoreBook() public virtual {
        vm.expectEmit(true, true, true, true);
        emit BookManager.Book(indexOne, titleOne);
        _manager.addBook(indexOne, titleOne);
    }

    function testOnlyOwnerCanStoreBook() public virtual {
        vm.startPrank(alice);
        vm.expectRevert();
        _manager.addBook(indexOne, titleOne);
        vm.stopPrank();
    }

    function testStoreVerses() public virtual {
        _manager.addBook(indexOne, titleOne);

        // At the end of the day, _bookId is only for the subgraph
        bytes memory _bookId = abi.encodePacked("0x1234567890abcdef");

        (
            uint256[] memory _verseNumbers,
            uint256[] memory _chapterNumbers,
            string[] memory _verseContent
        ) = _makeVerses(1);

        vm.recordLogs();
        _manager.addBatchVerses(
            indexOne,
            _bookId,
            _verseNumbers,
            _chapterNumbers,
            _verseContent
        );
        Vm.Log[] memory recordedLogs = vm.getRecordedLogs();
        assertEq(recordedLogs.length, ARRAY_LEN);

        for (uint256 i = 0; i < recordedLogs.length; i++) {
            address signer = address(
                uint160(uint256(recordedLogs[i].topics[1]))
            );
            assertEq(signer, address(this));

            // The .data field contains the ABI-encoded values of the event's non-indexed arguments, packed together in the order they appear in the event definition
            (
                uint256 loggedBookIndex,
                bytes memory loggedBookId,
                uint256 loggedVerseId,
                uint256 loggedVerseNumber,
                uint256 loggedChapterNumber,
                string memory loggedVerseContent
            ) = abi.decode(
                    recordedLogs[i].data,
                    (uint256, bytes, uint256, uint256, uint256, string)
                );

            assertEq(loggedBookIndex, indexOne);
            assertEq(loggedBookId, _bookId);
            assertEq(loggedVerseId, _verseNumbers[i]);
            assertEq(loggedVerseNumber, _verseNumbers[i]);
            assertEq(loggedChapterNumber, _chapterNumbers[i]);
            assertEq(loggedVerseContent, _verseContent[i]);
        }
    }

    function testStoreVerses_inMultipleBooks() public virtual {
        _manager.addBook(indexOne, titleOne);
        _manager.addBook(indexTwo, titleTwo);
        _manager.addBook(indexThree, titleThree);

        // At the end of the day, _bookId is only for the subgraph
        bytes memory _b1Id = abi.encodePacked("0xbookone");
        bytes memory _b2Id = abi.encodePacked("0xbooktwo");
        bytes memory _b3Id = abi.encodePacked("0xbookthree");

        //Book One's verses (same as in other tests [20 items])
        (
            uint256[] memory _verseNumbers,
            uint256[] memory _chapterNumbers,
            string[] memory _verseContent
        ) = _makeVerses(1);

        //Book Two's verses [5 items]
        uint256[] memory _b2verseNumbers = new uint256[](5);
        uint256[] memory _b2chapterNumbers = new uint256[](5);
        string[] memory _b2verseContent = new string[](5);

        for (uint256 i = 0; i < 5; i++) {
            uint256 ip1 = i + 1;
            _b2verseNumbers[i] = ip1;
            _b2chapterNumbers[i] = 1;
            _b2verseContent[i] = string(
                abi.encodePacked("Book Two ", vm.toString(ip1))
            );
        }

        //Book Three's verses [5 items]
        uint256[] memory _b3verseNumbers = new uint256[](5);
        uint256[] memory _b3chapterNumbers = new uint256[](5);
        string[] memory _b3verseContent = new string[](5);

        for (uint256 i = 0; i < 5; i++) {
            uint256 ip1 = i + 1;
            _b3verseNumbers[i] = ip1;
            _b3chapterNumbers[i] = 1;
            _b3verseContent[i] = string(
                abi.encodePacked("Book Three ", vm.toString(ip1))
            );
        }

        vm.recordLogs();
        _manager.addBatchVerses(
            indexOne,
            _b1Id,
            _verseNumbers,
            _chapterNumbers,
            _verseContent
        );
        _manager.addBatchVerses(
            indexTwo,
            _b2Id,
            _b2verseNumbers,
            _b2chapterNumbers,
            _b2verseContent
        );
        _manager.addBatchVerses(
            indexThree,
            _b3Id,
            _b3verseNumbers,
            _b3chapterNumbers,
            _b3verseContent
        );
        Vm.Log[] memory recordedLogs = vm.getRecordedLogs();
        assertEq(recordedLogs.length, 110);

        for (uint256 i = 0; i < 110; i++) {
            // The .data field contains the ABI-encoded values of the event's non-indexed arguments, packed together in the order they appear in the event definition
            (
                uint256 loggedBookIndex,
                bytes memory loggedBookId,
                uint256 loggedVerseId,
                uint256 loggedVerseNumber,
                uint256 loggedChapterNumber,
                string memory loggedVerseContent
            ) = abi.decode(
                    recordedLogs[i].data,
                    (uint256, bytes, uint256, uint256, uint256, string)
                );

            if (i < ARRAY_LEN) {
                //book one [20 items]
                assertEq(loggedBookIndex, indexOne);
                assertEq(loggedBookId, _b1Id);
                assertEq(loggedVerseId, _verseNumbers[i]);
                assertEq(loggedVerseNumber, _verseNumbers[i]);
                assertEq(loggedChapterNumber, _chapterNumbers[i]);
                assertEq(loggedVerseContent, _verseContent[i]);
            } else if (i < 105) {
                //book two [5 items]
                assertEq(loggedBookIndex, indexTwo);
                assertEq(loggedBookId, _b2Id);
                assertEq(loggedVerseId, _b2verseNumbers[i - ARRAY_LEN]);
                assertEq(loggedVerseNumber, _b2verseNumbers[i - ARRAY_LEN]);
                assertEq(loggedChapterNumber, _b2chapterNumbers[i - ARRAY_LEN]);
                assertEq(loggedVerseContent, _b2verseContent[i - ARRAY_LEN]);
            } else {
                // book three [5 items]
                assertEq(loggedBookIndex, indexThree);
                assertEq(loggedBookId, _b3Id);
                assertEq(loggedVerseId, _b3verseNumbers[i - 105]);
                assertEq(loggedVerseNumber, _b3verseNumbers[i - 105]);
                assertEq(loggedChapterNumber, _b3chapterNumbers[i - 105]);
                assertEq(loggedVerseContent, _b3verseContent[i - 105]);
            }
        }
    }

    function testOnlyOwnerCanStoreVerses() public virtual {
        _manager.addBook(indexOne, titleOne);

        // At the end of the day, _bookId is only for the subgraph
        bytes memory _bookId = abi.encodePacked("0x1234567890abcdef");

        (
            uint256[] memory _verseNumbers,
            uint256[] memory _chapterNumbers,
            string[] memory _verseContent
        ) = _makeVerses(1);

        vm.startPrank(alice);
        vm.expectRevert();
        _manager.addBatchVerses(
            indexOne,
            _bookId,
            _verseNumbers,
            _chapterNumbers,
            _verseContent
        );
        vm.stopPrank();
    }

    function testGetLastVerseAdded() public virtual {
        _manager.addBook(indexOne, titleOne);

        bytes memory _bookId = abi.encodePacked("0x1234567890abcdef");

        (
            uint256[] memory _verseNumbers,
            uint256[] memory _chapterNumbers,
            string[] memory _verseContent
        ) = _makeVerses(1);

        _manager.addBatchVerses(
            indexOne,
            _bookId,
            _verseNumbers,
            _chapterNumbers,
            _verseContent
        );

        BookManager.VerseStr memory lastVerseAdded = _manager.getLastVerseAdded(
            indexOne
        );

        assertEq(lastVerseAdded.verseNumber, ARRAY_LEN);
        assertEq(lastVerseAdded.verseContent, string(abi.encodePacked("TEST ", vm.toString(ARRAY_LEN))));
    }

    function testGetVerseByNumber() public virtual {
        _manager.addBook(indexOne, titleOne);

        bytes memory _bookId = abi.encodePacked("0x1234567890abcdef");

        (
            uint256[] memory _verseNumbers,
            uint256[] memory _chapterNumbers,
            string[] memory _verseContent
        ) = _makeVerses(1);

        _manager.addBatchVerses(
            indexOne,
            _bookId,
            _verseNumbers,
            _chapterNumbers,
            _verseContent
        );

        BookManager.VerseStr memory firstVerse = _manager.getVerseByNumber(
            indexOne,
            1
        );

        assertEq(firstVerse.verseNumber, 1);
        assertEq(firstVerse.verseContent, "TEST 1");

        BookManager.VerseStr memory anotherTest = _manager.getVerseByNumber(
            indexOne,
            11
        );

        assertEq(anotherTest.verseNumber, 11);
        assertEq(anotherTest.verseContent, "TEST 11");
    }

    function testConfirmVerses() public virtual {
        _manager.addBook(indexOne, titleOne);

        // At the end of the day, _bookId is only for the subgraph
        bytes memory _bookId = abi.encodePacked("0x1234567890abcdef");

        (
            uint256[] memory _verseNumbers,
            uint256[] memory _chapterNumbers,
            string[] memory _verseContent
        ) = _makeVerses(1);

        vm.recordLogs();
        _manager.addBatchVerses(
            indexOne,
            _bookId,
            _verseNumbers,
            _chapterNumbers,
            _verseContent
        );
        Vm.Log[] memory recordedLogs = vm.getRecordedLogs();
        assertEq(recordedLogs.length, ARRAY_LEN);

        for (uint256 i = 0; i < recordedLogs.length; i++) {
            address signer = address(
                uint160(uint256(recordedLogs[i].topics[1]))
            );
            assertEq(signer, address(this));

            // The .data field contains the ABI-encoded values of the event's non-indexed arguments, packed together in the order they appear in the event definition
            (
                uint256 loggedBookIndex,
                bytes memory loggedBookId,
                uint256 loggedVerseId,
                uint256 loggedVerseNumber,
                uint256 loggedChapterNumber,
                string memory loggedVerseContent
            ) = abi.decode(
                    recordedLogs[i].data,
                    (uint256, bytes, uint256, uint256, uint256, string)
                );

            assertEq(loggedBookIndex, indexOne);
            assertEq(loggedBookId, _bookId);
            assertEq(loggedVerseId, _verseNumbers[i]);
            assertEq(loggedVerseNumber, _verseNumbers[i]);
            assertEq(loggedChapterNumber, _chapterNumbers[i]);
            assertEq(loggedVerseContent, _verseContent[i]);

            // this verse ID bytes array is just for the subgraph
            bytes memory _verseBytesId = abi.encodePacked(
                "0xverse",
                vm.toString(i + 1)
            );

            // now test a confirmation by Alice
            vm.startPrank(alice);
            vm.expectEmit(true, true, true, true);
            emit BookManager.Confirmation(alice, _verseBytesId);
            _manager.confirmVerse(indexOne, _verseBytesId, loggedVerseId);
            vm.stopPrank();

            // now test a second confirmation by Bob
            vm.startPrank(bob);
            vm.expectEmit(true, true, true, true);
            emit BookManager.Confirmation(bob, _verseBytesId);
            _manager.confirmVerse(indexOne, _verseBytesId, loggedVerseId);
            vm.stopPrank();
        }
    }

    function testFinalizeBook() public virtual {
        vm.expectEmit(true, true, true, true);
        emit BookManager.Book(indexOne, titleOne);
        _manager.addBook(indexOne, titleOne);

        bytes memory _bookId = abi.encodePacked("0x1234567890abcdef"); //only for subgraph

        vm.expectEmit(true, true, true, true);
        emit BookManager.Finalization(address(this), _bookId);
        _manager.finalizeBook(indexOne, _bookId);
    }

    function testOnlyOwnerCanFinalizeBook() public virtual {
        vm.expectEmit(true, true, true, true);
        emit BookManager.Book(indexOne, titleOne);
        _manager.addBook(indexOne, titleOne);

        bytes memory _bookId = abi.encodePacked("0x1234567890abcdef"); //only for subgraph

        assertEq(_manager.owner(), owner);
        _manager.transferOwnership(alice);
        assertEq(_manager.owner(), alice);

        // make sure old owner can't finalize book
        vm.expectRevert();
        _manager.finalizeBook(indexOne, _bookId);

        // make sure new owner can finalize book
        vm.startPrank(alice);
        vm.expectEmit(true, true, true, true);
        emit BookManager.Finalization(alice, _bookId);
        _manager.finalizeBook(indexOne, _bookId);
        vm.stopPrank();
    }

    function test_RevertWhen_storeVerseAfterFinalization() public virtual {
        _manager.addBook(indexOne, titleOne);

        bytes memory _bookId = abi.encodePacked("0x1234567890abcdef"); //only for subgraph

        _manager.finalizeBook(indexOne, _bookId);

        // now try to add verses to this finalized book (should fail)

        (
            uint256[] memory _verseNumbers,
            uint256[] memory _chapterNumbers,
            string[] memory _verseContent
        ) = _makeVerses(1);

        vm.expectRevert("This book has already been finalized.");
        _manager.addBatchVerses(
            indexOne,
            _bookId,
            _verseNumbers,
            _chapterNumbers,
            _verseContent
        );
    }

    function test_RevertsWhen_samePersonConfirmsVerseTwice() public virtual {
        _manager.addBook(indexOne, titleOne);

        bytes memory _bookId = abi.encodePacked("0x1234567890abcdef"); //only for subgraph

        (
            uint256[] memory _verseNumbers,
            uint256[] memory _chapterNumbers,
            string[] memory _verseContent
        ) = _makeVerses(1);

        vm.recordLogs();
        _manager.addBatchVerses(
            indexOne,
            _bookId,
            _verseNumbers,
            _chapterNumbers,
            _verseContent
        );
        Vm.Log[] memory recordedLogs = vm.getRecordedLogs();

        for (uint256 i = 0; i < recordedLogs.length; i++) {
            // The .data field contains the ABI-encoded values of the event's non-indexed arguments, packed together in the order they appear in the event definition
            (
                uint256 loggedBookIndex,
                bytes memory loggedBookId,
                uint256 loggedVerseId,
                uint256 loggedVerseNumber,
                uint256 loggedChapterNumber,
                string memory loggedVerseContent
            ) = abi.decode(
                    recordedLogs[i].data,
                    (uint256, bytes, uint256, uint256, uint256, string)
                );

            // this verse ID bytes array is just for the subgraph
            bytes memory _verseBytesId = abi.encodePacked(
                "0xverse",
                vm.toString(i + 1)
            );

            // now test a confirmation
            vm.startPrank(alice);
            vm.expectEmit(true, true, true, true);
            emit BookManager.Confirmation(alice, _verseBytesId);
            _manager.confirmVerse(indexOne, _verseBytesId, loggedVerseId);

            vm.expectRevert("This address has already confirmed this verse.");
            _manager.confirmVerse(indexOne, _verseBytesId, loggedVerseId);
            vm.stopPrank();
        }
    }

    // VERSE/CHAPTER ORDER ENFORCEMENT

    // The contract's functionality is expecting all within the batch to be consecutive; however, the prevention occurs based on the last added to the previous batch
    function test_RevertsWhen_skippingVerseNumber() public virtual {
        _manager.addBook(indexOne, titleOne);

        // At the end of the day, _bookId is only for the subgraph
        bytes memory _bookId = abi.encodePacked("0xbookone");

        //store first batch
        uint256[] memory _verseNumbers = new uint256[](5);
        uint256[] memory _chapterNumbers = new uint256[](5);
        string[] memory _verseContent = new string[](5);

        for (uint256 i = 0; i < 5; i++) {
            uint256 ip1 = i + 1;
            _verseNumbers[i] = ip1;
            _chapterNumbers[i] = 1;
            _verseContent[i] = string(
                abi.encodePacked("TEST ", vm.toString(ip1))
            );
        }
        _manager.addBatchVerses(
            indexOne,
            _bookId,
            _verseNumbers,
            _chapterNumbers,
            _verseContent
        );

        //store second batch (which will start with a skipped verse, and revert)
        uint256[] memory _batch2verseNumbers = new uint256[](5);
        uint256[] memory _batch2chapterNumbers = new uint256[](5);
        string[] memory _batch2verseContent = new string[](5);

        for (uint256 i = 0; i < 5; i++) {
            uint256 ip1 = i + 7; //will get the verse number out of whack (skipping a verse)
            _batch2verseNumbers[i] = ip1;
            _batch2chapterNumbers[i] = 1;
            _batch2verseContent[i] = string(
                abi.encodePacked("TEST ", vm.toString(ip1))
            );
        }

        vm.expectRevert(
            "The contract is preventing you from skipping a verse."
        );
        _manager.addBatchVerses(
            indexOne,
            _bookId,
            _batch2verseNumbers,
            _batch2chapterNumbers,
            _batch2verseContent
        );
    }

    function test_RevertsWhen_skippingChapterNumber() public virtual {
        _manager.addBook(indexOne, titleOne);

        // At the end of the day, _bookId is only for the subgraph
        bytes memory _bookId = abi.encodePacked("0xbookone");

        //store first batch
        uint256[] memory _verseNumbers = new uint256[](5);
        uint256[] memory _chapterNumbers = new uint256[](5);
        string[] memory _verseContent = new string[](5);

        for (uint256 i = 0; i < 5; i++) {
            uint256 ip1 = i + 1;
            _verseNumbers[i] = ip1;
            _chapterNumbers[i] = 1;
            _verseContent[i] = string(
                abi.encodePacked("TEST ", vm.toString(ip1))
            );
        }
        _manager.addBatchVerses(
            indexOne,
            _bookId,
            _verseNumbers,
            _chapterNumbers,
            _verseContent
        );

        //store second batch (which will start with a skipped verse, and revert)
        uint256[] memory _batch2verseNumbers = new uint256[](5);
        uint256[] memory _batch2chapterNumbers = new uint256[](5);
        string[] memory _batch2verseContent = new string[](5);

        for (uint256 i = 0; i < 5; i++) {
            uint256 ip1 = i + 1;
            _batch2verseNumbers[i] = ip1;
            _batch2chapterNumbers[i] = 3; //will get the chapter number out of whack (skipping a chapter)
            _batch2verseContent[i] = string(
                abi.encodePacked("TEST ", vm.toString(ip1))
            );
        }

        vm.expectRevert(
            "The contract is preventing you from skipping a chapter."
        );
        _manager.addBatchVerses(
            indexOne,
            _bookId,
            _batch2verseNumbers,
            _batch2chapterNumbers,
            _batch2verseContent
        );
    }

    function test_RevertsWhen_skippingFirstVerseOfBible() public virtual {
        _manager.addBook(indexOne, titleOne);

        // At the end of the day, _bookId is only for the subgraph
        bytes memory _bookId = abi.encodePacked("0xbookone");

        //store first batch
        uint256[] memory _verseNumbers = new uint256[](5);
        uint256[] memory _chapterNumbers = new uint256[](5);
        string[] memory _verseContent = new string[](5);

        for (uint256 i = 0; i < 5; i++) {
            uint256 ip1 = i + 2; // like starting with Genesis 1:2
            _verseNumbers[i] = ip1;
            _chapterNumbers[i] = 1;
            _verseContent[i] = string(
                abi.encodePacked("TEST ", vm.toString(ip1))
            );
        }

        vm.expectRevert(
            "The contract is preventing you from starting with a verse that is not 1:1"
        );
        _manager.addBatchVerses(
            indexOne,
            _bookId,
            _verseNumbers,
            _chapterNumbers,
            _verseContent
        );
    }

    function test_RevertsWhen_skippingFirstChapterOfBible() public virtual {
        _manager.addBook(indexOne, titleOne);

        // At the end of the day, _bookId is only for the subgraph
        bytes memory _bookId = abi.encodePacked("0xbookone");

        //store first batch
        uint256[] memory _verseNumbers = new uint256[](5);
        uint256[] memory _chapterNumbers = new uint256[](5);
        string[] memory _verseContent = new string[](5);

        for (uint256 i = 0; i < 5; i++) {
            uint256 ip1 = i + 1;
            _verseNumbers[i] = ip1;
            _chapterNumbers[i] = 2; // like starting with Genesis 2:1
            _verseContent[i] = string(
                abi.encodePacked("TEST ", vm.toString(ip1))
            );
        }

        vm.expectRevert(
            "The contract is preventing you from starting with a verse that is not 1:1"
        );
        _manager.addBatchVerses(
            indexOne,
            _bookId,
            _verseNumbers,
            _chapterNumbers,
            _verseContent
        );
    }

    function test_RevertsWhen_skippingFirstVerseOfNewChapter() public virtual {
        _manager.addBook(indexOne, titleOne);

        // At the end of the day, _bookId is only for the subgraph
        bytes memory _bookId = abi.encodePacked("0xbookone");

        //store first batch
        uint256[] memory _verseNumbers = new uint256[](5);
        uint256[] memory _chapterNumbers = new uint256[](5);
        string[] memory _verseContent = new string[](5);

        for (uint256 i = 0; i < 5; i++) {
            uint256 ip1 = i + 1;
            _verseNumbers[i] = ip1;
            _chapterNumbers[i] = 1;
            _verseContent[i] = string(
                abi.encodePacked("TEST ", vm.toString(ip1))
            );
        }
        _manager.addBatchVerses(
            indexOne,
            _bookId,
            _verseNumbers,
            _chapterNumbers,
            _verseContent
        );

        //store second batch (which will start with a skipped verse, and revert)
        uint256[] memory _batch2verseNumbers = new uint256[](5);
        uint256[] memory _batch2chapterNumbers = new uint256[](5);
        string[] memory _batch2verseContent = new string[](5);

        for (uint256 i = 0; i < 5; i++) {
            uint256 ip1 = i + 2; // starts a new chapter off on verse 2, which should revert
            _batch2verseNumbers[i] = ip1;
            _batch2chapterNumbers[i] = 2;
            _batch2verseContent[i] = string(
                abi.encodePacked("TEST ", vm.toString(ip1))
            );
        }

        vm.expectRevert(
            "The contract is preventing you from starting a new chapter with a verse that is not 1."
        );
        _manager.addBatchVerses(
            indexOne,
            _bookId,
            _batch2verseNumbers,
            _batch2chapterNumbers,
            _batch2verseContent
        );
    }
    // END: VERSE/CHAPTER ORDER ENFORCEMENT

    // HELPERS
    function _makeVerses(uint256 chapterNumber)
        private
        returns (uint256[] memory, uint256[] memory, string[] memory)
    {
        uint256[] memory _verseNumbers = new uint256[](ARRAY_LEN);
        uint256[] memory _chapterNumbers = new uint256[](ARRAY_LEN);
        string[] memory _verseContent = new string[](ARRAY_LEN);

        for (uint256 i = 0; i < ARRAY_LEN; i++) {
            uint256 ip1 = i + 1;
            _verseNumbers[i] = ip1;
            _chapterNumbers[i] = chapterNumber;
            _verseContent[i] = string(
                abi.encodePacked("TEST ", vm.toString(ip1))
            );
        }

        return (_verseNumbers, _chapterNumbers, _verseContent);
    }
}
