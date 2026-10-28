--[[
    MiniMap —— 更小、更紧凑的世界生成

    本模组的全部逻辑都放在 modworldgenmain.lua 里。

    原因：DST 在「世界生成」阶段只加载 modworldgenmain.lua，
    不会加载 modmain.lua（见 scripts/mods.lua 的 ModWrangler:LoadMods）。
    把世界生成钩子写在 modmain.lua 里会导致模组看起来加载成功，
    但生成世界时完全不生效。

    这个文件保留为空，方便以后添加 UI / RPC 之类的非世界生成内容。
]]
