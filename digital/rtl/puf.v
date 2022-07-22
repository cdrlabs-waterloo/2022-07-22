`default_nettype none

module puf(
    input  wire         clk,
    input  wire         rst_n,
    input  wire         i_go,          // start evaluations
    input  wire [ 55:0] i_chl_seed,    // initial challenge
    input  wire [ 55:0] i_key1,        // secret key share 1 (or plain)
    input  wire [ 55:0] i_key2,        // secret key share 2
    input  wire [ 55:0] i_erchl,       // unstable chl
    input  wire [ 55:0] i_seed56,      // nlfsr shares seed
    input  wire [  7:0] i_seed8,       // clock randomizer seed
    input  wire [ 10:0] i_seed11,      // casr seed
    input  wire [ 15:0] i_scc_end,     // number of cycles to stop saving
    input  wire [ 15:0] i_scc_begin,   // number of cycles to start saving
    input  wire [ 15:0] i_evx,         // number of evaluations
    input  wire [  7:0] i_chx,         // number of unrolled challenges
    input  wire [  7:0] i_grd,         // number of guard cycles before eval
    input  wire [  3:0] i_rpt,         // number of repeated evaluations
    input  wire         i_use_seed,    // rng selection (0: apuf, 1: seed)
    input  wire         i_use_clkrnd,  // clock randomization
    input  wire [  1:0] i_arc,         // arch selection (0: smp, 1: ncm, 2: msk)
    input  wire         i_clk_smp,     // clock for smp
    input  wire         i_clk_ncm,     // clock for ncm
    input  wire         i_clk_msk,     // clock for msk
    output wire [ 55:0] o_state1,      // observable values for nlfsr/lfsr states
    output wire [ 55:0] o_state2,      // observable values for nlfsr/lfsr states
    output wire [ 15:0] o_stat,        // response statistics (accumulated)
    output wire [127:0] o_auth,        // 128 responses (one bit per resp)
    output reg          o_save,        // high while operation is running
    output reg          o_done);       // high when operation has completed

    reg [3:0] state;

    reg [127:0] auth;
    reg [ 15:0] stat;

    reg [1:0] valid_trans;
    reg       q_last;

    reg [15:0] evx_cnter;
    reg [15:0] scc_cnter;

    wire [ 3:0] state_plus1 = state + 1'b1;

    wire [15:0] evx_cnter_plus1 = evx_cnter + 1'b1;
    wire [ 7:0] scc_cnter_plus1 = scc_cnter + 1'b1;

    reg  go    [0:2];
    wire q     [0:2];
    wire valid [0:2];
    wire done  [0:2];

    wire [55:0] state1 [0:2];
    wire [55:0] state2;

    reg [1:0] i_go_meta; 
    wire      i_go_sync = i_go_meta[1];

    always @(posedge clk or negedge rst_n)
        if (!rst_n) i_go_meta <= 2'b0;
        else        i_go_meta <= {i_go_meta[0], i_go};

    always @(posedge clk or negedge rst_n)
        if (!rst_n) begin
            state <= 0;
            auth <= 128'b0;
            stat <= 0;
            evx_cnter <= 0;
            scc_cnter <= 0;
            valid_trans <= 0;
            q_last <= 0;
            go[0] <= 0; 
            go[1] <= 0;
            go[2] <= 0;
            o_save <= 0;
            o_done <= 0;
        end
        else begin
            valid_trans <= {valid_trans[0], valid[i_arc]};
            q_last <= q[i_arc];
            if (valid_trans == 2'b01) begin
                stat <= stat + q_last;
                auth <= {auth[126:0], q_last};
            end
            case (state)
                'd0: begin
                    if (i_go_sync) begin
                        state <= state_plus1;
                        stat <= 0;
                        auth <= 128'b0;
                        evx_cnter <= 0;
                    end
                end
                'd1: begin
                    state <= state_plus1;
                    evx_cnter <= evx_cnter_plus1;
                    scc_cnter <= 0;
                    go[i_arc] <= 1;
                end
                'd2: begin
                    if (scc_cnter == i_scc_end)
                        o_save <= 0;
                    else begin
                        scc_cnter <= scc_cnter_plus1;
                        if (scc_cnter == i_scc_begin)
                            o_save <= 1;
                    end

                    if (done[i_arc]) begin
                        state <= state_plus1;
                        go[i_arc] <= 0;
                    end
                end
                'd3: begin
                    if (!done[i_arc]) begin
                        if (evx_cnter == i_evx)
                            state <= state_plus1;
                        else
                            state <= 'd1;
                    end
                end
                'd4: begin
                    state <= state_plus1;
                    o_done <= 1;
                    o_save <= 0;
                end
                'd5: begin
                    if (!i_go_sync) begin
                        state <= 0;
                        o_done <= 0;
                    end
                end
                default: begin
                    state <= state_plus1;
                end
            endcase
        end

    smp_core U_SMP_CORE (
        .clk          ( i_clk_smp    ) ,
        .rst_n        ( rst_n        ) ,
        .i_go         ( go[0]        ) ,
        .i_chl_seed   ( i_chl_seed   ) ,
        .i_key1       ( i_key1       ) ,
        .i_chx        ( i_chx        ) ,
        .i_rpt        ( i_rpt        ) ,
        .o_state1     ( state1[0]    ) ,
        .o_q          ( q[0]         ) ,
        .o_valid      ( valid[0]     ) ,
        .o_done       ( done[0]      ) );

    ncm_core U_NCM_CORE (
        .clk          ( i_clk_ncm    ) ,
        .rst_n        ( rst_n        ) ,
        .i_go         ( go[1]        ) ,
        .i_chl_seed   ( i_chl_seed   ) ,
        .i_key1       ( i_key1       ) ,
        .i_erchl      ( i_erchl      ) ,
        .i_seed8      ( i_seed8      ) ,
        .i_chx        ( i_chx        ) ,
        .i_grd        ( i_grd        ) ,
        .i_rpt        ( i_rpt        ) ,
        .i_use_seed   ( i_use_seed   ) ,
        .i_use_clkrnd ( i_use_clkrnd ) ,
        .o_state1     ( state1[1]    ) ,
        .o_q          ( q[1]         ) ,
        .o_valid      ( valid[1]     ) ,
        .o_done       ( done[1]      ) );

    msk_core U_MSK_CORE (
        .clk          ( i_clk_msk    ) ,
        .rst_n        ( rst_n        ) ,
        .i_go         ( go[2]        ) ,
        .i_chl_seed   ( i_chl_seed   ) ,
        .i_key1       ( i_key1       ) ,
        .i_key2       ( i_key2       ) ,
        .i_erchl      ( i_erchl      ) ,
        .i_seed56     ( i_seed56     ) ,
        .i_seed8      ( i_seed8      ) ,
        .i_seed11     ( i_seed11     ) ,
        .i_chx        ( i_chx        ) ,
        .i_grd        ( i_grd        ) ,
        .i_rpt        ( i_rpt        ) ,
        .i_use_seed   ( i_use_seed   ) ,
        .i_use_clkrnd ( i_use_clkrnd ) ,
        .o_state1     ( state1[2]    ) ,
        .o_state2     ( state2       ) ,
        .o_q          ( q[2]         ) ,
        .o_valid      ( valid[2]     ) ,
        .o_done       ( done[2]      ) );

    assign o_state1 = state1[i_arc];
    assign o_state2 = state2;
    assign o_auth = auth;
    assign o_stat = stat;

endmodule
