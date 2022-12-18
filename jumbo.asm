col_black = 0
col_red = 1
col_green = 2
col_yellow = 3
col_blue = 4
col_magenta = 5
col_cyan = 6
col_white = 7
col_flash_black_white = 8
col_flash_red_cyan = 9
col_flash_green_magenta = 10
col_flash_yellow_blue = 11
col_flash_blue_yellow = 12
col_flash_magenta_green = 13
col_flash_cyan_red = 14
col_flash_white_black = 15

.BlockXOffset
    EQUW 0

;--------------------------------------------------
.PrintBigChar
;   Print given ASCII at 8x size i.e. 64x64 pixels
;   a: character to print
;   x: 2-char vertical strip index within enlarged char (range 0-31)
;--------------------------------------------------
    STX ScreenCharX
    JSR CharSrcPtrForASCII

    LDA #offscreen_buffer MOD 256
    STA offscreen_buffer_ptr
    LDA #offscreen_buffer DIV 256
    STA offscreen_buffer_ptr + 1

    ; Save x to stack
    LDA ScreenCharX
    PHA

    ; We get called 4 times for each character to draw a 2-pixel slice
    ; each time. CharPixelX tells us start pixel X pos within the character
    ; for each slice (0, 2, 4, 6)
    AND #%00000011
    STA CharPixelX
    CLC
    ROL CharPixelX

    ; Divide x by 4 to get on-screen character in range 0-7
    CLC
    ROR ScreenCharX
    CLC
    ROR ScreenCharX

    ; Mask for pixel in X pos of source character
    LDX ScreenCharX
    LDA #128
    .setXmaskLoop
    DEX
    BMI setXmaskDone
    CLC
    ROR A
    JMP setXmaskLoop
    .setXmaskDone
    STA CharPixelMask
    LDX ScreenCharX

    LDY #0                         ; char row in Y
    STY ScreenCharY

    .PrintBigCharRow
        .PrintBigCharPrintBlock
            LDA (CharPtr), Y
            AND CharPixelMask
            BEQ PrintBigCharPixelNotSet
            LDA CharPixelMask
            PHA
            JSR ShowBlock
            PLA
            STA CharPixelMask

            JMP PrintBigCharNextRow

        .PrintBigCharPixelNotSet
            LDA CharPixelMask
            PHA
            LDX ScreenCharX
            JSR DrawCustomInfillChar
            PLA
            STA CharPixelMask

        .PrintBigCharNextRow 
            INY
            CPY #8
            BEQ PrintBigCharDone
            STY ScreenCharY
            JMP PrintBigCharRow

    .PrintBigCharDone
    PLA
    TAX
RTS

;--------------------------------------------------
.ShowBlock
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
        STA (offscreen_buffer_ptr), Y
        INY
        CPY #8
        BNE block_loop

    LDA offscreen_buffer_ptr
    CLC
    ADC #8
    STA offscreen_buffer_ptr

    PLA
    TAY
    PLA
    TAX
    PLA

    RTS


