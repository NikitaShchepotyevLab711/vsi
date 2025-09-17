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
	input  wire 	   start,
	output wire [7:0]  data_o

);

wire [7:0] data_gen_by_fpga;

// специальные сигналы FIFO блока //
wire 	    rst_l_buf;
wire [7:0]  RADDR = 8'hff;
wire [7:0]  WADDR = {4'b0000,rst_l_buf,3'b111};
wire 	    fifo_write_ena;
wire        fifo_read_ena;
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

codegen codegen_inst (
	.clk(clk),
	.rst_l(rst_l),
	.start(ram_rd_rq),
	.data(data_o)
);
/*
xci2_buf buf3 (
	.a(RDB),
	.y(RDB_buf)
);
xci2_buf buf4a (
	.a(WRB),
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
                .y(data_o[i])     
            );
    end
endgenerate

// блок FIFO //
cell_fifo_4x_swrite_sread fifo0(
	.DIn   ({1'b0,}		  ),    
	.RADDR (RADDR		  	  ),    
	.WADDR (WADDR		  	  ),    
	.RDB   (!RDB_buf	 	  ),   
	.WRB   (!WRB_buf		  ),   
	.RCLKS (fifo_read_clk 	  ),    
	.WCLKS (fifo_write_clk	  ),    
	.DC_in0(DC_in0	 	  	  ),    
	.DC_in1(DC_in1		  	  ),    
	.DC_in2(1'b0			  ),    
	.DO1   (data_gen_by_fpga  ), 
	.DO2   (DOut2			  ),
	.FULL2 (full2			  ),
	.EMPTY2(empty2			  ),
	.EQTH2 (eqth2			  ),
	.GEQTH2(geqth2		   	  ),
	.FULL1 (full1			  ),
	.EMPTY1(empty1			  ),
	.EQTH1 (eqth1			  ),
	.GEQTH1(geqth1			  )
);
*/
endmodule
