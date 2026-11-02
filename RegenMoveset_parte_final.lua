CanCollide = false
	f.CanQuery = false
	f.CanTouch = false
	f.CastShadow = false
	f.Material = Enum.Material.Granite
	f.Color = math.random() < 0.5 and COL.Tendon or COL.Muscle
	f.Transparency = 0.15

	local pA = partA.Position + Vector3.new(rand(-0.35, 0.35), rand(-0.35, 0.35), rand(-0.35, 0.35))
	local pB = partB.Position + Vector3.new(rand(-0.35, 0.35), rand(-0.35, 0.35), rand(-0.35, 0.35))
	local dist = clamp((pB - pA).Magnitude, 0.2, 2.2)
	f.Size = Vector3.new(0.08, 0.08, dist)
	f.CFrame = CFrame.lookAt((pA + pB) * 0.5, pB)
	f.Parent = folder

	TweenService:Create(f, TweenInfo.new(0.55, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Size = Vector3.new(0.02, 0.02, dist * 0.4),
		Transparency = 1,
	}):Play()
	Debris:AddItem(f, 0.60)
end

local function StepPassiveRegeneration(dt)
	if not alive(S.gen) then return end
	local hum = S.hum
	local curHealth = hum.Health
	local maxHealth = math.max(hum.MaxHealth, 1)

	if curHealth < S.lastHealth - 0.5 then
		local dmgFrac = (S.lastHealth - curHealth) / maxHealth
		S.integrity = clamp01(S.integrity - dmgFrac * 1.25)
	end
	S.lastHealth = curHealth

	if (curHealth < maxHealth or S.integrity < 1.0) and S.busy == nil then
		pcall(function()
			hum.Health = math.min(maxHealth, curHealth + CFG.PassiveRegen.HealPerSecond * dt)
		end)
		S.integrity = clamp01(S.integrity + 0.08 * dt)
		S.passivePulseTimer += dt
		if S.passivePulseTimer >= CFG.PassiveRegen.PulseInterval then
			S.passivePulseTimer = 0
			local ut = GetUpperTorso()
			local lt = GetLowerTorso()
			if ut and lt then
				SpawnPassiveMendFiber(ut, lt)
			end
		end
	else
		S.integrity = clamp01(S.integrity + 0.04 * dt)
	end
end

--------------------------------------------------------------------------------
-- 17. INTERFACE MINIMALISTA E PROFISSIONAL (DESIGN LIMPO E TÁTIL)
--------------------------------------------------------------------------------
local BUTTON_DEFS = {
	{ id = "Jump",       label = "SALTO",    icon = "▲", key = Enum.KeyCode.Q, keyText = "Q" },
	{ id = "Noclip",     label = "NOCLIP",   icon = "●", key = Enum.KeyCode.E, keyText = "E" },
	{ id = "Grapple",    label = "GANCHO",   icon = "↗", key = Enum.KeyCode.R, keyText = "R" },
	{ id = "HeadThrow",  label = "CABEÇA",   icon = "◉", key = Enum.KeyCode.F, keyText = "F" },
	{ id = "ArmControl", label = "BRAÇO",    icon = "✋", key = Enum.KeyCode.G, keyText = "G" },
	{ id = "AccelRegen", label = "REGEN",    icon = "✚", key = Enum.KeyCode.Z, keyText = "Z" },
	{ id = "ProneRegen", label = "RECONSTR", icon = "▬", key = Enum.KeyCode.X, keyText = "X" },
}

local UI_PALETTE = {
	Bg         = Color3.fromRGB(16, 17, 19),
	BgActive   = Color3.fromRGB(28, 30, 34),
	Border     = Color3.fromRGB(44, 46, 52),
	BorderAct  = Color3.fromRGB(142, 42, 46),
	TextMain   = Color3.fromRGB(224, 224, 228),
	TextMuted  = Color3.fromRGB(130, 132, 138),
	CooldownBg = Color3.fromRGB(10, 10, 12),
	BarBg      = Color3.fromRGB(22, 23, 26),
	BarFill    = Color3.fromRGB(132, 34, 38),
}

local UI = {
	gui         = nil,
	buttons     = {},
	banner      = nil,
	passiveFill = nil,
}

local TryUseAbility

