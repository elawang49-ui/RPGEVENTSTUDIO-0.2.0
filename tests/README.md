# tests/

自建极简测试，**不引入任何第三方插件**（需求 §16：不依赖第三方商业插件）。

## 约定

- 入口：`run.gd`，`extends SceneTree`，用 `--headless --script` 运行。
- 用 `quit(code)` 返回结果；非 0 即失败，可直接接入 CI 或 pre-commit。
- 用例命名：`test_<被测模块>.gd`，每个用例一个方法 `test_<行为>`，失败打印期望/实际。
- 运行时测试一律使用 Mock：`MockPresenter`（记录 UI 调用）、`MockAdapter`（道具/任务）、`MockClock`（跳过真实等待）。
- 夹具：`fixtures/*.tres`（最小事件、两页条件事件、非法引用事件）。

## 运行

```bash
godot --headless --path . --script res://tests/run.gd
```

## 计划覆盖

| 里程碑 | 用例 |
| --- | --- |
| M1 | `.tres` 往返序列化、`uid://` 引用跨路径解析、schema 迁移、校验器误报/漏报 |
| M3 | runner 顺序/条件/等待/取消、三态结果、自动事件不重复触发、公共事件递归上限、并行预算 |
| M5 | 未触发原因求值、状态快照恢复 |

Godot 无内置断言框架，`tests/framework/assert.gd` 提供 `assert_eq / assert_true / assert_signal / assert_awaits`。
