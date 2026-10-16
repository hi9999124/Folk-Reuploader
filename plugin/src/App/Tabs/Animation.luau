--!strict
local getFilterOptions = require("../GetFilterOptions")
local reuploadIds = require("../ReuploadIds")
local UiLibrary = require("../../UiLibrary")

local Selection = game:GetService("Selection")

return function(ui: UiLibrary.Ui, plugin: Plugin)
	local tab = ui:CreateTab("Animation")
	tab:CreateLabel("Scans the place, sends ids to Folk, then remaps animations in Studio.")

	tab:CreateButton("Reupload", function()
		local filter = getFilterOptions(plugin, game:GetDescendants())
		table.insert(filter.WhitelistedInstances, "Animation")
		reuploadIds(plugin, ui, filter, "Animation", _G.getPlaceList()) -- forgive me
	end)
	
	tab:CreateButton("Reupload Selected", function()
		local filter =  {
			WhitelistedInstances = { "Animation", "StringValue", "NumberValue", "IntValue", "LuaSourceContainer" },
			Instances = Selection:Get()
		}

		reuploadIds(plugin, ui, filter, "Animation", _G.getPlaceList()) -- forgive me
	end)
end
