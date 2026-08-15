# install.ps1 — deploy dsh-workspace-launcher into a local DeepSeek Harness (dsh) web profile.
#
# Usage:
#   .\install.ps1                 # install (idempotent) and restart the harness
#   .\install.ps1 -NoRestart      # install only; you restart the harness yourself
#   .\install.ps1 -Uninstall      # remove the plugin, undo the patch, restore cordis
#
# What it does:
#   1. Copies plugin/dsh-workspace-launcher into <DSH_HOME>\profiles\node_modules\
#   2. Patches @deepseek-ai/dsh-client-ui-workspace's client bundle (adds the
#      workspace row menu entries). Uses patch/dsh-client-ui-workspace.patch via
#      `git apply` (LF-safe); falls back to literal string insertion when git is
#      unavailable.
#   3. Registers the plugin in <DSH_HOME>\profiles\web\cordis.patch.yml.
#   4. Restarts the dsh web harness (unless -NoRestart).
#
# The whole flow is idempotent: running it twice is a no-op.

param(
    [switch]$NoRestart,
    [switch]$Uninstall
)

$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$dshHome = if ($env:DSH_HOME) { $env:DSH_HOME } else { Join-Path $env:USERPROFILE '.dsh' }
$profileRoot = Join-Path $dshHome 'profiles'
$pluginTarget = Join-Path $profileRoot 'node_modules\dsh-workspace-launcher'
$wsClient = Join-Path $profileRoot 'node_modules\@deepseek-ai\dsh-client-ui-workspace\lib\client.js'
$cordis = Join-Path $profileRoot 'web\cordis.patch.yml'
$patchFile = Join-Path $repoRoot 'patch\dsh-client-ui-workspace.patch'
$marker = 'dsh-workspace-open: reveal the workspace folder'

function Write-Step([string]$msg) { Write-Host "[dsh-workspace-launcher] $msg" -ForegroundColor Cyan }

# ---------- uninstall ----------
if ($Uninstall) {
    if (Test-Path $pluginTarget) { Remove-Item $pluginTarget -Recurse -Force; Write-Step "removed $pluginTarget" }
    if (Test-Path $wsClient) {
        $c = [System.IO.File]::ReadAllText($wsClient)
        if ($c.Contains($marker)) {
            $git = Get-Command git -ErrorAction SilentlyContinue
            if ($git) {
                Push-Location (Split-Path $wsClient)
                git -c core.autocrlf=false apply --unsafe-paths --directory=(Split-Path $wsClient) -R $patchFile 2>$null
                Pop-Location
                Write-Step "reverted workspace client patch (git)"
            } else {
                Write-Error "Uninstall needs git (to reverse the patch) or a pristine client.js. Reinstall the package @deepseek-ai/dsh-client-ui-workspace@0.1.0-rc.6 instead."
                exit 1
            }
        } else {
            Write-Step "workspace client not patched, nothing to undo"
        }
    }
    if (Test-Path $cordis) {
        $y = Get-Content $cordis -Raw
        if ($y -match '(?m)^# dsh-workspace-launcher.*?(?=^# |\z)') {
            $y = [regex]::Replace($y, '(?m)^# dsh-workspace-launcher.*?(?=^# |\z)', '')
            Set-Content -Path $cordis -Value $y -Encoding utf8 -NoNewline
            Write-Step "removed cordis entry"
        }
    }
    Write-Step "uninstall done. Restart the harness (start-dsh.bat) to apply."
    exit 0
}

# ---------- 1. plugin package ----------
New-Item -ItemType Directory -Force -Path $pluginTarget, (Join-Path $pluginTarget 'lib') | Out-Null
Copy-Item (Join-Path $repoRoot 'plugin\dsh-workspace-launcher\package.json') (Join-Path $pluginTarget 'package.json') -Force
Copy-Item (Join-Path $repoRoot 'plugin\dsh-workspace-launcher\lib\index.js') (Join-Path $pluginTarget 'lib\index.js') -Force
Copy-Item (Join-Path $repoRoot 'plugin\dsh-workspace-launcher\lib\client.js') (Join-Path $pluginTarget 'lib\client.js') -Force
Write-Step "plugin copied -> $pluginTarget"

