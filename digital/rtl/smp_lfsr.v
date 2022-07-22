`default_nettype none

module smp_lfsr (
    input  wire        clk,
    input  wire        rst_n,
    input  wire [55:0] i_wdata1,
    input  wire        i_load,
    input  wire        i_halt,
    output wire [55:0] o_rdata1);

    reg [55:0]  state;

    wire fb = (
        state[22] ^
        state[21] ^
        state[1] ^
        state[0]
    );

    always @(posedge clk or negedge rst_n)
        if (!rst_n) begin
            state <= 56'b0;
        end
        else begin
            if (i_load)
                state <= i_wdata1;
            else if (!i_halt)
                state <= {fb, state[55:1]};
        end

    assign o_rdata1 = state;

endmodule
