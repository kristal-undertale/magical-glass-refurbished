local RecruitMenu, super = HookSystem.hookScript(RecruitMenu)

function RecruitMenu:init()
    self.pre_init = true
    
    super.init(self)
    
    if Game:isLight() then
        if self.heart then
            self.heart:remove()
            self.heart = nil
        end
        self.heart = Sprite("player/heart_menu", 65, 117)
        self.heart:setScale(2)
        self.heart:setOrigin(0.5, 0.5)
        self.heart:setColor(Game:getSoulColor())
        self.heart.layer = 100
        self:addChild(self.heart)
    end

    self.recruits = Game:getAllRecruits(true)
    self.pre_init = nil
    self:setRecruitInBox(self.selected)
end

function RecruitMenu:setRecruitInBox(selected)
    if self.pre_init then return end
    
    super.setRecruitInBox(self, selected)
end

function RecruitMenu:update()
    super.update(self)

    if Game:isLight() then
        -- Instantly update position
        if self.state == "SELECT" then
            self.heart.x = 65
            self.heart.y = 117 + (self.selected - (self.selected_page - 1) * self:getLimit() - 1) * 35
            self.heart_target_x, self.heart_target_y  = self.heart.x, self.heart.y
        else
            self.heart.x = 65
            self.heart.y = 416
            self.heart_target_x, self.heart_target_y  = self.heart.x, self.heart.y
        end
    end
end