# ---------- 2. workspace client patch ----------
if (-not (Test-Path $wsClient)) { Write-Error "workspace client not found: $wsClient (is dsh-web-app 0.1.0-rc.6 installed?)"; exit 1 }
$c = [System.IO.File]::ReadAllText($wsClient)
if ($c.Contains($marker)) {
    Write-Step "workspace client already patched, skipping"
} else {
    $git = Get-Command git -ErrorAction SilentlyContinue
    if ($git) {
        Push-Location (Split-Path $wsClient)
        git -c core.autocrlf=false apply --unsafe-paths --directory=(Split-Path $wsClient) $patchFile
        if ($LASTEXITCODE -ne 0) { Pop-Location; Write-Error "git apply failed — the installed dsh-client-ui-workspace version may differ. See README (For AI: Debugging)."; exit 1 }
        Pop-Location
        Write-Step "workspace client patched (git)"
    } else {
        Write-Step "git not found; applying literal patch (PowerShell)"
        function Lf($s) { $s.Replace("`r`n", "`n") }
        $onSelectNew = Lf @"
							onSelect: (id) => {
								setMenuOpen(false);
								if (id === "rename") actions.rename();
								else if (id === "delete") actions.delete();
								else if (id === "open-explorer" || id === "open-vscode" || id === "open-terminal") {
									const cwd = row.cwd;
									if (typeof cwd !== "string" || cwd === "") return;
									fetch("/workspace-open/open", {
										method: "POST",
										headers: { "content-type": "application/json" },
										body: JSON.stringify({ path: cwd, app: id.slice(5) })
									}).then((response) => response.json()).then((payload) => {
										if (!payload.ok) throw new Error(payload.error || "open failed"); showNotice(t("toast.opened", { app: id === "open-explorer" ? t("open.explorer") : id === "open-vscode" ? t("open.vscode") : t("open.terminal") }), false);
									}).catch((error) => {
										showNotice(t("toast.openFailed", { message: String(error && error.message || error) }), true);
									});
								} else if (id === "copy-absolute" || id === "copy-relative") {
									const cwd = row.cwd;
									if (typeof cwd !== "string" || cwd === "") return;
									const value = id === "copy-absolute" ? cwd : (cwd.replace(/[/\\]+$/, "").split(/[/\\]/).pop() || cwd);
									_deepseek_ai_dsh_client_ui_primitives.writeClipboard(value).then((ok) => {
										showNotice(ok ? t("toast.copied", { text: value }) : t("toast.copyFailed"), !ok);
									});
								}
							},
"@
        $onSelectOld = Lf @"
							onSelect: (id) => {
								setMenuOpen(false);
								/* v8 ignore next -- workspaceMenuItems carries exactly these two rows today. */
								if (id !== "rename" && id !== "delete") return;
								if (id === "rename") actions.rename();
								else actions.delete();
							},
"@
        if (-not $c.Contains($onSelectOld)) { Write-Error "literal patch: onSelect block not found; version mismatch. See README."; exit 1 }
        $c = $c.Replace($onSelectOld, $onSelectNew)

        $menuBlock = Lf @"
			/* dsh-workspace-open: reveal the workspace folder in an external tool. */
			if (typeof row.cwd === "string" && row.cwd !== "") {
				workspaceMenuItems.push({
					id: "open-explorer",
					label: t("open.explorer"),
					icon: (0, react_jsx_runtime.jsx)(_deepseek_ai_dsh_client_ui_primitives.IconFolderOpenOutline16, {})
				}, {
					id: "open-vscode",
					label: t("open.vscode"),
					icon: (0, react_jsx_runtime.jsx)(_deepseek_ai_dsh_client_ui_primitives.IconCodeOutline16, {})
				}, {
					id: "open-terminal",
					label: t("open.terminal"),
					icon: (0, react_jsx_runtime.jsx)("span", {
						style: { width: 14, height: 14, display: "inline-flex", alignItems: "center", justifyContent: "center", fontSize: 9, fontWeight: 600 },
						children: ">_"
					})
				}, {
					id: "copy-absolute",
					label: t("copy.absolute"),
					icon: (0, react_jsx_runtime.jsx)(_deepseek_ai_dsh_client_ui_primitives.IconLinkOutline16, {})
				}, {
					id: "copy-relative",
					label: t("copy.relative"),
					icon: (0, react_jsx_runtime.jsx)(_deepseek_ai_dsh_client_ui_primitives.IconCopyOutline16, {})
				});
			}
"@
        if (-not $c.Contains("}];" + "`n")) { Write-Error "literal patch: menu items anchor not found"; exit 1 }
        $c = $c.Replace("}];" + "`n", "}];" + "`n" + $menuBlock + "`n")

        $notice = Lf @"
		/** Transient viewport toast for clipboard/open feedback (best-effort). */
		function showNotice(text, isError) {
			try {
				const el = document.createElement("div");
				el.textContent = text;
				el.setAttribute("role", isError ? "alert" : "status");
				el.style.cssText = "position:fixed;z-index:10000;right:16px;bottom:16px;max-width:70vw;padding:8px 12px;border-radius:10px;font-size:13px;line-height:18px;box-shadow:0 4px 16px rgba(0,0,0,.18);background:" + (isError ? "#c42b1c" : "#1f2328") + ";color:#fff";
				document.body.appendChild(el);
				setTimeout(() => el.remove(), 2500);
			} catch (_error) { /* notification is best-effort */ }
		}
"@
        $anchor = "return e.clientY < rect.top + rect.height / 2 ? `"before`" : `"after`";"
        if (-not $c.Contains($anchor)) { Write-Error "literal patch: rowHalf anchor not found"; exit 1 }
        $c = $c.Replace($anchor + "`n", $anchor + "`n" + $notice + "`n")

        $zhKeys = Lf @"
			"open.explorer": "在资源管理器中打开",
			"open.vscode": "在 VS Code 中打开",
			"open.terminal": "在终端中打开",
			"copy.absolute": "复制绝对路径",
			"copy.relative": "复制相对路径",
			"toast.copied": "已复制：{text}",
			"toast.copyFailed": "复制失败",
			"toast.openFailed": "打开失败：{message}",
			"toast.opened": "已打开：{app}",
"@
        $enKeys = Lf @"
			"open.explorer": "Open in File Explorer",
			"open.vscode": "Open in VS Code",
			"open.terminal": "Open in terminal",
			"copy.absolute": "Copy absolute path",
			"copy.relative": "Copy relative path",
			"toast.copied": "Copied: {text}",
			"toast.copyFailed": "Copy failed",
			"toast.openFailed": "Failed to open: {message}",
			"toast.opened": "Opened: {app}",
"@
        $zhAnchor = '"menu.archiveSession": "归档会话",'
        $enAnchor = '"menu.archiveSession": "Archive session",'
        if (-not $c.Contains($zhAnchor)) { Write-Error "literal patch: zh locale anchor not found"; exit 1 }
        $c = $c.Replace($zhAnchor + "`n", $zhAnchor + "`n" + $zhKeys + "`n")
        if (-not $c.Contains($enAnchor)) { Write-Error "literal patch: en locale anchor not found"; exit 1 }
        $c = $c.Replace($enAnchor + "`n", $enAnchor + "`n" + $enKeys + "`n")

        [System.IO.File]::WriteAllText($wsClient, $c, (New-Object System.Text.UTF8Encoding($false)))
        Write-Step "workspace client patched (literal)"
    }
}

