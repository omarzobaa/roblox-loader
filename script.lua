local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local PhysicsService = game:GetService("PhysicsService")
local TeleportService = game:GetService("TeleportService")
local StarterGui = game:GetService("StarterGui")
local Workspace = game:GetService("Workspace")
local Camera = Workspace.CurrentCamera

-- =========================
-- UI SCALE (smaller menu)
-- =========================
local UI_SCALE = 0.75
local function S(n: number): number
	return math.max(1, math.floor(n * UI_SCALE + 0.5))
end
local CONTENT_INSET_X = S(4)
local FULL_WIDTH_INSET = S(4)
local BUTTON_HEIGHT = S(26)
local SWITCH_WIDTH = S(52)
local SWITCH_GAP = S(6)
local SWITCH_HEIGHT = BUTTON_HEIGHT
local SWITCH_PADDING = S(3)
local SWITCH_KNOB_SIZE = SWITCH_HEIGHT - (SWITCH_PADDING * 2)
local SLIDER_TRACK_HEIGHT = S(6)
local SLIDER_KNOB_SIZE = S(18)
local SLIDER_X_OFFSET = S(96)
local SLIDER_WIDTH_INSET = S(112)
local SLIDER_GLOW_THICKNESS = 1.25
local TAB_BAR_HEIGHT = S(28)
local TAB_BAR_GAP = S(6)
local TAB_BUTTON_PADDING = S(6)
local MAIN_PAGE_SCROLL_PAD = S(20)

-- =========================
-- DEFAULT BINDS (can rebind in GUI)
-- =========================
local espBind = { kind = "KeyCode", value = Enum.KeyCode.M }
local aimBind = { kind = "UserInputType", value = Enum.UserInputType.MouseButton2 } -- hold
local noclipBind = { kind = "KeyCode", value = Enum.KeyCode.CapsLock }
local walkBind = { kind = "KeyCode", value = Enum.KeyCode.T }
local flyBind = { kind = "KeyCode", value = Enum.KeyCode.F }

-- =========================
-- ESP SETTINGS
-- =========================
local RAINBOW_SPEED = 0.35
local HIGHLIGHT_OUTLINE = Color3.fromRGB(255, 255, 255)
local HIGHLIGHT_FILL_TRANSPARENCY = 0.5
local HIGHLIGHT_NAME = "AnomalyESP_Highlight"

-- =========================
-- AIM SETTINGS
-- =========================
local MAX_RAY_DISTANCE = 1000
local MAX_SNAP_TO_RAY = 8

-- =========================
-- WALK SPEED SETTINGS
-- =========================
local WALK_SPEED_SLIDER_MAX = 1000
local WALK_SPEED_INPUT_MAX = 100000000000000000
local FLY_SPEED_SLIDER_MAX = 1000
local FLY_SPEED_INPUT_MAX = 100000000000000000

-- =========================
-- LASER VISUAL
-- =========================
local LASER_WIDTH_0 = 0.08
local LASER_WIDTH_1 = 0.08
local LASER_TRANSPARENCY = 0.15

-- =========================
-- UI COLORS
-- =========================
local SWITCH_OFF = Color3.fromRGB(85, 85, 95)
local REBIND_BG_IDLE = Color3.fromRGB(26, 26, 32)
local REBIND_BG_HOVER = Color3.fromRGB(36, 36, 46)
local REBIND_BG_DOWN  = Color3.fromRGB(44, 44, 58)
local TAB_ACTIVE_BG = Color3.fromRGB(30, 30, 38)
local TAB_INACTIVE_TEXT = Color3.fromRGB(180, 180, 200)
local OUTLINE_THIN = 0.75
local OUTLINE_THIN_ACTIVE = 1.5
local EDGE_GUARD = S(1) -- unused guard; kept for potential future spacing tweaks

-- =========================
-- STATE
-- =========================
local espArmed = true
local aimArmed = true
local noclipArmed = true
local espEnabled = false
local aimEnabled = false
local noclipEnabled = false
local walkSpeedEnabled = false
local walkSpeedValue = 50
local storedWalkSpeed: number? = nil
local flySpeedValue = 50
local dragLock = false
local dragBlockTargets = {} :: { [Instance]: boolean }
local targetPart: BasePart? = nil
local selectedPartName = "Head"
local flyEnabled = false
local flyRunning = false
local flyKeys = { W = false, S = false, A = false, D = false }
local flyCore: Part? = nil
local flyGyro: BodyGyro? = nil
local flyVel: BodyVelocity? = nil
local flyKeyDownConn: RBXScriptConnection? = nil
local flyKeyUpConn: RBXScriptConnection? = nil
local flyLoopConn: RBXScriptConnection? = nil
local fling = { enabled = false, nudge = 0.1, lastVel = Vector3.zero }

getgenv().walkSpeedSettings = getgenv().walkSpeedSettings or {
	WalkSpeed = {
		Enabled = false,
		Speed = walkSpeedValue,
	},
	Activation = {
		WalkSpeedToggleKey = "T",
		FlyToggleKey = "F",
	},
}
walkSpeedEnabled = getgenv().walkSpeedSettings.WalkSpeed.Enabled == true
walkSpeedValue = 50
flySpeedValue = 50
getgenv().walkSpeedSettings.WalkSpeed.Speed = walkSpeedValue

do
	local rep = game:GetService("ReplicatedStorage")
	if not rep:FindFirstChild("juisdfj0i32i0eidsuf0iok") then
		local detection = Instance.new("Decal")
		detection.Name = "juisdfj0i32i0eidsuf0iok"
		detection.Parent = rep
	end
end

-- =========================
-- NOCLIP SETTINGS
-- =========================
local NOCLIP_GROUP = "NoclipLocal"

pcall(function()
	PhysicsService:CreateCollisionGroup(NOCLIP_GROUP)
end)

pcall(function()
	for _, g in ipairs(PhysicsService:GetCollisionGroups()) do
		PhysicsService:CollisionGroupSetCollidable(NOCLIP_GROUP, g.name, false)
	end
end)

local noclipParts = {} :: { BasePart }
local noclipOriginal = {} :: { [BasePart]: { CanCollide: boolean, CanTouch: boolean, CanQuery: boolean, CollisionGroup: string } }

local function rememberNoclipOriginal(p: BasePart)
	if noclipOriginal[p] then return end
	noclipOriginal[p] = {
		CanCollide = p.CanCollide,
		CanTouch = p.CanTouch,
		CanQuery = p.CanQuery,
		CollisionGroup = p.CollisionGroup,
	}
end

local function applyNoclipToPart(p: BasePart)
	rememberNoclipOriginal(p)
	p.CanCollide = false
	p.CanTouch = false
	p.CanQuery = false
	p.CollisionGroup = NOCLIP_GROUP
end

local function restoreNoclipPart(p: BasePart)
	local o = noclipOriginal[p]
	if not o then return end
	p.CanCollide = o.CanCollide
	p.CanTouch = o.CanTouch
	p.CanQuery = o.CanQuery
	p.CollisionGroup = o.CollisionGroup
end

local function collectNoclipParts(character: Model)
	table.clear(noclipParts)
	for _, d in ipairs(character:GetDescendants()) do
		if d:IsA("BasePart") then
			table.insert(noclipParts, d)
		end
	end
end

local function onNoclipCharacterAdded(character: Model)
	noclipOriginal = {}
	collectNoclipParts(character)
	if noclipEnabled then
		for _, p in ipairs(noclipParts) do
			if p and p.Parent then
				applyNoclipToPart(p)
			end
		end
	end

	character.DescendantAdded:Connect(function(d)
		if d:IsA("BasePart") then
			table.insert(noclipParts, d)
			if noclipEnabled then
				applyNoclipToPart(d)
			end
		end
	end)
end

local function setNoclipState(state: boolean)
	noclipEnabled = state

	if noclipEnabled then
		for _, p in ipairs(noclipParts) do
			if p and p.Parent then
				applyNoclipToPart(p)
			end
		end
	else
		for _, p in ipairs(noclipParts) do
			if p and p.Parent then
				restoreNoclipPart(p)
			end
		end
	end
end

-- =========================
-- WALK SPEED
-- =========================
local function getHumanoid()
	local character = LocalPlayer.Character
	if not character then return nil end
	return character:FindFirstChildOfClass("Humanoid")
end

local function applyWalkSpeed()
	local humanoid = getHumanoid()
	if not humanoid then return end
	if walkSpeedEnabled then
		if not storedWalkSpeed then
			storedWalkSpeed = humanoid.WalkSpeed
		end
		humanoid.WalkSpeed = walkSpeedValue
	else
		if storedWalkSpeed then
			humanoid.WalkSpeed = storedWalkSpeed
			storedWalkSpeed = nil
		end
	end
end

local function applyInstantWalkVelocity()
	if not walkSpeedEnabled then return end
	local humanoid = getHumanoid()
	if not humanoid then return end
	local rootPart = humanoid.RootPart or humanoid.Parent and humanoid.Parent:FindFirstChild("HumanoidRootPart")
	if not rootPart then return end
	local moveDir = humanoid.MoveDirection
	local currentVel = rootPart.AssemblyLinearVelocity
	if moveDir.Magnitude <= 0 then
		rootPart.AssemblyLinearVelocity = Vector3.new(0, currentVel.Y, 0)
		return
	end
	rootPart.AssemblyLinearVelocity = Vector3.new(moveDir.X * walkSpeedValue, currentVel.Y, moveDir.Z * walkSpeedValue)
end

-- =========================
-- FLY (safe body movers)
-- =========================
local function cleanupFly()
	if flyLoopConn then flyLoopConn:Disconnect() flyLoopConn = nil end
	if flyKeyDownConn then flyKeyDownConn:Disconnect() flyKeyDownConn = nil end
	if flyKeyUpConn then flyKeyUpConn:Disconnect() flyKeyUpConn = nil end
	if flyGyro then flyGyro:Destroy() flyGyro = nil end
	if flyVel then flyVel:Destroy() flyVel = nil end
	if flyCore then flyCore:Destroy() flyCore = nil end
	flyKeys = { W = false, S = false, A = false, D = false }
	local hum = getHumanoid()
	if hum and hum.Parent then hum.PlatformStand = false end
	flyRunning = false
end

local function ensureFlyCore(): Part?
	local character = LocalPlayer.Character
	if not character then return nil end
	local root = character:FindFirstChild("HumanoidRootPart") or character:FindFirstChild("LowerTorso")
	if not root or not root:IsA("BasePart") then return nil end
	local core = Instance.new("Part")
	core.Name = "FlyCoreLocal"
	core.Size = Vector3.new(0.05, 0.05, 0.05)
	core.Transparency = 1
	core.CanCollide = false
	core.Anchored = false
	core.Parent = Workspace

	local weld = Instance.new("Weld")
	weld.Part0 = core
	weld.Part1 = root
	weld.C0 = CFrame.new()
	weld.Parent = core

	return core
