INCLUDE ..\libs\Irvine32.inc
INCLUDE ..\libs\win32.inc

COLS = 80
ROWS = 25

LCOLS = 48
LROWS = 4

INSCOLS = 39
INSROWS = 8

GOCOLS = 55
GOROWS = 4

GetMatrixAddr PROTO mAddr:DWORD, mCols: DWORD, iRows: DWORD, iCols:DWORD, sType:BYTE

.data
	; Screen Buffer Data
	outHandle HANDLE 0
	scrBuffer CHAR_INFO COLS*ROWS DUP (<<0>, 0Fh>)
	scrSize COORD <COLS, ROWS>
	scrCoord COORD <0, 0>
	scrRect SMALL_RECT <0, 0, COLS-1, ROWS-1>
	
	; Menu Data
	cursorPos BYTE 0								; Relative menu cursor position
	
	; Game Data
	timeDifUp DWORD ?								; Time when game difficulty was last updated
	gameState BYTE 0								; Game stat: 0 = start, 1 = playing, 2 = end, 3 = instructions
	currScore DWORD 0								; Current player's score
	
	; Ship Data
	shipY BYTE 1
	
	; Enemies Data
	enemiesMatrix BYTE COLS*22 DUP (0)				; Enemy matrix
	enemyCycle BYTE 1								; Defines how much normal cycles need to pass, to update enemies
	enemyUpCtr BYTE 0								; Enemy iteration counter
	enemyGenCtr BYTE 0								; Enemy generation counter
	
	; Bullets Data
	bulletsMatrix BYTE COLS*22 DUP(0)					; Bullets array - Index determines X position, and the value determines Y position; if Y is -1, bullet doesn't exist
	bulletSCtr BYTE 0
	bulletMCtr BYTE 0
	bulletLCtr BYTE 0
	
	; Ship Literals
	shipThruster db '<|=>'
	shipMain 	 db '<|==|)'
	
	; Bullets Literals
	bulletsChar  db '-O='
	
	; Label Literals
	logo 	 db ' ___  ____   __    ___  ____    __    ___  ____ ',
				'/ __)(  _ \ /__\  / __)( ___)  /__\  / __)( ___)',
				'\__ \ )___//(__)\( (__  )__)  /(__)\( (__  )__) ',
				'(___/(__) (__)(__)\___)(____)(__)(__)\___)(____)'
			
	gameOver db '  ___    __    __  __  ____    _____  _  _  ____  ____ ',
				' / __)  /__\  (  \/  )( ___)  (  _  )( \/ )( ___)(  _ \',
				'( (_-. /(__)\  )    (  )__)    )(_)(  \  /  )__)  )   /',
				' \___/(__)(__)(_/\/\_)(____)  (_____)  \/  (____)(_)\_)'

	; Menu Literals
	startTxt db 'START'
	instrTxt db 'INSTRUCTIONS'
	quitTxt  db 'QUIT'
	mainTxt  db 'MAIN MENU'
	playTxt  db 'PLAY AGAIN'
	
	; Top Bar Literals
	bulletsTxt db 'AMMO:'
	scoreTxt   db 'SCORE:'
	
	; Final Score Text
	finalScoreTxt db 'YOUR FINAL SCORE WAS: '
	
	; Instructions Text
	instructions db 'WELCOME TO SPACEACE!                   ',
					'SHOOT THE GREEN ALIEN SHIPS TO SCORE!  ',
					'CONTROLS:                              ',
					'J: BULLETS - LOW DMG                   ',
					'K: BOMBS   - MEDIUM DMG                ',
					'L: LASERS  - HIGH DMG                  ',
					'W: MOVE THE SHIP UP                    ',
					'S: MOVE THE SHIP DOWN                  '				
.code

main PROC
	Invoke GetStdHandle, STD_OUTPUT_HANDLE
	mov outHandle, eax
	
	call Randomize
	
	call GetMSeconds
	mov timeDifUp, eax
	
gameLoop:
	call UpdateEntities

	call PrintScreen
		
	mov eax, 50
	call Delay		; wait 50 ms

	jmp gameLoop
	
	ret
