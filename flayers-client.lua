
_G.Flayers = {}
local flayers = _G.Flayers
local npt
local tooltips

flayers.cahedRegions = {}
flayers.regionHandles = {}

local isInsideFlayerRegion = false
local isShowingFlayer = false
local currentlyShowFlayerData

--executed on the resource load to make sure we have the flayers for
--where the player is spawned
local loadFlayersFirstRegion = function(taskObject)

    local regionName = flayers.npToolbox.GetBackgroundAreaName()
    --query the server for flayers on this region
    TriggerServerEvent("np-flayers:queryFlayersForRegion", regionName)
end

--triggered when the player change from a background region to another background region
local backgroundRegionChange = function(entered, regionObject)

    --check if the region exists, maybe the player character isn't in the game yet
    if (not regionObject) then
        return
    end

    --only want entered regions
    if (entered) then
        if (not flayers.cahedRegions[regionObject.name]) then
            --query the server for flayers on this region
            TriggerServerEvent("np-flayers:queryFlayersForRegion", regionObject.name)
        end
    end
end

--show flayer, called when the player is very near the flayer location
local showFlayer = function(flayerData)
    flayers.npTooltips.ClearTooltip()
    flayers.npTooltips.AddLine(" ")
    flayers.npTooltips.AddIcon(flayerData.img, false, 300, 400)

    --flayers.npTooltips.SetWorldLocation(flayerData.x, flayerData.y, flayerData.z)
    flayers.npTooltips.SetScreenLocation(.55, .35)

    flayers.npTooltips.SetTableCSS(
    {
        "padding: 0px;",
        "background-color: rgba(0, 0, 0, 0);",
        "border: 0px outset;",
		"padding-top: 0px;",
        "padding-bottom: 0px;",
        "border-color: rgba(0, 0, 0, 0);",
        "box-shadow: 0px 0px 0px #00000000;",
        "border-radius: 0px;",
    })

    flayers.npTooltips.ShowTooltip()
    currentlyShowFlayerData = flayerData
end

