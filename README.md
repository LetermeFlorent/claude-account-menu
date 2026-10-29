# claude-account-menu

clm is a terminal menu for people who use several Claude Code accounts on one computer. Each account has its own config folder (`.claude`, `.claude-compte2` and so on). clm starts Claude Code on the one you pick and shows the 5 hour and 7 day quota of every account next to its name. It also adds, renames, removes, saves and restores accounts, keeps Claude Code up to date, and can sync your settings between PCs through your own Google Drive. It runs on Windows, macOS and Linux and is released under the MIT licence.

## Install

Clone the repository and run the installer for your system. [INSTALL.md](INSTALL.md) has the requirements, the update and uninstall steps and troubleshooting.

```powershell
git clone https://github.com/LetermeFlorent/claude-account-menu.git
cd claude-account-menu
powershell -ExecutionPolicy Bypass -File .\install.ps1
```

On Linux and macOS, install PowerShell 7 first and run `sh install.sh` instead. Then open a new terminal and type `clm`. What clm sends over the network and what it keeps on disk is described in [PRIVACY.md](PRIVACY.md).

## The menu

The menu opens full screen with one block per account: its number, name and plan, its e-mail address, and a 5 hour bar and a 7 day bar with the percentage, the time before the reset and a word for the pace. The bars turn to a stronger colour at 30 % and again at 70 %. An account at 100 % gets a badge such as "quota 5h atteint". Quotas are read in the background, kept for 3 minutes in a cache and read again for each account about every 3 minutes while the menu is open. A counter next to each name shows the wait ("maj 2m05s"), or "pause API" when the usage API has refused the call, in which case the last known values stay on screen.

The pace word comes from projecting the current percentage to the end of the window: `debut` (under 10 % of the window elapsed), `faible` (projected under 70 %), `normal` (70 to 100 %), `fort` (100 to 130 %), `excessif` (over 130 %) and `epuise` (quota used up).

The menu text is in French. In a terminal that cannot draw it (input or output redirected, or no VT support) clm prints the account list with the quotas and asks for a number instead. Under 41 columns, or in a very short terminal, the menu shows one line per account. While the startup updates run, most keys wait until they finish.

### Keys

Letters work in upper case too. Esc and Ctrl+C quit as well, and the footer of the menu lists the main keys.

| Key | Action |
|---|---|
| Up, Down | Move the cursor, wrapping around |
| Enter | Launch the selected account |
| `1` to `9` | Launch the account with that number |
| `a` | Add an account |
| `x` | Remove an account |
| `n` | Rename an account |
| `m` | Read the quotas of the selected account again now |
| `u` | Install the clm update announced by "[maj dispo]" and restart; with none waiting it only says so |
| `y` | Run a Drive sync, or connect Drive when this PC is not connected |
| `p` | Choose which skills and MCP servers sync to this PC |
| `s` | Save accounts to an archive |
| `r` | Restore a saved archive |
| `w` | Open the web page |
| `q` | Quit |

On Windows the mouse works too: a click selects an account, a double click on the selected one launches it, the wheel moves the cursor and a click on a footer key presses it. While the menu is open, quick edit mode is switched off on the console, so selecting text needs Shift.

### Launching an account

Claude Code starts in the same terminal with `CLAUDE_CONFIG_DIR` set to the account's folder (the variable is removed for `.claude`). Just before, clm writes the account's quotas to the status line state file. The program is `~/.local/bin/claude` (`claude.exe` on Windows) if it exists, otherwise the first `claude` on the PATH. Arguments clm does not recognise go to Claude Code, and its exit code becomes clm's.

### Accounts

Key `a` asks for a name (Enter keeps `compteN`, `q` cancels) and creates the folder `.claude-compteN`, with N the first free number from the account count plus one. The new folder gets links to the shared items of `.claude` (the folders `agents`, `commands`, `hooks`, `plugins`, `rules`, `skills` and the files `ANTI-EMPREINTE.md`, `CLAUDE.md`, `settings.local.json`, `statusline.json`), a copy of its `settings.json`, and a `.claude.json` that skips Claude Code's welcome. Then `claude auth login` opens your browser. If claude.ai is already signed in there under another account, use a private window. An abandoned login leaves the account in the menu as "cree, mais non connecte": launch it and type `/login`.

