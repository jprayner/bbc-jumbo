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

;--------------------------------------------------
.print_2px_char_slice
;   Print given ASCII at 8x size i.e. 64x64 pixels
;   a: character to print
;   x: 2-char vertical strip index within enlarged char (range 0-31)
;--------------------------------------------------
    STX screen_char_x
    JSR get_char_ptr_for_ascii

    LDA #offscreen_buffer MOD 256
    STA offscreen_buff_ptr
    LDA #offscreen_buffer DIV 256
    STA offscreen_buff_ptr + 1

    ; Save x to stack
    LDA screen_char_x
    PHA

    ; We get called 4 times for each character to draw a 2-pixel slice
    ; each time. char_pixel_x tells us start pixel X pos within the character
    ; for each slice (0, 2, 4, 6)
    AND #%00000011
    STA char_pixel_x
    CLC
    ROL char_pixel_x

    ; Divide x by 4 to get on-screen character in range 0-7
    CLC
    ROR screen_char_x
    CLC
    ROR screen_char_x

    ; Mask for pixel in X pos of source character
    LDX screen_char_x
    LDA #128
    .set_x_mask_loop
    DEX
    BMI set_x_mask_done
    CLC
    ROR A
    JMP set_x_mask_loop
    .set_x_mask_done
    STA char_pixel_mask
    LDX screen_char_x

    LDY #0                         ; char row in Y
    STY screen_char_y

    .print_2px_char_sliceRow
        .print_2px_char_slicePrintBlock
            LDA (char_ptr), Y
            AND char_pixel_mask
            BEQ print_2px_char_slicePixelNotSet
            LDA char_pixel_mask
            PHA
            JSR print_block
            PLA
            STA char_pixel_mask

            JMP print_2px_char_sliceNextRow

        .print_2px_char_slicePixelNotSet
            LDA char_pixel_mask
            PHA
            LDX screen_char_x
            JSR print_custom_infill_char
            PLA
            STA char_pixel_mask

        .print_2px_char_sliceNextRow 
            INY
            CPY #8
            BEQ print_2px_char_sliceDone
            STY screen_char_y
            JMP print_2px_char_sliceRow

    .print_2px_char_sliceDone
    PLA
    TAX
RTS

;--------------------------------------------------
.print_block
;   Show a block of 8x8 pixels at specified location
;   x: X character co-ord
;   y: Y character co-ord
;--------------------------------------------------
    PHA
    TXA
    PHA
    TYA
    PHA

    LDY #0
    .block_loop
        LDA #col_red OR (col_red * 2)
        STA (offscreen_buff_ptr), Y
        INY
        CPY #8
        BNE block_loop

    LDA offscreen_buff_ptr
    CLC
    ADC #8
    STA offscreen_buff_ptr

    PLA
    TAY
    PLA
    TAX
    PLA

    RTS


