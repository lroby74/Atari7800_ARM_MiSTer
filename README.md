# Atari 7800 for MiSTer — with ARM coprocessor support

Plays the Atari 7800 and Atari 2600 libraries on MiSTer, and adds the one thing
the official core cannot do: **cartridges built around an ARM coprocessor.**

Load the RBF, put your games in the `Atari7800` folder, and play. Everything
below is about what you get and how to set it up.

## The headline

The official core shows an **Out of Order** screen when you load a CDF, CDFJ,
CDFJ+ or DPC+ cartridge — the modern Harmony and Melody games. Its own README
explains why: those games *"require a 70mhz ARM cpu, which would be either very
difficult, or impossible, to have run properly on the cyclone V that MiSTer FPGA
uses"*.

**Here they run.** Draconian, Galagon, Wizard of Wor Arcade, Gorf Arcade,
Scramble Arcade, Space Rocks, Zoo Keeper, Qyx, Stay Frosty 2, Neon Run and the
rest of the Champ Games catalogue. Atari 7800 cartridges with an ARM
coprocessor start and run too.

## Fixed in this fork

- **Fixed CDF, CDFJ, CDFJ+ and DPC+ cartridges showing Out of Order.** They now
  load and play (Draconian, Wizard of Wor Arcade).
- **Fixed YM2151 not found.** Games and demos that keep time with the sound chip
  itself were silent and complained the chip was missing (Shinobi demo, 1942).
- **Fixed YM2151 and POKEY going silent when Minnie is switched on.** What the
  cartridge asks for now always wins over the menu option (1942, EXO).
- **Fixed POKEY not being detected.** Software that goes looking for the chip
  finds it again, at every address the format allows (7800 Utility Cart, EXO).
- **Fixed Hard Reset leaving the previous game half-loaded.** A reset now
  restarts a game cleanly, cartridge still in the slot (Wizard of Wor, and any
  ARM game up to 512 KB).
- **Fixed the second fire button being ignored unless you used a SNAC adapter.**
  Two-button controllers are now recognised by the games that support them, on
  any controller, keyboard included (Qyx, Scramble Arcade).
- **Fixed the controller being ignored when the port is left on Auto.** Games
  that declare a controller the core did not recognise now fall back to a
  joystick instead of no input at all (A.R.T.I.).
- **Flicker blend**, on by default, for games that draw on alternating frames.

## Features

- Runs the complete Atari 7800 retail library.
- NTSC and PAL regions.
- High Score Cart saving.
- Light Guns, Trakballs, Mice, QuadTari and Paddles.
- XEGS keyboard support via POKEY.
- Support for XM and XBoard modules.
- Activision, Absolute, Bankset, Souper and Supergame mappers up to 1 MB.
- Expansion audio: POKEY, two POKEYs at once, YM2151, Covox and Minnie.
- BupChip music playback, with a volume setting in the audio menu
  (Rikki & Vikki).
- **Pause Core on OSD** stops the whole machine, soundtrack included. Open
  the menu and the game and its music freeze; close it and both carry on
  from the same point (Rikki & Vikki included).
- Choice of Cool, Warm or Hot system temperature colour output.

## Setup

