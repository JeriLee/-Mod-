-- Translation --

local lang_code = language or locale
if lang_code == "zhr" or lang_code == "zht" then
    lang_code = "zh"
end

local function tr(string)
    return string[lang_code] or string["en"]
end

local STRINGS = {
    NAME = {
        en = "More equip slots",
        ru = "Больше слотов для экипировки",
        zh = "更多装备槽（自用版）",
    },
    VERSION = {
        en = "Version: ",
        ru = "Версия: ",
        zh = "版本：",
    },
    DESCRIPTION = {
        en = "Allows to add extra equipment slots for armor, dress, and amulet. See <https://gitlab.com/AndreyMZ/dst-more-equip-slots> for details.",
        ru = "Позволяет добавлять дополнительные слоты снаряжения для брони, одежды и амулета. Подробнее см. <https://gitlab.com/AndreyMZ/dst-more-equip-slots>.",
        zh = "允许为护甲、衣服和护身符添加单独的装备槽。有关详细信息，请参阅 <https://gitlab.com/AndreyMZ/dst-more-equip-slots>。",
    },
    SLOT = {
        ORIGINAL = {
            en = "Original body slot",
            ru = "Основной слот",
            zh = "默认"
        },
        EXTRA_1 = {
            en = "Extra body slot #1",
            ru = "Дополнительный слот №1",
            zh = "插槽1",
        },
        EXTRA_2 = {
            en = "Extra body slot #2",
            ru = "Дополнительный слот №2",
            zh = "插槽2",
        },
        EXTRA_3 = {
            en = "Extra body slot #3",
            ru = "Дополнительный слот №3",
            zh = "插槽3",
        },
    },
    CONFIG = {
        SECTION_EQUIP = {
            en = "Тype/slot mapping",
            ru = "Соответствие тип/слот",
            zh = "型/槽映射",
        },
        HEAVY = {
            LABEL = {
                en = "Heavy",
                ru = "Тяжёлое",
                zh = "重型物品",
            },
            DESCRIPTION = {
                en = "In which slot do you want to equip heavy items?",
                ru = "В какой слот вы хотите экипировать тяжелые предметы?",
                zh = "您想在哪个插槽中装备重型物品？",
            },
        },
        BACKPACK = {
            LABEL = {
                en = "Backpack",
                ru = "Рюкзак",
                zh = "背包",
            },
            DESCRIPTION = {
                en = "In which slot do you want to equip backpacks?",
                ru = "В какой слот вы хотите экипировать рюкзаки?",
                zh = "您想在哪个插槽中装备背包？",
            },
        },
        COSTUME = {
            LABEL = {
                en = "Costume",
                ru = "Костюм",
                zh = "戏服",
            },
            DESCRIPTION = {
                en = "In which slot do you want to equip сostumes?",
                ru = "В какой слот вы хотите экипировать костюмы?",
                zh = "您想让你的戏服穿在那个位置？",
            },
        },
        ARMOR = {
            LABEL = {
                en = "Armor",
                ru = "Броня",
                zh = "护甲",
            },
            DESCRIPTION = {
                en = "In which slot do you want to equip armors?",
                ru = "В какой слот вы хотите экипировать броню?",
                zh = "您想让你的护甲穿在那个位置？",
            },
        },
        DRESS = {
            LABEL = {
                en = "Dress",
                ru = "Одежда",
                zh = "服装",
            },
            DESCRIPTION = {
                en = "In which slot do you want to equip dress?",
                ru = "В какой слот вы хотите экипировать одежду?",
                zh = "您想让你的服装穿在那个位置？",
            },
        },
        AMULET = {
            LABEL = {
                en = "Amulet",
                ru = "Амулет",
                zh = "护符",
            },
            DESCRIPTION = {
                en = "In which slot do you want to equip amulets?",
                ru = "В какой слот вы хотите экипировать амулеты?",
                zh = "您想让你的护符穿在那个位置？",
            },
        },
        SECTION_COMPATIBILITY = {
            en = "Compatibility",
            ru = "Cовместимость",
            zh = "兼容性",
        },
        RENDER = {
            LABEL = {
                en = "Render body equipment",
                ru = "Отрисовывать экипировку",
                zh = "人物是否显示所有装备外形",
            },
            DESCRIPTION = {
                en = "If no, then only the last equipped/unequipped body item will be rendered. "
                  .. "Switch off if there are problems (which may be with other mods).",
                ru = "Если нет, то будет отображаться только последний экипированный предмет. "
                  .. "Выключите, если возникают проблемы (возможно из-за других модов).",
                zh = "如果选否，则仅显示最后装备或未装备的人物外表。 "
                  .. "如果有模组物品不显示外形，请选否。",
            },
        },
        MANNEQUIN = {
            LABEL = {
                en = "Use a mannquine and punching bags",
                ru = "Использовать манекен и боксёрские груши",
                zh = "使用人体模型",
            },
            DESCRIPTION = {
                en = "If no, then a mannequin and punching bags will not accept items from the extra body slots. "
                  .. "Switch off if there are problems (which may be with other mods).",
                ru = "Если нет, то манекен и боксёрские груши не будут принимать вещи из дополнительных слотов. "
                  .. "Выключите, если возникают проблемы (возможно из-за других модов).",
                zh = nil,
            },
        },
        AUTO_BACKPACK = {
            LABEL = {
                en = "Autodetect backpacks",
                ru = "Автоопределение рюкзаков",
                zh = "自动侦测背包",
            },
            DESCRIPTION = {
                en = "If yes, then backpacks from *incompatible* mods will be equipped to the slot for backpack.",
                ru = "Если да, то рюкзаки из *несовместимых* модов будут экипироваться в слот для рюкзака.",
                zh = nil,
            },
        },
        AUTO_ARMOR = {
            LABEL = {
                en = "Autodetect armor",
                ru = "Автоопределение брони",
                zh = "自动侦测护甲",
            },
            DESCRIPTION = {
                en = "If yes, then armors from *incompatible* mods will be equipped to the slot for armor, but it may "
                  .. "still malfunction. Switch off if there are problems.",
                ru = "Если да, то броня из *несовместимых* модов будет экипироваться в слот для брони, но она всё ещё "
                  .. "может функционировать неправильно. Выключите, если возникают проблемы.",
                zh = nil,
            },
        },
        AUTO_DRESS = {
            LABEL = {
                en = "Autodetect dress",
                ru = "Автоопределение одежды",
                zh = "自动侦测服装",
            },
            DESCRIPTION = {
                en = "If yes, then dresses from *incompatible* mods will be equipped to the slot for dress, but it may "
                  .. "still malfunction. Switch off if there are problems.",
                ru = "Если да, то одежда из *несовместимых* модов будет экипироваться в слот для одежды, но она всё ещё "
                  .. "может функционировать неправильно. Выключите, если возникают проблемы.",
                zh = nil,
            },
        },
        AUTO_AMULET = {
            LABEL = {
                en = "Autodetect amulets",
                ru = "Автоопределение амулетов",
                zh = "自动侦测护符",
            },
            DESCRIPTION = {
                en = "If yes, then amulets from mods compatible with the mod \"Extra Equip Slots\" will be equipped to "
                  .. "the slot for amulet.",
                ru = "Если да, то амулеты из модов, совместимых с модом \"Extra Equip Slots\", будут экипироваться в "
                  .. "слот для амулета.",
                zh = nil,
            },
        },
    },
    NO = {
        en = "No",
        ru = "Нет",
        zh = "否",
    },
    YES = {
        en = "Yes",
        ru = "Да",
        zh = "是",
    },
}


