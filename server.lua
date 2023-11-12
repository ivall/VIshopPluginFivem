prefix = '[VIshopPlugin] '
domain = 'https://dev123.vishop.pl'

FIL            = {}
FIL.MySQLReady  = false

MySQL.ready(function()
    FIL.MySQLReady = true
end)

AddEventHandler('playerConnecting', function(name, setCallback, deferrals)
    FIL.PlayerConnecting(source, setCallback, deferrals)
end)

FIL.PlayerConnecting = function(playerId, setCallback, deferrals)
    local mySqlState = FIL.MySQLReady

    deferrals.defer()
    Citizen.Wait(100)

    if (not mySqlState) then
        deferrals.update(prefix..'Waiting for database connection...')
    end

    while not FIL.MySQLReady do
        Citizen.Wait(10)
    end

    if (FIL.MySQLReady and not mySqlState) then
        Citizen.Wait(100)
    end

    local name = GetPlayerName(playerId) or 'Unknown'
    local identifiers, steamIdentifier = GetPlayerIdentifiers(playerId) or {}

    local license = nil

    for _, identifier in pairs(identifiers) do
        if (string.match(string.lower(identifier), 'steam:')) then
            steamIdentifier = identifier
        elseif (string.match(string.lower(identifier), 'license:')) then
            license = identifier
        end
    end

    if (steamIdentifier == nil or steamIdentifier == '' or steamIdentifier == 'none') then
        deferrals.done()
        return
    end

    local identifiersExists = false

    local queryParams = {
        ['@identifier'] = steamIdentifier
    }

    local query = 'SELECT COUNT(*) AS `count` FROM `user_identifiers` WHERE `identifier` = @identifier'

    if (license == nil) then
        query = query .. ' AND `license` IS NULL'
    else
        query = query .. ' AND `license` = @license'
        queryParams['license'] = license
    end

    MySQL.Async.fetchAll(query, queryParams, function(results)
        if (results ~= nil and #results > 0) then
            identifiersExists = tonumber(results[1].count) > 0
        end

        if (not identifiersExists) then
            MySQL.Async.execute("INSERT INTO `user_identifiers` (`id`, `identifier`, `name`, `license`, `date`, `online`) VALUES (NULL, @identifier, @name, @license, CURRENT_TIMESTAMP, 1)", {
                ['@identifier'] = steamIdentifier,
                ['@name'] = name,
                ['@license'] = license,
            })
        else
            MySQL.Async.execute("UPDATE `user_identifiers` SET `name` = @name, `date` = CURRENT_TIMESTAMP, `online` = 1 WHERE `identifier` = @identifier AND `license` = @license", {
                ['@identifier'] = steamIdentifier,
                ['@name'] = name,
                ['@license'] = license,
            })
        end

        Citizen.Wait(100)
        deferrals.done()
    end)
end

AddEventHandler('playerDropped', function (reason)
    local steamid  = nil
    local license  = nil
    for k,v in pairs(GetPlayerIdentifiers(source))do
      if string.sub(v, 1, string.len("steam:")) == "steam:" then
        steamid = v
      elseif string.sub(v, 1, string.len("license:")) == "license:" then
        license = v
      end
    end
    MySQL.Async.execute("UPDATE `user_identifiers` SET `online` = 0 WHERE `identifier` = @identifier AND `license` = @license", {
        ['@identifier'] = steamid,
        ['@license'] = license,
    })
end)

CreateThread(function()
    while true do
        getOrders()
        Wait(30000)  -- zmiana tej wartosci = automatyczna blokada sklepu
    end
end)

function getOrders ()
    PerformHttpRequest(domain.."/panel/shops/"..Config.shopId.."/servers/"..Config.serverId.."/payments/?status=executing", function (statusCode, resultData, resultHeaders)
      orders = json.decode(resultData)
      for v, order in pairs(orders) do
        local steamid = string.format("steam:%x", math.tointeger(order['steam_uid']))
        if order["product"]["require_player_online"] then
            local isOnline = MySQL.Sync.fetchScalar("SELECT online FROM user_identifiers WHERE identifier = @steamid", {
                ['@steamid'] = steamid
            })
            if not isOnline then
                goto continue
            end
        end
        print(prefix.."Wykonywanie zamówienia "..order["id"])
        for v, command in pairs(order["product"]["commands"]) do
            command = string.gsub(command, "{STEAMID}", steamid)
            command = string.gsub(command, "{NICK}", order['player'])
            if string.find(command, "{LICENSEID") then
                local licenseid = MySQL.Sync.fetchScalar("SELECT license FROM user_identifiers WHERE identifier = @steamid", {
                    ['@steamid'] = steamid
                })
                command = string.gsub(command, "{LICENSEID}", licenseid)
            end
            print(prefix.."Wykonywanie komendy >> "..command)
            ExecuteCommand(command)
        end
        orderExecuted(order["id"])
        ::continue::
      end
    end, "GET", "", {Authorization = Config.apiKey})
end

function orderExecuted (orderId)
    PerformHttpRequest(domain.."/panel/shops/"..Config.shopId.."/servers/"..Config.serverId.."/payments/"..orderId.."/", function (statusCode, resultData, resultHeaders)
        print(prefix.."Wykonano zamówienie "..orderId)
    end, "PUT", "", {Authorization = Config.apiKey})
end