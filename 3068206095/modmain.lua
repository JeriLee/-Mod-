GLOBAL.setmetatable(env,{__index=function(t,k) return GLOBAL.rawget(GLOBAL,k) end})  --GLOBAL相关照抄


PrefabFiles = {
	"wigfridarmor",
}

Assets = {
}

STRINGS.NAMES.WIGFRIDARMOR = "女武神战甲"
STRINGS.RECIPE_DESC.WIGFRIDARMOR = "女武神要有像样的战甲，我看石头和金子就很合适嘛"
STRINGS.CHARACTERS.GENERIC.DESCRIBE.WIGFRIDARMOR = "他很适合女武神."

AddRecipe("wigfridarmor",
{Ingredient("goldnugget", 2),Ingredient("rocks", 2)},
RECIPETABS.WAR, TECH.NONE,
nil, nil, nil, nil, "valkyrie",
"images/inventoryimages/wigfridarmor.xml",
"wigfridarmor.tex")


--------------------------------------------------------------------------
-- 奔雷矛 · 月台充能
--------------------------------------------------------------------------

local SPEAR = "spear_wathgrithr_lightning"
local SPEAR_CHARGED = "spear_wathgrithr_lightning_charged"
local REPAIR_MATERIAL = "thulecite_pieces"

local function GetCfg(key, default)
	local ok, v = pcall(GetModConfigData, key)
	if ok and v ~= nil then
		return v
	end
	return default
end

local ENABLE = GetCfg("ThunderSpear_Enable", true)
local CHARGES = GetCfg("ThunderSpear_Charges", 1)
local NIGHT_HOURS = GetCfg("ThunderSpear_NightHours", 12)
local REPAIR_HP = GetCfg("ThunderSpear_RepairHP", 2)


