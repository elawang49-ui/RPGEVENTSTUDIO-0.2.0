# RPGEVENTSTUDIO 0.2.0-rc2 安装与接入

验证环境：Godot 4.7.2，标准 GDScript 版。不需要 GUT、.NET、Python 或第三方插件来运行游戏。Python 3.9+ 仅用于源码仓库的测试与打包工具。

## 安装

1. 关闭目标项目的 Godot 编辑器，备份项目并提交当前改动。
2. 将 ZIP 中的 `addons/rpgeventstudio/` 完整放到目标项目同名目录。升级时先比较宿主自己修改过的插件文件，不要直接覆盖本地定制。
3. 用 Godot 4.7.2 打开目标项目，等待导入完成。在「项目设置 → 插件」启用 Godot RPG Event Studio。
4. 确认 Autoload 中出现 `RPGEventStudio`，指向插件运行时。Godot 可以将路径保存成 `uid://`，这属于正常序列化；必须保留 ZIP 中的 `.uid` 文件。
5. 在编辑器主屏使用 Graph、Story、Map 创建内容。正式游戏内容放在插件目录之外，避免升级覆盖。

CI/命令行首次安装：先在 project.godot 的 `[editor_plugins]` 中启用 `res://addons/rpgeventstudio/plugin.cfg`，然后运行 `godot --headless --editor --path <project> --import`。插件会持久安装 Autoload。普通关闭编辑器不会卸载它；明确禁用插件会移除插件自己的 Autoload，不删除宿主的不同路径单例。

## 最小运行

```gdscript
var definition := load("res://content/events/intro.tres") as EventDefinition
RPGEventStudio.start_event(definition)
# 结果通过 RPGEventStudio.bus.event_finished(report) 获取。
# report.result 为 EventRunner.Result.COMPLETED / CANCELLED / FAILED。
```

使用 EventInteractor2D、MapEvent2D、EventAutoRun2D 或 LevelGraphRunner2D 可以按交互、区域、自动或关卡图触发。关卡节点离树会停止对应图；当前场景离树会取消该场景运行中的事件。自行管理非 current_scene 的跨场景任务时，在切换生命周期边界主动调用 `RPGEventStudio.cancel_all(reason)`。

## 0.2 的状态规则（升级必读）

- 宿主直接 `RPGEventStudio.set_state()` 或 `runtime.state.set_value()` 仍然立即生效。
- 事件指令使用 `ctx.get_state/set_state` 或 `ctx.state`，写入进入事件会话。事件自身与同步嵌套调用能读取会话内的新值；宿主和 Graph 只会在整段事件成功后看到提交。
- 取消或失败丢弃整段会话，包括已经返回的子事件写入。失败和取消执行已登记的清理钩子；成功释放清理登记。嵌套事件结束报告只表示该次执行结束，其状态仍以父事件的最终成功为准。
- 事件读写过的键被宿主/其他事件修改，或宿主 restore/reset 使快照失效时，事件以 FAILED 结束，reason 包含 `state conflict`。不会覆盖宿主更新，也不会自动重放道具/任务等副作用。
- once 只有顶层会话成功后才消耗；嵌套 once 在父会话结束前预留，避免另一事件重复执行。取消/失败允许重试。
- 提交是同步终态边界；收到正式 changed/batch_committed 后，提交已成立。监听器此时发出的取消不能撤销已发布批次。
- 事务只涵盖 StateStore。外部道具、任务、节点等副作用由适配器及 `ctx.on_cancel()` 清理负责。
- 会话视图的 snapshot/dump 读取也参加冲突检测；在事件内调用 restore/reset 会先修改本会话，只有成功时才发布完整替换，取消仍然丢弃。宿主直接使用共享 StateStore 的原有生命周期行为保持不变。
- 存档仍使用既有 `snapshot()/restore()`，格式没有改变；执行中的会话不进入存档。不要依赖 `ctx.state == RPGEventStudio.state` 的对象身份。

