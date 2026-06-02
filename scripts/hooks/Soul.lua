local Soul, super = HookSystem.hookScript(Soul)

function Soul:init(x, y, color)
    super.init(self, x, y, color)

    self.speed = Game.battle.soul_speed
    if not Kristal.getLibConfig("magical-glass", "light_world_dark_battle_tension") and Game:isLight() then
        self.graze_collider.collidable = false
    end
end

function Soul:update()
    self.speed = Game.battle.soul_speed

    super.update(self)
end

return Soul
