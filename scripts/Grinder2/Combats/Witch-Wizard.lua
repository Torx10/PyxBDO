Magician = { }
Magician.__index = Magician
Magician.version = "3.1"
Magician.author = "torx"
Magician.Gui = { }
Magician.Gui.ShowGui = false
Magician.GrinderVersion = 2

------------- Gui Settings -----------------------------------------------------------------------------------------------
-- Fireball Options
Magician.Gui.Fireball = true
Magician.Gui.FireballExplosion = true
-- Lightning Options
Magician.Gui.LightningChain = true
Magician.Gui.Lightning = true
Magician.Gui.LightningStorm = true
Magician.Gui.ResidualLightning = true
-- Magic Arrow Options
Magician.Gui.MagicArrow = true
Magician.Gui.MultiArrow = true
Magician.Gui.ConcentratedArrow = true
-- Melee Options
Magician.Gui.DaggerStab = true
-- Speed Spell Options
Magician.Gui.SpeedSpell = true
-- Health Options
Magician.Gui.HealingAura = true
-- Magician.Gui.LockHA = false
Magician.Gui.HealingAuraHealthPercent = 75
Magician.Gui.HealingAuraManaPercent = 60
Magician.Gui.HealingLighthouse = true
-- Magician.Gui.LockHL = false
Magician.Gui.HealingLighthouseHealthPercent = 50
Magician.Gui.HealingLighthouseManaPercent = 30
-- Mana Options
Magician.Gui.MagicAbsorb = true
-- Magician.Gui.LockMA = false
Magician.Gui.MagicAbsorbManaPercent = 50
Magician.Gui.SpellboundHeart = true
-- Magician.Gui.LockSB = false
Magician.Gui.SpellboundHeartManaPercent = 80
-- Defense Options
Magician.Gui.MagicShield = true
-- Magician.Gui.LockMS = false
Magician.Gui.MagicShieldHealthPercent = 50
Magician.Gui.MagicLighthouse = true
-- Magician.Gui.LockML = false
Magician.Gui.MagicLighthouseHealthPercent = 40
-- Cooldown Options
Magician.Gui.SagesMemory = true
Magician.Gui.MeteorShower = true
Magician.Gui.Blizzard = true
-- Quick Slot Options
Magician.Gui.MultiArrowSlot = nil
Magician.Gui.SpeedSpellSlot = nil
Magician.Gui.SpellboundHeartSlot = nil
Magician.Gui.MagicLighthouseSlot = nil
Magician.Gui.SagesMemorySlot = nil

-- NOT YET IMPLEMENTED
-- Magician.Gui.EarthsResponse = true
-- Magician.Gui.Earthquake = true
-- Magician.Gui.Freeze = true
-- Magician.Gui.FrigidFog = true
-- Magician.Gui.MagicEvasion = true
-- Magician.Gui.ProtectedArea = true
-- Magician.Gui.StaffAttck = true
-- Magician.Gui.Teleport = true

------------- SetActionState Buttons -------------------------------------------------------------------------------------
Magician.LMB        = ACTION_FLAG_MAIN_ATTACK
Magician.RMB        = ACTION_FLAG_SECONDARY_ATTACK
Magician.Shift      = ACTION_FLAG_EVASION
Magician.Space      = ACTION_FLAG_JUMP
Magician.Q          = ACTION_FLAG_SPECIAL_ACTION_1
Magician.E          = ACTION_FLAG_SPECIAL_ACTION_2
Magician.F          = ACTION_FLAG_SPECIAL_ACTION_3
Magician.W          = ACTION_FLAG_MOVE_FORWARD
Magician.S          = ACTION_FLAG_MOVE_BACKWARD
Magician.A          = ACTION_FLAG_MOVE_LEFT
Magician.D          = ACTION_FLAG_MOVE_RIGHT
Magician.Z          = ACTION_FLAG_PARTNER_COMMAND_1
Magician.X          = ACTION_FLAG_PARTNER_COMMAND_2
Magician.C          = ACTION_FLAG_AWEKENED_GEAR
Magician.V          = ACTION_FLAG_EMERGENCY_ESCAPE

------------- functions --------------------------------------------------------------------------------------------------
function Magician:FixFire()
    local selfPlayer = GetSelfPlayer()
    if selfPlayer:CheckCurrentAction("BT_Skill_Fireball_Ing") then
        print("Fireball stuck as ROAMING starts...firing")
        selfPlayer:SetActionState( Magician.RMB, 500 )
        return
    end
end

