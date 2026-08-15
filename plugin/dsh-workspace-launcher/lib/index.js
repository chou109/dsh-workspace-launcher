/**
 * dsh-workspace-launcher — host half.
 *
 * Exposes POST /workspace-open/open { path, app } and opens the given absolute
 * path with the requested tool:
 *   - explorer (default): the OS file manager (Windows Explorer / Finder /
 *     xdg-open) — the primary use case;
 *   - vscode: `code <path>`, with Windows fallbacks to the registry
 *     "App Paths\Code.exe" entry, the standard install paths, and a
 *     drive-root probe (`X:\Microsoft VS Code\Code.exe`) — VS Code is often
 *     installed in a custom location;
 *   - terminal: a new terminal window rooted at the path (Windows Terminal,
 *     falling back to a PowerShell window).
 *
 * Windows specifics (all learned the hard way):
 *   - workspace paths often end with a trailing separator; it must be
 *     stripped or `cmd /c start "" "<path>\"` breaks (the backslash escapes
 *     the closing quote and Windows reports "cannot find the file");
 *   - spawning `explorer.exe` directly from a detached/background process
 *     frequently returns without opening a window, so Windows uses
 *     `cmd /c start "" "<path>"` (ShellExecute) instead;
 *   - console apps (wt/powershell/cmd) must NOT be spawned with
 *     `windowsHide: true` or their window never shows.
 *
 * Spawns are detached and stdio-ignored so the harness never blocks on the
 * launched app and the process survives the request.
 */
import { spawn, execFile } from "node:child_process";
import { existsSync } from "node:fs";

const name = "dsh-workspace-launcher";
const inject = ["webServer"];

const MAX_BODY_BYTES = 16 * 1024;

/** Collect a small JSON request body. */
async function readJsonBody(req) {
	let body = "";
	for await (const chunk of req) {
		body += chunk;
		if (body.length > MAX_BODY_BYTES) throw new Error("request body too large");
	}
	return JSON.parse(body);
}

function json(res, status, value) {
	res.writeHead(status, { "content-type": "application/json; charset=utf-8" });
	res.end(JSON.stringify(value));
}

/** Strip trailing separators so quoting a path never breaks on a `\`. */
function normalizePath(path) {
	return String(path).replace(/[\\/]+$/, "");
}

/**
 * Spawn a command detached and resolve once it is up (or failed to spawn).
 * `windowsHide` stays false so console apps (terminals) show their window.
 */
function openDetached(command, args) {
	return new Promise((resolve) => {
		let child;
		try {
			child = spawn(command, args, { detached: true, stdio: "ignore" });
		} catch (error) {
			resolve({ ok: false, error: String(error && error.message || error) });
			return;
		}
		child.once("error", (error) => resolve({ ok: false, error: String(error && error.message || error) }));
		child.once("spawn", () => {
			child.unref();
			resolve({ ok: true });
		});
	});
}

/** Read the (Default) REG_SZ value of a registry key; undefined when absent. */
function readRegDefault(key) {
	return new Promise((resolve) => {
		execFile("reg", ["query", key, "/ve"], { windowsHide: true }, (error, stdout) => {
			if (error) {
				resolve(void 0);
				return;
			}
			const match = String(stdout).match(/\sREG_SZ\s+(.+?)\s*(\r?\n|$)/);
			resolve(match ? match[1].trim() : void 0);
		});
	});
}

/**
 * Locate VS Code's executable on Windows: registry "App Paths\Code.exe"
 * (HKCU then HKLM), then the standard install paths, then a drive-root probe
 * for `X:\Microsoft VS Code\Code.exe` (custom installs like D:\Microsoft VS Code).
 */
