ESX = exports["es_extended"]:getSharedObject()
lib.locale()
ESX.RegisterServerCallback("PL-bossmenu:haeorjat", function(source, cb, job)
    local xPlayers = ESX.GetPlayers()
    local orjat = {}

    MySQL.Async.fetchAll('SELECT identifier, firstname, lastname, job_grade FROM users WHERE job = @job', {
        ['@job'] = job
    }, function(results)

        local jobGrades = {}

        MySQL.Async.fetchAll('SELECT job_name, grade, label FROM job_grades WHERE job_name = @job_name', {
            ['@job_name'] = job
        }, function(jobGradesResults)
            for _, grade in ipairs(jobGradesResults) do
                jobGrades[tostring(grade.grade)] = grade.label
            end

            for i = 1, #results, 1 do
                local online = false
                local gradeLabel = ''
                for j = 1, #xPlayers, 1 do
                    local xPlayer = ESX.GetPlayerFromId(xPlayers[j])
                    if xPlayer and xPlayer.getIdentifier() == results[i].identifier then
                        online = true
                        gradeLabel = xPlayer.getJob().grade_label
                        break
                    end
                end

                if not online then
                    gradeLabel = jobGrades[tostring(results[i].job_grade)] or ''
                end

                table.insert(orjat, {
                    identifier = results[i].identifier,
                    firstname = results[i].firstname,
                    lastname = results[i].lastname,
                    job_grade = gradeLabel,
                    online = online
                })
            end
            cb(orjat)
        end)
    end)
end)

RegisterServerEvent("PL-bossmenu:hallitse", function(action, identifier, jobName)
    local xPlayer = ESX.GetPlayerFromIdentifier(identifier)
    
    if xPlayer then
        -- Player is online, handle job changes for xPlayer
        local notifyMessage = ""
        if action == "promote" then
            notifyMessage = locale("promoted_message") 
            local newGrade = xPlayer.job.grade + 1
            xPlayer.setJob(jobName, newGrade)
            MySQL.update("UPDATE users SET job_grade = ? WHERE identifier = ?", {newGrade, identifier})
        elseif action == "demote" then
            notifyMessage = locale("demoted_message")  
            local newGrade = xPlayer.job.grade - 1
            xPlayer.setJob(jobName, newGrade)
            MySQL.update("UPDATE users SET job_grade = ? WHERE identifier = ?", {newGrade, identifier})
        elseif action == "fire" then
            notifyMessage = locale("fired_message")  
            xPlayer.setJob(PL.unemployed_job, 0)
            MySQL.update("UPDATE users SET job_grade = ?, job = ? WHERE identifier = ?", {0, PL.unemployed_job, identifier})
        end

        -- Notify the player based on the action
        if notifyMessage ~= "" then
            if PL.notify == "ESX" then
                xPlayer.showNotification(notifyMessage)
            elseif PL.notify == "ox" then
                TriggerClientEvent("ox_lib:notify", xPlayer.source, {
                    icon = action == "promote" and "fas fa-user-plus" or action == "demote" and "fas fa-user-minus" or "fas fa-user-xmark",
                    title = notifyMessage,
                    type = action == "promote" and "success" or "error",
                })
            end
        end

    else
        -- Player is offline, we need to fetch job information from the database
        MySQL.scalar("SELECT job_grade FROM users WHERE identifier = ?", {identifier}, function(currentGrade)
            if currentGrade then
                local newGrade = currentGrade
                local notifyMessage = ""

                -- Perform actions based on the requested action
                if action == "promote" then
                    newGrade = currentGrade + 1
                    notifyMessage = locale("promoted_message")
                    MySQL.update("UPDATE users SET job_grade = ? WHERE identifier = ?", {newGrade, identifier})
                elseif action == "demote" then
                    newGrade = currentGrade - 1
                    notifyMessage = locale("demoted_message")
                    MySQL.update("UPDATE users SET job_grade = ? WHERE identifier = ?", {newGrade, identifier})
                elseif action == "fire" then
                    notifyMessage = locale("fired_message")
                    MySQL.update("UPDATE users SET job_grade = ?, job = ? WHERE identifier = ?", {0, PL.unemployed_job, identifier})
                end

                -- Optionally, you could also trigger a notification for admins or log the action.
            else
                print("Error: Could not find player with identifier " .. identifier)
            end
        end)
    end
end)

