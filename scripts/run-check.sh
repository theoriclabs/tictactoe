#!/bin/bash
# Serve tic-tac-toe on a fresh SQLite database and check every claim in the post: a game,
# every rejection, malformed input, races, a restart, the stored board, and hand-corrupted
# rows. It prints each exchange, and exits non-zero if any answer differs from the one the
# post shows. Build first: `lake build tictactoe`. Needs curl, python3 and sqlite3.
set -u
D="$(cd "$(dirname "$0")/.." && pwd)"
RUN=$D/.lake/run; mkdir -p "$RUN"; DB=$RUN/tictactoe.sqlite; LOG=$RUN/server.log
BIN=$D/.lake/build/bin/tictactoe
PORT=$(python3 -c 'import socket;s=socket.socket();s.bind(("127.0.0.1",0));print(s.getsockname()[1])')
rm -f "$DB" "$DB-wal" "$DB-shm"
# Keep a Mac awake while the server runs; elsewhere run it directly.
AWAKE=""; command -v caffeinate > /dev/null && AWAKE="caffeinate -i"
start() { (cd "$RUN" && LEANAPP_DATABASE=$DB LEANAPP_PORT=$PORT exec $AWAKE "$BIN" > "$LOG" 2>&1) & SERVER=$!
  for i in $(seq 1 100); do curl -s -o /dev/null http://127.0.0.1:$PORT/games/1 && return 0; sleep 0.1; done
  echo "server did not start"; cat "$LOG"; return 1; }
