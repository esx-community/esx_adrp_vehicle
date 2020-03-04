fx_version 'adamant'

game 'gta5'

description 'ESX ADRP Vehicle Managment'

version '1.0.0'

server_scripts {
	'@es_extended/locale.lua',
	'locales/en.lua',
	'config.lua',
	'server/main.lua',
	'server/lock.lua',
	'server/trunk.lua'
}

client_scripts {
	'@es_extended/locale.lua',
	'locales/en.lua',
	'config.lua',
	'client/main.lua',
	'client/lock.lua',
	'client/trunk.lua'
}

dependency 'es_extended'
