require "MSF/Model"
local S={file="ModSettingsFolders.cfg",backup="ModSettingsFolders.previous.cfg"}
ModSettingsFolders.Store=S
local function read(file)
    local reader=getFileReader(file,false);if not reader then return nil end
    local lines={};local size=0
    local ok,err=pcall(function()
        while true do
            local line=reader:readLine();if line==nil then break end
            size=size+#line+1;if size>524288 then error("layout too large") end
            lines[#lines+1]=line
        end
    end)
    reader:close();if not ok then return nil,err end
    return table.concat(lines,"\n").."\n"
end
local function write(file,text)
    local writer=getFileWriter(file,true,false);assert(writer,"layout writer unavailable")
    local ok,err=pcall(function() writer:write(text) end)
    local closed,closeError=pcall(function() writer:close() end)
    if not ok then error(err) end;if not closed then error(closeError) end
end
function S.load()
    if S.state then return S.state end
    local text,readError=read(S.file);local state=text and ModSettingsFolders.Model.decode(text)
    if state then S.good=text
    elseif text and text:match("^MSF%d+") and not text:match("^MSF1[\r\n]") then S.blocked=true
    else
        local backup,backupError=read(S.backup);state=backup and ModSettingsFolders.Model.decode(backup)
        if state then S.good=backup;S.recovered=true
        elseif text or readError or backup or backupError then S.blocked=true end
    end
    S.state=state or ModSettingsFolders.Model.new();return S.state
end
function S.save(candidate)
    if S.blocked then return false,"unsupported or damaged layout; original file preserved" end
    local text=ModSettingsFolders.Model.encode(candidate or S.load())
    local ok,err=pcall(function()
        if S.good then write(S.backup,S.good) end
        write(S.file,text)
    end)
    if ok then S.good=text;if candidate then S.state=candidate end end
    return ok,err
end
return S
