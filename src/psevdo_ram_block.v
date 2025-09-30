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

reg [8:0] read_data01;
reg [8:0] read_data23;

always @(posedge WCLKS) begin
    if (!WRB) begin
        memory_block0[WADDR] <= DIn;
    end
end

always @(posedge RCLKS) begin
    if (!RDB) begin
		read_data01 <= memory_block0[RADDR];
		read_data23 <= '0;
	end
end

assign DO1 = read_data01;  
assign DO2 = read_data23;

endmodule