`timescale 1ns / 1ps

module FP16_adder (
    input clk,
    input rst,
    (* mark_debug = "true", keep = "true" *)input  [15:0] a,
    (* mark_debug = "true", keep = "true" *)input  [15:0] b,
    (* mark_debug = "true", keep = "true" *)input         add_en,  // Enable signal: perform addition/subtraction only when high
   (* mark_debug = "true", keep = "true" *) output  [15:0] result
);
    // Unpack inputs
    wire        sign_a = a[15];
    wire [4:0]  exp_a  = a[14:10];
    wire [9:0]  man_a  = a[9:0];
    wire        sign_b = b[15];
    wire [4:0]  exp_b  = b[14:10];
    wire [9:0]  man_b  = b[9:0];

    // Early bypass
    wire [15:0] zero16 = 16'h0000;

    // Mantissas with implicit leading bit
    wire [10:0] m_a = (exp_a == 0) ? {1'b0, man_a} : {1'b1, man_a};
    wire [10:0] m_b = (exp_b == 0) ? {1'b0, man_b} : {1'b1, man_b};

    // Common exponent and exponent difference
    wire [4:0] exp_common = (exp_a >= exp_b) ? exp_a : exp_b;
    wire [4:0] exp_diff   = (exp_a >= exp_b) ? (exp_a - exp_b) : (exp_b - exp_a);

    // Shift mantissas
    wire [10:0] m_a_s = (exp_a >= exp_b) ? m_a : (m_a >> exp_diff);
    wire [10:0] m_b_s = (exp_b >= exp_a) ? m_b : (m_b >> exp_diff);

    // Decide add or subtract
    wire        op_add = (sign_a == sign_b);
    wire [11:0] mant_sum = op_add
        ? ({1'b0, m_a_s} + {1'b0, m_b_s})
        : ((m_a_s >= m_b_s)
            ? ({1'b0, m_a_s} - {1'b0, m_b_s})
            : ({1'b0, m_b_s} - {1'b0, m_a_s}));
    wire        sign_r = op_add
        ? sign_a
        : ((m_a_s >= m_b_s) ? sign_a : sign_b);

    // Normalization
    reg [4:0] exp_r;
    reg [9:0] man_r;
    reg [10:0] norm_m;
    reg [15:0] result_reg;

    
    
    integer shift;
    integer i;

    always @(*) begin
        if (mant_sum == 0) begin
            exp_r  = 0;
            man_r  = 0;
        end else if (mant_sum[11]) begin
            norm_m = mant_sum[11:1];
            exp_r  = exp_common + 1;
            man_r  = norm_m[9:0];
        end else begin
            norm_m = mant_sum[10:0];
            exp_r  = exp_common;
            shift = 0;
            for(i=0 ; i< 11 ; i=i+1) begin
                if(norm_m[10]==0 && exp_r>0)begin
                    norm_m = norm_m<< 1;
                    exp_r = exp_r- 1;
                    shift= shift +1;
                end
           end
            man_r = norm_m[9:0];
        end
    end

    // Output logic gated by add_en
   (* KEEP = "TRUE" *) wire [15:0] packed_result = {sign_r, exp_r, man_r};
   
   always @(posedge clk) begin
        if (rst)
            result_reg <= 16'd0;
        else if (add_en)
            result_reg <= packed_result;
    end


    assign result = (rst) ? 16'd0 :add_en ? packed_result :  result_reg;

endmodule
