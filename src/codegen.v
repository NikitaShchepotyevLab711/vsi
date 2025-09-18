//###########################################################
//##                                                         
//##   Created       X-CAD v2.76.0                               
//##   Date/Time     22.01.2025 / 13:13:17                                 
//##   Language      Verilog                                      
//##                                                         
//###########################################################

module codegen #(
	parameter DATA_WIDTH = 8
) (
	input  wire clk,
	input  wire rst_l,
	output reg ready,
	input wire start,
	output wire [DATA_WIDTH-1:0] data
);
	
reg [DATA_WIDTH-1:0] increment;

always @(posedge clk or negedge rst_l) begin
	if (!rst_l) begin
		increment <= '0;
		ready <= 0;
	end
	else begin
		if (start)
			if (increment < 8'hff) begin
				increment <= increment + 1;
				ready <= 0;
			end
			else	
				ready <= 1;
	end
end

assign data = increment;

endmodule