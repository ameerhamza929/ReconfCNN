
module Super_CE #(
    parameter SIZE = 8,        // 8x8 array of processing elements
    parameter WIDTH = 16      //Data size
)(
    input wire clk,
    input wire rst,
    input conv_comp,
    input wire hold,
    input eng_shift_vert,
//    input [1:0]Ctrl_act,
    input ctrl_bf_conv,
//    input ctrl_bf_act,
//    input ctrl_bf_pool,
//    input ctrl_bf_batch,
//    input [WIDTH-1:0] alpha,
//    input [WIDTH-1:0] beta,
//    input [WIDTH-1:0] mean,
    input wire [1023:0] mem_data_inn,         // Data input for unified memory
    input wire [1023:0] eng_shift_hor,         // 1D array for eng_shift from CE
    input wire [1023:0] eng_shift_ver,         // 1D array for eng_shift input from PE
    output wire [1023:0] ENG_shift_out, //ENgine shift from outfmap,
    input wire ctrl0,          // Control signal for each PE
    input wire [1:0] ctrl1,    // Control signal for each PE
    input wire add_enable,     // Add enable signal for each PE
    input wire acc_enable,
    input wire add_eng,
    input [15:0] weight_in,
    input wire flush,
    (* keep = "true" *) output reg [1023:0] dataout_a
 );

    // Wires to connect HOR_shift and VERT_shift between processing elements
    (* keep = "true" *) wire [WIDTH-1:0] HOR_shift_wires [0:SIZE-1][0:SIZE-1];
    (* keep = "true" *) wire [WIDTH-1:0] VERT_shift_wires [0:SIZE-1][0:SIZE-1];
    (* keep = "true" *) wire [WIDTH-1:0] ENG_shift_wires [0:SIZE-1][0:SIZE-1];

     (* keep = "true" *)wire [WIDTH-1:0] ENG_shift_w [(SIZE*SIZE)-1:0];
     
    // Local Memories
    wire [WIDTH-1:0] Infmap [SIZE*SIZE-1:0];    // 2D Array for storing Infmap
    reg [WIDTH-1:0] weight;    // register for storing weight
    reg [WIDTH-1:0] Outfmap [SIZE*SIZE-1:0];  // 2D Array for storing Outfmap
    
    wire [WIDTH-1:0] Outfmap1 [SIZE*SIZE-1:0];
    
    genvar a;
    generate
        for (a = 0; a < SIZE*SIZE; a = a + 1) begin : loop1
            always @ (posedge clk or posedge rst)
                begin
                    if(rst) Outfmap[a] <= 16'd0;
                    else if(conv_comp) begin
                      if(!hold) Outfmap[a]<= Outfmap1[a];
                    end       
                end
            end
    endgenerate
    //assign 
    
    
   genvar c;
   generate
   
        for(c=0; c<64; c = c+1) begin
            assign ENG_shift_w[c] = eng_shift_vert ? eng_shift_ver[(((c+1)*WIDTH) - 1): (c*WIDTH)]: eng_shift_hor[(((c+1)*WIDTH) - 1): (c*WIDTH)];
       end
   endgenerate
   
   
   genvar b;
   generate
        for(b=0; b<64; b = b+1) begin
            assign ENG_shift_out[(((b+1)*WIDTH) - 1): (b*WIDTH)] = (rst) ? 16'd0 : Outfmap[b];
       end
   endgenerate
    
