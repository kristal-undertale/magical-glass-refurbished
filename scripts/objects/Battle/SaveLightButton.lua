---@class SaveButton : LightActionButton
---@overload fun(...) : SaveButton
local SaveButton, super = Class(LightActionButton)

function SaveButton:init()
    super.init(self, "save")
end

function SaveButton:update()
    super.update(self)
    
    if not self.disabled then
        self:setColor(ColorUtils.HSLToRGB(Kristal.getTime() / 0.75 % 1, 1, 0.69))
    end
end

return SaveButton