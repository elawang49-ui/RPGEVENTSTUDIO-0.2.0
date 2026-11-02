# RPGEVENTSTUDIO 0.2.0-rc2 验收记录

日期：2026-11-02。修复提交 b06f82c、bd201bd；版本元数据 c99a6a5。

rc1 上线后发现 Linux 字体差异使分页断言与计数不稳定；固定测试字体后，额外发现事件列表测试错误依赖第一条引用的返回顺序。前者使用源码内随附的两款 OFL 中文字体验收，后者检查目标节点实际存在并增加反向排列回归，未放宽目标路径条件。其他系统字体 UI 测试保留。测试字体不进入插件 ZIP。

自动播放还有真实缺陷：打字时提前开始阅读倒计时。新增测试先得到 2 项失败，再去掉提前启动计时的分支，让既有打字完成入口负责启动倒计时。接口与资源格式未改变。

| 验收 | 结果 |
|---|---|
| macOS 独立 fresh clone 全量 | headless 1287/1287、editor 228/228、故障控制 12/12 |
| Linux GitHub Actions | headless 1287/1287、editor 228/228、故障控制 12/12 |
| 两平台 ZIP 空白安装 | 8/8，失败注入实际退出 1 |
| School 隔离副本 | 批准的事务契约迁移后 119/119 |
| GamePrototype 隔离副本 | 资源运行 8/8；仍无主场景，不宣称整款游戏验收 |

[Linux 完整 CI](https://github.com/elawang49-ui/RPGEVENTSTUDIO-0.2.0/actions/runs/41407837667) 已成功完成，包括首次导入、全量测试、打包、实际 ZIP 安装和失败注入。对应提交 bd201bd；后续归档只增加本文和日志。

原始红/绿、Linux、fresh clone、宿主日志保存在 docs/qa/0.2.0-rc2/evidence。没有新增白名单或错误豁免，原基线套件保留。原有引擎退出期资源诊断规则未改动。

仍为预发布版本：Windows/Linux 人工 GUI、第三方自定义适配器和真实手柄验证尚未完成；既有事务外部副作用边界及 Graph 顺序调度限制见 QUALITY_REPORT.md。没有修改 main 或主题分支，rc1 标签不移动。

推荐安装 rpgeventstudio-0.2.0-rc2.zip；安装与状态升级规则见 INSTALL.md。允许商业游戏，禁止售卖插件本体及修改版，详见 LICENSE。
