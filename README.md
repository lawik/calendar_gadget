# Calendar Gadget

Can take a calendar link (tested with Google Calendar) and show you the next item on the agenda on an Inky Phat eInk display.

To get it running:

## Get fonts

I've used the Artwiz fonts via this repo (https://github.com/whitelynx/artwiz-fonts-wl/releases) and unpacked the .bdf files into `firmware/rootfs_overlay/fonts`.

## Erlang and Elixir

If you have asdf installed, you should be able to go into the firmware dir and go `asdf install`. Or change the asdf versions to something you like, I bumped to Erlang 24.1 to get some faster reboots.

## Set up environment variables

In your terminal or however you link managing env vars, assuming a Raspberry Pi 0, and some made-up wifi credentials:

```
export MIX_TARGET=rpi0
export MIX_ENV=prod
export SSID="My Fancy Wifi"
export PSK="my-pass-132"
```

## Build firmware

```
mix deps.get
mix firmware
# Insert SD card
mix firmware.burn
# Put it in your device
```

## Confirm it runs

```
ping nerves.local
```

It should respond when it is up.

Looking for errors:

```
ssh nerves.local
RingLogger.next
```

You can also check if http://nerves.local is up in your browser. Typically won't work from Chrome on Android which I don't believe does mDNS.

## Set up a calendar (currently not in UI)

```
ssh nerves.local
# Create new calendar
c = CalendarApp.Calendar.add("demo", "https://fancy-calendar-url")
# Pull calendar data, should update all views (web and eInk)
CalendarApp.Calendar.update_calendar(c)
```