end

local function flyStep()
	if not (flyCore and flyGyro) then return end
	local camera = Workspace.CurrentCamera
	local move = Vector3.zero
	if flyKeys.W then move += camera.CFrame.LookVector end
	if flyKeys.S then move -= camera.CFrame.LookVector end
	if flyKeys.D then move += camera.CFrame.RightVector end
	if flyKeys.A then move -= camera.CFrame.RightVector end
	local moveDir = move.Magnitude > 0 and move.Unit or Vector3.zero
	local speed = flySpeedValue
	if flyVel then
		flyVel.Velocity = moveDir * speed
	else
		flyCore.AssemblyLinearVelocity = moveDir * speed
	end
	flyGyro.CFrame = CFrame.new(flyCore.Position, flyCore.Position + camera.CFrame.LookVector)
end

local function startFly()
	if flyRunning then return end
	local character = LocalPlayer.Character
	if not character then return end
	local hum = getHumanoid()
	if not hum then return end

	local core = ensureFlyCore()
	if not core then
		flyEnabled = false
		if flyEnabledCtl then flyEnabledCtl.setOn(false) end
		return
	end
	flyCore = core

	flyGyro = Instance.new("BodyGyro")
	flyGyro.Name = "FlyGyroLocal"
	flyGyro.MaxTorque = Vector3.new(9e9, 9e9, 9e9)
	flyGyro.CFrame = core.CFrame
	flyGyro.Parent = core

	flyVel = Instance.new("BodyVelocity")
	flyVel.Name = "FlyVelocityLocal"
	flyVel.MaxForce = Vector3.new(9e9, 9e9, 9e9)
	flyVel.Velocity = Vector3.zero
	flyVel.Parent = core

	hum.PlatformStand = true
	flyRunning = true

	-- seed key state so holding W/A/S/D before enabling fly works immediately
	flyKeys.W = UserInputService:IsKeyDown(Enum.KeyCode.W)
	flyKeys.S = UserInputService:IsKeyDown(Enum.KeyCode.S)
	flyKeys.A = UserInputService:IsKeyDown(Enum.KeyCode.A)
	flyKeys.D = UserInputService:IsKeyDown(Enum.KeyCode.D)

	flyKeyDownConn = UserInputService.InputBegan:Connect(function(input, gpe)
		if gpe then return end
		if input.UserInputType == Enum.UserInputType.Keyboard then
			if input.KeyCode == Enum.KeyCode.W then flyKeys.W = true end
			if input.KeyCode == Enum.KeyCode.S then flyKeys.S = true end
			if input.KeyCode == Enum.KeyCode.A then flyKeys.A = true end
			if input.KeyCode == Enum.KeyCode.D then flyKeys.D = true end
		end
	end)
	flyKeyUpConn = UserInputService.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.Keyboard then
			if input.KeyCode == Enum.KeyCode.W then flyKeys.W = false end
			if input.KeyCode == Enum.KeyCode.S then flyKeys.S = false end
			if input.KeyCode == Enum.KeyCode.A then flyKeys.A = false end
			if input.KeyCode == Enum.KeyCode.D then flyKeys.D = false end
		end
	end)

	flyLoopConn = RunService.Heartbeat:Connect(flyStep)
end

local function stopFly()
	flyEnabled = false
	cleanupFly()
	if flyEnabledCtl then
		flyEnabledCtl.setOn(false)
	end
end

local function toggleFly()
	flyEnabled = not flyEnabled
	if flyEnabledCtl then
		flyEnabledCtl.setOn(flyEnabled)
	end
	if flyEnabled then
		if walkSpeedEnabled then
			walkSpeedEnabled = false
			walkSpeedEnabledCtl.setOn(false)
			applyWalkSpeed()
		end
	end
	if flyEnabled then
		startFly()
	else
		stopFly()
	end
end

if LocalPlayer.Character then
	onNoclipCharacterAdded(LocalPlayer.Character)
	if walkSpeedEnabled then
		applyWalkSpeed()
	end
end
LocalPlayer.CharacterAdded:Connect(function(character)
	onNoclipCharacterAdded(character)
	stopFly()
end)

-- =========================
-- HELPERS
-- =========================
local function alive(char: Model?)
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	return hum and hum.Health > 0
end

local function pointToRayDistance(origin: Vector3, dirUnit: Vector3, point: Vector3)
	local v = point - origin
	local t = v:Dot(dirUnit)
	if t <= 0 or t > MAX_RAY_DISTANCE then
		return math.huge, t
	end
	local closest = origin + dirUnit * t
	return (point - closest).Magnitude, t
end

local function getCharPart(char: Model, name: string): BasePart?
	local p = char:FindFirstChild(name)
	if p and p:IsA("BasePart") then return p end

	if name == "UpperTorso" or name == "LowerTorso" then
		local torso = char:FindFirstChild("Torso")
		if torso and torso:IsA("BasePart") then return torso end
	end
	if name == "Torso" then
		local ut = char:FindFirstChild("UpperTorso")
		if ut and ut:IsA("BasePart") then return ut end
		local lt = char:FindFirstChild("LowerTorso")
		if lt and lt:IsA("BasePart") then return lt end
	end
	return nil
end

local function findLaserClosestPart(partName: string)
	local origin = Camera.CFrame.Position
	local dir = Camera.CFrame.LookVector.Unit

	local bestPart = nil
	local bestDist = math.huge
	local bestT = math.huge

	for _, plr in ipairs(Players:GetPlayers()) do
		if plr ~= LocalPlayer then
			local char = plr.Character
			if char and alive(char) then
				local part = getCharPart(char, partName)
				if part then
					local dist, t = pointToRayDistance(origin, dir, part.Position)
					if dist <= MAX_SNAP_TO_RAY then
						if dist < bestDist or (dist == bestDist and t < bestT) then
							bestDist, bestT, bestPart = dist, t, part
						end
					end
				end
			end
		end
	end

	return bestPart
end

-- =========================
-- ESP (HIGHLIGHT)
-- =========================
local function ensureHighlight(plr: Player)
	if plr == LocalPlayer then return nil end
	local char = plr.Character
	if not char then return nil end

	local hl = char:FindFirstChild(HIGHLIGHT_NAME)
	if not hl then
		hl = Instance.new("Highlight")
		hl.Name = HIGHLIGHT_NAME
		hl.Adornee = char
		hl.Parent = char
		hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
		hl.OutlineColor = HIGHLIGHT_OUTLINE
		hl.FillTransparency = HIGHLIGHT_FILL_TRANSPARENCY
	end
	return hl
end

local function removeHighlight(plr: Player)
	if plr == LocalPlayer then return end
	local char = plr.Character
	if not char then return end
	local hl = char:FindFirstChild(HIGHLIGHT_NAME)
	if hl then hl:Destroy() end
end

local function removeAllHighlights()
	for _, plr in ipairs(Players:GetPlayers()) do
		removeHighlight(plr)
	end
end

-- =========================
-- LASER (BEAM)
-- =========================
local laserBeam: Beam? = nil
local a0: Attachment? = nil
local a1: Attachment? = nil
local laserEndPart: Part? = nil
local laserStartPart: Part? = nil

local function destroyLaser()
	if laserBeam then laserBeam:Destroy() laserBeam = nil end
	if a0 then a0:Destroy() a0 = nil end
	if a1 then a1:Destroy() a1 = nil end
	if laserEndPart then laserEndPart:Destroy() laserEndPart = nil end
	if laserStartPart then laserStartPart:Destroy() laserStartPart = nil end
end

local function ensureLaser()
	if laserBeam and a0 and a1 and laserEndPart and laserStartPart then return end

	laserStartPart = Instance.new("Part")
	laserStartPart.Name = "LaserStartPart"
	laserStartPart.Anchored = true
	laserStartPart.CanCollide = false
	laserStartPart.CanQuery = false
	laserStartPart.CanTouch = false
	laserStartPart.Transparency = 1
	laserStartPart.Size = Vector3.new(0.1, 0.1, 0.1)
	laserStartPart.Parent = Workspace

	a0 = Instance.new("Attachment")
	a0.Name = "LaserStart"
	a0.Parent = laserStartPart

	laserEndPart = Instance.new("Part")
	laserEndPart.Name = "LaserEndPart"
	laserEndPart.Anchored = true
	laserEndPart.CanCollide = false
	laserEndPart.CanQuery = false
	laserEndPart.CanTouch = false
	laserEndPart.Transparency = 1
	laserEndPart.Size = Vector3.new(0.1, 0.1, 0.1)
	laserEndPart.Parent = Workspace

	a1 = Instance.new("Attachment")
	a1.Name = "LaserEnd"
	a1.Parent = laserEndPart

	laserBeam = Instance.new("Beam")
	laserBeam.Name = "LaserBeam"
	laserBeam.Attachment0 = a0
	laserBeam.Attachment1 = a1
	laserBeam.Width0 = LASER_WIDTH_0
	laserBeam.Width1 = LASER_WIDTH_1
	laserBeam.LightInfluence = 0
	laserBeam.FaceCamera = true
	laserBeam.Transparency = NumberSequence.new(LASER_TRANSPARENCY)
	laserBeam.Color = ColorSequence.new(Color3.fromRGB(255, 0, 0))
	laserBeam.Parent = Workspace
end

local function setLaserEndPosition(pos: Vector3)
	if laserEndPart then
		laserEndPart.CFrame = CFrame.new(pos)
	end
end

local function updateLaserStart()
	if laserStartPart then
		laserStartPart.CFrame = Camera.CFrame
	end
end

-- =========================
-- AIM START/STOP
-- =========================
local function aimStart()
	aimEnabled = true
	targetPart = findLaserClosestPart(selectedPartName)
	if not targetPart then
		aimEnabled = false
		targetPart = nil
		destroyLaser()
		return
	end
	ensureLaser()
end

local function aimStop()
	aimEnabled = false
	targetPart = nil
	destroyLaser()
end

-- =========================
-- GUI BUILD (ALWAYS ON TOP)
-- =========================
local gui = Instance.new("ScreenGui")
gui.Name = "ESP_AIM_StatusGui"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.DisplayOrder = 999999
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.Parent = LocalPlayer:WaitForChild("PlayerGui")

local function mk(instanceType, props)
	local inst = Instance.new(instanceType)
	for k, v in pairs(props) do inst[k] = v end
	return inst
end

local function tween(obj, info, props)
	local t = TweenService:Create(obj, info, props)
	t:Play()
	return t
end

-- (matrix background removed)

local rainbowStrokes = {} :: { UIStroke }
local rainbowTexts = {} :: { TextLabel }
local rainbowSwitches = {} :: { [TextButton]: boolean }
local rainbowFrames = {} :: { Frame }

-- ✅ FIX: pulse uses a stored "original thickness" so it never creeps bigger
local pulseStrokes = {} :: { UIStroke }
local pulseBaseThickness = {} :: { [UIStroke]: number }
local pulseInFlight = {} :: { [UIStroke]: boolean }

