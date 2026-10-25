-- 奔雷矛 · 雷萃状态 HUD 指示器
--
-- 在玩家 HUD 上显示「雷萃」的图标与剩余时间。
--
-- 实现要点（均使用本体原生机制，无需额外美术资源）：
--   1. 倒计时环 + 数字：复用 widgets/badge 的 Badge 基类
--      （圆形进度环 status_meter_circle + 中央数字），
--      与本体的「复仇幽灵」倒计时徽章是同一套做法。
--   2. 图标：用 GetInventoryItemAtlas + widgets/image
--      直接取本体的避雷针物品图标。
--   3. 数据来源：服务端把剩余秒数写在武器的 net 变量上
--      （见 lightningrod.lua 的 _lightningrod_net），
--      客户端读玩家手上那把奔雷矛的值即可；
--      读不到时回退到玩家分类对象上的备用通道。
--   4. 挂载点：HUD 里的状态徽章群（ThePlayer.HUD.controls.status），
--      和本体 health/sanity/hunger 徽章同一个坐标系。
--
-- 入口：客户端进入世界时，HUD / ThePlayer 可能都还没就绪，
-- 所以这里用了多个入口 + 定时重试，只要有一个能跑起来就会挂上。
--
-- 注意：本文件是 require 进来的普通模块，默认 _G 带 strict，
-- 所有引擎接口都要从 genv 桥接表取（见 genv.lua）。
-- ThePlayer / TheFrontEnd 都是运行时才赋值的全局，要用 G.Global 实时取。

local G = require("moonbase_ritual/genv")

local TUNING = G.Get("TUNING")
local Class = G.Get("Class")
local GetInventoryItemAtlas = G.Get("GetInventoryItemAtlas")
local EQUIPSLOTS = G.Get("EQUIPSLOTS")
local AddPlayerPostInit = G.Get("AddPlayerPostInit")
local AddSimPostInit = G.Get("AddSimPostInit")

local LightningRodHud = {}

-- 已创建的 badge 实例
local badge = nil
-- badge 类（延迟创建）
local badgeclass = nil
-- 是否已经在重试挂载
local retrying = false
-- 上一次的诊断信息（变了才打印，避免刷屏）
local lastdiag = nil

-- 电光配色
local TINT = { 235/255, 200/255, 80/255, 1 }

-- 指示器在状态徽章群里的位置（徽章群在屏幕正上方）
-- Y 轴向上为正，徽章群在 y=-150 处，往下移就是让 Y 变大（趋近 0）
local HUD_X = 0
local HUD_Y = -288

-- 倒计时总长度：一天（= 一个完整昼夜循环）
local MAX_TIME = TUNING.TOTAL_DAY_TIME

--------------------------------------------------------------------------
-- 诊断：把当前状态打印到日志（内容变化时才打印）
--------------------------------------------------------------------------
local function Diag(str)
	if str ~= lastdiag then
		lastdiag = str
		print("[雷萃HUD] " .. str)
	end
end

--------------------------------------------------------------------------
-- 取玩家的背包
--
-- 主机（listen server）上 ThePlayer 可能指向两边的实体之一：
--   1. frontend 的 replica 实体 -> 有 replica.inventory（客户端数据）
--   2. server sim 的玩家实体   -> 有 components.inventory（权威数据）
-- 两种都能读，所以做个兜底，避免在主机上读不到数据。
--------------------------------------------------------------------------
local function GetInventory(player)
	if player == nil then
		return nil
	end

	if player.replica ~= nil and player.replica.inventory ~= nil then
		return player.replica.inventory
	end

	if player.components ~= nil and player.components.inventory ~= nil then
		return player.components.inventory
	end

	return nil
end

