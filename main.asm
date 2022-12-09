osrdch = &FFE0
oswrch = &FFEE
osasci = &FFE3
oscli = &FFF7
osword = &FFF1
osbyte = &FFF4
vid_mem = &3000
vid_end = &8000
reset_scroll_vid_mem = &3280
chars = &C058

crtc_reg = &FE00
crtc_val = &FE01

crtc_reg_disp_rows = &06
crtc_reg_cursor_ctrl = &0A
crtc_reg_screen_start_h = &0C
crtc_reg_screen_start_l = &0D

osbyte_inkey = &81

ORG &70
  .VidMemPtr    SKIP 2
  .TablePtr     SKIP 2
  .CharPtr      SKIP 2
  .ScrollPtr    SKIP 2
  .SrcPtr       SKIP 2
  .DestPtr      SKIP 2
  .MessagePtr   SKIP 2
  .MessageIdx   SKIP 1
  .Temp         SKIP 1
  .Flags        SKIP 1
  .ScrollVal    SKIP 1
  .ScrollCount  SKIP 1
  .Copy2PixelStripCharColumn                SKIP 1
  .Copy2PixelStrip2PixelSliceOffset         SKIP 1

ORG &2000         ; code origin (like P%=&2000)


.start

;--------------------------------------------------
.Main
;--------------------------------------------------

    ;JSR osrdch

    SEI
        LDA #%01111111   ; disable all System VIA interrupts
        STA &FE4E

    ;    LDA #0 
    ;    STA &FE4B
    CLI

    \\ Mode 2 = 160x256 pixels / 20x32 text positions
    LDA #22:JSR oswrch
    LDA #2:JSR oswrch

    LDA #message MOD 256
    STA MessagePtr
    LDA #message DIV 256
    STA MessagePtr + 1

    JSR initScroll

    LDY #0
    .messageLoop
    LDA (MessagePtr), Y
    BEQ foreever
    JSR scrollSingleChar
    INY
    JMP messageLoop

    .foreever
    JMP foreever

RTS

; a: char to scroll
; x: char index
.scrollSingleChar
    STA Temp

    PHA
    TXA
    PHA
    TYA
    PHA

    ; draw character starting from row 24
    LDA Temp
    LDY #24
    JSR PrintBigChar

    ; init strip counter (0-31)
    LDX #0

    .shiftLoop
    JSR Copy2PixelStrip
    ;JSR delay
    JSR waitForKey

    INX
    CPX #32
    BEQ scrollSingleCharDone

    .scrollLeft2Pixels
    DEC ScrollVal
    BEQ resetScroll
    CLC
    INC ScrollPtr
    BCC scrollLeft2PixelsDone
    INC ScrollPtr + 1
    .scrollLeft2PixelsDone

    LDA #crtc_reg_screen_start_l
    STA crtc_reg
    LDA ScrollPtr
    STA crtc_val
    
    LDA #crtc_reg_screen_start_h
    STA crtc_reg
    LDA ScrollPtr + 1
    STA crtc_val

    JMP shiftLoop

.resetScroll
    INC ScrollCount
    LDY ScrollCount

    ;LDA #vid_mem MOD 2048
    ;STA ScrollPtr
    ;LDA #vid_mem DIV 2048
    ;STA ScrollPtr + 1

    ; double this value each time to scroll up one row and keep things lined up

    ; R12 and R13 are the screen start address / 8
    ;CLC
    ;LDA ScrollPtr
    ;ADC #80
    ;STA ScrollPtr
    ;BCC skipVerticalScrollMsbAdd
    ;INC ScrollPtr + 1
    ;.skipVerticalScrollMsbAdd

    LDA #80
    STA ScrollVal

    JMP shiftLoop
;.resetScroll
;    LDA MessageIdx
;    CMP #5
;    BEQ resetScroll2

.resetScroll1
    LDA #&4F ; TODO: tidy up!
    STA ScrollPtr
    LDA #vid_mem DIV 2048
    STA ScrollPtr + 1
    LDA #80
    STA ScrollVal

    JMP shiftLoop

.resetScroll2
    LDA #&9e ; TODO: tidy up!
    STA ScrollPtr
    LDA #vid_mem DIV 2048
    STA ScrollPtr + 1
    LDA #80
    STA ScrollVal

    JMP shiftLoop

