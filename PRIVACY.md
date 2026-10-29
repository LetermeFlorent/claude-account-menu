# Privacy

clm runs on your computer and has no server of its own. It talks to a few services, listed below with what each one receives. Nothing is sent to the author, and clm has no telemetry.

## What clm sends, and to whom

To read an account's quota, clm calls the Anthropic usage API (`api.anthropic.com/api/oauth/usage`) with that account's Claude Code access token in an `Authorization` header. It reads back the 5 hour and 7 day percentages and reset times. When the access token is about to expire, clm renews it the way Claude Code does, with a request to `platform.claude.com/v1/oauth/token` that carries the refresh token and a `claude-cli/<version>` user agent. On macOS clm never renews a token itself, and it skips renewal for an account marked as open on another PC.

To update itself, clm asks the GitHub API for the latest release of `LetermeFlorent/claude-account-menu`, then downloads the release zip and its `.sha256` file from `github.com`. The only header it sends is `User-Agent: clm`. The zip is refused unless its SHA-256 matches. The update of Claude Code is done by `claude update`, which does its own networking. clm only reads a release `manifest.json` from `storage.googleapis.com` to size the progress bar.

Google Drive is used only if you connect it with the `y` key or `clm --drive-login`. Sign-in goes through your browser to `accounts.google.com`, with the `drive.file` scope, PKCE and a loopback redirect on `127.0.0.1`. That scope lets clm see only the files it created itself, inside a `clm-sync` folder. Calls go to `oauth2.googleapis.com` and `www.googleapis.com`.

Before opening the menu or launching an account, clm also opens a plain TCP connection to `api.anthropic.com:443` and `github.com:443` to check that you are online. No data is sent on it. The local web page loads nothing from the internet.

## What goes to Drive, and how it is encrypted

Synced files are your account folders (without conversations, caches and other local-only items), `.claude.json`, `.mcp.json`, the account list, and each account's Claude Code login file, which holds its tokens. Conversations (`projects/*.jsonl`, with their `subagents` and `tool-results`), `file-history`, `node_modules`, caches and browser profiles never leave the PC, while the `memory` folders of projects do sync. The `statusLine` entry of each `settings.json` stays local.

Everything is encrypted before upload with a key made from your sync phrase (at least 12 characters). The key comes from PBKDF2 with HMAC-SHA256, 600000 rounds and a random 16 byte salt. Each file is encrypted with AES-256 in CBC mode with a random IV, then signed with HMAC-SHA256 over its Drive path, the IV and the ciphertext. The signature is checked before anything is decrypted, so a modified file is refused.

Some things stay readable on Drive because Google needs them as metadata: file names (which include account folder names and project folder names), sizes, modification times, the name of each PC, the time each account was last opened on a PC, the expiry time and e-mail address of each token file, a key id, and for each file a tag made from its MD5 hash encrypted with a derived key, which is the same for equal files. The file `clm-key.json` is not encrypted. It holds the salt, the round count and a check value, so that a typed phrase can be verified. Anyone who can read your Drive could use it to guess a weak phrase, at 600000 rounds per guess.

Your sync phrase is not stored. The 32 byte key derived from it is, and on its own it can decrypt your Drive files. On Windows it sits in the file `sync-key`, protected by DPAPI for your user. On macOS it is in the login Keychain (service `clm-sync-key`, account `clm`). On Linux it is a JSON file with mode 600. A forgotten phrase cannot be recovered: `clm --sync-key-reset` creates a new one.

## What stays on this PC

The state folder is `%LOCALAPPDATA%\clm` on Windows, `~/Library/Application Support/clm` on macOS and `$XDG_STATE_HOME/clm` (default `~/.local/state/clm`) on Linux. It holds the account list, display and sync settings, and `drive.json` with your Google tokens. The `backup-key` file is a random key used only to recognise the backups clm made. None of it is uploaded.

On Linux and macOS, files holding secrets get mode 600. On Windows they keep the default permissions of your profile folder, except `sync-key`, which is DPAPI-protected.

The quota cache `usage.json` is in `%LOCALAPPDATA%\claude-menu`, `~/Library/Caches/claude-menu` or `~/.cache/claude-menu`. It has percentages and times per account name, with no token and no e-mail. The status line state file lives in a `claude-statusline` folder at the same base as the state folder.

Backups are written to your Downloads folder as `claude-comptes-*.zip` (or `.tar.gz`). They are not encrypted. On Windows and Linux they contain each account's login file, so treat them like a password and delete them when you are done. On macOS the login stays in the Keychain and is not in the archive.

The web page started by `w` or `clm --web` listens on `127.0.0.1` only, on a port chosen by the system. It opens with a one-time link valid for 60 seconds, then uses a session cookie, and it stops when the menu closes. It returns account names, e-mail addresses, plans and quotas, never a token.

## Turning Drive off

Run `clm --sync-auto=off` to stop automatic sync (login files are still exchanged when you launch or close an account). To cut the link completely, run `clm --sync-key-forget` and delete `drive.json` from the state folder on each PC, then remove clm's access at https://myaccount.google.com/permissions. The `clm-sync` folder in your Drive can then be deleted by hand.

## Contact

letermeflorent@gmail.com
