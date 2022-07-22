`default_nettype none

module clkdiv256(input wire clk,
                 input wire rst_n,
                 output reg o_clk_div2,
                 output reg o_clk_div4,
                 output reg o_clk_div8,
                 output reg o_clk_div16,
                 output reg o_clk_div32,
                 output reg o_clk_div64,
                 output reg o_clk_div128,
                 output reg o_clk_div256);

  always @(posedge clk or negedge rst_n)
    if (!rst_n) o_clk_div2 <= 1'b0;
    else        o_clk_div2 <= ~o_clk_div2;

  always @(posedge o_clk_div2 or negedge rst_n)
    if (!rst_n) o_clk_div4 <= 1'b0;
    else        o_clk_div4 <= ~o_clk_div4;

  always @(posedge o_clk_div4 or negedge rst_n)
    if (!rst_n) o_clk_div8 <= 1'b0;
    else        o_clk_div8 <= ~o_clk_div8;

  always @(posedge o_clk_div8 or negedge rst_n)
    if (!rst_n) o_clk_div16 <= 1'b0;
    else        o_clk_div16 <= ~o_clk_div16;

  always @(posedge o_clk_div16 or negedge rst_n)
    if (!rst_n) o_clk_div32 <= 1'b0;
    else        o_clk_div32 <= ~o_clk_div32;

  always @(posedge o_clk_div32 or negedge rst_n)
    if (!rst_n) o_clk_div64 <= 1'b0;
    else        o_clk_div64 <= ~o_clk_div64;

  always @(posedge o_clk_div64 or negedge rst_n)
    if (!rst_n) o_clk_div128 <= 1'b0;
    else        o_clk_div128 <= ~o_clk_div128;

  always @(posedge o_clk_div128 or negedge rst_n)
    if (!rst_n) o_clk_div256 <= 1'b0;
    else        o_clk_div256 <= ~o_clk_div256;

endmodule

module clkdiv(input  wire       clk,
              input  wire       rst_n,
              input  wire       i_en,
              input  wire [2:0] i_div,
              output reg        o_clk_div);
              
  wire clk_pre;

  wire clk_div2;
  wire clk_div4;
  wire clk_div8;
  wire clk_div16;
  wire clk_div32;
  wire clk_div64;
  wire clk_div128;
  wire clk_div256;

  CKLNQD1 U_CLK_GATE(
    .TE ( 1'b0    ) ,
    .E  ( i_en    ) ,
    .CP ( clk     ) ,
    .Q  ( clk_pre ) );

  clkdiv256 U_CLK_DIV(
    .clk          ( clk_pre    ) ,
    .rst_n        ( rst_n      ) ,
    .o_clk_div2   ( clk_div2   ) ,
    .o_clk_div4   ( clk_div4   ) ,
    .o_clk_div8   ( clk_div8   ) ,
    .o_clk_div16  ( clk_div16  ) ,
    .o_clk_div32  ( clk_div32  ) ,
    .o_clk_div64  ( clk_div64  ) ,
    .o_clk_div128 ( clk_div128 ) ,
    .o_clk_div256 ( clk_div256 ) );

  always @*
    case (i_div)
      3'd0: o_clk_div = clk_div2;
      3'd1: o_clk_div = clk_div4;
      3'd2: o_clk_div = clk_div8;
      3'd3: o_clk_div = clk_div16;
      3'd4: o_clk_div = clk_div32;
      3'd5: o_clk_div = clk_div64;
      3'd6: o_clk_div = clk_div128;
      3'd7: o_clk_div = clk_div256;
      default: o_clk_div = clk_div2;
    endcase

endmodule

module clkg (
    input  wire        clk_jtag,    // jtag clock
    input  wire        rst_n,       // async reset
    input  wire        i_osc_en,    // oscillator enable
    input  wire        i_clk_en,    // clock enable
    input  wire        i_smp_en,    // clock smp enable
    input  wire        i_ncm_en,    // clock ncm enable
    input  wire        i_msk_en,    // clock msk enable
    input  wire [2:0]  i_clk_div,   // clock divider
    output wire        o_clk,       // output sys clock
    output wire        o_clk_smp,   // output clock for smp
    output wire        o_clk_ncm,   // output clock for ncm
    output wire        o_clk_msk);  // output clock for msk

    wire clk_osc_pre;
    wire clk_osc;
    wire clk_glitch;

    INVLONG_OSC37 U_CLK_OSC(
        .EN  ( i_osc_en     ),
        .OUT ( clk_osc_pre  ) );

    /* it is hard to tell innovus/liberate the driving strength of the
    * oscillator, puting a fixed buffer on the output is much easier */
    INVD2 U_CLK_OSC_DRV(
        .I  ( clk_osc_pre ),
        .ZN ( clk_osc     ) );

    MUX2D0 U_MUX2_JTAG_OSC(
        .I0( clk_jtag       ),
        .I1( clk_osc        ),
        .S ( i_osc_en       ),
        .Z ( clk_glitch     ) );

    clkdiv U_CLKDIV(
        .clk         ( clk_glitch ) ,
        .rst_n       ( rst_n      ) ,
        .i_en        ( i_clk_en   ) ,
        .i_div       ( i_clk_div  ) ,
        .o_clk_div   ( o_clk      ) );

    CKLNQD1 U_CLK_GATE_SMP(
        .TE ( 1'b0       ) ,
        .E  ( i_smp_en   ) ,
        .CP ( o_clk      ) ,
        .Q  ( o_clk_smp  ) );

    CKLNQD1 U_CLK_GATE_NCM(
        .TE ( 1'b0       ) ,
        .E  ( i_ncm_en   ) ,
        .CP ( o_clk      ) ,
        .Q  ( o_clk_ncm  ) );

    CKLNQD1 U_CLK_GATE_MSK(
        .TE ( 1'b0       ) ,
        .E  ( i_msk_en   ) ,
        .CP ( o_clk      ) ,
        .Q  ( o_clk_msk  ) );

endmodule

