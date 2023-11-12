-- This resource is part of the default Cfx.re asset pack (cfx-server-data)
-- Altering or recreating for local use only is strongly discouraged.

version '1.0.0'
description 'VIshop.pl plugin'

fx_version 'bodacious'
game 'gta5'

server_only 'yes'

server_scripts {
	'@mysql-async/lib/MySQL.lua',
	'config.lua',
	'server.lua'
}

dependencies {
    'mysql-async'
}