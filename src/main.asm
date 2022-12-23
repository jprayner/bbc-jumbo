IRQ1V = &204
IRQ2V = &206

OSRDCH = &FFE0
OSWRCH = &FFEE
OSWORD = &FFF1
OSBYTE = &FFF4
VID_MEM_START = &3000

CRTC_REG = &FE00
CRTC_VAL = &FE01

CRTC_REG_DISP_ROWS = &06
CRTC_REG_CURSOR_CTRL = &0A
CRTC_REG_SCREEN_START_H = &0C
CRTC_REG_SCREEN_START_L = &0D

VIA_INT_EN = &FE4E
VIA_INT_FLAG = &FE4D

RUN_MODE_STANDALONE = &01
RUN_MODE_ECONET_LEADER = &02
RUN_MODE_ECONET_FOLLOWER = &03

ORG &70
GUARD &9F
  .vid_mem_ptr          SKIP 2
  .table_ptr            SKIP 2
  .char_ptr             SKIP 2
  .scroll_ptr           SKIP 2
  .src_ptr              SKIP 2
  .dest_ptr             SKIP 2
  .message_ptr          SKIP 2
  .temp                 SKIP 1
  .flags                SKIP 1
  .scroll_count         SKIP 1
  .timer_count          SKIP 1
  .tick_flag            SKIP 1
  .old_irqv             SKIP 2
  .offscreen_buff_ptr   SKIP 2

ORG &2000
GUARD &26FF

;------------------------------------------------------------------------------
; Entrypoint to application.
;
;   run_mode:           Determines if we are standalone, leader or follower
;   num_screens_delay:  How long to wait before starting to scroll: first
;                       follower delayed by 1 screen, second by 2 etc. Set to
;                       0 for standalone or leader. 
;   message:            Message to scroll, terminated by &0d.
;------------------------------------------------------------------------------
.start
{
    LDA run_mode
    CMP #RUN_MODE_STANDALONE
    BEQ start_scrolling
    CMP #RUN_MODE_ECONET_LEADER
    BEQ start_leader
    CMP #RUN_MODE_ECONET_FOLLOWER
    BEQ start_follower
}

;------------------------------------------------------------------------------
; Leader sends a broadcast to all stations on the network to start scrolling
; before starting itself.
;------------------------------------------------------------------------------
.start_leader
{
    JSR broadcast_start
    JMP start_scrolling
}

;------------------------------------------------------------------------------
; Follower waits for leader's broadcast before start to scroll.
;------------------------------------------------------------------------------
.start_follower
{
    JSR wait_broadcast_start
    JMP start_scrolling
}

;------------------------------------------------------------------------------
; Main scrolling loop.
;
;   run_mode:           Determines if we are standalone, leader or follower
;   num_screens_delay:  How long to wait before starting to scroll: first
;                       follower delayed by 1 screen, second by 2 etc. Set to
;                       0 for standalone or leader. 
;   message:            Message to scroll, terminated by &0d.
;------------------------------------------------------------------------------
.start_scrolling
{
    SEI
        LDA #%01111111   ; disable all System VIA interrupts
        STA VIA_INT_EN
    CLI

    ; Mode 2 = 160x256 pixels / 20x32 text positions
    LDA #22 : JSR OSWRCH
    LDA #2  : JSR OSWRCH

    ; Configure CRTC to show 8 rows
    LDA #CRTC_REG_DISP_ROWS : STA CRTC_REG
    LDA #8                  : STA CRTC_VAL

    ; Configure CRTC to offset visible area to centre of screen
    LDA #7                  : STA CRTC_REG
    LDA #24                 : STA CRTC_VAL

    JSR setup_interrupt_handler

    LDA #0
    STA scroll_count

    JSR init_scroll
    JSR delay_scroll_start

    .restart
    LDA #message MOD 256 : STA message_ptr
    LDA #message DIV 256 : STA message_ptr + 1

    .message_loop
    LDY #0
    LDA (message_ptr), Y
    CMP #&0d
    BEQ done

    CLC
    INC message_ptr
    BNE inc_message_ptr_done
    INC message_ptr + 1
    .inc_message_ptr_done

    JSR scroll_single_char

    INY
    JMP message_loop

    .done
    JMP restart

    RTS
}

ALIGN &100
; Stores 2-pixel (1 byte) strip of 64 pixels height prior to copying to screen
.offscreen_buffer       SKIP 64
; ASCII value of current character to be enlarged and drawn on screen
.current_char           SKIP 1

INCLUDE "interrupt.asm"
INCLUDE "scroll.asm"
INCLUDE "render.asm"
INCLUDE "util.asm"
INCLUDE "econet.asm"
INCLUDE "tables.asm"

;------------------------------------------------------------------------------
; Arguments follow. Remember to update first line of Menu BASIC programme if
; these addresses change.
;------------------------------------------------------------------------------
ORG &2700
; Manner in which app is being launched: RUN_MODE_STANDALONE,
; RUN_MODE_ECONET_LEADER or RUN_MODE_ECONET_FOLLOWER
.run_mode
    EQUB RUN_MODE_STANDALONE
; How long to wait before starting to scroll: first follower delayed by 1
; screen, second by 2 etc. Set to 0 for standalone or leader. 
.num_screens_delay
    EQUB 0
; Message to scroll, terminated by &0d.
.message
    EQUS "Message goes here."
    EQUB &0d
; Leave enough room for a message so that it is included when POKEd to another
; machine
ORG &27FF
EQUB 0
.end

SAVE "Code", start, end
PUTBASIC "MENU"
PUTFILE "BOOT", "!BOOT", &FFFF
