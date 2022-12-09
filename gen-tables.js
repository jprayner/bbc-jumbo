const corners = [
    "11000011",
    "11000011",
    "00000000",
    "00000000",
    "00000000",
    "00000000",
    "11000011",
    "11000011",
];

genTable();

function genTable() {
    console.log(".antiAliasChars");
    for (let i = 0; i < 16; i++) {
        let flags = i.toString(2);
        flags = "0000".substr(flags.length) + flags;
        console.log(`.antiAliasChar${i}    ; BL/BR/TR/TL == ${flags}`);

        const bottomLeft = i & 8;
        const bottomRight = i & 4;
        const topRight = i & 2;
        const topLeft = i & 1;

        for (let j = 0; j < 8; j++) {
            let charRowBinary = corners[j];
            let charRow = parseInt(charRowBinary, 2);

            let mask = 0;
            if (j < 4) {
                // top
                if (topLeft) {
                    mask |= parseInt("11110000", 2);
                }
                if (topRight) {
                    mask |= parseInt("00001111", 2);
                }
            } else {
                // bottom
                if (bottomLeft) {
                    mask |= parseInt("11110000", 2);
                }
                if (bottomRight) {
                    mask |= parseInt("00001111", 2);
                }
            }

            let maskedRow = charRow & mask;
            let maskedRowBinary = maskedRow.toString(2);
            maskedRowBinary = "00000000".substr(maskedRowBinary.length) + maskedRowBinary;
            console.log(`    EQUB %${maskedRowBinary}`);
        }
    }

    console.log(`; 640 multiplication table (LSB, MSB)`);
    console.log(`.Table640`);
    for (let i = 0; i < 32; i++) {
        let val = i * 640;

        let valHexLo = (val % 256).toString(16);
        valHexLo = "00".substr(valHexLo.length) + valHexLo;

        let valHexHi = Math.floor(val / 256).toString(16);
        valHexHi = "00".substr(valHexHi.length) + valHexHi;

        console.log(`   EQUW &${valHexLo}${valHexHi} ; ${i} * 640`);
    }
}
