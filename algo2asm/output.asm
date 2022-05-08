; ASM file obtained from a LaTeX file

	const ax,beginning
	jmp ax

:div_err_str
@string "Erreur : Division par 0 impossible\n"

:div_err
	const ax,div_err_str
	callprintfs ax
	end

:beginning
; Stack preparation
	const bp,stack
	const sp,stack
	const ax,2
	sub sp,ax
; Reading the number -1
	const ax,-1
	push ax
; Affect a value to the variable p
	const ax,var:p
	pop bx
	storew bx,ax
; Reading the number 2
	const ax,2
	push ax
; Affect a value to the variable d
	const ax,var:d
	pop bx
	storew bx,ax
; Reading the variable named d
	const ax,var:d
	loadw bx,ax
	push bx
; Reading the variable named p
	const ax,var:p
	loadw bx,ax
	push bx
; Substracting two expressions
	pop ax
	pop bx
	sub bx,ax
	push bx
; Affect a value to the variable bro
	const ax,var:bro
	pop bx
	storew bx,ax
	end

; Variable declarations

:var:bro
@int 0

:var:d
@int 0

:var:p
@int 0

;Stack zone
:stack
@int 0
