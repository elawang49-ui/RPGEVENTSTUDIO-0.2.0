# 测试

使用标准 Godot 4.7.2，不依赖第三方测试框架。

```bash
export GODOT_BIN=/path/to/Godot
python3 tools/test_runner.py --all
```

运行器先完成首次导入，生成全局类名缓存和翻译资源，再运行22个 headless套件、6个真实编辑器套件和11个故障注入控制。精确检查数登记在 `tools/test_counts.json`；每个原有套件保留，新增检查只增加数量。完整输出在 `.godot/test-results/`。只有退出码、汇总、断言数量、CASE完成度与诊断检查全部通过才算通过。

手动跑单一 GDScript 前先执行：

```bash
godot --headless --editor --path . --import
godot --headless --path . --script res://tests/run.gd
```

新增 runtime_release_test 覆盖共享状态批处理重入、会话回滚/冲突、once预留、父子清理、Presenter所有权、暂停、场景退出及图等待闸门。Story专项覆盖顺序/嵌套选项整体操作。编辑器套件执行真实UndoRedo、面板同步、关闭面板后撤销、保存绕开缓存重载和插件禁用/启用。

安装包和独立宿主验证使用 `tools/release_check.py`，详见 tools/README.md。开发自测会写夹具和临时数据，必须在开发工作区或工具创建的隔离副本运行，不能把测试工具放进正在使用玩家存档的正式宿主执行。

11个故障注入包含运行中类型/空引用异常、未完成测试、预期负向错误、缺汇总、提前退出、失败断言、子测试中断和解析失败。运行器同时核对注入的实际错误证据，防止“任何失败都算注入成功”。刻意中断且不会自行退出的脚本在15秒内被测试工具终止，并被判为失败控制，不会占用数分钟。

没有新增引擎错误白名单或套件豁免。沿用基线的退出期 resources-in-use 规则，不能将其解释为“Godot退出零诊断”。
