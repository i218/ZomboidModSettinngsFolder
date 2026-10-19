require "MSF/Model"
ModSettingsFolders.Capture={}
local C=ModSettingsFolders.Capture
-- This game's rawget() also traverses metatables. pairs() identifies own fields.
local function own(object,key)
    for k,v in pairs(object) do if k==key then return v end end
end
local function children(page)
    local result={};for _,child in pairs(page:getChildren() or {}) do result[#result+1]=child end;return result
end
-- Build the ORIGINAL forms exactly once. Keep every GameOption and option.element.
function C.build(owner,builder,width)
    local originalWidth=owner.width
    local rawWidth=own(owner,"getWidth");local rawHeader=own(owner,"addHorizontalLine");local rawPage=own(owner,"addPage")
    local header,addPage=owner.addHorizontalLine,owner.addPage
    local definitions,groups,seen={},{},{}
    local page,current;local targetActive=false;local reason
    local function reject(message) if not reason then reason=message end end
    local function finish()
        if not current then return end
        for _,child in ipairs(children(page)) do
            if not seen[child] then
                seen[child]=true
                current.nodes[#current.nodes+1]={ui=child,y=child:getY(),visible=child:getIsVisible()}
                current.bottom=math.max(current.bottom,child:getY()+child:getHeight())
            end
        end
        current=nil
    end
    owner.getWidth=function() return targetActive and width or originalWidth end
    owner.addPage=function(self,name,...)
        finish()
        targetActive=false;self.width=originalWidth
        local isMods=name==getText("UI_mainscreen_mods")
        if isMods and not page then
            -- Wrappers may filter Data before calling the stock builder, or load()
            -- may register settings. Snapshot the registry actually used on this page.
            local ids={}
            for _,options in ipairs(PZAPI.ModOptions.Data) do
                if ids[options.modOptionsID] then reject("duplicate section IDs on Mods page") end
                ids[options.modOptionsID]=true;definitions[#definitions+1]=options
            end
            targetActive=not reason and #definitions>0
            if targetActive then self.width=width end
        elseif isMods then reject("multiple native Mods pages") end
        local result=addPage(self,name,...)
        if isMods and not page then
            page=self.mainPanel
            for _,child in ipairs(children(page)) do seen[child]=true end
        end
        return result
    end
    owner.addHorizontalLine=function(self,y,text)
        -- Other mods may append their own tabs and leave mainPanel pointing there.
        -- Their headers, layout and controls must remain entirely independent.
        if not page or self.mainPanel~=page then return header(self,y,text) end
        finish()
        local options=definitions[#groups+1]
        if not options or text~=getText(options.name) then reject("section header mismatch at "..(#groups+1)) end
        current={id=options and options.modOptionsID or "",name=text,nodes={},top=self.addY+y,bottom=self.addY+y}
        groups[#groups+1]=current
        return header(self,y,text)
    end
    local ok,result=pcall(builder,owner)
    owner.width=originalWidth;owner.getWidth=rawWidth;owner.addHorizontalLine=rawHeader;owner.addPage=rawPage
    if not ok then error(result) end
    finish()
    if not page then reject("native Mods page not found")
    elseif #groups~=#definitions then reject("Mods section count differs: "..#groups.."/"..#definitions)
    elseif #groups==0 then reject("no registered Mods sections") end
    if reason then
        if page then page:setWidth(originalWidth) end
        return nil,reason.."; keeping native controls"
    end
    for _,group in ipairs(groups) do
        group.active=true
        for _,node in ipairs(group.nodes) do
            node.rawVisible=own(node.ui,"setVisible");node.nativeVisible=node.ui.setVisible
            node.wrapper=function(ui,value,...)
                node.visible=not not value
                return node.nativeVisible(ui,group.active and node.visible,...)
            end
            node.ui.setVisible=node.wrapper
        end
    end
    return {page=page,groups=groups,width=width,scrollHeight=page:getScrollHeight(),height=page:getHeight()}
end
-- Relayout changes only visibility/Y, never values, registration or callbacks.
function C.show(capture,selection)
    local y=8
    for _,group in ipairs(capture.groups) do
        local visible=selection==nil or selection==group.id
        group.active=visible
        for _,node in ipairs(group.nodes) do
            node.nativeVisible(node.ui,visible and node.visible)
            node.ui:setY(visible and y+node.y-group.top or node.y)
        end
        if visible then y=y+math.max(24,group.bottom-group.top)+16 end
    end
    capture.page:setYScroll(0);capture.page:setScrollHeight(y+16)
end
function C.release(capture)
    capture.page:setScrollHeight(capture.scrollHeight);capture.page:setYScroll(0)
    for _,group in ipairs(capture.groups) do
        group.active=true
        for _,node in ipairs(group.nodes) do
            if node.ui.setVisible==node.wrapper then node.ui.setVisible=node.rawVisible end
            node.nativeVisible(node.ui,node.visible);node.ui:setY(node.y)
        end
    end
end
return C
