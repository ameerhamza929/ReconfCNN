`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 07/22/2025 11:55:47 AM
// Design Name: 
// Module Name: mux2to1
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


module mux2to1 #(parameter WIDTH =16)(
input [WIDTH-1:0] in0,
input [WIDTH-1:0] in1,
input sel,
output [WIDTH-1:0] out

    );
    
    assign out = sel ? in1 : in0;
endmodule