;--------------------------------------------------
.print_custom_infill_char
;   Fills in corners next to edges of surrounding blocks, giving an anti-aliased effect.
;   This is done by inspecting the surrounding pixels of the source character and selecting
;   an 8x8 character from the anti_alias_chars table to match.
;
;   x: Char pixel col # (0=leftmost, 7=rightmost)
;   y: Char pixel row # (0=leftmost, 7=rightmost)
;   char_ptr: start location of character being drawn
;   char_pixel_mask: 8-bit mask with only x pos bit set
;   on exit, custom_char populated with infill mask; a contains flags
;--------------------------------------------------
    PHA
    LDA #0
    STA temp                        ; init mask to store a bit for pixel above, right, left and below

    .check_top
    CPY #0
    BEQ check_right                  ; no pixel above, move along...
    DEY                             ; decrement Y pos
    LDA (char_ptr), Y                ; get that row
    AND char_pixel_mask               ; check bit at same X pos (i.e. immediately above)
    BEQ check_top_restore_y            ; pixel above is clear, move along...

    LDA temp                        ; set flag for top
    ORA #%00000001
    STA temp

    .check_top_restore_y               ; restore Y and load contents of that row, ready for
    INY                             ; checking left & right pixels

    .check_right
    CPX #7
    BEQ check_left                   ; no pixel to right, move along...
    CLC
    ROR char_pixel_mask               ; move mask one bit to right
    LDA (char_ptr), Y                ; get character row
    AND char_pixel_mask               ; check whether bit to right is set
    BEQ check_right_restore_mask       ; bit to right is not set, move along

    LDA temp                        ; set flag for right
    ORA #%00000010
    STA temp

    .check_right_restore_mask          ; restore mask
    CLC
    ROL char_pixel_mask

    .check_left
    CPX #0
    BEQ check_bottom                 ; no pixel to left, move along
    CLC
    ROL char_pixel_mask               ; move mask one bit to left
    LDA (char_ptr), Y                ; get character row
    AND char_pixel_mask               ; check whether bit to left is set
    BEQ check_left_restore_mask        ; bit to left is clear, move along

    LDA temp                        ; set flag for left
    ORA #%00000100
    STA temp

    .check_left_restore_mask
    CLC
    ROR char_pixel_mask

    .check_bottom
    CPY #7
    BEQ build_char
    INY
    LDA (char_ptr), Y                ; get character row
    AND char_pixel_mask
    BEQ check_bottom_restore_y

    LDA temp                        ; set flag for bottom
    ORA #%00001000
    STA temp

    .check_bottom_restore_y
    DEY

    .build_char
    LDA #0
    STA flags

    .build_top
    LDA #%00000001           ; check whether pixel above is set
    AND temp
    BEQ build_buttom

        .build_topLeft
        LDA #%00000100      ; check whether pixel to left is set
        AND temp
        BEQ build_top_right

        LDA flags           ; both top and left set, so set top-left flag
        ORA #%00000001
        STA flags

        .build_top_right
        LDA #%00000010      ; check whether pixel to right is set
        AND temp
        BEQ build_buttom

        LDA flags           ; both top and right set, so set top-right flag
        ORA #%00000010
        STA flags

    .build_buttom
    LDA #%00001000           ; check whether pixel below is set
    AND temp
    BEQ doDraw

        .build_buttom_left
        LDA #%00000100      ; check whether pixel to left is set
        AND temp
        BEQ build_buttom_right

        LDA flags           ; both bottom and left set, so set bottom-left flag
        ORA #%00001000
        STA flags

        .build_buttom_right
        LDA #%00000010      ; check whether pixel to right is set
        AND temp
        BEQ doDraw

        LDA flags           ; both bottom and right set, so set bottom-right flag
        ORA #%00000100
        STA flags

    .doDraw

    TXA
    PHA
    TYA
    PHA

    LDA flags

    JSR print_anti_alias_corners

    PLA
    TAY
    PLA
    TAX
    PLA

    RTS

;--------------------------------------------------
.print_anti_alias_corners
;   Draws anti-aliased corners at the specified character position. The
;   accumulator contains flags for which corners to draw.
;   a:  xxxx0000
;              ^--- top-left
;             ^---- top-right
;            ^----- bottom-right
;           ^------ bottom-left
;--------------------------------------------------
    STA anti_alias_corner_flags

    PHA                         ; save accumulator

    LDA char_ptr                 ; save char_ptr
    PHA
    LDA char_ptr+1
    PHA

    LDA anti_alias_corner_flags
    BEQ noCorners
    NOP
    .noCorners

    CLC
    ROL A                        ; x8
    ROL A
    ROL A
    ADC #anti_alias_chars MOD 256
    STA char_ptr
    LDA #0
    ADC #anti_alias_chars DIV 256
    STA char_ptr+1

    JSR print_char

    PLA : STA char_ptr + 1
    PLA : STA char_ptr
    PLA

    RTS

