/*
MODULE: mod_hi_speed_protocol_rx. v1.1 24/03/2011.

Written by Nikiforov Andrey (C)2011,IKI,Moscow,Russia

ОПИСАНИЕ РАБОТЫ:
----------------

History:
--------
v1.0 06/12/2010 - начало.
v1.1 24/03/2011 - переделал, чтобы был одновременный прием и передача.
*/

module mod_hi_speed_protocol_rx(
//////////////////////////// ОБЩИЕ
CLK, 
RESET,

CODING,
DECODING,

//////////////////////////// БИТЫ УПРАВЛЕНИЯ

BIT_SR,
BIT_BUSY,

//////////////////////////// ПРИЕМ СООБЩЕНИЙ
CLK_EN_RS_DECODER,

RX_FLAG,
RX_BYTE_NUMBER,
RX_FLAG_BYTE_NUMBER_RD_EN,

RX_RAM_REQ_WR,
RX_RAM_RDY_WR,
RX_RAM_ADDR_OUT,
RX_RAM_DATA_OUT,

RX_END_MESSAGE,
RX_MESSAGE_RIGHT,
RX_END_MESSAGE_LINE,

//////////////////////////// ПЕРЕДАЧА СООБЩЕНИЙ
CLK_EN_RS_CODER,

TX_RAM_REQ_RD,
TX_RAM_RDY_RD,
TX_RAM_ADDR_OUT,
TX_RAM_DATA_IN,

FLAG_DATA_OUT,

//////////////////////////// ВХОДНЫЕ И ВЫХОДНЫЕ ЛИНИИ
COM1,
COM2,
DATA1,
DATA2
);

///////////////////////////////////////////////////////////////////
//
// Parameters
// 

//`define test_simulation

parameter QUARTZ = 24;

parameter MARKER_BYTE_CODER = 8'ha5;
parameter MARKER_BYTE_DECODER = 8'ha5;

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

//////////////////////////// ОБЩИЕ
// Входная частота. Контроллер полностью синхронизирован от этой частоты
input 			CLK; 
// Общий ресет контроллера. GND - активный. (то есть при GND  всё в ресете.)
input 			RESET;

// Сигнал передачи сообщения
output 			CODING;
// Сигнал ожидания приема сообщения и приема сообщения
output 			DECODING;

//////////////////////////// БИТЫ УПРАВЛЕНИЯ
// бит готовности данных (1 - данные готовы)
input 			BIT_SR; // выдавать 1
// бит занятости (1 - оконечное устройство занято)
input 			BIT_BUSY; // выдаввть 0

//////////////////////////// ПРИЕМ СООБЩЕНИЙ
// CLK_EN для декодера
input 			CLK_EN_RS_DECODER;

// статус принятого сообщения
output  [7:0]	RX_FLAG;
// кол-во байт данных в принятом сообщении
output  [15:0]	RX_BYTE_NUMBER;
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

// Сигнал приема сообщения
output			RX_END_MESSAGE;
// Сигнал приема правильного сообщения (0 - не правильное сообщение, 1 - правильное сообщение)
output			RX_MESSAGE_RIGHT;
// По какой линии принято сообщение (0 - по COM1, 1 - по COM2)
output			RX_END_MESSAGE_LINE;

//////////////////////////// ПЕРЕДАЧА СООБЩЕНИЙ
// CLK_EN для кодера
input 			CLK_EN_RS_CODER;

// запрос на чтение из памяти
output 			TX_RAM_REQ_RD;
// завершение действия по запросу на чтение из памяти
input 			TX_RAM_RDY_RD;
// выходная шина адреса
output [15:0]	TX_RAM_ADDR_OUT;
// входная шина данных
input  [7:0]	TX_RAM_DATA_IN;

// Сигнал - выдаем кадр данных
output 			FLAG_DATA_OUT;

//////////////////////////// ВХОДНЫЕ И ВЫХОДНЫЕ ЛИНИИ
// линия передачи 1
output			DATA1;
// линия передачи 2
output			DATA2;
// линия приема 1
input 			COM1;
// линия приема 2
input 			COM2;

///////////////////////////////////////////////////////////////////
//
// Local Wires and Registers
//