Key `x` lists the accounts and then offers two exits: take the account out of the menu and keep its folder, or also erase the folder after clm puts a safety archive in Downloads. Only folders named `.claude-<name>` can be erased, never `.claude`, and the last account cannot be removed. Key `n` changes the displayed name, which cannot be empty, hold a comma or match another account. Names are cut at 40 characters. The order of the menu is the order of `accounts.json`, and `clm --move` changes it.

### Updates

At startup clm checks for a newer release of itself, then runs `claude update` for Claude Code, and shows both as progress bars above the accounts. The menu stays usable if a step fails and the reason shows at the bottom. See INSTALL.md for details.

## Command line

Everything the menu does also works as an option, and `clm --help` prints them all with the keys, the variables and the files. A `<compte>` is a number from 1 to 9, an account name or a folder name such as `.claude-compte2`. Options exit with 0, or 1 and a reason on the last line.

| Option | What it does |
|---|---|
| `clm -N` | Launch account N (1 to 9) without the menu; other arguments go to Claude Code |
| `--list` | One line per account: number, name, folder, e-mail |
| `--usage` | Print the quotas and the pace words, then exit |
| `--add [name]` | Create an account and start its login |
| `--rename <compte> <name>` | Rename an account |
| `--move <compte> <rank>` | Move an account to a rank, 1 being the top |
| `--remove <compte> [--erase] --yes` | Remove an account; without `--yes` it prints the plan and exits 1 |
| `--save[=name,name]` | Save the named accounts, or all, to Downloads |
| `--backups` | List the archives clm made on this PC |
| `--restore=<archive> [--only=name,name] [--yes]` | Restore an archive; `--yes` accepts changed hooks, MCP, env or permissions |
| `--version` | Print clm and Claude Code versions |
| `--update` | Check for a newer clm, then run the Claude Code update for every account |
| `--no-update` | Skip both updates for this run |
| `--web` | Open the menu with the web page; needs an interactive terminal |
| `--palette auto\|dark\|light` | Set the colours of this PC (`sombre` and `clair` also work) |
| `--anim auto\|on\|off` | Set the animations of this PC |
| `--help`, `-h` | Print the full help |

Drive options: `--drive-login`, `--drive-status`, `--sync [--force]`, `--sync-auto=on\|off`, `--sync-key`, `--sync-key-reset` and `--sync-key-forget`. Per-PC choices of synced skills and MCP servers use `--prefs`, `--prefs-on <id>`, `--prefs-off <id>` and `--prefs-erase <id> --yes`, where an id looks like `skill:name`, `mcp:project|name` or `global:name`.

## Backup and restore

Key `s` (or `--save`) writes `claude-comptes-<date>.zip` to your Downloads folder (`.tar.gz` on Linux without `bsdtar`). It holds the chosen account folders, `.claude.json` and `.mcp.json` when `.claude` is chosen, the account list, and the clm scripts from `~/.local/bin`. Conversations, caches and hidden folders in `skills` are left out, and so are the shared items of accounts other than `.claude`. The archive is not encrypted and, on Windows and Linux, contains the login tokens: keep it private.

Key `r` shows up to nine of the most recent archives that clm itself made on this PC, which it recognises by name and size against its own record, then lets you pick accounts. The archive's signature is checked at restore time. `clm --restore=<path>` accepts any archive and only warns. Before overwriting, clm saves the accounts already present, and it refuses an archive made by a newer clm. Restoring unpacks only account items, so files missing from the archive stay as they are. When the archive changes hooks, MCP servers, environment variables or permissions, the menu lists them in alert colour (it always asks for `o` before restoring), the command line needs `--yes`, and a restore from the web page fails with a message to confirm in the menu. A token that was renewed since the backup may need a fresh `/login`.

## Syncing between PCs

