# Getting started

Five minutes from a pile of unnamed audio to a named project folder.

## 1. Install the app

[Download the latest Mac app](https://github.com/koostix/music-projects-organizer/releases/latest/download/Music-Projects-Organizer.zip).

Unzip, drag **Music Projects Organizer** into Applications, then right-click → **Open** the first time.

Needs macOS 14 or later. To build from source instead, see the [README](../README.md#build-from-source).

Open **Music Projects Organizer** from Applications or Spotlight.

## 2. Decide what to point it at

**Inbox mode** (default) watches:

- `~/Desktop/_Music Projects/_Inbox` — every folder you drop
- unnamed folders in `_Start` and `2_Revise`
- unnamed Logic packages in `~/Music/Logic`

**Any folder** — press `⌘O` and pick a dump, an SD-card folder, `_Start`, a USB drive, or a session you already named and want to retitle.

If those library folders do not exist yet, create them or ignore them and just open folders.

## 3. Inspect

Select a pile in the sidebar.

- The contents list is clickable. Audio loads the waveform and plays.
- Click the same file again to pause. Click another file to switch.
- Drag the waveform to scrub. Release to play from there.
- Folders and other files reveal in Finder.

A folder of only audio (Tascam `EX000_*.WAV`, a TapeLooper dump) is treated as one project. A folder of project folders lists those, plus any leftover loose files.

## 4. Name it

```
YYMMDD_description_BPM
260323_underwater guitar_92
```

- **Date** defaults to the date already on the folder, or the oldest file.
- **Description** — spaces are fine. Slashes and colons become spaces.
- **BPM** is 20–300, or **000** if the song has no tempo. Click a file to play it. Tap a quarter note with **Space**. Two taps fills the field. Leave `000` for drones, rubato, or Tascam dumps with no click.

Already-named folders are parsed so you can retitle them.

## 5. File it

Pick a destination:

| Destination | What happens |
|---|---|
| **Here** | Rename in place. Loose files are wrapped into a new folder. |
| **_Start** | Move into `~/Desktop/_Music Projects/_Start` |
| **Choose…** | Move into a folder you pick |

Inbox and untitled Logic dumps default to `_Start`. Everything else defaults to **Here**.

Hit Return. The pile is moved, not copied. Same volume only.

Skip with `⌘.` if this one can wait.

## Typical first day

1. Drop a recorder dump into `_Inbox`, or `⌘O` the folder itself.
2. Click the mix (or the largest take). Listen.
3. Type a short description.
4. Tap tempo if you do not know it.
5. Return.

Finder now has something like:

```
~/Desktop/_Music Projects/_Start/260323_underwater guitar_92/
```

## Tips

- Close Logic before filing a pile that contains a `.logicx`.
- **Unnamed only** hides folders that already look named.
- `⇧⌘I` jumps back to Inbox after you have been browsing.
- You can rename a named project later the same way. The form prefills from `YYMMDD_description_BPM`.

## Rebuild after a code change

```bash
cd music-projects-organizer
./scripts/package-app.sh
cp -R "dist/Music Projects Organizer.app" ~/Applications/
```
