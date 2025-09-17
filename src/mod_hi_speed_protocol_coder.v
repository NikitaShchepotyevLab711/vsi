/*
MODULE: mod_hi_speed_protocol_coder. v1.0 06/12/2010.

Written by Nikiforov Andrey (C)2010,IKI,Moscow,Russia

ОПИСАНИЕ РАБОТЫ:
----------------

Модуль кодер для работы с высокоскоростным интерфейсом.

History:
--------
v1.0 06/12/2010 - начало.
*/

module mod_hi_speed_protocol_coder(
CLK, 
RESET,

CLK_EN_RS, 

TX_STR,
TX_FLAG,
TX_BYTE_NUMBER,

TX_RAM_REQ_RD,
TX_RAM_RDY_RD,
TX_RAM_ADDR_OUT,
TX_RAM_DATA_IN,

CODING,
OUT,

test
);

///////////////////////////////////////////////////////////////////
//
// Parameters
// 

//`define test_simulation

parameter QUARTZ = 24;

parameter [7:0] MARKER_BYTE = 8'hb6;


//`ifdef test_simulation 	// TEST СИМУЛЯЦИЯ!!!
//
//	// Ширина адресной шины
//	parameter WIDTHAD = 20;
//
//`else 					// WORK РАБОЧИЙ РЕЖИМ
//
//	// Ширина адресной шины
//	parameter WIDTHAD = 0;
//
//`endif

///////////////////////////////////////////////////////////////////
//
// Inputs, Outputs, InOuts
// 

// Входная частота. Контроллер полностью синхронизирован от этой частоты
input 			CLK; 
// Общий ресет контроллера. GND - активный. (то есть при GND  всё в ресете.)
input 			RESET;

// частота передачи данных по интерфейсу RS-485
input 			CLK_EN_RS;

// Строб отправки сообщения на передачу
input 			TX_STR;
// Флаг сообщения на передачу
input [7:0] 	TX_FLAG;
// Кол-во байт данных на передачу
input [15:0]	TX_BYTE_NUMBER;

// запрос на чтение из памяти
output 			TX_RAM_REQ_RD;
// завершение действия по запросу на чтение из памяти
input 			TX_RAM_RDY_RD;
// выходная шина адреса
output [15:0]	TX_RAM_ADDR_OUT;
// входная шина данных
input  [7:0]	TX_RAM_DATA_IN;

// Сигнал кодирования сообщения
output 			CODING;
// выходная линия
output 			OUT;


output [31:0] test;
///////////////////////////////////////////////////////////////////
//
// Local Wires and Registers
//

// Модуль RS_CODER
wire		rs_coder_CODING;
wire		rs_coder_FULL;
wire		rs_coder_TIME_OUT;

// данные, выдаваемые в кодер
reg [7:0]	coder_data_in;

// Модуль crc16
wire [15:0]	crc16_coder_data_out;

// Сигнал для переключения номера байта
reg			coder_wr_in_dff;

////////////////////// КОНТРОЛЛЕР ДЕЙСТВИЙ //////////////////////////////////////////////////////

reg	[3:0]	fsm_state;

parameter	FSM_IDLE 			= 4'd0,
			FSM_TX_MARKER 		= 4'd1,
			FSM_TX_MARKER_END 	= 4'd2,
			FSM_TX_DATA1 		= 4'd3,
			FSM_TX_DATA2 		= 4'd4,
			FSM_TX_DATA_END		= 4'd5,
            FSM_TX_CRC     		= 4'd6,
            FSM_TX_CRC_END    	= 4'd7;

reg			crc_en;
reg	[1:0]	flag_tx_count;
reg	[15:0]	tx_count;
reg	[15:0]	TX_RAM_ADDR_OUT;
reg			CODING;
reg	[7:0]	reg_tx_flag;
reg	[15:0]	reg_tx_byte_number;
reg			coder_wr_in;
reg			TX_RAM_REQ_RD;
reg	[7:0]	reg_data;

///////////////////////////////////////////////////////////////////
//
// Begin

// Модуль RS_CODER
rs_coder #(.PARITY_BIT("ON"), .STOP_BIT(1), .WAIT_END(1), .FIRST_BIT("LSB")) rs_coder_inst(
.CLK			(CLK),
.CLK_EN			(CLK_EN_RS),
.RESET			(RESET), 
.WR_DATA		(coder_data_in[7:0]),
.WR_EN			(coder_wr_in),

.OUT			(OUT),
.CODING			(rs_coder_CODING),
.FULL			(rs_coder_FULL),
.TIME_OUT		(rs_coder_TIME_OUT)
);

// данные, выдаваемые в кодер
always @(*) 
begin
	case (flag_tx_count[1:0])
		2'd0	: 	begin // МАРКЕР
						case (tx_count[15:0])
							16'd0	: 	coder_data_in[7:0] = MARKER_BYTE[7:0];
							16'd1	: 	coder_data_in[7:0] = reg_tx_flag[7:0];
							16'd2	: 	coder_data_in[7:0] = reg_tx_byte_number[15:8];
							default : 	coder_data_in[7:0] = reg_tx_byte_number[7:0];
						endcase
					end
		2'd1	: 	begin // ДАННЫЕ
						coder_data_in[7:0] = reg_data[7:0];
					end
		default	: 	begin // CRC
						case (tx_count[15:0])
							16'd0	: 	coder_data_in[7:0] = crc16_coder_data_out[15:8];
							default : 	coder_data_in[7:0] = crc16_coder_data_out[7:0];
						endcase
					end
	endcase
end

wire crc_clk_en = CLK_EN_RS & coder_wr_in & crc_en;

