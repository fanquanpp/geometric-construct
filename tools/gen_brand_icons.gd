extends SceneTree

# 品牌图标生成器 v0.70.0(用户令「作为游戏图标。替换全部。」):
# 母版 SVG 为用户提供之 icon1.svg(设计:暗底圆角板 #18181B + 红色
# 圆角方主体 #E53935 + 左上白色高光 30% + 黑色胶囊双眼,整体构成
# 吉祥物脸),全文内嵌于 SOURCE_FULL 常量,派生两个变体后栅格化:
#   icon.png                       256×256  整图(项目图标 project.godot
#                                            :19 + Windows 导出 exe 图标
#                                            export_presets.cfg:272-273)
#   assets/brand/icon_192.png      192×192  安卓 legacy 主图标(整图)
#   assets/brand/icon_bg_432.png   432×432  安卓自适应背景层(纯 #18181B
#                                            满铺,沿旧例纯色底)
#   assets/brand/icon_fg_432.png   432×432  自适应前景层(透明底;红主体
#                                            居中缩至 260px——安卓 108dp
#                                            画布 72dp 可见窗/66dp 安全区
#                                            内,圆角掩膜下仍读作圆角方)
#   assets/brand/icon_mono_432.png 432×432  自适应单色层(白剪影,双眼
#                                            evenodd 掏空;Android 13
#                                            主题色图标只用其 alpha)
# 派生规则(SOURCE_FG/SOURCE_MONO):
#   去底板矩形,其余元素整体包 <g transform="translate(t,t) scale(f)">
#   关于中心(256,256)缩放;f 使主体先放大到 260÷(432/512) 设计像素
#   (栅格化另有 432/512 缩放,两级相乘后落盘恰 260 画布像素),
#   t = 256×(1-f)。几何坐标单一真值直取母版,零手算烘焙。
# headless 运行:
#   godot --headless --path . --script res://tools/gen_brand_icons.gd
# PNG 属生成产物,可随时由本工具重建;五处 .import(无损 compress/mode=0
# 无 mipmap detect_3d=0)路径不变零改动,仅内容更替后重导入即可。

const MASTER := 512
const FG_BODY_PX := 260  # 前景/单色层主体边长(432 画布内)

const SOURCE_FULL := """<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 512 512">
  <rect width="512" height="512" rx="100" fill="#18181B" />
  <rect x="76" y="76" width="360" height="360" rx="70" fill="#E53935" />
  <line x1="115" y1="140" x2="170" y2="140" stroke="#FFFFFF" stroke-width="14" stroke-linecap="round" opacity="0.3" />
  <rect x="155" y="195" width="42" height="90" rx="21" fill="#000000" />
  <rect x="285" y="195" width="42" height="90" rx="21" fill="#000000" />
</svg>"""

const _RASTER := 432.0 / 512.0
const _F := float(FG_BODY_PX) / 360.0 / _RASTER
const _T := 256.0 * (1.0 - _F)
const _XFORM := "translate(%.4f,%.4f) scale(%.7f)" % [_T, _T, _F]

const SOURCE_FG := """<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 512 512">
  <g transform="%s">
    <rect x="76" y="76" width="360" height="360" rx="70" fill="#E53935" />
    <line x1="115" y1="140" x2="170" y2="140" stroke="#FFFFFF" stroke-width="14" stroke-linecap="round" opacity="0.3" />
    <rect x="155" y="195" width="42" height="90" rx="21" fill="#000000" />
    <rect x="285" y="195" width="42" height="90" rx="21" fill="#000000" />
  </g>
</svg>""" % _XFORM

const SOURCE_MONO := """<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 512 512">
  <g transform="%s">
    <path fill-rule="evenodd" fill="#FFFFFF" d="M146 76 H366 A70 70 0 0 1 436 146 V366 A70 70 0 0 1 366 436 H146 A70 70 0 0 1 76 366 V146 A70 70 0 0 1 146 76 Z
      M155 216 A21 21 0 0 1 197 216 V264 A21 21 0 0 1 155 264 Z
      M285 216 A21 21 0 0 1 327 216 V264 A21 21 0 0 1 285 264 Z" />
    <line x1="115" y1="140" x2="170" y2="140" stroke="#FFFFFF" stroke-width="14" stroke-linecap="round" opacity="0.3" />
  </g>
</svg>""" % _XFORM


func _initialize() -> void:
	var fails := 0
	fails += _emit_svg(SOURCE_FULL, 256, "res://icon.png")
	fails += _emit_svg(SOURCE_FULL, 192, "res://assets/brand/icon_192.png")
	fails += _emit_svg(SOURCE_FG, 432, "res://assets/brand/icon_fg_432.png")
	fails += _emit_svg(SOURCE_MONO, 432, "res://assets/brand/icon_mono_432.png")

	# 自适应背景层:纯色满铺,无图案(沿旧例)。
	var bg := Image.create(432, 432, false, Image.FORMAT_RGBA8)
	bg.fill(Color("#18181B"))
	fails += _emit_img(bg, "res://assets/brand/icon_bg_432.png")

	quit(0 if fails == 0 else 1)


# 栅格化 SVG 至目标边长并落盘。设计画布恒 512,scale=目标/512。
func _emit_svg(source: String, out_px: int, path: String) -> int:
	var img := Image.new()
	var err := img.load_svg_from_buffer(source.to_utf8_buffer(),
		float(out_px) / float(MASTER))
	if err != OK:
		push_error("SVG 栅格化失败 %s(缩放 %s)" % [path, float(out_px) / MASTER])
		return 1
	return _emit_img(img, path)


func _emit_img(img: Image, path: String) -> int:
	var err := img.save_png(path)
	if err != OK:
		push_error("PNG 落盘失败 " + path)
		return 1
	print("%s %dx%d ok" % [path, img.get_width(), img.get_height()])
	return 0
