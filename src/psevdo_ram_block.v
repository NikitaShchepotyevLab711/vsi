module psevdo_ram_block (
    input [8:0] DIn,          
    input [7:0] RADDR,        
    input [7:0] WADDR,       
    input RDB,               
    input WRB,                
    input RCLKS,              
    input WCLKS,              
    input DC_in0,             
    input DC_in1,             
    input DC_in2,            
    output wire [8:0] DO1,    
    output wire [8:0] DO2      
);

reg [8:0] memory_block0 [0:255];
reg [8:0] memory_block1 [0:255];
reg [8:0] memory_block2 [0:255];
reg [8:0] memory_block3 [0:255];

reg [8:0] read_data01;
reg [8:0] read_data23;

always @(posedge WCLKS) begin
    if (!WRB) begin
        case ({DC_in2, DC_in1, DC_in0})
            3'b000: memory_block0[WADDR] <= DIn;
            3'b001: memory_block1[WADDR] <= DIn;
            3'b010: memory_block2[WADDR] <= DIn;
            3'b011: memory_block3[WADDR] <= DIn;
        endcase
    end
end

always @(posedge RCLKS) begin
    if (!RDB) begin
        case ({DC_in2, DC_in1, DC_in0})
            3'b000: begin
						read_data01 <= memory_block0[RADDR];
						read_data23 <= '0;
					end
            3'b001: begin
						read_data01 <= memory_block1[RADDR];
						read_data23 <= '0;
					end
            3'b010: begin
						read_data23 <= memory_block2[RADDR];
						read_data01 <= '0;
					end
            3'b011: begin
						read_data23 <= memory_block3[RADDR];
						read_data01 <= '0;
					end
            default: begin 
						read_data01 <= 9'h0;
						read_data23 <= 9'h0; 
					 end
        endcase
    end
end

assign DO1 = read_data01;  
assign DO2 = read_data23;

endmodule