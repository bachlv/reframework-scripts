--[[
    RE9 Requiem - Mr. Raccoon Unlocker (WIP)
    REFramework Lua Script
]]

local gimmick_manager = sdk.get_managed_singleton("app.GimmickManager")
local fragile_symbol_place_id_type = sdk.find_type_definition("app.GmFragileSymbolPlaceID.Hash")

local function get_fragile_symbol_name(id)
    if not fragile_symbol_place_id_type then return "Unknown Location " .. tostring(id) end
    
    local fields = fragile_symbol_place_id_type:get_fields()
    for i, field in ipairs(fields) do
        if field:is_static() then
            local field_name = field:get_name()
            local ok, val = pcall(function() return field:get_data(nil) end)
            
            if ok and val ~= nil then
                if type(val) == "number" and val == id then
                    return field_name
                elseif type(val) == "userdata" and val.call then
                    local ok2, val2 = pcall(function() return val:call("asValue") end)
                    if ok2 and val2 == id then
                        return field_name
                    end
                end
            end
        end
    end
    return "Unknown Location " .. tostring(id)
end

local function shoot_all_raccoons()
    if not gimmick_manager then return end
    
    local save_datas = gimmick_manager:get_field("_GmFragileSymbolSaveDatas")
    if not save_datas then return end
    
    local count = save_datas:call("get_Count")
    if count == nil or count == 0 then return end
    
    for i = 0, count - 1 do
        local save_data = save_datas:call("get_Item", i)
        if save_data then
            save_data:set_field("_IsAchievement", true)
        end
    end
    
    local ach_mgr = sdk.get_managed_singleton("app.AchievementManager")
    if ach_mgr then
        ach_mgr:call("requestSystemSave", true)
    end
end

re.on_draw_ui(function()
    if imgui.tree_node("Mr. Raccoons Tracker") then
        if gimmick_manager then
            local save_datas = gimmick_manager:get_field("_GmFragileSymbolSaveDatas")
            
            if save_datas then
                local count = save_datas:call("get_Count")
                if count and count > 0 then
                    if imgui.button("Unlock All Raccoons") then
                        shoot_all_raccoons()
                    end
                    
                    imgui.text("Total Raccoons Tracker: " .. tostring(count))
                    imgui.separator()
                    
                    for i = 0, count - 1 do
                        local save_data = save_datas:call("get_Item", i)
                        if save_data then
                            local place_id = save_data:get_field("_PlaceID")
                            local is_achieved = save_data:get_field("_IsAchievement")
                            
                            local name = get_fragile_symbol_name(place_id)
                            local status = is_achieved and "[SHOT]" or "[NOT SHOT]"
                            local color = is_achieved and 0xFF00FF00 or 0xFF0000FF -- Green / Red
                            
                            imgui.text_colored(status .. " - " .. name, color)
                        end
                    end
                else
                    imgui.text("No Mr. Raccoons found in save data currently.")
                end
            else
                imgui.text("Failed to get SymbolSaveDatas list.")
            end
        else
            imgui.text_colored("GimmickManager not available.", 0xFF0000FF)
        end
        imgui.tree_pop()
    end
end)
