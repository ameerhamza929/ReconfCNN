

module demux1to2_16bit (
    input [15:0] in,     // 16-bit input
    input sel,     // 2-bit select line
    output reg [15:0] out0, // Output 0
    output reg [15:0] out1 // Output 1
);

    always @(*) begin
        // Set all outputs to 0 initially
            out0 = 16'b0;
            out1 = 16'b0;

        // Route the input to the selected output based on `sel`
        case (sel)
            1'b0: out0 = in;
            1'b1: out1 = in;
            default: ; // Do nothing, all outputs remain zero
        endcase
    end

endmodule