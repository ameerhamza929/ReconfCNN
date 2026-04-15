`timescale 1ns / 1ps

module processingelement #(parameter WIDTH =16)(
    input rst,
    input clk,                // Clock signal
    input hold,
    (* mark_debug = "true", keep = "true" *) input [15:0] Infmap,      // 16-bit floating-point input (half precision)
    (* mark_debug = "true" , keep = "true" *) input [15:0] weight,      // 16-bit floating-point weight (half precision)
     (* mark_debug = "true" *)input [15:0] hor_shift,   // 16-bit input for horizontal shift
    input [15:0] vert_shift,  // 16-bit input for vertical shift
    input [15:0] eng_shift,   // 16-bit input for engine shift
    (* mark_debug = "true" ,KEEP = "TRUE" *)output [15:0] Outfmap,    // 16-bit floating-point output (half precision)
    (* mark_debug = "true", keep = "true" *)output wire [15:0] HOR_shift_out,  // 16-bit output for horizontal shift
    output [15:0] VERT_shift_out, // 16-bit output for vertical shift
    output [15:0] ENG_shift_out,  // 16-bit output for engine shift
     (* mark_debug = "true" *)input ctrl0,              // 1-bit control signal for mux2to1_16bit
    
     (* mark_debug = "true" *)input [1:0] ctrl1,        // 2-bit control signal for mux4to1_16bit and demux1to4_16bit
     (* mark_debug = "true" *)input add_enable,          // 1-bit enable signal for adders
     (* mark_debug = "true" *)input acc_enable,
    input add_eng,
    input flush
);

// Internal registers
 reg [15:0] reg0; // Register for storing hor_shift value
 reg [15:0] reg1; // Register for storing vert_shift value
 reg [15:0] reg2; // Register for storing eng_shift value
 reg [15:0] reg3;
 wire [WIDTH-1:0] mux2_out;     
wire [15:0] out_demux0,out_demux1,out_demux2,out_demux3; 
wire [15:0] Outfmap_copy;  


always @(posedge clk or posedge rst) begin
    if (rst)
        reg3 <= 16'd0;
    else if(!hold)
        reg3 <= Outfmap_copy;
end

    
reg [15:0] hor_shift_sync;

always @(negedge clk or posedge rst) begin
    if (rst) 
        hor_shift_sync <= 16'd0;
    else 
        hor_shift_sync <= hor_shift; // Buffer the input
end
//wire [15:0]dummy;
assign ENG_shift_out = out_demux3;
assign VERT_shift_out = out_demux2; 
assign HOR_shift_out = out_demux0;  
    always@(posedge clk or posedge rst) begin
        if(rst) begin
            reg0<=16'd0;
            reg1<=16'd0;
            reg2<=16'd0;
        end
        else if (flush) begin
             reg0<=16'd0;
             reg1<=16'd0;
             reg2<=16'd0;
        
        end 
        else if (add_enable) begin
                reg0 <= reg0; 
                reg1<=vert_shift;
                reg2<=eng_shift;
             end
         else begin
                reg1<=reg1;
                reg2<=reg2;
                reg0<= hor_shift_sync;           
         end
            
     end
    
    
    
    // Instantiate the float16_multiplier
 (* keep = "true" *) wire [15:0] mult_result;
  FP16_Mul mult_inst (
    .a(Infmap),
    .b(weight),
    .result(mult_result)
);


    // Instantiate the 2-to-1 MUX
    wire [15:0] mux2to1_result;
   mux2to1 mux2to1_inst (
        .in0(16'd0),     // Input 0: Zero
        .in1(reg0),      // Input 1: Stored hor_shift value
        .sel(ctrl0),     // Select line
        .out(mux2to1_result)
    );

    // First instance of float16_adder
    wire [15:0] adder1_result;
    (* dont_touch = "true" *)FP16_adder adder1_inst (
        .clk(clk),
        .rst(rst),
        .a(mux2to1_result),
        .b(mult_result),
        .add_en(!add_enable),
        .result(adder1_result)
    );


       
    

     mux2to1 mux2(
           .in0(reg1),
           .in1(reg2),
           .sel(ctrl1[0]),  // if sel = 1 then mux2_out = reg2
           .out(mux2_out)
           );
           
     wire [WIDTH-1:0] mux3_out;   
     mux2to1 mux3(
           .in0(16'd0),
           .in1(mux2_out),  // if sel = 1 then mux3_out = mux2_out
           .sel(ctrl1[1]),
           .out(mux3_out)
           );
    
    
     demux1to2_16bit demux1(
        .in(adder1_result), // if sel = 1 then demux1_out = adder_result
        .sel(ctrl1[1]),
        .out0(out_demux0),
        .out1(out_demux1)
       );
       
    
    wire [WIDTH-1: 0] acc_in; //input to the last adder
    mux2to1 mux4(
           .in0(out_demux1),
           .in1(reg3),  // if sel = 1 then mux3_out = mux2_out
           .sel(add_eng),
           .out(acc_in)
           );
    // Second instance of float16_adder
    (* dont_touch = "true" *) FP16_adder Accumulate (
        .clk(clk),
        .rst(rst),
        .a(acc_in),     // First input from DEMUX (out0)
        .b(mux3_out), // Second input from 4-to-1 MUX
        .add_en(acc_enable),
        .result(Outfmap_copy)    // Output of adder2 is Outfmap
    );

    

    assign Outfmap = (rst) ? 16'd0:Outfmap_copy;
//   int16_adder Accumulate (
//        .a(acc_in),     // First input from DEMUX (out0)
//        .b(mux3_out),       // Second input from 4-to-1 MUX
//        .add_en(acc_enable),
//        .result(Outfmap)    // Output of adder2 is Outfmap
//    );

    
    demux1to2_16bit demux2(
        .in(Outfmap_copy),
        .sel(ctrl1[0]),           
        .out0(out_demux2),
        .out1(out_demux3)
       ) ;
       
     
       

endmodule