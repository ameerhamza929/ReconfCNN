`timescale 1 ns / 1 ps

module Accelerator_ver_2_0_v1_0_M_AXIS #
(
    // User parameters
    parameter WIDTH           = 16,
    parameter SIZE            = 8,
    parameter R               = 8,
    parameter C               = 8,
    parameter stride          = 2,
    parameter channel_in      = 3,
    parameter channel_out     = 16,
    parameter WORD_WIDTH      = 64,
    parameter MAX_R           = 8,
    parameter MAX_C           = 8,
    parameter NUM_BANKS       = 16,
    parameter NUM_BUFFER      = 3,
    parameter total_CE_engines = 3,

    // AXI-Stream parameters
    parameter integer C_M_AXIS_TDATA_WIDTH = 32,
    parameter integer C_M_START_COUNT      = 32
)
(
    // User ports
    input  wire        go,
    output wire [31:0] mem_data_out,
	(* mark_debug = "true", keep = "true" *) output wire tx_en,
	output done,

    // AXI-Stream global ports
    input  wire M_AXIS_ACLK,
    input  wire M_AXIS_ARESETN,

    // AXI-Stream master ports
    output wire                                  M_AXIS_TVALID,
    output wire [C_M_AXIS_TDATA_WIDTH-1 : 0]    M_AXIS_TDATA,
    output wire [(C_M_AXIS_TDATA_WIDTH/8)-1 : 0] M_AXIS_TSTRB,
    output wire                                  M_AXIS_TLAST,
    input  wire                                  M_AXIS_TREADY
);

		// ============================================================
		// Internal signals
		// ============================================================

		reg streaming;         // High once 'go' is asserted — stays high (continuous stream)
		//wire tx_en;            // A transfer actually happens this cycle

		// ============================================================
		// Startup controller instantiation
		// ============================================================

		startup_controller #(
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
		) uut (
			.clk         (M_AXIS_ACLK),
			.rst_n       (M_AXIS_ARESETN),
			.go          (go),         // <-- backpressure signal fed in
			.tx_en       (tx_en),
			.mem_data_out(mem_data_out),
			.done(done)
		);

		// ============================================================
		// Streaming enable: latch 'go', never de-assert
		// (change to: streaming <= go; if you want a stoppable stream)
		// ============================================================

		always @(posedge M_AXIS_ACLK) begin
			if (!M_AXIS_ARESETN)
				streaming <= 1'b0;
			else if (go)
				streaming <= 1'b1;
		end

		// ============================================================
		// AXI-Stream handshake
		// tx_en is the ONLY signal that means "data was consumed".
		// Feed this back to startup_controller so it advances its
		// output exactly once per accepted word — no drops, no repeats.
		// ============================================================

		assign tx_en         = M_AXIS_TVALID & M_AXIS_TREADY;

		// ============================================================
		// AXI-Stream outputs
		// ============================================================

		// TVALID: asserted every cycle once streaming is active.
		// The slave can apply backpressure via TREADY.
		assign M_AXIS_TVALID = streaming;

		// TDATA: wire mem_data_out straight to the bus.
		// Data is presented the same cycle TVALID is high.
		// startup_controller must NOT advance its pointer
		// until tx_en pulses — use tx_en as its read-enable.
		assign M_AXIS_TDATA  = mem_data_out;

		// TSTRB: all byte lanes valid
		assign M_AXIS_TSTRB  = {(C_M_AXIS_TDATA_WIDTH/8){1'b1}};
		// Add this register
		reg [3:0] word_count;   // 0-15 counter for 16-word bursts

		// Count accepted words
		always @(posedge M_AXIS_ACLK) begin
			if (!M_AXIS_ARESETN)
				word_count <= 4'd0;
			else if (tx_en) begin                        // only count on accepted words
				if (word_count == 4'd15)
					word_count <= 4'd0;
				else
					word_count <= word_count + 1'b1;
			end
		end

		// TLAST goes high on the 16th word of every burst
		assign M_AXIS_TLAST = (word_count == 4'd15) && M_AXIS_TVALID;

		// TLAST: tie low for a continuous / infinite stream.
		// Set to 1 on the last word if your protocol requires packets.

endmodule