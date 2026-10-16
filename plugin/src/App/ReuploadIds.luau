--!strict
local AssetIdFilter = require("./AssetIdFilter")
local Connection = require("./Connection")
local retry = require("./Retry")
local StatusCodes = require("./StatusCodes")
local UiLibrary = require("../UiLibrary")

local MarketplaceService = game:GetService("MarketplaceService")
local ScriptEditorService = game:GetService("ScriptEditorService")
local HttpService = game:GetService("HttpService")

local currentVersion = script.Parent.Parent.Parent.Version.Value
local busy = false

type ProductInfo = {
    AssetTypeId: number,
    TargetId: number,
    IsNew: boolean,
    Updated: string, -- ISO format
    AssetId: number,
    ProductId: number,
    MinimumMembershipLevel: number,
    Created: string, -- ISO format
    Creator: {
        Name: string,
        CreatorTargetId: number,
        Id: number,
        HasVerifiedBadge: boolean,
        CreatorType: string
    },
    IsLimited: boolean,
    ContentRatingTypeId: number,
    Sales: number,
    IsPublicDomain: boolean,
    Name: string,
    IsForSale: boolean,
    Description: string,
    IconImageAssetId: number,
    IsLimitedUnique: boolean
}

type Request = {
	placeId: number,         
	creatorId: number,       
	ids: { number },             
	defaultPlaceIds: { number }, 
	pluginVersion: string,   
	assetType: string,       
	exportJson: boolean,     
	isGroup: boolean     
}

local function scriptInjectionEnabled()
    local testScript = Instance.new("Script")
	local success = pcall(ScriptEditorService.UpdateSourceAsync, ScriptEditorService, testScript, function() 
		return "" 
	end)
	
	testScript:Destroy()
	return success
end

function getGameInfo(): (boolean, number, number)
    local creatorId, placeId = game.CreatorId, game.PlaceId

    if placeId == 0 then
        return false, creatorId, placeId 
    end

    if creatorId ~= 0 then
        local isGroup =  game.CreatorType == Enum.CreatorType.Group
        return isGroup, creatorId, placeId
    end

    local success, result = retry(3, MarketplaceService.GetProductInfo, MarketplaceService, placeId)
    if not success then
        return false, creatorId, placeId
    end

    local creatorInfo = (result :: ProductInfo).Creator
    local isGroup = creatorInfo.CreatorType == "Group"
    return isGroup, creatorInfo.CreatorTargetId, placeId
end

return function(plugin: Plugin, ui: UiLibrary.Ui, filterOptions: AssetIdFilter.FilterOptions, assetType: "Animation" | "Sound" | "Mesh", placeArray: { number }?)
    if busy then
        ui:Notify("Notification", "Plugin is busy.")
        return 
    end
    busy = true

    if not scriptInjectionEnabled() then
        ui:Notify("Notification", "Plugin needs script injection permission.")
        busy = false
        return
    end

    local isGroup, creatorId, placeId = getGameInfo()
    if placeId == 0 then
        ui:Notify("Notification", "Game needs to be published. Restart place after publishing.")
        busy = false
        return
    elseif creatorId == 0 then
        ui:Notify("Notification", "Failed to get place info. Try again or restart the place.")
        busy = false
        return
    end
    
    local filteredIds = AssetIdFilter.filterInstances(filterOptions)
    if next(filteredIds) == nil then
        ui:Notify("Notification", "No ids found.")
        busy = false
        return
    end

    local port = plugin:GetSetting("Port")
    if not Connection.probe(port) then
        local found = Connection.scan(port)
        if found then
            port = found
            plugin:SetSetting("Port", port)
        end
    end

    local connection, response = Connection.new(port)
    if not connection then
        ui:Notify("Folk", "Unable to reach Folk. Start the executable — it will auto-connect to Studio.")
        busy = false
        return
    end
    connection:Hello(HttpService:JSONEncode({
        pluginVersion = currentVersion,
        placeId = placeId,
        creatorId = creatorId,
        isGroup = isGroup,
        placeName = game.Name,
        port = port,
    }))

    local function onDataRecieved(data: string)
        local success, result = pcall(HttpService.JSONDecode, HttpService, data)
        if not success then
            if data ~= "done" then return end
            
            ui:Notify("Folk", "Finished reuploading all ids.")
            busy = false
            connection:Destroy()
            return
        end

        if #(result :: any) == 0 then return end
        AssetIdFilter.replaceIds(filteredIds, result :: any)
        warn(`Replaced {#(result :: any)} ids`)
    end

    connection.onDataRecieved = onDataRecieved
    connection.onDisconnect = function()
        ui:Notify("Folk", "Disconnected from Folk host. It will auto-reconnect.")
        busy = false
    end

    local idArray = AssetIdFilter.getIdArray(filteredIds)
    local request: Request = {
        pluginVersion = currentVersion,
        creatorId = creatorId,
        isGroup = isGroup,
        assetType = assetType,
        ids = idArray,
        placeId = placeId,
        defaultPlaceIds = placeArray or {},
        exportJson = plugin:GetSetting("ExportJSON")
    }
    
    local success, statusCode = connection:Send("/v1/reupload", HttpService:JSONEncode(request))
    if not success then
        success, statusCode = connection:Send("/reupload", HttpService:JSONEncode(request))
    end
    if not success then
        local message: string = (StatusCodes :: any)[statusCode] or ("Unable to send data to localhost.\n" .. statusCode)
        ui:Notify("Notification", message)

        busy = false
        connection:Destroy()
        return
    end

    ui:Notify("Notification", `Sent {#idArray} ids to localhost.`)

    if response then
        onDataRecieved(response)
    end
end
