ModSettingsFolders=ModSettingsFolders or {}
local M={}
ModSettingsFolders.Model=M
local function valid(s,max)
    if type(s)~="string" or #s==0 or #s>max then return false end
    for i=1,#s do local b=string.byte(s,i);if b<32 or b==127 then return false end end
    return true
end
local function name(s) return type(s)=="string" and s:gsub("^%s+",""):gsub("%s+$","") or "" end
function M.new() return {folders={},members={},nextId=1,unfiledCollapsed=false} end
function M.find(state,id) for i,f in ipairs(state.folders) do if f.id==id then return f,i end end end
function M.create(state,text)
    text=name(text)
    if not valid(text,160) or #state.folders>=99 or state.nextId>1000000000 then return nil,"name" end
    for _,f in ipairs(state.folders) do if string.lower(f.name)==string.lower(text) then return nil,"duplicate" end end
    local id="f"..state.nextId;state.nextId=state.nextId+1
    state.folders[#state.folders+1]={id=id,name=text,collapsed=false}
    return id
end
function M.rename(state,id,text)
    local f=M.find(state,id);text=name(text)
    if not f or not valid(text,160) then return false,"name" end
    for _,other in ipairs(state.folders) do if other~=f and string.lower(other.name)==string.lower(text) then return false,"duplicate" end end
    f.name=text;return true
end
function M.delete(state,id)
    local _,index=M.find(state,id);if not index then return false end
    table.remove(state.folders,index)
    for key,folder in pairs(state.members) do if folder==id then state.members[key]=nil end end
    return true
end
function M.move(state,section,folder)
    if not valid(section,256) or (folder and not M.find(state,folder)) then return false end
    if folder and not state.members[section] then
        local count=0;for _ in pairs(state.members) do count=count+1 end
        if count>=2000 then return false end
    end
    state.members[section]=folder;return true
end
function M.reorder(state,id,delta)
    local f,i=M.find(state,id);if not f or (delta~=-1 and delta~=1) then return false end
    local j=i+delta;if j<1 or j>#state.folders then return false end
    state.folders[i],state.folders[j]=state.folders[j],state.folders[i];return true
end
-- Kahlua stores Java Unicode strings, not UTF-8 byte arrays. Keep text intact.
-- Escape only format delimiters; never reconstruct Unicode with string.char().
local function escape(s) return (s:gsub("%%", "%%25"):gsub("|", "%%7C")) end
local function unescape(s)
    if s:gsub("%%25", ""):gsub("%%7C", ""):find("%%") then return nil end
    return (s:gsub("%%(%x%x)",function(code) return code=="25" and "%" or "|" end))
end
function M.encode(state)
    local lines={"MSF1","U|"..(state.unfiledCollapsed and "1" or "0")}
    for _,f in ipairs(state.folders) do lines[#lines+1]="F|"..f.id.."|"..(f.collapsed and "1" or "0").."|"..escape(f.name) end
    local keys={};for id in pairs(state.members) do keys[#keys+1]=id end;table.sort(keys)
    for _,id in ipairs(keys) do lines[#lines+1]="M|"..state.members[id].."|"..escape(id) end
    return table.concat(lines,"\n").."\n"
end
function M.decode(text)
    if type(text)~="string" or #text>524288 then return nil,"size" end
    local lines={};for line in (text.."\n"):gmatch("([^\n]*)\n") do lines[#lines+1]=line:gsub("\r$","") end
    if lines[1]~="MSF1" then return nil,"version" end
    local state=M.new();local pending={};local ids={};local count=0;local unfiled=false
    for i=2,#lines do
        local line=lines[i]
        if line=="U|0" or line=="U|1" then
            if unfiled then return nil,"folder" end
            unfiled=true;state.unfiledCollapsed=line=="U|1"
        elseif line~="" then
            local id,collapsed,encoded=line:match("^F|(f%d+)|([01])|([^|]+)$")
            if id then
                local number=tonumber(id:sub(2));local label=unescape(encoded)
                if not number or number<1 or number>1000000000 or ids[id] or not valid(label,160) or #state.folders>=99 then return nil,"folder" end
                ids[id]=true;state.folders[#state.folders+1]={id=id,name=label,collapsed=collapsed=="1"};state.nextId=math.max(state.nextId,number+1)
            else
                local folder,key=line:match("^M|(f%d+)|([^|]+)$");key=key and unescape(key)
                if not folder or not valid(key,256) or pending[key] then return nil,"member" end
                count=count+1;if count>2000 then return nil,"size" end;pending[key]=folder
            end
        end
    end
    for key,folder in pairs(pending) do if not ids[folder] then return nil,"folder" end;state.members[key]=folder end
    return state
end
return M
