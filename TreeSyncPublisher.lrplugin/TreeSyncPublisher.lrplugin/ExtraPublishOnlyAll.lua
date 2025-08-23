
local LrApplication      = import 'LrApplication'
local LrFunctionContext  = import 'LrFunctionContext'
local LrDialogs          = import 'LrDialogs'
local LrTasks            = import 'LrTasks'

LrFunctionContext.callWithContext('PublishOnlyAll_TSP', function(context)
    LrTasks.startAsyncTask(function()
        local catalog  = LrApplication.activeCatalog()
        local services = catalog:getPublishServices(_PLUGIN.id)
        local total    = 0

        local function publishTree(node)
            local okC, colls = pcall(function() return node:getChildCollections() end)
            if okC and type(colls) == 'table' then
                for _, c in ipairs(colls) do
                    total = total + 1
                    pcall(function() c:publishNow() end)
                end
            end
            local okS, sets = pcall(function() return node:getChildCollectionSets() end)
            if okS and type(sets) == 'table' then
                for _, s in ipairs(sets) do publishTree(s) end
            end
        end

        for _, srv in ipairs(services or {}) do publishTree(srv) end

        LrDialogs.message("TreeSync Publisher", string.format("Queued publish for %d collections across all TreeSync services.", total), "info")
    end)
end)