local function pulseUI()
	for _, s in ipairs(pulseStrokes) do
		if not (s and s.Parent) then
			pulseInFlight[s] = nil
			pulseBaseThickness[s] = nil
			continue
		end

		-- prevent stacking pulses on same stroke
		if pulseInFlight[s] then
			-- hard-reset to base to avoid “stuck bigger” even if spammed
			local base = pulseBaseThickness[s] or s.Thickness
			s.Thickness = base
			continue
		end

		pulseInFlight[s] = true
		local base = pulseBaseThickness[s] or s.Thickness
		pulseBaseThickness[s] = base

		-- always start from base
		s.Thickness = base

		local up = tween(s, TweenInfo.new(0.10, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Thickness = base + 2 })
		up.Completed:Connect(function()
			if not (s and s.Parent) then
				pulseInFlight[s] = nil
				return
			end
			local down = tween(s, TweenInfo.new(0.16, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Thickness = base })
			down.Completed:Connect(function()
				if s and s.Parent then
					s.Thickness = base
				end
				pulseInFlight[s] = nil
			end)
		end)
	end
end

local function addHover(btn: TextButton)
	btn.MouseEnter:Connect(function()
		tween(btn, TweenInfo.new(0.10, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { BackgroundColor3 = REBIND_BG_HOVER })
	end)
	btn.MouseLeave:Connect(function()
		tween(btn, TweenInfo.new(0.10, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { BackgroundColor3 = REBIND_BG_IDLE })
	end)
	btn.MouseButton1Down:Connect(function()
		btn.BackgroundColor3 = REBIND_BG_DOWN
	end)
	btn.MouseButton1Up:Connect(function()
		local pos = UserInputService:GetMouseLocation()
		local absPos, absSize = btn.AbsolutePosition, btn.AbsoluteSize
		local inside = pos.X >= absPos.X and pos.X <= absPos.X + absSize.X and pos.Y >= absPos.Y and pos.Y <= absPos.Y + absSize.Y
		btn.BackgroundColor3 = inside and REBIND_BG_HOVER or REBIND_BG_IDLE
	end)
end

-- =========================
-- PANEL (thinner border)
-- =========================
local panel = mk("Frame", {
	Name = "Panel",
	Size = UDim2.fromOffset(S(504), S(420) + TAB_BAR_HEIGHT + TAB_BAR_GAP),
	Position = UDim2.fromOffset(S(240), S(20)),
	BackgroundColor3 = Color3.fromRGB(10, 10, 12),
	BorderSizePixel = 0,
	ZIndex = 50,
	Parent = gui,
})
local openSize = panel.Size
local openSizeBase = panel.Size
panel.ClipsDescendants = true
mk("UICorner", { CornerRadius = UDim.new(0, S(18)), Parent = panel })

local panelStroke = mk("UIStroke", {
	Thickness = 1,
	Color = Color3.fromRGB(255, 0, 0),
	Transparency = 0,
	ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
	LineJoinMode = Enum.LineJoinMode.Round,
	Parent = panel,
})
table.insert(rainbowStrokes, panelStroke)
table.insert(pulseStrokes, panelStroke)
pulseBaseThickness[panelStroke] = panelStroke.Thickness

local inner = mk("Frame", {
	Name = "Inner",
	Size = UDim2.new(1, -S(12), 1, -S(12)),
	Position = UDim2.fromOffset(S(6), S(6)),
	BackgroundColor3 = Color3.fromRGB(18, 18, 22),
	BorderSizePixel = 0,
	ZIndex = 51,
	Parent = panel,
})
mk("UICorner", { CornerRadius = UDim.new(0, S(16)), Parent = inner })

-- (matrix background removed)

local top = mk("Frame", {
	Name = "Top",
	Size = UDim2.new(1, 0, 0, S(46)),
	BackgroundTransparency = 1,
	ZIndex = 52,
	Parent = inner,
})

local title = mk("TextLabel", {
	Name = "Title",
	Size = UDim2.new(1, -S(120), 1, 0),
	Position = UDim2.fromOffset(S(12), 0),
	BackgroundTransparency = 1,
	Text = "OS Inspector",
	TextXAlignment = Enum.TextXAlignment.Left,
	Font = Enum.Font.GothamBlack,
	TextSize = S(15),
	TextColor3 = Color3.fromRGB(255, 0, 0),
	ZIndex = 53,
	Parent = top,
})
table.insert(rainbowTexts, title)

local minimizeBtn = mk("TextButton", {
	Name = "Minimize",
	Size = UDim2.fromOffset(S(36), S(28)),
	Position = UDim2.new(1, -S(48), 0, S(9)),
	BackgroundColor3 = Color3.fromRGB(28, 28, 34),
	Text = "—",
	Font = Enum.Font.GothamBold,
	TextSize = S(16),
	TextColor3 = Color3.fromRGB(235, 235, 245),
	AutoButtonColor = true,
	ZIndex = 54,
	Parent = top,
})
mk("UICorner", { CornerRadius = UDim.new(0, S(12)), Parent = minimizeBtn })

local content = mk("Frame", {
	Name = "Content",
	Size = UDim2.new(1, 0, 1, -S(58)),
	Position = UDim2.fromOffset(0, S(52)),
	BackgroundTransparency = 1,
	ZIndex = 52,
	Parent = inner,
})
local contentInner = mk("Frame", {
	Name = "ContentInner",
	Size = UDim2.new(1, -(CONTENT_INSET_X * 2), 1, 0),
	Position = UDim2.fromOffset(CONTENT_INSET_X, 0),
	BackgroundTransparency = 1,
	ZIndex = 52,
	Parent = content,
})

local tabBar = mk("Frame", {
	Name = "TabBar",
	Size = UDim2.new(1, 0, 0, TAB_BAR_HEIGHT),
	Position = UDim2.fromOffset(0, 0),
	BackgroundTransparency = 1,
	ZIndex = 53,
	Parent = contentInner,
})
mk("UIListLayout", {
	FillDirection = Enum.FillDirection.Horizontal,
	HorizontalAlignment = Enum.HorizontalAlignment.Left,
	VerticalAlignment = Enum.VerticalAlignment.Center,
	SortOrder = Enum.SortOrder.LayoutOrder,
	Padding = UDim.new(0, TAB_BUTTON_PADDING),
	Parent = tabBar,
})

local pages = mk("Frame", {
	Name = "Pages",
	Size = UDim2.new(1, 0, 1, -(TAB_BAR_HEIGHT + TAB_BAR_GAP)),
	Position = UDim2.fromOffset(0, TAB_BAR_HEIGHT + TAB_BAR_GAP),
	BackgroundTransparency = 1,
	ClipsDescendants = true,
	ZIndex = 53,
	Parent = contentInner,
})

local pageMain = mk("ScrollingFrame", {
	Name = "PageMain",
	Size = UDim2.fromScale(1, 1),
	BackgroundTransparency = 1,
	BorderSizePixel = 0,
	ClipsDescendants = true,
	CanvasSize = UDim2.new(0, 0, 0, S(600)),
	AutomaticCanvasSize = Enum.AutomaticSize.None,
	ScrollBarThickness = 0,
	ScrollBarImageColor3 = Color3.fromRGB(120, 120, 150),
	ScrollBarImageTransparency = 1,
	VerticalScrollBarInset = Enum.ScrollBarInset.None,
	Visible = true,
	ZIndex = 53,
	Parent = pages,
})
mk("UIPadding", {
	PaddingLeft = UDim.new(0, 0),
	PaddingRight = UDim.new(0, 0),
	PaddingTop = UDim.new(0, S(8)),
	PaddingBottom = UDim.new(0, S(8)),
	Parent = pageMain,
})
local function refreshMainCanvasSize()
	local maxBottom = 0
	for _, child in ipairs(pageMain:GetChildren()) do
		if child:IsA("GuiObject") then
			local bottom = child.Position.Y.Offset + child.Size.Y.Offset
			if bottom > maxBottom then
				maxBottom = bottom
			end
		end
	end
	pageMain.CanvasSize = UDim2.new(0, 0, 0, maxBottom + MAIN_PAGE_SCROLL_PAD)
end
pageMain.ChildAdded:Connect(function()
	task.defer(refreshMainCanvasSize)
end)
pageMain.ChildRemoved:Connect(function()
	refreshMainCanvasSize()
end)

local pageJob = mk("ScrollingFrame", {
	Name = "PageJob",
	Size = UDim2.fromScale(1, 1),
	BackgroundTransparency = 1,
	BorderSizePixel = 0,
	ClipsDescendants = true,
	CanvasSize = UDim2.new(0, 0, 0, 0),
	AutomaticCanvasSize = Enum.AutomaticSize.Y,
	ScrollBarThickness = 0,
	ScrollBarImageColor3 = Color3.fromRGB(120, 120, 150),
	ScrollBarImageTransparency = 1,
	VerticalScrollBarInset = Enum.ScrollBarInset.None,
	Visible = false,
	ZIndex = 53,
	Parent = pages,
})
mk("UIPadding", {
	PaddingLeft = UDim.new(0, 0),
	PaddingRight = UDim.new(0, 0),
	PaddingTop = UDim.new(0, S(8)),
	PaddingBottom = UDim.new(0, 0),
	Parent = pageJob,
})

local pageHitbox = mk("ScrollingFrame", {
	Name = "PageHitbox",
	Size = UDim2.fromScale(1, 1),
	BackgroundTransparency = 1,
	BorderSizePixel = 0,
	ClipsDescendants = true,
	CanvasSize = UDim2.new(0, 0, 0, 0),
	AutomaticCanvasSize = Enum.AutomaticSize.Y,
	ScrollBarThickness = 0,
	ScrollBarImageColor3 = Color3.fromRGB(120, 120, 150),
	ScrollBarImageTransparency = 1,
	VerticalScrollBarInset = Enum.ScrollBarInset.None,
	Visible = false,
	ZIndex = 53,
	Parent = pages,
})
mk("UIPadding", {
	PaddingLeft = UDim.new(0, 0),
	PaddingRight = UDim.new(0, 0),
	PaddingTop = UDim.new(0, S(8)),
	PaddingBottom = UDim.new(0, 0),
	Parent = pageHitbox,
})

local tabButtons = {} :: { [string]: { button: TextButton, stroke: UIStroke, indicator: Frame, active: boolean } }
local tabOrder = {} :: { { button: TextButton, stroke: UIStroke, indicator: Frame, active: boolean } }
local tabPages = {} :: { [string]: ScrollingFrame }

local function updateTabButtonSizes()
	if tabBar.AbsoluteSize.X <= 0 then return end
	local count = #tabOrder
	if count == 0 then return end
	local totalPadding = TAB_BUTTON_PADDING * (count - 1)
	local width = math.floor((tabBar.AbsoluteSize.X - totalPadding) / count)
	if width < S(64) then width = S(64) end
	for _, tab in ipairs(tabOrder) do
		tab.button.Size = UDim2.fromOffset(width, TAB_BAR_HEIGHT)
	end
end

local function setActiveTab(key: string)
	for name, page in pairs(tabPages) do
		page.Visible = name == key
	end
	for name, tab in pairs(tabButtons) do
		local active = name == key
		tab.active = active
		tab.button.BackgroundColor3 = active and TAB_ACTIVE_BG or REBIND_BG_IDLE
		tab.button.TextColor3 = active and Color3.fromRGB(245, 245, 255) or TAB_INACTIVE_TEXT
		tab.stroke.Transparency = active and 0 or 0.65
		tab.stroke.Thickness = active and 2 or 1
		tab.indicator.Visible = active
	end
end

local function createTabButton(key: string, label: string, order: number, page: ScrollingFrame)
	local btn = mk("TextButton", {
		Name = ("Tab_%s"):format(key),
		Size = UDim2.fromOffset(S(80), TAB_BAR_HEIGHT),
		BackgroundColor3 = REBIND_BG_IDLE,
		Text = label,
		Font = Enum.Font.GothamBold,
		TextSize = S(11),
		TextColor3 = TAB_INACTIVE_TEXT,
		AutoButtonColor = false,
		ZIndex = 54,
		LayoutOrder = order,
		Parent = tabBar,
	})
	mk("UICorner", { CornerRadius = UDim.new(0, S(10)), Parent = btn })
	local stroke = mk("UIStroke", { Thickness = 1, Color = Color3.fromRGB(120, 120, 150), Transparency = 0.65, Parent = btn })
	local indicator = mk("Frame", {
		Size = UDim2.new(1, -S(10), 0, S(2)),
		Position = UDim2.new(0, S(5), 1, -S(3)),
		BackgroundColor3 = Color3.fromRGB(255, 0, 0),
		BorderSizePixel = 0,
		Visible = false,
		ZIndex = 55,
		Parent = btn,
	})
	table.insert(rainbowFrames, indicator)

	local tab = { button = btn, stroke = stroke, indicator = indicator, active = false }
	tabButtons[key] = tab
	table.insert(tabOrder, tab)
	tabPages[key] = page

	btn.MouseButton1Click:Connect(function()
		setActiveTab(key)
	end)
	btn.MouseEnter:Connect(function()
		if not tab.active then
			btn.BackgroundColor3 = REBIND_BG_HOVER
		end
	end)
	btn.MouseLeave:Connect(function()
		if not tab.active then
			btn.BackgroundColor3 = REBIND_BG_IDLE
		end
	end)
end

tabBar:GetPropertyChangedSignal("AbsoluteSize"):Connect(updateTabButtonSizes)

createTabButton("MAIN", "MAIN", 1, pageMain)
createTabButton("JOB", "JOB", 2, pageJob)
createTabButton("HITBOX", "HITBOX", 3, pageHitbox)
updateTabButtonSizes()
setActiveTab("MAIN")

local function sectionHeader(parent: Instance, text, y)
	return mk("TextLabel", {
		Size = UDim2.new(1, 0, 0, S(18)),
		Position = UDim2.fromOffset(0, S(y)),
		BackgroundTransparency = 1,
		TextXAlignment = Enum.TextXAlignment.Left,
		Font = Enum.Font.GothamSemibold,
		TextSize = S(11),
		TextColor3 = Color3.fromRGB(180, 180, 200),
		Text = text,
		ZIndex = 53,
		Parent = parent,
	})
end

-- ✅ iPhone switch row (CLICK LABEL OR SWITCH)
local function createIosSwitchRow(parent: Instance, rowY: number, labelText: string, onToggle: () -> ())
	local row = mk("Frame", {
		Size = UDim2.new(1, 0, 0, BUTTON_HEIGHT),
		Position = UDim2.fromOffset(0, S(rowY)),
		BackgroundTransparency = 1,
		ZIndex = 53,
		Parent = parent,
	})

	local labelBtn = mk("TextButton", {
		Size = UDim2.new(1, -(SWITCH_WIDTH + SWITCH_GAP), 1, 0),
		BackgroundTransparency = 1,
		TextXAlignment = Enum.TextXAlignment.Left,
		Text = labelText,
		Font = Enum.Font.Gotham,
		TextSize = S(12),
		TextColor3 = Color3.fromRGB(225, 225, 240),
		AutoButtonColor = false,
		ZIndex = 54,
		Parent = row,
	})

	local switch = mk("TextButton", {
		Size = UDim2.fromOffset(SWITCH_WIDTH, SWITCH_HEIGHT),
		Position = UDim2.new(1, -SWITCH_WIDTH, 0.5, -math.floor(SWITCH_HEIGHT / 2)),
		BackgroundColor3 = SWITCH_OFF,
		Text = "",
		AutoButtonColor = false,
		ZIndex = 54,
		Parent = row,
	})
	mk("UICorner", { CornerRadius = UDim.new(1, 0), Parent = switch })

	local knob = mk("Frame", {
		Size = UDim2.fromOffset(SWITCH_KNOB_SIZE, SWITCH_KNOB_SIZE),
		Position = UDim2.fromOffset(SWITCH_PADDING, SWITCH_PADDING),
		BackgroundColor3 = Color3.fromRGB(245, 245, 255),
		ZIndex = 55,
		Parent = switch,
	})
	mk("UICorner", { CornerRadius = UDim.new(1, 0), Parent = knob })
	mk("UIStroke", { Thickness = 1, Color = Color3.fromRGB(0, 0, 0), Transparency = 0.78, Parent = knob })

	local function setOn(state: boolean, instant: boolean?)
		if state then
			rainbowSwitches[switch] = true
		else
			rainbowSwitches[switch] = nil
			switch.BackgroundColor3 = SWITCH_OFF
		end

		local pos = state
			and UDim2.fromOffset(SWITCH_WIDTH - SWITCH_KNOB_SIZE - SWITCH_PADDING, SWITCH_PADDING)
			or UDim2.fromOffset(SWITCH_PADDING, SWITCH_PADDING)
		if instant then
			knob.Position = pos
		else
			tween(knob, TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Position = pos })
		end
	end

	switch.MouseButton1Click:Connect(onToggle)
	labelBtn.MouseButton1Click:Connect(onToggle)

	return { switch = switch, setOn = setOn }
end

-- =========================
-- ARM SWITCHES
-- =========================
sectionHeader(pageMain, "ARM (GATES INPUT)", 0)

local espArmCtl
local noclipArmCtl
local aimArmCtl

espArmCtl = createIosSwitchRow(pageMain, 20, "ESP Armed", function()
	espArmed = not espArmed
	espArmCtl.setOn(espArmed)
	pulseUI()
	if not espArmed then
		espEnabled = false
		removeAllHighlights()
	end
end)

noclipArmCtl = createIosSwitchRow(pageMain, 52, "Noclip Armed", function()
	noclipArmed = not noclipArmed
	noclipArmCtl.setOn(noclipArmed)
	pulseUI()
	if not noclipArmed then
		setNoclipState(false)
	end
end)

aimArmCtl = createIosSwitchRow(pageMain, 84, "Aim Armed", function()
	aimArmed = not aimArmed
	aimArmCtl.setOn(aimArmed)
	pulseUI()
	if not aimArmed then
		aimStop()
	end
end)

espArmCtl.setOn(true, true)
noclipArmCtl.setOn(true, true)
aimArmCtl.setOn(true, true)

-- =========================
-- WALK SPEED
-- =========================
sectionHeader(pageMain, "WALK SPEED", 122)

local walkSpeedEnabledCtl
local walkSpeedErrorLabel

walkSpeedEnabledCtl = createIosSwitchRow(pageMain, 142, "Walk Speed Enabled", function()
	walkSpeedEnabled = not walkSpeedEnabled
	getgenv().walkSpeedSettings.WalkSpeed.Enabled = walkSpeedEnabled
	walkSpeedEnabledCtl.setOn(walkSpeedEnabled)
	pulseUI()
	if walkSpeedEnabled then
		-- disable fly when walk speed turns on
		if flyEnabled then
			stopFly()
		end
	end
	applyWalkSpeed()
end)
walkSpeedEnabledCtl.setOn(walkSpeedEnabled, true)

local sliderRow = mk("Frame", {
	Size = UDim2.new(1, 0, 0, S(32)),
	Position = UDim2.fromOffset(0, S(174)),
	BackgroundTransparency = 1,
	ZIndex = 53,
	Parent = pageMain,
})
dragBlockTargets[sliderRow] = true

mk("TextLabel", {
	Size = UDim2.fromOffset(S(84), S(32)),
	BackgroundTransparency = 1,
	TextXAlignment = Enum.TextXAlignment.Left,
	Text = "Slider",
	Font = Enum.Font.Gotham,
	TextSize = S(11),
	TextColor3 = Color3.fromRGB(220, 220, 235),
	ZIndex = 54,
	Parent = sliderRow,
})

local sliderTrack = mk("Frame", {
	Size = UDim2.new(1, -SLIDER_WIDTH_INSET, 0, SLIDER_TRACK_HEIGHT),
	Position = UDim2.new(0, SLIDER_X_OFFSET, 0.5, -math.floor(SLIDER_TRACK_HEIGHT / 2)),
	BackgroundColor3 = Color3.fromRGB(20, 20, 26),
	BackgroundTransparency = 0.2,
	BorderSizePixel = 0,
	ZIndex = 54,
	Parent = sliderRow,
})
dragBlockTargets[sliderTrack] = true
sliderTrack.ClipsDescendants = false
mk("UICorner", { CornerRadius = UDim.new(1, 0), Parent = sliderTrack })
local sliderTrackStroke = mk("UIStroke", {
	Thickness = SLIDER_GLOW_THICKNESS,
	Color = Color3.fromRGB(255, 0, 0),
	Transparency = 0.15,
	Parent = sliderTrack,
})
table.insert(rainbowStrokes, sliderTrackStroke)

local sliderKnobOuter = mk("Frame", {
	Size = UDim2.fromOffset(SLIDER_KNOB_SIZE, SLIDER_KNOB_SIZE),
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.new(0, 0, 0.5, 0),
	BackgroundColor3 = Color3.fromRGB(22, 22, 28),
	BorderSizePixel = 0,
	ZIndex = 55,
	Parent = sliderTrack,
})
dragBlockTargets[sliderKnobOuter] = true
mk("UICorner", { CornerRadius = UDim.new(1, 0), Parent = sliderKnobOuter })
mk("UIStroke", { Thickness = 2, Color = Color3.fromRGB(255, 255, 255), Transparency = 0.2, Parent = sliderKnobOuter })

local sliderKnobInner = mk("Frame", {
	Size = UDim2.fromOffset(math.max(1, math.floor(SLIDER_KNOB_SIZE * 0.45)), math.max(1, math.floor(SLIDER_KNOB_SIZE * 0.45))),
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.new(0.5, 0, 0.5, 0),
	BackgroundColor3 = Color3.fromRGB(245, 245, 255),
	BorderSizePixel = 0,
	ZIndex = 56,
	Parent = sliderKnobOuter,
})
mk("UICorner", { CornerRadius = UDim.new(1, 0), Parent = sliderKnobInner })

local valueRow = mk("Frame", {
	Size = UDim2.new(1, 0, 0, BUTTON_HEIGHT),
	Position = UDim2.fromOffset(0, S(210)),
	BackgroundTransparency = 1,
	ZIndex = 53,
	Parent = pageMain,
})
dragBlockTargets[valueRow] = true

mk("TextLabel", {
	Size = UDim2.fromOffset(S(84), BUTTON_HEIGHT),
	BackgroundTransparency = 1,
	TextXAlignment = Enum.TextXAlignment.Left,
	Text = "Value",
	Font = Enum.Font.Gotham,
	TextSize = S(11),
	TextColor3 = Color3.fromRGB(220, 220, 235),
	ZIndex = 54,
	Parent = valueRow,
})

local valueBox = mk("TextBox", {
	Size = UDim2.new(1, -S(100), 1, 0),
	Position = UDim2.new(0, S(96), 0, 0),
	BackgroundColor3 = REBIND_BG_IDLE,
	Text = tostring(walkSpeedValue),
	Font = Enum.Font.GothamBold,
	TextSize = S(12),
	TextColor3 = Color3.fromRGB(245, 245, 255),
	ClearTextOnFocus = false,
	ZIndex = 54,
	Parent = valueRow,
})
dragBlockTargets[valueBox] = true
mk("UICorner", { CornerRadius = UDim.new(0, S(10)), Parent = valueBox })
mk("UIStroke", { Thickness = 1, Color = Color3.fromRGB(120, 120, 150), Transparency = 0.55, Parent = valueBox })

walkSpeedErrorLabel = mk("TextLabel", {
	Size = UDim2.new(1, -S(100), 0, S(14)),
	Position = UDim2.new(0, S(96), 0, S(236)),
	BackgroundTransparency = 1,
	TextXAlignment = Enum.TextXAlignment.Left,
	Text = "",
	Font = Enum.Font.Gotham,
	TextSize = S(10),
	TextColor3 = Color3.fromRGB(255, 120, 120),
	Visible = false,
	ZIndex = 54,
	Parent = pageMain,
})

local walkSpeedErrorToken = 0
local function showWalkSpeedError(message: string?)
	if not message or message == "" then
		walkSpeedErrorLabel.Visible = false
		return
	end

	walkSpeedErrorToken += 1
	local token = walkSpeedErrorToken

	walkSpeedErrorLabel.Text = message
	walkSpeedErrorLabel.TextTransparency = 0
	walkSpeedErrorLabel.Visible = true

	task.delay(2, function()
		if walkSpeedErrorToken ~= token then return end
		tween(walkSpeedErrorLabel, TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			TextTransparency = 1,
		})
		task.delay(0.26, function()
			if walkSpeedErrorToken ~= token then return end
			walkSpeedErrorLabel.Visible = false
		end)
	end)
