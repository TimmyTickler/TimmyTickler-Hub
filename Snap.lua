local Players     = game:GetService("Players")
local RS          = game:GetService("ReplicatedStorage")
local Workspace   = game:GetService("Workspace")
local UIS         = game:GetService("UserInputService")
local RunService  = game:GetService("RunService")
local player      = Players.LocalPlayer or Players.PlayerAdded:Wait()
local genv        = (rawget(_G, "getgenv") and getgenv()) or _G
local UILIB_URL = "https://raw.githubusercontent.com/TimmyTickler/TimmyTickler-Hub/refs/heads/main/Core.lua"
local function loadUILib()
	local ok, src = pcall(game.HttpGet, game, UILIB_URL)
	if not ok or type(src) ~= "string" or #src == 0 then
		error("Snap Shot: could not fetch UILib from " .. UILIB_URL .. " (" .. tostring(src) .. ")")
	end
	local fn, err = loadstring(src, "@UILib")
	if not fn then error("Snap Shot: UILib compile error: " .. tostring(err)) end
	return fn()
end
local UILib = loadUILib()
local window = UILib:CreateWindow({
	Title = "Snap Shot", SubTitle = "standalone",
	ToggleKey = Enum.KeyCode.RightShift, Size = Vector2.new(560, 430),
})
local tab = window:AddTab("Snap Shot")
local function notify(msg) window:Notify({ Title = "Snap Shot", Text = tostring(msg) }) end
local breakWhile = {}
breakWhile[63] = true
local snapShotTargetName   = ""
local snapShotDistance     = 10
local snapShotKey          = Enum.KeyCode.G
local snapShotAuto         = false
local snapShotAimOffsetDeg = 90
local snapShotFireWait     = 12
local snapShotAll
local snapToggleEl
local uiToggles = {}
uiToggles["SnapShot"] = {
	setState = function(v) if snapToggleEl then snapToggleEl:Set(v) end end,
	getState = function() return snapToggleEl and snapToggleEl.Value or false end,
}
local installInventoryHook
local teleportTank
installInventoryHook = function()
	if not genv.__tommyLastFireArgs then
		local t = table.pack(0, CFrame.new(), {})
		t.n = 3
		genv.__tommyLastFireArgs = t
	end
	return true
end
pcall(installInventoryHook)
local function findTank(name)
	local Tanks = Workspace:FindFirstChild("Tanks")
	if not Tanks then return nil end
	return Tanks:FindFirstChild("Tank-" .. name)
end
local R = {}
R.cheatLabels = {}
R.snapMoveMethod = "Fast Step (Basically makes it look jittery)"
function R.isTankModel(t)
	return t:IsA("Model")
		and t:FindFirstChild("Base") ~= nil
		and (t.Name:match("^Tank%-") ~= nil or t.Name:match("^MatchBot") ~= nil)
end
function R.isBotTank(tank)
	return tank ~= nil and tank.Name:match("^MatchBot") ~= nil
end
function R.tankLabel(tank)
	if not tank then return "?" end
	return (tank.Name:gsub("^Tank%-", ""):gsub("^MatchBot%s+", ""))
