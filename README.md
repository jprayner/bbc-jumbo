# Econet Jumbo Text Scroller for the BBC Micro

## Description

This is a silly little app for the BBC Micro which smoothly scrolls large, (kinda!) anti-aliased text across the screen.

If you've got an Econet then it can scroll the message across multiple screens.

The app is mostly implemented in 6502 assembly language with a menu system written in BBC BASIC.

## Demo

[![Econet Jumbo Text Scroller demo]
(https://img.youtube.com/vi/e47kdo0Q8_Y/hqdefault.jpg)]
(https://youtu.be/e47kdo0Q8_Y)


Credit: music by [Music Unlimited](https://pixabay.com/users/music_unlimited-27600023/?utm_source=link-attribution&amp;utm_medium=referral&amp;utm_campaign=music&amp;utm_content=124008) from
[Pixabay](https://pixabay.com//?utm_source=link-attribution&amp;utm_medium=referral&amp;utm_campaign=music&amp;utm_content=124008)

## Building

Ensure that you have [BeebAsm](https://github.com/stardot/beebasm) in your PATH and execute `run.sh` to generate `src/jumbo.ssd` disk image which you can load onto your Beeb using your storage solution of choice.


## Running

The SSD is bootable so shift+BREAK should do the trick to kick off the menu or alternatively:

```
CHAIN "MENU"
```

Choose the standalone option if you're running on a single machine, supply a message and away you go.

If you're lucky enough to have a functioning Econet then selecting this option prompts you to enter the station numbers. The server is assumed to be the rightmost machine and you should enter the Econet station numbers of the other machines from left-to-right.
