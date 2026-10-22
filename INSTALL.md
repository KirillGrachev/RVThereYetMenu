# Установка RVThereYetMenu

Трейнер для **RV There Yet?** (Unreal Engine 5) на базе **UE4SS** (Lua-мод).
Ставится только на машину игрока; для большинства функций — только хосту.

## Требования

- RV There Yet? (Steam), актуальная версия (проверено на сборке 2026-09, UE 5.6);
- UE4SS experimental 3.0.1+ (на этой игре проверен снапшот из набора
  MoreRVers — он же лежит в `RVTY-DumpKit.zip` на рабочем сервере);
- Windows 10/11 x64.

## Шаг 1. UE4SS

Распакуйте UE4SS в папку игры, если ещё не установлен:

```
<Steam>\steamapps\common\Ride\Ride\Binaries\Win64\
    dwmapi.dll            <- прокси-загрузчик
    ue4ss\
        UE4SS.dll
        UE4SS-settings.ini
        Mods\ ...
```

Готовый набор: `RVTY-DumpKit.zip` (на сервере `/root/work/rvty-game/`),
либо релиз `experimental-latest` из https://github.com/UE4SS-RE/RE-UE4SS/releases,
либо пакет MoreRVers «WithUE4SS» (https://github.com/alex-nardozzi/MoreRVers).

## Шаг 2. Мод

1. Скопируйте папку `mod/Mods/RVThereYetMenu` из этого репозитория в
   `...\Win64\ue4ss\Mods\`, чтобы получилось:

   ```
   ue4ss\Mods\RVThereYetMenu\
       scripts\main.lua
       config.ini
       lang\lang.tsv
   ```

2. Впишите мод в `ue4ss\Mods\mods.txt` **до строки `Keybinds : 1`**:

   ```
   RVThereYetMenu : 1
   ```

3. Скопируйте `mod/UE4SS_Signatures/FText_Constructor.lua` в
   `...\Win64\ue4ss\UE4SS_Signatures\` (папку создать, если её нет).
   Без этого файла в UE 5.4+ не создаётся FText и текст меню будет пустым.

## Шаг 3. Запуск

1. Запустите игру. В консоли UE4SS должны появиться строки
   `[RVThereYetMenu] [INFO] RVThereYetMenu v0.1.0 loaded ...`.
2. Меню открывается клавишей **INSERT** (настраивается в `config.ini`).

## Настройка (config.ini)

| Ключ | Значение | Смысл |
|---|---|---|
| `Menu.ToggleKey` | `INSERT` | Клавиша меню (имя из таблицы Key UE4SS) |
| `Menu.Language` | `ru` / `en` | Язык интерфейса |
| `Session.MaxPlayers` | `8` (1..24) | Кап игроков для хоста |
| `Session.AutoApplySlots` | `true` | Применять кап к каждой новой сессии |
| `Logging.Level` | `INFO` | DEBUG / INFO / WARN / ERROR |

## Дампы для разработки (вкладка Info)

Кнопки `Dump objects / Dump CXX headers / Dump .usmap` пишут в `ue4ss\`:
`UE4SS_ObjectDump.txt`, `CXXHeaderDump\`, `Mappings.usmap`. Эти файлы
использует `tools/NameCheck` (валидация reflection-имён мода) — после
обновления игры прогоните дампы и пришлите их разработчику.

## Удаление

Удалите `dwmapi.dll`, папку `ue4ss\` и строку из `mods.txt`.
Файлы игры мод не изменяет.

## Безопасность

- Игра кооперативная (PvE), античита нет; тем не менее тестировать
  деструктивные функции (вкладка Players → «Для разработчика») лучше
  в своей сессии.
- Разблокировки пишутся в ваш сейв штатными dev-функциями игры;
  достижения при выдаче косметики НЕ срабатывают (так задумано игрой).
