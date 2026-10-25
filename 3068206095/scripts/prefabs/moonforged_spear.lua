-- 月淬奔雷矛
-- 属性与机制完全复用原版 "奔雷矛(普通)" spear_wathgrithr_lightning，
-- 在此之上额外附带：
--   1. 对暗影阵营 +25% 伤害（参考玻璃刀 glasscutter 的 damagetypebonus 实现）
--   2. 夜晚缓慢恢复耐久（在 modmain.lua 中通过 AddPrefabPostInit 复用 AddNightRepair 实现）
--
-- 复用方式：直接调用原版奔雷矛 Prefab 的构造函数 fn 来生成实体，
-- 避免重复实现女武神技能树（rechargeable / aoetargeting / aoeweapon_lunge 等）联动逻辑。
--
-- 外观：固定使用奔雷矛的"月光(lunar)"皮肤 build 与图标，与普通奔雷矛形成视觉区分。
-- lunar 是动态动画资源(DYNAMIC_ANIM)，需在 assets 中显式声明以加载。

local SPEAR_BASE = "spear_wathgrithr_lightning"

-- 对暗影阵营的增伤倍数（玻璃刀为 1.25，即 +25%）
local SHADOW_DAMAGE_BONUS = 1.25

-- 月淬外观：固定使用奔雷矛的"月光(lunar)"皮肤
local MOONFORGED_SKIN = "spear_wathgrithr_lightning_lunar"

local function fn(...)
	local inst = Prefabs[SPEAR_BASE].fn(...)

	if inst ~= nil then
		-- 3D 外观（地面/装备）：直接用 lunar 皮肤 build
		inst.AnimState:SetBuild(MOONFORGED_SKIN)

		-- 设置皮肤名，让 OnEquip 里 GetSkinBuild() 返回 lunar build，
		-- 从而装备在手上时 swap symbol 也使用 lunar 外观
		inst.skinname = MOONFORGED_SKIN

		if TheWorld.ismastersim then
			-- 物品栏图标：lunar 皮肤图标（依赖 DYNAMIC_ANIM 资源加载后注册的 atlas）
			if inst.components.inventoryitem ~= nil then
				inst.components.inventoryitem:ChangeImageName(MOONFORGED_SKIN)
			end

			-- 对暗影阵营增伤（参考 glasscutter.lua）
			local damagetypebonus = inst:AddComponent("damagetypebonus")
			damagetypebonus:AddBonus("shadowsubmissive", inst, SHADOW_DAMAGE_BONUS)
		end
	end

	return inst
end

local assets =
{
	Asset("ANIM", "anim/spear_wathgrithr_lightning.zip"),
	Asset("DYNAMIC_ANIM", "anim/dynamic/"..MOONFORGED_SKIN..".zip"),
	Asset("PKGREF", "anim/dynamic/"..MOONFORGED_SKIN..".dyn"),
}

return Prefab("moonforged_spear", fn, assets, Prefabs[SPEAR_BASE].deps)
