---@diagnostic disable: undefined-field, inject-field
---@class UnderPlayer : Player
---@field force_walk boolean Whether the player is forced to walk instead of run.
---@field moving boolean
---@field was_moving boolean
---@field moved boolean
---@field moving_x number
---@field moving_y number
---@field step_accum number
---@field _uw_walk_frame integer
---@field slope_blocked boolean
---@field on_slope boolean
---@field xprevious number
local UnderPlayer, super = Class(Player)

-- this is basically a complete rewrite atp 💔
---@param x number
---@param y number
function UnderPlayer:init(chara, x, y)
    super.init(self, chara, x, y)

    -- If 'true', the player will be unable to run, like in Undertale
    self.force_walk = not Kristal.getLibConfig("magical-glass", "undertale_movement_can_run")

    -- Don't edit the stuff below
    self.moving = false
    self.was_moving = false
    self.step_accum = 0
    self._uw_walk_frame = 1
    self.slope_blocked = false

    self.xprevious = self.x
end

function UnderPlayer:setActor(actor)
    super.setActor(self, actor)
    self:setHitbox(self.collider:getBounds())
end

function UnderPlayer:setHitbox(x, y, w, h)
    if Kristal.getLibConfig("magical-glass", "undertale_collision") then
        self:setCollider(LightHitbox(self, x, y, w, h))
    else
        super.setHitbox(self, x, y, w, h)
    end
end

--- get the direction the player is sliding to
---@param slope_dir string
---@param facing string
---@return number x
---@return number y
function UnderPlayer:getSlideDirection(slope_dir, facing)
    if slope_dir == "sdr" then
        if facing == "right" then return 1, -1 end
        if facing == "down" then return -1, 1 end
        if facing == "up" then return 0, -1 end
        if facing == "left" then return -1, 0 end
    elseif slope_dir == "sur" then
        if facing == "right" then return 1, 1 end
        if facing == "up" then return -1, -1 end
        if facing == "down" then return 0, 1 end
        if facing == "left" then return -1, 0 end
    elseif slope_dir == "sul" then
        if facing == "left" then return -1, 1 end
        if facing == "up" then return 1, -1 end
        if facing == "down" then return 0, 1 end
        if facing == "right" then return 1, 0 end
    elseif slope_dir == "sdl" then
        if facing == "left" then return -1, -1 end
        if facing == "down" then return 1, 1 end
        if facing == "up" then return 0, -1 end
        if facing == "right" then return 1, 0 end
    end
    return 0, 0
end

--- check if player is colliding with a slope and wall
---@param slope_dir string
---@param left boolean
---@param up boolean
---@param right boolean
---@param down boolean
---@return boolean
function UnderPlayer:checkSlopeConflict(slope_dir, left, up, right, down)
    if up and down then
        return self:checkSlopeCancel(slope_dir, left, up, right, down)
    end
    if slope_dir == "sul" or slope_dir == "sdr" then
        return (right and down) or (up and left)
    elseif slope_dir == "sur" or slope_dir == "sdl" then
        return (left and down) or (up and right)
    end
    return false
end

---@param slope_dir string
---@param left boolean
---@param up boolean
---@param right boolean
---@param down boolean
---@return boolean
function UnderPlayer:checkSlopeCancel(slope_dir, left, up, right, down)
    if slope_dir == "sdr" then return down and right end
    if slope_dir == "sur" then return up and right end
    if slope_dir == "sul" then return up and left end
    if slope_dir == "sdl" then return down and left end
    return false
end

function UnderPlayer:setPosition(...)
    super.setPosition(self, ...)
    self.xprevious = self.x
end

--- checks if "target" is an event object (interactables, etc)
--- having the "ignore_collide" property on events makes the code treat those events as normal collider walls (not events) (returns false here)
---@param target (Event|Object)?
---@return boolean is_event
function UnderPlayer:isEventObject(target)
    if not target or not target.includes then return false end
    if target["ignore_collide"] then return false end
    return target:includes(Event) or target:includes(NPC)
end

