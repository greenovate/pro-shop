# Pro Shop

A World of Warcraft addon for **Anniversary Classic (TBC, Patch 2.5.5)** that helps profession service providers advertise, manage customers, and track tips.

## Features

- **Profession Detection** — Automatically detects your professions, skill levels, and scans known recipes
- **Smart Advertising** — Auto-generates ads featuring your best recipes, or write custom ads per profession
- **Trade Chat Monitoring** — Watches trade/general/LFG chat for crafting requests matching your professions
- **Auto-Invite with Zone Check** — Sends group invites only to players in your same zone (via /who verification)
- **Customer Queue** — Tracks incoming customers, their mat status, and service progress
- **Tip Tracking** — Detects gold received via trade window, auto-whispers thanks, tracks session/lifetime tips
- **Whisper Templates** — Customizable greeting, mat inquiry, busy, and thank-you messages
- **Lockpicking Support** — Dynamic ads based on actual lockpicking skill and which lockboxes you can open
- **Class Services** — Mage portals and Warlock summons supported
- **Busy Mode** — Toggle to notify new customers you'll get to them shortly
- **Blacklist** — Block specific players from triggering auto-actions
- **ElvUI Compatible** — Minimap button works with ElvUI's minimap collector
- **Minimap Button** — Quick access: left-click config, shift-click broadcast, ctrl-click busy, right-click toggle

## Installation

1. Download the latest release
2. Extract `ProShop` folder into your `Interface\AddOns\` directory
3. Restart WoW or `/reload`

## Commands

| Command | Description |
|---------|-------------|
| `/ps` | Open settings panel |
| `/ps toggle` | Enable/disable addon |
| `/ps scan` | Rescan professions |
| `/ps busy` | Toggle busy mode |
| `/ps queue` | Show customer queue |
| `/ps next` | Serve next customer |
| `/ps done` | Mark current customer complete |
| `/ps clear` | Clear queue |
| `/ps bl [name]` | Toggle blacklist |
| `/ps tips` | Show tip statistics |
| `/ps cd` | Show profession cooldowns |
| `/ps status` | Show current status |
| `/ps monitor` | Toggle chat monitoring |

## Configuration

Open the settings panel with `/ps` — five tabs:

1. **General** — Master toggle, busy mode, active professions (controls monitoring/invites), detected skills, cooldowns
2. **Monitor** — Chat channel toggles, auto-invite, auto-whisper, sound alerts, contact cooldown
3. **Advertise** — Per-profession ad toggles, custom ad text boxes, broadcast buttons
4. **Whispers** — Customize all whisper templates with {item} and {position} placeholders
5. **Queue** — Live customer queue display with status tracking

## License

All rights reserved.
