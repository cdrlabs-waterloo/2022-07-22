`default_nettype none

module jtag_fsm(
  input wire tck,
  input wire tms,
  input wire rst_n,
  output wire state_tlr,
  output wire state_capturedr,
  output wire state_captureir,
  output wire state_shiftdr,
  output wire state_shiftir,
  output wire state_updatedr,
  output wire state_updateir,
  output wire state_runidle
);

  `include "tst_params.vh"

  reg[3:0] state;

  always @(posedge tck or negedge rst_n) begin
    if(!rst_n) begin
      state <= TEST_LOGIC_RESET;
    end else begin
      case(state)
        TEST_LOGIC_RESET: state <= tms ? TEST_LOGIC_RESET : RUN_TEST_IDLE;
        RUN_TEST_IDLE:    state <= tms ? SELECT_DR        : RUN_TEST_IDLE;
        SELECT_DR:        state <= tms ? SELECT_IR        : CAPTURE_DR;
        CAPTURE_DR:       state <= tms ? EXIT1_DR         : SHIFT_DR;
        SHIFT_DR:         state <= tms ? EXIT1_DR         : SHIFT_DR;
        EXIT1_DR:         state <= tms ? UPDATE_DR        : PAUSE_DR;
        PAUSE_DR:         state <= tms ? EXIT2_DR         : PAUSE_DR;
        EXIT2_DR:         state <= tms ? UPDATE_DR        : SHIFT_DR;
        UPDATE_DR:        state <= tms ? SELECT_DR        : RUN_TEST_IDLE;
        SELECT_IR:        state <= tms ? TEST_LOGIC_RESET : CAPTURE_IR;
        CAPTURE_IR:       state <= tms ? EXIT1_IR         : SHIFT_IR;
        SHIFT_IR:         state <= tms ? EXIT1_IR         : SHIFT_IR;
        EXIT1_IR:         state <= tms ? UPDATE_IR        : PAUSE_IR;
        PAUSE_IR:         state <= tms ? EXIT2_IR         : PAUSE_IR;
        EXIT2_IR:         state <= tms ? UPDATE_IR        : SHIFT_IR;
        UPDATE_IR:        state <= tms ? SELECT_DR        : RUN_TEST_IDLE;
      endcase
    end
  end

  assign state_tlr       = (state == TEST_LOGIC_RESET);
  assign state_capturedr = (state == CAPTURE_DR);
  assign state_captureir = (state == CAPTURE_IR);
  assign state_shiftdr   = (state == SHIFT_DR);
  assign state_shiftir   = (state == SHIFT_IR);
  assign state_updatedr  = (state == UPDATE_DR);
  assign state_updateir  = (state == UPDATE_IR);
  assign state_runidle   = (state == RUN_TEST_IDLE);

endmodule

