@tool
class_name GraphIssue
extends RefCounted
## 关卡图静态校验的一条结果：严重级别 + 定位 + 描述 + 修复建议。
## 由 GraphValidator 产出，编辑器的检查面板负责展示与定位。

enum Severity { INFO, WARNING, ERROR }

var severity: int = Severity.INFO
## 稳定的机器标识（测试与过滤用），如 "start.missing"。
var code: String = ""
## 相关节点；全局性问题（如缺少开始节点）为空。
var node_id: StringName = &""
## 节点显示名（标题，缺省用类型名）。
var node_name: String = ""
## 人读的问题描述（已本地化）。
var message: String = ""
## 人读的修复建议（已本地化）。
var suggestion: String = ""

func severity_label() -> String:
	match severity:
		Severity.ERROR:
			return L10n.ui("graph.check.severity.error")
		Severity.WARNING:
			return L10n.ui("graph.check.severity.warning")
		_:
			return L10n.ui("graph.check.severity.info")
