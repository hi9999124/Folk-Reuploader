--!strict
local UiLibrary = {}

local Tab = require("./UiLibrary/Tab")
local Theme = require("./UiLibrary/Theme")
local Tip = require("./UiLibrary/Tip")
local Widgets = require("./UiLibrary/Widgets")

local TOPBAR_TITLE = "Folk Reuploader"

type ThemeManager = typeof(Theme)

local function selectTab(self: Ui, tabIndex: number)
	if self._currentTabIndex ~= 0 then
		local tabToUnselect = self._tabs[self._currentTabIndex]
		tabToUnselect.button:ColorUnselected()
		tabToUnselect.instance.Visible = false
	end

	local tabToSelect = self._tabs[tabIndex]
	tabToSelect.button:ColorSelected()
	tabToSelect.instance.Visible = true
	self._currentTabIndex = tabIndex
end

local function CreateTab(self: Ui, name: string): Tab.Tab
	local tabIndex = #self._tabs + 1
	local tab = Tab.new(self.instance, function()
		if self._currentTabIndex == tabIndex then
			return
		end
		selectTab(self, tabIndex)
	end, name)
	table.insert(self._tabs, tab)

	if self._currentTabIndex == 0 then
		selectTab(self, tabIndex)
	end
	return tab
end

local function CreateTip(self: Ui, text: string): Tip.Tip
	return Tip.new(self.instance:FindFirstChild("Tip") :: Frame, text)
end

local function Notify(self: Ui, title: string, description: string)
	local notification = self.instance:FindFirstChild("Notification") :: Frame
	local titleLabel = notification:FindFirstChild("Title") :: TextLabel
	local descLabel = notification:FindFirstChild("Description") :: TextLabel
	titleLabel.Text = title
	descLabel.Text = description
	notification.Visible = true
end

local function SetStatus(self: Ui, text: string, connected: boolean?)
	local status = self.instance:FindFirstChild("Status") :: TextLabel
	status.Text = text
	if connected == true then
		status.TextColor3 = Color3.fromRGB(110, 220, 160)
	elseif connected == false then
		status.TextColor3 = Color3.fromRGB(240, 120, 110)
	else
		status.TextColor3 = Theme.get().DimmedTextColor
	end
end

local function UpdateTheme(self: Ui)
	local theme = Theme.get()
	local uiFrame = self.instance
	uiFrame.BackgroundColor3 = theme.BackgroundColor

	local main = uiFrame:FindFirstChild("Main") :: Frame
	main.BackgroundColor3 = theme.ForegroundColor

	local topBar = uiFrame:FindFirstChild("Topbar") :: Frame
	topBar.BackgroundColor3 = theme.BorderColor
	local title = topBar:FindFirstChild("Title") :: TextLabel
	title.Text = TOPBAR_TITLE
	Theme.updateText(title)

	local notification = uiFrame:FindFirstChild("Notification") :: Frame
	notification.BackgroundColor3 = theme.ForegroundColor
	Theme.updateText(notification:FindFirstChild("Title") :: TextLabel, true)
	Theme.updateText(notification:FindFirstChild("Description") :: TextLabel, true)
	Theme.updateText(notification:FindFirstChild("Close") :: TextButton, true)
	;(notification:FindFirstChild("Title") :: TextLabel).TextSize += 6

	local tipbar = uiFrame:FindFirstChild("Tip") :: Frame
	tipbar.BackgroundColor3 = theme.BorderColor
	local tipInner = tipbar:FindFirstChild("Frame") :: Frame
	tipInner.BackgroundColor3 = theme.ForegroundColor
	Theme.updateText(tipInner:FindFirstChild("TipText") :: TextLabel)

	local status = uiFrame:FindFirstChild("Status") :: TextLabel
	Theme.updateText(status)

	for _, tab in self._tabs do
		tab:UpdateTheme()
	end

	if self._currentTabIndex ~= 0 then
		self._tabs[self._currentTabIndex].button:ColorSelected()
	end
end

local function Destroy(self: Ui)
	for _, tab in self._tabs do
		tab:Destroy()
	end
	self._studioThemeChanged:Disconnect()
	self._notificationClosed:Disconnect()
	self.instance:Destroy()
	table.clear(self :: any)
end

export type Ui = {
	_currentTabIndex: number,
	_notificationClosed: RBXScriptConnection,
	_studioThemeChanged: RBXScriptConnection,
	_tabs: { Tab.Tab },
	theme: ThemeManager,
	instance: Frame,
	CreateTab: typeof(CreateTab),
	CreateTip: typeof(CreateTip),
	Notify: typeof(Notify),
	SetStatus: typeof(SetStatus),
	UpdateTheme: typeof(UpdateTheme),
	Destroy: typeof(Destroy),
}

