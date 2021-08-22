\m4_TLV_version 1d: tl-x.org
\SV
   // This code can be found in: https://github.com/stevehoover/LF-Building-a-RISC-V-CPU-Core/risc-v_shell.tlv
   
   m4_include_lib(['https://raw.githubusercontent.com/stevehoover/warp-v_includes/1d1023ccf8e7b0a8cf8e8fc4f0a823ebb61008e3/risc-v_defs.tlv'])
   m4_include_lib(['https://raw.githubusercontent.com/stevehoover/LF-Building-a-RISC-V-CPU-Core/main/lib/risc-v_shell_lib.tlv'])



   //---------------------------------------------------------------------------------
   // /====================\
   // | Sum 1 to 9 Program |
   // \====================/
   //
   // Program to test RV32I
   // Add 1,2,3,...,9 (in that order).
   //
   // Regs:
   //  x12 (a2): 10
   //  x13 (a3): 1..10
   //  x14 (a4): Sum
   // 
   //m4_asm(ADDI, x14, x0, 0)             // Initialize sum register a4 with 0
   //m4_asm(ADDI, x12, x0, 1010)          // Store count of 10 in register a2.
   //m4_asm(ADDI, x13, x0, 1)             // Initialize loop count register a3 with 0
   // Loop:
   //m4_asm(ADD, x14, x13, x14)           // Incremental summation
   //m4_asm(ADDI, x13, x13, 1)            // Increment loop count by 1
   //m4_asm(BLT, x13, x12, 1111111111000) // If a3 is less than a2, branch to label named <loop>
   // Test result value in x14, and set x31 to reflect pass/fail.
   //m4_asm(ADDI, x30, x14, 111111010100) // Subtract expected value of 44 to set x30 to 1 if and only iff the result is 45 (1 + 2 + ... + 9).
   //m4_asm(BGE, x0, x0, 0) // Done. Jump to itself (infinite loop). (Up to 20-bit signed immediate plus implicit 0 bit (unlike JALR) provides byte address; last immediate bit should also be 0)
   //m4_asm_end()
   //m4_define(['M4_MAX_CYC'], 50)
   m4_test_prog()
   //---------------------------------------------------------------------------------



\SV
   m4_makerchip_module   // (Expanded in Nav-TLV pane.)
   /* verilator lint_on WIDTH */
