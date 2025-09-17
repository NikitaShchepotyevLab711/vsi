//###########################################################
//##                                                         
//##   Created       X-CAD v2.76.0                               
//##   Date/Time     22.01.2025 / 13:13:17                                 
//##   Language      Verilog                                      
//##                                                         
//###########################################################

module codegen(
	input  wire clk,
	input  wire rst_l,
	input  wire start,
	output [7:0] data
);

reg [7:0] increment = 0;

always @(posedge clk or negedge rst_l) begin
	if (!rst_l) 
		increment <= '0;
	else if (start) 
		increment <= increment + 1;
end

assign data = increment;

endmodule