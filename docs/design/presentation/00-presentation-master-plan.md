# 表现系统总设计方案 · PRESENTATION MASTER PLAN(00)

> 状态:**v1.0(2026-09-12 定稿)** · 本文是**表现系统**(Presentation
> System)的唯一总纲:UI 动效 / 交互反馈 / 角色与建筑与机关动画 / VFX /
> 粒子 / 光影 / Shader / 镜头 / 转场 / 剧情演出 / 音乐同步 / 全局运动
> 语法——十六子域的唯一出处。
> 正典关系:`motion.md`(档位/缓动白名单)与 `art-style.md`(无圆角/
> 无渐变/无柔影)继续生效,本文在其上立**运动语法**;`fx-light-uiux.md`
> 的三纪律/语义光源/shader 白名单/UI 微交互**全量并入本卷**,该文档
> 转为 P0 实装分镜清单。
> 最高原则:**所有运动都有语义。**不是特效越多越好。

---

## 卷〇 · 三纪律与强度等级(承 fx-light-uiux,全量正典化)

三纪律:**语义优先 / 硬边 / 预算**(同屏动态光 ≤4、shader ≤6、
粒子发射器 ≤6、单演出 ≤0.6s)。

**效果强度等级 FX-0 ~ FX-5**(全局通用,防视觉污染):

| 级 | 定义 | 例 |
|---|---|---|
| FX-0 | 无效果 | 静止平台 |
| FX-1 | 轻微反馈 | 按钮点击、hover |
| FX-2 | 普通交互 | 机关打开、角色能力发动 |
| FX-3 | 重要事件 | 大型建筑启动、伍共鸣、逆翻转 |
| FX-4 | 大型事件 | 死亡重构、章节光色切换 |
| FX-5 | 世界级事件 | 第七形出现、世界重构 |

铁律:**重要程度 → 表现强度**。所有东西都亮/都有粒子/都震屏,
真正的高潮就不存在了。

---

## 卷一 · MOTION GRAMMAR(运动语法,最高层规范)

基础动作只有六类,一切动效 = 它们的组合:

```
ENTER 进入 · EXIT 退出 · MOVE 移动
ROTATE 旋转 · TRANSFORM 形态变化 · RECONSTRUCT 重构
```

组合示例(正典化):

- **按钮** = ENTER(位置切入)→ MOVE(Hover 轻微位移)→
  TRANSFORM(Click 压缩)→ 恢复;
- **建筑** = ENTER(结构展开)→ MOVE(定位)→ LOCK;
- **角色死亡** = TRANSFORM(形体破坏)→ Fragment → EXIT →
  RECONSTRUCT(重新组合)。

禁止使用"缩放+淡入+弹跳"等通用游戏动效词汇——那是别的游戏的语言。

---

## 卷二 · UI MOTION(八子域:Boot/Page/Navigation/Component/Feedback/
Loading/Transition/Narrative)

- **页面进入(构成主义五拍)**:元素分块 → 轴线定位 → 标题进入 →
  内容展开 → 交互元素出现。例·主菜单:Title 左侧切入 → Menu 右侧
  依次进入 → 背景几何缓移 → Primary 按钮最后出现。
- **页面退出(三拍)**:内容按层级撤出 → 背景结构移动 → 页面关闭。
  禁止 A 页突然消失、B 页突然出现。
- **Hover(几何关系变化,非 scale 1.1)**:边界线移动 + 几何标记出现 +
  文字轻微位移 + 短促 UI_Focus 音。
- **Click(六步,精确·机械·几何)**:压缩 40–80ms → 边框瞬时变化 →
  几何线扩散 → 微型粒子 → UI_Click SFX → 恢复。禁:爆炸/彩烟/大幅缩放。
- **UI_FEEDBACK 十五态**:Focus / Hover / Press / Confirm / Cancel /
  Back / Open / Close / Locked / Error / Warning / Complete / Unlock /
  New / Selected——每态固定"视觉+音"配对:
  Locked=短暂偏移+结构线收紧+低沉音;Complete=边界闭合+刻度亮起+
  确认音;Error=沿轴抖动+红色刻度闪烁+短促错误音。

---

## 卷三 · 几何点击波纹(Interaction FX,项目辨识件)

点击点 → **对象同形线框**向外扩张 → 断裂 → 消失。形状随对象:
普通按钮=方形 / 角色=其形状 / 机关=其几何符号 / 伍=两个三角形同时
扩散。实现走集中反馈系统:`UI 事件 → Feedback System → 标准 FX`,
**任何按钮不得自实现特效**。十件:CursorHit / ButtonPress /
SelectionRing / FocusLine / ConfirmBurst / CancelBreak / UnlockLine /
ErrorPulse / HoverTrace / DragTrace。

---

## 卷四 · 角色动画语法(形状变形就是角色动画)

五形无腿,不做传统骨骼动画——**形变即表演**。

