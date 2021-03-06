Bot = { }
Bot.Settings = Settings()
Bot.Running = false
Bot.Paused = false
Bot.PausedManual = false
Bot.WasRunning = false
Bot.PrintConsoleState = false
Bot.EnableDebug = false
Bot.EnableDebugMainWindow = false
Bot.EnableDebugProfileEditor = false
Bot.EnableDebugInventory = false
Bot.EnableDebugDeathState = false
Bot.EnableDebugEquipFishignRodState = false
Bot.EnableDebugEquipFloatState = false
Bot.EnableDebugHookFishState = false
Bot.EnableDebugHookHandleGameState = false
Bot.EnableDebugInventoryDeleteState = false
Bot.SecurityState = SecurityState()
Bot.RoamingState = RoamingState()
Bot.EnableDebugLootState = false
Bot.EnableDebugRepairState = false
Bot.EnableDebugStartFishingState = false
Bot.EnableDebugTradeManagerState = false
Bot.EnableDebugVendorState = false
Bot.EnableDebugWarehouseState = false

Bot._switchTimer = PyxTimer:New(2)

Bot.Fsm = FSM()
Bot.Pather = Pather:New(MyGraph())
Bot.Combat = nil
Bot.CombatPull = nil
-- Converted to CommonStates
Bot.WarehouseState = WarehouseState()
Bot.TurninState = TurninState()
Bot.VendorState = VendorState()
Bot.DeathState = DeathState()
Bot.RepairState = RepairState()
Bot.LootState = LootActorState()
Bot.InventoryDeleteState = InventoryDeleteState()
Bot.SecurityState = SecurityState()
Bot.RoamingState = RoamingState()
Bot.DoReset = false
Bot.SleepTimer = nil
Bot.LastPauseTick = nil
Bot.LoopCounter = 0
Bot.Time = nil
Bot.Hours = nil
Bot.Minutes = nil
Bot.Seconds = nil

Bot.Counter = 0
Bot.PlayerAudioPause = PyxTimer:New(1.5)
Bot.PlayerChangeHotSpotPause = PyxTimer:New(60)


-- Not Converted yet
Bot.CombatFightState = CombatFightState()
Bot.CombatPullState = CombatPullState()


-- Bot.Fsm:AddState(RoamingState())
-- Bot.Fsm:AddState(IdleState())

function Bot.KillListCompareFunction(objecta, objectb)

    if objecta.Guid == objectb.Guid then
        return true
    end
    return false
end
Bot.KillList = PyxTimedList:New(Bot.KillListCompareFunction)

function Bot.FormatMoney(amount)
    -- used the example from here: http://lua-users.org/wiki/FormattingNumbers
    local formatted = amount
    while true do
        formatted, k = string.gsub(formatted, "^(-?%d+)(%d%d%d)", '%1.%2')
        -- comma to separate the thousands
        if (k == 0) then
            break
        end
    end
    return formatted
end

function Bot.ResetStats()
    Bot.Stats = {
        SilverInitial = GetSelfPlayer().Inventory.Money,
        SilverGained = 0,
        KillCount = 0,
        -- Loots = 0,
        -- AverageLootTime = 0,
        -- LootQuality = {},
        -- Fishes = 0,
        -- Shards = 0,
        -- Keys = 0,
        -- Eggs = 0,
        -- Trashes = 0,
        -- LootTimeCount = 0,
        -- LastLootTick = 0,
        -- TotalLootTime = 0,
        SessionStart = Pyx.Win32.GetTickCount(),
        TotalSession = 0,
    }
end

function Bot.SilverStats(deposit)
    if not deposit then
        Bot.Stats.SilverGained = Bot.Stats.SilverGained +(GetSelfPlayer().Inventory.Money - Bot.Stats.SilverInitial)
    end
    Bot.Stats.SilverInitial = GetSelfPlayer().Inventory.Money
end

Bot.ResetStats()


