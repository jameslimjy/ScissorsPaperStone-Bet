pragma solidity ^0.5.4;

contract ScissorsPaperStone {
    mapping(uint => uint) winningCombination;
    constructor () public payable {
        // 1. Scissors
        // 2. Paper
        // 3. Stone
        winningCombination[1] = 2;
        winningCombination[2] = 3;
        winningCombination[3] = 1;
    }
    
    enum State {
        CREATED,
        WAIT_FOR_PARTICIPANT,
        JOINED,
        FIRST_PLAYER_COMMITTED,
        READY_FOR_REVEAL,
        FIRST_PLAYER_REVEALED,
        END
    }

    struct Game {
        uint gameId;
        uint bet;
        address payable[2] players;
        State state;
    }

    struct Move {
        bytes32 hash;
        uint value;
    }

    mapping(uint => Game) public games;
    uint public nextGameId;
    mapping(uint => mapping(address => Move)) moves;

    function createGame(address payable opponent) payable external {
        require(msg.value > 0, "need to include a wager");
        require(msg.sender != opponent, "cannot play against yourself");
        address payable[2] memory players = [msg.sender, opponent];
        games[nextGameId] = Game(nextGameId, msg.value, players, State.WAIT_FOR_PARTICIPANT);
        nextGameId++;
    }

    function joinGame(uint gameId) payable external {
        Game storage game = games[gameId];
        require(msg.sender == game.players[1], "only the specified opponent can join this game");
        require(game.state == State.WAIT_FOR_PARTICIPANT, "game is already underway");
        require(msg.value == game.bet, "need to match the bet amount for this game");
        game.state = State.JOINED;
    }

    function commitMove(uint gameId, uint value, uint salt) external isPlayer(gameId) {
        Game storage game = games[gameId];
        if(msg.sender == game.players[0]) {
            require(game.state == State.JOINED || game.state == State.FIRST_PLAYER_COMMITTED, "must wait until second player has joined");
        } 
        require(moves[gameId][msg.sender].hash == 0, "you have already made your move");
        moves[gameId][msg.sender] = Move(keccak256(abi.encodePacked(value, salt)), 0);

        if(game.state == State.FIRST_PLAYER_COMMITTED) {
            game.state = State.READY_FOR_REVEAL;
        }

        if(game.state == State.JOINED) {
            game.state = State.FIRST_PLAYER_COMMITTED;
        }
        
    }

    function reveal(uint gameId, uint value, uint salt) external isPlayer(gameId) {
        Game storage game = games[gameId];
        require(game.state == State.READY_FOR_REVEAL || game.state == State.FIRST_PLAYER_REVEALED, "either 1 or both players have yet to commit their moves");
        Move storage move = moves[gameId][msg.sender];
        require(move.value == 0, "you have already revealed your move");
        bytes32 checkHash = keccak256(abi.encodePacked(value, salt));
        require(move.hash == checkHash, "the move + salt inputs given does not match what was stored, dont cheat!");
        move.value = value;

        if(game.state == State.READY_FOR_REVEAL) {
            game.state = State.FIRST_PLAYER_REVEALED;
            return;
        }
        
        address payable opponentAddress = msg.sender == game.players[0] ? game.players[1] : game.players[0];
        Move storage opponentMove = moves[gameId][opponentAddress];
        if(game.state == State.FIRST_PLAYER_REVEALED) {
            // win
            if(winningCombination[move.value] == opponentMove.value) {
                msg.sender.transfer(2 * game.bet);
            }
            // draw
            if(move.value == opponentMove.value) {
                msg.sender.transfer(game.bet);
                opponentAddress.transfer(game.bet);
            }
            // lose
            if(winningCombination[opponentMove.value] == move.value) {
                opponentAddress.transfer(2 * game.bet);
            }
            
            game.state = State.END;
        }
    }

    modifier isPlayer(uint gameId) {
        Game memory game = games[gameId];
        require(msg.sender == game.players[0] || msg.sender == game.players[1], "you are not involved in this game");
        _;
    }

}