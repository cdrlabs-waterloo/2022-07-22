`default_nettype none

module msk_core (
    input  wire        clk,
    input  wire        rst_n,
    input  wire        i_go,
    input  wire [55:0] i_chl_seed,
    input  wire [55:0] i_key1,
    input  wire [55:0] i_key2,
    input  wire [55:0] i_erchl,
    input  wire [55:0] i_seed56,
    input  wire [ 7:0] i_seed8,
    input  wire [10:0] i_seed11,
    input  wire [ 7:0] i_chx,
    input  wire [ 7:0] i_grd,
    input  wire [ 3:0] i_rpt,
    input  wire        i_use_seed,
    input  wire        i_use_clkrnd,
    output wire [55:0] o_state1,
    output wire [55:0] o_state2,
    output reg         o_q,
    output reg         o_valid,
    output reg         o_done);

    wire clkr;
    wire r0, r1, r2;

    wire clock_rand_ser_out_valid;
    wire clock_rand_ser_out;
    reg  clock_rand_load_par;
    reg  clock_rand_load_ser;

    wire clock_rand_r0;
    wire clock_rand_r1;
    wire clock_rand_r2;

    wire casr_load_par;
    wire casr_r0;
    wire casr_r1;
    wire casr_r2;

    reg [3:0] state;
    reg [6:0] cycl_cnter;
    reg [7:0] runs_cnter;
    reg [3:0] rpts_cnter;
    reg [2:0] apuf_cnter;

    reg [4:0] rpts_accm;

    wire [55:0] nlfsr_wdata1;
    wire [55:0] nlfsr_wdata2;
    wire [55:0] nlfsr_rdata1;
    wire [55:0] nlfsr_rdata2;
    wire [55:0] nlfsr_rdata_xor;

    reg nlfsr_wpar;
    reg nlfsr_wser;
    reg nlfsr_rxor;
    reg nlfsr_halt;

    wire [55:0] chl;
    wire        q1, q0;

    reg a;
    reg apuf_done;
    reg apuf_ready;

    wire cycl_init_done  = (cycl_cnter == 'd111) ? 1'b1 : 1'b0;
    wire cycl_flush_done = (cycl_cnter ==  'd56) ? 1'b1 : 1'b0;

    wire [3:0] state_plus1 = state + 1'b1;

    wire [7:0] cycl_cnter_plus1 = cycl_cnter + 1'b1;
    wire [7:0] runs_cnter_plus1 = runs_cnter + 1'b1;
    wire [3:0] rpts_cnter_plus1 = rpts_cnter + 1'b1;

    wire init_mode = (state <  'd6) ? 1 : 0;
    wire load_key  = (state == 'd6) ? 1 : 0;

    always @(posedge clkr or negedge rst_n)
        if (!rst_n) begin
            state <= 0;
            clock_rand_load_par <= 0;
            clock_rand_load_ser <= 0;
            nlfsr_wpar <= 0;
            nlfsr_wser <= 0;
            nlfsr_rxor <= 0;
            nlfsr_halt <= 0;
            runs_cnter <= 0;
            cycl_cnter <= 0;
            rpts_cnter <= 0;
            rpts_accm <= 0;
            a <= 0;
            o_q <= 0;
            o_valid <= 0;
            o_done <= 0;
        end else begin
            case (state)
                'd0: begin
                    /* start initialization */
                    if (i_go) begin
                        state <= state_plus1;
                        runs_cnter <= 0;
                        nlfsr_halt <= 1;
                        cycl_cnter <= 0;
                        if (i_use_seed) begin
                            clock_rand_load_par <= 1;
                            nlfsr_wpar <= 1;
                            state <= 'd5; /* GOTO */
                        end
                    end
                end
                'd1: begin // entry point from 'd3
                    /* evaluates using unstable challenge */
                    if (apuf_ready) begin
                        state <= state_plus1;
                        cycl_cnter <= cycl_cnter_plus1;
                        a <= 1;
                    end
                end
                'd2: begin
                    /* loads response into clock rand LFSR */
                    if (apuf_done) begin
                        state <= state_plus1;
                        clock_rand_load_ser <= 1;
                    end
                end
                'd3: begin
                    /* checks if initialization is complete */
                    a <= 0;
                    clock_rand_load_ser <= 0;
                    if (cycl_cnter == (8 + 11)) begin
                        state <= state_plus1;
                        nlfsr_wser <= 1;
                        cycl_cnter <= 0;
                    end
                    else
                        state <= 'd1;
                end
                'd4: begin
                    /* loads random bits from RNG (clock rand & casr) to NLFSR */
                    cycl_cnter <= cycl_cnter_plus1;
                    if (cycl_cnter == 56) begin
                        state <= state_plus1;
                        nlfsr_wser <= 0;
                    end
                end
                'd5: begin // entry point from 'd0
                    /* loads seed into NLFSR (or skips if using unstable chl) */
                    state <= state_plus1;
                    clock_rand_load_par <= 0;
                    nlfsr_wpar <= 1;
                end
                'd6: begin
                    /* loads key into NLFSR (xoring with current value) */
                    state <= state_plus1;
                    nlfsr_wpar <= 0;
                    cycl_cnter <= 0;
                end
                'd7: begin
                    /* load chl (xoring with current value) & run guard cycles */
                    nlfsr_halt <= 0;
                    cycl_cnter <= cycl_cnter_plus1;
                    if (cycl_cnter == i_grd | (~i_use_clkrnd)) begin
                        state <= state_plus1;
                        cycl_cnter <= 0;
                        nlfsr_wpar <= 1;
                    end
                end
                'd8: begin
                    /* run for 112 cycles (+56 below) to initilize chl */
                    nlfsr_wpar <= 0;
                    cycl_cnter <= cycl_cnter_plus1;
                    if (cycl_init_done) begin
                        state <= state_plus1;
                        cycl_cnter <= 0;
                    end
                end
                'd9: begin // entry point from 'd13
                    /* run NFLSR for 56 cycles to acquire new challenge */
                    rpts_cnter <= 0;
                    rpts_accm <= 0;
                    nlfsr_halt <= 0;
                    nlfsr_rxor <= 0;
                    cycl_cnter <= cycl_cnter_plus1;
                    if (cycl_flush_done) begin
                        state <= state_plus1;
                        runs_cnter <= runs_cnter_plus1;
                        nlfsr_halt <= 1;
                        nlfsr_rxor <= 1;
                        cycl_cnter <= 0;
                    end
                end
                'd10: begin // entry point from 'd11
                    /* evaluate the arbiter puf */
                    if (apuf_ready) begin
                        state <= state_plus1;
                        rpts_cnter <= rpts_cnter_plus1;
                        a <= 1;
                    end
                end
                'd11: begin
                    /* accumulate the response in repeats counter/accum */
                    if (apuf_done) begin
                        a <= 0;
                        rpts_accm <= q0 ? rpts_accm + 1'b1 : rpts_accm - 1'b1;
                        if (rpts_cnter == i_rpt)
                            state <= state_plus1;
                        else
                            state <= 'd10; /* GOTO */
                    end
                end
                'd12: begin
                    /* output final response with valid signal */
                    state <= state_plus1;
                    o_q <= rpts_accm[4];
                    o_valid <= 1;
                end
                'd13: begin
                    /* output respose and eval next chl (or done) */
                    o_q <= 0;
                    o_valid <= 0;
                    if (runs_cnter == i_chx) begin
                        state <= state_plus1;
                        o_done <= 1;
                    end
                    else
                        state <= 'd9; /* GOTO */
                end
                'd14: begin
                    /* waiting go fall to clear done */
                    if (!i_go) begin
                        state <= 0;
                        o_done <= 0;
                    end
                end
            endcase
        end

    clock_rand U_CLOCK_RAND (
        .clk             ( clk                         ) ,
        .rst_n           ( rst_n                       ) ,
        .i_en            ( i_use_clkrnd & (~init_mode) ) ,
        .i_seed          ( i_seed8                     ) ,
        .i_load          ( clock_rand_load_par         ) ,
        .i_ser_in_valid  ( clock_rand_load_ser         ) ,
        .i_ser_in        ( q0                          ) ,
        .o_ser_out_valid ( clock_rand_ser_out_valid    ) ,
        .o_ser_out       ( clock_rand_ser_out          ) ,
        .o_clk           ( clkr                        ) ,
        .o_r0            ( clock_rand_r0               ) ,
        .o_r1            ( clock_rand_r1               ) ,
        .o_r2            ( clock_rand_r2               ) );

    assign casr_load_par = clock_rand_load_par;

    casr U_CASR (
        .clk             ( clk                         ) ,
        .rst_n           ( rst_n                       ) ,
        .i_seed          ( i_seed11                    ) ,
        .i_load          ( casr_load_par               ) ,
        .i_ser_in_valid  ( clock_rand_ser_out_valid    ) ,
        .i_ser_in        ( clock_rand_ser_out          ) ,
        .o_ser_out_valid (                             ) ,
        .o_ser_out       (                             ) ,
        .o_r0            ( casr_r0                     ) ,
        .o_r1            ( casr_r1                     ) ,
        .o_r2            ( casr_r2                     ) );

    assign r0 = clock_rand_r0 ^ casr_r0;
    assign r1 = clock_rand_r1 ^ casr_r1;
    assign r2 = clock_rand_r2 ^ casr_r2;

    assign nlfsr_wdata1 = (init_mode) ? i_seed56 : 
                          (load_key)  ? (nlfsr_rdata1 ^ i_key1) :
                          (nlfsr_rdata1 ^ i_chl_seed);

    assign nlfsr_wdata2 = (init_mode) ? i_seed56 :
                          (load_key)  ? (nlfsr_rdata2 ^ i_key2)  :
                          (nlfsr_rdata2);

    msk_nlfsr U_MSK_NLFSR (
        .clk            ( clkr               ) ,
        .rst_n          ( rst_n              ) ,
        .i_wdata1       ( nlfsr_wdata1       ) ,
        .i_wdata2       ( nlfsr_wdata2       ) ,
        .i_load         ( nlfsr_wpar         ) ,
        .i_halt         ( nlfsr_halt         ) ,
        .i_ser_in_valid ( nlfsr_wser         ) ,
        .i_ser_in       ( r0                 ) ,
        .i_r1           ( r1                 ) ,
        .i_r2           ( r2                 ) ,
        .i_rxor         ( nlfsr_rxor         ) ,
        .o_rdata1       ( nlfsr_rdata1       ) ,
        .o_rdata2       ( nlfsr_rdata2       ) ,
        .o_rdata_xor    ( nlfsr_rdata_xor    ) );

    assign chl = init_mode ? i_erchl : nlfsr_rdata_xor;

    assign o_state1 = nlfsr_rdata1;
    assign o_state2 = nlfsr_rdata2;

    always @(posedge clk or negedge rst_n)
        if (!rst_n) begin
            apuf_cnter <= 0;
            apuf_done <= 0;
            apuf_ready <= 0;
        end
        else
            if (a) begin
                apuf_ready <= 0;
                if (apuf_cnter == 'd7)
                    apuf_done <= 1;
                else begin
                    apuf_done <= 0;
                    apuf_cnter <= apuf_cnter + 1'b1;
                end
            end
            else begin
                apuf_done <= 0;
                if (apuf_cnter == 0)
                    apuf_ready <= 1;
                else begin
                    apuf_ready <= 0;
                    apuf_cnter <= apuf_cnter - 1'b1;
                end
            end

    LONG56 U_LONG56(
        .Q0 ( q0              ) ,
        .Q1 ( q1              ) ,
        .A  ( a               ) ,
        .B  ( a               ) ,
        .E  ( chl             ) ,
        .EB ( ~chl            ) );

endmodule