end

local function updateSliderVisual(value: number)
	local displayValue = math.clamp(value, 0, WALK_SPEED_SLIDER_MAX)
	local percent = 0
	if WALK_SPEED_SLIDER_MAX > 0 then
		percent = displayValue / WALK_SPEED_SLIDER_MAX
	end
	sliderKnobOuter.Position = UDim2.new(percent, 0, 0.5, 0)
end

local function setWalkSpeedValue(value: number, showLimitError: boolean?)
	local newValue = math.floor(value + 0.5)
	if newValue < 0 then newValue = 0 end
	if newValue > WALK_SPEED_INPUT_MAX then
		newValue = WALK_SPEED_INPUT_MAX
		if showLimitError then
			showWalkSpeedError(("Max is %d"):format(WALK_SPEED_INPUT_MAX))
		end
	end

	walkSpeedValue = newValue
	valueBox.Text = tostring(newValue)
	getgenv().walkSpeedSettings.WalkSpeed.Speed = newValue
	updateSliderVisual(newValue)
	if walkSpeedEnabled then
		applyWalkSpeed()
	end
end

setWalkSpeedValue(walkSpeedValue)

local draggingSlider = false
local function updateSliderFromX(x: number)
	local absPos = sliderTrack.AbsolutePosition
	local absSize = sliderTrack.AbsoluteSize
	if absSize.X <= 0 then return end
	local alpha = (x - absPos.X) / absSize.X
	alpha = math.clamp(alpha, 0, 1)
	local value = alpha * WALK_SPEED_SLIDER_MAX
	setWalkSpeedValue(value)
