
local LrApplication = import 'LrApplication'
local LrFunctionContext = import 'LrFunctionContext'
local LrDialogs = import 'LrDialogs'
local LrTasks = import 'LrTasks'

LrFunctionContext.callWithContext('PublishOnlyAll', function(context)
    LrTasks.startAsyncTask(function()
        local catalog = LrApplication.activeCatalog()
        local services = catalog:getPublishServices(_PLUGIN.id)
        local total = 0
        local function publishTree(node)
            for _, c in ipairs(node:getChildCollections()) do
                total = total + 1
                c:publishNow(function()
                    app:log("^1 publishing finished - dunno whether successful or not.", c:getName())
                end)
            end
            for _, s in ipairs(node:getChildCollectionSets()) do
                publishTree(s)
            end
        end
        for _, srv in ipairs(services) do publishTree(srv) end
        LrDialogs.message("TreeSync Publisher", string.format("Queued publish for %d collections across all TreeSync services.", total))
    end)
end)
