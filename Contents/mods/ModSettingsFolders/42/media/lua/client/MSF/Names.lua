local N={};ModSettingsFolders.Names=N
local function clean(text) return type(text)=="string" and text:gsub("^%s+",""):gsub("%s+$","") or "" end
local function key(text) return string.lower(clean(text)):gsub("[%s%p]","") end
local function info(id)
    if not getModInfoByID then return end
    local ok,mod=pcall(getModInfoByID,id)
    if ok and mod then
        local named,title=pcall(function() return mod:getName() end)
        if named and clean(title)~="" then return clean(title) end
    end
end
function N.missing(id,text)
    text=clean(text)
    return text=="" or key(text)==key(id) or key(text)=="" or text:match("^UI_")~=nil or
        text:match("^IGUI_")~=nil or text:match("^Sandbox_")~=nil or
        string.lower(text)=="options" or string.lower(text)=="settings"
end
function N.display(id,text)
    text=clean(text)
    if not N.missing(id,text) then return text end
    local title=info(id)
    if title then return title end
    -- Some registries format the source ID differently (spaces, hyphens, case).
    -- Resolve only unique active-mod ID matches; never guess by substring.
    if getActivatedMods then
        local ok,found=pcall(function()
            local active=getActivatedMods();local result;local count=0
            for n=0,active:size()-1 do
                local modId=active:get(n)
                if key(modId)==key(id) then count=count+1;result=info(modId) end
            end
            return count==1 and result or nil
        end)
        if ok and found then return found end
    end
    return clean(id)~="" and id or text
end
return N