//    assign ENG_shift_out[1023: 1008] = Outfmap[0];
    
    
    // Memory addressing ranges
    localparam INFMAP_START_ADDR = 0;
    localparam WEIGHT_START_ADDR = SIZE * SIZE;  // Assuming 16-bit values and 64-bit memory access
    localparam OUTFMAP_START_ADDR = (SIZE*SIZE)+1;


     assign Infmap[0]  = mem_data_inn[15:0];
     assign   Infmap[1]  = mem_data_inn[31:16];
     assign   Infmap[2]  = mem_data_inn[47:32];
     assign   Infmap[3]  = mem_data_inn[63:48];
     assign   Infmap[4]  = mem_data_inn[79:64];
     assign   Infmap[5]  = mem_data_inn[95:80];
     assign   Infmap[6]  = mem_data_inn[111:96];
     assign   Infmap[7]  = mem_data_inn[127:112];
     assign   Infmap[8]  = mem_data_inn[143:128];
     assign   Infmap[9]  = mem_data_inn[159:144];
     assign   Infmap[10] = mem_data_inn[175:160];
     assign   Infmap[11] = mem_data_inn[191:176];
     assign   Infmap[12] = mem_data_inn[207:192];
     assign   Infmap[13] = mem_data_inn[223:208];
     assign   Infmap[14] = mem_data_inn[239:224];
     assign   Infmap[15] = mem_data_inn[255:240];
     assign   Infmap[16] = mem_data_inn[271:256];
     assign   Infmap[17] = mem_data_inn[287:272];
     assign   Infmap[18] = mem_data_inn[303:288];
     assign   Infmap[19] = mem_data_inn[319:304];
     assign   Infmap[20] = mem_data_inn[335:320];
     assign   Infmap[21] = mem_data_inn[351:336];
     assign   Infmap[22] = mem_data_inn[367:352];
     assign   Infmap[23] = mem_data_inn[383:368];
     assign   Infmap[24] = mem_data_inn[399:384];
     assign   Infmap[25] = mem_data_inn[415:400];
     assign   Infmap[26] = mem_data_inn[431:416];
     assign   Infmap[27] = mem_data_inn[447:432];
     assign   Infmap[28] = mem_data_inn[463:448];
     assign   Infmap[29] = mem_data_inn[479:464];
     assign   Infmap[30] = mem_data_inn[495:480];
     assign   Infmap[31] = mem_data_inn[511:496];
     assign   Infmap[32] = mem_data_inn[527:512];
     assign   Infmap[33] = mem_data_inn[543:528];
     assign   Infmap[34] = mem_data_inn[559:544];
     assign   Infmap[35] = mem_data_inn[575:560];
     assign   Infmap[36] = mem_data_inn[591:576];
     assign   Infmap[37] = mem_data_inn[607:592];
     assign   Infmap[38] = mem_data_inn[623:608];
     assign   Infmap[39] = mem_data_inn[639:624];
     assign   Infmap[40] = mem_data_inn[655:640];
     assign   Infmap[41] = mem_data_inn[671:656];
     assign   Infmap[42] = mem_data_inn[687:672];
     assign   Infmap[43] = mem_data_inn[703:688];
     assign   Infmap[44] = mem_data_inn[719:704];
     assign   Infmap[45] = mem_data_inn[735:720];
     assign   Infmap[46] = mem_data_inn[751:736];
     assign   Infmap[47] = mem_data_inn[767:752];
     assign   Infmap[48] = mem_data_inn[783:768];
     assign   Infmap[49] = mem_data_inn[799:784];
     assign   Infmap[50] = mem_data_inn[815:800];
     assign   Infmap[51] = mem_data_inn[831:816];
     assign   Infmap[52] = mem_data_inn[847:832];
     assign   Infmap[53] = mem_data_inn[863:848];
     assign   Infmap[54] = mem_data_inn[879:864];
     assign   Infmap[55] = mem_data_inn[895:880];
     assign   Infmap[56] = mem_data_inn[911:896];
     assign   Infmap[57] = mem_data_inn[927:912];
     assign   Infmap[58] = mem_data_inn[943:928];
     assign   Infmap[59] = mem_data_inn[959:944];
     assign   Infmap[60] = mem_data_inn[975:960];
     assign   Infmap[61] = mem_data_inn[991:976];
     assign   Infmap[62] = mem_data_inn[1007:992];
     assign   Infmap[63] = mem_data_inn[1023:1008];
   
   integer i, j;
   
    
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            // Reset memory arrays
            weight <= 16'd0;
        end else begin
            weight<= weight_in;
        end
    end   
    
    // Generate block to instantiate 8x8 array of processing elements
    genvar x, y;
    
            
    generate
        for (x = 0; x < SIZE; x = x + 1) begin : row_loop
            for (y = 0; y < SIZE; y = y + 1) begin : col_loop
              (* dont_touch = "true" *) processingelement processing_element_inst (
                    .rst(rst),
                    .clk(clk),
                    .hold(hold),
                    .Infmap(Infmap[(y*SIZE)+x]),
                    .weight(weight),
                    .hor_shift((x == 0 ) ? 16'd0 : HOR_shift_wires[x-1][y]), // For the first PE in each row, connect to hor_shift_init, otherwise connect to the previous PE's HOR_shift
                    .vert_shift((y == 0) ? 16'd0 : VERT_shift_wires[x][y-1]), // For the first PE in each column, connect to vert_shift_init, otherwise connect to the previous PE's VERT_shift
                    .eng_shift(ENG_shift_w[(x*SIZE)+y]),
                    .Outfmap(Outfmap1[((x*8)+y)]),
                    .HOR_shift_out(HOR_shift_wires[x][y]),   // Output HOR_shift is connected to the next PE in the row
                    .VERT_shift_out(VERT_shift_wires[x][y]), // Output VERT_shift is connected to the next PE in the column
                    .ENG_shift_out(ENG_shift_wires[x][y]),
                    .ctrl0(ctrl0),
                    .ctrl1(ctrl1),
                    .add_enable(add_enable),
                    .acc_enable(acc_enable),
                    .add_eng(add_eng),
                    .flush(flush)
                    
                );
            end
        end
    endgenerate
    
//    wire[WIDTH-1:0] activation_res1 [SIZE*SIZE-1:0];
    (* keep = "true" *) reg [WIDTH-1:0] mem_buffer [SIZE*SIZE-1:0];
//    wire [WIDTH-1:0] pool_res[(SIZE*2)-1:0];
//    wire [WIDTH-1:0] batch_res[(SIZE*SIZE)-1:0];

   integer cd;
    always@(posedge clk or posedge rst) begin
        if(rst) begin
                dataout_a <= 1024'd0;
        end
        else begin
            for (cd = 0; cd < 64; cd = cd +1)
                dataout_a[cd*16 +: 16] <= mem_buffer[cd];            
           
            end
    
      end
    
    integer h;
    always @(posedge clk or posedge rst)begin
        if(rst)begin
            for( h=0;h<SIZE*SIZE;h=h+1)begin
                mem_buffer[h]<= 16'd0;
            end
        end
        else if(ctrl_bf_conv) begin
            for( h=0;h<SIZE*SIZE;h=h+1)begin
                if(!hold) mem_buffer[h]<= Outfmap[h];
            end
        end
       
    end

    
    
    
    
    

endmodule
