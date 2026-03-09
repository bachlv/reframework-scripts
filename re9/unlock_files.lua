--[[
    RE9 Requiem - File/Document Unlocker
    REFramework Lua Script
]]
local script_name = "RE9 File Unlocker"

local status_msg = ""
local status_color = 0xFF44FF44
local unlocked_count = 0

local function sget(obj, f)
    if not obj then return nil end
    local ok, v = pcall(function() return obj:get_field(f) end)
    return ok and v or nil
end

local function do_unlock_files()
    local mgr = sdk.get_managed_singleton("app.FileManager")
    if not mgr then
        status_msg = "FileManager not found. Load a save first!"
        status_color = 0xFF4444FF
        return
    end

    local user_type = sdk.find_type_definition("app.FileInventoryUser")
    local user_obj = nil
    if user_type then
        local common_field = user_type:get_field("Common")
        if common_field then user_obj = common_field:get_data(nil) end
    end

    local inv = nil
    if user_obj then
        local ok_inv, res = pcall(function() return mgr:call("getFileInventory", user_obj) end)
        if ok_inv and res then
            inv = res
        end
    end

    if not inv then
        status_msg = "Could not get FileInventory."
        status_color = 0xFF4444FF
        return
    end

    local file_id_type = sdk.find_type_definition("app.FileID")
    if not file_id_type then
        status_msg = "app.FileID enumeration not found."
        status_color = 0xFF4444FF
        return
    end

    local acquire_opt_type = sdk.find_type_definition("app.FileAcquireOptionBit")
    local acquire_opt_none = nil
    if acquire_opt_type then
        local none_field = acquire_opt_type:get_field("None")
        if none_field then acquire_opt_none = none_field:get_data(nil) end
    end

    local fields = file_id_type:get_fields()
    local count = 0

    for _, field in ipairs(fields) do
        if field:is_static() and field:get_name() ~= "Count" then
            local ok, file_id_obj = pcall(function() return field:get_data(nil) end)
            if ok and file_id_obj then
                pcall(function() inv:call("acquire", file_id_obj, acquire_opt_none) end)

                pcall(function()
                    local ctx = inv:call("getContext", file_id_obj)
                    if ctx then ctx:call("set_IsNew", false) end
                end)

                count = count + 1
            end
        end
    end

    local ach_mgr = sdk.get_managed_singleton("app.AchievementManager")
    if ach_mgr then
        pcall(function() ach_mgr:call("requestSystemSave", true) end)
    end

    unlocked_count = count
    status_msg = string.format("Acquired %d files! (System Save Requested)", count)
    status_color = 0xFF44FF44
end

re.on_draw_ui(function()
    if imgui.tree_node(script_name) then
        imgui.text("Instantly unlocks all readable files/documents in the game.")
        imgui.text_colored("Warning: May contain spoilers for files you haven't found!", 0xFF44FFFF)
        imgui.spacing()

        if imgui.button("Unlock All Files") then
            do_unlock_files()
        end

        if status_msg ~= "" then
            imgui.spacing()
            imgui.text_colored(status_msg, status_color)
        end

        imgui.tree_pop()
    end
end)

log.info("[" .. script_name .. "] Loaded.")
