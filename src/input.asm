;; appGetKey [Input]
;;  Similar to [getKey](http://www.knightos.org/documentation/reference/input.html#getKey),
;;  but listens for hotkeys.
;; Outputs:
;;  A: Key pressed
;;  Z: Reset if thread lost focus during this call
appGetKey:
    pcall(getKey)
    jr checkKey

;; appGetKey [Input]
;;  Similar to [getKey](http://www.knightos.org/documentation/reference/input.html#getKey),
;;  but listens for hotkeys.
;; Outputs:
;;  A: Key pressed
;;  Z: Reset if thread lost focus during this call
appWaitKey:
    pcall(waitKey)
    ;jr checkKey

checkKey:
    cp kYEqu
    ijp(z, launchCastle)
    cp kGraph
    ijp(z, launchThreadList)
    cp a
    ret

mods:
    ; bitfield
    ; 0: shift
    ; 1: square
    ; 2: diamond
    .db 0

; From a TI-keyboard or the like
handleScanCode:
    or a
    ret z
    cp 0xFF
    ret z
    push af
        cp 0x4F
        jr nc, .modifier
        ; Load keymap based on mods
        ld b, a
        ild(a, (mods))
        bit 0, a
        jr nz, .shift
        bit 7, b
        jr nz, .shift
        ild(hl, ti_keyboard_keymap)
.find_key:
        ld a, b
        dec a
        cp 0x40
        jr nc, .not_mapped
        add a, l \ ld l, a \ jr nc, $+3 \ inc h
        ld a, (hl)
    inc sp \ inc sp
    cp a
    ret
.not_mapped:
    pop af
    ret
.shift:
        ild(hl, ti_keyboard_keymap_shift)
        ld a, b
        and 0b01111111
        ld b, a
        jr .find_key
.modifier:
        cp 0x50
        jr z, .clearMods

        cp 0x58 ; Square
        icall(z, launchThreadList)

        cp 0x54 ; Diamond
        icall(z, launchCastle)

        cp 0x51 ; Left shift
        jr nz, _
        ld a, 1
        ild((mods), a)
        icall(setCharSet)
_:      
        cp 0x52 ; Right shift
        jr nz, _
        ld a, 1
        ild((mods), a)
        icall(setCharSet)
_:  pop af
    or 1
    ld a, 0
    ret
.clearMods:
        xor a
        ild((mods), a)
        icall(setCharSet)
    jr -_

;; getCharacterInput [Input]
;;  Gets a key input from the user.
;; Outputs:
;;  A: ANSI character
;;  B: Raw keypress
;; Notes:
;;  Uses the upper-right hand corner of the screen to display
;;  input information, assumes you have a window chrome prepared.
;;  Possible values include \n and backspace (0x08).
;;  Also watches for F1/F5 to launch castle/thread list
getCharacterInput:
    icall(drawCharSetIndicator)

    pcall(getScanCode)
    ijp(z, handleScanCode)

    ld b, 0
    icall(appGetKey)
    jr nz, .lostFocus
    or a
    ret z ; Return if zero

    ld b, a

    ; Check for special keys
    cp kAlpha
    jr z, setCharSetFromKey
    cp k2nd
    jr z, setCharSetFromKey

    push bc

    ; Get key value
    sub 9
    jr c, _
    cp 41
    jr nc, _

    push hl
        push af
            ild(a, (charSet))
            add a, a \ add a, a \ add a, a \ ld b, a \ add a, a \ add a, a \ add a, b ; A * 40
            ild(hl, characterMapLowercase)
            add a, l
            ld l, a
            jr nc, $+3 \ inc h
        pop af

        add a, l
        ld l, a
        jr nc, $+3 \ inc h
        ld a, (hl)
    pop hl
    pop bc
    ret

_:  xor a
    pop bc
    cp a
    ret
.lostFocus:
    or 1
    ld a, 0
    ret

setCharSetFromKey:
    cp kAlpha
    icall(z, setAlphaKey)
    cp k2nd
    icall(z, set2ndKey)
    pcall(flushKeys)
    xor a
    ret

setAlphaKey: ; Switch between alpha charsets
    ild(a, (charSet))
    inc a
    cp 2 ; Clamp to <2
    jr c, _
        xor a
_:  ild((charSet), a)
    ret

set2ndKey: ; Switch between symbol charsets
    ild(a, (charSet))
    inc a
    cp 4 ; Clamp 1 < A < 4
    jr c, _
        ld a, 2
_:  cp 2
    jr nc, _
        ld a, 2
_:  ild((charSet), a)
    ret

; Draws the current character set indicator on a window
drawCharSetIndicator:
    push hl
    push de
    push bc
    push af
        ; Clear old sprite, if present
        ild(hl, clearCharSetSprite)
        ld de, 0x5C02
        ld b, 4
        pcall(putSpriteOR)

        ild(a, (charSet))
        ; Get sprite in HL
        add a, a \ add a, a ; A * 4
        ild(hl, charSetSprites)
        add a, l
        ld l, a
        jr nc, $+3 \ inc h
        ; Draw sprite
        pcall(putSpriteXOR)
    pop af
    pop bc
    pop de
    pop hl
    ret

charSet:
    .db 0

;; setCharSet [Input]
;;  Sets the character set used by [[getCharacterInput]].
;; Inputs:
;;  A: Charset
;; Notes:
;;  * 0: Uppercase letters
;;  * 1: Lowercase letters
;;  * 2: Symbols
;;  * 3: Extended symbols
setCharSet:
    cp 5
    ret nc ; Only allow 0-3
    ild((charSet), a)
    ret

;; getCharSet [Input]
;;  Gets the character set used by [[getCharacterInput]].
;; Inputs:
;;  A: Charset
;; Notes:
;;  * 0: Uppercase letters
;;  * 1: Lowercase letters
;;  * 2: Symbols
;;  * 3: Extended symbols
getCharSet:
    ild(a, (charSet))
    ret

#include "src/keymap.asm"
#include "src/characters.asm"
