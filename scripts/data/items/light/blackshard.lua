local item, super = Class("light/blackshard", true)

function item:init()
    super.init(self)
    
    -- Display name
    self.short_name = "BlkShard"
    
    self.can_sell = false
    
    self.light_bolt_direction = "random"
    self.light_bolt_speed_multiplier = 1.5
    self.light_attack_crit_multiplier = 3.3
end

function item:onToss()
    if Game:getConfig("canTossLightWeapons") then
        Game.world:showText({
            "* (You didn't quite understand\nwhy...)",
            "* (But, the thought of discarding\nit felt very wrong.)"
        })
        return false
    else
        return super.onToss(self)
    end
end

-- function item:onLightAttack(battler, enemy, damage, stretch, crit)
    -- if crit then
        -- Assets.playSound("bigcut")
        -- local sprite = Sprite()
        -- sprite:setAnimation({"effects/lightattack/hyperfoot", 6 / 30, true, frames = {"4-6"}})
        -- sprite:setColor(COLORS.red)
        -- sprite:setPosition(enemy:getRelativePos(0, -enemy.height / 2))
        -- Game.battle.timer:tween(3, sprite, {alpha = 0}, "out-quart")
        -- Game.battle.timer:doWhile(function() return sprite.alpha >= 0.1 end, function()
            -- Game.battle:shakeAttackSprite(sprite, 1)
        -- end, function()
            -- sprite:remove()
        -- end)

        -- Game.battle:addChild(sprite)
    -- end
    -- return super.onLightAttack(self, battler, enemy, damage, stretch, crit)
-- end

function item:getAttackSprite(battler, enemy, points)
    return "effects/attack/shard"
end

return item