School 的旧测试有一项在剧情中途读取 choice；需要更新为“中途仍不可见、成功结束后等于选择值”。附带 `school-state-contract.patch` 只修改测试契约并新增完成后的断言，不修改游戏流程。GamePrototype 当前没有主场景；本次验证覆盖项目导入和真实事件运行，不能据此声称完成了整款游戏的端到端验收。

## 展示层、暂停与扩展

自定义 Presenter 注入：`RPGEventStudio.set_presenter(node)`；恢复默认：`restore_default_presenter()`。必需方法：`show_text`、`is_text_finished`、`show_choices`、`get_choice`；可选 `close_all`、`fade_to`、`clear_fade`。Node 展示层离树/释放会取消相关事件。共用同一个展示层的对话/选项/淡入淡出互斥；纯状态事件可以并发。

宿主 `SceneTree.paused = true` 时，默认事件推进、计时与展示层暂停；取消仍可收尾。插件不主动更改宿主 paused。自定义 Presenter 的动画、输入及自行创建的 Tween 由宿主按同一暂停规则管理。

扩展继续使用现有 CommandHandler + CommandRegistry 注册机制，不在资源内执行任意脚本表达式。自定义展示类指令应注册到 `CommandRegistry.CAT_DIALOGUE`，便于统一申请展示层所有权；长任务返回 WAIT 并使用 ctx.wait_until。运行时使用 Godot Logger 的临时观察器辨别同步指令及等待回调的脚本异常；不屏蔽日志，不在 await 期间常驻，不接管宿主自己的日志器。所有状态修改走 ctx.state；持有全局 runtime.state 直接写入属于宿主行为，不会被事件回滚。注册入口目前仍是既有 `CommandRegistry._register`，本次保留，没有擅自新增或删改公开扩展接口。

插件保留宿主已定义的 InputMap 动作和绑定。需要主动改键时，通过 InputService 的既有 register_action、extend_action_defaults 与设置面板接入。

## 目录和依赖

```text
addons/rpgeventstudio/
  plugin.cfg / plugin.gd / *.uid
  core/      # 资源模型、状态、指令、Graph、校验、追踪、工具
  editor/    # Inspector、Graph、Story、Map、资源撤销操作
  runtime/   # Autoload、交互组件、默认 UI
  i18n/      # CSV 翻译源，首次导入生成运行所需翻译资源
  samples/   # 可选参考场景及资源；安装包包含完整示例
```

`res://state/state_catalog.tres`、`res://state/story_characters.tres` 和 `res://ui/rpgeventstudio_theme.tres` 属于宿主可选数据。缺失时降级为空状态库/花名册及默认主题，需要保存时由编辑器创建。插件不依赖开发工作区、绝对路径或预生成 `.godot` 缓存。

## 源码验证与打包

```bash
export GODOT_BIN=/path/to/Godot
python3 tools/test_runner.py --all  # 自动首次导入 + headless/editor/故障注入
python3 tools/release_check.py --package build  # 实际解压安装 ZIP 到临时空白工程
python3 tools/release_check.py --fresh          # 独立无缓存 clone + 全量测试
```

宿主回归可加 `--school <School路径> --school-state-contract --prototype <GamePrototype路径>`。工具只改新建隔离副本，原项目不变。证据和日志目录会打印到控制台，失败返回非零。

## 作者与许可

elawang49-ui <elawang49@gmail.com>。自定义RPGEVENTSTUDIO Source-Available License 1.0允许用插件制作和发行商业游戏，包括收费、广告、内购；禁止把插件本身或其修改版作为收费插件销售或收费分发。随游戏打包必要运行时是允许的，不要求公开游戏源码。分发插件时保留LICENSE；游戏可在随附许可证文件中保留声明，无需启动画面署名。

完整授权条款随安装包提供，复制addons/rpgeventstudio目录时其中的LICENSE和LICENSING.md也必须保留。本项目准确归类为“源码公开、禁止售卖插件”，不是OSI开源许可。
