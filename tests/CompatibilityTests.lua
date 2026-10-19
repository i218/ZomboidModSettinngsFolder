local F=ModSettingsFolders
local stock=MSF_StockBuilder
assert(stock,'stock form builder fixture missing')
local savedData,savedDict=PZAPI.ModOptions.Data,PZAPI.ModOptions.Dict
PZAPI.ModOptions.Data={};PZAPI.ModOptions.Dict={}
local first=PZAPI.ModOptions:create('compat.first','First section')
first:addTickBox('check','First',true)
local moved=PZAPI.ModOptions:create('compat.custom','Separate tab')
moved:addTickBox('custom','Custom',false)
local last=PZAPI.ModOptions:create('compat.last','Last section')
last:addTextEntry('text','Last','keep')
local all=PZAPI.ModOptions.Data
local function customPage(screen,options)
    screen:addPage('Separate custom tab');screen.addY=0
    screen:addHorizontalLine(8,getText(options.name))
    screen.customPage=screen.mainPanel;screen.customBuildWidth=screen:getWidth()
    screen.customControl=screen:addYesNo(200,8,26,26,'Custom')
end
local function filteredBuilder(screen)
    local others={first,last};PZAPI.ModOptions.Data=others
    stock(screen);PZAPI.ModOptions.Data=all
    customPage(screen,moved)
end
local function check(builder,label,customFirst)
    local owner=newOptions(1280)
    local capture,reason=F.Capture.build(owner,builder,1012)
    assert(capture,label..': '..tostring(reason))
    assert(#capture.groups==2 and capture.groups[1].id==first.modOptionsID and capture.groups[2].id==last.modOptionsID,label..': effective registry mismatch')
    local expectedMain=customFirst and capture.page or owner.customPage
    assert(capture.page~=owner.customPage and owner.mainPanel==expectedMain,label..': wrong page captured or mainPanel changed')
    assert(owner.customBuildWidth==1280 and owner.customPage:getWidth()==1280,label..': custom tab inherited narrowed width')
    assert(owner.width==1280,label..': owner width not restored')
    local controller=assert(F.UI.attach(owner,capture,260,false))
    assert(controller.create and controller.create:getIsVisible() and controller.tree:getIsVisible(),label..': folder controls unavailable')
    local customY=owner.customControl:getY()
    controller:select({kind='section',id=first.modOptionsID})
    assert(owner.customControl:getIsVisible() and owner.customControl:getY()==customY,label..': custom tab affected by section switch')
    local rows=#controller.tree.items
    local oldPrompt=controller.prompt
    controller.prompt=function(self,id) self.testPromptOpened=true;assert(id==nil) end
    controller.create.onclick(controller.create.target)
    controller.prompt=oldPrompt
    assert(controller.testPromptOpened and #controller.tree.items==rows,label..': New folder button callback lost')
    F.UI.detach(owner)
    assert(owner.customPage:getWidth()==1280 and owner.mainPanel==expectedMain,label..': detach altered custom tab')
end
if MSF_ReferencePrefs then
    -- Optional real installed Project A-Life addPanels(), extracted by Test.ps1.
    local prefs=MSF_ReferencePrefs
    prefs.optionsId=moved.modOptionsID
    prefs.prepareSliderLabels=function() return {} end
    prefs.buildPage=customPage;prefs.syncOptions=function() end
    MainOptions.style={}
    check(function(screen) prefs.addPanels(screen,stock) end,'installed Project A-Life addPanels')
    print('PASS installed Project A-Life addPanels: folder navigation attaches alongside its separate tab')
end
check(filteredBuilder,'filtered registry and appended tab')
check(function(screen)
    customPage(screen,moved)
    PZAPI.ModOptions.Data={first,last};stock(screen);PZAPI.ModOptions.Data=all
end,'custom tab before native Mods page',true)
-- load() may register sections before the native addPage(), after capture begins.
local originalLoad=PZAPI.ModOptions.load
local late
PZAPI.ModOptions.Data={first}
PZAPI.ModOptions.load=function(api)
    originalLoad(api)
    if not late then late=api:create('compat.late','Late registration');late:addTickBox('late','Late',true) end
end
local lateOwner=newOptions(1280)
local lateCapture=assert(F.Capture.build(lateOwner,stock,1012))
assert(#lateCapture.groups==2 and lateCapture.groups[2].id=='compat.late','load-time registry additions were lost')
F.Capture.release(lateCapture);PZAPI.ModOptions.load=originalLoad
PZAPI.ModOptions.Data=all

PZAPI.ModOptions.Data=savedData;PZAPI.ModOptions.Dict=savedDict
print('PASS split-tab compatibility: filtered/live registry, separate pages, native width, folder button, selection isolation and load-time registration')