async function findVscodeExecutable() {
	if (process.platform !== "win32") return void 0;
	for (const hive of ["HKCU", "HKLM"]) {
		const fromReg = await readRegDefault(`${hive}\\SOFTWARE\\Microsoft\\Windows\\CurrentVersion\\App Paths\\Code.exe`);
		if (fromReg && existsSync(fromReg)) return fromReg;
	}
	const candidates = [
		process.env.LOCALAPPDATA && `${process.env.LOCALAPPDATA}\\Programs\\Microsoft VS Code\\Code.exe`,
		process.env.ProgramFiles && `${process.env.ProgramFiles}\\Microsoft VS Code\\Code.exe`,
		process.env["ProgramFiles(x86)"] && `${process.env["ProgramFiles(x86)"]}\\Microsoft VS Code\\Code.exe`
	];
	for (let drive = 67; drive <= 90; drive++) { // C:..Z:
		const letter = String.fromCharCode(drive);
		if (existsSync(`${letter}:\\`)) candidates.push(`${letter}:\\Microsoft VS Code\\Code.exe`);
	}
	for (const candidate of candidates) {
		if (candidate && existsSync(candidate)) return candidate;
	}
	return void 0;
}

/** Quote a path for PowerShell's single-quoted string ('' escapes a quote). */
function psLiteral(path) {
	return "'" + String(path).replace(/'/g, "''") + "'";
}

async function openWorkspace(app, path) {
	const target = normalizePath(path);
	switch (app) {
		case "vscode": {
			const executable = await findVscodeExecutable();
			if (executable !== void 0) return openDetached(executable, [target]);
			return openDetached("code", [target]);
		}
		case "terminal": {
			if (process.platform === "win32") {
				// Prefer Windows Terminal; fall back to a visible PowerShell window.
				return openDetached("wt.exe", ["-d", target]).then((result) => (
					result.ok ? result : openDetached(
						"powershell.exe",
						["-NoExit", "-Command", `Set-Location -LiteralPath ${psLiteral(target)}`]
					)
				));
			}
			if (process.platform === "darwin") return openDetached("open", ["-a", "Terminal", target]);
			return openDetached("x-terminal-emulator", ["--working-directory=" + target]);
		}
		case "explorer":
		default: {
			if (process.platform === "win32") {
				// `cmd /c start "" <path>` opens the folder via ShellExecute even
				// from a detached/background process. Pass the RAW path: node
				// quotes arguments with spaces itself. Manually pre-quoting here
				// breaks cmd's `start` parsing — node escapes the embedded quotes
				// into backslashes, `start` then tries `\D:\...\` and Windows
				// shows "cannot find the file".
				return openDetached("cmd.exe", ["/c", "start", "", target]);
			}
			if (process.platform === "darwin") return openDetached("open", [target]);
			return openDetached("xdg-open", [target]);
		}
	}
}

function isAbsolutePath(path) {
	if (path.startsWith("/")) return true;
	if (path.startsWith("\\\\")) return true; // UNC
	return /^[A-Za-z]:[\\/]/.test(path); // drive letter
}

function apply(ctx) {
	ctx.effect(() => ctx.webServer.register({
		kind: "exact",
		path: "/workspace-open/open",
		handler: async (req, res) => {
			if (req.method !== "POST") {
				json(res, 405, { ok: false, error: "method not allowed" });
				return;
			}
			let payload;
			try {
				payload = await readJsonBody(req);
			} catch (error) {
				json(res, 400, { ok: false, error: "invalid JSON body: " + String(error && error.message || error) });
				return;
			}
			const path = payload && payload.path;
			const app = payload && typeof payload.app === "string" ? payload.app : "explorer";
			if (typeof path !== "string" || path.length === 0) {
				json(res, 400, { ok: false, error: "path must be a non-empty string" });
				return;
			}
			if (!isAbsolutePath(path)) {
				json(res, 400, { ok: false, error: "path must be absolute" });
				return;
			}
			try {
				const result = await openWorkspace(app, path);
				json(res, result.ok ? 200 : 500, result);
			} catch (error) {
				ctx.logger.error("[dsh-workspace-launcher] open failed:", error);
				json(res, 500, { ok: false, error: String(error && error.message || error) });
			}
		}
	}), "dsh-workspace-launcher: open route");
}

export { apply, inject, name };
