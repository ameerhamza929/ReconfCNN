`timescale 1ns / 1ps


module Bank (
    input  clk,
    input  rst,
    input  ce,
    input  we_b,
    input  mem_read,
    (* keep = "true" *)input  [4:0] addr_a,        // port A: used by mem_clear_1
    (* keep = "true" *)input  [4:0] addr_b,        // port B: used by normal write/read
    input  [63:0] datain_b,
    input  mem_clear_1,
     (* mark_debug = "true" *)output reg [63:0] dataout
);

    (* keep = "true" *) (* ram_style = "block" *) reg [63:0] mem [0:15];

    // --- Port B: normal data write + read (one synchronous port) ---
    integer i;
    
    always @(posedge clk) begin
        if(rst) begin
             dataout <= mem[addr_b];
             for (i = 0; i < 16; i = i + 1) begin
                mem[i] <= 0;
            end
        end
        else if (ce) begin
            if (we_b)
                mem[addr_b] <= datain_b;
            if (mem_read)
                dataout <= mem[addr_b];
            if (mem_clear_1)
                mem[addr_a] <= 64'd0;
        end
    end

  

    

endmodule