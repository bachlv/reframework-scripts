# 🎮 RE Scripts

A collection of useful [REFramework](https://github.com/praydog/REFramework) Lua scripts for Resident Evil games.

## Installation

1. Install [REFramework](https://github.com/praydog/REFramework) for your game
2. Copy the desired `.lua` script(s) into your game's `reframework/autorun/` folder
3. Launch the game and press **Insert** to open the REFramework menu

## Resident Evil 9: Requiem

Scripts are in the [`re9/`](re9/) folder.

| Script                                                   | Description                                                                              |
| -------------------------------------------------------- | ---------------------------------------------------------------------------------------- |
| [`add_key_items.lua`](re9/add_key_items.lua)             | View and add specific key items and weapons directly into your inventory                 |
| [`change_difficulty.lua`](re9/change_difficulty.lua)     | Override game difficulty mid-game (Casual, Standard Modern/Classic, Insanity)            |
| [`edit_playthrough.lua`](re9/edit_playthrough.lua)       | Modify clear times and playthrough counts with native integration to fetch RE.NET stats  |
| [`unlock_achievements.lua`](re9/unlock_achievements.lua) | Unlock achievements and claim Clear Points — supports Steam integration and batch unlock |
| [`unlock_files.lua`](re9/unlock_files.lua)               | Instantly acquire and mark as read all collectible documents and text files              |
| [`unlock_raccoon.lua`](re9/unlock_raccoon.lua)           | Track and instantly unlock all 25 Mr. Raccoons using the in-game Fragile Symbol tracking |

> [!NOTE]
> Scripts use `app.RankManager` and `app.AchievementManager` singletons — you need to be in-game (load a save) for them to work. Only use one achievement script at a time in `autorun/` to avoid conflicts.

## Contributing

Contributions are welcome! Feel free to submit a PR with new scripts or improvements.

## License

[MIT](LICENSE)
