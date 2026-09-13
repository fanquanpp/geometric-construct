class_name SfxSpec
extends Resource
## 音效规格(M-8 数值资源化 v0.38,场景资源强制约束):一条程序化合成
## 音效的全部可调数值 —— 播放音量 / 音高抖动 / 合成层组。@export 存
## data/sfx/*.tres,编辑器 Inspector 直调;resource 只作静态数据,
## 运行时禁止写入(烘焙在 Sfx.init 首帧前一次性完成)。
## 音级纪律:note 一律 C 大调自然音级(audio.md §1);玩法音 jitter>0
## = 生命感,UI 音与音符路径 jitter=0。

@export var id := ""                    ## 音效名(Sfx.play 寻址键)
@export var base_db := -8.0             ## 播放基础音量
@export var jitter := 0.0               ## 音高随机幅度(±比例)
@export var layers: Array[SfxLayer] = []
