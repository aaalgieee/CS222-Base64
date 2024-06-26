; NASM x86 asm

SECTION .data
inv_args db 'Invalid Parameters. Try ./base64 --help', 0Ah, 0h
inv_args_len dd 40
help_args db '-e to encode', 0Ah , '-d to decode' , 0Ah, '-t <text> to operate on text', 0Ah, 0h
help_args_len dd 92
help_param db '--help', 0h
help_param_len dd 7
encod_param db '-e',0h
param_len dd 3
decod_param db '-d', 0h
text_param db '-t', 0h
file_param db '-f', 0h
b64_chars db 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/', 0h
mem_start dd 0h
file_desc dd 0h

SECTION .text

global start

start:
	mov ebp, esp
	cmp dword [ebp], 4		; checking the number of arguements passed to the application
	je args_correct
	cmp dword [ebp], 2
	je help_func

invalid:				; executed if invalid arguements are passed to the application
	push dword [inv_args_len]	; length of data to print
	push inv_args			; base address of string to print
	call print
	add esp, 8
	call exit

print:
	mov edx, dword [esp + 8]	; implementation of print function which uses write syscall (eax = 4)
	mov ecx, dword [esp + 4]	; function accepts two params, 1st is the base address of string to be printed
	mov ebx, 1			; and 2nd param is the length of the string
	mov eax, 4			; save values in registers before calling this if those values are needed
	int 80h         ; write syscall
	ret

exit:
	mov ebx, 0
	mov eax, 1
	int 80h		; exit syscall
	ret

; stringcmp related labels begin here
stringcmp:
	push ebp			; strcmp like implementation in asm
	mov ebp, esp			; function accepts three arguements
	mov edi, ebp			; first is the address of string and 2nd is the length of this string
	add edi, 12			; third is the address of the string to be compared
	mov eax, dword [ebp + 16]
	mov ebx, dword [ebp + 8]		; If strings are equal eax contains 0 and 1 if they aren't
	xor ecx, ecx
	xor edx, edx

stringcmp_loop:
	mov cl, byte [eax]
	mov dl, byte [ebx]
	dec dword [edi]
	inc eax
	inc ebx
	cmp cl, dl
	jne string_not_eq
	cmp dword [edi], 0
	je string_eq
	jmp stringcmp_loop

string_eq:
	mov eax, 0
	pop ebp
	ret

string_not_eq:
	mov eax, 1
	pop ebp
	ret

; stringcmp related labels end here

; stringlen related labels begin here
stringlen:
	mov ebx, [esp + 4]	; implementation like strlen function

stringlen_loop:
	cmp byte [ebx], 0	; traverses through the string byte 0 is encountered and subtracts the base from that address
	je len_found		; the returned length is in eax register
	inc ebx
	jmp stringlen_loop

len_found:
	sub ebx, [esp + 4]
	mov eax, ebx
	ret

; stringlen related labels end here


find_c_in_s:
	push ebp
	mov ebp, esp
	push ebx
	push ecx
	push edx
	xor eax, eax
	mov ebx, dword [ebp + 8]
	mov ecx, dword [ebp + 12]
find_c_in_s_loop:
	cmp byte [ebx], cl
	je found_pos
	inc eax
	cmp eax, 65
	je find_not_found
	inc ebx
	jmp find_c_in_s_loop
find_not_found:
	xor eax, eax
found_pos:
	pop edx
	pop ecx
	pop ebx
	leave
	ret


allocate_mem:			; Need to improve this to allocate multiple buffers otherwise can't operate on files as it requires 2 buffers
	xor ebx, ebx
	mov eax, 45 		; syscall number for sys_brk
	int 0x80		; first syscall gets the address of break point
	mov [mem_start], eax
	mov ebx, [mem_start]
	add ebx, [esp + 4]
	mov eax, 45
	int 0x80		; second allocates the required amount memory after the first break point
	ret

args_correct:
	push encod_param		; base address of first string
	push dword [param_len]		; length of first string
	push dword [ebp + 8]			; base address of 2nd string to be compared
	call stringcmp
	add esp, 12			; pop args from stack
	cmp eax, 0			; checking wheather to encode here
	je enc_routine
	push decod_param
	push dword [param_len]
	push dword [ebp + 8]
	call stringcmp
	add esp, 12
	cmp eax, 0			; checking here to see if to decode
	je dec_routine
	jmp invalid

