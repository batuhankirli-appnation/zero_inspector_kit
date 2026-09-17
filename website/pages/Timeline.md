# Timeline / 统一会话时间线

## Overview / 概述

The Timeline tab merges network, logs, errors, routes, and alerts into a **single time-ordered stream**, so you can see the full causal chain of a session at a glance — e.g. "route push → two requests → error log → 5xx alert". Each source keeps its own data; the Timeline view only merges them for display.

统一会话时间线把网络、日志、异常、路由、告警归并为**一条按时间排序的流**，让你一眼看清一次会话的完整因果链——例如「路由跳转 → 两个请求 → error 日志 → 5xx 告警」。各来源的数据仍归属各自服务，时间线视图只做归并显示。

> **Available since v1.12.0**
>
> **v1.12.0 起可用**

## Where to find it / 入口

Tap the floating inspector button → the **Timeline** tab (located after **Routes** and before **Widgets** in the panel).

点击悬浮检查器按钮 → **Timeline** 标签页（位于面板中 **Routes** 之后、**Widgets** 之前）。

## Features / 功能

### 1. Merged stream / 归并流

- Network / Logs / Errors / Routes / Alerts appear interleaved by timestamp / 网络 / 日志 / 异常 / 路由 / 告警按时间戳交错排列
- Each entry shows its source icon, a colored left accent bar, timestamp, and a concise summary / 每条显示来源图标、左侧彩色强调条、时间戳与精炼摘要
- Tap any entry to expand details (e.g. request URL/status, log level/message, route action/name) / 点击任意条目展开详情（如请求 URL/状态、日志级别/内容、路由操作/名称）

把五类数据按时间归并，每条带来源图标、彩色强调条、时间戳与摘要，可点击展开。

### 2. Per-source filtering / 逐来源筛选

- Toggle each source on/off to focus on the ones you care about / 逐来源开关，只看关心的来源
- Filtering only hides entries from the merged view; underlying data is untouched / 筛选只隐藏归并视图中的条目，底层数据不受影响

顶部可按来源开关自由筛选，归并显示内容随之变化，底层数据不变。

### 3. Focus ±N seconds / ±N 秒聚焦

- Tap any event to enter "focus" mode: the view keeps only events within ±N seconds of the anchor / 点击任意事件进入「聚焦」模式，仅保留锚点前后 ±N 秒内的事件
- Window selector: 5s / 10s (default) / 30s / 窗口可选：5s / 10s（默认）/ 30s
- Great for isolating the exact cause-effect around a failure (e.g. what happened right before a 5xx alert) / 适合隔离某次失败前后的精确因果（如 5xx 告警前到底发生了什么）

点击任意事件即可「聚焦它前后 ±N 秒」，把噪音过滤掉，只留因果相关事件。

## How It Works / 工作原理

- **View-only merge** — `TimelineService.build()` reads from `InspectorService` (network / logs / errors), `RouteTrackerService`, and `AlertService`, sorts them by time, and tags each with its `TimelineEventKind`. It does **not** copy or own any data. / **仅视图归并**：`TimelineService.build()` 从各服务读取数据、按时间排序并打上来源标签，不复制、不持有数据。
- **Zero cost when closed** — no timers, no listeners, no polling while the panel is not open; the merge runs on demand when you open the Timeline tab. / **面板关闭时零开销**：未打开面板时不跑定时器、不监听、不轮询，仅在打开 Timeline 时按需归并。
- **`contextAround(anchor, window)`** — given an anchor event and a `Duration` window, returns the slice of events whose timestamp falls within `[anchor - window, anchor + window]`, oldest-first. / 给定锚点事件与窗口时长，返回落在 `[锚点 - 窗口, 锚点 + 窗口]` 内的事件，按时间升序。

## Related / 相关

- [Usage](Usage) — General usage guide / 通用使用指南
- [FPS Viewer](FPS-Viewer) — Includes the main-thread blocking watchdog / 含主线程阻塞看门狗
- [Route Tracker](Route-Tracker) — Route tracking details / 路由追踪详情