function UI.Build()
	local pg = player:WaitForChild("PlayerGui")
	local old = pg:FindFirstChild("RegenMovesetUI")
	if old then old:Destroy() end

	local sg = Instance.new("ScreenGui")
	sg.Name = "RegenMovesetUI"
	sg.IgnoreGuiInset = true
	sg.ResetOnSpawn = false
	sg.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	sg.Parent = pg
	UI.gui = sg

	local banner = Instance.new("TextLabel")
	banner.Name = "AimBanner"
	banner.AnchorPoint = Vector2.new(0.5, 0)
	banner.Position = UDim2.new(0.5, 0, 0, 40)
	banner.Size = UDim2.fromOffset(IS_MOBILE and 300 or 370, 26)
	banner.BackgroundColor3 = UI_PALETTE.Bg
	banner.BackgroundTransparency = 0.16
	banner.Font = Enum.Font.GothamMedium
	banner.TextSize = IS_MOBILE and 11 or 12
	banner.TextColor3 = UI_PALETTE.TextMain
	banner.Text = ""
	banner.Visible = false
	banner.Parent = sg
	local bCorner = Instance.new("UICorner")
	bCorner.CornerRadius = UDim.new(0, 4)
	bCorner.Parent = banner
	local bStroke = Instance.new("UIStroke")
	bStroke.Thickness = 1
	bStroke.Color = UI_PALETTE.BorderAct
	bStroke.Transparency = 0.35
	bStroke.Parent = banner
	UI.banner = banner

	SetBanner = function(msg)
		if not UI.banner then return end
		if msg and msg ~= "" then
			UI.banner.Text = msg
			UI.banner.Visible = true
		else
			UI.banner.Visible = false
		end
	end

	local btnSize = IS_MOBILE and 46 or 50
	local gap     = IS_MOBILE and 5 or 6
	local totalWidth = #BUTTON_DEFS * btnSize + (#BUTTON_DEFS - 1) * gap

	local container = Instance.new("Frame")
	container.Name = "HUDContainer"
	container.AnchorPoint = Vector2.new(0.5, 1)
	container.Position = UDim2.new(0.5, 0, 1, IS_MOBILE and -12 or -16)
	container.Size = UDim2.fromOffset(totalWidth, btnSize + 9)
	container.BackgroundTransparency = 1
	container.Parent = sg

	local pBarBg = Instance.new("Frame")
	pBarBg.Name = "PassiveIntegrityBar"
	pBarBg.Position = UDim2.fromOffset(0, 0)
	pBarBg.Size = UDim2.fromOffset(totalWidth, 3)
	pBarBg.BackgroundColor3 = UI_PALETTE.BarBg
	pBarBg.BackgroundTransparency = 0.25
	pBarBg.BorderSizePixel = 0
	pBarBg.Parent = container
	local pCorner = Instance.new("UICorner")
	pCorner.CornerRadius = UDim.new(0, 2)
	pCorner.Parent = pBarBg

	local pFill = Instance.new("Frame")
	pFill.Name = "Fill"
	pFill.Size = UDim2.fromScale(1, 1)
	pFill.BackgroundColor3 = UI_PALETTE.BarFill
	pFill.BorderSizePixel = 0
	pFill.Parent = pBarBg
	local pfCorner = Instance.new("UICorner")
	pfCorner.CornerRadius = UDim.new(0, 2)
	pfCorner.Parent = pFill
	UI.passiveFill = pFill

	local bar = Instance.new("Frame")
	bar.Name = "ActionBar"
	bar.Position = UDim2.fromOffset(0, 7)
	bar.Size = UDim2.fromOffset(totalWidth, btnSize)
	bar.BackgroundTransparency = 1
	bar.Parent = container

	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.VerticalAlignment = Enum.VerticalAlignment.Center
	layout.Padding = UDim.new(0, gap)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = bar

	for idx, def in ipairs(BUTTON_DEFS) do
		local btn = Instance.new("TextButton")
		btn.Name = def.id
		btn.LayoutOrder = idx
		btn.Size = UDim2.fromOffset(btnSize, btnSize)
		btn.BackgroundColor3 = UI_PALETTE.Bg
		btn.BackgroundTransparency = 0.14
		btn.AutoButtonColor = false
		btn.Text = ""
		btn.ClipsDescendants = true
		btn.Parent = bar

		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0, 5)
		corner.Parent = btn

		local stroke = Instance.new("UIStroke")
		stroke.Thickness = 1
		stroke.Color = UI_PALETTE.Border
		stroke.Transparency = 0.25
		stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		stroke.Parent = btn

		local scale = Instance.new("UIScale")
		scale.Scale = 1
		scale.Parent = btn

		if not IS_MOBILE then
			local keyLbl = Instance.new("TextLabel")
			keyLbl.Position = UDim2.fromOffset(4, 2)
			keyLbl.Size = UDim2.fromOffset(14, 11)
			keyLbl.BackgroundTransparency = 1
			keyLbl.Font = Enum.Font.GothamMedium
			keyLbl.TextSize = 9
			keyLbl.TextXAlignment = Enum.TextXAlignment.Left
			keyLbl.TextColor3 = UI_PALETTE.TextMuted
			keyLbl.Text = def.keyText
			keyLbl.Parent = btn
		end

		local icon = Instance.new("TextLabel")
		icon.AnchorPoint = Vector2.new(0.5, 0.5)
		icon.Position = UDim2.new(0.5, 0, 0.40, 0)
		icon.Size = UDim2.fromOffset(22, 18)
		icon.BackgroundTransparency = 1
		icon.Font = Enum.Font.GothamMedium
		icon.TextSize = IS_MOBILE and 13 or 14
		icon.TextColor3 = UI_PALETTE.TextMain
		icon.Text = def.icon
		icon.Parent = btn

		local lbl = Instance.new("TextLabel")
		lbl.AnchorPoint = Vector2.new(0.5, 1)
		lbl.Position = UDim2.new(0.5, 0, 1, -3)
		lbl.Size = UDim2.new(1, -4, 0, 11)
		lbl.BackgroundTransparency = 1
		lbl.Font = Enum.Font.GothamMedium
		lbl.TextSize = IS_MOBILE and 7 or 8
		lbl.TextColor3 = UI_PALETTE.TextMuted
		lbl.Text = def.label
		lbl.Parent = btn

		local cdFill = Instance.new("Frame")
		cdFill.AnchorPoint = Vector2.new(0, 1)
		cdFill.Position = UDim2.fromScale(0, 1)
		cdFill.Size = UDim2.fromScale(1, 0)
		cdFill.BackgroundColor3 = UI_PALETTE.CooldownBg
		cdFill.BackgroundTransparency = 0.22
		cdFill.BorderSizePixel = 0
		cdFill.ZIndex = 3
		cdFill.Parent = btn

		local cdText = Instance.new("TextLabel")
		cdText.AnchorPoint = Vector2.new(0.5, 0.5)
		cdText.Position = UDim2.fromScale(0.5, 0.5)
		cdText.Size = UDim2.fromScale(1, 1)
		cdText.BackgroundTransparency = 1
		cdText.Font = Enum.Font.GothamMedium
		cdText.TextSize = 11
		cdText.TextColor3 = UI_PALETTE.TextMain
		cdText.Text = ""
		cdText.ZIndex = 4
		cdText.Parent = btn

		btn.InputBegan:Connect(function(inp)
			if inp.UserInputType == Enum.UserInputType.MouseButton1 or inp.UserInputType == Enum.UserInputType.Touch then
				TweenService:Create(scale, TweenInfo.new(0.06, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Scale = 0.94 }):Play()
			end
		end)
		btn.InputEnded:Connect(function(inp)
			if inp.UserInputType == Enum.UserInputType.MouseButton1 or inp.UserInputType == Enum.UserInputType.Touch then
				TweenService:Create(scale, TweenInfo.new(0.10, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Scale = 1.0 }):Play()
			end
		end)
		btn.MouseLeave:Connect(function()
			TweenService:Create(scale, TweenInfo.new(0.10, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Scale = 1.0 }):Play()
		end)

		btn.Activated:Connect(function()
			if TryUseAbility then
				TryUseAbility(def.id)
			end
		end)

		UI.buttons[def.id] = {
			btn    = btn,
			stroke = stroke,
			scale  = scale,
			icon   = icon,
			lbl    = lbl,
			cdFill = cdFill,
			cdText = cdText,
		}
	end
