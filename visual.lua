if not _G.charSelectExists then return end

local function on_character_change(prevChar, currChar)
	local m = gMarioStates[0]
	if prevChar == CT_X then
        m.marioBodyState.shadeR = gXStates[m.playerIndex].shading.r
        m.marioBodyState.shadeG = gXStates[m.playerIndex].shading.g
        m.marioBodyState.shadeB = gXStates[m.playerIndex].shading.b
    elseif currChar == CT_X then
        gXStates[m.playerIndex].shading = {
            r = m.marioBodyState.shadeR,
            g = m.marioBodyState.shadeG,
            b = m.marioBodyState.shadeB
        }
        m.marioBodyState.shadeR = 63
        m.marioBodyState.shadeG = 63
        m.marioBodyState.shadeB = 63
	end
end

local function on_character_select_load()
    _G.charSelect.hook_on_character_change(on_character_change)
end

hook_event(HOOK_ON_MODS_LOADED, on_character_select_load)