--callback for when the player enters the flayer region
local onEnterFlayerRegion = function(regionHandle, flayerData)
    isInsideFlayerRegion = true

    RequestStreamedTextureDict("mpleaderboard")
    local flayerLocation = vector3(flayerData.x, flayerData.y, flayerData.z)

    --check the distance
    Citizen.CreateThread(function()
        local DrawSprite = DrawSprite
        local GetEntityCoords = GetEntityCoords
        local GetHudScreenPositionFromWorldPosition = GetHudScreenPositionFromWorldPosition

        while(isInsideFlayerRegion) do

            --check if the player is near the flayer, otherwise it shows a faded white rectangle
            local v3PlayerLocation = GetEntityCoords(PlayerPedId())
            local distance = (v3PlayerLocation - flayerLocation)

            if (#distance < 1.3) then
                if (not isShowingFlayer) then
                    isShowingFlayer = true
                    --show the flayer and cancel the loop
                    showFlayer(flayerData)
                    return
                end
            end

            local onScreen, screenX, screenY = GetHudScreenPositionFromWorldPosition(flayerData.x, flayerData.y, flayerData.z)
            DrawSprite("mpleaderboard", "leaderboard_voteblank_icon", screenX, screenY, .06, .15, 0.0, 255, 255, 255, 107)

            Wait(0)
        end
    end)
end

local onLeaveFlayerRegion = function(regionHandle, flayerData)
    --hide the flayer
    flayers.npTooltips.HideTooltip()
    isInsideFlayerRegion = nil
    isShowingFlayer = nil
    currentlyShowFlayerData = nil
end

--creates a new region for a flayer region
local createNewFlayerRegion = function(flayerRegionName, flayerData)
    local squareSize = 4

    --create coords for the region
    local coords = {}
    for i = -1, 1 do
        local x, y = npt.ScaleWorldCoordsToGridCoords(flayerData.x+i, flayerData.y+i, squareSize)
        coords[x] = {y-1, y, y+1}
    end

    --create the region table
    local newRegion = {
        name = flayerRegionName,
        worldHeight = flayerData.z,
        regionHeight = 20,
        regionEnterCallback = onEnterFlayerRegion,
        regionLeaveCallback = onLeaveFlayerRegion,
        squareSize = squareSize,
        regionCoords = coords,
        payLoad = {flayerData},
    }
    local regionHandle = npt.CreateRegion(newRegion)
    flayers.regionHandles[flayerRegionName] = regionHandle
end

--receiving an answer from server from querying flayers in the current region
RegisterNetEvent("np-flayers:answerFlayersForRegion")
AddEventHandler("np-flayers:answerFlayersForRegion", function(flayersInRegion, regionName)
    if (not regionName) then
        return
    end

    --cache the result
    flayers.cahedRegions[regionName] = flayersInRegion

    --create flayer regions
    for flayerIndex = 1, #flayersInRegion do
        local flayerData = flayersInRegion[flayerIndex]

        local cid = flayerData.cid
        local id = flayerData.id --flayer unique identifier
        local region = flayerData.region
        local y = flayerData.y
        local x = flayerData.x
        local z = flayerData.z
        local img = flayerData.img
        local expire = flayerData.expire

        --check if the flayer region exists
        local flayerRegionName = "flayer" .. id
        if (not npt.RegionExists(flayerRegionName)) then
            createNewFlayerRegion(flayerRegionName, flayerData)
        end
    end
end)


--send to server a request to create a new flayer
local addNewFlayer = function(url, expirationTime)
    --get the location where the flayer is being placed
    local _, hit, endCoords, surfaceNormal, entityHit = flayers.npToolbox.CastRayFromCamera(200.0)
    if (not hit or hit == 0) then
        return
    end
    --get the background region
    local regionName = flayers.npToolbox.GetBackgroundAreaName()
    TriggerServerEvent("np-flayers:addFlayer", endCoords, url, expirationTime, regionName)
end

--send to js to hide the creation panel
local hideCreateFlayerPanel = function()
	SendNUIMessage(
		{
			type = "hidecreatepanel",
		}
	)
    SetNuiFocus(false)
end

--callbacks from the javascript page
RegisterNUICallback("addnewflayer", function(data)
    local url = data.url
    local expirationTime = data.expirationTime

    hideCreateFlayerPanel()

    if (url:len() < 5) then
        return
    end

    addNewFlayer(url, expirationTime)
end)

RegisterNUICallback("cancelnewflayer", function(data)
    hideCreateFlayerPanel()
end)


--command /flayeradd
RegisterNetEvent("np-flayer:addFlayerCommand")
AddEventHandler("np-flayer:addFlayerCommand", function(source, args)
    --debug: test get regions for a region
        --local regionName = flayers.npToolbox.GetBackgroundAreaName()
        --TriggerServerEvent("np-flayers:queryFlayersForRegion", regionName)
        --if true then return end

    --debug: test add a new flayer at the player view point
        --addNewFlayer("www.site.com", 30)
        --if true then return end

	SendNUIMessage(
		{
			type = "showcreatepanel",
		}
	)
    SetNuiFocus(true, true)
end)

--command /flayerremove
RegisterNetEvent("np-flayer:removeFlayerCommand")
AddEventHandler("np-flayer:removeFlayerCommand", function(source, args)
    --check is there's a flayer in the player screen
    if (currentlyShowFlayerData) then
        local flayerId = currentlyShowFlayerData.id
        TriggerServerEvent("np-flayers:removeFlayer", flayerId, currentlyShowFlayerData.region)

        --remove the flayer from cache
        local regionCache = flayers.cahedRegions[currentlyShowFlayerData.region]
        if (regionCache) then
            for i = 1, #regionCache do
                local flayerObject = regionCache[i]
                if (flayerObject.id == flayerId) then
                    --remove from cache
                    table.remove(regionCache, i)

                    --remove the region
                    local flayerRegionName = "flayer" .. flayerId
                    local regionHandle = flayers.regionHandles[flayerRegionName] --probably is the background region
                    npt.DeleteRegion(regionHandle, true)
                    break
                end
            end
        end

        --remove the flayer from the screen
        onLeaveFlayerRegion()        
    end
end)

--initialize
Citizen.CreateThread(function()
	Wait(200)
	--get the toolbox
    npt = exports["np-toolbox"]:GetNoPixelToolbox()
    tooltips = exports["np-tooltips"]:GetTooltip()
    
    --cache the toolbox and tooltips
    flayers.npToolbox = npt
    flayers.npTooltips = tooltips

    --register to receive background regions event
    npt.RegisterBackgroundAreaCallback(backgroundRegionChange)

    --when the player enters the game
    --ocal getFirstRegion = npt.CreateTask(locationTaskFunc, CONST_CHECK_LOCATION_INTERVAL, false, true, false, false, "Location Manager")
    --loadFlayersFirstRegion()
end)
