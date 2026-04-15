`timescale 1ns / 1ps

module startup_controller #(
    parameter WIDTH     = 16,
    parameter SIZE      = 8,
    parameter R         = 8,
    parameter C         = 8,
    parameter stride    = 2,
    parameter channel_in  = 3,
    parameter channel_out = 16,
    parameter WORD_WIDTH  = 64,
    parameter MAX_R       = 8,
    parameter MAX_C       = 8,
    parameter NUM_BANKS   = 16,
    parameter NUM_BUFFER  = 3,
    parameter total_CE_engines = 3
)(
    input  wire clk,
    input  wire rst_n,   // <-- add active-low board reset (e.g. from PS or dedicated button)
    (* mark_debug = "true", keep = "true" *) input  wire go,
	(* mark_debug = "true", keep = "true" *) input  wire tx_en,
    (* mark_debug = "true", keep = "true" *) output wire [31:0] mem_data_out,
    output done 
);

    (* keep = "true" *) reg [4:0] state = 5'd0;
    (* keep = "true" *) reg [4:0] counter = 5'd0;
    (* mark_debug = "true", keep = "true" *) wire [4:0] state_cont;
    (* mark_debug = "true", keep = "true" *)  reg  rst;
    (* mark_debug = "true", keep = "true" *)  reg  ce;  
    (* mark_debug = "true", keep = "true" *)  reg  start;
    wire data_ready;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state   <= 5'd0;
            counter <= 5'd0;
            rst     <= 0;
            ce      <= 0;
            start   <= 0;
        end else begin
            case (state)
                5'd0: begin
                    rst   <= 0;
                    ce    <= 0;
                    start <= 0;
                    counter <= 0;
                    if (go && tx_en) state <= 5'd1;
                end
                5'd1: begin rst <= 1; ce <= 0; start <= 0; state <= 5'd2; end
                5'd2: begin rst <= 1; ce <= 0; start <= 0; state <= 5'd3; end
                5'd3: begin rst <= 1; ce <= 0; start <= 0; state <= 5'd4; end
                5'd4: begin rst <= 0; ce <= 0; start <= 0; counter <= 0; state <= 5'd5; end
                5'd5: begin counter <= counter + 1; if (counter == 4'd7) state <= 5'd6; end
                5'd6: begin rst <= 0; ce <= 1; start <= 1; state <= 5'd7; end
                5'd7: begin rst <= 0; ce <= 1; start <= 0; state <= 5'd7; end
                default: state <= 5'd0;
            endcase
        end
    end

    // Accelerator core instantiation
    Accelerator_core #(
        .SIZE             (SIZE),
        .WIDTH            (WIDTH),
        .R                (R),
        .C                (C),
        .stride           (stride),
        .channel_in       (channel_in),
        .channel_out      (channel_out),
        .WORD_WIDTH       (WORD_WIDTH),
        .MAX_R            (MAX_R),
        .MAX_C            (MAX_C),
        .NUM_BANKS        (NUM_BANKS),
        .NUM_BUFFER       (NUM_BUFFER),
        .total_CE_engines (total_CE_engines)
    ) u_core (
        .clk          (clk),
        .rst          (rst),
        .ce           (ce),
        .start        (start),
        .mem_data_out (mem_data_out),
        .state (state_cont),
        .data_ready(data_ready),
        .done(done)
    );

endmodule