\TLV
   
   $reset = *reset;
   
   //$next_pc[31:0] =  $reset ? '0:
   //                  $pc + 32'd4;
   $next_pc[31:0] = $taken_br ? $br_tgt_pc :
                    $reset ? '0 : $pc + 32'd4;
   $pc[31:0] = >>1$next_pc;
   
   //2 - IMEM - Read
   `READONLY_MEM($pc, $$instr[31:0])
   
   //3 - Decode Logic
   $is_u_instr = $instr[6:2] ==? 5'b0x101;
   
   $is_b_instr = $instr[6:2] == 5'b11000;
   
   $is_i_instr = $instr[6:2] ==? 5'b0000x ||
                 $instr[6:2] ==? 5'b001x0 ||
                 $instr[6:2] == 5'b11001;
   
   $is_r_instr = $instr[6:2] == 5'b01011 ||
                 $instr[6:2] ==? 5'b011x0 ||
                 $instr[6:2] == 5'b10100;
   
   $is_s_instr = $instr[6:2] ==? 5'b0100x;
   
   $is_j_instr = $instr[6:2] == 5'b11011;
   
   //4 - Extract instruction fields
   $funct7[6:0]   =  $instr[31:25];
   $funct3[2:0]   =  $instr[14:12];
   $rs1[4:0]      =  $instr[19:15];
   $rs2[4:0]      =  $instr[24:20];
   $rd[4:0]       =  $instr[11:7];
   $opcode[6:0]   =  $instr[6:0];
   `BOGUS_USE($funct7 $funct3 $rs1 $rs2 $rd $opcode)
   
   $rs2_valid = $is_r_instr || $is_s_instr || $is_b_instr;
   $rs1_valid = $is_r_instr || $is_i_instr || $is_s_instr || $is_b_instr;
   $funct3_valid = $is_r_instr || $is_i_instr || $is_s_instr || $is_b_instr;
   $rd_valid =  $is_r_instr || $is_i_instr || $is_u_instr || $is_j_instr;
   $imm_valid = $is_i_instr || $is_s_instr || $is_b_instr || $is_u_instr || $is_j_instr;
   `BOGUS_USE($funct7_valid $funct3_valid $rs1_valid $rs2_valid $rd_valid $imm_valid)
   
    //5 - Imm 
   $imm[31:0]  =  $is_i_instr ?  {{21{$instr[31]}}, $instr[30:20]}                                  :
                  $is_s_instr ?  {{21{$instr[31]}}, $instr[30:25], $instr[11:7]}                    :
                  $is_b_instr ?  {{20{$instr[31]}}, $instr[7], $instr[30:25], $instr[11:8], 1'b0}   :
                  $is_u_instr ?  {$instr[31:12], 12'b0}                                             :
                  $is_j_instr ?  {{12{$instr[31]}}, $instr[19:12], $instr[20], $instr[30:21], 1'b0} :
                                 32'b0 ;
   `BOGUS_USE($imm)
   
   //6 - Decode Logic: Instruction
   $dec_bits[10:0]   =  {$funct7[5], $funct3, $opcode};
   // Instructions for branch conditions
   $is_beq           =  $dec_bits ==? 11'bx_000_1100011;
   $is_bne           =  $dec_bits ==? 11'bx_001_1100011;
   $is_blt           =  $dec_bits ==? 11'bx_100_1100011;
   $is_bge           =  $dec_bits ==? 11'bx_101_1100011;
   $is_bltu          =  $dec_bits ==? 11'bx_110_1100011;
   $is_bgeu          =  $dec_bits ==? 11'bx_111_1100011;
   // Instructions using the ALU
   $is_addi          =  $dec_bits ==? 11'bx_000_0010011;
   $is_slti          =  $dec_bits ==? 11'bx_010_0010011;
   $is_sltiu         =  $dec_bits ==? 11'bx_011_0010011;
   $is_ori           =  $dec_bits ==? 11'bx_110_0010011;
   $is_andi          =  $dec_bits ==? 11'bx_111_0010011;
   $is_slli          =  $dec_bits ==? 11'b0_001_0010011;
   $is_srli          =  $dec_bits ==? 11'b0_101_0010011;
   $is_srai          =  $dec_bits ==? 11'b1_101_0010011;
   
   $is_add           =  $dec_bits ==? 11'b0_000_0110011;
   $is_lui           =  $dec_bits ==? 11'bx_xxx_0110111;
   $is_auipc         =  $dec_bits ==? 11'bx_xxx_0010111;
   $is_jal           =  $dec_bits ==? 11'bx_xxx_1101111;
   $is_jalr          =  $dec_bits ==? 11'bx_000_1100111;
   $is_sub           =  $dec_bits ==? 11'b1_000_0110011;
   $is_sll           =  $dec_bits ==? 11'b0_001_0110011;
   $is_slt           =  $dec_bits ==? 11'b0_010_0110011;
   `BOGUS_USE($is_beq $is_bne $is_blt $is_bge $is_bltu $is_bgeu $is_addi $is_add)
   
   // 7 ALU
   $result[31:0] =
    $is_addi ? $src1_value + $imm :
    $is_add  ? $src1_value + $src2_value:
               32'b0;
   // SLTU and SLTI (set if less than, unsigned) results:
   $sltu_rslt[31:0]  = {31'b0, $src1_value < $src2_value};
   $sltiu_rslt[31:0] = {31'b0, $src1_value < $imm};
   
   // SRA and SRAI (shift right, arithmetic) results:
   //  sign-extended src1
   $sext_src1[63:0] =  { {32{$src1_value[31]}}, $src1_value };
   //  64-bit sign-extended results, to be truncated
   $sra_rslt[63:0] =   $sext_src1 >> $src2_value[4:0];
   $srai_rslt[63:0] =  $sext_src1 >> $imm[4:0];
   
   // 8 Branch
   $taken_br = $is_beq  ? $src1_value == $src1_value :
               $is_bne  ? $src1_value != $src1_value :
               $is_blt  ? ($src1_value < $src2_value) ^ ($src1_value[31] != $src2_value[31]) :
               $is_bge  ? ($src1_value >= $src2_value2) ^ ($src1_value[31] != $src2_value[31]) :
               $is_bltu ? $src1_value < $src2_value :
               $is_bgeu ? $src1_value >= $src2_value: 1'b0;
   // The target PC is the PC of the branch plus its immediate value
   $br_tgt_pc[31:0] = $pc + $imm;
   
   
   // Assert these to end simulation (before Makerchip cycle limit).
   // *passed = 1'b0;
   m4+tb()
   *failed = *cyc_cnt > M4_MAX_CYC;
   
   // Deassert any values written to destination register x0 (it always have to be Zero)
   $rd_valid = $rd[4:0] == 5'b0 ? 0 : $rd_valid;
   
   // m4+rf(32, 32, $reset, $wr_en, $wr_index[4:0], $wr_data[31:0], $rs1_valid, $rs1, $src1_value, $rs2_valid, $rs2, $src2_value)
   m4+rf(32, 32, $reset, $rd_valid, $rd[4:0], $result[31:0], $rs1_valid, $rs1, $src1_value, $rs2_valid, $rs2, $src2_value)
   m4+dmem(32, 32, $reset, $addr[4:0], $wr_en, $wr_data[31:0], $rd_en, $rd_data)
   m4+cpu_viz()
\SV
   endmodule
