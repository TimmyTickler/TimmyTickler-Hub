local cloneref    = cloneref or clonereference or function(o) return o end
local gethui      = (typeof(gethui) == "function") and gethui or nil
local protect_gui = (typeof(protectgui) == "function" and protectgui)
	or (typeof(syn) == "table" and syn.protect_gui)
	or nil

local Players          = cloneref(game:GetService("Players"))
local TweenService     = cloneref(game:GetService("TweenService"))
local UserInputService = cloneref(game:GetService("UserInputService"))
local RunService       = cloneref(game:GetService("RunService"))
local TextService      = cloneref(game:GetService("TextService"))

assert(RunService:IsClient(), "UILib must run on the client")

local LocalPlayer = cloneref(Players.LocalPlayer)

local function mountGui(gui)
	if protect_gui then pcall(protect_gui, gui) end
	if gethui then
		local ok = pcall(function() gui.Parent = gethui() end)
		if ok and gui.Parent then return end
	end
	warn("[UILib] no gethui/protect_gui on this executor - mounting in PlayerGui (DETECTABLE).")
	gui.Parent = LocalPlayer:WaitForChild("PlayerGui")
end

local Theme = {
	Base         = Color3.fromRGB(17, 17, 22),
	Surface      = Color3.fromRGB(25, 25, 32),
	SurfaceHover = Color3.fromRGB(31, 31, 40),
	Sunken       = Color3.fromRGB(12, 12, 16),
	Stroke       = Color3.fromRGB(37, 37, 47),
	StrokeLight  = Color3.fromRGB(55, 55, 70),
	Accent       = Color3.fromRGB(124, 108, 255),
	Accent2      = Color3.fromRGB(170, 132, 255),
	Text         = Color3.fromRGB(236, 236, 244),
	SubText      = Color3.fromRGB(148, 148, 164),
	Dim          = Color3.fromRGB(96, 96, 112),
}

local FONT         = Enum.Font.BuilderSans
local FONT_MEDIUM  = Enum.Font.BuilderSansMedium
local FONT_BOLD    = Enum.Font.BuilderSansBold

local UILib = {}
UILib.Theme = Theme


local function create(className, props)
	local inst = Instance.new(className)
	local parent = nil
	for k, v in pairs(props or {}) do
		if k == "Parent" then
			parent = v
		else
			inst[k] = v
		end
	end
	if parent then
		inst.Parent = parent
	end
	return inst
end

local function round(inst, radius)
	create("UICorner", { CornerRadius = UDim.new(0, radius or 8), Parent = inst })
end

local function stroke(inst, color, transparency)
	return create("UIStroke", {
		Color = color or Theme.Stroke,
		Transparency = transparency or 0,
		Thickness = 1,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		Parent = inst,
	})
end

local function accentGradient(inst, rotation)
	return create("UIGradient", {
		Rotation = rotation or 0,
		Color = ColorSequence.new(Theme.Accent, Theme.Accent2),
		Parent = inst,
	})
end

local function tween(inst, props, time, style)
	TweenService:Create(
		inst,
		TweenInfo.new(time or 0.18, style or Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		props
	):Play()
end

local function safeCall(callback, ...)
	if callback then
		task.spawn(callback, ...)
	end
end

local function label(props)
	local defaults = {
		BackgroundTransparency = 1,
		Font = FONT_MEDIUM,
		TextColor3 = Theme.Text,
		TextSize = 14,
		TextXAlignment = Enum.TextXAlignment.Left,
	}
	for k, v in pairs(props) do
		defaults[k] = v
	end
	return create("TextLabel", defaults)
end

local function snap(value, min, max, step)
	value = math.clamp(value, min, max)
	value = math.round(value / step) * step
	return tonumber(string.format("%.10g", math.clamp(value, min, max)))
end

local function bindDrag(frame, onUpdate)
	frame.InputBegan:Connect(function(input)
		if input.UserInputType ~= Enum.UserInputType.MouseButton1
			and input.UserInputType ~= Enum.UserInputType.Touch then
			return
		end

		local first = true
		local function update(position)
			local px = math.clamp((position.X - frame.AbsolutePosition.X) / frame.AbsoluteSize.X, 0, 1)
			local py = math.clamp((position.Y - frame.AbsolutePosition.Y) / frame.AbsoluteSize.Y, 0, 1)
			onUpdate(px, py, first)
			first = false
		end

		update(input.Position)

		local moveConn, endConn
		moveConn = UserInputService.InputChanged:Connect(function(i)
			if i.UserInputType == Enum.UserInputType.MouseMovement
				or i.UserInputType == Enum.UserInputType.Touch then
				update(i.Position)
			end
		end)
		endConn = UserInputService.InputEnded:Connect(function(i)
			if i.UserInputType == Enum.UserInputType.MouseButton1
				or i.UserInputType == Enum.UserInputType.Touch then
				moveConn:Disconnect()
				endConn:Disconnect()
			end
		end)
	end)
end

local function makeDraggable(handle, target, connections)
	local dragging = false
	local dragStart, startPos

	handle.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.Touch then
			dragging = true
			dragStart = input.Position
			startPos = target.Position
		end
	end)
	handle.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.Touch then
			dragging = false
		end
	end)
	table.insert(connections, UserInputService.InputChanged:Connect(function(input)
		if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement
			or input.UserInputType == Enum.UserInputType.Touch) then
			local delta = input.Position - dragStart
			target.Position = UDim2.new(
				startPos.X.Scale, startPos.X.Offset + delta.X,
				startPos.Y.Scale, startPos.Y.Offset + delta.Y
			)
		end
	end))
end


function UILib:CreateWindow(options)
	options = options or {}
	local toggleKey = options.ToggleKey or Enum.KeyCode.RightShift
	local size = options.Size or Vector2.new(680, 460)
	local useSidebar = options.Sidebar ~= false

	if options.Accent then
		Theme.Accent = options.Accent
		Theme.Accent2 = options.Accent:Lerp(Color3.new(1, 1, 1), 0.25)
	end

	local connections = {}

	local gui = create("ScreenGui", {
		Name = options.Title or "UILib",
		ResetOnSpawn = false,
		IgnoreGuiInset = true,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		DisplayOrder = 100,
	})
	mountGui(gui)

	local root = create("Frame", {
		Name = "Root",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(size.X, size.Y),
		Parent = gui,
	})
	local rootScale = create("UIScale", { Scale = 1.04, Parent = root })

	local shadow = create("ImageLabel", {
		Name = "Shadow",
		BackgroundTransparency = 1,
		Image = "rbxassetid://6014261993",
		ImageColor3 = Color3.new(0, 0, 0),
		ImageTransparency = 0.45,
		ScaleType = Enum.ScaleType.Slice,
		SliceCenter = Rect.new(49, 49, 450, 450),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.new(1, 60, 1, 60),
		Parent = root,
	})

	local main = create("CanvasGroup", {
		Name = "Main",
		BackgroundColor3 = Theme.Base,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 1),
		GroupTransparency = 1,
		Parent = root,
	})
	round(main, 12)
	stroke(main, Theme.Stroke)

	local TITLE_H = 46

	local titleBar = create("Frame", {
		Name = "TitleBar",
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, TITLE_H),
		Parent = main,
	})

	label({
		Text = options.Title or "Menu",
		Font = FONT_BOLD,
		TextSize = 16,
		Size = UDim2.new(1, -260, 1, 0),
		Position = UDim2.new(0, 16, 0, 0),
		Parent = titleBar,
	})

	if options.SubTitle then
		local titleWidth = TextService:GetTextSize(
			options.Title or "Menu", 16, FONT_BOLD, Vector2.new(1000, 50)).X
		label({
			Text = options.SubTitle,
			Font = FONT,
			TextColor3 = Theme.Dim,
			TextSize = 13,
			Size = UDim2.new(0, 200, 1, 0),
			Position = UDim2.new(0, 26 + titleWidth, 0, 1),
			Parent = titleBar,
		})
	end

	local keyChip = create("Frame", {
		BackgroundColor3 = Theme.Sunken,
		BorderSizePixel = 0,
		AnchorPoint = Vector2.new(1, 0.5),
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.new(0, 0, 0, 22),
		Position = UDim2.new(1, -84, 0.5, 0),
		Parent = titleBar,
	})
	round(keyChip, 6)
	stroke(keyChip, Theme.Stroke)
	label({
		Text = toggleKey.Name,
		Font = FONT_MEDIUM,
		TextColor3 = Theme.Dim,
		TextSize = 11,
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.new(0, 0, 1, 0),
		TextXAlignment = Enum.TextXAlignment.Center,
		Parent = keyChip,
	})
	create("UIPadding", {
		PaddingLeft = UDim.new(0, 8),
		PaddingRight = UDim.new(0, 8),
		Parent = keyChip,
	})

	local function windowButton(text, xOffset)
		local btn = create("TextButton", {
			Text = text,
			Font = FONT_MEDIUM,
			TextSize = 14,
			TextColor3 = Theme.Dim,
			BackgroundColor3 = Theme.Surface,
			BackgroundTransparency = 1,
			AnchorPoint = Vector2.new(1, 0.5),
			Size = UDim2.fromOffset(30, 30),
			Position = UDim2.new(1, xOffset, 0.5, 0),
			Parent = titleBar,
		})
		round(btn, 8)
		btn.MouseEnter:Connect(function()
			tween(btn, { BackgroundTransparency = 0, TextColor3 = Theme.Text })
		end)
		btn.MouseLeave:Connect(function()
			tween(btn, { BackgroundTransparency = 1, TextColor3 = Theme.Dim })
		end)
		return btn
	end

	local closeBtn = windowButton("×", -10)
	local minimizeBtn = windowButton("–", -44)

	create("Frame", { -- divider under title bar
		BackgroundColor3 = Theme.Stroke,
		BorderSizePixel = 0,
		Size = UDim2.new(1, 0, 0, 1),
		Position = UDim2.new(0, 0, 0, TITLE_H),
		Parent = main,
	})

