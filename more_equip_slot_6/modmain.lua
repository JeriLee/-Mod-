local log = require "more_equip_slots/utils/log"
local mytable = require "more_equip_slots/utils/mytable"
local mod = require "more_equip_slots/utils/mod"


-- Assets.

local IMAGE = "images/equip_slots.tex"
local ATLAS = "images/equip_slots.xml"
Assets = {
    Asset("IMAGE", IMAGE),
    Asset("ATLAS", ATLAS),
}


-- Some configuration options.

local config_auto_backpack = GetModConfigData("config_auto_backpack")
local config_auto_armor    = GetModConfigData("config_auto_armor")
local config_auto_dress    = GetModConfigData("config_auto_dress")
local config_auto_amulet   = GetModConfigData("config_auto_amulet")


-- 一些全局变量.

EQUIP_TYPES = require "more_equip_slots/equip_types"

EQUIPSLOTS_MAP = {
    HEAVY    = GetModConfigData("slot_heavy"   ) or GLOBAL.EQUIPSLOTS.BODY,
    BACKPACK = GetModConfigData("slot_backpack") or GLOBAL.EQUIPSLOTS.BODY,
    BAND     = GLOBAL.EQUIPSLOTS.BODY,
    SHELL    = GLOBAL.EQUIPSLOTS.BODY,
    LIFEVEST = GLOBAL.EQUIPSLOTS.BODY,
    ARMOR    = GetModConfigData("slot_armor"   ) or GLOBAL.EQUIPSLOTS.BODY,
    DRESS    = GetModConfigData("slot_dress"   ) or GLOBAL.EQUIPSLOTS.BODY,
    AMULET   = GetModConfigData("slot_amulet"  ) or GLOBAL.EQUIPSLOTS.BODY,
    COSTUME  = GetModConfigData("slot_costume" ) or GLOBAL.EQUIPSLOTS.BODY,
}

EQUIPSLOTS_MAP_INVERSE = mytable.invert(EQUIPSLOTS_MAP)

BODY_EQUIPSLOTS = table.getkeys(EQUIPSLOTS_MAP_INVERSE)
table.sort(BODY_EQUIPSLOTS)


-- 一些辅助函数.

local function build_function_with_body_slot(slot)
    return function (super, ...)
        return mod.with_override(GLOBAL.EQUIPSLOTS, 'BODY', slot, super, ...)
    end
end

local with_armor_slot   = build_function_with_body_slot(EQUIPSLOTS_MAP.ARMOR)
local with_dress_slot   = build_function_with_body_slot(EQUIPSLOTS_MAP.DRESS)
local with_amulet_slot  = build_function_with_body_slot(EQUIPSLOTS_MAP.AMULET)
local with_costume_slot = build_function_with_body_slot(EQUIPSLOTS_MAP.COSTUME)


-- 1.1. Add new equip slots.
-- See `scripts/constants.lua:473`.

for _, v in ipairs(BODY_EQUIPSLOTS) do
    GLOBAL.EQUIPSLOTS[string.upper(v)] = v
end


-- 1.2. 为装备插槽设置元表，这允许处理不存在的插槽, e.g. `EQUIPSLOTS.NECK`.
-- Some mods use them to be compatible with the mod "Extra Equip Slots".
if config_auto_amulet then
    -- Some buggy mods (e.g. "[DST] WhaRang") erroneously set some custom equip slots, which prevents using the metatable.
    -- Let's workaround this by unsetting these slots.
    GLOBAL.EQUIPSLOTS.BACK  = nil
    GLOBAL.EQUIPSLOTS.NECK  = nil
    GLOBAL.EQUIPSLOTS.WAIST = nil

    GLOBAL.setmetatable(GLOBAL.EQUIPSLOTS, {
        __index = function(tbl, key)
            if key == 'BACK' then
                return GLOBAL.rawget(tbl, 'BODY') -- Fallback. Some mods (e.g. "Island Adventures") require it.
            elseif key == 'NECK' then
                return EQUIPSLOTS_MAP.AMULET
            elseif key == 'WAIST' then
                return GLOBAL.rawget(tbl, 'HANDS') -- Fallback. Some mods (e.g. "Island Adventures") require it.
            else
                return GLOBAL.rawget(tbl, key)
            end
        end
    })
end