end

function UI.DenyFeedback(id)
	local b = UI.buttons[id]
	if not b then return end
	TweenService:Create(b.scale, TweenInfo.new(0.05), { Scale = 0.92 }):Play()
	task.delay(0.06, function()
		if b.scale and b.scale.Parent then
			TweenService:Create(b.scale, TweenInfo.new(0.12), { Scale = 1.0 }):Play()
		end
	end)
end

RunService.RenderStepped:Connect(function(dt)
	local stepDt = math.min(dt, 0.05)
	StepPassiveRegeneration(stepDt)
	CamDirector:Step(stepDt)

	if UI.passiveFill and S.hum then
		local healthFrac = clamp01(S.hum.Health / math.max(S.hum.MaxHealth, 1))
		local displayFrac = clamp01(math.min(healthFrac, S.integrity))
		UI.passiveFill.Size = UDim2.fromScale(displayFrac, 1)
	end

	local now = os.clock()
	for _, def in ipairs(BUTTON_DEFS) do
		local b = UI.buttons[def.id]
		if b then
			local maxCd = CFG.Cooldown[def.id] or 5
			local rem   = math.max(0, (S.cd[def.id] or 0) - now)
			local frac  = clamp01(rem / maxCd)
			local isActive = (S.busy == def.id)
			local isLocked = (S.busy ~= nil and S.busy ~= def.id)

			b.cdFill.Size = UDim2.fromScale(1, frac)
			b.cdText.Text = rem > 0.05 and string.format("%.1f", rem) or ""
			b.btn.BackgroundColor3 = isActive and UI_PALETTE.BgActive or UI_PALETTE.Bg
			b.btn.BackgroundTransparency = isLocked and 0.46 or 0.14
			b.stroke.Color = isActive and UI_PALETTE.BorderAct or UI_PALETTE.Border
			b.stroke.Thickness = isActive and 1.4 or 1.0
			b.icon.TextTransparency = (isLocked or rem > 0) and 0.45 or 0.0
			b.lbl.TextTransparency  = (isLocked or rem > 0) and 0.50 or 0.0
		end
	end
end)

