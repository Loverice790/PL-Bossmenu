ESX = exports["es_extended"]:getSharedObject()

lib.locale()

for job, data in pairs(PL.jobs) do
    exports.ox_target:addBoxZone({
        coords = data.location,
        size = vec3(1,1,1),
        options = {
            {
                label = locale("open_bossmenu"),
                icon = "fas fa-user",
                groups = {
                    [job] = data.grade
                },
                onSelect = function()
                    bossimenu(job, data)
                end
            }
        }
    })
end

function bossimenu(job, data)
    lib.registerContext({
        title = locale("boss_menu_title"),
        id = string.format("bossmenu_%s", job),
        options = {
            {
                title = locale("company_account"), 
                icon = "fas fa-wallet",
                onSelect = function()
                    ESX.TriggerServerCallback("PL-bossmenu:getbalance", function(balance, omabalance) 
                        lib.registerContext({
                            title = locale("company_account"), 
                            id = "Firmantili",
                            options = {
                                {
                                    title = locale("balance") .. ": " .. balance, 
                                    icon = "fas fa-file-invoice-dollar",
                                    disabled = true,
                                },
                                {
                                    title = locale("withdraw_money"), 
                                    icon = "fas fa-file-invoice-dollar",
                                    onSelect = function()
                                        local input = lib.inputDialog(locale("withdraw_money"), {
                                            {
                                                type = "number",
                                                label = locale("input_amount"),
                                                placeholder = locale("input_amount"), 
                                                balance,
                                                max = balance, min = 0, required = true
                                            }
                                        })
                                        if input then
                                            local amount = input[1]
                                            if amount >= 1 then
                                                TriggerServerEvent("PL-bossmenu:withdraw", job, amount)
                                            else
                                                if PL.notify == "ESX" then
                                                    ESX.ShowNotification(locale("withdraw_failed")) 
                                                elseif PL.notify == "ox" then
                                                    lib.notify({
                                                        title = locale("withdraw_failed"), 
                                                        type = "error",
                                                    })
                                                end
                                            end
                                        end
                                    end
                                },
                                {
                                    title = locale("deposit_money"), 
                                    icon = "fas fa-file-invoice-dollar",
                                    onSelect = function()
                                        local input = lib.inputDialog(locale("deposit_money"), {
                                            {
                                                type = "number",
                                                label = locale("deposit_amount_label"), 
                                                placeholder = locale("max_balance") .. omabalance, 
                                                max = omabalance, min = 0, required = true
                                            }
                                        })
                                        if input then
                                            local amount = input[1]
                                            if amount >= 1 then  
                                                TriggerServerEvent("PL-bossmenu:deposit", job, amount)
                                            else
                                                if PL.notify == "ESX" then
                                                    ESX.ShowNotification(locale("insufficient_funds")) 
                                                elseif PL.notify == "ox" then
                                                    lib.notify({
                                                        title = locale("insufficient_funds"), 
                                                        type = "error",
                                                    })
                                                end
                                            end
                                        end
                                    end
                                }
                            }
                        })
                        lib.showContext("Firmantili")
                    end, job)
                end
            },
            {
                title = locale("employees"), 
                icon = "fas fa-user",
                onSelect = function()
                    openJobMenu(job, data.label)
                end
            },
            {
                title = locale("hire"), 
                icon = "fas fa-user",
                onSelect = function()
                    hireEmployeeMenu(job, data)
                end
            }
        }
    })
    lib.showContext(string.format("bossmenu_%s", job))
end

function openJobMenu(jobName, label)
    ESX.TriggerServerCallback("PL-bossmenu:haeorjat", function(orjat) 
        if orjat and #orjat > 0 then 
            local contextOptions = {}
            for _, player in ipairs(orjat) do
                local onlineStatus = player.online and "green" or "red"
                table.insert(contextOptions, {
                    title = player.firstname .. ' ' .. player.lastname,
                    description = locale("job_grade") .. ": " .. player.job_grade, 
                    iconColor = onlineStatus,
                    icon = 'fas fa-user-gear',
                    onSelect = function()
                        manageEmployeeMenu(jobName, player)
                    end
                })
            end
            lib.registerContext({
                title = locale("employees"),
                id = "orjat", 
                options = contextOptions
            })
            lib.showContext("orjat")
        else
            if PL.notify == "ESX" then
                ESX.ShowNotification(locale("no_employees_found")) 
            elseif PL.notify == "ox" then
                lib.notify({
                    title = locale("no_employees_found"), 
                    type = "error"
                })
            end
        end     
    end, jobName)
end

function manageEmployeeMenu(jobName, player)
    lib.registerContext({
        title = locale("manage_employee"),
        id = "manage_"..player.identifier,
        options = {
            {
                title = locale("promote"), 
                icon = "fas fa-user-plus",
                onSelect = function()
                    TriggerServerEvent("PL-bossmenu:hallitse", "promote", player.identifier, jobName)
                end
            },
            {
                title = locale("demote"),
                icon = "fas fa-user-minus",
                onSelect = function()
                    TriggerServerEvent("PL-bossmenu:hallitse", "demote", player.identifier, jobName)
                end
            },
            {
                title = locale("fire"), 
                icon = "fas fa-user-xmark",
                onSelect = function()
                    TriggerServerEvent("PL-bossmenu:hallitse", "fire", player.identifier, jobName)
                end
            }
        }
    })
    lib.showContext("manage_"..player.identifier)
end

function hireEmployeeMenu(jobName, data)
    local nearbyPlayers = getNearbyPlayers(5.0)

    if #nearbyPlayers > 0 then
        ESX.TriggerServerCallback('PL-bossmenu:getEligiblePlayers', function(eligiblePlayers)
            if #eligiblePlayers > 0 then
                local playerOptions = {}
                for _, player in ipairs(eligiblePlayers) do
                    table.insert(playerOptions, { label = player.name, value = player.serverId })
                end

                local input = lib.inputDialog(locale("hire_dialog_title"), { 
                    { type = 'select', label = locale("hire_dialog_label"), options = playerOptions, required = true } 
                })

                if input then
                    local selectedPlayer = input[1]
                    if selectedPlayer then
                        TriggerServerEvent('PL-bossmenu:hireEmployee', selectedPlayer, jobName, data.label)
                        if PL.notify == "ESX" then
                            ESX.ShowNotification(locale("player_hired")) 
                        elseif PL.notify == "ox" then
                            lib.notify({ title = locale("player_hired"), type = 'success' }) 
                        end
                    end
                end
            else
                if PL.notify == "ESX" then
                    ESX.ShowNotification(locale("no_eligible_players")) 
                elseif PL.notify == "ox" then
                    lib.notify({ title = locale("no_eligible_players"), type = 'error' }) 
                end
            end
        end, nearbyPlayers, jobName)
    else
        if PL.notify == "ESX" then
            ESX.ShowNotification(locale("no_players_nearby")) 
        elseif PL.notify == "ox" then
            lib.notify({ title = locale("no_players_nearby"), type = 'error' }) 
        end
    end
end

function getNearbyPlayers(radius)
    local players = GetActivePlayers()
    local nearbyPlayers = {}
    local playerPed = PlayerPedId()
    local playerCoords = GetEntityCoords(playerPed)

    for _, playerId in ipairs(players) do
        local targetPed = GetPlayerPed(playerId)
        local targetCoords = GetEntityCoords(targetPed)
        local distance = #(playerCoords - targetCoords)

        if distance <= radius and playerId ~= PlayerId() then
            table.insert(nearbyPlayers, { serverId = GetPlayerServerId(playerId), name = GetPlayerName(playerId) })
        end
    end

    return nearbyPlayers
end