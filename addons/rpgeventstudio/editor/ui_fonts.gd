@tool
class_name UiFonts
extends RefCounted
## 编辑器界面统一字号（px）。只用于编辑器面板；
## 运行时对话 UI 由 RpgEventStudioTheme 管理，二者互不影响。
## 中文辅助信息的下限是 12px，不再使用 9/10/11 作为常规字号。

const TITLE := 20
const SECTION := 16
const BODY := 14
const NOTE := 12
const BUTTON := 14
const DEBUG := 13
