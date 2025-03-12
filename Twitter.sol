// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

contract TweetContract {
    uint internal tweetId = 0;
    uint internal messageId = 0;
    uint internal commentId = 0;

    struct Tweet {
        uint ID;
        address author;
        string content;
        uint createTimestamp;
        uint likeCount;
        uint commentCount;
    }

    struct Message {
        uint ID;
        string content;
        address sender;
        address receiver;
        uint createTimestamp;
    }

    struct Comment {
        uint ID;
        uint tweetId;
        address author;
        string content;
        uint createTimestamp;
    }

    mapping(uint => Tweet) public tweets;
    mapping(address => uint[]) public tweetsOf;
    mapping(address => Message[]) public conversations;
    mapping(address => mapping(address => bool)) public operators;
    mapping(address => address[]) public following;
    mapping(uint => Comment[]) public tweetComments;        // New: Comments per tweet
    mapping(uint => mapping(address => bool)) public likes; // New: Likes per tweet per user
    mapping(uint => uint[]) public tweetCommentIds;         // New: Comment IDs per tweet

    event TweetCreated(uint id, address indexed author, string content, uint timestamp);
    event MessageSent(uint id, address indexed sender, address indexed receiver, string content, uint timestamp);
    event Follow(address indexed follower, address indexed followed);
    event OperatorAllowed(address indexed user, address indexed operator);
    event OperatorDisallowed(address indexed user, address indexed operator);
    event TweetLiked(uint indexed tweetId, address indexed liker);          // New
    event CommentCreated(uint id, uint indexed tweetId, address indexed author, string content, uint timestamp); // New

    modifier operatorAccess(address _user, address _operator) {
        require(operators[_user][_operator] || _user == _operator, "You are not an operator of the user's account");
        _;
    }

    function _tweet(address _from, string memory _content) internal {
        require(bytes(_content).length > 0, "Tweet content cannot be empty");
        
        Tweet memory newTweet = Tweet({
            ID: tweetId,
            author: _from,
            content: _content,
            createTimestamp: block.timestamp,
            likeCount: 0,
            commentCount: 0
        });

        tweets[tweetId] = newTweet;
        tweetsOf[_from].push(tweetId);
        tweetId++;

        emit TweetCreated(tweetId - 1, _from, _content, block.timestamp);
    }

    function _sendMessage(address _from, address _to, string memory _content) internal {
        require(_from != _to, "Cannot send message to self");
        require(bytes(_content).length > 0, "Message content cannot be empty");

        Message memory newMessage = Message({
            ID: messageId,
            content: _content,
            sender: _from,
            receiver: _to,
            createTimestamp: block.timestamp
        });

        conversations[_from].push(newMessage);
        conversations[_to].push(newMessage);
        messageId++;

        emit MessageSent(messageId - 1, _from, _to, _content, block.timestamp);
    }

    // New: Like a tweet
    function likeTweet(uint _tweetId) public {
        require(_tweetId < tweetId, "Tweet does not exist");
        require(!likes[_tweetId][msg.sender], "Already liked this tweet");
        
        likes[_tweetId][msg.sender] = true;
        tweets[_tweetId].likeCount++;
        
        emit TweetLiked(_tweetId, msg.sender);
    }

    // New: Comment on a tweet
    function commentOnTweet(uint _tweetId, string memory _content) public {
        require(_tweetId < tweetId, "Tweet does not exist");
        require(bytes(_content).length > 0, "Comment cannot be empty");

        Comment memory newComment = Comment({
            ID: commentId,
            tweetId: _tweetId,
            author: msg.sender,
            content: _content,
            createTimestamp: block.timestamp
        });

        tweetComments[_tweetId].push(newComment);
        tweetCommentIds[_tweetId].push(commentId);
        tweets[_tweetId].commentCount++;
        commentId++;

        emit CommentCreated(commentId - 1, _tweetId, msg.sender, _content, block.timestamp);
    }

    function tweet(string memory _content) public {
        _tweet(msg.sender, _content);
    }

    function tweet(address _from, string memory _content) public operatorAccess(_from, msg.sender) {
        _tweet(_from, _content);
    }

    function sendMessage(string memory _content, address _to) public {
        _sendMessage(msg.sender, _to, _content);
    }

    function sendMessage(address _from, address _to, string memory _content) 
        public 
        operatorAccess(_from, msg.sender) 
    {
        _sendMessage(_from, _to, _content);
    }

    function follow(address _followed) public {
        require(msg.sender != _followed, "Cannot follow yourself");
        require(!_isFollowing(msg.sender, _followed), "You are already following");
        following[msg.sender].push(_followed);
        emit Follow(msg.sender, _followed);
    }

    function _isFollowing(address _follower, address _followed) internal view returns (bool) {
        address[] storage followed = following[_follower];
        for (uint i = 0; i < followed.length; i++) {
            if (followed[i] == _followed) {
                return true;
            }
        }
        return false;
    }

    function allow(address _operator) public {
        require(msg.sender != _operator, "Cannot allow yourself as operator");
        require(!operators[msg.sender][_operator], "Already an operator");
        operators[msg.sender][_operator] = true;
        emit OperatorAllowed(msg.sender, _operator);
    }

    function disallow(address _operator) public {
        require(operators[msg.sender][_operator], "Not an operator");
        operators[msg.sender][_operator] = false;
        emit OperatorDisallowed(msg.sender, _operator);
    }

    function getLatestTweets(uint count) public view returns (Tweet[] memory) {
        require(count > 0, "Count must be greater than 0");
        require(count <= tweetId, "Not enough tweets");

        Tweet[] memory latestTweets = new Tweet[](count);
        for (uint i = 0; i < count; i++) {
            latestTweets[i] = tweets[tweetId - count + i];
        }
        return latestTweets;
    }

    function getLatestTweetsOf(address user, uint count) public view returns (Tweet[] memory) {
        uint userTweetsLength = tweetsOf[user].length;
        require(count > 0, "Count must be greater than 0");
        require(count <= userTweetsLength, "Not enough tweets");

        Tweet[] memory userLatestTweets = new Tweet[](count);
        for (uint i = 0; i < count; i++) {
            uint tweetIndex = tweetsOf[user][userTweetsLength - count + i];
            userLatestTweets[i] = tweets[tweetIndex];
        }
        return userLatestTweets;
    }

    // New: Get comments for a tweet
    function getTweetComments(uint _tweetId, uint count) public view returns (Comment[] memory) {
        require(_tweetId < tweetId, "Tweet does not exist");
        uint commentCount = tweetComments[_tweetId].length;
        require(count > 0, "Count must be greater than 0");
        require(count <= commentCount, "Not enough comments");

        Comment[] memory comments = new Comment[](count);
        for (uint i = 0; i < count; i++) {
            comments[i] = tweetComments[_tweetId][commentCount - count + i];
        }
        return comments;
    }
}