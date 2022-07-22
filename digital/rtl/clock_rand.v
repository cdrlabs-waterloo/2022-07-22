`default_nettype none

module clock_rand (
    input  wire        clk,
    input  wire        rst_n,
    input  wire        i_en,
    input  wire [7:0]  i_seed,
    input  wire        i_load,
    input  wire        i_ser_in_valid,
    input  wire        i_ser_in,
    output wire        o_ser_out_valid,
    output wire        o_ser_out,
    output wire        o_r0,
    output wire        o_r1,
    output wire        o_r2,
    output wire        o_clk);

    integer idx;

    reg [7:0]  state;
    reg clk_rand;

    wire fb = (
        state[6] ^
        state[5] ^
        state[1] ^
        state[0]
    ) ^ (~(|state));

    always @(posedge clk or negedge rst_n)
        if (!rst_n) begin
            state <= 0;
            clk_rand <= 0;
        end
        else begin
            if (i_load)
                state <= i_seed;
            else if (i_ser_in_valid)
                state <= {i_ser_in, state[7:1]};
            else
                state <= {fb, state[7:1]};

            if (state[0] | (~i_en))
                clk_rand <= ~clk_rand;
        end

    assign o_clk = clk_rand;

    assign o_ser_out_valid = i_ser_in_valid;
    assign o_ser_out = state[0];

    assign o_r0 = state[4];
    assign o_r1 = state[6];
    assign o_r2 = state[2];

endmodule

