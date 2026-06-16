---@class LightEncounter
---
---@field text string Text displayed when the battle starts.
---@field event boolean Whether this is an "event" encounter. Event encounters cannot be attacked, only show HP and LV, and start a wave as soon as the battle begins.
---@field event_waves string[] Waves used by event encounters.
---
---@field soul_target table? Default position the soul should move to during the battle transition. If `nil`, the default battle transition position is used.
---@field soul_offset table? Offset applied to the soul during the battle transition.
---@field fast_transition boolean? Whether the soul transition should be sped up. Useful for world hazard encounters.
---
---@field background (boolean|string)? Whether the default grid background is drawn.
---@field music string? The music used for this encounter.
---@field default_xactions boolean? Whether party members have the X-Action option in their spell menu.
---
---@field no_end_message boolean? Whether the battle skips the "YOU WON!" text.
---@field queued_enemy_spawns table[]? Enemy spawns queued before the battle exists.
---@field defeated_enemies table? Copy of `battle.defeated_enemies`, used to determine how each enemy was defeated.
---
---@field karma_mode boolean? Whether Karma/KR UI changes are enabled.
---@field invincible boolean? Whether `"* But it refused."` replaces the game over and revives the player.
---
---@field can_flee boolean? Whether the flee command is available in the mercy menu.
---@field yellow_funnycheat number? Amount of times the player used the yellow soul's BIGSHOT cheat.
---@field flee_chance number? Chance of successfully fleeing. Increases by 10 every turn.
---@field flee_messages string[]? Random flee messages shown after successfully running away.
---
---@field reduced_tension? boolean Whether tension gain is reduced for this encounter.
---
---@overload fun(...) : LightEncounter
local LightEncounter = Class()

