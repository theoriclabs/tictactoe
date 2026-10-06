import Lake
open Lake DSL

/-! The tic-tac-toe server needs LeanAPI (operations, endpoints, the HTTP server), which brings
LeanDB (the data model and SQLite) and LeanOntology. No LeanReact: it has no pages. -/

package tictactoe

require leanapi from git "https://github.com/theoriclabs/leanapi" @ "b66c2991fae8fbe55b5c77d14b0216016855c6c0"

lean_lib TicTacToe where
  roots := #[`TicTacToe.Rules, `TicTacToe.Server]

@[default_target]
lean_exe tictactoe where
  root := `Main