-- Mod information --

name = tr(STRINGS.NAME)
version = "1.3.6"
author = "小叶子、AndreyMZ"
description = tr(STRINGS.DESCRIPTION) .. "\n\n" .. tr(STRINGS.VERSION) .. version

api_version = 10

-- This mod is both server and client.
all_clients_require_mod = true
client_only_mod = false

-- This mod is functional with Don't Starve Together only.
dont_starve_compatible = false
reign_of_giants_compatible = false
dst_compatible = true

-- Priority of which our mod will be loaded. A bigger value means earlie loading. Default: 0.
-- Should be less than the priorities of the mods:
--  * (2) Island Adventures
--  * (0) Item Auto-Fuel Slots
--  * (0) [DST] WhaRang
priority = -1

-- These tags allow the server running this mod to be found with filters from the server listing screen.
server_filter_tags = {"equip equipment slot body backpack armor dress amulet"}

icon_atlas = "images/modicon.xml"
icon = "modicon.tex"


-- Configuration options --

local function section(title)
    return {
        name = title,
        options = {{data = false, description = ""}},
        default = false,
    }
end

local slot_options_not_implemented = {
    {data = false       , description = tr(STRINGS.SLOT.ORIGINAL)},
}

local slot_options = {
    {data = false       , description = tr(STRINGS.SLOT.ORIGINAL)},
    {data = "extrabody1", description = tr(STRINGS.SLOT.EXTRA_1)},
    {data = "extrabody2", description = tr(STRINGS.SLOT.EXTRA_2)},
    {data = "extrabody3", description = tr(STRINGS.SLOT.EXTRA_3)},
}

