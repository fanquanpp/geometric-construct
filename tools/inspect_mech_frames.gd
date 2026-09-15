extends SceneTree
## 机关正典帧占位检测:输出每张 PNG 的尺寸与非透明包围框(像素),
## 供 TerrainKit.mech_layout 精确适配机关区域。一次性工具。

const FILES := [
	"mech_speed_gate", "mech_speed_gate_f2",
	"mech_timed_bridge", "mech_timed_bridge_f2",
	"mech_piano_tile", "mech_piano_tile_f2",
	"mech_portal", "mech_portal_f2", "mech_portal_f3",
	"mech_lever_pad", "mech_lever_pad_f2",
	"mech_mover", "mech_ramp", "mech_push_box",
	"mech_launch_pad", "mech_ski_patch",
	"mech_exit_door", "mech_checkpoint",
]


func _initialize() -> void:
	for f: String in FILES:
		var path := "res://assets/archive/%s.png" % f
		var tex: Texture2D = load(path)
		if tex == null:
			print("MISSING ", f)
			continue
		var img: Image = tex.get_image()
		if img.is_compressed():
			img.decompress()
		print("%s size=%s used=%s" % [f, img.get_size(), img.get_used_rect()])
	quit(0)
