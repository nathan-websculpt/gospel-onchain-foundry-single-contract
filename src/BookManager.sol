//SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;

import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title BookManager
 * @author Nathan - 0x1e7aAbB9D0C701208E875131d0A1cFcDAba79350
 * @notice BookManager can represent a book of the Bible (KJV).
 * @dev This contract's deployer address is stored on variable: deployerAddress
 * BookManager will store/confirm (verse-by-verse) Bible verses (KJV) onto the blockchain.
 *
 */

// TODO: a getBooks function?

contract BookManager is Ownable {
    bool hasBeenFinalized;

    struct BookStr {
        uint256 bookIndex;
        bytes bookBytesId; // for subgraph
        mapping(uint256 => VerseStr) verses; // DONE: but maybe this should be bumped out of struct? // compiler err: "Storage arrays with nested mappings do not support .push(<arg>)."
        mapping(address => uint256[]) confirmations; //maybe these don't need to be in this struct?
        uint256 numberOfChapters;
        uint256 numberOfVerses;
        address deployerAddress;
        string bookTitle;
        bool hasBeenFinalized;
    }

    BookStr[] public books;

    struct VerseStr {
        uint256 bookIndex;
        uint256 verseId;
        uint256 verseNumber;
        uint256 chapterNumber;
        string verseContent;
    }

    string public constant BIBLE_VERSION = "KJV";
    string public constant BIBLE_VERSION_LONG = "King James Version";
    string public constant CODE_VERSION = "0.0.2";

    event Book(uint256 indexed index, string title);

    event Verse(
        address indexed signer,
        uint256 bookIndex,
        bytes bookId,
        uint256 verseId,
        uint256 verseNumber,
        uint256 chapterNumber,
        string verseContent
    );

    event Confirmation(address indexed confirmedBy, bytes verseId);

    event Finalization(address indexed finalizedBy, bytes bookId);

    modifier notFinalized(uint256 bookIndex) {
        BookStr storage thisBook = books[bookIndex - 1];
        require(!thisBook.hasBeenFinalized, "This book has already been finalized.");
        _;
    }

    // First change to this contract:
    // OpenZeppelin's Ownable contract introduced a constructor that requires an argument (specifically, an initial owner address) starting with version 5.0.0. Prior to this version, the constructor did not require any arguments and would automatically set the deployer as the initial owner
    // Starting in v5.0.0, the constructor signature changed to
    // constructor(address initialOwner)

    // CHANGE::
    // constructor(uint256 index, string memory title, address contractOwner) {
    constructor() Ownable(msg.sender) {}

    // Dat New-New
    function addBook(uint256 _index, string memory _title) external onlyOwner {
        // TODO: check index/order?
        books.push(); // push an empty item to overcome compiler err: "Storage arrays with nested mappings do not support .push(<arg>)."
        uint256 thisIndex = books.length - 1; // a: magic numbies, BAD

        books[thisIndex].bookIndex = _index;
        books[thisIndex].bookTitle = _title;
        emit Book(_index, _title);
    }
    // END:Dat New-New

    /// @dev _bookId is the (bytes) id in the subgraph; function will check validity of starting verse/chapter numbers
    /// @notice Add a batch of verses to the book
    function addBatchVerses(
        uint256 _bookIndex,
        bytes memory _bookId,
        uint256[] memory _verseNumber,
        uint256[] memory _chapterNumber,
        string[] memory _verseContent
    ) external notFinalized(_bookIndex) onlyOwner {
        BookStr storage thisBook = books[_bookIndex - 1];

        uint256 length = _verseNumber.length;
        require(length == _chapterNumber.length, "Invalid array lengths - lengths did not match.");
        require(length == _verseContent.length, "Invalid array lengths - lengths did not match.");
        // make sure a verse has been added before checking for skipped verses/chapters
        if (thisBook.verses[1].verseNumber != 0) {
            require(
                preventSkippingVerse(_bookIndex, _verseNumber[0], _chapterNumber[0]),
                "The contract is preventing you from skipping a verse."
            );
            require(
                preventSkippingChapter(_bookIndex, _chapterNumber[0]),
                "The contract is preventing you from skipping a chapter."
            );
            require(
                enforceFirstVerseOfNewChapter(_bookIndex, _verseNumber[0], _chapterNumber[0]),
                "The contract is preventing you from starting a new chapter with a verse that is not 1."
            );
        } else {
            // this is a first-verse scenario
            require(
                enforceFirstVerse(_bookIndex, _verseNumber[0], _chapterNumber[0]),
                "The contract is preventing you from starting with a verse that is not 1:1"
            );
        }

        for (uint256 i = 0; i < length; i++) {
            _storeVerse(_bookIndex, _bookId, _verseNumber[i], _chapterNumber[i], _verseContent[i]);
        }

        // if last chapter number (being added) is greater than current number of chapters, set the number of chapters
        if (_chapterNumber[length - 1] > thisBook.numberOfChapters) {
            thisBook.numberOfChapters = _chapterNumber[length - 1];
        }
    }

    /// @dev Allows a user to confirm a verse
    /// @notice Once you have compared a verse against the original source, you can confirm it
    function confirmVerse(uint256 _bookIndex, bytes memory _verseId, uint256 _numericalId) external {
        bool canContinue = true;
        BookStr storage thisBook = books[_bookIndex - 1];
        for (uint256 i = 0; i < thisBook.confirmations[msg.sender].length; i++) {
            if (thisBook.confirmations[msg.sender][i] == _numericalId) {
                canContinue = false;
                break;
            }
        }
        require(canContinue, "This address has already confirmed this verse.");

        thisBook.confirmations[msg.sender].push(_numericalId);
        emit Confirmation(msg.sender, _verseId);
    }

    /// Can't add verses after book is finalized
    /// @dev sets hasBeenFinalized to true; only needs the subgraph bookId to update on event
    /// @notice This function can't be un-done - verses can't be added once book is finalized
    function finalizeBook(uint256 _bookIndex, bytes memory _bookId) external onlyOwner {
        BookStr storage thisBook = books[_bookIndex - 1];
        require(thisBook.hasBeenFinalized == false, "This Book has already been finalized.");
        thisBook.hasBeenFinalized = true;
        emit Finalization(msg.sender, _bookId);
    }

    //TODO: add function to finalize whole book

    /// @dev Just for the ability to easily retrieve the last-verse-added on front-end
    /// @notice Use this when uploading verses to easily know what the next verse number should be
    function getLastVerseAdded(uint256 _bookIndex) external view returns (VerseStr memory) {
        BookStr storage thisBook = books[_bookIndex - 1];
        return thisBook.verses[thisBook.numberOfVerses];
    }

    /// @dev Retrieve verse by numerical id
    /// @notice Use this to bypass the subgraph and read the data directly from the blockchain
    function getVerseByNumber(uint256 _bookIndex, uint256 _numericalId) external view returns (VerseStr memory) {
        BookStr storage thisBook = books[_bookIndex - 1];
        return thisBook.verses[_numericalId];
    }

    function _storeVerse(
        uint256 _bookIndex,
        bytes memory _bookId,
        uint256 _verseNumber,
        uint256 _chapterNumber,
        string memory _verseContent
    ) private {
        BookStr storage thisBook = books[_bookIndex - 1];
        thisBook.numberOfVerses++;
        VerseStr storage thisVerse = thisBook.verses[thisBook.numberOfVerses];
        thisVerse.bookIndex = _bookIndex;
        thisVerse.verseId = thisBook.numberOfVerses;
        thisVerse.verseNumber = _verseNumber;
        thisVerse.chapterNumber = _chapterNumber;
        thisVerse.verseContent = _verseContent;

        emit Verse(
            msg.sender, _bookIndex, _bookId, thisBook.numberOfVerses, _verseNumber, _chapterNumber, _verseContent
        );
    }

    // verse-skip prevention
    // to prevent skipping verses
    // prevents the situation of storing 1:1 and then storing 1:3
    function preventSkippingVerse(uint256 _bookIndex, uint256 _verseNumber, uint256 _chapterNumber)
        private
        view
        returns (bool)
    {
        bool canContinue = true;
        BookStr storage thisBook = books[_bookIndex - 1];
        VerseStr storage lastVerseAdded = thisBook.verses[thisBook.numberOfVerses];

        if (lastVerseAdded.chapterNumber == _chapterNumber) {
            if (_verseNumber != lastVerseAdded.verseNumber + 1) {
                canContinue = false;
            }
        }
        return canContinue;
    }

    // to prevent skipping chapters
    // prevents the situation of storing 1:1 and then storing 3:1
    function preventSkippingChapter(uint256 _bookIndex, uint256 _chapterNumber) private view returns (bool) {
        bool canContinue = true;
        BookStr storage thisBook = books[_bookIndex - 1];
        VerseStr storage lastVerseAdded = thisBook.verses[thisBook.numberOfVerses];
        if (_chapterNumber != lastVerseAdded.chapterNumber && _chapterNumber != lastVerseAdded.chapterNumber + 1) {
            canContinue = false;
        }
        return canContinue;
    }

    function enforceFirstVerseOfNewChapter(uint256 _bookIndex, uint256 _verseNumber, uint256 _chapterNumber)
        private
        view
        returns (bool)
    {
        bool canContinue = true;
        BookStr storage thisBook = books[_bookIndex - 1];
        VerseStr storage lastVerseAdded = thisBook.verses[thisBook.numberOfVerses];
        if (_chapterNumber != lastVerseAdded.chapterNumber && _verseNumber != 1) {
            canContinue = false;
        }
        return canContinue;
    }

    //TODO: incorporate the bookIndex into this
    function enforceFirstVerse(uint256 _bookIndex, uint256 _verseNumber, uint256 _chapterNumber)
        private
        pure
        returns (bool)
    {
        bool canContinue = true;
        if (_chapterNumber != 1 || _verseNumber != 1) {
            canContinue = false;
        }
        return canContinue;
    }
}
