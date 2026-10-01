# Writing an Octet plugin

An Octet plugin is a folder with a `plugin.json` and the scripts it runs. Octet draws the UI; your plugin decides what goes in it, by running shell commands and reading what they print. No Swift, no build step, no Octet release: publish to this registry and anyone can install it from the Marketplace.

The fastest start is to copy [`template/`](template/), which has one of each common piece, and change it.

- [The manifest](#the-manifest)
- [How commands run](#how-commands-run)
- [Surfaces](#surfaces): [completions](#completions), [status bar chips](#status-bar-chips), [right-click menu items](#right-click-menu-items), [panels](#panels), [workspace icons](#workspace-icons), [model policies](#model-policies), [runtime icons](#runtime-icons)
- [Settings](#settings)
- [macOS, Linux and Windows](#macos-linux-and-windows)
- [Trying it](#trying-it) and [Publishing](#publishing)

## The manifest

```json
{
  "id": "my-plugin",
  "name": "My Plugin",
  "version": "1.0.0",
  "description": "One or two sentences for the Marketplace.",
  "author": "you",
  "keywords": ["search", "words"],
  "octet": 1,
  "platforms": ["macos", "linux"],
  "settings": [],
  "contributes": { }
}
```

| Field | |
|---|---|
| `id` | Lowercase letters, digits, `.`, `-`, `_`. The folder is named after it, and it never changes. |
| `version` | Dotted numbers. Raise it with every change: installed copies update when the registry's is newer. |
| `octet` | The manifest format, `1`. |
| `platforms` | Where it runs; default `["macos", "linux"]`. The Marketplace lists only what runs where it's open. |
| `settings` | What to ask the person for; see [Settings](#settings). |
| `contributes` | The surfaces below. Leave out what you don't use. |

Unknown keys are ignored, so a plugin written for a newer Octet still loads on an older one, without what the older one doesn't know.

## How commands run

Every `run` and `act` is a shell command: `sh -c` on macOS and Linux, PowerShell on Windows (see [platforms](#macos-linux-and-windows)). Put your logic in a script in the plugin folder and run it by path:

```json
"run": "sh \"$OCTET_PLUGIN_DIR/scripts/chip.sh\""
```

Commands run in the folder of the pane, workspace or tab they're for, with your login shell's `PATH`, and see these (completions get only `OCTET_PLUGIN_DIR` and your settings; they run in the pane's folder):

| Variable | |
|---|---|
| `OCTET_PLUGIN_DIR` | The plugin's own folder. |
| `OCTET_CWD` | The folder the command is for (also its working directory). |
| `OCTET_REPO_ROOT` | That folder's git repository, else the folder itself. |
| `OCTET_SHELL_PID` | The pane's shell, for status chips: to look at what's running in it. |
| `OCTET_SSH_HOST`, `OCTET_SSH_USER` | Set for chips in a pane that's logged into another machine. |
| `OCTET_PLUGIN_SETTINGS_URL` | Where the person fills in your [settings](#settings), when you have some. |
| your settings | Each [setting](#settings) under its own name. |

Commands have a time limit (`timeoutSeconds`, a few seconds by default) and are stopped after it, so keep them quick, and cache anything slow yourself. Write only to standard output what Octet should read; errors to standard error are ignored.

A plugin runs commands as the person who installs it. Read only what you need, never print secrets, and don't change anything without being asked (a menu item or a panel action is being asked).

## Surfaces

### Completions

Values for a command's argument while typing, e.g. repositories after `git clone`.

```json
"completions": [{
  "command": "git", "path": ["clone"],
  "run": "sh \"$OCTET_PLUGIN_DIR/scripts/repos.sh\"",
  "kind": "repository", "cacheSeconds": 300, "perFolder": false, "opensMenu": true
}]
```

Print one value per line, or `value<TAB>label<TAB>detail`. `kind` is `branch` (default), `repository`, `file`, `directory`, `command` or `flag`, and sets the row's icon. `path` names the subcommands before the argument (they're added if the command doesn't have them). `cacheSeconds` keeps values that long, `perFolder: false` shares them across folders, `opensMenu` opens the menu as soon as `path` is typed, `prefetchWhenTyping` starts fetching once the line starts with that text, and `firstArgumentOnly` leaves later arguments to file completion.

### Status bar chips

A chip under the terminal, re-run every `refreshSeconds` (default 10).

```json
"statusItems": [{
  "id": "todos", "name": "TODOs", "summary": "TODO comments in the repository",
  "sample": "4 TODO", "symbol": "checklist", "color": "E5C07B",
  "run": "sh \"$OCTET_PLUGIN_DIR/scripts/chip.sh\"",
  "whenFiles": [".git"], "refreshSeconds": 30, "scope": "local", "enabledByDefault": true
}]
```

The first line printed is the chip's text; printing nothing hides it. Later lines can set:

```
4 TODO
tone: warning
help: src/app.ts:12 TODO: retry\nsrc/db.ts:40 FIXME: pool size
url: https://example.com
```

`tone` is `normal`, `muted`, `success`, `warning` or `danger`. `help` is shown on hover (`\n` breaks a line). `url` opens on click: a web page, or your own `$OCTET_PLUGIN_SETTINGS_URL`, which opens your settings right on the chip. `symbol` is an SF Symbol, or set `icon` to an SVG or PNG in your folder (tinted with `color`). `whenFiles` runs the chip only when one of those files or folders is in the pane's folder or above it, up to the repository root. `scope` is `local` (default), `remote` (only over SSH) or `any`. People arrange chips in Settings › Status Bar; `enabledByDefault` puts yours there from the start.

### Right-click menu items

An item in a tab's or workspace's right-click menu that starts something in a new tab.

```json
"menuItems": [{
  "id": "log", "title": "Show Recent Commits", "in": ["tab", "workspace"],
  "whenFiles": [".git"], "run": "sh \"$OCTET_PLUGIN_DIR/scripts/log.sh\""
}]
```

The first line printed is a command Octet runs in a new tab of that workspace. Later lines can set `label: …` (the tab's name) and `cwd: …` (where it runs). Print only `message: …` to say why there's nothing to start. The tab's shell stays open when the command ends, so its output can be read.

### Panels

A button at the right of the tab bar, beside Todos and Git, opening a list with actions. The button shows while `run` prints something, and its panel is read again while open.

```json
"panels": [{
  "id": "todos", "title": "TODOs", "symbol": "checklist",
  "run": "sh \"$OCTET_PLUGIN_DIR/scripts/panel.sh\"",
  "act": "sh \"$OCTET_PLUGIN_DIR/scripts/act.sh\"",
  "whenFiles": [".git"], "refreshSeconds": 30
}]
```

`run` prints JSON:

```json
{
  "badge": "4", "tone": "warning",
  "message": "Shown when there are no rows",
  "rows": [
    { "id": "src/app.ts:12", "title": "retry", "detail": "src/app.ts:12", "tone": "warning",
      "url": "https://…", "actions": [{ "id": "open", "title": "Open", "symbol": "pencil" }] }
  ],
  "actions": [{ "id": "clear", "title": "Clear All", "confirm": "Remove every TODO?" }]
}
```

Clicking an action runs `act` with `OCTET_ACTION` set to the action's id, and `OCTET_ITEM` to its row's id for a row's action. `confirm` asks first. What `act` prints is read like a menu item's output: a command opens in a new tab (and the panel closes), `message: …` is shown, and nothing just reads the panel again.

### Workspace icons

The picture for a workspace in the sidebar, like the project's favicon or app icon.

```json
"workspaceIcons": [{ "id": "project", "run": "sh \"$OCTET_PLUGIN_DIR/find-icon.sh\"", "refreshSeconds": 600 }]
```

Run in the workspace's folder; print the path of an image inside that folder (PNG, JPEG, ICO, ICNS, SVG, WebP or GIF), relative or absolute. Anything outside the folder is ignored. Printing nothing leaves the workspace as it was. See `plugins/project-icons`.

### Model policies

Pick the model and effort Octet's own Claude and Codex conversations run on, from how much of the account's allowance is used.

```json
"modelPolicies": [{ "id": "usage", "agents": ["claude", "codex"], "run": "sh \"$OCTET_PLUGIN_DIR/switch.sh\"" }]
```

Run between turns, in the conversation's folder, whenever the usage or the person's pick changes. Besides the usual variables it sees:

| Variable | |
|---|---|
| `OCTET_AGENT` | `claude` or `codex`. |
| `OCTET_MODEL`, `OCTET_EFFORT` | The model and effort the person picked (effort empty for the model's default). |
| `OCTET_MODELS` | The model ids it can be moved to, space-separated, as the picker lists them. |
| `OCTET_EFFORTS` | The efforts the picked model takes. |
| `OCTET_USAGE_<WINDOW>` | Percent used of each running window: `OCTET_USAGE_5H`, `OCTET_USAGE_7D`, `OCTET_USAGE_7D_OPUS`. |
| `OCTET_USAGE`, `OCTET_USAGE_WINDOW`, `OCTET_USAGE_RESETS_AT` | The fullest window's percent, name, and reset time (Unix seconds). |

Print `model: <id>` and/or `effort: <level>`, and optionally `message: <why>`, which Octet shows in the conversation. A model the agent doesn't offer, or an effort the model doesn't take, is ignored. Print nothing to keep the person's pick: once a switch is no longer called for, Octet moves the conversation back by itself. If the person picks a model while switched, theirs stands until the policy stops calling for a switch. `agents` defaults to both. See `plugins/model-switcher`.

### Runtime icons

A mark on tabs for what their pane is running. These run nothing: they match process arguments.

```json
"runtimes": [{
  "id": "vite", "name": "Vite", "icon": "icons/vite.svg", "color": "646CFF",
  "match": ["\\bvite\\b"], "refineByDependency": [["@sveltejs/kit", "sveltekit"]]
}],
"runtimeIgnore": ["nvim"]
```

`match` is regular expressions (case-insensitive) tried against each process under the pane's shell, its arguments with paths shortened to their last part (`node /x/node_modules/.bin/vite` is matched as `node vite`). The first matching rule wins. `refineByDependency` switches to a more specific rule of yours when the project depends on a package. `runtimeIgnore` names executables whose children aren't the pane's runtime. See `plugins/dev-runtimes`.

## Settings

Ask for what your plugin needs, and Octet does the rest: a form in Settings › Plugins, secrets in the Keychain, and every command gets the values in its environment, never on a command line.

```json
"settings": [
  { "id": "TODO_PATTERN", "title": "What to look for", "placeholder": "TODO|FIXME",
    "detail": "A regular expression for git grep." },
  { "id": "SERVICE_TOKEN", "title": "API token", "secret": true,
    "link": "https://example.com/tokens" }
]
```

`id` is the environment variable your commands read it from (capitals, digits and `_`, not Octet's own `OCTET_` names or ones like `PATH`). `secret` makes a password field kept in the Keychain. `link` adds a button to where the value is made. When something you need is missing, print `url: $OCTET_PLUGIN_SETTINGS_URL` from a chip: clicking it asks for your settings right there, and the chip runs again once they're saved.

## macOS, Linux and Windows

A plain-string `run` is a POSIX `sh` command for macOS and Linux. To support Windows too, give one per platform; `unix` covers macOS and Linux, and `windows` is PowerShell:

```json
"run": { "unix": "sh \"$OCTET_PLUGIN_DIR/chip.sh\"",
         "windows": "& \"$env:OCTET_PLUGIN_DIR\\chip.ps1\"" }
```

A contribution with no command for the platform Octet is running on is left out there; the rest of the plugin still works. List where it runs in `platforms`. Prefer tools every platform has (`git`, `curl`); where one isn't, check with `command -v` and fall back, as `plugins/issues/scripts/jira-lib.sh` does.

## Trying it

1. Copy your plugin's folder to `~/Library/Application Support/Octet/Plugins/<id>` (Settings › Plugins › Plugin folder › Reveal).
2. Settings › Plugins › Reload, then turn it on in the Marketplace. A folder added by hand starts off, since what it contributes runs as you.
3. If it doesn't load, Settings › Plugins lists why under Couldn't load.

Run your scripts in a terminal the way Octet does, to see what they print:

```sh
cd ~/code/some-project
OCTET_PLUGIN_DIR=~/path/to/my-plugin OCTET_CWD=$PWD OCTET_REPO_ROOT=$PWD sh ~/path/to/my-plugin/scripts/chip.sh
```

Before publishing, check your scripts with `sh -n` and `shellcheck --shell=sh`; this repository's CI does both.

## Publishing

- **In this repository:** add your folder under `plugins/`, run `scripts/build-registry.py`, and open a pull request. CI checks the manifest, that every script a command names ships with it, and that the scripts parse.
- **From your own repository:** add an entry to `community.json` naming your repository, a pinned `ref` and your files, then run `scripts/build-registry.py --fetch` to fill in their checksums. See the README.

Once merged, it's in the Marketplace. To ship a change, raise `version`; installed copies update on their own. An `octet://plugin?id=<id>` link offers to install it, for a README or a web page.
