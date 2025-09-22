//###########################################################
//##                                                         
//##   Created       X-CAD v2.76.0                               
//##   Date/Time     11.09.2025 / 15:36:17                                 
//##   Language      Verilog                                      
//##                                                         
//###########################################################

module slave_device(
	input  wire 	   clk,
	input  wire 	   rst_l,
	input  wire 	   ram_rd_rq,
	input  wire [15:0] rd_addr,
	output reg  [7:0]  data_o,
	input  wire 	   new_msg,
	output reg 		   ready
);

wire [7:0] data_gen_by_fpga;
wire [7:0] data_inf;
wire [7:0] data_ram;
reg [15:0] data_h;
wire [8:0] DOut1;
reg RDB;
reg [7:0] raddr;

// специальные сигналы FIFO блока //
wire        fifo_read_clk; 
wire 	    fifo_write_clk;

wire 	    full1;
wire	    empty1;
wire 	    eqth1;
wire	    geqt1;
wire 	    full2;
wire	    empty2;
wire 	    eqth2;
wire 	    geqth2;

codegen #(.DATA_WIDTH(8)) codegen_inst (
	.clk(clk),
	.rst_l(rst_l),
	.data(data_inf),
	.start(1'b1),
	.ready(ready_inf)
);

reg [15:0] rd_addr_reg;
reg [7:0]  data_o_next;
reg        RDB_next;

always @(posedge clk or negedge rst_l) begin : rd_addr_pipeline
    if (!rst_l) begin
        rd_addr_reg <= '0;
        data_o <= '0;
        RDB <= 1;
    end else begin
        rd_addr_reg <= rd_addr;  
        data_o <= data_o_next;   
        RDB <= RDB_next;         
    end
end

reg [7:0] raddr_reg;
always @(posedge clk or negedge rst_l) begin :  rd_addr_pipeline_minus1
    if (!rst_l) 
        raddr_reg <= '0;
    else
        raddr_reg <= rd_addr[7:0] - 1;  
end

always @(posedge clk or negedge rst_l) begin : header_increment
	if (!rst_l) 
		data_h <= '0;
	else
		data_h <= (ram_rd_rq && rd_addr_reg == 0) ? data_h + 1 : data_h;
end

always @(*) begin : package_coding
    case (rd_addr_reg)  
        16'h0: begin
            data_o_next = data_h[15:8];
            RDB_next = 1;
			raddr <= 0;
        end
        16'h1: begin
            data_o_next = data_h[7:0];
            RDB_next = !ram_rd_rq;
			raddr = raddr_reg;
        end
        default: begin
            data_o_next = data_ram;
            RDB_next = !ram_rd_rq;
			raddr = raddr_reg;
        end
    endcase
end

xci2_buf buf3 (
	.a(RDB),
	.y(RDB_buf)
);

xci2_buf buf4a (
	.a(ready_inf),
	.y(WRB_buf)
);

xci2_buf buf7 (
	.a(clk),
	.y(fifo_write_clk)
);

xci2_buf buf8 (
	.a(clk),
	.y(fifo_read_clk)
);

genvar i;
generate
    for (i = 0; i < 8; i = i + 1) begin : data_buf_gen
            xci2_buf buf_inst0 (
                .a(DOut1[i]),       
                .y(data_ram[i])     
            );
    end
endgenerate

`ifdef DEBUG_MODE
	psevdo_ram_block ram0 (
	.DIn({1'b0,data_inf}),
	.RADDR(raddr),
	.WADDR(data_inf),
	.RDB(RDB_buf),
	.WRB(WRB_buf),
	.RCLKS(fifo_read_clk),
	.WCLKS(fifo_write_clk),
	.DC_in0(0),
	.DC_in1(0),
	.DC_in2(0),
	.DO1(DOut1),
	.DO2()
	);
`else
ramblock_4x_swrite_sread ramblock_4x_swrite_sread_instance (
	.DIn({1'b0,data_inf}),
	.RADDR(raddr),
	.WADDR(data_inf),
	.RDB(RDB_buf),
	.WRB(WRB_buf),
	.RCLKS(fifo_read_clk),
	.WCLKS(fifo_write_clk),
	.DC_in0(0),
	.DC_in1(0),
	.DC_in2(0),
	.DO1(DOut1),
	.DO2()
);
`endif

endmodule