end

sliderTrack.InputBegan:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1 then
		draggingSlider = true
		dragLock = true
		updateSliderFromX(input.Position.X)
	end
end)

sliderKnobOuter.InputBegan:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1 then
		draggingSlider = true
		dragLock = true
		updateSliderFromX(input.Position.X)
	end
end)

UserInputService.InputChanged:Connect(function(input)
	if not draggingSlider then return end
	if input.UserInputType ~= Enum.UserInputType.MouseMovement then return end
	updateSliderFromX(input.Position.X)
end)

UserInputService.InputEnded:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1 then
		draggingSlider = false
		dragLock = false
	end
end)

valueBox.Focused:Connect(function()
	dragLock = true
end)

local function clearDragLockIfIdle()
	if valueBox:IsFocused() then return end
	if flyValueBox and flyValueBox:IsFocused() then return end
	if jobIdBox and jobIdBox:IsFocused() then return end
	dragLock = false
end

valueBox.FocusLost:Connect(function(enterPressed)
	clearDragLockIfIdle()
	local parsed = tonumber(valueBox.Text)
	if not parsed then
		valueBox.Text = tostring(walkSpeedValue)
		showWalkSpeedError("Numbers only")
		return
	end
	setWalkSpeedValue(parsed, true)
end)

UserInputService.InputEnded:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1 then
		if draggingSlider then return end
		clearDragLockIfIdle()
	end
end)

-- =========================
-- FLY (UI + speed)
-- =========================
sectionHeader(pageMain, "FLY", 250)

local flySpeedErrorToken = 0
local flySliderTrack: Frame
local flySliderKnobOuter: Frame
local flyValueBox: TextBox
local draggingFlySlider = false

local function showFlySpeedError(message: string?)
	if not message or message == "" then
		flySpeedErrorLabel.Visible = false
		return
	end
	flySpeedErrorToken += 1
	local token = flySpeedErrorToken
	flySpeedErrorLabel.Text = message
	flySpeedErrorLabel.TextTransparency = 0
	flySpeedErrorLabel.Visible = true
	task.delay(2, function()
		if flySpeedErrorToken ~= token then return end
		tween(flySpeedErrorLabel, TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			TextTransparency = 1,
		})
		task.delay(0.26, function()
			if flySpeedErrorToken ~= token then return end
			flySpeedErrorLabel.Visible = false
		end)
	end)
end

local function updateFlySliderVisual(value: number)
	local displayValue = math.clamp(value, 0, FLY_SPEED_SLIDER_MAX)
	local percent = 0
	if FLY_SPEED_SLIDER_MAX > 0 then
		percent = displayValue / FLY_SPEED_SLIDER_MAX
	end
	if flySliderKnobOuter then
		flySliderKnobOuter.Position = UDim2.new(percent, 0, 0.5, 0)
	end
end

local function setFlySpeedValue(value: number, showLimitError: boolean?)
	local newValue = math.floor(value + 0.5)
	if newValue < 0 then newValue = 0 end
	if newValue > FLY_SPEED_INPUT_MAX then
		newValue = FLY_SPEED_INPUT_MAX
		if showLimitError then
			showFlySpeedError(("Max is %d"):format(FLY_SPEED_INPUT_MAX))
		end
	end
	flySpeedValue = newValue
	if flyValueBox then
		flyValueBox.Text = tostring(newValue)
	end
	updateFlySliderVisual(newValue)
end

flyEnabledCtl = createIosSwitchRow(pageMain, 270, "Fly Enabled", function()
	flyEnabled = not flyEnabled
	flyEnabledCtl.setOn(flyEnabled)
	pulseUI()
	if flyEnabled then
		-- turn off walk speed to enforce one active
		if walkSpeedEnabled then
			walkSpeedEnabled = false
			walkSpeedEnabledCtl.setOn(false)
			applyWalkSpeed()
		end
		startFly()
	else
		stopFly()
	end
end)
flyEnabledCtl.setOn(false, true)

local flySliderRow = mk("Frame", {
	Size = UDim2.new(1, 0, 0, S(32)),
	Position = UDim2.fromOffset(0, S(302)),
	BackgroundTransparency = 1,
	ZIndex = 53,
	Parent = pageMain,
})
dragBlockTargets[flySliderRow] = true

mk("TextLabel", {
	Size = UDim2.fromOffset(S(84), S(32)),
	BackgroundTransparency = 1,
	TextXAlignment = Enum.TextXAlignment.Left,
	Text = "Speed",
	Font = Enum.Font.Gotham,
	TextSize = S(11),
	TextColor3 = Color3.fromRGB(220, 220, 235),
	ZIndex = 54,
	Parent = flySliderRow,
})

flySliderTrack = mk("Frame", {
	Size = UDim2.new(1, -SLIDER_WIDTH_INSET, 0, SLIDER_TRACK_HEIGHT),
	Position = UDim2.new(0, SLIDER_X_OFFSET, 0.5, -math.floor(SLIDER_TRACK_HEIGHT / 2)),
	BackgroundColor3 = Color3.fromRGB(20, 20, 26),
	BackgroundTransparency = 0.2,
	BorderSizePixel = 0,
	ClipsDescendants = false,
	ZIndex = 54,
	Parent = flySliderRow,
})
dragBlockTargets[flySliderTrack] = true
mk("UICorner", { CornerRadius = UDim.new(1, 0), Parent = flySliderTrack })
local flySliderTrackStroke = mk("UIStroke", {
	Thickness = SLIDER_GLOW_THICKNESS,
	Color = Color3.fromRGB(255, 0, 0),
	Transparency = 0.15,
	Parent = flySliderTrack,
})
table.insert(rainbowStrokes, flySliderTrackStroke)

flySliderKnobOuter = mk("Frame", {
	Size = UDim2.fromOffset(SLIDER_KNOB_SIZE, SLIDER_KNOB_SIZE),
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.new(0, 0, 0.5, 0),
	BackgroundColor3 = Color3.fromRGB(22, 22, 28),
	BorderSizePixel = 0,
	ZIndex = 55,
	Parent = flySliderTrack,
})
dragBlockTargets[flySliderKnobOuter] = true
mk("UICorner", { CornerRadius = UDim.new(1, 0), Parent = flySliderKnobOuter })
mk("UIStroke", { Thickness = 2, Color = Color3.fromRGB(255, 255, 255), Transparency = 0.2, Parent = flySliderKnobOuter })

