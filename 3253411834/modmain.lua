GLOBAL.setmetatable(env,{__index=function(t,k) return GLOBAL.rawget(GLOBAL,k) end})  --GLOBAL相关照抄


-- logger
local ModLogKey = "lijr auto_equip_repair"
local DebugEnable = GetModConfigData("LogDebugEnable")
local InfoEnable = GetModConfigData("LogInfoEnable")
local ErrorEnable = GetModConfigData("LogErrorEnable")

local function LogDebug(...)
    if DebugEnable then
        print("[Debug]", ModLogKey, ...)
    end
end

local function LogDebug(name, ...)
    if DebugEnable then
        print("[Debug]", ModLogKey, tostring(name), ...)
    end
end

local function LogInfo(...)
    if InfoEnable then
        print("[Info]", ModLogKey, ...)
    end
end

local function LogError(...)
    if ErrorEnable then
        print("[Error]", ModLogKey, ...)
    end
end

-- user setting
function IsEnabled(Setting)
    return GetModConfigData(Setting)
end
local isFreezerEnable = IsEnabled("Freezer")
local isAutoOpen = IsEnabled("SlotAutoOpen")
local isPlayerInventoryEnable = IsEnabled("UsePlayerInventory")

-- custom slot roder
local CustomOrderType = {
    hand = "hand",
    backpack = "backpack",
    bodyArmor = "bodyArmor",
    bodyCloth = "bodyCloth",
    amulet = "amulet",
    hat = "hat",
}

local slot_order = {}
local function initSlotOrderTable(configName)
    local tmp = GetModConfigData(configName)
    if tmp ~= -1 then
        slot_order[configName] = tmp
        LogDebug("sort_order", configName, tmp)
    end
end

initSlotOrderTable("hand")
initSlotOrderTable("backpack")
initSlotOrderTable("hat")
initSlotOrderTable("bodyCloth")
initSlotOrderTable("amulet")
initSlotOrderTable("bodyArmor")

if DebugEnable then
    for k, v in pairs(CustomOrderType) do
        LogDebug("config sort order", k, v, slot_order[v])
    end
end

-- local config
-- local lunarRepair = "forgerepair_" .. FORGEMATERIALS.LUNARPLANT

local equip_pos = {
    hand = Vector3(0, 15, 0),
    body = Vector3(53, 15, 0),
    head = Vector3(53*2, 15, 0),
    back = Vector3(53*3, 15, 0),
    neck = Vector3(53*4, 15, 0)
}

local repair_type = {
    fuel = "fuel",
    fit = "fit",
    armor = "armor",
    sewing = "sewing",
    forge = "forge",
    eat = "eat",
    repairable = "repairable",
}

local nightmare_materials_predict = function(container, item, slot)
    return item.prefab == "nightmarefuel" or item.prefab == "horrorfuel"
end

local lunar_materials_predict = function(container, item, slot)
    return item.prefab == "lunarplant_kit"
end

local void_materials_predict = function(container, item, slot)
    return item.prefab == "voidcloth_kit"
end

local cave_materials = { "lightbulb", "fireflies", "slurtleslime"}
local cave_materials_predict = function(container, item, slot)
    return table.contains(cave_materials, item.prefab)
end

local wormlight_materials = { "wormlight", "wormlight_lesser" }
local wormlight_materials_predict = function(container, item, slot)
    return table.contains(wormlight_materials, item.prefab)
end

local usage_materials = { "sewing_tape", "sewing_kit" }
local usage_materials_predict = function(container, item, slot)
    return table.contains(usage_materials, item.prefab)
end

local materials_for_eat = function(container, food, slot)
    LogDebug("PrefersToEat", "food", food.perfab, "eater", container.inst.perfab)
    LogDebug("PrefersToEat2", "food", food.GUID, "eater", container.inst.GUID)
    for k,v in pairs(food) do 
        LogDebug("PrefersToEat3", "food", "k", k, "v", v)
    end

    -- return container.inst.components.eater:PrefersToEat(food)

    for i,v in ipairs(FOODGROUP.OMNI.types) do
        if food:HasTag("edible_" .. v) then
            return true
        end
    end
    return false
end

local used_fuel_materials_table = {
    USAGE = usage_materials_predict,
    CAVE = cave_materials_predict,
}

