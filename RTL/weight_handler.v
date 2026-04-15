`timescale 1ns / 1ps

module weight_memory #(
    parameter WIDTH                  = 16,
    parameter Active_accelerator_rows = 1,
    parameter total_CE_engines       = 3,
    parameter integer WORD_WIDTH     = 64,
    parameter weight_mem_depth       = 144,
    parameter CE_per_row             = 3
)(
    input        clk,
    input        rst,
    input [2:0]  Kh,
    input [2:0]  Kw,
    input [5:0]  channel_in,
    input [5:0]  channel_out,
    input [$clog2(weight_mem_depth)-1:0] start_addr,
    input        weight_read,
    output reg [(WIDTH*total_CE_engines)-1:0] weight
);

    // --------------------------------------------------------
    // Memory array
    // --------------------------------------------------------
    (* ram_style = "block" *) reg [WORD_WIDTH-1:0] memory [0:weight_mem_depth-1];

    initial begin
        $readmemh("D:/FYP/Conv_eng_Synth/Conv_eng_Synth.srcs/weights.txt", memory);
    end

    // --------------------------------------------------------
    // Combinational: active CE count and kernel size
    // --------------------------------------------------------
    reg [3:0] ACTIVE_CE_PER_ROW;
    reg [5:0] TOTAL_ACTIVE_CEs;
    reg [4:0] Kh_times_Kw_minus_1;

    always @(*) begin
        case (channel_in)
            5'd3:    ACTIVE_CE_PER_ROW = 3;
            5'd16:   ACTIVE_CE_PER_ROW = CE_per_row;
            default: ACTIVE_CE_PER_ROW = 0;
        endcase
        TOTAL_ACTIVE_CEs     = ACTIVE_CE_PER_ROW * Active_accelerator_rows;
        Kh_times_Kw_minus_1  = (Kh * Kw) - 1;
    end

    // --------------------------------------------------------
    localparam LINES_PER_FILTER = 3;

    // --------------------------------------------------------
    // Counters
    // --------------------------------------------------------
    reg [$clog2(weight_mem_depth)-1:0] current_base_addr;
    reg [$clog2(LINES_PER_FILTER*4):0] weight_counter;
    reg [31:0]                          channel_out_index;

    // --------------------------------------------------------
    // first_read_after_start - plain register, no self-loop
    // --------------------------------------------------------
    reg first_read_after_start;

    always @(*) begin
        if (rst)
            first_read_after_start <= 1'b1;
        else if (channel_out_index >= channel_out)
            first_read_after_start <= 1'b1;
        else if (weight_read)
            first_read_after_start <= 1'b0;
    end

    // --------------------------------------------------------
    // CE index mapping function
    // --------------------------------------------------------
    function integer get_ce_global_index;
        input integer linear_idx;
        integer row, pos;
        begin
            if (channel_in == 3) begin
                row = linear_idx / ACTIVE_CE_PER_ROW;
                pos = linear_idx % ACTIVE_CE_PER_ROW;
                get_ce_global_index = row * CE_per_row + (CE_per_row - ACTIVE_CE_PER_ROW) + pos;
            end
            else if (channel_in == 16) begin
                get_ce_global_index = linear_idx;
            end
            else begin
                get_ce_global_index = 0;
            end
        end
    endfunction

    // --------------------------------------------------------
    // Combinational: address and word offset
    // --------------------------------------------------------
    integer i;
    reg [$clog2(weight_mem_depth)-1:0] addr [0:2];
    reg [1:0] word_offset;

    always @(*) begin
        for (i = 0; i < TOTAL_ACTIVE_CEs; i = i + 1) begin
            addr[i] = current_base_addr + (i * LINES_PER_FILTER) + (weight_counter / 4);
        end
        word_offset = weight_counter % 4;
    end

    // --------------------------------------------------------
    // Sequential: memory read + counter update
    // Everything is inside a single if(rst)/else tree -
    // no floating if() outside it, which caused [Synth 8-91]
    // --------------------------------------------------------
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            current_base_addr <= 0;
            weight_counter    <= 0;
            channel_out_index <= 0;
            weight            <= 0;
        end
        else begin
            // -- priority 1: reload base address on new start --
            if (first_read_after_start) begin
                current_base_addr <= start_addr;
                weight_counter    <= 0;
                channel_out_index <= 0;
            end
            // -- priority 2: normal read --
            else if (weight_read) begin
                for (i = 0; i < TOTAL_ACTIVE_CEs; i = i + 1) begin
                    case (word_offset)
                        2'd0: weight[get_ce_global_index(i)*WIDTH +: WIDTH] <= memory[addr[i]][15:0];
                        2'd1: weight[get_ce_global_index(i)*WIDTH +: WIDTH] <= memory[addr[i]][31:16];
                        2'd2: weight[get_ce_global_index(i)*WIDTH +: WIDTH] <= memory[addr[i]][47:32];
                        2'd3: weight[get_ce_global_index(i)*WIDTH +: WIDTH] <= memory[addr[i]][63:48];
                    endcase
                end

                if (weight_counter >= Kh_times_Kw_minus_1) begin
                    weight_counter    <= 0;
                    if (channel_in == 3)
                        channel_out_index <= channel_out_index + 1;
                    current_base_addr <= current_base_addr + (TOTAL_ACTIVE_CEs * LINES_PER_FILTER);
                end
                else begin
                    weight_counter <= weight_counter + 1;
                end
            end
        end
    end

endmodule