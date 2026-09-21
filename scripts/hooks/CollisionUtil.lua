local CollisionUtil, super = HookSystem.hookScript(CollisionUtil)
local self = _G.CollisionUtil

-- i Dont like storing "math." functions inside local variables but
-- apparently its better for performance and the original collisionutil
-- file does this too so ill just keep it
local min = math.min
local max = math.max
local function rectsOverlap(x1, y1, w1, h1, x2, y2, w2, h2)
    return x1 + w1 > x2 and x1 < x2 + w2
       and y1 + h1 > y2 and y1 < y2 + h2
end
local function lineRectOverlap(x1, y1, x2, y2, rx, ry, rw, rh)
    if y1 == y2 then
        return y1 > ry and y1 < ry + rh
           and max(min(x1, x2), rx) < min(max(x1, x2), rx + rw)
    elseif x1 == x2 then
        return x1 > rx and x1 < rx + rw
           and max(min(y1, y2), ry) < min(max(y1, y2), ry + rh)
    end
end
local function rectFromPolygon(poly)
    if #poly ~= 4 then
        return
    end

    local left = min(poly[1][1], poly[2][1], poly[3][1], poly[4][1])
    local right = max(poly[1][1], poly[2][1], poly[3][1], poly[4][1])
    local top = min(poly[1][2], poly[2][2], poly[3][2], poly[4][2])
    local bottom = max(poly[1][2], poly[2][2], poly[3][2], poly[4][2])

    for _, point in ipairs(poly) do
        local x, y = point[1], point[2]

        if (x ~= left and x ~= right) or (y ~= top and y ~= bottom) then
            return
        end
    end

    return left, top, right - left, bottom - top
end
---------------------------------------

function CollisionUtil.rectRect(x1, y1, w1, h1, x2, y2, w2, h2)
    if not Kristal.getLibConfig("magical-glass", "undertale_collision") then
        return super.rectRect(x1, y1, w1, h1, x2, y2, w2, h2)
    end

    return rectsOverlap(x1, y1, w1, h1, x2, y2, w2, h2)
end

function CollisionUtil.rectPolygon(rx, ry, rw, rh, poly)
    if not Kristal.getLibConfig("magical-glass", "undertale_collision") then
        return super.rectPolygon(rx, ry, rw, rh, poly)
    end

    local px, py, pw, ph = rectFromPolygon(poly)

    if px then
        return rectsOverlap(rx, ry, rw, rh, px, py, pw, ph)
    end

    return super.rectPolygon(rx, ry, rw, rh, poly)
end

function CollisionUtil.polygonRect(poly, rx, ry, rw, rh)
    if not Kristal.getLibConfig("magical-glass", "undertale_collision") then
        return super.polygonRect(poly, rx, ry, rw, rh)
    end

    local px, py, pw, ph = rectFromPolygon(poly)

    if px then
        return rectsOverlap(px, py, pw, ph, rx, ry, rw, rh)
    end

    return super.polygonRect(poly, rx, ry, rw, rh)
end

function CollisionUtil.rectLine(rx, ry, rw, rh, x1, y1, x2, y2)
    if not Kristal.getLibConfig("magical-glass", "undertale_collision") then
        return super.rectLine(rx, ry, rw, rh, x1, y1, x2, y2)
    end

    local hit = lineRectOverlap(x1, y1, x2, y2, rx, ry, rw, rh)
    if hit ~= nil then
        return hit
    end

    return super.rectLine(rx, ry, rw, rh, x1, y1, x2, y2)
end

function CollisionUtil.lineRect(x1, y1, x2, y2, rx, ry, rw, rh)
    if not Kristal.getLibConfig("magical-glass", "undertale_collision") then
        return super.lineRect(x1, y1, x2, y2, rx, ry, rw, rh)
    end

    local hit = lineRectOverlap(x1, y1, x2, y2, rx, ry, rw, rh)
    if hit ~= nil then
        return hit
    end

    return super.lineRect(x1, y1, x2, y2, rx, ry, rw, rh)
end

function CollisionUtil.linePolygon(x1, y1, x2, y2, poly)
    if not Kristal.getLibConfig("magical-glass", "undertale_collision") then
        return super.linePolygon(x1, y1, x2, y2, poly)
    end

    local px, py, pw, ph = rectFromPolygon(poly)
    if px then
        local hit = lineRectOverlap(x1, y1, x2, y2, px, py, pw, ph)
        if hit ~= nil then
            return hit
        end
    end

    return super.linePolygon(x1, y1, x2, y2, poly)
end

function CollisionUtil.polygonLine(poly, x1, y1, x2, y2)
    if not Kristal.getLibConfig("magical-glass", "undertale_collision") then
        return super.polygonLine(poly, x1, y1, x2, y2)
    end

    local px, py, pw, ph = rectFromPolygon(poly)
    if px then
        local hit = lineRectOverlap(x1, y1, x2, y2, px, py, pw, ph)
        if hit ~= nil then
            return hit
        end
    end

    return super.polygonLine(poly, x1, y1, x2, y2)
end

return CollisionUtil
