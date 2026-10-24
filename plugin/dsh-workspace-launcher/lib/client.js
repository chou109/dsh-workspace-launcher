/**
 * dsh-workspace-launcher — browser half (client bundle), DSH 0.2.x.
 *
 * Registers a compact "Open" action in the Session header
 * (`conversation.session.header.actions`). The menu offers:
 *   - 在资源管理器中打开 / Open in File Explorer
 *   - 在 VS Code 中打开 / Open in VS Code
 *   - 在终端中打开 / Open in terminal
 *   - 复制工作区路径 / Copy workspace path
 *
 * The 1.x version patched `@deepseek-ai/dsh-client-ui-workspace`'s bundle to add
 * rows to the Workspace menu. 0.2.x builds client packages as dynamic bundles,
 * so that patch is neither applicable nor safe: this version contributes through
 * the documented slot API instead. The workspace path is read from the standard
 * `useWorkspaces` / `useSessions` selector hooks; the host half owns the actual
 * process launch through POST /workspace-open/open.
 */
window.__ModuleLoader__.load({
	id: "dsh-workspace-launcher",
	factory: (require) => {
		var module = { exports: {} };
		var exports = module.exports;
		Object.defineProperty(exports, Symbol.toStringTag, { value: "Module" });
		var react = require("react");
		var h = react.createElement;

		var NS = "dsh-workspace-launcher";
		var zh = {
			"action.open": "打开工作区",
			"menu.explorer": "在资源管理器中打开",
			"menu.vscode": "在 VS Code 中打开",
			"menu.terminal": "在终端中打开",
			"menu.copy": "复制工作区路径",
			"status.opened": "已打开：{app}",
			"status.copied": "已复制路径",
			"status.noPath": "当前会话没有可用的工作区路径",
			"status.failed": "操作失败：{message}"
		};
		var en = {
			"action.open": "Open workspace",
			"menu.explorer": "Open in File Explorer",
			"menu.vscode": "Open in VS Code",
			"menu.terminal": "Open in terminal",
			"menu.copy": "Copy workspace path",
			"status.opened": "Opened: {app}",
			"status.copied": "Path copied",
			"status.noPath": "This session has no workspace path",
			"status.failed": "Failed: {message}"
		};

		var css = [
			".dsh-wl-root{position:relative;display:inline-flex;align-items:center}",
			".dsh-wl-trigger{display:inline-flex;align-items:center;justify-content:center;gap:4px;height:26px;min-width:26px;padding:0 6px;border:0;border-radius:6px;background:transparent;color:var(--dsw-alias-label-secondary);cursor:pointer;font:inherit;font-size:12px}",
			".dsh-wl-trigger:hover{background:var(--dsw-alias-interactive-bg-hover-solid);color:var(--dsw-alias-label-primary)}",
			".dsh-wl-trigger[aria-expanded=true]{background:var(--dsw-alias-interactive-bg-hover);color:var(--dsw-alias-label-primary)}",
			".dsh-wl-menu{position:fixed;z-index:80;min-width:190px;padding:4px;border:1px solid var(--dsw-alias-border-l1);border-radius:10px;background:var(--dsw-alias-bg-base);box-shadow:var(--dsw-shadow-lv2);display:flex;flex-direction:column;gap:2px}",
			".dsh-wl-item{display:flex;align-items:center;gap:8px;width:100%;padding:6px 8px;border:0;border-radius:6px;background:transparent;color:var(--dsw-alias-label-primary);cursor:pointer;font:inherit;font-size:13px;text-align:left;white-space:nowrap}",
			".dsh-wl-item:hover{background:var(--dsw-alias-interactive-bg-hover-solid)}",
			".dsh-wl-item:disabled{opacity:.45;cursor:default}",
			".dsh-wl-status{padding:4px 8px 2px;font-size:11px;line-height:16px;color:var(--dsw-alias-label-tertiary);max-width:220px;white-space:normal}",
			".dsh-wl-status[data-error]{color:var(--dsw-alias-state-error-primary)}",
			".dsh-wl-icon{flex:none;width:14px;height:14px;display:inline-flex;align-items:center;justify-content:center;color:var(--dsw-alias-label-tertiary)}"
		].join("");
		var cssTagId = "dsh-workspace-launcher/header-action.css";

		function IconFolder() {
			return h("svg", { viewBox: "0 0 16 16", width: 14, height: 14, fill: "none", "aria-hidden": true },
				h("path", { d: "M1.8 4.2c0-.6.5-1.1 1.1-1.1h3.3l1.3 1.5h5.6c.6 0 1.1.5 1.1 1.1v6.1c0 .6-.5 1.1-1.1 1.1H2.9c-.6 0-1.1-.5-1.1-1.1V4.2Z", stroke: "currentColor", "stroke-width": 1.2, "stroke-linejoin": "round" }));
		}
		function IconTerminal() {
			return h("svg", { viewBox: "0 0 16 16", width: 14, height: 14, fill: "none", "aria-hidden": true },
				h("rect", { x: 1.8, y: 2.8, width: 12.4, height: 10.4, rx: 1.4, stroke: "currentColor", "stroke-width": 1.2 }),
				h("path", { d: "m4.4 6.2 2 1.8-2 1.8M8.2 9.9h3", stroke: "currentColor", "stroke-width": 1.2, "stroke-linecap": "round", "stroke-linejoin": "round" }));
		}
		function IconCode() {
			return h("svg", { viewBox: "0 0 16 16", width: 14, height: 14, fill: "none", "aria-hidden": true },
				h("path", { d: "M5.6 3.4 1.8 8l3.8 4.6M10.4 3.4 14.2 8l-3.8 4.6", stroke: "currentColor", "stroke-width": 1.3, "stroke-linecap": "round", "stroke-linejoin": "round" }));
		}
		function IconCopy() {
			return h("svg", { viewBox: "0 0 16 16", width: 14, height: 14, fill: "none", "aria-hidden": true },
				h("rect", { x: 5.2, y: 5.2, width: 8.2, height: 8.2, rx: 1.6, stroke: "currentColor", "stroke-width": 1.2 }),
				h("path", { d: "M10.8 5.2V3.9c0-.6-.5-1.1-1.1-1.1H3.9c-.6 0-1.1.5-1.1 1.1v5.8c0 .6.5 1.1 1.1 1.1h1.3", stroke: "currentColor", "stroke-width": 1.2 }));
		}

		function joinPath(base, relative) {
			if (typeof base !== "string" || base === "") return relative;
			var left = base.replace(/[\\/]+$/, "");
			var right = String(relative).replace(/^[\\/]+/, "");
			return left + "\\" + right;
		}

		function WorkspaceLauncher(props) {
			var sessionId = props.sessionId;
			var t = props.t;
			var workspacePath = props.useWorkspaces(function (state) {
				var items = state.items || [];
				for (var i = 0; i < items.length; i++) {
					var ids = items[i].sessionIds || [];
					for (var j = 0; j < ids.length; j++) {
						if (ids[j] === sessionId) return items[i].path;
					}
				}
				return undefined;
			});
			var cwd = props.useSessions(function (state) {
				var summary = state.byId ? state.byId[sessionId] : undefined;
				return summary === undefined ? undefined : summary.cwd;
			});
			var sessionTitle = props.useSessions(function (state) {
				var summary = state.byId ? state.byId[sessionId] : undefined;
				return summary === undefined ? undefined : summary.displayTitle;
			});

			var path = typeof cwd === "string" && cwd !== "" ? cwd : (typeof workspacePath === "string" ? workspacePath : undefined);

			var openState = react.useState(false);
			var open = openState[0];
			var setOpen = openState[1];
			var posState = react.useState(null);
			var pos = posState[0];
			var setPos = posState[1];
			var statusState = react.useState(null);
			var status = statusState[0];
			var setStatus = statusState[1];
			var busyState = react.useState(false);
			var busy = busyState[0];
			var setBusy = busyState[1];

			var rootRef = react.useRef(null);
			var triggerRef = react.useRef(null);
			var menuRef = react.useRef(null);
			var statusTimer = react.useRef(null);

			var flash = function (text, isError) {
				if (statusTimer.current !== null) clearTimeout(statusTimer.current);
				setStatus({ text: text, error: isError === true });
				statusTimer.current = setTimeout(function () {
					statusTimer.current = null;
					setStatus(null);
				}, 2600);
			};

			react.useEffect(function () {
				return function () {
					if (statusTimer.current !== null) clearTimeout(statusTimer.current);
				};
			}, []);

			react.useEffect(function () {
				if (!open) return;
				var onPointerDown = function (event) {
					var root = rootRef.current;
					if (root !== null && root.contains(event.target)) return;
					setOpen(false);
				};
				var onKeyDown = function (event) {
					if (event.key === "Escape") setOpen(false);
				};
				document.addEventListener("pointerdown", onPointerDown);
				document.addEventListener("keydown", onKeyDown);
				return function () {
					document.removeEventListener("pointerdown", onPointerDown);
					document.removeEventListener("keydown", onKeyDown);
				};
			}, [open]);

			react.useEffect(function () {
				if (!open) return;
				var trigger = triggerRef.current;
				if (trigger === null) return;
				var rect = trigger.getBoundingClientRect();
				var menuWidth = 196;
				var left = Math.min(Math.max(8, rect.right - menuWidth), window.innerWidth - menuWidth - 8);
				var top = rect.bottom + 6;
				setPos({ left: Math.round(left), top: Math.round(top) });
			}, [open]);

			var launch = function (app) {
				if (typeof path !== "string" || path === "") {
					flash(t("status.noPath"), true);
					return;
				}
				setBusy(true);
				fetch("/workspace-open/open", {
					method: "POST",
					headers: { "content-type": "application/json" },
					body: JSON.stringify({ path: path, app: app })
				}).then(function (response) { return response.json(); }).then(function (payload) {
					if (!payload || !payload.ok) throw new Error(payload && payload.error || "open failed");
					setOpen(false);
					flash(t("status.opened", { app: t("menu." + (app === "explorer" ? "explorer" : app === "vscode" ? "vscode" : "terminal")) }), false);
				}).catch(function (error) {
					flash(t("status.failed", { message: String(error && error.message || error) }), true);
				}).finally(function () { setBusy(false); });
			};

			var copyPath = function () {
				if (typeof path !== "string" || path === "") {
					flash(t("status.noPath"), true);
					return;
				}
				var done = function () { setOpen(false); flash(t("status.copied"), false); };
				if (navigator.clipboard && typeof navigator.clipboard.writeText === "function") {
					navigator.clipboard.writeText(path).then(done).catch(function () {
						flash(t("status.failed", { message: "clipboard" }), true);
					});
					return;
				}
				try {
					var area = document.createElement("textarea");
					area.value = path;
					area.style.position = "fixed";
					area.style.opacity = "0";
					document.body.appendChild(area);
					area.select();
					document.execCommand("copy");
					area.remove();
					done();
				} catch (error) {
					flash(t("status.failed", { message: String(error && error.message || error) }), true);
				}
			};

			var items = [
				{ id: "explorer", label: t("menu.explorer"), icon: IconFolder, run: function () { launch("explorer"); } },
				{ id: "vscode", label: t("menu.vscode"), icon: IconCode, run: function () { launch("vscode"); } },
				{ id: "terminal", label: t("menu.terminal"), icon: IconTerminal, run: function () { launch("terminal"); } },
				{ id: "copy", label: t("menu.copy"), icon: IconCopy, run: copyPath }
			];

			var trigger = h("button", {
				ref: triggerRef,
				type: "button",
				className: "dsh-wl-trigger",
				"aria-haspopup": "menu",
				"aria-expanded": open ? "true" : "false",
				"aria-label": t("action.open"),
				title: typeof path === "string" && path !== "" ? path : t("action.open"),
				onClick: function () { setOpen(function (value) { return !value; }); }
			}, [h("span", { key: "icon", className: "dsh-wl-icon" }, IconFolder()), h("span", { key: "label" }, t("action.open"))]);

			var children = [trigger];
			if (open && pos !== null) {
				var rows = items.map(function (item) {
					var Icon = item.icon;
					return h("button", {
						key: item.id,
						type: "button",
						className: "dsh-wl-item",
						role: "menuitem",
						disabled: busy || typeof path !== "string" || path === "" ? true : void 0,
						onClick: item.run
					}, [h("span", { key: "icon", className: "dsh-wl-icon" }, Icon()), h("span", { key: "label" }, item.label)]);
				});
				if (status !== null) rows.push(h("div", { key: "status", className: "dsh-wl-status", "data-error": status.error ? "" : void 0, role: status.error ? "alert" : "status" }, status.text));
				children.push(h("div", {
					key: "menu",
					ref: menuRef,
					className: "dsh-wl-menu",
					role: "menu",
					style: { left: pos.left + "px", top: pos.top + "px" }
				}, rows));
			} else if (status !== null) {
				children.push(h("span", { key: "status", className: "dsh-wl-status", "data-error": status.error ? "" : void 0, role: status.error ? "alert" : "status" }, status.text));
			}

			return h("span", { ref: rootRef, className: "dsh-wl-root", "data-workspace-launcher": true }, children);
		}

		var inject = ["slots", "sessions", "workspaces", "locale"];

		function apply(ctx) {
			ctx.effect(function () {
				if (typeof document === "undefined") return function () {};
				if (document.querySelector("style[data-plugin-css=" + JSON.stringify(cssTagId) + "]") !== null) return function () {};
				var tag = document.createElement("style");
				tag.dataset.plugin = "dsh-workspace-launcher";
				tag.dataset.pluginCss = cssTagId;
				tag.textContent = css;
				document.head.appendChild(tag);
				return function () { tag.remove(); };
			}, "dsh-workspace-launcher: styles");

			ctx.effect(function () {
				return ctx.locale.register(NS, { zh: zh, en: en });
			}, "dsh-workspace-launcher: dictionaries");

			ctx.slots.inject("conversation.session.header.actions", function () {
				return ctx.slots.register({
					name: "conversation.session.header.actions",
					id: "dsh-workspace-launcher",
					order: 30,
					locale: NS
				}, WorkspaceLauncher);
			});
		}

		exports.apply = apply;
		exports.inject = inject;
		return module.exports;
	}
});