main ENDP


;===================================================
; Procedimento que facilita o acesso à elementos de
; uma matriz com elementos do tipo byte
;
; Recebe: 	mAddr - Endereço da matriz
;			mCols - Total de colunas da matrix
;			iRows - Índice da linha a ser acessada
;			iCols - Índice da coluna a ser acessada
;			sType - Tamanho do tipo de dado
; Retorna:	eax - Endereço da posição desejada 
;===================================================
GetMatrixAddr PROC uses edx,
	mAddr: DWORD, mCols:DWORD, iRows:DWORD, iCols:DWORD, sType:BYTE
	
	mov eax, mCols
	mov edx, iRows
	mul edx						; eax = mCols * iRows
	
	add eax, iCols				; eax = (mCols * iRows) + iCols
	
	movzx edx, sType
	mul edx						; eax = ((mCols * iRows) + iCols) * sType
	
	add eax, mAddr				; eax = (mAddr + (mCols * iRows) + iCols) * sType = &mAddr[iRows][iCols]

	ret
GetMatrixAddr ENDP


;======================================================
;
PrintScreen PROC
;======================================================
	cmp gameState, 1
	je state1
	cmp gameState, 2
	je state2
	cmp gameState, 3
	je state3
	call ResetStartScreen
	jmp writeCons
state1:
	call ResetGameScreen
	call UpdateGameScreen
	jmp writeCons
state2:
	call ResetEndScreen
	jmp writeCons
state3:
	call ResetInsScreen
writeCons:
	Invoke WriteConsoleOutput, outHandle, ADDR scrBuffer, scrSize, scrCoord, ADDR scrRect
	call UpdateScore

	ret
PrintScreen ENDP


;======================================================
;
UpdateEntities PROC
;======================================================
	cmp gameState, 1
	je state1
	
	call ReadMenuInput
	
	jmp quit
state1:
	call UpdateEnemies
	call CheckCollisions
	call UpdateBullets
	call CheckCollisions
	call CheckTime
	call ReadGameInput
	
	jmp quit

quit:
	ret
UpdateEntities ENDP


;======================================================
;
ResetGameVariables PROC
;======================================================
	mov shipY, 1
	
	call GetMSeconds
	mov timeDifUp, eax
	
	mov enemyCycle, 3
	mov enemyUpCtr, 0
	mov enemyGenCtr, 0
	
	xor ecx, ecx
matrixReset:
	mov enemiesMatrix[ecx], 0
	mov bulletsMatrix[ecx], 0
	
	inc ecx
	cmp ecx, COLS*22
	jne matrixReset
	
	ret
ResetGameVariables ENDP


;======================================================
;
ResetStartScreen PROC uses eax ebx ecx edx esi edi
;======================================================
; Resets background to empty black
	xor ecx, ecx
blackBack:
	mov scrBuffer[ecx * CHAR_INFO].Char, 0
	mov scrBuffer[ecx * CHAR_INFO].Attributes, 0Fh
	
	inc ecx
	
	cmp ecx, LENGTHOF scrBuffer
	jne blackBack

; Renders logo on screen buffer
	xor ecx, ecx
	xor edx, edx
logoCol:
	Invoke GetMatrixAddr, ADDR logo, LCOLS, edx, ecx, TYPE logo				; returns logo[edx][ecx] pointer
	mov esi, eax
	push ecx
	push edx
	add ecx, 16
	add edx, 4
	Invoke GetMatrixAddr, ADDR scrBuffer, COLS, edx, ecx, TYPE scrBuffer	; returns scrBuffer[edx][ecx] pointer
	mov edi, eax
	pop edx
	pop ecx

	movzx ax, (BYTE PTR [esi])
	mov (CHAR_INFO PTR [edi]).Char, ax
	
	inc ecx
	cmp ecx, LCOLS
	jne logoCol
	
	mov ecx, 0
	inc edx
	cmp edx, LROWS
	jne logoCol
	
; Renders options menu
; Start label
	xor ecx, ecx