// Входные регистры 
reg			r_data1_1takt_en;
reg			r_data2_1takt_en;
reg			r_data1_4takt_en;
reg [3:0]	r_data1_4takt_dff;
reg			r_data2_4takt_en;
reg [3:0]	r_data2_4takt_dff;

//////////////////////////////////////////////////////////////////////////////////////////////////////////////////
////////////////////// ДЕКОДЕР ///////////////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////

wire			mod_hi_speed_protocol_decoder_DECODING;

//////////////////////////////////////////////////////////////////////////////////////////////////////////////////
////////////////////// КОДЕР /////////////////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////

wire			mod_hi_speed_protocol_coder_CODING;
wire			mod_hi_speed_protocol_coder_OUT;

// данные, записываемые в mod_hi_speed_protocol_coder
reg [15:0]		in_TX_BYTE_NUMBER;

////////////////////// КОНТРОЛЛЕР ДЕЙСТВИЙ ПРИЕМ //////////////////////////////////////////////////////
reg	[3:0]	fsm_rx_state;

parameter	FSM_RX_IDLE 				= 4'd0,
			FSM_RX_WAIT_FOR_DECODING 	= 4'd1,
			FSM_RX_RX 					= 4'd2;

reg	[4:0]	wait_rx_for_decoding_count;
reg			DECODING;


////////////////////// КОНТРОЛЛЕР ДЕЙСТВИЙ ПЕРЕДАЧА //////////////////////////////////////////////////////
reg	[3:0]	fsm_tx_state;

parameter	FSM_TX_IDLE 				= 4'd0,
			FSM_TX_WAIT_FOR_DECODING 	= 4'd1,
			FSM_TX_RX 					= 4'd2,
			FSM_TX_PAUSE 				= 4'd3,
			FSM_TX_TX 					= 4'd4,
			FSM_TX_TX1					= 4'd5,
            FSM_TX_END     				= 4'd6;

reg	[4:0]	wait_tx_for_decoding_count;
reg			reg_BIT_SR;
reg			reg_BIT_BUSY;
reg			flag_data_out;
reg			flag_error;
reg			reg_TX_STR;
reg			RX_END_MESSAGE_LINE;
reg			CODING;

///////////////////////////////////////////////////////////////////
//
// Begin

//////////////////////////////////////////////////////////////////////////////////////////////////////////////////
////////////////////// ДЕКОДЕР ///////////////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////

// Входные регистры 
always @ (posedge CLK or negedge RESET)
begin
	if (~RESET) 
		begin
			r_data1_1takt_en <= 1'b0;
			r_data2_1takt_en <= 1'b0;

			r_data1_4takt_en <= 1'b0;
			r_data1_4takt_dff[3:0] <= 4'b0;
			r_data2_4takt_en <= 1'b0;
			r_data2_4takt_dff[3:0] <= 4'b0;
     	end 
	else 
		begin 
			r_data1_1takt_en <= COM1;
			r_data2_1takt_en <= COM2;

			r_data1_4takt_en <= r_data1_4takt_dff[3];
			r_data1_4takt_dff[3:0] <= {r_data1_4takt_dff[2:0], COM1};
			r_data2_4takt_en <= r_data2_4takt_dff[3];
			r_data2_4takt_dff[3:0] <= {r_data2_4takt_dff[2:0], COM2};
		end		
end

mod_hi_speed_protocol_decoder #(.MARKER_BYTE(MARKER_BYTE_DECODER)) mod_hi_speed_protocol_decoder_inst(
.CLK						(CLK), 
.RESET						(RESET),

.CLK_EN_RS					(CLK_EN_RS_DECODER), 

.IN							(RX_END_MESSAGE_LINE ? r_data2_4takt_en : r_data1_4takt_en),

.RX_FLAG					(RX_FLAG[7:0]),
.RX_BYTE_NUMBER				(RX_BYTE_NUMBER[15:0]),
.RX_FLAG_BYTE_NUMBER_RD_EN	(RX_FLAG_BYTE_NUMBER_RD_EN),

.RX_RAM_REQ_WR				(RX_RAM_REQ_WR),
.RX_RAM_RDY_WR				(RX_RAM_RDY_WR),
.RX_RAM_ADDR_OUT			(RX_RAM_ADDR_OUT[15:0]),
.RX_RAM_DATA_OUT			(RX_RAM_DATA_OUT[7:0]),

