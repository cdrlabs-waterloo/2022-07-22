`default_nettype none

module smp_core (
    input  wire        clk,
    input  wire        rst_n,
    input  wire        i_go,
    input  wire [55:0] i_chl_seed,
    input  wire [55:0] i_key1,
    input  wire [ 7:0] i_chx,
    input  wire [ 3:0] i_rpt,
    output wire [55:0] o_state1,
    output reg         o_q,
    output reg         o_valid,
    output reg         o_done);

    reg [3:0] state;
    reg [6:0] cycl_cnter;
    reg [7:0] runs_cnter;
    reg [3:0] rpts_cnter;
    reg [2:0] apuf_cnter;

    reg [4:0] rpts_accm;

    wire [55:0] lfsr_wdata1;
    wire [55:0] lfsr_rdata1;

    reg lfsr_wpar;
    reg lfsr_halt;

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

    wire load_key  = (state == 'd1) ? 1 : 0;

    always @(posedge clk or negedge rst_n)
        if (!rst_n) begin
            state <= 0;
            lfsr_wpar <= 0;
            lfsr_halt <= 0;
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
                        lfsr_wpar <= 1;
                        runs_cnter <= 0;
                    end
                end
                'd1: begin
                    /* loads key into LFSR */
                    state <= state_plus1;
                    lfsr_wpar <= 1;
                    lfsr_halt <= 0;
                    cycl_cnter <= 0;
                end
                'd2: begin
                    /* load chl (xoring with current value) and run 112 cc */
                    lfsr_wpar <= 0;
                    cycl_cnter <= cycl_cnter_plus1;
                    if (cycl_init_done) begin
                        state <= state_plus1;
                        cycl_cnter <= 0;
                    end
                end
                'd3: begin // entry point from 'd7
                    /* run for 56 cycles to acquire new challenge */
                    rpts_cnter <= 0;
                    rpts_accm <= 0;
                    lfsr_halt <= 0;
                    cycl_cnter <= cycl_cnter_plus1;
                    if (cycl_flush_done) begin
                        state <= state_plus1;
                        runs_cnter <= runs_cnter_plus1;
                        lfsr_halt <= 1;
                        cycl_cnter <= 0;
                    end
                end
                'd4: begin // entry point from 'd5
                    /* evaluate the arbiter puf */
                    if (apuf_ready) begin
                        state <= state_plus1;
                        rpts_cnter <= rpts_cnter_plus1;
                        a <= 1;
                    end
                end
                'd5: begin
                    /* accumulate the response in repeats counter/accum */
                    if (apuf_done) begin
                        a <= 0;
                        rpts_accm <= q0 ? rpts_accm + 1'b1 : rpts_accm - 1'b1;
                        if (rpts_cnter == i_rpt)
                            state <= state_plus1;
                        else
                            state <= 'd4;
                    end
                end
                'd6: begin
                    /* output final response with valid signal */
                    state <= state_plus1;
                    o_q <= rpts_accm[4];
                    o_valid <= 1;
                end
                'd7: begin
                    /* output respose and eval next chl (or done) */
                    o_q <= 0;
                    o_valid <= 0;
                    if (runs_cnter == i_chx) begin
                        state <= state_plus1;
                        o_done <= 1;
                    end
                    else
                        state <= 'd3;
                end
                'd8: begin
                    /* waiting go fall to clear done */
                    if (!i_go) begin
                        state <= 0;
                        o_done <= 0;
                    end
                end
            endcase
        end

    assign lfsr_wdata1 = (load_key)  ? (i_key1) :
                          (lfsr_rdata1 ^ i_chl_seed);

    smp_lfsr U_SMP_LFSR (
        .clk            ( clk            ) ,
        .rst_n          ( rst_n          ) ,
        .i_wdata1       ( lfsr_wdata1    ) ,
        .i_load         ( lfsr_wpar      ) ,
        .i_halt         ( lfsr_halt      ) ,
        .o_rdata1       ( lfsr_rdata1    ) );

    assign chl = lfsr_rdata1;

    assign o_state1 = lfsr_rdata1;

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