startCopy:
	push ecx
	movzx ax, startTxt[ecx]
	add ecx, COLS*20+10
	mov scrBuffer[ecx * CHAR_INFO].Char, ax
	pop ecx
	
	inc ecx
	cmp ecx, LENGTHOF startTxt
	jne startCopy

; Instructions label
	xor ecx, ecx
instrCopy:
	push ecx
	movzx ax, instrTxt[ecx]
	add ecx, COLS*21+10
	mov scrBuffer[ecx * CHAR_INFO].Char, ax
	pop ecx
	
	inc ecx
	cmp ecx, LENGTHOF instrTxt
	jne instrCopy
	
; Quit label
	xor ecx, ecx
quitCopy:
	push ecx
	movzx ax, quitTxt[ecx]
	add ecx, COLS*22+10
	mov scrBuffer[ecx * CHAR_INFO].Char, ax
	pop ecx
	
	inc ecx
	cmp ecx, LENGTHOF quitTxt
	jne quitCopy
	
; Cursor selector
	movzx eax, cursorPos
	add eax, 20
	Invoke GetMatrixAddr, ADDR scrBuffer, COLS, eax, 9, TYPE scrBuffer		; returns scrBuffer[eax][9] pointer
	
	mov (CHAR_INFO PTR[eax]).Char, '>'
	
	ret
ResetStartScreen ENDP


;======================================================
;
ResetGameScreen PROC uses ecx
;======================================================
	xor ecx, ecx
	
topMenu:												; top menu has black background and white chars
	mov scrBuffer[ecx * CHAR_INFO].Char, 0
	mov scrBuffer[ecx * CHAR_INFO].Attributes, 0Fh
	
	inc ecx

	cmp ecx, COLS										; for(ecx=0; ecx<COLS; ecx++) { set_screen_buffer(ecx, black, white) }
	jne topMenu
	
mainSpace:												; main space has white background and black chars
	mov scrBuffer[ecx * CHAR_INFO].Char, 0
	mov scrBuffer[ecx * CHAR_INFO].Attributes, 0Fh
	
	inc ecx
	
	cmp ecx, COLS*ROWS									; for(ecx=COLS; ecx<COLS*ROWS; ecx++) { set_screen_buffer(ecx, white, black) }
	jne mainSpace

; Render game text
; Ammunition label
	xor ecx, ecx
bulletsCopy:
	push ecx
	movzx ax, bulletsTxt[ecx]
	add ecx, 1
	mov scrBuffer[ecx * CHAR_INFO].Char, ax
	pop ecx
	
	inc ecx
	cmp ecx, LENGTHOF bulletsTxt
	jne bulletsCopy

; Score label
	xor ecx,ecx
scoreCopy:
	push ecx
	movzx ax, scoreTxt[ecx]
	add ecx, 30
	mov scrBuffer[ecx * CHAR_INFO].Char, ax
	pop ecx
	
	inc ecx
	cmp ecx, LENGTHOF scoreTxt
	jne scoreCopy
	
	ret
ResetGameScreen ENDP

;======================================================
;
ResetInsScreen PROC uses eax ebx ecx edx esi edi
;======================================================
; Resets background to empty black
	xor ecx, ecx
blackBack:
	mov scrBuffer[ecx * CHAR_INFO].Char, 0
	mov scrBuffer[ecx * CHAR_INFO].Attributes, 0Fh
	
	inc ecx
	
	cmp ecx, LENGTHOF scrBuffer
	jne blackBack

; Renders instructions text on screen buffer
	xor ecx, ecx
	xor edx, edx
instrCol:
	Invoke GetMatrixAddr, ADDR instructions, INSCOLS, edx, ecx, TYPE instructions 	; returns logo[edx][ecx] pointer
	mov esi, eax
	push ecx
	push edx
	add ecx, 22
	add edx, 7
	Invoke GetMatrixAddr, ADDR scrBuffer, COLS, edx, ecx, TYPE scrBuffer			; returns scrBuffer[edx][ecx] pointer
	mov edi, eax
	pop edx
	pop ecx

	movzx ax, (BYTE PTR [esi])
	mov (CHAR_INFO PTR [edi]).Char, ax
	
	inc ecx
	cmp ecx, INSCOLS
	jne instrCol
	
	mov ecx, 0
	inc edx
	cmp edx, INSROWS
	jne instrCol
	
