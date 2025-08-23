
local LrApplication      = import 'LrApplication'
local LrFunctionContext  = import 'LrFunctionContext'
local LrDialogs          = import 'LrDialogs'
local LrTasks            = import 'LrTasks'

LrFunctionContext.callWithContext('PublishOnlyThisTree_TSP', function(context)
    LrTasks.startAsyncTask(function()
        local catalog = LrApplication.activeCatalog()
        local sources = catalog:getActiveSources()
        if not (sources and #sources > 0) then
            LrDialogs.message("TreeSync Publisher", "Select a TreeSync published collection or collection set first.", "info")
            return
        end

        local function publishTree(node)
            local okC, colls = pcall(function() return node:getChildCollections() end)
            if okC and type(colls) == 'table' then
                for _, c in ipairs(colls) do
                    pcall(function() c:publishNow() end)
                end
            end
            local okS, sets = pcall(function() return node:getChildCollectionSets() end)
            if okS and type(sets) == 'table' then
                for _, s in ipairs(sets) do publishTree(s) end
            end
        end

        local queued = 0
        local function countCollections(node)
            local n = 0
            local okC, colls = pcall(function() return node:getChildCollections() end)
            if okC and type(colls) == 'table' then n = n + #colls end
            local okS, sets = pcall(function() return node:getChildCollectionSets() end)
            if okS and type(sets) == 'table' then
                for _, s in ipairs(sets) do n = n + countCollections(s) end
            end
            return n
        end

        for _, src in ipairs(sources) do
            local okPub = pcall(function() src:publishNow() end)
            if okPub then
                queued = queued + 1
            else
                queued = queued + countCollections(src)
                publishTree(src)
            end
        end

        LrDialogs.message("TreeSync Publisher", string.format("Queued publish for %d collections under the selected tree(s).", queued), "info")
    end)
end)