.DECODING					(mod_hi_speed_protocol_decoder_DECODING),

.RX_END_MESSAGE				(RX_END_MESSAGE),
.RX_MESSAGE_RIGHT			(RX_MESSAGE_RIGHT)
);

//////////////////////////////////////////////////////////////////////////////////////////////////////////////////
////////////////////// КОДЕР /////////////////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////

mod_hi_speed_protocol_coder #(.MARKER_BYTE(MARKER_BYTE_CODER)) mod_hi_speed_protocol_coder_inst(
.CLK					(CLK), 
.RESET					(RESET),

.CLK_EN_RS				(CLK_EN_RS_CODER), 

.TX_STR					(reg_TX_STR),
.TX_FLAG				({3'b0, flag_data_out, 1'b0, BIT_BUSY, BIT_SR, flag_error}),
.TX_BYTE_NUMBER			(in_TX_BYTE_NUMBER[15:0]),

.TX_RAM_REQ_RD			(TX_RAM_REQ_RD),
.TX_RAM_RDY_RD			(TX_RAM_RDY_RD),
.TX_RAM_ADDR_OUT		(TX_RAM_ADDR_OUT[15:0]),
.TX_RAM_DATA_IN			(TX_RAM_DATA_IN[7:0]),

.CODING					(mod_hi_speed_protocol_coder_CODING),
.OUT					(mod_hi_speed_protocol_coder_OUT)
);

// данные, записываемые в mod_hi_speed_protocol_coder
always @(*)
begin 
	case (flag_data_out)
		1'b0 : begin // передача статуса
					in_TX_BYTE_NUMBER[15:0] = 16'h00;
				end
		default : 	begin // передача пакета данных
						in_TX_BYTE_NUMBER[15:0] = 16'd2032; //16'd496;
					end
	endcase
end