enc_routine:
	push text_param
	push dword [param_len]
	push dword [ebp + 12]
	call stringcmp
	add esp, 12
	cmp eax, 0			; checking if text param is provided
	je enc_text
	jmp invalid

enc_text:			; encoding routine if text is provided
	push dword [ebp + 16]			; base address of string
	call stringlen
	pop ecx
	push dword [ebp + 16]
	push eax
	call encode_b64
	add esp, 12
	push ebx
	push eax
	call print
	add esp, 8
	call exit
	ret

dec_routine:
        push text_param
        push dword [param_len]
        push dword [ebp + 12]
        call stringcmp
        add esp, 12
	cmp eax, 0
	je dec_text
	jmp invalid

dec_text:
        push dword [ebp + 16]                   ; base address of string
        call stringlen
        pop ecx
	push dword [ebp + 16]
	push eax
	call decode_b64
	add esp, 8
	push ebx
	push eax
	call print
	call exit
	ret


; base64 encoding algorithm
; result buffer is returned in eax
; length of result buffer is in ebx
; acepts 2 parameters
; first address of string is pushed on stack
; secondly the length of string is pushed
; so that makes length the first arguement and address as second 
; because length will be on top as happens in cases of all library functions
; this function itself allocates memory for resulting string, probably will make this better later

encode_b64:
	push ebp
	mov ebp, esp
	sub esp, 8		; allocating space for two local vars on stack
	mov eax, [ebp + 8]	; moving length of string to eax
	xor edx, edx
	mov ecx, 3
	div ecx			; checking if length is a multiple of 3
	mov ebx, 3
	sub ebx, edx		; checking how many bytes to add to pad the string to make it a multiple of 3
	cmp ebx, 3
	jne there		; if length is 3 then no need to add
	xor ebx, ebx
there:
	mov [ebp - 4], ebx		; padding length
	mov eax, [ebp + 8]
	add eax, [ebp - 4]		; original length + padding
	xor edx, edx
	div ecx				; dividing the original + padding by 3 and multiplying by 4
	inc ecx				; this will give us the length of resulting encoded string
	mul ecx
	cmp edx, 0
	jne stop
	add eax, 1			; for the newline byte
	mov [ebp - 8], eax		; result buffer length
	push eax
	call allocate_mem		; address of allocated mem is in mem_start
	pop ecx
	mov esi, [ebp + 12]		; string to be encoded
	mov edi, [mem_start]		; result buffer

encode_loop:
	cmp dword [ebp + 8], 0		; checking if original string has ended
	je pad_result			; pad the result if string has ended
	xor eax, eax
	mov ah, byte [esi]		; mov first to ah
	inc esi
	shl eax, 8			; shift the first byte to left 8 bits
	mov ah, byte [esi]		; move second and third byte to ah and al respectively
	mov al, byte [esi + 1]		; now eax contains three bytes in intended order
	add esi, 2
	mov ebx, eax			; eax is copied to 3 registers as there will be 4 resulting bytes
	mov ecx, eax
	mov edx, eax
	shr eax, 18			; gives the first 6 bitss
	shr ebx, 12			; 2nd 6 bits combination is at the end of regisster and similarly further
	shr ecx, 6
	and eax, 63			; and with 63 so last 6 bits will only get and'ed 
	and ebx, 63
	and ecx, 63
	and edx, 63			; we will have 4 bytes in eax, ebx, ecx, edx. these bytes will act as offset in b64_chars
	add eax, b64_chars		; address of first encoded byte
	mov al , byte [eax]
	mov byte [edi], al
	inc edi
	mov eax, ebx
	add ebx, b64_chars		; address of 2nd encoded byte
	mov bl, byte [ebx]
	mov byte [edi], bl
	inc edi
	cmp dword [ebp + 8], 1		; comparing the length left of original string, if its one then that means everything has been encoded
	je pad_result
	add ecx, b64_chars		; address of 3rd byte
	mov cl, byte [ecx]
	mov byte [edi], cl
	inc edi
	cmp dword [ebp + 8], 2		; check if the length left of original sstring is 2, if true then no need to find 4th byte
	je pad_result
	add edx, b64_chars		; address of 4th byte
	mov dl, byte [edx]
	mov byte [edi], dl
	inc edi
	sub dword [ebp + 8], 3		; subtract 3 from original string length
	jmp encode_loop			; loop

pad_result:
	cmp dword [ebp - 4], 0
	je encoded
	mov byte [edi], '='		; padding '='
	inc edi
	dec dword [ebp - 4]
	jmp pad_result

