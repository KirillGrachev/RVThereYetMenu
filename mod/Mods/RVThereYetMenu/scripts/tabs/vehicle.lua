--- Вкладка Vehicle: ремонт, посадка в транспорт, лебёдка, шипы.
--- Все действия — обёртки над BP_CheatManager (подтверждены дампом).
local Lang = require("core.lang")
local Actions = require("actions")
local Widgets = require("menu.widgets")

local Tab = { Id = "vehicle", TitleKey = "tab.vehicle" }

--- Ряд кнопок: две в строку, чтобы не растягивать вкладку в скролл.
local function buttonGrid(parent, context, actionIds)
    local row = nil
    for i, id in ipairs(actionIds) do
        if i % 2 == 1 then
            row = Widgets.HBox(parent)
            Widgets.AddTo(parent, row, { Bottom = 3 })
        end
        local label = Lang.T(id)
        local button = Widgets.Button(row, label, function() Actions.Run(context, id) end)
        Widgets.AddTo(row, button, { Right = (i % 2 == 1) and 4 or 0 }, 1.0)
    end
end

function Tab.Build(page, context)
    local repair = Widgets.Section(page, Lang.T("vehicle.title.repair"))
    buttonGrid(repair, context, {
        "vehicle.repair.all",
        "vehicle.repair.engine",
        "vehicle.repair.frame",
        "vehicle.repair.wheels",
    })

    local drive = Widgets.Section(page, Lang.T("vehicle.title.drive"))
    buttonGrid(drive, context, {
        "vehicle.drive.winnebago",
        "vehicle.drive.jetski",
    })

    local winch = Widgets.Section(page, Lang.T("vehicle.title.winch"))
    buttonGrid(winch, context, {
        "vehicle.winch.grab",
        "vehicle.winch.grab.rear",
        "vehicle.winch.reset",
        "vehicle.winch.reset.rear",
    })

    local studs = Widgets.Section(page, Lang.T("vehicle.title.studs"))
    buttonGrid(studs, context, {
        "vehicle.studs.add",
        "vehicle.studs.wear",
    })
end

return Tab
