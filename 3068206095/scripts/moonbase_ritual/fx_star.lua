-- 月台仪式 · 升级完成光球特效
-- 对应原版 moonbase 的 ShowColdStar / HideColdStar。
-- 仪式成功后，月台上方悬停一颗冷光星；取下武器 / 月台被毁时移除。
--
-- 注意：本文件是 require 进来的普通模块，引擎接口从 GLOBAL 取。

local G = require("moonbase_ritual/genv")

local SpawnPrefab = G.Lazy("SpawnPrefab")

local FxStar = {}

local STAR_PREFAB = "staffcoldlightfx"

-- 显示光球（幂等）
function FxStar.Show(i)
	if i._spearstar == nil then
		i._spearstar = SpawnPrefab(STAR_PREFAB)
		if i._spearstar ~= nil then
			i._spearstar.entity:SetParent(i.entity)
			if i.Light:IsEnabled() then
				i.AnimState:SetBloomEffectHandle("shaders/anim.ksh")
			end
		end
	end
end

-- 隐藏光球（幂等）
function FxStar.Hide(i)
	if i._spearstar ~= nil then
		i._spearstar:Remove()
		i._spearstar = nil
		if not i.Light:IsEnabled() then
			i.AnimState:ClearBloomEffectHandle()
		end
	end
end

return FxStar
