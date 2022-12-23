;------------------------------------------------------------------------------
; Sets up scroll pointer to point to start of video memory and destination
; pointer to just to right of visible screen.
;------------------------------------------------------------------------------
.init_scroll
{
    ; note CRTC start address is regular addr. / 8 (hence MOD/DIV 2048)
    LDA #VID_MEM_START MOD 2048 : STA scroll_ptr
    LDA #VID_MEM_START DIV 2048 : STA scroll_ptr + 1

    LDA #CRTC_REG_SCREEN_START_L  : STA CRTC_REG
    LDA scroll_ptr                : STA CRTC_VAL

    LDA #CRTC_REG_CURSOR_CTRL     : STA CRTC_REG
    LDA #0                        : STA CRTC_VAL

    LDX #20 ; start drawing at just after right-most pos of screen
    LDY #0
    JSR vid_mem_for_xy

    LDA vid_mem_ptr     : STA dest_ptr
    LDA vid_mem_ptr + 1 : STA dest_ptr + 1

    RTS
}

;------------------------------------------------------------------------------
; Waits an appropriate number of frames before beginning to scroll, so that
; text appears to flow from one screen to the next.
;
;   num_screens_delay:  Number of screens-worth of scrolling to wait before
;                       returning.
;------------------------------------------------------------------------------
.delay_scroll_start
{
    LDX num_screens_delay
    .delay_n_pages_loop
    BEQ delay_n_pages_done
    ; # 160 pixels / 2 pixels per scroll frame = 80 frames per page
    ; but add 10 more frames to allow for gap between physical screens
    LDY #90
    .delay_1_page_loop
    BEQ delay_1_page_done
    JSR wait_vsync
    DEY
    JMP delay_1_page_loop
    .delay_1_page_done
    DEX
    JMP delay_n_pages_loop
    .delay_n_pages_done

    RTS
}

;------------------------------------------------------------------------------
; Scrolls a single, 64-pixel width character onto the screen.
;   A: ASCII character to show
;------------------------------------------------------------------------------
.scroll_single_char
{
    STA current_char

    PHA
    TXA
    PHA
    TYA
    PHA

    ; init strip counter (0-31)
    LDX #0

    .shift_loop

    LDA current_char
    JSR print_2px_char_slice

    ; wait for vsync
    LDA #0
    STA tick_flag
    .wait_loop
    LDA tick_flag
    BEQ wait_loop

    .scroll_left_2px
    CLC
    INC scroll_ptr
    BNE scroll_left_2px_done
    INC scroll_ptr + 1

    ; check for scroll wrap
    LDA scroll_ptr + 1
    CMP #&10
    BMI skip_scroll_address_wrap
    ; wrap back to start of video memory (note CRTC start address is regular addr. / 8)
    LDA #VID_MEM_START DIV 2048
    STA scroll_ptr + 1
    .skip_scroll_address_wrap

    .scroll_left_2px_done
    LDA #CRTC_REG_SCREEN_START_L  : STA CRTC_REG
    LDA scroll_ptr                : STA CRTC_VAL
    LDA #CRTC_REG_SCREEN_START_H  : STA CRTC_REG
    LDA scroll_ptr + 1            : STA CRTC_VAL

    JSR copy_2px_strip

    ; a single char is 64 pixels wide so we need to copy 32x 2-pixel strips
    INX
    CPX #32
    BEQ done

    JMP shift_loop

    .done

    ; keep track of character MOD 8 (0-7)
    INC scroll_count
    LDA scroll_count
    CMP #8
    BCC skip_reset_scroll_count
    LDA #0
    STA scroll_count

    .skip_reset_scroll_count

    PLA
    TAY
    PLA
    TAX
    PLA
    RTS
}

;------------------------------------------------------------------------------
; Copies a 2x64-pixel slice of the current character from the offscreen buffer
; to the screen.
;
;   dest_ptr:   Current on-screen destination address (just to the right of
;               visible)
;   A: ASCII character to show
;------------------------------------------------------------------------------

; x: 2-pixel vertical strip index within character (in range 0-31, given we have 64-pixel wide characters)
.copy_2px_strip
{
    TXA
    PHA

    ; remember strip start address
    LDA dest_ptr
    PHA
    LDA dest_ptr + 1
    PHA

    ; start copying 8x rows of 2 pixels
    LDA #0
    STA temp
    LDA #offscreen_buffer MOD 256
    STA src_ptr
    LDA #offscreen_buffer DIV 256
    STA src_ptr + 1

    .copy_2px_strip_loop
    LDY #7
    .copy_next_pixel_row
    LDA (src_ptr), Y
    STA (dest_ptr), Y
    DEY
    BPL copy_next_pixel_row

    ; next row of offscreen buffer starts 8 bytes from previous row
    LDA #8
    CLC
    ADC src_ptr
    STA src_ptr

    ; next row of screen starts 640 bytes from previous row
    CLC
    LDA #640 MOD 256
    ADC dest_ptr
    STA dest_ptr
    LDA #640 DIV 256
    ADC dest_ptr + 1
    STA dest_ptr + 1

    ; if we've reached the end of screen memory, wrap back to start
    JSR handle_address_wrap

    ; done 8 on-screen rows (64 pixels) yet?
    INC temp
    LDA temp
    CMP #8
    BEQ copy_2px_stripDone

    JMP copy_2px_strip_loop

    .copy_2px_stripDone

    ; restore screen memory pointer
    PLA
    STA dest_ptr + 1
    PLA
    STA dest_ptr

    ; advance to next 2-pixel strip in screen memory pointer
    CLC
    ADC #8
    STA dest_ptr
    BCC done
    INC dest_ptr + 1
    JSR handle_address_wrap

    .done
    PLA
    TAX
    RTS
}

;------------------------------------------------------------------------------
; If screen memory point goes past end of screen (&7fff), wrap back to start 
; (&3000) by subtracting &5000.
;------------------------------------------------------------------------------

.handle_address_wrap
{
    LDA dest_ptr + 1
    CMP #&80
    BMI done

    LDA dest_ptr + 1
    SEC
    SBC #&50
    STA dest_ptr + 1

    .done
    RTS
}
