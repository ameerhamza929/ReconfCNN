`timescale 1 ns / 1 ps
	module Accelerator_ver_2_0_v1_0 #
	(
		// Users to add parameters here
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
    		 parameter total_CE_engines = 3,

		// User parameters ends
		// Do not modify the parameters beyond this line


		// Parameters of Axi Slave Bus Interface S_AXIS
		parameter integer C_S_AXIS_TDATA_WIDTH	= 32,

		// Parameters of Axi Master Bus Interface M_AXIS
		parameter integer C_M_AXIS_TDATA_WIDTH	= 32,
		parameter integer C_M_AXIS_START_COUNT	= 32
	)
	(
		// Users to add ports here
		input  wire go,                 
		output wire [31:0] mem_data_out, 
	    (* mark_debug = "true", keep = "true" *) output wire tx_en,
	    output wire done,

		// User ports ends
		// Do not modify the ports beyond this line


		// Ports of Axi Slave Bus Interface S_AXIS
		input wire  s_axis_aclk,
		input wire  s_axis_aresetn,
		output wire  s_axis_tready,
		input wire [C_S_AXIS_TDATA_WIDTH-1 : 0] s_axis_tdata,
		input wire [(C_S_AXIS_TDATA_WIDTH/8)-1 : 0] s_axis_tstrb,
		input wire  s_axis_tlast,
		input wire  s_axis_tvalid,

		// Ports of Axi Master Bus Interface M_AXIS
		input wire  m_axis_aclk,
		input wire  m_axis_aresetn,
		output wire  m_axis_tvalid,
		output wire [C_M_AXIS_TDATA_WIDTH-1 : 0] m_axis_tdata,
		output wire [(C_M_AXIS_TDATA_WIDTH/8)-1 : 0] m_axis_tstrb,
		output wire  m_axis_tlast,
		input wire  m_axis_tready
	);
// Instantiation of Axi Bus Interface S_AXIS
	Accelerator_ver_2_0_v1_0_S_AXIS # ( 
		.C_S_AXIS_TDATA_WIDTH(C_S_AXIS_TDATA_WIDTH)
	) Accelerator_v1_0_S_AXIS_inst (
		.S_AXIS_ACLK(s_axis_aclk),
		.S_AXIS_ARESETN(s_axis_aresetn),
		.S_AXIS_TREADY(s_axis_tready),
		.S_AXIS_TDATA(s_axis_tdata),
		.S_AXIS_TSTRB(s_axis_tstrb),
		.S_AXIS_TLAST(s_axis_tlast),
		.S_AXIS_TVALID(s_axis_tvalid)
	);

// Instantiation of Axi Bus Interface M_AXIS
	Accelerator_ver_2_0_v1_0_M_AXIS # ( 
		.SIZE(SIZE),
        .WIDTH(WIDTH),
        .R(R),
        .C(C),
        .stride(stride),
        .channel_in(channel_in),
        .channel_out(channel_out),
        .WORD_WIDTH(WORD_WIDTH),
        .MAX_R(MAX_R),
        .MAX_C(MAX_C),
        .NUM_BANKS(NUM_BANKS),
        .NUM_BUFFER(NUM_BUFFER),
        .total_CE_engines(total_CE_engines),
		.C_M_AXIS_TDATA_WIDTH(C_M_AXIS_TDATA_WIDTH),
		.C_M_START_COUNT(C_M_AXIS_START_COUNT)
	) Accelerator_v1_0_M_AXIS_inst (
		.go(go),
		.mem_data_out(mem_data_out),
		.tx_en(tx_en),
		.done(done),
		.M_AXIS_ACLK(m_axis_aclk),
		.M_AXIS_ARESETN(m_axis_aresetn),
		.M_AXIS_TVALID(m_axis_tvalid),
		.M_AXIS_TDATA(m_axis_tdata),
		.M_AXIS_TSTRB(m_axis_tstrb),
		.M_AXIS_TLAST(m_axis_tlast),
		.M_AXIS_TREADY(m_axis_tready)
	);

	// Add user logic here

	// User logic ends

	endmodule

