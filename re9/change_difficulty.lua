--[[
    RE9 Requiem - Change Save File Difficulty
    REFramework Lua Script

    Allows changing the active save file's difficulty at runtime.
    Saving the game at a typewriter afterwards makes it permanent.
]]
local script_name = "RE9 Difficulty Changer"

local DIFFICULTIES = {
    { id_str = "ID0010", label = "Casual" },
    { id_str = "ID0020", label = "Standard (Modern)" },
    { id_str = "ID0030", label = "Standard (Classic)" },
    { id_str = "ID0040", label = "Insanity" },
}

local status_msg = ""
local status_color = 0xFF44FF44

local function get_difficulty_manager()
    return sdk.get_managed_singleton("app.GameDifficultyManager")
end

local function get_difficulty_id_obj(id_str)
    local diff_type = sdk.find_type_definition("app.GameDifficultyID")
    if diff_type then
        local field = diff_type:get_field(id_str)
        if field then
            return field:get_data(nil)
        end
    end
    return nil
end

re.on_draw_ui(function()
    if imgui.tree_node(script_name) then
        local mgr = get_difficulty_manager()
        if not mgr then
            imgui.text_colored("GameDifficultyManager not found - Load a save first!", 0xFF4444FF)
            imgui.tree_pop()
            return
        end


        local current_diff_name = "Unknown"
        local ok, current_diff_obj = pcall(function() return mgr:get_field("_DifficultyID") end)
        if ok and current_diff_obj ~= nil then
            local ok_str, name = pcall(function() return current_diff_obj:call("ToString") end)
            if ok_str and name then
                current_diff_name = name
            end
        end

        local current_label = current_diff_name
        for _, diff in ipairs(DIFFICULTIES) do
            if diff.id_str == current_diff_name then
                current_label = diff.label .. " (" .. diff.id_str .. ")"
                break
            end
        end

        imgui.text("Current Difficulty: " .. current_label)
        imgui.spacing()
        imgui.separator()
        imgui.text("Change Save Difficulty To:")


        for _, diff in ipairs(DIFFICULTIES) do
            if imgui.button(diff.label) then
                local obj = get_difficulty_id_obj(diff.id_str)
                if obj then
                    local ok_set = pcall(function() mgr:set_field("_DifficultyID", obj) end)
                    pcall(function() mgr:call("set_DifficultyID", obj) end)
                    
                    if ok_set then
                        status_msg = "Difficulty successfully changed to " .. diff.label .. "!"
                        status_color = 0xFF44FF44
                    else
                        status_msg = "Failed to set difficulty! (set_field error)"
                        status_color = 0xFF4444FF
                    end
                else
                    status_msg = "Could not find difficulty object " .. diff.id_str .. " in memory!"
                    status_color = 0xFF4444FF
                end
            end
        end

        imgui.spacing()
        imgui.text_colored("IMPORTANT: Save your game manually to make this permanent!", 0xFF44FFFF)
        
        if status_msg ~= "" then
            imgui.spacing()
            imgui.text_colored(status_msg, status_color)
        end

        imgui.tree_pop()
    end
end)