local function buildShell(parent: Instance): Frame
	local root = Instance.new("Frame")
	root.Name = "MainFrame"
	root.BorderSizePixel = 0
	root.Size = UDim2.fromScale(1, 1)
	Widgets.corner(root, 8)

	local topbar = Instance.new("Frame")
	topbar.Name = "Topbar"
	topbar.BorderSizePixel = 0
	topbar.Size = UDim2.new(1, 0, 0, 64)
	topbar.Parent = root

	local title = Instance.new("TextLabel")
	title.Name = "Title"
	title.BackgroundTransparency = 1
	title.Position = UDim2.fromOffset(12, 6)
	title.Size = UDim2.new(1, -24, 0, 22)
	title.Font = Enum.Font.GothamBold
	title.Text = TOPBAR_TITLE
	title.TextSize = 16
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.Parent = topbar

	local tabBar = Instance.new("ScrollingFrame")
	tabBar.Name = "Frame"
	tabBar.BackgroundTransparency = 1
	tabBar.BorderSizePixel = 0
	tabBar.Position = UDim2.fromOffset(8, 30)
	tabBar.Size = UDim2.new(1, -16, 0, 28)
	tabBar.AutomaticCanvasSize = Enum.AutomaticSize.X
	tabBar.CanvasSize = UDim2.new()
	tabBar.ScrollBarThickness = 0
	tabBar.ScrollingDirection = Enum.ScrollingDirection.X
	Widgets.list(tabBar, 4, Enum.FillDirection.Horizontal)
	tabBar.Parent = topbar

	local status = Instance.new("TextLabel")
	status.Name = "Status"
	status.BackgroundTransparency = 1
	status.Position = UDim2.new(0, 12, 0, 64)
	status.Size = UDim2.new(1, -24, 0, 20)
	status.Font = Enum.Font.GothamMedium
	status.Text = "Searching for Folk host..."
	status.TextSize = 12
	status.TextXAlignment = Enum.TextXAlignment.Left
	status.Parent = root

	local main = Instance.new("Frame")
	main.Name = "Main"
	main.BorderSizePixel = 0
	main.Position = UDim2.fromOffset(8, 88)
	main.Size = UDim2.new(1, -16, 1, -120)
	Widgets.corner(main, 8)
	main.Parent = root

	local tabs = Instance.new("Frame")
	tabs.Name = "Tabs"
	tabs.BackgroundTransparency = 1
	tabs.Size = UDim2.fromScale(1, 1)
	tabs.Parent = main

	local tip = Instance.new("Frame")
	tip.Name = "Tip"
	tip.Visible = false
	tip.BorderSizePixel = 0
	tip.AnchorPoint = Vector2.new(0, 1)
	tip.Position = UDim2.new(0, 8, 1, -8)
	tip.Size = UDim2.new(1, -16, 0, 24)
	Widgets.corner(tip, 6)
	tip.Parent = root

	local tipInner = Instance.new("Frame")
	tipInner.Name = "Frame"
	tipInner.BorderSizePixel = 0
	tipInner.Size = UDim2.fromScale(1, 1)
	Widgets.corner(tipInner, 6)
	tipInner.Parent = tip

	local tipText = Instance.new("TextLabel")
	tipText.Name = "TipText"
	tipText.BackgroundTransparency = 1
	tipText.Size = UDim2.fromScale(1, 1)
	tipText.Text = ""
	tipText.Parent = tipInner

	local notification = Instance.new("Frame")
	notification.Name = "Notification"
	notification.Visible = false
	notification.ZIndex = 20
	notification.AnchorPoint = Vector2.new(0.5, 0.5)
	notification.Position = UDim2.fromScale(0.5, 0.5)
	notification.Size = UDim2.fromOffset(320, 150)
	notification.BorderSizePixel = 0
	Widgets.corner(notification, 10)
	Widgets.stroke(notification, Color3.fromRGB(232, 168, 88), 1)
	notification.Parent = root

	local nTitle = Instance.new("TextLabel")
	nTitle.Name = "Title"
	nTitle.BackgroundTransparency = 1
	nTitle.Position = UDim2.fromOffset(16, 12)
	nTitle.Size = UDim2.new(1, -32, 0, 28)
	nTitle.TextXAlignment = Enum.TextXAlignment.Left
	nTitle.ZIndex = 21
	nTitle.Parent = notification

	local nDesc = Instance.new("TextLabel")
	nDesc.Name = "Description"
	nDesc.BackgroundTransparency = 1
	nDesc.Position = UDim2.fromOffset(16, 44)
	nDesc.Size = UDim2.new(1, -32, 0, 60)
	nDesc.TextWrapped = true
	nDesc.TextXAlignment = Enum.TextXAlignment.Left
	nDesc.TextYAlignment = Enum.TextYAlignment.Top
	nDesc.ZIndex = 21
	nDesc.Parent = notification

	local nClose = Instance.new("TextButton")
	nClose.Name = "Close"
	nClose.AutoButtonColor = false
	nClose.AnchorPoint = Vector2.new(1, 1)
	nClose.Position = UDim2.new(1, -12, 1, -12)
	nClose.Size = UDim2.fromOffset(80, 26)
	nClose.Text = "Close"
	nClose.ZIndex = 21
	nClose.BorderSizePixel = 0
	Widgets.corner(nClose, 6)
	nClose.Parent = notification

	root.Parent = parent
	return root
end

function UiLibrary.new(parent: Instance, plugin: Plugin): Ui
	local instance = buildShell(parent)
	local notificationFrame = instance:FindFirstChild("Notification") :: Frame

	Theme.init(plugin)

	local self: Ui
	self = {
		_currentTabIndex = 0,
		_notificationClosed = (notificationFrame:FindFirstChild("Close") :: TextButton).MouseButton1Down:Connect(function()
			notificationFrame.Visible = false
		end),
		_studioThemeChanged = settings().Studio.ThemeChanged:Connect(function()
			Theme.set(Theme.get().Id)
			self:UpdateTheme()
		end),
		_tabs = {},
		theme = Theme,
		instance = instance,
		CreateTab = CreateTab,
		CreateTip = CreateTip,
		Notify = Notify,
		SetStatus = SetStatus,
		UpdateTheme = UpdateTheme,
		Destroy = Destroy,
	}

	self:UpdateTheme()
	return self
end

return UiLibrary
