require "ISUI/ISContextMenu"
-- Options are available before any player (and player context menu) exists.
-- Keep menu ownership local, including hit testing and submenu lookup.
local Menu=ISContextMenu:derive("MSF_ContextMenu")
ModSettingsFolders.ContextMenu=Menu
function Menu:getSubMenu(num)
    return self.root.instanceMap[num]
end
function Menu:topmostMenuWithMouse(x,y)
    local root=self.root
    local result
    local function contains(menu)
        return menu:getIsVisible() and x>=menu.x and x<menu.x+menu.width and y>=menu.y and y<menu.y+menu.height
    end
    if contains(root) then result=root end
    for _,menu in ipairs(root.instanceMap) do if contains(menu) then result=menu end end
    return result
end
function Menu:dispose()
    local root=self.root
    root:hideAndChildren()
    for _,menu in ipairs(root.instanceMap) do menu:removeFromUIManager() end
    root:removeFromUIManager()
end
function Menu:create(x,y,origin,parent)
    local menu=self:new(x,y,1,1,1.5)
    menu:initialise();menu:instantiate()
    menu.root=parent and parent.root or menu
    menu.parent=parent;menu.origin=origin;menu.player=0
    if not parent then menu.instanceMap={} end
    menu:setFontFromOption()
    menu.wantMouseEvents=true;menu.forceVisible=true;menu.visibleCheck=true
    menu:addToUIManager();menu:setVisible(parent==nil)
    if parent then
        local map=menu.root.instanceMap
        menu.subOptionNums=#map+1;map[menu.subOptionNums]=menu
    else
        menu.requestX=x;menu.requestY=y
        menu:setForceCursorVisible(true);menu:bringToTop()
    end
    return menu
end
return Menu
