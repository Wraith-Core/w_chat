# w_chat

Custom roleplay-ready chat system and command autocomplete styled to match `w_lib` for **Wraith Framework RedM**.

## Key Features

- Styled to match the Red Dead paper-and-ink theme of `w_lib`.
- Live command suggestions and autocomplete.
- Bilingual support (`en` / `ar`) following `w_lib:locale`.
- Includes `/clear` command and `addMessage` export.

## Installation

1. Remove or disable stock Cfx `chat` if present.
2. Place `w_chat` in `resources/[wraith]/w_chat`.
3. Add `ensure w_chat` to `server.cfg` after `w_lib`.

## Export

```lua
exports.w_chat:addMessage({
    args = { 'System', 'Welcome to the server!' },
})
```

## Documentation & Links

- **Developer Docs:** https://wraith-core.github.io/docs/#/resources/interface-world
- **txAdmin Recipe:** https://github.com/Wraith-Core/txAdminRecipe
