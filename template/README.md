# Plugin template

A working plugin to start from: a status bar chip, a panel with actions, a right-click item, a completion and a setting, all around a git repository's TODO comments. Read [PLUGINS.md](../PLUGINS.md) for what each part can do.

1. Copy this folder to `plugins/<your-id>` and change `id`, `name`, `description` and `author` in `plugin.json`.
2. Keep the surfaces you need, delete the rest from `contributes` and `scripts/`.
3. Try it: copy the folder to `~/Library/Application Support/Octet/Plugins/<your-id>`, then Settings › Plugins › Reload and turn it on in the Marketplace.
4. Publish: `scripts/build-registry.py`, then a pull request.

This folder isn't in the registry; only `plugins/` is.
