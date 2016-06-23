RoamingState = { }
RoamingState.__index = RoamingState
RoamingState.Name = "Roaming"

setmetatable(RoamingState, {
  __call = function (cls, ...)
    return cls.new(...)
  end,
})

function RoamingState.new()
  local self = setmetatable({}, RoamingState)
  self.Hotspots = {}
  self.CurrentHotspotIndex = 1
  self.Pather = nil
  return self
end

function RoamingState:NeedToRun()

    local selfPlayer = GetSelfPlayer()

    if not selfPlayer then
        return false
    end

    if not selfPlayer.IsAlive then
        return false
    end

    return true
end

function RoamingState:Run()

    local hotspot = self.Hotspots[self.CurrentHotspotIndex]
    local selfPlayer = GetSelfPlayer()

    if hotspot == nil then
    print("hotspot nil "..tostring(self.CurrentHotspotIndex).." "..tostring(table.length(self.Hotspots)))
    self.Hotspots = ProfileEditor.CurrentProfile:GetHotspots()
    return
    end

    if hotspot.Distance3DFromMe > 200 then
        Bot.CallCombatRoaming()

        if Bot.Settings.RunToHotSpots == true and ProfileEditor.CurrentProfile:IsPositionNearHotspots(selfPlayer.Position, Bot.Settings.Advanced.HotSpotRadius*2) == false then
        Bot.Pather:PathTo(hotspot)
        else
        Bot.Pather:PathTo(hotspot)
        end
    else

    self:ChangeHotSpot()
        print("Moving to hotspot #" .. tostring(self.CurrentHotspotIndex))
    end
end

function RoamingState:ChangeHotSpot()
        if self.CurrentHotspotIndex < table.length(self.Hotspots) then
            self.CurrentHotspotIndex = self.CurrentHotspotIndex + 1
        else
            self.CurrentHotspotIndex = 1
        end

end

function RoamingState:Reset()
  self.CurrentHotspotIndex = 1
  self.Pather = nil
end