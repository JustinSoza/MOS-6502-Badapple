    PROCESSOR 6502

VIA_REG_B    = $6000
VIA_REG_A    = $6001
VIA_DDR_B    = $6002
VIA_DDR_A    = $6003
VIA_PCR     = $600C

ACIA_DATA     = $5000
ACIA_STATUS    = $5001
ACIA_CMD    = $5002
ACIA_CTRL    = $5003


LCD_EN_LOW        = (0 << 7)
LCD_EN_HIGH        = (1 << 7)

LCD_RW_WRITE    = (0 << 6)
LCD_RW_READ     = (1 << 6)

LCD_RS_CMD        = (0 << 5)
LCD_RS_DATA        = (1 << 5)

I2CRAM  = $00

I2CADDR = I2CRAM
inb     = I2CRAM +1
outb    = I2CRAM +2
xtmp    = I2CRAM +3
lowbyte = I2CRAM +4
highbyte= I2CRAM +5

SCL     = 1 ; DRB0 bitmask
SCL_INV = $FE ; Inverted for easy clear bit
SDA     = 2 ; DRB1 bitmask
SDA_INV = $FD

RIOT = $80

; ========================================

    SEG        text
    ORG $8000
start:
    LDA #%00000000
    STA VIA_DDR_A

    LDA #$3C
    STA I2CADDR
    jsr oled_initF
    jsr oled_clear
    jsr oled_init
    jsr oled_write
    jmp halt

i2c_start:
  lda I2CADDR
  rol ; Shift in carry
  sta outb ; Save addr + r/w bit

  lda #SCL_INV
  and VIA_DDR_A
  sta VIA_DDR_A ; Start with SCL as input HIGH - that way we can inc/dec from here

  lda #SDA ; Ensure SDA is output low before SCL is LOW
  ora VIA_DDR_A
  sta VIA_DDR_A
  lda #SDA_INV
  and VIA_REG_A
  sta VIA_REG_A

  lda #SCL_INV ; Ensure SCL is low when it turns to output
  and VIA_REG_A
  sta VIA_REG_A
  inc VIA_DDR_A ; Set to output by incrementing the direction register == OUT, LOW

  ; Fall through to send address + RW bit
  ; After a start condition we always send the address byte so we don't need to RTS+JSR again here

i2cbyteout: ; Clears outb
  lda #SDA_INV ; In case this is a data byte we set SDA LOW
  and VIA_REG_A
  sta VIA_REG_A
  ldx #8
  bne first ; BRA - skip INC since first time already out, low
I2Cbyteloop:
  inc VIA_DDR_A ; SCL out, low
first:
  asl outb ; MSB to carry
  bcc seti2cbit0 ; If bit was low
  lda VIA_DDR_A       ; else set it high
  and #SDA_INV
  sta VIA_DDR_A
  bcs wasone ; BRA doesn't exist on 6507
seti2cbit0:
  lda VIA_DDR_A
  ora #SDA
  sta VIA_DDR_A
wasone:
  dec VIA_DDR_A
  dex
  bne I2Cbyteloop

  inc VIA_DDR_A

  lda VIA_DDR_A ; Set SDA to INPUT (HIGH)
  and #SDA_INV
  sta VIA_DDR_A

  dec VIA_DDR_A ; Clock high
  lda VIA_REG_A  ; Check ACK bit
  sec
  and #SDA
  bne nack
  clc ; Clear carry on ACK
nack:
  inc VIA_DDR_A ; SCL low
  rts

i2cbytein:
  ; Assume SCL is low from address byte
  lda VIA_DDR_A  ; SDA, input
  and #SDA_INV
  sta VIA_DDR_A
  lda #0
  sta inb
  ldx #8
i2cbyteinloop:
  clc
  dec VIA_DDR_A ; SCL HIGH
  lda VIA_REG_A ; Let's read after SCL goes high
  and #SDA
  beq got0
  sec
got0:
  rol inb ; Shift bit into the input byte
  inc VIA_DDR_A ; SCL LOW
  dex
  bne i2cbyteinloop

  lda VIA_DDR_A ; Send NACK == SDA high (only single bytes for now)
  and #SDA_INV
  sta VIA_DDR_A
  dec VIA_DDR_A ; SCL HIGH
  inc VIA_DDR_A ; SCL LOW