.initScroll
    LDA #vid_mem MOD 2048
    STA ScrollPtr
    LDA #vid_mem DIV 2048
    STA ScrollPtr + 1
    LDA #80
    STA ScrollVal
    LDA #0
    STA MessageIdx
    STA ScrollCount

    LDA #crtc_reg_screen_start_l
    STA crtc_reg
    LDA ScrollPtr
    STA crtc_val

    LDA #crtc_reg_cursor_ctrl
    STA crtc_reg
    LDA #0
    STA crtc_val

    ;LDA #crtc_reg_disp_rows
    ;STA crtc_reg
    ;LDA #08
    ;STA crtc_val
    RTS

.scrollSingleCharDone
    ; keep track of character MOD 6 (0-5) to know when to reset scroll
    ; and where in video memory to copy characters. After 6 chars we are neatly
    ; back to start of scroll window and are in-between characters.
    INC MessageIdx
    ;LDA MessageIdx
    ;CMP #6
    ;BEQ scrollSingleCharDoneSkipReset
    ;LDA #0
    ;STA MessageIdx
    ;.scrollSingleCharDoneSkipReset

    PLA
    TAY
    PLA
    TAX
    PLA
    RTS

.Copy2PixelStrip
    TXA
    PHA

    ; multiply lower 2 bits by 8 to get the offset in bytes: offset will be 0, 8, 16 or 24
    .Calc2PixelSliceOffset
    AND #%00000011
    ASL A
    ASL A
    ASL A
    STA Copy2PixelStrip2PixelSliceOffset

    ; divide by 4 to get the column offset in chars (there are 4x 2-pixel shifts per char)
    .CalcCharColumnOffset
    PLA
    PHA
    LSR A
    LSR A
    STA Copy2PixelStripCharColumn

    ; start copying 8x rows of 2 pixels
    LDA #0
    STA Temp

    .Copy2PixelStripLoop

    ; We're copying from row in Temp (+24 to find offscreen position where character has been drawn) and column derived from X on entry
    LDA Temp
    CLC
    ADC #24
    TAY
    LDX Copy2PixelStripCharColumn

    JSR VidMemForXY
    LDA VidMemPtr
    STA SrcPtr
    LDA VidMemPtr + 1
    STA SrcPtr + 1

    ; Add on the offset to the character address to get the start of the 2-pixel slice
    CLC
    LDA SrcPtr
    ADC Copy2PixelStrip2PixelSliceOffset
    STA SrcPtr
    BCC SkipMSBAdd
    INC SrcPtr + 1
    .SkipMSBAdd

    ; Row is in Temp; column is 19 + char pos * 8 (19 being rightmost column before scroll)
    LDA Temp
    TAY
    LDA MessageIdx
    ASL A
    ASL A
    ASL A
    CLC
    ADC Copy2PixelStripCharColumn
    ADC #19
    TAX

    JSR VidMemForXY
    LDA VidMemPtr
    STA DestPtr
    LDA VidMemPtr + 1
    STA DestPtr + 1

    CLC
    LDA DestPtr
    ADC Copy2PixelStrip2PixelSliceOffset
    STA DestPtr
    BCC SkipMSBAdd2
    INC DestPtr + 1
    .SkipMSBAdd2

    .Copy8PixelRows
    LDY #7
    .CopyNextPixelRow
    LDA (SrcPtr), Y
    STA (DestPtr), Y
    DEY
    BPL CopyNextPixelRow

    INC Temp
    LDA Temp
    CMP #8
    BEQ Copy2PixelStripDone

    JMP Copy2PixelStripLoop

    .Copy2PixelStripDone
    PLA
    TAX
    RTS

.delay
    PHA
    LDA #$b0
    STA Temp  ; high byte
    .delayloop
    ADC #01
    BNE delayloop
    CLC
    INC Temp
    BNE delayloop
    CLC
    PLA
    RTS

.waitForKey
    SEI
        LDA #%11111111   ; disable all System VIA interrupts
        STA &FE4E
    CLI
    JSR osrdch
    SEI
        LDA #%01111111   ; disable all System VIA interrupts
        STA &FE4E
    CLI
    RTS

.message
    EQUS "Klmnopq"
    EQUB 0

INCLUDE "jumbo.asm"
INCLUDE "tables.asm"

.end

SAVE "Code", start, end
PUTBASIC "DEBUG"
