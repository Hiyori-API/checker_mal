# CheckerMal

This is mostly a rewrite of [mal-id-cache](https://github.com/seanbreckenridge/mal-id-cache), with nicer concurrency/entrypoints.

This uses the [Just Added](https://myanimelist.net/anime.php?o=9&c%5B0%5D=a&c%5B1%5D=d&cv=2&w=1) page on MAL to find new entries, but all that page is is a search on the entire database reverse sorted by IDs. New entries may appear on the 2nd, 3rd, or even 20th page, if a moderator took a long time to get around to it. See [`config/pages.exs`](./config/pages.exs) for how often this checks different page ranges.

Currently any changes are stored as `txt` files in `./cache` (not synced to this repo), any changes are back filled to `mal-id-cache`. Eventually the [source backend](https://github.com/Hiyori-API/checker_mal/blob/master/config/config.exs#L16) will be some `NoSQL` database, and periodically synced up to the [`HiyoriDB`](https://github.com/Hiyori-API/HiyoriDB) repository.

This acts as the Checker for MAL to maintain a cache for `Hiyori`, but it has some additional, optional `applications`.

### Planned Features:

- [x] (**Core**) Maintain an up-to-date cache of anime (and manga) IDs on MAL
- [x] Calculate unapproved items and display them as HTML (replace [this](https://github.com/seanbreckenridge/mal-unapproved))
- [ ] An API for random anime/manga IDs

---

The Unapproved HTML webapp can be enabled/disabled in the [config](config.exs). Expects a Jikan instance to be running on port 8000 (port can also be modified in config)

---

This can be run with `mix run --no-halt` or `mix phx.server`; I'd recommend using the [`./production_server`](./production_server) script to make sure secrets are set properly, see [`config/prod.secret.exs`](./config/prod.secret.exs) for the required environment variables.

- Install dependencies with `mix deps.get`
- Create and migrate your database with `mix ecto.setup`
- Install Node.js dependencies with `npm install` inside the `assets` directory
- Start Phoenix endpoint with `mix phx.server`

Server is hosted on `localhost:4001`.
