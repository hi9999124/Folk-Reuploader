--!strict
local Button = {}

local Theme = require("../Theme")
local Widgets = require("../Widgets")

local function ColorSelected(self: Button)
	self.instance.BackgroundColor3 = Theme.get().SelectedColor
end

local function ColorUnselected(self: Button)
	self.instance.BackgroundColor3 = Theme.get().UnselectedColor
end

local function UpdateTheme(self: Button)
	Theme.updateText(self.instance, true)
	self.instance.BackgroundColor3 = Theme.get().UnselectedColor
end

local function Destroy(self: Button)
	self.instance:Destroy()
	table.clear(self :: any)
end

export type Button = {
	instance: TextButton,
	ColorSelected: typeof(ColorSelected),
	ColorUnselected: typeof(ColorUnselected),
	UpdateTheme: typeof(UpdateTheme),
	Destroy: typeof(Destroy),
}

function Button.new(parent: GuiObject, text: string, callback: () -> (), autoColor: boolean?): Button
	local instance = Widgets.textButton(parent, text, 28)

	local self: Button = {
		instance = instance,
		ColorSelected = ColorSelected,
		ColorUnselected = ColorUnselected,
		UpdateTheme = UpdateTheme,
		Destroy = Destroy,
	}

	if autoColor == nil then
		autoColor = true
	end

	instance.MouseButton1Down:Connect(function()
		if autoColor then
			self:ColorSelected()
		end
		callback()
	end)

	if autoColor then
		local function colorUnselected()
			self:ColorUnselected()
		end
		instance.MouseButton1Up:Connect(colorUnselected)
		instance.MouseLeave:Connect(colorUnselected)
	end

	self:UpdateTheme()
	return self
end

return Button
