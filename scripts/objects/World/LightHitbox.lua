---@class LightHitbox : Hitbox
local LightHitbox = Class(Hitbox)

function LightHitbox:getColliderType()
    return CollisionRegistry.LIGHT_HITBOX
end

function LightHitbox.pointInRect(x, y, rx, ry, rw, rh, include_boundary)
    if include_boundary then
        return x >= rx and x <= rx + rw and y >= ry and y <= ry + rh
    end
    return x > rx and x < rx + rw and y > ry and y < ry + rh
end

function LightHitbox.pointOnSegment(x, y, x1, y1, x2, y2)
    local cross = (x - x1) * (y2 - y1) - (y - y1) * (x2 - x1)
    return cross == 0
        and x >= math.min(x1, x2) and x <= math.max(x1, x2)
        and y >= math.min(y1, y2) and y <= math.max(y1, y2)
end

function LightHitbox.pointInPolygon(points, x, y, include_boundary)
    local inside = false
    for i, point in ipairs(points) do
        local next_point = points[(i % #points) + 1]
        if LightHitbox.pointOnSegment(x, y, point[1], point[2], next_point[1], next_point[2]) then
            return include_boundary
        end
        if (point[2] > y) ~= (next_point[2] > y)
            and x < (next_point[1] - point[1]) * (y - point[2]) / (next_point[2] - point[2]) + point[1]
        then
            inside = not inside
        end
    end
    return inside
end

function LightHitbox.lineIntersectsOpenRect(x1, y1, x2, y2, rx, ry, rw, rh)
    local dx, dy = x2 - x1, y2 - y1
    local t_min, t_max = 0, 1

    if dx == 0 then
        if x1 <= rx or x1 >= rx + rw then return false end
    else
        local a, b = (rx - x1) / dx, (rx + rw - x1) / dx
        t_min = math.max(t_min, math.min(a, b))
        t_max = math.min(t_max, math.max(a, b))
    end

    if dy == 0 then
        if y1 <= ry or y1 >= ry + rh then return false end
    else
        local a, b = (ry - y1) / dy, (ry + rh - y1) / dy
        t_min = math.max(t_min, math.min(a, b))
        t_max = math.min(t_max, math.max(a, b))
    end

    if t_min > t_max then return false end
    local t = (t_min + t_max) / 2
    return LightHitbox.pointInRect(x1 + dx * t, y1 + dy * t, rx, ry, rw, rh, false)
end

function LightHitbox.rectPolygonPoints(rect, points)
    for _, point in ipairs(points) do
        if LightHitbox.pointInRect(point[1], point[2], rect.x, rect.y, rect.width, rect.height, false) then
            return true
        end
    end

    local corners = {
        { rect.x, rect.y },
        { rect.x + rect.width, rect.y },
        { rect.x + rect.width, rect.y + rect.height },
        { rect.x, rect.y + rect.height }
    }
    for _, point in ipairs(corners) do
        if LightHitbox.pointInPolygon(points, point[1], point[2], false) then
            return true
        end
    end

    for i, point in ipairs(points) do
        local next_point = points[(i % #points) + 1]
        if LightHitbox.lineIntersectsOpenRect(
            point[1], point[2], next_point[1], next_point[2], rect.x, rect.y, rect.width, rect.height
        ) then
            return true
        end
    end

    local area = 0
    for i, point in ipairs(points) do
        if not LightHitbox.pointInRect(
            point[1], point[2], rect.x, rect.y, rect.width, rect.height, true
        ) then
            return false
        end
        local next_point = points[(i % #points) + 1]
        area = area + point[1] * next_point[2] - next_point[1] * point[2]
    end
    return area ~= 0
end

function LightHitbox.rectLine(rect, line)
    local x1, y1, x2, y2 = line:getLineFor(rect)
    return LightHitbox.lineIntersectsOpenRect(x1, y1, x2, y2, rect.x, rect.y, rect.width, rect.height)
end

function LightHitbox.rectCircle(rect, circle)
    local x, y, radius = circle:getCircleFor(rect)
    local closest_x = math.max(rect.x, math.min(x, rect.x + rect.width))
    local closest_y = math.max(rect.y, math.min(y, rect.y + rect.height))
    return (x - closest_x) ^ 2 + (y - closest_y) ^ 2 < radius ^ 2
end

function LightHitbox.rectPolygon(rect, polygon)
    return LightHitbox.rectPolygonPoints(rect, polygon:getPointsFor(rect))
end

return LightHitbox
