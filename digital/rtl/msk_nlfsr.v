`default_nettype none

module msk_nlfsr (
    input  wire        clk,
    input  wire        rst_n,
    input  wire [55:0] i_wdata1,
    input  wire [55:0] i_wdata2,
    input  wire        i_load,
    input  wire        i_halt,
    input  wire        i_ser_in_valid,
    input  wire        i_ser_in,
    input  wire        i_r1,
    input  wire        i_r2,
    input  wire        i_rxor,
    output wire [55:0] o_rdata1,
    output wire [55:0] o_rdata2,
    output wire [55:0] o_rdata_xor);

    reg [28:0]  sh1_s29;
    reg [26:0]  sh1_s27;

    reg [28:0]  sh2_s29;
    reg [26:0]  sh2_s27;

    wire sh1_p27 = sh1_s27[0];
    wire sh1_p29 = sh1_s29[0];

    wire sh2_p27 = sh2_s27[0];
    wire sh2_p29 = sh2_s29[0];


    wire sh1_fb29 = (
        (
            (sh1_s29[28] & sh1_s29[20]) ^
            (sh1_s29[28] | (~sh2_s29[20]))
        ) ^
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
    ) ^ sh1_p27 ^ i_r1;

    wire sh1_fb27 = (
        (
            (sh1_s27[10] & sh1_s27[6]) ^
            (sh1_s27[10] | (~sh2_s27[6]))
        ) ^
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
    ) ^ sh1_p29 ^ i_r2;

    wire sh2_fb29 = (
        (
            (sh2_s29[28] | (~sh2_s29[20])) ^
            (sh2_s29[28] & sh1_s29[20])
        ) ^
        sh2_s29[27] ^
        sh2_s29[23] ^
        sh2_s29[22] ^
        sh2_s29[19] ^
        sh2_s29[16] ^
        sh2_s29[12] ^
        sh2_s29[11] ^
        sh2_s29[6] ^
        sh2_s29[5] ^
        sh2_s29[3] ^
        sh2_s29[0]
    ) ^ sh2_p27 ^ i_r1;

    wire sh2_fb27 = (
        (
            (sh2_s27[10] | (~sh2_s27[6])) ^
            (sh2_s27[10] & sh1_s27[6])
        ) ^
        sh2_s27[21] ^
        sh2_s27[19] ^
        sh2_s27[17] ^
        sh2_s27[14] ^
        sh2_s27[11] ^
        sh2_s27[10] ^
        sh2_s27[8] ^
        sh2_s27[4] ^
        sh2_s27[2] ^
        sh2_s27[1] ^
        sh2_s27[0]
    ) ^ sh2_p29 ^ i_r2;
    
    always @(posedge clk or negedge rst_n)
        if (!rst_n) begin
            sh1_s29 <= 0;
            sh1_s27 <= 0;
            sh2_s29 <= 0;
            sh2_s27 <= 0;
        end
        else begin
            if (i_load) begin
                { sh1_s29, sh1_s27 } <= i_wdata1;
                { sh2_s29, sh2_s27 } <= i_wdata2;
            end
            else if (i_ser_in_valid) begin
                { sh1_s29, sh1_s27 } <= {i_ser_in, sh1_s29, sh1_s27[26:1]};
                { sh2_s29, sh2_s27 } <= {i_ser_in, sh2_s29, sh2_s27[26:1]};
            end
            else if (!i_halt) begin
                sh1_s29 <= {sh1_fb29, sh1_s29[28:1]};
                sh1_s27 <= {sh1_fb27, sh1_s27[26:1]};
                sh2_s29 <= {sh2_fb29, sh2_s29[28:1]};
                sh2_s27 <= {sh2_fb27, sh2_s27[26:1]};
            end
        end

    wire [55:0] sh1 = {sh1_s29, sh1_s27};
    wire [55:0] sh2 = {sh2_s29, sh2_s27};

    assign o_rdata1    = sh1;
    assign o_rdata2    = sh2;

    assign o_rdata_xor = sh1 ^ (i_rxor ? sh2 : 56'b0);

endmodule
