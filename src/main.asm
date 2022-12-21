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

.start_leader
{
    JSR broadcast_start
    JMP start_scrolling
}

.start_follower
{
    JSR wait_broadcast_start
    JMP start_scrolling
}

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

    ; Configure CRTC to show 8 rows
    LDA #7 : STA CRTC_REG
    LDA #24                  : STA CRTC_VAL

    JSR setup_interrupt_handler

    .restart
    LDA #message MOD 256 : STA message_ptr
    LDA #message DIV 256 : STA message_ptr + 1

    LDA #0
    STA scroll_count

    JSR init_scroll

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
    JSR restore_interrupt_handler

    .loop_forever
    JMP loop_forever

    RTS
}

ALIGN &100
.offscreen_buffer   SKIP 64
.current_char        SKIP 1

INCLUDE "interrupt.asm"
INCLUDE "scroll.asm"
INCLUDE "render.asm"
INCLUDE "util.asm"
INCLUDE "econet.asm"
INCLUDE "tables.asm"

ORG &2700
.run_mode           SKIP 1
.message
    EQUS "Message goes here."
    EQUB &0d

; leave enough room for a message
ORG &27FF
EQUB 0
.end

SAVE "Code", start, end
PUTBASIC "MENU"
PUTFILE "BOOT", "!BOOT", &FFFF
