--!strict
local Label = {}

local Theme = require("../Theme")
local Widgets = require("../Widgets")

local function ChangeText(self: Label, newText: string)
	self.instance.Text = newText
end

local function UpdateTheme(self: Label)
	Theme.updateText(self.instance, true)
	self.instance.BackgroundTransparency = 1
end

local function Destroy(self: Label)
	self.instance:Destroy()
	table.clear(self :: any)
end

export type Label = {
	instance: TextLabel,
	ChangeText: typeof(ChangeText),
	UpdateTheme: typeof(UpdateTheme),
	Destroy: typeof(Destroy),
}

function Label.new(parent: GuiObject, text: string): Label
	local instance = Widgets.textLabel(parent, text, 22)
	instance.TextWrapped = true
	instance.AutomaticSize = Enum.AutomaticSize.Y

	local self: Label = {
		instance = instance,
		ChangeText = ChangeText,
		UpdateTheme = UpdateTheme,
		Destroy = Destroy,
	}

	self:UpdateTheme()
	return self
end

return Label
