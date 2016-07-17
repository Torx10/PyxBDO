Feral = { }
Feral.__index = Feral
Feral.Version = "1.0"
Feral.Author = "torx"
Feral.Gui = { }
Feral.Gui.ShowGui = false
Feral.GrinderVersion = 2

local trampleCount = 0

------------- Gui Settings -----------------------------------------------------------------------------------------------
-- Pet Options
Feral.Gui.Pet = true
Feral.Gui.PetAttack = true
Feral.Gui.PetQuickSlot = nil
Feral.Gui.PetAttackSlot = nil
-- Flash Options
Feral.Gui.Flash = true
-- Pole Thrust Options
Feral.Gui.PoleThrust = true
-- Bolt Options
Feral.Gui.Bolt = true
-- Jolt Options
Feral.Gui.Jolt = true
-- Trample Options
Feral.Gui.Trample = true
Feral.Gui.TrampleManaPercent = 70
-- Upward Claw Options
Feral.Gui.UpwardClaw = true
Feral.Gui.UpwardClawManaPercent = 60
-- Whiplash Options
Feral.Gui.Whiplash = true
Feral.Gui.WhiplashManaPercent = 70
-- Void Lightning Options
Feral.Gui.Void = true
Feral.Gui.VoidManaPercent = 60
Feral.Gui.VoidMonsterCount = 4
-- Legendary Beast Power Options
Feral.Gui.LBP = true
Feral.Gui.LBPStam = 200
Feral.Gui.LBPManaPercent = 10
-- Soaring Kick Options
Feral.Gui.SoaringKick = true

------------- SetActionState Buttons -------------------------------------------------------------------------------------
Feral.LMB        = ACTION_FLAG_MAIN_ATTACK
Feral.RMB        = ACTION_FLAG_SECONDARY_ATTACK
Feral.Shift      = ACTION_FLAG_EVASION
Feral.Space      = ACTION_FLAG_JUMP
Feral.Q          = ACTION_FLAG_SPECIAL_ACTION_1
Feral.E          = ACTION_FLAG_SPECIAL_ACTION_2
Feral.F          = ACTION_FLAG_SPECIAL_ACTION_3
Feral.W          = ACTION_FLAG_MOVE_FORWARD
Feral.S          = ACTION_FLAG_MOVE_BACKWARD
Feral.A          = ACTION_FLAG_MOVE_LEFT
Feral.D          = ACTION_FLAG_MOVE_RIGHT
Feral.Z          = ACTION_FLAG_PARTNER_COMMAND_1
Feral.X          = ACTION_FLAG_PARTNER_COMMAND_2
Feral.C          = ACTION_FLAG_AWEKENED_GEAR
Feral.V          = ACTION_FLAG_EMERGENCY_ESCAPE

------------- functions --------------------------------------------------------------------------------------------------
function Feral:PetCheck()
    local mountCount = BDOLua.Execute("return getSelfPlayer():getSummonListCount()")
    local pet = 0
    for i= 0, mountCount - 1 do
        local info = tonumber(BDOLua.Execute("return getSelfPlayer():getSummonDataByIndex(".. i .."):getCharacterKey()"))
        if (60028 <= info and info <= 60087) or 60129 == info then
            pet = pet + 1
            break
        end
    end
    if pet > 0 then
        return true
    else
        return false
    end
end

function Feral:findQuickSlotById(skillId)
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

if Feral.Gui.PetQuickSlot == nil and EdanSkills.GetSkill(TAMER_SUMMON_HEILANG) ~= 0 then
    Feral.Gui.PetQuickSlot = Feral:findQuickSlotById(EdanSkills.GetSkill(TAMER_SUMMON_HEILANG))
end
if Feral.Gui.PetAttackSlot == nil and EdanSkills.GetSkill(TAMER_COMMAND_ATTACK) ~= 0 then
    Feral.Gui.PetAttackSlot = Feral:findQuickSlotById(EdanSkills.GetSkill(TAMER_COMMAND_ATTACK))
