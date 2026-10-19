require "OptionScreens/MainOptions"
require "MSF/UI"
local F=ModSettingsFolders
function F.install()
    if not MainOptions or MainOptions.addModOptionsPanel==F.wrapper then return end
    local previous=MainOptions.addModOptionsPanel
    F.wrapper=function(self)
        if self.msfBuilding then return previous(self) end
        local loaded,state=pcall(F.Store.load)
        if not loaded or F.Store.blocked then
            print("[ModSettingsFolders] native settings retained: layout could not be loaded")
            return previous(self)
        end
        local width=self:getWidth()
        local nav=math.min(260,math.max(190,math.floor(width*.22)))
        local comboWidth=45*(getCore():getOptionFontSizeReal()+1)+60
        local minimum=math.max(700,math.ceil((comboWidth*3+40)*1.5))
        local compact=width-nav-8<minimum
        self.msfBuilding=true
        local ok,capture,reason=pcall(F.Capture.build,self,previous,compact and width or width-nav-8)
        self.msfBuilding=nil
        if not ok then error(capture) end -- Original builder errors remain visible; the temporary hooks were restored.
        if not capture then print("[ModSettingsFolders] native settings retained: "..tostring(reason));return end
        local attached,controller=pcall(F.UI.attach,self,capture,nav,compact)
        if not attached then
            -- Keep every original control usable if the additional navigation fails.
            F.UI.detach(self);F.Capture.release(capture)
            print("[ModSettingsFolders] folder navigation unavailable: "..tostring(controller))
        elseif not controller then
            F.Capture.release(capture);capture.page:setWidth(width)
        end
    end
    MainOptions.addModOptionsPanel=F.wrapper
    if not F.colorWrapped then
        F.colorWrapped=true
        local original=MainOptions.onModColorPick
        MainOptions.onModColorPick=function(self,button)
            original(self,button)
            local controller=self.msfController
            if controller and button.parent==controller.page and button.colorPicker then
                local picker=button.colorPicker
                local x=button:getAbsoluteX()-self:getAbsoluteX()
                local y=button:getAbsoluteY()-self:getAbsoluteY()+button:getHeight()+1
                picker:setX(math.max(0,math.min(x,self:getWidth()-picker:getWidth())))
                picker:setY(math.max(0,math.min(y,self:getHeight()-picker:getHeight())))
            end
        end
    end
end
F.install()
Events.OnGameBoot.Add(F.install)
Events.OnMainMenuEnter.Add(F.install)