| 形 | 关键词 | 语法要点 |
|---|---|---|
| 疾 | 快/切/冲/停/反弹 | Idle 微前倾;Dash=几何拉伸,Dash End=突然压缩;爬墙=连续切割式;死亡=高速解构。**「疾学会停」的动画叙事:前期 Dash→立即停止;第四幕后 Dash→主动减速→稳定→静止**(动画本身讲故事) |
| 跃 | 压缩/弹射/上升/承接/落地 | Jump Start 压缩→Jump 拉伸→Apex 短暂稳定→Landing 压缩→恢复 |
| 逆 | 镜像/翻转/上下 | 置换:轴线出现→整体翻转→**世界级联动**(音效方向/UI 方向/粒子方向/镜头微方向同步改变) |
| 圆 | 旋转/惯性/轨迹/连续 | 移动=旋转;加速=轨迹增长;高速=轨迹强化;急停=轨迹延迟消失——速度成为视觉元素 |
| 伍 | 分离/接近/连接/共鸣/重构 | **五动画状态**:Separated → Approaching → Connected → Resonance → Reconstruction; Connected=两三角完成一次同步动作——玩法(磁界)+音乐(双声部)+剧情(关系)三线同此一态 |

---

## 卷五 · 建筑与机关动画

**建筑九动作**:展开/收缩/升降/旋转/折叠/断裂/重构/沉降/漂浮。
**建筑呼吸**:大型建筑允许 0.1%–1% 尺度极慢变化(巨构门厅结构位移/
穹顶周期微动/大风琴管体轻动)——世界不是静态地图。

**机关动画铁律**:玩家一眼知道当前状态。门:`LOCKED 闭合 → OPENING
分离 → OPEN 保持 → CLOSING 重组`。**移动平台六拍**:启动→机械预动作
→移动→减速→定位→锁定(Motion+Feedback)。

**限时桥五态模板(SOP,全时间族通用)**:
`SOLID → WARNING → PHASE_OUT → VOID → RECONSTRUCT`;
视觉:实体→边框闪烁→内部结构分离→几何碎片→消失;
声音:稳定→节拍,Warning→高频提示,Disappear→短促下降。

---

## 卷六 · 光影八类(LIGHTING)

World / Architecture / Character / Mechanism / Interactive / Story /
Anomaly / **Transition** Light。**禁万能 Bloom**——光承担信息。

- **World**:普通=平稳;异常=光照方向改变;空白=极低对比;
  第七形=不符合既有光照规律;
- **Mechanism**:OFF 极暗 → ACTIVE 明确几何光 → WARNING 周期闪烁 →
  COMPLETE 稳定;
- **Character**:不做周身光环——运动→局部光影响(圆高速=轨迹光线
  延迟;逆翻转=光照方向短暂反转;伍=两半各向局部光反馈);
- **Story(最易被忽略)**:角色领悟时刻=环境光降低+角色局部光升高+
  背景结构停止运动——玩家自然知道"这里很重要",无需弹窗;
- **Anomaly**:正常建筑阴影方向一致,**异常建筑某一结构阴影方向错误**
  ——比红色发光高级得多;
- **Transition**:幕转场=章节光色阶跃(fx-light-uiux 卷二)。

---

## 卷七 · Shader Library(十枚核心,准入制)

Geometry / Outline / **Deconstruct** / Reconstruction / Scanline /
Distortion / Mirror / Void / Highlight / Anomaly。

**Deconstruct ≠ 普通溶解**:完整几何体 → 边界断裂 → 几何块分离 →
线条消失 → 碎片 → 空白——符合"重构"世界观的离场方式。
**Reconstruction = 全游戏最重要特效之一**:Blank → Fragments →
Position → Shape → Character,且**声音+粒子+光+镜头+UI 五联同步完成**。

---

## 卷八 · 粒子七类(Dust / Fragment / Line / Scale / Note / Spark / Void)

参数变化产生不同效果,不新增类别;禁自然系(火焰/烟雾/光斑)。

### 粒子登记表(v0.29.2 起,准入制 —— 新粒子先登记后合入)

| 实例 | 类 | 域 | 强度 | 参数与语言 | 代码 |
|---|---|---|---|---|---|
| 漂浮尘埃 | Dust | 世界(相机跟随) | FX-0 常驻 | 20 粒 / 寿命 7s / 2px 方点 / PAPER α0.10 / 横向漂移 | `AmbientParticles._build_dust` |
| 雪屑(滑雪带) | Dust | 世界(带上方缓降) | FX-0 常驻 | 12 粒/带 / 寿命 2.6s / 重力 14 / PAPER α0.30 | `AmbientParticles._build_snow` |
| 管线滴水 | Dust(受重力变体) | 世界(法兰下坠落) | FX-0 常驻 | 2 点 ×2 粒 / 寿命 1.6s / 重力 900 / BLUE α0.45 直线坠落 | `AmbientParticles._build_drip` |
| 点按反馈 | Fragment | 屏域(触点处) | FX-1 轻微反馈 | 10 方块迸散 + 菱形回包 0.28s / 寿命 0.32s / PAPER+1 构成红 | `TouchControls.tap_burst_at` |

