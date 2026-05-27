# 句子播放完成状态

## 需求

- 记录每个切片（sentence）的播放完成状态
- 播放位置经过句子结束时间点即标记为"已完成"
- 已完成的切片字幕文字显示为灰色
- 音频所有切片都完成后，音频列表图标更换

## 设计

### 数据层

- `sentences` 表新增 `completed` 列（INTEGER NOT NULL DEFAULT 0）
- `Sentence` 模型新增 `completed` 字段（bool, 默认 false）
- 数据库版本 3 → 4，migration: `ALTER TABLE sentences ADD COLUMN completed INTEGER NOT NULL DEFAULT 0`
- `SentenceRepository` 新增 `markCompleted(id)` 方法

### 逻辑层

- `PlayerNotifier` 位置更新中，当播放位置经过当前句子 `endTimeMs` 时，调用 `markCompleted` 写库并更新状态
- 在句子切换（`_onSentenceComplete`）时也标记完成

### UI 层

- `SentenceCard`：`completed == true` 时文字颜色改为灰色（`theme.disabledColor`）
- `_AudioFileListTile`：查询该音频是否有未完成句子（`SELECT COUNT(*) FROM sentences WHERE audioFileId = ? AND completed = 0`），结果为 0 则使用 `Icons.check_circle` 替代 `Icons.audiotrack`

### 状态判定时机

- 播放器位置流更新时检查是否经过句子终点
- 进入播放页加载句子时读取 completed 状态
- 音频列表页按需查询全部完成状态
