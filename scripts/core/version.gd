class_name Version


const MAJOR := 0
const MINOR := 56
const PATCH := 2

const CHANNEL := ""

const GAME_TITLE := "几何构成"
const GAME_TITLE_EN := "GEOMETRIC CONSTRUCT"


static func number_string() -> String:
	return "%d.%d.%d" % [MAJOR, MINOR, PATCH]


static func full_string() -> String:
	return "v%s%s" % [number_string(), CHANNEL]
