`default_nettype none

module ncm_core (
    input  wire        clk,
    input  wire        rst_n,
    input  wire        i_go,
    input  wire [55:0] i_chl_seed,
    input  wire [55:0] i_key1,
    input  wire [55:0] i_erchl,
    input  wire [ 7:0] i_seed8,
    input  wire [ 7:0] i_chx,
    input  wire [ 7:0] i_grd,
    input  wire [ 3:0] i_rpt,
    input  wire        i_use_seed,
    input  wire        i_use_clkrnd,
    output wire [55:0] o_state1,
    output reg         o_q,
    output reg         o_valid,
    output reg         o_done);

    wire clkr;

    reg clock_rand_load_par;
    reg clock_rand_load_ser;

    reg [3:0] state;
    reg [6:0] cycl_cnter;
    reg [7:0] runs_cnter;
    reg [3:0] rpts_cnter;
    reg [2:0] apuf_cnter;

    reg [4:0] rpts_accm;

    wire [55:0] nlfsr_wdata1;
    wire [55:0] nlfsr_rdata1;

    reg nlfsr_wpar;
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

    wire init_mode = (state <  'd5) ? 1 : 0;
    wire load_key  = (state == 'd5) ? 1 : 0;

    always @(posedge clkr or negedge rst_n)
        if (!rst_n) begin
            state <= 0;
            clock_rand_load_par <= 0;
            clock_rand_load_ser <= 0;
            nlfsr_wpar <= 0;
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
                            state <= 'd4; /* GOTO */
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
                        nlfsr_wpar <= 1;
                    end
                    else
                        state <= 'd1;
                end
                'd4: begin // entry point from 'd0
                    /* loads seed into NLFSR (or skips if using unstable chl) */
                    state <= state_plus1;
                    clock_rand_load_par <= 0;
                    nlfsr_wpar <= 1;
                end
                'd5: begin
                    /* loads key into NLFSR (xoring with current value) */
                    state <= state_plus1;
                    clock_rand_load_par <= 0;
                    nlfsr_wpar <= 0;
                    cycl_cnter <= 0;
                end
                'd6: begin
                    /* run for guard cycles (misalignment and whittening) */
                    nlfsr_halt <= 0;
                    cycl_cnter <= cycl_cnter_plus1;
                    if (cycl_cnter == i_grd | (~i_use_clkrnd)) begin
                        state <= state_plus1;
                        cycl_cnter <= 0;
                        nlfsr_wpar <= 1;
                    end
                end
                'd7: begin
                    /* load chl (xoring with current value) and run 112 cc */
                    nlfsr_wpar <= 0;
                    cycl_cnter <= cycl_cnter_plus1;
                    if (cycl_init_done) begin
                        state <= state_plus1;
                        cycl_cnter <= 0;
                    end
                end
                'd8: begin // entry point from 'd12
                    /* run for 56 cycles to acquire new challenge */
                    rpts_cnter <= 0;
                    rpts_accm <= 0;
                    nlfsr_halt <= 0;
                    cycl_cnter <= cycl_cnter_plus1;
                    if (cycl_flush_done) begin
                        state <= state_plus1;
                        runs_cnter <= runs_cnter_plus1;
                        nlfsr_halt <= 1;
                        cycl_cnter <= 0;
                    end
                end
                'd9: begin // entry point from 'd10
                    /* evaluate the arbiter puf */
                    if (apuf_ready) begin
                        state <= state_plus1;
                        rpts_cnter <= rpts_cnter_plus1;
                        a <= 1;
                    end
                end
                'd10: begin
                    /* accumulate the response in repeats counter/accum */
                    if (apuf_done) begin
                        a <= 0;
                        rpts_accm <= q0 ? rpts_accm + 1'b1 : rpts_accm - 1'b1;
                        if (rpts_cnter == i_rpt)
                            state <= state_plus1;
                        else
                            state <= 'd9; /* GOTO */
                    end
                end
                'd11: begin
                    /* output final response with valid signal */
                    state <= state_plus1;
                    o_q <= rpts_accm[4];
                    o_valid <= 1;
                end
                'd12: begin
                    /* output respose and eval next chl (or done) */
                    o_q <= 0;
                    o_valid <= 0;
                    if (runs_cnter == i_chx) begin
                        state <= state_plus1;
                        o_done <= 1;
                    end
                    else
                        state <= 'd8; /* GOTO */
                end
                'd13: begin
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
        .o_ser_out_valid (                             ) ,
        .o_ser_out       (                             ) ,
        .o_clk           ( clkr                        ) ,
        .o_r0            (                             ) ,
        .o_r1            (                             ) ,
        .o_r2            (                             ) );

    assign nlfsr_wdata1 = (load_key)  ? (i_key1) :
                          (nlfsr_rdata1 ^ i_chl_seed);

    ncm_nlfsr U_NCM_NLFSR (
        .clk            ( clkr            ) ,
        .rst_n          ( rst_n           ) ,
        .i_wdata1       ( nlfsr_wdata1    ) ,
        .i_load         ( nlfsr_wpar      ) ,
        .i_halt         ( nlfsr_halt      ) ,
        .o_rdata1       ( nlfsr_rdata1    ) );

    assign chl = init_mode ? i_erchl : nlfsr_rdata1;

    assign o_state1 = nlfsr_rdata1;

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
