# dsh-workspace-launcher — v2.0.0，适配 DeepSeek Harness 0.2.x

在**会话标题栏**一键用**文件资源管理器 / VS Code / 终端**打开当前会话的工作区目录，或者**复制目录路径**。

> English: [README.md](README.md)

| 项目 | 说明 |
|---|---|
| 插件 | `dsh-workspace-launcher` 2.0.0 |
| 宿主 | DeepSeek Harness **0.2.1-rc.2**（桌面版或 `dsh web`） |
| 平台 | Windows 一等支持；macOS / Linux 由宿主半兼容 |
| 许可 | MIT |

## 相对 0.1.x 的变化

0.1.x 通过补丁改动 `@deepseek-ai/dsh-client-ui-workspace` 的编译产物，往工作区“...”菜单里塞 5 个条目。DSH 0.2 的客户端包是动态 bundle，直接改已安装产物既不安全也不受支持。

2.0 保留原来的宿主路由，UI 改用官方 slot API：

| 0.1.x | 2.0.0 |
|---|---|
| 补丁 `dsh-client-ui-workspace` bundle | 完全不打补丁 |
| 工作区“...”菜单里的 5 行 | **同一个菜单**：把四项追加到内置的重命名/删除菜单里；另有会话标题栏菜单 |
| 路径来自被补丁的那一行 | `useSessions` 的 `cwd`，工作区 `path` 兜底 |
| 往 `document.body` 塞 Toast | 状态文案显示在插件自己的浮层里 |

DSH 0.2 没有工作区菜单槽位（只有会话行菜单可扩展）。插件会记住刚点过“...”的工作区（按钮的 `aria-label` 带标题），在内置菜单出现时把四项追加进去；内置的重命名/删除行及其行为保持原样。

DSH 0.2 自带 **Open In…** 分裂按钮（`dsh-client-ui-open-in-app`），能从应用目录里选任意已安装程序打开会话目录。本插件与之互补：即使应用探测不到任何程序，也保证能打开资源管理器、VS Code、终端，或复制路径。

## 功能

会话标题栏新增“打开工作区”按钮；在侧边栏**右键点击工作区行**也会弹出同一菜单：

- **在资源管理器中打开** —— Windows 走 `cmd /c start`（ShellExecute），macOS 用 Finder，Linux 用 `xdg-open`。
- **在 VS Code 中打开** —— 先试 `code`，Windows 再从注册表 `App Paths`、标准安装路径、各盘根目录回退查找。
- **在终端中打开** —— 优先 Windows Terminal（`wt.exe`），失败回退到可见的 PowerShell 窗口；macOS 用 Terminal.app，Linux 用 `x-terminal-emulator`。
- **复制工作区路径** —— 剪贴板，失败时用 `document.execCommand` 兜底。

宿主半暴露 `POST /workspace-open/open { path, app }`：校验绝对路径、去掉结尾分隔符（Windows 引号问题）、分离进程且忽略 stdio，绝不阻塞 Harness。失败以 JSON 返回并显示在浮层里。

## 安装

### 插件管理器（桌面版）

把 `plugin/dsh-workspace-launcher` 目录作为 bundle 安装并启用。

### 命令行

```bash
dsh plugin --profile <profile> add /absolute/path/to/plugin/dsh-workspace-launcher
```

### 手动

把 `plugin/dsh-workspace-launcher` 链接进 profile 的 `node_modules`，再在 `cordis.patch.yml` 追加：

```yaml
- insert:
    - id: workspace-open
      name: 'dsh-workspace-launcher'
```

如果你用过 0.1.x 的安装脚本，请先**还原** `@deepseek-ai/dsh-client-ui-workspace`（重装 Harness 或该包）。旧补丁绝不能应用到 0.2 的 bundle 上。

## 验证

1. 打开一个工作区目录存在的会话。
2. 标题栏出现“打开工作区”；悬停时 tooltip 显示解析出的目录。
3. 点击 → 四个菜单项，分别能拉起对应程序。
4. “复制工作区路径”复制目录，浮层显示“已复制路径”。
5. 没有目录的会话显示“当前会话没有可用的工作区路径”。

## 卸载

停用/移除 bundle 后刷新页面即可，没有改动其他文件。

## 仓库结构

```
plugin/dsh-workspace-launcher/
  package.json            dsh.bundle.patch + dsh.client
  cordis.patch.yml
  lib/index.js            Host 半：/workspace-open/open 路由
  lib/client.js           浏览器半：会话标题栏菜单
install.ps1 / install.sh  bundle 安装脚本（不打补丁）
```

## 许可证

MIT。
