@tool
class_name CmdResult
extends RefCounted
## 指令执行结果。指令处理器永远是同步函数，异步全部交给 EventRunner，
## 这样避免 GDScript「协程必须 await」的静态检查把插件锁死。

const CONTINUE := 0      ## 继续下一条
const WAIT := 1          ## 挂起，直到 ctx 里的等待条件满足
const ENTER_BLOCK := 2   ## 进入 ctx.pending_block 执行（条件分歧 / 循环体）
const CALL := 3          ## 调用 ctx.pending_call（公共事件 / 其他事件）
const HALT := 4          ## 正常结束本事件
const ABORT := 5         ## 中断（错误或取消）