; Renders options menu
; Start label
	xor ecx, ecx
startCopy:
	push ecx
	movzx ax, startTxt[ecx]
	add ecx, COLS*20+10
	mov scrBuffer[ecx * CHAR_INFO].Char, ax
	pop ecx
	
	inc ecx
	cmp ecx, LENGTHOF startTxt
	jne startCopy
	
; Main Menu label
	xor ecx, ecx
mainCopy:
	push ecx
	movzx ax, mainTxt[ecx]
	add ecx, COLS*21+10
	mov scrBuffer[ecx * CHAR_INFO].Char, ax
	pop ecx
	
	inc ecx
	cmp ecx, LENGTHOF mainTxt
	jne mainCopy
	
; Quit label
	xor ecx, ecx
quitCopy:
	push ecx
	movzx ax, quitTxt[ecx]
	add ecx, COLS*22+10
	mov scrBuffer[ecx * CHAR_INFO].Char, ax
	pop ecx
	
	inc ecx
	cmp ecx, LENGTHOF quitTxt
	jne quitCopy

; Cursor selector
	movzx eax, cursorPos
	add eax, 20
	Invoke GetMatrixAddr, ADDR scrBuffer, COLS, eax, 9, TYPE scrBuffer		; returns scrBuffer[eax][9] pointer
	
	mov (CHAR_INFO PTR[eax]).Char, '>'
	
	ret
ResetInsScreen ENDP

;======================================================
;
UpdateGameScreen PROC uses eax ebx ecx edx
;======================================================
	xor ebx, ebx
	xor ecx, ecx
	xor edx, edx

; Update upper screen
	mov scrBuffer[10 * CHAR_INFO].Char, 'J'
	mov scrBuffer[15 * CHAR_INFO].Char, 'K'
	mov scrBuffer[20 * CHAR_INFO].Char, 'L'
	
	cmp bulletSCtr, 0
	jne sRed
	
	mov scrBuffer[10 * CHAR_INFO].Attributes, 0Ah	
	jmp sOut
sRed:
	mov scrBuffer[10 * CHAR_INFO].Attributes, 0Ch
sOut:
	cmp bulletMCtr, 0
	jne mRed
	
	mov scrBuffer[15 * CHAR_INFO].Attributes, 0Ah	
	jmp mOut
mRed:
	mov scrBuffer[15 * CHAR_INFO].Attributes, 0Ch
mOut:
	cmp bulletLCtr, 0
	jne lRed
	
	mov scrBuffer[20 * CHAR_INFO].Attributes, 0Ah	
	jmp lOut
lRed:
	mov scrBuffer[20 * CHAR_INFO].Attributes, 0Ch
lOut:

	mov eax, COLS
	mov bl, shipY
	mul ebx			; eax = COLS * shipY

	mov ebx, eax
topShip:
	mov dl, shipThruster[ecx]
	mov scrBuffer[ebx * CHAR_INFO].Char, dx
	mov scrBuffer[ebx * CHAR_INFO].Attributes, 1Ah
	
	inc ebx
	inc ecx
	cmp ecx, LENGTHOF shipThruster
	jne topShip
	
	add eax, COLS
	mov ebx, eax
	xor ecx, ecx
midShip:
	mov dl, shipMain[ecx]
	mov scrBuffer[ebx * CHAR_INFO].Char, dx
	mov scrBuffer[ebx * CHAR_INFO].Attributes, 1Ah 

	inc ebx
	inc ecx
	cmp ecx, LENGTHOF shipMain
	jne midShip
	
	add eax, COLS
	mov ebx, eax
	xor ecx, ecx
botShip:
	mov dl, shipThruster[ecx]
	mov scrBuffer[ebx * CHAR_INFO].Char, dx
	mov scrBuffer[ebx * CHAR_INFO].Attributes, 1Ah
	
	inc ebx
	inc ecx
	cmp ecx, LENGTHOF shipThruster
	jne botShip
	
