
// CRC-CCITT: xl6 + xl2 + x5 + 1

// Примечание Никифорова Андрея: изменил начальные значения с 0х0000h на 0хFFFFh. (Чтобы был стандартный CRC-CCITT)

//  Name  : CRC-16 CCITT
//  Poly  : 0x1021    x^16 + x^12 + x^5 + 1
//  Init  : 0xFFFF
//  Revert: false
//  XorOut: 0x0000
//  Check : 0x29B1 ("123456789")
//  MaxLen: 4095 байт (32767 бит) - обнаружение
//    одинарных, двойных, тройных и всех нечетных ошибок


//History:
//--------
//v1.1 27/10/2010 - добавил сигнал clk_en, по которому данные записывапются в регистр.	+ reset

module crc16(clk, clk_en, reset, clr, d, data_out);

input clk, clk_en, reset, clr; 
input [7:0] d; 
output [15:0] data_out;

wire [15:0] xor_out; 
reg [15:0] r;
wire [15:0] temr;


assign temr[0] = d[4] ^ d[0];
assign temr[1] = d[5] ^ d[1];
assign temr[2] = d[6] ^ d[2];
assign temr[3] = d[7] ^ d[3];
assign temr[4] = r[12] ^ r[8];
assign temr[5] = r[13] ^ r[9];
assign temr[6] = r[14] ^ r[10];
assign temr[7] = r[15] ^ r[11];
assign temr[8] = d[4] ^ r[12];
assign temr[9] = d[5] ^ r[13];
assign temr[10] = d[6] ^ r[14];
assign temr[11] = d[7] ^ r[15];
assign temr[12] = temr[0] ^ temr[4];
assign temr[13] = temr[1] ^ temr[5];
assign temr[14] = temr[2] ^ temr[6];
assign temr[15] = temr[3] ^ temr[7];

assign xor_out[0] = temr[12];
assign xor_out[1] = temr[13];
assign xor_out[2] = temr[14];
assign xor_out[3] = temr[15];
assign xor_out[4] = temr[8];
assign xor_out[5] = temr[9] ^  temr[12];
assign xor_out[6] = temr[10] ^  temr[13];
assign xor_out[7] = temr[11] ^  temr[14];
assign xor_out[8] = temr[15] ^ r[0];
assign xor_out[9] = temr[8] ^ r[1];
assign xor_out[10] = temr[9] ^ r[2];
assign xor_out[11] = temr[10] ^ r[3];
assign xor_out[12] = temr[11] ^ temr[12] ^ r[4];
assign xor_out[13] = temr[13] ^ r[5];
assign xor_out[14] = temr[14] ^ r[6];
assign xor_out[15] = temr[15] ^ r[7];

always @(posedge clk or negedge reset) 
begin
	if (~reset)  							// глобальный сброс
		begin
			r <= 16'h0;
		end
	else if (!clr) 
		//r <= 0;
		r <= 16'hffff; // Никифоров Андрей
	else if (clk_en)
		r <= xor_out;
end

assign data_out = r; 

endmodule