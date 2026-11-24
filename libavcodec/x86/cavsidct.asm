; Chinese AVS video (AVS1-P2, JiZhun profile) decoder
; Copyright (c) 2006  Stefan Gehrer <stefan.gehrer@gmx.de>
;
; MMX-optimized DSP functions, based on H.264 optimizations by
; Michael Niedermayer and Loren Merritt
; Conversion from gcc syntax to x264asm syntax with modifications
; by Ronald S. Bultje <rsbultje@gmail.com>
;
; This file is part of FFmpeg.
;
; FFmpeg is free software; you can redistribute it and/or
; modify it under the terms of the GNU Lesser General Public
; License as published by the Free Software Foundation; either
; version 2.1 of the License, or (at your option) any later version.
;
; FFmpeg is distributed in the hope that it will be useful,
; but WITHOUT ANY WARRANTY; without even the implied warranty of
; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
; Lesser General Public License for more details.
;
; You should have received a copy of the GNU Lesser General Public
; License along with FFmpeg; if not, write to the Free Software
; Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA

%include "libavutil/x86/x86util.asm"

SECTION_RODATA 32
pd_4:  times 4 dd 4
pd_64: times 4 dd 64

SECTION .text

; 1D CAVS inverse transform of one 4-column chunk with 32-bit intermediates,
; bit-exact with the C code (which matches the rm52k reference decoder).
; The 16-bit SSE2 version this replaces wrapped around on the large
; coefficients that occur in conformance streams; doing all arithmetic in
; the dword domain and relying on packssdw for the int16 clipping of the
; row/column results makes the kernel exact for the full int16 input range.
;
; %1 = word matrix base, %2 = chunk byte offset (0 = columns 0-3, 8 = 4-7),
; %3 = pass (1 = row pass with +4 rounding, 2 = column pass with +64 rounding)
; outputs (dwords): m0 = out0, m3 = out1, m4 = out2, m5 = out3,
;                   m13 = out4, m14 = out5, m1 = out6, m2 = out7
%macro CAVS_IDCT8_1D_32 3
    movq      m4, [%1 + 7*16 + %2]      ; s7
    movq      m5, [%1 + 1*16 + %2]      ; s1
    movq      m2, [%1 + 5*16 + %2]      ; s5
    movq      m7, [%1 + 3*16 + %2]      ; s3
    punpcklwd m4, m4
    punpcklwd m5, m5
    punpcklwd m2, m2
    punpcklwd m7, m7
    psrad     m4, 16                    ; sign-extend words to dwords
    psrad     m5, 16
    psrad     m2, 16
    psrad     m7, 16

    ; a0 = 3*s1 - 2*s7, a1 = 3*s3 + 2*s5
    ; a2 = 2*s3 - 3*s5, a3 = 2*s1 + 3*s7
    mova      m9,  m5
    pslld     m9,  1                    ; 2*s1
    mova      m10, m4
    pslld     m10, 1                    ; 2*s7
    mova      m11, m7
    pslld     m11, 1                    ; 2*s3
    mova      m12, m2
    pslld     m12, 1                    ; 2*s5
    mova      m0,  m5
    paddd     m0,  m9
    psubd     m0,  m10                  ; a0
    mova      m1,  m7
    paddd     m1,  m11
    paddd     m1,  m12                  ; a1
    mova      m3,  m2
    paddd     m3,  m12                  ; 3*s5
    mova      m8,  m11                  ; 2*s3
    psubd     m8,  m3                   ; a2
    mova      m3,  m4
    paddd     m3,  m10                  ; 3*s7
    paddd     m3,  m9                   ; a3

    ; b4 = 2*(a0+a1+a3)+a1, b5 = 2*(a0-a1+a2)+a0
    ; b6 = 2*(a3-a2-a1)+a3, b7 = 2*(a0-a2-a3)-a2
    mova      m9,  m0
    paddd     m9,  m1
    paddd     m9,  m3
    pslld     m9,  1
    paddd     m9,  m1                   ; b4
    mova      m10, m0
    psubd     m10, m1
    paddd     m10, m8
    pslld     m10, 1
    paddd     m10, m0                   ; b5
    mova      m11, m3
    psubd     m11, m8
    psubd     m11, m1
    pslld     m11, 1
    paddd     m11, m3                   ; b6
    mova      m12, m0
    psubd     m12, m8
    psubd     m12, m3
    pslld     m12, 1
    psubd     m12, m8                   ; b7

    ; load even rows: s0 -> m4, s4 -> m5, s2 -> m2, s6 -> m7
    movq      m4, [%1 + 0*16 + %2]
    movq      m5, [%1 + 4*16 + %2]
    movq      m2, [%1 + 2*16 + %2]
    movq      m7, [%1 + 6*16 + %2]
    punpcklwd m4, m4
    punpcklwd m5, m5
    punpcklwd m2, m2
    punpcklwd m7, m7
    psrad     m4, 16
    psrad     m5, 16
    psrad     m2, 16
    psrad     m7, 16

    ; a4 = 8*(s0+s4), a5 = 8*(s0-s4)  (+4 rounding on the row pass)
    mova      m13, m4
    paddd     m13, m5
    pslld     m13, 3                    ; a4
    mova      m14, m4
    psubd     m14, m5
    pslld     m14, 3                    ; a5
