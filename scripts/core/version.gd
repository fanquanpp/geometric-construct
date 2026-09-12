class_name Version
## 语义化版本号与构建信息的唯一来源。
## 发版规则见 docs/UPDATE.md:改了存档结构必须升 MAJOR/MINOR,
## 纯内容包(关卡/角色数据)升 PATCH。

const MAJOR := 0
const MINOR := 37
const PATCH := 0
## 渠道后缀:正式发布为空串,开发期可用 "-dev"、"-wip"。
const CHANNEL := ""

const GAME_TITLE := "几何构成"
const GAME_TITLE_EN := "GEOMETRIC CONSTRUCT"


static func number_string() -> String:
	return "%d.%d.%d" % [MAJOR, MINOR, PATCH]


static func full_string() -> String:
	return "v%s%s" % [number_string(), CHANNEL]
