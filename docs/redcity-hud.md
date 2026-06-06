# RedCity HUD

Resource: `resources/[redcity]/redcity_hud`

## Features

- Vehicle HUD is a small dark glass capsule at the bottom center.
- On-foot player info shows server ID, date, time, and voice mode.
- Status HUD shows HP, armor, hunger, and stress near the lower-left safe area.
- Seatbelt command uses `B` and exports `IsSeatbeltOn`.
- Voice range command uses `Z`; pma-voice is used when available, otherwise it falls back to a local three-mode cycle.
- Fuel supports LegacyFuel, ox_fuel, cdn-fuel, then native `GetVehicleFuelLevel` / `SetVehicleFuelLevel`.
- Gas stations add blips, marker interaction, ESX payment, and progressive refueling.
- Radar is hidden on foot and restored in vehicles when `Config.HUD.HideRadarOnFoot = true`.

## Config

Edit `config.lua`.

- HUD scale: `Config.HUD.Scale`
- HUD theme colors: `html/style.css` CSS variables under `:root`
- Vehicle position: CSS `.vehicle-hud` bottom/left values
- Seatbelt key and warning speed: `Config.Seatbelt`
- Voice key and colors: `Config.Voice`
- Fuel price and consumption: `Config.Fuel`
- Engine failure threshold: `Config.VehicleDamage.EngineFailHealth`
- Gas station coordinates: `Config.GasStations`
- Real time vs game time: `Config.UseRealTime`

## Server.cfg

Start after ESX status/basicneeds:

```cfg
ensure esx_status
ensure esx_basicneeds
ensure redcity_hud
```

Do not commit real `server.cfg`, `secrets.cfg`, `txData`, logs, cache, or database dumps.
