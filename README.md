# Econet Jumbo Text Scroller for the BBC Micro

## Description

This is a demo for the BBC Micro which smoothly scrolls large, (kinda!) anti-aliased text across the screen at 50fps. If you've got an Econet then it can scroll the message across multiple screens.

The program is mostly implemented in 6502 assembly language with a menu system written in BBC BASIC.

## Demo (sound on!)

https://user-images.githubusercontent.com/909745/209448748-c88f4287-9389-46d1-bef7-05fedc2c258d.mp4

Credit: music by [Music Unlimited](https://pixabay.com/users/music_unlimited-27600023/?utm_source=link-attribution&amp;utm_medium=referral&amp;utm_campaign=music&amp;utm_content=124008) from
[Pixabay](https://pixabay.com//?utm_source=link-attribution&amp;utm_medium=referral&amp;utm_campaign=music&amp;utm_content=124008)

## Running

Grab `jumbo.ssd` from the [Releases page](https://github.com/jprayner/bbc-jumbo/releases) and load onto your Beeb using your storage solution of choice.

The SSD is bootable so shift+BREAK should do the trick to kick off the menu or alternatively:

```
CHAIN "MENU"
```

Choose the standalone option if you're running on a single machine, supply a message and away you go.

If you're lucky enough to have a functioning Econet then selecting this option prompts you to enter the station numbers. The machine on which the menu is running (the "leader") is assumed to be the rightmost machine and you should enter the Econet station numbers of the other "follower" machines from right-to-left.

## Building

Ensure that you have [BeebAsm](https://github.com/stardot/beebasm) in your PATH and execute `make.sh` to generate a `jumbo.ssd` disk image.

## How does it work?

### Embiggening

The drawing of the text is handled by `render.asm`.

First, `get_char_ptr_for_ascii` is used to look up the character to be drawn in the OS. This is represented as 8 bytes, one for each row; each bit within a row byte represents a pixel within that row. A filled-in pixel is a `1` and a "hole" is a `0`. Then 8 pixels are plotted on-screen for each filled-in pixel in the source character, turning the characters into 64x64 pixels:

<img width="298" alt="Screenshot 2022-12-23 at 19 08 27" src="https://user-images.githubusercontent.com/909745/209396094-eff06f03-b70b-4516-afd0-6414f114aa2d.png">

Hmmm... a bit lumpy. To improve matters, some extra processing is done (in `print_custom_infill_char`) when a hole pixel is found in the source character: the pixels immediately around it at each of the four compass points are evaluated. Where two lines appear to be intersecting, a little infill lump is drawn. Consider where the two lines of a letter 'L' meet: just inside there, the pixel to the left and the one below will be `1` and so we will draw an infill to the bottom-left. `print_anti_alias_corners` takes the infill flags built up by `print_custom_infill_char` and uses them to look up a custom character in `tables.asm` (note the `1`s at the bottom-left):

```
.anti_alias_char8    ; BL/BR/TR/TL == 1000
    EQUB %00000000
    EQUB %00000000
    EQUB %00000000
    EQUB %00000000
    EQUB %00000000
    EQUB %00000000
    EQUB %11000000
    EQUB %11000000
```

Our 64x64 characters now look like this:

<img width="297" alt="Screenshot 2022-12-23 at 19 06 51" src="https://user-images.githubusercontent.com/909745/209401056-aeeac682-ecd7-4211-95ac-abe92d2bc31f.png">

### Scrolling

This app runs in screen mode 2 which is 160x256 pixels (20x32 characters). Each byte in screen memory describes two pixels (with the four bits per pixel giving a palette of 8 colours). It starts at `&3000` and ends at `&7fff`. By adding one to the start address of screen memory in the CRTC, the whole screen appears to move left by 2 pixels instantly without needing to do any memory copying. This is great because the Beeb doesn't have any blitting capability.

So all we need to do is fill in the 2 pixels just revealed by the scroll. The challenge is to do this quickly enough to fit within the vertical blanking interval in order to have a nice, smooth animation and to avoid "tearing" artefacts. `render.asm` is therefore optimised to only draw a vertical slice of the character being scrolled in and `scroll.asm` copies this in from the offscreen buffer to the screen. This has the additional advantage of keeping the offscreen buffer small (64 bytes).

Two separate pointers `scroll_ptr` and `dest_ptr` are maintained to keep track of the current scroll position (start of video memory) and where we're writing to (just to the right of the screen), respectively. When these advance past the end of video memory, they wrap back to the start. Thus scrolling can continue indefinitely, although the BASIC launcher currently imposes a limit of 254 chars to the size of the message.

### Econet

The leader sends a copy of the program — including the message to be scrolled — to each follower in turn using an Econet `POKE` operation. A `JSR` operation then causes the follower to jump to the entrypoint of the app where it sits waiting for a broadcast. Once the leader has prepared all followers (upto 253 of them!), a single Econet `TRANSMIT` operation to the broadcast address `&00` kicks off the action in perfect synchronisation!

In order to give the effect of text moving from one screen to another, the leader starts scrolling immediately but the first follower, placed immediately to the left of the leader, delays the start of its scroll by the time it takes for the text to cross the leader's screen. The second follower is delayed by two screen scroll periods, the third by three and so on.

The process is illustrated in the following sequence diagram:

![jumbo-econet-start](https://user-images.githubusercontent.com/909745/209437851-adfbbd98-eb87-4de3-82f1-0f8324a16d81.svg)

### Credits

* Kieran Connell for his excellent video on programming the CRTC, including how to do scrolling: https://www.youtube.com/watch?v=dbGRFUNARjw 
* Alex Nichol from King's School Worcester who wrote something very similar in the early 90s — this app is a tribute!
