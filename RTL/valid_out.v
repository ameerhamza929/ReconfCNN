`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 09/04/2025 02:35:21 PM
// Design Name: 
// Module Name: valid_out
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////
`timescale 1ns / 1ps

module valid_out #(
    parameter R      = 8,
    parameter C      = 8,
    parameter WIDTH  = 16,
    parameter stride = 1
)(
    input clk,
    input rst,
    input [2:0] Kh,
    input [2:0] Kw,
    input [R*C*WIDTH-1:0] dataout_a,
    input [R-1:0] mask_row,
    input [C-1:0] mask_col,
    output wire [R*C*WIDTH-1:0] dataout_a_valid  // Max size: R*C outputs
);

    // Calculate valid dimensions dynamically
    reg [3:0] valid_vals_r;
    reg [3:0] valid_vals_c;
    
    always @(*) begin
        valid_vals_r = ((R - Kw) / stride) + 1;
        valid_vals_c = ((C - Kh) / stride) + 1;
    end

    // Unpack input into array
    wire [WIDTH-1:0] pe_outputs [R*C-1:0];
    
    genvar cd;
    generate 
        for (cd = 0; cd < R*C; cd = cd + 1) begin
           assign pe_outputs[cd] = dataout_a[cd*WIDTH +: WIDTH];            
        end
    endgenerate
    
    // Storage for valid outputs - max size R*C
    integer r, c, idx;
    integer valid_count;
    reg [WIDTH-1:0] valid_outputs [R*C-1:0];
    
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            // Initialize all to zero
            for (idx = 0; idx < R*C; idx = idx + 1)
                valid_outputs[idx] <= {WIDTH{1'b0}};
            valid_count <= 0;
        end
        else begin
            // First, zero out ALL positions
            for (idx = 0; idx < R*C; idx = idx + 1)
                valid_outputs[idx] = {WIDTH{1'b0}};
            
            // Then fill valid values starting from LSB (index 0)
            valid_count = 0;
            for (r = 0; r < R; r = r + 1) begin
                if (mask_row[R-1-r]) begin
                    for (c = 0; c < C; c = c + 1) begin
                        if (mask_col[C-1-c]) begin
                            idx = (c*R) + r;
                            valid_outputs[valid_count] = pe_outputs[idx];
                            valid_count = valid_count + 1;
                        end
                    end
                end
            end
            // All positions >= valid_count remain zero (already set above)
        end
    end
    
    // Pack all outputs (valid at LSB, zeros at MSB)
    genvar i;
    generate 
        for (i = 0; i < R*C; i = i + 1) begin
           assign dataout_a_valid[i*WIDTH +: WIDTH] = valid_outputs[i];            
        end
    endgenerate

endmodule