%if %3 == 1
    paddd     m13, [pd_4]
    paddd     m14, [pd_4]
%endif

    ; a6 = 4*s6 + 10*s2, a7 = 4*s2 - 10*s6
    mova      m15, m2
    pslld     m15, 2                    ; 4*s2
    mova      m8,  m7
    pslld     m8,  2                    ; 4*s6
    mova      m0,  m2
    pslld     m0,  1                    ; 2*s2
    mova      m1,  m2
    pslld     m1,  3
    paddd     m1,  m0                   ; 10*s2
    mova      m3,  m7
    pslld     m3,  1                    ; 2*s6
    mova      m0,  m7
    pslld     m0,  3
    paddd     m0,  m3                   ; 10*s6
    paddd     m1,  m8                   ; a6
    psubd     m15, m0                   ; a7

    ; b0 = a4+a6, b1 = a5+a7, b2 = a5-a7, b3 = a4-a6
    mova      m0,  m13
    paddd     m0,  m1                   ; b0
    psubd     m13, m1                   ; b3
    mova      m1,  m14
    paddd     m1,  m15                  ; b1
    psubd     m14, m15                  ; b2

    ; out0 = b0+b4, out7 = b0-b4, out1 = b1+b5, out6 = b1-b5
    ; out2 = b2+b6, out5 = b2-b6, out3 = b3+b7, out4 = b3-b7
    mova      m2,  m0
    paddd     m0,  m9                   ; out0
    psubd     m2,  m9                   ; out7
    mova      m3,  m1
    paddd     m3,  m10                  ; out1
    psubd     m1,  m10                  ; out6
    mova      m4,  m14
    paddd     m4,  m11                  ; out2
    psubd     m14, m11                  ; out5
    mova      m5,  m13
    paddd     m5,  m12                  ; out3
    psubd     m13, m12                  ; out4
%if %3 == 2
    paddd     m0,  [pd_64]
    paddd     m3,  [pd_64]
    paddd     m4,  [pd_64]
    paddd     m5,  [pd_64]
    paddd     m13, [pd_64]
    paddd     m14, [pd_64]
    paddd     m1,  [pd_64]
    paddd     m2,  [pd_64]
%endif
%endmacro

