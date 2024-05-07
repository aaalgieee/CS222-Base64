section .data
    base64_table db 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/', 0

section .text
    global _start

_start:
    ; Read input string from user
    mov eax, 3      ; sys_read
    mov ebx, 0      ; stdin
    mov ecx, buffer ; buffer address
    mov edx, 256    ; buffer size
    int 0x80

    ; Encode input string to Base64
    mov esi, buffer ; source address
    mov edi, encoded_buffer ; destination address

encode_loop:
    lodsb           ; load byte from source
    test al, al     ; check if end of string
    jz end_encode

    ; First Base64 character
    shr al, 2       ; shift right by 2 bits
    mov dl, al      ; save first 6 bits
    and dl, 0x3F    ; mask out upper bits
    mov al, byte [base64_table + edx] ; lookup character
    stosb           ; store character to destination

    ; Second Base64 character
    mov al, dl      ; restore first 6 bits
    mov dl, ah      ; save next 2 bits
    and dl, 0x0F    ; mask out upper bits
    shl al, 4       ; shift left by 4 bits
    or al, dl       ; combine bits
    mov al, byte [base64_table + eax] ; lookup character
    stosb           ; store character to destination

    ; Third Base64 character
    mov al, ah      ; restore next 2 bits
    shl al, 2       ; shift left by 2 bits
    mov al, byte [base64_table + eax] ; lookup character
    stosb           ; store character to destination

    ; Fourth Base64 character
    mov al, 0x3D    ; padding character '='
    stosb           ; store padding character to destination

    jmp encode_loop

end_encode:
    ; Write encoded string to stdout
    mov eax, 4      ; sys_write
    mov ebx, 1      ; stdout
    mov ecx, encoded_buffer ; buffer address
    sub edx, ecx    ; calculate buffer size
    int 0x80

    ; Exit program
    mov eax, 1      ; sys_exit
    xor ebx, ebx    ; exit code 0
    int 0x80

section .bss
    buffer resb 256
    encoded_buffer resb 256