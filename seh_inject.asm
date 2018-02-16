;---------------------------------------------
; SEH Demo 2
; Copyright (C) ManHunter / PCL
; http://www.manhunter.ru
;---------------------------------------------

format PE GUI 4.0
entry start

include 'win32a.inc'

ID_ERR1 = 101
ID_ERR2 = 102
ID_ERR3 = 103

EXCEPTION_MAXIMUM_PARAMETERS = 15
SIZE_OF_80387_REGISTERS      = 80
MAXIMUM_SUPPORTED_EXTENSION  = 512
EXCEPTION_CONTINUE_EXECUTION = -1

struct FLOATING_SAVE_AREA
  ControlWord          dd ?
  StatusWord           dd ?
  TagWord              dd ?
  ErrorOffset          dd ?
  ErrorSelector        dd ?
  DataOffset           dd ?
  DataSelector         dd ?
  RegisterArea         rb SIZE_OF_80387_REGISTERS
  Cr0NpxState          dd ?
ends

struct CONTEXT
  ContextFlags         dd ?
  iDr0                 dd ?
  iDr1                 dd ?
  iDr2                 dd ?
  iDr3                 dd ?
  iDr6                 dd ?
  iDr7                 dd ?
  FloatSave            FLOATING_SAVE_AREA
  regGs                dd ?
  regFs                dd ?
  regEs                dd ?
  regDs                dd ?
  regEdi               dd ?
  regEsi               dd ?
  regEbx               dd ?
  regEdx               dd ?
  regEcx               dd ?
  regEax               dd ?
  regEbp               dd ?
  regEip               dd ?
  regCs                dd ?
  regFlag              dd ?
  regEsp               dd ?
  regSs                dd ?
  ExtendedRegisters    rb MAXIMUM_SUPPORTED_EXTENSION
ends

struct EXCEPTION_RECORD
  ExceptionCode        dd ?
  ExceptionFlags       dd ?
  pExceptionRecord     dd ?
  ExceptionAddress     dd ?
  NumberParameters     dd ?
  ExceptionInformation rd EXCEPTION_MAXIMUM_PARAMETERS
ends

struct EXCEPTION_POINTERS
  pExceptionRecord     dd ?
  pContextRecord       dd ?
ends

;---------------------------------------------

section '.code' code readable executable

start:
        invoke  GetModuleHandle,0
        invoke  DialogBoxParam,eax,37,HWND_DESKTOP,DialogProc,0
loc_exit:
        invoke  ExitProcess,0

;---------------------------------------------

proc DialogProc hwnddlg,msg,wparam,lparam
        push    ebx esi edi
        cmp     [msg],WM_INITDIALOG
        je      .wminitdialog
        cmp     [msg],WM_COMMAND
        je      .wmcommand
        cmp     [msg],WM_CLOSE
        je      .wmclose
        xor     eax,eax
        jmp     .finish
  .wminitdialog:
        jmp     .processed

  .wmcommand:
        cmp     [wparam],BN_CLICKED shl 16 + IDCANCEL
        je      .wmclose
        cmp     [wparam],BN_CLICKED shl 16 + ID_ERR1
        je      .error1
        cmp     [wparam],BN_CLICKED shl 16 + ID_ERR2
        je      .error2
        cmp     [wparam],BN_CLICKED shl 16 + ID_ERR3
        je      .error3
        cmp     [wparam],BN_CLICKED shl 16 + IDOK
        jne     .processed

        jmp     .finish

.error1:
        ; Добавить наш обработчик в цепочку
        push    ExceptionFilter
        push    dword [fs:0]
        mov     [fs:0],esp

        xor     eax,eax
        mov     eax,[eax]

        ; Убрать наш обработчик
        pop     dword[fs:0]
        add     esp, 4

        jmp     .processed

.error2:
        ; Добавить наш обработчик в цепочку
        push    ExceptionFilter
        push    dword [fs:0]
        mov     [fs:0],esp

        xor     ecx,ecx
        div     ecx

        ; Убрать наш обработчик
        pop     dword[fs:0]
        add     esp, 4

        jmp     .processed

.error3:
        ; Добавить наш обработчик в цепочку
        push    ExceptionFilter
        push    dword [fs:0]
        mov     [fs:0],esp

        db      0f1h,0f1h

        ; Убрать наш обработчик
        pop     dword[fs:0]
        add     esp, 4

        jmp     .processed

  .wmclose:
        invoke  EndDialog,[hwnddlg],0
  .processed:
        mov     eax,1
  .finish:
        pop     edi esi ebx
        ret
endp