--- check if a collider has collided with something
---@param collider Collider
---@return boolean
function UnderPlayer:checkCollision(collider)
    if self.noclip or NOCLIP then return false end
    Object.startCache()
    local hit = false
    for _, other in ipairs(self.world:getCollision(self.enemy_collision)) do
        if collider:meetsCollider(other) and collider ~= other then
            local parent = other:getOwner()
            if not (parent and self:isEventObject(parent)) and not other.slope_dir then
                hit = true
                break
            end
        end
    end
    Object.endCache()
    return hit
end

--- checks for collisions in a line
---@param x1 number
---@param y1 number
---@param x2 number
---@param y2 number
---@return boolean
function UnderPlayer:checkCollisionLine(x1, y1, x2, y2)
    return self:checkCollision(LineCollider(self, x1, y1, x2, y2))
end

--- gets hitbox edges as offsets relative to player x and y
---@return number left
---@return number top
---@return number right
---@return number bottom
function UnderPlayer:getHitboxOffsets()
    local hx, hy, hw, hh = self.collider:getBounds()
    return hx + 2, hy, hx + hw - 2, hy + hh
end

--- checks if player would collide with a wall at the target position
---@param target_x number
---@param target_y number
---@return boolean
function UnderPlayer:wouldHitboxOverlap(target_x, target_y)
    local saved_x, saved_y = self.x, self.y
    self.x, self.y = target_x, target_y
    Object.uncache(self)
    local hit = self:checkCollision(self.collider)
    self.x, self.y = saved_x, saved_y
    Object.uncache(self)
    return hit
end

--- classifies whatever the player is colliding with and also fires 'onCollide' (and 'onEnter' (for transitions)) to mimic undertale door behavior
--- idk if it would be better to return a table instead of returning each variable individually but this is probably fine
---@return Object? wall_target
---@return Object? slope_target
---@return ("sul"|"sur"|"sdl"|"sdr")? slope_dir
---@return Object? event_target
function UnderPlayer:checkSolidCollision()
    if self.noclip or NOCLIP then return end
    Object.startCache()

    for _, child in ipairs(self.world.children) do
        if child:includes(Transition) and self.collider:meetsCollider(child.collider) then
            child:onEnter(self)
        end
    end

    local wall_target, slope_target, slope_dir, event_target
    for _, other in ipairs(self.world:getCollision(self.enemy_collision)) do
        if self.collider:meetsCollider(other) and self.collider ~= other then
            local parent = other:getOwner()
            if parent and self:isEventObject(parent) then
                if not event_target then event_target = parent end
                if parent.onCollide then
                    parent:onCollide(self)
                end
            elseif other.slope_dir then
                if not slope_target then
                    slope_target = parent
                    slope_dir = other.slope_dir
                end
            else
                wall_target = wall_target or parent
            end
        end
    end
    Object.endCache()
    return wall_target, slope_target, slope_dir, event_target
end

function UnderPlayer:updateWalk()
    if not self:isMovementEnabled() then
        self.moving = false
        self:updateWalkFrame()
        return
    end
    
    self.step_accum = self.step_accum + DTMULT
    while self.step_accum >= 1 do
        self.step_accum = self.step_accum - 1
        self:handleMovement()
    end

    self:updateWalkFrame()
end

