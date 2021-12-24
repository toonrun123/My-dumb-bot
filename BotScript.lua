local Player = game.Players
local Runservice = game:GetService("RunService")
local PathFindingService = game:GetService("PathfindingService")
local Team:Teams = game.Teams

local Bot = script.Parent
local Config = Bot:WaitForChild("Config")
local Damage = Config:WaitForChild("Damage").Value
local Dist = Config:WaitForChild("Dist").Value
local CooldownAttack = Config:WaitForChild("CooldownAttack").Value
local AttackDistance = Config:WaitForChild("AttackDistance").Value
local Type = "Bad"

local myHuman = Bot:WaitForChild("Humanoid")
local myRoot = Bot:WaitForChild("HumanoidRootPart")
local head = Bot:WaitForChild("Head")
local LeftArm = Bot:WaitForChild("Left Arm")
local RightArm = Bot:WaitForChild("Right Arm")
local LeftLeg = Bot:WaitForChild("Left Leg")
local RightLeg = Bot:WaitForChild("Right Leg")
local Animator = myHuman:WaitForChild("Animator")

local Animations = script:WaitForChild("Animations")
--local Attack = Animator:LoadAnimation(Animations:WaitForChild("Attack"))
--local Attack2 = Animator:LoadAnimation(Animations:WaitForChild("Attack2"))

local BlacklistFolder
local DebuggerFolder = workspace.Debugger
local WhtielistFolder

local Height = math.abs(LeftLeg.Position.Y-(LeftLeg.Size.Y) - head.Position.Y+(head.Size.Y))+1
local Radius = math.ceil(2*(LeftArm.Position - RightArm.Position).Magnitude)
local agentsettings = {AgentRadius = Radius,AgentHeight = Height,AgentCanJump = true,WaypointSpacing = 1}

if rawequal(Type,"Bad") then
	Config["Safe_Player"].Value = false
	BlacklistFolder = workspace:WaitForChild("Bot"):WaitForChild("Bad")
	WhtielistFolder = {workspace:WaitForChild("Bot"):WaitForChild("Good"),workspace}
	Bot.Parent = workspace:WaitForChild("Bot"):WaitForChild("Bad")
else
	Config["Safe_Player"].Value = true
	BlacklistFolder = workspace:WaitForChild("Bot"):WaitForChild("Good")
	WhtielistFolder = {workspace:WaitForChild("Bot"):WaitForChild("Bad")}
	Bot.Parent = workspace:WaitForChild("Bot"):WaitForChild("Good")
end

local PastPosition = myRoot.Position
local RunserviceConnection
local Debounce = false
local RUNTIME_DEBOUNCE = false
local dah = false

local function TransferOwner(Player,target)
	if Player and target then
		for i,v in pairs(Bot:GetChildren()) do
			if v:IsA("BasePart") then
				v:SetNetworkOwner(Player)
			end
		end
	else
		for i,v in pairs(Bot:GetChildren()) do
			if v:IsA("BasePart") then
				v:SetNetworkOwner(nil)
			end	
		end
	end	
end

local function Checkpath(v)
	local min = v.Position - (0.5 * Vector3.new(1, 1, 1))
	local max = v.Position + (0.5 * Vector3.new(1, 1, 1))
	local region = Region3.new(min, max)
	local parts = workspace:FindPartsInRegion3WithIgnoreList(region,BlacklistFolder:GetChildren())
	if #parts <1 and not myHuman.Jump then
		return true
	end
	return false
end

local function Attack(Target)
	spawn(function()
		if not Debounce and (Target.Position - myRoot.Position).Magnitude <= AttackDistance and Target.Parent:FindFirstChild("Humanoid") then
			Debounce = true
			local Rad = math.random(1,2)
			if rawequal(Rad,1) then
				--Attack:Play()
			else
				--Attack2:Play()
			end
			wait(CooldownAttack)
			Debounce = false
		end
	end)
end

local function checkSight(target)
	local ray = Ray.new(myRoot.Position, (target.Position - myRoot.Position).Unit * Dist)
	local hit,position = workspace:FindPartOnRayWithIgnoreList(ray, BlacklistFolder:GetChildren())
	if hit then
		if hit:IsDescendantOf(target.Parent) then
			if math.abs(target.Position.Y - myRoot.Position.Y) <= 3 then
				return true
			elseif math.abs(target.Position.Y - myRoot.Position.Y) <= 5+5 then
				return true
			end
		end
	end
	return false
