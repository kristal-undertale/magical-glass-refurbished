local GreenSoul, super = Class(Soul)

function GreenSoul:init(x, y, undertale)
    super.init(self, x, y)

    self.undertale = undertale ~= false
    if self.undertale then
        self.color = {0, 192 / 255, 0, 1}
        
        -- In Kristal, the soul's origin is the top-left of its center 4 pixels
        -- In Deltarune, the soul's origin is the bottom-right (at least for the purposes of the green soul mode box radius)
        self.soul_origin_adjust_x = 0
        self.soul_origin_adjust_y = 0
        
        self.facing = math.rad(270) -- start facing upwards
    else
        self:setColor(0, 162 / 255, 0, 1)
        
        self.soul_origin_adjust_x = 1
        self.soul_origin_adjust_y = 1
        
        self.facing = math.rad(-90) -- start facing upwards
    end
    self.graze_collider.collidable = false -- disable grazing

    self.diagonal = false
    self.wide_blocker = self.undertale -- if true, the blocker covers the adjacent diagonals as well (a mechanic I've seen sometimes)

    -- turning
    self.turning_from = 0
    self.turning_left = 0
    self.turning_len = 3 / 30

    -- parrying
    self.enable_parry = not self.undertale
    self.parry_left = 0
    self.parry_len = 3 / 30
    self.parry_ease_from_info = nil -- {x, y}
    self.parry_cooldown_left = 0
    self.parry_cooldown_len = nil
    if self.parry_cooldown_len then
        self.parry_cooldown_len = self.parry_cooldown_len / 30
    end

    -- crit window
    self.crit_window_left = 0
    self.crit_window_len_normal = 4 / 30
    self.crit_window_len_diagonal = 6 / 30
    self.enable_crit = not self.undertale

    -- transition to/from diagonal
    self.diagonal_transition_from_box_radius = self:calculateBoxRadius()
    self.diagonal_transition_from_side_len = self:calculateCardinalSideLength()
    self.diagonal_transition_from_blocker_po = nil -- {x,y,ox,oy} aka pos and origin
    self.diagonal_transition_from_blocker_scale = self:calculateBlockerScale()
    self.diagonal_transition_left = 0
    self.diagonal_transition_len = 10 / 30

    -- highlight red on a hit
    self.hit_flash_left = 0
    self.hit_flash_len = 3 / 30

    -- highlight white on a crit
    self.crit_flash_left = 0
    self.crit_flash_len = 3 / 30

    self.blocker = nil
    self.blocker_crit_overlay = nil
    if self.undertale then
        self:setBlockerSprite("effects/greensoul/spear_blocker")
    else
        self:setBlockerSprite("effects/greensoul/axe_blocker")
    end

    self.tp_gain_mult_regular = 0.3125
    self.tp_gain_mult_crit = 0.625
    self.block_wt_reduction = false
    self.blocker_collider_depth = 0.25
    self.close_radius = 0.5
    self.clear_parry_cooldown_on_success = true

    self:updateMiscColliders()
end

-- Change the blocker sprite
function GreenSoul:setBlockerSprite(sprite_name)
    self.blocker_sprite = sprite_name

    if self.blocker ~= nil then
        self.blocker:remove()
        self.blocker = self:createBlocker()
        self.blocker_crit_overlay = nil

        self.diagonal_transition_from_blocker_po = nil
        self.parry_ease_from_info = nil
    end
end

-- Set whether the box is diagonal or not
function GreenSoul:setDiagonal(diagonal)
    if diagonal == self.diagonal then
        return
    end

    self.diagonal_transition_from_box_radius = self:calculateBoxRadius()
    self.diagonal_transition_from_side_len = self:calculateCardinalSideLength()

    if self.blocker ~= nil then
        self.diagonal_transition_from_blocker_po = {
            x = self.blocker.x,
            y = self.blocker.y,
            bsox = self.blocker.scale_origin_x,
            bsoy = self.blocker.scale_origin_y,
            brox = self.blocker.rotation_origin_x,
            broy = self.blocker.rotation_origin_y
        }
        self.diagonal_transition_from_blocker_scale = {
            self.blocker.scale_x,
            self.blocker.scale_y
        }

        -- If blocker is present, play mode change sound (blocker presence means we're fully visible i think)
        self:playModeChangeSound()
    end

    self.diagonal = diagonal
    self.diagonal_transition_left = self.diagonal_transition_len
end

-- Enable/disable wide blocker hitbox. (you are required to change the sprite manually)
function GreenSoul:setWideBlockerHitbox(wide)
    if wide == self.wide_blocker then
        return
    end

    self.wide_blocker = wide

    if self.blocker ~= nil then
        self.blocker:remove()
        self.blocker = self:createBlocker()
        self.blocker_crit_overlay = nil

        self.diagonal_transition_from_blocker_po = nil
        self.parry_ease_from_info = nil
    end
end

function GreenSoul:calculateBoxRadius()
    if self.diagonal and not self.undertale then
        return 33 -- yes, 33. I measured.
    else
        return 28
    end
end

-- calculates the length of the cardinal sides
function GreenSoul:calculateCardinalSideLength()
    if self.diagonal then
        return 32 -- in Deltarune: b/r sides are 2px longer than t/l. This behaviour occurs in Kristal/love2d as well, so no adjustment is needed.
    else
        return self:calculateBoxRadius()
    end
end

function GreenSoul:calculateDiagonalSideLength()
    local box_radius = self:calculateBoxRadius()
    local side_len_ch = self:calculateCardinalSideLength() / 2

    local p1 = {side_len_ch, -box_radius}
    local p2 = {box_radius, -side_len_ch}
    local dx = p2[1] - p1[1]
    local dy = p2[2] - p1[2]
    local hypotenuse = math.sqrt((dx * dx) + (dy * dy))

    return hypotenuse
end

function GreenSoul:calculateBlockerPosInfo()
    local box_radius = self:calculateBoxRadius()
    local blocker_sprite = Assets.getTexture(self.blocker_sprite)

    local soul_origin_x = self.soul_origin_adjust_x -- soul origin (relative to self)
    local soul_origin_y = self.soul_origin_adjust_y
    local right_edge = soul_origin_x + box_radius + 4 -- blocker edges (relative to self)
    local left_edge = right_edge - blocker_sprite:getWidth()
    local top_edge = soul_origin_y - (blocker_sprite:getHeight() / 2)

    -- fix misalignment issues (should be inline with the box on up/left sides, out by 1 on down/right)
    if not self.diagonal then
        top_edge = top_edge - 1
    else
        top_edge = top_edge + 1
    end

    local blocker_origin_x = soul_origin_x - left_edge -- blocker origin (relative to blocker?)
    local blocker_origin_y = soul_origin_y - top_edge

    return {
        x = left_edge,
        y = top_edge,
        ox = blocker_origin_x,
        oy = blocker_origin_y,
        right_edge = right_edge,
        sox = soul_origin_x,
        soy = soul_origin_y
    }
end

function GreenSoul:calculateBlockerScale()
    if self.diagonal then -- shrink blocker if diagonal
        if self.wide_blocker then
            return {1, 1} -- don't shrink wide blockers
        else
            return {1, 36 / 55}
        end
    else
        return {1, 1}
    end
end

function GreenSoul:createBlocker()
    local box_radius = self:calculateBoxRadius()
    local blocker_sprite = Assets.getTexture(self.blocker_sprite)

    local posInfo = self:calculateBlockerPosInfo()
    local blocker = Sprite(blocker_sprite)
    Game.battle:addChild(blocker)

    blocker:setLayer(BATTLE_LAYERS["above_bullets"]) -- draw above the box
    blocker.draw_children_above = 1 -- ensure crit effect can be drawn above the blocker

    blocker:setRotationOriginExact(posInfo.ox, posInfo.oy) -- rotate around center
    blocker:setScaleOriginExact(posInfo.ox, posInfo.oy) -- scale around center

    blocker.physics.match_rotation = true

    local blockerScale = self:calculateBlockerScale()
    blocker:setScale(blockerScale[1], blockerScale[2])

    -- create blocker collider
    blocker.collider = self:createBlockerCollider(blocker, posInfo)
    self:updateLaneColliders(blocker, posInfo)
    
    self.circle = Sprite("effects/greensoul/circle")
    self.circle:setLayer(blocker:getLayer() + 0.5)
    if self.undertale then
        Game.battle:addChild(self.circle)
    end

    return blocker
end

function GreenSoul:createBlockerCollider(parent, posInfo, depth, breadth)
    depth = depth or self.blocker_collider_depth
    breadth = breadth or 1

    -- lane collider (determines whether projectiles are in the correct lane)
    local box_radius = self:calculateBoxRadius() + 7
    local blocker_origin_x = posInfo.ox
    local blocker_origin_y = posInfo.oy

    local front_points = nil
    local side_len_ch = self:calculateCardinalSideLength() / 2 -- side length Cardinal Halved

    if self.diagonal then
        local side_len_half = math.min(side_len_ch, self:calculateDiagonalSideLength())
        front_points = {
            {blocker_origin_x + box_radius, blocker_origin_y - side_len_half * breadth},
            {blocker_origin_x + box_radius, blocker_origin_y + side_len_half * breadth}
        }

        if self.wide_blocker then
            -- correct front points (for non-1 breadth)
            if breadth ~= 1 then
                front_points[1][2] = front_points[1][2] + side_len_half * breadth - side_len_half
                front_points[2][2] = front_points[2][2] - side_len_half * breadth + side_len_half
            end

            -- add left/right extensions
            local breadth_offset = side_len_half * (1 - breadth) * 0.5
            table.insert(front_points, 1, {
                blocker_origin_x + side_len_ch + breadth_offset,
                blocker_origin_y - box_radius + breadth_offset
            }) -- cw of the top side
            table.insert(front_points, 4, {
                blocker_origin_x + side_len_ch + breadth_offset,
                blocker_origin_y + box_radius - breadth_offset
            }) -- ccw of the bottom side
        end
    else
        front_points = {
            {blocker_origin_x + box_radius, blocker_origin_y - box_radius * breadth},
            {blocker_origin_x + box_radius, blocker_origin_y + box_radius * breadth}
        }
    end

    local points = {}

    -- copy front points
    for _, pt in ipairs(front_points) do
        table.insert(points, pt)
    end

    -- create back points
    for _, pt in ipairs(front_points) do
        table.insert(points, #front_points + 1, {
            Utils.lerp(blocker_origin_x, pt[1], 1 - depth),
            Utils.lerp(blocker_origin_y, pt[2], 1 - depth)
        })
    end

    -- return collider
    return PolygonCollider(parent, points)
end

function GreenSoul:updateLaneColliders(blocker, posInfo)
    blocker.ffr_lane_colliders = self:createBlockerCollider(blocker, posInfo, 1, 0.25)
end

function GreenSoul:updateMiscColliders()
    local box_radius = self:calculateBoxRadius()

    -- box collider. used for the first-frame rule (among other things)
    local box_verts = self:calculateBoxVertices()
    local box_verts_packed = {} -- CAN YOU MAKE YOUR MIND UP ON EITHER {{x,y},...} or {x1,y1,...} OH MY GOD

    for i = 1, #box_verts, 2 do
        table.insert(box_verts_packed, {box_verts[i], box_verts[i + 1]})
    end

    self.box_collider = PolygonCollider(self, box_verts_packed)

    -- close collider (formerly the way too close collider from when there were two)
    self.close_collider = CircleCollider(self, 0, 0, box_radius * self.close_radius)
    -- self.close_collider.collidable = self.close_radius > 0
end

function GreenSoul:onRemove(parent)
    if self.blocker ~= nil then
        self.blocker:remove()
    end
    if self.circle ~= nil then
        self.circle:remove()
    end

    super.onRemove(self, parent)
end

function GreenSoul:update()
    -- Hide blocker sprite if transitioning
    if self.transitioning then
        if self.blocker ~= nil then
            self.blocker:remove()
            self.blocker = nil
            self.blocker_crit_overlay = nil
            for _, particle in ipairs(Game.stage:getObjects(GreenSoulCritParticle)) do
                particle:remove()
            end
        end
        if self.circle ~= nil then
            self.circle:remove()
            self.circle = nil
        end

        super.update(self)
        
        return
    end

    -- Create blocker (if it's not there)
    if self.blocker == nil then
        self.blocker = self:createBlocker()

        -- (play turn sound since it's probably the start of the defend section and for some reason the turn sound plays at the start of each turn)
        self:playTurnSound()
    end
    
    local posInfo = self:calculateBlockerPosInfo()
    self.blocker:setPosition(self:getRelativePos(posInfo.x, posInfo.y))
    self.circle:setPosition(self:getRelativePos(-self.circle.width / 2, -self.circle.height / 2))
    
    if self.undertale and self.facing == math.rad(270) then
        self.facing = math.rad(-90)
    end

    -- update sprite and colour
    if self.hit_flash_left > 0 then
        self.hit_flash_left = self.hit_flash_left - (1 * DT)
        self.blocker:setSprite(self.blocker_sprite .. "_hit")
    else
        self.blocker:setSprite(self.blocker_sprite)
    end

    if self.crit_flash_left > 0 then
        self.crit_flash_left = self.crit_flash_left - (1 * DT)

        if self.blocker_crit_overlay == nil then
            self.blocker_crit_overlay = Sprite(self.blocker_sprite .. "_crit", 0, 0)
            self.blocker:addChild(self.blocker_crit_overlay)
            self.blocker_crit_overlay:setLayer(1)
        end

        self.blocker_crit_overlay.alpha = Utils.ease(
            1,
            0,
            1 - (self.crit_flash_left / self.crit_flash_len),
            "inQuad"
        )
    else
        if self.blocker_crit_overlay ~= nil then
            self.blocker_crit_overlay.alpha = 0
        end
    end

    -- update rotation and parrying
    local is_critical = false

    if self.turning_left > 0 then
        self.turning_left = self.turning_left - (1 * DT)

        local ease_from = self.turning_from
        local alt_ease_from_lo = self.turning_from - math.rad(360)
        local alt_ease_from_hi = self.turning_from + math.rad(360)

        if math.abs(self.facing - alt_ease_from_lo) < math.abs(self.facing - ease_from) then
            -- rotate from the closer side
            ease_from = alt_ease_from_lo
        end

        if math.abs(self.facing - alt_ease_from_hi) < math.abs(self.facing - ease_from) then
            -- rotate from the closer side
            ease_from = alt_ease_from_hi
        end

        self.blocker.rotation = Utils.ease(
            ease_from,
            self.facing,
            1 - (self.turning_left / self.turning_len),
            "outQuad"
        )
    else
        self.blocker.rotation = self.facing
    end

    if self.parry_left > 0 then
        self.parry_left = self.parry_left - DT
        local ease_t = 1 - (self.parry_left / self.parry_len)

        -- update blocker pos
        local posInfo_to = self:calculateBlockerPosInfo()
        local x, y = self:getRelativePos()
        posInfo_to.x, posInfo_to.y = posInfo_to.x + x, posInfo_to.y + y
        
        if self.blocker ~= nil and self.parry_ease_from_info ~= nil then
            self.blocker.x = Utils.ease(self.parry_ease_from_info.x, posInfo_to.x, ease_t, "linear")
            self.blocker.y = Utils.ease(self.parry_ease_from_info.y, posInfo_to.y, ease_t, "linear")
        end

        if not (self.parry_left > 0) then
            -- end of anim
            -- fix blocker pos
            if self.blocker ~= nil and self.parry_ease_from_info ~= nil then
                self.blocker.x = posInfo_to.x
                self.blocker.y = posInfo_to.y
                self.parry_ease_from_info = nil
            end
        end
    end

    if self.parry_cooldown_left > 0 then
        self.parry_cooldown_left = self.parry_cooldown_left - DT
    end

    if self.crit_window_left > 0 and self.enable_crit then
        self.crit_window_left = self.crit_window_left - DT
        is_critical = true
    end

    -- update other effects
    if self.diagonal_transition_left > 0 then
        self.diagonal_transition_left = self.diagonal_transition_left - (1 * DT)

        local ease_t = 1 - (self.diagonal_transition_left / self.diagonal_transition_len)

        if self.blocker ~= nil then
            -- update blocker scale
            local ease_scale_from = self.diagonal_transition_from_blocker_scale
            local ease_scale_to = self:calculateBlockerScale()
            local scale_x = Utils.ease(ease_scale_from[1], ease_scale_to[1], ease_t, "inQuad")
            local scale_y = Utils.ease(ease_scale_from[2], ease_scale_to[2], ease_t, "inQuad")
            self.blocker:setScale(scale_x, scale_y)

            -- update blocker origin/pos
            local posInfo_to = self:calculateBlockerPosInfo()
            local x, y = self:getRelativePos()
            posInfo_to.x, posInfo_to.y = posInfo_to.x + x, posInfo_to.y + y

            if self.diagonal_transition_from_blocker_po ~= nil then
                local posInfo_from = self.diagonal_transition_from_blocker_po

                local x = Utils.ease(posInfo_from.x, posInfo_to.x, ease_t, "inQuad")
                local y = Utils.ease(posInfo_from.y, posInfo_to.y, ease_t, "inQuad")
                self.blocker.x = x
                self.blocker.y = y

                local brox = Utils.ease(posInfo_from.brox, posInfo_to.ox, ease_t, "inQuad")
                local broy = Utils.ease(posInfo_from.broy, posInfo_to.oy, ease_t, "inQuad")
                self.blocker:setRotationOriginExact(brox, broy)

                local bsox = Utils.ease(posInfo_from.bsox, posInfo_to.ox, ease_t, "inQuad")
                local bsoy = Utils.ease(posInfo_from.bsoy, posInfo_to.oy, ease_t, "inQuad")
                self.blocker:setScaleOriginExact(bsox, bsoy)
            end

            if not (self.diagonal_transition_left > 0) then
                -- end of anim
                -- update colliders
                self.blocker.collider = self:createBlockerCollider(self.blocker, posInfo_to)
                self:updateLaneColliders(self.blocker, posInfo_to)
                self:updateMiscColliders()

                -- fix blocker pos
                if self.diagonal_transition_from_blocker_po ~= nil then
                    self.blocker.x = posInfo_to.x
                    self.blocker.y = posInfo_to.y
                    self.diagonal_transition_from_blocker_po = nil
                end
            end
        end
    end

    -- detect bullet collisions
    local blocked_bullets = {}

    Object.startCache()

    for _, bullet in ipairs(Game.stage:getObjects(Bullet)) do
        if bullet:collidesWith(self.blocker.collider) then
            -- blocked
            table.insert(blocked_bullets, bullet)
        end
    end

    Object.endCache()

    for _, bullet in ipairs(blocked_bullets) do
        local was_grazed_previously = bullet.grazed
        local preventDefault = bullet:onGreenDeflect(is_critical)

        if not preventDefault then
            self.hit_flash_left = self.hit_flash_len

            if is_critical then
                -- flash white
                self.crit_flash_left = self.crit_flash_len

                -- sparkles
                for i = 1, 3 do
                    local pxr = self.blocker.rotation + math.rad(MathUtils.round(MathUtils.random(-30, 30)))
                    local px = 36 * math.cos(pxr)
                    local pyr = self.blocker.rotation + math.rad(MathUtils.round(MathUtils.random(-30, 30)))
                    local py = 36 * math.sin(pyr)
                    local p = GreenSoulCritParticle(px, py)
                    p.physics.direction = self.blocker.rotation

                    self:addChild(p)
                end

                -- clear parry CD
                if self.parry_cooldown_len ~= nil
                    and self.parry_cooldown_left > 0
                    and self.clear_parry_cooldown_on_success
                then
                    self.parry_cooldown_left = 0
                end
            end

            -- give tp
            if bullet:canGraze() then
                local tp_mult = self.tp_gain_mult_regular

                if is_critical then -- give double TP for crits
                    tp_mult = self.tp_gain_mult_crit
                end

                Game:giveTension(bullet:getGrazeTension() * self.graze_tp_factor * tp_mult)

                if self.block_wt_reduction and Game.battle.wave_timer < Game.battle.wave_length - (1 / 3) then
                    Game.battle.wave_timer = Game.battle.wave_timer + ((bullet.time_bonus / 30) * self.graze_time_factor * tp_mult)
                end
            end
        end
    end

    -- And update superclass
    super.update(self)
end

function GreenSoul:doMovement()
    -- Keyboard input
    -- We update the direction if:
    --  A new direction has just been pressed (allowing us to rotate 4way / enter diagonal)
    --  Or if, (diagonal only), a direction is being held and a perpendicular direction has just been released (allowing us to leave diagonals)
    local target_dir = self.facing

    if Input.pressed("right") or (self.diagonal and Input.down("right") and (Input.released("up") or Input.released("down"))) then
        target_dir = math.rad(0)

        if self.diagonal then
            if Input.down("up") then
                target_dir = target_dir - math.rad(45)
            elseif Input.down("down") then
                target_dir = target_dir + math.rad(45)
            end
        end
    elseif Input.pressed("down") or (self.diagonal and Input.down("down") and (Input.released("left") or Input.released("right"))) then
        target_dir = math.rad(90)

        if self.diagonal then
            if Input.down("left") then
                target_dir = target_dir + math.rad(45)
            elseif Input.down("right") then
                target_dir = target_dir - math.rad(45)
            end
        end
    elseif Input.pressed("left") or (self.diagonal and Input.down("left") and (Input.released("up") or Input.released("down"))) then
        target_dir = math.rad(180)

        if self.diagonal then
            if Input.down("up") then
                target_dir = target_dir + math.rad(45)
            elseif Input.down("down") then
                target_dir = target_dir - math.rad(45)
            end
        end
    elseif Input.pressed("up") or (self.diagonal and Input.down("up") and (Input.released("left") or Input.released("right"))) then
        target_dir = math.rad(270)

        if self.diagonal then
            if Input.down("left") then
                target_dir = target_dir - math.rad(45)
            elseif Input.down("right") then
                target_dir = target_dir + math.rad(45)
            end
        end
    end

    local refill_crit_window = false

    if target_dir ~= self.facing then
        self.turning_from = self.blocker.rotation
        self.facing = target_dir
        self.turning_left = self.turning_len

        self:playTurnSound()

        refill_crit_window = true
    elseif self.enable_parry
        and (Input.pressed("up") or Input.pressed("down") or Input.pressed("left") or Input.pressed("right"))
        and not (self.parry_cooldown_left > 0)
    then
        -- parry
        if self.blocker ~= nil then
            local parry_dist_px = 2 -- i think?
            local posInfo = self:calculateBlockerPosInfo()
            self.blocker:setPosition(self:getRelativePos(posInfo.x + parry_dist_px * math.cos(-self.facing), posInfo.y - parry_dist_px * math.sin(-self.facing)))
            self.parry_ease_from_info = {x = self.blocker.x, y = self.blocker.y}
        end

        self.parry_left = self.parry_len

        if self.parry_cooldown_len ~= nil then
            self.parry_cooldown_left = self.parry_cooldown_len + self.parry_len -- cooldown len is *between* parries, whereas right now we're starting a parry
        end

        self:playTurnSound()

        refill_crit_window = true
    end

    if refill_crit_window then
        if target_dir % math.rad(45) ~= 0 then
            self.crit_window_left = self.crit_window_len_diagonal
        else
            self.crit_window_left = self.crit_window_len_normal
        end
    end

    -- (green soul cannot move)
    self.moving_x = 0
    self.moving_y = 0
end

function GreenSoul:playModeChangeSound()
    if not self.undertale then
        Assets.playSound("jump")
    end
end

function GreenSoul:playTurnSound()
    if not self.undertale then
        Assets.playSound("wing")
    end
end

function GreenSoul:calculateBoxVertices()
    local vertices = nil
    local box_radius = self:calculateBoxRadius()

    if self.diagonal or self.diagonal_transition_left > 0 then -- we use these vertices both for the diagonal box and when transitioning between the two types of box
        -- side length Cardinal Halved
        local side_len_ch = self:calculateCardinalSideLength() / 2

        if not self.diagonal then -- not diagonal means we're transitioning away from diagonal
            box_radius = self.diagonal_transition_from_box_radius
            side_len_ch = self.diagonal_transition_from_side_len / 2
        end

        vertices = {
            -- top
            -side_len_ch + self.soul_origin_adjust_x, -box_radius + self.soul_origin_adjust_y,
             side_len_ch + self.soul_origin_adjust_x, -box_radius + self.soul_origin_adjust_y,

            -- right
             box_radius + self.soul_origin_adjust_x, -side_len_ch + self.soul_origin_adjust_y,
             box_radius + self.soul_origin_adjust_x,  side_len_ch + self.soul_origin_adjust_y,

            -- bottom
             side_len_ch + self.soul_origin_adjust_x,  box_radius + self.soul_origin_adjust_y,
            -side_len_ch + self.soul_origin_adjust_x,  box_radius + self.soul_origin_adjust_y,

            -- left
            -box_radius + self.soul_origin_adjust_x,  side_len_ch + self.soul_origin_adjust_y,
            -box_radius + self.soul_origin_adjust_x, -side_len_ch + self.soul_origin_adjust_y
        }

        if self.diagonal_transition_left > 0 then
            -- Handle transition
            local ease_t = 1 - (self.diagonal_transition_left / self.diagonal_transition_len)
            local mode = "inQuad"
            local from_box_radius = self.diagonal_transition_from_box_radius

            if not self.diagonal then -- ending diagonal - reverse
                ease_t = 1 - ease_t
                mode = "outQuad"
                from_box_radius = self:calculateBoxRadius()
            end

            local ease_from = {
                -from_box_radius + self.soul_origin_adjust_x, -from_box_radius + self.soul_origin_adjust_y, -- tl

                 from_box_radius + self.soul_origin_adjust_x, -from_box_radius + self.soul_origin_adjust_y, -- tr
                 from_box_radius + self.soul_origin_adjust_x, -from_box_radius + self.soul_origin_adjust_y, -- tr

                 from_box_radius + self.soul_origin_adjust_x,  from_box_radius + self.soul_origin_adjust_y, -- br
                 from_box_radius + self.soul_origin_adjust_x,  from_box_radius + self.soul_origin_adjust_y, -- br

                -from_box_radius + self.soul_origin_adjust_x,  from_box_radius + self.soul_origin_adjust_y, -- bl
                -from_box_radius + self.soul_origin_adjust_x,  from_box_radius + self.soul_origin_adjust_y, -- bl

                -from_box_radius + self.soul_origin_adjust_x, -from_box_radius + self.soul_origin_adjust_y -- tl
            }

            for i = 1, #vertices do
                vertices[i] = Utils.ease(ease_from[i], vertices[i], ease_t, mode)
            end
        end
    else
        vertices = {
            -box_radius + self.soul_origin_adjust_x, -box_radius + self.soul_origin_adjust_y,
            -box_radius + self.soul_origin_adjust_x,  box_radius + self.soul_origin_adjust_y,
             box_radius + self.soul_origin_adjust_x,  box_radius + self.soul_origin_adjust_y,
             box_radius + self.soul_origin_adjust_x, -box_radius + self.soul_origin_adjust_y
        }
    end

    return vertices
end

function GreenSoul:draw()
    -- override debug render logic (but not regular soul logic)
    Object.draw(self)

    -- draw box
    if not self.transitioning then
        local vertices = self:calculateBoxVertices()

        -- draw lanes (debug info only)
        -- if DEBUG_RENDER then
            -- love.graphics.setLineWidth(1)
            -- Draw.setColor({1, 0, 1, 0.5})

            -- for i = 1, #vertices / 2 do
                -- -- lua is 1-indexed
                -- love.graphics.line(vertices[(i * 2) - 1], vertices[i * 2], 0, 0)
            -- end
        -- end

        -- draw box
        if not self.undertale then
            love.graphics.setLineWidth(1)
            Draw.setColor({0, 160 / 256, 0, 1})
            love.graphics.polygon("line", vertices)
        end
    end

    -- draw colliders
    if DEBUG_RENDER then
        self.collider:draw(0, 1, 0)

        if self.blocker ~= nil then
            if self.blocker.collidable then
                self.blocker.ffr_lane_colliders:drawFor(self, 0.6, 0.3, 0.6)
                self.blocker.collider:drawFor(self, 1, 0.5, 1)
            end
        end

        -- self.box_collider:draw(0, 1, 0)
        self.close_collider:draw(0.5, 0.5, 0.5)
    end
end

return GreenSoul