function Magician:findQuickSlotById(skillId)
    local code = string.format([[
    for i = 0, 25 do
        local quickSlotKey = i - 1
        local quickSlotInfo = getQuickSlotItem(quickSlotKey)
        if CppEnums.QuickSlotType.eSkill == quickSlotInfo._type then
            local skillNo = quickSlotInfo._skillKey:getSkillNo()
            local skillTypeStaticWrapper = getSkillTypeStaticStatus(skillNo)
            local skillName = skillTypeStaticWrapper:getName()
            if skillNo == %i then
                return quickSlotKey
            end
        end
    end
    ]], skillId)
    slot = BDOLua.Execute(code)
    return slot
end

if Magician.Gui.MultiArrowSlot == nil and EdanSkills.GetSkill(WITCH_MULTIPLE_MAGIC_ARROWS) ~= 0 then
    Magician.Gui.MultiArrowSlot = Magician:findQuickSlotById(EdanSkills.GetSkill(WITCH_MULTIPLE_MAGIC_ARROWS))
end
if Magician.Gui.SpeedSpellSlot == nil and EdanSkills.GetSkill(WITCH_SPEED_SPELL) ~= 0 then
    Magician.Gui.SpeedSpellSlot = Magician:findQuickSlotById(EdanSkills.GetSkill(WITCH_SPEED_SPELL))
end
if Magician.Gui.SpellboundHeartSlot == nil and EdanSkills.GetSkill(WITCH_SPELLBOUND_HEART) ~= 0 then
    Magician.Gui.SpellboundHeartSlot = Magician:findQuickSlotById(EdanSkills.GetSkill(WITCH_SPELLBOUND_HEART))
end
if Magician.Gui.MagicLighthouseSlot == nil and EdanSkills.GetSkill(WITCH_MAGIC_LIGHTHOUSE) ~= 0 then
    Magician.Gui.MagicLighthouseSlot = Magician:findQuickSlotById(EdanSkills.GetSkill(WITCH_MAGIC_LIGHTHOUSE))
end
if Magician.Gui.SagesMemorySlot == nil and EdanSkills.GetSkill(WITCH_SAGES_MEMORY) ~= 0 then
    Magician.Gui.SagesMemorySlot = Magician:findQuickSlotById(EdanSkills.GetSkill(WITCH_SAGES_MEMORY))
end

------------- Attack Rotation --------------------------------------------------------------------------------------------
function Magician:Attack(monster)
    local player = GetSelfPlayer()
    if not monster or not player then
        self.combos = nil
        return
    end

    if player:CheckCurrentAction("BT_Skill_Fireball_Ing") then
        print("Fireball stuck in Attack...firing")
        player:SetActionState( Magician.RMB, 500 )
        return
    end

    if isPull and player.IsActionPending then
        return
    end

    local distance = monster.Position.Distance2DFromMe - monster.BodySize - player.BodySize

    if distance > 1200 or not monster.IsLineOfSight then
        Bot.Pather:MoveDirectTo(monster.Position)
        self.combos = nil
        return
    end

    if player.CurrentActionName == "BT_WAIT_HOLD_ON" then
        print("Stunned")
        self.combos = nil
        return
    end

    EdanScout.Update()
    player:FacePosition(monster.Position)

    -- Combo routine variables
    self.distance = distance
    self.player = player
    self.monster = monster
    self.ispull = isPull

    -- Execute combos
    if self.combos == nil or coroutine.status(self.combos) == 'dead' then
        self.combos = coroutine.create(Magician.Combos)
    end

    local result,err = coroutine.resume(self.combos, self)
    if err then
        print("Combo error: "..err)
    end

end