local fuel_value = {
    lightbulb = TUNING.MED_LARGE_FUEL,
    fireflies = TUNING.LARGE_FUEL,
    slurtleslime = TUNING.MED_FUEL,
    nightmarefuel = TUNING.LARGE_FUEL,
    horrorfuel = TUNING.LARGE_FUEL * 2,
    sewing_kit = TUNING.SEWINGKIT_REPAIR_VALUE,
    sewing_tape = TUNING.SEWING_TAPE_REPAIR_VALUE,
    wormlight = TUNING.WORMLIGHT_DURATION,
    wormlight_lesser = TUNING.WORMLIGHT_DURATION,
}

local repairer_value = {
    nightmarefuel = TUNING.NIGHTMAREFUEL_FINITEUSESREPAIRVALUE,
    horrorfuel = TUNING.NIGHTMAREFUEL_FINITEUSESREPAIRVALUE * 2,
}

local item_config = {
    yellowamulet = {
        itemtestfn = nightmare_materials_predict,
        pos = equip_pos.body,
        could_pos_neck = true,
        type = repair_type.fuel,
        accurately = true,
        custom_order = slot_order[CustomOrderType.amulet] ~= nil and slot_order[CustomOrderType.amulet] or nil,
    },
    orangeamulet = {
        itemtestfn = nightmare_materials_predict,
        pos = equip_pos.body,
        could_pos_neck = true,
        type = repair_type.fit,
        repair_type = repair_type.repairable,
        accurately = true,
        custom_order = slot_order[CustomOrderType.amulet] ~= nil and slot_order[CustomOrderType.amulet] or nil,
        isFuelNeed =    function(inst, fuelFinded)
                            -- for repairable
                            local repair_item_repairer = fuelFinded.components.repairer
                            local fuelValue = repair_item_repairer.finiteusesrepairvalue

                            local needLessThan = inst.components.finiteuses.total - fuelValue
                            LogDebug("yellowAmuletNeedFunc",
                            "current", inst.components.finiteuses.current,
                            "total",inst.components.finiteuses.total,
                            "fuelValue",fuelValue)
                            return inst.components.finiteuses.current <= needLessThan
                        end,
    },

    sword_lunarplant = {
        itemtestfn = lunar_materials_predict,
        pos = equip_pos.hand,
        type = repair_type.fit,
        repair_type = repair_type.forge,
        accurately = false,
        animbank = "ui_alterguardianhat_1x1",
        animbuild = "ui_alterguardianhat_1x1",
        custom_order = slot_order[CustomOrderType.hand] ~= nil and slot_order[CustomOrderType.hand] or nil,
    },
    armor_lunarplant = {
        itemtestfn = lunar_materials_predict,
        pos = equip_pos.body,
        type = repair_type.armor,
        repair_type = repair_type.forge,
        accurately = false,
        animbank = "ui_alterguardianhat_1x1",
        animbuild = "ui_alterguardianhat_1x1",
        custom_order = slot_order[CustomOrderType.bodyArmor] ~= nil and slot_order[CustomOrderType.bodyArmor] or nil,
    },
    armor_lunarplant_husk = {
        itemtestfn = lunar_materials_predict,
        pos = equip_pos.body,
        type = repair_type.armor,
        repair_type = repair_type.forge,
        accurately = false,
        animbank = "ui_alterguardianhat_1x1",
        animbuild = "ui_alterguardianhat_1x1",
        custom_order = slot_order[CustomOrderType.bodyArmor] ~= nil and slot_order[CustomOrderType.bodyArmor] or nil,
    },
    lunarplanthat = {
        itemtestfn = lunar_materials_predict,
        pos = equip_pos.head,
        type = repair_type.armor,
        repair_type = repair_type.forge,
        accurately = false,
        animbank = "ui_alterguardianhat_1x1",
        animbuild = "ui_alterguardianhat_1x1",
        custom_order = slot_order[CustomOrderType.hat] ~= nil and slot_order[CustomOrderType.hat] or nil,
    },
    shovel_lunarplant = {
        itemtestfn = lunar_materials_predict,
        pos = equip_pos.hand,
        type = repair_type.fit,
        repair_type = repair_type.forge,
        accurately = false,
        animbank = "ui_alterguardianhat_1x1",
        animbuild = "ui_alterguardianhat_1x1",
        custom_order = slot_order[CustomOrderType.hand] ~= nil and slot_order[CustomOrderType.hand] or nil,
    },
    staff_lunarplant = {
        itemtestfn = lunar_materials_predict,
        pos = equip_pos.hand,
        type = repair_type.fit,
        repair_type = repair_type.forge,
        accurately = false,
        animbank = "ui_alterguardianhat_1x1",
        animbuild = "ui_alterguardianhat_1x1",
        custom_order = slot_order[CustomOrderType.hand] ~= nil and slot_order[CustomOrderType.hand] or nil,
    },
    pickaxe_lunarplant = {
        itemtestfn = lunar_materials_predict,
        pos = equip_pos.hand,
        type = repair_type.fit,
        repair_type = repair_type.forge,
        accurately = false,
        animbank = "ui_alterguardianhat_1x1",
        animbuild = "ui_alterguardianhat_1x1",
        custom_order = slot_order[CustomOrderType.hand] ~= nil and slot_order[CustomOrderType.hand] or nil,
    },
    armor_voidcloth = {
        itemtestfn = void_materials_predict,
        pos = equip_pos.body,
        type = repair_type.armor,
        repair_type = repair_type.forge,
        accurately = false,
        animbank = "ui_antlionhat_1x1",
        animbuild = "ui_antlionhat_1x1",
        posh = 40,
        custom_order = slot_order[CustomOrderType.bodyArmor] ~= nil and slot_order[CustomOrderType.bodyArmor] or nil,
    },
    voidclothhat = {
        itemtestfn = void_materials_predict,
        pos = equip_pos.head,
        type = repair_type.armor,
        repair_type = repair_type.forge,
        accurately = false,
        animbank = "ui_antlionhat_1x1",
        animbuild = "ui_antlionhat_1x1",
        posh = 40,
        custom_order = slot_order[CustomOrderType.hat] ~= nil and slot_order[CustomOrderType.hat] or nil,
    },
    voidcloth_umbrella = {
        itemtestfn = void_materials_predict,
        pos = equip_pos.hand,
        type = repair_type.fuel,
        repair_type = repair_type.forge,
        accurately = false,
        animbank = "ui_antlionhat_1x1",
        animbuild = "ui_antlionhat_1x1",
        posh = 40,
        custom_order = slot_order[CustomOrderType.hand] ~= nil and slot_order[CustomOrderType.hand] or nil,
    },
    voidcloth_scythe = {
        itemtestfn = void_materials_predict,
        pos = equip_pos.hand,
        type = repair_type.fit,
        repair_type = repair_type.forge,
        accurately = false,
        animbank = "ui_antlionhat_1x1",
        animbuild = "ui_antlionhat_1x1",
        posh = 40,
        custom_order = slot_order[CustomOrderType.hand] ~= nil and slot_order[CustomOrderType.hand] or nil,
    },
    shadow_battleaxe = {
        itemtestfn = void_materials_predict,
        pos = equip_pos.hand,
        type = repair_type.fit,
        repair_type = repair_type.forge,
        accurately = false,
        animbank = "ui_antlionhat_1x1",
        animbuild = "ui_antlionhat_1x1",
        posh = 40,
        custom_order = slot_order[CustomOrderType.hand] ~= nil and slot_order[CustomOrderType.hand] or nil,
    },
    lantern = {
        itemtestfn = cave_materials_predict,
        pos = equip_pos.hand,
        type = repair_type.fuel,
        accurately = true,
        -- check_before_used = function (c) return cave_materials_predict(nil,c,nil) end,
        need_perish = true,
        custom_order = slot_order[CustomOrderType.hand] ~= nil and slot_order[CustomOrderType.hand] or nil,
    },
    minerhat = {
        itemtestfn = cave_materials_predict,
        pos = equip_pos.head,
        type = repair_type.fuel,
        accurately = true,
        -- check_before_used = function (c) return cave_materials_predict(nil,c,nil) end,
        need_perish = true,
        custom_order = slot_order[CustomOrderType.hat] ~= nil and slot_order[CustomOrderType.hat] or nil,
    },
    beefalohat = {
        itemtestfn = usage_materials_predict,
        pos = equip_pos.head,
        type = repair_type.fuel,
        repair_type = repair_type.sewing,
        accurately = true,
        custom_order = slot_order[CustomOrderType.hat] ~= nil and slot_order[CustomOrderType.hat] or nil,
    },
    molehat = {
        itemtestfn = wormlight_materials_predict,
        pos = equip_pos.head,
        type = repair_type.fuel,
        accurately = true,
        need_perish = true,
        custom_order = slot_order[CustomOrderType.hat] ~= nil and slot_order[CustomOrderType.hat] or nil,
    },
    -- tophat = {
    --     itemtestfn = usage_materials_predict,
    --     pos = equip_pos.head,
    --     type = repair_type.fuel,
    --     repair_type = repair_type.sewing,
    --     accurately = true,
    --     usemaster = true,
    --     custom_order = slot_order[CustomOrderType.hat] ~= nil and slot_order[CustomOrderType.hat] or nil,
    -- },
    beargervest = {
        itemtestfn = usage_materials_predict,
        pos = equip_pos.body,
        type = repair_type.fuel,
        repair_type = repair_type.sewing,
        accurately = true,
        custom_order = slot_order[CustomOrderType.bodyCloth] ~= nil and slot_order[CustomOrderType.bodyCloth] or nil,
    },
    pocketwatch_weapon = {
        itemtestfn = nightmare_materials_predict,
        pos = equip_pos.hand,
        type = repair_type.fuel,
        accurately = true,
        custom_order = slot_order[CustomOrderType.hand] ~= nil and slot_order[CustomOrderType.hand] or nil,
    },
    armorskeleton = {
        itemtestfn = nightmare_materials_predict,
        pos = equip_pos.body,
        type = repair_type.fuel,
        accurately = true,
        custom_order = slot_order[CustomOrderType.bodyArmor] ~= nil and slot_order[CustomOrderType.bodyArmor] or nil,
        animbank = "ui_antlionhat_1x1",
        animbuild = "ui_antlionhat_1x1",
        posh = 40,
    },

    --eyemaskhat

    eyemaskhat = {
        itemtestfn = materials_for_eat,
        need_perish = true,
        pos = equip_pos.head,
        type = repair_type.armor,
        repair_type = repair_type.eat,
        accurately = true,
        custom_order = slot_order[CustomOrderType.hat] ~= nil and slot_order[CustomOrderType.hat] or nil,
        isFuelNeed =    function(inst, food)
            -- eye eat
            local health = math.abs(food.components.edible:GetHealth(inst)) * inst.components.eater.healthabsorption
            local hunger = math.abs(food.components.edible:GetHunger(inst)) * inst.components.eater.hungerabsorption
            local fuelValue = health + hunger

            local needLessThan = inst.components.armor.maxcondition - fuelValue
            local current = inst.components.armor.condition
            local total = inst.components.armor.maxcondition
            LogDebug("eyeEatCheck","current", current,"total",total,"fuelValue",fuelValue,"needLessThan",needLessThan)
            return current <= needLessThan or current <= 100
        end
    },
    -- shieldofterror
    shieldofterror = {
        itemtestfn = materials_for_eat,
        need_perish = true,
        pos = equip_pos.hand,
        type = repair_type.armor,
        repair_type = repair_type.eat,
        accurately = true,
        custom_order = slot_order[CustomOrderType.hand] ~= nil and slot_order[CustomOrderType.hand] or nil,
        isFuelNeed =    function(inst, food)
            -- shieldofterror
            local health = math.abs(food.components.edible:GetHealth(inst)) * inst.components.eater.healthabsorption
            local hunger = math.abs(food.components.edible:GetHunger(inst)) * inst.components.eater.hungerabsorption
            local fuelValue = health + hunger

            local needLessThan = inst.components.armor.maxcondition - fuelValue
            local current = inst.components.armor.condition
            local total = inst.components.armor.maxcondition
            LogDebug("shieldofterror","current", current,"total",total,"fuelValue",fuelValue,"needLessThan",needLessThan)
            return current <= needLessThan or current <= 100
        end
    },
}

