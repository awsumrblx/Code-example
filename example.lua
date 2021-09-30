local UserInputService = game:GetService("UserInputService")
local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local Players = game:GetService("Players")

local player = Players.LocalPlayer
local mouse = player:GetMouse() -- used to set the icon

local function getMouseTarget(raycastParams)
	local mouseLocation = UserInputService:GetMouseLocation()
	local unscaledRay = Workspace.CurrentCamera:ViewportPointToRay(mouseLocation.X, mouseLocation.Y)
	local raycastResult = Workspace:Raycast(unscaledRay.Origin, unscaledRay.Direction * 1000, raycastParams)
	
	return raycastResult
end

local function stopHovering(self)
	if not self._isHovering then
		return
	end

	mouse.Icon = self._originalMouseIcon

	self._isHovering = false
	self._mouseLeaveEvent:Fire()
end

local CustomClickDetector = {}
CustomClickDetector.__index = CustomClickDetector
CustomClickDetector.ClassName = "CustomClickDetector"

function CustomClickDetector.new(instance)
	assert(instance:IsA("BasePart"), "Custom Click Detector expected instance to be a Part.")
	
	local self = setmetatable({}, CustomClickDetector)
	
	self._instance = instance
	
	self._mouseEnterEvent = Instance.new("BindableEvent")
	self._mouseLeaveEvent = Instance.new("BindableEvent")
	self._button1DownEvent = Instance.new("BindableEvent")
	
	self._garbage = {}
	
	self._isHovering = false
	self._originalMouseIcon = ""
	
	self.CursorImage = instance:GetAttribute("CursorIcon") or "rbxassetid://7033235466"
	self.MaxActivationDistance = instance:GetAttribute("MaxActivationDistance") or 15
	self.FilterType = Enum.RaycastFilterType.Blacklist
	
	self.MouseEnter = self._mouseEnterEvent.Event
	self.MouseLeave = self._mouseLeaveEvent.Event
	self.Button1Down = self._button1DownEvent.Event
	
	self._garbage = {
		self._mouseEnterEvent,
		self._mouseLeaveEvent,
		self._button1DownEvent,
	}
	
	return self
end

function CustomClickDetector:GetFilter()
	return {}
end

function CustomClickDetector:GetInstance()
	return self._instance
end

function CustomClickDetector:IsHovering()
	return self._isHovering
end

function CustomClickDetector:Start()
	local function updateHovering()
		local character = player.Character
		if not character then
			stopHovering(self)
			return
		end

		local humanoidRootPart = character:FindFirstChild("HumanoidRootPart")
		if not humanoidRootPart then
			stopHovering(self)
			return
		end
		
		local raycastParams = RaycastParams.new()
		raycastParams.FilterType = self.FilterType
		raycastParams.FilterDescendantsInstances = self:GetFilter()

		local raycastResult = getMouseTarget(raycastParams)
		if not raycastResult then
			stopHovering(self)
			return
		end
		
		if raycastResult.Instance ~= self._instance then
			if not raycastResult.Instance:IsDescendantOf(self._instance) then
				stopHovering(self)
				return
			end
		end
		
		if (humanoidRootPart.Position - self._instance.Position).Magnitude > self.MaxActivationDistance then
			stopHovering(self)
			return
		end
		
		task.defer(function() -- Make icon setting with task.defer since the leave event would fire *after* the enter event fired, so it would mess up the icons
			if not self._isHovering then
				return
			end

			mouse.Icon = self.CursorImage
		end)
		
		if self._isHovering then
			return
		end
		
		self._isHovering = true
		self._mouseEnterEvent:Fire()
	end
	
	local function updateButton1Down()
		local character = player.Character
		if not character then
			return
		end

		local humanoidRootPart = character:FindFirstChild("HumanoidRootPart")
		if not humanoidRootPart then
			return
		end

		local raycastParams = RaycastParams.new()
		raycastParams.FilterType = self.FilterType
		raycastParams.FilterDescendantsInstances = self:GetFilter()

		local raycastResult = getMouseTarget(raycastParams)
		if not raycastResult then
			return
		end

		if raycastResult.Instance ~= self._instance then
			if not raycastResult.Instance:IsDescendantOf(self._instance) then
				return
			end
		end

		if (humanoidRootPart.Position - self._instance.Position).Magnitude > self.MaxActivationDistance then
			return
		end

		self._button1DownEvent:Fire()
	end
	
	table.insert(self._garbage, CollectionService:GetInstanceRemovedSignal("_CustomClickDetector"):Connect(function(otherInstance)
		if otherInstance ~= self._instance then
			return
		end

		self:Destroy()
	end))
	
	table.insert(self._garbage, RunService.Stepped:Connect(updateHovering))
	table.insert(self._garbage, UserInputService.InputBegan:Connect(function(inputObject, gameProcessedEvent)
		if gameProcessedEvent then
			return
		end
		
		if inputObject.UserInputType ~= Enum.UserInputType.MouseButton1 and inputObject.UserInputType ~= Enum.UserInputType.Touch then
			return
		end
		
		updateButton1Down()
	end))
end

function CustomClickDetector:Destroy()
	stopHovering(self)
	
	for _, value in ipairs(self._garbage) do
		if typeof(value) == "Instance" then
			value:Destroy()
		elseif typeof(value) == "RBXScriptConnection" then
			value:Disconnect()
		elseif typeof(value) == "function" then
			value()
		end
	end
	
	self._garbage = {}
end

return CustomClickDetector