# ---------- 3. cordis registration ----------
if (-not (Test-Path $cordis)) { Write-Error "cordis patch file not found: $cordis"; exit 1 }
$y = Get-Content $cordis -Raw
if ($y -match 'dsh-workspace-launcher') {
    Write-Step "cordis entry already present, skipping"
} else {
    $entry = @"

# dsh-workspace-launcher: open the current workspace in File Explorer / VS Code /
# a terminal from the session header (bundle in profiles/node_modules/dsh-workspace-launcher).
- insert:
    - id: workspace-open
      name: 'dsh-workspace-launcher'
"@
    Add-Content -Path $cordis -Value $entry -Encoding utf8
    Write-Step "cordis entry added -> $cordis"
}

# ---------- 4. restart ----------
if ($NoRestart) {
    Write-Step "installed. Restart the harness (close the 'DeepSeek Harness Server' window and run start-dsh.bat) then hard-refresh the browser (Ctrl+F5)."
} else {
    Write-Step "restarting the dsh web harness..."
    $node = Get-CimInstance Win32_Process -Filter "Name='node.exe'" | Where-Object { $_.CommandLine -match 'dsh web' }
    foreach ($p in $node) { taskkill /F /T /PID $p.ProcessId 2>$null | Out-Null }
    Start-Sleep -Seconds 2
    Start-Process -FilePath 'cmd.exe' -ArgumentList '/c', 'npx -y @deepseek-ai/dsh web --host 127.0.0.1 --port 3080' -WindowStyle Minimized
    Write-Step "harness restarting (http://127.0.0.1:3080). Hard-refresh the browser (Ctrl+F5) once it is back."
}
Write-Step "done."
