# tools/

开发与发布辅助脚本，**不参与运行时**。

| 脚本 | 作用 |
| --- | --- |
| `check_deps.gd` | 静态检查依赖方向：`core/` 不得引用 `editor/`、`EditorInterface`、`GraphEdit`；文件行数上限 |
| `export_json.gd` | 事件/公共事件/关卡图 → JSON（AI 生成、code review、回归夹具） |
| `import_json.gd` | JSON → `.tres`，**必须先过 SchemaValidator + ReferenceValidator**，失败不落盘 |
| `validate_all.gd` | 全工程校验：指令注册、引用、图 lint、状态使用；输出可点击的问题列表 |
| `package.sh` | 打 zip（`addons/rpgeventstudio/` + 版本号 + 校验解析） |

## 原则

- JSON 只是交换格式，**不是**运行时数据源。
- 导入永远"校验优先"：不接受未通过 schema 的 AI 输出（需求 §15：不执行未经验证的数据）。
- 脚本本身用 `--headless` 可跑，不打开编辑器。
