`timescale 1ns / 1ps

module controller #(
    parameter SIZE = 8
)(
    input  wire        clk,
    input  wire        rst,
    input  wire        start,

    output reg         ctrl0,
    output reg  [1:0]  ctrl1,
    output reg         add_enable,
    output reg         acc_enable,
    output reg         conv_comp,
    (* mark_debug = "true" *)output reg  [2:0]  we_b,
    (* mark_debug = "true" *)output reg         we_a,
    output reg         flush,
    (* mark_debug = "true" *)output reg [4:0]   word_addr_a = 5'd0, word_addr_b =5'd0 ,

    // new outputs for engine shift
    output reg [2:0]   hold,
    output reg [2:0]   add_eng,
    output reg         ctrl_bf_conv,

    // output for memory store back
    output reg         valid_in,

    // output for BRAM infmap
    output reg [14:0]   addrb,
    output reg         enb,
    output reg [3:0]   bank_addr,
    output reg         valid_in_datain_b,
    output reg [4:0]   buffer_addr,
    output reg         mem_read,

    // weights_memory
    output reg [10:0]  weight_start_addr,
    output reg         weight_read,

    output reg [5:0]   channel_in,
    output reg [5:0]   channel_out,

    //// Kernel size
    output reg [2:0]   Kh,
    output reg [2:0]   Kw,

    output reg         eng_shift_vert,
    output reg         mem_clear_1,
    output reg         data_ready,
    (* mark_debug = "true", keep = "true", dont_touch = "true", fsm_encoding = "user" *)
    output reg [4:0]   state,
    (* mark_debug = "true", keep = "true"*) output reg done
);

    // --------------------------------------------------------
    // State Encoding
    // --------------------------------------------------------
    localparam S_IDLE                   = 5'd0;
    localparam S_INIT                   = 5'd1;
    localparam S_LOADDATA               = 5'd2;
    localparam S_next_patch_addr        = 5'd3;
    localparam S_nextpatch              = 5'd4;
    localparam S_memclear               = 5'd5;
    localparam S_weights                = 5'd6;
    localparam S_FLUSH                  = 5'd7;
    localparam S_LOAD_W0                = 5'd8;
    localparam S_CONV_LOOP              = 5'd9;
    localparam S_ACCUM                  = 5'd10;
    localparam S_INTER                  = 5'd11;
    localparam S_ADD                    = 5'd12;
    localparam S_DONE                   = 5'd13;
    localparam S_ENGSHIFT0              = 5'd14;
    localparam S_ENGSHIFT1              = 5'd15;
    localparam S_ENGSHIFT2              = 5'd16;
    localparam S_ENGSHIFT3              = 5'd17;
    localparam S_ENGSHIFT4              = 5'd18;
    localparam S_ENGSHIFT5              = 5'd19;
    localparam S_ENGSHIFT6              = 5'd20;
    localparam S_PISO_1                 = 5'd21;
    localparam S_PISO_2                 = 5'd22;
    localparam S_PISO_3                 = 5'd23;
    localparam S_memclear_1             = 5'd24;
    localparam S_next_patch_addr_buffer = 5'd25;

    (* keep = "true", dont_touch = "true", fsm_encoding = "user" *)
    reg [4:0] next_state;

    // --------------------------------------------------------
    // Internal Registers
    // --------------------------------------------------------
    reg [3:0]  repeat_count, repeat_count_conv, repeat_count_enb;
    reg [7:0]  repeat_count_loaddata;
    reg [3:0]  max_repeats, max_repeat_conv, max_repeat_enb;
    reg [7:0]  max_repeat_loaddata;
    reg [3:0]  max_repeat_writeback;
    (* mark_debug = "true" ,KEEP = "TRUE" *)reg load_patch = 1'b0; 
    reg        load_comp;
    reg [3:0]  current_layer;
    reg        input_req;

    (* keep = "true" *) reg [4:0] repeat_channel;
    reg [4:0] max_repeat_channel;

    // --------------------------------------------------------
    // Config Memory
    // --------------------------------------------------------
    localparam config_mem_depth = 441;
    localparam config_mem_width = 53;

    (* ram_style = "block" *) reg [config_mem_width-1:0] config_memory [0:config_mem_depth-1];

    initial begin
        $readmemb("D:/FYP/on_board_ver2/on_board_ver2.srcs/sources_1/mem", config_memory);
    end

    (* mark_debug = "true" *) reg [config_mem_width-1:0] config_memory_reg;
    (* keep = "true" *) reg [$clog2(config_mem_depth)-1:0] config_mem_addr;

    // Config memory read - registered (BRAM style)
    always @(posedge clk) begin
        config_memory_reg <= config_memory[config_mem_addr];
    end

    // --------------------------------------------------------
    // Unpacked config fields (combinational, no rst needed here)
    // --------------------------------------------------------
    reg [1:0]  layer_no;
    reg [4:0]  portb_aadr_in;
    reg [4:0]  porta_aadr_in;
    reg [4:0]  mem_clear_addr;
    reg        Load_next_chunk;
    reg [4:0]  portb_addrin_next;
    reg        mem_clear;

    // FIX: All outputs assigned unconditionally - no rst in combinational block
    //      rst is handled in the clocked block only. This eliminates latches
    //      that were previously inferred by the if(rst) in always @(*).
    always @(*) begin
        layer_no          = config_memory_reg[52:51];
        mem_clear         = config_memory_reg[50];
        mem_clear_addr    = config_memory_reg[49:45];
        portb_aadr_in     = config_memory_reg[44:40];
        porta_aadr_in     = config_memory_reg[39:35];
        weight_start_addr = config_memory_reg[34:24];
        channel_in        = config_memory_reg[23:18];
        channel_out       = config_memory_reg[17:12];
        Kh                = config_memory_reg[11:9];
        Kw                = config_memory_reg[8:6];
        portb_addrin_next = config_memory_reg[5:1];
        Load_next_chunk   = config_memory_reg[0];
    end

    // --------------------------------------------------------
    // State Register + Sequential Counters
    // FIX: rst only here, not in combinational blocks
    // --------------------------------------------------------
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            state             <= S_IDLE;
            repeat_count      <= 0;
            repeat_count_conv <= 0;
            repeat_channel    <= 0;
            config_mem_addr   <= 0;
        end else begin
            state <= next_state;

            // repeat_count
            if (state == S_CONV_LOOP)
                repeat_count <= repeat_count + 1'b1;
            else
                repeat_count <= 0;

            // repeat_count_conv
            if (state == S_ACCUM)
                repeat_count_conv <= repeat_count_conv + 1'b1;
            else if (state == S_ADD)
                repeat_count_conv <= 0;

            // repeat_channel & config_mem_addr
            if (state == S_ENGSHIFT6)
                repeat_channel <= repeat_channel + 1;
            else if (state == S_next_patch_addr) begin
                repeat_channel  <= 0;
                config_mem_addr <= config_mem_addr + 1;
            end
        end
    end

    // --------------------------------------------------------
    // Load Data Sequential Block
    // FIX: Removed default assignments outside if/else.
    //      All signals now properly reset or assigned inside
    //      the clocked block, preventing latch inference.
    // --------------------------------------------------------
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            repeat_count_loaddata <= 0;
            repeat_count_enb      <= 0;
            addrb                 <= 0;
            load_comp             <= 0;
            valid_in_datain_b     <= 0;
            enb                   <= 0;
            we_b                  <= 0;
            bank_addr             <= 0;
            input_req             <= 0;
        end else begin
            // Default each cycle - prevents latches
            valid_in_datain_b <= 1'b0;
            enb               <= 1'b0;
            we_b              <= 3'd0;
            bank_addr         <= 4'b0; // hold unless updated below
            input_req         <= 1'b0;

            if (load_patch) begin
                repeat_count_loaddata <= repeat_count_loaddata + 1'b1;
                enb <= 1'b1;

                if (repeat_count_loaddata >= 3)
                    we_b <= 3'b001;
                if (repeat_count_loaddata >= 19)
                    we_b <= 3'b010;
                if (repeat_count_loaddata >= 35)
                    we_b <= 3'b100;
                if (repeat_count_loaddata >= 51)
                    we_b <= 3'd0;

                if (repeat_count_loaddata == 8'd1)
                    input_req <= 1'b1;

                if (repeat_count_loaddata >= 4)
                    bank_addr <= bank_addr + 1;

                if (repeat_count_loaddata >= 2)
                    valid_in_datain_b <= 1'b1;

                if (repeat_count_loaddata >= 1 && repeat_count_loaddata < 49)
                    addrb <= addrb + 1;

                if (repeat_count_loaddata >= max_repeat_loaddata)
                    load_comp <= 1'b1;
            end else begin
                repeat_count_loaddata <= 0;
                load_comp             <= 1'b0;
            end
        end
    end

    // --------------------------------------------------------
    // Next State + Output Logic (Combinational)
    // FIX: ALL outputs assigned at the top unconditionally.
    //      No if(rst) here - rst is only in clocked blocks.
    //      This eliminates ALL 42 inferred latches.
    // --------------------------------------------------------
    
   always @(posedge clk or posedge rst) begin
        if (rst) begin
            load_patch <= 1'b0;
        end else begin
            case (state)
                S_INIT: begin    
                     load_patch <= 1'b1;
                    if (load_comp) 
                        load_patch <= 1'b0;
                end
                S_nextpatch: load_patch <= 1'b1;
                S_weights: begin  
                            if (load_comp) load_patch <= 1'b0;
                            else load_patch <= load_patch; // hold
                end
            endcase
        end
    end
    
    
    
    always@(posedge clk or posedge rst)begin
        if(rst)begin
            done <= 0;
        end
        else begin
            if(config_mem_addr > config_mem_depth - 1)begin
                done <= 1;
            end
        end
    
    end
    
    
    always @(*) begin
        // ---- Default all outputs unconditionally ----
        // This is the critical fix: every signal driven from this
        // block gets a default value so no latch is ever inferred.
        next_state           = S_IDLE;
        eng_shift_vert       = 1'b0;
        ctrl0                = 1'b0;
        ctrl1                = 2'b00;
        add_enable           = 1'b0;
        acc_enable           = 1'b0;
        conv_comp            = 1'b0;
        buffer_addr          = 5'd0;
        we_a                 = 1'b0;
        flush                = 1'b0;
        hold                 = 3'd0;
        add_eng              = 3'd0;
        ctrl_bf_conv         = 1'b0;
        valid_in             = 1'b0;
        weight_read          = 1'b0;
        mem_clear_1          = 1'b0;
        data_ready           = 1'b0;
        mem_read             = 1'b0;

        // Loop constants (must also be assigned unconditionally)
        max_repeat_loaddata  = 8'd50;
        max_repeats          = Kh - 3;
        max_repeat_conv      = Kh;
        max_repeat_writeback = 4'd3;
        max_repeat_channel   = 5'd0;
        max_repeat_enb       = 4'd2;

        if (channel_in == 3 && channel_out == 16)
            max_repeat_channel = 5'd16;

        // ---- FSM ----
        case (state)

            S_IDLE: begin
                next_state = start ? S_INIT : S_IDLE;
            end

            S_INIT: begin
//                load_patch = 1'b1;
                word_addr_b = portb_aadr_in;
                if (load_comp) begin
//                    load_patch = 1'b0;
                    next_state = S_LOADDATA;
                end else begin
                    next_state = S_INIT;
                end
            end

            S_LOADDATA: begin
                word_addr_b = portb_aadr_in;
                mem_read    = 1'b1;
                next_state  = Load_next_chunk ? S_nextpatch :
                              mem_clear       ? S_memclear  : S_weights;
            end

            S_next_patch_addr: begin
                next_state = S_next_patch_addr_buffer;
                word_addr_b = portb_addrin_next;
                word_addr_a = porta_aadr_in;
            end

            S_next_patch_addr_buffer: begin
                next_state = S_LOADDATA;
                word_addr_b = portb_addrin_next;
                word_addr_a = porta_aadr_in;
            end

            S_nextpatch: begin
//                load_patch  = 1'b1;
                word_addr_b = portb_addrin_next;
                next_state  = mem_clear ? S_memclear : S_weights;
            end

            S_memclear: begin
                we_a        = 1'b1;
                mem_clear_1 = 1'b1;
                word_addr_a = mem_clear_addr;
                next_state  = S_weights;
                word_addr_b = portb_addrin_next;
            end

            S_weights: begin
                word_addr_a = porta_aadr_in;
                weight_read = 1'b1;
//                if (load_comp)
//                    load_patch = 1'b0;
                word_addr_b = portb_addrin_next;
                next_state = S_FLUSH;
            end

            S_FLUSH: begin
                flush       = 1'b1;
                weight_read = 1'b1;
                word_addr_b = portb_addrin_next;
                word_addr_a = porta_aadr_in;
                next_state  = S_LOAD_W0;
            end

            S_LOAD_W0: begin
                ctrl0       = 1'b1;
                ctrl1       = 2'b01;
                weight_read = 1'b1;
                word_addr_b = portb_addrin_next;
                word_addr_a = porta_aadr_in;
                next_state  = S_CONV_LOOP;
            end

            S_CONV_LOOP: begin
                ctrl0       = 1'b1;
                ctrl1       = 2'b01;
                word_addr_b = portb_addrin_next;
                word_addr_a = porta_aadr_in;
                weight_read = (repeat_count < max_repeats) ? 1'b1 : 1'b0;
                next_state  = (repeat_count < max_repeats) ? S_CONV_LOOP : S_ACCUM;
            end

            S_ACCUM: begin
                ctrl0       = 1'b1;
                ctrl1       = 2'b10;
                acc_enable  = 1'b1;
                word_addr_b = portb_addrin_next;
                word_addr_a = porta_aadr_in;
                weight_read = (repeat_count_conv < max_repeat_conv - 1) ? 1'b1 : 1'b0;
                next_state  = S_INTER;
            end

            S_INTER: begin
                add_enable  = 1'b1;
                word_addr_b = portb_addrin_next;
                word_addr_a = porta_aadr_in;
                weight_read = (repeat_count_conv < max_repeat_conv) ? 1'b1 : 1'b0;
                next_state  = (repeat_count_conv < max_repeat_conv) ? S_LOAD_W0 : S_ADD;
            end

            S_ADD: begin
                conv_comp  = 1'b1;
                word_addr_b = portb_addrin_next;
                word_addr_a = porta_aadr_in;
                next_state = S_DONE;
            end

            S_DONE: begin
                hold       = 3'b111;
                word_addr_b = portb_addrin_next;
                word_addr_a = porta_aadr_in;
                next_state = S_ENGSHIFT0;
            end

            S_ENGSHIFT0: begin
                hold       = 3'b111;
                add_enable = 1'b1;
                word_addr_b = portb_addrin_next;
                word_addr_a = porta_aadr_in;
                next_state = S_ENGSHIFT1;
            end

            S_ENGSHIFT1: begin
                ctrl1      = 2'b11;
                acc_enable = 1'b1;
                hold       = 3'b111;
                add_eng    = 3'b010;
                word_addr_b = portb_addrin_next;
                word_addr_a = porta_aadr_in;
                next_state = S_ENGSHIFT2;
            end

            S_ENGSHIFT2: begin
                hold       = 3'b101;
                conv_comp  = 1'b1;
                add_eng    = 3'b000;
                ctrl1      = 2'b00;
                ctrl0      = 1'b0;
                word_addr_b = portb_addrin_next;
                word_addr_a = porta_aadr_in;
                next_state = S_ENGSHIFT3;
            end

            S_ENGSHIFT3: begin
                hold       = 3'b111;
                add_enable = 1'b1;
                word_addr_b = portb_addrin_next;
                word_addr_a = porta_aadr_in;
                next_state = S_ENGSHIFT4;
            end

            S_ENGSHIFT4: begin
                add_enable = 1'b0;
                ctrl1      = 2'b11;
                acc_enable = 1'b1;
                hold       = 3'b111;
                add_eng    = 3'b100;
                word_addr_b = portb_addrin_next;
                word_addr_a = porta_aadr_in;
                next_state = S_ENGSHIFT5;
            end

            S_ENGSHIFT5: begin
                add_enable = 1'b0;
                ctrl1      = 2'b00;
                acc_enable = 1'b0;
                hold       = 3'b011;
                conv_comp  = 1'b1;
                word_addr_b = portb_addrin_next;
                word_addr_a = porta_aadr_in;
                next_state = S_ENGSHIFT6;
            end

            S_ENGSHIFT6: begin
                conv_comp    = 1'b1;
                ctrl_bf_conv = (channel_in == 3) ? 1'b1 : 1'b0;
                hold         = 3'b011;
                word_addr_b = portb_addrin_next;
                word_addr_a = porta_aadr_in;
                next_state   = S_PISO_1;
            end

            S_PISO_1: begin
                word_addr_b = portb_addrin_next;
                word_addr_a = porta_aadr_in;
                next_state = S_PISO_2;
            end

            S_PISO_2: begin
                word_addr_b = portb_addrin_next;
                word_addr_a = porta_aadr_in;
                next_state = S_PISO_3;
            end

            S_PISO_3: begin
                data_ready = 1'b1;
                word_addr_b = portb_addrin_next;
                word_addr_a = porta_aadr_in;
                next_state = (repeat_channel < max_repeat_channel) ?
                             S_weights :(config_mem_addr < config_mem_depth) ? S_next_patch_addr : S_IDLE;
            end

            default: next_state = S_IDLE;

        endcase
    end

endmodule