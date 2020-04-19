local keyChain = {}
local coolDown = false

Citizen.CreateThread(function()
	while true do
		Citizen.Wait(0)
		local playerPed = PlayerPedId()
		local inVehicle = IsPedInAnyVehicle(playerPed, true)

		if IsControlJustReleased(0, 303) and IsInputDisabled(0) then
			TriggerEvent('esx_adrp_vehicle:toggleVehicleLock')
		end

		if inVehicle then
			local vehicle = GetVehiclePedIsIn(playerPed, false)

			if GetVehicleDoorLockStatus(vehicle) == 4 then
				DisableControlAction(0, 75, true)  -- Disable exit vehicle
				DisableControlAction(27, 75, true) -- Disable exit vehicle
			end
		end
	end
end)

Citizen.CreateThread(function()
	while true do
		Citizen.Wait(0)
		local playerPed = PlayerPedId()
		local vehicle = GetVehiclePedIsTryingToEnter(playerPed)

		if DoesEntityExist(vehicle) then
			local lockStatus = GetVehicleDoorLockStatus(vehicle)

			if lockStatus == 4 then
				ClearPedTasks(playerPed)
			end
		end
	end
end)

AddEventHandler('esx_adrp_vehicle:openKeyChainMenu', function()
	OpenKeyChainMenu()
end)

RegisterNetEvent('esx_adrp_vehicle:addKey')
AddEventHandler('esx_adrp_vehicle:addKey', function(plate, vehicleLabel)
	table.insert(keyChain, {
		vehicleLabel = vehicleLabel,
		plate = plate
	})
end)

RegisterNetEvent('esx_adrp_vehicle:dropKey')
AddEventHandler('esx_adrp_vehicle:dropKey', function(plate)
	for k,v in ipairs(keyChain) do
		if v.plate == plate then
			table.remove(keyChain, k)
			break
		end
	end
end)

AddEventHandler('esx_adrp_vehicle:toggleVehicleLock', function()
	local playerPed = PlayerPedId()
	local inVehicle, lockable, vehicle, plate, lockStatus = IsPedInAnyVehicle(playerPed, false)

	if coolDown then
		return
	end

	coolDown = true

	if inVehicle then
		vehicle = GetVehiclePedIsIn(playerPed, false)
	else
		vehicle = ESX.Game.GetVehicleInDirection()
	end

	if DoesEntityExist(vehicle) then
		plate = ESX.Math.Trim(GetVehicleNumberPlateText(vehicle))
		lockStatus = GetVehicleDoorLockStatus(vehicle)
		lockable = DoesVehicleHaveDoor(vehicle, 0)

		if IsVehicleDoorDamaged(vehicle, 0) then
			lockable = false
		end
	end

	if lockable then
		if HasVehicleKeys(plate) then
			TriggerServerEvent('esx_adrp_vehicle:onToggleVehicleLock', plate)
		end
	end

	Citizen.Wait(700)
	coolDown = false
end)

RegisterNetEvent('esx_adrp_vehicle:onToggleVehicleLock')
AddEventHandler('esx_adrp_vehicle:onToggleVehicleLock', function(plate, targetId)
	targetId = GetPlayerFromServerId(targetId)
	local targetCoords = GetEntityCoords(GetPlayerPed(targetId))
	local vehicles, foundVehicle = ESX.Game.GetVehiclesInArea(targetCoords, 10.0)

	for k,v in ipairs(vehicles) do
		local vehiclePlate = ESX.Math.Trim(GetVehicleNumberPlateText(v))

		if vehiclePlate == plate then
			foundVehicle = v
			break
		end
	end

	if foundVehicle then
		local lockStatus = GetVehicleDoorLockStatus(foundVehicle)

		if lockStatus == 1 then -- was unlocked
			SetVehicleDoorsLocked(foundVehicle, 4)
			PlayVehicleDoorCloseSound(foundVehicle, 1)
			SetVehicleDoorShut(foundVehicle, 0, true)

			if targetId == PlayerId() then
				ESX.ShowNotification('Your vehicle has been locked')
			end
		elseif lockStatus == 4 then -- was locked
			SetVehicleDoorsLocked(foundVehicle, 1)
			PlayVehicleDoorOpenSound(foundVehicle, 0)

			if targetId == PlayerId() then
				ESX.ShowNotification('Your vehicle has been unlocked')
			end
		end
	end
end)

function HasVehicleKeys(plate)
	for k,v in ipairs(keyChain) do
		if v.plate == plate then
			return true
		end
	end

	return false
end

function OpenKeyChainMenu()
	local elements = {}

	for k,v in ipairs(keyChain) do
		table.insert(elements, {
			label = ('%s - %s'):format(v.vehicleLabel, v.plate),
			plate = v.plate
		})
	end

	ESX.UI.Menu.Open('default', GetCurrentResourceName(), 'keychain_menu', {
		title    = _U('keychain_title'),
		align    = 'bottom-right',
		elements = elements
	}, function(data, menu)
		OpenKeyChainActions(data.current.plate)
	end, function(data, menu)
		menu.close()
	end)
end

function OpenKeyChainActions(plate)
	ESX.UI.Menu.Open('default', GetCurrentResourceName(), 'keychain_actions', {
		title    = _U('keychain_actions_title'),
		align    = 'bottom-right',
		elements = {
			{label = _U('keychain_givekey'), action = 'give_key'},
			{label = _U('keychain_dropkey'), action = 'drop_key'}
	}}, function(data, menu)
		if data.current.action == 'give_key' then
			OpenGiveKeyMenu(plate)
		elseif data.current.action == 'drop_key' then
			TriggerServerEvent('esx_adrp_vehicle:dropKey', plate)

			Citizen.Wait(300)
			ESX.ShowNotification(_U('keychain_dropped'))
			ESX.UI.Menu.CloseAll()
			OpenKeyChainMenu()
		end
	end, function(data, menu)
		menu.close()
	end)
end

function OpenGiveKeyMenu(plate)
	local elements, playerPed = {}, PlayerPedId()
	local players = ESX.Game.GetPlayersInArea(GetEntityCoords(playerPed), 3.0)

	for k,v in ipairs(players) do
		if not IsPedDeadOrDying(GetPlayerPed(v), true) and v ~= PlayerId() then
			table.insert(elements, {
				label  = GetPlayerName(v),
				player = v
			})
		end
	end

	if #elements == 0 then
		ESX.ShowNotification(_U('keychain_give_nonearby'))
		return
	end

	ESX.UI.Menu.Open('default', GetCurrentResourceName(), 'keychain_give', {
		title    = _U('keychain_give_title'),
		align    = 'bottom-right',
		elements = elements
	}, function(data, menu)
		players, foundPlayer = ESX.Game.GetPlayersInArea(GetEntityCoords(playerPed), 3.0), false

		for k,v in ipairs(players) do
			if data.current.player == v then
				foundPlayer = v
				break
			end
		end

		if foundPlayer then
			ESX.TriggerServerCallback('esx_adrp_vehicle:giveKey', function(success)
				if success then
					ESX.ShowNotification(_U('keychain_given', plate))
					ESX.UI.Menu.CloseAll()
					OpenKeyChainMenu()
				else
					ESX.ShowNotification(_U('keychain_notgiven'))
				end
			end, plate, GetPlayerServerId(data.current.player))
		else
			ESX.ShowNotification(_U('keychain_give_playerlost'))
			menu.close()
		end

	end, function(data, menu)
		menu.close()
	end)
end
