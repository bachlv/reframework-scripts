--[[
    RE9 Requiem - Item Lister & Adder
    REFramework Lua Script
]]

local script_name = "RE9 Key Item Tool"

local item_list = {}
local item_list_initialized = false
local search_query = ""

local status_msg = ""
local status_color = 0xFFFFFFFF

local function build_localized_name_map(item_manager, get_message_method)
    local names_map = {}
    if not item_manager or not get_message_method then return names_map end

    local catalog = item_manager:get_field("_ItemCatalog")
    if not catalog then return names_map end

    local dict = catalog:get_field("_Dict")
    if not dict then return names_map end

    local entries = dict:get_field("_entries")
    if not entries then return names_map end

    local elements = entries:get_elements()
    if not elements then return names_map end

    for _, entry in ipairs(elements) do
        if entry then
            local key = entry:get_field("key")
            local val = entry:get_field("value")
            
            if key and val and type(val) == "userdata" and val.get_type_definition then
                local actual_detail = val:get_field("_Value") or val:get_field("Value")
                if actual_detail then
                    local nid = actual_detail:get_field("_NameMessageId")
                    if nid then
                        local ok_loc, loc_name = pcall(function() return get_message_method:call(nil, nid) end)
                        if ok_loc and loc_name and loc_name ~= "" then
                            local ok_kval, key_str = pcall(function() return key:call("ToString") end)
                            if ok_kval and key_str then
                                names_map[key_str] = loc_name
                            end
                        end
                    end
                end
            end
        end
    end
    
    return names_map
end

local function init_item_list()
    if item_list_initialized then return end

    local item_id_type = sdk.find_type_definition("app.ItemID")
    if not item_id_type then
        status_msg = "app.ItemID enumeration not found."
        status_color = 0xFF4444FF
        return
    end

    local item_manager = sdk.get_managed_singleton("app.ItemManager")
    local gui_message_type = sdk.find_type_definition("via.gui.message")
    local get_message_method = nil
    if gui_message_type then
        get_message_method = gui_message_type:get_method("get(System.Guid)") or gui_message_type:get_method("get")
    end

    local localized_names = build_localized_name_map(item_manager, get_message_method)

    local fields = item_id_type:get_fields()
    for _, field in ipairs(fields) do
        if field:is_static() then
            local name = field:get_name()
            if name ~= "value__" and name ~= "Count" then
                local ok, val = pcall(function() return field:get_data(nil) end)
                if ok and val ~= nil then
                    local display_name = name
                    if localized_names[name] then
                        display_name = string.format("%s (%s)", localized_names[name], name)
                    end
                    
                    table.insert(item_list, { name = display_name, id = val })
                end
            end
        end
    end

    table.sort(item_list, function(a, b)
        return a.name < b.name
    end)

    item_list_initialized = true
    status_msg = string.format("Loaded %d items.", #item_list)
    status_color = 0xFF44FF44
end

local function add_item_to_inventory(item_id, item_name)
    log.info(string.format("Attempting to add %s (ID: %s)", item_name, tostring(item_id)))
    
    local get_inv_method = sdk.find_type_definition("app.GuiUtil"):get_method("getInventory")
    local inv = get_inv_method and get_inv_method:call(nil)
    if not inv then
        status_msg = "Could not retrieve Inventory from GuiUtil!"
        status_color = 0xFF4444FF
        return
    end

    local acquire_opts = sdk.find_type_definition("app.Inventory.AcquireItemOptions"):get_field("Default"):get_data(nil)
    local stock_event = sdk.find_type_definition("app.ItemStockChangedEventType"):get_field("Default"):get_data(nil)
    local merge_method = inv:get_type_definition():get_method("mergeOrAdd(app.ItemAmountData, System.Boolean, app.Inventory.AcquireItemOptions, app.ItemStockChangedEventType)")

    if not merge_method then
        status_msg = "mergeOrAdd method not found!"
        status_color = 0xFF4444FF
        return
    end

    local item_data = sdk.create_instance("app.ItemStockData"):add_ref()
    local ctor_stock = item_data:get_type_definition():get_method(".ctor(app.ItemID, System.Int32)")
    if ctor_stock then
        ctor_stock:call(item_data, item_id, 1)
        
        local ok, result = pcall(function() 
            return merge_method:call(inv, item_data, true, acquire_opts, stock_event)
        end)
        
        if ok and result then
            log.info(string.format("Successfully added %s using ItemStockData.", item_name))
            status_msg = string.format("Added 1x %s!", item_name)
            status_color = 0xFF44FF44
            return
        end
    end

    local loadable_data = sdk.create_instance("app.LoadableItemData"):add_ref()
    local ctor_load = loadable_data:get_type_definition():get_method(".ctor(app.ItemID, System.Int32, app.ItemLoadingType)")
    if ctor_load then
        local loading_type = sdk.find_type_definition("app.ItemLoadingType"):get_field("TypeA"):get_data(nil)
        ctor_load:call(loadable_data, item_id, 1000, loading_type)
        
        local ok2, result2 = pcall(function() 
            return merge_method:call(inv, loadable_data, true, acquire_opts, stock_event)
        end)
        
        if ok2 and result2 then
            log.info(string.format("Successfully added %s using LoadableItemData.", item_name))
            status_msg = string.format("Added %s (Weapon/Loadable)!", item_name)
            status_color = 0xFF44FF44
            return
        end
    end

    log.info(string.format("Failed to add %s. Both ItemStockData and LoadableItemData returned false/nil.", item_name))
    status_msg = string.format("Failed to add %s (Inventory full?)", item_name)
    status_color = 0xFFFFFF44
end

re.on_draw_ui(function()
    if imgui.tree_node(script_name) then
        if not item_list_initialized then
            if imgui.button("Load Item Data") then
                init_item_list()
            end
        else
            imgui.text_colored(status_msg, status_color)
            imgui.spacing()

            local changed, new_query = imgui.input_text("Search", search_query)
            if changed then
                search_query = new_query:lower()
            end

            imgui.spacing()

            if imgui.begin_child_window("ItemListRegion", 0, 300, true, 0) then
                local ok, err = pcall(function()
                    for i, item in ipairs(item_list) do
                        local match = true
                        if search_query ~= "" then
                            match = item.name:lower():find(search_query, 1, true) ~= nil
                        end

                        if match then
                            imgui.push_id(i)

                            if imgui.button("Add") then
                                add_item_to_inventory(item.id, item.name)
                            end
                            imgui.same_line()
                            imgui.text(string.format("[%d] %s", i, item.name))

                            imgui.pop_id()
                        end
                    end
                end)

                if not ok then
                    imgui.text_colored("Render Loop Error: " .. tostring(err), 0xFF4444FF)
                end
                imgui.end_child_window()
            end
        end

        imgui.tree_pop()
    end
end)

log.info("[" .. script_name .. "] Loaded.")
