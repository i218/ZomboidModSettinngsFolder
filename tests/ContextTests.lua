local F=ModSettingsFolders
-- Reproduce the screenshot with the unmodified native getter, including a QOL-style wrapper.
local stock=ISContextMenu.get
local calls=0
ISContextMenu.get=function(...)
    calls=calls+1
    local results={pcall(stock,...)}
    if not results[1] then error(results[2],0) end
    return results[2]
end
assert(not pcall(ISContextMenu.get,0,10,10),'native null-player failure not reproduced')
calls=0
local controller=setmetatable({state=F.Model.new(),tree={}}, {__index=F.UI})
function controller:save() self.saved=true end
local folder=assert(F.Model.create(controller.state,'Visual'))
controller.state.members.alpha=folder
controller:context({kind='section',id='alpha'},10,20)
local root=controller.contextMenu
assert(calls==0 and root:getIsVisible() and root.parent==nil and root.origin==controller.tree)
local sub=assert(root:getSubMenu(root.options[3].subOption))
assert(not sub:getIsVisible() and sub.parent==root and sub.root==root)
assert(root:topmostMenuWithMouse(11,21)==root)
sub:setX(400);sub:setY(20);sub:setVisible(true)
assert(sub:topmostMenuWithMouse(401,21)==sub)
assert(sub:topmostMenuWithMouse(1000,1000)==nil)
sub.mouseOver=1;sub:onMouseUp(1,1)
assert(controller.saved and not controller.state.members.alpha,'unfiled callback failed')
assert(not root:getIsVisible() and not sub:getIsVisible(),'selection did not close menus')
controller:context({kind='folder',id=folder},50,50)
assert(root.removed and sub.removed,'reopening leaked menus')
root=controller.contextMenu
assert(#root.options==6,'folder actions missing')
root:onMouseDownOutside(1000,1000);assert(not root:getIsVisible())
JoypadState.players[1]={}
controller:context(nil,30,40)
root=controller.contextMenu;root:onJoypadDown(Joypad.BButton)
assert(not root:getIsVisible() and lastJoypadFocus==controller.tree,'gamepad focus not restored')
-- Even with a loaded-world context, settings must not touch it or the global getter.
function getPlayerContextMenu() error('world menu must remain untouched') end
controller:context({kind='section',id='alpha'},30,40)
root=controller.contextMenu;root:dispose()
assert(root.removed and root.instanceMap[1].removed and calls==0)
print('PASS native context menu: null-player baseline reproduced, section/folder menus, hit testing, callbacks, outside click, gamepad close, disposal and global menu isolation')
