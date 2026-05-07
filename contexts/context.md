# 项目核心上下文

## 项目名称
Claude Code Desktop Mac 版本汉化项目

## 项目目标
将 Claude Code 的 Mac 桌面端应用进行中文化（汉化），提升中文用户的使用体验。

## 项目现状与基本情况
- 平台：macOS
- 当前阶段：初始化阶段，正准备获取应用包资源并制定汉化策略。

## 技术路线预期
如果目标应用是基于 Electron 开发（大部分跨平台桌面应用如此）：
1. 提取 `/Applications/Claude.app/Contents/Resources/app.asar`。
2. 使用 `asar` 工具解包。
3. 查找并替换关键 JS/JSON 文件中的英文字符串。
4. 重新打包为 `app.asar` 并覆盖原文件。
5. 使用 `codesign` 等工具对修改后的应用进行本地重签名。
