.MODEL TINY
.DATA

inputname       DB     "ENTER IC  "; input prompt
Num             DW      00H        ; counts of number of characters entered
COUNT           DW      0000H      ; counts of number of characters to be printed 
INVALID        DB     "INVALID IC" ; for incorrect input
Flag       DB     00H              ; 00H-IC not found,01H- correct IC num entered

; kb table for keyboard input
TABLE_K         DB     0EEh,0EDH,0EBH,0E7H
                DB     0DEH,0DDH,0DBH,0D7H
                DB     0BEH,0BDH,0BBH,0B7H
                DB     07EH,07DH,07BH,077H

;Test values for checking correctness
in7408          DB      00H,55H,0AAH,0FFH   ; for and gate
out7408         DB      00H,00H,00H,0FH
in7432          DB      00H,55H,0AAH,0FFH   ; for or gate
out7432         DB      00H,0FH,0FH,0FH
in7486          DB      00H,55H,0AAH,0FFH   ; for xor gate
out7486         DB      00H,0FH,0FH,00H

;display table for LCD
TABLE_D         DW     0H,  01H, 2H,  3H
                DW     4H,  5H,  6H,  7H
                DW     8H,  9H,  0AH, 0BH
                DW     0CH, 0DH, 0EH, 0FH

IC7408          DB     "7408"
IC7432          DB     "7432"
IC7486          DB     "7486"
ICBAD           DB      " FAIL"
ICGOOD          DB      " PASS"

; First 8255
porta           equ     10h
portb           equ     12h
portc           equ     14h
creg1           equ     16h

; Second 8255
port2a          equ     20h
port2b          equ     22h
port2c          equ     24h
creg2           equ     26h

Keys            DB      "0123456789SRABCD" 	 ;keypad keys
ICNUM           DB      "XXXX"              	;stores user entered IC number 

.CODE
.STARTUP

mov         al,010001010B  ; portB and upper portC as input and portA and lower portC as output
out         creg2,al


call INITIAL   ;initialises LCD 

Start:
 mov Num,0
 mov Flag,00H
 call clear           ; clears display
 lea DI,inputname     ; 
 mov COUNT,9          ; no of characters to be printed
 call stringdisp      ; prints input message to LCD

ReadKey:
 mov COUNT,01H
 call KEYBRD        ; reads keypush. offset from kb table is stored in AX
 lea DI,Keys        ; list of keypad keys
 add DI,AX          ; 
 mov SI,Num
 mov AL,[DI]        ; moves pushed key to al
 cmp AL,"R"         ; reset go to start of program
 je Start
 cmp AL,"S"         ; if user has entered a character amd then presses backspace then call procedure
 jne  StoreKey
 cmp Num,00H   ; if no character is enetered, goes back to ReadKey
 je ReadKey
 call BACKSPACE
 dec Num
 jmp ReadKey

; AL contains the last key pressed
StoreKey:
 mov ICNUM[SI],AL      ; pressed key is stored. ICNUM[SI] = [SI + ICNUM]
 call stringdispNext   ; writes character in AL to LCD
 inc Num
 ; IC number has 4 characters
 cmp Num,04H
 jz WriteICName
 jmp ReadKey

; writes ic number entered by user onto LCD again after clearing it
WriteICName:
 lea DI,ICNUM
 mov COUNT,04H
 call stringdisp

; Now checking which IC is it, or if input is wrong

isIt7408:
 lea BX,IC7408
 call cmp_IC_NUM         ; checks if user has entered 4 numbers
 cmp Flag,01H
 jne isIt7486            ; if Flag then check if IC is good or bad
 call Check7408
 jmp S4

isIt7486:
 lea BX,IC7486
 call cmp_IC_NUM
 cmp Flag,01H
 jne isIt7432
 call Check7486
 jmp S4

isIt7432:
 lea BX,IC7432
 call cmp_IC_NUM
 cmp Flag,01H
 jne NO_IC
 call Check7432
 jmp S4

; invalid input
NO_IC:
 lea DI,inVALID
 mov COUNT,10           ; if no ic found then writes ICNUM "not found" on LCD
 call stringdispNext

S4:
 call KEYBRD
 lea DI,Keys
 add DI,AX              ; Take the key pressed and put it in AL
 mov AL,[DI]
 cmp AL,"R"             ; If reset is pressed go back to start
 je Start
 jmp S4

.EXIT


; generates delay of 0.25 secs
D20MS:
          mov cx,2220
          xn:
              loop          xn
ret