Not much setup is required, but you may optionally put a system bios as
`boot0.rom` in your Atari7800 ROMs folder to use before loading a game. It may
increase compatibility in some rare cases if used. This core does rely on
properly configured Atari7800 headers as detailed
[here](http://7800.8bitdev.org/index.php/A78_Header_Specification). Using
Trebor 7800 ROM PROPack is recommended as this is a reliable source of correctly
headered ROMs.

## Controllers

Two-button controllers are found automatically by the games that support them —
there is nothing to switch on. Tested with a USB pad, a DB9 controller through a
USB adapter, a SNAC adapter and the plain keyboard: all four give you both
buttons, with Port 1 on either **Auto** or **Joystick**.

**QuadTari** is supported and starts switched off.

### QuadTari and two-button pads share the same two pins

On a real 2600 a game tells a peripheral apart by the resting level of the two
analog pins of the port, and the QuadTari and a two-button pad ask for opposite
levels on them. They are the same physical wires, so on real hardware you plug
in one or the other — and this core behaves the same way:

- **QuadTari off** (the default) — two-button pads are detected.
- **QuadTari on** — the QuadTari is detected, and the second button is not
  offered automatically on that port.

If you want a two-button pad on a port while the QuadTari is on, pick
**Gamepad** at the bottom of the Port 1 or Port 2 list in the Peripherals menu:
that forces the pad regardless. The same entry is what to use if a game assigns
some other peripheral to a port and you want a pad anyway.

## 2600 support

Most 2600 games are supported including most bankswitching schemes. **Unlike the
official core, cartridges with an ARM coprocessor — CDF, CDFJ, CDFJ+ and DPC+ —
are supported and play.** A few eccentric peripherals are still not supported,
namely the Compumate and the Gameline. The following bankswitching schemes are
supported: F8, F6, FE, E0, 3F, F4, P2, FA, CV, 2K, UA, E7, F0, 32, AR, 3E, SB,
WD (8k dump) and EF. Bankswitching auto-detects the correct type and does not
require special extensions.

## Paddles

The paddle peripheral is mostly used in 2600 games and has special handling
surrounding it because of its unusual 2-paddles-per-port configuration. Three
types of inputs are supported for paddles: analog sticks, mice, and mr. spinner
compatible joystick adapters. It is important to note that PADDLES HAVE A
DEDICATED FIRE BUTTON in this core, and it must be set in order to use the
paddles properly. Because there are four paddles and two controller ports, and a
myriad of input devices, paddles are assigned independently of joysticks. Every
time a game is cold reset, paddles are re-assigned. The core will assign paddles
in order, when a port has paddles enabled. The various devices are recognised
under these conditions:

- Mice when you click the left button.
- Analog sticks when you move either the Y axis or X axis to an extreme (make
  sure to assign analog x/y in the main mapping).
- Mr. Spinner devices when they are moved to an extreme position.

Please note that some games do not use paddle 1A for their input, some
exceptions are:

- Astroblast: uses 1B.
- Tac Scan: uses 2B.
- Demons to Diamonds: uses 1B.

To make dealing with this easier, there is an option to swap paddles A and B of
either port, so that 1A will become 1B and vice versa. Additionally, if the
input type is set to "auto" with 2600 games, pressing the fire button will
toggle the input into Joystick mode, and pressing the paddle button will toggle
the input into Paddle mode, for convenience.

## Joystick adapters

Over the years several Atari joystick to USB adapters have been created for 2600
and 7800 peripherals. Some of these do not split paddle operations into two
distinct devices. For this scenario, a special option has been added in the
peripheral configuration section of the menu that allows multiple paddles to be
on the same controller. When this mode is enabled, the first axis on a
controller seen will be mapped as the first paddle, and the second axis moved
will be mapped as the second. The first paddle button will be the assigned
"Paddle" button, and the second paddle button will be the Fire II button. Also
worth noting is both paddles MUST BE MAPPED AS AXIS AND BUTTONS ON THE MAIN MENU
before they will work in the core.

## Keyboard shortcuts

- F1 Select
- F2 Start
- F3 B/W toggle switch
- F4 Difficulty Left toggle switch A/B
- F5 Difficulty Right toggle switch A/B
- F6 Pause

## Additional notes

Some games use the
[difficulty switches](https://atariage.com/forums/topic/235913-atari-7800-difficulty-switches-guide/)
to control their behaviour, most notably Tower Toppler, which will continue to
skip levels if the switches are in the "low" position. For 2600 games it is
important to refer to the game manual for switch positions as some games will
not behave correctly if the switches are in the wrong position, and there is no
pair of positions that is correct for all 2600 games. The 7800 had issues with
colour consistency depending on the temperature of the system. Not all games may
look ideal with the warm palette, so you may have to experiment per game to find
the ideal colours.

## Known bugs

- Expansion ram of the XM module is not fully implemented.

## Credits

This is a fork of the official Atari 7800 MiSTer core and keeps its licence.
The POKEY implementation is by **mark watson**, used under its non-commercial
terms — see the header of each file in `rtl/Pokey`.

### Special thanks (from the original core)

- Mike Saarna for his enormous knowledge of the system and patient help.
- Osman Celimli for his DMA timing traces and experience.
- Robert Tuccitto for the extensive palette information.
- Remowilliams for testing a zillion games on real hardware.
- Alan Steremberg for getting access to valuable documentation.

### On the use of AI

The work in this fork was carried out with **Claude Code** (Anthropic) working
alongside the author: reading the reference sources, writing the RTL, building
the simulation benches and running the regressions. Every change was measured on
a testbench before it was accepted, and tested on real hardware afterwards. The
direction, the priorities and the final say were the author's; the AI did the
legwork and had to prove each claim with numbers.
