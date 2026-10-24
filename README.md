# dsh-workspace-launcher — v2.0.0 for DeepSeek Harness 0.2.x

Open the current session's workspace directory in **File Explorer**, **VS Code**, or a **terminal**, or copy its path, straight from the **Session header**.

> 中文文档见 [README.zh.md](README.zh.md)。

| | |
|---|---|
| Plugin | `dsh-workspace-launcher` 2.0.0 |
| Harness | DeepSeek Harness **0.2.1-rc.2** (Desktop or `dsh web`) |
| Platform | Windows first-class; macOS/Linux supported by the host half |
| License | MIT |

## What changed from 0.1.x

0.1.x patched `@deepseek-ai/dsh-client-ui-workspace`'s compiled bundle to inject five rows into the workspace “...” menu, then registered a plugin. DSH 0.2 builds client packages as dynamic bundles, so editing an installed bundle is unsafe and unsupported.

2.0 keeps the same host route and moves the UI to the documented slot API:

| 0.1.x | 2.0.0 |
|---|---|
| Patched `dsh-client-ui-workspace` bundle | No patches at all |
| Rows in the Workspace “...” menu | **The same menu**, with the four rows appended to the shipped Rename/Delete menu; plus a Session-header menu |
| Workspace path came from the patched row | `cwd` from `useSessions`, workspace `path` as fallback |
| Toasts injected into `document.body` | Status line inside the plugin's own popover |

DSH 0.2 has no workspace-menu slot (only session row menus are extendable). The plugin therefore remembers the workspace whose “...” button was pressed (its `aria-label` carries the title), watches for the shipped menu to appear, and appends the four rows inside that menu. The built-in Rename/Delete rows and their behavior are untouched.

DSH 0.2 also ships a built-in **Open In…** split button (`dsh-client-ui-open-in-app`) that opens the session directory in any installed application from the application catalog. This plugin stays complementary: it guarantees Explorer, VS Code, a terminal, and a clipboard copy even when the catalog probe finds nothing.

## What it does

The Session header gains an **Open workspace** button, and a **right-click on a workspace row** in the sidebar opens the same menu:

- **Open in File Explorer** — `explorer.exe` via `cmd /c start`, Finder, or `xdg-open`.
- **Open in VS Code** — `code`, with Windows registry/`App Paths`/standard-path fallbacks.
- **Open in terminal** — Windows Terminal (`wt.exe`), falling back to a visible PowerShell window; Terminal.app or `x-terminal-emulator` elsewhere.
- **Copy workspace path** — clipboard, with a `document.execCommand` fallback.

The host half exposes `POST /workspace-open/open` with `{ path, app }`. It validates that the path is absolute, strips trailing separators (Windows quoting), spawns detached with stdio ignored, and never blocks the harness. Failures are returned as JSON and shown in the popover.

## Install

### Plugin Manager (Desktop)

Install this folder as a bundle and enable `dsh-workspace-launcher`. The bundle lives in `plugin/dsh-workspace-launcher/`.

### CLI

```bash
dsh plugin --profile <profile> add /absolute/path/to/plugin/dsh-workspace-launcher
```

### Manual

Link `plugin/dsh-workspace-launcher` into the profile's `node_modules`, then add to `cordis.patch.yml`:

```yaml
- insert:
    - id: workspace-open
      name: 'dsh-workspace-launcher'
```

If you used the 0.1.x installer, **restore the original** `@deepseek-ai/dsh-client-ui-workspace` package first (reinstall the Harness or the package). The old patch must not be applied to 0.2 bundles.

## Verify

1. Open a session whose workspace directory exists.
2. The Session header shows **Open workspace**; hover it — the tooltip is the resolved directory.
3. Click → four menu rows. Each launches the expected application.
4. “Copy workspace path” copies the directory; the popover shows `Path copied`.
5. A session without a directory shows `This session has no workspace path`.

## Uninstall

Disable/remove the bundle and reload. Nothing else was modified.

## Repository layout

```
plugin/dsh-workspace-launcher/
  package.json            dsh.bundle.patch + dsh.client
  cordis.patch.yml
  lib/index.js            Host half: /workspace-open/open route
  lib/client.js           Browser half: Session-header menu
install.ps1 / install.sh  Bundle installer (no patches)
```

## License

MIT.
