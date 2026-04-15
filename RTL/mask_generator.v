module mask_generator #(
    parameter R      = 8,
    parameter C      = 8,
    parameter stride = 1
)(
    input clk,
    input rst,
    input [2:0] Kh,
    input [2:0] Kw,
    output reg [R-1:0] mask_row,
    output reg [C-1:0] mask_col
);
    
    // Calculate valid values dynamically
    reg [3:0] valid_vals_r;
    reg [3:0] valid_vals_c;
    
    always @(*) begin
        valid_vals_r = ((R - Kw) / stride) + 1;
        valid_vals_c = ((C - Kh) / stride) + 1;
    end
    
    integer i;
    
    always @(posedge clk or posedge rst) begin
        if(rst) begin
            mask_row <= {R{1'b0}};
            mask_col <= {C{1'b0}};
        end
        else begin
            // Initialize to zero
            mask_row <= {R{1'b0}};
            mask_col <= {C{1'b0}};
    
            // Set bits at stride intervals to 1
            for (i = 0; i < valid_vals_r; i = i + 1)
                mask_row[(i * stride) + (stride - 1)] <= 1'b1;
            
            for (i = 0; i < valid_vals_c; i = i + 1)
                mask_col[(i * stride) + (stride - 1)] <= 1'b1;
        end
    end
    
endmodule