stop() { pkill -P $SERVER 2>/dev/null; kill $SERVER 2>/dev/null; wait $SERVER 2>/dev/null; }
trap 'stop' EXIT
U=http://127.0.0.1:$PORT
FAILED=0
# expect WHAT GOT WANT: report an answer that differs from the post's.
expect() { if [ "$2" != "$3" ]; then echo "MISMATCH ($1), expected: $3"; FAILED=$((FAILED + 1)); fi; }
# c METHOD PATH [BODY] WANT: print a request and its answer (body and status), and check it.
c() { local m=$1 p=$2 b="" want
  if [ $# -eq 4 ]; then b=$3; want=$4; else want=$3; fi
  if [ -n "$b" ]; then echo "\$ curl -X $m $p -d '$b'"; r=$(curl -s -w ' [%{http_code}]' -X $m $U$p -d "$b")
  else echo "\$ curl -X $m $p"; r=$(curl -s -w ' [%{http_code}]' -X $m $U$p); fi
  echo "$r"; expect "$m $p" "$r" "$want"; }
# The status line, the error header and the body of a request.
head_and_body() { curl -s -i "$@" | tr -d '\r' | grep -iE '^HTTP|^x-leanapp-error|^\{'; }
WON='{"ok":{"board":[{"player":"x","square":"center"},{"player":"o","square":"topLeft"},{"player":"x","square":"top"},{"player":"o","square":"left"},{"player":"x","square":"bottom"}],"status":"xWon"}} [200]'
CORRUPT=$'HTTP/1.1 500 Internal Server Error\nX-Leanapp-Error: storage.corrupt\n{"error":"internal"}'

start || exit 1
echo "## a game"
c POST /games                                             '{"ok":1} [200]'
c GET /games/1                                            '{"ok":{"board":[],"status":"xToMove"}} [200]'
c POST /games/1/moves '{"player":"x","square":"center"}'  '{"ok":"oToMove"} [200]'
c POST /games/1/moves '{"player":"o","square":"center"}'  '{"error":"squareTaken"} [422]'
c POST /games/1/moves '{"player":"x","square":"topLeft"}' '{"error":"notYourTurn"} [422]'
c POST /games/1/moves '{"player":"o","square":"topLeft"}' '{"ok":"xToMove"} [200]'
c POST /games/1/moves '{"player":"x","square":"top"}'     '{"ok":"oToMove"} [200]'
c POST /games/1/moves '{"player":"o","square":"left"}'    '{"ok":"xToMove"} [200]'
c POST /games/1/moves '{"player":"x","square":"bottom"}'  '{"ok":"xWon"} [200]'
c POST /games/1/moves '{"player":"o","square":"right"}'   '{"error":"gameOver"} [422]'
c GET /games/1                                            "$WON"
echo "## things that can't be said"
c POST /games/1/moves '{"player":"x","square":"middle"}'  '{"error":"badRequest"} [400]'
c POST /games/1/moves '{"player":"z","square":"center"}'  '{"error":"badRequest"} [400]'
c GET /games/99                                           '{"error":"noSuchGame"} [422]'
c PUT /games/1                                            '{"status":405,"title":"Method Not Allowed","type":"about:blank"} [405]'
echo "## races: two clients move in a fresh game at the same moment"
for g in 2 3 4 5 6; do
  curl -s -o /dev/null -X POST $U/games
  curl -s -w ' [%{http_code}]' -X POST $U/games/$g/moves -d '{"player":"x","square":"center"}' > "$RUN/race1" & p1=$!
  curl -s -w ' [%{http_code}]' -X POST $U/games/$g/moves -d '{"player":"x","square":"topLeft"}' > "$RUN/race2" & p2=$!
  wait $p1 $p2
  n=$(curl -s $U/games/$g | python3 -c 'import sys,json;print(len(json.load(sys.stdin)["ok"]["board"]))')
  echo "game $g: $(cat "$RUN/race1") | $(cat "$RUN/race2") | moves stored: $n"
  # Either client may win; one move is accepted, the other is told it's O's turn.
  answers=$(printf '%s\n%s\n' "$(cat "$RUN/race1")" "$(cat "$RUN/race2")" | LC_ALL=C sort | paste -sd'|' -)
  expect "race in game $g" "$answers, $n" '{"error":"notYourTurn"} [422]|{"ok":"oToMove"} [200], 1'
done
echo "## restart"
stop; start || exit 1
c GET /games/1 "$WON"
echo "## the database"
stop
echo "\$ sqlite3 tictactoe.sqlite .tables"; sqlite3 "$DB" .tables
echo "\$ sqlite3 tictactoe.sqlite '.schema game'"; r=$(sqlite3 "$DB" ".schema game"); echo "$r"
expect ".schema game" "$r" 'CREATE TABLE IF NOT EXISTS "game" (id INTEGER PRIMARY KEY AUTOINCREMENT, "board" TEXT NOT NULL);'
echo "\$ sqlite3 tictactoe.sqlite 'SELECT board FROM game WHERE id = 1'"; r=$(sqlite3 "$DB" "SELECT board FROM game WHERE id = 1"); echo "$r"
expect "stored board" "$r" '[{"player":"x","square":"center"},{"player":"o","square":"topLeft"},{"player":"x","square":"top"},{"player":"o","square":"left"},{"player":"x","square":"bottom"}]'
echo "## hand-edit game 7 so O moved first, and game 8 into something that isn't JSON"
start || exit 1; curl -s -o /dev/null -X POST $U/games; curl -s -o /dev/null -X POST $U/games; stop
sqlite3 "$DB" "UPDATE game SET board = '[{\"player\":\"o\",\"square\":\"center\"}]' WHERE id = 7"
sqlite3 "$DB" "UPDATE game SET board = 'not json' WHERE id = 8"
start || exit 1
for g in 7 8; do
  echo "\$ curl -i GET /games/$g"; r=$(head_and_body $U/games/$g); echo "$r"; expect "corrupt game $g" "$r" "$CORRUPT"
done
echo "\$ curl -i POST /games/7/moves"; r=$(head_and_body -X POST $U/games/7/moves -d '{"player":"x","square":"top"}'); echo "$r"
expect "move in corrupt game 7" "$r" "$CORRUPT"
c GET /games/1 "$WON"
echo
if [ $FAILED -gt 0 ]; then echo "$FAILED answer(s) differ from the post"; exit 1; fi
echo "Every answer matches the post."
