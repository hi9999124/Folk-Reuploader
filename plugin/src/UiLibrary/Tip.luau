--!strict
local Tip = {}

local Theme = require("./Theme")

type TipBarAsset = Frame

local function UpdateTheme(self: Tip)
	local theme = Theme.get()
	self.instance.ImageColor3 = theme.TipColor
	self.instance.Image = theme.TipImage
end

local function Destroy(self: Tip)
	self.instance:Destroy()
	table.clear(self :: any)
end

export type Tip = {
	_tipBar: TipBarAsset,
	instance: ImageButton,
	UpdateTheme: typeof(UpdateTheme),
	Destroy: typeof(Destroy),
}

function Tip.new(tipBar: TipBarAsset, text: string): Tip
	local instance = Instance.new("ImageButton")
	instance.AnchorPoint = Vector2.new(0, 0.5)
	instance.BackgroundTransparency = 1
	instance.Size = UDim2.fromOffset(15, 15)
	instance.ZIndex = 2
	instance.ImageTransparency = 0.5

	instance.MouseEnter:Connect(function()
		instance.ImageTransparency = 0
		local tipText = tipBar:FindFirstChild("Frame") and tipBar.Frame:FindFirstChild("TipText")
		if tipText and tipText:IsA("TextLabel") then
			tipText.Text = text
		end
		tipBar.Visible = true
	end)

	instance.MouseLeave:Connect(function()
		instance.ImageTransparency = 0.5
		tipBar.Visible = false
	end)

	local self: Tip = {
		_tipBar = tipBar,
		instance = instance,
		UpdateTheme = UpdateTheme,
		Destroy = Destroy,
	}
	self:UpdateTheme()
	return self
end

return Tip
