<h1 align="center">XS-PoliceSystem</h1>

<p align="center">A complete police job and jail for <strong>QBox</strong> and <strong>QBCore</strong>. Replaces qbx_police, qb-policejob and qb-prison.</p>

<p align="center">
  <a href="https://github.com/XyraL/XS-PoliceSystem/releases"><img src="https://img.shields.io/github/v/release/XyraL/XS-PoliceSystem?include_prereleases&style=flat-square&color=3b82f6&label=release" alt="Latest release"></a>
  <img src="https://img.shields.io/badge/framework-QBox%20%7C%20QBCore-55dcff?style=flat-square" alt="framework">
  <img src="https://img.shields.io/badge/price-free-30d158?style=flat-square" alt="price">
  <a href="https://xyralscripts.dev/docs-xs-policesystem"><img src="https://img.shields.io/badge/docs-xyralscripts.dev-a889ff?style=flat-square" alt="docs"></a>
  <a href="https://discord.gg/XRURAw4TM2"><img src="https://img.shields.io/badge/support-discord-5865F2?style=flat-square" alt="support"></a>
</p>

<p align="center">
  <a href="https://xyralscripts.dev/xs-policesystem">Website</a> &nbsp;·&nbsp;
  <a href="https://xyralscripts.dev/docs-xs-policesystem">Setup guide</a> &nbsp;·&nbsp;
  <a href="https://github.com/XyraL/XS-PoliceSystem/releases">Releases</a> &nbsp;·&nbsp;
  <a href="https://discord.gg/XRURAw4TM2">Discord</a>
</p>

---

XS-PoliceSystem is the whole police job in one resource. You build your stations, prisons and impound lots in game, officers work from a quick action wheel that never takes the mouse, and the jail counts down only while the prisoner is online.

Nothing a prisoner or a suspect does gets them out early. Cuffs and jail time stay on the character through a logout or a crash, and come back the moment they log in.

## Features

- QBox and QBCore support
- In-game builder for any number of stations, prisons and impound lots, for any number of departments
- Stations: duty, lockers and outfits, armory by rank, garage and helipad with liveries and extras, evidence room, booking desk and boss office
- Armory shows a photo of every item, taken from your inventory's own images
- Evidence lockers numbered 1 to 9999, each with a case note, at every station
- Forensics: shooting leaves bullet casings with the gun's serial, getting hurt leaves blood, and robbery scripts leave fingerprints. Officers find them with a flashlight and bag them
- Prints & DNA on the wheel: scan a suspect and see if they match the evidence bags you carry
- On-duty officers see each other on the map with their callsigns. Set your own with `/callsign`, or the boss sets them in the boss office
- Tackle: sprint at someone and press G
- Live body cams and dash cams on every officer on duty, watched from a station camera room, with sound through pma-voice
- Security cameras at every bank and store, with the same numbers robbery scripts already send
- Helicopter camera with zoom, night and thermal vision, lock-on, the target's plate and speed, a spotlight and rappelling
- Radar in police cars with front and rear speeds and a plate reader, plus fixed speed cameras that fine speeders
- Flagged plates that the radar, the helicopter camera and speed cameras warn about
- Breathalyzer and drug swab, fed by the drinks and drugs in your other scripts
- Driver and firearm licences checked, given and taken on the wheel
- Ankle monitors that show the wearer on the officer map
- qb-policejob's chat commands, from /cuff and /cam to /flagplate, /takedna and /paytow
- Search a car's trunk, or its glovebox from inside, on any supported inventory
- Slow or stop the traffic around a scene
- Officer-down alerts with a blip when an on-duty officer goes down
- Police dogs: follow, stay, sniff people and cars for drugs, bite on command and ride in the car
- People without gloves leave prints on their casings and on cars they get into. Officers dust cars for prints
- A forensic lab at the station that names who the DNA and prints belong to, and who carries the gun a casing came from
- Bleach for criminals to clean up blood, casings and prints
- Community service in areas you build: sweeping spots, a task count that survives logouts, and extra tasks for walking off
- Booking mugshots with the height board, shown on the ID card check
- A prison siren on escapes and prison breaks, and solitary cells
- A duty clock: hours on duty this week and in total for every officer, in the boss office
- Impound to a lot of your choice with a hold time, a release fee and an optional police hold. Owners pay at the lot's desk and the car is parked for them
- Blip creator: any of the 966 map icons, any colour and size, shown to everyone, police, or police on duty
- Floor markers at points, on or off for each place
- Quick action wheel on F6: small, at the side of the screen, and you keep walking and looking around while it is open
- Wheel editor in the builder: order, menus, names, icons, who sees what by department and rank, and your own actions that run a command or event
- Officers pin their favourite actions to the front of their own wheel with G
- Cuff, escort, search, seize cash, check ID, GSR test, seat in a car, take out of a car, run a plate, impound, cones, barriers, spike strips, fines, jail, your MDT and a panic button
- Suspects can pull away from the cuffs with a quick skill check unless they have their hands up
- Jail with cells, prison jobs you make in the builder, workout stations, a canteen menu, a release desk and an escape alert, plus a one-click Bolingbroke layout
- Belongings are taken at the door and handed back on release, serial numbers and all
- Prisoners wear the jail outfit and get their own clothes back when they leave
- Boss office: hire someone nearby, change ranks, let people go (online or offline), and the department account
- Drop-in replacement for qbx_police, qb-policejob and qb-prison. Robbery scripts, radial menus, phones, inventories, medical scripts and MDTs keep working
- Works with XS-MDT, XS-Dispatch and XS-Medical when they are running, and needs none of them

