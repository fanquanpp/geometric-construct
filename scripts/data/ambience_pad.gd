class_name AmbiencePad
extends Resource
## BGM 和声垫声位(R2 数值资源化):一个和弦垫 = 拍位 + 音级组 + 时长 + 音量。
## 声位纪律:sus2 / add9 / 开放五度(空灵来源,audio.md §3),勿写三和弦原位。

@export var beat := 0.0                 ## 触发拍位(小节内)
@export var notes: Array[String] = []   ## 和弦音级(C 大调自然音级)
@export var dur_beats := 8.0            ## 时长(拍)
@export var vol := 0.085                ## 音量(每音双振荡器合唱分摊)