item_config.reflectivevest = item_config.beargervest
item_config.trunkvest_winter = item_config.beargervest
item_config.trunkvest_summer = item_config.beargervest
item_config.sweatervest = item_config.beargervest
item_config.raincoat = item_config.beargervest
item_config.armorslurper = item_config.beargervest
item_config.carnival_vest_a = item_config.beargervest
item_config.carnival_vest_b = item_config.beargervest
item_config.carnival_vest_c = item_config.beargervest

item_config.eyebrellahat = item_config.beefalohat
item_config.polly_rogershat = item_config.beefalohat
item_config.winterhat = item_config.beefalohat
item_config.catcoonhat = item_config.beefalohat
item_config.rainhat = item_config.beefalohat
item_config.earmuffshat = item_config.beefalohat
item_config.walrushat = item_config.beefalohat

item_config.strawhat = item_config.beefalohat
item_config.goggleshat = item_config.beefalohat
item_config.deserthat = item_config.beefalohat
item_config.walterhat = item_config.beefalohat

if DebugEnable then
    LogDebug("beefalohat custom_order", item_config.beefalohat.custom_order)
end

-- some function 

local function getSlotPos(item)
    return item.posh == nil and Vector3(0,   32 + 4,  0) or Vector3(0, 2, 0)
end

