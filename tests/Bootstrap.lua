function require() end
files={};writes=0;failWrite=false
function getFileReader(path,create)
    if not files[path] and create then files[path]="" end
    if not files[path] then return nil end
    local lines={};for line in files[path]:gmatch("([^\n]*)\n") do lines[#lines+1]=line:gsub("\r$", "") end
    local i=0;return {readLine=function() i=i+1;return lines[i] end,close=function() end}
end
function getFileWriter(path)
    local buffer=""
    return {write=function(self,text) if failWrite then error("disk full") end;buffer=buffer..text;files[path]=buffer;writes=writes+1 end,close=function() end}
end
function getText(s) return s end
function getKeyName(n) return "KEY"..tostring(n) end
function getMouseX() return 50 end
function getMouseY() return 50 end
function getCore() return {getOptionFontSizeReal=function() return testFontSize or 1 end,getScreenWidth=function() return 1280 end,getScreenHeight=function() return 720 end} end
UIFont={Small=1,Medium=2,Large=3};BUTTON_HGT=26;FONT_HGT_SMALL=16;UI_BORDER_SPACING=8;INITIAL_Y=8
function getTextManager() return {getFontHeight=function() return 16 end} end
function updateJoypadFocus(data) if data.focus.onGainJoypadFocus then data.focus:onGainJoypadFocus(data) end end
Events={OnGameBoot={Add=function() end},OnMainMenuEnter={Add=function() end}}
Joypad={AButton=0,BButton=1,XButton=2,YButton=3,LBumper=4,RBumper=5}
UI={};UI.__index=UI;local uid=0
function UI:derive(name) local o={Type=name};setmetatable(o,{__index=self});o.__index=o;return o end
ISBaseObject=UI
function UI:instanceof(object) local c=getmetatable(object);while c do if c==self then return true end;c=getmetatable(c);c=c and c.__index end;return false end
function UI:new(x,y,w,h,text,target,onclick)
    uid=uid+1
    return setmetatable({ID=uid,x=x or 0,y=y or 0,width=w or 0,height=h or 0,title=text,target=target,onclick=onclick,
        children={},childrenInOrder={},visible=true,items={},options={},selected=1,joypadButtonsY={},yscroll=0,Type=self.Type},self)
end
function UI:initialise() end
function UI:instantiate() self.javaObject={} end
function UI:noBackground() end
function UI:addToUIManager() end
function UI:setAnchorRight() end
function UI:setAnchorLeft() end
function UI:setAnchorBottom() end
function UI:setAnchorTop() end
function UI:setFont() end
function UI:drawRect() end
function UI:setTooltip(value) self.tooltip=value end
function UI:focus() end
function UI:prerender() end
function UI:addChild(child) self.children[child.ID]=child;self.childrenInOrder[#self.childrenInOrder+1]=child;child.parent=self end
function UI:removeChild(child) self.children[child.ID]=nil;for i,c in ipairs(self.childrenInOrder) do if c==child then table.remove(self.childrenInOrder,i);break end end end
function UI:getChildren() return self.children end
function UI:getX() return self.x end
function UI:getY() return self.y end
function UI:getWidth() return self.width end
function UI:getHeight() return self.height end
function UI:setX(value) self.x=value end
function UI:setY(value) self.y=value end
function UI:setWidth(value) self.width=value end
function UI:setHeight(value) self.height=value end
function UI:getAbsoluteX() return self.x+(self.parent and self.parent:getAbsoluteX() or 0) end
function UI:getAbsoluteY() return self.y+(self.parent and self.parent:getAbsoluteY() or 0) end
function UI:setVisible(value) self.visible=value end
function UI:getIsVisible() return self.visible end
function UI:setYScroll(value) self.yscroll=value end
function UI:getYScroll() return self.yscroll end
function UI:getScrollHeight() return self.scrollHeight or 0 end
function UI:ensureVisible() end
function UI:setJoypadFocusTopLeft() end
function UI:setScrollHeight(value) self.scrollHeight=value end
function UI:setSelected(i,value) self.options[i]=value end
function UI:isSelected(i) return self.options[i] end
function UI:disableOption(_,value) self.disabled=value end
function UI:setEnable(value) self.enabled=value end
function UI:setEditable(value) self.editable=value end
function UI:setText(value) self.text=value end
function UI:getText() return self.text end
function UI:getInternalText() return self.text end
function UI:setName(value) self.name=value end
function UI:setCurrentValue(value) self.value=value end
function UI:getCurrentValue() return self.value end
function UI:setInitialColor(value) self.backgroundColor=value end
function UI:setOnClick(fn,...) self.onclick=fn;self.clickArgs={...} end
function UI:clear() self.items={};self.selected=1 end
function UI:addItem(text,item) local row={text=text,item=item,height=self.itemheight};self.items[#self.items+1]=row;return row end
function UI:rowAt(x,y) return math.floor(y/(self.itemheight or 26))+1 end
function UI:doDrawItem(y,item) return y+(item.height or 26) end
function UI:setOnMouseDownFunction(target,fn) self.target=target;self.onmousedown=fn end
function UI:replaceView(old,new)
    for _,view in ipairs(self.viewList) do if view.view==old then view.view=new;return old end end
end
function UI:insertNewLineOfButtons(...) self.joypadButtonsY[#self.joypadButtonsY+1]={...} end
ISPanelJoypad=UI:derive("ISPanelJoypad");ISScrollingListBox=UI:derive("ISScrollingListBox");ISButton=UI:derive("ISButton")
ISColorPicker=UI:derive("ISColorPicker");ISLabel=UI:derive("ISLabel");ISTextBox=UI:derive("ISTextBox");ISModalDialog=UI:derive("ISModalDialog")
ColorInfo={new=function(r,g,b,a) return {r=r,g=g,b=b,a=a} end}
luautils={indexOf=function(t,value) for i,v in ipairs(t) do if v==value then return i end end;return -1 end,
 split=function(s,separator) local r={};for v in s:gmatch("[^"..separator.."]+") do r[#r+1]=v end;return r end}
DebugType={GameOption={trace=function() end,warn=function() end}}
MainOptions=UI:derive("MainOptions");MainOptions.keyText={};MainOptions.keyButtonWidth=100
function MainOptions:addPage(name)
    local page=UI:new(0,20,self:getWidth(),500);page:instantiate();self.mainPanel=page
    page:addChild(UI:new(0,0,13,500)) -- native scrollbar must never become part of a group
    self.tabs.viewList[#self.tabs.viewList+1]={name=name,view=page};self.tabs:addChild(page)
end
function MainOptions:addHorizontalLine(y,text)
    self.mainPanel:addChild(UI:new(8,self.addY+y,self.width-24,2));local label=UI:new(40,self.addY+y+8,200,18);label.text=text;self.mainPanel:addChild(label);self.addY=self.addY+42
end
function MainOptions:addHorizontalLineSmall(y) self.mainPanel:addChild(UI:new(8,self.addY+y,200,2));self.addY=self.addY+8 end
function MainOptions:addTitle(x,y,text) self.mainPanel:addChild(UI:new(x,self.addY+y,200,20));self.addY=self.addY+26 end
function MainOptions:addDescription(x,y,text) self.mainPanel:addChild(UI:new(x,self.addY+y,400,36));self.addY=self.addY+42 end
local function control(owner,x,y,w,h)
    local c=UI:new(x+20,y+owner.addY,w,h);owner.mainPanel:addChild(c)
    owner.mainPanel:addChild(UI:new(8,y+owner.addY,x,20));owner.mainPanel:insertNewLineOfButtons(c)
    owner.addY=owner.addY+h+8;return c
end
function MainOptions:addYesNo(x,y,w,h) local c=control(self,x,y,w,h);c.isTickBox=true;return c end
function MainOptions:addTickBox(x,y,w,h) local c=control(self,x,y,w,h);c.isTickBox=true;return c end
function UI:addOption(text) self.options[#self.options+1]={text=text};return #self.options end
function MainOptions:addTextEntry(x,y,text,value) local c=control(self,x,y,300,26);c.Type="ISTextEntryBox";c.text=value;return c end
function MainOptions:addCombo(x,y,w,h,text,values,selected) local c=control(self,x,y,w,h);c.isCombobox=true;c.selected=selected;return c end
function MainOptions:addColorButton(x,y,text,color,onclick) local c=control(self,x,y,50,26);c.backgroundColor=color;return c end
function MainOptions:addButton(x,y,text) return control(self,x,y,200,26) end
function MainOptions:addSlider(x,y,w,text,min,max,step,value) local c=control(self,x,y,w,26);c.Type="ISSliderPanel";c.value=value;c.label=UI:new();return c end
function MainOptions:onModColorPick(button) self:addChild(button.colorPicker) end
function MainOptions:onOptionMouseDown(button) self.backCalled=button end
function newOptions(width)
    local owner=MainOptions:new(0,0,width,700);owner:instantiate();owner.gameOptions=GameOptions:new()
    owner.tabs=UI:new(0,40,width,540);owner.tabs.tabHeight=20;owner.tabs.viewList={};owner:addChild(owner.tabs)
    owner.backButton={};return owner
end

ISTickBox=UI:derive("ISTickBox")
function ISLabel:new(x,y,h,text) local o=UI.new(self,x,y,200,h);o.text=text;return o end
ISContextMenu={}
function ISContextMenu.get() local m={options={}};setmetatable(m,{__index=ISContextMenu});lastContext=m;return m end
function ISContextMenu:getNew() return ISContextMenu.get() end
function ISContextMenu:addOption(text,target,fn,...) local o={text=text,target=target,fn=fn,args={...}};self.options[#self.options+1]=o;return o end
function ISContextMenu:addSubMenu(option,sub) option.sub=sub end

function UI:getActiveViewIndex() return self.activeIndex or 1 end
function UI:getActiveView() return self.viewList[self:getActiveViewIndex()].view end
function UI:activateView(name) for i,v in ipairs(self.viewList) do if v.name==name then self.activeIndex=i;return end end end
function MainOptions:onJoypadBeforeDeactivate() self.deactivated=true end