--------------------------------------------------------------------------
-- 在玩家的物品里找带雷萃状态的奔雷矛
-- 先看手上（主要使用场景），再看背包
--------------------------------------------------------------------------
local function FindBuffedItem()
	local player = G.Global("ThePlayer")
	if player == nil then
		return nil, nil, "no player"
	end

	local inv = GetInventory(player)
	if inv == nil then
		return nil, nil, "no inventory"
	end

	local function check(item)
		if item == nil then
			return nil
		end
		if item._lightningrod_net == nil then
			return nil
		end
		local t = item._lightningrod_net:value()
		if t == nil or t <= 0 then
			return nil
		end
		return item, t
	end

	-- 手上
	local equipped = inv:GetEquippedItem(EQUIPSLOTS.HANDS)
	local item, t = check(equipped)
	if item ~= nil then
		return item, t, "equipped"
	end

	-- 背包里也找一下
	local slots = inv.GetSlots ~= nil and inv:GetSlots() or nil
	if slots ~= nil then
		for _, v in ipairs(slots) do
			item, t = check(v)
			if item ~= nil then
				return item, t, "inventory"
			end
		end
	end

	-- 没找到时报告一下手持的是什么，方便排查
	if equipped ~= nil then
		return nil, nil, "equipped=" .. tostring(equipped.prefab)
			.. " netvar=" .. tostring(equipped._lightningrod_net ~= nil)
	else
		return nil, nil, "no equipped item"
	end
end

--------------------------------------------------------------------------
-- 取剩余时间
-- 优先读武器上的 net 变量，读不到再读玩家分类对象上的备用通道
--------------------------------------------------------------------------
local function GetBuffTime()
	local item, t, where = FindBuffedItem()
	if item ~= nil then
		return t, where
	end

	-- 备用通道：玩家分类对象
	local player = G.Global("ThePlayer")
	if player ~= nil
		and player.player_classified ~= nil
		and player.player_classified._mod_lightningrod_time ~= nil then
		local v = player.player_classified._mod_lightningrod_time:value()
		if v ~= nil and v > 0 then
			return v, "classified"
		end
	end

	return nil, where
end

--------------------------------------------------------------------------
-- 创建 badge 类
--------------------------------------------------------------------------
local function EnsureBadgeClass()
	if badgeclass ~= nil then
		return badgeclass
	end

	local Badge = require("widgets/badge")
	local Image = require("widgets/image")

	badgeclass = Class(Badge, function(self, owner)
		-- anim=nil, owner, tint, iconbuild=nil, circular_meter=true,
		-- use_clear_bg=nil, dont_update_while_paused=true, bonustint=nil
		Badge._ctor(self, nil, owner, TINT, nil, true, nil, true, nil)

		-- 图标：避雷针的物品图标（本体资源，无需额外美术）
		local atlas = GetInventoryItemAtlas("lightning_rod.tex")
		if atlas ~= nil then
			self.bufficon = self:AddChild(Image(atlas, "lightning_rod.tex", "default.tex"))
			self.bufficon:SetPosition(0, 42, 0)
			self.bufficon:SetScale(.4)
			self.bufficon:SetClickable(false)
		end

		-- 剩余时间数字（Badge 自带的 num），往下挪一点避开图标
		self.num:SetPosition(0, -6, 0)
		self.num:Show()

		self:Hide()
		self:StartUpdating()
	end)

	-- 每帧刷新
	function badgeclass:OnUpdate()
		local t, where = GetBuffTime()

		if t == nil then
			self:Hide()
			Diag("未找到雷萃计时：" .. tostring(where))
			return
		end

		self:Show()
		Diag("显示雷萃倒计时（" .. tostring(where) .. "）")

		-- 圆形倒计时环
		local percent = MAX_TIME > 0 and (t / MAX_TIME) or 0
		self:SetPercent(percent, MAX_TIME)

		-- 数字显示成 mm:ss
		local mins = math.floor(t / 60)
		local secs = math.floor(t % 60)
		self.num:SetString(string.format("%d:%02d", mins, secs))
	end

	return badgeclass
end