end
function R.allTanks()
	local out = {}
	local Tanks = Workspace:FindFirstChild("Tanks")
	if not Tanks then return out end
	for _, t in ipairs(Tanks:GetChildren()) do
		if R.isTankModel(t) then out[#out + 1] = t end
	end
	return out
end
function R.tankTeamColor(tank)
	local s = tank and tank:FindFirstChild("Settings")
	local tc = s and s:FindFirstChild("TeamColor")
	return tc and tc.Value or nil
end
function R.tankByModelName(name)
	local Tanks = Workspace:FindFirstChild("Tanks")
	if not (Tanks and name) then return nil end
	return Tanks:FindFirstChild(name)
end
function R.getMyTank()
	return findTank(player.Name)
end
function R.myTeamColor()
	return R.tankTeamColor(R.getMyTank()) or player.TeamColor
end
function R.isEnemyTank(tank, mineTC)
	if not tank then return false end
	if tank.Name == "Tank-" .. player.Name then return false end
	mineTC = mineTC or R.myTeamColor()
	local tc = R.tankTeamColor(tank)
	if not tc or not mineTC then return true end
	return tc ~= mineTC
end
function R.enemyTanks()
	local mine = R.myTeamColor()
	local out = {}
	for _, t in ipairs(R.allTanks()) do
		if R.isEnemyTank(t, mine) then out[#out + 1] = t end
	end
	return out
end
function R.tankBasePos(tank)
	local b = tank and tank:FindFirstChild("Base")
	if b and b:IsA("BasePart") then return b.Position end
	return nil
end
function R.nearestEnemyTank(fromPos)
	local best, bestD
	for _, t in ipairs(R.enemyTanks()) do
		local p = R.tankBasePos(t)
		if p then
			local d = (p - fromPos).Magnitude
			if not bestD or d < bestD then best, bestD = t, d end
		end
	end
	return best, bestD
end
function R.bulletTeamColor(s)
	if not s then return nil end
	local tc = s:FindFirstChild("TeamColor")
	if tc and tc.Value then return tc.Value end
	local src = s:FindFirstChild("Source")
	if src and src.Value and typeof(src.Value) == "Instance" then
		local m = src.Value:IsA("Model") and src.Value
			or src.Value:FindFirstAncestorWhichIsA("Model")
		local t = m and R.tankTeamColor(m)
		if t then return t end
	end
	local cv = s:FindFirstChild("Creator")
	if cv and cv.Value and typeof(cv.Value) == "Instance"
		and cv.Value:IsA("Player") then
		return cv.Value.TeamColor
	end
	return nil
end
function R.isEnemyBullet(s, mineTC)
	if not s then return false end
	local cv = s:FindFirstChild("Creator")
	if cv and cv.Value == player then return false end
	local src = s:FindFirstChild("Source")
	if src and src.Value and src.Value == R.getMyTank() then return false end
	local tc = R.bulletTeamColor(s)
	mineTC = mineTC or R.myTeamColor()
	if not tc or not mineTC then return false end
	return tc ~= mineTC
end
function R.findTankByLabel(query)
	if type(query) ~= "string" then return nil end
	query = query:match("^%s*(.-)%s*$")
	if query == "" then return nil end
	if query:lower() == "me" then return R.getMyTank() end
	local q = query:lower()
	local tanks = R.allTanks()
	for _, t in ipairs(tanks) do
		if t.Name:lower() == q or R.tankLabel(t):lower() == q then return t end
	end
	for _, t in ipairs(tanks) do
		if R.tankLabel(t):lower():sub(1, #q) == q then return t end
	end
	return nil
end
teleportTank = function(Tank, pos)
	local base = Tank:FindFirstChild("Base")
	if base then
		local cur = base.CFrame
		base.CFrame = CFrame.new(pos) * (cur - cur.Position)
	end
	local s = Tank:FindFirstChild("Settings")
	if s then
		local posVal = s:FindFirstChild("Position")
		if posVal and posVal:IsA("Vector3Value") then posVal.Value = pos end
		if base then
			local lcf = s:FindFirstChild("LocalCFrame")
			if lcf and lcf:IsA("CFrameValue") then lcf.Value = base.CFrame end
			local rcf = s:FindFirstChild("ReplicatedBaseCFrame")
			if rcf and rcf:IsA("CFrameValue") then rcf.Value = base.CFrame end
		end
	end
end
local function loopSnapShot()
	if installInventoryHook == nil or not installInventoryHook() then
		notify("Snap Shot: namecall hook unavailable")
		breakWhile[63] = true
		if uiToggles["SnapShot"] then uiToggles["SnapShot"].setState(false) end
		return
	end
	local fb = RS:FindFirstChild("Remotes") and RS.Remotes:FindFirstChild("FireBullet")
	if not fb then
		notify("Snap Shot: FireBullet remote missing")
		breakWhile[63] = true
		if uiToggles["SnapShot"] then uiToggles["SnapShot"].setState(false) end
		return
	end
	notify("Snap Shot armed — press " .. snapShotKey.Name
		.. " to snap behind target. Fire once first to capture args.")
	local function reaimCFrame(capturedCF, newOrigin, aimPos)
		local f = capturedCF.LookVector
		f = Vector3.new(f.X, 0, f.Z)
		local d = aimPos - newOrigin
		d = Vector3.new(d.X, 0, d.Z)
		local rotOnly = capturedCF - capturedCF.Position
		if f.Magnitude < 1e-4 or d.Magnitude < 1e-4 then
			return CFrame.new(newOrigin) * rotOnly
		end
		f = f.Unit; d = d.Unit
		local yaw = math.atan2(f:Cross(d).Y, f:Dot(d))
			+ math.rad(snapShotAimOffsetDeg)
		local rot = CFrame.fromAxisAngle(Vector3.new(0, 1, 0), yaw)
		return CFrame.new(newOrigin) * (rot * rotOnly)
	end
	local function snapRetarget(template, originPos, aimPos)
		local v3Total = 0
		for i = 1, template.n do
			if typeof(template[i]) == "Vector3" then v3Total = v3Total + 1 end
		end
		local out = table.pack(); out.n = template.n
		local v3Seen = 0
		for i = 1, template.n do
			local v = template[i]
			if typeof(v) == "Vector3" then
				v3Seen = v3Seen + 1
				if v3Total >= 2 and v3Seen == 1 then
					out[i] = originPos
				else
					out[i] = aimPos
				end
			elseif typeof(v) == "CFrame" then
				out[i] = reaimCFrame(v, originPos, aimPos)
			else
				out[i] = v
			end
		end
		return out
	end
	local function pickTarget()
		if snapShotTargetName and snapShotTargetName ~= "" then
			local t = R.findTankByLabel(snapShotTargetName)
			if t then return t end
		end
		local myTank = findTank(player.Name)
		local myBase = myTank and myTank:FindFirstChild("Base")
		if not (myBase and myBase:IsA("BasePart")) then return nil end
		return (R.nearestEnemyTank(myBase.Position))
	end
	local busy = false
	local function doSnap(forcedTarget, skipReturn)
		if busy then return end
		busy = true
		local myTank = findTank(player.Name)
		local myBase = myTank and myTank:FindFirstChild("Base")
		local myS    = myTank and myTank:FindFirstChild("Settings")
		if not (myTank and myBase and myBase:IsA("BasePart") and myS) then
			busy = false; return
		end
		local tTank = forcedTarget or pickTarget()
		local tBase = tTank and tTank:FindFirstChild("Base")
		if not (tBase and tBase:IsA("BasePart")) then
			notify("Snap Shot: no target")
			busy = false; return
		end
		local targetName = tTank.Name
		if not genv.__tommyLastFireArgs then
			notify("Snap Shot: fire once manually first to capture args")
			busy = false; return
		end
		local home = myBase.Position
		local function stickFrame()
			local mt = findTank(player.Name)
			local mb = mt and mt:FindFirstChild("Base")
			local ms = mt and mt:FindFirstChild("Settings")
			local tt = R.tankByModelName(targetName)
			local tb = tt and tt:FindFirstChild("Base")
			if not (mt and mb and mb:IsA("BasePart") and ms
				and tb and tb:IsA("BasePart")) then
				return nil
			end
			local lv = tb.CFrame.LookVector
			lv = Vector3.new(lv.X, 0, lv.Z)
			if lv.Magnitude < 1e-3 then lv = Vector3.new(0, 0, 1) end
			local behind = tb.Position - lv.Unit * snapShotDistance
			behind = Vector3.new(behind.X, home.Y, behind.Z)
			pcall(function() teleportTank(mt, behind) end)
			local aimLive = tb.Position
			local pt = ms:FindFirstChild("PointerTarget")
			if pt and pt:IsA("Vector3Value") then
				pcall(function() pt.Value = aimLive end)
			end
			local rpcf = ms:FindFirstChild("ReplicatedPointerCFrame")
			if rpcf and rpcf:IsA("CFrameValue") then
				local ptr = mt:FindFirstChild("Pointer")
				if ptr and ptr:IsA("BasePart") then
					pcall(function() rpcf.Value = CFrame.lookAt(ptr.Position, aimLive) end)
				end
			end
			return aimLive
		end
		local method = R.snapMoveMethod or "Fast Step"
		if method == "Teleport" then
			local travel = (tBase.Position - home).Magnitude
			local wait0  = math.min(travel / 35 + 0.5, snapShotFireWait)
			local tw = os.clock()
			while os.clock() - tw < wait0 and breakWhile[63] == false do
				if not stickFrame() then
					pcall(function()
						local m = findTank(player.Name)
						if m then teleportTank(m, home) end
					end)
					busy = false; return
				end
				task.wait()
			end
		else
		local STEP_SPEED = 350
		if method == "Normal Move" then
			local msv = myS:FindFirstChild("MoveSpeed")
			STEP_SPEED = (msv and type(msv.Value) == "number" and msv.Value > 0)
				and msv.Value or 33
		end
		local MAX_STEP   = 10
		local lv0 = tBase.CFrame.LookVector
		lv0 = Vector3.new(lv0.X, 0, lv0.Z)
		if lv0.Magnitude < 1e-3 then lv0 = Vector3.new(0, 0, 1) end
		local goal = tBase.Position - lv0.Unit * snapShotDistance
		goal = Vector3.new(goal.X, home.Y, goal.Z)
		local arrived  = false
		local t0 = os.clock()
		local deadline = t0 + snapShotFireWait
		while breakWhile[63] == false and os.clock() < deadline and not arrived do
			local mt = findTank(player.Name)
			local mb = mt and mt:FindFirstChild("Base")
			local ms = mt and mt:FindFirstChild("Settings")
			local tt = R.tankByModelName(targetName)
			local tb = tt and tt:FindFirstChild("Base")
			if not (mt and mb and mb:IsA("BasePart") and ms
				and tb and tb:IsA("BasePart")) then
				pcall(function()
					local m = findTank(player.Name)
					if m then teleportTank(m, home) end
				end)
				busy = false; return
			end
			local cur    = mb.Position
			local toGoal = goal - cur
			local dist   = toGoal.Magnitude
			local dt     = task.wait()
			local stepDist = math.min(STEP_SPEED * math.max(dt, 1/240), MAX_STEP)
			local nextPos
			if dist <= stepDist then nextPos = goal; arrived = true
			else nextPos = cur + toGoal.Unit * stepDist end
			pcall(function() teleportTank(mt, nextPos) end)
			local aimLive = tb.Position
			local pt = ms:FindFirstChild("PointerTarget")
			if pt and pt:IsA("Vector3Value") then pcall(function() pt.Value = aimLive end) end
			local rpcf = ms:FindFirstChild("ReplicatedPointerCFrame")
			if rpcf and rpcf:IsA("CFrameValue") then
				local ptr = mt:FindFirstChild("Pointer")
				if ptr and ptr:IsA("BasePart") then
					pcall(function() rpcf.Value = CFrame.lookAt(ptr.Position, aimLive) end)
				end
			end
		end
		end
		local loaded = myS:FindFirstChild("LoadedShots")
		if loaded and type(loaded.Value) == "number" and loaded.Value <= 0 then
			notify("Snap Shot: no rounds loaded")
		else
			local aimNow
			do
				local at = R.tankByModelName(targetName)
				local ab = at and at:FindFirstChild("Base")
				local am = findTank(player.Name)
				local asx = am and am:FindFirstChild("Settings")
				if ab and ab:IsA("BasePart") and asx then
					aimNow = ab.Position
					local pt = asx:FindFirstChild("PointerTarget")
					if pt and pt:IsA("Vector3Value") then
						pcall(function() pt.Value = aimNow end)
					end
					local rpcf = asx:FindFirstChild("ReplicatedPointerCFrame")
					if rpcf and rpcf:IsA("CFrameValue") then
						local ptr = am:FindFirstChild("Pointer")
						if ptr and ptr:IsA("BasePart") then
							pcall(function() rpcf.Value = CFrame.lookAt(ptr.Position, aimNow) end)
						end
					end
				end
			end
			if aimNow then
				local mt = findTank(player.Name)
				local cannon = mt and mt:FindFirstChild("Pointer")
					and mt.Pointer:FindFirstChild("Cannon")
				local mb = mt and mt:FindFirstChild("Base")
				local cannonPos = (cannon and cannon:IsA("BasePart")) and cannon.Position
					or (mb and mb.Position)
				if cannonPos then
					local shot = snapRetarget(genv.__tommyLastFireArgs, cannonPos, aimNow)
					pcall(function() fb:FireServer(table.unpack(shot, 1, shot.n)) end)
				end
			end
		end
		t0 = os.clock()
		while os.clock() - t0 < 0.2 and breakWhile[63] == false do
			if not stickFrame() then break end
			task.wait()
		end
		if not skipReturn then
			pcall(function()
				local mt = findTank(player.Name)
				if mt then teleportTank(mt, home) end
			end)
		end
		busy = false
	end
	local snapAllBusy, snapAllToken = false, 0
	snapShotAll = function()
		if snapAllBusy then
			snapAllBusy  = false
			snapAllToken = snapAllToken + 1
			notify("Snap All: cancelling...")
			return
		end
		if not genv.__tommyLastFireArgs then
			notify("Snap All: fire once manually first to capture args")
			return
		end
		local mt = findTank(player.Name)
		local mb = mt and mt:FindFirstChild("Base")
		if not (mb and mb:IsA("BasePart")) then
			notify("Snap All: you have no tank")
			return
		end
		local list = R.enemyTanks()
		if #list == 0 then notify("Snap All: no enemies") return end
		local origin = mb.Position
		table.sort(list, function(a, b)
			local pa, pb = R.tankBasePos(a), R.tankBasePos(b)
			if not pa then return false end
			if not pb then return true end
			return (pa - origin).Magnitude < (pb - origin).Magnitude
		end)
		snapAllBusy  = true
		snapAllToken = snapAllToken + 1
		local myToken = snapAllToken
		local startPos = origin
		task.spawn(function()
			notify(("Snap All: %d target%s"):format(#list, #list == 1 and "" or "s"))
			local hit = 0
			for _, t in ipairs(list) do
				if breakWhile[63] or myToken ~= snapAllToken then break end
				local live = R.tankByModelName(t.Name)
				if live and live:FindFirstChild("Base") then
					local waited = 0
					while busy and waited < 3 do
						task.wait(0.05); waited = waited + 0.05
					end
					doSnap(live, true)
					hit = hit + 1
					task.wait(0.15)
				end
			end
			pcall(function()
				local mt = findTank(player.Name)
				if mt then teleportTank(mt, startPos) end
			end)
			if myToken == snapAllToken then
				notify(("Snap All: done (%d/%d)"):format(hit, #list))
				snapAllBusy = false
			end
		end)
	end
	local conn
	pcall(function()
		conn = UIS.InputBegan:Connect(function(input, processed)
			if processed then return end
			if breakWhile[63] then return end
			if input.KeyCode == snapShotKey then
				task.spawn(doSnap)
			end
		end)
	end)
	local recentHit = {}
	local function pickAutoTarget()
		local myTank = findTank(player.Name)
		local myBase = myTank and myTank:FindFirstChild("Base")
		if not (myBase and myBase:IsA("BasePart")) then return nil end
		local now, COOLDOWN = os.clock(), 1.5
		local best, bestD, fb, fbD
		for _, t in ipairs(R.enemyTanks()) do
			local p = R.tankBasePos(t)
			if p then
				local d = (p - myBase.Position).Magnitude
				if not fbD or d < fbD then fb, fbD = t, d end
				local last = recentHit[t.Name]
				if (not last or now - last > COOLDOWN) and (not bestD or d < bestD) then
					best, bestD = t, d
				end
			end
		end
		return best or fb
	end
	while breakWhile[63] == false do
		if snapShotAuto and not busy and genv.__tommyLastFireArgs then
			local target
			if snapShotTargetName and snapShotTargetName ~= "" then
				target = R.findTankByLabel(snapShotTargetName)
			else
				target = pickAutoTarget()
			end
			if target then
				doSnap(target, true)
				recentHit[target.Name] = os.clock()
				if breakWhile[63] == false then task.wait(0.1) end
			else
				task.wait(0.1)
			end
		else
			task.wait(0.1)
		end
	end
	snapAllBusy  = false
	snapAllToken = snapAllToken + 1
	snapShotAll  = nil
	if conn then pcall(function() conn:Disconnect() end) end
end
R.snapMoveMethod = "Fast Step"
local function setSnap(on)
	if on then
		if breakWhile[63] == true then
			breakWhile[63] = false
			task.spawn(loopSnapShot)
		end
	else
		breakWhile[63] = true
	end
end
tab:AddTextbox({ Text = "Target", Placeholder = "player/bot name (blank = nearest enemy)",
	ClearOnFocus = false, Callback = function(t) snapShotTargetName = t or "" end })
tab:AddSlider({ Text = "Distance behind", Min = 4, Max = 40, Default = 10, Step = 1,
	Suffix = " studs", Callback = function(v) snapShotDistance = v end })
tab:AddSlider({ Text = "Aim Offset", Min = -180, Max = 180, Default = 90, Step = 5,
	Suffix = " deg", Callback = function(v) snapShotAimOffsetDeg = v end })
tab:AddSlider({ Text = "Max Drive Time", Min = 1, Max = 50, Default = 12, Step = 1,
	Suffix = " s", Callback = function(v) snapShotFireWait = v end })
tab:AddDropdown({ Text = "Move Method", Options = { "Fast Step", "Teleport", "Normal Move" },
	Default = "Fast Step", Callback = function(v) R.snapMoveMethod = v end })
snapToggleEl = tab:AddToggle({ Text = "Snap Shot (G = TP behind, fire, TP back)",
	Default = false, Callback = function(s) setSnap(s) end })
tab:AddToggle({ Text = "Auto (keep killing, no key press)",
	Default = false, Callback = function(s) snapShotAuto = s end })
tab:AddButton({ Text = "Snap All (every enemy, nearest first)",
	Callback = function() if snapShotAll then snapShotAll() else notify("enable Snap Shot first") end end })
print("[Snap Shot] loaded standalone. Toggle Snap Shot, then press G (or use Auto / Snap All).")