--- spooky rewrite
function UnderPlayer:handleMovement()
    local step = self:getBaseWalkSpeed()
    local step_start_x = self.x
    local step_start_y = self.y

    self.moving = false
    self.moving_x = 0
    self.moving_y = 0

    local speed_mult = 1
    if (self.force_run or Input.down("cancel")) and not self.force_walk then
        speed_mult = 2
    end

    local left = Input.down("left")
    local up = Input.down("up")
    local right = Input.down("right")
    local down = Input.down("down")
    local dancing = up and down

    if left then
        self.moving_x = -1
        local turned = true
        -- undertale decreases a held step by 1px after a frame (xprevious lags)
        local base = (self.xprevious == self.x + step) and (step - 1) or step
        self.x = self.x - base * speed_mult
        self.moving = true
        if up and self.facing == "up" then turned = false end
        if down and self.facing == "down" then turned = false end
        if turned then self:setFacing("left") end
    end

    if up then
        self.moving_y = -1
        local turned = true
        self.y = self.y - step * speed_mult
        self.moving = true
        if right and self.facing == "right" then turned = false end
        if left and self.facing == "left" then turned = false end
        if turned then self:setFacing("up") end
    end

    if right and not left then
        self.moving_x = 1
        local turned = true
        local base = (self.xprevious == self.x - step) and (step - 1) or step
        self.x = self.x + base * speed_mult
        self.moving = true
        if up and self.facing == "up" then turned = false end
        if down and self.facing == "down" then turned = false end
        if turned then self:setFacing("right") end
    end

    if down and not up then
        self.moving_y = 1
        local turned = true
        self.y = self.y + step * speed_mult
        self.moving = true
        if right and self.facing == "right" then turned = false end
        if left and self.facing == "left" then turned = false end
        if turned then self:setFacing("down") end
    end

    Object.uncache(self)

    if (not self.noclip) and (not NOCLIP) then
        local wall_target, slope_target, slope_dir, event_target = self:checkSolidCollision()
        local touching_slope = slope_target ~= nil

        local dx, dy, slide_blocked = 0, 0, false
        if slope_target then
            dx, dy = self:getSlideDirection(slope_dir, self.facing)
            slide_blocked = self:checkSlopeConflict(slope_dir, left, up, right, down)
                or self:wouldHitboxOverlap(step_start_x + dx * step, step_start_y + dy * step)
        end

        if slope_target and wall_target and not dancing and slide_blocked then
            slope_target = nil
        end

        self.slope_blocked = false
        if dancing and slope_target then
            if wall_target then
                self:resolveWall(wall_target, step_start_x, step_start_y, left, up, right, down)
            elseif dy < 0 and not slide_blocked then -- sliding up slope
                self:resolveSlope(slope_target, slope_dir, step_start_x, step_start_y, left, up, right, down)
                self.on_slope = true
                self.slope_blocked = true
            elseif self.on_slope then -- block movement after sliding
                self.x = step_start_x
                self.y = step_start_y
                self.moving = false
                Object.uncache(self)
                self.slope_blocked = true
            else -- trying to move into slope while doing frisk dance
                self.x = step_start_x
                self.y = step_start_y
                self.moving = false
                Object.uncache(self)
                self.slope_blocked = true
            end
        elseif slope_target then
            self:resolveSlope(slope_target, slope_dir, step_start_x, step_start_y, left, up, right, down)
            self.on_slope = true
        elseif wall_target then
            self:resolveWall(wall_target, step_start_x, step_start_y, left, up, right, down)
        elseif event_target then
            self.x = step_start_x
            self.y = step_start_y
            self.moving = false
            Object.uncache(self)
            self.slope_blocked = true
        end

        if not touching_slope then
            self.on_slope = false
        end
    end

    self.last_collided_x = self.moving_x ~= 0 and self.x == step_start_x
    self.last_collided_y = self.moving_y ~= 0 and self.y == step_start_y

    if self.x ~= step_start_x or self.y ~= step_start_y then
        self.moving = true
    end

    self.xprevious = step_start_x
end

---@param target (Event|Object)?
---@param step_start_x number
---@param step_start_y number
---@param left boolean
---@param up boolean
---@param right boolean
---@param down boolean
function UnderPlayer:resolveWall(target, step_start_x, step_start_y, left, up, right, down)
    local step = self:getBaseWalkSpeed()
    self.x = step_start_x
    self.y = step_start_y
    Object.uncache(self)
    self.moving = false

    local hit_left, hit_top, hit_right, hit_bottom = self:getHitboxOffsets()
    if up then
        if self:wouldHitboxOverlap(self.x, self.y - step) then
            if left and not self:checkCollisionLine(hit_left - step, hit_top, hit_left, hit_top) then
                self.x = self.x - step
                self:setFacing("left")
            end
            if right and not self:checkCollisionLine(hit_right + step, hit_top, hit_right, hit_top) then
                self.x = self.x + step
                self:setFacing("right")
            end
        else
            self.y = self.y - step
            self:setFacing("up")
        end
    end

    if down then
        if self:wouldHitboxOverlap(self.x, self.y + step) then
            if left and not self:checkCollisionLine(hit_left - step, hit_bottom, hit_left, hit_bottom) then
                self.x = self.x - step
                self:setFacing("left")
            end
            if right and not self:checkCollisionLine(hit_right + step, hit_bottom, hit_right, hit_bottom) then
                self.x = self.x + step
                self:setFacing("right")
            end
        else
            self.y = self.y + step
            self:setFacing("down")
        end
    end

    Object.uncache(self)

    if self.x ~= step_start_x or self.y ~= step_start_y then
        local w2, s2, sd2, e2 = self:checkSolidCollision()
        if w2 or e2 then
            self.x = step_start_x
            self.y = step_start_y
            Object.uncache(self)
        elseif s2 then
            if self:checkSlopeConflict(sd2, left, up, right, down) then
                self.x = step_start_x
                self.y = step_start_y
                Object.uncache(self)
            else
                self:resolveSlope(s2, sd2, self.x, self.y, left, up, right, down)
            end
        end
    end

    if target and target.onCollide then
        target:onCollide(self, DTMULT)
    end