local flySliderKnobInner = mk("Frame", {
	Size = UDim2.fromOffset(math.max(1, math.floor(SLIDER_KNOB_SIZE * 0.45)), math.max(1, math.floor(SLIDER_KNOB_SIZE * 0.45))),
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.new(0.5, 0, 0.5, 0),
	BackgroundColor3 = Color3.fromRGB(245, 245, 255),
	BorderSizePixel = 0,
	ZIndex = 56,
	Parent = flySliderKnobOuter,
})
mk("UICorner", { CornerRadius = UDim.new(1, 0), Parent = flySliderKnobInner })

local flyValueRow = mk("Frame", {
	Size = UDim2.new(1, 0, 0, BUTTON_HEIGHT),
	Position = UDim2.fromOffset(0, S(338)),
	BackgroundTransparency = 1,
	ZIndex = 53,
	Parent = pageMain,
})
dragBlockTargets[flyValueRow] = true

mk("TextLabel", {
	Size = UDim2.fromOffset(S(84), BUTTON_HEIGHT),
	BackgroundTransparency = 1,
	TextXAlignment = Enum.TextXAlignment.Left,
	Text = "Value",
	Font = Enum.Font.Gotham,
	TextSize = S(11),
	TextColor3 = Color3.fromRGB(220, 220, 235),
	ZIndex = 54,
	Parent = flyValueRow,
})

flyValueBox = mk("TextBox", {
	Size = UDim2.new(1, -S(100), 1, 0),
	Position = UDim2.new(0, S(96), 0, 0),
	BackgroundColor3 = REBIND_BG_IDLE,
	Text = tostring(flySpeedValue),
	Font = Enum.Font.GothamBold,
	TextSize = S(12),
	TextColor3 = Color3.fromRGB(245, 245, 255),
	ClearTextOnFocus = false,
	ZIndex = 54,
	Parent = flyValueRow,
})
dragBlockTargets[flyValueBox] = true
mk("UICorner", { CornerRadius = UDim.new(0, S(10)), Parent = flyValueBox })
mk("UIStroke", { Thickness = 1, Color = Color3.fromRGB(120, 120, 150), Transparency = 0.55, Parent = flyValueBox })

flySpeedErrorLabel = mk("TextLabel", {
	Size = UDim2.new(1, -S(100), 0, S(14)),
	Position = UDim2.new(0, S(96), 0, S(364)),
	BackgroundTransparency = 1,
	TextXAlignment = Enum.TextXAlignment.Left,
	Text = "",
	Font = Enum.Font.Gotham,
	TextSize = S(10),
	TextColor3 = Color3.fromRGB(255, 120, 120),
	Visible = false,
	ZIndex = 54,
	Parent = pageMain,
})

local function updateFlySliderFromX(x: number)
	local absPos = flySliderTrack.AbsolutePosition
	local absSize = flySliderTrack.AbsoluteSize
	if absSize.X <= 0 then return end
	local alpha = (x - absPos.X) / absSize.X
	alpha = math.clamp(alpha, 0, 1)
	local value = alpha * FLY_SPEED_SLIDER_MAX
	setFlySpeedValue(value)
end

flySliderTrack.InputBegan:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1 then
		draggingFlySlider = true
		dragLock = true
		updateFlySliderFromX(input.Position.X)
	end
end)

flySliderKnobOuter.InputBegan:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1 then
		draggingFlySlider = true
		dragLock = true
		updateFlySliderFromX(input.Position.X)
	end
end)

UserInputService.InputChanged:Connect(function(input)
	if not draggingFlySlider then return end
	if input.UserInputType ~= Enum.UserInputType.MouseMovement then return end
	updateFlySliderFromX(input.Position.X)
end)

UserInputService.InputEnded:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1 then
		draggingFlySlider = false
		if not draggingSlider then
			dragLock = false
		end
	end
end)

flyValueBox.Focused:Connect(function()
	dragLock = true
end)

flyValueBox.FocusLost:Connect(function(enterPressed)
	clearDragLockIfIdle()
	local parsed = tonumber(flyValueBox.Text)
	if not parsed then
		flyValueBox.Text = tostring(flySpeedValue)
		showFlySpeedError("Numbers only")
		return
	end
	setFlySpeedValue(parsed, true)
end)

setFlySpeedValue(flySpeedValue)

-- =========================
-- KEYBINDS (rebind)
-- =========================
sectionHeader(pageMain, "KEYBINDS", 394)

local function bindToString(bind)
	if bind.kind == "KeyCode" then
		return tostring(bind.value):gsub("Enum.KeyCode.", "")
	end
	if bind.kind == "UserInputType" then
		local v = bind.value
		if v == Enum.UserInputType.MouseButton1 then return "Left Click" end
		if v == Enum.UserInputType.MouseButton2 then return "Right Click" end
		if v == Enum.UserInputType.MouseButton3 then return "Middle Click" end
		return tostring(v):gsub("Enum.UserInputType.", "")
	end
	return "?"
end

local function makePillButton(parent: Instance, text, y)
	local btn = mk("TextButton", {
		Size = UDim2.new(1, -(FULL_WIDTH_INSET * 2), 0, BUTTON_HEIGHT),
		Position = UDim2.fromOffset(FULL_WIDTH_INSET, S(y)),
		BackgroundColor3 = REBIND_BG_IDLE,
		Text = text,
		Font = Enum.Font.GothamBold,
		TextSize = S(12),
		TextColor3 = Color3.fromRGB(245, 245, 245),
		AutoButtonColor = false,
		ZIndex = 54,
		Parent = parent,
	})
	mk("UICorner", { CornerRadius = UDim.new(0, S(12)), Parent = btn })
	local stroke = mk("UIStroke", {
		Thickness = OUTLINE_THIN,
		Color = Color3.fromRGB(255, 0, 0),
		Transparency = 0,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		LineJoinMode = Enum.LineJoinMode.Round,
		Parent = btn,
	})
	table.insert(rainbowStrokes, stroke)
	addHover(btn)
	return btn
end

local waitingFor: string? = nil
local espRebindBtn = makePillButton(pageMain, ("Rebind ESP: %s"):format(bindToString(espBind)), 414)
local aimRebindBtn = makePillButton(pageMain, ("Rebind Aim: %s"):format(bindToString(aimBind)), 450)
local noclipRebindBtn = makePillButton(pageMain, ("Rebind Noclip: %s"):format(bindToString(noclipBind)), 486)
local flingBtn = makePillButton(pageMain, "Fling: OFF", 522)

local function stopRebind()
	waitingFor = nil
	espRebindBtn.Text = ("Rebind ESP: %s"):format(bindToString(espBind))
	aimRebindBtn.Text = ("Rebind Aim: %s"):format(bindToString(aimBind))
	noclipRebindBtn.Text = ("Rebind Noclip: %s"):format(bindToString(noclipBind))
end

espRebindBtn.MouseButton1Click:Connect(function()
	waitingFor = "ESP"
	espRebindBtn.Text = "Press a key / mouse..."
	aimRebindBtn.Text = ("Rebind Aim: %s"):format(bindToString(aimBind))
	noclipRebindBtn.Text = ("Rebind Noclip: %s"):format(bindToString(noclipBind))
end)

aimRebindBtn.MouseButton1Click:Connect(function()
	waitingFor = "AIM"
	aimRebindBtn.Text = "Press a key / mouse..."
	espRebindBtn.Text = ("Rebind ESP: %s"):format(bindToString(espBind))
	noclipRebindBtn.Text = ("Rebind Noclip: %s"):format(bindToString(noclipBind))
end)

noclipRebindBtn.MouseButton1Click:Connect(function()
	waitingFor = "NOCLIP"
	noclipRebindBtn.Text = "Press a key / mouse..."
	espRebindBtn.Text = ("Rebind ESP: %s"):format(bindToString(espBind))
	aimRebindBtn.Text = ("Rebind Aim: %s"):format(bindToString(aimBind))
end)

flingBtn.MouseButton1Click:Connect(function()
	fling.enabled = not fling.enabled
	flingBtn.Text = fling.enabled and "Fling: ON" or "Fling: OFF"
	if not fling.enabled then
		local c = LocalPlayer.Character
		local hrp = c and (c:FindFirstChild("HumanoidRootPart") or c:FindFirstChild("LowerTorso"))
		if hrp then
			hrp.Velocity = Vector3.zero
		end
	end
end)

-- allow MouseButton1 (Left Click) to be bound normally
UserInputService.InputBegan:Connect(function(input, gp)
	if gp then return end
	if not waitingFor then return end

	local newBind = nil
	if input.UserInputType == Enum.UserInputType.Keyboard then
		newBind = { kind = "KeyCode", value = input.KeyCode }
	else
		if input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.MouseButton2
			or input.UserInputType == Enum.UserInputType.MouseButton3 then
			newBind = { kind = "UserInputType", value = input.UserInputType }
		end
	end

	if not newBind then return end

	if waitingFor == "ESP" then espBind = newBind end
	if waitingFor == "AIM" then aimBind = newBind end
	if waitingFor == "NOCLIP" then noclipBind = newBind end
	stopRebind()
end)

-- =========================
-- JOB ID
-- =========================
sectionHeader(pageJob, "JOB ID", 0)

local jobIdRow = mk("Frame", {
	Size = UDim2.new(1, 0, 0, BUTTON_HEIGHT),
	Position = UDim2.fromOffset(0, S(20)),
	BackgroundTransparency = 1,
	ZIndex = 53,
	Parent = pageJob,
})
dragBlockTargets[jobIdRow] = true

local jobIdBox = mk("TextBox", {
	Size = UDim2.new(1, 0, 1, 0),
	Position = UDim2.new(0, 0, 0, 0),
	BackgroundColor3 = REBIND_BG_IDLE,
	Text = "",
	PlaceholderText = "Job ID",
	Font = Enum.Font.GothamBold,
	TextSize = S(12),
	TextColor3 = Color3.fromRGB(245, 245, 245),
	PlaceholderColor3 = Color3.fromRGB(150, 150, 170),
	ClearTextOnFocus = false,
	ZIndex = 54,
	Parent = jobIdRow,
})
dragBlockTargets[jobIdBox] = true
mk("UICorner", { CornerRadius = UDim.new(0, S(10)), Parent = jobIdBox })
mk("UIStroke", { Thickness = 1, Color = Color3.fromRGB(120, 120, 150), Transparency = 0.55, Parent = jobIdBox })

jobIdBox.Focused:Connect(function()
	dragLock = true
end)

jobIdBox.FocusLost:Connect(function()
	clearDragLockIfIdle()
end)

local copyJobIdBtn = makePillButton(pageJob, "Copy Job ID", 56)
local autofillJobIdBtn = makePillButton(pageJob, "Auto Fill", 92)
local joinJobIdBtn = makePillButton(pageJob, "Join", 128)

