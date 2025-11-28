/* array7d_aarch64.s  (AArch64 / ARM64, links with libc)
 *
 * 7D array demo with insert/delete/edit/get/list.
 * Dimensions: 3^7 = 2187 cells, each cell is int64.
 *
 * Build:
 *   clang array7d_aarch64.s -o array7d
 *
 * Run:
 *   ./array7d
 */

        .text
        .global main
        .type   main, %function

/* -------- constants -------- */
        .equ D0, 3
        .equ D1, 3
        .equ D2, 3
        .equ D3, 3
        .equ D4, 3
        .equ D5, 3
        .equ D6, 3

        .equ TOT, 2187            /* 3^7 */
        .equ STR0, 729            /* 3^6 */
        .equ STR1, 243            /* 3^5 */
        .equ STR2, 81             /* 3^4 */
        .equ STR3, 27             /* 3^3 */
        .equ STR4, 9              /* 3^2 */
        .equ STR5, 3              /* 3^1 */

/* helpers: load address of local symbol */
        .macro  LADR reg, sym
        adrp    \reg, \sym
        add     \reg, \reg, :lo12:\sym
        .endm

/* -------- external libc -------- */
        .extern printf
        .extern scanf

/* -------- main -------- */
main:
        stp     x29, x30, [sp, -16]!
        mov     x29, sp

        /* banner */
        LADR    x0, banner
        bl      printf

menu_loop:
        /* print menu */
        LADR    x0, menu
        bl      printf

        /* read choice: scanf("%d", &choice) */
        LADR    x0, fmt_choice
        LADR    x1, choice
        bl      scanf

        /* load choice */
        LADR    x9, choice
        ldr     w10, [x9]

        /* if 0 -> exit */
        cbz     w10, done

        /* dispatch */
        cmp     w10, #1
        b.eq    op_insert
        cmp     w10, #2
        b.eq    op_edit
        cmp     w10, #3
        b.eq    op_delete
        cmp     w10, #4
        b.eq    op_get
        cmp     w10, #5
        b.eq    op_list

        /* unknown */
        LADR    x0, msg_unknown
        bl      printf
        b       menu_loop

/* -------- parse helpers (scanf formats) --------
 * Indices stored in idx[0..6] (u64), value in val (i64).
 */

/* -------- bounds + linear index compute --------
 * Loads idx[0..6] into x0..x6, checks each < 3.
 * Computes linear index into x10 (0..2186).
 * On bounds error, prints message and branches to menu_loop.
 */
