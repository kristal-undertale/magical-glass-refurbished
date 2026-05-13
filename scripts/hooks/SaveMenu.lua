local SaveMenu, super = HookSystem.hookScript(SaveMenu)

function SaveMenu:update()
    if self.state == "MAIN" and Input.pressed("confirm") and self.selected_x == 2 and self.selected_y == 2 then
        if Game:getConfig("enableRecruits") and #Game:getAllRecruits(true) > 0 then
            Input.clear("confirm")
            self:remove()
            Game.world:closeMenu()
            Game.world:openMenu(RecruitMenu())
        end
    else
        super.update(self)
    end
end

function SaveMenu:draw()
    super.draw(self)

    if self.state == "MAIN" then
        if Game:getConfig("enableRecruits") and #Game:getAllRecruits(true) > 0 then
            Draw.setColor(PALETTE["world_text"])
        else
            Draw.setColor(PALETTE["world_gray"])
        end
        love.graphics.print("Recruits", 350, 260)
    end
end

return SaveMenu