ESX.RegisterServerCallback("PL-bossmenu:getbalance", function(source, cb, job)
    local player = ESX.GetPlayerFromId(source)
    local playermoney = player.getMoney()
    MySQL.query("SELECT money FROM addon_account_data WHERE account_name = ?", {"society_"..job}, function(result)
        if result[1] then
            local balance = result[1].money
            cb(balance, playermoney)
        end
    end)
end)

RegisterServerEvent("PL-bossmenu:deposit", function(job, amount)
    local player = ESX.GetPlayerFromId(source)
    if player.getMoney() >= amount then
        MySQL.update("UPDATE addon_account_data SET money = money + ? WHERE account_name = ?", {amount, "society_"..job}, function(balanceChanged)
            if balanceChanged > 0 then
                if PL.notify == "ESX" then
                    player.showNotification(locale("deposited_message", amount))  
                elseif PL.notify == "ox" then
                    TriggerClientEvent("ox_lib:notify", player.source, {
                        title = locale("deposited_message", amount),  
                        icon = "fas fa-euro-sign",
                        type = "success",
                    })
                end
                player.removeMoney(amount)
            else
                if PL.notify == "ESX" then
                    player.showNotification(locale("deposit_failed"))  
                elseif PL.notify == "ox" then
                    TriggerClientEvent("ox_lib:notify", player.source, {
                        title = locale("deposit_failed"), 
                        icon = "fas fa-euro-sign",
                        type = "error",
                    })
                end
            end
        end)
    else
        if PL.notify == "ESX" then
            player.showNotification(locale("not_enough_money")) 
        elseif PL.notify == "ox" then
            TriggerClientEvent("ox_lib:notify", player.source, {
                title = locale("not_enough_money"), 
                icon = "fas fa-euro-sign",
                type = "error",
            })
        end
    end
end)

RegisterServerEvent("PL-bossmenu:withdraw", function(job, amount)
    local player = ESX.GetPlayerFromId(source)
    MySQL.update('UPDATE addon_account_data SET money = money - ? WHERE account_name = ?', {amount, "society_"..job}, function(balanceChanged)
        if balanceChanged > 0 then
            if PL.notify == "ESX" then
                player.showNotification(locale("withdrew_message", amount)) 
            elseif PL.notify == "ox" then
                TriggerClientEvent("ox_lib:notify", player.source, {
                    title = locale("withdrew_message", amount), 
                    icon = "fas fa-euro-sign",
                    type = "success"
                })
            end
            player.addMoney(amount)
        else
            if PL.notify == "ESX" then
                player.showNotification(locale("withdraw_failed"))  
            elseif PL.notify == "ox" then
                TriggerClientEvent("ox_lib:notify", player.source, {
                    title = locale("withdraw_failed"),  
                    icon = "fas fa-euro-sign",
                    type = "error",
                })
            end
        end
    end)
end)

ESX.RegisterServerCallback('PL-bossmenu:getEligiblePlayers', function(source, cb, nearbyPlayers, jobName)
    local eligiblePlayers = {}

    for _, player in ipairs(nearbyPlayers) do
        local xPlayer = ESX.GetPlayerFromId(player.serverId)
        if xPlayer and xPlayer.job.name ~= jobName then
            table.insert(eligiblePlayers, player)
        end
    end

    cb(eligiblePlayers)
end)

RegisterNetEvent('PL-bossmenu:hireEmployee', function(targetServerId, jobName, label)
    local xPlayer = ESX.GetPlayerFromId(targetServerId)

    if xPlayer and xPlayer.job.name ~= jobName then
        if PL.notify == "ESX" then
            xPlayer.showNotification(locale("hired_message", jobName)) 
        elseif PL.notify == "ox" then
            TriggerClientEvent("ox_lib:notify", xPlayer.source, {
                description = locale("hired_message", label), 
                icon = "fas fa-user-check",
                type = "success",
            })
        end
        xPlayer.setJob(jobName, 0)
        MySQL.update('UPDATE users SET job = ?, job_grade = ? WHERE identifier = ?', {jobName, 0, xPlayer.identifier})
    end
end)