check_and_linear:
        LADR    x11, idx

        ldr     x0, [x11, #0]          /* i0 */
        ldr     x1, [x11, #8]          /* i1 */
        ldr     x2, [x11, #16]         /* i2 */
        ldr     x3, [x11, #24]         /* i3 */
        ldr     x4, [x11, #32]         /* i4 */
        ldr     x5, [x11, #40]         /* i5 */
        ldr     x6, [x11, #48]         /* i6 */

        /* bounds: each must be < 3 */
        cmp     x0, #3
        b.hs    bounds_fail
        cmp     x1, #3
        b.hs    bounds_fail
        cmp     x2, #3
        b.hs    bounds_fail
        cmp     x3, #3
        b.hs    bounds_fail
        cmp     x4, #3
        b.hs    bounds_fail
        cmp     x5, #3
        b.hs    bounds_fail
        cmp     x6, #3
        b.hs    bounds_fail

        /* linear = i0*729 + i1*243 + i2*81 + i3*27 + i4*9 + i5*3 + i6 */
        mov     x9, #STR0
        mul     x10, x0, x9

        mov     x9, #STR1
        madd    x10, x1, x9, x10

        mov     x9, #STR2
        madd    x10, x2, x9, x10

        mov     x9, #STR3
        madd    x10, x3, x9, x10

        mov     x9, #STR4
        madd    x10, x4, x9, x10

        mov     x9, #STR5
        madd    x10, x5, x9, x10

        add     x10, x10, x6
        ret

bounds_fail:
        LADR    x0, msg_bounds
        bl      printf
        b       menu_loop

/* -------- op: INSERT -------- */
op_insert:
        LADR    x0, prompt_insert
        bl      printf

        /* scanf("%llu ... %lld", &idx0..&idx6, &val) */
        LADR    x0, fmt_insert
        LADR    x1, idx
        LADR    x2, idx+8
        LADR    x3, idx+16
        LADR    x4, idx+24
        LADR    x5, idx+32
        LADR    x6, idx+40
        LADR    x7, idx+48
        /* 8th pointer (&val) goes on stack (keep 16-byte alignment) */
        LADR    x8, val
        sub     sp, sp, #16
        str     x8, [sp]
        bl      scanf
        add     sp, sp, #16

        /* check scanf count == 8 */
        cmp     w0, #8
        b.ne    scan_fail_8

        bl      check_and_linear      /* sets x10 = linear index */

        /* occ[linear]? */
        LADR    x11, occ
        add     x11, x11, x10
        ldrb    w12, [x11]
        cbnz    w12, insert_exists

        /* store value */
        LADR    x13, vals
        lsl     x14, x10, #3
        add     x13, x13, x14
        LADR    x15, val
        ldr     x16, [x15]
        str     x16, [x13]

        /* set occupied=1 */
        mov     w12, #1
        strb    w12, [x11]

        LADR    x0, msg_insert_ok
        bl      printf
        b       menu_loop

insert_exists:
        LADR    x0, msg_occupied
        bl      printf
        b       menu_loop

scan_fail_8:
        LADR    x0, msg_scan_fail
        bl      printf
        b       menu_loop

/* -------- op: EDIT -------- */
op_edit:
        LADR    x0, prompt_edit
        bl      printf

        /* same input as insert */
        LADR    x0, fmt_insert
        LADR    x1, idx
        LADR    x2, idx+8
        LADR    x3, idx+16
        LADR    x4, idx+24
        LADR    x5, idx+32
        LADR    x6, idx+40
        LADR    x7, idx+48
        LADR    x8, val
        sub     sp, sp, #16
        str     x8, [sp]
        bl      scanf
        add     sp, sp, #16

        cmp     w0, #8
        b.ne    scan_fail_8

        bl      check_and_linear      /* x10 index */

        /* must be occupied */
        LADR    x11, occ
        add     x11, x11, x10
        ldrb    w12, [x11]
        cbz     w12, edit_empty

        /* overwrite value */
        LADR    x13, vals
        lsl     x14, x10, #3
        add     x13, x13, x14
        LADR    x15, val
        ldr     x16, [x15]
        str     x16, [x13]

        LADR    x0, msg_edit_ok
        bl      printf
        b       menu_loop

edit_empty:
        LADR    x0, msg_empty
        bl      printf
        b       menu_loop

/* -------- op: DELETE -------- */
op_delete:
        LADR    x0, prompt_delete
        bl      printf

        /* scanf("%llu ...", &idx0..&idx6) */
        LADR    x0, fmt_indices
        LADR    x1, idx
        LADR    x2, idx+8
        LADR    x3, idx+16
        LADR    x4, idx+24
        LADR    x5, idx+32
        LADR    x6, idx+40
        LADR    x7, idx+48
        bl      scanf
        cmp     w0, #7
        b.ne    scan_fail_7

        bl      check_and_linear

        LADR    x11, occ
        add     x11, x11, x10
        ldrb    w12, [x11]
        cbz     w12, del_empty

        /* clear value */
        LADR    x13, vals
        lsl     x14, x10, #3
        add     x13, x13, x14
        mov     x16, #0
        str     x16, [x13]

        /* clear occupied */
        mov     w12, #0
        strb    w12, [x11]

        LADR    x0, msg_delete_ok
        bl      printf
        b       menu_loop

del_empty:
        LADR    x0, msg_empty
        bl      printf
        b       menu_loop

scan_fail_7:
        LADR    x0, msg_scan_fail
        bl      printf
        b       menu_loop

/* -------- op: GET -------- */
op_get:
        LADR    x0, prompt_get
        bl      printf

        /* read 7 indices */
        LADR    x0, fmt_indices
        LADR    x1, idx
        LADR    x2, idx+8
        LADR    x3, idx+16
        LADR    x4, idx+24
        LADR    x5, idx+32
        LADR    x6, idx+40
        LADR    x7, idx+48
        bl      scanf
        cmp     w0, #7
        b.ne    scan_fail_7

        bl      check_and_linear

        /* occupied? */
        LADR    x11, occ
        add     x11, x11, x10
        ldrb    w12, [x11]
        cbz     w12, get_empty

        /* load value */
        LADR    x13, vals
        lsl     x14, x10, #3
        add     x13, x13, x14
        ldr     x15, [x13]

        /* printf("Value at [..] = %lld\n", i0..i6, value) */
        LADR    x11, idx
        ldr     x1, [x11, #0]
        ldr     x2, [x11, #8]
        ldr     x3, [x11, #16]
        ldr     x4, [x11, #24]
        ldr     x5, [x11, #32]
        ldr     x6, [x11, #40]
        ldr     x7, [x11, #48]
        LADR    x0, msg_get_val

        /* last vararg (value) on stack */
        mov     x8, x15
        sub     sp, sp, #16
        str     x8, [sp]
        bl      printf
        add     sp, sp, #16

        b       menu_loop

get_empty:
        /* printf("Cell [..] is <empty>\n", i0..i6) */
        LADR    x11, idx
        ldr     x1, [x11, #0]
        ldr     x2, [x11, #8]
        ldr     x3, [x11, #16]
        ldr     x4, [x11, #24]
        ldr     x5, [x11, #32]
        ldr     x6, [x11, #40]
        ldr     x7, [x11, #48]
        LADR    x0, msg_get_empty
        bl      printf
        b       menu_loop

/* -------- op: LIST -------- */
op_list:
        LADR    x0, msg_list_hdr
        bl      printf

        mov     x20, #0               /* linear index loop i = 0..TOT-1 */

list_loop:
        cmp     x20, #TOT
        b.hs    list_done

        /* if occ[i] == 0 skip */
        LADR    x11, occ
        add     x11, x11, x20
        ldrb    w12, [x11]
        cbz     w12, list_next

        /* load value vals[i] */
        LADR    x13, vals
        lsl     x14, x20, #3
        add     x13, x13, x14
        ldr     x15, [x13]

        /* unravel i -> (i0..i6), since each dim=3 */
        mov     x21, x20
        mov     x9,  #3

        udiv    x22, x21, x9
        msub    x27, x22, x9, x21     /* i6 */
        mov     x21, x22

        udiv    x22, x21, x9
        msub    x26, x22, x9, x21     /* i5 */
        mov     x21, x22

        udiv    x22, x21, x9
        msub    x25, x22, x9, x21     /* i4 */
        mov     x21, x22

        udiv    x22, x21, x9
        msub    x24, x22, x9, x21     /* i3 */
        mov     x21, x22

        udiv    x22, x21, x9
        msub    x23, x22, x9, x21     /* i2 */
        mov     x21, x22

        udiv    x22, x21, x9
        msub    x19, x22, x9, x21     /* i1 */
        mov     x18, x22              /* i0 */

        /* printf("(%llu ... %llu) = %lld\n", i0..i6, value) */
        LADR    x0, msg_list_row
        mov     x1, x18
        mov     x2, x19
        mov     x3, x23
        mov     x4, x24
        mov     x5, x25
        mov     x6, x26
        mov     x7, x27
        mov     x8, x15               /* value last on stack */
        sub     sp, sp, #16
        str     x8, [sp]
        bl      printf
        add     sp, sp, #16

list_next:
        add     x20, x20, #1
        b       list_loop

list_done:
        b       menu_loop

/* -------- exit -------- */
done:
        LADR    x0, msg_bye
        bl      printf

        mov     w0, #0
        ldp     x29, x30, [sp], 16
        ret

        .size main, .-main

/* -------- data -------- */
        .section .rodata

banner:
        .asciz  "\n7D Array Demo (AArch64 asm + libc)\nDims: 3x3x3x3x3x3x3 (2187 cells)\n\n"

menu:
        .asciz  "Menu:\n  1) Insert (only if empty)\n  2) Edit (only if occupied)\n  3) Delete\n  4) Get\n  5) List occupied\n  0) Exit\nChoice: "

prompt_insert:
        .asciz  "Enter i0 i1 i2 i3 i4 i5 i6 value : "
prompt_edit:
        .asciz  "Enter i0 i1 i2 i3 i4 i5 i6 new_value : "
prompt_delete:
        .asciz  "Enter i0 i1 i2 i3 i4 i5 i6 : "
prompt_get:
        .asciz  "Enter i0 i1 i2 i3 i4 i5 i6 : "

fmt_choice:
        .asciz  "%d"
fmt_indices:
        .asciz  "%llu %llu %llu %llu %llu %llu %llu"
fmt_insert:
        .asciz  "%llu %llu %llu %llu %llu %llu %llu %lld"

msg_unknown:
        .asciz  "Unknown choice.\n"
msg_scan_fail:
        .asciz  "Input parse failed. Try again.\n"
msg_bounds:
        .asciz  "Bounds error: each index must be 0..2.\n"
msg_occupied:
        .asciz  "Insert failed: cell is already occupied.\n"
msg_empty:
        .asciz  "Cell is empty.\n"
msg_insert_ok:
        .asciz  "Inserted.\n"
msg_edit_ok:
        .asciz  "Edited.\n"
msg_delete_ok:
        .asciz  "Deleted.\n"

msg_get_empty:
        .asciz  "Cell [%llu,%llu,%llu,%llu,%llu,%llu,%llu] is <empty>.\n"
msg_get_val:
        .asciz  "Value at [%llu,%llu,%llu,%llu,%llu,%llu,%llu] = %lld\n"

msg_list_hdr:
        .asciz  "Occupied cells:\n"
msg_list_row:
        .asciz  "  (%llu,%llu,%llu,%llu,%llu,%llu,%llu) = %lld\n"

msg_bye:
        .asciz  "Bye.\n"

/* -------- storage -------- */
        .bss
        .align  3
idx:
        .skip   56              /* 7 * 8 bytes */
val:
        .skip   8
        .align  2
choice:
        .skip   4

        .align  3
vals:
        .skip   (TOT*8)         /* int64 values */
occ:
        .skip   TOT             /* occupancy bytes */
userland@localhost:~$ l
