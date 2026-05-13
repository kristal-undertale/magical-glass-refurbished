local LightBullet, super = Class(Bullet)

function LightBullet:init(x, y, texture)
    super.init(self, x, y, texture)
    
    self.destroy_on_hit = "alt"
    self.layer = LIGHT_BATTLE_LAYERS["bullets"]
    self.can_collide_while_not_defending = false
end

function LightBullet:onCollide(soul)
    if Game.battle:getState() == "DEFENDING" or self.can_collide_while_not_defending then
        local moving = soul.moving_x ~= 0 or soul.moving_y ~= 0
        if self:getType() == "green" then
            self:onHeal(soul)
            self.destroy_on_hit = true
        end
        
        if self:getType() == "blue" and moving or self:getType() == "orange" and not moving or not TableUtils.contains({"blue", "orange"}, self:getType()) then
            if soul.inv_timer == 0 then
                self:onDamage(soul)
                if self.destroy_on_hit then
                    self:remove()
                end
            elseif self.destroy_on_hit == true then
                self:remove()
            end
        end
    end
end

return LightBullet