-- 2.1. 将新装备插槽添加到物品栏.
-- See `scripts/widgets/inventorybar.lua:92`.

local function get_eslot_image(eslot)
    local types = EQUIPSLOTS_MAP_INVERSE[eslot]
    if mytable.contains_all(types, {'BACKPACK', 'ARMOR'}) then
        return {ATLAS, "backpack+armor.tex"}
    elseif table.contains(types, 'BACKPACK') then
        return {ATLAS, "backpack.tex"}
    elseif table.contains(types, 'ARMOR') then
        return {ATLAS, "armor.tex"}
    elseif table.contains(types, 'DRESS') then
        return {ATLAS, "dress.tex"}
    elseif table.contains(types, 'AMULET') then
        return {ATLAS, "amulet.tex"}
    else
        return {GLOBAL.HUD_ATLAS, "equip_slot_body.tex"}
    end
end

AddClassPostConstruct("widgets/inventorybar", function(self)
    if GLOBAL.TheNet:GetServerGameMode() == "quagmire" then
        return
    end

    -- 更改旧设备插槽的图像.
    for _, info in ipairs(self.equipslotinfo) do
        if info.slot == GLOBAL.EQUIPSLOTS.BODY then
            local atlas_and_image = get_eslot_image(info.slot)
            info.atlas = atlas_and_image[1]
            info.image = atlas_and_image[2]
            break
        end
    end

    -- 添加新的装备插槽.
    local sortkey_start = 1.0 -- After the 1st slot ("body").
    local sortkey_delta = 1.0 / #BODY_EQUIPSLOTS
    for i, eslot in ipairs(BODY_EQUIPSLOTS) do
        if eslot ~= GLOBAL.EQUIPSLOTS.BODY then
            local atlas_and_image = get_eslot_image(eslot)
            self:AddEquipSlot(eslot, atlas_and_image[1], atlas_and_image[2], sortkey_start + (i - 1) * sortkey_delta)
        end
    end

    -- 修正库存栏背景的宽度.
    mod.override_method(self, 'Rebuild', function(super, self1)
        super(self1)

        local function CalcTotalWidth(num_slots, num_equip, num_buttons)
            -- See `scripts/widgets/inventorybar.lua:212-217`.
            local W = 68
            local SEP = 12
            local INTERSEP = 28
            local num_slotintersep = math.ceil(num_slots / 5)
            local num_equipintersep = num_buttons > 0 and 1 or 0
            return (num_slots + num_equip + num_buttons) * W + (num_slots + num_equip + num_buttons - num_slotintersep - num_equipintersep - 1) * SEP + (num_slotintersep + num_equipintersep) * INTERSEP
        end

        local num_slots = self1.owner.replica.inventory:GetNumSlots()
        local do_self_inspect = not (self1.controller_build or GLOBAL.GetGameModeProperty("no_avatar_popup"))

        local total_w_default = CalcTotalWidth(num_slots, 3, 1)
        local total_w_real    = CalcTotalWidth(num_slots, #self1.equipslotinfo, do_self_inspect and 1 or 0)
        local scale_default = 1.22 -- See `scripts/widgets/inventorybar.lua:261-262`.
        local scale_real = scale_default *  total_w_real / total_w_default
        self1.bg:SetScale(scale_real, 1, 1)
        self1.bgcover:SetScale(scale_real,1, 1)
    end)
end)


-- 2.2. Fix the position of the containers of the *Enlightened Crown* and *Turf-Raiser Helm*.
-- See `scripts/containers.lua`.
local containers = require "containers"
local SLOT_WIDTH = 53
local head_inv_pos_x = SLOT_WIDTH * (1 + #BODY_EQUIPSLOTS)
containers.params["alterguardianhat"].widget.pos.x = head_inv_pos_x
containers.params["antlionhat"      ].widget.pos.x = head_inv_pos_x


-- 3. Assign the new equip slots to the items.
-- See `scripts/prefabs/*.lua`.

local items_equip_types = require "more_equip_slots/items_equip_types"

AddPrefabPostInitAny(function(inst)
    if not (GLOBAL.TheWorld.ismastersim
            and inst.components.equippable ~= nil
            and table.contains(BODY_EQUIPSLOTS, inst.components.equippable.equipslot))
    then
        return
    end

    -- Get an equip slot by the type/tag.
    local eslot = nil
    for k, v in pairs(EQUIP_TYPES) do
        if inst:HasTag(v) then
            eslot = EQUIPSLOTS_MAP[k]
            break
        end
    end

    -- Fallback.
    if eslot == nil then
        local type = items_equip_types[inst.prefab]
        if type ~= nil then
            inst:AddTag(type)
            eslot = EQUIPSLOTS_MAP[string.upper(type)]
        elseif config_auto_amulet
                and inst.components.equippable.equipslot == EQUIPSLOTS_MAP.AMULET then
            log.info("[\"%s\"] = EQUIP_TYPES.AMULET, -- %s", inst.prefab, inst.name)
            inst:AddTag(EQUIP_TYPES.AMULET)
            eslot = EQUIPSLOTS_MAP.AMULET
        elseif config_auto_backpack
                and inst.components.container ~= nil then
            log.info("[\"%s\"] = EQUIP_TYPES.BACKPACK, -- %s", inst.prefab, inst.name)
            inst:AddTag(EQUIP_TYPES.BACKPACK)
            eslot = EQUIPSLOTS_MAP.BACKPACK
        elseif config_auto_armor
                and (inst.components.armor ~= nil or inst.components.resistance ~= nil) then
            log.info("[\"%s\"] = EQUIP_TYPES.ARMOR, -- %s", inst.prefab, inst.name)
            inst:AddTag(EQUIP_TYPES.ARMOR)
            eslot = EQUIPSLOTS_MAP.ARMOR
        elseif config_auto_dress
                and inst.components.fueled ~= nil
                and inst.components.fueled.fueltype == GLOBAL.FUELTYPE.USAGE then
            log.info("[\"%s\"] = EQUIP_TYPES.DRESS, -- %s", inst.prefab, inst.name)
            inst:AddTag(EQUIP_TYPES.DRESS)
            eslot = EQUIPSLOTS_MAP.DRESS
        else
            log.info("[\"%s\"] = nil, -- %s", inst.prefab, inst.name)
        end
    end

    if (eslot ~= nil) and (eslot ~= GLOBAL.EQUIPSLOTS.BODY) then
        -- Assign the new equip slot.
        -- See `scripts/prefabs/*.lua`.
        inst.components.equippable.equipslot = eslot

        -- For repairable items re-assign the new equip slot on repairing.
        -- See `scripts/prefabs/armor_lunarplant.lua`.
        -- See `scripts/prefabs/armor_voidcloth.lua`.
        -- See `scripts/prefabs/armor_wagpunk.lua`.
        if inst.components.forgerepairable ~= nil then
            mod.override_method(inst.components.forgerepairable, 'onrepaired', function(super, inst1, ...)
                super(inst1, ...)
                inst1.components.equippable.equipslot = eslot
            end)
        end

        -- 3.1. Fix the wet prefix.
        -- See `scripts/entityscript.lua:594`.
        if not inst.no_wet_prefix and inst.wet_prefix == nil then
            inst.wet_prefix = GLOBAL.STRINGS.WET_PREFIX.CLOTHING
        end
    end
end)


if GetModConfigData("config_mannequin") then

    -- 4.1. Add support for the extra body slots to the *Mannequin*.
    -- See `scripts/prefabs/sewing_mannequin.lua`.
    AddPrefabPostInit("sewing_mannequin", function(inst)
        if not GLOBAL.TheWorld.ismastersim then return end

        mod.override_method(inst.components.trader, "abletoaccepttest", function(super, inst1, item, doer)
            local equippable = item.components.equippable
            local result1, result2 = super(inst1, item, doer)
            return result1 or (equippable ~= nil and table.contains(BODY_EQUIPSLOTS, equippable.equipslot)),
                   result2
        end)

        mod.override_method(inst.components.activatable, "OnActivate", function(super, inst1, doer)
            mod.with_all_slots(inst1.components.inventory, GLOBAL.EQUIPSLOTS.BODY, BODY_EQUIPSLOTS,
                               super, inst1, doer)
        end)
    end)

    -- 4.2. Add support for the extra body slots to the *Punching Bag*, *Shadow Boxer*, and *Bright Boxer*.
    -- See `scripts/prefabs/punchingbag.lua`.
    for _, prefab in ipairs({"punchingbag", "punchingbag_shadow", "punchingbag_lunar"}) do
        AddPrefabPostInit(prefab, function(inst)
            if not GLOBAL.TheWorld.ismastersim then return end
            mod.override_method(inst.components.trader, 'abletoaccepttest', function(super, inst1, item, doer)
                local equippable = item.components.equippable
                local result1, result2 = super(inst1, item, doer)
                return result1 or (equippable ~= nil and table.contains(BODY_EQUIPSLOTS, equippable.equipslot)),
                       result2
            end)
        end)
    end

end


if EQUIPSLOTS_MAP.DRESS ~= GLOBAL.EQUIPSLOTS.BODY then

    -- 5.1. When you give Crabby Hermit a coat, she tries to use the old equip slot. Let's use the new one.
    -- See `scripts/prefabs/hermitcrab.lua`.
    AddPrefabPostInit("hermitcrab", function(inst)
        if not GLOBAL.TheWorld.ismastersim then return end

        -- Add an extra "itemget" listener which uses the method `inst.iscoat` instead of the up-value `iscoat`.
        -- See `scripts/prefabs/hermitcrab.lua:1011`.
        inst:ListenForEvent("itemget", function(_, data)
            if inst.iscoat(data.item) and GLOBAL.TheWorld.state.issnowing then
                local TASKS_GIVE_PUFFY_VEST = 11 -- Copy from `prefabs/hermitcrab.lua:57`.
                inst.components.inventory:Equip(data.item)
                inst.components.friendlevels:CompleteTask(TASKS_GIVE_PUFFY_VEST)
            end
        end)

        -- Override `ShouldAcceptItem`.
        -- See `scripts/prefabs/hermitcrab.lua:122-123,127`.
        mod.override_method(inst.components.trader, 'test', with_dress_slot)

        -- Override `OnRefuseItem`.
        -- See `scripts/prefabs/hermitcrab.lua:144-146`.
        mod.override_method(inst.components.trader, 'onrefuse', with_dress_slot)

        -- Override `iscoat`.
        -- See `scripts/prefabs/hermitcrab.lua:1363`.
        mod.override_method(inst, 'iscoat', with_dress_slot)
    end)


    -- 5.2. Crabby Hermit has a brain which allows her to equip/unequip a coat to/from the old equip slot. Let's use the new one.
    -- See `scripts/brains/hermitcrabbrain.lua`.
    local HermitBrain = require("brains/hermitcrabbrain")
    mod.override_upvalue(HermitBrain.OnStart, 'using_coat', with_dress_slot)
    mod.override_upvalue(HermitBrain.OnStart, 'UnEquipBody', with_dress_slot)

end


if EQUIPSLOTS_MAP.AMULET ~= GLOBAL.EQUIPSLOTS.BODY then

    -- 6.1. In the recipe popup the icon of the Construction Amulet is shown when it is equipped in the old slot. Let's use the new slot too.
    -- See `scripts/widgets/recipepopup.lua:334`.
    mod.override_method(require("widgets/recipepopup"), 'Refresh', with_amulet_slot)


    -- 6.2. Show the Construction Amulet in the crafting menu.
    -- See `scripts/widgets/redux/craftingmenu_ingredients.lua`.
    mod.override_method(require("widgets/redux/craftingmenu_ingredients"), 'SetRecipe', with_amulet_slot)


    -- 6.3. WhaRang Amulet
    AddPrefabPostInit("wharang_amulet", function(inst)
        if not GLOBAL.TheWorld.ismastersim then return end
        mod.override_method(inst.components.equippable, 'onequipfn', with_amulet_slot)
    end)

end


if EQUIPSLOTS_MAP.COSTUME ~= GLOBAL.EQUIPSLOTS.BODY then

    -- 7.1. Fix checking costume on the stage.
    -- See `components/stageactingprop.lua` > `StageActingProp:CheckCostume`
    mod.override_method(require("components/stageactingprop"), 'CheckCostume', with_costume_slot)

end


if EQUIPSLOTS_MAP.ARMOR ~= GLOBAL.EQUIPSLOTS.BODY then

    -- 8.1 Fix the position of the *Bone Armor* fuel slot added by the *Item Auto-Fuel Slots* mod.
    AddPrefabPostInit("armorskeleton", function(_)
        local armorskel_inv = containers.params["armorskel_inv"]
        if armorskel_inv ~= nil then
            armorskel_inv.widget.pos.x = SLOT_WIDTH * (mytable.index_of(BODY_EQUIPSLOTS, EQUIPSLOTS_MAP.ARMOR) - 1)
        end
    end)


    -- 8.2 Fix the brain of *Cozy Bunnyman*.
    -- See `scripts/brains/cozy_bunnymanbrain.lua`.
    local CozyBunnymanBrain = require("brains/cozy_bunnymanbrain")
    mod.override_upvalue(CozyBunnymanBrain.OnStart, 'plantpillow', with_armor_slot)

    -- Fix the pillows knockback effect.
    -- See `scripts/prefabs/pillow_common.lua`.
    mod.override_method(require("prefabs/pillow_common"), 'DoKnockback', with_armor_slot)

    -- Fix the pillows prize effect.
    -- See `scripts/prefabs/yotr_fightring.lua`.
    AddPrefabPostInit("yotr_fightring", function (inst)
        if not GLOBAL.TheWorld.ismastersim then return end
        mod.override_method(inst, '_EndMinigame', with_armor_slot)
    end)


    -- 8.3. Fix the bonuses from armor/helm sets: *Dreadstone*, *Brightshade*, *Void*, and other.
    mod.override_method(require("components/setbonus"), '_HasSetBonus', with_armor_slot)

    -- Fix the combination of *Dreadstone Helm* with *Dreadstone Armor*.
    -- See `scripts/prefabs/hats.lua`.
    AddPrefabPostInit("dreadstonehat", function (inst)
        if not GLOBAL.TheWorld.ismastersim then return end
        mod.override_upvalue(inst.components.equippable.dapperfn, 'dreadstone_getsetbonusequip', with_armor_slot)
    end)


    -- 8.4. Fix functioning of *W.A.R.B.I.S. Armor*.
    -- See `scripts/prefabs/armor_wagpunk.lua`.
    AddPrefabPostInit("armorwagpunk", function (inst)
        if not GLOBAL.TheWorld.ismastersim then return end
        mod.override_method(inst, 'OnAttack', with_armor_slot)
    end)

    -- Fix the combination of *W.A.R.B.I.S. Head Gear* with *W.A.R.B.I.S. Armor*.
    -- See `scripts/prefabs/hats.lua`.
    AddPrefabPostInit("wagpunkhat", function (inst)
        if not GLOBAL.TheWorld.ismastersim then return end
        mod.override_method(inst, 'SetNewTarget', with_armor_slot)
        mod.override_method(inst.components.targettracker, 'onresumefn', with_armor_slot)
        mod.override_method(inst.components.equippable, 'onequipfn', with_armor_slot)
        mod.override_method(inst.components.equippable, 'onunequipfn', with_armor_slot)
        mod.set_upvalue(inst.components.forgerepairable.onrepaired, 'fns', function(fns_orig)
            local fns = mytable.light_copy(fns_orig)
            mod.override_method(fns, 'wagpunk_onequip', with_armor_slot)
            mod.override_method(fns, 'wagpunk_onunequip', with_armor_slot)
            return fns
        end)
    end)

end


-- 10. Render items from the new equip slots.
if GetModConfigData("config_render") then

    local items_anim_symbols = {}

    -- Fill the `items_anim_symbols`.
    AddPrefabPostInitAny(function(inst)
        if not (GLOBAL.TheWorld.ismastersim
                and inst.components.equippable ~= nil
                and table.contains(BODY_EQUIPSLOTS, inst.components.equippable.equipslot))
        then
            return
        end

        local onequipfn_orig = inst.components.equippable.onequipfn
        local onequipfn_new = function(item, owner)
            local AnimStateOrig = owner.AnimState
            local AnimStateProxy = mod.proxy(AnimStateOrig, {
                OverrideSymbol = function(_, slot, sym_build, symbol)
                    if slot == "swap_body" or slot == "swap_body_tall" then
                        items_anim_symbols[item.prefab] = {sym_build, symbol}
                    else
                        AnimStateOrig:OverrideSymbol(slot, sym_build, symbol)
                    end
                end,
                OverrideItemSkinSymbol = function(_, slot, skin_build, symbol, item_guid, sym_build)
                    if slot == "swap_body" or slot == "swap_body_tall" then
                        items_anim_symbols[item.prefab] = {sym_build, symbol}
                    else
                        AnimStateOrig:OverrideItemSkinSymbol(slot, skin_build, symbol, item_guid, sym_build)
                    end
                end
            })
            owner.AnimState = AnimStateProxy
            onequipfn_orig(item, owner)
            owner.AnimState = AnimStateOrig
        end

        inst.components.equippable:SetOnEquip(onequipfn_new)

        -- For repairable items re-assign `onequipfn` on repairing.
        if inst.components.forgerepairable ~= nil then
            mod.override_method(inst.components.forgerepairable, 'onrepaired', function(super, inst1, ...)
                super(inst1, ...)
                inst1.components.equippable:SetOnEquip(onequipfn_new)
            end)
        end
    end)

    local function get_equipped_item(inventory, type)
        local candidate = inventory:GetEquippedItem(EQUIPSLOTS_MAP[string.upper(type)])
        return ((candidate ~= nil) and candidate:HasTag(type)) and candidate or nil
    end

    local function render_equipped_item(owner, render_slot, item)
        if item ~= nil then
            local build_and_symbol = items_anim_symbols[item.prefab]
            if build_and_symbol ~= nil then
                local skin_build = item:GetSkinBuild()
                if skin_build ~= nil then
                    owner.AnimState:OverrideItemSkinSymbol(render_slot, skin_build, build_and_symbol[2], item.GUID, build_and_symbol[1])
                else
                    owner.AnimState:OverrideSymbol(render_slot, build_and_symbol[1], build_and_symbol[2])
                end
            end
        else
            owner.AnimState:ClearOverrideSymbol(render_slot)
        end
    end

    local function render_body_equipment(owner)
        local inventory = owner.replica.inventory

        local item1 =
                   get_equipped_item(inventory, EQUIP_TYPES.BACKPACK)
                or get_equipped_item(inventory, EQUIP_TYPES.BAND)
                or get_equipped_item(inventory, EQUIP_TYPES.SHELL)
        local item2 =
                   get_equipped_item(inventory, EQUIP_TYPES.HEAVY)
                or get_equipped_item(inventory, EQUIP_TYPES.LIFEVEST)
                or get_equipped_item(inventory, EQUIP_TYPES.COSTUME)
                or get_equipped_item(inventory, EQUIP_TYPES.ARMOR)
                or get_equipped_item(inventory, EQUIP_TYPES.DRESS)
                or get_equipped_item(inventory, EQUIP_TYPES.AMULET)
                or inventory:GetEquippedItem(GLOBAL.EQUIPSLOTS.BODY) -- Fallback to an item of unknown type.

        render_equipped_item(owner, "swap_body_tall", item1)
        render_equipped_item(owner, "swap_body",      item2)
    end

    local function on_equip_or_unequip(owner, data)
        if table.contains(BODY_EQUIPSLOTS, data.eslot) then
            render_body_equipment(owner)
        end
    end

    AddComponentPostInit("inventory", function(_, inst)
        if GLOBAL.TheWorld.ismastersim then
            inst:ListenForEvent("equip",   on_equip_or_unequip)
            inst:ListenForEvent("unequip", on_equip_or_unequip)
        end
    end)

    -- In the state "amulet_rebirth" the Life Giving Amulet is removed but the anim symbol is not cleared.
    -- This is a problem, because we always clear the symbol on unequip. Let's workaround this.
    -- See `stategraphs/SGwilson.lua` > `"amulet_rebirth"` > `onenter`.
    -- See `scripts/prefabs/amulet.lua` > `onunequip_red`.
    AddStategraphPostInit("wilson", function(self)
        local amulet_rebirth_state = self.states["amulet_rebirth"]

        -- Prevents removing the amulet on entering the state.
        mod.override_method(amulet_rebirth_state, "onenter", function(super, ...)
            -- Replace the original slot by some non-existing slot to prevent discovering of the amulet.
            mod.with_override(GLOBAL.EQUIPSLOTS, 'BODY', "", super, ...)
        end)

        -- Instead, remove the amulet on exiting the state.
        mod.override_method(amulet_rebirth_state, "onexit", function(super, inst)
            local item = inst.components.inventory:GetEquippedItem(EQUIPSLOTS_MAP.AMULET)
            if item ~= nil and item.prefab == "amulet" then
                item = inst.components.inventory:RemoveItem(item)
                if item ~= nil then
                    item:Remove()
                end
            end
            super(inst)
        end)
    end)

end
