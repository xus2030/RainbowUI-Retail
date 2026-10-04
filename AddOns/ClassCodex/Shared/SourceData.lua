local _, ns = ...

local WILDCARD = "all"

function ns.SourceSpec(source, class, spec)
    local src = ClassCodexSource and ClassCodexSource[source]
    local byClass = src and src.data and src.data[class]
    return byClass and byClass[spec] or nil
end

--- True when the source carries ANY PvP-context data for the spec — i.e. the
--- spec "has a PvP guide" there. Guide-less specs show the PvP empty screen
--- instead of borrowed or PvE data.
function ns.HasPvpGuide(source, class, spec)
    local sd = ns.SourceSpec(source, class, spec)
    if not sd then return false end
    for _, cat in ipairs({ "gear", "enchants", "gems", "trinkets", "statPriority", "rotation", "talents", "crafting" }) do
        local byHero = sd[cat]
        if type(byHero) == "table" then
            for _, byCtx in pairs(byHero) do
                if type(byCtx) == "table" then
                    for ctx in pairs(byCtx) do
                        if ctx == "pvp" or ctx:sub(1, 4) == "pvp:" then return true end
                    end
                end
            end
        end
    end
    return false
end

function ns.LastUpdated()
    local best
    if ClassCodexSource then
        for _, src in pairs(ClassCodexSource) do
            local g = type(src) == "table" and src.meta and src.meta.generatedAt
            if type(g) == "string" and (not best or g > best) then best = g end
        end
    end
    return best and best:sub(1, 10) or nil
end

local function contextChain(context)
    local chain = { context }
    local sep = context:find(":", 1, true)
    if sep then chain[#chain + 1] = context:sub(1, sep - 1) end
    -- Generic pvp falls back to the shuffle bracket, so data emitted with
    -- bracket-specific contexts (multi-bracket fetch) still resolves.
    if context == "pvp" then chain[#chain + 1] = "pvp:shuffle" end
    local isPvp = context == "pvp" or context:sub(1, 4) == "pvp:"
    if context ~= WILDCARD and not isPvp then chain[#chain + 1] = WILDCARD end
    return chain
end
ns.ContextChain = contextChain

function ns.ResolveCategory(category, hero, context)
    if not category then return nil end
    local heroes = hero == WILDCARD and { WILDCARD } or { hero, WILDCARD }
    for _, ctx in ipairs(contextChain(context)) do
        for _, h in ipairs(heroes) do
            local byContext = category[h]
            if byContext and byContext[ctx] ~= nil then return byContext[ctx], h, ctx end
        end
    end
    return nil
end

--- ResolveCategory's full triple (payload, hero, context) — or nil. The hit
--- context tells callers whether a genuine entry resolved or a wildcard
--- fallback did (the stat priority variants depend on it), so this must tail-
--- call rather than embed ResolveCategory in an expression, which would
--- truncate it to a single value.
function ns.SourceValue(source, class, spec, category, hero, context)
    local sd = ns.SourceSpec(source, class, spec)
    if not sd then return nil end
    return ns.ResolveCategory(sd[category], hero or WILDCARD, context or WILDCARD)
end

function ns.ActiveSource()
    local s = ns.Context and ns.Context.source()
    if s and ClassCodexSource and ClassCodexSource[s] then return s end
    return (ns.Sources())[1] or "icyveins"
end

function ns.SourceHas(source, class, spec, category)
    local sd = ns.SourceSpec(source, class, spec)
    return sd ~= nil and sd[category] ~= nil
end

local DEFAULT_PRIORITY = { "icyveins", "ugg" }

function ns.Sources()
    local order, seen = {}, {}
    if not ClassCodexSource then return order end
    for _, s in ipairs(DEFAULT_PRIORITY) do
        if ClassCodexSource[s] then
            order[#order + 1] = s
            seen[s] = true
        end
    end
    for s in pairs(ClassCodexSource) do
        if not seen[s] then order[#order + 1] = s end
    end
    return order
end