--------------------------------------------------------------------------------
-- 18. DESPACHANTE DE HABILIDADES, TRANSIÇÕES E CICLO DE VIDA DO PERSONAGEM
--------------------------------------------------------------------------------
local ABILITY_HANDLERS = {
	Jump       = AbilityJump,
	Noclip     = AbilityNoclip,
	Grapple    = AbilityGrapple,
	HeadThrow  = AbilityHeadThrow,
	ArmControl = AbilityArmControl,
	AccelRegen = AbilityAcceleratedRegen,
	ProneRegen = AbilityProneRebuild,
}

TryUseAbility = function(id)
	if S.busy == "Grapple" and id == "Grapple" and aimCallback ~= nil then
		S.cancelAim = true
		return
	end
	if S.busy == "ArmControl" and id == "ArmControl" then
		S.endEarly = true
		return
	end

	if not alive(S.gen) then return end
	if S.busy ~= nil then
		UI.DenyFeedback(id)
		return
	end

	local now = os.clock()
	if (S.cd[id] or 0) > now then
		UI.DenyFeedback(id)
		return
	end

	if id == "Jump" and S.hum.FloorMaterial == Enum.Material.Air then
		UI.DenyFeedback(id)
		return
	end

	local fn = ABILITY_HANDLERS[id]
	if not fn then return end

	S.busy = id
	local myGen = S.gen
	local ctx = NewCtx(myGen)

	task.spawn(function()
		local ok, result = pcall(fn, ctx)
		ctx.maid:Clean()
		if S.gen == myGen then
			S.busy = nil
			if ok and result ~= false then
				S.cd[id] = os.clock() + (CFG.Cooldown[id] or 5)
			end
		end
	end)
end

UIS.InputBegan:Connect(function(input, gameProcessed)
	if aimCallback ~= nil then
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			local pos = UIS:GetMouseLocation()
			aimCallback(pos)
			return
		end
	end

	if gameProcessed then return end
	if UIS:GetFocusedTextBox() then return end

	for _, def in ipairs(BUTTON_DEFS) do
		if input.KeyCode == def.key then
			TryUseAbility(def.id)
			return
		end
	end
end)

local function OnCharacterAdded(char)
	S.gen += 1
	S.busy      = nil
	S.cancelAim = false
	S.endEarly  = false
	S.char      = char
	S.hum       = char:WaitForChild("Humanoid", 10)
	S.root      = char:WaitForChild("HumanoidRootPart", 10)
	if not S.hum or not S.root then return end

	S.r6         = (S.hum.RigType == Enum.HumanoidRigType.R6)
	S.lastHealth = S.hum.Health
	S.integrity  = 1.0
	table.clear(S.cd)
	SetBanner(nil)
	CamDirector:ClearStage()

	local cam = Workspace.CurrentCamera
	if cam then
		CamDirector.baseFov = cam.FieldOfView
	end

	S.hum.Died:Connect(function()
		S.gen += 1
		S.busy = nil
		SetBanner(nil)
		CamDirector:ClearStage()
	end)
end

UI.Build()
if player.Character then
	task.spawn(OnCharacterAdded, player.Character)
end
player.CharacterAdded:Connect(OnCharacterAdded)
