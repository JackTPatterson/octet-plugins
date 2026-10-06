# Octet plugins

The Marketplace's **Plugins** section lists agent plugins and terminal plugins together; filter by *Agents* or *Terminal*. Terminal plugins come from this repository: `registry.json` is the index Octet downloads, and each entry names a plugin's files, their SHA-256, and the GitHub repository they're downloaded from. Octet checks every file against its checksum and the manifest's id against the entry before installing into `~/Library/Application Support/Octet/Plugins/<id>`.

**Writing one?** Read [PLUGINS.md](PLUGINS.md), the guide to every part a plugin can add, and start from [`template/`](template/).

## Octet's own plugins

Each is a folder in `plugins/` with a `plugin.json`. After changing one, bump its `version` (installed copies are offered the update) and rebuild the index:

```sh
scripts/build-registry.py
```

CI checks every pull request: manifests are valid, every script a command names ships with its plugin, shell scripts parse, and `registry.json` matches the files (`scripts/build-registry.py --check`). Octet reads `registry.json` from `main`, so merging is publishing.

## Install links and updates

`octet://plugin?id=<id>` opens Octet and offers to install that plugin from the registry, after saying where it comes from. Use it as an "Install in Octet" link in a README or on a web page, e.g. [octet://plugin?id=containers](octet://plugin?id=containers).

Octet checks the registry at launch and every few hours. When a plugin's `version` here is newer than the installed one, Octet updates it automatically, or tells you if automatic updates are off (Settings › Plugins). It updates only plugins installed from the registry, and keeps each one turned on or off as it was. So to ship a fix, bump `version` and rebuild the index.

## Publishing yours

Keep the plugin in your own public GitHub repository, then open a pull request adding an entry to `community.json`:

```json
{ "id": "my-plugin", "name": "My Plugin", "description": "What it adds", "author": "you",
  "version": "1.0.0", "keywords": ["..."], "repo": "you/octet-my-plugin", "ref": "v1.0.0",
  "path": "", "files": ["plugin.json", "scripts/chip.sh"] }
```

Pin `ref` to a tag or commit. `scripts/build-registry.py --fetch` fills in the checksums, so a later change to the repository can't reach anyone without a new entry.

Plugins run shell commands as the person who installs them; the registry is reviewed, and each plugin is off until someone installs it from the Marketplace. A plugin can contribute terminal completions, status bar chips, runtime icons, items in a tab's or workspace's right-click menu (`menuItems`: a command that prints what to start in a new tab, like `dev-server`), and buttons at the right of the tab bar beside Todos and Git (`panels`: `run` prints the panel as JSON, a badge and rows with actions, and `act` runs an action with `OCTET_ACTION` and `OCTET_ITEM` set, like `containers`), and a workspace's icon in the sidebar (`workspaceIcons`: a command that prints the path of an image inside the workspace's folder, like `project-icons`), and the model and effort conversations run on as usage fills (`modelPolicies`, like `model-switcher`); see any plugin here for the manifest format. (The app itself holds only what stands for native features, like Other Macs.)

## macOS, Linux and Windows

One plugin, one registry, every platform Octet runs on. Manifests, the index and checksums are plain JSON; only the commands differ.

- A `run` that is a string is a POSIX `sh` command, for macOS and Linux.
- A `run` can instead name a command per platform: `unix` (macOS and Linux), `macos`, `linux`, or `windows`, a PowerShell command. A contribution with no command for the platform Octet is running on is left out there; the rest of the plugin still works.

  ```json
  "run": { "unix": "sh \"$OCTET_PLUGIN_DIR/chip.sh\"",
           "windows": "& \"$env:OCTET_PLUGIN_DIR\\chip.ps1\"" }
  ```

- `platforms` in `plugin.json` says where it runs (default `["macos", "linux"]`); the index carries it, and the Marketplace lists only what runs where it's open. Runtime icons run nothing, so a plugin of only those can list all three.
- Every command sees the same environment everywhere: `OCTET_PLUGIN_DIR`, and for chips `OCTET_CWD`, `OCTET_REPO_ROOT`, `OCTET_SHELL_PID`, `OCTET_SSH_HOST`, `OCTET_SSH_USER`. Output is the same text on every platform.
- Prefer tools every platform has (`git`, `gh`, `curl`). Where one isn't (`osascript`, the Keychain), check with `command -v` and fall back, as `issues/scripts/jira-lib.sh` does with Node and `secret-tool` on Linux. `github-repos` has a `list-repos.ps1` beside its `list-repos.sh` as the example for Windows.
