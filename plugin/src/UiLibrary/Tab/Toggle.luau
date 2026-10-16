--!strict
local Toggle = {}

local Theme = require("../Theme")
local Tip = require("../Tip")
local Widgets = require("../Widgets")

local function DoToggle(self: Toggle)
	self.state = not self.state
	self._callback(self.state)
	local theme = Theme.get()
	local button = self.instance:FindFirstChild("Button") :: TextButton
	button.BackgroundColor3 = self.state and theme.ToggleBackgroundColor or theme.UnselectedColor
	button.Text = self.state and "ON" or "OFF"
end

local function AddTip(self: Toggle, tip: Tip.Tip)
	local tipFrame = tip.instance
	local toggleFrame = self.instance
	local label = toggleFrame:FindFirstChild("TextLabel") :: TextLabel
	tipFrame.Position = UDim2.new(0, label.TextBounds.X + 5, 0.5, 0)
	tipFrame.Parent = label
	self._tip = tip
end

local function UpdateTheme(self: Toggle)
	local toggleFrame = self.instance
	Theme.updateFrame(toggleFrame)
	Theme.updateText(toggleFrame:FindFirstChild("TextLabel") :: TextLabel, false)

	local theme = Theme.get()
	local button = toggleFrame:FindFirstChild("Button") :: TextButton
	button.BorderColor3 = theme.BorderColor
	button.BackgroundColor3 = self.state and theme.ToggleBackgroundColor or theme.UnselectedColor
	button.TextColor3 = theme.TextColor
	button.Text = self.state and "ON" or "OFF"

	if self._tip then
		self._tip:UpdateTheme()
	end
end

local function Destroy(self: Toggle)
	if self._tip then
		self._tip:Destroy()
	end
	self.instance:Destroy()
	table.clear(self :: any)
end

export type Toggle = {
	_tip: Tip.Tip?,
	_callback: (state: boolean) -> (),
	state: boolean,
	instance: Frame,
	Toggle: typeof(DoToggle),
	AddTip: typeof(AddTip),
	UpdateTheme: typeof(UpdateTheme),
	Destroy: typeof(Destroy),
}

function Toggle.new(parent: GuiObject, text: string, callback: (state: boolean) -> (), defaultState: boolean?): Toggle
	local instance = Instance.new("Frame")
	instance.Name = "Toggle"
	instance.BorderSizePixel = 0
	instance.Size = UDim2.new(1, 0, 0, 28)
	Widgets.corner(instance, 6)

	local label = Widgets.textLabel(instance, text, 28)
	label.Position = UDim2.new(0, 8, 0, 0)
	label.Size = UDim2.new(1, -64, 1, 0)

	local button = Instance.new("TextButton")
	button.Name = "Button"
	button.AutoButtonColor = false
	button.AnchorPoint = Vector2.new(1, 0.5)
	button.Position = UDim2.new(1, -6, 0.5, 0)
	button.Size = UDim2.fromOffset(44, 20)
	button.BorderSizePixel = 0
	button.Font = Enum.Font.GothamBold
	button.TextSize = 11
	button.Text = "OFF"
	Widgets.corner(button, 4)
	button.Parent = instance

	local self: Toggle
	self = {
		_callback = callback,
		state = false,
		instance = instance,
		Toggle = DoToggle,
		AddTip = AddTip,
		UpdateTheme = UpdateTheme,
		Destroy = Destroy,
	} :: Toggle

	button.MouseButton1Down:Connect(function()
		self:Toggle()
	end)

	instance.Parent = parent
	self:UpdateTheme()
	if defaultState then
		self:Toggle()
	end

	return self
end

return Toggle
