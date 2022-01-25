`timescale 1ns/1ns

// Example of memonic names and bit fields for two pipeline register fields.

`define insField 31:0
`define PCField  212:181

// Add  remaining symbolic names and bit fields for the pipeline registers.
`define opcodeField     31:26
`define rsField         25:21
`define rtField         20:16
`define offsetField     137:106
`define controlField    36:32
`define isLoadField     34
`define isStoreField    35
`define isBranchField   36
`define op1Field        68:37
`define op2Field        100:69
`define rdField         105:101
`define weField         175
`define isHaltField     174
`define branchCondField 173
`define writeDataField  255:224
`define addressField    169:138


module processor (
       input CLK_pi,
       input CPU_RESET_pi
);

   // Defining four pipeline registers each 256 bits wide.
   // pipeReg1 (IF/ID), pipeReg2 (ID/EX), pipeReg3 (EX/MEM), pipeReg4 (MEMEB)

   reg [255:0] pipeReg1, pipeReg2, pipeReg3, pipeReg4;

   always @(posedge CLK_pi) begin

      // On reset, clear all bits of the pipeline registers
      if (CPU_RESET_pi) begin
	 pipeReg1 <= 256'b0;
	 pipeReg2 <= 256'b0;
	 pipeReg3 <= 256'b0;
	 pipeReg4 <= 256'b0;
      end

      else begin

	 // Add code to manage pipeline registers in noral operation

 	 // Update fields of pipeReg1  (Done for you)
	 pipeReg1[`insField]  <= instruction;
	 pipeReg1[`PCField]   <= currentPC;

	 // Update fields of pipeReg2
	 pipeReg2[`PCField]      <= pipeReg1[`PCField];
	 pipeReg2[`opcodeField]  <= aluFunc;
	 pipeReg2[`rsField]      <= rs;
	 pipeReg2[`rtField]      <= rt;
	 pipeReg2[`offsetField]  <= offset;
	 pipeReg2[`controlField] <= control;
	 pipeReg2[`rdField]      <= rd;
	 pipeReg2[`weField]      <= we;
	 pipeReg2[`isHaltField]  <= isHalt;
	 pipeReg2[`op1Field]	 <= op1;
	 pipeReg2[`op2Field]     <= op2;

	 // Update fields of pipeReg3
	 pipeReg3[`PCField]      <= pipeReg2[`PCField];
	 pipeReg3[`offsetField]  <= pipeReg2[`offsetField];
	 pipeReg3[`controlField] <= pipeReg2[`controlField];
	 pipeReg3[`rdField]      <= pipeReg2[`rdField];
	 pipeReg3[`weField]      <= pipeReg2[`weField];
	 pipeReg3[`isHaltField]  <= pipeReg2[`isHaltField];
	 pipeReg3[`op1Field]	 <= pipeReg2[`op1Field];
	 pipeReg3[`op2Field]     <= pipeReg2[`op2Field];
     pipeReg3[`addressField] <= aluResult;
     pipeReg3[`branchCondField] <= pipeReg2[`op1Field] != 0;

	 // Update fields of pipeReg4
	 pipeReg4[`PCField]      <= pipeReg3[`PCField];
	 pipeReg4[`weField]      <= pipeReg3[`weField];
	 pipeReg4[`isHaltField]  <= pipeReg3[`isHaltField];
	 pipeReg4[`rdField]      <= pipeReg3[`rdField];
	 pipeReg4[`writeDataField] <= pipeReg3[`isLoadField] ? loadData : pipeReg3[`addressField];

      end
end


   // Suggestion: Define auxuliary wire variables to identify pipeline register
   // signals that are routed to modules. That will avoid having complicated
   // pipeline register indexes as arguments in  module instantiations. These
   // auxiliary signals can be set using simple "assign" statements.



   // Instantiate the  function unit modules and connect them up. The insMem
   // module is done for you below.


   wire we, isHalt, itb, branchCond;
   wire [5:0] aluFunc;
   wire [4:0] rs, rt, control, rd;
   wire [31:0] offset, op1, op2, aluResult, tPC, loadData;
   wire [31:0] currentPC;    //  Wire  from IF stage to pipeReg1
   wire [31:0] instruction;  //  Wire  from IF stage to pipeReg1

insMem  myInstructionMem(
.pc_pi(currentPC),
.instruction_po(instruction)
);


decode myDecoder(
.instr_pi(pipeReg1[`insField]),
.opCode_po(aluFunc),            // op code
.rs_po(rs),                     // rs
.rt_po(rt),                     // rt
.offset_po(offset),             // offset
.control_po(control),           // {Branch, Store, Load, ADDI, ADD}
.destReg_po(rd),                // NOT a real rd: ADD -> rd, ADDI/LOAD -> rt
.writeEnable_po(we),            // ADD/ADDI/LOAD: True, STORE, BNEZ: False
.isHalt_po(isHalt)              // HALT
);


regFile  myRegFile(
.clk_pi(CLK_pi),
.reset_pi(CPU_RESET_pi),
.reg1_pi(pipeReg1[`rsField]),
.reg2_pi(pipeReg1[`rtField]),
.destReg_pi(pipeReg4[`rdField]),
.we_pi(pipeReg4[`weField]),
.writeData_pi(pipeReg4[`writeDataField]),
.operand1_po(op1),              // rs is sign-extended to op1
.operand2_po(op2)               // rt is sign-extended to op2
);

execute  myExecute(
.op1_pi(pipeReg2[`op1Field]),
.op2_pi(pipeReg2[`op2Field]),
.aluFunc_pi(pipeReg2[`opcodeField]),
.offset_pi(pipeReg2[`offsetField]),
.aluResult_po(aluResult)        // The sume of op1 and op2 or the address to load/store data
);

dataMem myDataMem(
.clk_pi(CLK_pi),
.reset_pi(CPU_RESET_pi),
.load_pi(pipeReg3[`isLoadField]),
.store_pi(pipeReg3[`isStoreField]),
.address_pi(pipeReg3[`addressField]),         // Memory location with value in op2 and offset
.storeData_pi(pipeReg3[`op2Field]),             // The data from rt
.loadData_po(loadData)          // If we load data, it will be written to rt
);

branchPC  myBranch(
.currentPC_pi(pipeReg3[`PCField]),
.branchCondTrue_pi(pipeReg3[`branchCondField]),
.isBranch_pi(pipeReg3[`isBranchField]),
.branchOffset_pi(pipeReg3[`offsetField]),
.isTakenBranch_po(itb),         // If BNEZ, then go to target PC in myPC
.targetPC_po(tPC)               // The target PC after BNEZ
);

PC  myPC(
.clk_pi(CLK_pi),
.reset_pi(CPU_RESET_pi),
.halt_pi(pipeReg4[`isHaltField]),
.isTakenBranch_pi(itb),
.targetPC_pi(tPC),
.pc_po(currentPC)               // The current PC
);


endmodule
