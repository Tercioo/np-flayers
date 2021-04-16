
--SERVER script of np-flayers

_G.Flayers = {}
local flayers = _G.Flayers
local npt
flayers.flayersCache = {
    currentId = 1
}

--delete expired flayers
local doCleanup = function()
    local query = [=[
        DELETE FROM `flayers` WHERE EXISTS(SELECT * FROM `flayers` WHERE `expire` < UNIX_TIMESTAMP())
    ]=]
    npt.SQLExecute(query, {}, nil, GetCurrentResourceName())
end

flayers.sqlResultCallback = function(sourceId, regionName, queryResult)
    local flayersInRegion = queryResult
    
    --cache the result
    if (type(flayersInRegion) == "table") then
        flayers.flayersCache[regionName] = flayersInRegion
    end

    --send the result to client
    if (#flayersInRegion > 0) then
        TriggerClientEvent("np-flayers:answerFlayersForRegion", sourceId, flayersInRegion, regionName)
    end
end

--RPCs
local clientRequestedFlayersForRegion = function(regionName)
    --check if the region is in the cache
    local flayersInRegion = flayers.flayersCache[regionName]
    if (flayersInRegion) then
        return TriggerClientEvent("np-flayers:answerFlayersForRegion", source, flayersInRegion, regionName)
    end

    --create a query
    local query = [=[
        SELECT * FROM flayers
        WHERE region = "@region"
    ]=]
    query = query:gsub("@region", regionName)

    --create the callback function with the sourceId
    local func = [=[
        return function(queryResult)
            local sourceId = @source
            local regionName = "@regionName"
            local funcCallback = _G.Flayers["sqlResultCallback"]
            return funcCallback(sourceId, regionName, queryResult)
        end
    ]=]

    func = func:gsub("@source", source)
    func = func:gsub("@regionName", regionName)
    func = load(func)
    func = func()

    --send the query
    npt.SQLFetch(query, {}, func, resourceName)
end

--client is requesting flayers on a region
RegisterNetEvent("np-flayers:queryFlayersForRegion")
AddEventHandler("np-flayers:queryFlayersForRegion", clientRequestedFlayersForRegion)

--callback from sql when the data has been inserted
local newFlayerAdded = function(source, id, url, location, cid, expirationTime, regionName)
    --create a flayer table identical to the returned from the sql query clientRequestedFlayersForRegion()
    local flayerObject = {
        cid = cid,
        id = id,
        region = regionName,
        y = location.y,
        x = location.x,
        z = location.z,
        img = url,
        expire = expirationTime,
    }

    --send the new flayer for all players in the region
    for playerServerId in pairs (npt.GetAllPlayersInRegion(regionName)) do
        TriggerClientEvent("np-flayers:answerFlayersForRegion", playerServerId, {flayerObject}, regionName)
    end
end

--player sent an add banner request
RegisterNetEvent("np-flayers:addFlayer")
AddEventHandler("np-flayers:addFlayer", function(location, url, expirationTime, regionName)
    local source = source

    if (type(location) ~= "vector3") then
        return

    elseif (type(url) ~= "string") then
        return

    elseif (type(expirationTime) ~= "number") then
        return

    elseif (type(regionName) ~= "string") then
        return
    end

    --get a player identifier
    local identifier = GetPlayerIdentifiers(source)[1]
    local cid = identifier:gsub(".*:", "")
    cid = 0 --database expect a number, need to change later

    --build the query
    local query = [=[
        INSERT INTO flayers 
        (img, x, y, z, cid, expire, region) 
        VALUES 
        ("@url", @location, "@cid", @expire, "@region");
        SELECT LAST_INSERT_ID()
    ]=]

    expirationTime = os.time() + expirationTime

    --add the values to query
    query = query:gsub("@url", url)
    query = query:gsub("@location", location.x .. ", " .. location.y .. ", " .. location.z)
    query = query:gsub("@cid", cid)
    query = query:gsub("@expire", expirationTime)
    query = query:gsub("@region", regionName)

    local resourceName = GetCurrentResourceName()

    MySQL.ready(function()
        MySQL.Async.fetchAll(query, {}, function(result)
            local lastId = result[2] and result[2][1] and result[2][1]["LAST_INSERT_ID()"]
            if (lastId) then
                newFlayerAdded(source, lastId, url, location, cid, expirationTime, regionName)
            end
        end)
    end)

    --send to all clients the new flayer location
    local textToLog = npt.FormatTextToLog(url, location.x, location.y, location.z, cid, expirationTime, regionName, lastId)
    npt.LogToFile(resourceName, "added a new flayer", cid, textToLog)
end)

--the client sent the data of the flayer to be deleted
RegisterNetEvent("np-flayers:removeFlayer")
AddEventHandler("np-flayers:removeFlayer", function(flayerId, regionName)
    MySQL.ready(function()
        MySQL.Async.execute("DELETE FROM `flayers` WHERE id = " .. flayerId)
    end)

    local regionCache = flayers.flayersCache[regionName]
    
    if (regionCache) then
        for i = 1, #regionCache do
            local flayerObject = regionCache[i]
            if (flayerId == flayerObject.id) then
                table.remove(regionCache, i)
                break
            end
        end
    end
end)

--slash commands
RegisterCommand("flayeradd", function(source, args)
	if (IsPlayerAceAllowed(source, "command")) then
		TriggerClientEvent("np-flayer:addFlayerCommand", source, source, args)
	end
end)
RegisterCommand("flayerremove", function(source, args)
	if (IsPlayerAceAllowed(source, "command")) then
        --send to client to know which flayer is currently shown in the screen
        --it'll send back the flayer Id with np-flayers:removeFlayer
        TriggerClientEvent("np-flayer:removeFlayerCommand", source, source, args)
	end
end)

--initialize
Citizen.CreateThread(function()
    Wait(100)
    npt = exports["np-toolbox"]:GetNoPixelToolbox()

    --clear expire flayers
    while (1) do
        doCleanup()
        Wait(600)
    end
end)

