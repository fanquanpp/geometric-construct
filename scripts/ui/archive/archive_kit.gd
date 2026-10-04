class_name ArchiveKit
extends RefCounted


## 档案 tag 统一构件:同一工艺(零圆角、纸缘细描边、内距随字号),
## 底色可配——角色页保角色色实底语义,bld/mech 页墨底,消双视觉语言
## (此前 geo 页实底无描边 / codex 页暗底无描边两套观感)。


## 统一 tag 板:纸缘 0.28 细描边 + 内距随字号(margin_h = size)。
static func tag_box(bg: Color, size: int) -> StyleBoxFlat:
	return Ui.sb(bg, 0, Color(Palette.I.paper, 0.28), 1, size, maxi(4, size / 3))


## 就地刷新既有 tag 节点(文本/底色/字色/字号全走统一工艺)。
static func apply_tag(tag: PanelContainer, text: String, bg: Color,
		fg: Color, size: int) -> void:
	tag.add_theme_stylebox_override("panel", tag_box(bg, size))
	var lb := tag.get_child(0) as Label
	lb.text = text
	lb.label_settings = Ui.ls(size, Ui.HEAD, fg)


## 新建统一工艺 tag(Ui.tag 骨架 + kit 板)。
static func make_tag(text: String, bg: Color, fg: Color, size := 12) -> PanelContainer:
	var tag := Ui.tag(text, bg, fg, size, size, maxi(4, size / 3))
	tag.add_theme_stylebox_override("panel", tag_box(bg, size))
	return tag
