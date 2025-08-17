local LrDialogs = import 'LrDialogs'
local LrView = import 'LrView'
local LrFunctionContext = import 'LrFunctionContext'
local LrPrefs = import 'LrPrefs'
local LrBinding = import 'LrBinding'
local LrTasks = import "LrTasks"


LrFunctionContext.callWithContext('UI_context', function(context)
local prefs = LrPrefs.prefsForPlugin()

-- Function to handle "Photo Sort Match This Tree"
app:call(
    Call:new{
        name = 'Running photo matching.',
        async = true,
        progress=true,
        guard = App.guardVocal,
        main = function(call)

            if not _PLUGIN.enabled then
                app:show{ warning="Plugin is disabled - must be enabled to publish..", call=call }
                call:cancel()
                return
            end


            local function publishing(pubCollSet)
                for c, tspSrv in pairs( pubCollSet ) do
                    local srvName = tspSrv:getName()
                    local collectionName = c:getName()
                    local publishSettings = tspSrv:getPublishSettings()["< contents >"] or nil

                    -- LrDialogs.message("publish collection name: ", tostring(collectionName).."  "..tostring(c))

                    local function getCollectionFullPath(collection)
                        if collection:getParent() == nil then
                            return collection:getName()
                        end
                        return getCollectionFullPath(collection:getParent()) .. "\\" .. collection:getName()
                    end
                    local destPath = publishSettings.destPath
                    local collectionFullPath = getCollectionFullPath(c)
                    local collectionId = c.localIdentifier

                    fprops:setPropertyForPlugin( nil, "collectionId", collectionId)
                    fprops:setPropertyForPlugin( nil, "missingOriginals", prefs.missingOriginals )
                    fprops:setPropertyForPlugin( nil, "destinationFolder", destPath .. "\\" .. collectionFullPath )
                   
                    -- LrDialogs.message(collectionName, "publishing now...")
                    local done
                    c:publishNow( function() -- reminder: this will NOT call process-rendered-photos method if nothing to export (even if something to delete), and even if ordering was done.
                        app:log( "^1 publishing finished - dunno whether successful or not.", collectionName )
                        done = true
                    end )

                    app:sleep( math.huge, 1, function( et )
                        return done
                    end )
                    if call:isQuit() then return end
                end
            end

            local catalog = LrApplication.activeCatalog()
            local PublishServices = catalog:getPublishServices(_PLUGIN.id)
            
            for i, src in ipairs( catalog:getActiveSources() ) do
                local srcName = cat:getSourceName( src )
                local srcType = cat:getSourceType( src )
                local collectionPath = collections:getFullCollPath( src, app:getPathSep() )
                local selection = {}

                local function markSelectedCollOrCollSet(collectionSet, currentPath)
                    for __, collection in ipairs(collectionSet:getChildCollections()) do
                        local fullPath = collection:getName()
                        if currentPath ~= "" then
                            fullPath = currentPath .. "/" .. fullPath
                        end
                        selection[fullPath] = true
                    end
                    for __, subSet in ipairs(collectionSet:getChildCollectionSets()) do
                        local fullPath = subSet:getName()
                        if currentPath ~= "" then
                            fullPath = currentPath .. "/" .. fullPath
                        end
                        selection[fullPath] = true
                        markSelectedCollOrCollSet(subSet, fullPath)
                    end
                end

                if srcType == 'LrPublishedCollection' or srcType == 'LrPublishedCollectionSet' then
                    local service = src:getService()
                    local serviceName = service:getName()

                    local index = 0
                    local addedPath = ""
                    for part in string.gmatch(collectionPath, "[^\\]+") do
                        if index == 1 then
                            addedPath = part
                        elseif index > 1 then
                            addedPath = addedPath .. "/" .. part
                        end
                        selection[addedPath] = true
                        index = index + 1
                    end

                    if srcType == "LrPublishedCollectionSet" then
                        markSelectedCollOrCollSet(src, addedPath)
                    end

                    local nErrors, colls, stats = Common.syncPhotosByCollection(call, service, selection)  -- collection syc

                    publishing(colls)
                    
                    local msg = "Succesfully synchronized and published!"
                    app:log(str:fmtx("^1: ^2", srcName, msg))
                    LrDialogs.message(srcName, msg)
                elseif srcType == 'LrCollection' or srcType == 'LrCollectionSet' then

                    local index = 0
                    local addedPath = ""
                    for part in string.gmatch(collectionPath, "[^\\]+") do
                        if index == 0 then
                            addedPath = part
                        else
                            addedPath = addedPath .. "/" .. part
                        end
                        selection[addedPath] = true
                        index = index + 1
                    end

                    if srcType == "LrCollectionSet" then
                        markSelectedCollOrCollSet(src, addedPath)
                    end

                    local summary, pubCollSet, sortedNotMatched = Common.syncNormalCollectionToPublishCollection(call, selection)  -- collection syc
                    
                    publishing(pubCollSet)

                    app:show{
                        info = "Sent for publishing."
                    }
                    app:log("Sent for publishing.")
                else
                    app:show{ info="You must select a collection, smart collection or collection set that is a Treesync source!", call=call }
                end
            end
            if call:isQuit() then return end
            -- TreeSyncManager:removeMissingPhotos()
        end
    }
)
end)
