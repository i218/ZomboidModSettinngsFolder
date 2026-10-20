require "MSF/Capture"
require "MSF/Store"
require "MSF/ContextMenu"
require "ISUI/ISPanelJoypad"
require "ISUI/ISScrollingListBox"
require "ISUI/ISButton"
require "ISUI/ISContextMenu"
require "ISUI/ISTextBox"
require "ISUI/ISModalDialog"
local U={};ModSettingsFolders.UI=U
local M,S,C=ModSettingsFolders.Model,ModSettingsFolders.Store,ModSettingsFolders.Capture
local function focus(ui,data) if data then data.focus=ui;updateJoypadFocus(data) end end
local function height() return math.max(26,getTextManager():getFontHeight(UIFont.Small)+10) end
function U.message(key)
    local screen=getCore()
    local modal=ISModalDialog:new(screen:getScreenWidth()/2-210,screen:getScreenHeight()/2-85,420,170,getText(key),false,nil,nil)
    modal:initialise();modal:addToUIManager()
end
function U:save()
    local ok,err=S.save()
    if not ok then print("[ModSettingsFolders] layout save failed: "..tostring(err));U.message("UI_MSF_SaveFailed") end
    self:refresh()
end
function U:newFolder()
    self:prompt(nil)
end
function U:prompt(id)
    local folder=id and M.find(self.state,id)
    local screen=getCore()
    local dialog=ISTextBox:new(screen:getScreenWidth()/2-230,screen:getScreenHeight()/2-90,460,180,
        getText(folder and "UI_MSF_Rename" or "UI_MSF_New"),folder and folder.name or "",self,function(controller,button)
            if button.internal~="OK" then return end
            local text=button.parent.entry:getText()
            local ok,err
            if id then ok,err=M.rename(controller.state,id,text) else ok,err=M.create(controller.state,text) end
            if not ok then U.message(err=="duplicate" and "UI_MSF_Duplicate" or "UI_MSF_InvalidName");return end
            controller:save()
        end)
    dialog:initialise();dialog:addToUIManager();dialog.entry:focus()
end
function U:deleteFolder(id)
    if M.delete(self.state,id) then self:save() end
end
function U:move(section,folder)
    if M.move(self.state,section,folder) then self:save() end
end
function U:reorder(id,delta)
    if M.reorder(self.state,id,delta) then self:save() end
end
function U:toggleFolder(id)
    if id=="unfiled" then self.state.unfiledCollapsed=not self.state.unfiledCollapsed
    else local f=M.find(self.state,id);if f then f.collapsed=not f.collapsed end end
    self:save()
end
function U:select(row)
    if not row then return end
    self.cursor=row
    if row.kind=="folder" then self:toggleFolder(row.id);return end
    self.selected=row.kind=="section" and row.id or nil
    C.show(self.capture,self.selected)
    self:refresh()
    if self.compact then self.navVisible=false;self:layout() end
