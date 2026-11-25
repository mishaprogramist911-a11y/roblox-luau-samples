# Roblox Luau samples

Three small pieces of server-side Roblox code, written in strict Luau.
They show how I write gameplay code: the server decides, the client only asks.

| File | What it shows |
| --- | --- |
| `src/server/RateLimiter.luau` | A token-bucket limiter to ignore remote spam |
| `src/server/PlayerData.luau` | Saving player stats: pcall, retries, autosave, save on shutdown |
| `src/server/CoinPickup.server.luau` | A coin pickup where every request is checked on the server |
| `src/client/CoinClient.client.luau` | The small client part that reports a touch |

## Details

**RateLimiter** gives each player a bucket of tokens. A request spends one,
tokens come back over time. Buckets are removed when the player leaves.

**PlayerData** never saves for a player whose data failed to load, so a
DataStore outage cannot replace real progress with zeros. Saved values are
checked against a template. It does not do session locking; a large live game
should use a library made for that, such as ProfileStore.

**CoinPickup** treats any part tagged `Coin` as a coin. The client sends only
the coin it touched. The server checks the rate, the type of the argument, the
tag, that the character is alive and near, and that the coin is not already
taken. The client never sends an amount.

## Try it

Tools: [Rokit](https://github.com/rojo-rbx/rokit) with Rojo and Selene (versions in `rokit.toml`).

```bash
rokit install
rojo build -o samples.rbxl
```

Open `samples.rbxl` in Roblox Studio, add a few parts, give them the tag `Coin`,
turn on "Enable Studio Access to API Services" in Game Settings, and press Play.

## What was checked

- The project builds with Rojo and passes Selene with no warnings.
- The limiter logic and the data clean-up logic were run in Studio with test values.
- The full pickup and save flow was not yet run in a published game.

Written with AI tools and reviewed by me.

## License

MIT
