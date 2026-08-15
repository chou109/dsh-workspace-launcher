/**
 * dsh-workspace-launcher — browser half (client bundle).
 *
 * UI is integrated into the workspace row menu in
 * @deepseek-ai/dsh-client-ui-workspace ("打开方式"-style entries that call the
 * host endpoint this package's node half mounts). This bundle exists so the
 * package keeps a valid `dsh.client` declaration; it registers nothing.
 */
window.__ModuleLoader__.load({
	id: "dsh-workspace-launcher",
	factory: (require) => {
		var module = { exports: {} };
		var exports = module.exports;
		Object.defineProperty(exports, Symbol.toStringTag, { value: "Module" });
		var inject = [];
		function apply() {}
		exports.apply = apply;
		exports.inject = inject;
		return module.exports;
	}
});
