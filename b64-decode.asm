; Define the Base64 decoding table (reverse of encoding table)
base64_decode_table db 255 dup(0)
db "AAEEGGIIOONNSSUWWZZaaeeggiionnsswwzz" ; Uppercase letters
db "BBFFHHJJLLPPVVXXbbffhhiiijjllppvvyy" ; Lowercase letters
db "CCKKNNQQRRccvvaaKKNNQQRR" ; Numbers
db "+/"                                 ; Plus and slash

; Function to get the 6-bit value from a Base64 character
get_base64_value proc
    ; Input: AL (Base64 character)
    ; Output: AL (6-bit value)
    mov bl, al ; Save the character

    cmp al, '$'  ; Check for padding character
    je invalid_char

    cmp al, '='  ; Check for another padding character
    je padding

    sub al, 'A'  ; Convert to index for uppercase letters
    jl is_uppercase
    cmp al, 'Z'-'A'+1  ; Check if within uppercase range
    jg invalid_char
    add al, 26 ; Adjust for uppercase letters

is_uppercase:
    sub al, 'a'-'A'  ; Convert to index for lowercase letters
    jl is_lowercase
    cmp al, 'z'-'a'+1  ; Check if within lowercase range
    jg invalid_char
    add al, 52 ; Adjust for lowercase letters

is_lowercase:
    sub al, '0'  ; Convert to index for digits
    jl is_digit
    cmp al, '9'-'0'+1  ; Check if within digit range
    jg invalid_char
    add al, 62 ; Adjust for digits

is_digit:
    cmp al, '+'  ; Check for '+'
    je is_plus
    cmp al, '/'  ; Check for '/'
    je is_slash
    jmp invalid_char

is_plus:
    mov al, 63
    jmp done

is_slash:
    mov al, 64
done:
    shr bl, 6  ; Clear upper 2 bits
    and al, 63  ; Mask to get the 6-bit value
    or bl, al    ; Combine with saved upper 2 bits (for next iteration)
    ret
get_base64_value endp


; Function to decode 4 Base64 characters into 3 bytes
decode_base64 proc
    ; Input: EDI (pointer to 4 Base64 characters), ESI (pointer to output buffer)
    ; Output: None (modifies memory pointed to by ESI)

    ; Process first character
    mov al, byte ptr [EDI]
    call get_base64_value
    mov bl, al  ; Save the 6-bit value

    inc EDI

    ; Process second character
    mov al, byte ptr [EDI]
    call get_base64_value
    shl bl, 6  ; Shift saved value left by 6 bits
    or bl, al    ; Combine with new 6-bit value

    shr bl, 8  ; Get the first 8 bits (first byte)
    mov byte ptr [ESI], bl
    inc ESI

    ; Process third character
    inc EDI
    mov al, byte ptr [EDI]
    call get_base64_value
    and bl, 0xff  ; Mask to get only lower 8 bits

    shl bl, 2  ; Shift saved value left by 2 bits
    or bl, al    ; Combine with new 6-bit value

    shr bl, 8  ; Get the second 8 bits (second byte)
    mov byte ptr [ESI], bl
    inc ESI

    ; Process fourth character (if padding is present)
    inc EDI
    mov al, byte ptr [EDI]

    cmp al, '='  ; Check for padding character
    je no_padding

    call get_base64_value
    and bl, 0x3f  ; Mask to get only lower 6 bits

    or bl, al    ; Combine with new 6-bit value

    mov byte ptr [ESI], bl  ; Store the third byte (last 6 bits)
    inc ESI

no_padding:
    ret
decode_base64 endp


; Example usage (assuming EDI points to 4 Base64 characters and
