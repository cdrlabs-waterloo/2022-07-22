`default_nettype none

module ncm_nlfsr (
    input  wire        clk,
    input  wire        rst_n,
    input  wire [55:0] i_wdata1,
    input  wire        i_load,
    input  wire        i_halt,
    output wire [55:0] o_rdata1);

    reg [28:0]  sh1_s29;
    reg [26:0]  sh1_s27;

    wire sh1_p27 = sh1_s27[0];
    wire sh1_p29 = sh1_s29[0];

    wire sh1_fb29 = (
        (sh1_s29[28] & sh1_s29[20]) ^
        sh1_s29[27] ^
        sh1_s29[23] ^
        sh1_s29[22] ^
        sh1_s29[19] ^
        sh1_s29[16] ^
        sh1_s29[12] ^
        sh1_s29[11] ^
        sh1_s29[6] ^
        sh1_s29[5] ^
        sh1_s29[3] ^
        sh1_s29[0]
    ) ^ sh1_p27;

    wire sh1_fb27 = (
        (sh1_s27[10] & sh1_s27[6]) ^
        sh1_s27[21] ^
        sh1_s27[19] ^
        sh1_s27[17] ^
        sh1_s27[14] ^
        sh1_s27[11] ^
        sh1_s27[10] ^
        sh1_s27[8] ^
        sh1_s27[4] ^
        sh1_s27[2] ^
        sh1_s27[1] ^
        sh1_s27[0]
    ) ^ sh1_p29;

    
    always @(posedge clk or negedge rst_n)
        if (!rst_n) begin
            sh1_s29 <= 0;
            sh1_s27 <= 0;
        end
        else begin
            if (i_load)
                { sh1_s29, sh1_s27 } <= i_wdata1;
            else if (!i_halt) begin
                sh1_s29 <= {sh1_fb29, sh1_s29[28:1]};
                sh1_s27 <= {sh1_fb27, sh1_s27[26:1]};
            end
        end

    wire [55:0] sh1 = {sh1_s29, sh1_s27};

    assign o_rdata1    = sh1;

endmodule