end

------------- Attack Rotation --------------------------------------------------------------------------------------------
function Feral:Attack(monster, isPull)
    local player = GetSelfPlayer()
    if not player or not monster then
    	self.combos = nil
    	return
    end

    if isPull and player.IsActionPending then
        return
    end

    local distance = monster.Position.Distance2DFromMe - monster.BodySize - player.BodySize

    if distance > 150 or not monster.IsLineOfSight or player.IsSwimming then
        if player.CurrentActionName == "BT_Skill_IronPunch_SC_UP2" or player.CurrentActionName == "BT_Skill_WallBreak_SC_UP3" then
            print("Pushed em too hard with our BJ ( ‾ʖ̫‾)")
            player:SetActionState( Feral.Shift | Feral.Space, 100 )
            return
        elseif player.CurrentActionName == "BT_SKill_Senkou_UP3" or player.CurrentActionName == "BT_Skill_Senkou_SpearUP2" or player.CurrentActionName == "BT_Skill_Senkou_Grip_UP" then
            print("Stuck in flash or pole animation lets end this!")
            player:SetActionState( Feral.Shift | Feral.Space, 100 )
        end
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

    -- copy any variables you want to use in your combo routine here
    self.distance = distance
    self.player = player
    self.monster = monster
    self.ispull = isPull

    -- execute combos
    if self.combos == nil or coroutine.status(self.combos) == 'dead' then
        self.combos = coroutine.create(self.Combos)
    end

    local result,err = coroutine.resume(self.combos, self)
    if err then
        print("Combo error: "..err)
    end

end

