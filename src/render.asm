col_black = 0
col_red = 1
col_green = 2
col_yellow = 3
col_blue = 4
col_magenta = 5
col_cyan = 6
col_white = 7

.block_x_offset
    EQUW 0

;------------------------------------------------------------------------------
.print_2px_char_slice
;   Print a vertical, 2-pixel slice of the given ASCII at 8x size i.e. 2x64
;   pixels into the offscreen buffer, ready for it to be copied on-screen by
;   scroll.asm.
;
;   A: ASCII character to print
;   X: Which slice of enlarged character to draw (range 0-31)
;------------------------------------------------------------------------------
    stx screen_char_x
    jsr get_char_ptr_for_ascii

    lda #offscreen_buffer MOD 256
    sta offscreen_buff_ptr
    lda #offscreen_buffer DIV 256
    sta offscreen_buff_ptr + 1

    ; Save x to stack
    lda screen_char_x
    pha

    ; We get called 4 times for the same pixel within the source character.
    ; char_pixel_x tells us start pixel X pos within the enlarged character
    ; for each slice (0, 2, 4, 6)
    and #%00000011
    sta char_pixel_x
    clc
    rol char_pixel_x

    ; Divide x by 4 to get on-screen character x pos in range 0-7
    clc
    ror screen_char_x
    clc
    ror screen_char_x

    ; Mask for pixel in X pos of source character
    ldx screen_char_x
    lda #128
    .set_x_mask_loop
    dex
    bmi set_x_mask_done
    clc
    ror A
    jmp set_x_mask_loop
    .set_x_mask_done
    sta char_pixel_mask
    ldx screen_char_x

    ldy #0                         ; char row in Y
    sty screen_char_y

    .print_2px_char_sliceRow
        .print_2px_char_slicePrintBlock
            lda (char_ptr), Y
            and char_pixel_mask
            beq print_2px_char_slicePixelNotSet
            lda char_pixel_mask
            pha
            jsr print_block
            pla 
            sta char_pixel_mask

            jmp print_2px_char_sliceNextRow

        .print_2px_char_slicePixelNotSet
            lda char_pixel_mask
            pha
            ldx screen_char_x
            jsr print_custom_infill_char
            pla 
            sta char_pixel_mask

        .print_2px_char_sliceNextRow 
            iny
            cpy #8
            beq print_2px_char_sliceDone
            sty screen_char_y
            jmp print_2px_char_sliceRow

    .print_2px_char_sliceDone
    pla 
    tax
rts

;------------------------------------------------------------------------------
.print_block
;   Copy a solid block of 2x8 pixels to the offscreen buffer.
;------------------------------------------------------------------------------
    pha
    txa
    pha
    tya
    pha

    ldy #0
    .block_loop
        lda #col_red OR (col_red * 2)
        sta (offscreen_buff_ptr), Y
        iny
        cpy #8
        bne block_loop

    lda offscreen_buff_ptr
    clc
    adc #8
    sta offscreen_buff_ptr

    pla 
    tay
    pla 
    tax
    pla 

    rts