;----------------------------------------------------------------------------------
; Обработчик критических ошибок
;----------------------------------------------------------------------------------
proc  ExceptionFilter pExcept:DWORD, pFrame:DWORD, pContext:DWORD, pDispatch:DWORD
        locals
            szFile   rb MAX_PATH
            szBuffer rb 500h
        endl

        mov     esi,[pExcept]  ; EXCEPTION_RECORD
        mov     edi,[pContext] ; CONTEXT

        ; ReadWrite
        mov     ecx,[esi+EXCEPTION_RECORD.ExceptionInformation]
        cmp     ecx,2
        jb      @f
        mov     ecx,2
@@:
        mov     ecx,[.szOperation+ecx*4]

        ; Continuable
        mov     edx,[esi+EXCEPTION_RECORD.ExceptionFlags]
        mov     edx,[.szLogical+edx*4]

        ; Сформировать текст исключения
        lea     ebx,[szBuffer]
        cinvoke wsprintf,ebx,.szMask,\
                [esi+EXCEPTION_RECORD.ExceptionAddress],\
                [esi+EXCEPTION_RECORD.ExceptionCode],\
                edx,[esi+EXCEPTION_RECORD.NumberParameters],ecx,\
                [edi+CONTEXT.regEax],[edi+CONTEXT.regEbx],\
                [edi+CONTEXT.regEcx],[edi+CONTEXT.regEdx],\
                [edi+CONTEXT.regEsp],[edi+CONTEXT.regEbp],\
                [edi+CONTEXT.regEsi],[edi+CONTEXT.regEdi]

        ; Сформировать имя файла для логирования ошибок
        lea     ebx,[szFile]
        invoke  GetModuleHandle,NULL
        invoke  GetModuleFileName,eax,ebx,MAX_PATH
        invoke  lstrcat,ebx,.szTail

        ; Поптытаться создать файл
        invoke  CreateFile,ebx,GENERIC_WRITE,FILE_SHARE_READ,\
                NULL,OPEN_ALWAYS,FILE_ATTRIBUTE_NORMAL,NULL
        cmp     eax,-1
        je      @f
        mov     ebx,eax

        ; Указатель на сформированный текст исключения
        lea     esi,[szBuffer]

        ; Дописать текст в конец файла лога
        invoke  SetFilePointer,ebx,0,0,FILE_END
        invoke  lstrlen,esi
        invoke  _lwrite,ebx,esi,eax
        invoke  CloseHandle,ebx
@@:
        ; Сообщение пользователю о возникновении ошибки
        invoke  MessageBox,0,esi,.szTitle,\
                MB_OK+MB_ICONHAND+MB_APPLMODAL+MB_TOPMOST

        invoke  ExitProcess,0

.szTail      db '_errors.log',0

.szLogical   dd .szFalse,.szTrue
.szFalse     db 'false',0
.szTrue      db 'true',0

.szOperation dd .szRead,.szWrite,.szOther
.szRead      db 'read',0
.szWrite     db 'write',0
.szOther     db 'other',0

.szTitle     db 'Critical error',0
.szMask      db 'Exception addr: %08Xh',13,10,'Exception type: %08Xh',13,10,13,10
             db 'Information:',13,10
             db 'Continuable = %s, NumberParameters = %u, ReadWrite = %s',13,10,13,10
             db 'Registers:',13,10
             db 'eax = %08Xh, ebx = %08Xh, ecx = %08Xh, edx = %08Xh',13,10
             db 'esp = %08Xh, ebp = %08Xh, esi = %08Xh, edi = %08Xh',13,10,13,10
             db 0
endp

;---------------------------------------------

section '.idata' import data readable writeable

  library kernel32,'kernel32.dll',\
          user32,'user32.dll'

  include 'apia\kernel32.inc'
  include 'apia\user32.inc'

;---------------------------------------------

section '.rsrc' resource data readable

  directory RT_DIALOG,dialogs

  resource dialogs,\
           37,LANG_ENGLISH+SUBLANG_DEFAULT,demonstration

  dialog demonstration,'SEH Demo 2',0,0,200,55,WS_CAPTION+WS_SYSMENU+DS_CENTER+DS_SYSMODAL
    dialogitem 'BUTTON','',-1, 2, -1, 195, 35,WS_VISIBLE+BS_GROUPBOX
    dialogitem 'BUTTON','Access Violation',ID_ERR1,7,8,60,20,WS_VISIBLE
    dialogitem 'BUTTON','Division by 0',ID_ERR2,70,8,60,20,WS_VISIBLE
    dialogitem 'BUTTON','Invalid Opcode',ID_ERR3,132,8,60,20,WS_VISIBLE
    dialogitem 'BUTTON','Exit',IDCANCEL,145,37,50,15,WS_VISIBLE+WS_TABSTOP+BS_PUSHBUTTON
  enddialog
