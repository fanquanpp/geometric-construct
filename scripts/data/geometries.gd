class_name Geometries


const UNIT_PX := 100.0


const PATHS: Array[String] = [
	"res://data/characters/dash.tres",
	"res://data/characters/spring.tres",
	"res://data/characters/fall.tres",
]

static var ALL: Array[GeometryDef] = []


static func _static_init() -> void:
	for i in PATHS.size():
		var def: GeometryDef = load(PATHS[i])
		def.index = i
		ALL.append(def)


static func get_def(index: int) -> GeometryDef:
	return ALL[clampi(index, 0, ALL.size() - 1)]


static func by_weight() -> Array:
	var copy := ALL.duplicate()
	copy.sort_custom(func(a: GeometryDef, b: GeometryDef) -> bool:
		return a.weight > b.weight)
	return copy
