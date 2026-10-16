--!strict
local Tab = {}

local Button = require("./Button")
local Label = require("./Label")
local List = require("./List")
local Split = require("./Split")
local Toggle = require("./Toggle")
local Widgets = require("../Widgets")

local function CreateButton(self: Tab, text: string, callback: () -> ()): Button.Button
	local button = Button.new(self.instance, text, callback)
	table.insert(self._elements, button)
	return button
end

local function CreateToggle(self: Tab, text: string, callback: (state: boolean) -> (), defaultState: boolean?): Toggle.Toggle
	local toggle = Toggle.new(self.instance, text, callback, defaultState)
	table.insert(self._elements, toggle)
	return toggle
end

local function CreateSplit(self: Tab): Split.Split
	local split = Split.new(self.instance)
	table.insert(self._elements, split)
	return split
end

local function CreateList(self: Tab): List.List
	local list = List.new(self.instance)
	table.insert(self._elements, list)
	return list
end

local function CreateLabel(self: Tab, text: string): Label.Label
	local label = Label.new(self.instance, text)
	table.insert(self._elements, label)
	return label
end

local function UpdateTheme(self: Tab)
	self.button:UpdateTheme()
	for _, element in self._elements do
		element:UpdateTheme()
	end
end

local function Destroy(self: Tab)
	for _, element in self._elements do
		element:Destroy()
	end
	table.clear(self :: any)
end

export type Tab = {
	_elements: { any },
	button: Button.Button,
	instance: Frame,
	CreateButton: typeof(CreateButton),
	CreateToggle: typeof(CreateToggle),
	CreateSplit: typeof(CreateSplit),
	CreateList: typeof(CreateList),
	CreateLabel: typeof(CreateLabel),
	UpdateTheme: typeof(UpdateTheme),
	Destroy: typeof(Destroy),
}

function Tab.new(uiFrame: Frame, clickedCallback: () -> (), name: string): Tab
	local instance = Instance.new("ScrollingFrame")
	instance.Name = name
	instance.BackgroundTransparency = 1
	instance.BorderSizePixel = 0
	instance.Size = UDim2.new(1, 0, 1, 0)
	instance.Visible = false
	instance.AutomaticCanvasSize = Enum.AutomaticSize.Y
	instance.CanvasSize = UDim2.new()
	instance.ScrollBarThickness = 4
	Widgets.list(instance, 6)
	Widgets.pad(instance, 8)

	local tabsHost = uiFrame:FindFirstChild("Main"):FindFirstChild("Tabs")
	instance.Parent = tabsHost

	local topbar = uiFrame:FindFirstChild("Topbar"):FindFirstChild("Frame") :: Frame

	local self: Tab = {
		_elements = {},
		button = Button.new(topbar, name, clickedCallback, false),
		instance = instance,
		CreateButton = CreateButton,
		CreateToggle = CreateToggle,
		CreateSplit = CreateSplit,
		CreateList = CreateList,
		CreateLabel = CreateLabel,
		UpdateTheme = UpdateTheme,
		Destroy = Destroy,
	}

	self.button.instance.Size = UDim2.new(0, 96, 1, -4)
	self:UpdateTheme()
	return self
end

return Tab