------------- Combos -----------------------------------------------------------------------------------------------------
function Feral:Combos()
    if self.player.IsActionPending then
        return
    end

    local wolfy = Feral:PetCheck()

    Bot.Pather:Stop()

    if Feral.Gui.Pet and Feral.Gui.PetQuickSlot ~= nil and wolfy == false and EdanSkills.SkillUsableCooldown(TAMER_SUMMON_HEILANG) then
        print("Call Wolfy from slot " .. Feral.Gui.PetQuickSlot)
        local slot = string.format([[quickSlot_UseSlot(%f)]], Feral.Gui.PetQuickSlot)
        BDOLua.Execute(slot)
        EdanCombo.WaitUntilDone()
    end

    if EdanScout.MonstersInMeleeRange <= 3 then
        -- Set pet to attck target
        if Feral.Gui.PetAttack and Feral.Gui.PetQuickSlot ~= nil then
            print("ATTACK MY BEAST ... ATTTAAAACCCKKKK" .. Feral.Gui.PetAttackSlot)
            local slot = string.format([[quickSlot_UseSlot(%f)]], Feral.Gui.PetAttackSlot)
            BDOLua.Execute(slot)
        end

        --flash and polethrust
        if Feral.Gui.Flash and EdanSkills.SkillUsableCooldown(TAMER_FLASH) then
            print("Flash the mob ^_~ *cheeky*")
            EdanCombo.SetActionStateAtPosition( Feral.S | Feral.LMB, self.monster.Position, 100 )
            if Feral.Gui.PoleThrust and EdanSkills.SkillUsableCooldown(TAMER_FLASH_POLE_THRUST) then
                print( "Give em a bit of the Pole ( ͡° ͜ʖ ͡°)" )
                EdanCombo.SetActionStateAtPosition( Feral.S | Feral.LMB, self.monster.Position, 500 )
                return
            end
            return
        end

        --bolt jolt trample
        if Feral.Gui.Bolt and EdanSkills.SkillUsableCooldown( TAMER_BOLT_WAVE ) then
            print("Give Em a bolt")
            EdanCombo.SetActionStateAtPosition( Feral.Shift | Feral.LMB, self.monster.Position, 100 )
            if Feral.Gui.Jolt and EdanSkills.SkillUsableCooldown( TAMER_JOLT_WAVE ) then
                print("Follow it with a Jolt")
                EdanCombo.SetActionStateAtPosition( Feral.Shift | Feral.LMB, self.monster.Position, 100 )
                if trampleCount < 2  then
                    print("Trample?")
                    EdanCombo.SetActionStateAtPosition( Feral.Space, self.monster.Position, 100)
                    trampleCount = trampleCount + 1
                    return
                else
                    print("LBP Cancel?")
                    EdanCombo.SetActionState( Feral.Shift | Feral.Space, 100)
                    trampleCount = 0
                    return
                end
            end
        end

        --upward claw
        if Feral.Gui.UpwardClaw and EdanSkills.SkillUsableCooldown( TAMER_HEILANG_UPWARD_CLAW ) then
            print("WOLFY CLAW")
            EdanCombo.SetActionStateAtPosition( Feral.Shift | Feral.RMB, self.monster.Position, 100 )
            return
        end

        --whiplash
        if Feral.Gui.Whiplash and EdanSkills.SkillUsableCooldown( TAMER_HEILANG_WHIPLASH ) then
            print("Whip yeah whip it good!")
            EdanCombo.HoldUntilDone( Feral.RMB, self.monster.Position, 300 )
            return
        end

    else
        -- Set pet to attck target
        if Feral.Gui.PetAttack and Feral.Gui.PetQuickSlot ~= nil then
            print("ATTACK MY BEAST ... ATTTAAAACCCKKKK" .. Feral.Gui.PetAttackSlot)
            local slot = string.format([[quickSlot_UseSlot(%f)]], Feral.Gui.PetAttackSlot)
            BDOLua.Execute(slot)
        end
        --flash and polethrust
        if Feral.Gui.Flash and EdanSkills.SkillUsableCooldown(TAMER_FLASH) then
            print("Flash the mobs (.)(.) Boobies")
            EdanCombo.SetActionStateAtPosition( Feral.S | Feral.LMB, self.monster.Position, 100 )
            if Feral.Gui.PoleThrust and EdanSkills.SkillUsableCooldown(TAMER_FLASH_POLE_THRUST) then
                print( "Let em touch the Pole ( ͡° ͜ʖ ͡°)" )
                EdanCombo.SetActionStateAtPosition( Feral.S | Feral.LMB, self.monster.Position, 500 )
                return
            end
            return
        end

        -- Soaring Kick
        if Feral.Gui.SoaringKick and EdanSkills.SkillUsableCooldown(TAMER_SOARING_KICK) then
            print("I believe I can SOAR and KICK some fucker in the head")
            EdanCombo.SetActionStateAtPosition( Feral.E, self.monster.Position, 100 )
            return
        end

         -- Void Lightning
        if Feral.Gui.Void and wolfy == true and (self.player.ManaPercent >= Feral.Gui.VoidManaPercent) and EdanSkills.SkillUsableCooldown(TAMER_VOID_LIGHTNING) then --and EdanScout.MonstersInMeleeRange >= Feral.Gui.VoidMonsterCount
            print("Void some lightning while Wolfsies out!!")
            EdanCombo.SetActionStateAtPosition(Feral.Q, self.monster.Position, 2000)
            print("Cancel void with some speed shit!!")
            EdanCombo.SetActionState(Feral.Shift | Feral.Space, 100)
            return
        end

        --bolt jolt trample
        if Feral.Gui.Bolt and EdanSkills.SkillUsableCooldown( TAMER_BOLT_WAVE ) then
            print("Give Em a bolt")
            EdanCombo.SetActionStateAtPosition( Feral.Shift | Feral.LMB, self.monster.Position, 100 )
            if Feral.Gui.Jolt and EdanSkills.SkillUsableCooldown( TAMER_JOLT_WAVE ) then
                print("Follow it with a Jolt")
                EdanCombo.SetActionStateAtPosition( Feral.Shift | Feral.LMB, self.monster.Position, 100 )
                if trampleCount < 2 then
                    print("Trample? maybe it cancels?")
                    EdanCombo.SetActionStateAtPosition( Feral.Space, self.monster.Position, 100)
                    trampleCount = trampleCount + 1
                    return
                else
                    print("LBP Cancel?")
                    EdanCombo.SetActionState( Feral.Shift | Feral.Space, 100)
                    trampleCount = 0
                    return
                end
            end
        end

        --upward claw
        if Feral.Gui.UpwardClaw and EdanSkills.SkillUsableCooldown( TAMER_HEILANG_UPWARD_CLAW ) then
            print("WOLFY CLAW! T_T")
            EdanCombo.SetActionStateAtPosition( Feral.Shift | Feral.RMB, self.monster.Position, 100 )
            return
        end

        --whiplash
        if Feral.Gui.Whiplash and EdanSkills.SkillUsableCooldown( TAMER_HEILANG_WHIPLASH ) then
            print("Whip yeah whip it good!")
            EdanCombo.HoldUntilDone( Feral.RMB, self.monster.Position, 300 )
            return
        end

    end
