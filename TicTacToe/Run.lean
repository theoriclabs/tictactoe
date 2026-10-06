/- Verification harness (not part of the post): runs the server's operations on LeanAPI's
   in-memory backend and checks every rejection the post describes. -/
import TicTacToe.Server
import LeanDb.Model
import LeanApi.Core
open LeanDb.Model LeanApi.Core TicTacToe

deriving instance BEq, Repr for MoveError, GetGameError

private def check (label : String) (condition : Bool) : IO Unit := do
  unless condition do throw (IO.userError ("FAIL: " ++ label))
  IO.println s!"ok: {label}"
private def ok [Repr E] (value : Except E A) : IO A :=
  match value with | .ok value => pure value | .error error => throw (IO.userError (reprStr error))
private def run (op : Op ε α) (store : LeanApi.Memory.Store) : IO (Except ε α × LeanApi.Memory.Store) :=
  ok (LeanApi.Memory.command (op : Flow .command OpScope ε α) store)
private def read (op : ReadOp ε α) (store : LeanApi.Memory.Store) : IO (Except ε α) := do
  let (result, _) ← ok (LeanApi.Memory.read (op : Flow .query OpScope ε α) store)
  return result
private def same [BEq ε] [BEq α] : Except ε α → Except ε α → Bool
  | .ok a, .ok b => a == b
  | .error a, .error b => a == b
  | _, _ => false

def main : IO Unit := do
  let start ← match Ontology.Instant.ofEpochSeconds 1000 with
    | .ok t => pure t | .error _ => throw (IO.userError "time")
  let store : LeanApi.Memory.Store := { now := start }
  let (game, store) ← (fun (r, s) => do pure (← ok r, s)) (← run newGame store)
  let (r, store) ← run (move game .x .center) store
  check "x takes the center, o to move" (same r (Except.ok Status.oToMove))
  let (r, store) ← run (move game .o .center) store
  check "o on the same square: squareTaken" (same r (Except.error MoveError.squareTaken))
  let (r, store) ← run (move game .x .topLeft) store
  check "x again: notYourTurn" (same r (Except.error MoveError.notYourTurn))
  match ← read (getGame game) store with
  | .ok v => check "rejected moves wrote nothing" (v.board.moves.length == 1)
  | .error _ => throw (IO.userError "getGame failed")
  let (r, store) ← run (move game .o .topLeft) store
  check "o top left" (same r (Except.ok Status.xToMove))
  let (_, store) ← run (move game .x .top) store
  let (_, store) ← run (move game .o .left) store
  let (r, store) ← run (move game .x .bottom) store
  check "x wins down the middle column" (same r (Except.ok Status.xWon))
  let (r, store) ← run (move game .o .right) store
  check "after the win: gameOver" (same r (Except.error MoveError.gameOver))
  let view ← read (getGame game) store
  match view with
  | .ok v =>
    check "view: status xWon" (v.status == Status.xWon)
    check "view: the five moves, in order" (v.board.moves.map (·.square) ==
      [Square.center, .topLeft, .top, .left, .bottom])
  | .error _ => throw (IO.userError "getGame failed")
  let unknown ← match Ref.parse (T := Game) "999" with
    | .ok r => pure r | .error _ => throw (IO.userError "ref")
  match ← read (getGame unknown) store with
  | .error .noSuchGame => check "unknown game: noSuchGame" true
  | .ok _ => check "unknown game: noSuchGame" false