end

local function findTarget()
	local dist = Dist
	local target = nil
	local potentialTargets = {}
	local seeTargets = {}
	for e,a in ipairs(WhtielistFolder) do
		for i,v in pairs(a:GetChildren()) do
			local human = v:FindFirstChild("Humanoid")
			local torso = v:FindFirstChild("HumanoidRootPart")
			local Player = Player:GetPlayerFromCharacter(v)
			if human and torso and v ~= Bot then
				if Player and not Config["Safe_Player"].Value then
					if (myRoot.Position - torso.Position).magnitude < dist and human.Health > 0 and rawequal(Player.Team,Team.Playing) then
						table.insert(potentialTargets,torso)
					end
				elseif not Player and v:FindFirstChild("Config") then
					if not rawequal(v["Config"]["Safe_Player"].Value,Config["Safe_Player"].Value) then
						if (myRoot.Position - torso.Position).magnitude < dist and human.Health > 0 then
							table.insert(potentialTargets,torso)
						end
					end
				end
			end
		end
	end
	
	if #potentialTargets > 0 then
		for i,v in ipairs(potentialTargets) do
			if checkSight(v) then
				table.insert(seeTargets, v)
			elseif rawequal(#seeTargets,0) and (myRoot.Position - v.Position).magnitude < dist then
				target = v
				dist = (myRoot.Position - v.Position).magnitude
			end
		end
	end
	if #seeTargets > 0 then
		dist = Dist
		for i,v in ipairs(seeTargets) do
			if (myRoot.Position - v.Position).magnitude < dist then
				target = v
				dist = (myRoot.Position - v.Position).magnitude
			end
		end
	end
	return target
end

local function Move(spec)
	if not RUNTIME_DEBOUNCE then
		RUNTIME_DEBOUNCE = true
		spec = spec or 3.5
		local target = findTarget()
		if target then
			local Player = game.Players:GetPlayerFromCharacter(target.Parent)
			local path = PathFindingService:CreatePath(agentsettings)
			path:ComputeAsync(myRoot.Position,target.Position)
			local waypoints = path:GetWaypoints()
			for i,v in pairs(waypoints) do
				if (target.Position - myRoot.Position).Magnitude >= 0 then
					TransferOwner(nil,nil)
					local Sight = checkSight(target)
					if not Sight then
						if rawequal(v.Action,Enum.PathWaypointAction.Jump) then
							spawn(function()
								wait(.3)
								myHuman.Jump = true
							end)
						end
						if rawequal(target.Parent.Humanoid.FloorMaterial,nil) then
							myHuman.Jump = true
						end
						local Timeout = 0
						local MaxTimeout = 30
						repeat
							myHuman:MoveTo(v.Position)
							Timeout += 1
							wait()
						until (myRoot.Position - v.Position).Magnitude <= spec or Timeout >= MaxTimeout or target.Parent.Humanoid.Health <= 0 or checkSight(target)
						PastPosition = v.Position	
						if Timeout >= MaxTimeout then
							myHuman.Jump = true
							spawn(function()
								Move(3.5)
							end)	
							break
						end
					else
						if rawequal(v.Action,Enum.PathWaypointAction.Jump) and (v.Position - myRoot.Position).Magnitude <= spec then
							spawn(function()
								wait(.1)
								myHuman.Jump = true
							end)
						end
						if rawequal(target.Parent.Humanoid.FloorMaterial,nil) then
							myHuman.Jump = true
						end
						myHuman:MoveTo(target.Position)
					end
				end
			end
			Attack(target)
		else
			TransferOwner(nil,nil)
		end
		RUNTIME_DEBOUNCE = false
	end	
end

game:GetService("RunService").Stepped:connect(function()
	if myHuman.Health < 1 then
		wait(5)
		Bot:Destroy()
	end
	local Complete,Error = pcall(function()
		Move(6.5)
	end)
	if Error then
		myHuman.Health = 0
	end	
end)
