------------------------------------------------------------------------------
-- Variables
-----------------------------------------------------------------------------

ProfileEditor = { }
ProfileEditor.Visible = false
ProfileEditor.CurrentProfile = Profile()
ProfileEditor.AvailablesProfilesSelectedIndex = 0
ProfileEditor.AvailablesProfiles = { }
ProfileEditor.AttackableMonstersSelectedIndex = 0
ProfileEditor.AttackableMonstersComboSelectedIndex = 0
ProfileEditor.MonstersName = { }
ProfileEditor.CurrentProfileSaveName = "Unamed"
ProfileEditor.CurrentMeshConnect = { }
ProfileEditor.MeshConnectEnabled = false
ProfileEditor.LastPosition = Vector3(0, 0, 0)

-----------------------------------------------------------------------------
-- ProfileEditor Functions
-----------------------------------------------------------------------------

function ProfileEditor.DrawProfileEditor()
    local shouldDraw
    local selfPlayer = GetSelfPlayer()

    if ProfileEditor.MeshConnectEnabled == true and ProfileEditor.LastPosition.Distance3DFromMe > 200 then
        ProfileEditor.CurrentMeshConnect[#ProfileEditor.CurrentMeshConnect + 1] = {X=selfPlayer.Position.X,Y=selfPlayer.Position.Y,Z=selfPlayer.Position.Z}
        ProfileEditor.LastPosition = selfPlayer.Position
        --    print("Connect Node: "..selfPlayer.Position)
    end

    if ProfileEditor.Visible then
        _, ProfileEditor.Visible = ImGui.Begin("Profile editor", ProfileEditor.Visible, ImVec2(300, 400), -1.0)

        _, ProfileEditor.CurrentProfileSaveName = ImGui.InputText("##profile_save_name", ProfileEditor.CurrentProfileSaveName)
        ImGui.SameLine()
        if ImGui.Button("Save") then
            ProfileEditor.SaveProfile(ProfileEditor.CurrentProfileSaveName)
        end

        _, ProfileEditor.AvailablesProfilesSelectedIndex = ImGui.Combo("##profile_load_combo", ProfileEditor.AvailablesProfilesSelectedIndex, ProfileEditor.AvailablesProfiles)
        ImGui.SameLine()
        if ImGui.Button("Load") then
            ProfileEditor.LoadProfile(ProfileEditor.AvailablesProfiles[ProfileEditor.AvailablesProfilesSelectedIndex])
        end

        if ImGui.Button("Clear profile##id_profile_clear", ImVec2(ImGui.GetContentRegionAvailWidth(), 20)) then
            Navigation.ClearMesh()
            ProfileEditor.CurrentProfile = Profile()
            ProfileEditor.CurrentProfileSaveName = "Unamed"
        end

        if ImGui.CollapsingHeader("Mesher", "id_profile_editor_mesh", true, true) then
            if Navigator.MeshConnectEnabled == false then
                _, Navigation.MesherEnabled = ImGui.Checkbox("Enable mesher##profile_enable_mesher", Navigation.MesherEnabled)
                ImGui.SameLine();
            end
            _, Navigation.RenderMesh = ImGui.Checkbox("Draw geometry##profile_draw_mesher", Navigation.RenderMesh)
            if ImGui.Button("Build navigation##id_profile_editor_build_navigation", ImVec2(ImGui.GetContentRegionAvailWidth(), 20)) then
                Navigation.BuildNavigation()
            end
            if ImGui.Button("Add Mesh Connect##id_profile_add_connect", ImVec2(ImGui.GetContentRegionAvailWidth(), 20)) then
                if Navigator.MeshConnectEnabled == false then
                    Navigation.MesherEnabled = false
                    ProfileEditor.MeshConnectEnabled = true
                    ProfileEditor.CurrentMeshConnect = { }
                    ProfileEditor.CurrentMeshConnect[#ProfileEditor.CurrentMeshConnect + 1] = {X=selfPlayer.Position.X,Y=selfPlayer.Position.Y,Z=selfPlayer.Position.Z}
                    ProfileEditor.LastPosition = selfPlayer.Position
                    ProfileEditor.CurrentProfile.MeshConnects[#ProfileEditor.CurrentProfile.MeshConnects + 1] = ProfileEditor.CurrentMeshConnect
                end
            end
            ImGui.Columns(3)
            for key, value in pairs(ProfileEditor.CurrentProfile.MeshConnects) do
                if ProfileEditor.MeshConnectEnabled == true and key == table.length(ProfileEditor.CurrentProfile.MeshConnects) then
                    ImGui.Text("Running..")
                    ImGui.NextColumn()
                    local dispDistance = Vector3(value[1].X,value[1].Y,value[1].Z)
                    ImGui.Text(math.floor(dispDistance.Distance3DFromMe) / 100)
                    ImGui.NextColumn()
                    if ImGui.Button("Set End##id_profile_end_connect") then
                        -- , ImVec2(ImGui.GetContentRegionAvailWidth(), 20)) then
                        value[#value + 1] = {X=selfPlayer.Position.X,Y=selfPlayer.Position.Y,Z=selfPlayer.Position.Z}
                        ProfileEditor.MeshConnectEnabled = false
                    end
                    ImGui.NextColumn()
                else
                if ImGui.SmallButton("Delete") then
                table.remove(ProfileEditor.CurrentProfile.MeshConnects,key)
                else
                    ImGui.NextColumn()
                    local dispDistance = Vector3(value[1].X,value[1].Y,value[1].Z)
                    ImGui.Text(math.floor(dispDistance.Distance3DFromMe) / 100)
                    ImGui.NextColumn()
                    dispDistance = Vector3(value[#value].X,value[#value].Y,value[#value].Z)

                    ImGui.Text(math.floor(dispDistance.Distance3DFromMe) / 100)
                    ImGui.NextColumn()
                    end
                end
            end
            ImGui.Columns(1)

        end

        if ImGui.CollapsingHeader("Fishing spot", "id_profile_editor_fishing_spot", true, false) then
            if ProfileEditor.CurrentProfile:HasFishSpot() then
                ImGui.Text("Distance : " .. math.floor(ProfileEditor.CurrentProfile:GetFishSpotPosition().Distance3DFromMe) / 100)
            else
                ImGui.Text("Distance : Not set")
            end
            if ImGui.Button("Set##id_profile_set_fishing_spot", ImVec2(ImGui.GetContentRegionAvailWidth() / 2, 20)) then
                local selfPlayer = GetSelfPlayer()
                if selfPlayer then
                    ProfileEditor.CurrentProfile.FishSpotPosition.X = selfPlayer.Position.X
                    ProfileEditor.CurrentProfile.FishSpotPosition.Y = selfPlayer.Position.Y
                    ProfileEditor.CurrentProfile.FishSpotPosition.Z = selfPlayer.Position.Z
                    ProfileEditor.CurrentProfile.FishSpotRotation = selfPlayer.Rotation
                end
            end
            ImGui.SameLine()
            if ImGui.Button("Clear##id_profile_clear_fishing_spot", ImVec2(ImGui.GetContentRegionAvailWidth(), 20)) then
                ProfileEditor.CurrentProfile.TradeManagerNpcName = ""
                ProfileEditor.CurrentProfile.FishSpotPosition.X = 0
                ProfileEditor.CurrentProfile.FishSpotPosition.Y = 0
                ProfileEditor.CurrentProfile.FishSpotPosition.Z = 0
                ProfileEditor.CurrentProfile.FishSpotRotation = 0
            end
        end

        if ImGui.CollapsingHeader("TradeManager npc", "id_profile_editor_TradeManager", true, false) then
            if string.len(ProfileEditor.CurrentProfile.TradeManagerNpcName) > 0 then
                ImGui.Text("Name : " .. ProfileEditor.CurrentProfile.TradeManagerNpcName .. " (" .. math.floor(ProfileEditor.CurrentProfile:GetTradeManagerPosition().Distance3DFromMe / 100) .. "y)")
            else
                ImGui.Text("Name : Not set")
            end
            if ImGui.Button("Set##id_profile_set_TradeManager", ImVec2(ImGui.GetContentRegionAvailWidth() / 2, 20)) then
                local npcs = GetNpcs()
                if table.length(npcs) > 0 then
                    local TradeManagerNpc = npcs[1]
                    ProfileEditor.CurrentProfile.TradeManagerNpcName = TradeManagerNpc.Name
                    ProfileEditor.CurrentProfile.TradeManagerNpcPosition.X = TradeManagerNpc.Position.X
                    ProfileEditor.CurrentProfile.TradeManagerNpcPosition.Y = TradeManagerNpc.Position.Y
                    ProfileEditor.CurrentProfile.TradeManagerNpcPosition.Z = TradeManagerNpc.Position.Z
                end
            end
            ImGui.SameLine()
            if ImGui.Button("Clear##id_profile_clear_TradeManager", ImVec2(ImGui.GetContentRegionAvailWidth(), 20)) then
                ProfileEditor.CurrentProfile.TradeManagerNpcName = ""
                ProfileEditor.CurrentProfile.TradeManagerNpcPosition.X = 0
                ProfileEditor.CurrentProfile.TradeManagerNpcPosition.Y = 0
                ProfileEditor.CurrentProfile.TradeManagerNpcPosition.Z = 0
            end
        end
        if ImGui.CollapsingHeader("Vendor npc", "id_profile_editor_Vendor", true, false) then
            if string.len(ProfileEditor.CurrentProfile.VendorNpcName) > 0 then
                ImGui.Text("Name : " .. ProfileEditor.CurrentProfile.VendorNpcName .. " (" .. math.floor(ProfileEditor.CurrentProfile:GetVendorPosition().Distance3DFromMe / 100) .. "y)")
            else
                ImGui.Text("Name : Not set")
            end
            if ImGui.Button("Set##id_profile_set_Vendor", ImVec2(ImGui.GetContentRegionAvailWidth() / 2, 20)) then
                local npcs = GetNpcs()
                if table.length(npcs) > 0 then
                    local VendorNpc = npcs[1]
                    ProfileEditor.CurrentProfile.VendorNpcName = VendorNpc.Name
                    ProfileEditor.CurrentProfile.VendorNpcPosition.X = VendorNpc.Position.X
                    ProfileEditor.CurrentProfile.VendorNpcPosition.Y = VendorNpc.Position.Y
                    ProfileEditor.CurrentProfile.VendorNpcPosition.Z = VendorNpc.Position.Z
                end
            end
            ImGui.SameLine()
            if ImGui.Button("Clear##id_profile_clear_Vendor", ImVec2(ImGui.GetContentRegionAvailWidth(), 20)) then
                ProfileEditor.CurrentProfile.VendorNpcName = ""
                ProfileEditor.CurrentProfile.VendorNpcPosition.X = 0
                ProfileEditor.CurrentProfile.VendorNpcPosition.Y = 0
                ProfileEditor.CurrentProfile.VendorNpcPosition.Z = 0
            end
        end

        if ImGui.CollapsingHeader("Warehouse npc", "id_profile_editor_Warehouse", true, false) then
            if string.len(ProfileEditor.CurrentProfile.WarehouseNpcName) > 0 then
                ImGui.Text("Name : " .. ProfileEditor.CurrentProfile.WarehouseNpcName .. " (" .. math.floor(ProfileEditor.CurrentProfile:GetWarehousePosition().Distance3DFromMe / 100) .. "y)")
            else
                ImGui.Text("Warehouse : Not set")
            end
            if ImGui.Button("Set##id_profile_set_Warehouse", ImVec2(ImGui.GetContentRegionAvailWidth() / 2, 20)) then
                local npcs = GetNpcs()
                if table.length(npcs) > 0 then
                    local WarehouseNpc = npcs[1]
                    ProfileEditor.CurrentProfile.WarehouseNpcName = WarehouseNpc.Name
                    ProfileEditor.CurrentProfile.WarehouseNpcPosition.X = WarehouseNpc.Position.X
                    ProfileEditor.CurrentProfile.WarehouseNpcPosition.Y = WarehouseNpc.Position.Y
                    ProfileEditor.CurrentProfile.WarehouseNpcPosition.Z = WarehouseNpc.Position.Z
                end
            end
            ImGui.SameLine()
            if ImGui.Button("Clear##id_profile_clear_Warehouse", ImVec2(ImGui.GetContentRegionAvailWidth(), 20)) then
                ProfileEditor.CurrentProfile.WarehouseNpcName = ""
                ProfileEditor.CurrentProfile.WarehouseNpcPosition.X = 0
                ProfileEditor.CurrentProfile.WarehouseNpcPosition.Y = 0
                ProfileEditor.CurrentProfile.WarehouseNpcPosition.Z = 0
            end
        end
        if ImGui.CollapsingHeader("Repair npc", "id_profile_editor_Repair", true, false) then
            if string.len(ProfileEditor.CurrentProfile.RepairNpcName) > 0 then
                ImGui.Text("Name : " .. ProfileEditor.CurrentProfile.RepairNpcName .. " (" .. math.floor(ProfileEditor.CurrentProfile:GetRepairPosition().Distance3DFromMe / 100) .. "y)")
            else
                ImGui.Text("Name : Not set")
            end
            if ImGui.Button("Set##id_profile_set_Repair", ImVec2(ImGui.GetContentRegionAvailWidth() / 2, 20)) then
                local npcs = GetNpcs()
                if table.length(npcs) > 0 then
                    local RepairNpc = npcs[1]
                    ProfileEditor.CurrentProfile.RepairNpcName = RepairNpc.Name
                    ProfileEditor.CurrentProfile.RepairNpcPosition.X = RepairNpc.Position.X
                    ProfileEditor.CurrentProfile.RepairNpcPosition.Y = RepairNpc.Position.Y
                    ProfileEditor.CurrentProfile.RepairNpcPosition.Z = RepairNpc.Position.Z
                end
            end
            ImGui.SameLine()
            if ImGui.Button("Clear##id_profile_clear_Repair", ImVec2(ImGui.GetContentRegionAvailWidth(), 20)) then
                ProfileEditor.CurrentProfile.RepairNpcName = ""
                ProfileEditor.CurrentProfile.RepairNpcPosition.X = 0
                ProfileEditor.CurrentProfile.RepairNpcPosition.Y = 0
                ProfileEditor.CurrentProfile.RepairNpcPosition.Z = 0
            end
        end

        ImGui.End()
    end
end

function ProfileEditor.RefreshAvailableProfiles()
    ProfileEditor.AvailablesProfiles = { }
    for k, v in pairs(Pyx.FileSystem.GetFiles("Profiles\\*.json")) do
        v = string.gsub(v, ".json", "")
        table.insert(ProfileEditor.AvailablesProfiles, v)
    end
end



function ProfileEditor.SaveProfile(name)



    local profileFilename = "\\Profiles\\" .. name .. ".json"
    local meshFilename = "\\Profiles\\" .. name .. ".mesh"
    local objFilename = "\\Profiles\\" .. name .. ".obj"

    print("Save mesh : " .. meshFilename)
    if not Navigation.SaveMesh(meshFilename) then
        print("Unable to save .mesh !")
        return
    end

    Bot.Settings.LastProfileName = name

    local json = JSON:new()
    Pyx.FileSystem.WriteFile(profileFilename, json:encode_pretty(ProfileEditor.CurrentProfile))
    ProfileEditor.RefreshAvailableProfiles()

end

function ProfileEditor.LoadProfile(name)

    local profileFilename = "\\Profiles\\" .. name .. ".json"
    local meshFilename = "\\Profiles\\" .. name .. ".mesh"

    print("Load mesh : " .. meshFilename)
    if not Navigation.LoadMesh(meshFilename) then
        print("Unable to load .mesh !")
        return
    end

    Bot.Settings.LastProfileName = name
    ProfileEditor.CurrentProfileSaveName = name

    ProfileEditor.AttackableMonstersSelectedIndex = 0
    ProfileEditor.AttackableMonstersComboSelectedIndex = 0

    local json = JSON:new()
    ProfileEditor.CurrentProfile = Profile()
    table.merge(ProfileEditor.CurrentProfile, json:decode(Pyx.FileSystem.ReadFile(profileFilename)))

end

function ProfileEditor.UpdateMonstersList()
    ProfileEditor.MonstersName = { }
    local selfPlayer = GetSelfPlayer()
    if selfPlayer then
        for k, v in pairs(GetMonsters()) do
            if not table.find(ProfileEditor.MonstersName, v.Name) and not table.find(ProfileEditor.CurrentProfile.AttackMonsters, v.Name) then
                table.insert(ProfileEditor.MonstersName, v.Name)
            end
        end
    end
end

function ProfileEditor.OnDrawGuiCallback()
    ProfileEditor.DrawProfileEditor()
end

function ProfileEditor.OnRender3D()

    if Navigation.RenderMesh then

        local selfPlayer = GetSelfPlayer()

        if ProfileEditor.CurrentProfile:HasFishSpot() then
            Renderer.Draw3DTrianglesList(GetInvertedTriangleList(ProfileEditor.CurrentProfile.FishSpotPosition.X, ProfileEditor.CurrentProfile.FishSpotPosition.Y + 100, ProfileEditor.CurrentProfile.FishSpotPosition.Z, 100, 150, 0xAAFF0000, 0xAAFF00FF))
        end

        for key, value in pairs(ProfileEditor.CurrentProfile.MeshConnects) do
            for k, v in pairs(value) do
            Renderer.Draw3DTrianglesList(GetInvertedTriangleList(v.X, v.Y + 25, v.Z, 25, 38, 0xAAFF0000, 0xAAFF00FF))
            end
        end
    end

end

ProfileEditor.RefreshAvailableProfiles()

if table.length(ProfileEditor.AvailablesProfiles) > 0 then
    ProfileEditor.AvailablesProfilesSelectedIndex = 1
end