Press `y` to connect Google Drive. A browser window opens for Google sign-in, then clm asks for a sync phrase of at least 12 characters (twice on a new Drive, once if the Drive already has one). Every PC needs the same phrase. It is asked by `y`, `--drive-login`, `--sync-key` and `--sync-key-reset`, never by background jobs; `y` asks again when Drive is connected but this PC holds no phrase. What gets synced, how it is encrypted and what stays readable is in PRIVACY.md.

Automatic sync is on by default. It runs in the background when the menu opens, when you launch an account, and while Claude Code runs through a small hidden watcher that starts with the account, uses low priority and stops itself. Conflicts keep the newer file and save the other as `<file>.conflit-<PC name>` (characters other than letters, digits, `_` and `-` become `_`). On the first sync of a PC, the Drive copy wins and the local one is kept the same way. A sync that would delete more than 20 files and more than a tenth of the known files is blocked until you run `clm --sync --force`.

Login tokens are exchanged too, and the one that expires later wins, so an account stays signed in on every PC. Only use one account in one place at a time: two Claude Code sessions renewing the same token can sign each other out.

Key `p` (or `--prefs`) lists synced skills and MCP servers with check boxes for this PC. With two or more PCs, the left and right arrows switch to another PC's choices. Space toggles an item and `Suppr` erases it everywhere, both after a confirmation with `o`; erasing works only on this PC's own list, and on another PC's list only Space works. Esc or `q` leaves the page. Skills go to the Drive trash, so they can be recovered there.

## Web page

Key `w` or `clm --web` opens a page at `http://127.0.0.1:<port>/` in your browser, served by clm while the menu is open and closed with it. It has four tabs, Comptes, Drive, Affichage and Sauvegardes, and does what the keys do: quotas, add, rename, move, remove, sync choices, display settings, save and restore. Actions run in the terminal menu, so while it is busy the page answers that clm is busy.

## Colours and animation

The palette is chosen in this order: the `STATUSLINE_BG` variable (`dark` or `light`), then `clm --palette`, then the system theme (Windows registry, macOS appearance, GNOME, GTK or KDE), then dark. The animations follow the same order with `CLM_ANIM` (`0` or `1`), `clm --anim` and the system setting for reduced motion. Both settings are stored in `display.json`.

## Files

The state folder is `%LOCALAPPDATA%\clm` on Windows, `~/Library/Application Support/clm` on macOS and `$XDG_STATE_HOME/clm` (default `~/.local/state/clm`) on Linux.

| File | Content |
|---|---|
| `accounts.json` | The account list, `[{Label, Dir}]` in menu order |
| `display.json` | Palette and animation choice |
| `drive.json` | Google tokens and the PC name; secret |
| `sync-key` | The sync key; absent on macOS, which uses the Keychain |
| `sync-choice.json`, `sync-catalog.json` | Per-PC sync choices |
| `backup-key`, `backup-marks.txt` | Recognition of the archives clm made |

Smaller files here are locks and sync bookkeeping. Elsewhere, the quota cache is `usage.json` in `%LOCALAPPDATA%\claude-menu`, `~/Library/Caches/claude-menu` or `~/.cache/claude-menu`, the status line state is in a `claude-statusline` folder next to the state folder, and the program files are in `~/.local/bin`. A damaged `accounts.json` is copied aside as `accounts.json.bad-<date>` and defaults are used.

## Tests

`tests/run.ps1` runs every `*.checks.ps1` file under `tests` in a temporary sandbox, with no network and no real account, and exits with a non-zero code on any failure. Run it with `powershell -File tests\run.ps1` or `pwsh -File tests/run.ps1`. CI runs it on Linux, macOS and Windows for every push and pull request, with PowerShell 7 everywhere and Windows PowerShell 5.1 as well on Windows, plus a lint and an install smoke test.

## Limits

The number keys cover the first nine accounts. Quotas come from an undocumented Anthropic API and token renewal from an undocumented OAuth endpoint, so either may change or refuse calls. The same account open on two PCs at once can end up signed out on one of them, and the menu then warns with "ouvert sur <PC>".
