/-! Tic-tac-toe, the domain: vocabulary and rules. Plain Lean, no libraries. -/

namespace TicTacToe

inductive Player where
  | x
  | o
  deriving DecidableEq, Repr

/-- The nine squares of the board. -/
inductive Square where
  | topLeft    | top    | topRight
  | left       | center | right
  | bottomLeft | bottom | bottomRight
  deriving DecidableEq, Repr

structure Move where
  player : Player
  square : Square
  deriving DecidableEq, Repr

inductive Status where
  | xToMove | oToMove       -- still going
  | xWon | oWon | draw      -- over
  deriving DecidableEq, Repr

/-- The marks on the board, in the order they were made. -/
structure Board where
  private mk ::
  moves : List Move

def Board.empty : Board := ⟨[]⟩

/-- Who has marked a square, if anyone. -/
def Board.mark (board : Board) (square : Square) : Option Player :=
  (board.moves.find? (·.square == square)).map (·.player)

/-- The eight ways to win: three rows, three columns, two diagonals. -/
def lines : List (List Square) := [
  [.topLeft, .top, .topRight], [.left, .center, .right], [.bottomLeft, .bottom, .bottomRight],
  [.topLeft, .left, .bottomLeft], [.top, .center, .bottom], [.topRight, .right, .bottomRight],
  [.topLeft, .center, .bottomRight], [.topRight, .center, .bottomLeft]
]

def Board.winner (board : Board) : Option Player :=
  [Player.x, .o].find? fun p => lines.any fun line => line.all (board.mark · == some p)

def Board.status (board : Board) : Status :=
  match board.winner with
  | some .x => .xWon
  | some .o => .oWon
  | none =>
    if board.moves.length = 9 then .draw
    else if board.moves.length % 2 = 0 then .xToMove
    else .oToMove

/-- The status in which it's this player's move. -/
def Player.toMove : Player → Status
  | .x => .xToMove
  | .o => .oToMove

/-- A move is valid when it's the mover's turn (so the game isn't over) and the square is empty. -/
abbrev Board.ValidMove (board : Board) (move : Move) : Prop :=
  board.status = move.player.toMove ∧ board.mark move.square = none

/-- The only way to put a mark on a board. -/
def Board.play (board : Board) (move : Move) (_ : board.ValidMove move) : Board :=
  ⟨board.moves ++ [move]⟩

/-- Rebuild a board from a list of moves, checking every one of them. -/
def Board.replay (moves : List Move) : Option Board :=
  moves.foldlM (init := Board.empty) fun board move =>
    if h : board.ValidMove move then some (board.play move h) else none

end TicTacToe
