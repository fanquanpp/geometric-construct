class_name SfxLayer
extends Resource
## 音效合成单层(R2 数值资源化):波形 + 音高扫频 + 包络 + 泛音/颤音。
## 字段语义与 Sfx._layer 规格一一对应(audio.md §0 合成模型)。

@export var wave := "square"            ## square / tri / saw / sine / noise
@export var duty := 0.5                 ## 脉冲占空比(仅 square)
@export var note := ""                  ## 音名("C4");空 = 用 f0
@export var f0 := 440.0                 ## 起始频率 Hz(note 为空时生效)
@export var f1 := 0.0                   ## 结束频率;0 = 无滑音(= f0)
@export var t0 := 0.0                   ## 层起始偏移秒(琶音/回声)
@export var dur := 0.1                  ## 时长秒
@export var vol := 1.0                  ## 层音量 0-1
@export var atk := 0.004                ## 起音秒(线性)
@export var dec := 10.0                 ## 指数衰减速率
@export var harm: Array[Vector2] = []   ## 泛音表 [倍频, 增益]
@export var vib: Array[float] = []      ## 颤音 [Hz, 深度比例]
