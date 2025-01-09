fx_version "cerulean"

game "gta5"

lua54 "yes"

author "pipsa_dev"

description "Simppeli boss menu"

shared_script {"@ox_lib/init.lua", "config.lua" }

client_script {"client/client.lua"}

server_script {"server/server.lua", "@oxmysql/lib/MySQL.lua"}

files {
    "locales/*.json"
}