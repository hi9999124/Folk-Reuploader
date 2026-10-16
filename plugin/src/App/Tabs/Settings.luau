--!strict
local Connection = require("../Connection")
local UiLibrary = require("../../UiLibrary")

return function(ui: UiLibrary.Ui, plugin: Plugin)
	local tab = ui:CreateTab("Settings")
	tab:CreateLabel("Ports, export, and autofill. Folk writes these when Studio or the host already knows them.")

	local split = tab:CreateSplit()
	local portInput
	portInput = split:CreateInput("Port: " .. tostring(plugin:GetSetting("Port")), function(input)
		local newPort = tonumber(input)
		if not newPort then
			return
		end
		if newPort < 1024 or newPort > 49151 then
			ui:Notify("Folk", "Port has to be between 1024-49151.")
			return
		end
		plugin:SetSetting("Port", newPort)
		portInput.instance.TextBox.PlaceholderText = "Port: " .. newPort
	end)
	split:CreateToggle("Export JSON when done", function(state)
		plugin:SetSetting("ExportJSON", state)
	end, plugin:GetSetting("ExportJSON"))

	tab:CreateButton("Detect Folk host", function()
		local port, health = Connection.scan(plugin:GetSetting("Port") or 38073)
		if not port then
			ui:Notify("Folk", "No Folk host found. Start the executable first.")
			return
		end
		plugin:SetSetting("Port", port)
		portInput.instance.TextBox.PlaceholderText = "Port: " .. port
		local extra = ""
		local ok, decoded = pcall(game:GetService("HttpService").JSONDecode, game:GetService("HttpService"), health or "")
		if ok and typeof(decoded) == "table" and (decoded :: any).user then
			extra = `\nSigned in as {(decoded :: any).user}`
		end
		ui:Notify("Folk", `Auto-filled port {port}.{extra}`)
		ui:SetStatus(`Connected to Folk · port {port}`, true)
	end)
end
