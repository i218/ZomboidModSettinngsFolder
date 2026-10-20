ISPanel=UI:derive("ISPanel")
function getTexture() return {} end
function UI:setForceCursorVisible(value) self.forceCursor=value end
JoypadState={players={}}
function setJoypadFocus(player,ui) lastJoypadFocus=ui end
function getPlayerContextMenu() return nil end
local core=getCore()
core.getOptionContextMenuFont=function() return "Small" end
core.getGameMode=function() return "Sandbox" end
core.getOptionSingleContextMenu=function() return false end
function getCore() return core end
local text=getTextManager()
text.getFontFromEnum=function() return {getLineHeight=function() return 16 end} end
text.MeasureStringX=function(_,font,value) return #value*8 end
function getTextManager() return text end
ModSettingsFolders={Store={},Capture={}}