if ENABLE then

	local function IsSpear(item)
		return item ~= nil and (item.prefab == SPEAR or item.prefab == SPEAR_CHARGED)
	end

	local function MoonIsFixed(inst)
		local w = inst.components.workable
		return w ~= nil and (w.workleft or 0) > TUNING.MOONBASE_DAMAGED_WORK
	end

	local function MoonHasSpear(inst)
		return inst._thunderspear ~= nil
	end

	------------------------------------------------------------------------
	-- 插入
	------------------------------------------------------------------------
	local function MoonInsert(inst, item)
		if item == nil or not IsSpear(item) or MoonHasSpear(inst) then
			return false
		end
		if not MoonIsFixed(inst) then
			return false
		end

		local uses = item.components.finiteuses ~= nil and item.components.finiteuses:GetPercent() or 1
		local skinname = item.skinname
		local skinid = item.skin_id

		inst._thunderspear = item.prefab
		inst._thunderspear_uses = uses
		inst._thunderspear_skin = skinname
		inst._thunderspear_skinid = skinid
		inst._thunderspear_charges = 0
		inst._thunderspear_charging = nil

		-- 生成一个真正的武器实体挂到月台上（复用 _staffinst 字段）
		local proxy = SpawnPrefab(item.prefab, skinname, skinid)
		if proxy ~= nil then
			if proxy.components.finiteuses ~= nil then
				proxy.components.finiteuses:SetPercent(uses)
			end
			inst:AddChild(proxy)
			proxy.Transform:SetPosition(0, 0, 0)
			proxy:RemoveFromScene()
			inst._staffinst = proxy
			inst._staffuse = nil
		end

		-- 显示矛符号
		inst.AnimState:OverrideSymbol("swap_staffs", "staffs", "yellowstaff")

		inst.SoundEmitter:PlaySound("dontstarve/common/together/moonbase/moonstaff_place")

		-- 同步"插着矛"状态给客户端
		if inst._thunderspear_net ~= nil then
			inst._thunderspear_net:set(true)
		end

		return true
	end

	------------------------------------------------------------------------
	-- 取下
	------------------------------------------------------------------------
	local function MoonTakeOut(inst, doer)
		if not MoonHasSpear(inst) then
			return nil
		end

		local uses = inst._thunderspear_uses or 1

		-- 停掉充能
		inst._thunderspear_charging = nil
		if inst.components.timer ~= nil then
			inst.components.timer:StopTimer("mooncharge")
			inst.components.timer:StopTimer("mooncharge2")
			inst.components.timer:StopTimer("mooncharge3")
			inst.components.timer:StopTimer("moonchargepre")
		end
		if inst.components.moonbeastspawner ~= nil then
			inst.components.moonbeastspawner:Stop()
		end
		inst:RemoveTag("intense")

		-- 取出代理实体
		local result = nil
		if inst._staffinst ~= nil and inst._staffinst:IsValid() then
			inst:RemoveChild(inst._staffinst)
			inst._staffinst:ReturnToScene()
			if inst._staffinst.components.finiteuses ~= nil then
				inst._staffinst.components.finiteuses:SetPercent(uses)
			end
			result = inst._staffinst
			inst._staffinst = nil
		else
			local spear = inst._thunderspear
			local skinname = inst._thunderspear_skin
			local skinid = inst._thunderspear_skinid
			result = SpawnPrefab(spear, skinname, skinid)
			if result ~= nil and result.components.finiteuses ~= nil then
				result.components.finiteuses:SetPercent(uses)
			end
		end

		-- 清空状态
		inst._thunderspear = nil
		inst._thunderspear_uses = nil
		inst._thunderspear_skin = nil
		inst._thunderspear_skinid = nil
		inst._thunderspear_charges = 0
		inst._staffuse = nil

		inst.AnimState:ClearOverrideSymbol("swap_staffs")
		inst.SoundEmitter:PlaySound("dontstarve/common/together/moonbase/moonstaff_place")

		if inst._thunderspear_net ~= nil then
			inst._thunderspear_net:set(false)
		end

		return result
	end

	------------------------------------------------------------------------
	-- 喂碎片
	------------------------------------------------------------------------
	local function MoonFeed(inst, doer)
		if not MoonHasSpear(inst) or MoonIsFixed(inst) then
			return false
		end
		if doer == nil or not doer:IsValid() or doer.components.inventory == nil then
			return false
		end

		local item = doer.components.inventory:FindItem(function(o)
			return o ~= nil and o.prefab == REPAIR_MATERIAL
		end)
		if item == nil then
			return false
		end

		if item.components.stackable ~= nil and item.components.stackable:IsStack() then
			item.components.stackable:Get(1):Remove()
		else
			item:Remove()
		end

		-- 补武器耐久 25%
		if inst._thunderspear_uses ~= nil then
			inst._thunderspear_uses = math.min(1, inst._thunderspear_uses + 0.25)
			if inst._staffinst ~= nil and inst._staffinst:IsValid()
				and inst._staffinst.components.finiteuses ~= nil then
				inst._staffinst.components.finiteuses:SetPercent(inst._thunderspear_uses)
			end
		end

		-- 补月台损坏值
		local w = inst.components.workable
		if w ~= nil then
			w:SetWorkLeft(math.min(w.maxwork or 0, (w.workleft or 0) + REPAIR_HP))
			if MoonIsFixed(inst) and inst.components.trader ~= nil then
				inst.components.trader:Enable()
			end
		end

		inst.SoundEmitter:PlaySound("dontstarve/common/together/moonbase/repair")

		return true
	end

	------------------------------------------------------------------------
	-- 动作
	------------------------------------------------------------------------
	local ACT = AddAction("WIGFRIDARMOR_MOONREPAIR", "使用", function(act)
		local doer = act.doer
		local target = act.target
		if doer == nil or target == nil or not target:IsValid() then
			return false
		end

		if not TheWorld.ismastersim then
			return true
		end

		-- 手上有矛 -> 插入
		if act.invobject ~= nil and IsSpear(act.invobject) then
			if MoonInsert(target, act.invobject) then
				act.invobject:Remove()
				return true
			end
			return false
		end

		-- 插着矛且空手 -> 取下
		if act.invobject == nil and MoonHasSpear(target) then
			local item = MoonTakeOut(target, doer)
			if item ~= nil and doer.components.inventory ~= nil then
				doer.components.inventory:GiveItem(item, nil, target:GetPosition())
				return true
			end
			return false
		end

		-- 喂碎片
		return MoonFeed(target, doer)
	end)

	ACT.mount_valid = true
	ACT.distance = 2
	ACT.priority = 1

	STRINGS.ACTIONS.WIGFRIDARMOR_MOONREPAIR = "使用"
	STRINGS.ACTIONS.WIGFRIDARMOR_MOONREPAIR_GENERIC = "使用"

	------------------------------------------------------------------------
	-- 客户端动作预检
	-- EQUIPPED 类型：用"手上装备的物品"作用于"目标物体"
	-- 挂在 weapon 组件上（奔雷矛有 weapon 组件），inst = 手上的矛，target = 月台
	------------------------------------------------------------------------
	AddComponentAction("EQUIPPED", "weapon", function(inst, doer, target, actions, right)
		if right or doer == nil or doer.replica == nil or doer.replica.inventory == nil then
			return
		end
		if target == nil or not target:HasTag("moonbase") then
			return
		end

		-- 手上有矛 -> 插入
		if IsSpear(inst) then
			table.insert(actions, ACTIONS.WIGFRIDARMOR_MOONREPAIR)
		end
	end)

	-- SCENE 类型：空手取下 / 手拿碎片喂
	AddComponentAction("SCENE", "inspectable", function(inst, doer, actions, right)
		if right or doer == nil or doer.replica == nil or doer.replica.inventory == nil then
			return
		end
		if not inst:HasTag("moonbase") then
			return
		end

		-- 插着矛（客户端看 net 变量）且空手 -> 取下
		local has_spear = inst._thunderspear_net ~= nil and inst._thunderspear_net:value() or false
		if has_spear then
			table.insert(actions, ACTIONS.WIGFRIDARMOR_MOONREPAIR)
			return
		end

		-- 有碎片 -> 喂
		for i = 1, doer.replica.inventory:GetNumSlots() do
			local it = doer.replica.inventory:GetItemInSlot(i)
			if it ~= nil and it.prefab == REPAIR_MATERIAL then
				table.insert(actions, ACTIONS.WIGFRIDARMOR_MOONREPAIR)
				return
			end
		end
	end)

	AddStategraphActionHandler("wilson", ActionHandler(ACTIONS.WIGFRIDARMOR_MOONREPAIR, "dolongaction"))
	AddStategraphActionHandler("wilson_client", ActionHandler(ACTIONS.WIGFRIDARMOR_MOONREPAIR, "dolongaction"))

	------------------------------------------------------------------------
	-- 月台：同步变量 + 月圆充能 + 存档
	------------------------------------------------------------------------
	AddPrefabPostInit("moonbase", function(inst)

		-- 同步"插着矛"状态（net 变量，两边都要建）
		if inst._thunderspear_net == nil then
			inst._thunderspear_net = net_bool(inst.GUID, "moonbase._thunderspear", "thunderspeardirty")
		end

		if not TheWorld.ismastersim then
			return
		end

		-- 月圆状态
		inst:WatchWorldState("isfullmoon", function(i, isfullmoon)
			if not MoonHasSpear(i) or not MoonIsFixed(i) then
				return
			end

			if isfullmoon then
				if not i._thunderspear_charging then
					i._thunderspear_charging = true
					if i.components.timer ~= nil then
						i.components.timer:StartTimer("mooncharge", TUNING.MOONBASE_CHARGE_DURATION)
					end
					if i.components.moonbeastspawner ~= nil then
						i.components.moonbeastspawner:Start()
					end
				end
			else
				i._thunderspear_charging = nil
				if i.components.timer ~= nil then
					i.components.timer:StopTimer("mooncharge")
					i.components.timer:StopTimer("mooncharge2")
					i.components.timer:StopTimer("mooncharge3")
				end
				if i.components.moonbeastspawner ~= nil then
					i.components.moonbeastspawner:Stop()
				end
				i:RemoveTag("intense")
			end
		end)

		-- 充能计时结束
		inst:ListenForEvent("timerdone", function(i, data)
			if data == nil or data.name ~= "mooncharge" then
				return
			end
			if not MoonHasSpear(i) or not i._thunderspear_charging then
				return
			end

			i._thunderspear_charging = nil
			i._thunderspear_charges = (i._thunderspear_charges or 0) + 1

			if i._thunderspear_charges < CHARGES then
				if i.components.moonbeastspawner ~= nil then
					i.components.moonbeastspawner:Stop()
				end
				i:RemoveTag("intense")
				return
			end

			-- 充满：换成充能版
			local uses = i._thunderspear_uses or 1
			local skinname = i._thunderspear_skin
			local skinid = i._thunderspear_skinid

			i._thunderspear = SPEAR_CHARGED
			i._thunderspear_charges = 0

			if i._staffinst ~= nil and i._staffinst:IsValid() then
				i:RemoveChild(i._staffinst)
				i._staffinst:Remove()
			end
			local proxy = SpawnPrefab(SPEAR_CHARGED, skinname, skinid)
			if proxy ~= nil then
				if proxy.components.finiteuses ~= nil then
					proxy.components.finiteuses:SetPercent(uses)
				end
				i:AddChild(proxy)
				proxy.Transform:SetPosition(0, 0, 0)
				proxy:RemoveFromScene()
				i._staffinst = proxy
				i._staffuse = nil
			end

			if i.components.moonbeastspawner ~= nil then
				i.components.moonbeastspawner:ForcePetrify()
				i.components.moonbeastspawner:Stop()
			end
			i:RemoveTag("intense")

			i.SoundEmitter:PlaySound("dontstarve/common/together/moonbase/beam_stop")
		end)

		-- 存档
		local oldOnSave = inst.OnSave
		inst.OnSave = function(i, data)
			if oldOnSave ~= nil then
				oldOnSave(i, data)
			end
			if MoonHasSpear(i) then
				data.thunderspear = i._thunderspear
				data.thunderspear_uses = i._thunderspear_uses
				data.thunderspear_skin = i._thunderspear_skin
				data.thunderspear_skinid = i._thunderspear_skinid
				data.thunderspear_charges = i._thunderspear_charges
			end
		end

		local oldOnLoad = inst.OnLoad
		inst.OnLoad = function(i, data)
			if oldOnLoad ~= nil then
				oldOnLoad(i, data)
			end
			if data ~= nil and data.thunderspear ~= nil then
				i._thunderspear = data.thunderspear
				i._thunderspear_uses = data.thunderspear_uses or 1
				i._thunderspear_skin = data.thunderspear_skin
				i._thunderspear_skinid = data.thunderspear_skinid
				i._thunderspear_charges = data.thunderspear_charges or 0

				i:DoTaskInTime(0, function(ii)
					if not ii:IsValid() or not MoonHasSpear(ii) then
						return
					end
					local proxy = SpawnPrefab(ii._thunderspear, ii._thunderspear_skin, ii._thunderspear_skinid)
					if proxy ~= nil then
						if proxy.components.finiteuses ~= nil then
							proxy.components.finiteuses:SetPercent(ii._thunderspear_uses or 1)
						end
						ii:AddChild(proxy)
						proxy.Transform:SetPosition(0, 0, 0)
						proxy:RemoveFromScene()
						ii._staffinst = proxy
						ii._staffuse = nil
					end
					ii.AnimState:OverrideSymbol("swap_staffs", "staffs", "yellowstaff")
					if ii._thunderspear_net ~= nil then
						ii._thunderspear_net:set(true)
					end
				end)
			end
		end
	end)

	------------------------------------------------------------------------
	-- 奔雷矛：夜晚缓慢恢复耐久
	------------------------------------------------------------------------
	local function AddNightRepair(inst)
		if not TheWorld.ismastersim then
			return
		end
		if inst.components.finiteuses == nil or NIGHT_HOURS <= 0 then
			return
		end

		local total = inst.components.finiteuses.total
		local seconds_per_use = (NIGHT_HOURS * TUNING.SEG_TIME) / math.max(1, total)

		inst._nightrepair_acc = 0

		inst:DoPeriodicTask(1, function(i)
			local fu = i.components.finiteuses
			if fu == nil then
				return
			end
			local uses = fu:GetUses()
			if uses <= 0 or uses >= fu.total then
				i._nightrepair_acc = 0
				return
			end
			if TheWorld.state.isday then
				i._nightrepair_acc = 0
				return
			end
			-- 插在月台上（成为子实体）不恢复
			if i.parent ~= nil then
				return
			end

			i._nightrepair_acc = i._nightrepair_acc + 1
			if i._nightrepair_acc >= seconds_per_use then
				local gain = math.floor(i._nightrepair_acc / seconds_per_use)
				i._nightrepair_acc = i._nightrepair_acc - gain * seconds_per_use
				fu:Repair(gain)
			end
		end)
	end

	local SPEAR_PREFABS = { SPEAR, SPEAR_CHARGED }
	local SPEAR_SKINS = { "lunar", "valkyrie", "wrestle", "northern" }

	for _, base in ipairs(SPEAR_PREFABS) do
		AddPrefabPostInit(base, AddNightRepair)
		for _, skin in ipairs(SPEAR_SKINS) do
			AddPrefabPostInit(base.."_"..skin, AddNightRepair)
		end
	end

end
