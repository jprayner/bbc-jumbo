;------------------------------------------------------------------------------
; Sets up scroll pointer to point to start of video memory and destination
; pointer to just to right of visible screen.
;------------------------------------------------------------------------------
.init_scroll
{
    ; note CRTC start address is regular addr. / 8 (hence MOD/DIV 2048)
    lda #VID_MEM_START MOD 2048 : sta scroll_ptr
    lda #VID_MEM_START DIV 2048 : sta scroll_ptr + 1

    lda #CRTC_REG_SCREEN_START_L  : sta CRTC_REG
    lda scroll_ptr                : sta CRTC_VAL

    lda #CRTC_REG_CURSOR_CTRL     : sta CRTC_REG
    lda #0                        : sta CRTC_VAL

    ldx #20 ; start drawing at just after right-most pos of screen
    ldy #0
    jsr vid_mem_for_xy

    lda vid_mem_ptr     : sta dest_ptr
    lda vid_mem_ptr + 1 : sta dest_ptr + 1

    rts
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
    ldx num_screens_delay
    .delay_n_pages_loop
    beq delay_n_pages_done
    ; # 160 pixels / 2 pixels per scroll frame = 80 frames per page
    ; but add 10 more frames to allow for gap between physical screens
    ldy #90
    .delay_1_page_loop
    beq delay_1_page_done
    jsr wait_vsync
    dey
    jmp delay_1_page_loop
    .delay_1_page_done
    dex
    jmp delay_n_pages_loop
    .delay_n_pages_done

    rts
}

;------------------------------------------------------------------------------
; Scrolls a single, 64-pixel width character onto the screen.
;   A: ASCII character to show
;------------------------------------------------------------------------------
.scroll_single_char
{
    sta current_char

    pha
    txa
    pha
    tya
    pha

    ; init strip counter (0-31)
    ldx #0

    .shift_loop

    lda current_char
    jsr print_2px_char_slice

    ; wait for vsync
    lda #0
    sta tick_flag
    .wait_loop
    lda tick_flag
    beq wait_loop

    .scroll_left_2px
    clc
    inc scroll_ptr
    bne scroll_left_2px_done
    inc scroll_ptr + 1

    ; check for scroll wrap
    lda scroll_ptr + 1
    cmp #&10
    bmi skip_scroll_address_wrap
    ; wrap back to start of video memory (note CRTC start address is regular addr. / 8)
    lda #VID_MEM_START DIV 2048
    sta scroll_ptr + 1
    .skip_scroll_address_wrap

    .scroll_left_2px_done
    lda #CRTC_REG_SCREEN_START_L  : sta CRTC_REG
    lda scroll_ptr                : sta CRTC_VAL
    lda #CRTC_REG_SCREEN_START_H  : sta CRTC_REG
    lda scroll_ptr + 1            : sta CRTC_VAL

    jsr copy_2px_strip

    ; a single char is 64 pixels wide so we need to copy 32x 2-pixel strips
    inx
    cpx #32
    beq done

    jmp shift_loop

    .done

    ; keep track of character MOD 8 (0-7)
    inc scroll_count
    lda scroll_count
    cmp #8
    bcc skip_reset_scroll_count
    lda #0
    sta scroll_count

    .skip_reset_scroll_count

    pla 
    tay
    pla 
    tax
    pla 
    rts
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
    txa
    pha

    ; remember strip start address
    lda dest_ptr
    pha
    lda dest_ptr + 1
    pha

    ; start copying 8x rows of 2 pixels
    lda #0
    sta temp
    lda #offscreen_buffer MOD 256
    sta src_ptr
    lda #offscreen_buffer DIV 256
    sta src_ptr + 1

    .copy_2px_strip_loop
    ldy #7
    .copy_next_pixel_row
    lda (src_ptr), Y
    sta (dest_ptr), Y
    dey
    bpl copy_next_pixel_row

    ; next row of offscreen buffer starts 8 bytes from previous row
    lda #8
    clc
    adc src_ptr
    sta src_ptr

    ; next row of screen starts 640 bytes from previous row
    clc
    lda #640 MOD 256
    adc dest_ptr
    sta dest_ptr
    lda #640 DIV 256
    adc dest_ptr + 1
    sta dest_ptr + 1

    ; if we've reached the end of screen memory, wrap back to start
    jsr handle_address_wrap

    ; done 8 on-screen rows (64 pixels) yet?
    inc temp
    lda temp
    cmp #8
    beq copy_2px_stripDone

    jmp copy_2px_strip_loop

    .copy_2px_stripDone

    ; restore screen memory pointer
    pla 
    sta dest_ptr + 1
    pla 
    sta dest_ptr

    ; advance to next 2-pixel strip in screen memory pointer
    clc
    adc #8
    sta dest_ptr
    bcc done
    inc dest_ptr + 1
    jsr handle_address_wrap

    .done
    pla 
    tax
    rts
}

;------------------------------------------------------------------------------
; If screen memory point goes past end of screen (&7fff), wrap back to start 
; (&3000) by subtracting &5000.
;------------------------------------------------------------------------------

.handle_address_wrap
{
    lda dest_ptr + 1
    cmp #&80
    bmi done

    lda dest_ptr + 1
    sec
    sbc #&50
    sta dest_ptr + 1

    .done
    rts
}
