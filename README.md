# CheckerMal

This is mostly a rewrite of [mal-id-cache](https://github.com/purarue/mal-id-cache), with nicer concurrency/entrypoints.

This uses the [Just Added](https://myanimelist.net/anime.php?o=9&c%5B0%5D=a&c%5B1%5D=d&cv=2&w=1) page on MAL to find new entries, but all that page is is a search on the entire database reverse sorted by IDs. New entries may appear on the 2nd, 3rd, or even 20th page, if a moderator took a long time to get around to it. See [`config/pages.exs`](./config/pages.exs) for how often this checks different page ranges.

Currently any changes are stored as `txt` files in `./cache` (not synced to this repo), any changes are back filled to `mal-id-cache`. Eventually the [source backend](https://github.com/Hiyori-API/checker_mal/blob/master/config/config.exs#L16) will be some `NoSQL` database, and periodically synced up to the [`HiyoriDB`](https://github.com/Hiyori-API/HiyoriDB) repository.

This acts as the Checker for MAL to maintain a cache for `Hiyori`, but it has some additional, optional `applications`.

### Planned Features:

- [x] (**Core**) Maintain an up-to-date cache of anime IDs on MAL
- [x] Calculate unapproved items and display them as HTML (replace [this](https://github.com/purarue/mal-unapproved))
- [x] Create an API for unapproved items

Note: This used to also index the unapproved manga, but since Aug 25 2023, MAL removed the way I was doing that. See <https://purarue.xyz/mal_unapproved/manga> for info

---

## Unapproved HTML

The Unapproved HTML webapp can be enabled/disabled in the [config](config/config.exs)

Expects the `MAL_CLIENTID` environment variable to be set (a MAL API Client ID)

---

The Unapproved API returns similar data to the HTML. While the server is booting (the first couple seconds, while its requesting the unapproved HTML page for the first time), it may send HTTP errors (some HTTP code >=400) due to timeouts

It returns items similar to the HTML, like:

```json
{
  "id": 45383,
  "name": "Crepuscule (Yamachi)",
  "nsfw": false,
  "type": "Manga"
}
```

The `name`, `nsfw` and `type` fields are all nullable -- they might by `null` if the data for it has to yet to be cached.

There are public, CORS-friendly API routes at:

<https://purarue.xyz/mal_unapproved/api/anime>

You can also limit how many are returned, if you just want the top <https://purarue.xyz/mal_unapproved/api/anime?limit=50>

---

This can be run with `mix run --no-halt` or `mix phx.server`; I'd recommend using the [`./production_server`](./production_server) script to make sure secrets are set properly, see [`config/prod.secret.exs`](./config/prod.secret.exs) for the required environment variables.

- Install dependencies with `mix deps.get`
- Create and migrate your database with `mix ecto.setup`
- Install Node.js dependencies with `yarn` inside the `assets` directory
- Start Phoenix endpoint with `mix phx.server`

Server is hosted on `localhost:4001`.

---

Includes a basic HTTP API to request more pages to be requested (since sometimes it takes a few days to check as far back as you may want). Those can be triggered by sending GET requests like:

`http://localhost:4001/api/pages?type=anime&pages=15`
`http://localhost:4001/api/pages?type=anime&pages=30`
`http://localhost:4001/api/pages?type=manga&pages=100`
