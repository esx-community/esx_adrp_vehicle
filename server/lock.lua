local playerKeys = {}

AddEventHandler('esx_adrp_vehicle:addKey', function(playerId, plate, vehicleLabel)
	local _,key = GetPlayerKeyByPlate(playerId, plate)

	if not key then
		table.insert(playerKeys[playerId], {
			vehicleLabel = vehicleLabel,
			plate = plate
		})
	end

	TriggerClientEvent('esx_adrp_vehicle:addKey', playerId, plate, vehicleLabel)
end)

RegisterNetEvent('esx_adrp_vehicle:dropKey')
AddEventHandler('esx_adrp_vehicle:dropKey', function(plate)
	DropPlayerKey(source, plate)
end)

AddEventHandler('esx_adrp_vehicle:dropTargetKey', function(playerId, plate)
	DropPlayerKey(playerId, plate)
end)

function DropPlayerKey(playerId, plate)
	if playerKeys[playerId] then
		for k,v in ipairs(playerKeys[playerId]) do
			if v.plate == plate then
				table.remove(playerKeys[playerId], k)
	
				break
			end
		end
	
		TriggerClientEvent('esx_adrp_vehicle:dropKey', playerId, plate)
	end
end

ESX.RegisterServerCallback('esx_adrp_vehicle:giveKey', function(source, cb, plate, targetId)
	local _,key = GetPlayerKeyByPlate(source, plate)
	local identifier = GetPlayerIdentifier(source, 0)

	if key and GetPlayerName(targetId) then
		local _, targetKey = GetPlayerKeyByPlate(targetId, plate)

		if not targetKey then
			cb(true)
			TriggerEvent('esx_adrp_vehicle:addKey', targetId, plate, key.vehicleLabel)
			TriggerClientEvent('esx:showNotification', targetId, _U('keychain_given_target', GetPlayerName(source), plate))
		else
			cb(false)
		end
	else
		cb(false)
		print(('esx_adrp_vehicle: %s attempted to give a key to a vehicle he doesn\'t have keys for'):format(identifier))
	end
end)

RegisterNetEvent('esx_adrp_vehicle:onToggleVehicleLock')
AddEventHandler('esx_adrp_vehicle:onToggleVehicleLock', function(plate)
	local _,key = GetPlayerKeyByPlate(source, plate)
	local identifier = GetPlayerIdentifier(source, 0)

	if key then
		TriggerClientEvent('esx_adrp_vehicle:onToggleVehicleLock', -1, plate, source)
	else
		print(('esx_adrp_vehicle: %s attempted to toggle an vehicle lock'):format(identifier))
	end
end)

function GetPlayerKeyByPlate(playerId, plate)
	if not playerKeys[playerId] then
		playerKeys[playerId] = {}
	end

	for k,v in ipairs(playerKeys[playerId]) do
		if v.plate == plate then
			return k, v
		end
	end
end
