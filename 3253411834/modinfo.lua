local function Adaptive(en,zh,zht)local specify={zh=zh,zht=zht}return specify[locale]or en end

local NAME_MOD = Adaptive (
[[EquipAutoRepiar(2026.10.23Update)]]
,
[[装备自动修理(2026.10.23更新)]]
,
[[裝備自動修理(2026.10.23更新)]]
)

local DESC_MOD = Adaptive(
[[
	Equipped with automatic repair, suitable for five-compartment backpack mod,Suitable for six equipment slots

	If you don’t like the slots automatically opening when you equip something, you can enable the 'Turn Off Auto-Open Slots' feature. 
	If you don't like extra slots, you can turn on 'Find Materials from Player Inventory,' so there won’t be extra slots. But to support lanterns being automatically repaired when placed on the ground, the lantern slot is still kept. 
	Known game features:
		Feature 1: Once equipment has a slot, it can’t be copied by the Mimic Worm. If you want it copied, please disable the slot feature.
		Feature 2: Equipment with slots cannot be put into wrapping paper.

	Currently only items are supported:
	Amulet (Yellow Amulet,Orange Amulet)
	Clothing (Bearskin vest, cool summer dress, floppy vest, Breathable vest, houndtooth vest, raincoat, Belt of Hunger, Chirpy 3-set (Scarf/Cloak/Capelet))
	Hats (horn hat, eyeball umbrella, winter hat, rain hat, cat hat, rabbit ear muffs, Polly Roger's hat, Tam o' Shanter, straw hat, funky goggles, Desert goggles, Squirrel Pioneer hat, Salty Dog's Hat)
	Nightshade complete (Nightshade Sword, Nightshade helmet, Nightshade armor, Nightshade Wand, Nightshade Smasher, Nightshade Hoe, Brambleshade Armor)
	Shadow Set (Void Robe, Void Hood, Shadow Umbrella, Shadow Reaper, Shadow Maul, Gloomerang)
	Lighting (Lantern, miner's hat, Moggles, Shadow Thurible)
	Other Weapon(Alarming Clock)
	Other Armor(Bone Armor,EyeMask)
	Version:3.1
]],
[[
	禁止搬运！！！
	装备自动修理,适用于五格背包mod,适配六格背包
	如果不喜欢装备戴上的时候，自动打开格子，可以启用【关闭格子自动打开】功能
	如果不喜欢多余的格子，可以开启【从玩家背包寻找材料】这样就不会有额外格子。但是为了支持提灯放在地上自动修理，还是保留了提灯的格子。
	已知游戏特性：
		特性1：当装备拥有格子以后，就不能被拟态蠕虫复制。如果需要拟态蠕虫复制，请关闭格子功能。
		特性2：带有格子的装备不能放入打包纸。

	当前仅支持道具:
		护符(魔光护符,懒人护符)
		服装(熊皮背心,清凉夏装,松软背心,透气背心,犬牙背心,雨衣,饥饿腰带,叽叽喳喳三件套(围巾/披风/短披肩))
		帽子(牛角帽,眼球伞,冬帽,雨帽,猫帽,兔耳罩,波利罗杰的帽子,贝雷帽,草帽,时髦护目镜,沙漠护目镜,松鼠先锋队帽子,咸狗帽)
		亮茄全套(亮茄剑,亮茄头盔,亮茄盔甲,亮茄魔杖,亮茄粉碎者,亮茄锄铲,荆棘茄甲)
		暗影全套(虚空长袍,虚空兜帽,暗影伞,暗影收割者,暗影槌,阴郁回旋镖)
		照明类(提灯,矿工帽,鼹鼠帽,暗影香炉)
		其他武器(警钟)
		其他防具(骨头盔甲,眼面具)
	待补充:餐桌灯,棱镜/勋章的装备
	版本:3.1
]]
,
[[
	禁止搬運！！！
	裝備自動修理,適用於五格揹包mod,適配六格揹包

	如果不喜歡裝備戴上的時候，自動打開格子，可以啟用【關閉格子自動打開】功能
	如果不喜歡多餘的格子，可以開啟【從玩家背包尋找材料】這樣就不會有額外格子。但是為了支持提燈放在地上自動修理，還是保留了提燈的格子。
	已知遊戲特性：
		特性1：當裝備擁有格子以後，就不能被擬態蠕蟲複製。如果需要擬態蠕蟲複製，請關閉格子功能。
		特性2：帶有格子的裝備不能放入打包紙。

	當前僅支持道具:
	護符(魔光護符,懶人護符)
	服裝(熊皮背心,清涼夏裝,鬆軟背心,透氣背心,犬牙背心,雨衣,饥饿腰带,嘰嘰喳喳三件套(圍巾/披風/短披肩))
	帽子(牛角帽,眼球傘,冬帽,雨帽,貓帽,兔耳罩,波利羅傑的帽子,貝雷帽,草帽,時髦護目鏡,沙漠護目鏡,松鼠先鋒隊帽子,鹹狗帽)
	亮茄全套(亮茄劍,亮茄頭盔,亮茄盔甲,亮茄魔杖,亮茄粉碎者,亮茄鋤鏟,荆棘茄甲)
	暗影全套(虛空長袍,虛空兜帽,暗影傘,暗影收割者,暗影槌,阴郁回旋镖)
	照明類(提燈,礦工帽,鼴鼠帽,暗影香爐)
	其他武器(警鐘)
	其他防具(骨頭盔甲,眼面具)
	版本:3.1

]])

name = NAME_MOD
description = DESC_MOD
author = "Larkin" 
version = "3.1"

forumthread = "" 

api_version = 10

dst_compatible = true
dont_starve_compatible = false
reign_of_giants_compatible = false

all_clients_require_mod = true

icon_atlas = "modicon.xml"
icon = "modicon.tex"

priority = 999999999


server_filter_tags = {

}

local TXT_STATIC = {
	["Freezer"] = Adaptive("Freezer","永久保鲜","永久保鮮"),
	["FreezerDesc"] = Adaptive("Stop fluorescent fruit rot","停止燃料腐烂","停止燃料腐爛"),

	["SlotAutoOpen"] = Adaptive("slot auto open","格子自动打开","格子自动打开"),
	["SlotAutoOpenDesc"] = Adaptive("slot auto open after the equipment is put on","装备穿上后是否格子自动打开","装备穿上后是否格子自动打开"),

	["AutoFillSlot"] = Adaptive("auto fill slot on pickup","拾取自动加入格子","拾取自動加入格子"),
	["AutoFillSlotDesc"] = Adaptive("On: repair materials you pick up go into the equipment's own slot first (the equipment must be worn and its slot opened).\nOff: materials stay in your inventory, the slot only takes what you put in by hand.",
	"开启：捡到该装备能用的修理材料时，优先放进装备自带的格子（需要装备已穿上、且格子已打开）。\n关闭：材料留在背包里，格子只接收你手动放进去的东西。",
	"開啓：撿到該裝備能用的修理材料時，優先放進裝備自帶的格子（需要裝備已穿上、且格子已打開）。\n關閉：材料留在揹包裡，格子只接收你手動放進去的東西。"),

	["UsePlayerInventory"] = Adaptive("Search from player inventory","从玩家背包寻找材料","從玩家揹包尋找材料"),
	["UsePlayerInventoryDesc"] = Adaptive("Automatically find suitable materials from the player's backpack instead of the equipment's own grid",
	"自动从玩家背包中寻找合适的材料进行修复，无需放入装备自带的格子",
	"自動從玩家揹包中尋找合適的材料進行修復，無需放入裝備自帶的格子"),

	["enableOrNot"] = Adaptive("is enable or not","是否开启","是否開啓"),

	["yellowamulet"] = Adaptive("Magiluminescence","魔光护符","魔光護符"),

	["sword_lunarplant"] = Adaptive("Brightshade Sword","亮茄剑","亮茄劍"),
	["armor_lunarplant"] = Adaptive("Brightshade Armor","亮茄盔甲","亮茄盔甲"),
	-- add armor_lunarplant_husk
	["armor_lunarplant_husk"] = Adaptive("Brambleshade Armor","荆棘茄甲","荆棘茄甲"),
	["lunarplanthat"] = Adaptive("Brightshade Helm","亮茄头盔","亮茄頭盔"),
	["shovel_lunarplant"] = Adaptive("Brightshade Shoevel","亮茄锄铲","亮茄鋤鏟"),
	["staff_lunarplant"] = Adaptive("Brightshade Staff","亮茄魔杖","亮茄魔杖"),
	["pickaxe_lunarplant"] = Adaptive("Brightshade Smasher","亮茄粉碎者","亮茄粉碎者"),

	["armor_voidcloth"] = Adaptive("Void Robe","虚空长袍","虛空長袍"),
	["voidclothhat"] = Adaptive("Void Cowl","虚空兜帽","虛空兜帽"),
	["voidcloth_umbrella"] = Adaptive("Void Umbralla","暗影伞","暗影傘"),
	["voidcloth_scythe"] = Adaptive("Shadow Reaper","暗影收割者","暗影收割者"),
	["shadow_battleaxe"] = Adaptive("Shadow Maul","暗影槌","暗影槌"),
	["voidcloth_boomerang"] = Adaptive("Gloomerang","阴郁回旋镖","阴郁回旋镖"),
	["thurible"] = Adaptive("Shadow Thurible","暗影香炉","暗影香爐"),
	["salty_doghat"] = Adaptive("Salty Dog's Hat","咸狗帽","鹹狗帽"),

	["lantern"] = Adaptive("Lantern","提灯","提燈"),
	["minerhat"] = Adaptive("Miner Hat","矿工帽","礦工帽"),
	["molehat"] = Adaptive("Moggles","鼹鼠帽","鼴鼠帽"),

	["beefalohat"] = Adaptive("Beefalo Hat","牛角帽","牛角帽"),
	["eyebrellahat"] = Adaptive("Eyebrella","眼球伞","眼球傘"),
	["winterhat"] = Adaptive("Winter Hat","冬帽","冬帽"),
	["catcoonhat"] = Adaptive("Cat Cap","雨帽","雨帽"),
	["rainhat"] = Adaptive("Rain Hat","猫帽","貓帽"),
	["earmuffshat"] = Adaptive("Rabbit Earmuffs","兔耳罩","兔耳罩"),
	["polly_rogershat"] = Adaptive("Polly Roger's Hat","波利罗杰的帽子","波利羅傑的帽子"),
	["walrushat"] = Adaptive("Tam o' Shanter","贝雷帽","贝雷帽"),

	["beargervest"] = Adaptive("Hibearnation Vest","熊皮背心","熊皮背心"),
	["reflectivevest"] = Adaptive("Summer Frest","清凉夏装","清涼夏裝"),
	["trunkvest_winter"] = Adaptive("Puffy Vest","松软背心","鬆軟背心"),
	["trunkvest_summer"] = Adaptive("Breezy Vest","透气背心","透氣背心"),
	["sweatervest"] = Adaptive("Dapper Vest","犬牙背心","犬牙背心"),
	["raincoat"] = Adaptive("Rain Coat","雨衣","雨衣"),
	--armorslurper
	["armorslurper"] = Adaptive("Belt of Hunger","饥饿腰带","饥饿腰带"),

	["carnival_vest_a"] = Adaptive("Chirpy Scarf","叽叽喳喳围巾","嘰嘰喳喳圍巾"),
	["carnival_vest_b"] = Adaptive("Chirpy Cloak","叽叽喳喳披风","嘰嘰喳喳披風"),
	["carnival_vest_c"] = Adaptive("Chirpy Capelet","叽叽喳喳短披肩","嘰嘰喳喳短披肩"),

	["tophat"] = Adaptive("Top Hat","高礼帽","高禮帽"),
	["strawhat"] = Adaptive("Straw Hat","草帽","草帽"),
	["goggleshat"] = Adaptive("Fashion Goggles","时髦护目镜","時髦護目鏡"),
	["deserthat"] = Adaptive("Desert Goggles","沙漠护目镜","沙漠護目鏡"),
	["walterhat"] = Adaptive("Pinetree Pioneer Hat","松鼠先锋队帽子","松鼠先鋒隊帽子"),

	-- [""] = Adaptive("","",""),
	--pocketwatch_weapon
	["pocketwatch_weapon"] = Adaptive("Alarming Clock","警钟","警鐘"),
	-- 新增装备
	["eyemaskhat"] = Adaptive("Eye Mask","眼面具","眼面具"),
	--shieldofterror
	["shieldofterror"] = Adaptive("Shield of Terror","恐怖盾牌","恐怖盾牌"),
	["orangeamulet"] = Adaptive("The Lazy Forager","懒人护符","懶人護符"),
	-- armorskeleton
	["armorskeleton"] = Adaptive("Bone Armor","骨头盔甲","骨頭盔甲"),

-- 选项文本
	["Disabled"] = Adaptive("Disabled","禁用","禁用"),
	["Enabled"] = Adaptive("Enabled","启用","啟用"),
	["default"] = Adaptive("default","默认","默認"),
	["1"] = Adaptive("first","1","1"),
	["2"] = Adaptive("second","2","2"),
	["3"] = Adaptive("third","3","3"),
	["4"] = Adaptive("forth","4","4"),
	["5"] = Adaptive("fifth","5","5"),
	["6"] = Adaptive("sixth","6","6"),
	["7"] = Adaptive("seventh","7","7"),
	["8"] = Adaptive("eighth","8","8"),
-- 文本
	["SLOT_CUSTOM_DESC"] = Adaptive("In different equipment grid mods, the grid position is not fixed, if you need to adjust the position, please customize the grid position",
	"在不同的装备格子mod中，格子位置并不固定，如果需要调整位置，请自定义设置格子位置",
	"在不同的裝備格子mod中，格子位置並不固定，如果需要調整位置，請自定義設置格子位置"),
--六个格的位置，这并不符合很多六个格子背包mod的设定
	["hand"] = Adaptive("custom the hand slot order","手部装备位置自定义","手部裝備位置自定義"),
	["backpack"] = Adaptive("custom the backpack slot order","背包装备位置自定义","揹包裝備位置自定義"),
	["hat"] = Adaptive("custom the head slot order","头部装备位置自定义","頭部裝備位置自定義"),
	["bodyCloth"] = Adaptive("custom the body cloth slot order","身着的衣服位置自定义","身着的衣服位置自定義"),
	["bodyArmor"] = Adaptive("custom the body armor slot order","身着的护甲位置自定义","身着的護甲位置自定義"),
	["amulet"] = Adaptive("custom the amulet slot order","护符位置自定义","护符位置自定义"),
-- 特殊字段
	["specialFunction"] = Adaptive("Special function","特殊功能","特殊功能"),
	["customSlot"] = Adaptive("custom the slot order","自定义装备槽位置(适配六格背包)","自定義裝備槽位置(適配六格揹包)"),
	["equipSetting"] = Adaptive("enable equip Settings","装备是否开启设置","裝備是否開啓設置"),
-- debug开关
	["debugSetting"] = Adaptive("Debug Setting(If not necessary, do not modify)","调试设置(请勿开启)","調試設置(請勿開啓)"),

	["LogDebugEnable"] = Adaptive("LogDebugEnable","LogDebugEnable","LogDebugEnable"),
	["LogInfoEnable"] = Adaptive("LogInfoEnable","LogInfoEnable","LogInfoEnable"),
	["LogErrorEnable"] = Adaptive("LogErrorEnable","LogErrorEnable","LogErrorEnable"),

}


local Options =
{
	{description = TXT_STATIC["Disabled"], 	data = false, hover = TXT_STATIC["Disabled"]},
	{description = TXT_STATIC["Enabled"],   data = true, hover = TXT_STATIC["Enabled"]}
}

local SlotOptions =
{
	{description = TXT_STATIC["default"], 	data = -1, hover = TXT_STATIC["default"]},
	{description = TXT_STATIC["1"],   data = 1, hover = TXT_STATIC["1"]},
	{description = TXT_STATIC["2"],   data = 2, hover = TXT_STATIC["2"]},
	{description = TXT_STATIC["3"],   data = 3, hover = TXT_STATIC["3"]},
	{description = TXT_STATIC["4"],   data = 4, hover = TXT_STATIC["4"]},
	{description = TXT_STATIC["5"],   data = 5, hover = TXT_STATIC["5"]},
	{description = TXT_STATIC["6"],   data = 6, hover = TXT_STATIC["6"]},
	{description = TXT_STATIC["7"],   data = 7, hover = TXT_STATIC["7"]},
	{description = TXT_STATIC["8"],   data = 8, hover = TXT_STATIC["8"]},
}

configuration_options = {
	{
		name = TXT_STATIC["specialFunction"],
		label = TXT_STATIC["specialFunction"], 
		options = {{description = "", data = 0}},
		default = 0,
		tags = {"ignore"},
	},
	{
		name = "Freezer",
		label = TXT_STATIC["Freezer"],
		hover = TXT_STATIC["FreezerDesc"],
		options = Options,
		default = true,
	},
	{
		name = "SlotAutoOpen",
		label = TXT_STATIC["SlotAutoOpen"],
		hover = TXT_STATIC["SlotAutoOpenDesc"],
		options = Options,
		default = false,
	},
	{
		name = "AutoFillSlot",
		label = TXT_STATIC["AutoFillSlot"],
		hover = TXT_STATIC["AutoFillSlotDesc"],
		options = Options,
		default = true,
	},
	{
		name = "UsePlayerInventory",
		label = TXT_STATIC["UsePlayerInventory"],
		hover = TXT_STATIC["UsePlayerInventoryDesc"],
		options = Options,
		default = false,
	},

	{
		name = TXT_STATIC["customSlot"],
		label = TXT_STATIC["customSlot"], 
		options = {{description = "", data = 0}},
		default = 0,
		tags = {"ignore"},
	},

	{
		name = "hand",
		label = TXT_STATIC["hand"],
		hover = TXT_STATIC["SLOT_CUSTOM_DESC"],
		options = SlotOptions,
		default = -1,
	},
	{
		name = "backpack",
		label = TXT_STATIC["backpack"],
		hover = TXT_STATIC["SLOT_CUSTOM_DESC"],
		options = SlotOptions,
		default = -1,
	},
	{
		name = "bodyArmor",
		label = TXT_STATIC["bodyArmor"],
		hover = TXT_STATIC["SLOT_CUSTOM_DESC"],
		options = SlotOptions,
		default = -1,
	},
	{
		name = "bodyCloth",
		label = TXT_STATIC["bodyCloth"],
		hover = TXT_STATIC["SLOT_CUSTOM_DESC"],
		options = SlotOptions,
		default = -1,
	},
	{
		name = "amulet",
		label = TXT_STATIC["amulet"],
		hover = TXT_STATIC["SLOT_CUSTOM_DESC"],
		options = SlotOptions,
		default = -1,
	},
	{
		name = "hat",
		label = TXT_STATIC["hat"],
		hover = TXT_STATIC["SLOT_CUSTOM_DESC"],
		options = SlotOptions,
		default = -1,
	},
	{
		name = TXT_STATIC["equipSetting"],
		label = TXT_STATIC["equipSetting"], 
		options = {{description = "", data = 0}},
		default = 0,
		tags = {"ignore"},
	},

	-- amulet
	{
		name = "yellowamulet",
		label = TXT_STATIC["yellowamulet"],
		hover = TXT_STATIC["yellowamulet"] .. TXT_STATIC["enableOrNot"],
		options = Options,
		default = true,
	},
	{
		name = "orangeamulet",
		label = TXT_STATIC["orangeamulet"],
		hover = TXT_STATIC["orangeamulet"] .. TXT_STATIC["enableOrNot"],
		options = Options,
		default = true,
	},

	-- lunar
	{
		name = "sword_lunarplant",
		label = TXT_STATIC["sword_lunarplant"],
		hover = TXT_STATIC["sword_lunarplant"] .. TXT_STATIC["enableOrNot"],
		options = Options,
		default = true,
	},
	{
		name = "armor_lunarplant",
		label = TXT_STATIC["armor_lunarplant"],
		hover = TXT_STATIC["armor_lunarplant"] .. TXT_STATIC["enableOrNot"],
		options = Options,
		default = true,
	},
	{
		name = "armor_lunarplant_husk",
		label = TXT_STATIC["armor_lunarplant_husk"],
		hover = TXT_STATIC["armor_lunarplant_husk"] .. TXT_STATIC["enableOrNot"],
		options = Options,
		default = true,
	},
	{
		name = "lunarplanthat",
		label = TXT_STATIC["lunarplanthat"],
		hover = TXT_STATIC["lunarplanthat"] .. TXT_STATIC["enableOrNot"],
		options = Options,
		default = true,
	},
	{
		name = "shovel_lunarplant",
		label = TXT_STATIC["shovel_lunarplant"],
		hover = TXT_STATIC["shovel_lunarplant"] .. TXT_STATIC["enableOrNot"],
		options = Options,
		default = true,
	},
	{
		name = "staff_lunarplant",
		label = TXT_STATIC["staff_lunarplant"],
		hover = TXT_STATIC["staff_lunarplant"] .. TXT_STATIC["enableOrNot"],
		options = Options,
		default = true,
	},
	{
		name = "pickaxe_lunarplant",
		label = TXT_STATIC["pickaxe_lunarplant"],
		hover = TXT_STATIC["pickaxe_lunarplant"] .. TXT_STATIC["enableOrNot"],
		options = Options,
		default = true,
	},

		-- void
	{
		name = "armor_voidcloth",
		label = TXT_STATIC["armor_voidcloth"],
		hover = TXT_STATIC["armor_voidcloth"] .. TXT_STATIC["enableOrNot"],
		options = Options,
		default = true,
	},
	{
		name = "voidclothhat",
		label = TXT_STATIC["voidclothhat"],
		hover = TXT_STATIC["voidclothhat"] .. TXT_STATIC["enableOrNot"],
		options = Options,
		default = true,
	},
	{
		name = "voidcloth_umbrella",
		label = TXT_STATIC["voidcloth_umbrella"],
		hover = TXT_STATIC["voidcloth_umbrella"] .. TXT_STATIC["enableOrNot"],
		options = Options,
		default = true,
	},
	{
		name = "voidcloth_scythe",
		label = TXT_STATIC["voidcloth_scythe"],
		hover = TXT_STATIC["voidcloth_scythe"] .. TXT_STATIC["enableOrNot"],
		options = Options,
		default = true,
	},
	{
		name = "shadow_battleaxe",
		label = TXT_STATIC["shadow_battleaxe"],
		hover = TXT_STATIC["shadow_battleaxe"] .. TXT_STATIC["enableOrNot"],
		options = Options,
		default = true,
	},
	{
		name = "voidcloth_boomerang",
		label = TXT_STATIC["voidcloth_boomerang"],
		hover = TXT_STATIC["voidcloth_boomerang"] .. TXT_STATIC["enableOrNot"],
		options = Options,
		default = true,
	},
	{
		name = "thurible",
		label = TXT_STATIC["thurible"],
		hover = TXT_STATIC["thurible"] .. TXT_STATIC["enableOrNot"],
		options = Options,
		default = true,
	},

	-- lighting
	{
		name = "lantern",
		label = TXT_STATIC["lantern"],
		hover = TXT_STATIC["lantern"] .. TXT_STATIC["enableOrNot"],
		options = Options,
		default = true,
	},
	{
		name = "minerhat",
		label = TXT_STATIC["minerhat"],
		hover = TXT_STATIC["minerhat"] .. TXT_STATIC["enableOrNot"],
		options = Options,
		default = true,
	},
	{
		name = "molehat",
		label = TXT_STATIC["molehat"],
		hover = TXT_STATIC["molehat"] .. TXT_STATIC["enableOrNot"],
		options = Options,
		default = true,
	},
	{
		name = "salty_doghat",
		label = TXT_STATIC["salty_doghat"],
		hover = TXT_STATIC["salty_doghat"] .. TXT_STATIC["enableOrNot"],
		options = Options,
		default = true,
	},

	-- hat
	{
		name = "beefalohat",
		label = TXT_STATIC["beefalohat"],
		hover = TXT_STATIC["beefalohat"] .. TXT_STATIC["enableOrNot"],
		options = Options,
		default = true,
	},
	{
		name = "eyebrellahat",
		label = TXT_STATIC["eyebrellahat"],
		hover = TXT_STATIC["eyebrellahat"] .. TXT_STATIC["enableOrNot"],
		options = Options,
		default = true,
	},
	{
		name = "winterhat",
		label = TXT_STATIC["winterhat"],
		hover = TXT_STATIC["winterhat"] .. TXT_STATIC["enableOrNot"],
		options = Options,
		default = true,
	},
	{
		name = "catcoonhat",
		label = TXT_STATIC["catcoonhat"],
		hover = TXT_STATIC["catcoonhat"] .. TXT_STATIC["enableOrNot"],
		options = Options,
		default = true,
	},
	{
		name = "rainhat",
		label = TXT_STATIC["rainhat"],
		hover = TXT_STATIC["rainhat"] .. TXT_STATIC["enableOrNot"],
		options = Options,
		default = true,
	},
	{
		name = "earmuffshat",
		label = TXT_STATIC["earmuffshat"],
		hover = TXT_STATIC["earmuffshat"] .. TXT_STATIC["enableOrNot"],
		options = Options,
		default = true,
	},
	-- {
	-- 	name = "tophat",
	-- 	label = TXT_STATIC["tophat"],
	-- 	hover = TXT_STATIC["tophat"] .. TXT_STATIC["enableOrNot"],
	-- 	options = Options,
	-- 	default = true,
	-- },
	{
		name = "strawhat",
		label = TXT_STATIC["strawhat"],
		hover = TXT_STATIC["strawhat"] .. TXT_STATIC["enableOrNot"],
		options = Options,
		default = true,
	},
	{
		name = "goggleshat",
		label = TXT_STATIC["goggleshat"],
		hover = TXT_STATIC["goggleshat"] .. TXT_STATIC["enableOrNot"],
		options = Options,
		default = true,
	},
	{
		name = "deserthat",
		label = TXT_STATIC["deserthat"],
		hover = TXT_STATIC["deserthat"] .. TXT_STATIC["enableOrNot"],
		options = Options,
		default = true,
	},
	{
		name = "walterhat",
		label = TXT_STATIC["walterhat"],
		hover = TXT_STATIC["walterhat"] .. TXT_STATIC["enableOrNot"],
		options = Options,
		default = true,
	},

	-- cloth
	{
		name = "beargervest",
		label = TXT_STATIC["beargervest"],
		hover = TXT_STATIC["beargervest"] .. TXT_STATIC["enableOrNot"],
		options = Options,
		default = true,
	},
	{
		name = "reflectivevest",
		label = TXT_STATIC["reflectivevest"],
		hover = TXT_STATIC["reflectivevest"] .. TXT_STATIC["enableOrNot"],
		options = Options,
		default = true,
	},
	{
		name = "trunkvest_winter",
		label = TXT_STATIC["trunkvest_winter"],
		hover = TXT_STATIC["trunkvest_winter"] .. TXT_STATIC["enableOrNot"],
		options = Options,
		default = true,
	},
	{
		name = "trunkvest_summer",
		label = TXT_STATIC["trunkvest_summer"],
		hover = TXT_STATIC["trunkvest_summer"] .. TXT_STATIC["enableOrNot"],
		options = Options,
		default = true,
	},
	{
		name = "sweatervest",
		label = TXT_STATIC["sweatervest"],
		hover = TXT_STATIC["sweatervest"] .. TXT_STATIC["enableOrNot"],
		options = Options,
		default = true,
	},
	{
		name = "raincoat",
		label = TXT_STATIC["raincoat"],
		hover = TXT_STATIC["raincoat"] .. TXT_STATIC["enableOrNot"],
		options = Options,
		default = true,
	},
	{
		name = "armorslurper",
		label = TXT_STATIC["armorslurper"],
		hover = TXT_STATIC["armorslurper"] .. TXT_STATIC["enableOrNot"],
		options = Options,
		default = true,
	},
	{
		name = "carnival_vest_a",
		label = TXT_STATIC["carnival_vest_a"],
		hover = TXT_STATIC["carnival_vest_a"] .. TXT_STATIC["enableOrNot"],
		options = Options,
		default = true,
	},
	{
		name = "carnival_vest_b",
		label = TXT_STATIC["carnival_vest_b"],
		hover = TXT_STATIC["carnival_vest_b"] .. TXT_STATIC["enableOrNot"],
		options = Options,
		default = true,
	},
	{
		name = "carnival_vest_c",
		label = TXT_STATIC["carnival_vest_c"],
		hover = TXT_STATIC["carnival_vest_c"] .. TXT_STATIC["enableOrNot"],
		options = Options,
		default = true,
	},

	--pocketwatch_weapon
	{
		name = "pocketwatch_weapon",
		label = TXT_STATIC["pocketwatch_weapon"],
		hover = TXT_STATIC["pocketwatch_weapon"] .. TXT_STATIC["enableOrNot"],
		options = Options,
		default = true,
	},
	--eyemaskhat
	{
		name = "eyemaskhat",
		label = TXT_STATIC["eyemaskhat"],
		hover = TXT_STATIC["eyemaskhat"] .. TXT_STATIC["enableOrNot"],
		options = Options,
		default = true,
	},
	--shieldofterror
	{
		name = "shieldofterror",
		label = TXT_STATIC["shieldofterror"],
		hover = TXT_STATIC["shieldofterror"] .. TXT_STATIC["enableOrNot"],
		options = Options,
		default = true,
	},
	
	--walrushat
	{
		name = "walrushat",
		label = TXT_STATIC["walrushat"],
		hover = TXT_STATIC["walrushat"] .. TXT_STATIC["enableOrNot"],
		options = Options,
		default = true,
	},

	-- armorskeleton
	{
		name = "armorskeleton",
		label = TXT_STATIC["armorskeleton"],
		hover = TXT_STATIC["walrushat"] .. TXT_STATIC["enableOrNot"],
		options = Options,
		default = true,
	},

	-- debug Setting
	{
		name = TXT_STATIC["debugSetting"],
		label = TXT_STATIC["debugSetting"], 
		options = {{description = "", data = 0}},
		default = 0,
		tags = {"ignore"},
	},
	{
		name = "LogDebugEnable",
		label = TXT_STATIC["LogDebugEnable"],
		hover = TXT_STATIC["LogDebugEnable"],
		options = Options,
		default = false,
	},
	{
		name = "LogInfoEnable",
		label = TXT_STATIC["LogInfoEnable"],
		hover = TXT_STATIC["LogInfoEnable"],
		options = Options,
		default = false,
	},
	{
		name = "LogErrorEnable",
		label = TXT_STATIC["LogErrorEnable"],
		hover = TXT_STATIC["LogErrorEnable"],
		options = Options,
		default = false,
	},
}