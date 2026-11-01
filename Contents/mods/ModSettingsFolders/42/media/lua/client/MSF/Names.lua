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
function N.source(id)
    local title=info(id)
    if title then return title,id end
    if getActivatedMods then
        local ok,found,source=pcall(function()
            local active=getActivatedMods();local result,modId;local count=0
            for n=0,active:size()-1 do
                local candidate=active:get(n)
                if key(candidate)==key(id) then count=count+1;modId=candidate;result=info(candidate) end
            end
            if count==1 then return result,modId end
        end)
        if ok then return found,source end
    end
end
function N.display(id,text)
    text=clean(text)
    if not N.missing(id,text) then return text end
    local title=N.source(id)
    return title or (clean(id)~="" and id or text)
end
return N