local window = {
    Gui = gui,
    Main = main,
    Tabs = {},
    Visible = true,
    _search = {},
    _decor = {},
    _keybinds = {},
}

	local SIDEBAR_W = 176
	local content
	local tabList
	local searchBox = nil

	if useSidebar then
		local sidebar = create("Frame", {
			Name = "Sidebar",
			BackgroundTransparency = 1,
			Position = UDim2.new(0, 0, 0, TITLE_H + 1),
			Size = UDim2.new(0, SIDEBAR_W, 1, -(TITLE_H + 1)),
			Parent = main,
		})
		create("Frame", {
			BackgroundColor3 = Theme.Stroke,
			BorderSizePixel = 0,
			Size = UDim2.new(0, 1, 1, -(TITLE_H + 1)),
			Position = UDim2.new(0, SIDEBAR_W, 0, TITLE_H + 1),
			Parent = main,
		})

		-- search box
		searchBox = create("TextBox", {
			Text = "",
			PlaceholderText = "Search...",
			PlaceholderColor3 = Theme.Dim,
			Font = FONT_MEDIUM,
			TextSize = 12,
			TextColor3 = Theme.Text,
			TextXAlignment = Enum.TextXAlignment.Left,
			BackgroundColor3 = Theme.Sunken,
			BorderSizePixel = 0,
			ClearTextOnFocus = false,
			Size = UDim2.new(1, -20, 0, 28),
			Position = UDim2.new(0, 10, 0, 10),
			Parent = sidebar,
		})
		round(searchBox, 6)
		local searchStroke = stroke(searchBox, Theme.Stroke)
		create("UIPadding", {
			PaddingLeft = UDim.new(0, 10),
			PaddingRight = UDim.new(0, 10),
			Parent = searchBox,
		})
		searchBox.Focused:Connect(function()
			tween(searchStroke, { Color = Theme.Accent })
		end)
		searchBox.FocusLost:Connect(function()
			tween(searchStroke, { Color = Theme.Stroke })
		end)

		tabList = create("ScrollingFrame", {
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			Position = UDim2.new(0, 0, 0, 46),
			Size = UDim2.new(1, 0, 1, -(46 + 56)),
			CanvasSize = UDim2.new(),
			AutomaticCanvasSize = Enum.AutomaticSize.Y,
			ScrollBarThickness = 2,
			ScrollBarImageColor3 = Theme.Stroke,
			Parent = sidebar,
		})
		create("UIListLayout", {
			Padding = UDim.new(0, 4),
			SortOrder = Enum.SortOrder.LayoutOrder,
			Parent = tabList,
		})
		create("UIPadding", {
			PaddingTop = UDim.new(0, 2),
			PaddingLeft = UDim.new(0, 10),
			PaddingRight = UDim.new(0, 10),
			PaddingBottom = UDim.new(0, 10),
			Parent = tabList,
		})

		local userCard = create("Frame", {
			BackgroundTransparency = 1,
			Size = UDim2.new(1, 0, 0, 56),
			Position = UDim2.new(0, 0, 1, -56),
			Parent = sidebar,
		})
		create("Frame", {
			BackgroundColor3 = Theme.Stroke,
			BorderSizePixel = 0,
			Size = UDim2.new(1, -20, 0, 1),
			Position = UDim2.new(0, 10, 0, 0),
			Parent = userCard,
		})
		local avatar = create("ImageLabel", {
			BackgroundColor3 = Theme.Surface,
			Image = string.format(
				"rbxthumb://type=AvatarHeadShot&id=%d&w=48&h=48",
				math.max(LocalPlayer.UserId, 1)
			),
			Size = UDim2.fromOffset(32, 32),
			Position = UDim2.new(0, 12, 0.5, -16),
			Parent = userCard,
		})
		round(avatar, 16)
		label({
			Text = LocalPlayer.DisplayName,
			TextSize = 13,
			Size = UDim2.new(1, -60, 0, 16),
			Position = UDim2.new(0, 52, 0, 12),
			TextTruncate = Enum.TextTruncate.AtEnd,
			Parent = userCard,
		})
		label({
			Text = "@" .. LocalPlayer.Name,
			Font = FONT,
			TextColor3 = Theme.Dim,
			TextSize = 11,
			Size = UDim2.new(1, -60, 0, 12),
			Position = UDim2.new(0, 52, 0, 29),
			TextTruncate = Enum.TextTruncate.AtEnd,
			Parent = userCard,
		})

		content = create("Frame", {
			Name = "Content",
			BackgroundTransparency = 1,
			ClipsDescendants = true,
			Position = UDim2.new(0, SIDEBAR_W + 1, 0, TITLE_H + 1),
			Size = UDim2.new(1, -(SIDEBAR_W + 1), 1, -(TITLE_H + 1)),
			Parent = main,
		})
	else
		local STRIP_H = 42
		tabList = create("ScrollingFrame", {
			Name = "TabStrip",
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			Position = UDim2.new(0, 0, 0, TITLE_H + 1),
			Size = UDim2.new(1, 0, 0, STRIP_H),
			CanvasSize = UDim2.new(),
			AutomaticCanvasSize = Enum.AutomaticSize.X,
			ScrollBarThickness = 0,
			ScrollingDirection = Enum.ScrollingDirection.X,
			Parent = main,
		})
		create("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			Padding = UDim.new(0, 6),
			SortOrder = Enum.SortOrder.LayoutOrder,
			VerticalAlignment = Enum.VerticalAlignment.Center,
			Parent = tabList,
		})
		create("UIPadding", {
			PaddingLeft = UDim.new(0, 12),
			PaddingRight = UDim.new(0, 12),
			Parent = tabList,
		})

		content = create("Frame", {
			Name = "Content",
			BackgroundTransparency = 1,
			ClipsDescendants = true,
			Position = UDim2.new(0, 0, 0, TITLE_H + 1 + STRIP_H),
			Size = UDim2.new(1, 0, 1, -(TITLE_H + 1 + STRIP_H)),
			Parent = main,
		})
	end

	local function applySearch(query)
		query = string.lower(query or "")
		local counts = {}
		for _, entry in ipairs(window._search) do
			local visible = query == "" or string.find(entry.text, query, 1, true) ~= nil
			entry.frame.Visible = visible
			if visible then
				counts[entry.tab] = (counts[entry.tab] or 0) + 1
			end
		end
		for _, frame in ipairs(window._decor) do
			frame.Visible = query == ""
		end
		for _, t in ipairs(window.Tabs) do
			t.Button.TextTransparency = (query ~= "" and (counts[t] or 0) == 0) and 0.6 or 0
		end
	end

	if searchBox then
		searchBox:GetPropertyChangedSignal("Text"):Connect(function()
			applySearch(searchBox.Text)
		end)
	end

	local notifHolder = create("Frame", {
		Name = "Notifications",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -16, 0, 16),
		Size = UDim2.new(0, 300, 1, -32),
		Parent = gui,
	})
	create("UIListLayout", {
		Padding = UDim.new(0, 8),
		SortOrder = Enum.SortOrder.LayoutOrder,
		HorizontalAlignment = Enum.HorizontalAlignment.Right,
		Parent = notifHolder,
	})

	makeDraggable(titleBar, root, connections)

	local ctxFrame = nil
	local ctxConn = nil

	local function closeContext()
		if ctxFrame then
			ctxFrame:Destroy()
			ctxFrame = nil
		end
		if ctxConn then
			ctxConn:Disconnect()
			ctxConn = nil
		end
	end

	function window:_openContext(items, position)
		closeContext()
		local inset = game:GetService("GuiService"):GetGuiInset()
		ctxFrame = create("Frame", {
			BackgroundColor3 = Theme.Surface,
			BorderSizePixel = 0,
			Size = UDim2.new(0, 170, 0, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			Position = UDim2.fromOffset(position.X + inset.X, position.Y + inset.Y),
			ZIndex = 200,
			Parent = gui,
		})
		round(ctxFrame, 8)
		stroke(ctxFrame, Theme.StrokeLight)
		create("UIListLayout", {
			Padding = UDim.new(0, 2),
			SortOrder = Enum.SortOrder.LayoutOrder,
			Parent = ctxFrame,
		})
		create("UIPadding", {
			PaddingTop = UDim.new(0, 5),
			PaddingBottom = UDim.new(0, 5),
			PaddingLeft = UDim.new(0, 5),
			PaddingRight = UDim.new(0, 5),
			Parent = ctxFrame,
		})
		for i, item in ipairs(items) do
			local btn = create("TextButton", {
				Text = item.Text or "?",
				Font = FONT_MEDIUM,
				TextSize = 12,
				TextColor3 = Theme.SubText,
				TextXAlignment = Enum.TextXAlignment.Left,
				BackgroundColor3 = Theme.SurfaceHover,
				BackgroundTransparency = 1,
				BorderSizePixel = 0,
				Size = UDim2.new(1, 0, 0, 26),
				ZIndex = 201,
				LayoutOrder = i,
				Parent = ctxFrame,
			})
			round(btn, 6)
			create("UIPadding", { PaddingLeft = UDim.new(0, 10), Parent = btn })
			btn.MouseEnter:Connect(function()
				tween(btn, { BackgroundTransparency = 0, TextColor3 = Theme.Text })
			end)
			btn.MouseLeave:Connect(function()
				tween(btn, { BackgroundTransparency = 1, TextColor3 = Theme.SubText })
			end)
			btn.MouseButton1Click:Connect(function()
				closeContext()
				safeCall(item.Callback)
			end)
		end
		local myFrame = ctxFrame
		task.defer(function()
			if ctxFrame ~= myFrame then
				return
			end
			local vp = gui.AbsoluteSize
			local sz = ctxFrame.AbsoluteSize
			local gx = math.clamp(position.X + inset.X, 8, math.max(8, vp.X - sz.X - 8))
			local gy = math.clamp(position.Y + inset.Y, 8, math.max(8, vp.Y - sz.Y - 8))
			ctxFrame.Position = UDim2.fromOffset(gx, gy)
			ctxConn = UserInputService.InputBegan:Connect(function(input)
				if input.UserInputType == Enum.UserInputType.MouseButton1
					or input.UserInputType == Enum.UserInputType.MouseButton2 then
					if not ctxFrame then return end
					local p = input.Position
					local ap, as = ctxFrame.AbsolutePosition, ctxFrame.AbsoluteSize
					if p.X < ap.X or p.X > ap.X + as.X or p.Y < ap.Y or p.Y > ap.Y + as.Y then
						closeContext()
					end
				end
			end)
		end)
	end

	local hud, hudList = nil, nil

	local function refreshHUD()
		if not hudList then
			return
		end
		for _, child in ipairs(hudList:GetChildren()) do
			if child:IsA("Frame") then
				child:Destroy()
			end
		end
		local function addRow(order, keyText, labelText)
			local row = create("Frame", {
				BackgroundTransparency = 1,
				Size = UDim2.new(1, 0, 0, 20),
				LayoutOrder = order,
				Parent = hudList,
			})
			local chip = create("Frame", {
				BackgroundColor3 = Theme.Sunken,
				BorderSizePixel = 0,
				AutomaticSize = Enum.AutomaticSize.X,
				Size = UDim2.new(0, 0, 0, 18),
				Position = UDim2.new(0, 0, 0.5, -9),
				Parent = row,
			})
			round(chip, 4)
			stroke(chip, Theme.Stroke)
			label({
				Text = keyText,
				TextSize = 10,
				TextColor3 = Theme.Accent2,
				TextXAlignment = Enum.TextXAlignment.Center,
				AutomaticSize = Enum.AutomaticSize.X,
				Size = UDim2.new(0, 0, 1, 0),
				Parent = chip,
			})
			create("UIPadding", {
				PaddingLeft = UDim.new(0, 6),
				PaddingRight = UDim.new(0, 6),
				Parent = chip,
			})
			label({
				Text = labelText,
				Font = FONT,
				TextSize = 11,
				TextColor3 = Theme.SubText,
				Size = UDim2.new(1, -70, 1, 0),
				Position = UDim2.new(0, 66, 0, 0),
				TextTruncate = Enum.TextTruncate.AtEnd,
				Parent = row,
			})
		end
		addRow(0, toggleKey.Name, "Toggle menu")
		for i, entry in ipairs(window._keybinds) do
			local key = entry.get()
			addRow(i, key and key.Name or "None", entry.label)
		end
	end
	window._refreshKeybindHUD = refreshHUD

	local function ensureHUD()
		if hud then
			return
		end
		hud = create("Frame", {
			Name = "KeybindHUD",
			BackgroundColor3 = Theme.Base,
			BackgroundTransparency = 0.1,
			BorderSizePixel = 0,
			Size = UDim2.new(0, 190, 0, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			Position = UDim2.new(0, 16, 0, 16),
			Parent = gui,
		})
		round(hud, 10)
		stroke(hud, Theme.Stroke)
		create("UIPadding", {
			PaddingTop = UDim.new(0, 10),
			PaddingBottom = UDim.new(0, 10),
			PaddingLeft = UDim.new(0, 12),
			PaddingRight = UDim.new(0, 12),
			Parent = hud,
		})
		label({
			Text = "KEYBINDS",
			Font = FONT_BOLD,
			TextSize = 10,
			TextColor3 = Theme.Dim,
			Size = UDim2.new(1, 0, 0, 14),
			Parent = hud,
		})
		hudList = create("Frame", {
			BackgroundTransparency = 1,
			Size = UDim2.new(1, 0, 0, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			Position = UDim2.new(0, 0, 0, 18),
			Parent = hud,
		})
		create("UIListLayout", {
			Padding = UDim.new(0, 2),
			SortOrder = Enum.SortOrder.LayoutOrder,
			Parent = hudList,
		})
		makeDraggable(hud, hud, connections)
	end

	function window:SetKeybindHUD(visible)
		if visible then
			ensureHUD()
			refreshHUD()
		end
		if hud then
			hud.Visible = visible == true
		end
	end

	if options.Resizable ~= false then
		local grip = create("TextButton", {
			Text = "",
			BackgroundTransparency = 1,
			AnchorPoint = Vector2.new(1, 1),
			Size = UDim2.fromOffset(18, 18),
			Position = UDim2.new(1, -2, 1, -2),
			ZIndex = 50,
			Parent = main,
		})
		for i, len in ipairs({ 12, 7 }) do
			create("Frame", {
				BackgroundColor3 = Theme.Dim,
				BorderSizePixel = 0,
				AnchorPoint = Vector2.new(0.5, 0.5),
				Size = UDim2.fromOffset(len, 1),
				Position = UDim2.new(0.5, i * 2 - 2, 0.5, i * 2 - 2),
				Rotation = -45,
				Parent = grip,
			})
		end

		local resizing = false
		local resizeStart, startSize, startPos
		grip.InputBegan:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.MouseButton1
				or input.UserInputType == Enum.UserInputType.Touch then
				resizing = true
				resizeStart = input.Position
				startSize = Vector2.new(root.AbsoluteSize.X, root.AbsoluteSize.Y)
				startPos = root.Position
			end
		end)
		grip.InputEnded:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.MouseButton1
				or input.UserInputType == Enum.UserInputType.Touch then
				resizing = false
			end
		end)
		table.insert(connections, UserInputService.InputChanged:Connect(function(input)
			if resizing and (input.UserInputType == Enum.UserInputType.MouseMovement
				or input.UserInputType == Enum.UserInputType.Touch) then
				local delta = input.Position - resizeStart
				local newW = math.clamp(startSize.X + delta.X, 460, 1400)
				local newH = math.clamp(startSize.Y + delta.Y, 320, 900)
				root.Size = UDim2.fromOffset(newW, newH)
				-- anchor is centered; shift position so the top-left corner stays put
				root.Position = UDim2.new(
					startPos.X.Scale, startPos.X.Offset + (newW - startSize.X) / 2,
					startPos.Y.Scale, startPos.Y.Offset + (newH - startSize.Y) / 2
				)
			end
		end))
	end

	local animating = false
	local function animateIn()
		root.Visible = true
		animating = true
		rootScale.Scale = 1.04
		tween(main, { GroupTransparency = 0 }, 0.22)
		tween(rootScale, { Scale = 1 }, 0.25, Enum.EasingStyle.Back)
		tween(shadow, { ImageTransparency = 0.45 }, 0.22)
		task.delay(0.25, function() animating = false end)
	end
	local function animateOut()
		animating = true
		tween(main, { GroupTransparency = 1 }, 0.18)
		tween(rootScale, { Scale = 1.04 }, 0.18)
		tween(shadow, { ImageTransparency = 1 }, 0.18)
		task.delay(0.2, function()
			root.Visible = false
			animating = false
		end)
	end

	function window:SetVisible(visible)
		if visible == window.Visible or animating then
			return
		end
		window.Visible = visible
		if visible then
			animateIn()
		else
			animateOut()
		end
	end

	function window:Toggle()
		window:SetVisible(not window.Visible)
	end

	function window:Destroy()
		closeContext()
		for _, conn in ipairs(connections) do
			conn:Disconnect()
		end
		gui:Destroy()
	end

	function window:Notify(opts)
		opts = opts or {}
		local hasActions = opts.Actions and #opts.Actions > 0
		local duration = opts.Duration or (hasActions and 8 or 4)

		local notif = create("CanvasGroup", {
			BackgroundColor3 = Theme.Surface,
			Size = UDim2.new(1, 0, 0, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			GroupTransparency = 1,
			BorderSizePixel = 0,
			ClipsDescendants = true,
			Parent = notifHolder,
		})
		round(notif, 10)
		stroke(notif, Theme.Stroke)

		local body = create("Frame", {
			BackgroundTransparency = 1,
			Size = UDim2.new(1, 0, 0, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			Parent = notif,
		})
		create("UIListLayout", {
			Padding = UDim.new(0, 5),
			SortOrder = Enum.SortOrder.LayoutOrder,
			Parent = body,
		})
		create("UIPadding", {
			PaddingTop = UDim.new(0, 12),
			PaddingBottom = UDim.new(0, 14),
			PaddingLeft = UDim.new(0, 16),
			PaddingRight = UDim.new(0, 14),
			Parent = body,
		})
		local bar = create("Frame", {
			BackgroundColor3 = Theme.Accent,
			BorderSizePixel = 0,
			Size = UDim2.new(0, 3, 1, -16),
			Position = UDim2.new(0, 6, 0, 8),
			Parent = notif,
		})
		round(bar, 2)
		accentGradient(bar, 90)
		label({
			Text = opts.Title or "Notification",
			Font = FONT_BOLD,
			TextSize = 14,
			Size = UDim2.new(1, 0, 0, 16),
			LayoutOrder = 1,
			Parent = body,
		})
		if opts.Text then
			label({
				Text = opts.Text,
				Font = FONT,
				TextColor3 = Theme.SubText,
				TextSize = 13,
				TextWrapped = true,
				AutomaticSize = Enum.AutomaticSize.Y,
				Size = UDim2.new(1, 0, 0, 0),
				LayoutOrder = 2,
				Parent = body,
			})
		end

		local dismissed = false
		local function dismiss()
			if dismissed or not notif.Parent then
				return
			end
			dismissed = true
			tween(notif, { GroupTransparency = 1 }, 0.3)
			task.delay(0.35, function()
				notif:Destroy()
			end)
		end

		if hasActions then
			local row = create("Frame", {
				BackgroundTransparency = 1,
				Size = UDim2.new(1, 0, 0, 26),
				LayoutOrder = 3,
				Parent = body,
			})
			create("UIListLayout", {
				FillDirection = Enum.FillDirection.Horizontal,
				Padding = UDim.new(0, 6),
				SortOrder = Enum.SortOrder.LayoutOrder,
				Parent = row,
			})
			for i, action in ipairs(opts.Actions) do
				local btn = create("TextButton", {
					Text = action.Text or "OK",
					Font = FONT_MEDIUM,
					TextSize = 12,
					TextColor3 = Theme.Text,
					BackgroundColor3 = Theme.Sunken,
					BorderSizePixel = 0,
					AutomaticSize = Enum.AutomaticSize.X,
					Size = UDim2.new(0, 0, 0, 24),
					LayoutOrder = i,
					Parent = row,
				})
				round(btn, 6)
				local btnStroke = stroke(btn, Theme.Stroke)
				create("UIPadding", {
					PaddingLeft = UDim.new(0, 10),
					PaddingRight = UDim.new(0, 10),
					Parent = btn,
				})
				btn.MouseEnter:Connect(function()
					tween(btnStroke, { Color = Theme.Accent })
					tween(btn, { TextColor3 = Theme.Accent2 })
				end)
				btn.MouseLeave:Connect(function()
					tween(btnStroke, { Color = Theme.Stroke })
					tween(btn, { TextColor3 = Theme.Text })
				end)
				btn.MouseButton1Click:Connect(function()
					safeCall(action.Callback)
					dismiss()
				end)
			end
		end

		-- countdown bar
		local progress = create("Frame", {
			BackgroundColor3 = Theme.Accent,
			BorderSizePixel = 0,
			AnchorPoint = Vector2.new(0, 1),
			Size = UDim2.new(1, 0, 0, 2),
			Position = UDim2.new(0, 0, 1, 0),
			Parent = notif,
		})
		accentGradient(progress)

		tween(notif, { GroupTransparency = 0 }, 0.25)
		TweenService:Create(progress,
			TweenInfo.new(duration, Enum.EasingStyle.Linear),
			{ Size = UDim2.new(0, 0, 0, 2) }
		):Play()
		task.delay(duration, dismiss)
	end

	function window:SelectTab(tab)
		for _, t in ipairs(window.Tabs) do
			local selected = (t == tab)
			t.Selected = selected
			t.Page.Visible = selected
			tween(t.Button, {
				BackgroundTransparency = selected and 0 or 1,
				TextColor3 = selected and Theme.Text or Theme.SubText,
			})
			if t.Indicator then
				t.Indicator.Visible = selected
			end
		end
	end

	closeBtn.MouseButton1Click:Connect(function()
		window:Destroy()
	end)
	minimizeBtn.MouseButton1Click:Connect(function()
		window:Toggle()
	end)
	table.insert(connections, UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if gameProcessed then
			return
		end
		if input.KeyCode == toggleKey then
			window:Toggle()
		end
	end))

	local function buildTab(name, buttonParent)
		local tabButton, indicator

		if useSidebar then
			tabButton = create("TextButton", {
				Text = name,
				Font = FONT_MEDIUM,
				TextSize = 14,
				TextColor3 = Theme.SubText,
				TextXAlignment = Enum.TextXAlignment.Left,
				BackgroundColor3 = Theme.Surface,
				BackgroundTransparency = 1,
				BorderSizePixel = 0,
				Size = UDim2.new(1, 0, 0, 34),
				Parent = buttonParent,
			})
			round(tabButton, 8)
			create("UIPadding", { PaddingLeft = UDim.new(0, 18), Parent = tabButton })

			indicator = create("Frame", {
				BackgroundColor3 = Theme.Accent,
				BorderSizePixel = 0,
				Size = UDim2.new(0, 3, 0, 14),
				Position = UDim2.new(0, -11, 0.5, -7),
				Visible = false,
				Parent = tabButton,
			})
			round(indicator, 2)
			accentGradient(indicator, 90)
		else
			tabButton = create("TextButton", {
				Text = name,
				Font = FONT_MEDIUM,
				TextSize = 13,
				TextColor3 = Theme.SubText,
				BackgroundColor3 = Theme.Surface,
				BackgroundTransparency = 1,
				BorderSizePixel = 0,
				AutomaticSize = Enum.AutomaticSize.X,
				Size = UDim2.new(0, 0, 0, 28),
				Parent = buttonParent,
			})
			round(tabButton, 14)
			create("UIPadding", {
				PaddingLeft = UDim.new(0, 14),
				PaddingRight = UDim.new(0, 14),
				Parent = tabButton,
			})
		end

		local page = create("ScrollingFrame", {
			Name = name,
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			Size = UDim2.new(1, 0, 1, 0),
			CanvasSize = UDim2.new(),
			AutomaticCanvasSize = Enum.AutomaticSize.Y,
			ScrollBarThickness = 3,
			ScrollBarImageColor3 = Theme.StrokeLight,
			Visible = false,
			Parent = content,
		})
		create("UIListLayout", {
			Padding = UDim.new(0, 8),
			SortOrder = Enum.SortOrder.LayoutOrder,
			Parent = page,
		})
		create("UIPadding", {
			PaddingTop = UDim.new(0, 12),
			PaddingBottom = UDim.new(0, 12),
			PaddingLeft = UDim.new(0, 14),
			PaddingRight = UDim.new(0, 14),
			Parent = page,
		})

		local tab = {
			Name = name,
			Button = tabButton,
			Indicator = indicator,
			Page = page,
			Selected = false,
		}

		tabButton.MouseEnter:Connect(function()
			if not tab.Selected then
				tween(tabButton, { BackgroundTransparency = 0.55 })
			end
		end)
		tabButton.MouseLeave:Connect(function()
			if not tab.Selected then
				tween(tabButton, { BackgroundTransparency = 1 })
			end
		end)

		local order = 0

		local function card(baseHeight, opts, autoExpand)
			order += 1
			local hasDesc = opts and opts.Description ~= nil
			local height = baseHeight + (hasDesc and 18 or 0)
			local frame = create("Frame", {
				BackgroundColor3 = Theme.Surface,
				BorderSizePixel = 0,
				Size = UDim2.new(1, 0, 0, height),
				AutomaticSize = autoExpand and Enum.AutomaticSize.Y or Enum.AutomaticSize.None,
				LayoutOrder = order,
				Parent = page,
			})
			round(frame, 8)
			stroke(frame, Theme.Stroke, 0.25)
			return frame, height
		end

		local function finish(frame, obj, opts)
			obj = obj or {}
			local searchText = string.lower(
				((opts and opts.Text) or "") .. " " .. ((opts and opts.Description) or ""))
			table.insert(window._search, { frame = frame, text = searchText, tab = tab })

			local lockOverlay = nil
			function obj:SetDisabled(disabled)
				disabled = disabled == true
				if disabled and not lockOverlay then
					lockOverlay = create("TextButton", {
						Text = "",
						AutoButtonColor = false,
						BackgroundColor3 = Theme.Base,
						BackgroundTransparency = 0.45,
						BorderSizePixel = 0,
						Size = UDim2.new(1, 0, 1, 0),
						ZIndex = 10,
						Parent = frame,
					})
					round(lockOverlay, 8)
				end
				if lockOverlay then
					lockOverlay.Visible = disabled
				end
			end

			local frameStroke = frame:FindFirstChildOfClass("UIStroke")
			function obj:Highlight()
				if frameStroke then
					frameStroke.Color = Theme.Accent
					frameStroke.Transparency = 0
				end
				frame.BackgroundColor3 = Theme.Accent:Lerp(Theme.Surface, 0.75)
				tween(frame, { BackgroundColor3 = Theme.Surface }, 0.9)
				task.delay(0.9, function()
					if frameStroke then
						frameStroke.Color = Theme.Stroke
						frameStroke.Transparency = 0.25
					end
				end)
			end

			if opts and opts.Context then
				frame.InputBegan:Connect(function(input)
					if input.UserInputType == Enum.UserInputType.MouseButton2 then
						window:_openContext(opts.Context, input.Position)
					end
				end)
			end

			return obj
		end

		local function cardTitle(parent, opts, rowHeight, rightInset)
			rightInset = rightInset or 190
			if opts.Description then
				label({
					Text = opts.Text or "",
					Size = UDim2.new(1, -rightInset, 0, 16),
					Position = UDim2.new(0, 14, 0, math.floor(rowHeight / 2) - 17),
					TextTruncate = Enum.TextTruncate.AtEnd,
					Parent = parent,
				})
				label({
					Text = opts.Description,
					Font = FONT,
					TextColor3 = Theme.Dim,
					TextSize = 12,
					Size = UDim2.new(1, -rightInset, 0, 14),
					Position = UDim2.new(0, 14, 0, math.floor(rowHeight / 2) + 1),
					TextTruncate = Enum.TextTruncate.AtEnd,
					Parent = parent,
				})
			else
				label({
					Text = opts.Text or "",
					Size = UDim2.new(1, -rightInset, 1, 0),
					Position = UDim2.new(0, 14, 0, 0),
					TextTruncate = Enum.TextTruncate.AtEnd,
					Parent = parent,
				})
			end
		end

		local function hoverEffect(trigger, target)
			trigger.MouseEnter:Connect(function()
				tween(target, { BackgroundColor3 = Theme.SurfaceHover })
			end)
			trigger.MouseLeave:Connect(function()
				tween(target, { BackgroundColor3 = Theme.Surface })
			end)
		end

		local function clickOverlay(parent)
			return create("TextButton", {
				Text = "",
				BackgroundTransparency = 1,
				Size = UDim2.new(1, 0, 1, 0),
				Parent = parent,
			})
		end

		local function sunkenControl(parent, width, height)
			local control = create("Frame", {
				BackgroundColor3 = Theme.Sunken,
				BorderSizePixel = 0,
				AnchorPoint = Vector2.new(1, 0.5),
				Size = UDim2.fromOffset(width, height or 26),
				Position = UDim2.new(1, -14, 0.5, 0),
				Parent = parent,
			})
			round(control, 6)
			local controlStroke = stroke(control, Theme.Stroke)
			return control, controlStroke
		end

		function tab:AddSection(text)
			order += 1
			local frame = create("Frame", {
				BackgroundTransparency = 1,
				Size = UDim2.new(1, 0, 0, 26),
				LayoutOrder = order,
				Parent = page,
			})
			local textWidth = TextService:GetTextSize(
				string.upper(text), 11, FONT_BOLD, Vector2.new(1000, 50)).X
			label({
				Text = string.upper(text),
				Font = FONT_BOLD,
				TextColor3 = Theme.SubText,
				TextSize = 11,
				Size = UDim2.new(1, -8, 1, 0),
				Position = UDim2.new(0, 4, 0, 6),
				Parent = frame,
			})
			create("Frame", {
				BackgroundColor3 = Theme.Stroke,
				BorderSizePixel = 0,
				Size = UDim2.new(1, -(textWidth + 18), 0, 1),
				Position = UDim2.new(0, textWidth + 14, 0.5, 3),
				Parent = frame,
			})
			table.insert(window._decor, frame)
		end

		function tab:AddDivider()
			order += 1
			local holder = create("Frame", {
				BackgroundTransparency = 1,
				Size = UDim2.new(1, 0, 0, 9),
				LayoutOrder = order,
				Parent = page,
			})
			create("Frame", {
				BackgroundColor3 = Theme.Stroke,
				BorderSizePixel = 0,
				Size = UDim2.new(1, -8, 0, 1),
				Position = UDim2.new(0, 4, 0.5, 0),
				Parent = holder,
			})
			table.insert(window._decor, holder)
		end

		function tab:AddLabel(text)
			local frame = card(36, nil)
			local textLabel = label({
				Text = text,
				TextColor3 = Theme.SubText,
				TextSize = 13,
				Size = UDim2.new(1, -28, 1, 0),
				Position = UDim2.new(0, 14, 0, 0),
				Parent = frame,
			})
			local obj = {
				Set = function(_, newText)
					textLabel.Text = newText
				end,
			}
			return finish(frame, obj, { Text = text })
		end

		function tab:AddParagraph(opts)
			local frame = card(0, nil, true)
			create("UIPadding", {
				PaddingTop = UDim.new(0, 12),
				PaddingBottom = UDim.new(0, 12),
				PaddingLeft = UDim.new(0, 14),
				PaddingRight = UDim.new(0, 14),
				Parent = frame,
			})
			label({
				Text = opts.Title or "",
				Font = FONT_BOLD,
				TextSize = 14,
				Size = UDim2.new(1, 0, 0, 16),
				Parent = frame,
			})
			local body = label({
				Text = opts.Content or "",
				Font = FONT,
				TextColor3 = Theme.SubText,
				TextSize = 13,
				TextWrapped = true,
				AutomaticSize = Enum.AutomaticSize.Y,
				Size = UDim2.new(1, 0, 0, 0),
				Position = UDim2.new(0, 0, 0, 21),
				Parent = frame,
			})
			local obj = {
				Set = function(_, newContent)
					body.Text = newContent
				end,
			}
			return finish(frame, obj, { Text = opts.Title, Description = opts.Content, Context = opts.Context })
		end

		function tab:AddButton(opts)
			local frame, height = card(44, opts)
			local scale = create("UIScale", { Parent = frame })
			cardTitle(frame, opts, height, 40)
			label({
				Text = "›",
				Font = FONT_BOLD,
				TextColor3 = Theme.Dim,
				TextSize = 18,
				TextXAlignment = Enum.TextXAlignment.Center,
				AnchorPoint = Vector2.new(1, 0.5),
				Size = UDim2.fromOffset(20, 20),
				Position = UDim2.new(1, -12, 0.5, 0),
				Parent = frame,
			})
			local click = clickOverlay(frame)
			hoverEffect(click, frame)
			click.MouseButton1Click:Connect(function()
				tween(scale, { Scale = 0.985 }, 0.06)
				task.delay(0.07, function()
					tween(scale, { Scale = 1 }, 0.12, Enum.EasingStyle.Back)
				end)
				safeCall(opts.Callback)
			end)
			return finish(frame, nil, opts)
		end

		function tab:AddToggle(opts)
			local frame, height = card(44, opts)
			cardTitle(frame, opts, height, 70)

			local track = create("Frame", {
				BackgroundColor3 = Theme.Sunken,
				BorderSizePixel = 0,
				AnchorPoint = Vector2.new(1, 0.5),
				Size = UDim2.fromOffset(40, 22),
				Position = UDim2.new(1, -14, 0.5, 0),
				Parent = frame,
			})
			round(track, 11)
			local trackStroke = stroke(track, Theme.Stroke)
			local trackFill = create("Frame", {
				BackgroundColor3 = Theme.Accent,
				BackgroundTransparency = 1,
				BorderSizePixel = 0,
				Size = UDim2.fromScale(1, 1),
				Parent = track,
			})
			round(trackFill, 11)
			accentGradient(trackFill)
			local knob = create("Frame", {
				BackgroundColor3 = Theme.Dim,
				BorderSizePixel = 0,
				Size = UDim2.fromOffset(16, 16),
				Position = UDim2.new(0, 3, 0.5, -8),
				Parent = track,
			})
			round(knob, 8)

			local toggle = { Value = opts.Default == true }

			local function render()
				tween(trackFill, { BackgroundTransparency = toggle.Value and 0 or 1 }, 0.2)
				tween(trackStroke, { Transparency = toggle.Value and 1 or 0 }, 0.2)
				tween(knob, {
					Position = toggle.Value and UDim2.new(1, -19, 0.5, -8) or UDim2.new(0, 3, 0.5, -8),
					BackgroundColor3 = toggle.Value and Color3.new(1, 1, 1) or Theme.Dim,
				}, 0.25, Enum.EasingStyle.Back)
			end

			function toggle:Set(value)
				value = value == true
				if value ~= toggle.Value then
					toggle.Value = value
					render()
					safeCall(opts.Callback, value)
				end
			end

			local click = clickOverlay(frame)
			hoverEffect(click, frame)
			click.MouseButton1Click:Connect(function()
				toggle:Set(not toggle.Value)
			end)

			render()
			if toggle.Value then
				safeCall(opts.Callback, true)
			end
			return finish(frame, toggle, opts)
		end

		function tab:AddSlider(opts)
			local min = opts.Min or 0
			local max = opts.Max or 100
			local step = opts.Step or 1
			local suffix = opts.Suffix or ""

			local frame, height = card(58, opts)
			local topH = height - 26
			cardTitle(frame, { Text = opts.Text, Description = opts.Description }, topH, 100)

			local chip = create("Frame", {
				BackgroundColor3 = Theme.Sunken,
				BorderSizePixel = 0,
				AnchorPoint = Vector2.new(1, 0),
				AutomaticSize = Enum.AutomaticSize.X,
				Size = UDim2.new(0, 0, 0, 20),
				Position = UDim2.new(1, -14, 0, math.floor(topH / 2) - 10),
				Parent = frame,
			})
			round(chip, 6)
			stroke(chip, Theme.Stroke)
			local valueLabel = label({
				Text = "",
				TextColor3 = Theme.Accent2,
				TextSize = 12,
				TextXAlignment = Enum.TextXAlignment.Center,
				AutomaticSize = Enum.AutomaticSize.X,
				Size = UDim2.new(0, 0, 1, 0),
				Parent = chip,
			})
			create("UIPadding", {
				PaddingLeft = UDim.new(0, 8),
				PaddingRight = UDim.new(0, 8),
				Parent = chip,
			})

			local hitbox = create("Frame", {
				BackgroundTransparency = 1,
				AnchorPoint = Vector2.new(0, 1),
				Size = UDim2.new(1, -28, 0, 18),
				Position = UDim2.new(0, 14, 1, -8),
				Parent = frame,
			})
			local bar = create("Frame", {
				BackgroundColor3 = Theme.Sunken,
				BorderSizePixel = 0,
				Size = UDim2.new(1, 0, 0, 4),
				Position = UDim2.new(0, 0, 0.5, -2),
				Parent = hitbox,
			})
			round(bar, 2)
			local fill = create("Frame", {
				BackgroundColor3 = Theme.Accent,
				BorderSizePixel = 0,
				Size = UDim2.new(0, 0, 1, 0),
				Parent = bar,
			})
			round(fill, 2)
			accentGradient(fill)
			local knob = create("Frame", {
				BackgroundColor3 = Color3.new(1, 1, 1),
				BorderSizePixel = 0,
				AnchorPoint = Vector2.new(0.5, 0.5),
				Size = UDim2.fromOffset(12, 12),
				Position = UDim2.new(0, 0, 0.5, 0),
				Parent = bar,
			})
			round(knob, 6)

			local slider = { Value = nil }

			local function render()
				local percent = (slider.Value - min) / (max - min)
				fill.Size = UDim2.new(percent, 0, 1, 0)
				knob.Position = UDim2.new(percent, 0, 0.5, 0)
				valueLabel.Text = tostring(slider.Value) .. suffix
			end

			function slider:Set(value)
				value = snap(value, min, max, step)
				if value ~= slider.Value then
					slider.Value = value
					render()
					safeCall(opts.Callback, value)
				end
			end

			bindDrag(hitbox, function(px)
				slider:Set(min + (max - min) * px)
			end)

			slider.Value = math.clamp(opts.Default or min, min, max)
			render()
			return finish(frame, slider, opts)
		end

		function tab:AddRangeSlider(opts)
			local min = opts.Min or 0
			local max = opts.Max or 100
			local step = opts.Step or 1
			local suffix = opts.Suffix or ""

			local frame, height = card(58, opts)
			local topH = height - 26
			cardTitle(frame, { Text = opts.Text, Description = opts.Description }, topH, 120)

			local chip = create("Frame", {
				BackgroundColor3 = Theme.Sunken,
				BorderSizePixel = 0,
				AnchorPoint = Vector2.new(1, 0),
				AutomaticSize = Enum.AutomaticSize.X,
				Size = UDim2.new(0, 0, 0, 20),
				Position = UDim2.new(1, -14, 0, math.floor(topH / 2) - 10),
				Parent = frame,
			})
			round(chip, 6)
			stroke(chip, Theme.Stroke)
			local valueLabel = label({
				Text = "",
				TextColor3 = Theme.Accent2,
				TextSize = 12,
				TextXAlignment = Enum.TextXAlignment.Center,
				AutomaticSize = Enum.AutomaticSize.X,
				Size = UDim2.new(0, 0, 1, 0),
				Parent = chip,
			})
			create("UIPadding", {
				PaddingLeft = UDim.new(0, 8),
				PaddingRight = UDim.new(0, 8),
				Parent = chip,
			})

			local hitbox = create("Frame", {
				BackgroundTransparency = 1,
				AnchorPoint = Vector2.new(0, 1),
				Size = UDim2.new(1, -28, 0, 18),
				Position = UDim2.new(0, 14, 1, -8),
				Parent = frame,
			})
			local bar = create("Frame", {
				BackgroundColor3 = Theme.Sunken,
				BorderSizePixel = 0,
				Size = UDim2.new(1, 0, 0, 4),
				Position = UDim2.new(0, 0, 0.5, -2),
				Parent = hitbox,
			})
			round(bar, 2)
			local fill = create("Frame", {
				BackgroundColor3 = Theme.Accent,
				BorderSizePixel = 0,
				Size = UDim2.new(0, 0, 1, 0),
				Parent = bar,
			})
			round(fill, 2)
			accentGradient(fill)
			local knobA = create("Frame", {
				BackgroundColor3 = Color3.new(1, 1, 1),
				BorderSizePixel = 0,
				AnchorPoint = Vector2.new(0.5, 0.5),
				Size = UDim2.fromOffset(12, 12),
				Position = UDim2.new(0, 0, 0.5, 0),
				Parent = bar,
			})
			round(knobA, 6)
			local knobB = knobA:Clone()
			knobB.Parent = bar

			local defaults = opts.Default or {}
			local range = {
				Min = math.clamp(defaults[1] or min, min, max),
				Max = math.clamp(defaults[2] or max, min, max),
			}

			local function render()
				local pa = (range.Min - min) / (max - min)
				local pb = (range.Max - min) / (max - min)
				knobA.Position = UDim2.new(pa, 0, 0.5, 0)
				knobB.Position = UDim2.new(pb, 0, 0.5, 0)
				fill.Position = UDim2.new(pa, 0, 0, 0)
				fill.Size = UDim2.new(pb - pa, 0, 1, 0)
				valueLabel.Text = tostring(range.Min) .. suffix .. " – " .. tostring(range.Max) .. suffix
			end

			function range:Set(newMin, newMax)
				newMin = snap(newMin or range.Min, min, max, step)
				newMax = snap(newMax or range.Max, min, max, step)
				if newMin > newMax then
					newMin, newMax = newMax, newMin
				end
				if newMin ~= range.Min or newMax ~= range.Max then
					range.Min, range.Max = newMin, newMax
					render()
					safeCall(opts.Callback, newMin, newMax)
				end
			end

			local activeKnob = nil
			bindDrag(hitbox, function(px, _, isFirst)
				if isFirst then
					local pa = (range.Min - min) / (max - min)
					local pb = (range.Max - min) / (max - min)
					activeKnob = (math.abs(px - pa) <= math.abs(px - pb)) and "min" or "max"
				end
				local raw = min + (max - min) * px
				if activeKnob == "min" then
					range:Set(math.min(raw, range.Max), range.Max)
				else
					range:Set(range.Min, math.max(raw, range.Min))
				end
			end)

			render()
			return finish(frame, range, opts)
		end

		function tab:AddStepper(opts)
			local min = opts.Min or 0
			local max = opts.Max or 100
			local step = opts.Step or 1
			local suffix = opts.Suffix or ""

			local frame, height = card(44, opts)
			cardTitle(frame, opts, height, 150)

			local control = sunkenControl(frame, 124, 26)

			local function stepButton(text, xScale)
				local btn = create("TextButton", {
					Text = text,
					Font = FONT_BOLD,
					TextSize = 14,
					TextColor3 = Theme.SubText,
					BackgroundTransparency = 1,
					Size = UDim2.new(0, 28, 1, 0),
					Position = UDim2.new(xScale, xScale == 1 and -28 or 0, 0, 0),
					Parent = control,
				})
				btn.MouseEnter:Connect(function()
					tween(btn, { TextColor3 = Theme.Accent2 })
				end)
				btn.MouseLeave:Connect(function()
					tween(btn, { TextColor3 = Theme.SubText })
				end)
				return btn
			end

			local minusBtn = stepButton("-", 0)
			local plusBtn = stepButton("+", 1)
			local valueLabel = label({
				Text = "",
				TextSize = 12,
				TextXAlignment = Enum.TextXAlignment.Center,
				Size = UDim2.new(1, -56, 1, 0),
				Position = UDim2.new(0, 28, 0, 0),
				Parent = control,
			})

			local stepper = { Value = snap(opts.Default or min, min, max, step) }

			local function render()
				valueLabel.Text = tostring(stepper.Value) .. suffix
			end

			function stepper:Set(value)
				value = snap(value, min, max, step)
				if value ~= stepper.Value then
					stepper.Value = value
					render()
					safeCall(opts.Callback, value)
				end
			end

			minusBtn.MouseButton1Click:Connect(function()
				stepper:Set(stepper.Value - step)
			end)
			plusBtn.MouseButton1Click:Connect(function()
				stepper:Set(stepper.Value + step)
			end)

			render()
			return finish(frame, stepper, opts)
		end

		function tab:AddSegmented(opts)
			local segOptions = opts.Options or {}
			local count = math.max(#segOptions, 1)

			local frame, height = card(44, opts)
			cardTitle(frame, opts, height, 200)

			local control = sunkenControl(frame, 180, 26)

			local highlight = create("Frame", {
				BackgroundColor3 = Theme.Accent,
				BorderSizePixel = 0,
				Size = UDim2.new(1 / count, -4, 1, -4),
				Position = UDim2.new(0, 2, 0, 2),
				Parent = control,
			})
			round(highlight, 5)
			accentGradient(highlight)

			local segmented = { Value = opts.Default or segOptions[1] }
			local buttons = {}

			local function render()
				for i, option in ipairs(segOptions) do
					local selected = (option == segmented.Value)
					tween(buttons[i], { TextColor3 = selected and Color3.new(1, 1, 1) or Theme.SubText })
					if selected then
						tween(highlight, { Position = UDim2.new((i - 1) / count, 2, 0, 2) }, 0.2)
					end
				end
			end

			function segmented:Set(option)
				if option ~= segmented.Value and table.find(segOptions, option) then
					segmented.Value = option
					render()
					safeCall(opts.Callback, option)
				end
			end

			for i, option in ipairs(segOptions) do
				local btn = create("TextButton", {
					Text = tostring(option),
					Font = FONT_MEDIUM,
					TextSize = 11,
					TextColor3 = Theme.SubText,
					TextTruncate = Enum.TextTruncate.AtEnd,
					BackgroundTransparency = 1,
					Size = UDim2.new(1 / count, 0, 1, 0),
					Position = UDim2.new((i - 1) / count, 0, 0, 0),
					ZIndex = 2,
					Parent = control,
				})
				btn.MouseButton1Click:Connect(function()
					segmented:Set(option)
				end)
				buttons[i] = btn
			end

			render()
			return finish(frame, segmented, opts)
		end

		function tab:AddProgress(opts)
			local min = opts.Min or 0
			local max = opts.Max or 100
			local suffix = opts.Suffix or ""

			local frame, height = card(58, opts)
			local topH = height - 26
			cardTitle(frame, { Text = opts.Text, Description = opts.Description }, topH, 100)

			local chip = create("Frame", {
				BackgroundColor3 = Theme.Sunken,
				BorderSizePixel = 0,
				AnchorPoint = Vector2.new(1, 0),
				AutomaticSize = Enum.AutomaticSize.X,
				Size = UDim2.new(0, 0, 0, 20),
				Position = UDim2.new(1, -14, 0, math.floor(topH / 2) - 10),
				Parent = frame,
			})
			round(chip, 6)
			stroke(chip, Theme.Stroke)
			local valueLabel = label({
				Text = "",
				TextColor3 = Theme.Accent2,
				TextSize = 12,
				TextXAlignment = Enum.TextXAlignment.Center,
				AutomaticSize = Enum.AutomaticSize.X,
				Size = UDim2.new(0, 0, 1, 0),
				Parent = chip,
			})
			create("UIPadding", {
				PaddingLeft = UDim.new(0, 8),
				PaddingRight = UDim.new(0, 8),
				Parent = chip,
			})

			local bar = create("Frame", {
				BackgroundColor3 = Theme.Sunken,
				BorderSizePixel = 0,
				AnchorPoint = Vector2.new(0, 1),
				Size = UDim2.new(1, -28, 0, 6),
				Position = UDim2.new(0, 14, 1, -12),
				Parent = frame,
			})
			round(bar, 3)
			local fill = create("Frame", {
				BackgroundColor3 = Theme.Accent,
				BorderSizePixel = 0,
				Size = UDim2.new(0, 0, 1, 0),
				Parent = bar,
			})
			round(fill, 3)
			accentGradient(fill)

			local progress = { Value = math.clamp(opts.Value or min, min, max) }
			local customText = nil

			local function render()
				local percent = (progress.Value - min) / (max - min)
				tween(fill, { Size = UDim2.new(percent, 0, 1, 0) }, 0.25)
				valueLabel.Text = customText or (tostring(progress.Value) .. suffix)
			end

			function progress:Set(value)
				progress.Value = math.clamp(value, min, max)
				render()
			end

			function progress:SetText(text)
				customText = text
				render()
			end

			render()
			return finish(frame, progress, opts)
		end

		function tab:AddVector3(opts)
			local frame, height = card(44, opts)
			cardTitle(frame, opts, height, 210)

			local default = opts.Default or Vector3.zero
			local vector = { Value = default }
			local boxes = {}

			local axes = { "X", "Y", "Z" }
			for i, axis in ipairs(axes) do
				local box = create("TextBox", {
					Text = tostring(default[axis]),
					PlaceholderText = axis,
					PlaceholderColor3 = Theme.Dim,
					Font = FONT_MEDIUM,
					TextSize = 12,
					TextColor3 = Theme.Text,
					BackgroundColor3 = Theme.Sunken,
					BorderSizePixel = 0,
					ClearTextOnFocus = false,
					AnchorPoint = Vector2.new(1, 0.5),
					Size = UDim2.fromOffset(58, 26),
					Position = UDim2.new(1, -14 - (3 - i) * 62, 0.5, 0),
					Parent = frame,
				})
				round(box, 6)
				local boxStroke = stroke(box, Theme.Stroke)
				box.Focused:Connect(function()
					tween(boxStroke, { Color = Theme.Accent })
				end)
				boxes[axis] = box

				box.FocusLost:Connect(function()
					tween(boxStroke, { Color = Theme.Stroke })
					local x = tonumber(boxes.X.Text) or vector.Value.X
					local y = tonumber(boxes.Y.Text) or vector.Value.Y
					local z = tonumber(boxes.Z.Text) or vector.Value.Z
					local newValue = Vector3.new(x, y, z)
					boxes.X.Text = tostring(x)
					boxes.Y.Text = tostring(y)
					boxes.Z.Text = tostring(z)
					if newValue ~= vector.Value then
						vector.Value = newValue
						safeCall(opts.Callback, newValue)
					end
				end)
			end

			function vector:Set(v3)
				vector.Value = v3
				boxes.X.Text = tostring(v3.X)
				boxes.Y.Text = tostring(v3.Y)
				boxes.Z.Text = tostring(v3.Z)
				safeCall(opts.Callback, v3)
			end

			return finish(frame, vector, opts)
		end

		function tab:AddTree(opts)
			local frame = card(8, nil, true)
			create("UIPadding", {
				PaddingTop = UDim.new(0, 8),
				PaddingBottom = UDim.new(0, 8),
				PaddingLeft = UDim.new(0, 8),
				PaddingRight = UDim.new(0, 8),
				Parent = frame,
			})

			if opts.Text then
				label({
					Text = opts.Text,
					Font = FONT_BOLD,
					TextSize = 13,
					Size = UDim2.new(1, -12, 0, 22),
					Position = UDim2.new(0, 6, 0, 0),
					Parent = frame,
				})
			end

			local rootHolder = create("Frame", {
				BackgroundTransparency = 1,
				Size = UDim2.new(1, 0, 0, 0),
				AutomaticSize = Enum.AutomaticSize.Y,
				Position = UDim2.new(0, 0, 0, opts.Text and 24 or 0),
				Parent = frame,
			})
			create("UIListLayout", {
				Padding = UDim.new(0, 1),
				SortOrder = Enum.SortOrder.LayoutOrder,
				Parent = rootHolder,
			})

			local function buildNodes(items, parent, depth)
				for i, node in ipairs(items) do
					local hasChildren = node.Children and #node.Children > 0

					local row = create("TextButton", {
						Text = "",
						BackgroundColor3 = Theme.SurfaceHover,
						BackgroundTransparency = 1,
						BorderSizePixel = 0,
						Size = UDim2.new(1, 0, 0, 26),
						LayoutOrder = i * 2,
						Parent = parent,
					})
					round(row, 6)

					local chevron = nil
					if hasChildren then
						chevron = label({
							Text = "›",
							Font = FONT_BOLD,
							TextColor3 = Theme.Dim,
							TextSize = 13,
							TextXAlignment = Enum.TextXAlignment.Center,
							Size = UDim2.fromOffset(14, 14),
							Position = UDim2.new(0, 6 + depth * 14, 0.5, -7),
							Parent = row,
						})
					end
					label({
						Text = node.Text or "?",
						Font = FONT_MEDIUM,
						TextSize = 12,
						TextColor3 = hasChildren and Theme.Text or Theme.SubText,
						Size = UDim2.new(1, -(28 + depth * 14), 1, 0),
						Position = UDim2.new(0, 24 + depth * 14, 0, 0),
						TextTruncate = Enum.TextTruncate.AtEnd,
						Parent = row,
					})

					local childHolder = nil
					if hasChildren then
						childHolder = create("Frame", {
							BackgroundTransparency = 1,
							Size = UDim2.new(1, 0, 0, 0),
							AutomaticSize = Enum.AutomaticSize.Y,
							Visible = node.Open == true,
							LayoutOrder = i * 2 + 1,
							Parent = parent,
						})
						create("UIListLayout", {
							Padding = UDim.new(0, 1),
							SortOrder = Enum.SortOrder.LayoutOrder,
							Parent = childHolder,
						})
						if node.Open == true and chevron then
							chevron.Rotation = 90
						end
						buildNodes(node.Children, childHolder, depth + 1)
					end

					row.MouseEnter:Connect(function()
						tween(row, { BackgroundTransparency = 0.5 })
					end)
					row.MouseLeave:Connect(function()
						tween(row, { BackgroundTransparency = 1 })
					end)
					row.MouseButton1Click:Connect(function()
						if childHolder then
							childHolder.Visible = not childHolder.Visible
							tween(chevron, { Rotation = childHolder.Visible and 90 or 0 })
						end
						safeCall(node.Callback or opts.Callback, node)
					end)
				end
			end

			local tree = {}

			function tree:Refresh(items)
				for _, child in ipairs(rootHolder:GetChildren()) do
					if not child:IsA("UIListLayout") then
						child:Destroy()
					end
				end
				buildNodes(items or {}, rootHolder, 0)
			end

			tree:Refresh(opts.Items or {})
			return finish(frame, tree, opts)
		end

		function tab:AddDropdown(opts)
			local multi = opts.Multi == true

			local frame, height = card(44, opts, true)
			create("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder, Parent = frame })

			local header = create("Frame", {
				BackgroundTransparency = 1,
				Size = UDim2.new(1, 0, 0, height),
				LayoutOrder = 1,
				Parent = frame,
			})
			cardTitle(header, opts, height, 200)

			local control, controlStroke = sunkenControl(header, 170, 26)
			local valueLabel = label({
				Text = "",
				TextColor3 = Theme.SubText,
				TextSize = 12,
				Size = UDim2.new(1, -34, 1, 0),
				Position = UDim2.new(0, 10, 0, 0),
				TextTruncate = Enum.TextTruncate.AtEnd,
				Parent = control,
			})
			local chevron = label({
				Text = "›",
				Rotation = 90,
				TextColor3 = Theme.Dim,
				TextSize = 12,
				TextXAlignment = Enum.TextXAlignment.Center,
				AnchorPoint = Vector2.new(1, 0.5),
				Size = UDim2.fromOffset(18, 18),
				Position = UDim2.new(1, -4, 0.5, 0),
				Parent = control,
			})

			local holder = create("Frame", {
				BackgroundTransparency = 1,
				Size = UDim2.new(1, 0, 0, 0),
				AutomaticSize = Enum.AutomaticSize.Y,
				Visible = false,
				LayoutOrder = 2,
				Parent = frame,
			})
			create("UIPadding", {
				PaddingLeft = UDim.new(0, 12),
				PaddingRight = UDim.new(0, 12),
				PaddingBottom = UDim.new(0, 12),
				Parent = holder,
			})
			local optionsBox = create("ScrollingFrame", {
				BackgroundColor3 = Theme.Sunken,
				BorderSizePixel = 0,
				Size = UDim2.new(1, 0, 0, 0),
				CanvasSize = UDim2.new(),
				AutomaticCanvasSize = Enum.AutomaticSize.Y,
				ScrollBarThickness = 3,
				ScrollBarImageColor3 = Theme.StrokeLight,
				Parent = holder,
			})
			round(optionsBox, 8)
			stroke(optionsBox, Theme.Stroke)
			create("UIListLayout", {
				Padding = UDim.new(0, 2),
				SortOrder = Enum.SortOrder.LayoutOrder,
				Parent = optionsBox,
			})
			create("UIPadding", {
				PaddingTop = UDim.new(0, 5),
				PaddingBottom = UDim.new(0, 5),
				PaddingLeft = UDim.new(0, 5),
				PaddingRight = UDim.new(0, 5),
				Parent = optionsBox,
			})

			local dropdown = {
				Value = multi and (opts.Default or {}) or opts.Default,
				Options = opts.Options or {},
			}
			local open = false
			local optionRows = {}

			local function isSelected(option)
				if multi then
					return table.find(dropdown.Value, option) ~= nil
				end
				return dropdown.Value == option
			end

			local function renderSelection()
				if multi then
					valueLabel.Text = #dropdown.Value > 0 and table.concat(dropdown.Value, ", ") or "None"
					valueLabel.TextColor3 = #dropdown.Value > 0 and Theme.Text or Theme.SubText
				else
					valueLabel.Text = dropdown.Value ~= nil and tostring(dropdown.Value) or "None"
					valueLabel.TextColor3 = dropdown.Value ~= nil and Theme.Text or Theme.SubText
				end
				for option, row in pairs(optionRows) do
					local selected = isSelected(option)
					row.button.TextColor3 = selected and Theme.Text or Theme.SubText
					row.check.Visible = selected
				end
			end

			local function setOpen(value)
				open = value
				holder.Visible = open
				tween(chevron, { Rotation = open and 270 or 90 })
				tween(controlStroke, { Color = open and Theme.Accent or Theme.Stroke })
			end

			local function fireCallback()
				if multi then
					safeCall(opts.Callback, table.clone(dropdown.Value))
				else
					safeCall(opts.Callback, dropdown.Value)
				end
			end

			function dropdown:Set(value)
				if multi then
					dropdown.Value = value or {}
				else
					if value == dropdown.Value then
						return
					end
					dropdown.Value = value
				end
				renderSelection()
				fireCallback()
			end

			local function onOptionClicked(option)
				if multi then
					local index = table.find(dropdown.Value, option)
					if index then
						table.remove(dropdown.Value, index)
					else
						table.insert(dropdown.Value, option)
					end
					renderSelection()
					fireCallback()
				else
					if dropdown.Value ~= option then
						dropdown.Value = option
						renderSelection()
						fireCallback()
					end
					setOpen(false)
				end
			end

			function dropdown:Refresh(newOptions, keepValue)
				dropdown.Options = newOptions
				for _, row in pairs(optionRows) do
					row.button:Destroy()
				end
				table.clear(optionRows)
				for i, option in ipairs(newOptions) do
					local btn = create("TextButton", {
						Text = tostring(option),
						Font = FONT_MEDIUM,
						TextSize = 12,
						TextColor3 = Theme.SubText,
						TextXAlignment = Enum.TextXAlignment.Left,
						BackgroundColor3 = Theme.Surface,
						BackgroundTransparency = 1,
						BorderSizePixel = 0,
						Size = UDim2.new(1, 0, 0, 26),
						LayoutOrder = i,
						Parent = optionsBox,
					})
					round(btn, 6)
					create("UIPadding", { PaddingLeft = UDim.new(0, 10), Parent = btn })
					local check = create("Frame", {
						BackgroundColor3 = Theme.Accent2,
						BorderSizePixel = 0,
						AnchorPoint = Vector2.new(1, 0.5),
						Size = UDim2.fromOffset(6, 6),
						Position = UDim2.new(1, -12, 0.5, 0),
						Visible = false,
						Parent = btn,
					})
					round(check, 3)
					btn.MouseEnter:Connect(function()
						tween(btn, { BackgroundTransparency = 0.4 })
					end)
					btn.MouseLeave:Connect(function()
						tween(btn, { BackgroundTransparency = 1 })
					end)
					btn.MouseButton1Click:Connect(function()
						onOptionClicked(option)
					end)
					optionRows[option] = { button = btn, check = check }
				end
				optionsBox.Size = UDim2.new(1, 0, 0, math.min(#newOptions * 28 + 10, 150))
				if not keepValue then
					dropdown.Value = multi and {} or nil
				end
				renderSelection()
			end

			local click = clickOverlay(header)
			hoverEffect(click, frame)
			click.MouseButton1Click:Connect(function()
				setOpen(not open)
			end)

			dropdown:Refresh(dropdown.Options, true)
			return finish(frame, dropdown, opts)
		end

		function tab:AddPlayerDropdown(opts)
			opts = opts or {}
			local multi = opts.Multi == true

			local function playerNames()
				local list = {}
				for _, p in ipairs(Players:GetPlayers()) do
					if not (opts.ExcludeSelf and p == LocalPlayer) then
						table.insert(list, p.Name)
					end
				end
				table.sort(list)
				return list
			end

			opts.Options = playerNames()
			local dropdown = tab:AddDropdown(opts)

			local function refresh()
				local list = playerNames()
				dropdown:Refresh(list, true)
				if multi then
					local filtered = {}
					for _, name in ipairs(dropdown.Value) do
						if table.find(list, name) then
							table.insert(filtered, name)
						end
					end
					if #filtered ~= #dropdown.Value then
						dropdown:Set(filtered)
					end
				else
					if dropdown.Value ~= nil and not table.find(list, dropdown.Value) then
						dropdown:Set(nil)
					end
				end
			end

			table.insert(connections, Players.PlayerAdded:Connect(function()
				task.defer(refresh)
			end))
			table.insert(connections, Players.PlayerRemoving:Connect(function()
				task.defer(refresh)
			end))

			function dropdown:GetPlayer()
				return dropdown.Value and Players:FindFirstChild(dropdown.Value) or nil
			end

			function dropdown:GetPlayers()
				local out = {}
				for _, name in ipairs(multi and dropdown.Value or { dropdown.Value }) do
					local p = name and Players:FindFirstChild(name)
					if p then
						table.insert(out, p)
					end
				end
				return out
			end

			return dropdown
		end

		function tab:AddKeybind(opts)
			local frame, height = card(44, opts)
			cardTitle(frame, opts, height, 120)

			local keyButton = create("TextButton", {
				Text = "",
				Font = FONT_MEDIUM,
				TextSize = 12,
				TextColor3 = Theme.SubText,
				BackgroundColor3 = Theme.Sunken,
				BorderSizePixel = 0,
				AutomaticSize = Enum.AutomaticSize.X,
				Size = UDim2.new(0, 0, 0, 24),
				AnchorPoint = Vector2.new(1, 0.5),
				Position = UDim2.new(1, -14, 0.5, 0),
				Parent = frame,
			})
			round(keyButton, 6)
			local keyStroke = stroke(keyButton, Theme.Stroke)
			create("UIPadding", {
				PaddingLeft = UDim.new(0, 10),
				PaddingRight = UDim.new(0, 10),
				Parent = keyButton,
			})

			local keybind = { Key = opts.Default }
			local binding = false

			local function render()
				keyButton.Text = binding and "..." or (keybind.Key and keybind.Key.Name or "None")
				tween(keyStroke, { Color = binding and Theme.Accent or Theme.Stroke })
			end

			function keybind:Set(keyCode)
				keybind.Key = keyCode
				render()
				window._refreshKeybindHUD()
				safeCall(opts.OnChanged, keyCode)
			end

			keyButton.MouseButton1Click:Connect(function()
				if binding then
					return
				end
				binding = true
				render()
				local conn
				conn = UserInputService.InputBegan:Connect(function(input)
					if input.UserInputType == Enum.UserInputType.Keyboard then
						conn:Disconnect()
						binding = false
						if input.KeyCode == Enum.KeyCode.Escape then
							render()
						else
							keybind:Set(input.KeyCode)
						end
					end
				end)
			end)

			table.insert(connections, UserInputService.InputBegan:Connect(function(input, gameProcessed)
				if gameProcessed or binding then
					return
				end
				if keybind.Key and input.KeyCode == keybind.Key then
					safeCall(opts.Callback, keybind.Key)
				end
			end))

			table.insert(window._keybinds, {
				label = opts.Text or "Keybind",
				get = function()
					return keybind.Key
				end,
			})
			window._refreshKeybindHUD()

			render()
			return finish(frame, keybind, opts)
		end

		function tab:AddTextbox(opts)
			local frame, height = card(44, opts)
			cardTitle(frame, opts, height, 200)

			local box = create("TextBox", {
				Text = opts.Default or "",
				PlaceholderText = opts.Placeholder or "...",
				PlaceholderColor3 = Theme.Dim,
				Font = FONT_MEDIUM,
				TextSize = 12,
				TextColor3 = Theme.Text,
				TextXAlignment = Enum.TextXAlignment.Left,
				BackgroundColor3 = Theme.Sunken,
				BorderSizePixel = 0,
				ClearTextOnFocus = opts.ClearOnFocus == true,
				Size = UDim2.fromOffset(170, 26),
				AnchorPoint = Vector2.new(1, 0.5),
				Position = UDim2.new(1, -14, 0.5, 0),
				Parent = frame,
			})
			round(box, 6)
			local boxStroke = stroke(box, Theme.Stroke)
			create("UIPadding", {
				PaddingLeft = UDim.new(0, 10),
				PaddingRight = UDim.new(0, 10),
				Parent = box,
			})

			box.Focused:Connect(function()
				tween(boxStroke, { Color = Theme.Accent })
			end)
			box.FocusLost:Connect(function(enterPressed)
				tween(boxStroke, { Color = Theme.Stroke })
				safeCall(opts.Callback, box.Text, enterPressed)
			end)

			local obj = {
				Set = function(_, text)
					box.Text = text
				end,
				GetValue = function()
					return box.Text
				end,
			}
			return finish(frame, obj, opts)
		end

		function tab:AddColorPicker(opts)
			local frame, height = card(44, opts, true)
			create("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder, Parent = frame })

			local header = create("Frame", {
				BackgroundTransparency = 1,
				Size = UDim2.new(1, 0, 0, height),
				LayoutOrder = 1,
				Parent = frame,
			})
			cardTitle(header, opts, height, 70)

			local swatch = create("Frame", {
				BackgroundColor3 = opts.Default or Theme.Accent,
				BorderSizePixel = 0,
				AnchorPoint = Vector2.new(1, 0.5),
				Size = UDim2.fromOffset(34, 22),
				Position = UDim2.new(1, -14, 0.5, 0),
				Parent = header,
			})
			round(swatch, 6)
			stroke(swatch, Theme.StrokeLight)

			local panel = create("Frame", {
				BackgroundTransparency = 1,
				Size = UDim2.new(1, 0, 0, 158),
				Visible = false,
				LayoutOrder = 2,
				Parent = frame,
			})

			-- saturation/value box
			local svBox = create("Frame", {
				BackgroundColor3 = Color3.fromHSV(0, 1, 1),
				BorderSizePixel = 0,
				Size = UDim2.new(1, -58, 0, 118),
				Position = UDim2.new(0, 14, 0, 0),
				Parent = panel,
			})
			round(svBox, 8)
			stroke(svBox, Theme.Stroke)
			local whiteOverlay = create("Frame", {
				BackgroundColor3 = Color3.new(1, 1, 1),
				BorderSizePixel = 0,
				Size = UDim2.fromScale(1, 1),
				Parent = svBox,
			})
			round(whiteOverlay, 8)
			create("UIGradient", {
				Transparency = NumberSequence.new({
					NumberSequenceKeypoint.new(0, 0),
					NumberSequenceKeypoint.new(1, 1),
				}),
				Parent = whiteOverlay,
			})
			local blackOverlay = create("Frame", {
				BackgroundColor3 = Color3.new(0, 0, 0),
				BorderSizePixel = 0,
				Size = UDim2.fromScale(1, 1),
				Parent = svBox,
			})
			round(blackOverlay, 8)
			create("UIGradient", {
				Rotation = 90,
				Transparency = NumberSequence.new({
					NumberSequenceKeypoint.new(0, 1),
					NumberSequenceKeypoint.new(1, 0),
				}),
				Parent = blackOverlay,
			})
			local svCursor = create("Frame", {
				BackgroundTransparency = 1,
				AnchorPoint = Vector2.new(0.5, 0.5),
				Size = UDim2.fromOffset(12, 12),
				Parent = svBox,
			})
			round(svCursor, 6)
			local svCursorStroke = stroke(svCursor, Color3.new(1, 1, 1), 0)
			svCursorStroke.Thickness = 2

			-- hue bar
			local hueBar = create("Frame", {
				BorderSizePixel = 0,
				AnchorPoint = Vector2.new(1, 0),
				Size = UDim2.new(0, 18, 0, 118),
				Position = UDim2.new(1, -14, 0, 0),
				Parent = panel,
			})
			round(hueBar, 8)
			local hueKeypoints = {}
			for i = 0, 6 do
				table.insert(hueKeypoints, ColorSequenceKeypoint.new(i / 6, Color3.fromHSV(i / 6, 1, 1)))
			end
			create("UIGradient", {
				Rotation = 90,
				Color = ColorSequence.new(hueKeypoints),
				Parent = hueBar,
			})
			local hueCursor = create("Frame", {
				BackgroundColor3 = Color3.new(1, 1, 1),
				BorderSizePixel = 0,
				AnchorPoint = Vector2.new(0.5, 0.5),
				Size = UDim2.new(1, 4, 0, 4),
				Position = UDim2.new(0.5, 0, 0, 0),
				Parent = hueBar,
			})
			round(hueCursor, 2)

			local hexLabel = label({
				Text = "#FFFFFF",
				Font = Enum.Font.Code,
				TextColor3 = Theme.Dim,
				TextSize = 12,
				Size = UDim2.new(1, -28, 0, 20),
				Position = UDim2.new(0, 14, 0, 126),
				Parent = panel,
			})

			local h, s, v = (opts.Default or Theme.Accent):ToHSV()
			local picker = { Value = opts.Default or Theme.Accent }
			local open = false

			local function render(fireCallback)
				picker.Value = Color3.fromHSV(h, s, v)
				swatch.BackgroundColor3 = picker.Value
				svBox.BackgroundColor3 = Color3.fromHSV(h, 1, 1)
				svCursor.Position = UDim2.new(s, 0, 1 - v, 0)
				hueCursor.Position = UDim2.new(0.5, 0, h, 0)
				hexLabel.Text = "#" .. picker.Value:ToHex():upper()
				if fireCallback then
					safeCall(opts.Callback, picker.Value)
				end
			end

			function picker:Set(color)
				h, s, v = color:ToHSV()
				render(true)
			end

			bindDrag(svBox, function(px, py)
				s = px
				v = 1 - py
				render(true)
			end)
			bindDrag(hueBar, function(_, py)
				h = math.clamp(py, 0, 0.9999)
				render(true)
			end)

			local click = clickOverlay(header)
			hoverEffect(click, frame)
			click.MouseButton1Click:Connect(function()
				open = not open
				panel.Visible = open
			end)

			render(false)
			return finish(frame, picker, opts)
		end

		return tab
	end

	local function registerTab(tab)
		table.insert(window.Tabs, tab)
		tab.Button.MouseButton1Click:Connect(function()
			window:SelectTab(tab)
		end)
		if #window.Tabs == 1 then
			window:SelectTab(tab)
		end
	end

	function window:AddTab(name)
		local tab = buildTab(name, tabList)
		registerTab(tab)
		return tab
	end

	function window:AddGroup(name, opts)
		opts = opts or {}

		if not useSidebar then
			return {
				AddTab = function(_, tabName)
					return window:AddTab(tabName)
				end,
				SetOpen = function() end,
			}
		end

		local headerBtn = create("TextButton", {
			Text = "",
			BackgroundTransparency = 1,
			Size = UDim2.new(1, 0, 0, 28),
			Parent = tabList,
		})
		local chevron = label({
			Text = "›",
			Font = FONT_BOLD,
			TextColor3 = Theme.Dim,
			TextSize = 12,
			TextXAlignment = Enum.TextXAlignment.Center,
			Size = UDim2.fromOffset(14, 14),
			Position = UDim2.new(0, 2, 0.5, -7),
			Parent = headerBtn,
		})
		label({
			Text = string.upper(name),
			Font = FONT_BOLD,
			TextColor3 = Theme.Dim,
			TextSize = 11,
			Size = UDim2.new(1, -22, 1, 0),
			Position = UDim2.new(0, 20, 0, 0),
			Parent = headerBtn,
		})

		local container = create("Frame", {
			BackgroundTransparency = 1,
			Size = UDim2.new(1, 0, 0, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			Visible = opts.Open ~= false,
			Parent = tabList,
		})
		create("UIListLayout", {
			Padding = UDim.new(0, 4),
			SortOrder = Enum.SortOrder.LayoutOrder,
			Parent = container,
		})
		create("UIPadding", { PaddingLeft = UDim.new(0, 8), Parent = container })

		local group = { Name = name, Open = opts.Open ~= false }

		local function renderOpen()
			container.Visible = group.Open
			tween(chevron, { Rotation = group.Open and 90 or 0 })
		end

		function group:SetOpen(value)
			group.Open = value == true
			renderOpen()
		end

		function group:AddTab(tabName)
			local tab = buildTab(tabName, container)
			registerTab(tab)
			return tab
		end

		headerBtn.MouseButton1Click:Connect(function()
			group:SetOpen(not group.Open)
		end)
		headerBtn.MouseEnter:Connect(function()
			tween(chevron, { TextColor3 = Theme.Text })
		end)
		headerBtn.MouseLeave:Connect(function()
			tween(chevron, { TextColor3 = Theme.Dim })
		end)

		renderOpen()
		return group
	end

	if options.KeybindHUD then
		window:SetKeybindHUD(true)
	end

	animateIn()
	return window
end

function UILib:LoadScripts(window, scripts)
	local defs = {}

	local function collect(item)
		if typeof(item) == "Instance" then
			if item:IsA("ModuleScript") then
				local ok, def = pcall(require, item)
				if ok and type(def) == "table" then
					table.insert(defs, def)
				else
					warn("[UILib] failed to require script module: " .. item:GetFullName())
				end
			elseif item:IsA("Folder") then
				for _, child in ipairs(item:GetChildren()) do
					collect(child)
				end
			end
		elseif type(item) == "table" then
			table.insert(defs, item)
		end
	end

	if typeof(scripts) == "Instance" then
		collect(scripts)
	else
		for _, item in ipairs(scripts or {}) do
			collect(item)
		end
	end

	local function matches(def)
		if def.Universal == true then
			return true
		end
		for _, id in ipairs(def.Games or {}) do
			if id == game.PlaceId or id == game.GameId then
				return true
			end
		end
		return false
	end

	local loaded = {}
	local function runDef(def)
		local target = window
		if not def.NoGroup then
			target = window:AddGroup(def.Name or "Script")
		end
		local ok, err = pcall(def.Init, target, window, UILib)
		if ok then
			table.insert(loaded, def.Name or "Script")
		else
			warn("[UILib] script '" .. tostring(def.Name) .. "' failed to load: " .. tostring(err))
		end
	end

	for _, def in ipairs(defs) do
		if def.Universal == true and def.Init then
			runDef(def)
		end
	end
	for _, def in ipairs(defs) do
		if def.Universal ~= true and def.Init and matches(def) then
			runDef(def)
		end
	end

	return loaded
end

return UILib
