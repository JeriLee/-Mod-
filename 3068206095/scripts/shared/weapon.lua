-- 共享配置 · 武器身份
--
-- 月台仪式（moonbase_ritual）与古铸（ancient_cast）改的是同一把奔雷矛，
-- 所以 prefab 名放在这里共用，避免两处各写一份后对不上。

local Shared = {}

-- 普通奔雷矛
Shared.SPEAR = "spear_wathgrithr_lightning"

-- 充能奔雷矛
Shared.SPEAR_CHARGED = "spear_wathgrithr_lightning_charged"

-- 奔雷矛的全部皮肤后缀
Shared.SPEAR_SKINS = { "lunar", "valkyrie", "wrestle", "northern" }

return Shared
