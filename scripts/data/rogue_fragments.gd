class_name RogueFragments
## 肉鸽模式 · 手工关卡片段库(docs/design/roguelike.md §4 · 单人制)。
## v0.17 机制完善期:**全部关卡片段已清空**,待机制达标后重新设计。
## 设计纪律不变:手工片段 × 接口对齐(左端单一出生带 / 尾部单一归门),
## 按主角分组(疾 / 跃 / 逆 / 圆 各一条专属片段链 + 章末精英考),
## 每章二选一 = 同一母题的快 / 稳两种手工排法;不做程序生成。
## 系统代码(RogueDirector / RunState / RunModifiers / rogue_layer)保留休眠;
## 肉鸽主页入口已隐藏(menu_layer),重开设计时按原 API 重建片段即可。


## 某主角某章的两条路线(快 / 稳)——片段清空后返回空数组。
## RogueDirector 依赖非空数组选路;空库期间肉鸽入口已隐藏,不可达。
static func chapter_routes(_focus: int, _chapter: int) -> Array:
	return []


## 章末精英考(每位主角一场专属大考)——片段清空后返回空字典。
static func elite(_focus: int) -> Dictionary:
	return {}