////////////////////// КОНТРОЛЛЕР ДЕЙСТВИЙ ПРИЕМ //////////////////////////////////////////////////////
always @ (posedge CLK or negedge RESET)
begin
	if (~RESET) 
		begin
			wait_rx_for_decoding_count[4:0] <= 5'b0;
			
			RX_END_MESSAGE_LINE <= 1'b0;
			
			DECODING <= 1'b0;
			
			fsm_rx_state  <= FSM_RX_IDLE;
     	end 
	else begin
       case(fsm_rx_state)
	 FSM_RX_IDLE : 
		begin	
			wait_rx_for_decoding_count[4:0] <= 5'b0;
			
			if (~DECODING)
				begin
					if (CLK_EN_RS_DECODER)
						begin
							if (r_data1_1takt_en == 1'b0)
								begin
									RX_END_MESSAGE_LINE <= 1'b0;
									DECODING <= 1'b1;
									fsm_rx_state  <= FSM_RX_WAIT_FOR_DECODING;
								end
							else if (r_data2_1takt_en == 1'b0)
								begin
									RX_END_MESSAGE_LINE <= 1'b1;
									DECODING <= 1'b1;
									fsm_rx_state  <= FSM_RX_WAIT_FOR_DECODING;
								end
						end
				end
			else
				begin
					DECODING <= 1'b0;
				end
	 	end
	 FSM_RX_WAIT_FOR_DECODING :
		begin
			if (CLK_EN_RS_DECODER)
				begin
					wait_rx_for_decoding_count[4:0] <= wait_rx_for_decoding_count[4:0] + 1'b1;
					
					if (mod_hi_speed_protocol_decoder_DECODING)
						begin
							fsm_rx_state  <= FSM_RX_RX;
						end
					else if (wait_rx_for_decoding_count[4:0] == 5'd31)
						begin
							fsm_rx_state  <= FSM_RX_IDLE;
						end
				end
	 	end
	 FSM_RX_RX :
		begin
			if (RX_END_MESSAGE)
				begin
					fsm_rx_state  <= FSM_RX_IDLE;						
				end
	 	end
	default : 				fsm_rx_state  <= FSM_RX_IDLE;
       endcase
	end
end

////////////////////// КОНТРОЛЛЕР ДЕЙСТВИЙ ПЕРЕДАЧА //////////////////////////////////////////////////////
always @ (posedge CLK or negedge RESET)
begin
	if (~RESET) 
		begin
			wait_tx_for_decoding_count[4:0] <= 5'b0;
			reg_BIT_SR <= 1'b0;
			reg_BIT_BUSY <= 1'b0;
			flag_data_out <= 1'b0;
			flag_error <= 1'b0;
			reg_TX_STR <= 1'b0;
			
			CODING <= 1'b0;
			
			fsm_tx_state  <= FSM_TX_IDLE;
     	end 
	else begin
       case(fsm_tx_state)
	 FSM_TX_IDLE : 
		begin	
			wait_tx_for_decoding_count[4:0] <= 5'b0;
			reg_BIT_SR <= 1'b0;
			reg_BIT_BUSY <= 1'b0;
			flag_data_out <= 1'b0;
			flag_error <= 1'b0;
			reg_TX_STR <= 1'b0;
			
			if (~CODING)
				begin
					if (CLK_EN_RS_DECODER)
						begin
							if (r_data1_1takt_en == 1'b0)
								begin
									//CODING <= 1'b1;
									fsm_tx_state  <= FSM_TX_WAIT_FOR_DECODING;
								end
							else if (r_data2_1takt_en == 1'b0)
								begin
									//CODING <= 1'b1;
									fsm_tx_state  <= FSM_TX_WAIT_FOR_DECODING;
								end
						end
				end
			else
				begin
					CODING <= 1'b0;
				end
	 	end
	 FSM_TX_WAIT_FOR_DECODING :
		begin
			if (CLK_EN_RS_DECODER)
				begin
					wait_tx_for_decoding_count[4:0] <= wait_tx_for_decoding_count[4:0] + 1'b1;
					
					if (mod_hi_speed_protocol_decoder_DECODING)
						begin
							reg_BIT_SR <= BIT_SR;
							reg_BIT_BUSY <= BIT_BUSY;

							fsm_tx_state  <= FSM_TX_RX;
						end
					else if (wait_tx_for_decoding_count[4:0] == 5'd31)
						begin
							fsm_tx_state  <= FSM_TX_IDLE;
						end
				end
	 	end
	 FSM_TX_RX : // CODING <= 1'b1;
		begin
			if (RX_END_MESSAGE)
				begin
					flag_error <= ~RX_MESSAGE_RIGHT;
					
					case (RX_FLAG[7:0])
						8'h02 : // УКС
								begin
									CODING <= 1'b1;
									fsm_tx_state  <= FSM_TX_PAUSE;
								end
						8'h03 : // Запрос статуса
								begin
									CODING <= 1'b1;
									fsm_tx_state  <= FSM_TX_PAUSE;
								end
						8'h04 : // Запрос пакета данных
								begin
									CODING <= 1'b1;
									flag_data_out <= RX_MESSAGE_RIGHT & reg_BIT_SR & ~reg_BIT_BUSY;  // отвечаем пакетом данных (нет ошибки + данные готовы + не занят)
									fsm_tx_state  <= FSM_TX_PAUSE;
								end
						default : // Другое, отвечать не надо
								begin
									fsm_tx_state  <= FSM_TX_IDLE;
								end
					endcase
				end
	 	end
	 FSM_TX_PAUSE :
		begin
			fsm_tx_state  <= FSM_TX_TX;
	 	end	 
	 FSM_TX_TX :
		begin
			reg_TX_STR <= 1'b1;
			fsm_tx_state  <= FSM_TX_TX1;
	 	end	
	 FSM_TX_TX1 :
		begin
			reg_TX_STR <= 1'b0;
			if (mod_hi_speed_protocol_coder_CODING) fsm_tx_state <= FSM_TX_END;
	 	end	
	 FSM_TX_END :
		begin
			if (~mod_hi_speed_protocol_coder_CODING) fsm_tx_state <= FSM_TX_IDLE;
	 	end
	default : 				fsm_tx_state  <= FSM_TX_IDLE;
       endcase
	end
end

// выходные линии
assign DATA1 = mod_hi_speed_protocol_coder_OUT;
assign DATA2 = mod_hi_speed_protocol_coder_OUT;

// Сигнал - выдаем кадр данных
assign FLAG_DATA_OUT = flag_data_out;

endmodule