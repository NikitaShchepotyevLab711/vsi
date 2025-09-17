/*
MODULE: mod_hi_speed_protocol_decoder. v1.0 06/12/2010.

Written by Nikiforov Andrey (C)2010,IKI,Moscow,Russia

ОПИСАНИЕ РАБОТЫ:
----------------

Модуль декодер для работы с высокоскоростным интерфейсом.

History:
--------
v1.0 06/12/2010 - начало.
*/

module mod_hi_speed_protocol_decoder(
CLK, 
RESET,

CLK_EN_RS, 

IN,

RX_FLAG,
RX_BYTE_NUMBER,
RX_FLAG_BYTE_NUMBER_RD_EN,

RX_RAM_REQ_WR,
RX_RAM_RDY_WR,
RX_RAM_ADDR_OUT,
RX_RAM_DATA_OUT,

DECODING,

RX_END_MESSAGE,
RX_MESSAGE_RIGHT
);

///////////////////////////////////////////////////////////////////
//
// Parameters
// 

//`define test_simulation

parameter QUARTZ = 24;

parameter [7:0] MARKER_BYTE = 8'ha5;

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

// частота в 4 раза больше скорости передачи данных по интерфейсу RS-485
input 			CLK_EN_RS;

// входная линия
input 			IN;

// принятый байт флаг/статус
output [7:0]	RX_FLAG;
// принятое число "кол-во байт данных"
output [15:0]	RX_BYTE_NUMBER;
// сигнал, выставляется сразу после получения флаг/статуса и "кол-ва байт данных"
output			RX_FLAG_BYTE_NUMBER_RD_EN;


// запрос на запись в память
output			RX_RAM_REQ_WR;
// завершение действия по запросу на запись в память
input			RX_RAM_RDY_WR;
// выходная шина адреса
output [15:0]	RX_RAM_ADDR_OUT;
// выходная шина данных
output [7:0]	RX_RAM_DATA_OUT;


// Сигнал декодирования посылки
output 			DECODING;
// Сигнал приема сообщения
output 			RX_END_MESSAGE;
// Сигнал приема правильного сообщения (0 - не правильное сообщение, 1 - правильное сообщение)
output 			RX_MESSAGE_RIGHT;

///////////////////////////////////////////////////////////////////
//
// Local Wires and Registers
//

// ДЕКОДЕР
wire [7:0]	rs_decoder_data_out;
wire		rs_decoder_decoding;
wire		rs_decoder_rd_en;
wire		rs_decoder_end_message;
wire		rs_decoder_error;

// Модуль crc16
wire [15:0]	crc16_decoder_data_out;

// Получение фронта сигнала DECODING
reg [1:0]	rs_decoder_decoding_dff;
reg			rs_decoder_decoding_front;

////////////////////// КОНТРОЛЛЕР ДЕЙСТВИЙ //////////////////////////////////////////////////////

reg	[3:0]	fsm_state;

parameter	FSM_IDLE 			= 4'd0,
			FSM_RX_MARKER 		= 4'd1,
			FSM_RX_MARKER_END 	= 4'd2,
			FSM_RX_DATA1 		= 4'd3,
			FSM_RX_DATA2 		= 4'd4,
			FSM_RX_DATA_END		= 4'd5,
            FSM_RX_CRC     		= 4'd6,
            FSM_RX_CRC_END    	= 4'd7;

reg [15:0]	rx_count;
reg			RX_END_MESSAGE;
reg			RX_MESSAGE_RIGHT;
reg [7:0]	RX_FLAG;
reg [15:0]	RX_BYTE_NUMBER;
reg			RX_FLAG_BYTE_NUMBER_RD_EN;
reg			RX_RAM_REQ_WR;
reg [15:0]	RX_RAM_ADDR_OUT;
reg [7:0]	RX_RAM_DATA_OUT;	
reg			DECODING;
reg			crc_en;
reg [15:0]	reg_crc;		

///////////////////////////////////////////////////////////////////
//
// Begin

// ДЕКОДЕР
rs_decoder_4 #(.PARITY_BIT("ON"), .STOP_BIT(1), .WAIT_END(1), .FIRST_BIT("LSB")) rs_decoder_4_inst(
.CLK			(CLK),
.CLK_EN			(CLK_EN_RS),
.RESET			(RESET), 
.IN				(IN),

.DATA_OUT		(rs_decoder_data_out[7:0]),
.DECODING		(rs_decoder_decoding),
.RD_EN			(rs_decoder_rd_en),
.END_MESSAGE	(rs_decoder_end_message),
.ERROR			(rs_decoder_error)
);