;--------------------------------------------------
.get_char_ptr_for_ascii
;   Given ASCII character, get ptr to char in
;   character set (8 rows x 8 bits) and store in 
;   char_ptr
;   a: character to print
;--------------------------------------------------
    STA osword_0a

    LDA #&0A
    LDX #osword_0a MOD 256
    LDY #osword_0a DIV 256
    JSR OSWORD

    LDX #custom_char MOD 256
    LDY #custom_char DIV 256
    STX char_ptr
    STY char_ptr+1

    RTS

;--------------------------------------------------
.print_char
;   Copies an 8x8 character from the given source address to the screen at the given position.
;   (char_ptr): loc of char
;   char_pixel_x: start X pos of 2-pixel strip within character (0, 2, 4, 6)
;--------------------------------------------------
    TYA
    PHA

    ; Mask for pixel in X pos of source character
    LDY char_pixel_x
    LDA #128
    .set_mask_loop
    DEY
    BMI set_mask_done
    CLC
    ROR A
    JMP set_mask_loop
    .set_mask_done
    STA print_mask

    LDY #0

    .print_char_pix_a
        LDA #0
        STA video_mem_value

        LDA (char_ptr), Y
        AND print_mask
        BEQ print_char_pix_b

        LDA #col_red
        STA video_mem_value

    .print_char_pix_b
        CLC
        ROR print_mask

        LDA (char_ptr), Y
        AND print_mask
        BEQ print_2px_byte

        LDA #(col_red * 2)
        ORA video_mem_value
        STA video_mem_value

    .print_2px_byte
        CLC
        ROL print_mask ; restore to original value

        LDA video_mem_value
        STA (offscreen_buff_ptr), Y

        INY
        TYA
        AND #&08
        BEQ print_char_pix_a

    .done
    LDA offscreen_buff_ptr
    CLC
    ADC #8
    STA offscreen_buff_ptr

    PLA
    TAY
RTS

;--------------------------------------------------
.vid_mem_for_xy
; Put start loc for character pos into vid_mem_ptr
; x: X character co-ord
; y: Y character co-ord
;--------------------------------------------------
{
    PHA

    ; memory loc = VID_MEM_START + (Y * 640) + (X * 32)

    ; Y * 640 - use lookup, see http://mdfs.net/Docs/Comp/BBC/OS1-20/C300
    TYA
    ROL A ; x2 to get word offset from start of lookup table (table contains
          ; 16-bit locations
    CLC
    ADC #table_640 MOD 256
    STA table_ptr
    LDA #0
    ADC #table_640 DIV 256
    STA table_ptr+1

    ; + VID_MEM_START
    LDY #1
    CLC
    LDA (table_ptr), Y
    ADC #VID_MEM_START MOD 256
    STA vid_mem_ptr
    LDY #0
    LDA (table_ptr), Y
    ADC #VID_MEM_START DIV 256
    STA vid_mem_ptr+1

    ; + X*32 100000
    TXA
    STA block_x_offset
    LDA #0
    STA block_x_offset+1

    .print_block_mult_x2
        CLC
        ASL block_x_offset
        BCC print_block_mult_x4
        INC block_x_offset+1

    .print_block_mult_x4
        ASL block_x_offset+1
        CLC
        ASL block_x_offset
        BCC print_block_mult_x8
        INC block_x_offset+1
    
    .print_block_mult_x8
        ASL block_x_offset+1
        CLC
        ASL block_x_offset
        BCC print_block_mult_x16
        INC block_x_offset+1
    
    .print_block_mult_x16
        ASL block_x_offset+1
        CLC
        ASL block_x_offset
        BCC print_block_mult_x32
        INC block_x_offset+1
    
    .print_block_mult_x32
        ASL block_x_offset+1
        CLC
        ASL block_x_offset
        BCC done
        INC block_x_offset+1
    
    .done
    CLC
    LDA block_x_offset
    ADC vid_mem_ptr
    STA vid_mem_ptr
    LDA block_x_offset+1
    ADC vid_mem_ptr+1
    STA vid_mem_ptr+1

    PLA
    RTS
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