## Requirements

- [qbx_core](https://github.com/Qbox-project/qbx_core) or [qb-core](https://github.com/qbcore-framework/qb-core)
- [ox_lib](https://github.com/overextended/ox_lib)
- [oxmysql](https://github.com/overextended/oxmysql)
- Optional: a target, an appearance, a vehicle keys, a banking and a dispatch resource. They are picked up on their own

## Install

1. Stop qbx_police, qb-policejob and qb-prison and take them out of `server.cfg`. XS-PoliceSystem answers for all three, so running both would fight over every arrest.
2. Drop `XS-PoliceSystem` into your resources folder.
3. Add it to `server.cfg` after its dependencies:
   ```
   ensure ox_lib
   ensure oxmysql
   ensure XS-PoliceSystem
   ```
4. Give your staff the builder:
   ```
   add_ace group.admin xs.police.admin allow
   ```
5. Add the items. Paste `items/ox_inventory.lua` into `ox_inventory/data/items.lua` and `items/ox_inventory_weapons.lua` into the Weapons table in `ox_inventory/data/weapons.lua`, or `items/qb_core.lua` into `qb-core/shared/items.lua`. Replace any entries with the same name (handcuffs and the evidence bags are already there on most QBCore servers).
6. Copy `inventory_images/*.png` into your inventory's image folder.
7. Restart the server. The tables are made on first start.
8. Run `/policebuilder` in game and build your first station and prison.

Police are anyone with a job named `police`, `lspd`, `bcso`, `sasp`, `sast` or `ranger`, or a job of type `leo`. Change that in `Config.Jobs`.

## The builder

`/policebuilder` opens the builder. The **Overview** shows how far your setup has got, lists anything missing (no duty point, a garage with no cars, a tunnel with no exit) with a button straight to it, and starts a whole place in one click: **Mission Row PD**, **Paleto Bay Sheriff** or **Bolingbroke Penitentiary**. Each place has a **Layout** tab with a top-down plan of its points to scale, and a **Live** switch that hides it from players without deleting it. A prison with inmates or a lot holding cars cannot be switched off or deleted.

Press **Ctrl+K** to search places and settings, **Ctrl+S** to save, and **Walk the site** to hide the builder and walk around with every point labelled. Backspace brings it back.

### Settings in game

**Settings** in the builder holds about 150 options from config.lua: duty, ranks, cuffing, forensics, fines, impound, radar, K9, prison, community service and more. Saving puts them live for everyone straight away, no restart. What you save is kept in the database and wins over config.lua, and **Reset** puts a setting back to the config.lua value. Only the qb-policejob chat commands switch needs a restart.

## Building a station

Go to **Stations** and press **New station**. Every point is placed with a free camera or at your own feet:

| Point | What it does |
|---|---|
| Duty | Clock in and out |
| Locker room | Change outfit and open your own locker |
| Armory | Weapons and gear by rank |
| Garage | Take out and put away cars. Set a spawn spot for each one |
| Helipad | Helicopters for higher ranks |
| Evidence | Numbered evidence lockers. Type a number from 1 to 9999 to open one |
| Booking | Send a cuffed suspect to jail |
| Boss office | The department's office: roster, records, armory and garage, money and the activity log |
| Camera room | Live body cams and dash cams of every officer on duty |

The **Armory** tab sets what each rank can take and what it costs. The **Garage** tab sets the cars and helicopters, the lowest rank for each, the livery and which extras are on. **Options** picks which departments use the station, the plate prefix and the floor markers, and **Map blip** sets its blip. Leave every department unticked and all of them can use it.

### Evidence lockers

The evidence point opens the evidence room. Type a locker number, add a case note if you like, and open it. Every locker used at the station is listed with its note, who last opened it and when, so you can search by number or note. Each station has its own lockers 1 to 9999. Set `Config.Evidence.shared = true` to make locker 12 the same locker at every station.

### Boss office

The boss office is the department's own screen. **Roster** lists every officer with their rank, callsign, status and hours. Bosses promote, demote, set callsigns, hire someone standing next to them and let people go. Each officer has a record of notes, warnings and commendations, and warnings and commendations tell the officer. **Armory** and **Garage** let the boss change what each rank can take and drive at their station, picking from the items and cars in `Config.Boss`, so nobody hands out gear the server never meant police to have. Admins can add anything in the builder. **Money** shows the account, deposits and withdrawals, and where this week's money came from. **Activity** is the department's log of arrests, fines, impounds, evidence and staff changes, with search and filters. Opening it needs `Config.Grades.manage` or the boss flag.

### Armory photos

Item photos come from your inventory's image folder: ox_inventory, qb-inventory, ps-inventory, qs-inventory, codem-inventory and core_inventory are picked up on their own. For anything else, set `Config.Armory.images` to your folder, like `'nui://my_inventory/html/images/%s.png'`. An item with no photo shows a plain icon.

## Building a prison

Go to **Prisons** and press **New prison**, or start from **Bolingbroke Penitentiary** on the Overview, and place:

- **Cells**, where prisoners are put. Add a few
- **Canteen**, where prisoners pick a meal
- **Workout** stations: push-ups, sit-ups, chin-ups, free weights, yoga or jogging on the spot. A set lowers stress, and can take time off with `Config.Jail.workout.credit`
- **Release**, where prisoners walk out and collect anything that did not fit in their pockets
- **Guard posts**, where a guard stands. With two or more, guards patrol between them
- **Commissary**, a clerk where inmates spend their credit
- **Inmate trader**, an inmate who deals in cigarettes
- **Workbench**, a hidden spot for making tools
- **Hidden stashes**, a loose tile or a vent any inmate can hide things in. Give each one a name
- **Tunnels** and **weak fences**, each with the spot where it comes out

The **Prison jobs** tab holds the prison's jobs. Each one has a name, what it looks like (sweeping, cleaning, electrical repairs, kitchen duty, gardening and more), how long a task takes, how much time it takes off, the commissary credit it pays, and its own spots. A prisoner walks up to a spot and does the task, and the next spot of that job lights up so they keep moving. A spot cannot be done again for `Config.Jail.spotCooldown` seconds. A new prison starts with five jobs ready for their spots.

The **Canteen** tab sets the meals. Each meal is a tray of up to six items. Prisoners pick one, then wait the set minutes before the next.

On the **Options** tab, set the centre of the prison and the escape radius. Leaving that circle counts as an escape, and every officer on duty is told. While you build it is shown as a red ring.

**Use the Bolingbroke layout** on the Options tab fills in Bolingbroke Penitentiary for you: 11 cells, the electrician job with 7 spots, the canteen, two workout spots, the release point and the escape circle.

## Building an impound lot

Go to **Impound lots** and press **New impound lot**, then place:

- **Release desk**, where owners pay and collect, and where police see the lot's records. A clerk stands there unless you clear the clerk model on the **Options** tab
- **Parking bays**, where a released car is parked for its owner. Add a few

**Options** sets the lot's usual release fee, which departments can see the records and clear holds, the clerk and the floor markers.

When an officer impounds a car from the wheel, they pick the lot, how long it is held (none, hours or days, counted in real time; the form starts on `Config.Impound.defaultHold`, no hold by default), the fee and a reason. A **police hold** keeps the car until an officer clears it. At the desk, owners see their cars, how long is left and the fee, and pay to have the car parked in a free bay with its keys. Officers of rank 2 and up (`Config.Grades.impoundRelease`) can clear a hold or waive the fee there.

With no lot built, impounding sends the car to your garage script's depot for `Config.Impound.fee` instead.

Holds are kept with qb-garages and qbx_garages: a held car does not show in their garages or depots until it is collected at the lot. Garage scripts with their own impound columns, such as jg-advancedgarages, cd_garage or okokGarage, may still list a held car. Set `Config.Impound.heldState` if your garage needs a different value.

## Map blips

Every station, prison and impound lot has a **Map blip** tab, and **New map blip** under **Map blips** makes a blip on its own. Pick an icon from the police set or search all 966, pick a colour, the size, the name, who sees it (everyone, police, or police on duty) and whether it only shows on the minimap when close. The blip shows on your map while you edit it, so you can see it before you save.

## Floor markers

Each place has a **Floor markers** switch on its **Options** tab. Off, the points have no ring on the floor and still work with your target script or the [E] prompt. `Config.Markers` is what a new place starts with.

## The wheel

Press **F6** to open the wheel on duty. Scroll or press 1 to 9 to pick, left click to use, right click to go back. It does not take the mouse, so you can walk and look around while it is open, and whoever the action will hit is marked.

Every action can be switched off in `Config.Wheel.actions`. Set `holdToOpen = true` if you would rather hold the key and let go to use.

Open `/policebuilder` and pick **Quick action wheel** to change it. Drag the entries or use the arrows to reorder them, move actions between menus, make new menus, and rename any entry or give it another icon. Each action can be kept to some departments and a lowest rank. For the built-in actions the server checks this too, so a hidden one cannot be run another way. **Your own action** adds an entry that runs a command, a client event or a server event, for things like an emote, a radio or another script's menu. The main ring has number keys for its first nine entries. Save and every officer has the new wheel straight away. **Reset to default** puts the original wheel back.

Officers press **G** on an action while the wheel is open to pin it to the front of their main ring, and again to unpin it. Pins are saved per character. `Config.Wheel.favourites` sets how many (4 by default, 0 turns pinning off) and `Config.Wheel.pinKey` the key.

The **MDT** button opens your MDT. It finds XS-MDT, ps-mdt, redutzu-mdt, kartik-mdt, tk_mdt, drx_mdt, CodeM's PD MDT (codem-mdtv2), origen_police, qs-dispatch, lb-tablet or qb-mdt on its own, in that order. For anything else, set `Config.MDT.resource = 'command'` and the command it opens with. With no MDT found, the button is hidden.

## Forensics

Shooting a gun drops bullet casings where they land, and a burst piles up in one spot as "6 bullet casings". Getting hurt drops blood, and a badly hurt player leaves a trail as they move. Robbery scripts that use qb-policejob's evidence events (store, jewellery, house and bank robberies) leave fingerprints. Evidence lasts `Config.Forensics.minutes`.

On-duty officers see evidence in the beam of a flashlight, handheld or on a weapon. Point it around a scene and the casings, blood and prints light up. Stand on one and press **E** to bag it. That uses an empty evidence bag (the armory hands out 10 at a time) and gives a sealed bag that records what it is, where it was found, when, and who bagged it:

- **Casings**: the round, how many, and the serial number of the gun that fired them
- **Blood**: the blood type and a DNA code
- **Fingerprints**: the print code

File the bags in an evidence locker under the case number.

Get close to a piece of evidence and a field note shows what you can tell by eye: how fresh it is, the kind of gun and how many casings, whether one carries a print, and how much blood there is.

Gloves matter. Someone shooting without gloves can leave a print on the casings (`Config.Forensics.printOnCasing`), and anyone who gets into a car without gloves leaves prints on it for a few hours. **Dust for prints** on the wheel (Vehicle) lifts every print on the nearest car into one evidence bag. Gloves are checked with your framework's own glove check.

**Bleach** (the `bleach` item) lets anyone clean up the blood, casings and prints within 5 metres of them.

### Forensic lab

Place a **Forensic lab** point at a station in the builder. Officers standing at it see the evidence bags they carry and work them at the bench: casings go under a comparison microscope to line up the marks, blood goes through a DNA run, and prints are turned until the ridges sit on the one on file. DNA and prints are matched to a name, even for people who are offline, and a casing's serial number to whoever carries that gun, along with any print on the casings. The report lists every fact and any earlier report with the same gun, DNA or print, so scenes link up. Each report is saved at that station.

**Prints & DNA** on the wheel (Person menu) takes a restrained suspect's fingerprints and a DNA swab. The scanner shows their print and DNA codes, open warrants from XS-MDT, how often they have been booked and how many lab reports they are linked to, and lists any evidence bags you are carrying that match them. Copy the print, DNA or citizen ID with one press, or open their XS-MDT profile straight from the scanner (other MDTs just open). Gloves stop the scan until they come off (`Config.Forensics.glovesBlock`).

Set `Config.Forensics.flashlight = false` to show evidence up close without a flashlight, or `bag = false` to bag without an item. Other scripts can leave evidence with `exports['XS-PoliceSystem']:AddEvidence('fingerprint', source, coords)` or `'blood'`.

### Evidence from another script

Set `Config.Bridges.evidence` to use another evidence script. `'auto'` uses [evidences](https://github.com/noobsystems/evidences) when it is running and ours otherwise. With another script, ours stops dropping casings, blood and prints, Prints & DNA, Dust for prints and the lab point are hidden, and the qb-policejob evidence events robbery scripts send are passed on to evidences. `'none'` turns scene evidence off.

## Officers on the map

On-duty officers see each other on the map, with their callsign and name. The blip shows whether they are on foot or in a car, helicopter, plane or boat, and turns red and flashes when they press panic. On-duty EMS show too (`Config.UnitBlips.jobs`), and each job has its own colour.

Officers set their own callsign with `/callsign 2-A-14`. Bosses can set anyone's in the boss office, even when that officer is offline. Callsigns show on the map, on panic alerts and in the boss office roster. Set `Config.Callsign.command = ''` to leave callsigns to the boss office only.

## Body cams and dash cams

Every officer on duty has a body cam running, and every car taken out of a station garage has a dash cam. Place a **Camera room** point at a station to watch them. It shows every officer on duty with their callsign, rank, the street they are on and whether they are on foot or in a car, and it updates every few seconds.

| Camera | What you see |
|---|---|
| Body cam | Chest height, wide angle, facing where the officer faces |
| Dash cam | From behind the windscreen of their station car, with speed, heading, lights, siren and the speed of the car in front |
| Back seat | The rear cabin of their station car, facing the back seat |

The dash cam belongs to the car, so it keeps running when the officer gets out. While watching, **A** and **D** go to the next officer, **1**, **2** and **3** switch between the cameras, **M** turns the sound on and off, and **Backspace** goes back to the camera room. With pma-voice you hear what the officer hears. The minimap follows the unit.

Officers are not told when their camera is watched. The feed closes if you get hurt, and drops when the officer goes off duty or is out of range for a few seconds. Every viewing is in the boss office activity log.

Supervisors can also watch from **Unit cams** on the wheel (Paperwork) and from the MDT, from `Config.UnitCams.remoteGrade` up. Set `remote = false` to keep it to the camera room. `anyEmergencyVehicle = true` gives a dash cam to any emergency vehicle an officer is driving, not just station cars.

## Security cameras

The 34 bank and store cameras from qb-policejob are in `Config.Cameras`, with the same numbers. When a robbery script sends an alert with a camera, officers are told which one saw it. **Cameras** on the wheel (Paperwork) lists them all, with the last alert's camera at the top, and `/cam 22` opens one directly. A or D switches cameras, the mouse turns the ones that can turn, scroll zooms and Backspace leaves. Cameras a robbery script turns off show no signal.

## Helicopter camera

In a police helicopter (`Config.Heli.models`), press **E** for the camera. Right click switches day, night and thermal vision, scroll zooms and space locks onto a vehicle, which shows its model, plate, speed and street. A flagged plate is reported to every officer. **H** turns the spotlight on for everyone to see, and **X** rappels from a back seat.

## Radar and flagged plates

**F5** in a police car shows the radar: the speed of the car ahead and behind, the fastest reading and your own speed. **Numpad 5** locks the readings. The plate reader shows both plates and beeps when one is flagged.

**Flag plate** on the wheel (Vehicle) flags the nearest car's plate with a reason, for a few hours or until removed. `/flagplate`, `/unflagplate` and `/plateinfo` work too, and running a plate shows its flag. Flags are saved, and the radar, the helicopter camera and speed cameras warn every officer when a flagged plate goes past.

The 11 fixed speed cameras from qbx_police are in `Config.SpeedCameras`, off by default. Turned on, they fine drivers going over the limit from the bank (the fine goes to the police account) and report flagged plates.

## Breathalyzer and drug swab

**Breathalyzer** and **Drug swab** on the wheel (Person) test the person in front of you. The breathalyzer shows their blood alcohol against `Config.Tests.bacLimit`, and the oral fluid test shows cannabis, cocaine, meth and opiates.

The results come from what your other scripts report through qb-policejob's `evidence:client:SetStatus`, which drink and drug items already use. `Config.Tests.drugs` says which of those statuses each test line picks up. Scripts can also call `exports['XS-PoliceSystem']:SetStatus(source, 'alcohol', seconds)`.

## Licences and ankle monitors

**Licences** on the wheel (Person) shows someone's driver and firearm licences. Any officer can take one, and officers of rank 2 and up (`Config.Grades.licences`) can give one. `/grantlicense`, `/revokelicense` and `/takedrivinglicense` work too.

**Ankle monitor** puts a GPS monitor on a restrained person, or takes it off. It stays on through a logout, and on-duty officers see the wearer on their map.

## Scene work

**Search car** on the wheel (Vehicle) opens the nearest car's trunk, or the glovebox when you are inside it. It works with ox_inventory, qb-inventory and the older inventories.

Cones, barriers and spike strips are picked up by looking at them with your target and choosing **Pick up**, or with **Pick up** on the wheel (Scene) next to them.

**Slow traffic** and **Stop traffic** on the wheel (Scene) make NPC cars crawl or stop within 40 metres of you, shown to officers as a circle on the map. Press it again in the same spot to clear it. Zones clear on their own after 20 minutes (`Config.Traffic`).

When an on-duty officer goes down, every other officer gets an alert and a blip with their callsign.

## K9

Officers call a dog from the wheel (Scene > K9). The dog follows you, sits on command and keeps up if you get far ahead. Every command works on the person or car you are looking at.

- **Sniff** walks the dog round the car or person. It sits and barks on anything in `Config.K9.find` that they carry, or that is in the car's trunk, glovebox or on anyone inside
- **Track** finds the nearest person who is not police within `Config.K9.trackRadius`, runs to them and barks
- **Send dog** sends it after the person for a few seconds
- **Guard** sits the dog next to a suspect. If they run or move away, it takes them down. Cuffing them ends it
- **Bark** barks at them
- **Follow / stay** also calls the dog back from anything it is doing
- **In / out of car** puts it in a free back seat and takes it out again

`Config.K9` sets the rank and departments that can have one, and the ranges.

## Tackle

Sprint at someone and press **G** to tackle them. They go down for `Config.Tackle.seconds` and you dive with them. Only officers can tackle unless `Config.Tackle.anyone` is on, and there is a cooldown between tackles. The key can be changed in the game's key bindings.

## Community service

Build a **Service** area in the builder and place its task spots. **Community service** on the wheel (Paperwork) gives a restrained person a number of tasks. They are taken to the area, take the cuffs off and sweep up at one spot after another, each task taking `Config.Service.seconds`. Walking more than 60 metres away brings them back and adds tasks (`Config.Service.penalty`). The tasks left are saved, so logging out does not get them out of it. Other scripts can call `exports['XS-PoliceSystem']:SendToService(source, tasks, reason)`.

## Mugshots

The booking point at a station has **Take a mugshot**. The restrained person holds up the height board with their name, citizen ID and the date, the officer's camera frames their face, and the photo is saved. It shows on the ID card check, and other scripts can read it with `exports['XS-PoliceSystem']:GetMugshot(citizenid)`. The photo needs screenshot-basic running; without it the pose still happens but nothing is saved.

## Jail

A sentence is in months, and one month is one minute by default (`Config.Jail.minutesPerMonth`). Time only counts while the prisoner is online. Logging out or crashing saves the time left, and they go straight back to a cell when they log in.

Belongings are taken at the door and stored with the sentence. They are handed back on release. Anything that does not fit waits at the release desk.

When someone escapes, the prison siren sounds for everyone near the prison for `Config.Jail.alarmMinutes`. Robbery scripts can start a prison break, which sounds the siren and alerts officers, with `exports['XS-PoliceSystem']:PrisonBreak(jailId)`. `StartPrisonAlarm`, `StopPrisonAlarm` and `IsPrisonAlarmActive` are there too, and old scripts asking qb-prison about the alarm get the real answer.

Place **Solitary cells** in a prison in the builder. **Solitary** on the wheel (Paperwork) sends the inmate in front of you there for `Config.Jail.solitaryMinutes`, with no jobs, canteen or workouts. Their sentence keeps counting, and pressing it again lets them out early.

### Prison life

Guards stand at the guard posts and patrol between them. Every few minutes (`Config.Jail.contraband.searchMinutes`) they pat down an inmate near a post, take any contraband and add time.

Prison jobs pay commissary credit as well as taking time off, and can turn up scrap metal or a spoon. Credit is spent at the commissary on food, cigarettes and phone calls, which send a message to someone in the city. Credit survives logging out, and `Config.Jail.creditPayout` can pay what is left in cash at release.

The inmate trader deals in cigarettes: scrap, spoons and lockpicks for sale, and he takes shivs and food. At the workbench, scrap becomes a shiv, a lockpick or wire cutters (`Config.Jail.recipes`).

Tunnels are dug with a spoon over several sessions (`Config.Jail.breakout.tunnelSessions`), and spoons can snap. A weak fence is cut with wire cutters in one go. Either way, a guard post close by may catch them at it and add time. Going through comes out at the exit placed in the builder, sets off the prison alarm and alerts every officer on duty.

Every cell has a stash under the mattress. Each inmate has their own, and it is still there the next time they are locked up. Hidden stash spots are shared by every inmate who finds them. Guards never search either one (`Config.Jail.bedStash`, `Config.Jail.hiddenStash`).

At release, everything picked up inside is taken before their own items are handed back, so cutters and shivs stay in the prison (`Config.Jail.releaseClear`).

The new items are `prison_scrap`, `prison_spoon`, `prison_shiv`, `prison_cutters` and `prison_cigarettes`, in `items/` with their images.

The shiv fights like a knife. On ox_inventory it is a weapon (`items/ox_inventory_weapons.lua`) and goes on your hotbar like one. On other inventories, use it to pull it out and use it again to put it away.

## Duty clock

Every minute on duty counts. The boss office roster shows each officer's hours this week (from Monday) and in total.

## Coming from qbx_police, qb-policejob or qb-prison

There is nothing to move. `ishandcuffed`, `injail` and `criminalrecord` are kept in the same place, and the old events and exports still answer:

- `police:server:policeAlert` from robbery scripts, in both the old and the new style
- `police:SetCopCount`, `police:GetCops` and the other cop-count checks
- The handcuffed flag and `invBusy`, so inventories, phones and radial menus lock up while cuffed
- The qb-radialmenu and qbx_radialmenu police actions
- `police:client:GetCuffed` and `police:client:DeEscort` from medical scripts are accepted but do nothing, so going down never takes the cuffs off
- `police:client:SendToJail`, `prison:client:Enter` and `police:server:JailPlayer` from MDTs and tablets
- `exports['qb-policejob']:IsHandcuffed()`
- `evidence:server:CreateFingerDrop` and `evidence:server:CreateBloodDrop` from robbery and medical scripts, which now leave real evidence
- `police:GetDutyPlayers` with each officer's callsign

Nothing a client sends can take cuffs off or shorten a sentence. Events that used to trust the client, such as `police:server:SetHandcuffStatus` and `prison:server:SetJailStatus`, are ignored.

With XS-MDT, set `Config.JailResource = 'qb-prison'` in the MDT and sentences from the MDT go straight to this jail.

## With XS-MDT

When XS-MDT 3.1 or newer is running, the two share their records:

- Flagged plates and MDT BOLOs are the same list. A BOLO on a plate, or a car flagged stolen in the MDT, sets off the radar, helicopter camera and speed cameras, and a plate flagged from the wheel shows up in the MDT as a BOLO. Clearing either side clears both
- Mugshots taken at booking become the MDT profile photo
- The MDT profile has a Custody tab with the person's ankle monitor, community service and forensic lab matches
- The ID check stamps WANTED with the number of active MDT warrants, and running a plate tells you when the owner is wanted
- Watching a body cam from the MDT opens our body cam, with the dash cam and back seat camera a key away

## Commands

| Command | Who | What |
|---|---|---|
| `/policebuilder` | Admins | Opens the builder |
| `/policewheel` (F6) | Police on duty | Opens the wheel |
| `/unjail [id]` | Admins and police | Releases someone from jail |
| `/callsign [callsign]` | Police | Sets your callsign |
| `/cam [number]` | Police | Watches a security camera |
| `/flagplate [plate] [reason]` | Police | Flags a plate. `/unflagplate` and `/plateinfo` too |
| `/grantlicense [id] [driver/weapon]` | Police, rank 2+ | Gives a licence. `/revokelicense` takes one |
| `/anklet`, `/ankletlocation [citizenid]` | Police | Ankle monitor on or off, and where one is |
| `/takedna [id]` | Police | Bags a DNA sample |
| `/clearcasings`, `/clearblood` | Police | Clears evidence within 10 metres |
| `/paytow [id]`, `/paylawyer [id]` | Police | Pays a tow driver or lawyer from the department account |
| `/911p [message]` | Everyone | Reports something to the police |
| `/cuff`, `/escort`, `/seizecash`, `/fine`, `/pobject`, `/spikestrip` | Police | The wheel actions as commands |
| F5, Numpad 5 | Police | Radar, and locking it |
| Tackle (G) | Police | Tackles the person you are sprinting at |
| `/policediag` | Everyone | Shows what XS-PoliceSystem picked up, for support |

## Exports

Server:

```lua
exports['XS-PoliceSystem']:SendToJail(source, months, reason)
exports['XS-PoliceSystem']:ReleaseFromJail(source)
exports['XS-PoliceSystem']:IsInJail(source)
exports['XS-PoliceSystem']:JailTimeLeft(source)   -- seconds
exports['XS-PoliceSystem']:IsHandcuffed(source)
exports['XS-PoliceSystem']:SetHandcuffed(source, true)
exports['XS-PoliceSystem']:IsEscorted(source)
exports['XS-PoliceSystem']:GetCopCount()
exports['XS-PoliceSystem']:ImpoundedVehicles(citizenid) -- cars held at impound lots
exports['XS-PoliceSystem']:AddEvidence('fingerprint', source, coords) -- or 'blood'
exports['XS-PoliceSystem']:GetCallsign(source)
exports['XS-PoliceSystem']:FlagPlate(plate, reason, hours) -- 0 hours is until removed
exports['XS-PoliceSystem']:UnflagPlate(plate)
exports['XS-PoliceSystem']:IsPlateFlagged(plate)
exports['XS-PoliceSystem']:SetStatus(source, 'alcohol', seconds)
exports['XS-PoliceSystem']:SendToService(source, tasks, reason)
exports['XS-PoliceSystem']:GetMugshot(citizenid) -- a jpeg data URL, or nil
exports['XS-PoliceSystem']:PrisonBreak(jailId)
exports['XS-PoliceSystem']:StartPrisonAlarm(jailId, minutes)
exports['XS-PoliceSystem']:GetPlateFlag(plate)
exports['XS-PoliceSystem']:GetProfile(citizenid) -- ankle monitor, community service, lab matches, mugshot
```

Client:

```lua
exports['XS-PoliceSystem']:IsHandcuffed()
exports['XS-PoliceSystem']:WatchUnit(serverId, 'body') -- or 'dash' or 'cabin'
exports['XS-PoliceSystem']:OpenUnitCams()
exports['XS-PoliceSystem']:IsWatchingUnitCam()
```

## License

See [LICENSE](LICENSE).
