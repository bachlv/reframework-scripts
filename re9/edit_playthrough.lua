--[[
    RE9 Requiem - Playthrough Editor
    REFramework Lua Script
]]

local script_name = "RE9 Playthrough Editor"

local DIFFICULTIES = {
    { id = "ID0010", label = "Casual",             int_val = 0 },
    { id = "ID0020", label = "Standard (Modern)",  int_val = 1 },
    { id = "ID0030", label = "Standard (Classic)", int_val = 2 },
    { id = "ID0040", label = "Insanity",           int_val = 3 },
}

local clear_data = {}
local total_clear = 0
local game_clear = 0
local new_game = 0
local status_msg = ""
local status_color = 0xFF44FF44
local loaded = false

local time_inputs = {}

local function sget(obj, f)
    if not obj then return nil end
    local ok, v = pcall(function() return obj:get_field(f) end)
    return ok and v or nil
end

local function sset(obj, f, val)
    if not obj then return false end
    local ok = pcall(function() obj:set_field(f, val) end)
    return ok
end

local function toS(v)
    if v == nil then return "nil" end
    if type(v) ~= "userdata" then return tostring(v) end
    local ok, s = pcall(function() return v:call("ToString") end)
    return ok and s or tostring(v)
end

for _, d in ipairs(DIFFICULTIES) do
    time_inputs[d.id] = { h = 0, m = 0, s = 0 }
end

local count_inputs = { total = 0, game = 0, newgame = 0 }


local function secs_to_hms(total_secs)
    if total_secs < 0 then return 0, 0, 0 end
    local h = math.floor(total_secs / 3600)
    local m = math.floor((total_secs % 3600) / 60)
    local s = total_secs % 60
    return h, m, s
end

local function hms_to_secs(h, m, s)
    return h * 3600 + m * 60 + s
end

local function format_time(total_secs)
    if total_secs < 0 then return "-- Not Cleared --" end
    local h, m, s = secs_to_hms(total_secs)
    return string.format("%d:%02d'%02d\"", h, m, s)
end


local function refresh()
    clear_data = {}
    local mgr = sdk.get_managed_singleton("app.GameDataManager")
    if not mgr then
        status_msg = "GameDataManager not found - load a save first"
        status_color = 0xFF4444FF
        return
    end

    total_clear = sget(mgr, "_TotalClearCount") or 0
    game_clear = sget(mgr, "_GameClearCount") or 0
    new_game = sget(mgr, "_NewGameCount") or 0
    count_inputs.total = total_clear
    count_inputs.game = game_clear
    count_inputs.newgame = new_game

    local db = sget(mgr, "_BestTimeDB")
    if not db then
        status_msg = "_BestTimeDB not available"
        status_color = 0xFF4444FF
        return
    end

    local entries = sget(db, "_entries")
    local entry_count = sget(db, "_count") or 0

    for i = 0, tonumber(entry_count) - 1 do
        local entry = nil
        pcall(function() entry = entries:call("Get", i) end)
        if entry then
            local value = sget(entry, "value")
            if value then
                local diff_id = toS(sget(value, "<DifficultyID>k__BackingField"))
                local clear_time = sget(value, "<ClearTime>k__BackingField")
                local time_secs = tonumber(toS(clear_time)) or -1

                clear_data[diff_id] = {
                    obj = value,
                    time_secs = time_secs,
                }

                if time_secs >= 0 then
                    local h, m, s = secs_to_hms(time_secs)
                    time_inputs[diff_id] = { h = h, m = m, s = s }
                else
                    time_inputs[diff_id] = { h = 0, m = 0, s = 0 }
                end
            end
        end
    end

    loaded = true
    status_msg = "Data loaded successfully"
    status_color = 0xFF44FF44
end


local function set_clear_time(diff_id, time_secs)
    local entry = clear_data[diff_id]
    if not entry or not entry.obj then
        status_msg = "No entry for " .. diff_id
        status_color = 0xFF4444FF
        return false
    end

    local ok = sset(entry.obj, "<ClearTime>k__BackingField", time_secs)
    if ok then
        entry.time_secs = time_secs
        log.info("[PlayEditor] Set " .. diff_id .. " ClearTime=" .. time_secs)
        return true
    else
        status_msg = "Failed to set ClearTime for " .. diff_id
        status_color = 0xFF4444FF
        return false
    end
end


local function set_clear_counts(total, game, ng)
    local mgr = sdk.get_managed_singleton("app.GameDataManager")
    if not mgr then return false end

    sset(mgr, "_TotalClearCount", total)
    sset(mgr, "_GameClearCount", game)
    sset(mgr, "_NewGameCount", ng)

    total_clear = total
    game_clear = game
    new_game = ng
    log.info("[PlayEditor] Counts: total=" .. total .. " game=" .. game .. " newgame=" .. ng)
    return true
end


local function do_save()
    local mgr = sdk.get_managed_singleton("app.GameDataManager")
    if not mgr then
        status_msg = "Cannot save: no GameDataManager"
        status_color = 0xFF4444FF
        return
    end

    local ach_mgr = sdk.get_managed_singleton("app.AchievementManager")
    if ach_mgr then
        local ok = pcall(function() ach_mgr:call("requestSystemSave", true) end)
        if ok then
            status_msg = "Save requested via AchievementManager"
            status_color = 0xFF44FF44
            log.info("[PlayEditor] System save triggered")
            return
        end
    end

    status_msg = "Save request sent (verify in-game)"
    status_color = 0xFFFFFF44
