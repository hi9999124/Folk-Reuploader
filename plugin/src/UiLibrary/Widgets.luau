--!strict
local Widgets = {}

function Widgets.corner(parent: Instance, radius: number)
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, radius)
	corner.Parent = parent
	return corner
end

function Widgets.stroke(parent: Instance, color: Color3, thickness: number?)
	local stroke = Instance.new("UIStroke")
	stroke.Color = color
	stroke.Thickness = thickness or 1
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Parent = parent
	return stroke
end

function Widgets.pad(parent: Instance, px: number)
	local padding = Instance.new("UIPadding")
	padding.PaddingTop = UDim.new(0, px)
	padding.PaddingBottom = UDim.new(0, px)
	padding.PaddingLeft = UDim.new(0, px)
	padding.PaddingRight = UDim.new(0, px)
	padding.Parent = parent
	return padding
end

function Widgets.list(parent: Instance, padding: number, fillDir: Enum.FillDirection?)
	local layout = Instance.new("UIListLayout")
	layout.FillDirection = fillDir or Enum.FillDirection.Vertical
	layout.Padding = UDim.new(0, padding)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = parent
	return layout
end

function Widgets.textButton(parent: Instance, text: string, height: number): TextButton
	local button = Instance.new("TextButton")
	button.Name = "Button"
	button.AutoButtonColor = false
	button.BorderSizePixel = 0
	button.Size = UDim2.new(1, 0, 0, height)
	button.Font = Enum.Font.GothamMedium
	button.Text = text
	button.TextSize = 14
	button.TextXAlignment = Enum.TextXAlignment.Center
	Widgets.corner(button, 6)
	button.Parent = parent
	return button
end

function Widgets.textLabel(parent: Instance, text: string, height: number): TextLabel
	local label = Instance.new("TextLabel")
	label.Name = "TextLabel"
	label.BackgroundTransparency = 1
	label.BorderSizePixel = 0
	label.Size = UDim2.new(1, 0, 0, height)
	label.Font = Enum.Font.GothamMedium
	label.Text = text
	label.TextSize = 14
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.Parent = parent
	return label
end

return Widgets