function Bot.GetPlayers(onlyPvpFlagged)
    local actors = GetActors()
    local players = { }

    for key, value in pairs(actors) do
        if value.IsPlayer then
            if (onlyPvpFlagged == nil or onlyPvpFlagged == false) or(onlyPvpFlagged == true and value.IsPvpEnable == true) then
                players[#players] = value
            end

        end
    end
    return players
end

function Bot.LoadCombat()
    local combatScriptFile = Bot.Settings.CombatScript
    local code = Pyx.FileSystem.ReadFile("Combats/" .. combatScriptFile)
    combatScriptFunc, combatScriptError = load(code)
    if combatScriptFunc == nil then
        print(string.format("Unable to load combat script: func %s err %s", tostring(combatScriptFunc), tostring(combatScriptError)))
        return
    end
    Bot.Combat = combatScriptFunc()

    if not Bot.Combat then
        print("Unable to load combat script !")
        Bot.Combat = nil
        return
    end

    if not Bot.Combat.Attack then
        print("Combat script doesn't have .Attack function !")
        Bot.Combat = nil
        return
    end

    if not Bot.Combat.GrinderVersion or Bot.Combat.GrinderVersion ~= 2 then
        print("Combat script is not marked as Grinder2 Compatable!")
        Bot.Combat = nil
        return
    end

    if Bot.Combat.Gui then
        BotSettings.LoadCombatSettings()
    end
end

function Bot.Start()
    if not Bot.Running then
        Bot.RepairState.Forced = false
        Bot.WarehouseState.Forced = false
        Bot.TurninState.Forced = false
        Bot.VendorState.Forced = false
        Bot.SaveSettings()
        Bot.Stats.SessionStart = Pyx.Win32.GetTickCount()
        Bot.Pather.Graph = ProfileEditor.CurrentGraph

        local currentProfile = ProfileEditor.CurrentProfile

        if not currentProfile then
            print("No profile loaded !")
            return
        end

        if Bot.MeshDisabled ~= true and table.length(currentProfile.Hotspots) < 1 then
            print("Profile requires at least 1 hotspots !")
            return
        end

        Bot.LoadCombat()

        if Bot.Combat == nil then
            print("Must choose a valid Combat Script")
            return
        end

        if Bot.MeshDisabled == true then
            PathRecorder.RealPulse = PathRecorder.Pulse
            PathRecorder.Pulse = function(self) end
        end

        --[[
        ProfileEditor.MeshConnectEnabled = false
        Navigator.MeshConnects = ProfileEditor.CurrentProfile.MeshConnects
        --]]

        Bot.WarehouseState:Reset()
        Bot.TurninState:Reset()
        Bot.VendorState:Reset()
        Bot.RepairState:Reset()
        Bot.DeathState:Reset()
        Bot.SecurityState:Reset()

        Bot.Pather.Fallback = Bot.Settings.PatherFallBack

        Bot.Pather.Graph = ProfileEditor.PathRecorder.Graph
        Bot.Pather:Reset()

        Bot.WarehouseState.Settings.NpcName = currentProfile.WarehouseNpcName
        Bot.WarehouseState.Settings.NpcPosition = currentProfile.WarehouseNpcPosition

        Bot.WarehouseState.CallWhenCompleted = Bot.StateComplete
        Bot.WarehouseState.CallWhileMoving = Bot.StateMoving

        Bot.TurninState.Settings.NpcName = currentProfile.TurninNpcName
        Bot.TurninState.Settings.NpcPosition = currentProfile.TurninNpcPosition

        Bot.TurninState.CallWhenCompleted = Bot.StateComplete
        Bot.TurninState.CallWhileMoving = Bot.StateMoving

        Bot.VendorState.Settings.NpcName = currentProfile.VendorNpcName
        Bot.VendorState.Settings.NpcPosition = currentProfile.VendorNpcPosition

        Bot.VendorState.CallWhenCompleted = Bot.StateComplete
        Bot.VendorState.CallWhileMoving = Bot.StateMoving

        Bot.DeathState.CallWhenCompleted = Bot.Death

        Bot.RepairState.Settings.NpcName = currentProfile.RepairNpcName
        Bot.RepairState.Settings.NpcPosition = currentProfile.RepairNpcPosition

        Bot.RepairState.CallWhileMoving = Bot.StateMoving

        Bot.LootState.CallWhileMoving = Bot.StateMoving

        Bot.SecurityState.PlayerDetectedFunction = Bot.PlayerAlarm
        Bot.SecurityState.TeleportDetectedFunction = Bot.TeleportAlarm

        Bot.RoamingState.Hotspots = ProfileEditor.CurrentProfile.Hotspots

        Bot.LootState.LootAreaList = Bot.KillList

        if Bot.MeshDisabled ~= true then
            ProfileEditor.Visible = false
            ProfileEditor.PathRecorder.Enabled = false
        end
        Bot.Pather.OnStuckCall = Bot.OnStuck
        Bot.Fsm = FSM()
        Bot.Fsm.ShowOutput = true

        if Bot.MeshDisabled ~= true then
            Bot.Fsm:AddState(Bot.SecurityState)
            Bot.Fsm:AddState(Bot.DeathState)
            Bot.Fsm:AddState(LibConsumables.ConsumablesState)
            Bot.Fsm:AddState(Bot.LootState.CombatLootState)
            Bot.Fsm:AddState(Bot.CombatFightState)
            Bot.Fsm:AddState(Bot.TurninState)
            Bot.Fsm:AddState(Bot.VendorState)
            Bot.Fsm:AddState(Bot.WarehouseState)
            Bot.Fsm:AddState(Bot.RepairState)
            Bot.Fsm:AddState(Bot.LootState)
            Bot.Fsm:AddState(Bot.InventoryDeleteState)
            Bot.Fsm:AddState(Bot.CombatPullState)
            Bot.Fsm:AddState(Bot.RoamingState)
            Bot.Fsm:AddState(IdleState())
        else
            Bot.Fsm:AddState(Bot.DeathState)
            Bot.Fsm:AddState(PlayerPressState())
            Bot.Fsm:AddState(LibConsumables.ConsumablesState)
            Bot.Fsm:AddState(Bot.LootState.CombatLootState)
            Bot.Fsm:AddState(Bot.CombatFightState)
            Bot.Fsm:AddState(Bot.LootState)
            Bot.Fsm:AddState(Bot.InventoryDeleteState)
            Bot.Fsm:AddState(Bot.CombatPullState)
            Bot.Fsm:AddState(IdleState())
        end

        Bot.Running = true
    end
end

function Bot.Death(state)
    Bot.DoReset = true
    if Bot.DeathState.Settings.ReviveMethod == DeathState.SETTINGS_ON_DEATH_ONLY_CALL_WHEN_COMPLETED then
        Bot.Stop()
    else
        Bot.TurninState:Reset()
        Bot.WarehouseState:Reset()
        Bot.VendorState:Reset()
        Bot.RepairState:Reset()
        Bot.SecurityState:Reset()
        Bot.SecurityState.PauseTeleportDetectionTimer = PyxTimer:New(60)
    end
end

function Bot.Stop()
    Bot.TurninState:Reset()
    Bot.RepairState:Reset()
    Bot.WarehouseState:Reset()
    Bot.VendorState:Reset()
    Bot.DeathState:Reset()
    Bot.SecurityState:Reset()
    Bot.SecurityState.PauseTeleportDetectionTimer = PyxTimer:New(60)

    Bot.Running = false
    Bot.LoopCounter = 0
    Bot.Paused = false
    Bot.PausedManual = false
    --    Navigator.Stop(true)
    Bot.Pather:Stop()
    local selfPlayer = GetSelfPlayer()
    selfPlayer:ClearActionState()
    Bot.Stats.TotalSession = Bot.Stats.TotalSession +(Pyx.Win32.GetTickCount() - Bot.Stats.SessionStart)

    if PathRecorder.RealPulse ~= nil then
        PathRecorder.Pulse = PathRecorder.RealPulse
        PathRecorder.RealPulse = nil
    end
    --[[
    Navigator.Stop(false)
    --]]

end

function Bot.OnPulse()

    if Pyx.Input.IsGameForeground() then
        -- pause to start or stop bot
        if Pyx.Input.IsKeyDown(0x12) and Pyx.Input.IsKeyDown(string.byte('S')) then
            if Bot._startHotKeyPressed ~= true then
                Bot._startHotKeyPressed = true
                if Bot.Running and(not Bot.Paused or not Bot.PausedManual) then
                    print("Stopping bot from hotkey")
                    BDOLua.Execute("FGlobal_WorldBossShow('Grinder STOPPED')")
                    Bot.Stop()
                elseif Bot.Paused then
                    print("Bot remain paused, cause of some options enabled")
                elseif Bot.PausedManual then
                    print("Unpause the bot first!")
                else
                    print("Starting bot from hotkey")
                    BDOLua.Execute("FGlobal_WorldBossShow('Grinder STARTED')")
                    Bot.Start()
                end
            end
            -- DISABLED FOR NOW
            -- elseif Pyx.Input.IsKeyDown(0x12) and Pyx.Input.IsKeyDown(string.byte('P')) then
            -- if Bot._pauseHotKeyPressed ~= true then
            -- Bot._pauseHotKeyPressed = true
            -- if Bot.Running and (not Bot.Paused and not Bot.PausedManual) then
            -- print("Pausing bot from hotkey")
            -- BDOLua.Execute("FGlobal_WorldBossShow('Grinder Paused')")
            -- Bot.PausedManual = true
            -- elseif not Bot.Paused and Bot.PausedManual then
            -- print("Unpausing bot from hotkey")
            -- BDOLua.Execute("FGlobal_WorldBossShow('Grinder Resumed')")
            -- Bot.PausedManual = false
            -- end
            -- end
        elseif Pyx.Input.IsKeyDown(0x12) and Pyx.Input.IsKeyDown(string.byte('E')) then
            if Bot._profileHotKeyPressed ~= true then
                Bot._profileHotKeyPressed = true
                if not ProfileEditor.Visible then
                    ProfileEditor.Visible = true
                elseif ProfileEditor.Visible then
                    ProfileEditor.Visible = false
                end
            end
        elseif Pyx.Input.IsKeyDown(0x12) and Pyx.Input.IsKeyDown(string.byte('O')) then
            if Bot._settingsHotKeyPressed ~= true then
                Bot._settingsHotKeyPressed = true
                if not BotSettings.Visible then
                    BotSettings.Visible = true
                elseif BotSettings.Visible then
                    BotSettings.Visible = false
                end
            end
        elseif Pyx.Input.IsKeyDown(0x12) and Pyx.Input.IsKeyDown(string.byte('D')) then
            if Bot._advancedsettingsHotKeyPressed ~= true then
                Bot._advancedsettingsHotKeyPressed = true
                if not AdvancedSettings.Visible then
                    AdvancedSettings.Visible = true
                elseif AdvancedSettings.Visible then
                    AdvancedSettings.Visible = false
                end
            end
        elseif Pyx.Input.IsKeyDown(0x12) and Pyx.Input.IsKeyDown(string.byte('B')) then
            if Bot._inventoryHotKeyPressed ~= true then
                Bot._inventoryHotKeyPressed = true
                if not InventoryList.Visible then
                    InventoryList.Visible = true
                elseif InventoryList.Visible then
                    InventoryList.Visible = false
                end
            end
        elseif Pyx.Input.IsKeyDown(0x12) and Pyx.Input.IsKeyDown(string.byte('C')) then
            if Bot._consumableHotKeyPressed ~= true then
                Bot._consumableHotKeyPressed = true
                if not LibConsumableWindow.Visible then
                    LibConsumableWindow.Visible = true
                elseif LibConsumableWindow.Visible then
                    LibConsumableWindow.Visible = false
                end
            end
        elseif Pyx.Input.IsKeyDown(0x12) and Pyx.Input.IsKeyDown(string.byte('L')) then
            if Bot._statsHotKeyPressed ~= true then
                Bot._statsHotKeyPressed = true
                if not Stats.Visible then
                    Stats.Visible = true
                elseif Stats.Visible then
                    Stats.Visible = false
                end
            end
        elseif Pyx.Input.IsKeyDown(0x12) and Pyx.Input.IsKeyDown(string.byte('W')) then
            if Bot._warehouseHotKeyPressed ~= true then
                Bot._warehouseHotKeyPressed = true
                if Bot.Running and(not Bot.Paused or not Bot.PausedManual) then
                    Bot.WarehouseState.Forced = true
                    if Bot.EnableDebug then
                        print("Go to Warehouse")
                    end
                elseif Bot.Paused then
                    print("Bot remain paused, cause of some options enabled")
                elseif Bot.PausedManual then
                    print("Unpause the bot first!")
                else
                    print("Start the bot first!")
                end
            end
        elseif Pyx.Input.IsKeyDown(0x12) and Pyx.Input.IsKeyDown(string.byte('T')) then
            if Bot._exchangeHotKeyPressed ~= true then
                Bot._exchangeHotKeyPressed = true
                if Bot.Running and(not Bot.Paused or not Bot.PausedManual) then
                    Bot.TurninState.Forced = true
                    if Bot.EnableDebug then
                        print("Go to Exchange")
                    end
                elseif Bot.Paused then
                    print("Bot remain paused, cause of some options enabled")
                elseif Bot.PausedManual then
                    print("Unpause the bot first!")
                else
                    print("Start the bot first!")
                end
            end
        elseif Pyx.Input.IsKeyDown(0x12) and Pyx.Input.IsKeyDown(string.byte('V')) then
            if Bot._vendorHotKeyPressed ~= true then
                Bot._vendorHotKeyPressed = true
                if Bot.Running and(not Bot.Paused or not Bot.PausedManual) then
                    Bot.VendorState.Forced = true
                    if Bot.EnableDebug then
                        print("Go to Vendor")
                    end
                elseif Bot.Paused then
                    print("Bot remain paused, cause of some options enabled")
                elseif Bot.PausedManual then
                    print("Unpause the bot first!")
                else
                    print("Start the bot first!")
                end
            end
        elseif Pyx.Input.IsKeyDown(0x12) and Pyx.Input.IsKeyDown(string.byte('R')) then
            if Bot._repairHotKeyPressed ~= true then
                Bot._repairHotKeyPressed = true
                if Bot.Running and(not Bot.Paused or not Bot.PausedManual) then
                    Bot.RepairState.Forced = true
                    if Bot.EnableDebug then
                        print("Go Repair")
                    end
                elseif Bot.Paused then
                    print("Bot remain paused, cause of some options enabled")
                elseif Bot.PausedManual then
                    print("Unpause the bot first!")
                else
                    print("Start the bot first!")
                end
            end
        elseif Pyx.Input.IsKeyDown(0x12) and Pyx.Input.IsKeyDown(string.byte('F')) then
            if Bot._addHotKeyPressed ~= true then
                Bot._addHotKeyPressed = true
                print("Adding hotspot through hotkey")
                local selfPlayer = GetSelfPlayer()
                if selfPlayer then
                    local selfPlayerPosition = selfPlayer.Position
                    table.insert(ProfileEditor.CurrentProfile.Hotspots, { X = selfPlayerPosition.X, Y = selfPlayerPosition.Y, Z = selfPlayerPosition.Z })
                end
            end

        else
            Bot._startHotKeyPressed = false
            Bot._pauseHotKeyPressed = false
            Bot._addHotKeyPressed = false
            Bot._profileHotKeyPressed = false
            Bot._settingsHotKeyPressed = false
            Bot._advancedsettingsHotKeyPressed = false
            Bot._inventoryHotKeyPressed = false
            Bot._consumableHotKeyPressed = false
            Bot._statsHotKeyPressed = false
            Bot._warehouseHotKeyPressed = false
            Bot._exchangeHotKeyPressed = false
            Bot._vendorHotKeyPressed = false
            Bot._repairHotKeyPressed = false
        end
    end

    if Bot.Paused or Bot.PausedManual then
        Bot.LoopCounter = Bot.LoopCounter + 1
    end

    if Bot.Counter > 0 then
        Bot.Counter = Bot.Counter - 1
    end

    if Bot.Running then
        if Bot.DoReset == true then
            Bot.Fsm.Reset = true
            Bot.Pather:Stop()
            --            Bot.Pather:Reset()

            Bot.SecurityState:Reset()
            Bot.DoReset = false
        end

        Bot.Fsm:Pulse()
        Bot.Pather:Pulse()
        if Bot.Fsm.CurrentState ~= nil and(Bot.Fsm.CurrentState == Bot.WarehouseState or Bot.Fsm.CurrentState == Bot.VendorState or Bot.Fsm.CurrentState == Bot.RepairState
            or Bot.Fsm.CurrentState == Bot.TurninState) then
            local selfPlayer = GetSelfPlayer()

            if selfPlayer and selfPlayer.IsBattleMode == true then
                if selfPlayer.IsActionPending == false then
                    if Bot._switchTimer:IsRunning() == false or Bot._switchTimer:Expired() == true then
                        Keybindings.HoldByActionId(KEYBINDING_ACTION_WEAPON_IN_OUT, 500)
                        print("Bot switch from battle mode: " .. tostring(selfPlayer.IsBattleMode) .. " " .. tostring(selfPlayer.CurrentActionName))
                        Bot._switchTimer:Reset()
                        Bot._switchTimer:Start()
                    end

                end
                if Bot.SecurityState.PausePlayerDetection == false then
                print("Bot: Pausing Player Detection for state: " .. Bot.Fsm.CurrentState.Name)
                Bot.SecurityState.PausePlayerDetection = true
                end
            end
        elseif Bot.SecurityState.PausePlayerDetection == true and(Bot.Fsm.CurrentState == nil or(Bot.Fsm.CurrentState ~= Bot.WarehouseState and Bot.Fsm.CurrentState ~= Bot.VendorState and Bot.Fsm.CurrentState ~= Bot.RepairState
            and Bot.Fsm.CurrentState ~= Bot.TurninState)) then
            print("Bot Re Enable Player detection 240 seconds")
            Bot.SecurityState.PausePlayerDetection = false
            Bot.SecurityState.PausePlayerDetectionTimer = PyxTimer:New(240)
            Bot.SecurityState.PausePlayerDetectionTimer:Start()
        end

        Stats.GetKills()
        Bot.Time = math.ceil((Bot.Stats.TotalSession + Pyx.Win32.GetTickCount() - Bot.Stats.SessionStart) / 1000)
        Bot.Seconds = Bot.Time % 60
        Bot.Minutes = math.floor(Bot.Time / 60) % 60
        Bot.Hours = math.floor(Bot.Time /(60 * 60))

        if Bot.VendorState.Forced == true or Bot.RepairState.Forced == true or Bot.WarehouseState.Forced == true or Bot.TurninState.Forced then
            Bot.CombatPullState.Enabled = false
        else
            Bot.CombatPullState.Enabled = true
        end
    end
end

function Bot.CallCombatAttack(monsterActor, isPull)
    if Bot.Combat and Bot.Combat.Attack then
        Bot.Combat:Attack(monsterActor, isPull)
    end
end

function Bot.CallCombatRoaming()
    if Bot.Combat and Bot.Combat.Roaming then
        Bot.Combat:Roaming()
    end
end

function Bot.CallGui()
    if Bot.Combat and Bot.Combat.UserInterface then
        Bot.Combat:UserInterface()
    end
end

function Bot.SaveSettings()
    local json = JSON:new()
    Pyx.FileSystem.WriteFile("Settings.json", json:encode_pretty(Bot.Settings))
end

function Bot.LoadSettings()
    local json = JSON:new()
    Bot.Settings = Settings()
    Bot.Settings.WarehouseSettings = Bot.WarehouseState.Settings
    Bot.Settings.TurninSettings = Bot.TurninState.Settings
    Bot.Settings.VendorSettings = Bot.VendorState.Settings
    Bot.Settings.DeathSettings = Bot.DeathState.Settings
    Bot.Settings.RepairSettings = Bot.RepairState.Settings
    Bot.Settings.LootSettings = Bot.LootState.Settings
    Bot.Settings.InventoryDeleteSettings = Bot.InventoryDeleteState.Settings
    Bot.Settings.LibConsumablesSettings = LibConsumables.Settings
    Bot.Settings.PullSettings = Bot.CombatPullState.Settings
    Bot.Settings.SecuritySettings = Bot.SecurityState.Settings
    Bot.Settings.PatherFallBack = Bot.Pather.Fallback

    table.merge(Bot.Settings, json:decode(Pyx.FileSystem.ReadFile("Settings.json")))
    if string.len(Bot.Settings.LastProfileName) > 0 then
        ProfileEditor.LoadProfile(Bot.Settings.LastProfileName)
    end
end

function Bot.StateMoving(state)
    Bot.CallCombatRoaming()
end


function Bot.OnStuck()
    if Bot.Pather.StuckCount == 18 and Bot.Fsm.CurrentState ~= nil then
        Bot.Fsm.CurrentState.Stuck = true
    end

    if Bot.Pather.StuckCount > 35 then
        print("We are too stuck try rescue")
        BDOLua.Execute("callRescue()")
        Bot.SecurityState.PauseTeleportDetectionTimer = PyxTimer:New(60)
    end
end

function Bot.PlayerAlarm()
    local toRet = false
    if (Bot.PlayerAudioPause:Expired() == true or Bot.PlayerAudioPause:IsRunning() == false) and Bot.Settings.SecurityPlayerMakeSound == true then
        print("Player Alarm: Play Noise")
        BDOLua.Execute("audioPostEvent_SystemUi(0,8)")
        Bot.PlayerAudioPause:Reset()
        Bot.PlayerAudioPause:Start()
    end

    if Bot.Settings.SecurityPlayerChangeChannel == true then

    end


    if (Bot.PlayerChangeHotSpotPause:Expired() or Bot.PlayerChangeHotSpotPause:IsRunning() == false) and Bot.Settings.SecurityPlayerChangeHotSpot == true then
        print("Player Alarm: Change Hotspot")
        Bot.RoamingState:ChangeHotSpot()
        Bot.PlayerChangeHotSpotPause:Reset()
        Bot.PlayerChangeHotSpotPause:Start()
    end

    if Bot.Settings.SecurityPlayerGoVendor == true then
        print("Player Alarm: Force Vendor, Repair, Warehouse")
        Bot.VendorState.Forced = true
        Bot.RepairState.Forced = true
        Bot.WarehouseState.Forced = true
    end


    if Bot.Settings.SecurityPlayerStopBot == true then
        print("Player Alarm: Stop Bot")
        toRet = true
        Bot.Stop()
    end

    return toRet
end


function Bot.TeleportAlarm()
    local toRet = false;

    if Bot.Settings.SecurityTeleportMakeSound == true then
        print("Teleport Alarm: Play Audio")
        BDOLua.Execute("audioPostEvent_SystemUi(0,8)")
        toRet = false
    end

    if Bot.Settings.SecurityTeleportStopBot == true then
        print("Teleport Alarm: Stop Bot")
        Bot.Stop()
        toRet = true
    end

    if Bot.Settings.SecurityTeleportKillGame == true then
        print("Teleport Alarm: Kill Process")
        Pyx.Win32.TerminateProcess()
        toRet = true
    end

    return toRet
end

function Bot.StateComplete(state)

    if state == Bot.VendorState then
        if Bot.Settings.WarehouseAfterVendor == true then
            print("Settings say Forcing Warehouse after vendor")
            Bot.WarehouseState.Forced = true
        end
    end

    if state == Bot.TurninState then
        if Bot.Settings.VendorAfterTurnin == true then
            print("Settings say Forcing Vendor after turnin")
            Bot.VendorState.Forced = true
        end
    end

    if state == Bot.WarehouseState then
        if Bot.Settings.RepairAfterWarehouse == true then
            print("Settings say Forcing Repair after Warehouse")
            Bot.RepairState.Forced = true
        end
    end

end

function Bot.CheckIfLoggedIn()
    if GetSelfPlayer() then
        return true
    end

    return false
end


function Bot.DetectPlayer()
    local characters = GetActors()
    table.sort(characters, function(a, b) return a.Position.Distance3DFromMe < b.Position.Distance3DFromMe end)
    for k, v in pairs(characters) do
        if v.IsPlayer and not v.IsSelfPlayer then
            return true
        end
    end
    return false
end

function Bot.DetectPlayerAt(position, range)
    local characters = Bot.GetPlayers(false)


    if position == nil or position.GetDistance3D == nil or range == nil then
        print("DetectPlayerAt got a nil being safe returning true")
        return true
    end

    for k, v in pairs(characters) do
        if v.IsPlayer == true and v.IsAlive == true and v.IsSelfPlayer == false and
            position:GetDistance3D(v.Position) <= range then
            return true
        end
    end
    return false
end
