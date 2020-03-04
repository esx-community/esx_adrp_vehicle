local isUsingTrunk = false

AddEventHandler('esx_adrp_vehicle:openTrunk', function()
	if not isUsingTrunk then
		OpenNearbyVehicleTrunk()
	end
end)

Citizen.CreateThread(function()
	while true do
		Citizen.Wait(0)
		if IsControlJustReleased(0, 47) and IsInputDisabled(0) then
			OpenNearbyVehicleTrunk()
		end
	end
end)

function OpenNearbyVehicleTrunk()
	local vehicle = ESX.Game.GetVehicleInDirection()
	local playerPed = PlayerPedId()

	if not IsPedOnFoot(playerPed) or IsPedDeadOrDying(playerPed, true) then
		return
	end

	if vehicle and DoesEntityExist(vehicle) then
		local lockStatus, plate, class = GetVehicleDoorLockStatus(vehicle), ESX.Math.Trim(GetVehicleNumberPlateText(vehicle)), GetVehicleClass(vehicle)

		if lockStatus ~= 1 then
			ESX.ShowNotification(_U('trunk_locked'))
			return
		end

		ESX.TriggerServerCallback('esx_adrp_vehicle:attemptOpenTrunk', function(success)
			if success then
				SetVehicleDoorOpen(vehicle, 5, false, false)
				OpenVehicleTrunk(plate)
				StartTrackVehicle(vehicle, plate)
			else
				ESX.ShowNotification(_U('trunk_busy'))
			end
		end, plate, class)
	end
end

function StartTrackVehicle(vehicle, plate)
	Citizen.CreateThread(function()
		local playerPed = PlayerPedId()
		local playerCoords, vehicleCoords = GetEntityCoords(playerPed), GetEntityCoords(vehicle)
		local distance = #(playerCoords - vehicleCoords)
		local timeout = 0

		while distance < 4 and isUsingTrunk and not IsPedDeadOrDying(playerPed, true) and IsPedOnFoot(playerPed) do
			Citizen.Wait(0)

			playerCoords, vehicleCoords = GetEntityCoords(playerPed), GetEntityCoords(vehicle)
			distance = #(playerCoords - vehicleCoords)

			DisableAllControlActions(0)

			EnableControlAction(0, 27, true)
			EnableControlAction(0, 173, true)
			EnableControlAction(0, 174, true)
			EnableControlAction(0, 175, true)
			EnableControlAction(0, 18, true)
			EnableControlAction(0, 177, true)

			local menuMain = ESX.UI.Menu.IsOpen('default', GetCurrentResourceName(), 'trunk_menu')
			local menuTake = ESX.UI.Menu.IsOpen('default', GetCurrentResourceName(), 'trunk_take')
			local menuTakeDialog = ESX.UI.Menu.IsOpen('dialog', GetCurrentResourceName(), 'trunk_take_dialog')
			local menuDeposit = ESX.UI.Menu.IsOpen('default', GetCurrentResourceName(), 'trunk_deposit')
			local menuDepositDialog = ESX.UI.Menu.IsOpen('dialog', GetCurrentResourceName(), 'trunk_deposit_dialog')
			
			if not menuMain and not menuTake and not menuTakeDialog and not menuDeposit and not menuDepositDialog then
				timeout = timeout + 1

				if timeout > 500 then -- Long timeout because of possible server being slow, menus open async!
					ESX.ShowNotification(_U('error_left_menu'))
					return
				end
			elseif timeout > 0 then
				timeout = 0
			end
		end

		ESX.UI.Menu.CloseAll()

		ESX.TriggerServerCallback('esx_adrp_vehicle:leaveTrunk', function(success)
			if success then
				SetVehicleDoorShut(vehicle, 5, false)
			end
		end, plate)
	end)
end

function OpenVehicleTrunk(plate)
	isUsingTrunk = true

	ESX.UI.Menu.Open('default', GetCurrentResourceName(), 'trunk_menu', {
		title    = _U('trunk_title'),
		align    = 'top-left',
		elements = {
			{label = _U('trunk_take'), menu = 'take'},
			{label = _U('trunk_deposit'), menu = 'deposit'}
		}
	}, function(data, menu)
		if data.current.menu == 'take' then
			OpenTakeMenu(plate)
		elseif data.current.menu == 'deposit' then
			ESX.TriggerServerCallback('esx_adrp_vehicle:getTrunkWeight', function(weightCurrent, weightMax)
				OpenDepositMenu(plate, weightCurrent, weightMax)
			end)
		end
	end, function(data, menu)
		menu.close()
		isUsingTrunk = false
	end)
end

