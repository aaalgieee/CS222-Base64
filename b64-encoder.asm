; Define the Base64 encoding table
base64_table db "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"

; Function to get the Base64 character for a 6-bit value
get_base64_char proc
    ; Input: AL (6-bit value)
    ; Output: AL (Base64 character)
    mov bl, 0 ; Clear bl for calculations
    shl al, 2  ; Shift left by 2 bits to make room for next 6 bits
    add al, bl ; Combine with next 6 bits (initially 0)
    cmp al, 26 ; Check if less than uppercase letters (A-Z)
    jl is_uppercase
    add al, 65 ; Convert to uppercase letter (A-Z)
    jmp done

is_uppercase:
    cmp al, 52 ; Check if less than lowercase letters (a-z)
    jl is_lowercase
    add al, 71 ; Convert to lowercase letter (a-z)
    jmp done

is_lowercase:
    cmp al, 62 ; Check if less than digits (0-9)
    jl is_digit
    add al, 48 ; Convert to digit (0-9)
    jmp done

is_digit:
    cmp al, 63 ; Check for '+'
    je is_plus
    cmp al, 64 ; Check for '/'
    je is_slash
    jmp done  ; Invalid input (not 6 bits)

is_plus:
    mov al, '+'
    jmp done

is_slash:
    mov al, '/'
done:
    ret
get_base64_char endp


; Function to encode 3 bytes into 4 Base64 characters
encode_base64 proc
    ; Input: EDI (pointer to 3 bytes), ESI (pointer to output buffer)
    ; Output: None (modifies memory pointed to by ESI)
    
    ; Process first byte
    mov al, byte ptr [EDI]
    shr al, 2  ; Get the first 6 bits

    push eax   ; Save upper 2 bits for later
    call get_base64_char
    mov byte ptr [ESI], al ; Store Base64 character
    inc ESI

    ; Process second byte (middle 6 bits)
    mov al, byte ptr [EDI]
    and al, 3   ; Mask to get only lower 2 bits
    shl al, 4  ; Shift left by 4 bits
    
    pop eax    ; Restore upper 2 bits
    or al, bl    ; Combine with saved upper 2 bits
    call get_base64_char
    mov byte ptr [ESI], al ; Store Base64 character
    inc ESI

    ; Process third byte (last 6 bits)
    mov al, byte ptr [EDI+1]
    shr al, 4  ; Get the first 4 bits
    or al, bl    ; Combine with saved lower 2 bits
    call get_base64_char
    mov byte ptr [ESI], al ; Store Base64 character
    inc ESI

    ; Padding (if necessary)
    mov al, byte ptr [EDI+1]
    and al, 15  ; Mask to get the last 2 bits
    cmp al, 0   ; Check if all bits are 0 (padding)
    je no_padding

    call get_base64_char
    mov byte ptr [ESI], al ; Store Base64 character
    inc ESI

    mov al, '=' ; Padding character
    mov byte ptr [ESI], al ; Store padding
    inc ESI

no_padding:
    ret
encode_base64 endp

; Example usage (assuming EDI points to 3 bytes and ESI points to output buffer)
mov eax, 0   ; Clear accumulator
call encode_base64
