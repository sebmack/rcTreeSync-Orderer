local LrDialogs = import 'LrDialogs'
local LrView = import 'LrView'
local LrFunctionContext = import 'LrFunctionContext'
local LrPrefs = import 'LrPrefs'
local LrBinding = import 'LrBinding'
local LrTasks = import "LrTasks"


LrFunctionContext.callWithContext('UI_context', function(context)
local selection = LrBinding.makePropertyTable(context)
local prefs = LrPrefs.prefsForPlugin()


-- Function to handle "Photo Sort Match All"
app:call(
    Call:new{
        name = 'Running photo matching.',
        async = true,
        guard = App.guardVocal,
        main = function(call)
            if not _PLUGIN.enabled then
                app:show{ warning="Plugin is disabled - must be enabled to publish..", call=call }
                call:cancel()
                return
            end

            local catalog = LrApplication.activeCatalog()
            prefs.collectionData = {}


            local function buildcollectionData(collectionSet, parentNode, currentPath)
                -- Traverse through all child collections in the collection set
                for _, collection in ipairs(collectionSet:getChildCollections()) do
                    local node = {
                        node = collection,
                        label = collection:getName(),
                        checked = false,
                        collapsed = false,  -- Start with all items collapsed
                        children = {},
                    }
                    local nextPath = currentPath .. "/" .. node.label
                    selection[nextPath] = selection[nextPath] or false
                    node.checked = selection[nextPath]
                    table.insert(parentNode.children, node)
                end
    
                -- Traverse through all child collection sets (subsets)
                for _, subSet in ipairs(collectionSet:getChildCollectionSets()) do
                    local node = {
                        node = subSet,
                        label = subSet:getName(),
                        checked = false,
                        collapsed = true,  -- Start with all items collapsed
                        children = {},
                    }
                    local nextPath = currentPath .. "/" .. node.label
                    selection[nextPath] = selection[nextPath] or false
                    node.checked = selection[nextPath]
                    table.insert(parentNode.children, node)
                    buildcollectionData(subSet, node, nextPath)
                end
            end
    
            local root = {
                node = nil,
                label = "All Select",
                checked = false,
                children = {}
            }
            selection[root.label] = selection[root.label] or false
            root.checked = selection[root.label]
            table.insert(prefs.collectionData, root)

            local normalCollections = catalog:getChildCollections()
            local normalCollectionSets = catalog:getChildCollectionSets()
            for _, collection  in ipairs(normalCollections) do
                local rootNode = {
                    node = collection,
                    label = collection:getName(),
                    checked = false,
                    children = {},
                }
                local collectionPath = root.label .. "/" .. rootNode.label
                selection[collectionPath] = selection[collectionPath] or false
                rootNode.checked = selection[collectionPath]
                table.insert(root.children, rootNode)
            end
            for _, collectionSet  in ipairs(normalCollectionSets) do
                local rootNode = {
                    node = collectionSet,
                    label = collectionSet:getName(),
                    checked = false,
                    children = {},
                }
                local collectionPath = root.label .. "/" .. rootNode.label
                selection[collectionPath] = selection[collectionPath] or false
                rootNode.checked = selection[collectionPath]
    
                buildcollectionData(collectionSet, rootNode, collectionPath)
                table.insert(root.children, rootNode)
            end

            local function checkAllParent(currentPath)
                if currentPath == root.label then
                    for _, node in ipairs(prefs.collectionData) do
                        node.checked = true
                        selection[node.label] = true
                        return node.children
                    end
                end

                local reversed_currentPath = string.reverse(currentPath)
                local start_pos, end_pos = string.find(reversed_currentPath, "/", 1, true)

                local length = #currentPath
                local substr = string.sub(reversed_currentPath, end_pos + 1)
                local label = string.sub(currentPath, length - start_pos + 2)
                local nodes = checkAllParent(string.reverse(substr))
                for _, node in ipairs(nodes) do
                    if node.label == label then
                        selection[currentPath] = true
                        node.checked = true
                        -- LrDialogs.message("label: ", node.label..", "..currentPath)
                        return node.children
                    end
                end
            end
            
            local function checkAllSubCollections(node, chk, currentPath)
                node.checked = chk
                selection[currentPath] = chk
                if node.children then
                    for _, childNode in ipairs(node.children) do
                        local nextPath = currentPath
                        if nextPath ~= "" then
                            nextPath = nextPath .. "/"
                        end
                        nextPath = nextPath .. childNode.label
                        checkAllSubCollections(childNode, chk, nextPath)
                    end
                end
            end
    
            
            local function renderTree(treeNodes, depth, currentPath)
                local uiElements = {}
    
                for _, node in ipairs(treeNodes) do
                    local nextPath = currentPath
                    if nextPath ~= "" then
                        nextPath = nextPath .. "/"
                    end
                    nextPath = nextPath .. node.label
                    -- LrDialogs.message(node.label, nextPath)
                    table.insert(uiElements, 
                        vf:row {
                            vf:static_text {
                                title = string.rep("      ", depth)
                            },
                            vf:push_button {
                                title = #node.children > 0 and "▼" or "▶",
                                width = 20,
                            },
                            vf:checkbox {
                                title = "",
                                value = LrView.bind(nextPath),  -- Bind checkbox to the state
                                -- value = node.checked,
                                action = function()
                                    local chk = not node.checked
                                    node.checked = chk
                                    -- LrDialogs.message(node.label, tostring(chk))
                                    checkAllSubCollections(node, chk, nextPath)
                                    checkAllParent(currentPath)
                                end,
                            },
                            vf:static_text {
                                title = node.label,
                                fill_horizontal = 1,
                            },
                        }
                    )
    
                    if #node.children > 0 then
                        local childElements = renderTree(node.children, depth + 1, nextPath)
                        for _, childElement in ipairs(childElements) do
                            table.insert(uiElements, childElement)
                        end
                    end
                end
    
                return uiElements
            end
    
    
            local function deepCopy(original)
                local copy = {}
                for k, v in pairs(original) do
                    if type(v) == 'table' then
                        copy[k] = deepCopy(v)
                    else
                        copy[k] = v
                    end
                end
                return copy
            end
            local treeview = renderTree(prefs.collectionData, 0, "")
            local contents = vf:column {
                bind_to_object = selection,
                vf:static_text {
                    title = "Select collection to sync.",
                    fill_horizontal = 1
                },
                vf:spacer {
                    height = 10  -- Additional spacer to increase size.
                },
                vf:scrolled_view {
                    width = 700,
                    height = 500,
                    vf:column(treeview),
                },
            }
            
            local dlg = LrDialogs.presentModalDialog {
                title = "Select collections to synchronize:",
                contents = contents,
            }
    
            if dlg == 'ok' then
                local photoMatch = true
                local autoOrder = true

                local summ, pubCollSet, sortedNotMatched = Common.syncPhotosBySelectedOption( call, true, false, selection )  -- collection syc

                local nUpd = tab:countItems( summ )
                local nCollToPub = tab:countItems( pubCollSet )
                local b = {}
                for srvName, stats in tab:sortedPairs( summ ) do
                    b[#b + 1] = str:fmtx( "* ^1 - ^2", srvName, stats )
                end
                
                local description
                if nCollToPub > 0 then
                    if nCollToPub == 1 then -- multiple collections to publish, but not too many (most publish services can not handle more than a dozen concurrently).
                        description = "Synchronized 1 collection"
                    else
                        description = str:fmtx("Synchronized ^1 collection", nCollToPub)
                    end
                else
                    description = "There are no new or modified collections to synchronize, but you can still opt to synchronize all (whether or not they're new or modified..)."
                end

                if call:isQuit() then return end

                local showcaseText = str:fmtx("^1\n\n\n^2", str:fmtx("^1 in ^2", description, str:plural( nUpd, "service", true )), table.concat( b, "\n" ))
                local updated = app:show{
                    confirm=showcaseText,
                    width = 700,
                    height = 400,
                    call = call,
                }
                app:log(table.concat( b, "\n" ))
                -- TreeSyncManager:removeMissingPhotos()
            end
        end
    }
)
end)  -- End of LrFunctionContext.callWithContext
-- LrDialogs.message("Photo Sort Match All", "Successfully run!")