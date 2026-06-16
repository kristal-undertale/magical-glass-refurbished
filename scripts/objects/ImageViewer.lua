---@class ImageViewer : Sprite
---@overload fun(...) : ImageViewer
local ImageViewer, super = Class(Sprite)

---@param sprite string
---@param x number
---@param y number
function ImageViewer:init(sprite, x, y)
    super.init(self, sprite, x, y)
    
    self.x = x or 0
    self.y = y or 0

    self:setParallax(0)
    self.draw_children_below = 0
    self:setScale(2)
end

---@param key string
function ImageViewer:onKeyPressed(key)
    if Input.isConfirm(key) or Input.isCancel(key) then
        self:remove()
        Game.world:closeMenu()
    end
end

return ImageViewer