function RecruitMenu:draw()
    love.graphics.setFont(self.font)

    if self.state == "SELECT" then
        love.graphics.setLineWidth(4)
        Draw.setColor(PALETTE["world_border"])
        love.graphics.rectangle("line", 32, 12, 587, 427)
        Draw.setColor(PALETTE["world_fill"])
        love.graphics.rectangle("fill", 34, 14, 583, 423)

        Draw.setColor(COLORS["white"])
        love.graphics.print("Recruits", 80, 30)
        Draw.setColor(0, 1, 0)
        love.graphics.print("PROGRESS", 270, 30, 0, 0.5, 1)

        local offset = 0
        for i,recruit in pairs(self.recruits) do
            if i <= self:getLastSelectedInPage() and i >= self:getFirstSelectedInPage() then
                Draw.setColor(COLORS["white"])
                if i == self.selected then
                    Draw.printAlign(recruit:getName(), 473, 240, "center")
                    love.graphics.print("CHAPTER " .. recruit:getChapter(), 368, 280)
                    Draw.printAlign("LV " .. recruit:getLevel(), 576, 280, "right")
                    if Input.usingGamepad() then
                        love.graphics.print("More Info", 414, 320)
                        Draw.draw(Input.getTexture("confirm"), 380, 323, 0, 2, 2)
                        love.graphics.print("Quit", 414, 352)
                        Draw.draw(Input.getTexture("cancel"), 380, 353, 0, 2, 2)
                    else
                        love.graphics.print(Input.getText("confirm") .. ": More Info", 380, 320)
                        love.graphics.print(Input.getText("cancel") .. ": Quit", 380, 352)
                    end
                    Draw.setColor(COLORS["yellow"])
                end
                local name = recruit:getName()
                local x_scale = 1
                if self.font:getWidth(name) >= 180 then
                    x_scale = 180 / self.font:getWidth(name)
                end
                love.graphics.print(name, 80, 100 + offset, 0, x_scale, 1)
                if Game:hasRecruitByData(recruit) then
                    Draw.setColor(0, 1, 0)
                    love.graphics.print("Recruited!", 275, 100 + offset, 0, 0.5, 1)
                else
                    Draw.setColor(PALETTE["world_light_gray"])
                    local recruit_progress = recruit:getRecruited() .. (Game:getConfig("recruitsProgressSpaces") and " / " or "/") .. recruit:getRecruitAmount()
                    love.graphics.print(recruit_progress, 280, 100 + offset)
                end
                offset = offset + 35
            end
        end

        if self:getMaxPages() > 1 then
            Draw.setColor(1, 1, 1, 1)
            local offset = MathUtils.round(math.sin(Kristal.getTime() * 5)) * 2
            Draw.draw(self.arrow_left, 22 - offset, 213, 0, 2, 2)
            Draw.draw(self.arrow_right, 612 + offset, 213, 0, 2, 2)
        end
    elseif self.state == "INFO" then
        love.graphics.setLineWidth(4)
        Draw.setColor(PALETTE["world_border"])
        love.graphics.rectangle("line", 32, 12, 577, 437)
        Draw.setColor(PALETTE["world_fill"])
        love.graphics.rectangle("fill", 34, 14, 573, 433)

        Draw.setColor(COLORS["white"])
        for i,recruit in pairs(self.recruits) do
            Draw.printAlign(self.selected .. "/" .. #self.recruits, 590, 30, "right", 0, 0.5, 1)
            if i == self.selected then
                love.graphics.print("CHAPTER " .. recruit:getChapter(), 300, 30, 0, 0.5, 1)
                love.graphics.print(recruit:getName(), 300, 70)
                love.graphics.setFont(self.description_font)
                Draw.printAlign(Game:hasRecruitByData(recruit) and recruit:getDescription() or "Not yet fully recruited", 301, 120, {["align"] = "left", ["line_offset"] = 4})
                love.graphics.setFont(self.font)

                for i,value in ipairs({"LIKE", "DISLIKE", "?????", "?????"}) do
                    local x_scale = 1
                    if self.font:getWidth(value) >= 60 then
                        x_scale = 80 / self.font:getWidth(value)
                    end
                    love.graphics.print(value, 80, 200 + i * 40, 0, x_scale, 1)
                end
                for i,value in ipairs({Game:hasRecruitByData(recruit) and recruit:getLike() or "?", Game:hasRecruitByData(recruit) and recruit:getDislike() or "?", "?????????", "?????????"}) do
                    local x_scale = 1
                    if self.font:getWidth(value) >= 290 then
                        x_scale = 290 / self.font:getWidth(value)
                    end
                    love.graphics.print(value, 180, 200 + i * 40, 0, x_scale, 1)
                end

                if Input.usingGamepad() then
                    love.graphics.print("Press         to Return", 80, 400)
                    Draw.draw(Input.getTexture("cancel"), 165, 402, 0, 2, 2)
                else
                    love.graphics.print("Press " .. Input.getText("cancel") .. " to Return", 80, 400)
                end
                love.graphics.print("LEVEL", 525, 240, 0, 0.5, 1)
                Draw.printAlign(recruit:getLevel(), 590, 240, "right", 0, 0.5, 1)
                love.graphics.print("ATTACK", 518, 280, 0, 0.5, 1)
                Draw.printAlign(recruit:getAttack(), 590, 280, "right", 0, 0.5, 1)
                love.graphics.print("DEFENSE", 511, 320, 0, 0.5, 1)
                Draw.printAlign(recruit:getDefense(), 590, 320, "right", 0, 0.5, 1)
                Draw.printAlign("ELEMENT  " .. recruit:getElement(), 590, 360, "right", 0, 0.5, 1)
            end

            Draw.setColor(1, 1, 1, 1)
            local offset = MathUtils.round(math.sin(Kristal.getTime() * 5)) * 2
            Draw.draw(self.arrow_left, 22 - offset, 218, 0, 2, 2)
            Draw.draw(self.arrow_right, 602 + offset, 218, 0, 2, 2)
        end
    else
        error("Unknown state in recruit menu: \"" .. self.state .. "\"")
    end

    love.graphics.setLineWidth(1)
    Draw.setColor(PALETTE["world_border"])
    love.graphics.rectangle("line", self.recruit_box.x, self.recruit_box.y, self.recruit_box.width + 1, self.recruit_box.height + 1)

    Object.draw(self)
end

return RecruitMenu