;generates delay of 20ms
DELAY PROC
    mov CX, 1325 ;1325*15.085 usec = 20 msec
    WasteTime:
                NOP
                NOP
                LOOP WasteTime
    RET
DELAY ENDP


; LCD initially displays "IC NUM -  " 
INITIAL PROC NEAR
 ; initializing LCD for 2 lines & 5*7 matrix
 mov AL, 38H
 call WriteCommand           ;write the command to LCD
 call DELAY                  ;delay before next command
 call DELAY
 call DELAY
 ; LCD ON, Show cursor
 mov AL, 0EH
 call WriteCommand
 call DELAY
 ; clear LCD
 mov AL, 01
 call WriteCommand
 call DELAY
 ; command for shifting cursor right
 mov AL, 06
 call WriteCommand
 call DELAY
 RET
INITIAL ENDP

; clear the display
clear PROC
 mov AL, 01
 call WriteCommand
 call DELAY
 call DELAY
 RET
clear ENDP



;read key pressed 
KEYBRD PROC NEAR
 pushf
 push BX
 push CX
 push DX   ; SAVinG THE REGISTERS USED
 mov         AL,0FFH
 out         port2c,AL
 ; Checking all keys are open
 X0: mov AL,00H
     out port2c,AL
 Open: in   AL, port2c
       and  AL,0F0H
       cmp  AL,0F0H
       jnz  Open                  ; Means the key is still pressed, go back to X1
       call D20MS                 ; debounce check
       mov  AL,00H
       out  port2c ,AL            ; provide column values as output through lower port C

  ; BL has 0 on col no. Al has 0 on row no.
 findRC:in  AL,  port2c
        and  AL,0F0H
        cmp  AL,0F0H
        jz   findRC
        call D20MS                 ;key debounce check
        mov  AL,00H
        out  port2c ,AL            ;provide column values as output through lower port C
        in   AL,  port2c
        and  AL,0F0H
        cmp  AL,0F0H
        jz   findRC                ;debounce check 

 ; Checking the first column
 mov  AL, 0EH          ;E = 1110
 mov  BL,AL
 out  port2c,AL
 in   AL, port2c
 and  AL,0F0H
 cmp  AL,0F0H
 jnz  RC
 ; Checking the second column
 mov  AL,0DH          ; D = 1101
 mov  BL,AL
 out  port2c ,AL
 in   AL, port2c
 and  AL,0F0H
 cmp  AL,0F0H
 jnz  RC
 ;Checking the third column
 mov  AL, 0BH          ; B = 1011
 mov  BL,AL
 out  port2c,AL
 in   AL, port2c
 and  AL,0F0H
 cmp  AL,0F0H
 jnz  RC
 ; Checking the fourth column
 mov  AL, 07H          ; 7 = 0111
 mov  BL,AL
 out  port2c,AL
 in   AL, port2c
 and  AL,0F0H
 cmp  AL,0F0H
 jz   findRC

    ; lower nibble of BL col no. upper nibble of AL row no.
    ; This converts into Row Column format to be checked from kb table and stores into Al.
 RC:or   AL,BL
    mov  CX,0FH
    mov  DI,00H

    ; compares preesed key with all keys in keyboard.
 FindKey:cmp  AL,TABLE_K[DI]
         jz   Over
         inc  DI
         LOOP FindKey

 Over:mov AX,DI      ; move the offset of key pressed to AX
      pop DX
      pop CX
      pop BX
      popf
      RET
KEYBRD   ENDP

; writes a string with starting add at DI having count characters to display
stringdisp PROC NEAR
 call clear
 LoopOver:
  mov AL, [DI]
  call WriteChar        ;issue it to LCD
  call DELAY          ; delay before next character
  call DELAY
  inc DI              ; move to next character
  dec COUNT
  jnz LoopOver
 RET
stringdisp ENDP


; writes command in AL to LCD
; sends the commands to port A which is connected to D0-D7 of LCD
; then enables pin from high to low with RS=0 for selecting command register and R/W = 0 for write operation.
WriteCommand PROC
 mov DX, PORTA
 out DX, AL          ; AL contains the command
 mov DX, PORTB
 ; Enable High
 mov AL, 00000100B
 out DX, AL
 ; A small pause
 NOP
 NOP
 ; Enable Low
 mov AL, 00000000B
 out DX, AL
 RET
WriteCommand ENDP



; stringdisp without CLS. 
stringdispNext PROC NEAR
 LoopOver2:
  mov AL, [DI]
  call WriteChar        ;issue it to LCD
  call DELAY          ; delay before next character
  call DELAY
  inc DI              ; move to next character
  dec COUNT
  jnz LoopOver2
  RET
