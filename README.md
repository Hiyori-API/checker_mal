# CheckerMal

This is mostly a rewrite of [mal-id-cache](https://github.com/seanbreckenridge/mal-id-cache), with nicer concurrency/entrypoints.

Currently any changes discovered by this are back filled to `mal-id-cache`

This acts as the Checker for MAL to maintain a cache for `Hiyori`, but it has some additional, optional `applications`.

### Planned Features:

- [x] (**Core**) Maintain an up-to-date cache of anime (and manga) IDs on MAL
- [ ] Calculate unapproved items and display them as HTML (replace [this](https://github.com/seanbreckenridge/mal-unapproved))
- [ ] An API for random anime/manga IDs
- [ ] A feed of recently approved anime/manga as HTML, provide data for [this](https://github.com/seanbreckenridge/mal-notify-bot)

---

Check [`config/pages.exs`](./config/pages.exs) for how often this checks different page ranges.

---

This can be run with `mix run --no-halt` or `mix phx.server`

- Install dependencies with `mix deps.get`
- Create and migrate your database with `mix ecto.setup`
- Install Node.js dependencies with `npm install` inside the `assets` directory
- Start Phoenix endpoint with `mix phx.server`

Server is hosted on `localhost:4001`.
