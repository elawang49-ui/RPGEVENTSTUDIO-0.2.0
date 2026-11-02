# RPGEVENTSTUDIO 0.2.0-rc1 工程交付报告

本报告记录发布前本地验收；随后已将发布分支上传至 [GitHub](https://github.com/elawang49-ui/RPGEVENTSTUDIO-0.2.0)。远程 CI 状态以仓库 Actions 为准。

日期：2026-11-02（Asia/Shanghai）。运行环境：macOS，Godot `4.7.2.stable.official.ed1daf0bf`。

代码验收基准：`833ea41`，分支 `release/0.2.0-rc1`。最终归档提交只增加报告和日志，不再改插件代码。建议版本号为 **0.2.0-rc1**；这是可安装的发布候选，不把尚未执行的跨平台 GUI / 远程 CI 验收冒充为正式发布完成。

最终验收状态：**PASS**。已提交代码的独立fresh clone通过1259项headless、228项editor和12个故障控制；同一ZIP的空白安装及两宿主隔离验证通过。

## 1. 基线和保护

- 从 `9368e3331268ed7518580b6e1fe451c36813a361` 创建独立分支和 `/Users/elawang/Godot/rpg-studio-release-0.2.0-rc1` worktree。
- 开始及恢复工作时重新检查了 branch、worktree list、HEAD、status、merge-base/提交关系。确认 Batch 1 是 Batch 2 祖先。
- 没有修改 main，没有覆盖/删除分支或 worktree，没有使用 hard reset、clean 或强制覆盖。
- `feat/ui-theme-presets-v2` 保持在 `706fd5420cb9e8ed1bba720b9a58c3696b73efff`，相对指定基线仍有4个独有提交。本会话首次读取时其工作区已是0个未提交修改，与用户此前75项的记录不同；本轮没有对该分支或工作区执行写入。
- School、GamePrototype 都只在新建临时副本中替换插件验证，原工程未被本轮工具修改。

## 2. 修复闭环

| 项目 | 处理与证据 |
|---|---|
| P1-2 选项块 | 顺序式/嵌套式整体删除、复制、移动、撤销与重做，资源实例保留；55项 Story headless专项以及真实editor回归 |
| 深拷贝/资源污染 | 命令树和参数容器深拷贝；外部事件/媒体资源继续引用；第三方 EventCommand 子类、额外导出容器和 Resource属性得到保留 |
| 剪切→撤销→粘贴 | 检测剪切对象是否已被撤销恢复；必要时生成独立副本，避免同一实例占两个列表位置 |
| P1-7 事务重入 | StateStore改嵌套批处理；先摘下待通知批次再广播，重入提交按revision顺序排队；宿主直接读写语义保留 |
| P1-8 取消提交 | 事件会话隔离；成功发布，取消/失败丢弃；不使用整库快照覆盖并发宿主写入 |
| P1-9 once | 成功才消耗；嵌套once预留到父会话结束；失败/取消可重试 |
| P1-10 Presenter并发 | 按共享展示层获取所有权，嵌套归父会话；状态事件不误关其他事件UI，完成后释放所有权 |
| 后台交互与工具门禁 | 纯parallel等待不占玩家交互锁，持有展示层时正常阻塞；工具面板下的自动/区域触发延后，关闭后不丢触发沿；29项交互回归 |
| P1-11 暂停 | 执行、等待、默认UI按宿主暂停；计时保留剩余时长；暂停中取消仍可完成收尾；不修改宿主paused值 |
| 嵌套与场景收尾 | 子事件失败传播，已完成子事件的清理钩子转交父级；宿主/场景/展示层/角色/镜头退出时安全取消；旧图停止并注销 |
| Graph等待 | 同步启动回执区分拒绝/忽略；按实例等待；监听早于调用以支持同步完成；停止中的协程安全退栈 |
| StateStore快照API | snapshot/dump整体读取参加冲突检查；会话restore/reset在成功时发布完整替换；宿主restore后Graph条件重新求值 |
| 自定义handler异常 | 使用临时Logger观察同步调用和等待回调；异常不再因GDScript默认返回值被当作CONTINUE；保留日志，明确FAILED并回滚；故障控制含12项额外收尾断言 |
| P2-6 页面UndoRedo | 新增/删除页、条件增删/字段、trigger、repeat_policy可撤销；真实editor验证 |
| R1–R3资源原子操作 | EventPage插入/删除/移动由公共资源方法执行；EventCommand参数走set_param；EventDefinition内部原子页替换保留实例；共享ResourceEdits以WeakRef引用UI，关闭面板后撤销仍有效 |
| 多面板同步 | Inspector/Story共享定义变化通知，合并延迟刷新；自身连续输入不重建焦点控件；参数与页面UndoRedo不会转写后来打开的资源 |
| 旧选项资源 | 字符串换行选项与数组选项使用同一解析规则，改名/移动可用；撤销恢复原字符串表示，无schema迁移 |
| 搜索与Tree | 保留Batch 2隐藏根修复；新增实际行显隐测试并修复大小写匹配 |
| UI效率/生命周期 | 隐藏Map停止扫描、隐藏主题预览停止渲染；状态库输入和角色取色合并保存；焦点离开提交角色文本；字体/节点/状态弹窗受面板生命周期管理 |
| 首次安装 | Autoload安装持久化，退出编辑器不卸载；禁用兼容路径及uid://，真实禁用/启用/落盘回归通过 |
| 测试与CI | 自动首次import；精确套件登记、完整输出日志；故障控制核对实际错误证据；提供固定Godot版本与校验值的Actions配置 |

原有 P0 Graph 生命周期、Presenter释放、InputMap共存、Graph参数撤销和鼠标坐标修复继续通过对应基线套件。本轮核实的P0/P1均已关闭，没有以跳过断言或增加错误豁免处理失败。

## 3. 状态契约与架构

用户已明确确认“事件完整成功才写入开关；中途取消不留下半成品”。完整方案保存在 `docs/qa/0.2.0-rc1/runtime-state-proposal.md`。

共享StateStore的直接写入、既有公开方法、信号签名、snapshot数据形状和Resource schema保持不变。ctx.state变为满足StateStore类型的内部会话视图，事件内部看到自己的写入；宿主只见成功提交。并发读写冲突明确FAILED，不覆盖宿主更新、不自动重放有外部副作用的指令。提交通知是不可撤销的同步终态边界。

没有将插件改成Demo专用运行器，没有删除公开扩展接口，没有重建视觉系统，没有大规模重构事件资源模型。核心不新增editor依赖。异常观察器使用[Godot Logger的官方接口](https://docs.godotengine.org/en/stable/classes/class_logger.html)，仅在同一线程的同步执行片段注册，不跨await驻留，也不屏蔽宿主日志。

## 4. 测试结果与可信度

| 验证 | 数量/结果 |
|---|---|
| 重新实跑指定基线 | headless 1149/1149，editor 184/184，故障控制通过 |
| 发布代码 headless | 1259/1259，22个套件 |
| 发布代码 editor | 228/228，6个真实编辑器套件 |
| 故障注入控制 | 12/12；包含自定义handler/等待谓词/等待回调异常后12项安全收尾断言 |
| ZIP空白工程 | 首次导入、Autoload、运行、事件/图保存、绕开缓存反序列化：8/8 |
| 空白安装失败注入 | 9项中故意失败1项，进程实际退出1；工具确认失败控制有效 |
| Fresh clone | 独立clone已提交发布分支、无预存.godot，自动导入后全量1259+228及12个故障控制 |
| School | 原始118项中117通过；唯一差异为批准的中途choice可见性变化；隔离副本强化契约后119/119 |
| GamePrototype | 导入通过，独立真实事件/资源运行8/8；工程目前没有主场景，不宣称整款游戏端到端验收 |

所有原有套件保留。新增数量来自运行时74项、Story新增26项、批量搜索新增2项、交互门禁新增8项；editor新增44项。原来的355项主套件没有减少，其中一个旧“按单条指令移动”的预期更新为完整选项块移动，仍检查同一资源实例和正确内容。

先红后绿的证据包括：交互门禁4项失败、选项整体操作12项失败、运行时首组15项失败、旧字符串选项5项失败、子类复制3项失败、快照生命周期4项失败，以及异常handler被误报成功的实测。日志与最终全量输出随交付保存。

没有新增测试白名单、没有新增套件错误豁免。`SUITE_ALLOWED_ERRORS`继续为空。基线已有的Godot退出期resources-in-use规则未改动；报告不把它表述成“退出零诊断”。故障注入的原始SCRIPT ERROR必须被测试运行器判为失败，控制自身才算通过。

## 5. 宿主兼容性说明

School原测试在分支文字仍显示时要求共享状态中的choice已经变成1。这与新确认的事务规则直接冲突。迁移补丁改为中途仍不可见，并新增事件成功后等于1的断言，原有UI、分支、取消、Presenter切换、存档桥断言保留，从118项增加为119项。

补丁仅在隔离副本应用，随包提供 `school-state-contract.patch`。没有改School原工程，也没有通过放宽到“任意值都通过”掩盖差异。

GamePrototype本地插件版本有自己的修改，本轮没有直接覆盖它；隔离副本安装完整候选插件后完成导入和运行测试。正式升级前仍应比较宿主自定义修改，安装说明已明确这一点。

## 6. 安装包、目录与依赖

完整插件包：`rpgeventstudio-0.2.0-rc1.zip`，包含 `addons/rpgeventstudio/`、87个GDScript及对应.uid、样例和素材、INSTALL.md、RELEASE_NOTES.md及School契约补丁。源码ZIP另含测试、工具和报告；Git bundle保留完整可追溯历史。

运行时目录：core / runtime / i18n；编辑器目录：editor；示例：samples；入口：plugin.cfg/plugin.gd。必须依赖Godot 4.7.2；游戏运行不依赖Python、.NET或其他测试插件。Python仅用于源码验收/打包。

包不包含.godot缓存、翻译导入产物、.import、备份、临时文件或开发机绝对路径依赖。实际解压该ZIP后运行空白安装验证；不是只对工作区源码做模拟安装。

详细安装、接入、暂停、自定义指令及状态迁移说明见 `INSTALL.md`，版本变化见 `RELEASE_NOTES.md`。

## 7. 已知限制和未完成边界

1. 可见的部分Map/调试/追踪视图仍保留定时刷新；已关闭隐藏Map扫描和隐藏主题渲染，没有宣称消灭全部轮询。
2. Graph多出边继续采用既有顺序调度，不承诺任意分支真正并行；没有擅自重构令牌模型。
3. 外部道具/任务/场景副作用不属于StateStore事务，扩展需提供取消清理。自定义Presenter自行创建的动画和输入需遵守宿主暂停规则。
4. 本轮本机验证为macOS；Windows/Linux实际GUI、第三方不同适配器的人工验收以及远程Actions尚未执行。CI配置已提供，不能冒充远程CI已绿。
5. 原有架构草案中的预算调度、检查点等未来能力不等同于当前实现；文档已标明草案状态。

上述限制不通过跳过测试隐藏。推荐以rc1交给第三方做受控接入，收集上述平台与适配器反馈后再决定0.2.0正式版本标签。

## 8. 可复现入口与提交记录

```bash
export GODOT_BIN=/path/to/Godot
python3 tools/test_runner.py --all
python3 tools/release_check.py --fresh --package build
python3 tools/release_check.py --school <School> --school-state-contract --prototype <GamePrototype>
```

最终HEAD、完整新增提交清单、插件包SHA-256、源码ZIP和可独立clone的Git bundle列在交付目录的COMMITS.txt和SHA256SUMS.txt中。报告归档后发布worktree保持干净；没有合并main或推送/发布远程版本。

## 9. 发布许可补充（2026-11-02）

用户确认的准确许可范围为“允许做商业游戏，只禁止售卖插件本身”，并最终选择设备Git/SSH账号elawang49-ui及邮箱elawang49@gmail.com作为署名。新增自定义RPGEVENTSTUDIO Source-Available License 1.0；完整条款与中文说明同时保存在仓库根目录和插件目录，安装包也包含它们。允许商业游戏、独立扩展与服务，禁止售卖插件本体/改版；不冒称MIT/GPL或OSI开源许可。

本轮只修改署名、授权说明和打包内容，不修改运行时代码、公共API或资源schema。既有验收数量保持有效；许可证版本另做实际ZIP独立安装和许可文件一致性验证。后续提交使用当前GitHub账号的作者邮箱，仅通过单次git命令覆盖身份；没有修改设备全局Git配置，也没有改写既有历史提交。
