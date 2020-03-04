local trunkOpen = {}
local trunkContent = {}
local trunkClass = {}

AddEventHandler('esx_adrp_vehicle:clearTrunkInventory', function(plate)
	trunkContent[plate] = nil
	trunkClass[plate] = nil
	trunkOpen[plate] = nil
end)

ESX.RegisterServerCallback('esx_adrp_vehicle:attemptOpenTrunk', function(source, cb, plate, vehicleClass)
	if trunkOpen[plate] then
		cb(false)
	else
		trunkOpen[plate] = source

		if not trunkContent[plate] then
			trunkContent[plate] = {}

			trunkClass[plate] = vehicleClass
		end

		cb(true)
	end
end)

ESX.RegisterServerCallback('esx_adrp_vehicle:leaveTrunk', function(source, cb, plate)
	local identifier = GetPlayerIdentifier(source, 0)

	if trunkOpen[plate] then
		trunkOpen[plate] = nil
		cb(true)
	else
		print(('esx_adrp_vehicle: %s attempted to leaveTrunk'):format(identifier))
		cb(false)
	end
end)

ESX.RegisterServerCallback('esx_adrp_vehicle:getTrunkInventory', function(source, cb)
	local identifier = GetPlayerIdentifier(source, 0)
	local plate = GetCurrentPlayerPlate(source)

	if plate then
		cb(GetTrunkContent(plate), CalculateVehicleWeight(plate), GetVehicleWeightMax(plate))
	else
		print(('esx_adrp_vehicle: %s attempted to getTrunkInventory!'):format(identifier))
		cb({}, 0)
	end
end)

ESX.RegisterServerCallback('esx_adrp_vehicle:addToTrunk', function(source, cb, item, type, count)
	local xPlayer = ESX.GetPlayerFromId(source)
	local plate = GetCurrentPlayerPlate(source)
	
	if plate then
		local vehicle = GetTrunkContent(plate)
		local vehicleItem = vehicle[item] or nil
		local weightMax = GetVehicleWeightMax(plate)
		local newWeight = CalculateNewVehicleWeight(plate, item, type, count)

		if newWeight > GetVehicleWeightMax(plate) then
			cb(false, _U('error_add_vehiclelimit'), nil, nil)
		else

			if type == 'item_standard' then
				local playerItem = xPlayer.getInventoryItem(item)

				if playerItem.count >= count then
					xPlayer.removeInventoryItem(item, count)
					AddVehicleItem(plate, item, playerItem.label, count, type, nil)
					cb(true, nil, newWeight, weightMax)
				else
					cb(false, _U('error_add_playerenough', playerItem.label), nil, nil)
				end
			elseif type == 'item_weapon' then
				local _,weapon = xPlayer.getWeapon(item)
	
				if weapon then
					if vehicleItem then
						cb(false, _U('error_add_weaponalready'), nil, nil)
					else
						xPlayer.removeWeapon(item)
						AddVehicleItem(plate, item, weapon.label, weapon.ammo, type, weapon.components)
						cb(true, nil, newWeight, weightMax)
					end
				else
					cb(false, _U('error_add_weaponmissing'), nil, nil)
				end
			elseif type == 'item_account' then
				local account = xPlayer.getAccount(item)
	
				if account.money >= count then
					xPlayer.removeAccountMoney(item, count)
					AddVehicleItem(plate, item, account.label, count, type, nil)
	
					cb(true, nil, newWeight, weightMax)
				else
					cb(false, _U('error_add_enoughblack'), nil, nil)
				end
			end

		end
	else
		print(('esx_adrp_vehicle: %s attempted to addToTrunk!'):format(xPlayer.identifier))
		cb(false, 'unknown')
	end
end)