module jtag_reg
  #( parameter DR_LEN = 0,
     parameter IR_OPCODE = 4'b0)(
    input  wire              tck,
    input  wire              tdi,
    output wire              tdo,
    input  wire              rst_n,
    input  wire              state_tlr,
    input  wire              state_capturedr,
    input  wire              state_shiftdr,
    input  wire              state_updatedr,
    input  wire [3:0]        ir_reg,
    input  wire [DR_LEN-1:0] dr_data_in,
    output reg  [DR_LEN-1:0] dr_data_out);

  reg [DR_LEN-1:0] dr_reg;

  assign tdo = dr_reg[0];

  always @(posedge tck or negedge rst_n) begin
    if(!rst_n) begin
      dr_reg      <= {DR_LEN{1'b0}};
      dr_data_out <= {DR_LEN{1'b0}};
    end else begin
      if(state_tlr) 
        dr_reg <= {DR_LEN{1'b0}};
      if(ir_reg == IR_OPCODE) begin
        if(state_capturedr)
          dr_reg <= dr_data_in;
        else if(state_shiftdr) begin
          if(DR_LEN == 1)
            dr_reg <= tdi;
          else 
            dr_reg <= {tdi, dr_reg[DR_LEN-1:1]};
        end else if(state_updatedr) begin
          dr_data_out <= dr_reg;
        end
      end
    end
  end
endmodule

module tst
  #(parameter ID_PARTVER   = 4'h0,
    parameter ID_PARTNUM   = 16'hbeef,
    parameter ID_MANF      = 11'h123)
 (
  input  wire         tck,
  input  wire         tms,
  input  wire         tdi,
  output reg          tdo,
  input  wire         rst_n,
  // CLK_OP
  output wire         o_osc_en,
  output wire         o_clk_en,
  output wire         o_smp_en,
  output wire         o_ncm_en,
  output wire         o_msk_en,
  output wire [  2:0] o_clk_div,
  // CHL_OP
  output wire         o_go,
  output wire [ 55:0] o_chl_seed,
  // KEY_OP
  output wire [ 55:0] o_key1,
  output wire [ 55:0] o_key2,
  // RNG_OP
  output wire [ 55:0] o_erchl,
  output wire [ 55:0] o_seed56,
  output wire [  7:0] o_seed8,
  output wire [ 10:0] o_seed11,
  // SET_OP
  output wire [ 15:0] o_scc_end,
  output wire [ 15:0] o_scc_begin,
  output wire [ 15:0] o_evx,
  output wire [  7:0] o_chx,
  output wire [  7:0] o_grd,
  output wire [  3:0] o_rpt,
  output wire         o_use_seed,
  output wire         o_use_clkrnd,
  output wire [  1:0] o_arc,
  // RNG_OP
  input  wire [ 55:0] i_state1,
  input  wire [ 55:0] i_state2,
  // GET_OP
  input  wire [ 15:0] i_stat,
  // AUT_OP
  input  wire [127:0] i_auth,
  // STA_OP
  input  wire         i_save,
  input  wire         i_done);

  `include "tst_params.vh"

  wire state_tlr, state_capturedr, state_captureir, state_shiftdr, state_shiftir,
    state_updatedr, state_updateir, state_runidle;

  // ---------------------------------------------------------------------------------
  // mandatory jtag register and logic
  //

  jtag_fsm fsm(
    .tck             ( tck             ) ,
    .tms             ( tms             ) ,
    .rst_n           ( rst_n           ) ,
    .state_tlr       ( state_tlr       ) ,
    .state_capturedr ( state_capturedr ) ,
    .state_captureir ( state_captureir ) ,
    .state_shiftdr   ( state_shiftdr   ) ,
    .state_shiftir   ( state_shiftir   ) ,
    .state_updatedr  ( state_updatedr  ) ,
    .state_updateir  ( state_updateir  ) ,
    .state_runidle   ( state_runidle   ) );

  reg[3:0] ir_reg;

  // ---------------------------------------------------------------------------------
  // IDCODE_OP
  //

  wire        idcode_tdo;
  wire [31:0] idcode_in;

  assign idcode_in = {ID_PARTVER, ID_PARTNUM, ID_MANF, 1'b1};

  jtag_reg #(
    .DR_LEN    ( IDCODE_LEN ) ,
    .IR_OPCODE ( IDCODE_OP  ) )
    idcode_reg (
      .tck             ( tck             ) ,
      .tdi             ( tdi             ) ,
      .tdo             ( idcode_tdo      ) ,
      .rst_n           ( rst_n           ) ,
      .state_tlr       ( state_tlr       ) ,
      .state_capturedr ( state_capturedr ) ,
      .state_shiftdr   ( state_shiftdr   ) ,
      .state_updatedr  ( 1'b0            ) ,
      .ir_reg          ( ir_reg          ) ,
      .dr_data_out     (                 ) ,
      .dr_data_in      ( idcode_in       ) );

  // ---------------------------------------------------------------------------------
  // BYPASS_OP
  //

  wire bypass_tdo;

  jtag_reg #(
    .DR_LEN    ( BYPASS_LEN ) ,
    .IR_OPCODE ( BYPASS_OP  ))
    bypass_reg (
      .tck             ( tck             ) ,
      .tdi             ( tdi             ) ,
      .tdo             ( bypass_tdo      ) ,
      .rst_n           ( rst_n           ) ,
      .state_tlr       ( state_tlr       ) ,
      .state_capturedr ( state_capturedr ) ,
      .state_shiftdr   ( state_shiftdr   ) ,
      .state_updatedr  ( 1'b0            ) ,
      .ir_reg          ( ir_reg          ) ,
      .dr_data_out     (                 ) ,
      .dr_data_in      ( 1'b0            ) );

  // ---------------------------------------------------------------------------------
  // CLK_OP
  // 

  wire               clk_tdo;
  wire [CLK_LEN-1:0] clk_out;
  wire [CLK_LEN-1:0] clk_in;

  assign { o_osc_en,
           o_clk_en,
           o_smp_en,
           o_ncm_en,
           o_msk_en,
           o_clk_div } = clk_out;

  assign clk_in = { o_osc_en,
                    o_clk_en,
                    o_smp_en,
                    o_ncm_en,
                    o_msk_en,
                    o_clk_div };

  jtag_reg #(
    .DR_LEN    ( CLK_LEN ) ,
    .IR_OPCODE ( CLK_OP  ) )
    clk_reg (
      .tck             ( tck             ) ,
      .tdi             ( tdi             ) ,
      .tdo             ( clk_tdo         ) ,
      .rst_n           ( rst_n           ) ,
      .state_tlr       ( state_tlr       ) ,
      .state_capturedr ( state_capturedr ) ,
      .state_shiftdr   ( state_shiftdr   ) ,
      .state_updatedr  ( state_updatedr  ) ,
      .ir_reg          ( ir_reg          ) ,
      .dr_data_out     ( clk_out         ) ,
      .dr_data_in      ( clk_in          ) );

  // ---------------------------------------------------------------------------------
  // CHL_OP
  //

  wire               chl_tdo;
  wire [CHL_LEN-1:0] chl_out;
  wire [CHL_LEN-1:0] chl_in;

  wire [6:0] chl_rsvd;

  assign { chl_rsvd, o_go, o_chl_seed } = chl_out;

  assign chl_in = { 7'b0, o_go, o_chl_seed };

  jtag_reg #(
    .DR_LEN    ( CHL_LEN ) ,
    .IR_OPCODE ( CHL_OP  ) )
    chl_reg (
      .tck             ( tck             ) ,
      .tdi             ( tdi             ) ,
      .tdo             ( chl_tdo         ) ,
      .rst_n           ( rst_n           ) ,
      .state_tlr       ( state_tlr       ) ,
      .state_capturedr ( state_capturedr ) ,
      .state_shiftdr   ( state_shiftdr   ) ,
      .state_updatedr  ( state_updatedr  ) ,
      .ir_reg          ( ir_reg          ) ,
      .dr_data_out     ( chl_out         ) ,
      .dr_data_in      ( chl_in          ) );
  
  // ---------------------------------------------------------------------------------
  // KEY_OP
  //

  wire               key_tdo;
  wire [KEY_LEN-1:0] key_out;
  wire [KEY_LEN-1:0] key_in;

  assign { o_key1, o_key2 } = key_out;

  assign key_in = { o_key1, o_key2 };

  jtag_reg #(
    .DR_LEN    ( KEY_LEN ) ,
    .IR_OPCODE ( KEY_OP  ) )
    key_reg (
      .tck             ( tck             ) ,
      .tdi             ( tdi             ) ,
      .tdo             ( key_tdo         ) ,
      .rst_n           ( rst_n           ) ,
      .state_tlr       ( state_tlr       ) ,
      .state_capturedr ( state_capturedr ) ,
      .state_shiftdr   ( state_shiftdr   ) ,
      .state_updatedr  ( state_updatedr  ) ,
      .ir_reg          ( ir_reg          ) ,
      .dr_data_out     ( key_out         ) ,
      .dr_data_in      ( key_in          ) );

  // ---------------------------------------------------------------------------------
  // RNG_OP
  //

  wire               rng_tdo;
  wire [RNG_LEN-1:0] rng_out;
  wire [RNG_LEN-1:0] rng_in;

  wire [4:0] rsvd;

  assign { o_erchl, o_seed56, o_seed8, o_seed11, rsvd } = rng_out;

  assign rng_in = { i_state1, i_state2, 8'b0, 11'b0, 5'b0 };

  jtag_reg #(
    .DR_LEN    ( RNG_LEN ) ,
    .IR_OPCODE ( RNG_OP  ) )
    rng_reg (
      .tck             ( tck             ) ,
      .tdi             ( tdi             ) ,
      .tdo             ( rng_tdo         ) ,
      .rst_n           ( rst_n           ) ,
      .state_tlr       ( state_tlr       ) ,
      .state_capturedr ( state_capturedr ) ,
      .state_shiftdr   ( state_shiftdr   ) ,
      .state_updatedr  ( state_updatedr  ) ,
      .ir_reg          ( ir_reg          ) ,
      .dr_data_out     ( rng_out         ) ,
      .dr_data_in      ( rng_in          ) );

  // ---------------------------------------------------------------------------------
  // SET_OP
  //

  wire               set_tdo;
  wire [SET_LEN-1:0] set_out;
  wire [SET_LEN-1:0] set_in;

  assign { o_scc_end,
           o_scc_begin,
           o_evx,
           o_chx,
           o_grd,
           o_rpt,
           o_use_seed,
           o_use_clkrnd,
           o_arc } = set_out;

  assign set_in = { o_scc_end,
                    o_scc_begin,
                    o_evx,
                    o_chx,
                    o_grd,
                    o_rpt,
                    o_use_seed,
                    o_use_clkrnd,
                    o_arc };

  jtag_reg #(
    .DR_LEN    ( SET_LEN ) ,
    .IR_OPCODE ( SET_OP  ) )
    set_reg (
      .tck             ( tck             ) ,
      .tdi             ( tdi             ) ,
      .tdo             ( set_tdo         ) ,
      .rst_n           ( rst_n           ) ,
      .state_tlr       ( state_tlr       ) ,
      .state_capturedr ( state_capturedr ) ,
      .state_shiftdr   ( state_shiftdr   ) ,
      .state_updatedr  ( state_updatedr  ) ,
      .ir_reg          ( ir_reg          ) ,
      .dr_data_out     ( set_out         ) ,
      .dr_data_in      ( set_in          ) );

  // ---------------------------------------------------------------------------------
  // GET_OP
  //
  
  wire               get_tdo;
  wire [GET_LEN-1:0] get_out;
  wire [GET_LEN-1:0] get_in;

  assign get_in = { i_stat } ;

  jtag_reg #(
    .DR_LEN    ( GET_LEN ) ,
    .IR_OPCODE ( GET_OP  ) )
    get_reg (
      .tck             ( tck             ) ,
      .tdi             ( tdi             ) ,
      .tdo             ( get_tdo         ) ,
      .rst_n           ( rst_n           ) ,
      .state_tlr       ( state_tlr       ) ,
      .state_capturedr ( state_capturedr ) ,
      .state_shiftdr   ( state_shiftdr   ) ,
      .state_updatedr  ( state_updatedr  ) ,
      .ir_reg          ( ir_reg          ) ,
      .dr_data_out     ( get_out         ) ,
      .dr_data_in      ( get_in          ) );

  // ---------------------------------------------------------------------------------
  // AUT_OP
  //
  
  wire               aut_tdo;
  wire [AUT_LEN-1:0] aut_out;
  wire [AUT_LEN-1:0] aut_in;

  assign aut_in = { i_auth };

  jtag_reg #(
    .DR_LEN    ( AUT_LEN ) ,
    .IR_OPCODE ( AUT_OP  ) )
    aut_reg (
      .tck             ( tck             ) ,
      .tdi             ( tdi             ) ,
      .tdo             ( aut_tdo         ) ,
      .rst_n           ( rst_n           ) ,
      .state_tlr       ( state_tlr       ) ,
      .state_capturedr ( state_capturedr ) ,
      .state_shiftdr   ( state_shiftdr   ) ,
      .state_updatedr  ( state_updatedr  ) ,
      .ir_reg          ( ir_reg          ) ,
      .dr_data_out     ( aut_out         ) ,
      .dr_data_in      ( aut_in          ) );

  // ---------------------------------------------------------------------------------
  // STA_OP
  // 

  wire               sta_tdo;
  wire [STA_LEN-1:0] sta_out;
  wire [STA_LEN-1:0] sta_in;

  assign sta_in = { 6'b0, i_save, i_done };

  jtag_reg #(
    .DR_LEN    ( STA_LEN ) ,
    .IR_OPCODE ( STA_OP  ) )
    sta_reg (
      .tck             ( tck             ) ,
      .tdi             ( tdi             ) ,
      .tdo             ( sta_tdo         ) ,
      .rst_n           ( rst_n           ) ,
      .state_tlr       ( state_tlr       ) ,
      .state_capturedr ( state_capturedr ) ,
      .state_shiftdr   ( state_shiftdr   ) ,
      .state_updatedr  ( state_updatedr  ) ,
      .ir_reg          ( ir_reg          ) ,
      .dr_data_out     ( sta_out         ) ,
      .dr_data_in      ( sta_in          ) );

  // ---------------------------------------------------------------------------------
  // more jtag logic
  //

  wire ir_tdo;
  assign ir_tdo = ir_reg[0];
  always @(posedge tck or negedge rst_n) begin
    if(!rst_n) begin
      ir_reg <= IDCODE_OP;
    end else if(state_tlr) begin
      ir_reg <= IDCODE_OP;
    end else if(state_captureir) begin
      ir_reg <= 4'b0000;
    end else if(state_shiftir) begin
      ir_reg <= {tdi, ir_reg[3:1]};
    end
  end

  // IR selects the appropriate DR
  reg tdo_pre;
  always @* begin
    tdo_pre = 1'b0;
    if(state_shiftdr) begin
      case(ir_reg)
        IDCODE_OP:   tdo_pre = idcode_tdo;
        BYPASS_OP:   tdo_pre = bypass_tdo;
        CLK_OP:      tdo_pre = clk_tdo;
        CHL_OP:      tdo_pre = chl_tdo;
        KEY_OP:      tdo_pre = key_tdo;
        RNG_OP:      tdo_pre = rng_tdo;
        SET_OP:      tdo_pre = set_tdo;
        GET_OP:      tdo_pre = get_tdo;
        AUT_OP:      tdo_pre = aut_tdo;
        STA_OP:      tdo_pre = sta_tdo;
        default:     tdo_pre = bypass_tdo;
      endcase
    end else if(state_shiftir) begin
      tdo_pre = ir_tdo;
    end
  end

  // TDO updates on the negative edge according to the spec
  always @(negedge tck or negedge rst_n)
    if (!rst_n) tdo <= 1'b0;
    else        tdo <= tdo_pre;

endmodule

