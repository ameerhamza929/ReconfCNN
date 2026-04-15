`timescale 1ns / 1ps



module top_module #(
    parameter SIZE    = 8,
    parameter WIDTH   = 16,
    parameter R       = 8,
    parameter C       = 8,
    parameter stride  = 2
)      
(                                      
 input wire clk,                      
 input wire rst,                      
 input wire[2:0] hold,
 input wire eng_shift_vert,
 input conv_comp,                     
 input ctrl_bf_conv,
// input ctrl_bf_act,
// input ctrl_bf_pool,
// input ctrl_bf_batch,
// input [1:0]Ctrl_act,
 input [2:0]Kh ,                  
 input [2:0]Kw ,
// input[WIDTH-1:0] alpha,
// input [WIDTH-1:0] beta,
// input [WIDTH-1:0] mean, 
 (* keep = "true" *) input wire [3071:0] mem_data_in,       
                                       
 input wire ctrl0,          // Control
 input wire [1:0] ctrl1,    // Control
 input wire add_enable,     // Add ena
 input wire acc_enable,               
 input wire [2:0]add_eng,
 (* keep = "true" *) input [47:0] weight,
 input flush,
 (* keep = "true" *) output  [1023:0] dataout_a                   
 );
 

 
   (* keep = "true" *) wire [1023:0]eng_shift_wires[0:2];
   wire [1023:0] eng_shift_wires_ver;
   wire [1023:0] infmap[0:31];
   (* keep = "true" *) wire [1023:0] dataout_a_wires;
   
   
   genvar y;
   generate
        for(y=0;y<3; y=y+1)begin
           assign infmap[y] = (flush== 0) ? mem_data_in[(1024*(y+1))-1:(1024*(y+1))-1024]:1023'd0;      
        end
   endgenerate  



     
   genvar l,m;
   generate
        for(m=0;m<2; m=m+1)begin
                convolution_engine con_inst (                       
                    .clk(clk),                      
                    .rst(rst),
                    .conv_comp(conv_comp),
                    .hold(hold[m]),                      
                    .mem_data_inn(infmap[m]),      
                    .eng_shift((m == 0 ) ? 16'd0 :eng_shift_wires[m-1]),
                    .ENG_shift_out(eng_shift_wires[m]),          
                    .ctrl0(ctrl0),                  
                    .ctrl1(ctrl1),                  
                    .add_enable(add_enable),        
                    .acc_enable(acc_enable),        
                    .add_eng(add_eng[m]),
                    .weight_in(weight[(m*16)+16-1:m*16]),
                    .flush(flush)               
             );  
            end        
   endgenerate
    
   
    


            Super_CE super_ce_inst(
                 .clk(clk),                      
                  .rst(rst),                      
                   .hold(hold[2]),                     
                   .conv_comp(conv_comp),
                   .eng_shift_vert(eng_shift_vert),                     
//                    .Ctrl_act(Ctrl_act),                 
                    .ctrl_bf_conv(ctrl_bf_conv),                  
//                    .ctrl_bf_act(ctrl_bf_act),                   
//                    .ctrl_bf_pool(ctrl_bf_pool),                  
//                    .ctrl_bf_batch(ctrl_bf_batch),                 
//                    .alpha(alpha),             
//                    .beta(beta),              
//                    .mean(mean),              
                   .mem_data_inn(infmap[2]),       
                   .eng_shift_hor(eng_shift_wires[1]),       
                   .ENG_shift_out(eng_shift_wires_ver), 
                   .ctrl0(ctrl0),          // Control
                   .ctrl1(ctrl1),    // Control
                   .add_enable(add_enable),     // Add ena
                   .acc_enable(acc_enable),               
                   .add_eng(add_eng[2]),
                   .weight_in(weight[47:32]),
                   .flush(flush),
                   .dataout_a(dataout_a_wires)                   
            );

  
  wire [R-1:0] mask_row;
  wire [C-1:0] mask_col;
  
  
  
     mask_generator #(
        .R(R),
        .C(C),
        .stride(stride)
    ) u_mask_generator (
        .clk(clk),
        .rst(rst),
        .Kh(Kh),
        .Kw(Kw),
        .mask_row(mask_row),
        .mask_col(mask_col)
    );
    
  
   
  
    
    

        valid_out #(
            .R(R),
            .C(C),
            .WIDTH(WIDTH),
            .stride(stride)         
        ) valid_data_inst (
            .clk(clk),
            .rst(rst),
            .Kh(Kh),
            .Kw(Kw),
            .dataout_a(dataout_a_wires),
            .mask_row(mask_row),
            .mask_col(mask_col),
            .dataout_a_valid(dataout_a)
        );


 
 
 
endmodule