stringdispNext ENDP


BACKSPACE PROC NEAR
  push DX
  push AX
  mov AL,00010000B    ; shifts cursor to one space left
  call WriteCommand
  call DELAY          ; wait before next command
  call DELAY
  mov AL,' '
  call WriteChar      ; overwrite " "
  call DELAY
  call DELAY          ; wait before issuing next command
  mov AL,00010000B    ; shifting cursor to left
  call WriteCommand
  pop AX              ;retrive registers
  pop DX
  RET
BACKSPACE ENDP



; Write single character in AL to LCD
; R/W = 0 because we are writing. RS is 1 because data register is to be selected.
WriteChar PROC
 push DX
 mov DX,PORTA            ; DX=port A address
 out DX, AL              ; issue the char to LCD
 mov AL, 00000101B
 mov DX, PORTB           ;port B address
 out DX, AL
 mov AL, 00000001B
 out DX, AL
 pop DX
 RET
WriteChar ENDP



; Compares BX and ICNUM for equality
cmp_IC_NUM PROC NEAR
 mov SI,0000H
 cmp_NUM:
  mov AL,ICNUM[SI]
  cmp AL,[BX+SI]
  je NXT_NUM
  jmp EP_cmp_IC
  NXT_NUM:
   cmp SI,03H
   je PASS_cmp_IC   ; If all chars equal set Flag to 1 before return
   inc SI
   jmp cmp_NUM
 PASS_cmp_IC:
  mov Flag,01H
  EP_cmp_IC:
 RET
cmp_IC_NUM ENDP



Check7408 PROC NEAR  ;checks if 7408 is good or bad[pass or fail]
 mov DI,00H
 Testing7408:
  mov AL,in7408[DI]
  out port2a,AL       ; input for the 7408 IC
  in AL,port2b        ; output value of 7408 goes to AL
  and AL,0FH          ; Masking. Only lower nibble needed.
  cmp AL,out7408[DI]  ; Verify by comparing with expected output.
  je Next7408
  call FAIL
  jmp Ret7408
 Next7408:
  cmp DI,03H           ; All four chars are same
  je Pass7408         ; Means Pass.
  inc DI               ; If all chars are not read yet, proceed to next char
  jmp Testing7408
 Pass7408:
  call PASS
  Ret7408:
 RET
Check7408 ENDP


Check7432 PROC NEAR  ;checks if 7432 is good or bad[pass or fail]
 mov DI,00H
 Testing7432:
  mov AL,in7432[DI]
  out port2a,AL       ; input for the 7432 IC
  in AL,port2b        ; output value of 7432 goes to AL
  and AL,0FH          ; Masking. Only lower nibble needed.
  cmp AL,out7432[DI]  ; Verify by comparing with expected output.
  je Next7432
  call FAIL
  jmp Ret7432
 Next7432:
  cmp DI,03H           ; All four chars are same
  je Pass7432         ; Means Pass.
  inc DI               ; If all chars are not read yet, proceed to next char
  jmp Testing7432
 Pass7432:
  call PASS
 Ret7432:
  RET
Check7432 ENDP


Check7486 PROC NEAR  ;checks if 7486 is good or bad[pass or fail]
 mov DI,00H
 Testing7486:
  mov AL,in7486[DI]
  out port2a,AL       ; input for the 7486 IC
  in AL,port2b        ; output value of 7486 goes to AL
  and AL,0FH          ; Masking. Only lower nibble needed.
  cmp AL,out7486[DI]  ; Verify by comparing with expected output.
  je Next7486
  call FAIL
  jmp Ret7486
 Next7486:
  cmp DI,03H           ; All four chars are same
  je Pass7486         ; Means Pass.
  inc DI               ; If all chars are not read yet, proceed to next char
  jmp Testing7486
 Pass7486:
  call PASS
 Ret7486:
  RET
Check7486 ENDP


; When IC check fails
FAIL PROC NEAR
 pushf
 push DI
 mov COUNT,05
 lea DI,ICBAD     ; ' FAIL'
 call stringdispNext    ; Writes next to the IC number
 pop DI
 popf
 RET
FAIL ENDP


; When the IC passes the test
PASS PROC NEAR
 pushf
 push DI
 mov COUNT,05        ; Number of letters
 lea DI,ICGOOD       ; ' PASS'
 call stringdispNext   ; Writes next to the IC number
 pop DI
 popf
 RET
PASS ENDP


END

