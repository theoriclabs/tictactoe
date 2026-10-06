import TicTacToe.Server
import LeanApi.Native

/-! Serve the tic-tac-toe API: `lake exe tictactoe` listens on port 8080 and keeps its games in
`tictactoe.sqlite`. -/

app% server where
  api := api

def main (args : List String) : IO UInt32 :=
  server.main args { database := "tictactoe.sqlite" }