end

------------- Roaming ----------------------------------------------------------------------------------------------------
function Feral:Roaming()
    local selfPlayer = GetSelfPlayer()
    if not selfPlayer then
        return
    end

    if Feral.Gui.PetQuickSlot == nil then
        Feral.Gui.PetQuickSlot = Feral:findQuickSlotById(EdanSkills.GetSkill(TAMER_SUMMON_HEILANG))
    end
    if Feral.Gui.PetAttackSlot == nil then
        Feral.Gui.PetAttackSlot = Feral:findQuickSlotById(EdanSkills.GetSkill(TAMER_COMMAND_ATTACK))
    end

    local wolfy = Feral:PetCheck()

    if Feral.Gui.Pet and Feral.Gui.PetQuickSlot ~= nil and wolfy == false and EdanSkills.SkillUsableCooldown(TAMER_SUMMON_HEILANG) then
        print("Call Wolfy from slot " .. Feral.Gui.PetQuickSlot)
        local slot = string.format([[quickSlot_UseSlot(%f)]], Feral.Gui.PetQuickSlot)
        BDOLua.Execute(slot)
        --EdanCombo.WaitUntilDone()
    end


    self.combos = nil

    if selfPlayer.CurrentActionName == "BT_Skill_IronPunch_SC_UP2" or selfPlayer.CurrentActionName == "BT_Skill_WallBreak_SC_UP3" then
        print("Combat over but still bolting or jolting... what what lets fix that!")
        selfPlayer:SetActionState( Feral.Shift | Feral.Space, 100 )
        return
    end

    if selfPlayer.CurrentActionName == "BT_SKill_Senkou_UP3" or selfPlayer.CurrentActionName == "BT_Skill_Senkou_SpearUP2" or selfPlayer.CurrentActionName == "BT_Skill_Senkou_Grip_UP" then
        print("Stuck in flash or pole animation lets end this!")
        selfPlayer:SetActionState( Feral.Shift | Feral.Space, 100 )
    end
end