end
function U:refresh()
    local list=self.tree;local scroll=list:getYScroll();list:clear()
    local preferred,fallback
    local function add(text,row)
        local item=list:addItem(text,row)
        item.tooltip=row.kind=="section" and (text.."\n"..row.id) or text
        if (row.kind=="all" and self.selected==nil) or (row.kind=="section" and row.id==self.selected) then fallback=#list.items end
        if self.cursor and self.cursor.kind==row.kind and self.cursor.id==row.id then preferred=#list.items end
    end
    add(getText("UI_MSF_All"),{kind="all"})
    local groups={};for _,group in ipairs(self.capture.groups) do groups[#groups+1]=group end
    table.sort(groups,function(a,b) local an,bn=string.lower(a.name),string.lower(b.name);if an==bn then return a.id<b.id end;return an<bn end)
    local function folder(id,label,closed)
        local entries={}
        for _,group in ipairs(groups) do
            local assigned=self.state.members[group.id]
            if (id=="unfiled" and not assigned) or assigned==id then entries[#entries+1]=group end
        end
        add((closed and "[+] " or "[-] ")..label.." ("..#entries..")",{kind="folder",id=id})
        if not closed then for _,group in ipairs(entries) do add("    "..group.name,{kind="section",id=group.id}) end end
    end
    for _,f in ipairs(self.state.folders) do folder(f.id,f.name,f.collapsed) end
    folder("unfiled",getText("UI_MSF_Unfiled"),self.state.unfiledCollapsed)
    list.selected=preferred or fallback or 1
    list:setYScroll(scroll)
end
function U:context(row,x,y)
    if self.contextMenu then self.contextMenu:dispose() end
    local menu=ModSettingsFolders.ContextMenu:create(x or getMouseX(),y or getMouseY(),self.tree)
    self.contextMenu=menu
    menu:addOption(getText("UI_MSF_New"),self,U.newFolder)
    menu:addOption(getText("UI_MSF_All"),self,function(controller) controller:select({kind="all"}) end)
    if not row then return end
    if row.kind=="section" then
        local option=menu:addOption(getText("UI_MSF_Move"),nil,nil)
        local sub=ModSettingsFolders.ContextMenu:create(menu:getX(),menu:getY(),self.tree,menu);menu:addSubMenu(option,sub)
        sub:addOption(getText("UI_MSF_Unfiled"),self,U.move,row.id,nil)
        for _,f in ipairs(self.state.folders) do sub:addOption(f.name,self,U.move,row.id,f.id) end
    elseif row.kind=="folder" and row.id~="unfiled" then
        menu:addOption(getText("UI_MSF_Rename"),self,U.prompt,row.id)
        menu:addOption(getText("UI_MSF_Up"),self,U.reorder,row.id,-1)
        menu:addOption(getText("UI_MSF_Down"),self,U.reorder,row.id,1)
        menu:addOption(getText("UI_MSF_Delete"),self,U.deleteFolder,row.id)
    end
end
function U:layout()
    local w,h=self.host:getWidth(),self.host:getHeight();local buttonHeight=height()
    if self.compact then
        self.toggle:setWidth(w-16)
        self.nav:setX(0);self.nav:setY(buttonHeight+8);self.nav:setWidth(w);self.nav:setHeight(h-buttonHeight-8)
        self.page:setX(0);self.page:setY(buttonHeight+8);self.page:setWidth(w);self.page:setHeight(h-buttonHeight-8)
        self.nav:setVisible(self.navVisible==true);self.page:setVisible(not self.navVisible)
    else
        self.nav:setWidth(self.navWidth);self.nav:setHeight(h)
        self.page:setX(self.navWidth+8);self.page:setY(0);self.page:setWidth(w-self.navWidth-8);self.page:setHeight(h)
    end
    self.create:setWidth(self.nav:getWidth()-16)
    self.tree:setWidth(self.nav:getWidth()-16);self.tree:setHeight(self.nav:getHeight()-buttonHeight-24)
end
function U.detach(owner)
    local self=owner.msfController;if not self then return end
    if self.contextMenu then self.contextMenu:dispose();self.contextMenu=nil end
    local visible=self.host:getIsVisible()
    owner.tabs:replaceView(self.host,self.page)
    self.host:removeChild(self.page);owner.tabs:removeChild(self.host);owner.tabs:addChild(self.page)
    self.page:setX(0);self.page:setY(owner.tabs.tabHeight);self.page:setWidth(owner:getWidth());self.page:setVisible(visible)
    self.page.onJoypadDown=self.originalJoypad
    self.page.onGainJoypadFocus=self.originalGain
    self.page.onJoypadBeforeDeactivate=self.originalDeactivate
    self.page:setHeight(self.capture.height)
    C.release(self.capture);owner.msfController=nil
end
function U.attach(owner,capture,navWidth,compact)
    local page=capture.page;local tabs=owner.tabs
    if not tabs.replaceView then return nil end
    local self=setmetatable({owner=owner,page=page,capture=capture,state=S.load(),navWidth=navWidth,compact=compact,originalJoypad=page.onJoypadDown,originalGain=page.onGainJoypadFocus,originalDeactivate=page.onJoypadBeforeDeactivate},{__index=U})
    local host=ISPanelJoypad:new(0,tabs.tabHeight,owner:getWidth(),page:getHeight());host:initialise();host:instantiate();host:noBackground()
    host:setAnchorRight(true);host:setAnchorBottom(true)
    if tabs:replaceView(page,host)~=page then return nil end
    local visible=page:getIsVisible();tabs:removeChild(page);tabs:addChild(host);host:setVisible(visible)
    host:addChild(page);page:setVisible(true);self.host=host;owner.msfController=self
    local nav=ISPanelJoypad:new(0,0,navWidth,page:getHeight());nav:initialise();nav:instantiate();nav:noBackground();host:addChild(nav);self.nav=nav
    local create=ISButton:new(8,8,navWidth-16,height(),getText("UI_MSF_New"),self,U.newFolder);create:initialise();nav:addChild(create);self.create=create
    local list=ISScrollingListBox:new(8,height()+16,navWidth-16,page:getHeight()-height()-24);list:initialise();list:instantiate()
    list:setFont(UIFont.Small,4);list.itemheight=height();nav:addChild(list);self.tree=list
    list:setOnMouseDownFunction(self,U.select)
    list.onRightMouseDown=function(box,x,y)
        local item=box.items[box:rowAt(x,y)];self:context(item and item.item)
        return true
    end
    local draw=list.doDrawItem
    list.doDrawItem=function(box,y,item,alt)
        local current=item.item.kind=="section" and item.item.id==self.selected or item.item.kind=="all" and self.selected==nil
        if current then box:drawRect(0,y,box.width,item.height or box.itemheight,.25,.3,.65,1) end
        return draw(box,y,item,alt)
    end
    -- Native list arrows invoke the mouse callback; folders must toggle only on A.
    list.onJoypadDirUp=function(box) box.selected=math.max(1,box.selected-1);box:ensureVisible(box.selected);self.cursor=box.items[box.selected] and box.items[box.selected].item end
    list.onJoypadDirDown=function(box) box.selected=math.min(#box.items,box.selected+1);box:ensureVisible(box.selected);self.cursor=box.items[box.selected] and box.items[box.selected].item end
    local function changeTab(button,data)
        if button~=Joypad.LBumper and button~=Joypad.RBumper then return false end
        local index=tabs:getActiveViewIndex()+(button==Joypad.LBumper and -1 or 1)
        if index<1 then index=#tabs.viewList elseif index>#tabs.viewList then index=1 end
        tabs:activateView(tabs.viewList[index].name);focus(tabs:getActiveView(),data);return true
    end
    list.onJoypadDown=function(box,button,data)
        if changeTab(button,data) then return end
        local item=box.items[box.selected];local row=item and item.item
        if button==Joypad.AButton then self:select(row);if row and row.kind~="folder" then focus(page,data) end
        elseif button==Joypad.XButton then self:context(row,box:getAbsoluteX()+20,box:getAbsoluteY()+20)
        elseif button==Joypad.YButton then self:newFolder()
        elseif button==Joypad.BButton then owner:onOptionMouseDown(owner.backButton) end
    end
    host.onGainJoypadFocus=function(_,data) focus(list,data) end
    local function deactivate(_,data) owner:onJoypadBeforeDeactivate(data) end
    host.onJoypadBeforeDeactivate=deactivate;page.onJoypadBeforeDeactivate=deactivate;list.onJoypadBeforeDeactivate=deactivate
    page.onGainJoypadFocus=function(panel,data)
        if self.originalGain then self.originalGain(panel,data) end
        panel:setJoypadFocusTopLeft(data)
    end
    local oldJoypad=page.onJoypadDown
    self.originalJoypad=oldJoypad
    page.onJoypadDown=function(panel,button,data)
        if changeTab(button,data) then return end
        if button==Joypad.BButton then
            if self.compact then self.navVisible=true;self:layout() end
            focus(list,data);return
        end
        if oldJoypad then return oldJoypad(panel,button,data) end
    end
    if compact then
        local toggle=ISButton:new(8,4,owner:getWidth()-16,height(),getText("UI_MSF_Navigate"),self,function(controller)
            controller.navVisible=not controller.navVisible;controller:layout()
        end)
        toggle:initialise();host:addChild(toggle);self.toggle=toggle
    end
    local baseRender=host.prerender
    host.prerender=function(panel)
        if self.lastWidth~=panel:getWidth() or self.lastHeight~=panel:getHeight() then
            self.lastWidth=panel:getWidth();self.lastHeight=panel:getHeight();self:layout()
        end
        if baseRender then baseRender(panel) end
    end
    self:refresh();C.show(capture,nil);self:layout()
    return self
end
return U
