# Security

## Reporting a problem

If you find a security issue in Cube Hub, please **don't open a public issue**. Report it privately instead: on GitHub, open the **Security** tab of the repository and click **Report a vulnerability**. I'll answer as soon as I can.

## What Cube Hub does on your Mac

- **Claude Code hooks.** With your OK, Cube Hub adds hooks to `~/.claude/settings.json` (after saving a copy of the file). They run `~/.cube-widget/bin/cube-hook`, which only writes small files in `~/.cube-widget/sessions/`. It never sends anything anywhere.
- **Terminal.** The "Afficher dans Terminal", "Ramener dans le Hub" and `>_` buttons control the Terminal app through AppleScript, only when you click them. macOS asks for your permission first.
- **Nothing is collected.** No analytics, no account, no server of mine.

## Telegram (off by default)

Telegram is optional and everything in it starts turned off.

- The bot token and the unlock secret are stored in the **macOS keychain**, never in a file.
- **Notifications** send the project name and a short summary to your own bot. The summary is made by Claude Code on your Mac (`claude -p`, with the small Haiku model).
- **Answering from your phone** types text into a Claude session. It is protected by several layers:
  - a 6-digit code from your authenticator app, valid 30 minutes;
  - each project must be allowed on the Mac, one by one;
  - only your own private chat with the bot is read;
  - no terminal or Claude commands (`!`, `/`, `#`);
  - message limits, and late or replayed messages are refused;
  - a log of everything received (`~/.cube-widget/remote.log`) and a Mac notification for what matters.

If you don't need to answer from your phone, leave "Commandes depuis Telegram" off.
