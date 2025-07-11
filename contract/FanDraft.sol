// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract FanDraftGame {
    address public owner;
    uint256 public draftCounter;
    uint256 public entryFee; // In wei
    uint256 public platformRevenue;

    struct DraftEntry {
        address player;
        uint256[] playerIds;
        uint256 score;
        bool claimedReward;
    }

    struct Draft {
        uint256 id;
        bool isActive;
        address[] participants;
        mapping(address => DraftEntry) entries;
        address winner; // Top 3
        uint256 totalPool;
        uint256 deadline;
    }

    struct PlayerStats {
        uint256 totalGamesPlayed;
        uint256 totalWins;
        uint256 totalWinnings;
    }

    mapping(address => PlayerStats) public playerStats;

    string[] public draftNames;

    mapping(uint256 => Draft) public drafts;
    mapping(address => uint256) public totalWins;


    modifier onlyOwner() {
        require(msg.sender == owner, "Only admin can perform this action");
        _;
    }

    constructor(uint256 _entryFee) {
        owner = msg.sender;
        entryFee = _entryFee;
    }

    function createDraft(string memory draftName, uint256 durationSeconds) external onlyOwner {
        draftCounter++;
        Draft storage d = drafts[draftCounter];
        d.id = draftCounter;
        d.isActive = true;
        d.deadline = block.timestamp + durationSeconds;

        draftNames.push(draftName);
    }

    function getDraft(
        uint256 draftId
    ) external view returns (
        uint256 id,
        // string memory name,
        bool isActive,
        uint256 totalPool,
        uint256 deadline
    ) {
        uint256 _id = drafts[draftId].id;
        // string memory _name = drafts[draftId].name;
        bool _isActive = drafts[draftId].isActive;
        uint256 _totalPool = drafts[draftId].totalPool;
        uint256 _deadline = drafts[draftId].deadline;

        return (_id, _isActive, _totalPool, _deadline);
    }

    function getDraftName(uint256 draftId) public view returns (string memory) {
        require(draftId > 0 && draftId <= draftNames.length, "Invalid draft ID");
        return draftNames[draftId - 1]; // ✅ Adjust for 0-based index
    }

    function getAllDraftNames() public view returns (string[] memory) {
        return draftNames;
    }


    function joinDraft(uint256 draftId, uint256[] memory selectedPlayers) external payable {
        Draft storage d = drafts[draftId];
        require(d.isActive, "Draft not active");
        require(block.timestamp <= d.deadline, "Draft deadline passed");
        require(msg.value == entryFee, "Incorrect entry fee");
        require(selectedPlayers.length == 11, "Must select 11 players");
        require(d.entries[msg.sender].player == address(0), "Already joined");

        d.entries[msg.sender] = DraftEntry({
            player: msg.sender,
            playerIds: selectedPlayers,
            score: 0,
            claimedReward: false
        });

        d.participants.push(msg.sender);
        d.totalPool += msg.value;
        playerStats[msg.sender].totalGamesPlayed += 1;
    }

    function resolveDraft(uint256 draftId, address winner, uint256 score) external onlyOwner {
        Draft storage d = drafts[draftId];
        require(d.isActive, "Draft already resolved");
        require(block.timestamp > d.deadline, "Draft still ongoing");
        require(winner != address(0), "Winner address required");

        d.isActive = false;
        d.winner = winner;

        uint256 pool = d.totalPool;
        uint256 reward = (pool * 90) / 100;
        uint256 fee = pool - reward;

        platformRevenue += fee;

        // Send reward to winner
        (bool sent, ) = winner.call{value: reward}("");
        require(sent, "Reward transfer failed");

        // Update stats
        d.entries[winner].score = score;
        totalWins[winner]++;
        playerStats[winner].totalWins += 1;
        playerStats[winner].totalWinnings += reward;

        emit DraftResolved(draftId, d.winner, score);
    }

    function getLeaderboard(address player) public view returns (
        uint256 totalGames,
        uint256 wins,
        uint256 totalWinnings,
        uint256 winRate
    ) {
        PlayerStats memory stats = playerStats[player];
        uint256 rate = stats.totalGamesPlayed > 0
            ? (stats.totalWins * 100) / stats.totalGamesPlayed
            : 0;

        return (
            stats.totalGamesPlayed,
            stats.totalWins,
            stats.totalWinnings,
            rate
        );
    }




    function getParticipants(uint256 draftId) public view returns (address[] memory) {
        return drafts[draftId].participants;
    }

    function getPlayerSelection(uint256 draftId, address user) public view returns (uint256[] memory) {
        return drafts[draftId].entries[user].playerIds;
    }

    function getDraftWinner(uint256 draftId) public view returns (address) {
        return drafts[draftId].winner;
    }

    function withdrawRevenue() external onlyOwner {
        require(platformRevenue > 0, "No revenue to withdraw");

        uint256 amount = platformRevenue;
        platformRevenue = 0;

        (bool sent, ) = owner.call{value: amount}("");
        require(sent, "Withdraw failed");
    }

    function changeEntryFee(uint256 newFee) external onlyOwner {
        entryFee = newFee;
    }

    event DraftResolved(uint256 indexed draftId, address winner, uint256 score);

    receive() external payable {}
    fallback() external payable {}
}
