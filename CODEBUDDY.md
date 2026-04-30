# CODEBUDDY.md This file provides guidance to CodeBuddy when working with code in this repository.

## 项目概述

这是一个 **Don't Starve Together（饥荒联机版）** 模组（Mod），ID 为 `3253411834`，名为 **"装备自动修理" (EquipAutoRepair)**，作者 Larkin，版本 2.6。

功能：为游戏中各类可消耗装备（护符、护甲、帽子、服装、照明工具等）附加一个**内嵌容器格子**，当装备被使用消耗时，自动从该容器中取出对应修复材料进行补充/修复。

## 模组结构

```
3253411834/                # 模组根目录（文件夹名 = Steam Workshop ID）
  ├── modinfo.lua          # 模组元数据 + 配置选项（配置项、多语言标签）
  ├── modmain.lua          # 所有逻辑代码（单一文件，约867行）
  ├── mod.manifest         # 二进制清单文件
  ├── modicon.tex          # 模组图标（纹理）
  └── modicon.xml          # 模组图标（atlas 定义）

scripts/                   # DST 游戏本体脚本副本（仅作开发参考，非模组代码）
  ├── main.lua
  ├── tuning.lua           # 游戏数值常量
  ├── components/          # 游戏组件（armor, fueled, finiteuses, forgerepairable, sewing 等）
  ├── prefabs/             # 游戏预制体定义（yellowamulet, lantern, minerhat 等）
  ├── containers.lua       # 容器定义（模组通过修改此文件添加自定义容器）
  ├── stategraphs/
  ├── brains/
  ├── screens/
  ├── widgets/
  └── ...
```

## 架构与核心设计

### 模组入口：modmain.lua

所有逻辑集中于 `3253411834/modmain.lua`，不拆分文件。

### 核心流程

1. **配置加载**：启动时读取 `GetModConfigData()` 获取每个装备的启用开关、槽位顺序、防腐开关等设置。
2. **装备配置表**：`item_config` 是核心数据结构，每个 key 是游戏 prefab 名（如 `yellowamulet`, `lantern`），value 包含：
   - `itemtestfn` — 判定什么材料可放入修复格子
   - `pos` / `posh` — 格子 UI 位置
   - `type` — 修复类型：`fuel`（燃料）、`fit`（耐久）、`armor`（护甲）
   - `repair_type` — 底层修复机制：`forge`（锻造修复）、`sewing`（缝纫）、`eat`（进食）、`repairable`（可修复组件）
   - `accurately` — 是否在每次变化时检查修复（比仅监听 depleted/onfinished 更精确）
   - `custom_order` — 多装备槽位排序
   - `isFuelNeed` — 自定义"是否需要修复"判断函数
3. **容器注册**：遍历 `item_config`，调用 `containers.params[prefab .. "_container"]` 注册 UI 容器，每个容器只有 1 个格子（眼面具和恐怖盾牌有 2 个）。格子通过 `itemtestfn` 限制只接受对应修复材料。
4. **后处理钩子**：`AddPrefabPostInit(prefab, addAutorepair)` 为每个启用的装备注册初始化函数 `addAutorepair()`。该函数：
   - 添加 `container` 组件，设置 `canbeopened = false`，在装备时自动打开/关闭
   - 可选启用"永久保鲜"（添加 `preserver` 组件，腐败速率为 0）
   - 根据 `repair_type` 挂载对应的修复钩子：

### 修复机制与钩子

| repair_type | 钩子方式 | 触发时机 |
|---|---|---|
| `fuel` | 覆盖 `fueled.depleted` + 可选 `fueled.DoDelta` | 燃料耗尽时 / 燃料变化时（精确模式） |
| `fit` （finiteuses） | 覆盖 `finiteuses.onfinished` + 可选 `percentusedchange` 事件 | 耐久耗尽时 / 百分比变化时（精确模式） |
| `armor` （forge） | 覆盖 `armor.onfinished` + 勾住 `forgerepairable.onrepaired` | 护甲破碎时 / 修复完成后（恢复容器） |
| `armor` （eat） | 监听 `percentusedchange` 事件 | 护甲耐久变化时 |
| `repairable` | 监听 `percentusedchange` 事件 + 调用 `repairable:Repair` | 百分比变化时 |
| `sewing` | 调用 `sewing:DoSewing` | 燃料耗尽/耐久耗尽时 |

### 关键数据流

```
装备被装备 → container.canbeopened = true, 自动打开格子
用户放入修复材料 → itemtestfn 校验材料是否匹配
装备使用（耐久/燃料降低）→ 触发对应 OnFinished/DoDelta/percentusedchange
  → checkAndRepair() 从 container:FindItem 取出材料
    → 根据 repair_type 调用对应修复 API（TakeFuelItem / Repair / DoSewing / Eat）
    → 若修复成功则不触发原始 depleted/onfinished（避免装备消失）
    → 若修复失败则调用原始函数（装备正常消耗/破碎）
```

### 游戏引擎概念参考

- **prefab**：游戏对象的模板名称（如 `lantern`, `yellowamulet`）
- **component**：附着在 prefab 上的功能模块（如 `fueled`, `finiteuses`, `armor`, `container`）
- **tuning.lua**：游戏数值常量定义
- **containers.lua**：容器 UI 参数定义（槽位布局、物品过滤）
- **`GLOBAL`**：DST 全局命名空间，模组通过 `env.__index = GLOBAL` 访问

## 常用命令

### 验证 modinfo.lua 配置
模组没有构建或测试脚本。验证模组配置正确性的方式是在游戏中加载模组并查看模组设置页面是否正常显示。也可以通过 Lua 语法检查验证文件：

```powershell
# Lua 语法检查（需安装 Lua）
luac -p 3253411834/modmain.lua
luac -p 3253411834/modinfo.lua
```

### 在本地测试模组
1. 将 `3253411834/` 文件夹复制或链接到 DST 的 mod 目录：
   - Windows: `%USERPROFILE%\Documents\Klei\DoNotStarveTogether\mods\`
2. 启动游戏，在 Mods 页面找到"装备自动修理"并启用。
3. 创建/加入世界，使用对应装备验证自动修理功能。
4. 游戏控制台日志可通过 `~` 键打开控制台查看 `[Debug] / [Info] / [Error]` 输出。调试日志可通过模组配置页面启用。

### 添加新装备支持
若需为新 prefab 添加自动修理支持：
1. 在 `item_config` 表中添加新条目
2. 在 `modinfo.lua` 的 `configuration_options` 中添加对应开关
3. 如有需要，将新 prefab 关联到已有配置（参考 `item_config.beargervest` 被多处复用的模式）