// Модуль crc16
crc16 crc16_coder(
.clk		(CLK), 
.clk_en		(crc_clk_en), 
.reset		(RESET),
.clr		(CODING), 
.d			(coder_data_in[7:0]),	// [7:0] 
.data_out	(crc16_coder_data_out[15:0])  // [15:0]
);

assign test[31:0] = {4'b0, CLK, CLK_EN_RS & coder_wr_in & crc_en, RESET, CODING, coder_data_in[7:0], crc16_coder_data_out[15:0]};

// Сигнал для переключения номера байта
always @ (posedge CLK or negedge RESET)
begin
	if (~RESET) 
		begin
			coder_wr_in_dff <= 1'b0;
     	end
	else if (CLK_EN_RS)
		begin
			coder_wr_in_dff <= coder_wr_in;
		end
end

////////////////////// КОНТРОЛЛЕР ДЕЙСТВИЙ //////////////////////////////////////////////////////
always @ (posedge CLK or negedge RESET)
begin
	if (~RESET) 
		begin
			crc_en <= 1'b0;
			flag_tx_count[1:0] <= 2'd0;
			tx_count[15:0] <= 16'd0;
			TX_RAM_ADDR_OUT[15:0] <= 16'd0;

			CODING <= 1'b0;
			reg_tx_flag[7:0] <= 8'd0;
			reg_tx_byte_number[15:0] <= 16'd0;
			
			coder_wr_in <= 1'b0;
			TX_RAM_REQ_RD <= 1'b0;
			reg_data[7:0] <= 8'd0;
			
			fsm_state  <= FSM_IDLE;
     	end
	else begin
       case(fsm_state)
	 FSM_IDLE : 
		begin	
	 		crc_en <= 1'b1;
			flag_tx_count[1:0] <= 2'd0;
			tx_count[15:0] <= 16'd0;
			TX_RAM_ADDR_OUT[15:0] <= 16'd0;

			coder_wr_in <= 1'b0;
			TX_RAM_REQ_RD <= 1'b0;
			reg_data[7:0] <= 8'd0;
						
			if (TX_STR & ~CODING)
				begin
					CODING <= 1'b1;
					reg_tx_flag[7:0] <= TX_FLAG[7:0];
					reg_tx_byte_number[15:0] <= TX_BYTE_NUMBER[15:0];
					fsm_state  <= FSM_TX_MARKER;
				end
			else
				begin
					CODING <= 1'b0;
				end
	 	end
	 FSM_TX_MARKER :
		begin
			if (CLK_EN_RS)
				begin
					coder_wr_in <= ~coder_wr_in & ~rs_coder_FULL;
					
					if (coder_wr_in_dff)	tx_count[15:0] <= tx_count[15:0] + 1'b1;

					if (coder_wr_in & (tx_count[15:0] == 16'd3))	
						begin
							fsm_state  <= FSM_TX_MARKER_END;
						end
				end
	 	end
	 FSM_TX_MARKER_END :
		begin
			if (CLK_EN_RS)
				begin
					flag_tx_count[1:0] <= flag_tx_count[1:0] + 1'b1;
					tx_count[15:0] <= 16'h0;
					
					if (reg_tx_byte_number[15:0] == 16'd0)	fsm_state  <= FSM_TX_DATA_END;
					else									
						begin
							TX_RAM_REQ_RD <= 1'b1;
							fsm_state  <= FSM_TX_DATA1;
						end
				end
	 	end
	 FSM_TX_DATA1 :
		begin
			if (TX_RAM_RDY_RD)
				begin
					TX_RAM_REQ_RD <= 1'b0;
					reg_data[7:0] <= TX_RAM_DATA_IN[7:0];
					tx_count[15:0] <= tx_count[15:0] + 1'b1;
					TX_RAM_ADDR_OUT[15:0] <= TX_RAM_ADDR_OUT[15:0] + 1'b1;
					fsm_state  <= FSM_TX_DATA2;
				end
			else
				begin
					TX_RAM_REQ_RD <= 1'b1;
				end
	 	end
	 FSM_TX_DATA2 :
		begin
			if (CLK_EN_RS)
				begin
					coder_wr_in <= ~coder_wr_in & ~rs_coder_FULL;
					
					if (coder_wr_in)
						begin
							if (tx_count[15:0] == reg_tx_byte_number[15:0])		fsm_state  <= FSM_TX_DATA_END;
							else									
								begin
									TX_RAM_REQ_RD <= 1'b1;
									fsm_state  <= FSM_TX_DATA1;
								end
						end
				end
	 	end
	 FSM_TX_DATA_END :
		begin
			if (CLK_EN_RS)
				begin
					flag_tx_count[1:0] <= flag_tx_count[1:0] + 1'b1;
					tx_count[15:0] <= 16'd0;
					crc_en <= 1'b0;
					
					fsm_state  <= FSM_TX_CRC;
				end
	 	end
	 FSM_TX_CRC :
		begin
			if (CLK_EN_RS)
				begin
					coder_wr_in <= ~coder_wr_in & ~rs_coder_FULL;
					
					if (coder_wr_in_dff)	tx_count[15:0] <= tx_count[15:0] + 1'b1;

					if (coder_wr_in & (tx_count[15:0] == 16'd1))
						begin
							fsm_state  <= FSM_TX_CRC_END;
						end
				end
	 	end
	 FSM_TX_CRC_END :
		begin
			if (CLK_EN_RS)
				begin
					if (~rs_coder_CODING) fsm_state  <= FSM_IDLE;
				end
	 	end		 	
	default : 				fsm_state  <= FSM_IDLE;
       endcase
	end
end

endmodule