------------- User Interface ---------------------------------------------------------------------------------------------
function Feral:UserInterface()
    if Feral.Gui.ShowGui then
        _, Feral.Gui.ShowGui = ImGui.Begin("Feral - Options", true, ImVec2(150, 450), -1.0) --, ImGuiWindowFlags_AlwaysAutoResize | ImGuiWindowFlags_NoResize)
        if EdanSkills.GetSkill(TAMER_SUMMON_HEILANG) ~= 0 then
            if Feral.Gui.PetQuickSlot == nil or Feral.Gui.PetAttackSlot == nil then
                ImGui.TextColored(ImVec4(1,0,0,1), "Summon Heilang skill and Command: Attack skill")
                ImGui.TextColored(ImVec4(1,0,0,1), "must be put on the quickslot bar for those skills to work")
            end
            ImGui.Separator()
            ImGui.Columns(2, "SkillData", true)
            ImGui.TextColored(ImVec4(1,0.843,0,1), "Skill")
            ImGui.NextColumn()
            ImGui.TextColored(ImVec4(1,0.843,0,1), "QuickSlot")
            ImGui.NextColumn()
            ImGui.Separator()
            ImGui.Text("Summon Heilang")
            ImGui.NextColumn()
            if Feral.Gui.PetQuickSlot ~= nil then
                ImGui.Text(tostring(math.floor((Feral.Gui.PetQuickSlot + 1))))
            else
                ImGui.Text(tostring(Feral.Gui.PetQuickSlot))
            end
            ImGui.NextColumn()
            ImGui.Text("Command: Attack skill")
            ImGui.NextColumn()
            if Feral.Gui.PetAttackSlot ~= nil then
                ImGui.Text(tostring(math.floor((Feral.Gui.PetAttackSlot + 1))))
            else
                ImGui.Text(tostring(Feral.Gui.PetAttackSlot))
            end
            ImGui.NextColumn()
            ImGui.Columns(1)
            ImGui.Separator()
            if ImGui.Button("Reload QuickSlots", ImVec2(ImGui.GetContentRegionAvailWidth(), 20)) then
                Feral.Gui.PetQuickSlot = Feral:findQuickSlotById(EdanSkills.GetSkill(TAMER_SUMMON_HEILANG))
                Feral.Gui.PetAttackSlot = Feral:findQuickSlotById(EdanSkills.GetSkill(TAMER_COMMAND_ATTACK))
            end
            if ImGui.CollapsingHeader( "Pet Options","id_pet_options" ,true ,true) then
                if ImGui.TreeNode("Pet Summon Options") then
                    _, Feral.Gui.Pet = ImGui.Checkbox("Use Pet##id_gui_pet", Feral.Gui.Pet)
                    _, Feral.Gui.PetAttack = ImGui.Checkbox("Make Pet Attack##id_gui_petattack", Feral.Gui.PetAttack)
                    ImGui.TreePop()
                end
            end
        end
        if ImGui.CollapsingHeader( "Spell Options","id_spell_options" ,true ,true) then
            if ImGui.TreeNode("Void Lightning Options") then
                _, Feral.Gui.Void = ImGui.Checkbox("Use Void Lightning##id_gui_void", Feral.Gui.Void)
                _, Feral.Gui.VoidManaPercent = ImGui.SliderInt("MP%##id_gui_voidmanapercent", Feral.Gui.VoidManaPercent, 1, 100)
                ImGui.TreePop()
            end
            _, Feral.Gui.Flash = ImGui.Checkbox("Use Flash##id_gui_flash", Feral.Gui.Flash)
            _, Feral.Gui.PoleThrust = ImGui.Checkbox("Use Pole Thrust##id_gui_pole", Feral.Gui.PoleThrust)
            _, Feral.Gui.Bolt = ImGui.Checkbox("Use Bolt##id_gui_bolt", Feral.Gui.Bolt)
            _, Feral.Gui.Jolt = ImGui.Checkbox("Use Jolt##id_gui_jolt", Feral.Gui.Jolt)
            --_, Feral.Gui.Trample = ImGui.Checkbox("Use Trample##id_gui_trample", Feral.Gui.Trample)
            _, Feral.Gui.UpwardClaw = ImGui.Checkbox("Use Upward Claw##id_gui_upwardclaw", Feral.Gui.UpwardClaw)
            _, Feral.Gui.Whiplash = ImGui.Checkbox("Use Whiplash##id_gui_whiplash", Feral.Gui.Whiplash)
            _, Feral.Gui.SoaringKick = ImGui.Checkbox("Use Soaring Kick##id_gui_soaringkick", Feral.Gui.SoaringKick)
        end
        ImGui.End()
    end
end

return setmetatable({}, Feral)