;--------------------------------------------------
.DrawCustomInfillChar
;   Fills in corners next to edges of surrounding blocks, giving an anti-aliased effect.
;   This is done by inspecting the surrounding pixels of the source character and selecting
;   an 8x8 character from the antiAliasChars table to match.
;
;   x: Char pixel col # (0=leftmost, 7=rightmost)
;   y: Char pixel row # (0=leftmost, 7=rightmost)
;   CharPtr: start location of character being drawn
;   CharPixelMask: 8-bit mask with only x pos bit set
;   on exit, CustomChar populated with infill mask; a contains flags
;--------------------------------------------------
    PHA
    LDA #0
    STA Temp                        ; init mask to store a bit for pixel above, right, left and below

    .checkTop
    CPY #0
    BEQ checkRight                  ; no pixel above, move along...
    DEY                             ; decrement Y pos
    LDA (CharPtr), Y                ; get that row
    AND CharPixelMask               ; check bit at same X pos (i.e. immediately above)
    BEQ checkTopRestoreY            ; pixel above is clear, move along...

    LDA Temp                        ; set flag for top
    ORA #%00000001
    STA Temp

    .checkTopRestoreY               ; restore Y and load contents of that row, ready for
    INY                             ; checking left & right pixels

    .checkRight
    CPX #7
    BEQ checkLeft                   ; no pixel to right, move along...
    CLC
    ROR CharPixelMask               ; move mask one bit to right
    LDA (CharPtr), Y                ; get character row
    AND CharPixelMask               ; check whether bit to right is set
    BEQ checkRightRestoreMask       ; bit to right is not set, move along

    LDA Temp                        ; set flag for right
    ORA #%00000010
    STA Temp

    .checkRightRestoreMask          ; restore mask
    CLC
    ROL CharPixelMask

    .checkLeft
    CPX #0
    BEQ checkBottom                 ; no pixel to left, move along
    CLC
    ROL CharPixelMask               ; move mask one bit to left
    LDA (CharPtr), Y                ; get character row
    AND CharPixelMask               ; check whether bit to left is set
    BEQ checkLeftRestoreMask        ; bit to left is clear, move along

    LDA Temp                        ; set flag for left
    ORA #%00000100
    STA Temp

    .checkLeftRestoreMask
    CLC
    ROR CharPixelMask

    .checkBottom
    CPY #7
    BEQ buildChar
    INY
    LDA (CharPtr), Y                ; get character row
    AND CharPixelMask
    BEQ checkBottomRestoreY

    LDA Temp                        ; set flag for bottom
    ORA #%00001000
    STA Temp

    .checkBottomRestoreY
    DEY

    .buildChar
    LDA #0
    STA Flags

    .buildTop
    LDA #%00000001           ; check whether pixel above is set
    AND Temp
    BEQ buildBottom

        .buildTopLeft
        LDA #%00000100      ; check whether pixel to left is set
        AND Temp
        BEQ buildTopRight

        LDA Flags           ; both top and left set, so set top-left flag
        ORA #%00000001
        STA Flags

        .buildTopRight
        LDA #%00000010      ; check whether pixel to right is set
        AND Temp
        BEQ buildBottom

        LDA Flags           ; both top and right set, so set top-right flag
        ORA #%00000010
        STA Flags

    .buildBottom
    LDA #%00001000           ; check whether pixel below is set
    AND Temp
    BEQ doDraw

        .buildBottomLeft
        LDA #%00000100      ; check whether pixel to left is set
        AND Temp
        BEQ buildBottomRight

        LDA Flags           ; both bottom and left set, so set bottom-left flag
        ORA #%00001000
        STA Flags

        .buildBottomRight
        LDA #%00000010      ; check whether pixel to right is set
        AND Temp
        BEQ doDraw

        LDA Flags           ; both bottom and right set, so set bottom-right flag
        ORA #%00000100
        STA Flags

    .doDraw

    TXA
    PHA
    TYA
    PHA

    LDA Flags

    JSR DrawAntiAliasCorners

    PLA
    TAY
    PLA
    TAX
    PLA

    RTS

;--------------------------------------------------
.DrawAntiAliasCorners
;   Draws anti-aliased corners at the specified character position. The
;   accumulator contains flags for which corners to draw.
;   a:  xxxx0000
;              ^--- top-left
;             ^---- top-right
;            ^----- bottom-right
;           ^------ bottom-left
;--------------------------------------------------
    STA DrawAntiAliasCornersFlags

    PHA                         ; save accumulator

    LDA CharPtr                 ; save CharPtr
    PHA
    LDA CharPtr+1
    PHA

    LDA DrawAntiAliasCornersFlags
    BEQ noCorners
    NOP
    .noCorners

    CLC
    ROL A                        ; x8
    ROL A
    ROL A
    ADC #antiAliasChars MOD 256
    STA CharPtr
    LDA #0
    ADC #antiAliasChars DIV 256
    STA CharPtr+1


    JSR PrintChar

    PLA                         ; restore CharPtr
    STA CharPtr+1
    PLA
    STA CharPtr

    PLA                         ; restore accumulator

    RTS

;--------------------------------------------------
.CharSrcPtrForASCII
;   Given ASCII character, get ptr to char in
;   character set (8 rows x 8 bits) and store in 
;   CharPtr
;   a: character to print
;--------------------------------------------------
    STA OSWORDx0A

    LDA #&0A
    LDX #OSWORDx0A MOD 256
    LDY #OSWORDx0A DIV 256
    JSR osword

    LDX #CustomChar MOD 256
    LDY #CustomChar DIV 256
    STX CharPtr
    STY CharPtr+1

    RTS