rts
i2c_stop:
  lda VIA_DDR_A ; SDA low
  ora #SDA
  sta VIA_DDR_A
  dec VIA_DDR_A ; SCL HIGH
  lda VIA_DDR_A ; Set SDA high after SCL == Stop condition
  and #SDA_INV
  sta VIA_DDR_A
  rts

oled_initF:
    clc
    jsr i2c_start
    ;lda #$80
    ;sta outb
    ;jsr i2cbyteout
    LDY #0
initloopF:
    LDA oled_inittabF,y
    cmp #$ff
    beq init_doneF
    STA outb
    jsr i2cbyteout
    iny
    bne initloopF
init_doneF:
    jsr i2c_stop
    rts

oled_init:
    clc
    jsr i2c_start
    ;lda #$80
    ;sta outb
    ;jsr i2cbyteout
    LDY #0
initloop:
    LDA oled_inittab,y
    cmp #$ff
    beq init_done
    STA outb
    jsr i2cbyteout
    iny
    bne initloop
init_done:
    jsr i2c_stop
    rts


oled_clear:
  clc 
  jsr i2c_start
  lda #$40
  sta outb
  jsr i2cbyteout
  ldx #4 ; 4 for full screen
clearrow:
  ldy #0
  stx xtmp
clearcolumn:
  lda #0
  clc
  jsr i2cbyteout
  dey
  bne clearcolumn ; inner loop
  ldx xtmp
  dex
  bne clearrow ; outer loop
  jsr i2c_stop
  rts

oled_write:
  clc ; write
  jsr i2c_start
  lda #$40 ; Data write mode
  STA outb
  jsr i2cbyteout

  ldx #<oled_screen
  stx lowbyte ; low byte
  ldx #>oled_screen
  stx highbyte ; high byte

  ldx #40
  stx xtmp
  ldy #0
write_loop:
  LDA (lowbyte),y ; Load byte into A
  STA outb
  jsr i2cbyteout ; Send out byte
  iny ; loop through all bytes
  bne write_loop
  ldx highbyte ; load high byte
  inx
  stx highbyte ; save new high byte
  ldx xtmp
  dex
  bne write_loop
write_done:
  lda #0
  rts

halt:
  jmp halt



oled_inittabF:
  .byte $ae ; turn display off
  .byte $d5 ; 
  .byte $f0
  .byte $a8
  .byte $3f ; screen size
  .byte $40 ; startline 0
  .byte $21 ; limit columns
  .byte $00 ; start 0
  .byte $7f ; end 63=3f, end 127=7f
  .byte $22 ; limit pages
  .byte $00 ; page 0
  .byte $07 ; page 3
  .byte $8d
  .byte $14
  .byte $a1
  .byte $c8
  .byte $20 ; addressing mode
  .byte $01 ; 10=page, 00=horz, 01=vert
  .byte $da
  .byte $12
  .byte $fe ; set contrast
  .byte $7f
  .byte $d9
  .byte $11
  .byte $a4
  .byte $af ; turn display on
  .byte $b0, $10, $00 ; page 0, column 0
  .byte $ff ; STOP

oled_inittab:
  .byte $ae ; turn display off
  .byte $d5 ; 
  .byte $f0
  .byte $a8
  .byte $3f ; screen size
  .byte $40 ; startline 0
  .byte $21 ; limit COLUMNS
  .byte $00 ; start 0, 31=1f
  .byte $3f ; end 63=3f, end 127=7f, 95=5f
  .byte $22 ; limit PAGES
  .byte $00 ; page 0
  .byte $03 ; page 3
  .byte $8d
  .byte $14
  .byte $a1
  .byte $c8
  .byte $20 ; addressing mode
  .byte $01 ; 10=page, 00=horz, 01=vert
  .byte $da
  .byte $12
  .byte $fe ; set contrast
  .byte $7f
  .byte $d9
  .byte $11
  .byte $a4
  .byte $af ; turn display on
  .byte $b0, $10, $00 ; page 2, column 31
  .byte $ff ; STOP

oled_screen:
  INCBIN "./code/badapple.bin"
    
    
    ORG $FFFA
reset_vectors:
    DC.W start    ; NMI
    DC.W start    ; RESET
    DC.W start    ; IRQ