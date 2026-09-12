class_name AmbienceMotif
extends Resource
## BGM motif 数据表(R2 数值资源化 v0.38,场景资源强制约束):
## 章节 unlocks / 主角音乐画像的全部可调数值 —— bpm / 循环拍数 / 深空风 /
## drone 铺底音级 / pads 和声垫 / steps 短句,一律 @export 存 .tres,
## 编辑器 Inspector 直调;本资源只作静态数据,运行时禁止写入
## (资源默认共享引用,一处写处处变)。
## 音级纪律:notes 一律 C 大调自然音级(抒情段 Am),audio.md §1;
## 数据源:data/music/<id>.tres;SSOT 迁移自旧代码 const MOTIFS(v0.38)。

@export var id := "prologue"            ## set_motif 寻址键(关内唯一)
@export var bpm := 56.0                 ## 节拍时钟 BPM(顺带驱动 TimedBridge)
@export var cycle := 16.0               ## 小节循环拍数
@export var wind := 0.5                 ## 深空风强度 0-1(循环边界风涌)
@export var drone: Array[float] = []    ## 低音铺底频率 Hz(首音加权 ×1.6)
@export var pads: Array[AmbiencePad] = []
@export var steps: Array[AmbienceStep] = []