; Enemies
	mov ecx, 0
updateEnemy:
	cmp enemiesMatrix[ecx], 0
	je nextEnemy
	
	add ecx, COLS*2
	mov scrBuffer[ecx*CHAR_INFO].Char, 'X'
	mov scrBuffer[ecx*CHAR_INFO].Attributes, 0ACh
	sub ecx, COLS*2
	
nextEnemy:
	inc ecx
	cmp ecx, LENGTHOF enemiesMatrix
	jne updateEnemy
	
; Bullets
	xor eax, eax
	xor ecx, ecx
bulletsPrint:
	mov al, bulletsMatrix[ecx]
	cmp al, 0
	je nextBullets
	
	add ecx, COLS*2
	
	dec al
	movzx ax, bulletsChar[eax]							; Load the correct char from bulletsChar literal
	mov scrBuffer[ecx*CHAR_INFO].Char, ax
	mov scrBuffer[ecx*CHAR_INFO].Attributes, 0Ch
	
	sub ecx, COLS*2
	
nextBullets:
	inc ecx
	cmp ecx, LENGTHOF bulletsMatrix
	jne bulletsPrint
	
	ret
UpdateGameScreen ENDP

;======================================================
;
UpdateScore PROC
;======================================================
; Updates the score and prints it to console
	xor edx, edx	

gameScore:
	cmp gameState, 1
	jne finalScore
	
	mov dl, 35
	mov bl, LENGTHOF scoreTxt
	add dl, bl
	mov dh, 0
	call gotoXY
	mov eax, currScore
	call writeDEC

finalScore:
	cmp gameState, 2
	jne noScore
	
	mov dl, 30
	mov bl, LENGTHOF finalScoreTxt
	add dl, bl
	mov dh, 14
	call gotoXY
	mov eax, currScore
	call writeDEC

noScore:
	ret
UpdateScore ENDP


;======================================================
;
ResetEndScreen PROC
;======================================================
; Resets background to empty black
	xor ecx, ecx
blackBack:
	mov scrBuffer[ecx * CHAR_INFO].Char, 0
	mov scrBuffer[ecx * CHAR_INFO].Attributes, 0Fh
	
	inc ecx
	
	cmp ecx, LENGTHOF scrBuffer
	jne blackBack

; Renders logo on screen buffer
	xor ecx, ecx
	xor edx, edx
gameOverCol:
	Invoke GetMatrixAddr, ADDR gameOver, GOCOLS, edx, ecx, TYPE logo		; returns gameover[edx][ecx] pointer
	mov esi, eax
	push ecx
	push edx
	add ecx, 13
	add edx, 4
	Invoke GetMatrixAddr, ADDR scrBuffer, COLS, edx, ecx, TYPE scrBuffer	; returns scrBuffer[edx][ecx] pointer
	mov edi, eax
	pop edx
	pop ecx

	movzx ax, (BYTE PTR [esi])
	mov (CHAR_INFO PTR [edi]).Char, ax
	
	inc ecx
	cmp ecx, GOCOLS
	jne gameOverCol
	
	mov ecx, 0
	inc edx
	cmp edx, GOROWS
	jne gameOverCol

; Renders final score text
	xor ecx,ecx
scoreCopy:
	push ecx
	movzx ax, finalScoreTxt[ecx]
	add ecx, COLS*14+25
	mov scrBuffer[ecx * CHAR_INFO].Char, ax
	pop ecx
	
	inc ecx
	cmp ecx, LENGTHOF finalScoreTxt
	jne scoreCopy

; Renders options menu
; Play Again label
	xor ecx, ecx
playCopy:
	push ecx
	movzx ax, playTxt[ecx]
	add ecx, COLS*20+10
	mov scrBuffer[ecx * CHAR_INFO].Char, ax
	pop ecx
	
	inc ecx
	cmp ecx, LENGTHOF playTxt
	jne playCopy

; Main Menu label
	xor ecx, ecx
mainCopy:
	push ecx
	movzx ax, mainTxt[ecx]
	add ecx, COLS*21+10
	mov scrBuffer[ecx * CHAR_INFO].Char, ax
	pop ecx
	
	inc ecx
	cmp ecx, LENGTHOF mainTxt
	jne mainCopy
	
