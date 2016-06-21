Pather = { }
Pather.__index = Pather

function Pather:New(myGraph)

    local o = {
        Graph = myGraph,
        Fallback = false,

        CurrentPath = { },
        CurrentPosition = 0,
        OnStuckCall = nil,
        ToFarDistance = 1000,
        _lastPosition = nil,
        _lastMoveTo = nil,
        _currentPath = { },
        _currenPathIndex = 1,
        _pathMode = 1,
        -- 1 is Nav system, 3 is BDO Internal
        StuckCount = 0,
        Running = false,
        Destination = Vector3(0,0,0),
        LastStuckTimer = PyxTimer:New(0.5),
        LastStuckCheckPosition = Vector3(0,0,0),
        ApproachDistance = 190,
        DirectLosDistance = 2500,
        SentAutoPath = PyxTimer:New(3)

    }
    setmetatable(o, self)
    return o
end

function Pather:SendBDOMove(destination, playerRun)
    print("Send BDO Move")
    local selfPlayer = GetSelfPlayer()
    --    selfPlayer:ClearActionState()
    local myDistance = destination.Distance3DFromMe
    if myDistance < self.DirectLosDistance and destination.IsLineOfSight then
        selfPlayer:MoveTo(destination)

    else

        local code = string.format([[
                                                                                                                        ToClient_DeleteNaviGuideByGroup(0)
                                                                                                                        local target = float3(%f, %f, %f)
                                                                                                                        local repairNaviKey = ToClient_WorldMapNaviStart( target, NavigationGuideParam(), true, true )
                                                                                                                        local selfPlayer = getSelfPlayer():get()
                                                                                                                        selfPlayer:setNavigationMovePath(key)
                                                                                                                        selfPlayer:checkNaviPathUI(key)
                                                                                                                    ]], destination.X, destination.Y, destination.Z)
        BDOLua.Execute(code)
    end
    self.SentAutoPath:Reset()
    self.SentAutoPath:Start()
    self._pathMode = 3

    self.Destination = destination
    self.Running = true


end

function Pather:Pulse()
    local selfPlayer = GetSelfPlayer()

    if selfPlayer == nil then
        return
    end

    if selfPlayer ~= nil and(self.Running == false and selfPlayer.IsSwimming == false) or(string.find(selfPlayer.CurrentActionName, "STANCE_CHANGE", 1) ~= nil) then
        self.LastStuckTimer:Reset()
        self.LastStuckTimer:Start()
        self.LastStuckCheckPosition = selfPlayer.Position
    end

    if self.Running == true and selfPlayer ~= nil then
        self.LastPosition = selfPlayer.Position



        if self.LastStuckTimer:Expired() == true then
            if (self.LastStuckCheckPosition.Distance2DFromMe < 35) then
                self:StuckHandler()
            else
                self.StuckCount = 0
            end
            self.LastStuckTimer:Reset()
            self.LastStuckTimer:Start()
            self.LastStuckCheckPosition = selfPlayer.Position
        end

        if self._pathMode == 3 then
            local myDistance = self.Destination.Distance3DFromMe
            if myDistance > 500 then
                if string.find(selfPlayer.CurrentActionName, "AUTO_RUN", 1) == nil
                    and string.find(selfPlayer.CurrentActionName, "RUN_SPRINT_FAST", 1) == nil
                    and(self.SentAutoPath:IsRunning() == false or self.SentAutoPath:Expired() == true) then
                    if self.Destination.IsLineOfSight or self.Destination.Distance3DFromMe < 500 then
                        selfPlayer:MoveTo(self.Destination)
                    else
                        --                        print(self.Destination.IsLineOfSight)
                        local code = string.format([[
                                                                                                                                                                                                                                                ToClient_DeleteNaviGuideByGroup(0)
                                                                                                                                                                                                                                                local target = float3(%f, %f, %f)
                                                                                                                                                                                                                                                local repairNaviKey = ToClient_WorldMapNaviStart( target, NavigationGuideParam(), true, true )
                                                                                                                                                                                                                                                local selfPlayer = getSelfPlayer():get()
                                                                                                                                                                                                                                                selfPlayer:setNavigationMovePath(key)
                                                                                                                                                                                                                                                selfPlayer:checkNaviPathUI(key)
                                                                                                                                                                                                                                            ]], self.Destination.X, self.Destination.Y, self.Destination.Z)
                        BDOLua.Execute(code)

                    end
                end
                return
            end
            --            if myDistance > self.ApproachDistance then
            selfPlayer:MoveTo(self.Destination)
            --            else
            --                selfPlayer:ClearActionState()
            --                self:Stop()
            --            end

            return
        end

        if self._pathMode == 1 then
            local nextWaypoint = Vector3(self.CurrentPath[self._currenPathIndex].X, self.CurrentPath[self._currenPathIndex].Y, self.CurrentPath[self._currenPathIndex].Z)
            if nextWaypoint then
                if nextWaypoint.Distance3DFromMe > self.ApproachDistance or self._currenPathIndex == table.length(self.CurrentPath) then
                    selfPlayer:MoveTo(nextWaypoint)
                    --                    print("Pather: "..tostring(self.ApproachDistance).." "..tostring(self._currenPathIndex).." "..tostring(nextWaypoint.Distance3DFromMe))
                else

                    if self._currenPathIndex >= table.length(self.CurrentPath) then
                        self._currenPathIndex = table.length(self.CurrentPath)
                    else
                        self._currenPathIndex = self._currenPathIndex + 1
                    end
                end
            end
        end

    end

