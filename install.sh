#!/usr/bin/env bash
# install.sh — deploy dsh-workspace-launcher into a local DeepSeek Harness (dsh) web
# profile (macOS / Linux; the plugin is Windows-first, macOS/Linux are best-effort).
#
# Usage:
#   ./install.sh          # install (idempotent)
#   ./install.sh --uninstall
#
# Steps: copy plugin -> <DSH_HOME>/profiles/node_modules, patch the workspace
# client bundle (python3 literal patch), register in cordis.patch.yml. Then
# restart the harness yourself (dsh web).

set -euo pipefail
REPO="$(cd "$(dirname "$0")" && pwd)"
DSH_HOME="${DSH_HOME:-$HOME/.dsh}"
PROFILE="$DSH_HOME/profiles"
TARGET="$PROFILE/node_modules/dsh-workspace-launcher"
WS_CLIENT="$PROFILE/node_modules/@deepseek-ai/dsh-client-ui-workspace/lib/client.js"
CORDIS="$PROFILE/web/cordis.patch.yml"
MARKER='dsh-workspace-open: reveal the workspace folder'

log() { printf '[dsh-workspace-launcher] %s\n' "$*"; }

if [[ "${1:-}" == "--uninstall" ]]; then
  rm -rf "$TARGET" && log "removed $TARGET"
  if [[ -f "$WS_CLIENT" ]] && grep -qF "$MARKER" "$WS_CLIENT"; then
    log "workspace client is patched — reverse the patch manually (see README 'For AI', or reinstall @deepseek-ai/dsh-client-ui-workspace@0.1.0-rc.6)"
  fi
  log "uninstall done; restart the harness to apply"
  exit 0
fi

# 1. plugin package
mkdir -p "$TARGET/lib"
cp "$REPO/plugin/dsh-workspace-launcher/package.json" "$TARGET/package.json"
cp "$REPO/plugin/dsh-workspace-launcher/lib/index.js" "$TARGET/lib/index.js"
cp "$REPO/plugin/dsh-workspace-launcher/lib/client.js" "$TARGET/lib/client.js"
log "plugin copied -> $TARGET"

# 2. workspace client patch (python3 literal patch, LF safe)
if grep -qF "$MARKER" "$WS_CLIENT"; then
  log "workspace client already patched, skipping"
else
  python3 - "$WS_CLIENT" <<'PY'
import re, sys
path = sys.argv[1]
src = open(path, encoding="utf-8", newline="").read()

menu = '''\t\t\t/* dsh-workspace-open: reveal the workspace folder in an external tool. */
\t\t\tif (typeof row.cwd === "string" && row.cwd !== "") {
\t\t\t\tworkspaceMenuItems.push({
\t\t\t\t\tid: "open-explorer",
\t\t\t\t\tlabel: t("open.explorer"),
\t\t\t\t\ticon: (0, react_jsx_runtime.jsx)(_deepseek_ai_dsh_client_ui_primitives.IconFolderOpenOutline16, {})
\t\t\t\t}, {
\t\t\t\t\tid: "open-vscode",
\t\t\t\t\tlabel: t("open.vscode"),
\t\t\t\t\ticon: (0, react_jsx_runtime.jsx)(_deepseek_ai_dsh_client_ui_primitives.IconCodeOutline16, {})
\t\t\t\t}, {
\t\t\t\t\tid: "open-terminal",
\t\t\t\t\tlabel: t("open.terminal"),
\t\t\t\t\ticon: (0, react_jsx_runtime.jsx)("span", {
\t\t\t\t\t\tstyle: { width: 14, height: 14, display: "inline-flex", alignItems: "center", justifyContent: "center", fontSize: 9, fontWeight: 600 },
\t\t\t\t\t\tchildren: ">_"
\t\t\t\t\t})
\t\t\t\t}, {
\t\t\t\t\tid: "copy-absolute",
\t\t\t\t\tlabel: t("copy.absolute"),
\t\t\t\t\ticon: (0, react_jsx_runtime.jsx)(_deepseek_ai_dsh_client_ui_primitives.IconLinkOutline16, {})
\t\t\t\t}, {
\t\t\t\t\tid: "copy-relative",
\t\t\t\t\tlabel: t("copy.relative"),
\t\t\t\t\ticon: (0, react_jsx_runtime.jsx)(_deepseek_ai_dsh_client_ui_primitives.IconCopyOutline16, {})
\t\t\t\t});
\t\t\t}
'''

