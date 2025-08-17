--[[
        Info.lua
--]]

return {
    appName = "TreeSync Publisher",
    shortAppName = "TSP",
    author = "Rob Cole",
    authorsWebsite = "www.robcole.com",
    donateUrl = "http://www.robcole.com/Rob/Donate",
    platforms = { 'Windows', 'Mac' },
    pluginId = "com.robcole.lightroom.TreeSyncPublisher",
    xmlRpcUrl = "http://www.robcole.com/Rob/_common/cfpages/XmlRpc.cfm",
    -- LrPluginName = "rc TreeSync Publisher",
    LrPluginName = LOC "$$$/rcTreeSyncPublisher/PluginName=rc TreeSync Publisher",
    LrSdkMinimumVersion = 3.0,
    LrSdkVersion = 5.0,
    LrPluginInfoUrl = "http://www.robcole.com/Rob/ProductsAndServices/TreeSyncPublisherLrPlugin",
    LrPluginInfoProvider = "TreeSyncManager.lua",
    LrToolkitIdentifier = "com.robcole.TreeSyncPublisher",
    LrInitPlugin = "Init.lua",
    LrShutdownPlugin = "Shutdown.lua",
    LrExportServiceProvider = {
        title = "rc TreeSync Publisher",
        file = "TreeSyncPublish.lua",
        builtInPresetsDir = "Export Presets",
    },
    LrExportMenuItems = {
        {
            title = "Photo Sort Match All",
            file = "ExtraSyncPhotoSortMatchAll.lua",  -- Pointing to the Lua file containing the function
        },
        {
            title = "Photo Sort Match This Tree",
            file = "ExtraSyncPhotoSortMatchThisTree.lua",  -- Pointing to the Lua file containing the function
        },
    },
    MyMetadataDefinitionFile = "MyMetadataDefinitionFile.lua",
    LrMetadataTagsetFactory = "Tagsets.lua",
    -- LrMetadataProvider = {
    --     schemaVersion = 1,
    --     metadataFieldsForPhotos = {
    --         {
    --             id = 'treesync_missing_photo',
    --             title = 'Missing Photo',
    --             dataType = 'string',  -- This could also be 'number', 'boolean', etc.
    --             searchable = true,
    --             readOnly = true,
    --             browsable = true,
    --             version = 1,
    --         },
    --         {
    --             id = 'modelRelease',
    --             title = LOC "$$$/Sample/Fields/ModelRelease=Model Release",
    --             dataType = 'enum',
    --             values = {
    --                 {
    --                     value = nil,
    --                     title = LOC "$$$/Sample/Fields/ModelRelease/NotSure=Not Sure",
    --                 },
    --                 {
    --                     value = 'yes',
    --                     title = LOC "$$$/Sample/Fields/ModelRelease/Yes=Yes",
    --                 },
    --                 {
    --                     value = 'no',
    --                     title = LOC "$$$/Sample/Fields/ModelRelease/No=No",
    --                 },
    --                 -- optional: allowPluginToSetOtherValues = true,
    --             },
    --         },
    --     },
    -- },
    VERSION = { display = "11.0    Build: 2014-09-26 14:56:44" },
}
