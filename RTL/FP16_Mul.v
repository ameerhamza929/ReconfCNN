`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////


module FP16_Mul(
    input [15:0] a, // First floating-point number
    input [15:0] b, // Second floating-point number
    output reg[15:0] result
    );
    
    //extract components
    wire a_sign = a[15];
    wire [4:0] a_exp = a[14:10];
    wire [9:0] a_frac = a[9:0];
    
    wire b_sign = b[15];
    wire [4:0] b_exp = b[14:10];
    wire [9:0] b_frac = b[9:0];
    
    
    //special cases
    wire a_zero = (a_exp == 00) && (a_frac == 0);
    wire b_zero = (b_exp == 00) && (b_frac == 0);
    wire a_inf = (a_exp == 5'b11111) && (a_frac == 0);
    wire b_inf = (b_exp == 5'b11111) && (b_frac == 0);
    wire a_nan = (a_exp == 5'b11111) && (a_frac != 0);
    wire b_nan = (b_exp == 5'b11111) && (b_frac != 0);
    
    wire res_sign; //result sign
    assign res_sign = a_sign ^ b_sign;
    
    wire [21:0] frac_prod; // fract part result
    
    assign frac_prod = {1'b1, a_frac} * {1'b1, b_frac};
    
    wire[5:0] exp_sum ; //add_exp result
    assign exp_sum = {1'b0, a_exp} + {1'b0 + b_exp} - 6'd15;
    
    //normalize the result
    wire[4:0] res_exp;
    wire[9:0] res_frac;
    assign res_exp = frac_prod[21]? (exp_sum + 1): exp_sum;
    assign res_frac = frac_prod[21]? frac_prod[20:11]: frac_prod[19:10];
    
    always@(*)begin
        if(a_nan || b_nan || (a_inf&&b_zero) || (a_zero&&b_inf))
            result <= {res_sign ,5'b11110, 10'b1111111111}; //Nan
         else if(a_inf || b_inf)
            result <= {res_sign ,5'b11110, 10'b1111111111}; // infinity
         else if(a_zero || b_zero)
            result <= {res_sign,15'b0};
          else
            result <= { res_sign , res_exp , res_frac};
    end
    
endmodule
