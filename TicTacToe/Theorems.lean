import TicTacToe.Rules

/-! What the rules guarantee, for every game: a board the server builds, or reads back from the database
and replays, never has a square marked twice, never has more than nine moves, alternates X and O starting
with X, and takes no move once it is over. -/

namespace TicTacToe

theorem Board.play_moves (b : Board) (m : Move) (h : b.ValidMove m) : (b.play m h).moves = b.moves ++ [m] := rfl

theorem Board.mark_eq_none (b : Board) (s : Square) : b.mark s = none ↔ s ∉ b.moves.map (·.square) := by
  simp [Board.mark, List.find?_eq_none]

/-- A game that is over takes no more moves. -/
theorem Board.not_valid_of_over (b : Board) (m : Move)
    (h : b.status = .xWon ∨ b.status = .oWon ∨ b.status = .draw) : ¬ b.ValidMove m := by
  obtain ⟨p, s⟩ := m
  rintro ⟨hs, _⟩
  cases p <;> simp_all [Player.toMove]

/-- Whose move it is follows from how many moves there have been: X after an even number, O after an odd one. -/
theorem Board.turn_of_status (b : Board) (p : Player) (h : b.status = p.toMove) :
    b.moves.length ≠ 9 ∧ (p = .x ↔ b.moves.length % 2 = 0) := by
  unfold Board.status at h
  split at h
  · cases p <;> simp [Player.toMove] at h
  · cases p <;> simp [Player.toMove] at h
  · split at h
    · cases p <;> simp [Player.toMove] at h
    · split at h <;> cases p <;> simp_all [Player.toMove]

/-- What every board reached by legal moves satisfies. -/
structure Board.Sound (b : Board) : Prop where
  distinct : (b.moves.map (·.square)).Nodup
  atMostNine : b.moves.length ≤ 9
  alternate : ∀ (i : Nat) (h : i < b.moves.length), b.moves[i].player = if i % 2 = 0 then .x else .o

theorem Board.sound_empty : Board.empty.Sound :=
  ⟨by simp [Board.empty], by simp [Board.empty], by simp [Board.empty]⟩

theorem Board.sound_play (b : Board) (m : Move) (h : b.ValidMove m) (hb : b.Sound) : (b.play m h).Sound := by
  obtain ⟨hs, hm⟩ := h
  have ⟨h9, hturn⟩ := Board.turn_of_status b m.player hs
  have hfree := (Board.mark_eq_none b m.square).mp hm
  refine ⟨?_, ?_, ?_⟩
  · simp only [Board.play_moves, List.map_append, List.map_cons, List.map_nil]
    exact List.nodup_append.mpr ⟨hb.distinct, by simp, fun a ha c hc heq => hfree (by simp at hc; rw [← hc, ← heq]; exact ha)⟩
  · have := hb.atMostNine
    simp only [Board.play_moves, List.length_append, List.length_cons, List.length_nil]
    omega
  · intro i hi
    simp only [Board.play_moves, List.length_append, List.length_cons, List.length_nil] at hi
    simp only [Board.play_moves]
    by_cases hlt : i < b.moves.length
    · rw [List.getElem_append_left hlt]
      exact hb.alternate i hlt
    · have hi' : i = b.moves.length := by omega
      subst hi'
      simp only [List.getElem_append_right (Nat.le_refl _), Nat.sub_self, List.getElem_cons_zero]
      cases hp : m.player <;> simp_all

/-- Replaying from a sound board gives a sound board whose moves are exactly the old ones followed by the new. -/
theorem Board.sound_replayFrom (ms : List Move) :
    ∀ (b b' : Board), b.Sound →
      ms.foldlM (init := b) (fun board move => if h : board.ValidMove move then some (board.play move h) else none) = some b' →
      b'.Sound ∧ b'.moves = b.moves ++ ms := by
  induction ms with
  | nil => intro b b' hb h; simp at h; subst h; exact ⟨hb, by simp⟩
  | cons m ms ih =>
    intro b b' hb h
    simp only [List.foldlM_cons] at h
    split at h
    · rename_i hv
      have := ih (b.play m hv) b' (Board.sound_play b m hv hb) (by simpa using h)
      exact ⟨this.1, by rw [this.2, Board.play_moves]; simp⟩
    · simp at h

/-- Every board `replay` accepts (so every game read back from the database) is sound, and holds exactly
the moves it was given. -/
theorem Board.replay_sound (ms : List Move) (b : Board) (h : Board.replay ms = some b) : b.Sound ∧ b.moves = ms := by
  have := Board.sound_replayFrom ms Board.empty b Board.sound_empty h
  exact ⟨this.1, by simpa [Board.empty] using this.2⟩

/-- So no game has more than nine moves, or a square marked twice. -/
theorem Board.replay_atMostNine (ms : List Move) (b : Board) (h : Board.replay ms = some b) : ms.length ≤ 9 := by
  have ⟨hs, hm⟩ := Board.replay_sound ms b h
  exact hm ▸ hs.atMostNine

/-- Whoever `winner` names really has three in a row: a whole line of the eight is marked by them. -/
theorem Board.winner_has_line (b : Board) (p : Player) (h : b.winner = some p) :
    ∃ line ∈ lines, ∀ s ∈ line, b.mark s = some p := by
  unfold Board.winner at h
  have hp := List.find?_some h
  simp only [List.any_eq_true, List.all_eq_true, beq_iff_eq] at hp
  exact hp

/-- The eight winning lines are three distinct squares each, and no two are the same. -/
theorem lines_ok : lines.length = 8 ∧ lines.Nodup ∧ lines.all (fun l => l.length = 3 && l.Nodup) := by decide

end TicTacToe