- 常驻发射器计数:Backdrop 屏域 motes 2 + 上表常驻 3 = **同屏 ≤6 达标**;
  点按反馈为 ≤0.35s 一次性演出(M6 时限内)。
- ~~地图皮动效层 `MapSkinFX`~~(**v0.39.0 随地图皮退役**;原条目:非粒子,`_draw` 常驻低幅):信标呼吸 2.0s /
  圣环脉冲 2.4s / 光柱气流上浮线 —— M5(周期 1.5~2.5s、幅度克制、
  不抢焦点)+ M9(Time 驱动)双合规。

---

## 卷九 · 镜头九式与语义化震动

Follow / LookAt / Pan / Zoom / **Shake(语义化)** / Impact / **Freeze** /
Focus / Transition。

震动语义化:小碰撞→无;重要机关→极轻;巨大结构→中等;世界重构→强;
剧情高潮→特殊设计。**镜头 Freeze(舞台感)**:重大事件→世界运动骤停→
声音留下→镜头停住→某个几何体完成变化→恢复。

---

## 卷十 · 转场七式与"UI 是世界的一部分"

Construct / Collapse / Slide / Split / Mirror / Rotate / Rebuild。
关卡间:建筑结构拆解 → 线框化 → 移动 → 重新组合(世界自己在重排,
不是黑屏)。**UI/世界转场统一**:选关卡片边框展开 → 变成建筑框架 →
镜头进入框架 → 进入游戏——UI 不是游戏外壳,是世界的一部分。

---

## 卷十一 · BEAT EVENT(节拍驱动表现)

统一节拍事件系统,订阅方:UI / Mechanism / Light / Particle /
Architecture / Character。通道四分:**主节拍 + 次节拍 + 旋律事件 +
特殊事件**——防止全屏抽搐。BPM 与拍点由既有 beat_clock 正典供出。

---

## 卷十二 · 章节 Motion Identity(七幕动效身份)

| 幕 | 动效身份 |
|---|---|
| 序幕 | 慢 · 空 · 少 |
| 第一幕 | 机械 · 规律 · 重复 |
| 第二幕 | 镜像 · 翻转 |
| 第三幕 | 分裂 · 错位 |
| 第四幕 | 破坏 · 变形 |
| 第五幕 | 秩序崩解 |
| 落幕 | 停止 · 重构 · 归零 |

剧情、建筑、音乐、动画四线共用同一身份。

---

## 卷十三 · VFX 十族、矩阵与效果规格单

**十族**:UI / Character / Ability / Mechanism / Architecture /
Environment / Narrative / Rerun / Anomaly / Transition FX。

**Presentation Matrix**(每效果一行,格式正典):
`ID / 对象 / 事件 / 动画 / VFX / 光影 / 镜头 / 音频 / 强度`。
正典种子:FX001 UI 按钮 Click(Press+Line,FX-1)/ FX002 机关 Open
(Move+Light,FX-2)/ FX003 疾 Dash(Stretch+Trail+MotionLight,FX-2)/
FX004 逆 Gravity(Flip+Axis+Direction,FX-3)/ FX005 伍 Connect
(Sync+Resonance+双光,FX-3)/ FX006 死亡(Deconstruct+Fragment+
Collapse+Shake,FX-4)/ FX007 世界 Reconstruct(Rebuild+Fragment+
Flash+Major,FX-5)。

**效果规格单(EFFECT SPEC)模板**——每个效果进入 Godot 前必填:

```
FX-ID / 对象 / 触发时机 / 持续(s) / 强度(FX-0~5)
曲线(motion.md 白名单) / 粒子(七类或无) / Shader(库内或无)
光(八类或无) / 镜头(九式或无) / 音效(UI/机制/角色/环境事件名)
Godot 落点(Tween / CPUParticles2D / PointLight2D / canvas shader / material)
```

---

## 卷十四 · 文档体系与 Godot 实装映射

**26 文件拆分按需生长**(01-motion-grammar … 26-presentation-qa),
不预建空壳;`fx-light-uiux.md` 保留为 P0 实装分镜清单。

**Godot 落点映射**:基础动作=Tween 六型(TRANS_SINE/QUART 等 motion
白名单内);粒子=CPUParticles2D(七类各一参数预设);光=PointLight2D
(阶跃贴图)+ 既有 Directional rig;Deconstruct/Reconstruction=
碎片 Sprite 群 + Tween 编排(不用 shader dissolve);Beat Event=
beat_clock 订阅器;错位抖动=镜头 offset(既有 kick 扩展)。

---

## 卷十五 · 禁止清单(补充)

故障彩偏 / 辉光溢出 / 径向渐变光斑 / 弹性回弹 / 全屏同频抽搐 /
无语义 Shake / 周身光环 / 普通溶解(非 Deconstruct)/ 每按钮自实现
特效。违者 = 不合入。
