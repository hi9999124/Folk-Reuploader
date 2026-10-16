--!strict
local Connection = require("../Connection")
local UiLibrary = require("../../UiLibrary")

local MarketplaceService = game:GetService("MarketplaceService")

return function(ui: UiLibrary.Ui, plugin: Plugin)
	local tab = ui:CreateTab("Studio")
	local statusLabel = tab:CreateLabel("Host: searching…")
	local placeLabel = tab:CreateLabel("Place: detecting…")
	local creatorLabel = tab:CreateLabel("Creator: detecting…")
	local userLabel = tab:CreateLabel("Account: waiting for Folk…")

	local function refreshPlace()
		local placeId = game.PlaceId
		local creatorId = game.CreatorId
		if placeId ~= 0 then
			placeLabel:ChangeText(`Place: {placeId}`)
			local creatorType = if game.CreatorType == Enum.CreatorType.Group then "Group" else "User"
			if creatorId ~= 0 then
				creatorLabel:ChangeText(`Creator: {creatorType} {creatorId}`)
			else
				local ok, info = pcall(MarketplaceService.GetProductInfo, MarketplaceService, placeId)
				if ok then
					local creator = (info :: any).Creator
					creatorLabel:ChangeText(`Creator: {creator.CreatorType} {creator.Id}`)
				end
			end
		else
			placeLabel:ChangeText("Place: unpublished — publish & reopen to auto-fill")
			creatorLabel:ChangeText("Creator: unknown until the place is published")
		end
	end

	refreshPlace()

	local function helloPayload(port: number): string
		return game:GetService("HttpService"):JSONEncode({
			pluginVersion = script.Parent.Parent.Parent.Parent.Version.Value,
			placeId = game.PlaceId,
			creatorId = game.CreatorId,
			isGroup = game.CreatorType == Enum.CreatorType.Group,
			placeName = game.Name,
			port = port,
		})
	end

	local function connect()
		local preferred = plugin:GetSetting("Port") or 38073
		local port, health = Connection.scan(preferred)
		if not port then
			statusLabel:ChangeText("Host: offline — start Folk Reuploader")
			ui:SetStatus("Folk host not found. Run the executable.", false)
			return
		end

		plugin:SetSetting("Port", port)
		local conn, _ = Connection.new(port)
		if not conn then
			statusLabel:ChangeText("Host: handshake failed")
			ui:SetStatus("Found a port but handshake failed.", false)
			return
		end

		conn:Hello(helloPayload(port))
		statusLabel:ChangeText(`Host: live on 127.0.0.1:{port}`)
		ui:SetStatus(`Connected to Folk · port {port}`, true)

		if health then
			local ok, decoded = pcall(game.GetService(game, "HttpService").JSONDecode, game:GetService("HttpService"), health)
			if ok and typeof(decoded) == "table" and (decoded :: any).user then
				userLabel:ChangeText(`Account: {(decoded :: any).user}`)
			end
		end

		conn.onDisconnect = function()
			statusLabel:ChangeText("Host: disconnected")
			ui:SetStatus("Disconnected from Folk host.", false)
		end
	end

	tab:CreateButton("Reconnect now", function()
		connect()
		refreshPlace()
	end)

	tab:CreateToggle("Auto-connect on open", function(state)
		plugin:SetSetting("AutoConnect", state)
	end, plugin:GetSetting("AutoConnect") ~= false)

	if plugin:GetSetting("AutoConnect") ~= false then
		task.spawn(connect)
		task.spawn(function()
			while true do
				task.wait(4)
				if plugin:GetSetting("AutoConnect") == false then
					continue
				end
				local port = plugin:GetSetting("Port") or 38073
				local ok = Connection.probe(port)
				if not ok then
					connect()
				else
					local live, _ = Connection.new(port)
					if live then
						live:Hello(helloPayload(port))
						live:Destroy()
					end
				end
			end
		end)
	end
end
