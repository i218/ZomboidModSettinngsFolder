require "MSF/Model"
local M=ModSettingsFolders.Model
local I={file="ModFolders.cfg"};ModSettingsFolders.Import=I
local function label(s) return s:gsub("^%s+",""):gsub("%s+$","") end
local function valid(s,max)
    if type(s)~="string" or #s==0 or #s>max then return false end
    for n=1,#s do local c=s:byte(n);if c<32 or c==127 then return false end end
    return true
end
function I.available()
    if getModInfoByID then local ok,mod=pcall(getModInfoByID,"ModFolders");if ok and mod then return true end end
    if getActivatedMods then
        local ok,active=pcall(function() return getActivatedMods():contains("ModFolders") end)
        return ok and active==true
    end
    return false
end
local function decodeValue(value,version)
    if version==2 then
        if value=="" then return "" end
        local out={}
        for token in (value..","):gmatch("(.-),") do
            if not token:match("^%x+$") or #token>4 then return nil end
            out[#out+1]=string.char(tonumber(token,16))
        end
        return table.concat(out)
    end
    -- Legacy percent escaping used variable-width UTF-16 values.
    local out={};local pos=1
    while pos<=#value do
        local c=value:sub(pos,pos)
        if c~="%" then out[#out+1]=c;pos=pos+1
        else
            local pair=value:sub(pos+1,pos+2);local code=tonumber(pair,16)
            if #pair~=2 or not pair:match("^%x%x$") then return nil end
            local quad=value:sub(pos+1,pos+4)
            local number=#quad==4 and quad:match("^%x+$") and tonumber(quad,16)
            local plain=code>=48 and code<=57 or code>=65 and code<=90 or code>=97 and code<=122 or code==45 or code==46 or code==95 or code==126
            local after=value:sub(pos+5,pos+5)
            local wide=number and number>255 and (plain or after=="" or after=="%")
            out[#out+1]=string.char(wide and number or code);pos=pos+(wide and 5 or 3)
        end
    end
    return table.concat(out)
end
function I.decode(text)
    if type(text)~="string" or #text>524288 then return nil,"size" end
    local lines={};local version=1;local hasVersion=false
    for line in (text.."\n"):gmatch("([^\n]*)\n") do
        line=line:gsub("\r$","");lines[#lines+1]=line
        if line:match("^version=") then
            if hasVersion or (line~="version=1" and line~="version=2") then return nil,"version" end
            hasVersion=true;version=tonumber(line:sub(9))
        end
    end
    local source={folders={},members={}};local ids={};local members=0
    for _,line in ipairs(lines) do
        if line~="" and not line:match("^version=") then
            local id,expanded,value=line:match("^folder=(%d+)|([01])|(.*)$")
            if id then
                local number=tonumber(id);local name=decodeValue(value,version);name=name and label(name)
                if number<1 or number>1000000000 or ids[number] or not valid(name,160) or #source.folders>=99 then return nil,"folder" end
                ids[number]=true;source.folders[#source.folders+1]={id=number,name=name,collapsed=expanded=="0"}
            else
                local key,folder=line:match("^member=(.-)|(%d+)$")
                if key then
                    key=decodeValue(key,version);folder=tonumber(folder)
                    if not valid(key,256) or source.members[key] then return nil,"member" end
                    members=members+1;if members>2000 then return nil,"size" end
                    source.members[key]=folder
                elseif not line:match("^next=%d+$") then return nil,"format" end
            end
        end
    end
    for _,id in pairs(source.members) do if not ids[id] then return nil,"folder" end end
    return source
end
function I.read()
    local reader=getFileReader(I.file,false);if not reader then return nil,"missing" end
    local ok,text=pcall(function()
        local lines={};local size=0
        while true do
            local line=reader:readLine();if line==nil then break end
            size=size+#line+1;if size>524288 then error("size") end
            lines[#lines+1]=line
        end
        return table.concat(lines,"\n")
    end)
    local closed=pcall(function() reader:close() end)
    if not ok or not closed then return nil,"read" end
    return I.decode(text)
end
local function normalized(s) return string.lower(s):gsub("[%s%p]","") end
function I.resolve(modId,groups)
    local exact={};local names={};local target=normalized(modId)
    local info
    if getModInfoByID then local ok,value=pcall(getModInfoByID,modId);if ok then info=value end end
    local title
    if info then local ok,value=pcall(function() return info:getName() end);if ok and type(value)=="string" then title=normalized(value) end end
    for _,g in ipairs(groups) do
        if string.lower(g.id)==string.lower(modId) then exact[#exact+1]=g.id end
        if normalized(g.id)==target or normalized(g.name)==target or title and normalized(g.name)==title then names[#names+1]=g.id end
    end
    if #exact==1 then return exact[1] end
    if #exact==0 and #names==1 then return names[1] end
end
function I.merge(state,source,groups)
    local nodes={};local parent={};local localNode={};local sourceNode={};local names={};local sections={}
    local function root(n) while parent[n]~=n do n=parent[n] end;return n end
    local function union(a,b) a=root(a);b=root(b);if a~=b then parent[math.max(a,b)]=math.min(a,b) end end
    local function node(folder,existing)
        local n=#nodes+1;nodes[n]={folder=folder,existing=existing};parent[n]=n
        local key=string.lower(folder.name)
        if names[key] then union(n,names[key]) else names[key]=n end
        return n
    end
    for _,f in ipairs(state.folders) do localNode[f.id]=node(f,true) end
    for _,f in ipairs(source.folders) do sourceNode[f.id]=node(f,false) end
    for key,id in pairs(state.members) do sections[key]=localNode[id] end
    local keys={};for key in pairs(source.members) do keys[#keys+1]=key end;table.sort(keys)
    local skipped=0;local imported={}
    for _,key in ipairs(keys) do
        local section=I.resolve(key,groups)
        if section then
            local n=sourceNode[source.members[key]]
            if sections[section] then union(n,sections[section]) else sections[section]=n end
            imported[section]=true
        else skipped=skipped+1 end
    end
    local candidate=M.new();candidate.nextId=state.nextId;candidate.unfiledCollapsed=state.unfiledCollapsed
    local targets={};local created=0;local merged=0
    for n,item in ipairs(nodes) do
        local component=root(n)
        if not targets[component] then
            local f=item.folder;local id
            if item.existing then
                id=f.id;candidate.folders[#candidate.folders+1]={id=id,name=f.name,collapsed=f.collapsed}
            else
                id=M.create(candidate,f.name);if not id then return nil,"limit" end
                M.find(candidate,id).collapsed=f.collapsed;created=created+1
            end
            targets[component]=id
        else merged=merged+1 end
    end
    local assigned=0
    for key,n in pairs(sections) do
        if not M.move(candidate,key,targets[root(n)]) then return nil,"limit" end
        if imported[key] then assigned=assigned+1 end
    end
    if not M.decode(M.encode(candidate)) then return nil,"limit" end
    return candidate,{created=created,merged=merged,assigned=assigned,skipped=skipped}
end
return I
