.anti_alias_chars
.anti_alias_char0    ; BL/BR/TR/TL == 0000
    EQUB %00000000
    EQUB %00000000
    EQUB %00000000
    EQUB %00000000
    EQUB %00000000
    EQUB %00000000
    EQUB %00000000
    EQUB %00000000
.anti_alias_char1    ; BL/BR/TR/TL == 0001
    EQUB %11000000
    EQUB %11000000
    EQUB %00000000
    EQUB %00000000
    EQUB %00000000
    EQUB %00000000
    EQUB %00000000
    EQUB %00000000
.anti_alias_char2    ; BL/BR/TR/TL == 0010
    EQUB %00000011
    EQUB %00000011
    EQUB %00000000
    EQUB %00000000
    EQUB %00000000
    EQUB %00000000
    EQUB %00000000
    EQUB %00000000
.anti_alias_char3    ; BL/BR/TR/TL == 0011
    EQUB %11000011
    EQUB %11000011
    EQUB %00000000
    EQUB %00000000
    EQUB %00000000
    EQUB %00000000
    EQUB %00000000
    EQUB %00000000
.anti_alias_char4    ; BL/BR/TR/TL == 0100
    EQUB %00000000
    EQUB %00000000
    EQUB %00000000
    EQUB %00000000
    EQUB %00000000
    EQUB %00000000
    EQUB %00000011
    EQUB %00000011
.anti_alias_char5    ; BL/BR/TR/TL == 0101
    EQUB %11000000
    EQUB %11000000
    EQUB %00000000
    EQUB %00000000
    EQUB %00000000
    EQUB %00000000
    EQUB %00000011
    EQUB %00000011
.anti_alias_char6    ; BL/BR/TR/TL == 0110
    EQUB %00000011
    EQUB %00000011
    EQUB %00000000
    EQUB %00000000
    EQUB %00000000
    EQUB %00000000
    EQUB %00000011
    EQUB %00000011
.anti_alias_char7    ; BL/BR/TR/TL == 0111
    EQUB %11000011
    EQUB %11000011
    EQUB %00000000
    EQUB %00000000
    EQUB %00000000
    EQUB %00000000
    EQUB %00000011
    EQUB %00000011
.anti_alias_char8    ; BL/BR/TR/TL == 1000
    EQUB %00000000
    EQUB %00000000
    EQUB %00000000
    EQUB %00000000
    EQUB %00000000
    EQUB %00000000
    EQUB %11000000
    EQUB %11000000
.anti_alias_char9    ; BL/BR/TR/TL == 1001
    EQUB %11000000
    EQUB %11000000
    EQUB %00000000
    EQUB %00000000
    EQUB %00000000
    EQUB %00000000
    EQUB %11000000
    EQUB %11000000
.anti_alias_char10    ; BL/BR/TR/TL == 1010
    EQUB %00000011
    EQUB %00000011
    EQUB %00000000
    EQUB %00000000
    EQUB %00000000
    EQUB %00000000
    EQUB %11000000
    EQUB %11000000
.anti_alias_char11    ; BL/BR/TR/TL == 1011
    EQUB %11000011
    EQUB %11000011
    EQUB %00000000
    EQUB %00000000
    EQUB %00000000
    EQUB %00000000
    EQUB %11000000
    EQUB %11000000
.anti_alias_char12    ; BL/BR/TR/TL == 1100
    EQUB %00000000
    EQUB %00000000
    EQUB %00000000
    EQUB %00000000
    EQUB %00000000
    EQUB %00000000
    EQUB %11000011
    EQUB %11000011
.anti_alias_char13    ; BL/BR/TR/TL == 1101
    EQUB %11000000
    EQUB %11000000
    EQUB %00000000
    EQUB %00000000
    EQUB %00000000
    EQUB %00000000
    EQUB %11000011
    EQUB %11000011
.anti_alias_char14    ; BL/BR/TR/TL == 1110
    EQUB %00000011
    EQUB %00000011
    EQUB %00000000
    EQUB %00000000
    EQUB %00000000
    EQUB %00000000
    EQUB %11000011
    EQUB %11000011
.anti_alias_char15    ; BL/BR/TR/TL == 1111
    EQUB %11000011
    EQUB %11000011
    EQUB %00000000
    EQUB %00000000
    EQUB %00000000
    EQUB %00000000
    EQUB %11000011
    EQUB %11000011
; 640 multiplication table (LSB, MSB)
.table_640
   EQUW &0000 ; 0 * 640
   EQUW &8002 ; 1 * 640
   EQUW &0005 ; 2 * 640
   EQUW &8007 ; 3 * 640
   EQUW &000a ; 4 * 640
   EQUW &800c ; 5 * 640
   EQUW &000f ; 6 * 640
   EQUW &8011 ; 7 * 640
   EQUW &0014 ; 8 * 640
   EQUW &8016 ; 9 * 640
   EQUW &0019 ; 10 * 640
   EQUW &801b ; 11 * 640
   EQUW &001e ; 12 * 640
   EQUW &8020 ; 13 * 640
   EQUW &0023 ; 14 * 640
   EQUW &8025 ; 15 * 640
   EQUW &0028 ; 16 * 640
   EQUW &802a ; 17 * 640
   EQUW &002d ; 18 * 640
   EQUW &802f ; 19 * 640
   EQUW &0032 ; 20 * 640
   EQUW &8034 ; 21 * 640
   EQUW &0037 ; 22 * 640
   EQUW &8039 ; 23 * 640
   EQUW &003c ; 24 * 640
   EQUW &803e ; 25 * 640
   EQUW &0041 ; 26 * 640
   EQUW &8043 ; 27 * 640
   EQUW &0046 ; 28 * 640
   EQUW &8048 ; 29 * 640
   EQUW &004b ; 30 * 640
   EQUW &804d ; 31 * 640
