`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
module PISO (
    input              clk,
    input              rst,
    input      [1023:0] datain,
    input              data_ready,
    output reg [31:0]  mem_data_out
);
    reg [1023:0] shift_reg;
    reg [4:0]    count;
    reg          active;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            shift_reg    <= 1024'd0;
            mem_data_out <= 32'd0;
            count        <= 5'd0;
            active       <= 1'b0;
        end else begin
            if (data_ready && !active) begin
                shift_reg <= datain;
                count     <= 5'd0;
                active    <= 1'b1;
            end
            else if (active) begin
                mem_data_out <= shift_reg[31:0];
                shift_reg    <= shift_reg >> 32;
                count        <= count + 1'b1;
                if (count == 5'd4) begin
                    active <= 1'b0;
                end
            end
        end
    end
endmodule