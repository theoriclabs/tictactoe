import TicTacToe.Rules
open TicTacToe

def opening : Board :=
  Board.empty
    |>.play ⟨.x, .center⟩ (by decide)
    |>.play ⟨.o, .topLeft⟩ (by decide)

#eval opening.status

def sameSquare : Board :=
  Board.empty
    |>.play ⟨.x, .center⟩ (by decide)
    |>.play ⟨.o, .center⟩ (by decide)

def twice : Board :=
  Board.empty
    |>.play ⟨.x, .center⟩ (by decide)
    |>.play ⟨.x, .topLeft⟩ (by decide)

def forged : Board := ⟨[⟨.x, .center⟩, ⟨.o, .center⟩]⟩
