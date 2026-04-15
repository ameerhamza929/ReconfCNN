`timescale 1ns / 1ps

module Accelerator_core #(
 parameter SIZE = 8,        // 8x8 arr
 parameter WIDTH = 16,
 parameter R = 8,
 parameter C = 8,
 parameter stride = 2,
 parameter integer channel_in     = 3,
 parameter integer channel_out    = 16,
 parameter integer WORD_WIDTH     = 64,   // bits per bank word
 parameter integer MAX_R          = 8,    // designed tile rows (e.g., 8)
 parameter integer MAX_C          = 8,    // designed tile cols (e.g., 8)

 parameter integer NUM_BANKS      = 16,
 parameter integer NUM_BUFFER    = 3,
 parameter total_CE_engines = 3
 
)(
    input clk,
    input rst,
    input ce,
    input start,
    (* keep = "true" *) output [31:0] mem_data_out,
    (* keep = "true" *) output [4:0] state,
    output wire data_ready,
    output wire done
);


    wire [3:0] bank_addr;            
               



     (* mark_debug = "true", keep = "true" *) wire [63:0] datain_b0, datain_b1, datain_b2;

   

    // Intermediate connection from memory array
    (* keep = "true" *) wire [3071:0] mem_data_bus; // 64*16 banks = 1024 * 64 bits = 65536 bits = 32767:0
    wire [1023:0] dataout_a;
   (* keep = "true" *) wire [191:0] datain_b_wires;
    
    assign datain_b_wires = {
     datain_b2,  datain_b1,  datain_b0
};
    
    wire [5:0] channel_in_1;
    wire [5:0] channel_out_1;
    wire [2:0] Kh_1;
    wire [2:0] Kw_1;
    wire ctrl_bf_pool;
    wire [1:0] Ctrl_act;       
//    input ctrl_bf_conv,        
    wire ctrl_bf_act;
    
    wire ctrl0;
    wire [1:0]ctrl1;
    wire add_enable;
    wire acc_enable;
    wire flush;
   
    wire conv_comp;
    wire [2:0] we_b;
    wire we_a;
    wire [4:0] word_addr_a, word_addr_b;
    
    wire [2:0] hold;
    wire [2:0] add_eng;
    wire        ctrl_bf_conv;
   
   
   wire valid_in;

//    mem_addr
   wire[14:0] addrb;
   wire[63:0]doutb;
   wire enb;
    wire[14:0] addra;
   wire[63:0]dina;
   wire ena;
   
   assign addra = 8'd0;
   assign ena  = 1'b0;
   assign dina = 64'd0;
   
   wire valid_in_datain_b;
 wire mem_read;
 
 
 
 wire [10:0] weight_start_addr;
 wire weight_read;
 

                
                                   
   
    
 wire mem_clear_1;
// wire data_ready;

wire eng_shift_vert; 


 (* dont_touch = "true" *) controller #(
    .SIZE(SIZE)

) uut (
    .clk(clk),
    .rst(rst),
    .start(start),

    .ctrl0(ctrl0),
    .ctrl1(ctrl1),
    .add_enable(add_enable),
    .acc_enable(acc_enable),
    .conv_comp(conv_comp),
    .we_a(we_a),
    .we_b(we_b),
    .flush(flush),
    .word_addr_a(word_addr_a),
    .word_addr_b(word_addr_b),

    // New engine shift outputs
    .hold(hold),
    .add_eng(add_eng),
    .ctrl_bf_conv(ctrl_bf_conv),
    
    .valid_in(valid_in),
    
    .addrb(addrb),
    .enb(enb),
    .bank_addr(bank_addr),
    .valid_in_datain_b(valid_in_datain_b),
    .mem_read(mem_read),
    
    .weight_start_addr(weight_start_addr),
    .weight_read(weight_read),
    
   .channel_in (   channel_in_1    ),
   .channel_out(    channel_out_1   ),
   .Kh         (    Kh_1   ),
   .Kw         (    Kw_1  ) ,
   
   .eng_shift_vert(eng_shift_vert),
   
   .mem_clear_1(mem_clear_1),
   .data_ready (data_ready),
   .state(state),
   .done(done)
);



blk_mem_gen_0 BRAM_inst(
    .addra(addra),
    .clka(clk),
    .dina(dina),
    .ena(ena),
    .addrb(addrb),
    .clkb(clk),
    .doutb(doutb),
    .enb(enb)

);




data_from_blk_to_buffer_lines  

u_data_from_blk_to_buffer_lines (
    .clk        (clk),
    .rst        (rst),
    .doutb      (doutb),
    .valid_in   (valid_in_datain_b),

    .channel_in (channel_in) , 
    .channel_out (channel_out),


    .datain_b0  (datain_b0),
    .datain_b1  (datain_b1),
    .datain_b2  (datain_b2)
    
);


     (* mark_debug = "true", keep = "true" *) wire  [total_CE_engines*WIDTH -1:0] weights;

    weight_memory #(
    .WIDTH(WIDTH),
    .Active_accelerator_rows(1),
    .total_CE_engines(3),
    .WORD_WIDTH(WORD_WIDTH),
    .weight_mem_depth(144),
    .CE_per_row(3)
) u_weight_mem (
    .clk   (clk),
    .rst   (rst),
    .Kh(Kh_1),
    .Kw(Kw_1),
    .channel_in(channel_in_1),
    .channel_out(channel_out_1),
    .start_addr (weight_start_addr),
    .weight_read(weight_read),
    .weight     (weights)
);



    // Instantiate memory array
    memory_array  #(
    .ELEM_WIDTH    (WIDTH  ),
    .WORD_WIDTH    (WORD_WIDTH  ),
    .MAX_R         (R       ),
    .MAX_C         (C ),
    .NUM_BANKS     (NUM_BANKS   ),
    .NUM_BUFFER    (NUM_BUFFER  )
    
    )mem_inst (
        
        .clk(clk),
        .rst(rst),
        .mem_clear_1(mem_clear_1),
        .channel_in(channel_in_1),
        .channel_out(channel_out_1),
        .Kh(Kh_1),
        .Kw(Kw_1),
        .stride(stride), 
        .ce(ce),
        .flush(flush),
        .we_b(we_b),
        .mem_read(mem_read),
        .valid_in(valid_in),
        .bank_addr(bank_addr),
        .word_addr_a(word_addr_a),
        .word_addr_b(word_addr_b),
        .datain_b(datain_b_wires),
        .dataout(mem_data_bus)  // entire memory output
    );
    
    

    // Instantiate accelerator top module
    top_module #(
    .SIZE (SIZE),
    .WIDTH (WIDTH),   
    .R     (R)        ,
    .C     (C)        ,
    .stride (stride)
    ) accelerator_inst (
        .clk(clk),
        .rst(rst),
        .Kh    (Kh_1)       ,
        .Kw    (Kw_1)       , 
        .hold(hold),
        .eng_shift_vert(eng_shift_vert),
        .conv_comp(conv_comp),
        .ctrl_bf_conv(ctrl_bf_conv),

        .mem_data_in(mem_data_bus),       // full memory input
        .ctrl0(ctrl0),
        .ctrl1(ctrl1),
        .add_enable(add_enable),
        .acc_enable(acc_enable),
        .add_eng(add_eng),
        .weight(weights),
        .flush(flush),
        .dataout_a(dataout_a)
    );


    PISO u_piso (
        .clk          (clk),
        .rst          (rst),
        .datain       (dataout_a),
        .data_ready   (data_ready),
        .mem_data_out (mem_data_out)
    );
    
   
        
////         Write Address Channel
//        wire [4:0]  s_axi_awaddr = 0;
//        wire        s_axi_awvalid= 0;
//        wire        s_axi_awready= 0;
        
//        // Write Data Channel
//        wire [31:0] s_axi_wdata =0;
//        wire [3:0]  s_axi_wstrb =0;
//        wire        s_axi_wvalid=0;
//        wire        s_axi_wready=0;
        
//        // Write Response Channel
//        wire [1:0]  s_axi_bresp = 0;
//        wire        s_axi_bvalid= 0;
//        wire        s_axi_bready= 0;
        
//        // Read Address Channel
//        wire [4:0]  s_axi_araddr = 0;
//        wire        s_axi_arvalid= 0;
//        wire        s_axi_arready= 0;
        
//        // Read Data Channel
//        wire [31:0] s_axi_rdata = 0;
//        wire [1:0]  s_axi_rresp = 0;
//        wire        s_axi_rvalid= 0;
//        wire        s_axi_rready= 0;
        
//        wire capture_done = 0;
    
//    axi_piso_capture #(
//    .NUM_WORDS(3),
//    .C_S_AXI_DATA_WIDTH(32),
//    .C_S_AXI_ADDR_WIDTH(5)
//) axi_piso_capture_inst (
//    .s_axi_aclk        (clk),
//    .s_axi_aresetn     (rst),

//    .s_axi_awaddr      (s_axi_awaddr),
//    .s_axi_awvalid     (s_axi_awvalid),
//    .s_axi_awready     (s_axi_awready),

//    .s_axi_wdata       (s_axi_wdata),
//    .s_axi_wstrb       (s_axi_wstrb),
//    .s_axi_wvalid      (s_axi_wvalid),
//    .s_axi_wready      (s_axi_wready),

//    .s_axi_bresp       (s_axi_bresp),
//    .s_axi_bvalid      (s_axi_bvalid),
//    .s_axi_bready      (s_axi_bready),

//    .s_axi_araddr      (s_axi_araddr),
//    .s_axi_arvalid     (s_axi_arvalid),
//    .s_axi_arready     (s_axi_arready),

//    .s_axi_rdata       (s_axi_rdata),
//    .s_axi_rresp       (s_axi_rresp),
//    .s_axi_rvalid      (s_axi_rvalid),
//    .s_axi_rready      (s_axi_rready),

//    // PISO interface
//    .mem_data_out      (mem_data_out),
//    .data_valid        (data_ready),

//    .capture_done      (capture_done)
//);




endmodule
