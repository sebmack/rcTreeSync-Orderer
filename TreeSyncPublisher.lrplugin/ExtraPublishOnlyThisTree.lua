
local LrApplication = import 'LrApplication'
local LrFunctionContext = import 'LrFunctionContext'
local LrDialogs = import 'LrDialogs'
local LrTasks = import 'LrTasks'

LrFunctionContext.callWithContext('PublishOnlyThisTree', function(context)
    LrTasks.startAsyncTask(function()
        local catalog = LrApplication.activeCatalog()
        local sources = catalog:getActiveSources()
        if not sources or #sources == 0 then
            LrDialogs.message("TreeSync Publisher", "Select a TreeSync Published Collection or Collection Set first.", "info")
            return
        end
        local function publishTree(node)
            for _, c in ipairs(node:getChildCollections()) do
                c:publishNow(function()
                    app:log("^1 publishing finished - dunno whether successful or not.", c:getName())
                end)
            end
            for _, s in ipairs(node:getChildCollectionSets()) do
                publishTree(s)
            end
        end
        local queued = 0
        local function countCollections(n)
            local c = 0
            for _, _c in ipairs(n:getChildCollections()) do c = c + 1 end
            for _, s in ipairs(n:getChildCollectionSets()) do c = c + countCollections(s) end
            return c
        end
        for _, src in ipairs(sources) do
            local t = cat:getSourceType(src)
            if t == 'LrPublishedCollection' or t == 'LrPublishedCollectionSet' then
                queued = queued + countCollections(src)
                publishTree(src)
            end
        end
        LrDialogs.message("TreeSync Publisher", string.format("Queued publish for %d collections under the selected tree(s).", queued), "info")
    end)
end)