encoded:
	mov byte [edi], 0Ah
	mov eax, dword [mem_start]	; address of result buffer will be in eax
	mov ebx ,dword [ebp - 8]	; length of result buffer
	leave
	ret

; base 64 encoding function ends here


; base64 decoding

decode_b64:
	push ebp		; below ebp first is the length and then base address
	mov ebp, esp
	sub esp, 8
	mov eax, [ebp + 8]	; length of encoded string
	xor edx, edx
	mov ecx, 4
	div ecx			; dividing length by 4
	dec ecx
	mul ecx			; multiply by 3, now length of original string is in eax, need to subtract '=' if encoded string is padded
	cmp edx, 0
	jne stop
	inc eax			; inc eax cuz why not
	mov [ebp - 4], eax	; storing original + padding locally
	mov ebx, dword [ebp + 12]
	add ebx, [ebp + 8]	; going to the end of encoded string by adding len to base address to check for padding
	xor ecx, ecx
	dec ebx			; go one before null
  loc_dec_loop:
	cmp byte [ebx], '='
	jne p_len_found
	dec ebx
	inc ecx			; padding len in ecx
	jmp loc_dec_loop
p_len_found:
	mov dword [ebp - 8], ecx	; storing padding locally on stack
	push dword [ebp - 4]
	call allocate_mem	; allocated mem in mem_start
	dec dword [ebp - 4]	; 1 byte was allocated extra for newline char, dec'ing length to not mess the decoding
	pop ebx			; after this instruction, encoded string is in [ebp + 12], len of of encoded str [ebp + 8]
	mov esi, [ebp + 12]	; len of result is in [ebp - 4], padding in [ebp -8]
	mov edi, [mem_start]
	mov eax, dword [ebp -8]
	sub dword [ebp - 4], eax	; subtract paddding from result padding
	push dword [ebp-4]

decoding_loop:
	cmp dword [esp], 0
	je decoded
	mov eax, 0
	mov ebx, eax
	mov ecx, ebx
	mov edx, ecx
	mov al, byte [esi]		; moving 4 bytes to 4 registers respectively
	mov bl, byte [esi + 1]
	mov cl, byte [esi + 2]
	mov dl, byte [esi + 3]
	push eax			; finding position of first character in base64 array which will be the first 6 bits of the decoded result
	push b64_chars
	call find_c_in_s
	add esp, 8
	push eax		; pushing first 6 bits on stack bcuz need those registers to do stuff
	push ebx
	push b64_chars		; finding position of 2nd char
	call find_c_in_s
	add esp, 8
	mov ebx, eax		; 6-12 bits in ebx
	push ecx
	push b64_chars		; finding position of 3rd char
	call find_c_in_s
	add esp, 8
	mov ecx, eax		; 12-18 bits in ecx
	push edx
	push b64_chars		; finding position of 4th char
	call find_c_in_s
	add esp, 8
	mov edx, eax		; 18-24 bits in edx
	pop eax			; 0-6 bits in eax again
	shl eax, 18		; building the 24 bits original string
	shl ebx, 12
	shl ecx, 6
	or eax, ebx
	or eax, ecx
	or eax, edx
	mov ebx, eax
	shr ebx, 16
	mov byte [edi], bl	; bl contains the first byte , moving it to result buffer
	inc edi
	dec dword [esp]
	cmp dword [esp], 0	; checking if we have filled the whole original string, if yes then decoding completed
	je decoded
	mov byte [edi], ah	; moving 2nd byte to result buffer
	inc edi
	dec dword [esp]
	cmp dword [esp], 0
	je decoded
	mov byte [edi], al	; moving 3rd byte to result buffer
	inc edi
	dec dword [esp]
	add esi, 4
	jmp decoding_loop
decoded:
	pop ebx
	inc dword [ebp - 4]		; accounting for newline
	mov byte [edi], 0Ah
	mov ebx, dword [ebp - 4]	; moving length of result buffer
	mov eax, dword [mem_start]	; moving base address of result buffer
	leave				; restore stack to previous stack frame state
	ret

stop:		; Something is not right, Size too high
	call exit
	ret

; Function related to --help param

help_func:
	mov ebx, [ebp + 8]
	push help_param
	push dword [help_param_len]
	push ebx
	call stringcmp
	add esp, 12
	cmp eax, 0
	jne invalid
	push dword [help_args_len]
	push help_args
	call print
	add esp, 12
	call exit
	ret