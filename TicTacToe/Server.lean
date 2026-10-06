import LeanDb.Model
import LeanApi.Core
import TicTacToe.Rules
open LeanDb.Model LeanApi.Core TicTacToe

/-! The API server: storage and endpoints for the rules in `TicTacToe.Rules`. -/

deriving instance Domain for Player, Square, Move, Status

/-- A board is stored and sent as its moves, and read back by replaying them. -/
represent Board as List Move by (·.moves) checked Board.replay

structure Game where
  board : Board
  deriving Entity

def newGame : Op Empty (Ref Game) :=
  Game.insert { board := .empty }

inductive MoveError where
  | noSuchGame
  | gameOver
  | notYourTurn
  | squareTaken

/-- Which part of the rule a move breaks. It only picks the error; `require` does the checking. -/
def MoveError.of (board : Board) (move : Move) : MoveError :=
  if board.status ∈ [.xWon, .oWon, .draw] then .gameOver
  else if board.status ≠ move.player.toMove then .notYourTurn
  else .squareTaken

def move (game : Ref Game) (player : Player) (square : Square) : Op MoveError Status := do
  let some g ← Game.find game | throw .noSuchGame
  let m : Move := ⟨player, square⟩
  let ⟨valid⟩ ← require (g.board.ValidMove m) (MoveError.of g.board m)
  let board := g.board.play m valid
  Game.update g { board }
  return board.status

structure GameView where
  board  : Board
  status : Status

inductive GetGameError where
  | noSuchGame

def getGame (game : Ref Game) : ReadOp GetGameError GameView := do
  let some g ← Game.find game | throw .noSuchGame
  return { board := g.board, status := g.board.status }

def api : Api := [
  post "/games"              newGame,
  post "/games/:game/moves"  move,
  get  "/games/:game"        getGame
]