configuration_options = {
    section(tr(STRINGS.CONFIG.SECTION_EQUIP)),
    {
        name = "slot_heavy",
        label = tr(STRINGS.CONFIG.HEAVY.LABEL),
        hover = tr(STRINGS.CONFIG.HEAVY.DESCRIPTION),
        default = false,
        options = slot_options_not_implemented,
    },
    {
        name = "slot_backpack",
        label = tr(STRINGS.CONFIG.BACKPACK.LABEL),
        hover = tr(STRINGS.CONFIG.BACKPACK.DESCRIPTION),
        default = false,
        options = slot_options_not_implemented,
    },
    {
        name = "slot_costume",
        label = tr(STRINGS.CONFIG.COSTUME.LABEL),
        hover = tr(STRINGS.CONFIG.COSTUME.DESCRIPTION),
        default = false,
        options = slot_options,
    },
    {
        name = "slot_armor",
        label = tr(STRINGS.CONFIG.ARMOR.LABEL),
        hover = tr(STRINGS.CONFIG.ARMOR.DESCRIPTION),
        default = false,
        options = slot_options,
    },
    {
        name = "slot_dress",
        label = tr(STRINGS.CONFIG.DRESS.LABEL),
        hover = tr(STRINGS.CONFIG.DRESS.DESCRIPTION),
        default = "extrabody2",
        options = slot_options,
    },
    {
        name = "slot_amulet",
        label = tr(STRINGS.CONFIG.AMULET.LABEL),
        hover = tr(STRINGS.CONFIG.AMULET.DESCRIPTION),
        default = "extrabody3",
        options = slot_options,
    },
    section(tr(STRINGS.CONFIG.SECTION_COMPATIBILITY)),
    {
        name = "config_render",
        label = tr(STRINGS.CONFIG.RENDER.LABEL),
        hover = tr(STRINGS.CONFIG.RENDER.DESCRIPTION),
        default = true,
        options = {
            {data = false, description = tr(STRINGS.NO)},
            {data = true,  description = tr(STRINGS.YES)},
        },
    },
    {
        name = "config_mannequin",
        label = tr(STRINGS.CONFIG.MANNEQUIN.LABEL),
        hover = tr(STRINGS.CONFIG.MANNEQUIN.DESCRIPTION),
        default = true,
        options = {
            {data = false, description = tr(STRINGS.NO)},
            {data = true,  description = tr(STRINGS.YES)},
        },
    },
    {
        name = "config_auto_backpack",
        label = tr(STRINGS.CONFIG.AUTO_BACKPACK.LABEL),
        hover = tr(STRINGS.CONFIG.AUTO_BACKPACK.DESCRIPTION),
        default = true,
        options = {
            {data = false, description = tr(STRINGS.NO)},
            {data = true,  description = tr(STRINGS.YES)},
        },
    },
    {
        name = "config_auto_armor",
        label = tr(STRINGS.CONFIG.AUTO_ARMOR.LABEL),
        hover = tr(STRINGS.CONFIG.AUTO_ARMOR.DESCRIPTION),
        default = false,
        options = {
            {data = false, description = tr(STRINGS.NO)},
            {data = true,  description = tr(STRINGS.YES)},
        },
    },
    {
        name = "config_auto_dress",
        label = tr(STRINGS.CONFIG.AUTO_DRESS.LABEL),
        hover = tr(STRINGS.CONFIG.AUTO_DRESS.DESCRIPTION),
        default = false,
        options = {
            {data = false, description = tr(STRINGS.NO)},
            {data = true,  description = tr(STRINGS.YES)},
        },
    },
    {
        name = "config_auto_amulet",
        label = tr(STRINGS.CONFIG.AUTO_AMULET.LABEL),
        hover = tr(STRINGS.CONFIG.AUTO_AMULET.DESCRIPTION),
        default = true,
        options = {
            {data = false, description = tr(STRINGS.NO)},
            {data = true,  description = tr(STRINGS.YES)},
        },
    },
}
