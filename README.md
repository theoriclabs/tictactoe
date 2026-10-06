# Tic-tac-toe

A tic-tac-toe REST API in Lean, with its games stored in SQLite. It is built on
[LeanAPI](https://github.com/theoriclabs/leanapi) and [LeanDB](https://github.com/theoriclabs/LeanDB),
and has no frontend.

The rules are plain Lean. A move can only be played with evidence that it's legal, and a board
read back from the database is replayed through the same rules.

| File | What it is |
| --- | --- |
| `TicTacToe/Rules.lean` | The game: vocabulary and rules. Plain Lean, no imports. |
| `TicTacToe/Server.lean` | Storage and endpoints. It imports `LeanDb.Model` and `LeanApi.Core`. |
| `Main.lean` | `app% server where api := api`, the HTTP server. It imports `LeanApi.Native`. |
| `TicTacToe/Examples.lean` | Compile-time examples. Three of them fail to compile on purpose. |
| `TicTacToe/Run.lean` | Test harness: runs the operations on LeanAPI's in-memory backend. |
| `scripts/run-check.sh` | Serves the app on a fresh SQLite database, and checks every answer over HTTP. |

## Running it

Install [elan](https://github.com/leanprover/elan) and OpenSSL 3 (`brew install openssl@3` on
macOS, `apt install libssl-dev` on Debian or Ubuntu). Lake fetches LeanAPI, LeanDB and their
dependencies at the revisions pinned in `lake-manifest.json`. SQLite is bundled.

```sh
lake build                                    # build the server
lake env lean --run TicTacToe/Run.lean        # in-memory checks
scripts/run-check.sh                          # HTTP and SQLite checks
lake exe tictactoe                            # serve on 127.0.0.1:8080
```

```sh
$ curl -X POST localhost:8080/games
{"ok":1}
$ curl -X POST localhost:8080/games/1/moves -d '{"player":"x","square":"center"}'
{"ok":"oToMove"}
$ curl -X POST localhost:8080/games/1/moves -d '{"player":"o","square":"center"}'
{"error":"squareTaken"}
$ curl localhost:8080/games/1
{"ok":{"board":[{"player":"x","square":"center"}],"status":"oToMove"}}
```

The endpoints:

| Request | Answer |
| --- | --- |
| `POST /games` | The new game's id. |
| `POST /games/:game/moves` with `{"player", "square"}` | The game's status after the move, or `noSuchGame`, `gameOver`, `notYourTurn` or `squareTaken` (422). |
| `GET /games/:game` | The board (the moves in order) and the status. |

Players are `x` and `o`. Squares are `topLeft`, `top`, `topRight`, `left`, `center`, `right`,
`bottomLeft`, `bottom` and `bottomRight`. Anything else is a 400.

## Configuration

The server reads these environment variables:

| Variable | Default | |
| --- | --- | --- |
| `LEANAPP_HOST` | `127.0.0.1` | The IPv4 address to listen on. |
| `LEANAPP_PORT` | `8080` | The port. |
| `LEANAPP_DATABASE` | `tictactoe.sqlite` | The SQLite file, created if missing. |

## Deploying

The `Dockerfile` builds the server and runs it on port `$PORT`, listening on `0.0.0.0` and keeping
its games in `/data/tictactoe.sqlite`. Mount a volume at `/data` so games survive a redeploy.
`railway.json` deploys it on [Railway](https://railway.com).