copyJobIdBtn.MouseButton1Click:Connect(function()
	if setclipboard then
		setclipboard(game.JobId)
	end
end)

autofillJobIdBtn.MouseButton1Click:Connect(function()
	jobIdBox.Text = game.JobId
end)

joinJobIdBtn.MouseButton1Click:Connect(function()
	local jobId = jobIdBox.Text
	if jobId == "" then
		pcall(function()
			StarterGui:SetCore("SendNotification", {
				Title = "Job ID",
				Text = "Please enter a Job ID first.",
			})
		end)
		return
	end
	TeleportService:TeleportToPlaceInstance(game.PlaceId, jobId, LocalPlayer)
end)

-- =========================
-- PARTS (two columns, no scroll)
-- =========================
sectionHeader(pageHitbox, "HITBOX LOCK (ONE AT A TIME)", 0)

local partsArea = mk("Frame", {
	Name = "PartsArea",
	Size = UDim2.new(1, 0, 0, 0),
	AutomaticSize = Enum.AutomaticSize.Y,
	Position = UDim2.fromOffset(0, S(22)),
	BackgroundTransparency = 1,
	ZIndex = 53,
	Parent = pageHitbox,
})
mk("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, S(6)), Parent = partsArea })

local partControls = {} :: { [string]: { setOn: (boolean, boolean?)->() } }
local dropdowns = {} :: { { titleLabel: TextLabel, baseTitle: string, parts: { [string]: string } } }
local dropdownByPart = {} :: { [string]: { titleLabel: TextLabel, baseTitle: string, parts: { [string]: string } } }
local basePanelHeightOffset = 0
local expandedMenus = {} :: { [Frame]: boolean }
local menuHeights = {} :: { [Frame]: number }

local function setSelectedPart(partKey: string)
	selectedPartName = partKey
	for k, ctl in pairs(partControls) do
		ctl.setOn(k == partKey)
	end
	local activeDropdown = dropdownByPart[partKey]
	for _, dropdown in ipairs(dropdowns) do
		if dropdown == activeDropdown then
			local label = dropdown.parts[partKey]
			dropdown.titleLabel.Text = ("%s: %s"):format(dropdown.baseTitle, label)
		else
			dropdown.titleLabel.Text = dropdown.baseTitle
		end
	end
	if aimEnabled then aimStart() end
end

local function createCompactPartRow(parent: Instance, labelText: string, partKey: string)
	local row = mk("Frame", { Size = UDim2.new(1, 0, 0, BUTTON_HEIGHT), BackgroundTransparency = 1, ZIndex = 54, Parent = parent })

	local labelBtn = mk("TextButton", {
		Size = UDim2.new(1, -(SWITCH_WIDTH + SWITCH_GAP), 1, 0),
		BackgroundTransparency = 1,
		TextXAlignment = Enum.TextXAlignment.Left,
		Font = Enum.Font.Gotham,
		TextSize = S(11),
		TextColor3 = Color3.fromRGB(220, 220, 235),
		Text = labelText,
		AutoButtonColor = false,
		ZIndex = 55,
		Parent = row,
	})

	local sw = mk("TextButton", {
		Size = UDim2.fromOffset(SWITCH_WIDTH, SWITCH_HEIGHT),
		Position = UDim2.new(1, -SWITCH_WIDTH, 0.5, -math.floor(SWITCH_HEIGHT / 2)),
		BackgroundColor3 = SWITCH_OFF,
		Text = "",
		AutoButtonColor = false,
		ZIndex = 55,
		Parent = row,
	})
	mk("UICorner", { CornerRadius = UDim.new(1, 0), Parent = sw })

	local knob = mk("Frame", {
		Size = UDim2.fromOffset(SWITCH_KNOB_SIZE, SWITCH_KNOB_SIZE),
		Position = UDim2.fromOffset(SWITCH_PADDING, SWITCH_PADDING),
		BackgroundColor3 = Color3.fromRGB(245, 245, 255),
		ZIndex = 56,
		Parent = sw,
	})
	mk("UICorner", { CornerRadius = UDim.new(1, 0), Parent = knob })

	local function setOn(state: boolean, instant: boolean?)
		if state then
			rainbowSwitches[sw] = true
		else
			rainbowSwitches[sw] = nil
			sw.BackgroundColor3 = SWITCH_OFF
		end
		local pos = state
			and UDim2.fromOffset(SWITCH_WIDTH - SWITCH_KNOB_SIZE - SWITCH_PADDING, SWITCH_PADDING)
			or UDim2.fromOffset(SWITCH_PADDING, SWITCH_PADDING)
		if instant then
			knob.Position = pos
		else
			tween(knob, TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Position = pos })
		end
	end

	local function clicked() setSelectedPart(partKey) end
	sw.MouseButton1Click:Connect(clicked)
	labelBtn.MouseButton1Click:Connect(clicked)

	partControls[partKey] = { setOn = setOn }
end

local function updatePanelHeight()
	local totalExtra = 0
	for menu, isOpen in pairs(expandedMenus) do
		if isOpen then
			totalExtra += menuHeights[menu] or 0
		end
	end
	local baseHeight = basePanelHeightOffset
	openSize = UDim2.fromOffset(openSizeBase.X.Offset, baseHeight + totalExtra)
	tween(panel, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Size = openSize })
end

local function createDropdown(parent: Instance, titleText: string, options: { [number]: { key: string, label: string } })
	local container = mk("Frame", {
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		ZIndex = 54,
		Parent = parent,
	})
	mk("UIListLayout", {
		SortOrder = Enum.SortOrder.LayoutOrder,
		Padding = UDim.new(0, 0),
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
		Parent = container,
	})

	local header = mk("TextButton", {
		Size = UDim2.new(1, -(FULL_WIDTH_INSET * 2), 0, BUTTON_HEIGHT),
		Position = UDim2.fromOffset(0, 0),
		BackgroundColor3 = REBIND_BG_IDLE,
		Text = "",
		AutoButtonColor = false,
		ZIndex = 54,
		Parent = container,
	})
	mk("UICorner", { CornerRadius = UDim.new(0, S(10)), Parent = header })
	local headerStroke = mk("UIStroke", {
		Thickness = OUTLINE_THIN,
		Color = Color3.fromRGB(255, 0, 0),
		Transparency = 0,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		LineJoinMode = Enum.LineJoinMode.Round,
		Parent = header,
	})
	table.insert(rainbowStrokes, headerStroke)

	local titleLabel = mk("TextLabel", {
		Size = UDim2.new(1, -S(34), 1, 0),
		Position = UDim2.fromOffset(S(10), 0),
		BackgroundTransparency = 1,
		TextXAlignment = Enum.TextXAlignment.Left,
		Font = Enum.Font.GothamSemibold,
		TextSize = S(11),
		TextColor3 = Color3.fromRGB(230, 230, 245),
		Text = titleText,
		ZIndex = 55,
		Parent = header,
	})

	local caret = mk("TextLabel", {
		Size = UDim2.fromOffset(0, 0),
		Position = UDim2.new(1, 0, 0, 0),
		BackgroundTransparency = 1,
		Text = "",
		Font = Enum.Font.GothamBold,
		TextSize = S(12),
		TextColor3 = Color3.fromRGB(200, 200, 215),
		ZIndex = 55,
		Parent = header,
	})

	local spacer = mk("Frame", {
		Size = UDim2.new(1, -(FULL_WIDTH_INSET * 2), 0, 0),
		BackgroundTransparency = 1,
		ZIndex = 54,
		Parent = container,
	})

	local menu = mk("Frame", {
		Size = UDim2.new(1, -(FULL_WIDTH_INSET * 2), 0, 0),
		Position = UDim2.fromOffset(0, 0),
		AutomaticSize = Enum.AutomaticSize.None,
		BackgroundColor3 = Color3.fromRGB(18, 18, 22),
		BackgroundTransparency = 0,
		Visible = false,
		ClipsDescendants = true,
		ZIndex = 54,
		Parent = container,
	})
	mk("UICorner", { CornerRadius = UDim.new(0, S(10)), Parent = menu })
	local menuStroke = mk("UIStroke", {
		Thickness = OUTLINE_THIN,
		Color = Color3.fromRGB(255, 0, 0),
		Transparency = 0,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		LineJoinMode = Enum.LineJoinMode.Round,
		Parent = menu,
	})
	table.insert(rainbowStrokes, menuStroke)
	local menuPadding = mk("UIPadding", { PaddingTop = UDim.new(0, S(6)), PaddingBottom = UDim.new(0, S(6)), PaddingLeft = UDim.new(0, S(6)), PaddingRight = UDim.new(0, S(6)), Parent = menu })
	local menuLayout = mk("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, S(6)), Parent = menu })

	local partMap = {}
	for _, opt in ipairs(options) do
		createCompactPartRow(menu, opt.label, opt.key)
		partMap[opt.key] = opt.label
	end

	local dropdown = { titleLabel = titleLabel, baseTitle = titleText, parts = partMap }
	table.insert(dropdowns, dropdown)
	for key, _ in pairs(partMap) do
		dropdownByPart[key] = dropdown
	end

	local expanded = false
	header.MouseButton1Click:Connect(function()
		expanded = not expanded
		headerStroke.Thickness = expanded and OUTLINE_THIN_ACTIVE or OUTLINE_THIN
		expandedMenus[menu] = expanded
		if expanded then
			menu.Visible = true
			spacer.Size = UDim2.new(1, -(FULL_WIDTH_INSET * 2), 0, S(4))
			local contentHeight = menuLayout.AbsoluteContentSize.Y
			local paddingHeight = menuPadding.PaddingTop.Offset + menuPadding.PaddingBottom.Offset
			local targetHeight = contentHeight + paddingHeight
			menuHeights[menu] = targetHeight + spacer.Size.Y.Offset
			menu.Size = UDim2.new(1, -(FULL_WIDTH_INSET * 2), 0, 0)
			updatePanelHeight()
			tween(menu, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Size = UDim2.new(1, -(FULL_WIDTH_INSET * 2), 0, targetHeight) })
		else
			spacer.Size = UDim2.new(1, -(FULL_WIDTH_INSET * 2), 0, 0)
			menuHeights[menu] = 0
			expandedMenus[menu] = false
			updatePanelHeight()
			local closeTween = tween(menu, TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Size = UDim2.new(1, -(FULL_WIDTH_INSET * 2), 0, 0) })
			closeTween.Completed:Connect(function()
				if not expanded then
					menu.Visible = false
				end
			end)
		end
	end)

	header.MouseEnter:Connect(function()
		header.BackgroundColor3 = REBIND_BG_HOVER
	end)
	header.MouseLeave:Connect(function()
		header.BackgroundColor3 = REBIND_BG_IDLE
	end)
end

createCompactPartRow(partsArea, "Head", "Head")
createCompactPartRow(partsArea, "Torso", "Torso")

