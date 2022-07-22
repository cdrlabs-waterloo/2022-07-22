`default_nettype none

module hgo_top(
  input  wire HGO_TCK,
  input  wire HGO_TMS,
  input  wire HGO_TDI,
  output wire HGO_TDO,
  input  wire HGO_RSTN,
  output wire HGO_SAVE,
  output wire HGO_DONE);

  reg  [1:0] rst_n_sync;
  wire       rst_n;

  wire jtag_tck;
  wire jtag_tms;
  wire jtag_tdi;
  wire jtag_tdo;

  wire clk;
  wire clk_smp;
  wire clk_ncm;
  wire clk_msk;

  wire         go;
  wire [ 55:0] chl_seed;
  wire [ 55:0] key1;
  wire [ 55:0] key2;
  wire [ 55:0] erchl;
  wire [ 55:0] seed56;
  wire [  7:0] seed8;
  wire [ 10:0] seed11;
  wire [ 15:0] scc_end;
  wire [ 15:0] scc_begin;
  wire [ 15:0] evx;
  wire [  7:0] chx;
  wire [  7:0] grd;
  wire [  3:0] rpt;
  wire         use_seed;
  wire         use_clkrnd;
  wire [  1:0] arc;
  wire [ 55:0] state1;
  wire [ 55:0] state2;
  wire [ 15:0] stat;
  wire [127:0] auth;
  wire         save;
  wire         done;
  wire         osc_en;
  wire         clk_en;
  wire         smp_en;
  wire         ncm_en;
  wire         msk_en;
  wire [  2:0] clk_div;

  tst U_TST (
    .tck          ( jtag_tck   ) ,
    .tms          ( jtag_tms   ) ,
    .tdi          ( jtag_tdi   ) ,
    .tdo          ( jtag_tdo   ) ,
    .rst_n        ( rst_n      ) ,
    .o_osc_en     ( osc_en     ) ,
    .o_clk_en     ( clk_en     ) ,
    .o_smp_en     ( smp_en     ) ,
    .o_ncm_en     ( ncm_en     ) ,
    .o_msk_en     ( msk_en     ) ,
    .o_clk_div    ( clk_div    ) ,
    .o_go         ( go         ) ,
    .o_chl_seed   ( chl_seed   ) ,
    .o_key1       ( key1       ) ,
    .o_key2       ( key2       ) ,
    .o_erchl      ( erchl      ) ,
    .o_seed56     ( seed56     ) ,
    .o_seed8      ( seed8      ) ,
    .o_seed11     ( seed11     ) ,
    .o_scc_end    ( scc_end    ) ,
    .o_scc_begin  ( scc_begin  ) ,
    .o_evx        ( evx        ) ,
    .o_chx        ( chx        ) ,
    .o_grd        ( grd        ) ,
    .o_rpt        ( rpt        ) ,
    .o_use_seed   ( use_seed   ) ,
    .o_use_clkrnd ( use_clkrnd ) ,
    .o_arc        ( arc        ) ,
    .i_state1     ( state1     ) ,
    .i_state2     ( state2     ) ,
    .i_stat       ( stat       ) ,
    .i_auth       ( auth       ) ,
    .i_save       ( save       ) ,
    .i_done       ( done       ) );

  clkg U_CLKG (
    .clk_jtag  ( jtag_tck ) ,
    .rst_n     ( rst_n    ) ,
    .i_osc_en  ( osc_en   ) ,
    .i_clk_en  ( clk_en   ) ,
    .i_smp_en  ( smp_en   ) ,
    .i_ncm_en  ( ncm_en   ) ,
    .i_msk_en  ( msk_en   ) ,
    .i_clk_div ( clk_div  ) ,
    .o_clk     ( clk      ) ,
    .o_clk_smp ( clk_smp  ) ,
    .o_clk_ncm ( clk_ncm  ) ,
    .o_clk_msk ( clk_msk  ) );

  puf U_PUF (
    .clk          ( clk        ) ,
    .rst_n        ( rst_n      ) ,
    .i_go         ( go         ) ,
    .i_chl_seed   ( chl_seed   ) ,
    .i_key1       ( key1       ) ,
    .i_key2       ( key2       ) ,
    .i_erchl      ( erchl      ) ,
    .i_seed56     ( seed56      ) ,
    .i_seed8      ( seed8      ) ,
    .i_seed11     ( seed11     ) ,
    .i_scc_end    ( scc_end    ) ,
    .i_scc_begin  ( scc_begin  ) ,
    .i_evx        ( evx        ) ,
    .i_chx        ( chx        ) ,
    .i_grd        ( grd        ) ,
    .i_rpt        ( rpt        ) ,
    .i_use_seed   ( use_seed   ) ,
    .i_use_clkrnd ( use_clkrnd ) ,
    .i_arc        ( arc        ) ,
    .i_clk_smp    ( clk_smp    ) ,
    .i_clk_ncm    ( clk_ncm    ) ,
    .i_clk_msk    ( clk_msk    ) ,
    .o_state1     ( state1     ) ,
    .o_state2     ( state2     ) ,
    .o_stat       ( stat       ) ,
    .o_auth       ( auth       ) ,
    .o_save       ( save       ) ,
    .o_done       ( done       ) );

  assign jtag_tck = HGO_TCK;
  assign jtag_tms = HGO_TMS;
  assign jtag_tdi = HGO_TDI;
  assign HGO_TDO = jtag_tdo;
  assign HGO_SAVE = save;
  assign HGO_DONE = done;
  assign rst_n = rst_n_sync[1];

  always @(posedge jtag_tck or negedge HGO_RSTN)
    if (!HGO_RSTN) rst_n_sync <= 2'b0;
    else           rst_n_sync <= {rst_n_sync[0], 1'b1};

endmodule

