--- Вкладка Vehicle: ремонт, посадка в транспорт, лебёдка, шипы.
--- Все действия — обёртки над BP_CheatManager (подтверждены дампом).
local Lang = require("core.lang")
local Actions = require("actions")
local W = require("menu.widgets")

local Tab = { Id = "vehicle", TitleKey = "tab.vehicle" }

--- Ряд кнопок: две в строку, чтобы не растягивать вкладку в скролл.
local function buttonGrid(parent, ctx, ids)
    local row = nil
    for i, id in ipairs(ids) do
        if i % 2 == 1 then
            row = W.HBox(parent)
            W.AddTo(parent, row, { Bottom = 3 })
        end
        local label = Lang.T(id)
        local btn = W.Button(row, label, function() Actions.Run(ctx, id) end)
        W.AddTo(row, btn, { Right = (i % 2 == 1) and 4 or 0 }, 1.0)
    end
end

function Tab.Build(page, ctx)
    local repair = W.Section(page, Lang.T("vehicle.title.repair"))
    buttonGrid(repair, ctx, {
        "vehicle.repair.all",
        "vehicle.repair.engine",
        "vehicle.repair.frame",
        "vehicle.repair.wheels",
    })

    local drive = W.Section(page, Lang.T("vehicle.title.drive"))
    buttonGrid(drive, ctx, {
        "vehicle.drive.winnebago",
        "vehicle.drive.jetski",
    })

    local winch = W.Section(page, Lang.T("vehicle.title.winch"))
    buttonGrid(winch, ctx, {
        "vehicle.winch.grab",
        "vehicle.winch.grab.rear",
        "vehicle.winch.reset",
        "vehicle.winch.reset.rear",
    })

    local studs = W.Section(page, Lang.T("vehicle.title.studs"))
    buttonGrid(studs, ctx, {
        "vehicle.studs.add",
        "vehicle.studs.wear",
    })
end

return Tab