;------------------------------------------------------------------------------
.print_custom_infill_char
;   Fills in corners next to edges of surrounding blocks, giving an anti-
;   aliased effect. This is done by inspecting the surrounding pixels of the
;   source character and selecting an 8x8 character from the anti_alias_chars
;   table to match.
;
;   X:                  Char pixel col # (0=leftmost, 7=rightmost)
;   Y:                  Char pixel row # (0=leftmost, 7=rightmost)
;   char_ptr:           Start location of character being drawn
;   char_pixel_mask:    8-bit mask with only x pos bit set
;
;   On exit, custom_char populated with infill mask; A contains flags
;------------------------------------------------------------------------------
    pha
    lda #0
    sta temp                        ; init mask to store a bit for pixel above, right, left and below

    .check_top
    cpy #0
    beq check_right                  ; no pixel above, move along...
    dey                             ; decrement Y pos
    lda (char_ptr), Y                ; get that row
    and char_pixel_mask               ; check bit at same X pos (i.e. immediately above)
    beq check_top_restore_y            ; pixel above is clear, move along...

    lda temp                        ; set flag for top
    ora #%00000001
    sta temp

    .check_top_restore_y               ; restore Y and load contents of that row, ready for
    iny                             ; checking left & right pixels

    .check_right
    cpx #7
    beq check_left                   ; no pixel to right, move along...
    clc
    ror char_pixel_mask               ; move mask one bit to right
    lda (char_ptr), Y                ; get character row
    and char_pixel_mask               ; check whether bit to right is set
    beq check_right_restore_mask       ; bit to right is not set, move along

    lda temp                        ; set flag for right
    ora #%00000010
    sta temp

    .check_right_restore_mask          ; restore mask
    clc
    rol char_pixel_mask

    .check_left
    cpx #0
    beq check_bottom                 ; no pixel to left, move along
    clc
    rol char_pixel_mask               ; move mask one bit to left
    lda (char_ptr), Y                ; get character row
    and char_pixel_mask               ; check whether bit to left is set
    beq check_left_restore_mask        ; bit to left is clear, move along

    lda temp                        ; set flag for left
    ora #%00000100
    sta temp

    .check_left_restore_mask
    clc
    ror char_pixel_mask

    .check_bottom
    cpy #7
    beq build_char
    iny
    lda (char_ptr), Y                ; get character row
    and char_pixel_mask
    beq check_bottom_restore_y

    lda temp                        ; set flag for bottom
    ora #%00001000
    sta temp

    .check_bottom_restore_y
    dey

    .build_char
    lda #0
    sta flags

    .build_top
    lda #%00000001           ; check whether pixel above is set
    and temp
    beq build_buttom

        .build_topLeft
        lda #%00000100      ; check whether pixel to left is set
        and temp
        beq build_top_right

        lda flags           ; both top and left set, so set top-left flag
        ora #%00000001
        sta flags

        .build_top_right
        lda #%00000010      ; check whether pixel to right is set
        and temp
        beq build_buttom

        lda flags           ; both top and right set, so set top-right flag
        ora #%00000010
        sta flags

    .build_buttom
    lda #%00001000           ; check whether pixel below is set
    and temp
    beq do_draw

        .build_buttom_left
        lda #%00000100      ; check whether pixel to left is set
        and temp
        beq build_buttom_right

        lda flags           ; both bottom and left set, so set bottom-left flag
        ora #%00001000
        sta flags

        .build_buttom_right
        lda #%00000010      ; check whether pixel to right is set
        and temp
        beq do_draw

        lda flags           ; both bottom and right set, so set bottom-right flag
        ora #%00000100
        sta flags

    .do_draw

    txa
    pha
    tya
    pha

    lda flags

    jsr print_anti_alias_corners

    pla 
    tay
    pla 
    tax
    pla 

    rts

;------------------------------------------------------------------------------
.print_anti_alias_corners
;   Draws anti-aliased corners to the offscreen buffer. The accumulator
;   contains flags for which corners to draw.
;
;   A:  xxxx0000
;              ^--- top-left
;             ^---- top-right
;            ^----- bottom-right
;           ^------ bottom-left
;--------------------------------------------------
    sta anti_alias_corner_flags

    pha                         ; save accumulator

    lda char_ptr                 ; save char_ptr
    pha
    lda char_ptr+1
    pha

    lda anti_alias_corner_flags
    beq noCorners
    NOP
    .noCorners

    clc
    rol A                        ; x8
    rol A
    rol A
    adc #anti_alias_chars MOD 256
    sta char_ptr
    lda #0
    adc #anti_alias_chars DIV 256
    sta char_ptr+1

    jsr print_char

    pla  : sta char_ptr + 1
    pla  : sta char_ptr
    pla 

    rts

;------------------------------------------------------------------------------
.get_char_ptr_for_ascii
;   Populate char_ptr with pointer to ASCII character specified in accumulator.
;
;   A:  Character to retrieve
;------------------------------------------------------------------------------
    sta osword_0a

    lda #&0A
    ldx #osword_0a MOD 256
    ldy #osword_0a DIV 256
    jsr OSWORD

    ldx #custom_char MOD 256
    ldy #custom_char DIV 256
    stx char_ptr
    sty char_ptr+1

    rts