;--------------------------------------------------
.PrintChar
;   Copies an 8x8 character from the given source address to the screen at the given position.
;   (CharPtr): loc of char
;   CharPixelX: start X pos of 2-pixel strip within character (0, 2, 4, 6)
;--------------------------------------------------
    TYA
    PHA

    ; Mask for pixel in X pos of source character
    LDY CharPixelX
    LDA #128
    .setPrintMaskLoop
    DEY
    BMI setPrintMaskDone
    CLC
    ROR A
    JMP setPrintMaskLoop
    .setPrintMaskDone
    STA PrintMask

    LDY #0

    .PrintCharPixA
        LDA #0
        STA VideoMemValue

        LDA (CharPtr), Y
        AND PrintMask
        BEQ PrintCharPixB

        LDA #col_red
        STA VideoMemValue

    .PrintCharPixB
        CLC
        ROR PrintMask

        LDA (CharPtr), Y
        AND PrintMask
        BEQ PrintCharDisplayColByte

        LDA #(col_red * 2)
        ORA VideoMemValue
        STA VideoMemValue

    .PrintCharDisplayColByte
        CLC
        ROL PrintMask ; restore to original value

        LDA VideoMemValue
        STA (offscreen_buffer_ptr), Y

        INY
        TYA
        AND #&08
        BEQ PrintCharPixA

    .PrintCharDone
    LDA offscreen_buffer_ptr
    CLC
    ADC #8
    STA offscreen_buffer_ptr

    PLA
    TAY
RTS

;--------------------------------------------------
.VidMemForXY
; Put start loc for character pos into VidMemPtr
; x: X character co-ord
; y: Y character co-ord
;--------------------------------------------------
    PHA

    ; memory loc = vid_mem + (Y * 640) + (X * 32)

    ; Y * 640 - use lookup, see http://mdfs.net/Docs/Comp/BBC/OS1-20/C300
    TYA
    ROL A ; x2 to get word offset from start of lookup table (table contains
          ; 16-bit locations
    CLC
    ADC #Table640 MOD 256
    STA TablePtr
    LDA #0
    ADC #Table640 DIV 256
    STA TablePtr+1

    ; + vid_mem
    LDY #1
    CLC
    LDA (TablePtr), Y
    ADC #vid_mem MOD 256
    STA VidMemPtr
    LDY #0
    LDA (TablePtr), Y
    ADC #vid_mem DIV 256
    STA VidMemPtr+1

    ; + X*32 100000
    TXA
    STA BlockXOffset
    LDA #0
    STA BlockXOffset+1

    .ShowBlockMultX2
        CLC
        ASL BlockXOffset
        BCC ShowBlockMultX4
        INC BlockXOffset+1

    .ShowBlockMultX4
        ASL BlockXOffset+1
        CLC
        ASL BlockXOffset
        BCC ShowBlockMultX8
        INC BlockXOffset+1
    
    .ShowBlockMultX8
        ASL BlockXOffset+1
        CLC
        ASL BlockXOffset
        BCC ShowBlockMultX16
        INC BlockXOffset+1
    
    .ShowBlockMultX16
        ASL BlockXOffset+1
        CLC
        ASL BlockXOffset
        BCC ShowBlockMultX32
        INC BlockXOffset+1
    
    .ShowBlockMultX32
        ASL BlockXOffset+1
        CLC
        ASL BlockXOffset
        BCC ShowBlockMultDone
        INC BlockXOffset+1
    
    .ShowBlockMultDone
    CLC
    LDA BlockXOffset
    ADC VidMemPtr
    STA VidMemPtr
    LDA BlockXOffset+1
    ADC VidMemPtr+1
    STA VidMemPtr+1

    PLA
    RTS


.DrawAntiAliasCornersFlags
    EQUB 0

.CharPixelX
    EQUB 0
.CharPixelY
    EQUB 0
.CharPixelMask
    EQUB 0
.PrintMask
    EQUB 0
.ScreenCharX
    EQUB 0
.ScreenCharY
    EQUB 0

.VideoMemValue
    EQUB 0

.DebugCli
    EQUS "EXEC DEBUG", 13

; Note that CustomChar must follow OSWORD &0A character (it gets populated with
; result)
.OSWORDx0A
    EQUB 0

.CustomChar
    EQUB 0
    EQUB 0
    EQUB 0
    EQUB 0
    EQUB 0
    EQUB 0
    EQUB 0
    EQUB 0
