-- 月台仪式 · 充能光柱染色
--
-- 为什么要单独放在这里？
--   SetMultColour 在服务端调用对客户端无效，必须在两端各自执行。
--   所以给三个 FX prefab 各挂一个 AddPrefabPostInit，让每个客户端
--   在自己的 FX 实体上染色。
--
-- 判断依据：查找脚下的月台，若其 _thunderspear_net 为真（插着矛）则染色。
--
-- 注意：本文件是 require 进来的普通模块，引擎接口从 GLOBAL 取。

local G = require("shared/genv")
local Config = require("moonbase_ritual/config")

local AddPrefabPostInit = G.Get("AddPrefabPostInit")
local FindEntity = G.Get("FindEntity")

local BeamTint = {}

local BEAM_COLOURS = {
	positronbeam_back = Config.BEAM_COLOUR_BACK,
	positronbeam_front = Config.BEAM_COLOUR_FRONT,
	positronpulse = Config.BEAM_COLOUR_PULSE,
}

local MOONBASE_TAG = { "moonbase" }

local function TintBeamForSpear(inst)
	inst:DoTaskInTime(0, function(i)
		if not i:IsValid() then
			return
		end

		local c = BEAM_COLOURS[i.prefab]
		if c == nil then
			return
		end

		-- 查找脚下月台，判断是否插着武器
		local mb = FindEntity(i, 4, nil, MOONBASE_TAG)
		if mb ~= nil and mb._thunderspear_net ~= nil
			and mb._thunderspear_net:value() then
			i.AnimState:SetMultColour(c[1], c[2], c[3], c[4])
		end
	end)
end

function BeamTint.Register()
	for name in pairs(BEAM_COLOURS) do
		AddPrefabPostInit(name, TintBeamForSpear)
	end
end

return BeamTint
