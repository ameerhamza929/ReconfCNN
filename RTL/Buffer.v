`timescale 1ns / 1ps



module Buffer (
    input clk,
    input rst,
    input ce,
    input we_b,
//    input we_a,
    input mem_read,
    input [3:0] bank_addr,
    input [4:0] word_addr_a,    // 6 bits = 64 words
    input [4:0] word_addr_b,
    input [63:0] datain_b,
//    input [1023:0] datain_a,
    input mem_clear_1,
    output [1023:0] dataout
);
    wire [63:0] bank_out [0:15];

    
    
    wire [15:0] bank_we;
    genvar k;
    generate
        for (k = 0; k < 16; k = k + 1) begin : DECODE
            assign bank_we[k] = we_b & (bank_addr == k[3:0]);
        end
    endgenerate
    
    genvar j;
    generate
        for (j = 0; j < 16; j = j + 1) begin : BANK_LOOP
            (* dont_touch = "true" *) Bank bank_inst (
                .clk        (clk),
                .rst        (rst),
                .ce         (ce),
                .we_b       (bank_we[j]),      // <-- clean index into wire array
                .mem_read   (mem_read),
                .addr_a     (word_addr_a),
                .addr_b     (word_addr_b),
                .datain_b   (datain_b),
                .mem_clear_1(mem_clear_1),
                .dataout    (bank_out[j])
            );
        end
    endgenerate
    
    genvar x;
    generate
        for(x=0;x<16; x=x+1)begin
                
                assign dataout[(64*(x+1))-1:(64*(x+1))-64] = bank_out[x];
        end
    endgenerate
endmodule