ESX.RegisterServerCallback('esx_adrp_vehicle:removeFromTrunk', function(source, cb, item, type, count)
	local xPlayer = ESX.GetPlayerFromId(source)
	local plate = GetCurrentPlayerPlate(source)

	if plate then
		local vehicle = GetTrunkContent(plate)
		local vehicleItem = vehicle[item]
		local weightMax = GetVehicleWeightMax(plate)

		if vehicleItem then

			if type == 'item_standard' then
				local playerItem = xPlayer.getInventoryItem(item)

				if playerItem.limit ~= -1 and (playerItem.count + count) > playerItem.limit then
					cb(false, _U('error_remove_playerlimit', playerItem.label), nil, nil)
				elseif vehicleItem.count < count then
					cb(false, _U('error_remove_trunk', playerItem.label), nil, nil)
				else
					xPlayer.addInventoryItem(item, count)
					RemoveVehicleItem(plate, item, count)

					cb(true, nil, CalculateVehicleWeight(plate), weightMax)
				end
			elseif type == 'item_weapon' then
				if xPlayer.hasWeapon(item) then
					cb(false, _U('error_remove_hasweapon'), nil, nil)
				else
					xPlayer.addWeapon(item, vehicleItem.count)

					for k,v in ipairs(vehicleItem.components) do
						xPlayer.addWeaponComponent(item, v)
					end

					RemoveVehicleItem(plate, item, vehicleItem.count)

					cb(true, nil, CalculateVehicleWeight(plate), weightMax)
				end
			elseif type == 'item_account' then
				if count <= vehicleItem.count then
					xPlayer.addAccountMoney(item, count)
					RemoveVehicleItem(plate, item, count)

					cb(true, nil, CalculateVehicleWeight(plate), weightMax)
				else
					cb(false, _U('error_remove_enoughblack'), nil, nil)
				end
			end

		else
			print(('esx_adrp_vehicle: %s attempted to remove unknown item!'):format(xPlayer.identifier))
			cb(false, 'unknown', nil, nil)
		end

	else
		print(('esx_adrp_vehicle: %s attempted to removeFromTrunk!'):format(xPlayer.identifier))
		cb(false, 'unknown', nil, nil)
	end
end)

ESX.RegisterServerCallback('esx_adrp_vehicle:getTrunkWeight', function(source, cb)
	local plate = GetCurrentPlayerPlate(source)
	local identifier = GetPlayerIdentifier(source, 0)

	if plate then
		local weightMax = GetVehicleWeightMax(plate)
		local weightCurrent = CalculateVehicleWeight(plate)

		cb(weightCurrent, weightMax)
	else
		print(('esx_adrp_vehicle: %s attempted to getTrunkWeight!'):format(identifier))
		cb(0, 0)
	end
end)

function GetTrunkContent(plate)
	return trunkContent[plate] or {}
end

function GetVehicleItem(plate, item)
	return trunkContent[plate][item]
end

function AddVehicleItem(plate, item, label, count, type, components)
	if not GetVehicleItem(plate, item) then
		trunkContent[plate][item] = {}

		trunkContent[plate][item].label = label
		trunkContent[plate][item].count = count
		trunkContent[plate][item].type = type
		trunkContent[plate][item].components = components or nil
	else
		local vehicleCount = trunkContent[plate][item].count
	
		trunkContent[plate][item].count = vehicleCount + count
	end
end

function RemoveVehicleItem(plate, item, count)
	local currentCount = trunkContent[plate][item].count
	local newCount = currentCount - count

	if newCount == 0 then
		trunkContent[plate][item] = nil
	else
		trunkContent[plate][item].count = newCount
	end
end

function GetCurrentPlayerPlate(playerId)
	for plate,v in pairs(trunkOpen) do
		if v == playerId then
			return plate
		end
	end

	return nil
end

function GetVehicleWeightMax(plate)
	local class = trunkClass[plate]
	return Config.VehicleLimit[class]
end

function CalculateVehicleWeight(plate)
	local weight = 0

	for k,v in pairs(GetTrunkContent(plate)) do
		local multiplier = Config.WeightDefaults[v.type]
		local override = Config.WeightItems[k]

		if override then
			multiplier = override
		end

		if v.type == 'item_standard' then
			weight = weight + (v.count * multiplier)
		elseif v.type == 'item_weapon' then
			weight = weight + multiplier
		elseif v.type == 'item_account' then
			weight = weight + ESX.Math.Round(v.count * multiplier)
		end
	end

	return weight
end

function CalculateNewVehicleWeight(plate, item, type, count)
	local weight = CalculateVehicleWeight(plate)
	local multiplier = Config.WeightDefaults[type]
	local override = Config.WeightItems[item]

	if override then
		multiplier = override
	end

	if type == 'item_standard' then
		weight = weight + (count * multiplier)
	elseif type == 'item_weapon' then
		weight = weight + multiplier
	elseif type == 'item_account' then
		weight = weight + ESX.Math.Round(count * multiplier)
	end

	return weight
end
