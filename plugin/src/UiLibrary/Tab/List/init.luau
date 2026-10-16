--!strict
local List = {}

local Input = require("./Input")
local Theme = require("../Theme")
local ListElement = require("./List/ListElement")
local Widgets = require("../Widgets")

local function Get(self: List): { string }
	local values = {}
	for i, _ in self.elements do
		table.insert(values, i)
	end
	return values
end

local function AddInput(self: List, placeholderText: string, callback: (input: string) -> ()): Input.Input
	local input = Input.new(self.instance, placeholderText, callback)
	local scrollingFrame = self.instance:FindFirstChild("ScrollingFrame") :: ScrollingFrame
	scrollingFrame.Position = UDim2.new(0, 0, 0, 32)
	scrollingFrame.Size = UDim2.new(1, 0, 1, -32)
	self._input = input
	return input
end

local function CreateElement(self: List, value: string): ListElement.ListElement
	local listElement = ListElement.new(self.instance:FindFirstChild("ScrollingFrame") :: ScrollingFrame, function()
		self.elements[value] = nil
	end, value)
	self.elements[value] = listElement
	return listElement
end

local function RemoveElement(self: List, value: string)
	if not self.elements[value] then
		error(`{value} does not exist in list`)
	end
	self.elements[value]:Destroy()
	self.elements[value] = nil
end

local function UpdateTheme(self: List)
	local listFrame = self.instance:FindFirstChild("ScrollingFrame") :: ScrollingFrame
	Theme.updateFrame(listFrame)
	for _, element in self.elements do
		element:UpdateTheme()
	end
	if self._input then
		self._input:UpdateTheme()
	end
end

local function Destroy(self: List)
	for _, element in self.elements do
		element:Destroy()
	end
	self.instance:Destroy()
	table.clear(self :: any)
end

export type List = {
	_input: Input.Input?,
	elements: { [string]: ListElement.ListElement },
	instance: Frame,
	Get: typeof(Get),
	AddInput: typeof(AddInput),
	CreateElement: typeof(CreateElement),
	RemoveElement: typeof(RemoveElement),
	UpdateTheme: typeof(UpdateTheme),
	Destroy: typeof(Destroy),
}

function List.new(parent: GuiObject): List
	local instance = Instance.new("Frame")
	instance.Name = "List"
	instance.BackgroundTransparency = 1
	instance.Size = UDim2.new(1, 0, 1, -8)
	instance.Parent = parent

	local scrolling = Instance.new("ScrollingFrame")
	scrolling.Name = "ScrollingFrame"
	scrolling.BorderSizePixel = 0
	scrolling.Size = UDim2.new(1, 0, 1, 0)
	scrolling.AutomaticCanvasSize = Enum.AutomaticSize.Y
	scrolling.CanvasSize = UDim2.new()
	scrolling.ScrollBarThickness = 4
	scrolling.Parent = instance
	Widgets.list(scrolling, 4)
	Widgets.pad(scrolling, 2)

	local self = {
		elements = {},
		instance = instance,
		Get = Get,
		AddInput = AddInput,
		CreateElement = CreateElement,
		RemoveElement = RemoveElement,
		UpdateTheme = UpdateTheme,
		Destroy = Destroy,
	} :: List

	self:UpdateTheme()
	return self
end

return List
