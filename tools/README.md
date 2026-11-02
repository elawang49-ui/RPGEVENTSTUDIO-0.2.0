# 工程工具

运行游戏只需要 `addons/rpgeventstudio/` 和 Godot 4.7.2。本目录不属于运行时依赖。

| 工具 | 实际作用 |
|---|---|
| `test_runner.py` | 自动 `--editor --import`，执行全部22个 headless、6个 editor 套件和12个故障注入控制；校验数量、完成度、退出码、未授权诊断，写日志到 `.godot/test-results/` |
| `test_counts.json` | 每个套件的精确断言数量，不允许少注册测试 |
| `release_check.py` | 从插件包实际安装空白工程、注入安装失败、独立 clone 全测，以及可选 School/GamePrototype 隔离升级回归；打印证据目录 |
| `blank_install_check.gd` | 只依赖 addon 的8项安装/运行/资源读回测试；故障模式必须返回非零 |
| `build_samples.gd` | 构建开发示例资源 |
| `check_i18n.gd` | 词条/引用辅助检查，不替代运行测试 |
| `check_theme_persist.gd` | 跨进程主题持久化 create/verify/cleanup |
| `visual_check.gd`、`check_theme_persist.gd`、`visual_docs.gd` | UI辅助检查/文档截图 |
| `capture_bbcode_editor.gd`、`dialogue_pagination_shots.gd`、`hardening_shots.gd`、`round3_scroll_shots.gd`、`ui_round2_shots.gd` | 开发截图工具，需要图形环境；有些会生成示例/截图，不应在正式宿主运行 |

```bash
export GODOT_BIN=/path/to/Godot
python3 tools/test_runner.py --all
python3 tools/release_check.py --package build
python3 tools/release_check.py --fresh
```

`--fresh` 从当前 `release/0.2.0-rc1` 的已提交内容 clone；未提交文件不属于 clone 验收范围。`--package` 先生成完整 ZIP，再从这个 ZIP 实际安装。包不含 `.godot`、翻译导入产物、`.import`、备份和临时文件，保留源码、素材和 `.uid`。

可选宿主验证：`--school <path> --school-state-contract --prototype <path>`。School 的状态契约补丁只应用于隔离副本，并保留补丁证据；不改原工程。GamePrototype 没有主场景，只报告插件导入/运行验证。

此前文档提到的 check_deps/export_json/import_json/validate_all/package.sh 不在当前仓库，不能作为可执行步骤。打包使用本目录的 release_check.py。
