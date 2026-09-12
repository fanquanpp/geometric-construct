class_name AmbienceStep
extends Resource
## BGM motif 短句音符(R2 数值资源化):拍位 + 音名 + 时长 + 波形 + 音量。
## 波形:sine / tri / bell(正弦 + 2/3 号泛音,重延迟发送)。

@export var beat := 0.0                 ## 触发拍位(小节内)
@export var note := "C4"                ## 音名(C 大调自然音级)
@export var dur_beats := 1.0            ## 时长(拍)
@export var wave := "tri"               ## sine / tri / bell
@export var vol := 0.1                  ## 音量