local function getPos(item)
    local useX = item.pos.x
    local useY = item.posh ~= nil and item.posh or item.pos.y
    local useZ = item.pos.z

    if item.custom_order ~= nil then
        useX = 53*(item.custom_order-1)
    end
    return  Vector3(useX, useY, useZ)
end

-- containers
local containers = require("containers")

for perfab, item in pairs(item_config) do
    containers.params[perfab .. "_container"] = {
        widget =
        {
            slotpos =
            {
                item.posh == nil and Vector3(0,   32 + 4,  0) or Vector3(0, 2, 0),
            },
            slotbg =
            {
                { image = "slingshot_ammo_slot.tex" },
            },
            animbank = item.animbank ~= nil and item.animbank or "ui_cookpot_1x2",
            animbuild = item.animbuild ~= nil and item.animbuild or "ui_cookpot_1x2",
            pos = getPos(item),
        },
        usespecificslotsforitems = true,
        type = "hand_inv",
        excludefromcrafting = true,
        itemtestfn = item.itemtestfn
    }

end

local needRebuildConfig = {"eyemaskhat", "shieldofterror", "molehat"}

for _,prefab in pairs(needRebuildConfig) do
    containers.params[prefab .. "_container"].widget.slotpos = 
    {
        Vector3(0,   32 + 4,  0),
        Vector3(0, -(32 + 4), 0),
    }
    containers.params[prefab .. "_container"].widget.slotbg = 
    {
        { image = "slingshot_ammo_slot.tex" },
        { image = "slingshot_ammo_slot.tex" },
    }
    local oldX = containers.params[prefab .. "_container"].widget.pos.x
    containers.params[prefab .. "_container"].widget.pos = Vector3(oldX, 60, 0)
