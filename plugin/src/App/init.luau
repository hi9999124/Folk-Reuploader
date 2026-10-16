--!strict
local App = {}

local UiLibrary = require("./UiLibrary")

local currentVersion = script.Parent.Parent.Version.Value
local tabOrder = {
	"ConnectionHub",
	"Animation",
	"Sound",
	"Mesh",
	"Replace",
	"Filter",
	"Themes",
	"Settings",
}

function App.init(ui: UiLibrary.Ui, plugin: Plugin)
	for _, tabName in tabOrder do
		local tab = script.Tabs:FindFirstChild(tabName)
		assert(tab, "tab not found")
		task.spawn(require(tab), ui, plugin)
	end

	ui:SetStatus(`Folk {currentVersion} · waiting for host`, false)
end

return App
