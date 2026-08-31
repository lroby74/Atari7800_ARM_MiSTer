//============================================================================
// thumb3 - shared definitions
//
// Micro-operations and the fields of the control word the decoder produces.
// SystemVerilog-2005 only: no packages, no structs, no enums, no always_comb.
//============================================================================
`ifndef THUMB3_DEFS_VH
`define THUMB3_DEFS_VH

// ---- micro-operations ------------------------------------------------------
`define U_NOP    6'd0
`define U_MOV    6'd1
`define U_ADD    6'd2
`define U_SUB    6'd3
`define U_ADC    6'd4
`define U_SBC    6'd5
`define U_AND    6'd6
`define U_ORR    6'd7
`define U_EOR    6'd8
`define U_BIC    6'd9
`define U_MVN    6'd10
`define U_CMP    6'd11
`define U_CMN    6'd12
`define U_TST    6'd13
`define U_NEG    6'd14
`define U_LSL    6'd15
`define U_LSR    6'd16
`define U_ASR    6'd17
`define U_ROR    6'd18
`define U_MUL    6'd19
`define U_SXTB   6'd20
`define U_SXTH   6'd21
`define U_UXTB   6'd22
`define U_UXTH   6'd23
`define U_REV    6'd24
`define U_REV16  6'd25
`define U_REVSH  6'd26
`define U_LOAD   6'd27
`define U_STORE  6'd28
`define U_BLOCK  6'd29
`define U_BRANCH 6'd30   // pc-relative branch, conditional or not
`define U_BX     6'd31   // branch to a register (BX, and the low half of BL)
`define U_BLPFX  6'd32   // first half of BL: LR = PC + (offset << 12)
`define U_SWI    6'd33
`define U_UNDEF  6'd34

// ---- memory access size ----------------------------------------------------
`define SZ_BYTE  2'd0
`define SZ_HALF  2'd1
`define SZ_WORD  2'd2

// ---- named registers -------------------------------------------------------
`define R_SP     4'd13
`define R_LR     4'd14
`define R_PC     4'd15

// ---- bits of the set_flag mask ---------------------------------------------
//      [3]=N [2]=Z [1]=C [0]=V
`define F_NONE   4'b0000
`define F_NZ     4'b1100
`define F_NZC    4'b1110
`define F_NZCV   4'b1111

`endif