end

-- 从玩家背包中寻找合适的修复材料
local function findItemFromPlayerInventory(doer, prefabName)
    local itemtestfn = containers.params[prefabName .. "_container"].itemtestfn
    if itemtestfn == nil or doer == nil or doer.components.inventory == nil then
        return nil
    end

    local numSlots = doer.components.inventory:GetNumSlots()
    for i = 0, numSlots - 1 do
        local item = doer.components.inventory:GetItemInSlot(i)
        if item ~= nil and itemtestfn(nil, item, nil) then
            return item
        end
    end
    return nil
end

local function checkAndRepair(inst, prefabConfig, callBack, isFuelNeedFunc)
    local doer = inst.components.inventoryitem.owner
    local fuelFinded = nil
    if prefabConfig.usemaster then
        -- LogDebug("tophat2 used K1")
        -- if inst.components.magiciantool ~= nil then
        --     LogDebug("tophat2 used K2")
        --     if inst.components.magiciantool ~= nil then
        --         LogDebug("tophat2 used K3", inst.components.magiciantool)
        --         for k,v in pairs(inst.components.magiciantool) do
        --             LogDebug("tophat2 used K4", k, "->", v)
        --         end
        --     end
        --     if inst.components.container_proxy ~= nil then
        --         fuelFinded = magicInst.components.container_proxy.master.components.container:FindItem(function () return true end )
        --         LogDebug("tophat2 used K100", fuelFinded)
        --     end
        -- else
        --     fuelFinded = inst.components.container:FindItem(function () return true end )
        -- end
    else
        if isPlayerInventoryEnable and doer ~= nil then
            fuelFinded = findItemFromPlayerInventory(doer, inst.prefab)
        else
            fuelFinded = inst.components.container:FindItem(function () return true end )
        end
    end


    local fuelAdded = false
    if fuelFinded ~= nil then
        local needAdd = isFuelNeedFunc == nil and true or isFuelNeedFunc(inst, fuelFinded)
        if needAdd == false then
            -- do nothing
        elseif fuelFinded.components.stackable == nil then
            if prefabConfig.repair_type == repair_type.sewing then
                fuelFinded.components.sewing:DoSewing(inst, doer)
            else
                LogError("stackable is nil ", fuelFinded ~= nil and fuelFinded.name or "fuelIsNil", inst.name)
            end
        else
            local usedFuel = fuelFinded.components.stackable:Get(1)

            local actionType = prefabConfig.repair_type ~= nil and prefabConfig.repair_type or prefabConfig.type
            if actionType == repair_type.forge then
                inst.components.forgerepairable:Repair(doer, usedFuel)
            elseif actionType == repair_type.fuel then
                inst.components.fueled:TakeFuelItem(usedFuel, doer)
            elseif actionType == repair_type.sewing then
                usedFuel.components.sewing:DoSewing(inst, doer)
            elseif actionType == repair_type.repairable then
                inst.components.repairable:Repair(doer, usedFuel)
            elseif actionType == repair_type.eat then
                inst.components.eater:Eat(usedFuel,doer)
            end
            fuelAdded = true
        end
    end
    callBack(fuelAdded)