;------------------------------------------------------------------------------
.print_char
;   Renders a 2x8 strip of the given source character to the offscreen buffer.
;
;   char_ptr:       loc of char to render
;   char_pixel_x:   start bit position of strip to render within source char
;                   (0, 2, 4, 6)
;------------------------------------------------------------------------------
    tya
    pha

    ; Mask for pixel in X pos of source character
    ldy char_pixel_x
    lda #128
    .set_mask_loop
    dey
    bmi set_mask_done
    clc
    ror A
    jmp set_mask_loop
    .set_mask_done
    sta print_mask

    ldy #0

    .print_char_pix_a
        lda #0
        sta video_mem_value

        lda (char_ptr), Y
        and print_mask
        beq print_char_pix_b

        lda #col_red
        sta video_mem_value

    .print_char_pix_b
        clc
        ror print_mask

        lda (char_ptr), Y
        and print_mask
        beq print_2px_byte

        lda #(col_red * 2)
        ora video_mem_value
        sta video_mem_value

    .print_2px_byte
        clc
        rol print_mask ; restore to original value

        lda video_mem_value
        sta (offscreen_buff_ptr), Y

        iny
        tya
        and #&08
        beq print_char_pix_a

    .done
    lda offscreen_buff_ptr
    clc
    adc #8
    sta offscreen_buff_ptr

    pla 
    tay
rts

;------------------------------------------------------------------------------
.vid_mem_for_xy
; Put start loc for on-screen character pos into vid_mem_ptr
;
;   X: X character co-ord
;   Y: Y character co-ord
;------------------------------------------------------------------------------
{
    pha

    ; memory loc = VID_MEM_START + (Y * 640) + (X * 32)

    ; Y * 640 - use lookup
    tya
    rol A ; x2 to get word offset from start of lookup table (table contains
          ; 16-bit locations
    clc
    adc #table_640 MOD 256
    sta table_ptr
    lda #0
    adc #table_640 DIV 256
    sta table_ptr+1

    ; + VID_MEM_START
    ldy #1
    clc
    lda (table_ptr), Y
    adc #VID_MEM_START MOD 256
    sta vid_mem_ptr
    ldy #0
    lda (table_ptr), Y
    adc #VID_MEM_START DIV 256
    sta vid_mem_ptr+1

    ; + X*32 100000
    txa
    sta block_x_offset
    lda #0
    sta block_x_offset+1

    .print_block_mult_x2
        clc
        asl block_x_offset
        bcc print_block_mult_x4
        inc block_x_offset+1

    .print_block_mult_x4
        asl block_x_offset+1
        clc
        asl block_x_offset
        bcc print_block_mult_x8
        inc block_x_offset+1
    
    .print_block_mult_x8
        asl block_x_offset+1
        clc
        asl block_x_offset
        bcc print_block_mult_x16
        inc block_x_offset+1
    
    .print_block_mult_x16
        asl block_x_offset+1
        clc
        asl block_x_offset
        bcc print_block_mult_x32
        inc block_x_offset+1
    
    .print_block_mult_x32
        asl block_x_offset+1
        clc
        asl block_x_offset
        bcc done
        inc block_x_offset+1
    
    .done
    clc
    lda block_x_offset
    adc vid_mem_ptr
    sta vid_mem_ptr
    lda block_x_offset+1
    adc vid_mem_ptr+1
    sta vid_mem_ptr+1

    pla 
    rts
}

.anti_alias_corner_flags
    EQUB 0

.char_pixel_x
    EQUB 0
.char_pixel_mask
    EQUB 0
.print_mask
    EQUB 0
.screen_char_x
    EQUB 0
.screen_char_y
    EQUB 0

.video_mem_value
    EQUB 0

; Note that custom_char must follow OSWORD &0A character (it gets populated with
; result)
.osword_0a
    EQUB 0

.custom_char
    EQUB 0
    EQUB 0
    EQUB 0
    EQUB 0
    EQUB 0
    EQUB 0
    EQUB 0
    EQUB 0
