`timescale 1ns / 1ps



module memory_array #(

    parameter integer ELEM_WIDTH     = 16,   // bits per element
    parameter integer WORD_WIDTH     = 64,   // bits per bank word
    parameter integer MAX_R          = 8,    // designed tile rows (e.g., 8)
    parameter integer MAX_C          = 8,    // designed tile cols (e.g., 8)

    parameter integer NUM_BANKS      = 16,
    parameter integer NUM_BUFFER    = 3,

    parameter integer NO_OF_PATCHES_ROW = 5,
    parameter integer NO_OF_PATCHES_COL = 5

) (
    input clk,
    input rst,
    input mem_clear_1,
    input [5:0] channel_in,
    input [5:0] channel_out,
    input  wire [2:0] Kh,                    // Dynamic kernel height
    input  wire [2:0] Kw, 
    input  wire [2:0] stride,       
    
    input ce,                  // Chip enable
//    input we_a,
    input flush,
    input [2:0] we_b,                 // Write enable
    input mem_read,
    input valid_in,
    //input [4:0] db_addr,
    input [3:0] bank_addr,
    input [4:0] word_addr_a,     // Address inside the Bank (0-63)
    input [4:0] word_addr_b,
    input [191:0] datain_b,
//    input [(MAX_R * MAX_C * ELEM_WIDTH*4)-1:0] datain_a,
    output [3071:0] dataout
);
  
    wire [1023:0] db_out [ NUM_BUFFER-1:0];
    wire [63:0] datain_b_wires [NUM_BUFFER-1:0];

    
    
//    genvar io;
//    generate
//        for(io = 0; io<NUM_BUFFER ;io = io+1)begin
//            assign arranged_data_out_wire[io] = arranged_data_out[(WORD_WIDTH*NUM_BANKS)*(io+1)-1:(WORD_WIDTH*NUM_BANKS)*(io+1)-(WORD_WIDTH*NUM_BANKS)];
//        end 
//    endgenerate
    
    
//    wire [(WORD_WIDTH*NUM_BANKS)-1:0] arranged_data_out_wire_merged[0:NUM_BUFFER-1];
    genvar g;
    generate
        for (g = 0; g < 3; g = g + 1) begin
            assign datain_b_wires[g] = datain_b[(64*(g+1))-1:(64*(g+1))-64];
        end
    endgenerate
        
//    genvar y;
//    generate
//        for( y=0;y<4; y = y +1)begin
//            assign datain_a_wires[y] = datain_a[(MAX_R*MAX_C*NUM_BANKS*(y+1))-1:(MAX_R*MAX_C*NUM_BANKS*(y+1))- MAX_R*MAX_C*NUM_BANKS];
//        end
//    endgenerate
    

    
    
    
    ////////////////////////////
// wire [(MAX_R * MAX_C * ELEM_WIDTH)-1:0] dataout_a [0:3];
    

    
    genvar i;
    generate
        for (i = 0; i < 3; i = i + 1) begin : DB_LOOP
            Buffer db_inst (
                .clk(clk),
                .rst(rst),
                .ce(ce),           //&(db_addr == i)
                .we_b(we_b[i]),
                .mem_read(mem_read),
                .bank_addr(bank_addr),
                .word_addr_a(word_addr_a),
                .word_addr_b(word_addr_b),
                .datain_b(datain_b_wires[i]),
                .mem_clear_1(mem_clear_1),
                .dataout(db_out[i])
            );
        end
    endgenerate
    
    genvar x;
    generate
        for(x=0;x<3;x=x+1)begin
            assign dataout[(1024*(x+1))-1:(1024*(x+1))-1024] = (rst) ? 1024'd0 : db_out[x];
        end
    endgenerate
    
endmodule