end

---@param target Object
---@param slope_dir "sul"|"sur"|"sdl"|"sdr"
---@param step_start_x number
---@param step_start_y number
---@param left boolean
---@param up boolean
---@param right boolean
---@param down boolean
function UnderPlayer:resolveSlope(target, slope_dir, step_start_x, step_start_y, left, up, right, down)
    local step = self:getBaseWalkSpeed()

    if self:checkSlopeConflict(slope_dir, left, up, right, down) then
        self.x = step_start_x
        self.y = step_start_y
        self.moving = false
        Object.uncache(self)
        return
    end

    local dx, dy = self:getSlideDirection(slope_dir, self.facing)
    if dx == 0 and dy == 0 then return end

    self.x = step_start_x + dx * step
    self.y = step_start_y + dy * step
    Object.uncache(self)

    if self:wouldHitboxOverlap(self.x + dx * step, self.y + dy * step) then
        local guard = step + 2
        while guard > 0 and not self:checkCollision(self.collider) do
            self.x = self.x + dx
            self.y = self.y + dy
            Object.uncache(self)
            guard = guard - 1
        end
        self.x = self.x - dx * (step + 1)
        self.y = self.y - dy * (step + 1)
        Object.uncache(self)
    end

    self.moving = false
    if target and target.onCollide then target:onCollide(self) end
end

--- custom way of handling walk animation frame cycling (so its accurate to undertale)
--- this feels hacky but i dont think there is a better way to do it
function UnderPlayer:updateWalkFrame()
    if not self.sprite then return end

    local is_dancing = Input.down("up") and Input.down("down") and self.last_collided_y and not self.last_collided_x and not self.slope_blocked
    if is_dancing then
        self.facing = "down"
    end
    local effectively_moving = self.moving or is_dancing

    if effectively_moving then
        local num_frames = #self.sprite.frames
        -- Immediately go to 2nd frame of walk animation unless you're facing right
        -- Because undertale does that for some reason :p
        if not self.was_moving and self.facing ~= "right" then
            self._uw_walk_frame = 2
        else
            self._uw_walk_frame = self._uw_walk_frame + 0.2 * DTMULT
            if self._uw_walk_frame >= num_frames + 1 then
                self._uw_walk_frame = self._uw_walk_frame - num_frames
            end
        end
        local ws = self:getBaseWalkSpeed()
        self.moved = ws
    else
        self._uw_walk_frame = 1
        self.moved = 0
    end

    self.was_moving = effectively_moving
end

function UnderPlayer:update()
    super.update(self)
    if self.sprite then
        if self.sprite.frames then
            local n = #self.sprite.frames
            if n > 0 then
                self.sprite.walk_frame = self._uw_walk_frame
                self.sprite.frame = ((math.floor(self._uw_walk_frame) - 1) % n) + 1
            end
        end

        -- this lifts the player sprite up by 6px when facing down while doing the frisk dance so it looks accurate to undertale
        if self._sprite_base_y == nil then
            self._sprite_base_y = self.sprite.y
        end
        local dance_down = self:isMovementEnabled() and self.state_manager.state == "WALK" and self.facing == "down" and Input.down("up") and Input.down("down") and not self.slope_blocked and (not self.last_collided_x or (Input.down("left") and Input.down("right")))
        self.sprite.y = self._sprite_base_y + (dance_down and -6 or 0)
    end
end

return UnderPlayer
