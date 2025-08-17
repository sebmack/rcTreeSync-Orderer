--[[
        TreeSyncManager.lua
--]]


local TreeSyncManager, dbg, dbgf = Manager:newClass{ className='TreeSyncManager' }
local LrView = import 'LrView'
local LrDialogs = import 'LrDialogs'
local LrFunctionContext = import 'LrFunctionContext'
local LrPrefs = import 'LrPrefs'
local LrBinding = import 'LrBinding'
local LrTasks = import "LrTasks"
local LrExportSession = import 'LrExportSession'
local LrStringUtils = import 'LrStringUtils'

-- local PassableCollectionInfo = import 'PassableCollectionInfo'


-- LrFunctionContext.callWithContext('UI_context', function(context)
-- local boundDataSource = LrBinding.makePropertyTable(context)
-- local prefs = LrPrefs.prefsForPlugin()
-- prefs.manualOverridePath = prefs.manualOverridePath or Lightroom:computeActivePresetDir()
-- prefs.suppressNonFinalDialogs = prefs.suppressNonFinalDialogs or false
-- boundDataSource.manualOverridePath = prefs.manualOverridePath
-- boundDataSource.suppressNonFinalDialogs=prefs.suppressNonFinalDialogs


LrFunctionContext.callWithContext('UI_context', function(context)
local boundDataSource = LrBinding.makePropertyTable(context)
local prefs = LrPrefs.prefsForPlugin()
prefs.manualOverridePath = prefs.manualOverridePath or Lightroom:computeActivePresetDir()
prefs.suppressNonFinalDialogs = prefs.suppressNonFinalDialogs or false
prefs.missingOriginals = prefs.missingOriginals or "Prompt"                     -- new feature
prefs.showSelectiveDlg = prefs.showSelectiveDlg or false                     -- new feature
prefs.selectivePublication = prefs.selectivePublication or false                     -- new feature
prefs.previewPhoto = prefs.previewPhoto or {}                     -- new feature
prefs.doOp = prefs.doOp or "match"                    -- new feature
boundDataSource.manualOverridePath = prefs.manualOverridePath
boundDataSource.suppressNonFinalDialogs=prefs.suppressNonFinalDialogs
boundDataSource.missingOriginals=prefs.missingOriginals                         -- new feature
boundDataSource.showSelectiveDlg=prefs.showSelectiveDlg                         -- new feature
boundDataSource.selectivePublication=prefs.selectivePublication                         -- new feature
boundDataSource.previewPhoto=prefs.previewPhoto                         -- new feature
boundDataSource.doOp=prefs.doOp                         -- new feature



if prefs.publishCollectionData == nil then
    prefs.publishCollectionData = {}  -- Default value
end
boundDataSource.publishCollectionData=prefs.publishCollectionData






--[[
        Constructor for extending class.
--]]
function TreeSyncManager:newClass( t )
    return Manager.newClass( self, t )
end



--[[
        Constructor for new instance object.
--]]
function TreeSyncManager:new( t )
    return Manager.new( self, t )
end



--- Static function to initialize plugin preferences (not framework preferences) - both global and non-global.
--[[ this until 13/May/2013 22:25:
function TreeSyncManager.initPrefs()
    -- I N I T   G L O B A L   P R E F S
    -- Instructions: uncomment to support these external apps in global prefs, otherwise delete:
    -- app:initGlobalPref( 'exifToolApp', "" )
    -- app:initGlobalPref( 'mogrifyApp', "" )
    -- app:initGlobalPref( 'sqliteApp', "" )
    -- I N I T   L O C A L   P R E F S
    -- Instructions: uncomment to support these external apps in global prefs, otherwise delete:
    -- app:initPref( 'exifToolApp', "" )
    -- app:initPref( 'mogrifyApp', "" )
    -- app:initPref( 'sqliteApp', "" )
    -- *** Instructions: delete this line if no async init or continued background processing:
    -- app:initPref( 'background', false ) -- true to support on-going background processing, after async init (auto-update most-sel photo).
    -- *** Instructions: delete these 3 if not using them:
    --app:initPref( 'processTargetPhotosInBackground', false )
    --app:initPref( 'processFilmstripPhotosInBackground', false )
    --app:initPref( 'processAllPhotosInBackground', false )
    -- I N I T   B A S E   P R E F S
    Manager.initPrefs()
end
--]]



-- @13/May/2013 22:26, this:
--- Initialize global preferences.
--
function TreeSyncManager:_initGlobalPrefs()
    -- Instructions: delete the following line (or set property to nil) if this isn't an export plugin.
    
    -- this is the primary motivator for the change: (tree-sync as exporter was not compatible with export-manager management: oops).
    fprops:setPropertyForPlugin( _PLUGIN, 'exportMgmtVer', "2" ) -- a little add-on here to support export management. '1' is legacy (rc-common-modules) mgmt.
    
    -- Instructions: uncomment to support these external apps in global prefs, otherwise delete:
    -- app:initGlobalPref( 'exifToolApp', "" )
    -- app:initGlobalPref( 'mogrifyApp', "" )
    -- app:initGlobalPref( 'sqliteApp', "" )
    Manager._initGlobalPrefs( self )
end



--- Initialize local preferences for preset.
--
function TreeSyncManager:_initPrefs( presetName )
    -- Instructions: uncomment to support these external apps in global prefs, otherwise delete:
    -- app:initPref( 'exifToolApp', "", presetName )
    -- app:initPref( 'mogrifyApp', "", presetName )
    -- app:initPref( 'sqliteApp', "", presetName )
    -- *** Instructions: delete this line if no async init or continued background processing:
    --app:initPref( 'background', false, presetName ) -- true to support on-going background processing, after async init (auto-update most-sel photo).
    -- *** Instructions: delete these 3 if not using them:
    --app:initPref( 'processTargetPhotosInBackground', false, presetName )
    --app:initPref( 'processFilmstripPhotosInBackground', false, presetName )
    --app:initPref( 'processAllPhotosInBackground', false, presetName )
    Manager._initPrefs( self, presetName )
end



--- Start of plugin manager dialog.
-- 
function TreeSyncManager:startDialogMethod( props )
    Manager.startDialogMethod( self, props )
end



--- Preference change handler.
--
--  @usage      Handles preference changes.
--              <br>Preferences not handled are forwarded to base class handler.
--  @usage      Handles changes that occur for any reason, one of which is user entered value when property bound to preference,
--              <br>another is preference set programmatically - recursion guarding is essential.
--
function TreeSyncManager:prefChangeHandlerMethod( _id, _prefs, key, value )
    Manager.prefChangeHandlerMethod( self, _id, _prefs, key, value )
end



--- Property change handler.
--
--  @usage      Properties handled by this method, are either temporary, or
--              should be tied to named setting preferences.
--
function TreeSyncManager:propChangeHandlerMethod( props, name, value, call )
    if app.prefMgr and (app:getPref( name ) == value) then -- eliminate redundent calls.
        -- Note: in managed cased, raw-pref-key is always different than name.
        -- Note: if preferences are not managed, then depending on binding,
        -- app-get-pref may equal value immediately even before calling this method, in which case
        -- we must fall through to process changes.
        return
    end
    -- *** Instructions: strip this if not using background processing:
    if name == 'background' then
        app:setPref( 'background', value )
        if value then
            local started = background:start()
            if started then
                app:show( "Auto-check started." )
            else
                app:show( "Auto-check already started." )
            end
        elseif value ~= nil then
            app:call( Call:new{ name = 'Stop Background Task', async=true, guard=App.guardVocal, main=function( call )
                local stopped
                repeat
                    stopped = background:stop( 10 ) -- give it some seconds.
                    if stopped then
                        app:logV( "Auto-check was stopped by user." )
                        app:show( "Auto-check is stopped." ) -- visible status wshould be sufficient.
                    else
                        if dialog:isOk( "Auto-check stoppage not confirmed - try again? (auto-check should have stopped - please report problem; if you cant get it to stop, try reloading plugin)" ) then
                            -- ok
                        else
                            break
                        end
                    end
                until stopped
            end } )
        end
    else
        -- Note: preference key is different than name.
        Manager.propChangeHandlerMethod( self, props, name, value, call )
    end
end



--- Sections for bottom of plugin manager dialog.
-- 


function TreeSyncManager:sectionsForBottomOfDialogMethod( vf, props)

    local appSection = {}
    appSection.bind_to_object = props
    
	appSection.title = app:getAppName() .. " Settings"
	appSection.synopsis = bind{ key='presetName', object=prefs }

	appSection.spacing = vf:label_spacing()
    

function TreeSyncManager:copyToClipboard(text)

    local sanitizedText = text:gsub("\n", "\\n"):gsub("\"", "\\\"")

    local handle = io.popen("dir 2>nul")
    local result = handle:read("*a")
    handle:close()
    local isWindows = result and result:find("Volume") ~= nil
    -- -- Debug message to confirm platform detection
    if isWindows then
        LrTasks.execute( "echo " .. sanitizedText .. " | clip" )
    else
        handle = io.popen("uname")
        result = handle:read("*a")
        handle:close()

        -- Clean up result
        result = result and result:match("^%s*(.-)%s*$")  -- Trim whitespace
        if result == "Linux" then
            LrTasks.execute( "echo " .. sanitizedText .. " | xclip -selection clipboard" )
        elseif result == "Darwin" then
            LrTasks.execute( "echo " .. sanitizedText .. " | pbcopy" )
        else
            LrTasks.execute( "echo " .. sanitizedText .. " | clip" )
        end
    end
end


function TreeSyncManager:removeMissingPhotos()
    local LrFunctionContext = import 'LrFunctionContext'
    local LrApplication = import 'LrApplication'
    local catalog = LrApplication.activeCatalog()
    local PublishServices = catalog:getPublishServices(_PLUGIN.id)
    local deletedCnt = 0;

    for _, publishService in ipairs(PublishServices) do
        local publishSettings = publishService:getPublishSettings()
        local es = publishSettings["< contents >"] or error( "where's the pub-srv settings?" )

        local function photoMatching(collectionSet, parentPath)
            local addPath = "All Select" .. "/" .. publishService:getName()
            if parentPath ~= "" then
                addPath = addPath .. "/" .. string.sub(parentPath, 2)
            end
            if not boundDataSource[addPath] then
                return
            end

            for _, collection in ipairs(collectionSet:getChildCollections()) do
                local collectionName = collection:getName()
                
                local currentPath = parentPath .. "\\" .. collectionName
                local destinationPath = es.destPath..currentPath

                local photos = collection:getPhotos()
                local colType = collection:isSmartCollection()
                local checked = addPath .. "/" .. collectionName
                
                if not colType and boundDataSource[checked] then
                    for _, photo in ipairs(photos) do
                        local photoName = photo:getFormattedMetadata("fileName")
                        local sourcePath = photo:getRawMetadata("path")
                        -- LrDialogs.message("photo: ", "name:  "..tostring(photoName).."\npath:   "..sourcePath)
                        local missing = LrFileUtils.exists(sourcePath)
                        
                        if not missing then
                            -- LrDialogs.message("photo: ", "name:  "..tostring(photoName).."\npath:   "..currentPath.."\nmissing:   "..tostring(missing))
                            local fullPath = destinationPath .. "\\" .. photoName
                            -- LrDialogs.message("full path: ", fullPath)
                            app:log( photoName.." is missed from "..sourcePath )
                            local notFoundInDestinationFolder = LrFileUtils.exists(fullPath)
                            if not notFoundInDestinationFolder then
                                catalog:withWriteAccessDo("Remove Photos from Collection", function()
                                    collection:removePhotos({photo})
                                end)
                                deletedCnt = deletedCnt + 1
                                app:log( "missing photo "..photoName.." is removed from "..collectionName )
                            end
                        end
                    end
                end
            end
            for __, subSet in ipairs(collectionSet:getChildCollectionSets()) do
                photoMatching(subSet, parentPath.."\\"..subSet:getName())
            end
        end
        photoMatching(publishService, "")
    end

   return deletedCnt
end

 -- Row bound to boundDataSource
local manualOverrideRow = vf:row {
    vf:static_text {
        title = "Preset Folder Override:",
        width = 120
    },
    vf:edit_field {
        value = LrView.bind("manualOverridePath"),
        -- tooltip = "Only over-ride this if presets are not working",
        width_in_chars = 25,
        enabled=false,
    },
    vf:push_button {
        title = "Copy to clipboard",  -- Small icon or info button
        tooltip = LrView.bind("manualOverridePath"),
        width = 100,
        action = function()
            local path = tostring(prefs.manualOverridePath)
            TreeSyncManager:copyToClipboard(path)
        end,
    },
    vf:push_button {
        title = "Update",
        action = function(button)
            LrDialogs.message("Debug: manualOverridePath", tostring(prefs.manualOverridePath))
            local newPath = LrDialogs.runOpenPanel({
                title = "Select Preset Folder", 
                canChooseFiles = false, 
                canChooseDirectories = true, 
                allowsMultipleSelection = false
            })
            if newPath and #newPath > 0 then
                tostring(newPath)
                prefs.manualOverridePath = newPath[1]
                boundDataSource.manualOverridePath = newPath[1]
            end
        end,
    },
    vf:push_button {
        title = "Automate",
        tooltip = "Automate the finding of the preset folder",
        action = function(button)
            prefs.manualOverridePath = nil
            boundDataSource.manualOverridePath = nil
            LrDialogs.message("Debug: manualOverridePath", tostring(prefs.manualOverridePath))
            Lightroom:computeActivePresetDir()
            LrDialogs.message("Debug: manualOverridePath after compute", tostring(prefs.manualOverridePath))
            boundDataSource.manualOverridePath = prefs.manualOverridePath
        end,
    },
}
manualOverrideRow.bind_to_object = boundDataSource

appSection[#appSection + 1] = manualOverrideRow



local suppressNonFinalDialogsRow = vf:row {
    vf:static_text {
        title = "Hide Prompts Between Collection Sets:",
        tooltip = "Treesync will usually show a log prompt after every collection set. Bypass it and only view the final one here",
    },
    vf:checkbox {
        title = "Enable",
        value = LrView.bind('suppressNonFinalDialogs'),
    },
}
suppressNonFinalDialogsRow.bind_to_object = boundDataSource
appSection[#appSection + 1] = suppressNonFinalDialogsRow
boundDataSource:addObserver('suppressNonFinalDialogs', function(propertyTable, key, newValue)
    if newValue then
        -- Checkbox was checked
        prefs.suppressNonFinalDialogs = newValue

    else
        -- Checkbox was unchecked
        prefs.suppressNonFinalDialogs = boundDataSource.suppressNonFinalDialogs

    end
end)


-- This part is adding by me

local missingOriginalsRow = vf:row {
    vf:static_text {
        title = "Ignore && Log Missing Originals",
        tooltip = "To allow rapid publication, ignore prompts - see log to fix problems after a TSP",
    },
    vf:radio_button {
        title = "All",
        value = LrView.bind('missingOriginals'),
        checked_value="All",
    },
    -- vf:radio_button {
    --     title = "Where a published copy exists",
    --     value = LrView.bind('missingOriginals'),
    --     checked_value="CopyExists",
    -- },
    vf:radio_button {
        title = "Prompt",
        value = LrView.bind('missingOriginals'),
        checked_value="Prompt",
    }
}
missingOriginalsRow.bind_to_object = boundDataSource
appSection[#appSection + 1] = missingOriginalsRow
    
boundDataSource:addObserver('missingOriginals', function(propertyTable, key, newValue)
    if newValue then
        prefs.missingOriginals = newValue
    else
        prefs.missingOriginals = boundDataSource.missingOriginals
    end
end)


-- The end!
    
    appSection[#appSection + 1] =
        vf:row {
            vf:push_button {
                title = "Mark As Published",
                tooltip = "Selected photos must be 'New Photos to Publish', *not* already published...",
                width = share 'buttonWidth',
                action = function( button )
                    local tsp = TreeSyncPublish:newDialog()
                    tsp:maintRun( true )
                end,
            },
            vf:static_text {
                title = "Mark selected photos as published, and assign correct published info...",
            },
        }

    appSection[#appSection + 1] =
        vf:row {
            vf:push_button {
                title = "Maintain Published Photos",
                tooltip = "Avoid the requirement to republish photos when all that is necessary is to shoe-horn in some new info...",
                width = share 'buttonWidth',
                action = function( button )
                    local tsp = TreeSyncPublish:newDialog()
                    tsp:maintRun( false )
                end,
            },
            vf:static_text {
                title = "Recompute new info for published photos, for when some info has changed...",
            },
        }

	appSection[#appSection + 1] = 
		vf:row {
			vf:push_button {
				title = "Detect Publish Anomalies",
                width = share 'buttonWidth',
				tooltip = "Scrutinizes published photos plugin-wide to check for bad IDs and duplicates.",
				action = function( button )
                    app:service{ name=button.title, async=true, progress=true, guard=App.guardVocal, main=function( call )
                        call.nDup = 0
                        call.nRep = 0
                        local pubSrvs = PublishServices:new()
                        app:pcall{ name="Initialize Publish Services (for detecting publish anomalies)", progress={ modal=true }, function( icall )
                            pubSrvs:init( icall, _PLUGIN.id ) -- init pub-info for this plugin only.
                        end }
                        -- local pubPhotos = pubSrvs:getPublishedPhotos() -- get published photos (by default, this plugin only).
                        -- reminder: this method is deprecated, since it bypasses init info.
                        local pubPhotoInfo, pubPhotoCount = pubSrvs:getPubPhotoInfo() -- get info about published photos.
                        local ids = {}
                        local dups = {}
                        local repub = {}
                        local lookup = {}
                        if pubPhotoCount > 0 then
                            local btn = app:show{ confirm="Check all published photos in ^1's pervue, and mark anomalous photos for republishing.\n\nClick 'OK' to begin, or 'Cancel' to abort.",--\n \n*** Disclaimer: only works for normal trees, not flat.",
                                subs = { app:getAppName() },
                                buttons = { dia:btn( "OK", 'ok' ), dia:btn( "Cancel", 'cancel' ) },
                                call = call,
                            }
                            if btn == 'cancel' then
                                call:cancel()
                                return
                            end
                            -- note: since this is just checking for dups, and bad ID *format*, it works for uploaded (and deleted) photos as well.
                            --for i, pubPhoto in ipairs( pubPhotos ) do
                            local i = 0
                            for pubPhoto, info in pairs( pubPhotoInfo ) do
                                i = i + 1
                                --local info = pubSrvs:getInfoForPubPhoto( pubPhoto ) or error( "no pubsrv info tbl" ) -- srvInfo & pubColl
                                local id = pubPhoto:getRemoteId()
                                if id ~= nil then
                                    -- note: pub-photo does not have a coll/srv tied to it, so one has to build entire structure to determin associated service and hence settings.
                                    local srvInfo = info.srvInfo or error( "no pub-srv info" ) -- { srv=srv, pluginId=pluginId, pubColls={}, pubPhotos={} }                                    
                                    local srv = srvInfo.srv or error( "no srv in pub-srv info" )
                                    local settings = srv:getPublishSettings()['< contents >'] -- assume if srv-info has srv that it's a legitimate srv (will return pub-settings).
                                    assert( settings, "no settings" )
                                    if settings.destTreeType == nil then -- pub service hasn't been saved since upgrade.
                                        app:logW( "Publish service settings for '^1' need to be re-saved, processing aborted.", srv:getName() )
                                        return
                                    -- else great
                                    end
                                    local destPath, msg = Common.getDestPathFromPublishedId( id, settings )
                                    if destPath then
                                        local exists = LrFileUtils.exists( destPath )
                                        if exists == nil then -- not on local host
                                            -- 29/Jun/2014 19:56 - I have no idea what I meant by the following comment - maybe because there was the
                                            -- ftp upload w/ delete-after-upload feature. But that feature was removed, so this is being changed to an anomaly:
                                            
                                            -- because implementation is p.s. agnostic, absence on local host is not considered an anomaly worthy of a warning
                                            --  - user can check log file. ###3 - possible improvement??
                                            --app:log( "Not on local host: ^1", destPath ) - pre 29/Jun/2014 19:58
                                            
                                            app:logW( "Not on local host: ^1", destPath ) -- post 29/Jun/2014 19:58
                                            repub[#repub + 1] = pubPhoto -- Seems if not on local host, the anomaly should be corrected by republishing (or removal..).
                                            
                                        elseif exists == 'file' then
                                            app:logV( "Present on local host: ^1", destPath )
                                        elseif exists == 'directory' then
                                            app:logW( "*** '^1' is a directory, not a file - hmm...", destPath )
                                            repub[#repub + 1] = pubPhoto -- Raise attention to f'd up pub-photo.
                                        else
                                            app:logE( "Not sure if directory entry exists or not: ^1", destPath )
                                            repub[#repub + 1] = pubPhoto -- Raise attention to f'd up pub-photo.
                                        end
                                        if lookup[destPath] then
                                            dups[lookup[destPath]] = true
                                            dups[pubPhoto] = true
                                        else
                                            lookup[destPath] = pubPhoto
                                        end
                                    else
                                        app:logV( "Published id of ^1 is not OK - ^2.", pubPhoto:getPhoto():getRawMetadata( 'path' ), msg )
                                        repub[#repub + 1] = pubPhoto
                                    end
                                else
                                    app:logV( "Published id of ^1 is missing - its being marked for republish.", pubPhoto:getPhoto():getRawMetadata( 'path' ) )
                                    repub[#repub + 1] = pubPhoto
                                end
                                if call:isQuit() then
                                    return
                                else
                                    call:setPortionComplete( i, pubPhotoCount )
                                end
                            end
                            local cnt = tab:countItems( dups )
                            if cnt > 0 or #repub > 0 then
                                local ok = dia:isOk( "Mark for re-publishing (^1) - the purpose is to isolate them so you can deal with them - maybe republish, or maybe remove from publishing collection...?", str:plural( cnt + #repub, "anomalous photo" ) )
                                if not ok then
                                    call:cancel()
                                    return
                                end
                                call:setCaption( "Working - please wait..." )
                                -- commented out 16/Sep/2014 22:35 - local s, m = cat:withRetries( 20, catalog.withWriteAccessDo, call.name, function( context ) -- should be ported to cat:update, but *shouldn't* be too many dups or repubs?
                                local s, m = cat:update( 20, call.name, function( context, phase ) -- added 16/Sep/2014 22:36.. - tested: OK.
                                    for pubPhoto, _ in pairs( dups ) do
                                        call.nDup = call.nDup + 1
                                        -- @13/May/2012 23:05 These two lines were commented out, but I'm not sure why - seems there needs to be
                                        -- some way to call attention to photos that have resulted in duplicate destinations, one or the other needs to be republished,
                                        -- but which? ###4
                                        app:log( "Duplicate published photo (^1) being marked for republishing, id: ^2", pubPhoto:getPhoto():getRawMetadata( 'path' ), pubPhoto:getRemoteId() )
                                        pubPhoto:setEditedFlag( true ) -- remark for republish (remove photo from published photos).
                                        -- pubPhoto:setRemoteId( LrUUID.generateUUID() ) -- *don't* do this, or else neither photo can be deleted.
                                        if call:isQuit() then
                                            return
                                        else
                                            call:setPortionComplete( call.nDup, cnt )
                                        end
                                    end
                                    for i, pubPhoto in ipairs( repub ) do -- bad ID
                                        call.nRep = call.nRep + 1
                                        app:log( "Published photo (^1) with bad ID being marked for republishing, id: ^2", pubPhoto:getPhoto():getRawMetadata( 'path' ), pubPhoto:getRemoteId() )
                                        pubPhoto:setEditedFlag( true ) -- remark for republish (remove photo from published photos).
                                        pubPhoto:setRemoteId( LrUUID.generateUUID() ) -- set to unique but invalid value: photos must either be re-published, or "maintained".
                                        if call:isQuit() then
                                            return
                                        else
                                            call:setPortionComplete( i, #repub )
                                        end
                                    end
                                end )
                                if s then
                                    -- pass
                                else
                                    app:error( m )
                                end
                            else
                                app:show{ info="No anomalies.", call=call }
                            end
                        else                                
                            app:show{ info="No published photos, yet.", call=call }
                        end
                    end, finale=function( call, status, message )
                        if status then
                            app:log( "^1 duplicates unmarked as published.", str:plural( call.nDup, "photo", true ) )
                            app:log( "^1 republished due to invalid ID.", str:plural( call.nRep, "photo", true ) )
                        else
                            -- no-op
                        end
                    end }
                    
				end
			},
			vf:static_text {
				title = str:format( "Detect bad and/or duplicate published photos - and mark for republishing." ),
			},
		}
        

    appSection[#appSection + 1] =
        vf:row {
            vf:push_button {
                title = "Delete Extraneous Files", -- this could be enhanced to work for remotely published extraneous files too, but user has remote sync for that.
                tooltip = "If destination photo has no counter-part in source, it will be deleted, subject to pre-approval - of course.",
                width = share 'buttonWidth',
                action = function( button )
                    app:service{ name=button.title, async=true, progress=true, guard=App.guardVocal, main=function( call )
                        call.stats = {
                            nSubject = 0,
                            nDeleted = 0,
                        }
                        local destRoot
                        local pubColls = {}
                        local pubSrvs = {}
                        local photoSet = {}
                        for i, src in ipairs( catalog:getActiveSources() ) do
                            local srcType = cat:getSourceType( src )
                            if srcType == 'LrPublishedCollection' then
                                local pubSrv = src:getService()
                                if pubSrv:getPluginId() == _PLUGIN.id then
                                    pubColls[#pubColls + 1] = src
                                    local photos = src:getPhotos()
                                    local set = tab:createSet( photos )
                                    tab:addToSet( photoSet, set )
                                    pubSrvs[pubSrv] = true
                                end
                            end
                        end
                        if #pubColls == 0 then
                            app:show{ warning="No '^1' published collections are selected.", app:getPluginName() }
                            call:cancel()
                            return
                        end
                        local exts = {}
                        local dbSet = {}
                        for pubSrv, _ in pairs( pubSrvs ) do
                            local settings = pubSrv:getPublishSettings()['< contents >']
                            assert( settings, "no settings" )
                            destRoot = settings.destPath
                            for destPath in LrFileUtils.recursiveFiles( destRoot ) do
                                local key = str:pathToPropForPluginKey( destPath )
                                local uuid = cat:getPropertyForPlugin( key ) -- Save mapping entry from destination file to source photo. Throws error if trouble.
                                if str:is( uuid ) then
                                    local photo = catalog:findPhotoByUuid( uuid )
                                    if photo then
                                        photoSet[photo] = false
                                    else
                                        app:log( "Source photo no longer in catalog corresponding to: '^1', uuid: ^2", destPath, uuid )
                                        local ext = LrPathUtils.extension( destPath )
                                        call.stats.nSubject = call.stats.nSubject + 1
                                        if exts[ext] then
                                            local a = exts[ext]
                                            a[#a + 1] = destPath
                                        else
                                            exts[ext] = { destPath }
                                        end
                                    end
                                else
                                    --extra[#extra + 1] = destPath
                                    
                                    app:log( "No ID corresponding to '^1' has been recorded.", destPath )
                                    local ext = LrPathUtils.extension( destPath )
                                    call.stats.nSubject = call.stats.nSubject + 1
                                    if ext == "db" then
                                        local filename = LrPathUtils.leafName( destPath )
                                        if filename == "Thumbs.db" then
                                            dbSet[destPath] = true
                                        end
                                    end
                                    if exts[ext] then
                                        local a = exts[ext]
                                        a[#a + 1] = destPath
                                    else
                                        exts[ext] = { destPath }
                                    end
                                end
                            end
                        end
                        local photos = tab:createArrayFromSet( photoSet )
                        local dbs = tab:createArrayFromSet( dbSet )
                        local tb
                        local buttons
                        if #dbs > 0 then
                            tb = str:fmtx( " (^1 'Thumbs.db' files)", #dbs )
                            buttons = { dia:btn( "Yes - Delete All", 'ok' ), dia:btn( "View Log File", 'other' ), dia:btn( "Yes - But Leave Thumb.db Files", 'leaveThumbs' ) }
                        else
                            tb = ""
                            buttons = { dia:btn( "Yes - Delete", 'ok' ), dia:btn( "View Log File", 'other' ) }
                        end
                        if #photos > 0 then
                            local cache = lrMeta:createCache{ photos=photos, rawIds = { 'path', 'uuid' } }
                            app:log()
                            app:log( "^1 not represented in published tree^2:", str:nItems( #photos, "photos" ), tb )
                            for i, photo in ipairs( photos ) do
                                app:log( "^1: ^2", cache:getRawMetadata( photo, 'path' ), cache:getRawMetadata( photo, 'uuid' ) )
                            end
                            app:log()
                            local most = catalog:getTargetPhoto()
                            if not photoSet[most] then
                                most = photos[1]
                            end 
                            catalog:setSelectedPhotos( most, photos ) -- sources are already selected.
                            LrTasks.yield()
                            local button = app:show{ info="^1 not represented in a published tree should be selected now, and all such photos are listed in the log file - consider canceling, then do maintenance on selected photos, then re-run 'Delete Extraneous Files'.\n \nPress 'OK' to proceed to the deletion prompt despite unrepresented photos, or press 'Cancel' to abort.",
                                subs = { str:nItems( #photos, "photos" ) },
                                buttons = { dia:btn( "OK", 'ok' )  },
                            }
                            if button == 'cancel' then
                                call:abort( "User aborted to consider photos not represented in published tree before deleting extraneous files." )
                                return
                            end
                        else
                            app:log()
                            app:log( "No photos unrepresented." )
                            app:log()
                        end
                        if call.stats.nSubject > 0 then
                            app:log()
                            app:log()
                            app:log( "To be deleted, should you approve, by extension:", str:plural( call.stats.nSubject, "file", true ) )
                            for k, v in tab:sortedPairs( exts ) do
                                app:log( "^1: ^2", k, #v )
                                for i, v2 in ipairs( v ) do
                                    app:log( v2 )
                                end
                            end
                            app:log()
                            local answer
                            repeat
                                answer = app:show{ info="Delete ^1? Log file contains complete list^2.",
                                    subs = { str:plural( call.stats.nSubject, "file", true ), tb },
                                    buttons = buttons,
                                }
                                if answer == 'ok' then
                                    app:log( "Deleting all extraneous files." )
                                    break
                                elseif answer == 'leaveThumbs' then
                                    app:log( "Deleting extraneous files, except Thumbs.db files." )
                                    break
                                elseif answer == 'cancel' then
                                    call:cancel()
                                    return
                                else
                                    app:showLogFile()
                                end
                            until false

                            
                            for e, v in pairs( exts ) do
                                app:log()
                                app:log( "Deleting ^1:", str:nItems( #v, str:fmtx( "extraneous .^1 files", e ) ) )
                                for i, path in ipairs( v ) do
                                    local delete = false
                                    if dbSet[path] then
                                        if answer == 'leaveThumbs' then
                                            app:log( "NOT deleting Thumb.db file: ^1", path )
                                        else
                                            delete = true
                                        end
                                    else
                                        delete = true
                                    end
                                    if delete then
                                        local deleted, wasntIt = fso:moveToTrash( path )
                                        -- local deleted, wasntIt = false, "Bogus..."
                                        if deleted then
                                            app:log( "^1 - deleted, or moved to trash.", path )
                                            call.stats.nDeleted = call.stats.nDeleted + 1
                                        else
                                            app:logE( "^1 - NOT deleted, error message: ^2", path, wasntIt )
                                        end
                                    -- else message logged above.
                                    end
                                end
                            end
                            app:log()
                            -- could remind user about remote sync, but I think I'll leave it up to the user - extraneous files on the local host, does not necessarily mean extraneous remote files.
                        else
                            app:show{ info="No extraneous files." }
                            call:cancel()
                            return
                        end
                    end, finale=function( call )
                        app:log()
                        app:log( "^1/^2 deleted.", call.stats.nDeleted, str:plural( call.stats.nSubject, "file", true ) )
                    end }
                end,
            },
            vf:static_text {
                title = "Delete extraneous files in export tree of selected published service collections.",
            },
        }

    appSection[#appSection + 1] = vf:spacer{ height=10 }
    
    
    appSection[#appSection + 1] =
        vf:row {
            vf:push_button {
                title = str:fmtx( "Photo-match, auto-order, && publish" ),
                tooltip = "Consider all TreeSyncPublisher services, and if setup to mirror folder tree or collection set with photo matching, duplicate mirrored source tree as collection set in TSP. (and if not photo matching, it will be ignored)\n \n*** You will be given the option to proceed with publishing after \"photos-to-be-published\" collection has been prepared, and it's generally a good idea to do so (unless you've got good reason to defer publishing..).",
                width = share 'buttonWidth',
                action = function( button )
                    app:service{ name=button.title, async=true, progress=true, guard=App.guardVocal, main=function( call )
                        if not _PLUGIN.enabled then
                            app:show{ warning="Plugin is disabled - must be enabled to publish..", call=call }
                            call:cancel()
                            return
                        end

                        -- local summ, pubCollSet, sortedNotMatched = Common.syncPhotos( call, true, false )
                        local summ, pubCollSet, sortedNotMatched = Common.quickSyncPhotos( call, true, false )
                        
                        local photoMatch
                        local autoOrder
                        local vi = {}
                        vi[#vi + 1] = vf:row {
                            bind_to_object = boundDataSource,
                            vf:static_text {
                                title = "Before publishing, do",
                            },
                            vf:radio_button {
                                title = "photo-matching",
                                value = LrView.bind( 'doOp' ),
                                -- value = app:getPrefBinding( 'doOp' ),
                                checked_value = 'match',
                            },                            
                            vf:radio_button {
                                title = "auto-ordering",
                                -- value = app:getPrefBinding( 'doOp' ),
                                value = LrView.bind( 'doOp' ),
                                checked_value = 'order',
                            },                            
                            vf:radio_button {
                                title = "both",
                                -- value = app:getPrefBinding( 'doOp' ),
                                value = LrView.bind( 'doOp' ),
                                checked_value = 'both',
                            },                            
                        }

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

                        -- Added new feature from broken file
                        local catalog = LrApplication.activeCatalog()
                        local PublishServices = catalog:getPublishServices(_PLUGIN.id)
                        boundDataSource.collectionTree = {}
                        local function buildCollectionTree(collectionSet, parentNode, currentPath)
                            -- Traverse through all child collections in the collection set
                            for _, collection in ipairs(collectionSet:getChildCollections()) do
                                local node = {
                                    node = collection,
                                    label = collection:getName(),
                                    checked = false,
                                    children = {},
                                }
                                local nextPath = currentPath .. "/" .. node.label
                                boundDataSource[nextPath] = boundDataSource[nextPath] or false
                                node.checked = boundDataSource[nextPath]
                                table.insert(parentNode.children, node)
                            end

                            -- Traverse through all child collection sets (subsets)
                            for _, subSet in ipairs(collectionSet:getChildCollectionSets()) do
                                local node = {
                                    node = subSet,
                                    label = subSet:getName(),
                                    checked = false,
                                    children = {},
                                }
                                local nextPath = currentPath .. "/" .. node.label
                                boundDataSource[nextPath] = boundDataSource[nextPath] or false
                                node.checked = boundDataSource[nextPath]
                                buildCollectionTree(subSet, node, nextPath)
                                table.insert(parentNode.children, node)
                            end
                        end

                        local root = {
                            node = nil,
                            label = "All Select",
                            checked = false,
                            children = {}
                        }
                        boundDataSource[root.label] = boundDataSource[root.label] or false
                        root.checked = boundDataSource[root.label]
                        table.insert(boundDataSource.collectionTree, root)
                        for _, publishService  in ipairs(PublishServices) do
                            local rootNode = {
                                node = publishService,
                                label = publishService:getName(),
                                checked = false,
                                children = {},
                            }
                            local collectionPath = root.label .. "/" .. rootNode.label
                            boundDataSource[collectionPath] = boundDataSource[collectionPath] or false
                            rootNode.checked = boundDataSource[collectionPath]

                            buildCollectionTree(publishService, rootNode, collectionPath)
                            table.insert(root.children, rootNode)
                        end

                        local function checkAllParent(currentPath)
                            if currentPath == root.label then
                                for _, node in ipairs(boundDataSource.collectionTree) do
                                    node.checked = true
                                    boundDataSource[node.label] = true
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
                                    boundDataSource[currentPath] = true
                                    node.checked = true
                                    -- LrDialogs.message("label: ", node.label..", "..currentPath)
                                    return node.children
                                end
                            end
                        end

                        local function checkAllSubCollections(node, chk, currentPath)
                            node.checked = chk
                            boundDataSource[currentPath] = chk
                            -- LrDialogs.message(node.label, currentPath..":    "..tostring(chk))
                            -- LrDialogs.message("current full path: ", currentPath .. tostring(node.checked))
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
                                -- LrDialogs.message("node.label: ", node.label)
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

                                if node.children then
                                    local childElements = renderTree(node.children, depth + 1, nextPath)
                                    for _, childElement in ipairs(childElements) do
                                        table.insert(uiElements, childElement)
                                    end
                                end
                            end

                            return uiElements
                        end

                        
                        boundDataSource.showSelectiveDlg = false
                        vi[#vi + 1] = vf:row {
                            bind_to_object = boundDataSource,
                            vf:checkbox {
                                title = "Selective Publication",
                                checked_value = true,
                                unchecked_value = false,
                                -- value = app:getPrefBinding( 'selectivePublication' ),  -- Bind to a property
                                -- value = LrView.bind('selectivePublication'),
                                value = LrView.bind('showSelectiveDlg'),
                                tooltip = "Select to only publish a subset of photos",
                                action = function()
                                    boundDataSource.showSelectiveDlg = not boundDataSource.showSelectiveDlg
                                    if boundDataSource.showSelectiveDlg then
                                        boundDataSource.originalCollectionTree = deepCopy(boundDataSource.collectionTree)
                                        boundDataSource.publishCollectionData = renderTree(boundDataSource.collectionTree, 0, "")

                                        local contents = vf:column {
                                            bind_to_object = boundDataSource,
                                            vf:scrolled_view {
                                                width = 700,
                                                height = 500,
                                                vf:column(boundDataSource.publishCollectionData),
                                            },
                                        }
                                        local a = LrDialogs.presentModalDialog {
                                            title = "Select collections to publish:",
                                            contents = contents,
                                        }
                                        if a == 'ok' then
                                            boundDataSource.publishCollectionData = boundDataSource.collectionTree
                                            prefs.publishCollectionData = boundDataSource.collectionTree
                                        else
                                            boundDataSource.publishCollectionData = boundDataSource.originalCollectionTree
                                            prefs.publishCollectionData = boundDataSource.originalCollectionTree
                                            boundDataSource.collectionTree = boundDataSource.originalCollectionTree
                                            prefs.collectionTree = boundDataSource.originalCollectionTree
                                        end
                                    end
                                end,
                            }
                        }

                        local a = app:show{ confirm="Do photo-matching, auto-ordering, and publishing?\n(all publish services in TSP purview will be considered)\n \n* Photo-matching will be done if collection set being mirrored has 'Photo Matching' enabled.\n* Auto-ordering will only be attempted if collection set being mirrored is publish type. It will only work if you've inserted TreeSyncOrderer \"export filter\" (post-process action) in the settings of the publish service being mirrored AND said publish service supports export filters (post-process actions).\n \nYou will be prompted to publish after photo-matching (and/or auto-ordering) is complete (if said prompt is still being shown).",
                            subs = {},
                            -- buttons = { dia:btn( "Yes - do specified operations..", 'ok' ), dia:btn( "No - don't do anything..", 'cancel' ), }, - ok/cancel is fine.
                            viewItems = vi,
                            call = call,
                        }


                        local doOp = boundDataSource.doOp
                        if a=='ok' then
                            if doOp == 'both' then
                                photoMatch = true
                                autoOrder = true
                            elseif doOp == 'match' then
                                photoMatch = true
                                autoOrder = false
                            elseif doOp == 'order' then
                                photoMatch = false
                                autoOrder = true
                            else
                                error( "bad op" )
                            end
                        elseif a=='cancel' then
                            call:cancel()
                            return
                        else
                            error( "bad btn" )
                        end
                        
                        if call:isQuit() then return end


                        pubCollSet = {} -- toss current set
                        local nSrvToPub = 0
                        local nCollToPub = 0
                        local selection = {}
                        local totalCnt = 0

                        if boundDataSource.showSelectiveDlg then
                            for _, root in ipairs( boundDataSource.publishCollectionData ) do
                                -- LrDialogs.message(root.label, tostring(root.checked))
                                if root.checked then
                                    for __, publishService in ipairs(root.children) do
                                        if publishService.checked then
                                            -- LrDialogs.message(publishService.label, tostring(publishService.checked))
                                            nSrvToPub = nSrvToPub + 1
                                            local function addPublishedCollection(treeNodes, currentCollPath)
                                                for ___, collection in ipairs(treeNodes) do
                                                    if collection.checked then
                                                        local fullCollPath = currentCollPath.."/"..collection.node:getName()
                                                        -- LrDialogs.message("comparing checked: ", tostring(collection.label).."\n"..tostring(collection.node))
                                                        if tostring(collection.node) == "LrPublishedCollection" then
                                                            pubCollSet[collection.node] = publishService.node
                                                            totalCnt = totalCnt + #collection.node:getPhotos()
                                                            nCollToPub = nCollToPub + 1
                                                            selection[fullCollPath] = true
                                                            -- LrDialogs.message("collection name: ", tostring(#collection.node:getPhotos()))
                                                        end
                                                        if #collection.children then
                                                            addPublishedCollection(collection.children, fullCollPath)
                                                        end
                                                    end
                                                end
                                            end
                                            addPublishedCollection(publishService.children, publishService.node:getName())
                                        end
                                    end
                                end
                            end
                        else
                            local allTsp = catalog:getPublishServices( _PLUGIN.id )
                            selection["AllSelection"] = true      -- 1571 line in  in Common.lua should be same as "AllSelection"
                            for i, tsp in ipairs( allTsp ) do
                                local es = tsp:getPublishSettings()['< contents >'] or error( "no publish settings" )
                                -- assert( es, "no es" )
                                if es.photosToo or es.assureOrder then
                                    nSrvToPub = nSrvToPub + 1
                                    local colls = cat:getCollsInCollSet( tsp )
                                    for j, c in ipairs( colls ) do
                                        -- LrDialogs.message("comparing checked: ", tostring(c:getName()).."\n"..tostring(tsp:getName()))
                                        pubCollSet[c] = tsp
                                        totalCnt = totalCnt + #c:getPhotos()
                                        nCollToPub = nCollToPub + 1
                                    end
                                end
                            end
                        end

                        Common.fullSyncPhotos( call, photoMatch, autoOrder, selection )
                        if call:isQuit() then return end
                        -- if prefs.missingOriginals == "All" then
                        --     TreeSyncManager:removeMissingPhotos()
                        -- end
                        -- LrDialogs.message("deletedCnt: ", tostring(deletedCnt))

                        local nUpd = tab:countItems( summ )

                        --if nUpd > 0 then
                            local b = {}
                            for srvName, stats in tab:sortedPairs( summ ) do
                                if boundDataSource.showSelectiveDlg then
                                    for _, root in ipairs( boundDataSource.publishCollectionData ) do
                                        for __, publishService in ipairs(root.children) do
                                            if publishService.checked and publishService.node:getName() == srvName then
                                                b[#b + 1] = str:fmtx( "* ^1\n^2", srvName, stats )
                                            end
                                        end
                                    end
                                else
                                    b[#b + 1] = str:fmtx( "* ^1\n^2", srvName, stats )
                                end
                            end
                            local okBtn
                            local okVal
                            local othBtn
                            local allBtn = dia:btn( "Publish all collections", "other2" )
                            local tb2
                            local tb3
                            if nCollToPub > 0 then
                                if nCollToPub > 1 and nCollToPub <= 12 then -- multiple collections to publish, but not too many (most publish services can not handle more than a dozen concurrently).
                                    tb2 = "\n \nChoose \"one at a time\" for maximum reliability (and minimum CPU utilization).\nChoose \"all at once\" for maximum speed via concurrent processing."
                                    okBtn = dia:btn( "Yes - one at a time", 'ok' )
                                    othBtn = dia:btn( "Yes - all at once", 'other' )
                                else
                                    tb2 = "\n \n(you will be presented with a dialog box when publishing is finished, if it's still being shown..)."
                                    okBtn = dia:btn( "Yes - and wait for it..", 'ok' )
                                end
                                tb3 = str:fmtx( "Publish ^1 now?", str:nItems( nCollToPub, "new or modified collections" ) )
                            else
                                tb2 = "\n \n(you will be presented with a dialog box when publishing is finished, if it's still being shown..)."
                                okBtn = dia:btn( "Publish all collections", "ok" )
                                okVal = "other2"
                                allBtn = nil
                                tb3 = "There are no new or modified collections to publish, but you can still opt to publish all (whether or not they're new or modified..)."
                            end
                            local updated = app:show{ confirm="^1 updated:\n-----------------------\n\n^2\n \n^3^4\n \nActual number of photos to be published (new/modified/deleted..) is ^5.\n \nIf you opt to publish all, only those with photo-matching or sort-ordering will be published - one at a time.",
                                subs = { str:plural( nUpd, "service", true ), table.concat( b, "\n" ), tb3, tb2, totalCnt },
                                width = 700,
                                height = 400,
                                buttons = { allBtn, othBtn, okBtn, dia:btn( "No thanks - not now..", 'cancel' ) }, -- nil button OK (ignored).
                                -- actionPrefKey = "Publish updated photo collections",
                                call = call,
                            }
                           

                            if updated == 'ok' and okVal then
                                updated = okVal
                            end
                            local wait
                            if updated == 'ok' then
                                wait = true
                            elseif updated == 'other' then
                                if othBtn then
                                    wait = false
                                else -- answer left over from previous save when multiple services were being exported (with do-not-show ticked).
                                    wait = true
                                end
                            elseif updated == 'other2' then
                                wait = true
                            elseif updated == 'cancel' then
                                return
                            else
                                error( "bad btn" )
                            end

                            local msg = str:fmtx( "Publishing ^1 in ^2", str:pluralize( nCollToPub, "collection" ), str:pluralize( nSrvToPub, "service" ) )
                            app:displayInfo( msg )

                            if nCollToPub == 0 then
                                app:show{ warning="Nothing to publish", call=call }
                                call:cancel()
                                return
                            end


                            for c, tspSrv in pairs( pubCollSet ) do
                                local srvName = tspSrv:getName()
                                local collectionName = c:getName()
                                local publishSettings = tspSrv:getPublishSettings()["< contents >"] or nil
                                local destPath = publishSettings.destPath
                                auxSettings[srvName] = { deferUploading=autoOrder } -- will be copied to exp/pub object when it gets to that.
                                -- reminder: aux-settings are used because publish-settings are write-only at this point.
                                local function getCollectionFullPath(collection)
                                    if collection:getParent() == nil then
                                        return collection:getName()
                                    end
                                    return getCollectionFullPath(collection:getParent()) .. "\\" .. collection:getName()
                                end
                                local collectionFullPath = getCollectionFullPath(c)
                                local destFolderPath = destPath .. "\\" .. collectionFullPath
                                local collectionId = c.localIdentifier
                                local done
                                -- LrDialogs.message("destFolderPath: ", destFolderPath)

                                local photos = c:getPhotos()
                                local photosToDo = {}
                                for i, photo in ipairs(photos) do
                                    local sourcePath = photo:getRawMetadata("path")
                                    local missing = LrFileUtils.exists(sourcePath)
                                    local folderPath = LrPathUtils.parent(sourcePath)
                                    local pathError = LrFileUtils.exists(folderPath)

                                    if not missing then
                                        local errMsg = "Missing originals: " .. sourcePath
                                        if prefs.missingOriginals == "All" then
                                            if not pathError then
                                                errMsg = "Path corrupted: " .. sourcePath
                                            else
                                                errMsg = "Not found: " .. sourcePath
                                            end
                                            table.insert(photosToDo, photo)
                                        end
                                        app:log(errMsg)
                                    end
                                end

                                local tsp = TreeSyncPublish:newDialog()
                                local done1 = tsp:markAsPublishedForMissingOriginals( call, photosToDo, c, tspSrv )

                                if wait then
                                    app:sleep( math.huge, 1, function( et )
                                        return done1
                                    end )
                                end
                                

                                fprops:setPropertyForPlugin( nil, "collectionId", collectionId)
                                fprops:setPropertyForPlugin( nil, "collName", collectionName)
                                fprops:setPropertyForPlugin( nil, "missingOriginals", prefs.missingOriginals )
                                fprops:setPropertyForPlugin( nil, "destinationFolder", destPath .. "\\" .. collectionFullPath )
                               
                                -- LrDialogs.message(collectionName, "publishing now...")
                                c:publishNow( function() -- reminder: this will NOT call process-rendered-photos method if nothing to export (even if something to delete), and even if ordering was done.
                                    app:log( "^1 publishing finished - dunno whether successful or not.", collectionName )
                                    done = true
                                end )

                                if wait then
                                    app:sleep( math.huge, 1, function( et )
                                        return done
                                    end )
                                end
                                
                            end

                            app:log( "*****************   Publishing finished successfully.   *****************" )

                            local completed = app:show{
                                info = "Publishing finished successfully. Do you want to see the log?",
                                buttons = {dia:btn( "Yes", 'ok' ), dia:btn( "No", 'cancel')},
                            }

                            if completed =="ok" then
                                if app:isLoggerEnabled() and LrFileUtils.exists( app:getLogFilePath() ) then
                                    app:showLogFile()
                                else
                                    app:show( "no log" )
                                end
                            end
                            call:cancel()
                            
                    end, finale=function()
                        auxSettings = {} -- default state is empty table.
                    end }
                end,
            },
            vf:static_text {
                title = "Update photos-to-be-published collections, sort ordering info, then publish.",
            },
        }
	
    if not app:isRelease() then
        appSection[#appSection + 1] = vf:spacer{ height=25 }
        appSection[#appSection + 1] =
            vf:static_text {
                title = "Present in development version only:"
            }
        appSection[#appSection + 1] = vf:separator{ fill_horizontal=.34 }
        appSection[#appSection + 1] = vf:spacer{ height=3 }
    	appSection[#appSection + 1] = 
    		vf:row {
    			vf:edit_field {
    				value = bind( "testData" ),
    			},
    			vf:static_text {
    				title = str:format( "Test data" ),
    			},
    		}
    	appSection[#appSection + 1] = 
    		vf:row {
    			vf:push_button {
    				title = "Test",
    				action = function( button )
    				    --[[
    				    app:call( Call:new{ name='Test', async=true, main = function( call )
                            local s, m
                            s, m = background:sendAndReceive( "command 1", "parm 1" )
                            app:logInfo( str:fmt( "1. s: ^1, m: ^2", str:to( s ), str:to( m ) ) )
                        end } )
    				    app:call( Call:new{ name='Test', async=true, main = function( call )
                            local s, m
                            s, m = background:sendAndReceive( "command 2", "parm 1", "parm 2" )
                            app:logInfo( str:fmt( "2. s: ^1, m: ^2", str:to( s ), str:to( m ) ) )
                        end } )
                        --]]
                        
                        app:service{ name=button.title, async=true, function()
                            local p = catalog:getTargetPhoto()
                            --Debug.pause( p:getRawMetadata( 'uuid' ) )
                            local filenamePreset
                            local presets = LrApplication.filenamePresets()
                            local pluginName = "Original Filename" -- app:getPluginName() -- excludes extension though, for some reason, I thought at first ext was included (losing my mind?).
                            app:logV( "Looking for filename preset named '^1'", pluginName )
                            for k, v in pairs( presets ) do
                                if str:isEqualIgnoringCase( k, pluginName ) then
                                    app:log( "Got requisite filename preset." )
                                    filenamePreset = v -- UUID on win7/64-Lr4, but doc says could be path - hmmm......
                                    break
                                else
                                    app:logV( "'^1' is not it...", k )
                                end
                            end
                            if not filenamePreset then
                                Debug.pause( "?" )
                            else
                                Debug.pause( filenamePreset )
                                --Debug.pause( p:getNameViaPreset( filenamePreset ) ) -- for some reason this not reliable when preset is for orig fn - argh..
                                -- (I could have sworn it worked once, but now it ain't workin' at all). *** SEEMS OK AFTER RESTARTING LIGHTROOM - HMM.. (ME OR LR??)
                            end
                            
                            local preferPresetOverFile = false -- set true if you prefer sqliteroom-compat orig-filename over that obtained via preset when both are available.
                            local ofn, msg = cat:getOriginalFilename( p, preferPresetOverFile )
                            if ofn then
                                Debug.pause( ofn, msg )
                            else
                                app:show{ warning=msg }
                            end
                            
                        end }
                                                
    				end
    			},
    			vf:static_text {
    				title = str:format( "Perform tests." ),
    			},
    		}
	
    end
		
    local sections = Manager.sectionsForBottomOfDialogMethod ( self, vf, props ) -- fetch base manager sections.
    if #appSection > 0 then
        tab:appendArray( sections, { appSection } ) -- put app-specific prefs after.
    end
    return sections
end


end)  -- End of LrFunctionContext.callWithContext


return TreeSyncManager
-- the end.