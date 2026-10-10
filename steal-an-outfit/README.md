# Steal an Outfit (Roblox)

Мультиплеерная игра в жанре «Steal a Brainrot»: забираешь украшения с манекенов, они висят на персонаже и приносят деньги, пока ты на арене. Код на Luau (`--!strict`), проект собирается через Rojo.

Сейчас готова **Фаза 1 (ядро)**: арена из примитивов, 12 манекенов с волнами дропа, 8 гримёрок, подбор с удержанием, экипировка на 6 слотов тела со Swap, выпадение на пол, доход только на арене, HUD.

## Запуск

Нужен Roblox Studio (Windows или macOS): https://create.roblox.com/docs/studio/setup

**Вариант А, проще всего.** Открыть готовый файл места `StealAnOutfit.rbxlx` в Studio (File → Open from File). Файл собирается командой `rojo build -o StealAnOutfit.rbxlx` и в репозиторий не коммитится.

**Вариант Б, для разработки.** Живая синхронизация кода через Rojo:
1. Поставь [Rokit](https://github.com/rojo-rbx/rokit) и в этой папке выполни `rokit install` (подтянет Rojo, StyLua, Selene из `rokit.toml`).
2. Поставь плагин Rojo в Studio: `rojo plugin install`.
3. `rojo serve` в этой папке.
4. В Studio открой любой пустой шаблон (например Baseplate), в плагине Rojo нажми **Connect**. Baseplate и SpawnLocation шаблона скрипт сам удаляет при старте игры.

Карта строится скриптом при старте сервера, поэтому в режиме редактирования Workspace пустой. Это нормально.

Для публикации: Game Settings → Places → Max Players = **8** (скрипт рассчитан на 8 гримёрок; лишний игрок спавнится на подиуме без гримёрки). Lighting.Technology выставляется из `default.project.json` в Future; если плагин Rojo не смог его записать, выставь вручную.

## Как проверить Фазу 1

Вкладка **Test** → в блоке Clients and Servers выбери 2 или 3 игрока → **Start**. Откроются окно сервера и по окну на каждого игрока, переключайся между окнами игроков.

- Каждый игрок появляется в своей гримёрке, над дверью табличка с ником.
- Через 5 секунд после старта на 12 манекенах появляются украшения, дальше новая волна каждые 60 секунд. Таймер «NEXT DROP IN» вверху экрана.
- Над манекеном подпись: название, редкость, доход. Удерживай **E** 0.6 сек, украшение надевается на нужную часть тела и появляется в нижней панели слотов. Другие игроки видят его на тебе.
- Деньги растут только на арене. В гримёрке в HUD написано «No income in your dressing room», и сумма не растёт.
- Возьми второе украшение в уже занятый слот: появится окно Swap / Cancel. При Swap старое украшение вылетает на пол, его можно поднять (удержание 0.3 сек), через 30 секунд оно исчезает.
- Чужой игрок не может пройти в твою гримёрку (розовое силовое поле в дверях).
- Legendary и выше: баннер на весь сервер, украшение светится и искрится.

Для быстрой проверки редких предметов временно подними веса в `src/shared/Config/Rarities.luau`.

## Замена плейсхолдеров на модели

Скрипты сначала ищут готовые модели и только потом строят примитивы.

| Что | Куда положить | Требования |
|---|---|---|
| Вся карта | `Workspace/Arena` или `ReplicatedStorage/Assets/Arena` | Model с папками `Mannequins` (модели манекенов), `Bases` (гримёрки) и моделью `GrandMannequin` |
| Части карты | `ReplicatedStorage/Assets/ArenaShell`, `ClothesRack`, `FoldingScreen`, `MakeupStation`, `StageLight` | Model, pivot на полу, перед модели смотрит по -Z |
| Манекен | `ReplicatedStorage/Assets/Mannequin`, `GrandMannequin` | Model с частью `PromptPart` и Attachment'ами `HatAttachment`, `FaceFrontAttachment`, `NeckAttachment`, `BodyFrontAttachment`, `BodyBackAttachment`, `WaistCenterAttachment` |
| Гримёрка | `ReplicatedStorage/Assets/DressingRoom` | Model, pivot в центре дверного проёма на уровне пола, -Z смотрит внутрь комнаты. Части: `Zone` (объём комнаты), `Barrier` (дверной проём, его LookVector смотрит внутрь), `SpawnPoint`, `Sign` (лицевая сторона Front смотрит на арену) |
| Украшение | `ReplicatedStorage/Assets/Items/<id предмета>` | Accessory с частью `Handle`, в Handle есть Attachment с именем слота (см. таблицу слотов). Мутации перекрашивают части; атрибут `KeepLook = true` на части это отключает |

Id предметов смотри в `src/shared/Config/Items.luau`.

## Структура

```
src/
  server/                      -> ServerScriptService/Server
    Main.server.luau           порядок инициализации, вход/выход игроков, респавн
    Services/
      MapBuilder.luau          арена, манекены, гримёрки, освещение
      BaseService.luau         назначение гримёрок, барьер, safe zone, табличка
      ItemService.luau         экипировка, Swap, выпадение на пол, подбор
      MannequinService.luau    волны дропа, ролл редкости и мутации
      EconomyService.luau      тик дохода, множители
      PlayerDataService.luau   данные игрока (пока в памяти, ProfileStore в Фазе 3)
      AnnouncementService.luau уведомления и баннеры
    Util/
      CollisionGroups.luau     группы столкновений для барьеров и предметов на полу
      RateLimiter.luau         ограничение частоты Remote-вызовов
  shared/                      -> ReplicatedStorage/Shared
    Types.luau, Remotes.luau, ItemUtil.luau, ItemVisuals.luau, Format.luau
    Config/                    GameConfig, Items, Rarities, Mutations, Levels
  client/                      -> StarterPlayerScripts/Client
    Main.client.luau
    Controllers/               HUD, Notification, Swap, Effects
    UI/Theme.luau              цвета, шрифты, масштабирование под экран
```

Весь баланс в `src/shared/Config/`. Сервер единственный источник правды по деньгам и предметам; клиент только показывает состояние и отвечает на предложение Swap.

## Проверки кода

```
selene src
stylua --check src
```

Типы проверялись [luau-lsp](https://github.com/JohnnyMorganz/luau-lsp) со строгим режимом и определениями Roblox (`rojo sourcemap -o sourcemap.json`, затем `luau-lsp analyze --sourcemap sourcemap.json --definitions=globalTypes.d.luau src`), на старом и новом солвере.