end


re.on_draw_ui(function()
    if imgui.tree_node(script_name) then
        if not loaded then refresh() end

        if imgui.button("Refresh") then refresh() end

        if status_msg ~= "" then
            imgui.same_line()
            imgui.text_colored(status_msg, status_color)
        end

        imgui.spacing()
        imgui.separator()


        imgui.spacing()
        imgui.text_colored(">> Best Clear Times", 0xFFFFAA44)
        imgui.spacing()

        for _, d in ipairs(DIFFICULTIES) do
            local entry = clear_data[d.id]
            local current_time = entry and entry.time_secs or -1
            local is_cleared = current_time >= 0

            local indicator = is_cleared and "[CLEAR]" or "[     ]"
            local color = is_cleared and 0xFF44FF44 or 0xFF888888
            imgui.text_colored(string.format("%-7s %-20s %s", indicator, d.label, format_time(current_time)), color)

            local ti = time_inputs[d.id]
            imgui.push_id("time_" .. d.id)

            imgui.push_item_width(40)
            local ch, new_h = imgui.drag_int("h##" .. d.id, ti.h, 1, 0, 999)
            if ch then ti.h = new_h end
            imgui.same_line()
            local cm, new_m = imgui.drag_int("m##" .. d.id, ti.m, 1, 0, 59)
            if cm then ti.m = new_m end
            imgui.same_line()
            local cs, new_s = imgui.drag_int("s##" .. d.id, ti.s, 1, 0, 59)
            if cs then ti.s = new_s end
            imgui.pop_item_width()

            imgui.same_line()
            if imgui.button("Set##time_" .. d.id) then
                local new_secs = hms_to_secs(ti.h, ti.m, ti.s)
                if set_clear_time(d.id, new_secs) then
                    status_msg = d.label .. " = " .. format_time(new_secs)
                    status_color = 0xFF44FF44
                end
            end

            imgui.same_line()
            if imgui.button("Reset##time_" .. d.id) then
                if set_clear_time(d.id, -1) then
                    ti.h, ti.m, ti.s = 0, 0, 0
                    status_msg = d.label .. " reset to uncleared"
                    status_color = 0xFFFFFF44
                end
            end

            imgui.pop_id()
            imgui.spacing()
        end

        imgui.spacing()
        if imgui.button("Mark All Cleared (1:00'00\")") then
            local count = 0
            for _, d in ipairs(DIFFICULTIES) do
                local entry = clear_data[d.id]
                if entry and entry.time_secs < 0 then
                    if set_clear_time(d.id, 3600) then
                        time_inputs[d.id] = { h = 1, m = 0, s = 0 }
                        count = count + 1
                    end
                end
            end
            status_msg = "Marked " .. count .. " difficulties as cleared"
            status_color = 0xFF44FF44
        end

        imgui.same_line()
        if imgui.button("Reset All") then
            for _, d in ipairs(DIFFICULTIES) do
                set_clear_time(d.id, -1)
                time_inputs[d.id] = { h = 0, m = 0, s = 0 }
            end
            status_msg = "All clear times reset"
            status_color = 0xFFFFFF44
        end


        imgui.spacing()
        imgui.separator()
        imgui.spacing()
        imgui.text_colored(">> Clear Counts", 0xFFFFAA44)
        imgui.spacing()

        imgui.text("Current: Total=" .. total_clear .. "  Game=" .. game_clear .. "  NewGame=" .. new_game)
        imgui.spacing()

        imgui.push_item_width(120)
        local ct, new_total = imgui.drag_int("Total Clear Count", count_inputs.total, 1, 0, 100)
        if ct then count_inputs.total = new_total end

        local cg, new_game_val = imgui.drag_int("Game Clear Count", count_inputs.game, 1, 0, 100)
        if cg then count_inputs.game = new_game_val end

        local cn, new_ng = imgui.drag_int("New Game Count", count_inputs.newgame, 1, 0, 100)
        if cn then count_inputs.newgame = new_ng end
        imgui.pop_item_width()

        if imgui.button("Apply Counts") then
            if set_clear_counts(count_inputs.total, count_inputs.game, count_inputs.newgame) then
                status_msg = "Counts updated"
                status_color = 0xFF44FF44
            end
        end


        imgui.spacing()
        imgui.separator()
        imgui.spacing()

        if imgui.button(">> Save Changes <<") then
            do_save()
        end

        imgui.same_line()
        imgui.text_colored("Saves to system slot (persists across game restarts)", 0xFF888888)

        imgui.spacing()
        imgui.separator()
        imgui.spacing()
        imgui.text_colored("Changes take effect immediately in memory.", 0xFF888888)
        imgui.text_colored("Press Save to persist. Return to title screen to see updated results.", 0xFF888888)

        imgui.tree_pop()
    end
end)


log.info("[" .. script_name .. "] Loaded.")
