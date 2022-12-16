IRQ1V = &204
IRQ2V = &206

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
GUARD &9F
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
  .ScrollCount  SKIP 1
  .Copy2PixelStripCharColumn                SKIP 1
  .timer_count   SKIP 1
  .tick_flag     SKIP 1
  .old_irqv     SKIP 2
  .offscreen_buffer_ptr SKIP 2

ORG &2000         ; code origin (like P%=&2000)
GUARD &3000

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

    JSR setupInterruptHandler
    ;JMP foreever

    .restart
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
;JSR waitForKey
    INY
    JMP messageLoop

    .foreever
    JMP foreever

RTS

.setupInterruptHandler
    SEI

    ; enable vsync interrupt
    LDA #%10000010
    STA &FE4E ; interrupt enable register

    ; Store old IRQ1V
    LDA IRQ1V
    STA old_irqv
    LDA IRQ1V+1
    STA old_irqv + 1

    ; Setup IRQ handler
    LDA #irq_handler MOD 256
    STA IRQ1V
    LDA #irq_handler DIV 256
    STA IRQ1V + 1

    CLI
    RTS

.irq_handler
    LDA &FC
    PHA
    TXA
    PHA
    TYA
    PHA

    LDA &FE4D ; System VIA interrupt flag register
    AND #%00000010 ; vsync interrupt flag
    BEQ irq_handler_done

    STA &FE4D ; clear flag

    INC timer_count
    LDA #1
    CMP timer_count
    BPL irq_handler_done

    ; set tick flag to 1 to indicate timer tick
    LDA #1
    STA tick_flag

    ; reset timer
    LDA #0
    STA timer_count

    .irq_handler_done

    ; todo
    PLA
    TAY
    PLA
    TAX
    PLA
    STA &FC
    RTI

.currentChar
    EQUB 0

; a: char to scroll
; x: char index
.scrollSingleChar
    STA currentChar

    PHA
    TXA
    PHA
    TYA
    PHA

    ; init strip counter (0-31)
    LDX #0

    .shiftLoop

    ; draw section of character starting from row 24
    LDA currentChar
    LDY #24
    JSR PrintBigChar

    LDA #0
    STA tick_flag
    .waitLoop
    LDA tick_flag
    ;BEQ waitLoop

    .scrollLeft2Pixels
    CLC
    INC ScrollPtr
    BNE scrollLeft2PixelsDone
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

    JSR Copy2PixelStrip

    INX
    CPX #32
    BEQ scrollSingleCharDone

    JMP shiftLoop

.initScroll
    LDA #vid_mem MOD 2048
    STA ScrollPtr
    LDA #vid_mem DIV 2048
    STA ScrollPtr + 1
    LDA #0
    STA MessageIdx
    LDA #0
    STA ScrollCount

    LDA #crtc_reg_screen_start_l
    STA crtc_reg
    LDA ScrollPtr
    STA crtc_val

    LDA #crtc_reg_cursor_ctrl
    STA crtc_reg
    LDA #0
    STA crtc_val

    LDX #20
    LDY #0
    JSR VidMemForXY
    LDA VidMemPtr
    STA DestPtr
    LDA VidMemPtr + 1
    STA DestPtr + 1

    RTS

.scrollSingleCharDone
    ; keep track of character MOD 8 (0-7)
    INC ScrollCount
    LDA ScrollCount
    CMP #8
    BCC dontResetScrollCount
    .resetScrollCount
    LDA #0
    STA ScrollCount

    ;JSR initScroll

    .dontResetScrollCount

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

; x: 2-pixel vertical strip index within character (in range 0-31, given we have 64-pixel wide characters)
.Copy2PixelStrip
    TXA
    PHA

    ; remember strip start address
    LDA DestPtr
    PHA
    LDA DestPtr + 1
    PHA

    ; start copying 8x rows of 2 pixels
    LDA #0
    STA Temp

    ; Source start address
    LDA #offscreen_buffer MOD 256
    STA SrcPtr
    LDA #offscreen_buffer DIV 256
    STA SrcPtr + 1

    .Copy2PixelStripLoop

    .Copy8PixelRows
    LDY #7
    .CopyNextPixelRow
    LDA (SrcPtr), Y
    STA (DestPtr), Y
    DEY
    BPL CopyNextPixelRow

    LDA #8
    CLC
    ADC SrcPtr
    STA SrcPtr

    CLC
    LDA #640 MOD 256
    ADC DestPtr
    STA DestPtr
    LDA #640 DIV 256
    ADC DestPtr + 1
    STA DestPtr + 1

    INC Temp
    LDA Temp
    CMP #8
    BEQ Copy2PixelStripDone

    JMP Copy2PixelStripLoop

    .Copy2PixelStripDone

    ; restore char start address
    PLA
    STA DestPtr + 1
    PLA
    STA DestPtr

    ; Advance to next 2-pixel strip
    CLC
    ADC #8
    STA DestPtr
    BCC SkipMSBAdd2
    INC DestPtr + 1
    .SkipMSBAdd2

    PLA
    TAX
    RTS

.delay
    PHA
    LDA #$e0
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

ALIGN &100
.offscreen_buffer SKIP 64


.message
    EQUS "Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed d"
    ; do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat. Duis aute irure dolor in reprehenderit in voluptate velit esse cillum dolore eu fugiat nulla pariatur. Excepteur sint occaecat cupidatat non proident, sunt in culpa qui officia deserunt mollit anim id est laborum."
    EQUB 0

INCLUDE "jumbo.asm"
INCLUDE "tables.asm"

.end

SAVE "Code", start, end
PUTBASIC "DEBUG"
