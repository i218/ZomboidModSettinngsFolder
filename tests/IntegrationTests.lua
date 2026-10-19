local function own(o,key) for k,v in pairs(o) do if k==key then return v end end end
local F=ModSettingsFolders
local native=MainOptions.addModOptionsPanel
local builds=0
MainOptions.addModOptionsPanel=function(owner) builds=builds+1;native(owner);owner.extensionRan=true end
F.install() -- chain an independently installed wrapper, without duplicate form creation
local a=PZAPI.ModOptions:create('alpha','Same display name')
local b=PZAPI.ModOptions:create('beta','Same display name')
local c=PZAPI.ModOptions:create('empty','Empty section')
a:addTitle('Title');a:addDescription('Description');a:addSeparator()
local changed=0
local tick=a:addTickBox('tick','Tick',false);tick.onChangeApply=function() changed=changed+1 end
local text=a:addTextEntry('text','Text','original')
local combo=a:addComboBox('combo','Combo');combo:addItem('One',true);combo:addItem('Two')
local slider=a:addSlider('slider','Slider',0,100,1,50)
local color=a:addColorPicker('color','Color',1,.5,0,1)
local key=a:addKeyBind('key','Key',12)
local multi=a:addMultipleTickBox('multi','Multi');multi:addTickBox('first',true);multi:addTickBox('second',false)
local target={};local clicked=0
local button=a:addButton('button','Button',nil,function(t,control,arg) assert(t==target and arg==42);clicked=clicked+1 end,target,42)
b:addTickBox('other','Other',true)
local owner=newOptions(1280);owner:addModOptionsPanel()
assert(builds==1 and owner.extensionRan and owner.msfController)
local ui=owner.msfController;assert(owner.width==1280 and own(owner,'getWidth')==nil and own(owner,'addHorizontalLine')==nil)
assert(#ui.capture.groups==3 and #owner.gameOptions.options==7)
assert(owner.tabs.viewList[1].view==ui.host and ui.page.parent==ui.host)
assert(ui.page.childrenInOrder[1].setVisible==UI.setVisible) -- scrollbar excluded
owner.gameOptions:toUI()
local tickControl=tick.element;local keyElement=key.element;local gameOption=owner.gameOptions.options[1]
tickControl:setSelected(1,true);text.element:setText('unsaved');combo.element.selected=2;slider.element:setCurrentValue(75)
color.element.backgroundColor={r=.2,g=.3,b=.4,a=1};keyElement.keyCode=73;multi.element:setSelected(2,true)
for i=1,3 do ui:select({kind='section',id='beta'});ui:select({kind='section',id='alpha'}) end
assert(builds==1 and tick.element==tickControl and key.element==keyElement and owner.gameOptions.options[1]==gameOption)
assert(tickControl:isSelected(1) and text.element:getText()=='unsaved' and combo.element.selected==2 and slider.element.value==75)
assert(not tick.value and text.value=='original' and changed==0)
-- A hidden group cannot be made visible by another mod's dynamic callback.
ui:select({kind='section',id='beta'});tickControl:setVisible(true);assert(not tickControl:getIsVisible())
ui:select({kind='section',id='alpha'});assert(tickControl:getIsVisible())
tickControl:setVisible(false);ui:select({kind='all'});assert(not tickControl:getIsVisible())
tickControl:setVisible(true)
owner.gameOptions:apply();assert(tick.value and text.value=='unsaved' and combo.selected==2 and slider.value==75 and changed==1)
assert(multi.values[2].value and color.color.r==.2)
owner.gameOptions:apply();assert(changed==1)
button.element.onclick(button.element.target,button.element,unpack(button.element.onClickArgs));assert(clicked==1)
PZAPI.ModOptions:save();assert(files['ModOptions.ini']:find('keybind|alpha|key|73',1,true))
local folder=assert(F.Model.create(ui.state,'Visual'))
ui:move('alpha',folder);assert(ui.state.members.alpha==folder)
a.name='Renamed display';ui:refresh();assert(ui.state.members.alpha==folder)
ui:context({kind='section',id='alpha'},10,10)
local menu=lastContext -- submenu is last created context
assert(#menu.options==2);menu.options[1].fn(menu.options[1].target,unpack(menu.options[1].args))
assert(not ui.state.members.alpha)
local saved=files[F.Store.file];ui:select({kind='section',id='beta'});assert(files[F.Store.file]==saved)
owner:onModColorPick(color.element);assert(color.element.colorPicker.parent==owner)
assert(color.element.colorPicker.x==color.element:getAbsoluteX()-owner:getAbsoluteX())
-- A narrow screen keeps the native full-width form behind a navigation toggle.
local small=newOptions(800);small:addModOptionsPanel();assert(small.msfController.compact)
local compact=small.msfController;assert(compact.page:getWidth()==800 and compact.page:getIsVisible())
compact.toggle.onclick(compact.toggle.target);assert(compact.nav:getIsVisible() and not compact.page:getIsVisible())
compact:select({kind='section',id='alpha'});assert(compact.page:getIsVisible() and not compact.nav:getIsVisible())
local joy={};compact.host:onGainJoypadFocus(joy);assert(joy.focus==compact.tree)
compact:select({kind='folder',id=folder});assert(compact.tree.items[compact.tree.selected].item.id==folder)
local collapsed=F.Model.find(compact.state,folder).collapsed
compact.tree:onJoypadDirDown();assert(F.Model.find(compact.state,folder).collapsed==collapsed)
small.tabs.viewList[2]={name='another tab',view=UI:new()}
compact.page:onJoypadDown(Joypad.RBumper,joy);assert(small.tabs.activeIndex==2 and joy.focus==small.tabs.viewList[2].view)
compact.page:onJoypadBeforeDeactivate(joy);assert(small.deactivated)
small.tabs.activeIndex=1

compact.tree.selected=1;compact.tree:onJoypadDown(Joypad.AButton,joy);assert(joy.focus==compact.page)
compact.page:onJoypadDown(Joypad.BButton,joy);assert(joy.focus==compact.tree and compact.nav:getIsVisible())
-- Explicit detach restores form ownership, positions and visibility wrappers.
local group=compact.capture.groups[2];local oldY=group.nodes[1].y
F.UI.detach(small);assert(not small.msfController and small.tabs.viewList[1].view==compact.page)
assert(compact.page.parent==small.tabs and compact.page:getWidth()==800)
assert(group.nodes[1].ui:getY()==oldY and group.nodes[1].ui:getIsVisible())
testFontSize=2
local largeFont=newOptions(1100);largeFont:addModOptionsPanel();assert(largeFont.msfController.compact)
testFontSize=nil
-- Ambiguous IDs retain a usable native page and don't add the navigator.
PZAPI.ModOptions:create('beta','Duplicate ID')
local duplicate=newOptions(1280);duplicate:addModOptionsPanel();assert(not duplicate.msfController and duplicate.mainPanel:getWidth()==1280)
table.remove(PZAPI.ModOptions.Data)
-- Original builder failures must restore all temporary instance hooks.
local broken=newOptions(1280)
local ok=pcall(F.Capture.build,broken,function() error('original failure') end,900)
assert(not ok and broken.width==1280 and own(broken,'getWidth')==nil and own(broken,'addHorizontalLine')==nil and own(broken,'addPage')==nil)
-- Failure after native page reparenting rolls back to the native tab.
local oldRefresh=F.UI.refresh;F.UI.refresh=function() error('injected navigation failure') end
local rollback=newOptions(1280);rollback:addModOptionsPanel();F.UI.refresh=oldRefresh
assert(not rollback.msfController and rollback.tabs.viewList[1].view==rollback.mainPanel)
assert(rollback.mainPanel.parent==rollback.tabs and rollback.mainPanel:getWidth()==1280)
for _,child in pairs(rollback.mainPanel.children) do assert(child:getIsVisible()) end
print('PASS native form integration: all setting types, stable control identities, unsaved edits, apply callbacks, keybind save, duplicate names, dynamic visibility, context moves, compact navigation, gamepad focus, native fallback and error rollback')
