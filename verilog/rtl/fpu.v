// SPDX-FileCopyrightText: 2023 Desrep
// SPDX-FileCopyrightText: 2024 jjimenezu
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//      http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.
// SPDX-License-Identifier: Apache-2.0

// Changes by jjimenezu: adapted fpu interfaces to user_project_wrapper IO and LA.

// It contains addition, multiplication, division,square root and fp compare.
// 32 (single precision) bit Floating point unit
// Need to find a way to generate the Done flag correctly
// This is the top level instantiation
// `include "special_characters.v"   //MOD: coment includes in all files except special_characters in other files
// `include "fp_mul.v"
// `include "fp_div.v"
// `include "fp_comp.v"
// `include "fp_add.v"
// `include "fp_sqr.v"

`default_nettype none

module fpu #(
    parameter BITS = 32
)(
`ifdef USE_POWER_PINS
    inout vccd1,	// User area 1 1.8V supply
    inout vssd1,	// User area 1 digital ground
`endif

    // Wishbone Slave ports (WB MI A)
    input wb_clk_i,
    input wb_rst_i,
    input wbs_stb_i,
    input wbs_cyc_i,
    input wbs_we_i,
    input [3:0] wbs_sel_i,
    input [31:0] wbs_dat_i,
    input [31:0] wbs_adr_i,
    output wbs_ack_o,
    output [31:0] wbs_dat_o,

    // Logic Analyzer Signals
    input  [127:0] la_data_in,
    output [127:0] la_data_out,
    input  [127:0] la_oenb,

    // IOs
    input  [37:0] io_in,
    output reg [37:0] io_out,
    output reg [37:0] io_oeb,  // output enable when io_oeb = 0

    // IRQ
    output [2:0] irq
);


//***** IO index ******//

// unused outputs
assign wbs_dat_o =  32'h0000_0000;
assign wbs_ack_o = 1'b0;
assign irq = 3'b000;
// todo: try harden the desing whitout unused inputs and outputs

wire clk;
wire [2:0] select;

//              clk_select    clk_extern
assign clk = (io_in[33]) ? io_in[34]: wb_clk_i;
assign select = io_in[37:35];


reg rstp;
reg [31:0] in1p, in2p;
reg  act;
reg [2:0] round_mp;    // rounding mode selector
reg [2:0] opcode;      // 1 = mul, 0 = add, 2 = division, 3 = square root, 4 = compare

always @* begin

  // select input from IO always io_oeb = 1
  io_oeb[37:32] = {6{1'b1}};
  io_out[37:32] = {6{1'b0}};

  // Input-Output modes between fpu and user_project_wrapper interfaces
  case (select)
    // 0: LA mode.
    3'b000: begin
      in1p         = la_data_in[31:0];
      in2p         = la_data_in[63:32];
      act          = la_data_in[66];
      opcode       = la_data_in[70:68];
      round_mp     = la_data_in[74:72];
      io_out[31:0] = out0;
      io_oeb[31:0] = 32'h0000_0000;
      rstp         = la_data_in[64];
    end

    // 1: Flags
    3'b001: begin
      io_out[31:0] = {done0,inexact0,ov0,un0,less1,eq1,great1,inv0,div_zero0,{(32-9){1'b0}}};
      io_oeb[31:0] = 32'h0000_0000;
      rstp         = io_in[32];
    end

    // 2: In1
    3'b010: begin
      in1p  = io_in[31:0];
      io_oeb[31:0] = 32'hffff_ffff;
      rstp         = io_in[32];
    end

    // 3: Out
    3'b011: begin
      io_out[31:0] = out0;
      io_oeb[31:0] = 32'h0000_0000;
      rstp         = io_in[32];
    end

    // 4: Control
    3'b100: begin
      opcode       = io_in[31:29];
      act          = io_in[28];
      round_mp     = io_in[27:25];
      rstp         = io_in[32];
      io_oeb[31:0] = 32'hffff_ffff;
    end

    // 5: Out
    3'b101: begin
      io_out[31:0] = out0;
      io_oeb[31:0] = 32'h0000_0000;
      rstp         = io_in[32];
    end

    // 6: In2
    3'b110: begin  
      in2p   = io_in[31:0];
      io_oeb[31:0] = 32'hffff_ffff;
      rstp         = io_in[32];
    end

    // 7: Flags
    3'b111: begin 
      io_out[31:0] = {done0,inexact0,ov0,un0,less1,eq1,great1,inv0,div_zero0,{(32-9){1'b0}}};
      io_oeb[31:0] = 32'h0000_0000;
      rstp         = io_in[32];
    end

    // Default: LA
    default: begin  
      in1p         = la_data_in[31:0];
      in2p         = la_data_in[63:32];
      act          = la_data_in[66];
      opcode       = la_data_in[70:68];
      round_mp     = la_data_in[74:72];
      io_out[31:0] = out0;
      io_oeb[31:0] = 32'h0000_0000;
      rstp         = la_data_in[64];
    end
  endcase
end


// **** FPU mux ****//

reg [31:0] out0;
reg [31:0] in1pa,in2pa,in1pm,in2pm,in1pc,in2pc,in1pd,in2pd,in1ps;
wire [31:0] aout,mout,dout,sout;
wire aov,aun,mov,mun,dov,dun,sov,sun,eq0,less0,great0;
wire inva,invm,invd,invs,div_zerod,invc;
wire inexacta,inexactm,inexactd,inexacts;
reg ov0,un0,done0,inv0,inexact0,div_zero0;
wire adone,mdone,cdone,ddone,sdone;
reg eq1,less1,great1;
// reg clka, clkm, clkd, clks;

  //add
  fp_add addu(
    `ifdef USE_POWER_PINS
      .vccd1(vccd1),	// User area 1 1.8V power
      .vssd1(vssd1),	// User area 1 digital ground
    `endif
    .in1(in1pa),.in2(in2pa),.out(aout),.ov(aov),.un(aun),.clk(clk),.rst(rstp),.round_m(round_mp),.done(adone),.inv(inva),.inexact(inexacta));

  // //mul
  fp_mul mulu(
    `ifdef USE_POWER_PINS
      .vccd1(vccd1),	// User area 1 1.8V power
      .vssd1(vssd1),	// User area 1 digital ground
    `endif
    .in1(in1pm),.in2(in2pm),.out(mout),.ov(mov),.un(mun),.clk(clk),.rst(rstp),.round_m(round_mp),.act(act),.done(mdone),.inv(invm),.inexact(inexactm));

  // // //compare
  fp_comp com1(
    `ifdef USE_POWER_PINS
      .vccd1(vccd1),	// User area 1 1.8V power
      .vssd1(vssd1),	// User area 1 digital ground
    `endif
    .in1(in1pc),.in2(in2pc),.eq(eq0),.great(great0),.less(less0),.act(act),.done(cdone),.clk(clk),.rst(rstp),.inv(invc));

  // // division
  fp_div dv1(
    `ifdef USE_POWER_PINS
      .vccd1(vccd1),	// User area 1 1.8V power
      .vssd1(vssd1),	// User area 1 digital ground
    `endif
    .in1(in1pd),.in2(in2pd),.out(dout),.ov(dov),.un(dun),.rst(rstp),.clk(clk),.round_m(round_mp),.act(act),.done(ddone),.inv(invd),.inexact(inexactd),.div_zero(div_zerod));

  // //square root
   fp_sqr   sqr1(
    `ifdef USE_POWER_PINS
      .vccd1(vccd1),	// User area 1 1.8V power
      .vssd1(vssd1),	// User area 1 digital ground
    `endif
    .in1(in1ps),.out(sout),.ov(sov),.un(sun),.clk(clk),.rst(rstp),.round_m(round_mp),.act(act),.done(sdone),.inv(invs),.inexact(inexacts));

  // Select inputs and outputs depending on the operation
always @* begin

  case (opcode)
    0: begin
      out0 = aout;
      ov0= aov;
      un0= aun;
      done0 = adone;
      in1pa = in1p;
      in2pa = in2p;
      in1pm = 0;
      in2pm = 0;
      in1pc = in1p;
      in2pc = in2p;
      in1pd = 0;
      in2pd = 0;
      in1ps = 0;
      eq1 = eq0;
      great1  = great0;
      less1 = less0;
      inv0 = inva;
      inexact0 = inexacta;
      div_zero0 = 0;
    end
    1: begin
      out0 = mout;
      ov0 = mov;
      un0 = mun;
      done0 = mdone;
      in1pa = 0;
      in2pa = 0;
      in1pm = in1p;
      in2pm = in2p;
      in1pc = 0;
      in2pc = 0;
      in1pd = 0;
      in2pd = 0;
      in1ps = 0;
      eq1 = 0;
      great1  = 0;
      less1 = 0;
      inv0 = invm;
      inexact0 = inexactm;
      div_zero0 = 0;
    end
    2: begin
      out0 = dout;
      ov0 = dov;
      un0 = dun;
      done0 = ddone;
      in1pa = 0;
      in2pa = 0;
      in1pm = 0;
      in2pm = 0;
      in1pc = 0;
      in2pc = 0;
      eq1 = 0;
      great1  = 0;
      less1 = 0;
      in1pd = in1p;
      in2pd = in2p;
      in1ps = 0;
       inv0 = invd;
      inexact0 = inexactd;
      div_zero0 = div_zerod;
    end
    3: begin
      out0 = sout;
      ov0 = sov;
      un0 = sun;
      done0 = sdone;
      in1pa = 0;
      in2pa = 0;
      in1pm = 0;
      in2pm = 0;
      in1pc = 0;
      in2pc = 0;
      in1pd = 0;
      in2pd = 0;
      eq1 = 0;
      great1  = 0;
      less1 = 0;
      in1ps = in1p;
      inv0 = invs;
      inexact0 = inexacts;
      div_zero0 = 0;
    end
    4: begin
      out0 = 0;
      ov0 = sov;
      un0 = sun;
      in1pa = 0;
      in2pa = 0;
      in1pm = 0;
      in2pm = 0;
      in1pc = in1p;
      in2pc = in2p;
      in1pd = 0;
      in2pd = 0;
      in1ps = 0;
      eq1 = 0;
      great1  = 0;
      less1 = 0;
      inv0 = invc;
      inexact0 = inexacta;
      div_zero0 = 0;
    end

   default : begin
    out0 = aout;
    ov0= aov;
    un0= aun;
    done0 = adone;
    in1pa = in1p;
    in2pa = in2p;
    in1pm = 0;
    in2pm = 0;
    in1pc = 0;
    in2pc = 0;
    in1pd = 0;
    in2pd = 0;
    in1ps = 0;
    eq1 = eq0;
    great1  = 0;
    less1 = 0;
    inv0 = 0;
    inexact0 = 0;
    div_zero0 = 0;
   end
  endcase

end

// always @*
// begin
//   la_data_out = {out0,done0,inexact0,ov0,un0,less1,eq1,great1,inv0,div_zero0,{(128-41){1'b0}}};
// end

assign la_data_out = {out0,done0,inexact0,ov0,un0,less1,eq1,great1,inv0,div_zero0,{(128-41){1'b0}}};

endmodule

`default_nettype wire
