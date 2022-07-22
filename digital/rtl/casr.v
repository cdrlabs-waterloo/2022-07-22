`default_nettype none

module casr (
    input  wire        clk,
    input  wire        rst_n,
    input  wire [10:0] i_seed,
    input  wire        i_load,
    input  wire        i_ser_in_valid,
    input  wire        i_ser_in,
    output wire        o_ser_out_valid,
    output wire        o_ser_out,
    output wire        o_r0,
    output wire        o_r1,
    output wire        o_r2);

    integer idx;

    reg [10:0] state;

    wire [10:0] nxt_state;

    always @(posedge clk or negedge rst_n)
        if (!rst_n)
            state <= 0;
        else
            if (i_load)
                state <= i_seed;
            else if (i_ser_in_valid)
                state <= {i_ser_in, state[10:1]};
            else
                for (idx = 0; idx < 11; idx = idx+1)
                    state[idx] <= (~(|state)) ? 1 : nxt_state[idx];

    genvar  i;
    generate
        // From: Cattell 1995, JET, matches the model in `digital/python/casr.py`
        for (i = 1; i <= 11; i = i+1) begin : casr_blk
            wire left  = (i > 1)  ? state[11-i+1] : 0;
            wire right = (i < 11) ? state[11-i-1] : 0;
            assign nxt_state[11-i] = (i == 1) ? left ^ right ^ state[11-1] : left ^ right;
        end
    endgenerate

    assign o_ser_out_valid = i_ser_in_valid;
    assign o_ser_out = state[0];

    assign o_r0 = state[9];
    assign o_r1 = state[3];
    assign o_r2 = state[1];

endmodule