--------------------------------------------------------------------------
-- 找到状态徽章群作为挂载点
--------------------------------------------------------------------------
local function GetStatusRoot(player)
	local hud = player.HUD
	if hud == nil then
		return nil
	end
	-- 本体把状态徽章群放在 HUD 的 controls.status 里
	if hud.controls ~= nil and hud.controls.status ~= nil then
		return hud.controls.status
	end
	return hud
end

--------------------------------------------------------------------------
-- 主入口：把指示器挂到玩家 HUD 上
--------------------------------------------------------------------------
function LightningRodHud.Setup()
	-- 注意：不能用 TheWorld.ismastersim 来判断"是不是服务器"！
	-- 主机（listen server）上 server sim 与 client UI 在同一个进程里跑，
	-- ismastersim 为 true，但主机玩家同样需要看到 HUD。
	-- 真正的判定标准是"本地有没有 HUD"：
	-- 纯服务器没有 frontend，也就没有 ThePlayer / HUD，天然挂不上。

	local player = G.Global("ThePlayer")
	if player == nil then
		Diag("Setup: 还没有 ThePlayer")
		return false
	end

	local root = GetStatusRoot(player)
	if root == nil then
		Diag("Setup: ThePlayer.HUD 还没建好")
		return false
	end

	local class = EnsureBadgeClass()

	if badge == nil then
		badge = class(player)
		badge:SetPosition(HUD_X, HUD_Y, 0)
		badge:SetScale(.85)
	end

	-- HUD 可能被重建（复活 / 换人），需要时重新挂上
	if badge.parent ~= root then
		root:AddChild(badge)
		badge:SetPosition(HUD_X, HUD_Y, 0)
	end

	Diag("Setup: 指示器已挂到 HUD")

	return true
end

--------------------------------------------------------------------------
-- 重试挂载：HUD / ThePlayer 可能比玩家实体稍晚才就绪
--
-- host 是用来跑定时器的实体。
-- 一定要优先用外部传入的宿主，不能只依赖 ThePlayer ——
-- 因为回调触发的那一刻 ThePlayer 很可能还没赋值。
--------------------------------------------------------------------------
function LightningRodHud.StartRetry(host)
	if retrying then
		return
	end

	-- 找一个能跑定时器的宿主
	-- 注意顺序：主机（listen server）上 server env 里 TheWorld 一定存在，
	-- 而 ThePlayer 要等 frontend 建好 HUD 之后才有值。
	if host == nil then
		host = G.Global("TheWorld")
	end
	if host == nil then
		-- 前端的根 widget 实体：纯客户端一定存在
		local fe = G.Global("TheFrontEnd")
		if fe ~= nil and fe.screenroot ~= nil then
			host = fe.screenroot.inst
		end
	end
	if host == nil then
		host = G.Global("ThePlayer")
	end
	if host == nil then
		Diag("StartRetry: 找不到定时器宿主")
		return
	end

	retrying = true
	host:DoPeriodicTask(1, function()
		if LightningRodHud.Setup() then
			retrying = false
			return nil
		end
	end)
end

--------------------------------------------------------------------------
-- 入口：注册所有可能的触发点
--------------------------------------------------------------------------
function LightningRodHud.Start()
	Diag("Start()")

	local function TrySetup(host)
		if LightningRodHud.Setup() then
			return true
		end
		LightningRodHud.StartRetry(host)
		return false
	end

	-- 入口1：玩家实体创建（客户端 / 服务端都会触发）
	if AddPlayerPostInit ~= nil then
		AddPlayerPostInit(function(inst)
			inst:DoTaskInTime(0, function()
				TrySetup(inst)
			end)
		end)
	end

	-- 入口2：世界开始（客户端进世界时必定触发，gamelogic.lua 里调用）
	if AddSimPostInit ~= nil then
		AddSimPostInit(function()
			TrySetup(G.Global("TheWorld"))
		end)
	end

	-- 入口3：立刻试一次（可能 ThePlayer / HUD 已经就绪）
	TrySetup(nil)

	return true
end

return LightningRodHud