function LightEncounter:init()
    -- Text that will be displayed when the battle starts
    self.text = "* A skirmish breaks out!"

    -- Is an "event" encounter (can't attack, only hp and lv are shown. A wave is started as soon as the battle starts)
    self.event = false
    self.event_waves = {"_empty"}

    -- For event/cutscene encounters: show the full battle HUD (name + LV/HP strip and the action
    -- buttons) instead of the compact event strip. The buttons are non-interactive in a cutscene.
    self.show_battle_ui = false
    
    -- A table defining the default location of where the soul should move to
    -- during the battle transition. If this is nil, it will move to the default location.
    self.soul_target = nil
    self.soul_offset = nil

    -- Speeds up the soul transition (useful for world hazards encounters)
    self.fast_transition = false

    -- Whether the default grid background is drawn
    self.background = true

    -- The music used for this encounter
    self.music = Game:isLight() and "battle_ut" or "battle_dt"

    -- Whether characters have the X-Action option in their spell menu
    self.default_xactions = Game:getConfig("partyActions")

    -- Should the battle skip the YOU WON! text?
    self.no_end_message = false

    -- Table used to spawn enemies when the battle exists, if this encounter is created before
    self.queued_enemy_spawns = {}

    -- A copy of battle.defeated_enemies, used to determine how an enemy has been defeated.
    self.defeated_enemies = nil
    
    -- Whether Karma (KR) UI changes will appear.
    self.karma_mode = false
    
    -- Whether "* But it refused." will replace the game over and revive the player.
    self.invincible = false

    -- Whether the flee command is available at the mercy button
    self.can_flee = Game:isLight()
    
    -- Amount of times the player used the yellow soul's BIGSHOT cheat
    self.yellow_funnycheat = 0

    -- The chance of successful flee (increases by 10 every turn)
    self.flee_chance = 50
    
    -- A random flee message that appears when you manage to run away.
    self.flee_messages = {}

    -- Whether tension is reduced for this encounter.
    self.reduced_tension = false
end

function LightEncounter:onBattleInit() end

function LightEncounter:eventWaves()
    return self.event_waves
end

function LightEncounter:onBattleStart() end

function LightEncounter:onBattleEnd() end

function LightEncounter:onTurnStart() end

function LightEncounter:onTurnEnd()
    self.flee_chance = self.flee_chance + 10
end

function LightEncounter:onActionsStart() end
function LightEncounter:onActionsEnd() end

function LightEncounter:onCharacterTurn(battler, undo) end

function LightEncounter:canFlee()
    if Game.battle.soul and Game.battle.soul:includes(GreenLightSoul) then
        return false
    else
        return self.can_flee
    end
end

function LightEncounter:onFlee() end
function LightEncounter:onFleeFail() end

function LightEncounter:beforeStateChange(old, new, reason) end
function LightEncounter:onStateChange(old, new, reason) end

function LightEncounter:onActionSelect(battler, button) end

function LightEncounter:onMenuSelect(state_reason, item, can_select) end
function LightEncounter:onMenuCancel(state_reason, item) end

function LightEncounter:onEnemySelect(state_reason, enemy_index) end
function LightEncounter:onEnemyCancel(state_reason, enemy_index) end

function LightEncounter:onPartySelect(state_reason, party_index) end
function LightEncounter:onPartyCancel(state_reason, party_index) end

function LightEncounter:onGameOver() end
function LightEncounter:onReturnToWorld(events) end

function LightEncounter:getDialogueCutscene() end

function LightEncounter:getVictoryMoney(money) end
function LightEncounter:getVictoryXP(xp) end
function LightEncounter:getVictoryText(text, money, xp) end

function LightEncounter:update() end

function LightEncounter:draw() end

function LightEncounter:addEnemy(enemy, x, y, ...)
    local enemy_obj
    if type(enemy) == "string" then
        enemy_obj = Mod.libs["magical-glass"]:createLightEnemy(enemy, ...)
    else
        enemy_obj = enemy
    end
    local enemies = self.queued_enemy_spawns
    local enemies_index
    if Game.battle and Game.state == "BATTLE" then
        enemies = Game.battle.enemies
        enemies_index = Game.battle.enemies_index
    end
    if x and y then
        enemy_obj:setPosition(x, y)
    else
        for _, enemy in ipairs(enemies) do
            enemy.x = enemy.x - 76
        end
        local x, y = (SCREEN_WIDTH / 2) - 2 + (76 * #enemies), 244
        enemy_obj:setPosition(x, y)
    end
    enemy_obj.encounter = self
    table.insert(enemies, enemy_obj)
    if enemies_index then
        table.insert(enemies_index, enemy_obj)
    end
    if Game.battle and Game.state == "BATTLE" then
        Game.battle:addChild(enemy_obj)
    end
    return enemy_obj
end

function LightEncounter:getInitialEncounterText()
    return self.text
end

function LightEncounter:getFleeMessage()
    if #self.flee_messages == 0 then
        local flee_messages = {
            "* I'm outta here.", -- 1/20
            "* I've got better to do.", --1/20
            "* Don't slow me down.", --1/20
            "* Escaped..." --17/20
        }
        return flee_messages[math.min(MathUtils.round(MathUtils.random(1, 20)), #flee_messages)]
    end
    return self.flee_messages[MathUtils.round(MathUtils.random(1, #self.flee_messages))]
end

function LightEncounter:getEncounterText()
    local enemies = Game.battle:getActiveEnemies()
    local enemy = TableUtils.pick(enemies, function(v)
        if not v.text then
            return true
        else
            return #v.text > 0
        end
    end)
    if enemy then
        return enemy:getEncounterText()
    else
        return self:getInitialEncounterText()
    end
end

function LightEncounter:getNextWaves()
    local waves = {}
    if self.event then
        for _, wave in ipairs(self:eventWaves()) do
            table.insert(waves, wave)
        end
    else
        for _, enemy in ipairs(Game.battle:getActiveEnemies()) do
            local wave = enemy:selectWave()
            if wave then
                table.insert(waves, wave)
            end
        end
    end
    return waves
end

function LightEncounter:getNextMenuWaves()
    local waves = {}
    for _, enemy in ipairs(Game.battle:getActiveEnemies()) do
        local wave = enemy:selectMenuWave()
        if wave then
            table.insert(waves, wave)
        end
    end
    return waves
end

function LightEncounter:getSoulColor()
    return Game:getSoulColor()
end

function LightEncounter:onDialogueEnd()
    Game.battle:setState("DEFENDINGBEGIN")
end

function LightEncounter:onWavesDone()
    Game.battle:setState("DEFENDINGEND", "WAVEENDED")
end

function LightEncounter:onMenuWavesDone() end

function LightEncounter:getDefeatedEnemies()
    return self.defeated_enemies or Game.battle.defeated_enemies
end

function LightEncounter:createSoul(x, y, color)
    return LightSoul(x, y, color)
end

function LightEncounter:setFlag(flag, value)
    Game:setFlag("lightencounter#"..self.id..":"..flag, value)
end

function LightEncounter:getFlag(flag, default)
    return Game:getFlag("lightencounter#"..self.id..":"..flag, default)
end

function LightEncounter:addFlag(flag, amount)
    return Game:addFlag("lightencounter#"..self.id..":"..flag, amount)
end

function LightEncounter:hasReducedTension()
    return self.reduced_tension
end

function LightEncounter:getDefendTension(battler)
    if self:hasReducedTension() then
        return 2
    end
    return 16
end

function LightEncounter:canDefendFromMercy(battler)
    return Kristal.getLibConfig("magical-glass", "light_battle_tp") or not Game:isLight()
end

function LightEncounter:isAutoHealingEnabled(battler)
    return true
end

function LightEncounter:canSwoon(target)
    return true
end

function LightEncounter:createBackground()
    if self.background then
        local background = Sprite(type(self.background) == "string" and self.background or "ui/lightbattle/backgrounds/standard", 0, 0, SCREEN_HEIGHT, SCREEN_WIDTH)
        background:setColor(Game:isLight() and {34 / 255, 177 / 255, 76 / 255, 1} or {175 / 255, 35 / 255, 175 / 255, 1})
        background:setParallax(0, 0)
        background.layer = LIGHT_BATTLE_LAYERS["background"]
        background.debug_select = false
        return Game.battle:addChild(background)
    end
end

function LightEncounter:canDeepCopy()
    return false
end

return LightEncounter