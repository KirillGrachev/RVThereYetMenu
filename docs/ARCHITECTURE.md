# Архитектура RVThereYetMenu

Трейнер для **RV There Yet?** (Unreal Engine 5.6, Shipping, IoStore,
мультиплеер EOS+Steam). Платформа моддинга — **UE4SS** (Lua): та же,
на которой мод MoreRVers проверенно поднимает кап игроков этой игры.

Архитектурно проект повторяет договорённости RiskOfRainMenu
(RoR2SandboxMenu), перенесённые с BepInEx/Harmony на UE4SS/UMG:

| RiskOfRainMenu (Unity)          | RVThereYetMenu (UE5)                  |
|---------------------------------|----------------------------------------|
| BepInEx plugin, IMGUI           | UE4SS Lua mod, UMG из чистого Lua      |
| Harmony-патчи                   | RegisterHook / NotifyOnNewObject       |
| GameApi (обёртки рефлексии)     | `core/engine.lua` + `core/guard.lua`   |
| GameRefs + GameRefsTests        | `core/refs.lua` + `tools/NameCheck`    |
| CheatState / CheatFlag          | `core/state.lua`                       |
| SandboxActions (диспетчер)      | `actions.lua` (реестр id → run)        |
| MenuUI / Theme / Widgets / Tabs | `menu/` + `tabs/` (UMG-виджеты)        |
| Protocol (client → host)        | не нужен в v0.1: действия хоста и так  |
|                                 | серверные; клиентские — локальные      |
| lang.tsv                        | `lang/lang.tsv` (тот же формат)        |

## Слои

```
main.lua                тонкий вход: конфиг, lang, хоткей, LoadMap-хук
actions.lua             диспетчер: id -> действие (game thread, статус)
tabs/*.lua              вкладки меню: Build/Refresh, только UI
menu/menuui.lua         окно: сборка UMG, вкладки, курсор, рефреш-цикл
menu/widgets.lua        фабрика виджетов (StaticConstructObject + WidgetTree)
menu/theme.lua          цвета/шрифты/видимость
hooks/session.lua       слоты: MaxPlayers на экземпляре + CDO, хуки
hooks/unlocks.lua       косметика/кассеты/чекпоинты + сохранение в слот
hooks/cheats.lua        обёртка BP_CheatManager
core/engine.lua         доступ к объектам (GameInstance, GameSession, ...)
core/guard.lua          ApiGuard: pcall-обёртки, антифлуд ошибок
core/state.lua          CheatState: флаги, зеркала (applied/original), метрики
core/refs.lua           ВСЕ reflection-строки (данные, не код)
core/config.lua         INI: parse/normalize/clamp/save
core/lang.lua           lang.tsv: перевод с деградацией en -> key
core/log.lua            уровни, префикс, английский текст сообщений
```

Правила слоёв (контракты):

1. **К игре — только через Guard.** Любой reflection-вызов может упасть
   (патч игры, клиент без сессии, фронтенд без GameSession); падение в
   game thread уронит игру пользователю.
2. **Имена — только из refs.lua.** Никаких строковых reflection-путей в
   других модулях: NameCheck валидирует один файл, а не весь код.
3. **Меню не трогает игру напрямую.** Кнопки вызывают `Actions.Run(id)`,
   который уходит в `ExecuteInGameThread` и пишет единый статус.
4. **Значения клампятся на входе** (Config), а не в точках применения.
5. **Оригинал запоминается один раз** (State.Mirror): Release честно
   возвращает то, что было до первого применения.

## Модель мультиплеера

Игра — listen-сервер (хост + клиенты, EOS/Steam). Как и MoreRVers:
кап слотов и разблокировки применяются **на хосте**; клиентам мод не
нужен. Клиентские действия (waypoint-телепорты своего пешки, UI) —
локальные. Полноценный client→host протокол (как NetProtocol в RoR)
в v0.1 не переносился: для UE-сессии действия гостей можно добавить
позже через серверные RPC игровых классов (материал появится после
CXX-дампов).

## Валидация имён (GameRefsTests-эквивалент)

Конвейер офлайн-реверса без запуска игры (все инструменты — C#/.NET 10,
работают на Linux-сервере):

```
Ride-Windows.utoc/.ucas
   → tools/AssetIndex  → assets.txt (19101 пакет; CUE4Parse, Mount())
   → tools/AssetDump   → dumps/*.txt (name batch из Zen-заголовка:
                          LoadNameBatch@60, не требует .usmap)
scripts/core/refs.lua + assets.txt + dumps/
   → tools/NameCheck   → OK / ENGINE(whitelist) / UNKNOWN (exit 1)
```

После того как автор прогонит игру с UE4SS (вкладка Info → Dump objects /
Dump CXX headers / Dump .usmap):
- `Mappings.usmap` включает FULL-режим AssetDump (свойства со значениями);
- `UE4SS_ObjectDump.txt` снимает ENGINE-whitelist (проверка движковых
  имён: GameSession.MaxPlayers, PlayerController.* и т.д.).

## Тесты

- `tests/lua/run_tests.lua` — чистая логика без UE4SS: config (parse/
  clamp/roundtrip/дефолты), lang (перевод/деградация/format), state
  (флаги/original-зеркала/метрики), refs (форма данных), actions
  (полнота реестра, labelKey ↔ lang.tsv, dangerous-флаги).
- `tests/NameCheck.Tests` — xunit: парсер секций refs.lua (вложенные
  блоки, владельцы Members).
- `tests/fixtures` — сквозной прогон NameCheck в CI (синтетические
  assets/dumps тех же форматов).
- luacheck (`.luacheckrc`) — глобалы UE4SS объявлены явно.

## Сборка релиза

CI на теге релиза пакует `mod/` в `RVThereYetMenu-vX.Y.Z-ModOnly.zip`
(структура как у MoreRVers: Mods/RVThereYetMenu + UE4SS_Signatures).
UE4SS в релиз не кладём — у пользователя он уже стоит (или ставится
из RVTY-DumpKit / релизов UE4SS).