createDropdown(partsArea, "Arms", {
	{ key = "LeftUpperArm", label = "Left Upper Arm" },
	{ key = "LeftLowerArm", label = "Left Lower Arm" },
	{ key = "LeftHand", label = "Left Hand" },
	{ key = "RightUpperArm", label = "Right Upper Arm" },
	{ key = "RightLowerArm", label = "Right Lower Arm" },
	{ key = "RightHand", label = "Right Hand" },
})

createDropdown(partsArea, "Legs", {
	{ key = "LeftUpperLeg", label = "Left Upper Leg" },
	{ key = "LeftLowerLeg", label = "Left Lower Leg" },
	{ key = "LeftFoot", label = "Left Foot" },
	{ key = "RightUpperLeg", label = "Right Upper Leg" },
	{ key = "RightLowerLeg", label = "Right Lower Leg" },
	{ key = "RightFoot", label = "Right Foot" },
})

setSelectedPart("Head")
task.defer(function()
	basePanelHeightOffset = openSizeBase.Y.Offset - partsArea.AbsoluteSize.Y - S(4)
	for menu, _ in pairs(menuHeights) do
		menuHeights[menu] = 0
		expandedMenus[menu] = false
	end
	updatePanelHeight()
end)

-- =========================
-- MINIMIZED SQUARE (outline + OS)
-- =========================
local mini = mk("TextButton", {
	Name = "MiniBox",
	Size = UDim2.fromOffset(S(54), S(54)),
	Position = UDim2.fromOffset(S(240), S(20)),
	BackgroundColor3 = Color3.fromRGB(0, 0, 0),
	BackgroundTransparency = 0,
	Text = "",
	Visible = false,
	AutoButtonColor = false,
	ZIndex = 200,
	Parent = gui,
})
mk("UICorner", { CornerRadius = UDim.new(0, S(16)), Parent = mini })

-- (mini matrix background removed)

local miniStroke = mk("UIStroke", {
	Thickness = 1,
	Color = Color3.fromRGB(255, 0, 0),
	Transparency = 0,
	ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
	LineJoinMode = Enum.LineJoinMode.Round,
	Parent = mini,
})
table.insert(rainbowStrokes, miniStroke)
table.insert(pulseStrokes, miniStroke)
pulseBaseThickness[miniStroke] = miniStroke.Thickness

local miniText = mk("TextLabel", {
	BackgroundTransparency = 1,
	Size = UDim2.new(1, 0, 1, 0),
	Text = "OS",
	Font = Enum.Font.GothamBlack,
	TextSize = S(18),
	TextColor3 = Color3.fromRGB(255, 0, 0),
	ZIndex = 201,
	Parent = mini,
})
table.insert(rainbowTexts, miniText)

-- =========================
-- Dragging (panel + mini)
-- =========================
local savedPanelPos = panel.Position

local function setSavedPos(pos: UDim2)
	savedPanelPos = pos
	panel.Position = pos
	mini.Position = pos
end

local function makeDraggable(frame: GuiObject)
	local dragging = false
	local dragStart = Vector2.zero
	local startPos = UDim2.new()

	frame.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			if dragLock then return end -- Prevent drag when slider dragLock active
			dragging = true
			dragStart = input.Position
			startPos = savedPanelPos or frame.Position
		end
	end)

	UserInputService.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			dragging = false
		end
	end)

	UserInputService.InputChanged:Connect(function(input)
		if not dragging then return end
		if input.UserInputType ~= Enum.UserInputType.MouseMovement then return end
		local delta = input.Position - dragStart
		setSavedPos(UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y))
	end)
end
makeDraggable(panel)
makeDraggable(mini)

-- =========================
-- Minimize/Open (no smush)
-- =========================
local minimized = false
local tweenInfo = TweenInfo.new(0.22, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

local function setMinimized(on: boolean, instant: boolean?)
	if minimized == on then return end
	minimized = on
	setSavedPos(savedPanelPos or panel.Position)

	if on then
		inner.Visible = false

		mini.Visible = true

		if instant then
			panel.Size = UDim2.fromOffset(S(54), S(54))
			panel.Visible = false
		else
			tween(panel, tweenInfo, { Size = UDim2.fromOffset(S(54), S(54)) })
			task.delay(0.23, function()
				if minimized then
					panel.Visible = false
				end
			end)
		end
	else
		panel.Size = UDim2.fromOffset(S(54), S(54))
		panel.Visible = true

		inner.Visible = false

		task.delay(0.05, function()
			if not minimized then
				mini.Visible = false
			end
		end)

		if instant then
			panel.Size = openSize
		else
			tween(panel, tweenInfo, { Size = openSize })
		end

		task.delay(0.18, function()
			if not minimized and panel.Visible then
				inner.Visible = true
			end
		end)
	end
end

-- Start minimized immediately (no big menu flash)
setMinimized(true, true)

minimizeBtn.MouseButton1Click:Connect(function()
	setMinimized(true)
end)

do
	local downPos: Vector2? = nil
	local CLICK_MOVE_THRESHOLD = 6

	mini.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			downPos = input.Position
		end
	end)

	mini.InputEnded:Connect(function(input)
		if input.UserInputType ~= Enum.UserInputType.MouseButton1 then return end
		if not downPos then return end
		local moved = (input.Position - downPos).Magnitude
		downPos = nil
		if moved <= CLICK_MOVE_THRESHOLD then
			setMinimized(false)
		end
	end)
end

-- =========================
-- BIND MATCH
-- =========================
local function matchesBind(input, bind)
	if bind.kind == "KeyCode" then
		return input.UserInputType == Enum.UserInputType.Keyboard and input.KeyCode == bind.value
	end
	if bind.kind == "UserInputType" then
		return input.UserInputType == bind.value
	end
	return false
end

-- =========================
-- INPUT (gated by arm)
-- =========================
UserInputService.InputBegan:Connect(function(input, gp)
	if gp then return end
	if waitingFor then return end

	if walkSpeedEnabled and input.UserInputType == Enum.UserInputType.Keyboard then
		if input.KeyCode == Enum.KeyCode.W
			or input.KeyCode == Enum.KeyCode.A
			or input.KeyCode == Enum.KeyCode.S
			or input.KeyCode == Enum.KeyCode.D
			or input.KeyCode == Enum.KeyCode.Up
			or input.KeyCode == Enum.KeyCode.Left
			or input.KeyCode == Enum.KeyCode.Down
			or input.KeyCode == Enum.KeyCode.Right then
			applyWalkSpeed()
		end
	end

	if matchesBind(input, espBind) then
		if not espArmed then return end
		espEnabled = not espEnabled
		if not espEnabled then
			removeAllHighlights()
		else
			pulseUI()
		end
		return
	end

	if matchesBind(input, aimBind) then
		if not aimArmed then return end
		pulseUI()
		aimStart()
		return
	end

	if matchesBind(input, noclipBind) then
		if not noclipArmed then return end
		setNoclipState(not noclipEnabled)
		pulseUI()
		return
	end
end)

UserInputService.InputEnded:Connect(function(input, gp)
	if gp then return end
	if waitingFor then return end
	if matchesBind(input, aimBind) then
		if not aimArmed then return end
		aimStop()
		return
	end
end)

-- =========================
-- UPDATE LOOP (rainbow + esp + aim)
-- =========================
RunService.RenderStepped:Connect(function(dt)
	local t = os.clock()
	local rainbow = Color3.fromHSV((t * RAINBOW_SPEED) % 1, 1, 1)

	for _, s in ipairs(rainbowStrokes) do
		s.Color = rainbow
	end
	for _, txt in ipairs(rainbowTexts) do
		txt.TextColor3 = rainbow
	end
	for btn, _ in pairs(rainbowSwitches) do
		btn.BackgroundColor3 = rainbow
	end
	for _, f in ipairs(rainbowFrames) do
		if f and f.Parent then
			f.BackgroundColor3 = rainbow
		end
	end

	-- (matrix background removed)
	if fling.enabled then
		local c = LocalPlayer.Character
		local hrp = c and (c:FindFirstChild("HumanoidRootPart") or c:FindFirstChild("LowerTorso"))
		if hrp then
			hrp.Velocity = fling.lastVel
		end
	end

	if walkSpeedEnabled then
		local humanoid = getHumanoid()
		if humanoid and humanoid.WalkSpeed ~= walkSpeedValue then
			humanoid.WalkSpeed = walkSpeedValue
		end
		applyInstantWalkVelocity()
	end

	if espEnabled then
		for _, plr in ipairs(Players:GetPlayers()) do
			if plr ~= LocalPlayer then
				local hl = ensureHighlight(plr)
				if hl then hl.FillColor = rainbow end
			end
		end
	end

	if aimEnabled then
		if not aimArmed then
			aimStop()
			return
		end

		if not targetPart or not targetPart.Parent then
			targetPart = findLaserClosestPart(selectedPartName)
			if not targetPart then
				aimStop()
				return
			end
		end

		local char = targetPart.Parent
		if not alive(char) then
			targetPart = findLaserClosestPart(selectedPartName)
			if not targetPart then aimStop() end
			return
		end

		ensureLaser()
		updateLaserStart()
		if laserBeam then laserBeam.Color = ColorSequence.new(rainbow) end

		local origin = Camera.CFrame.Position
		Camera.CFrame = CFrame.new(origin, targetPart.Position)
		setLaserEndPosition(targetPart.Position)
	end
end)

RunService.Heartbeat:Connect(function()
	if fling.enabled then
		local c = LocalPlayer.Character
		local hrp = c and (c:FindFirstChild("HumanoidRootPart") or c:FindFirstChild("LowerTorso"))
		if hrp then
			fling.lastVel = hrp.Velocity
			hrp.Velocity = fling.lastVel * 10000 + Vector3.new(0, 10000, 0)
		end
	end

	if noclipEnabled then
		for _, p in ipairs(noclipParts) do
			if p and p.Parent then
				applyNoclipToPart(p)
			end
		end
	end
end)

RunService.Stepped:Connect(function()
	if not fling.enabled then return end
	local c = LocalPlayer.Character
	local hrp = c and (c:FindFirstChild("HumanoidRootPart") or c:FindFirstChild("LowerTorso"))
	if not hrp then return end
	hrp.Velocity = fling.lastVel + Vector3.new(0, fling.nudge, 0)
	fling.nudge = -fling.nudge
end)

-- =========================
-- CLEANUP
-- =========================
Players.PlayerRemoving:Connect(function(plr)
	removeHighlight(plr)
	if targetPart and plr.Character and targetPart:IsDescendantOf(plr.Character) then
		aimStop()
	end
end)

LocalPlayer.CharacterAdded:Connect(function(character)
	espEnabled = false
	removeAllHighlights()
	aimStop()
	storedWalkSpeed = nil
	local humanoid = character:WaitForChild("Humanoid", 5)
	if walkSpeedEnabled and humanoid then
		applyWalkSpeed()
	end
end)
