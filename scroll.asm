
.init_scroll
{
    ; note CRTC start address is regular addr. / 8 (hence MOD/DIV 2048)
    LDA #VID_MEM_START MOD 2048 : STA scroll_ptr
    LDA #VID_MEM_START DIV 2048 : STA scroll_ptr + 1

    LDA #CRTC_REG_SCREEN_START_L  : STA CRTC_REG
    LDA scroll_ptr                : STA CRTC_VAL

    LDA #CRTC_REG_CURSOR_CTRL     : STA CRTC_REG
    LDA #0                        : STA CRTC_VAL

    LDX #20
    LDY #0
    JSR vid_mem_for_xy

    LDA vid_mem_ptr     : STA dest_ptr
    LDA vid_mem_ptr + 1 : STA dest_ptr + 1

    RTS
}

; a: char to scroll
; x: char index
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
    ; BEQ wait_loop

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

    ; Source start address
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

    LDA #8
    CLC
    ADC src_ptr
    STA src_ptr

    CLC
    LDA #640 MOD 256
    ADC dest_ptr
    STA dest_ptr
    LDA #640 DIV 256
    ADC dest_ptr + 1
    STA dest_ptr + 1

    JSR handle_address_wrap

    INC temp
    LDA temp
    CMP #8
    BEQ copy_2px_stripDone

    JMP copy_2px_strip_loop

    .copy_2px_stripDone

    ; restore char start address
    PLA
    STA dest_ptr + 1
    PLA
    STA dest_ptr

    ; Advance to next 2-pixel strip
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