------------- Combos -----------------------------------------------------------------------------------------------------
function Magician:Combos()
    if self.player.IsActionPending then
        print("action is pending")
        return
    end

    Magician:FixFire()
    Bot.Pather:Stop()

    -- Use Healing Aura
    if Magician.Gui.HealingAura and (self.player.HealthPercent <= Magician.Gui.HealingAuraHealthPercent or self.player.ManaPercent < Magician.Gui.HealingAuraManaPercent) and EdanSkills.SkillUsableCooldown(WITCH_HEALING_AURA) then
        print( "Casting Healing Aura" )
        EdanCombo.PressAndWait( Magician.E, self.player.Position )
        return
    end

    -- Use Healing Lighthouse
    if Magician.Gui.HealingLighthouse and (self.player.HealthPercent <= Magician.Gui.HealingLighthouseHealthPercent or self.player.ManaPercent <= Magician.Gui.HealingLighthouseManaPercent) and EdanSkills.SkillUsableCooldown(WITCH_HEALING_LIGHTHOUSE) then
        print( "Casting Healing Lighthouse" )
        EdanCombo.PressAndWait( Magician.Shift | Magician.E )
        return
    end

    -- Use Magical Absoption
    if Magician.Gui.MagicAbsorb and ((EdanScout.MonstersInMeleeRange == 0 and self.player.ManaPercent < Magician.Gui.MagicAbsorbManaPercent) or self.player.ManaPercent < 10) and EdanSkills.SkillUsableCooldown(WITCH_MANA_ABSORPTION) then
        print( "Casting Magical Absorption" )
        EdanCombo.PressAndWait( Magician.Shift | Magician.LMB, self.monster.Position )
        EdanCombo.Wait(1000)
        return
    end

    -- Use Spellbound Heart (Mana Orb)
    if Magician.Gui.SpellboundHeart and Magician.Gui.SpellboundHeartSlot ~= nil and self.player.ManaPercent <= Magician.Gui.SpellboundHeartManaPercent and EdanSkills.SkillUsableCooldown(WITCH_SPELLBOUND_HEART) then
        print( "Casting Mana Orb" )
        local slot = string.format([[quickSlot_UseSlot(%f)]], Magician.Gui.SpellboundHeartSlot)
        BDOLua.Execute(slot)
        EdanCombo.WaitUntilDone()
        return
    end

    -- Use Magic Shield
    if Magician.Gui.MagicShield and ((self.player.HealthPercent <= 70 and EdanScout.MonstersInMeleeRange >= 2) or self.player.HealthPercent <= Magician.Gui.MagicShieldHealthPercent) and self.player.ManaPercent >= 30 and EdanSkills.SkillUsableCooldown(WITCH_MAGICAL_SHIELD) and not self.player:HasBuffById(617) then
        print( "Casting Magical Shield" )
        EdanCombo.PressAndWait( Magician.Q, self.player.Position )
        return
    end

    -- Use Magic Lighthouse
    if Magician.Gui.MagicLighthouse and Magician.Gui.MagicLighthouseSlot ~= nil and EdanScout.MonstersInMeleeRange > 2 and self.player.HealthPercent <= Magician.Gui.MagicLighthouseHealthPercent and EdanSkills.SkillUsableCooldown(WITCH_MAGIC_LIGHTHOUSE) then
        print( "Casting Taunt Orb" )
        local slot = string.format([[quickSlot_UseSlot(%f)]], Magician.Gui.MagicLighthouseSlot)
        BDOLua.Execute(slot)
        EdanCombo.WaitUntilDone()
        return
    end

    -- Use Speed Spell
    if Magician.Gui.SpeedSpell and Magician.Gui.SpeedSpellSlot ~= nil and EdanScout.MonstersInMeleeRange == 0 and EdanSkills.SkillUsableCooldown( WITCH_SPEED_SPELL ) then
        print( "Casting Speed Buff from quickslot" )
        local slot = string.format([[quickSlot_UseSlot(%f)]], Magician.Gui.SpeedSpellSlot)
        BDOLua.Execute(slot)
        EdanCombo.WaitUntilDone()
        return
    end

    -- Use Sages Wisdom
    if Magician.Gui.SagesMemory and Magician.Gui.SagesMemorySlot ~= nil and #EdanScout.Monsters >= 3 and EdanSkills.SkillUsableCooldown(WITCH_SAGES_MEMORY)  and not self.player:HasBuffById(110) and (EdanSkills.SkillUsableCooldown(WITCH_METEOR_SHOWER) or (EdanSkills.SkillUsableCooldown(WITCH_BLIZZARD) or EdanSkills.SkillUsableCooldown(WITCH_ULTIMATE_BLIZZARD))) then
        print( "Casting Sages Wisdom" )
        local slot = string.format([[quickSlot_UseSlot(%f)]], Magician.Gui.SagesMemorySlot)
        BDOLua.Execute(slot)
        EdanCombo.WaitUntilDone()
        EdanCombo.Wait(300)
        return
    end

    -- Use Meteor Shower
    if Magician.Gui.MeteorShower and self.player:HasBuffById(110) and EdanSkills.SkillUsableCooldown(WITCH_METEOR_SHOWER) then
        print( "Casting Meteor Shower" )
        EdanCombo.SetActionStateAtPosition( Magician.S | Magician.LMB | Magician.RMB, self.monster.Position, 1000 )
        return
    end

    -- Use Blizzard
    if Magician.Gui.Blizzard and self.player:HasBuffById(110) and (EdanSkills.SkillUsableCooldown(WITCH_BLIZZARD) or EdanSkills.SkillUsableCooldown(WITCH_ULTIMATE_BLIZZARD)) then
        print( "Casting Blizzard" )
        EdanCombo.SetActionStateAtPosition( Magician.Shift | Magician.LMB | Magician.RMB, self.monster.Position, 4000 )
        return
    end

    -- Use Lightning + Residual
    if Magician.Gui.Lightning and EdanSkills.SkillUsableCooldown(WITCH_LIGHTNING) and (self.player.BlackRage < 100 or #EdanScout.Monsters >= 3) then
        if Magician.Gui.ResidualLightning and EdanSkills.SkillUsableCooldown(WITCH_RESIDUAL_LIGHTNING) then
            print( "Casting Lightning with Residual to follow" )
            EdanCombo.SetActionStateAtPosition( Magician.S | Magician.F, self.monster.Position, 1000 )
            print( "Casting Residual Lightning after Lightning" )
            EdanCombo.PressAndWait( Magician.RMB, self.monster.Position, 1000 )
            EdanCombo.Wait(1000)
        else
            print( "Casting Lightning" )
            EdanCombo.PressAndWait( Magician.S | Magician.F, self.monster.Position, 500 )
            EdanCombo.Wait(500)
        end
        return
    end

    -- Use Fireball + Explosion
    if Magician.Gui.Fireball and EdanSkills.SkillUsableCooldown(WITCH_FIREBALL) and self.player.ManaPercent > 10 then
        Bot.Pather:Stop()
        print( "Casting Fireball" )
        EdanCombo.SetActionState( Magician.S | Magician.LMB, 500 )
        if EdanScout.MonstersInMeleeRange == 0 then
            EdanCombo.WaitUntilNotDoing("^BT_Skill_Fireball_Cast_")
        end
        EdanCombo.PressAndWait(Magician.RMB, self.monster.Position)
        if Magician.Gui.FireballExplosion and self.player:HasBuffById(1001) and EdanSkills.SkillUsableCooldown(WITCH_FIREBALL_EXPLOSION) then
            print( "Casting Fireball Explosion" )
            EdanCombo.SetActionStateAtPosition( Magician.RMB, self.monster.Position, 1000 )
        end
        return
    end

    -- Use Multiple Magic Arrows
    if Magician.Gui.MultiArrow and Magician.Gui.MultiArrowSlot ~= nil and EdanSkills.SkillUsableCooldown(WITCH_MULTIPLE_MAGIC_ARROWS) then
        print( "Casting Multiple Magic Arrows" )
        local slot = string.format([[quickSlot_UseSlot(%f)]], Magician.Gui.MultiArrowSlot)
        BDOLua.Execute(slot)
        EdanCombo.WaitUntilDone()
        return
    end

    -- Use Lightning Chain + Storm
    if Magician.Gui.LightningChain and self.player.ManaPercent > 30 and EdanSkills.SkillUsable(WITCH_LIGHTNING_CHAIN) then
        Bot.Pather:Stop()
        print( "Casting Lightning Chain" )
        EdanCombo.HoldUntilDone( Magician.Shift | Magician.RMB, self.monster.Position )
        if Magician.Gui.LightningStorm and self.player:HasBuffById(1002) and EdanSkills.SkillUsable(WITCH_LIGHTNING_STORM) then
            print( "Casting Lightning Chain with Storm to follow" )
            EdanCombo.SetActionStateAtPosition( Magician.LMB | Magician.RMB, self.monster.Position, 1500 )
        end
        return
    end

    -- Use Concentrated Magical Arrow
    if Magician.Gui.ConcentratedArrow and EdanSkills.SkillUsable(WITCH_CONCENTRATED_MAGIC_ARROW) and self.player.ManaPercent > 15 then
        print( "Casting Concentrated Magic Arrow" )
        EdanCombo.SetActionStateAtPosition( Magician.LMB | Magician.RMB, self.monster.Position, 1000 )
        return
    end

    -- Use Magic Arrow
    if Magician.Gui.MagicArrow and EdanSkills.SkillUsable(WITCH_MAGIC_ARROW) then
        print( "Casting Magic Arrow" )
        EdanCombo.SetActionStateAtPosition( Magician.RMB, self.monster.Position )
        return
    end

    -- Use Dagger Stab
    if Magician.Gui.DaggerStab and EdanScout.MonstersInMeleeRange > 0 and EdanSkills.SkillUsableCooldown(WITCH_DAGGER_STAB) then
        print( "Using Dagger Stab" )
        EdanCombo.SetActionStateAtPosition( Magician.F, self.monster.Position, 200 )
        EdanCombo.Wait(500)
        return
    end
end

------------- Roaming ----------------------------------------------------------------------------------------------------
function Magician:Roaming()
    local selfPlayer = GetSelfPlayer()
    if not selfPlayer then return end

    if selfPlayer:CheckCurrentAction("BT_Skill_Fireball_Ing") then
        print("Fireball stuck as ROAMING starts...firing")
        selfPlayer:SetActionState( Magician.RMB, 500 )
        return
    end
    self.combos = nil

    if selfPlayer.IsActionPending then
        return
    end

    if selfPlayer.HealthPercent <= Magician.Gui.HealingAuraHealthPercent and EdanSkills.SkillUsableCooldown(WITCH_HEALING_AURA) then
        print( "Health Low out of comabt using Healing Aura" )
        selfPlayer:SetActionState( Magician.E )
        return
    end

end
------------- User Interface ---------------------------------------------------------------------------------------------
function Magician:UserInterface()
  if Magician.Gui.ShowGui then
    _, Magician.Gui.ShowGui = ImGui.Begin("Magician - Options", true, ImVec2(150, 50), -1.0, ImGuiWindowFlags_AlwaysAutoResize | ImGuiWindowFlags_NoResize)
    if Magician.Gui.MultiArrowSlot == nil and EdanSkills.GetSkill(WITCH_MULTIPLE_MAGIC_ARROWS) ~= 0 then
        ImGui.Text("Multiple Magic Arrow must be on a quickslot for it to work")
    end
    if Magician.Gui.SpeedSpellSlot == nil and EdanSkills.GetSkill(WITCH_SPEED_SPELL) ~= 0 then
        ImGui.Text("Speed Spell must be on a quickslot for it to work")
    end
    if Magician.Gui.SpellboundHeartSlot == nil and EdanSkills.GetSkill(WITCH_SPELLBOUND_HEART) ~= 0 then
        ImGui.Text("Spellbound Heart must be on a quickslot for it to work")
    end
    if Magician.Gui.MagicLighthouseSlot == nil and EdanSkills.GetSkill(WITCH_MAGIC_LIGHTHOUSE) ~= 0 then
        ImGui.Text("Magic Lighthouse must be on a quickslot for it to work")
    end
    if Magician.Gui.SagesMemorySlot == nil and EdanSkills.GetSkill(WITCH_SAGES_MEMORY) ~= 0 then
        ImGui.Text("Sages Memory must be on a quickslot for it to work")
    end
    if EdanSkills.GetSkill(WITCH_MULTIPLE_MAGIC_ARROWS) ~= 0 or EdanSkills.GetSkill(WITCH_SPEED_SPELL) ~= 0 or EdanSkills.GetSkill(WITCH_SPELLBOUND_HEART) ~= 0 or EdanSkills.GetSkill(WITCH_MAGIC_LIGHTHOUSE) ~= 0 or EdanSkills.GetSkill(WITCH_SAGES_MEMORY) ~= 0 then
        ImGui.Separator()
        ImGui.Columns(2, "SkillData", true)
        ImGui.TextColored(ImVec4(1,0.843,0,1), "Skill")
        ImGui.NextColumn()
        ImGui.TextColored(ImVec4(1,0.843,0,1), "QuickSlot")
        ImGui.NextColumn()
        ImGui.Separator()
        if EdanSkills.GetSkill(WITCH_MULTIPLE_MAGIC_ARROWS) ~= 0 then
            ImGui.Text("Multiple Magic Arrow")
            ImGui.NextColumn()
            ImGui.Text(tostring(Magician.Gui.MultiArrowSlot))
            ImGui.NextColumn()
        end
        if EdanSkills.GetSkill(WITCH_SPEED_SPELL) ~= 0 then
            ImGui.Text("Speed Spell")
            ImGui.NextColumn()
            ImGui.Text(tostring(Magician.Gui.SpeedSpellSlot))
            ImGui.NextColumn()
        end
        if EdanSkills.GetSkill(WITCH_SPELLBOUND_HEART) ~= 0 then
            ImGui.Text("Spellbound Heart")
            ImGui.NextColumn()
            ImGui.Text(tostring(Magician.Gui.SpellboundHeartSlot))
            ImGui.NextColumn()
        end
        if EdanSkills.GetSkill(WITCH_MAGIC_LIGHTHOUSE) ~= 0 then
            ImGui.Text("Magic Lighthouse")
            ImGui.NextColumn()
            ImGui.Text(tostring(Magician.Gui.MagicLighthouseSlot))
            ImGui.NextColumn()
        end
        if EdanSkills.GetSkill(WITCH_SAGES_MEMORY) ~= 0 then
            ImGui.Text("Sages Memory")
            ImGui.NextColumn()
            ImGui.Text(tostring(Magician.Gui.SagesMemorySlot))
            ImGui.NextColumn()
        end
        ImGui.Columns(1)
        ImGui.Separator()
        if ImGui.Button("Reload QuickSlots", ImVec2(ImGui.GetContentRegionAvailWidth(), 20)) then
            Magician.Gui.MultiArrowSlot = Magician:findQuickSlotById(EdanSkills.GetSkill(WITCH_MULTIPLE_MAGIC_ARROWS))
            Magician.Gui.SpeedSpellSlot = Magician:findQuickSlotById(EdanSkills.GetSkill(WITCH_SPEED_SPELL))
            Magician.Gui.SpellboundHeartSlot = Magician:findQuickSlotById(EdanSkills.GetSkill(WITCH_SPELLBOUND_HEART))
            Magician.Gui.MagicLighthouseSlot = Magician:findQuickSlotById(EdanSkills.GetSkill(WITCH_MAGIC_LIGHTHOUSE))
            Magician.Gui.SagesMemorySlot = Magician:findQuickSlotById(EdanSkills.GetSkill(WITCH_SAGES_MEMORY))
        end
    end
    if ImGui.CollapsingHeader( "Spell Options","id_spell_options" ,true ,true) then
        if EdanSkills.GetSkill(WITCH_FIREBALL) ~= 0 or EdanSkills.GetSkill(WITCH_FIREBALL_EXPLOSION) ~= 0 then
            if ImGui.TreeNode("Fireball Options") then
                if EdanSkills.GetSkill(WITCH_FIREBALL) ~= 0 then
                    _, Magician.Gui.Fireball = ImGui.Checkbox("Use Fireball##id_gui_fireball", Magician.Gui.Fireball)
                end
                if EdanSkills.GetSkill(WITCH_FIREBALL_EXPLOSION) ~= 0 then
                    _, Magician.Gui.FireballExplosion = ImGui.Checkbox("Use Fireball Explosion##id_gui_fireballexplosion", Magician.Gui.FireballExplosion)
                end
                ImGui.TreePop()
            end
        end
        if EdanSkills.GetSkill(WITCH_LIGHTNING) ~= 0 or EdanSkills.GetSkill(WITCH_RESIDUAL_LIGHTNING) ~= 0 or EdanSkills.GetSkill(WITCH_LIGHTNING_CHAIN) ~= 0 or EdanSkills.GetSkill(WITCH_LIGHTNING_STORM) ~= 0 then
            if ImGui.TreeNode("Lightning Options") then
                if EdanSkills.GetSkill(WITCH_LIGHTNING) ~= 0 then
                    _, Magician.Gui.Lightning = ImGui.Checkbox("Use Lightning##id_gui_lightning", Magician.Gui.Lightning)
                end
                if EdanSkills.GetSkill(WITCH_RESIDUAL_LIGHTNING) ~= 0 then
                    _, Magician.Gui.ResidualLightning = ImGui.Checkbox("Use Residual Lightning##id_gui_residuallightning", Magician.Gui.ResidualLightning)
                end
                if EdanSkills.GetSkill(WITCH_LIGHTNING_CHAIN) ~= 0 then
                    _, Magician.Gui.LightningChain = ImGui.Checkbox("Use Chain Lightning##id_gui_lightningchain", Magician.Gui.LightningChain)
                end
                if EdanSkills.GetSkill(WITCH_LIGHTNING_STORM) ~= 0 then
                    _, Magician.Gui.LightningStorm = ImGui.Checkbox("Use Lightning Storm##id_gui_lightningstorm", Magician.Gui.LightningStorm)
                end
                ImGui.TreePop()
            end
        end
        if ImGui.TreeNode("Magic Arrow Options") then
            _, Magician.Gui.MagicArrow = ImGui.Checkbox("Use Magic Arrow##id_gui_magicarrow", Magician.Gui.MagicArrow)
            if EdanSkills.GetSkill(WITCH_MULTIPLE_MAGIC_ARROWS) ~= 0 then
                _, Magician.Gui.MultiArrow = ImGui.Checkbox("Use Multiple Magic Arrow##id_gui_multiarrow", Magician.Gui.MultiArrow)
            end
            if EdanSkills.GetSkill(WITCH_CONCENTRATED_MAGIC_ARROW) ~= 0 then
                _, Magician.Gui.ConcentratedArrow = ImGui.Checkbox("Use Concentrated Magic Arrow##id_gui_concentratedarrow", Magician.Gui.ConcentratedArrow)
            end
            ImGui.TreePop()
        end
        if ImGui.TreeNode("Speed Buff Options") then
            if EdanSkills.GetSkill(WITCH_SPEED_SPELL) ~= 0 then
                _, Magician.Gui.SpeedSpell = ImGui.Checkbox("Use Speed Spell##id_gui_speedspell", Magician.Gui.SpeedSpell)
            end
            ImGui.TreePop()
        end
        if ImGui.TreeNode("Melee Options") then
            _, Magician.Gui.DaggerStab = ImGui.Checkbox("Use Dagger Stab##id_gui_daggerstab", Magician.Gui.DaggerStab)
            ImGui.TreePop()
        end
    end

    if ImGui.CollapsingHeader( "Recovery + Defense Options","id_defensive_options" ,true ,true) then

        if ImGui.TreeNode("Health Recovery Options") then
            if EdanSkills.GetSkill(WITCH_HEALING_AURA) ~= 0 then
                _, Magician.Gui.HealingAura = ImGui.Checkbox("Use Healing Aura##id_gui_healingaura", Magician.Gui.HealingAura)
                --ImGui.SameLine()
                --_, Magician.Gui.LockHA = ImGui.Checkbox("Lock Values##id_gui_lockhealingaura", Magician.Gui.LockHA)
                if Magician.Gui.HealingAura then --and not Magician.Gui.LockHA then
                    _, Magician.Gui.HealingAuraHealthPercent = ImGui.SliderInt("HP%##id_gui_healingaura_hp", Magician.Gui.HealingAuraHealthPercent, 1, 95)
                    _, Magician.Gui.HealingAuraManaPercent = ImGui.SliderInt("MP%##id_gui_healingaura_mp", Magician.Gui.HealingAuraManaPercent, 1, 95)
                end
            end

            if EdanSkills.GetSkill(WITCH_HEALING_LIGHTHOUSE) ~= 0 then
                _, Magician.Gui.HealingLighthouse = ImGui.Checkbox("Use Healing Lighthouse##id_gui_healinglighthouse", Magician.Gui.HealingLighthouse)
                --ImGui.SameLine()
                --_, Magician.Gui.LockHL = ImGui.Checkbox("Lock Values##id_gui_lockhealinglighthouse", Magician.Gui.LockHL)
                if Magician.Gui.HealingLighthouse then --and not Magician.Gui.LockHL then
                    _, Magician.Gui.HealingLighthouseHealthPercent = ImGui.SliderInt("HP%##id_gui_healinglighthouse_hp", Magician.Gui.HealingLighthouseHealthPercent, 1, 95)
                    _, Magician.Gui.HealingLighthouseManaPercent = ImGui.SliderInt("MP%##id_gui_healinglighthouse_mp", Magician.Gui.HealingLighthouseManaPercent, 1, 95)
                end
            end

            ImGui.TreePop()
        end


        if ImGui.TreeNode("Mana Recovery Options") then
            if EdanSkills.GetSkill(WITCH_MANA_ABSORPTION) ~= 0 then
                _, Magician.Gui.MagicAbsorb = ImGui.Checkbox("Use Mana Drain##id_gui_manadrain", Magician.Gui.MagicAbsorb)
                --ImGui.SameLine()
                --_, Magician.Gui.LockMA = ImGui.Checkbox("Lock Value##id_gui_lockmanadrain", Magician.Gui.LockMA)
                if Magician.Gui.MagicAbsorb then --and not Magician.Gui.LockMA then
                    _, Magician.Gui.MagicAbsorbManaPercent = ImGui.SliderInt("MP%##id_gui_manadrain_mp", Magician.Gui.MagicAbsorbManaPercent, 1, 95)
                end
            end

            if EdanSkills.GetSkill(WITCH_SPELLBOUND_HEART) ~= 0 then
                _, Magician.Gui.SpellboundHeart = ImGui.Checkbox("Use Spellbound Heart##id_gui_spellboundheart", Magician.Gui.SpellboundHeart)
                --ImGui.SameLine()
                --_, Magician.Gui.LockSB = ImGui.Checkbox("Lock Value##id_gui_lockspellboundheart", Magician.Gui.LockSB)
                if Magician.Gui.SpellboundHeart then --and not Magician.Gui.LockSB then
                    _, Magician.Gui.SpellboundHeartManaPercent = ImGui.SliderInt("MP%##id_gui_spellboundheart_mp", Magician.Gui.SpellboundHeartManaPercent, 1, 95)
                end
            end

            ImGui.TreePop()
        end

        if ImGui.TreeNode("Defense Options") then
            if EdanSkills.GetSkill(WITCH_MAGICAL_SHIELD) ~= 0 then
                _, Magician.Gui.MagicShield = ImGui.Checkbox("Use Magic Shield##id_gui_magicshield", Magician.Gui.MagicShield)
                --ImGui.SameLine()
                --_, Magician.Gui.LockMS = ImGui.Checkbox("Lock Value##id_gui_lockmagicshield", Magician.Gui.LockMS)
                if Magician.Gui.MagicShield then --and not Magician.Gui.LockMS then
                    _, Magician.Gui.MagicShieldHealthPercent = ImGui.SliderInt("HP%##id_gui_magicshield_hp", Magician.Gui.MagicShieldHealthPercent, 1, 95)
                end
            end

            if EdanSkills.GetSkill(WITCH_MAGIC_LIGHTHOUSE) ~= 0 then
                _, Magician.Gui.MagicLighthouse = ImGui.Checkbox("Use Magic Lighthouse##id_gui_magiclighthouse", Magician.Gui.MagicLighthouse)
                --ImGui.SameLine()
                --_, Magician.Gui.LockML = ImGui.Checkbox("Lock Value##id_gui_lockmagiclighthouse", Magician.Gui.LockML)
                if Magician.Gui.MagicLighthouse then --and not Magician.Gui.LockML then
                    _, Magician.Gui.MagicLighthouseHealthPercent = ImGui.SliderInt("HP%##id_gui_magiclighthouse_hp", Magician.Gui.MagicLighthouseHealthPercent, 1, 95)
                end
            end

            ImGui.TreePop()
        end

    end

    if EdanSkills.GetSkill(WITCH_BLIZZARD) ~= 0 or EdanSkills.GetSkill(WITCH_ULTIMATE_BLIZZARD) ~= 0 or EdanSkills.GetSkill(WITCH_METEOR_SHOWER) ~= 0 then
        if ImGui.CollapsingHeader( "Cooldown Options","id_cd_options" ,true ,true) then
            _, Magician.Gui.SagesMemory = ImGui.Checkbox("Use Sages Memory##id_gui_sagememory", Magician.Gui.SagesMemory)
            if Magician.Gui.SagesMemory then
                if EdanSkills.GetSkill(WITCH_BLIZZARD) ~= 0 or EdanSkills.GetSkill(WITCH_ULTIMATE_BLIZZARD) ~= 0 then
                    _, Magician.Gui.Blizzard = ImGui.Checkbox("Use Blizzard##id_gui_blizzard", Magician.Gui.Blizzard)
                end
                if EdanSkills.GetSkill(WITCH_METEOR_SHOWER) ~= 0 then
                    _, Magician.Gui.MeteorShower = ImGui.Checkbox("Use Meteor Shower##id_gui_meteorshower", Magician.Gui.MeteorShower)
                end
            end
        end
    end
    ImGui.End()

    -- NOT YET IMPLEMENTED
    -- _, Magician.Gui.MagicEvasion = ImGui.Checkbox("##id_gui_", )
    -- _, Magician.Gui.StaffAttck = ImGui.Checkbox("##id_gui_", )
    -- _, Magician.Gui.Teleport = ImGui.Checkbox("##id_gui_", )
    -- _, Magician.Gui.Freeze = ImGui.Checkbox("##id_gui_", )
    -- _, Magician.Gui.FrigidFog = ImGui.Checkbox("##id_gui_", )
    -- _, Magician.Gui.EarthsResponse = ImGui.Checkbox("##id_gui_", )
    -- _, Magician.Gui.Earthquake = ImGui.Checkbox("##id_gui_", )
    -- _, Magician.Gui.ProtectedArea = ImGui.Checkbox("##id_gui_", )
  end
end

--------------------------------------------------------------------------------------------------------------------------
return setmetatable({}, Magician)
