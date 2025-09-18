module cell_ramblock_4x_swrite_sread (
	DIn,
	RADDR,
	WADDR,
	RDB,
	WRB,
	RCLKS,
	WCLKS,
	DC_in0,
	DC_in1,
	DC_in2,
	DO1,
	DO2 );

	input [8:0] DIn;
	input [7:0] RADDR;
	input [7:0] WADDR;
	input RDB;
	input WRB;
	input RCLKS;
	input WCLKS;
	input DC_in0;
	input DC_in1;
	input DC_in2;
	output [8:0] DO1;
	output [8:0] DO2;

	ramblock_4x_swrite_sread ramblock_4x_swrite_sread_instance (
		.DIn(DIn),
		.RADDR(RADDR),
		.WADDR(WADDR),
		.RDB(RDB),
		.WRB(WRB),
		.RCLKS(RCLKS),
		.WCLKS(WCLKS),
		.DC_in0(DC_in0),
		.DC_in1(DC_in1),
		.DC_in2(DC_in2),
		.DO1(DO1),
		.DO2(DO2)
	);

endmodule