end

local function checkAndRepair2(inst, prefabConfig, isFuelNeedFunc)
    local doer = inst.components.inventoryitem.owner
    local fuelFinded = nil
    if isPlayerInventoryEnable and doer ~= nil then
        fuelFinded = findItemFromPlayerInventory(doer, inst.prefab)
    else
        fuelFinded = inst.components.container:FindItem(function () return true end )
    end
    -- if prefabConfig.usemaster then
    --     LogDebug("tophat2 used K1")
    --     if inst.components.magiciantool ~= nil then
    --         LogDebug("tophat2 used K2")
    --         if inst.components.magiciantool ~= nil then
    --             LogDebug("tophat2 used K3", inst.components.magiciantool)
    --             for k,v in pairs(inst.components.magiciantool) do
    --                 LogDebug("tophat2 used K4", k, "->", v)
    --             end
    --         end
    --         if inst.components.container_proxy ~= nil then
    --             fuelFinded = magicInst.components.container_proxy.master.components.container:FindItem(function () return true end )
    --             LogDebug("tophat2 used K100", fuelFinded)
    --         end
    --     else
    --         fuelFinded = inst.components.container:FindItem(function () return true end )
    --     end
    -- else
    --     fuelFinded = inst.components.container:FindItem(function () return true end )
    -- end

    local fuelAdded = false
    if fuelFinded ~= nil then
        local needAdd = isFuelNeedFunc == nil and true or isFuelNeedFunc(inst, fuelFinded)
        if needAdd == false then
            -- do nothing
        elseif fuelFinded.components.stackable == nil then
            if prefabConfig.repair_type == repair_type.sewing then
                fuelFinded.components.sewing:DoSewing(inst, doer)
            else
                LogError("stackable is nil ", fuelFinded ~= nil and fuelFinded.name or "fuelIsNil", inst.name)
            end
        else
            local usedFuel = fuelFinded.components.stackable:Get(1)

            local actionType = prefabConfig.repair_type ~= nil and prefabConfig.repair_type or prefabConfig.type
            if actionType == repair_type.forge then
                inst.components.forgerepairable:Repair(doer, usedFuel)
            elseif actionType == repair_type.fuel then
                inst.components.fueled:TakeFuelItem(usedFuel, doer)
            elseif actionType == repair_type.sewing then
                usedFuel.components.sewing:DoSewing(inst, doer)
            elseif actionType == repair_type.repairable then
                inst.components.repairable:Repair(doer, usedFuel)
            elseif actionType == repair_type.eat then
                inst.components.eater:Eat(usedFuel,doer)
            end
            fuelAdded = true
        end
    end
end

local function fuelDeleped(inst, prefabConfig)
    local oldFuelDepleted = inst.components.fueled ~= nil and inst.components.fueled.depleted or nil
    if oldFuelDepleted ~= nil then
        LogDebug("loadFunction", tostring(inst.name), "oldFuelDepleted")
        inst.components.fueled.depleted = function (item)
            checkAndRepair(item, prefabConfig, function (fuelAdded)
                if fuelAdded == false then
                    oldFuelDepleted(item)
                end
            end)
        end
    end
end

local function is_fuel_need(inst, fuelFinded)
    local needLessThan = inst.components.fueled.maxfuel - fuel_value[fuelFinded.prefab]
    return inst.components.fueled.currentfuel <= needLessThan
end

local function fuelDoDelta(inst, prefabConfig)
    local oldFuelDoDelta = inst.components.fueled ~= nil and inst.components.fueled.DoDelta or nil
    if oldFuelDoDelta ~= nil then
        LogDebug("loadFunction", tostring(inst.name), "oldFuelDoDelta")
        inst.components.fueled.DoDelta = function(amount, temp)
            LogDebug("DoDelt", tostring(inst.name), temp)

            if temp ~= nil and type(temp) == "number" and temp > 0 then 
                oldFuelDoDelta(amount, temp)
                return
            end

            checkAndRepair(inst, prefabConfig, 
                function (a) oldFuelDoDelta(amount, temp) end,
                is_fuel_need
            );
        end
    end