; Quit label
	xor ecx, ecx
quitCopy:
	push ecx
	movzx ax, quitTxt[ecx]
	add ecx, COLS*22+10
	mov scrBuffer[ecx * CHAR_INFO].Char, ax
	pop ecx
	
	inc ecx
	cmp ecx, LENGTHOF quitTxt
	jne quitCopy
	
; Cursor selector
	movzx eax, cursorPos
	add eax, 20
	Invoke GetMatrixAddr, ADDR scrBuffer, COLS, eax, 9, TYPE scrBuffer		; returns scrBuffer[eax][9] pointer
	
	mov (CHAR_INFO PTR[eax]).Char, '>'
	
	ret
ResetEndScreen ENDP


;======================================================
;
UpdateEnemies PROC uses eax ecx edx
;======================================================
	mov al, enemyCycle
	cmp enemyUpCtr, al
	jne elseUpdate
	
	mov ecx, 0
rowLoop:
	mov al, enemiesMatrix[ecx+1]
	mov enemiesMatrix[ecx], al
	inc ecx
	mov eax, ecx
	mov ebx, COLS
	xor edx, edx
	div ebx							; eax = ecx mod COLS
	cmp edx, COLS-1
	jne rowLoop

	mov enemiesMatrix[ecx], 0
	inc ecx
	
	cmp ecx, LENGTHOF enemiesMatrix
	jne rowLoop
	
	cmp enemyGenCtr, 2
	jne elseGenerate
	
	mov eax, 21
	call RandomRange
	add eax, 2						; eax = random.range(2, 23)
	mov ebx, COLS
	mul ebx
	add eax, COLS-1
	mov enemiesMatrix[eax], 3
	
	mov enemyGenCtr, 0
	jmp endGenerate
elseGenerate:
	inc enemyGenCtr					; enemyGenCtr++

endGenerate:
	
	mov enemyUpCtr, 0				; resets enemy update counter
	jmp endUpdate
elseUpdate:
	inc enemyUpCtr					; enemyUpCtr++

endUpdate:
	
	ret
UpdateEnemies ENDP


;======================================================
;
UpdateBullets PROC
;======================================================
	mov ecx, LENGTHOF bulletsMatrix - 1
rowLoop:
	mov al, bulletsMatrix[ecx-1]
	mov bulletsMatrix[ecx], al
	dec ecx
	mov eax, ecx
	mov ebx, COLS
	xor edx, edx
	div ebx							; eax = ecx mod COLS
	cmp edx, 0
	jne rowLoop

	mov bulletsMatrix[ecx], 0
	dec ecx
	
	cmp ecx, -1
	jne rowLoop
	
	cmp bulletSCtr, 0
	je bulletM
	
	dec bulletSCtr
bulletM:
	cmp bulletMCtr, 0
	je bulletL
	
	dec bulletMCtr
bulletL:
	cmp bulletLCtr, 0
	je bulletOut

	dec bulletLCtr
bulletOut:

	ret
UpdateBullets ENDP


;======================================================
;
CheckCollisions PROC
;======================================================
; "Enemy-Bullet" Collisions
	mov ecx, 0
tileLoop:
	cmp enemiesMatrix[ecx], 0
	je nextTile
	cmp bulletsMatrix[ecx], 0
	je nextTile
	
	
	mov al, enemiesMatrix[ecx]
	cmp al, bulletsMatrix[ecx]
	jbe instaKill
	sub al, bulletsMatrix[ecx]
	jmp finish
instaKill:
	mov al, 0
	inc currScore
finish:	
	mov enemiesMatrix[ecx], al
	mov bulletsMatrix[ecx], 0
	
nextTile:
	inc ecx
	cmp ecx, LENGTHOF enemiesMatrix
	jne tileLoop

; "Enemy-Left Side" Collision
	mov ecx, LENGTHOF shipMain - 1
rowLoop:
	cmp enemiesMatrix[ecx], 0
	je nextRow
	
	mov gameState, 2
	