; the kernel needs all 16 xmm registers, so it is x86-64 only; 32-bit x86
; keeps the (exact) C version
%if ARCH_X86_64
INIT_XMM sse2
cglobal cavs_idct8, 2, 2, 16, 16 * 16, out, in
    ; pass 1 (row pass: +4 rounding, >>3), columns 0-3
    CAVS_IDCT8_1D_32 inq, 0, 1
    mova      [rsp +  0*16], m0
    mova      [rsp +  1*16], m3
    mova      [rsp +  2*16], m4
    mova      [rsp +  3*16], m5
    mova      [rsp +  4*16], m13
    mova      [rsp +  5*16], m14
    mova      [rsp +  6*16], m1
    mova      [rsp +  7*16], m2
    ; pass 1, columns 4-7; clip to int16 (packssdw) and shift
    CAVS_IDCT8_1D_32 inq, 8, 1
    mova      m8,  [rsp +  0*16]
    packssdw  m8,  m0
    psraw     m8,  3                    ; dst0
    mova      m9,  [rsp +  1*16]
    packssdw  m9,  m3
    psraw     m9,  3                    ; dst1
    mova      m10, [rsp +  2*16]
    packssdw  m10, m4
    psraw     m10, 3                    ; dst2
    mova      m11, [rsp +  3*16]
    packssdw  m11, m5
    psraw     m11, 3                    ; dst3
    mova      m12, [rsp +  4*16]
    packssdw  m12, m13
    psraw     m12, 3                    ; dst4
    mova      m13, [rsp +  5*16]
    packssdw  m13, m14
    psraw     m13, 3                    ; dst5
    mova      m14, [rsp +  6*16]
    packssdw  m14, m1
    psraw     m14, 3                    ; dst6
    mova      m15, [rsp +  7*16]
    packssdw  m15, m2
    psraw     m15, 3                    ; dst7

    TRANSPOSE8x8W 8, 9, 10, 11, 12, 13, 14, 15, 0
    mova      [rsp +  0*16], m8
    mova      [rsp +  1*16], m9
    mova      [rsp +  2*16], m10
    mova      [rsp +  3*16], m11
    mova      [rsp +  4*16], m12
    mova      [rsp +  5*16], m13
    mova      [rsp +  6*16], m14
    mova      [rsp +  7*16], m15

    ; pass 2 (column pass: +64 rounding, >>7), rows 0-3 of the transpose
    CAVS_IDCT8_1D_32 rsp, 0, 2
    mova      [rsp +  8*16], m0
    mova      [rsp +  9*16], m3
    mova      [rsp + 10*16], m4
    mova      [rsp + 11*16], m5
    mova      [rsp + 12*16], m13
    mova      [rsp + 13*16], m14
    mova      [rsp + 14*16], m1
    mova      [rsp + 15*16], m2
    ; pass 2, rows 4-7 of the transpose; clip, shift and store
    CAVS_IDCT8_1D_32 rsp, 8, 2
    mova      m8,  [rsp +  8*16]
    packssdw  m8,  m0
    psraw     m8,  7
    mova      [outq + 0*16], m8
    mova      m9,  [rsp +  9*16]
    packssdw  m9,  m3
    psraw     m9,  7
    mova      [outq + 1*16], m9
    mova      m10, [rsp + 10*16]
    packssdw  m10, m4
    psraw     m10, 7
    mova      [outq + 2*16], m10
    mova      m11, [rsp + 11*16]
    packssdw  m11, m5
    psraw     m11, 7
    mova      [outq + 3*16], m11
    mova      m12, [rsp + 12*16]
    packssdw  m12, m13
    psraw     m12, 7
    mova      [outq + 4*16], m12
    mova      m13, [rsp + 13*16]
    packssdw  m13, m14
    psraw     m13, 7
    mova      [outq + 5*16], m13
    mova      m14, [rsp + 14*16]
    packssdw  m14, m1
    psraw     m14, 7
    mova      [outq + 6*16], m14
    mova      m15, [rsp + 15*16]
    packssdw  m15, m2
    psraw     m15, 7
    mova      [outq + 7*16], m15
    RET
%endif