onsel_new = '''\t\t\t\t\t\t\tonSelect: (id) => {
\t\t\t\t\t\t\t\tsetMenuOpen(false);
\t\t\t\t\t\t\t\tif (id === "rename") actions.rename();
\t\t\t\t\t\t\t\telse if (id === "delete") actions.delete();
\t\t\t\t\t\t\t\telse if (id === "open-explorer" || id === "open-vscode" || id === "open-terminal") {
\t\t\t\t\t\t\t\t\tconst cwd = row.cwd;
\t\t\t\t\t\t\t\t\tif (typeof cwd !== "string" || cwd === "") return;
\t\t\t\t\t\t\t\t\tfetch("/workspace-open/open", {
\t\t\t\t\t\t\t\t\t\tmethod: "POST",
\t\t\t\t\t\t\t\t\t\theaders: { "content-type": "application/json" },
\t\t\t\t\t\t\t\t\t\tbody: JSON.stringify({ path: cwd, app: id.slice(5) })
\t\t\t\t\t\t\t\t\t}).then((response) => response.json()).then((payload) => {
\t\t\t\t\t\t\t\t\t\tif (!payload.ok) throw new Error(payload.error || "open failed"); showNotice(t("toast.opened", { app: id === "open-explorer" ? t("open.explorer") : id === "open-vscode" ? t("open.vscode") : t("open.terminal") }), false);
\t\t\t\t\t\t\t\t\t}).catch((error) => {
\t\t\t\t\t\t\t\t\t\tshowNotice(t("toast.openFailed", { message: String(error && error.message || error) }), true);
\t\t\t\t\t\t\t\t\t});
\t\t\t\t\t\t\t\t} else if (id === "copy-absolute" || id === "copy-relative") {
\t\t\t\t\t\t\t\t\tconst cwd = row.cwd;
\t\t\t\t\t\t\t\t\tif (typeof cwd !== "string" || cwd === "") return;
\t\t\t\t\t\t\t\t\tconst value = id === "copy-absolute" ? cwd : (cwd.replace(/[/\\\\]+$/, "").split(/[/\\\\]/).pop() || cwd);
\t\t\t\t\t\t\t\t\t_deepseek_ai_dsh_client_ui_primitives.writeClipboard(value).then((ok) => {
\t\t\t\t\t\t\t\t\t\tshowNotice(ok ? t("toast.copied", { text: value }) : t("toast.copyFailed"), !ok);
\t\t\t\t\t\t\t\t\t});
\t\t\t\t\t\t\t\t}
\t\t\t\t\t\t\t},
'''
onsel_old = '''\t\t\t\t\t\t\tonSelect: (id) => {
\t\t\t\t\t\t\t\tsetMenuOpen(false);
\t\t\t\t\t\t\t\t/* v8 ignore next -- workspaceMenuItems carries exactly these two rows today. */
\t\t\t\t\t\t\t\tif (id !== "rename" && id !== "delete") return;
\t\t\t\t\t\t\t\tif (id === "rename") actions.rename();
\t\t\t\t\t\t\t\telse actions.delete();
\t\t\t\t\t\t\t},
'''

notice = '''\t\t/** Transient viewport toast for clipboard/open feedback (best-effort). */
\t\tfunction showNotice(text, isError) {
\t\t\ttry {
\t\t\t\tconst el = document.createElement("div");
\t\t\t\tel.textContent = text;
\t\t\t\tel.setAttribute("role", isError ? "alert" : "status");
\t\t\t\tel.style.cssText = "position:fixed;z-index:10000;right:16px;bottom:16px;max-width:70vw;padding:8px 12px;border-radius:10px;font-size:13px;line-height:18px;box-shadow:0 4px 16px rgba(0,0,0,.18);background:" + (isError ? "#c42b1c" : "#1f2328") + ";color:#fff";
\t\t\t\tdocument.body.appendChild(el);
\t\t\t\tsetTimeout(() => el.remove(), 2500);
\t\t\t} catch (_error) { /* notification is best-effort */ }
\t\t}
'''

zh = '''\t\t\t"open.explorer": "在资源管理器中打开",
\t\t\t"open.vscode": "在 VS Code 中打开",
\t\t\t"open.terminal": "在终端中打开",
\t\t\t"copy.absolute": "复制绝对路径",
\t\t\t"copy.relative": "复制相对路径",
\t\t\t"toast.copied": "已复制：{text}",
\t\t\t"toast.copyFailed": "复制失败",
\t\t\t"toast.openFailed": "打开失败：{message}",
\t\t\t"toast.opened": "已打开：{app}",
'''

en = '''\t\t\t"open.explorer": "Open in File Explorer",
\t\t\t"open.vscode": "Open in VS Code",
\t\t\t"open.terminal": "Open in terminal",
\t\t\t"copy.absolute": "Copy absolute path",
\t\t\t"copy.relative": "Copy relative path",
\t\t\t"toast.copied": "Copied: {text}",
\t\t\t"toast.copyFailed": "Copy failed",
\t\t\t"toast.openFailed": "Failed to open: {message}",
\t\t\t"toast.opened": "Opened: {app}",
'''

if '}];\n' in src and 'rowHalf' in src and 'menu.archiveSession' in src and onsel_old in src:
    src = src.replace('}];\n', '}];\n' + menu + '\n', 1)
    src = src.replace(onsel_old, onsel_new, 1)
    anchor = 'return e.clientY < rect.top + rect.height / 2 ? "before" : "after";'
    src = src.replace(anchor + '\n', anchor + '\n' + notice + '\n', 1)
    src = src.replace('"menu.archiveSession": "归档会话",\n', '"menu.archiveSession": "归档会话",\n' + zh + '\n', 1)
    src = src.replace('"menu.archiveSession": "Archive session",\n', '"menu.archiveSession": "Archive session",\n' + en + '\n', 1)
    open(path, "w", encoding="utf-8", newline="").write(src)
    print("[dsh-workspace-launcher] workspace client patched (python3)")
else:
    print("[dsh-workspace-launcher] ERROR: workspace client version mismatch; patch anchors not found", file=sys.stderr)
    sys.exit(1)
PY
fi

# 3. cordis registration
if grep -q 'dsh-workspace-launcher' "$CORDIS"; then
  log "cordis entry already present, skipping"
else
  cat >> "$CORDIS" <<'EOF'

# dsh-workspace-launcher: open the current workspace in File Explorer / VS Code /
# a terminal from the session header (bundle in profiles/node_modules/dsh-workspace-launcher).
- insert:
    - id: workspace-open
      name: 'dsh-workspace-launcher'
EOF
  log "cordis entry added -> $CORDIS"
fi

log "installed. Restart the harness (run 'dsh web --host 127.0.0.1 --port 3080' again) and hard-refresh the browser."