end

function Pather:MoveDirectTo(to)
    local path = { MyNode(to.X, to.Y, to.Z) }
    if self._pathMode == 3 then
        self:Stop()

    end
    self.Destination = to
    self.CurrentPath = path
    self._pathMode = 1
    self._currenPathIndex = 1
    self.Running = true
    print("Going Direct have los")

end

function Pather:PathTo(to)
    local selfPlayer = GetSelfPlayer()

    if selfPlayer == nil then
        return false
    end

    if self.Destination.X == to.X and self.Destination.Y == to.Y and self.Destination.Z == to.Z and table.length(self.CurrentPath) > 0 then
        --        print("Same Dest have a path")
        self.Running = true
        return true
    end
    local path = { }
    if selfPlayer.Position:GetDistance3D(to) < self.DirectLosDistance and to.IsLineOfSight or selfPlayer.Position:GetDistance3D(to) < 500 then
        self:MoveDirectTo(to)
        return true
    else
        path = self:GeneratePath(selfPlayer.Position, to)
    end

    if table.length(path) > 0 then
        if self._pathMode == 3 then
            self:Stop()

        end
        table.insert(path, MyNode(to.X, to.Y, to.Z))
        self.Destination = to
        self.CurrentPath = path
        self._pathMode = 1
        self._currenPathIndex = 1
        self.Running = true

        return true
    elseif self.Fallback == true then
        if self.Destination.X == to.X and self.Destination.Y == to.Y and self.Destination.Z == to.Z and self.Running == false then
            self:SendBDOMove(to, false)
            self.SentAutoPath:Reset()
            self.SentAutoPath:Start()

        end
        self.Destination = to
        self.CurrentPath = { }
        self._pathMode = 3
        self._currenPathIndex = 1
        self.Running = true
    end
    return false
end

function Pather:GeneratePath(from, to)
    local selfPlayer = GetSelfPlayer()

    local path = { }

    if selfPlayer == nil then
        return path
    end


    local startNode = self:FindClosestNodeLos(from.X, from.Y, from.Z, 3000, true)
    local endNode = self.Graph:FindClosestNode(to.X, to.Y, to.Z, 1000, true)

    print("pather startNode:" .. tostring(startNode))
    print("pather endNode:" .. tostring(endNode))

    if (startNode == nil or endNode == nil) then
        return path
    end


    local astar = MyAStar(self.Graph)
    local path = astar:SearchForPath(startNode, endNode, true, true)

    print("pather tl: "..tostring(table.length(path)))
    return path
end


function Pather:FindClosestNodeLos(X, Y, Z, MaxDistance, mustConnect)
    local nodes = self.Graph:GetNodes()
    local toRet = nil

    local position = MyNode(X, Y, Z)
    local newDistance = 0
    local lastDistance = 0
    for key, value in pairs(nodes) do
        newDistance = value:GetDistance3D(position)
        if newDistance <= MaxDistance and(toRet == nil or newDistance < lastDistance) and Vector3(value.X, value.Y, value.Z).IsLineOfSight == true and
        (mustConnect ~= true or table.length(self.Graph:GetConnectionsList(value)) > 0) then
            lastDistance = newDistance
            toRet = value
        end
    end
    return toRet
end


function Pather:CanPathTo(to)
    local selfPlayer = GetSelfPlayer()
    if selfPlayer == nil then
        return false
    end

    if self.Fallback == true then
        return true
    end

    if to.Distance3DFromMe < self.DirectLosDistance and to.IsLineOfSight then
        return true
    end

    return table.length(self:GeneratePath(selfPlayer.Position, to)) > 0

end

function Pather:StuckHandler()
local selfPlayer = GetSelfPlayer()
--                print("I'm stuck")
                -- , jump forward !")
--                print(selfPlayer.CurrentActionName)
                if self.StuckCount == 8 or self.StuckCount == 14 then
                    
                    print("Set Move Forward")
                    selfPlayer:ClearActionState()
                    selfPlayer:SetActionState(ACTION_FLAG_MOVE_FORWARD, 1000)
                elseif self.StuckCount == 2 then 
                    print("Jump Forward")
                    Keybindings.HoldByActionId(KEYBINDING_ACTION_JUMP, 500)
                elseif self.StuckCount == 6  then
                    print("Move Right")
                    selfPlayer:ClearActionState()
                    selfPlayer:SetActionState(ACTION_FLAG_MOVE_RIGHT, 1000)
                elseif self.StuckCount == 11  then
                    print("Move Left")
                    selfPlayer:ClearActionState()
                    selfPlayer:SetActionState(ACTION_FLAG_MOVE_LEFT, 1000)
                end
                self.StuckCount = self.StuckCount + 1
                if self.OnStuckCall ~= nil then
                    self.OnStuckCall()
                end


end

function Pather:Stop()
    local selfPlayer = GetSelfPlayer()
    self.Running = false
    self.CurrentPath = { }
    self.Destination = Vector3(0, 0, 0)
    self.LastWayPoint = false
    self.StuckCount = 0
    self.LastStuckTimer:Reset()
    self.LastStuckTimer:Start()
    self.LastStuckCheckPosition = selfPlayer.Position

    if selfPlayer then
        selfPlayer:MoveTo(Vector3(0, 0, 0))
    end

end