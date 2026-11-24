import Lake
open Lake DSL

/-! The tic-tac-toe server needs LeanAPI (operations, endpoints, the HTTP server), which brings
LeanDB (the data model and SQLite) and LeanOntology. No LeanReact: it has no pages. -/

package tictactoe where
  version := v!"0.1.0"

require leanapi from git "https://github.com/theoriclabs/leanapi" @ "v0.6.0"

lean_lib TicTacToe where
  roots := #[`TicTacToe.Rules, `TicTacToe.Server]

@[default_target]
lean_exe tictactoe where
  root := `Main
