--!strict
local ListElement = {}

local Theme = require("../../Theme")
local Widgets = require("../../Widgets")

local function OnClicked(self: ListElement, callback: () -> ()): ListElement
	local element = self.instance
	self._clickedConnection = element.MouseButton1Down:Connect(function()
		callback()
	end)
	element.BackgroundColor3 = Theme.get().UnselectedColor
	return self
end

local function AddDestroyButton(self: ListElement, callback: () -> ()?): ListElement
	local button = Instance.new("ImageButton")
	button.Name = "ImageButton"
	button.AutoButtonColor = false
	button.AnchorPoint = Vector2.new(1, 0.5)
	button.BorderSizePixel = 0
	button.Position = UDim2.new(1, -4, 0.5, 0)
	button.Size = UDim2.fromOffset(16, 16)
	button.ZIndex = 2
	Widgets.corner(button, 4)
	button.Parent = self.instance

	self._removedConnection = button.MouseButton1Down:Connect(function()
		if callback then
			callback()
		end
		self._removedCallback()
		self:Destroy()
	end)

	self:UpdateTheme()
	return self
end

local function UpdateTheme(self: ListElement)
	local theme = Theme.get()
	local element = self.instance
	Theme.updateFrame(element)
	if self._clickedConnection then
		element.BackgroundColor3 = self.selected and theme.SelectedColor or theme.UnselectedColor
	end

	local elementButton = element:FindFirstChild("ImageButton")
	if elementButton and elementButton:IsA("ImageButton") then
		Theme.updateFrame(elementButton)
		elementButton.ImageColor3 = theme.XColor
		elementButton.BackgroundColor3 = theme.UnselectedColor
		elementButton.Image = theme.XImage
	end

	Theme.updateText(element:FindFirstChild("TextLabel") :: TextLabel, false)
end

local function Destroy(self: ListElement)
	if self._removedConnection then
		self._removedConnection:Disconnect()
	end
	if self._clickedConnection then
		self._clickedConnection:Disconnect()
	end
	self.instance:Destroy()
	table.clear(self :: any)
end

export type ListElement = {
	_clickedConnection: RBXScriptConnection?,
	_removedCallback: () -> (),
	_removedConnection: RBXScriptConnection?,
	instance: TextButton,
	selected: boolean,
	OnClicked: typeof(OnClicked),
	AddDestroyButton: typeof(AddDestroyButton),
	UpdateTheme: typeof(UpdateTheme),
	Destroy: typeof(Destroy),
}

function ListElement.new(parent: Instance, removedCallback: () -> ()?, value: string): ListElement
	local instance = Instance.new("TextButton")
	instance.Name = "ListElement"
	instance.AutoButtonColor = false
	instance.BorderSizePixel = 0
	instance.Size = UDim2.new(1, -4, 0, 24)
	instance.Text = ""
	Widgets.corner(instance, 4)

	local label = Instance.new("TextLabel")
	label.Name = "TextLabel"
	label.BackgroundTransparency = 1
	label.Position = UDim2.fromOffset(8, 0)
	label.Size = UDim2.new(1, -28, 1, 0)
	label.Text = value
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.Parent = instance

	instance.Parent = parent

	local self: ListElement = {
		_removedCallback = removedCallback,
		instance = instance,
		selected = false,
		OnClicked = OnClicked,
		AddDestroyButton = AddDestroyButton,
		UpdateTheme = UpdateTheme,
		Destroy = Destroy,
	} :: ListElement

	self:UpdateTheme()
	return self
end

return ListElement
