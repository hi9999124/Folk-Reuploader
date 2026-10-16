--!strict
local Input = {}

local Theme = require("../Theme")
local Tip = require("../Tip")
local Widgets = require("../Widgets")

local function AddTip(self: Input, tip: Tip.Tip)
	local textBox = self.instance.TextBox
	textBox.Position = UDim2.new(0, 25, 0.5, 0)
	textBox.Size = UDim2.new(1, -45, 1, -2)
	local tipFrame = tip.instance
	tipFrame.Position = UDim2.new(0, 5, 0.5, 0)
	tipFrame.Parent = self.instance
	self._tip = tip
end

local function UpdateTheme(self: Input)
	local theme = Theme.get()
	local instance = self.instance
	instance.BackgroundColor3 = theme.UnselectedColor
	instance.BorderColor3 = theme.BorderColor

	local button = instance:FindFirstChild("ImageButton") :: ImageButton
	Theme.updateFrame(button)
	button.BackgroundColor3 = theme.UnselectedColor
	button.Image = theme.InputImage
	button.ImageColor3 = theme.InputColor

	Theme.updateText(instance:FindFirstChild("TextBox") :: TextBox, true)

	if self._tip then
		self._tip:UpdateTheme()
	end
end

local function Destroy(self: Input)
	if self._tip then
		self._tip:Destroy()
	end
	self.instance:Destroy()
	table.clear(self :: any)
end

export type Input = {
	_tip: Tip.Tip,
	instance: Frame,
	AddTip: typeof(AddTip),
	UpdateTheme: typeof(UpdateTheme),
	Destroy: typeof(Destroy),
}

function Input.new(parent: GuiObject, placeholderText: string, callback: (input: string) -> ()): Input
	local instance = Instance.new("Frame")
	instance.Name = "Input"
	instance.BorderSizePixel = 0
	instance.Size = UDim2.new(1, 0, 0, 28)
	Widgets.corner(instance, 6)

	local inputBox = Instance.new("TextBox")
	inputBox.Name = "TextBox"
	inputBox.BackgroundTransparency = 1
	inputBox.BorderSizePixel = 0
	inputBox.ClearTextOnFocus = false
	inputBox.PlaceholderText = placeholderText
	inputBox.Position = UDim2.new(0, 8, 0.5, 0)
	inputBox.AnchorPoint = Vector2.new(0, 0.5)
	inputBox.Size = UDim2.new(1, -36, 1, -2)
	inputBox.Text = ""
	inputBox.TextXAlignment = Enum.TextXAlignment.Left
	inputBox.Parent = instance

	local button = Instance.new("ImageButton")
	button.Name = "ImageButton"
	button.AutoButtonColor = false
	button.AnchorPoint = Vector2.new(1, 0.5)
	button.Position = UDim2.new(1, -4, 0.5, 0)
	button.Size = UDim2.fromOffset(20, 20)
	button.BorderSizePixel = 0
	Widgets.corner(button, 4)
	button.Parent = instance

	local function inputEntered()
		local text = inputBox.Text
		if text == "" then
			return
		end
		inputBox.Text = ""
		callback(text)
	end

	inputBox.FocusLost:Connect(function(enterPressed)
		if enterPressed then
			inputEntered()
		end
	end)

	button.MouseButton1Down:Connect(function()
		button.BackgroundColor3 = Theme.get().SelectedColor
		inputEntered()
	end)

	local function colorUnselected()
		button.BackgroundColor3 = Theme.get().UnselectedColor
	end
	button.MouseButton1Up:Connect(colorUnselected)
	button.MouseLeave:Connect(colorUnselected)

	instance.Parent = parent

	local self = {
		instance = instance,
		AddTip = AddTip,
		UpdateTheme = UpdateTheme,
		Destroy = Destroy,
	} :: Input

	self:UpdateTheme()
	return self
end

return Input
