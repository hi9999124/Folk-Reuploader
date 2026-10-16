--!strict
local UiLibrary = require("./Plugin/UiLibrary")
local App = require("./Plugin/App")

local RunService = game:GetService("RunService")

if not RunService:IsEdit() then
	return
end

local VERSION = script.Parent.Version.Value
local toolbar = plugin:CreateToolbar("Folk Reuploader")
local widget = plugin:CreateDockWidgetPluginGui(
	"FolkReuploader",
	DockWidgetPluginGuiInfo.new(Enum.InitialDockState.Float, true, false, 560, 420, 420, 320)
)

local toggleButton = toolbar:CreateButton("Folk", "Toggle Folk Reuploader", "rbxassetid://83178708216253")
toggleButton.Click:Connect(function()
	widget.Enabled = not widget.Enabled
end)

widget:GetPropertyChangedSignal("Enabled"):Connect(function()
	toggleButton:SetActive(widget.Enabled)
end)
widget.Title = `Folk Reuploader {VERSION}`

local defaults = {
	Port = 38073,
	ExportJSON = false,
	AutoConnect = true,
	StrVals = true,
	Scripts = true,
	NumVals = true,
	MeshParts = true,
	SpecialMeshes = true,
	CharacterMeshes = true,
}

for key, value in defaults do
	if plugin:GetSetting(key) == nil then
		plugin:SetSetting(key, value)
	end
end

local ui = UiLibrary.new(widget, plugin)
App.init(ui, plugin)

plugin.Unloading:Once(function()
	ui:Destroy()
end)