nextRow:
	add ecx, COLS
	cmp ecx, LENGTHOF enemiesMatrix
	jb rowLoop
	
	ret
CheckCollisions ENDP

;======================================================
;
CheckTime PROC uses eax edx
;======================================================
	cmp enemyCycle, 1
	jbe notUp					; if(enemyCycle <= 1) { already on hard, do nothing }
	call GetMSeconds
	sub eax, timeDifUp
	cmp eax, 90000				; 90000 ms = 90s = 1:30 min
	jb notUp					; if (eax >= 90000) { reset timeDifUp; up the difficulty; }
	
	dec enemyCycle
	call GetMSeconds
	mov timeDifUp, eax

notUp:
	
	ret
CheckTime ENDP


;======================================================
;
ReadMenuInput PROC uses eax
;======================================================
	mov eax, 50
	call Delay			; wait 50ms
	
	call ReadKey
	
	cmp dx, 'W'		; up arrow
	je cursorUp
	cmp dx, 'S' 	; down arrow
	je cursorDown
	cmp dx, VK_RETURN	; return key
	je optionCh
	jmp inputEnd
	
cursorUp:
	mov al, cursorPos
	dec al
	
	cmp al, 0
	jl inputEnd
	
	mov cursorPos, al

	jmp inputEnd
cursorDown:
	mov al, cursorPos
	inc al
	
	cmp al, 2
	jg inputEnd
	
	mov cursorPos, al

	jmp inputEnd
	
optionCh:
	cmp cursorPos, 2
	je quitOp
	cmp cursorPos, 1
	je insMainOp

	mov cursorPos, 0
	mov gameState, 1
	call ResetGameVariables
	
	jmp outOp
insMainOp:
	mov cursorPos, 0
	
	cmp gameState, 0
	je insOp

mainOp:
	mov gameState, 0
	jmp outOp

insOp:
	mov gameState, 3
	jmp outOp

quitOp:
	exit
	
outOp:
	jmp inputEnd
	
inputEnd:
	ret
ReadMenuInput ENDP


;======================================================
;
ReadGameInput PROC uses eax edx
;======================================================
	mov eax, 50
	call Delay		; wait 50ms
	
	call ReadKey
	
	cmp dx, 'W'	; up arrow
	je shipUp
	cmp dx, 'S'	; down arrow
	je shipDown
	cmp dx, 'J'		; j key
	je shootSmall
	cmp dx, 'K'		; k key
	je shootMedium
	cmp dx, 'L'		; l key
	je shootLarge
	jmp inputEnd
	
shipUp:
	mov al, [shipY]
	dec al
	
	cmp al, 1
	jb inputEnd		; if (shipY-1 < 1) { shipY-- }
	
	mov shipY, al
	
	jmp inputEnd
shipDown:
	mov al, [shipY]
	inc al
	
	cmp al, 22		; if (shipY+1 > 22) { shipY++ }
	ja inputEnd
	
	mov shipY, al
	
	jmp inputEnd
shootSmall:
	cmp bulletSCtr, 0
	ja inputEnd

	movzx eax, shipY
	inc eax
	
	mov edx, COLS
	mul edx
	add eax, LENGTHOF shipMain
	sub eax, COLS*2

	mov bulletsMatrix[eax], 1
	mov bulletSCtr, 2
	
	jmp inputEnd
shootMedium:
	cmp bulletMCtr, 0
	ja inputEnd

	movzx eax, shipY
	inc eax
	
	mov edx, COLS
	mul edx
	add eax, LENGTHOF shipMain
	sub eax, COLS*2
	
	mov bulletsMatrix[eax], 2
	mov bulletMCtr, 7
	
	jmp inputEnd
shootLarge:
	cmp bulletLCtr, 0
	ja inputEnd

	movzx eax, shipY
	inc eax
	
	mov edx, COLS
	mul edx
	add eax, LENGTHOF shipMain
	sub eax, COLS*2
	
	mov bulletsMatrix[eax], 3
	mov bulletLCtr, 15
	
	jmp inputEnd
inputEnd:

	ret
ReadGameInput ENDP

END main