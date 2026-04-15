`timescale 1ns / 1ps

module data_from_blk_to_buffer_lines 
(
    input  wire        clk,
    input  wire        rst,
    input  wire [63:0] doutb,
    input  wire        valid_in,
    input  wire [4:0]  channel_in,
    input  wire [4:0]  channel_out,
    output wire [63:0] datain_b0, datain_b1, datain_b2
);

    reg [63:0] datain_b [0:2];

    
    reg [15:0] counter;

    // map array to outputs
    assign datain_b0  = datain_b[0];
    assign datain_b1  = datain_b[1];
    assign datain_b2  = datain_b[2];


    // patch size = channel_in * 16
    wire [8:0] PATCH_SIZE;
    assign PATCH_SIZE  = channel_in * 16;
    // last counter value in a patch
    reg [8:0] LAST_COUNT; 

    integer idx;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            counter <= 16'd0;
            LAST_COUNT <= 9'd0;
            for (idx = 0; idx < 3; idx = idx + 1)
                datain_b[idx] <= 64'd0;
        end
        else begin
            LAST_COUNT <= (PATCH_SIZE == 0) ? 0 : (PATCH_SIZE - 1);
            if (valid_in) begin
                      case (counter / 16)   // group 0,1,2
                        0: begin
                            datain_b[0]  <= doutb;
                            datain_b[1]  <= 64'd0;
                            datain_b[2]  <= 64'd0;
                        end
                        1: begin
                            datain_b[0]  <= 64'd0;
                            datain_b[1]  <= doutb;
                            datain_b[2]  <= 64'd0;
                        end
                        2: begin
                            datain_b[0]  <= 64'd0;
                            datain_b[1]  <= 64'd0;
                            datain_b[2]  <= doutb;
                        end
                        default: begin
                            // do nothing for out-of-range groups
                        end
                    endcase
                
        
                if (counter == LAST_COUNT)
                    counter <= 16'd0;   // reset for next patch
                else
                    counter <= counter + 1;
            end
            else
                counter <= 16'd0;
        end
    end

endmodule
