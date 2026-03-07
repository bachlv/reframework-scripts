--[[
    RE9 Requiem - Achievement Unlocker
    REFramework Lua Script
]]

local script_name = "RE9 Achievement Unlocker"

local achievements = {}
local status_msgs = {}
local global_msg = ""
local last_refresh = 0
local use_game_unlock = true

local function sget(obj, f)
    if not obj then return nil end
    local ok, v = pcall(function() return obj:get_field(f) end)
    return ok and v or nil
end

local function scall(obj, m, ...)
    if not obj then return nil end
    local a = { ... }
    local ok, v = pcall(function() return obj:call(m, table.unpack(a)) end)
    return ok and v or nil
end

local function toS(v)
    if v == nil then return "nil" end
    if type(v) ~= "userdata" then return tostring(v) end
    local ok, s = pcall(function() return v:call("ToString") end)
    return ok and s or tostring(v)
end

local function refresh()
    achievements = {}
    local mgr = sdk.get_managed_singleton("app.AchievementManager")
    if not mgr then
        global_msg = "AchievementManager not found - load a save first"
        return
    end

    local list = sget(mgr, "_ContextViewList")
    if not list then
        global_msg = "Achievement list not loaded yet"
        return
    end

    local count = scall(list, "get_Count") or 0
    for i = 0, count - 1 do
        local item = scall(list, "get_Item", i)
        if item then
            local data = sget(item, "_Data")
            table.insert(achievements, {
                idx = i,
                item = item,
                bonus_id = toS(scall(item, "get_BonusID")),
                ach_key = data and toS(scall(data, "get_AchievementID")) or "?",
                cp = data and (scall(data, "get_ClearPoint") or 0) or 0,
                done = sget(item, "_Completed") or false,
                got_cp = sget(item, "_ReceivedClearPoint") or false,
                progress = sget(item, "_ProgressCount") or 0,
                max_count = (data and scall(data, "get_MaxAchievedCount") or 0),
            })
        end
    end

    local tcp = sget(mgr, "_TotalClearPoint") or 0
    global_msg = #achievements .. " achievements loaded. Total CP: " .. toS(tcp)
    last_refresh = os.clock()
end

local function do_unlock(ach)
    local mgr = sdk.get_managed_singleton("app.AchievementManager")
    if not mgr then return "No manager" end

    local results = {}

    log.info("[Unlocker] Step 0: Clearing reject dict for #" .. ach.idx)
    local reject_dic = sget(mgr, "_ServiceRequestRejectContextDic")
    if reject_dic and ach.ach_key and ach.ach_key ~= "?" and ach.ach_key ~= "nil" then
        local data = sget(ach.item, "_Data")
        if data then
            local ach_key_val = sget(data, "_AchievementID")
            if ach_key_val then
                pcall(function() reject_dic:call("Remove", ach_key_val) end)
                pcall(function() reject_dic:call("Clear") end)
                table.insert(results, "reject:cleared")
            end
        end
    end

    if use_game_unlock then
        log.info("[Unlocker] Step 1: mgr:unlockAchievement for #" .. ach.idx)
        local ok1, r1 = pcall(function()
            return mgr:call("unlockAchievement", ach.item, false)
        end)
        if ok1 then
            table.insert(results, "steam:" .. toS(r1))
        else
            table.insert(results, "steam:FAIL")
        end

        log.info("[Unlocker] Step 1b: tryUnlockAchievementList")
        pcall(function()
            mgr:call("unlockAchievement", ach.item, true)
        end)
    end

    log.info("[Unlocker] Step 2: forceUnlock for #" .. ach.idx)
    local ok2 = pcall(function() ach.item:call("forceUnlock") end)
    table.insert(results, ok2 and "done:OK" or "done:FAIL")

    pcall(function() mgr:call("requestSystemSave", true) end)
    table.insert(results, "saved")

    log.info("[Unlocker] Done: " .. table.concat(results, " | "))
    return table.concat(results, " | ")
end


re.on_draw_ui(function()
    if imgui.tree_node(script_name) then
        if #achievements == 0 and os.clock() - last_refresh > 2 then
            refresh()
        end

        if imgui.button("Refresh") then refresh() end

        imgui.same_line()
        if #achievements > 0 and imgui.button("Unlock All Incomplete") then
            local n = 0
            for _, a in ipairs(achievements) do
                if not a.done then
                    status_msgs[a.idx] = do_unlock(a)
                    n = n + 1
                end
            end
            global_msg = "Unlocked " .. n .. " achievements"
            refresh()
        end



        imgui.same_line()
        local changed, new_val = imgui.checkbox("Try Steam unlock", use_game_unlock)
        if changed then use_game_unlock = new_val end

        if global_msg ~= "" then
            imgui.text_colored(global_msg, 0xFF44FF44)
        end
        imgui.separator()

        for _, a in ipairs(achievements) do
            local c = 0xFFFFFFFF
            if a.done and a.got_cp then
                c = 0xFF44FF44 -- green: done + CP collected
            elseif a.done then
                c = 0xFF44FFFF
            end -- cyan: done, CP not yet collected

            local line = string.format("%s #%-2d %-18s %-6s CP:%-6s %s/%s",
                a.done and "[DONE]" or "[    ]",
                a.idx, a.bonus_id, a.ach_key,
                tostring(a.cp), tostring(a.progress), tostring(a.max_count))

            imgui.text_colored(line, c)

            if not a.done then
                imgui.same_line()
                if imgui.button("Unlock##" .. a.idx) then
                    status_msgs[a.idx] = do_unlock(a)
                    refresh()
                end
            end

            if status_msgs[a.idx] then
                imgui.same_line()
                imgui.text_colored(" > " .. status_msgs[a.idx], 0xFFAAAAFF)
            end
        end

        imgui.tree_pop()
    end
end)

log.info("[" .. script_name .. "] Loaded.")
