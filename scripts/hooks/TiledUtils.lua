---@diagnostic disable: inject-field, undefined-field
---@class TiledUtils
local TiledUtils, super = HookSystem.hookScript(TiledUtils)

local function slopeBounds(points)
    local min_x, max_x = math.huge, -math.huge
    local min_y, max_y = math.huge, -math.huge
    for _, p in ipairs(points) do
        if p[1] < min_x then min_x = p[1] end
        if p[1] > max_x then max_x = p[1] end
        if p[2] < min_y then min_y = p[2] end
        if p[2] > max_y then max_y = p[2] end
    end
    return min_x, min_y, max_x, max_y
end

local function slopeType(points)
    if #points ~= 3 then return false end

    local min_x, min_y, max_x, max_y = slopeBounds(points)
    if min_x == max_x or min_y == max_y then
        return false
    end

    for i = 1, 3 do
        local v = points[i]
        local shares_x, shares_y = false, false
        for j = 1, 3 do
            if j ~= i then
                if points[j][1] == v[1] then shares_x = true end
                if points[j][2] == v[2] then shares_y = true end
            end
        end
        if shares_x and shares_y then
            local at_left = v[1] == min_x
            local at_top  = v[2] == min_y
            if     (at_left)     and (at_top)     then  return "sul"
            elseif (not at_left) and (at_top)     then  return "sur"
            elseif (at_left)     and (not at_top) then  return "sdl"
            else                                        return "sdr" end
        end
    end

    return false
end

--- detect if collision block is a polygon and checks if its a slope (like undertale's obj_sur, sul, sdl, sdr objects)
---@param parent Object
---@param data table
---@param x number
---@param y number
---@param properties table?
---@return Collider?
function TiledUtils.colliderFromShape(parent, data, x, y, properties)
    local collider = super.colliderFromShape(parent, data, x, y, properties)
    if collider and data and data.shape == "polygon" and collider:includes(PolygonCollider) then
        local slope_dir = slopeType(collider.points)
        if slope_dir then
            collider.slope_dir = slope_dir
        end
    end
    return collider
end

return TiledUtils