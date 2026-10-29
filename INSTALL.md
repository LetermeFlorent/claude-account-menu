# Installing clm

clm is a terminal menu that starts Claude Code on one of several accounts and shows each account's 5 hour and 7 day quota. This page covers installing, updating and removing it. The README describes what it does once it runs.

## Requirements

On Windows you need Windows PowerShell 5.1, which ships with the system, and `tar.exe` from Windows 10 1803 or later for backups. The installer only warns when `tar.exe` is missing (on Linux it warns when `bsdtar` is missing). `clm.cmd` runs clm with PowerShell 7 when `%ProgramFiles%\PowerShell\7\pwsh.exe` exists and with Windows PowerShell 5.1 otherwise. The status line hook always runs on 5.1.

On Linux and macOS you need PowerShell 7 (`pwsh`) on the PATH. On macOS, `brew install powershell` does it. On Linux, restoring a `.zip` backup also needs `bsdtar` (package `libarchive-tools`), since GNU tar cannot read zip files.

Claude Code should already be installed in `~/.local/bin` or on the PATH. The installers only warn if they cannot find it. Git is optional and is used only to stamp the version of a clone.

To open the menu or launch an account, clm needs internet access: it checks that `api.anthropic.com` or `github.com` answers on port 443 (up to 3 tries within 3 seconds) and exits with an error if neither does. Options that only read local files, such as `--list`, `--version` and `--help`, skip the check.

## Install on Windows

Clone the repository (or unpack a release zip) and run the installer from its folder.

```powershell
git clone https://github.com/LetermeFlorent/claude-account-menu.git
cd claude-account-menu
powershell -ExecutionPolicy Bypass -File .\install.ps1
```

The script takes no options. It copies every `.ps1` and `.cmd` file of `bin`, the `bin\clm-web` folder and the `bin\lang` text tables to `%USERPROFILE%\.local\bin`, rewriting only the files that changed and removing the ones clm no longer ships, and adds that folder to your user PATH if it is missing. It lists what it copied in `clm.files` and writes `clm.version` last, from git or from the release package. While it copies, a `clm.installing` marker tells every running clm to wait and then reload itself. Open a new terminal, because terminals that were already open do not see the new PATH, then type `clm`.

## Install on Linux and macOS

The steps are the same with the shell installer.

```sh
git clone https://github.com/LetermeFlorent/claude-account-menu.git
cd claude-account-menu
sh install.sh
```

It copies the `.ps1` files, the `clm` launcher, `clm-web` and `lang` to `~/.local/bin`, the same way. The `clm` launcher needs `pwsh` on the PATH; `CLM_PWSH` is read only by the hook step of the installer. It does not edit your shell profile: if the folder is not on the PATH it prints the line `export PATH="$HOME/.local/bin:$PATH"` for you to add to `~/.profile`, `~/.bashrc` or `~/.zshrc`. If `pwsh` is missing it copies the files, tells you to install PowerShell 7 and stops before the hook step, so run it again afterwards. Set `CLM_PWSH` to use a `pwsh` that is not on the PATH.

## The status line hook

Both installers run `install-hook.ps1`, which you can also run alone. For `~/.claude` and every `~/.claude-compte*` folder that has a `settings.json`, it adds a `SessionStart` hook (matcher `startup`, timeout 15 seconds) that runs `claude-statusline-seed.ps1`. That script copies the quotas clm knows into the status line state file whenever Claude Code starts, without calling the network.

Before it changes a file, the hook step copies it to `settings.json.bak-seed`. If the hook is already there the file is left alone, and a stale hook command is replaced in place. A `settings.json` that is not valid JSON stops the installer with an error, after the `.bak-seed` copy is made. New accounts created by clm copy `~/.claude/settings.json`, so they carry the hook too.

## First launch

Run `clm`. With no `accounts.json` yet, clm lists `.claude` as `compte1` plus any `~/.claude-compte2` to `~/.claude-compte9` folders that exist, then saves that list in its state folder (`%LOCALAPPDATA%\clm`, `~/Library/Application Support/clm` or `~/.local/state/clm`). Press `a` to add an account, or run `clm --usage` to print the quotas without opening the menu. Files from older versions that sat in your home folder are moved into the state folder automatically.

## Moving to another computer

Run `clm` and press `s` to save accounts to an archive in your Downloads folder, copy the archive over, install clm there, and press `r`. A backup made by a newer clm than the installed one is refused: let clm update first. Backups hold the saved settings but not the login of macOS accounts, which live in the Keychain. Those accounts sign in again after a restore. The README has the details, including Drive sync as an alternative.

## Updating

clm updates itself when it was installed with the installer. At startup it asks GitHub for the latest release, unless another clm checked in the last 2 minutes, and while the menu is open it asks again every 10 minutes. When a newer one exists the menu shows `[maj dispo]` and the `u` key restarts clm onto it, which installs it after a last check. The download is checked against the release's SHA-256 file before anything runs.

Only one clm installs at a time, the others wait up to 3 minutes. Once the new version is installed, every other running clm restarts onto it as soon as its menu is idle, with `--no-update`. A clm never restarts while a Claude Code session it launched is running.

Nothing updates when `clm.version` is missing, which happens when you installed from a copy without git or a release package, or when clm runs from the clone instead of `~/.local/bin`. In that case pull the repository (or unpack the new release) and run the installer again. The installers are safe to repeat.

`clm --update` forces a check and then runs `claude update`, once, and shows the result for every account. One clm runs it at a time under a lock: the others wait up to 5 minutes, or skip a check made in the last 2 minutes. Pass `--no-update` to skip both clm's and Claude Code's update for one run.

## Uninstalling

There is no uninstall command. Delete the clm files from `~/.local/bin` (`clm`, `clm.cmd`, `claude-menu.cmd`, `claude-*.ps1`, `clm.version`, `clm.files` and the `clm-web` and `lang` folders) but keep `claude` or `claude.exe`, which is Claude Code. On Windows, remove `%USERPROFILE%\.local\bin` from your user PATH only if nothing else needs it.

Then remove the hook entry that runs `claude-statusline-seed.ps1` from each account's `settings.json` (the `.bak-seed` copy is the file as it was before). The state folder and the cache folder (`%LOCALAPPDATA%\claude-menu`, `~/Library/Caches/claude-menu` or `~/.cache/claude-menu`) can go too. If you used Drive sync, run `clm --sync-key-forget` first. Your account folders and backups are never deleted by the installers.

## Troubleshooting

If `clm` is not recognised on Windows, open a new terminal or run `%USERPROFILE%\.local\bin\clm.cmd`. On Linux and macOS, check that `~/.local/bin` is on the PATH and that `pwsh` runs.

If Claude Code's update reports "verification impossible", "telechargement bloque" or "deja en cours ailleurs", it timed out (20 seconds without a recognised answer, 90 seconds without download progress) or another session is updating. clm tries up to 3 times, waits up to 60 seconds for the other session, and the menu stays usable. `clm --no-update` skips it.

An account that shows "non connecte", "jeton expire" or "jeton refuse" needs one launch from the menu and a `/login`. After a "pause API" the bars keep their last values until the pause ends.

If the status line shows no quotas, check that the account folder is listed in `accounts.json` and that the `claude-statusline` state folder exists: the hook does nothing for a folder clm does not know, and writes nothing when that folder is absent. Run `clm --help` for every option, key, variable and file.
