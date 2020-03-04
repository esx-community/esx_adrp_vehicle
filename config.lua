Config = {}

Config.Locale = 'en'

Config.WeightDefaults = {
	['item_standard'] = 2,
	['item_weapon'] = 20,
	['item_account'] = 0.01,
}

-- Individual item weights, add them here. They will override the default weight limit
-- Weapons must be in uppercase
Config.WeightItems = {
	['essence'] = 20,
	['coke_pooch'] = 4
}

-- Weight in Kilograms
Config.VehicleLimit = {
	[0] = 100, --Compact
	[1] = 140, --Sedan
	[2] = 160, --SUV
	[3] = 150, --Coupes
	[4] = 170, --Muscle
	[5] = 100, --Sports Classics
	[6] = 40, --Sports
	[7] = 20, --Super
	[8] = 30, --Motorcycles
	[9] = 225, --Off-road
	[10] = 300, --Industrial
	[11] = 200, --Utility
	[12] = 300, --Vans
	[13] = 0, --Cycles
	[14] = 200, --Boats
	[15] = 200, --Helicopters
	[16] = 500, --Planes
	[17] = 400, --Service
	[18] = 50, --Emergency
	[19] = 50, --Military
	[20] = 150 --Commercial
}