end

local function allDodelta(inst, prefabConfig)
    inst:ListenForEvent("percentusedchange", function(i, data)
        LogDebug("allDodelta", inst.name, data.percent)

        checkAndRepair2(inst, prefabConfig, prefabConfig.isFuelNeed and prefabConfig.isFuelNeed or is_fuel_need);
    end)
end

local function solveFinishFit(inst, prefabConfig)
    local oldOnFinished = inst.components.finiteuses ~= nil and inst.components.finiteuses.onfinished or nil
    if oldOnFinished ~= nil then
        LogDebug("loadFunction", tostring(inst.name), "oldOnFinished")
        inst.components.finiteuses.onfinished = function (item)
                checkAndRepair(item, prefabConfig, function (fuelAdded)
                if fuelAdded == false then
                    oldOnFinished(item)
                end
            end)
        end
    end
end

local function solveFinishArmor(inst, prefabConfig)
    local oldOnFinishedArmor = inst.components.armor ~= nil and inst.components.armor.onfinished or nil
    if oldOnFinishedArmor ~= nil then
        LogDebug("loadFunction", tostring(inst.name), "oldOnFinished")
        inst.components.armor.onfinished = function (item)
            checkAndRepair(item, prefabConfig, function (fuelAdded)
                if fuelAdded == false then
                    oldOnFinishedArmor(item)
                end
            end)
        end
    end
end

local function solveAfterRepair(inst, prefabConfig)
    local oldRepaired = inst.components.forgerepairable ~= nil and inst.components.forgerepairable.onrepaired or nil
    if oldRepaired ~= nil then
        LogDebug("loadFunction", tostring(inst.name), "oldRepaired")
        inst.components.forgerepairable.onrepaired = function (item)
            oldRepaired(item)
            if inst.components.container == nil then
                LogError("container missing", inst.name)
                inst:AddComponent("container")
                inst.components.container:WidgetSetup(inst.prefab .. "_container")
                inst.components.container.canbeopened = false
            end
        end
    end
end

local function loadRuntimeConfig(inst)
    local itemConfig = item_config[inst.prefab]
    -- if itemConfig.custom_order ~= nil then
    --     LogDebug("fixOrder", inst.name, itemConfig.custom_order, itemConfig.custom_order-1)
    --     local order = itemConfig.custom_order - 1
    --     local oldPos = containers.params.yellowamulet_container.widget.pos
    --     containers.params.yellowamulet_container.widget.pos = itemConfig.posh ~= nil and Vector3(53*order, itemConfig.posh, oldPos.z) or Vector3(53*order, oldPos.y, oldPos.z)
    --     return
    -- end
    if itemConfig.could_pos_neck ~= nil and GLOBAL.EQUIPSLOTS.NECK ~= nil then
        containers.params[inst.prefab .. "_container"].widget.pos = itemConfig.posh ~= nil and Vector3(equip_pos.neck.x, itemConfig.posh, equip_pos.neck.z) or equip_pos.neck
    end
end

local function addAutorepair(inst)
    loadRuntimeConfig(inst)

    if not TheWorld.ismastersim then
        inst.OnEntityReplicated = function(inst) inst.replica.container:WidgetSetup(inst.prefab .."_container") end
        return inst
    end

    if inst.components.container ~= nil then
        inst.components.container = nil
    end
    inst:AddComponent("container")
    inst.components.container:WidgetSetup(inst.prefab .. "_container")
    inst.components.container.canbeopened = false

    inst:ListenForEvent("equipped", function(i, event)
        i.components.container.canbeopened = true
        if isAutoOpen and i.components.container ~= nil then
            i.components.container:Open(event.owner)
        end
    end)