wire crc_clk_en = CLK_EN_RS & rs_decoder_rd_en & crc_en;

// Модуль crc16
crc16 crc16_decoder(
.clk		(CLK), 
.clk_en		(crc_clk_en), 
.reset		(RESET),
.clr		(DECODING), 
.d			(rs_decoder_data_out[7:0]),		// [7:0] 
.data_out	(crc16_decoder_data_out[15:0])  // [15:0]
);

// Получение фронта сигнала DECODING
always @ (posedge CLK or negedge RESET)
begin
	if (~RESET) 
		begin
			rs_decoder_decoding_dff[1:0] <= 2'b0;
			rs_decoder_decoding_front <= 1'b0;
     	end
	else
		begin
			rs_decoder_decoding_dff[1:0] <= {rs_decoder_decoding_dff[0], rs_decoder_decoding};
			rs_decoder_decoding_front <= (rs_decoder_decoding_dff[1:0] == 2'b01);
		end
end

////////////////////// КОНТРОЛЛЕР ДЕЙСТВИЙ //////////////////////////////////////////////////////
always @ (posedge CLK or negedge RESET)
begin
	if (~RESET) 
		begin
			rx_count[15:0] <= 16'b0;
			RX_END_MESSAGE <= 1'b0;
			RX_MESSAGE_RIGHT <= 1'b0;
			RX_FLAG[7:0] <= 8'b0;
			RX_BYTE_NUMBER[15:0] <= 16'b0;
			RX_FLAG_BYTE_NUMBER_RD_EN <= 1'b0;
											
			RX_RAM_REQ_WR <= 1'b0;
			RX_RAM_ADDR_OUT[15:0] <= 16'b0;
			RX_RAM_DATA_OUT[7:0] <= 8'b0;	
			
			reg_crc[15:0] <= 16'b0;
			
			DECODING <= 1'b0;
			crc_en <= 1'b0;
			
			fsm_state  <= FSM_IDLE;
     	end
	else begin
       case(fsm_state)
	 FSM_IDLE : 
		begin	
			rx_count[15:0] <= 16'b0;
			RX_END_MESSAGE <= 1'b0;
			RX_MESSAGE_RIGHT <= 1'b0;
			RX_FLAG[7:0] <= 8'b0;
			RX_BYTE_NUMBER[15:0] <= 16'b0;
			RX_FLAG_BYTE_NUMBER_RD_EN <= 1'b0;
											
			RX_RAM_REQ_WR <= 1'b0;
			RX_RAM_ADDR_OUT[15:0] <= 16'b0;
			RX_RAM_DATA_OUT[7:0] <= 8'b0;								
			
			reg_crc[15:0] <= 16'b0;
																						
			if (rs_decoder_decoding_front & ~DECODING)
				begin
					DECODING <= 1'b1;
					crc_en <= 1'b1;
					fsm_state  <= FSM_RX_MARKER;
				end
			else
				begin
					DECODING <= 1'b0;
					crc_en <= 1'b0;
				end
	 	end
	 FSM_RX_MARKER :
		begin
			if (CLK_EN_RS)
				begin
					if (rs_decoder_error)
						begin
							RX_END_MESSAGE <= 1'b1;
							RX_MESSAGE_RIGHT <= 1'b0;
							fsm_state  <= FSM_IDLE;
						end
					else if (rs_decoder_end_message)
						begin
							RX_END_MESSAGE <= 1'b1;
							RX_MESSAGE_RIGHT <= 1'b0;
							fsm_state  <= FSM_IDLE;
						end
					else if (rs_decoder_rd_en)
						begin
							rx_count[15:0] <= rx_count[15:0] + 1'b1;
							
							case (rx_count[15:0])
								16'd0 : begin
											if (rs_decoder_data_out[7:0] != MARKER_BYTE[7:0])
												begin
													RX_END_MESSAGE <= 1'b1;
													RX_MESSAGE_RIGHT <= 1'b0;
													fsm_state  <= FSM_IDLE;
												end
										end
								16'd1 : begin
											RX_FLAG[7:0] <= rs_decoder_data_out[7:0];
										end
								16'd2 : begin
											RX_BYTE_NUMBER[15:8] <= rs_decoder_data_out[7:0];
										end
								16'd3 : begin
											RX_BYTE_NUMBER[7:0] <= rs_decoder_data_out[7:0];
											RX_FLAG_BYTE_NUMBER_RD_EN <= 1'b1;
											fsm_state  <= FSM_RX_MARKER_END;
										end	
								default : ;
							endcase
						end
				end
	 	end
	 FSM_RX_MARKER_END :
		begin
			rx_count[15:0] <= 16'b0;
			RX_FLAG_BYTE_NUMBER_RD_EN <= 1'b0;
			
			if (RX_BYTE_NUMBER[15:0] == 16'b0)	fsm_state  <= FSM_RX_DATA_END;
			else								fsm_state  <= FSM_RX_DATA1;
	 	end
	 FSM_RX_DATA1 :
		begin
//			// запрос на запись в память
//			output			RX_RAM_REQ_WR;
//			// завершение действия по запросу на запись в память
//			input			RX_RAM_RDY_WR;
//			// выходная шина адреса
//			output [15:0]	RX_RAM_ADDR_OUT;
//			// выходная шина данных
//			output [7:0]	RX_RAM_DATA_OUT;
			
			if (CLK_EN_RS)
				begin
					if (rs_decoder_error)
						begin
							RX_END_MESSAGE <= 1'b1;
							RX_MESSAGE_RIGHT <= 1'b0;
							fsm_state  <= FSM_IDLE;
						end
					else if (rs_decoder_end_message)
						begin
							RX_END_MESSAGE <= 1'b1;
							RX_MESSAGE_RIGHT <= 1'b0;
							fsm_state  <= FSM_IDLE;
						end
					else if (rs_decoder_rd_en)
						begin
							rx_count[15:0] <= rx_count[15:0] + 1'b1;
							RX_RAM_REQ_WR <= 1'b1;
							RX_RAM_DATA_OUT[7:0] <= rs_decoder_data_out[7:0];
							fsm_state  <= FSM_RX_DATA2;
						end
				end
	 	end
	 FSM_RX_DATA2 :
		begin
			if (rs_decoder_rd_en | rs_decoder_end_message)
				begin
					RX_END_MESSAGE <= 1'b1;
					RX_MESSAGE_RIGHT <= 1'b0;
					fsm_state  <= FSM_IDLE;				
				end
			else if (RX_RAM_RDY_WR)
				begin
					RX_RAM_REQ_WR <= 1'b0;
					RX_RAM_ADDR_OUT[15:0] <= RX_RAM_ADDR_OUT[15:0] + 1'b1;
					
					if (rx_count[15:0] == RX_BYTE_NUMBER[15:0])	fsm_state  <= FSM_RX_DATA_END;
					else										fsm_state  <= FSM_RX_DATA1;
				end
	 	end
	 FSM_RX_DATA_END :
		begin
			rx_count[15:0] <= 16'b0;
			crc_en <= 1'b0;
			fsm_state  <= FSM_RX_CRC;
	 	end
	 FSM_RX_CRC :
		begin
			if (CLK_EN_RS)
				begin
					if (rs_decoder_error)
						begin
							RX_END_MESSAGE <= 1'b1;
							RX_MESSAGE_RIGHT <= 1'b0;
							fsm_state  <= FSM_IDLE;
						end
					else if (rs_decoder_end_message)
						begin
							RX_END_MESSAGE <= 1'b1;
							RX_MESSAGE_RIGHT <= 1'b0;
							fsm_state  <= FSM_IDLE;
						end
					else if (rs_decoder_rd_en)
						begin
							rx_count[15:0] <= rx_count[15:0] + 1'b1;
							
							case (rx_count[15:0])
								16'd0 : begin
											reg_crc[15:8] <= rs_decoder_data_out[7:0];
										end
								16'd1 : begin
											reg_crc[7:0] <= rs_decoder_data_out[7:0];
											fsm_state  <= FSM_RX_CRC_END;
										end	
								default : ;
							endcase
						end
				end
	 	end
	 FSM_RX_CRC_END :
		begin
			if (reg_crc[15:0] == crc16_decoder_data_out[15:0])
				begin
					RX_END_MESSAGE <= 1'b1;
					RX_MESSAGE_RIGHT <= 1'b1;
					fsm_state  <= FSM_IDLE;
				end
			else
				begin
					RX_END_MESSAGE <= 1'b1;
					RX_MESSAGE_RIGHT <= 1'b0;
					fsm_state  <= FSM_IDLE;
				end
	 	end		 	
	default : 				fsm_state  <= FSM_IDLE;
       endcase
	end
end


endmodule