function OpenTakeMenu()
	local elements = {}

	ESX.TriggerServerCallback('esx_adrp_vehicle:getTrunkInventory', function(content, weightCurrent, weightMax)
		for k,v in pairs(content) do
			if v.type == 'item_standard' then
				table.insert(elements, {
					label = ('%s (<span style="color:blue;">x%s</span>)'):format(v.label, v.count),
					_label = v.label,
					item = k,
					count = v.count,
					type = v.type
				})
			elseif v.type == 'item_weapon' then
				table.insert(elements, {
					label = ('%s (%s rounds)'):format(v.label, v.count),
					item = k,
					count = v.count,
					type = 'item_weapon'
				})
			elseif v.type == 'item_account' then
				table.insert(elements, {
					label = ('%s: <span style="color:darkred;">$%s</span>'):format(v.label, ESX.Math.GroupDigits(v.count)),
					_label = v.label,
					item = k,
					count = v.count,
					type = 'item_account'
				})
			end
		end
	
		ESX.UI.Menu.Open('default', GetCurrentResourceName(), 'trunk_take', {
			title    = _U('trunk_take_title', weightCurrent, weightMax),
			align    = 'top-left',
			elements = elements
		}, function(data, menu)
			if data.current.type == 'item_standard' or data.current.type == 'item_account' then
				ESX.UI.Menu.Open('dialog', GetCurrentResourceName(), 'trunk_take_dialog', {
					title = _U('trunk_take_quantity')
				}, function(data2, menu2)
					local quantity = tonumber(data2.value)
	
					if quantity then
						menu2.close()
	
						ESX.TriggerServerCallback('esx_adrp_vehicle:removeFromTrunk', function(success, message, weightCurrent, weightMax)
							if success then
								local newData = data.current
								newData.count = data.current.count - quantity
								menu.setTitle(_U('trunk_take_title', weightCurrent, weightMax))

								if newData.count > 0 then
									if data.current.type == 'item_standard' then
										newData.label = ('%s (<span style="color:blue;">x%s</span>)'):format(data.current._label, data.current.count)
									elseif data.current.type == 'item_account' then
										newData.label = ('%s: <span style="color:darkred;">$%s</span>'):format(data.current._label, ESX.Math.GroupDigits(data.current.count))
									end

									menu.update({item = data.current.item}, newData)
									menu.refresh()
								else
									menu.removeElement({item = data.current.item})
									menu.refresh()
								end
							else
								ESX.ShowNotification(message)
							end
						end, data.current.item, data.current.type, quantity)
					end
				end, function(data2, menu2)
					menu2.close()
				end)
			elseif data.current.type == 'item_weapon' then
				ESX.TriggerServerCallback('esx_adrp_vehicle:removeFromTrunk', function(success, message, weightCurrent, weightMax)
					if success then
						menu.setTitle(_U('trunk_take_title', weightCurrent, weightMax))
						menu.removeElement({item = data.current.item})
						menu.refresh()
					else
						ESX.ShowNotification(message)
					end
				end, data.current.item, data.current.type, nil)
			end
		end, function(data, menu)
			menu.close()
		end)
	end)
end

function OpenDepositMenu(plate, current, max)
	ESX.UI.Menu.Open('default', GetCurrentResourceName(), 'trunk_deposit', {
		title    = _U('trunk_deposit_title', current, max),
		align    = 'top-left',
		elements = GetPlayerInventory()
	}, function(data, menu)
		if data.current.type == 'item_standard' or data.current.type == 'item_account' then
			ESX.UI.Menu.Open('dialog', GetCurrentResourceName(), 'trunk_deposit_dialog', {
				title = _U('trunk_deposit_quantity')
			}, function(data2, menu2)
				local quantity = tonumber(data2.value)

				if quantity then
					menu2.close()

					ESX.TriggerServerCallback('esx_adrp_vehicle:addToTrunk', function(success, message, weightCurrent, weightMax)
						if success then
							local newData = data.current
							newData.count = data.current.count - quantity
							menu.setTitle(_U('trunk_deposit_title', weightCurrent, weightMax))

							if newData.count > 0 then
								if data.current.type == 'item_standard' then
									newData.label = ('%s (<span style="color:blue;">x%s</span>)'):format(data.current._label, data.current.count)
								elseif data.current.type == 'item_account' then
									newData.label = ('%s: <span style="color:darkred;">$%s</span>'):format(data.current._label, ESX.Math.GroupDigits(data.current.count))
								end

								menu.update({item = data.current.item}, newData)
								menu.refresh()
							else
								menu.removeElement({item = data.current.item})
								menu.refresh()
							end
						else
							ESX.ShowNotification(message)
						end
					end, data.current.item, data.current.type, quantity)
				end
			end, function(data2, menu2)
				menu2.close()
			end)
		elseif data.current.type == 'item_weapon' then
			ESX.TriggerServerCallback('esx_adrp_vehicle:addToTrunk', function(success, message, weightCurrent, weightMax)
				if success then
					menu.removeElement({item = data.current.item})
					menu.setTitle(_U('trunk_deposit_title', weightCurrent, weightMax))
					menu.refresh()
				else
					ESX.ShowNotification(message)
				end
			end, data.current.item, data.current.type, nil)
		end
	end, function(data, menu)
		menu.close()
	end)
end

function GetPlayerInventory()
	ESX.PlayerData = ESX.GetPlayerData()
	local elements = {}

	for k,v in ipairs(ESX.PlayerData.inventory) do
		if v.count > 0 then
			table.insert(elements, {
				label = ('%s (<span style="color:blue;">x%s</span>)'):format(v.label, v.count),
				_label = v.label,
				item = v.name,
				count = v.count,
				type = 'item_standard'
			})
		end
	end

	for k,v in ipairs(ESX.PlayerData.loadout) do
		table.insert(elements, {
			label = ('%s (%s rounds)'):format(v.label, v.ammo),
			_label = v.label,
			item = v.name,
			count = v.ammo,
			type = 'item_weapon'
		})
	end

	for k,v in ipairs(ESX.PlayerData.accounts) do
		if v.name == 'black_money' and v.money > 0 then
			local money = ESX.Math.Round(v.money)

			table.insert(elements, {
				label = ('%s: <span style="color:darkred;">$%s</span>'):format(v.label, ESX.Math.GroupDigits(money)),
				_label = v.label,
				item = v.name,
				count = money,
				type = 'item_account'
			})

			break
		end
	end

	return elements
end