-- old code will get a container.canbeopend false
-- because lunar ammor will remove onequip method after broken, and reset after repair
-- if I override this function ,i will resolve broken

    -- local oldOnEquip = inst.components.equippable.onequipfn
    -- inst.components.equippable.onequipfn = nil
    -- inst.components.equippable.onequipfn = function(inst, owner)
    --     oldOnEquip(inst, owner)
    --     inst.components.container.canbeopened = true
    --     if inst.components.container ~= nil then
    --         inst.components.container:Open(owner)
    --     end
    -- end

    inst:ListenForEvent("unequipped", function(i, data)
        i.components.container.canbeopened = false
        if i.components.container ~= nil then
            i.components.container:Close()
        end
    end)

    -- local oldOnUnequip = inst.components.equippable.onunequipfn
    -- inst.components.equippable.onunequipfn = function(inst, owner)
    --     oldOnUnequip(inst, owner)
    --     inst.components.container.canbeopened = false
    --     if inst.components.container ~= nil then
    --         inst.components.container:Close()
    --     end
    -- end

    local prefabName = inst.prefab
    local prefabConfig = item_config[prefabName]

    if isFreezerEnable and prefabConfig.need_perish ~= nil then
        if inst.components.preserver ~= nil then
            inst.components.preserver = nil
        end
        inst:AddComponent("preserver")
        inst.components.preserver:SetPerishRateMultiplier(0)
    end


    if prefabConfig.type == repair_type.fuel then 
        fuelDeleped(inst, prefabConfig)
        if prefabConfig.accurately then
            fuelDoDelta(inst, prefabConfig)
        end
    end

    if prefabConfig.type == repair_type.fit then
        solveFinishFit(inst, prefabConfig)
        if prefabConfig.accurately then
            if prefabConfig.repair_type == repair_type.repairable then
                -- yellowamulet
                allDodelta(inst, prefabConfig)
            end
        end
    end

    if prefabConfig.type == repair_type.armor then
        if prefabConfig.repair_type == repair_type.forge then
            solveFinishArmor(inst, prefabConfig)
            if prefabConfig.accurately then

            end
            solveAfterRepair(inst, prefabConfig)
        end
        
        if prefabConfig.repair_type == repair_type.eat then
            -- eye mask not need override onfinish, because it`s a bad solution
            if prefabConfig.accurately then
                allDodelta(inst,prefabConfig)
            end
        end
    end

    
    -- local oldFiniteUsed = inst.components.finiteuses ~= nil and inst.components.finiteuses.Use or nil
    -- if oldFiniteUsed ~= nil then
    --     LogDebug("loadFunction", tostring(inst.name), "oldFiniteUsed")
    --     inst.components.finiteuses.Use = function (num)
    --         local doer = inst.components.inventoryitem.owner
    --         local fuelFinded = inst.components.container:FindItem(function () return true end )
    --         local fuelAdded = false
    --         if fuelFinded ~= nil then
    --             local needLessThan = 50
    --             if fuelFinded.prefab == "lunarplant_kit" then
    --                 needLessThan = inst.components.finiteuses.total - 10
    --             end
    --             LogDebug("checkFuelNeed", "need and now", tostring(needLessThan), tostring(inst.components.finiteuses.current))

    --             if fuelFinded.components.stackable == nil then
    --                 LogError("stackable is nil ", fuelFinded ~= nil and fuelFinded.name or "fuelIsNil")
    --             elseif inst.components.finiteuses.current <= needLessThan then
    --                 local usedFuel = fuelFinded.components.stackable:Get(1)
    --                 inst.components.forgerepairable:Repair(doer, usedFuel)
    --                 fuelAdded = true
    --             end
    --         end

    --         oldFiniteUsed(num)
    --     end
    -- end
end

for prefab,_ in pairs(item_config) do
    if IsEnabled(prefab) then
        AddPrefabPostInit(prefab, addAutorepair)
    end
end

-- 嚎弹炮
-- containers.params.houndstooth_blowpipe = {
--     widget =
--     {
--         slotpos = {},
--         slotbg = {},
--         animbank = "ui_alterguardianhat_1x6",
--         animbuild = "ui_alterguardianhat_1x6",
--         pos = Vector3(106, 150, 0),
--     },
--     usespecificslotsforitems = true,
--     type = "hand_inv",
--     excludefromcrafting = true
-- }

-- local AGHAT_SLOTSTART = 95
-- local AGHAT_SLOTDIFF = 72
-- local SLOT_BG = { image = "spore_slot.tex", atlas = "images/hud2.xml" }
-- for i = 0, 4 do
--     local sp = Vector3(0, AGHAT_SLOTSTART - (i*AGHAT_SLOTDIFF), 0)
--     table.insert(containers.params.houndstooth_blowpipe.widget.slotpos, sp)
--     table.insert(containers.params.houndstooth_blowpipe.widget.slotbg, SLOT_BG)
-- end

-- function containers.params.houndstooth_blowpipe.itemtestfn(container, item, slot)
-- 	return item:HasTag("blowpipeammo")
-- end