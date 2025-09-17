/*
MODULE: RS_DECODER. v1.4 22/03/2010.

Written by Nikiforov Andrey (C)2010,IKI,Moscow,Russia

ОПИСАНИЕ РАБОТЫ:
----------------
Входы и выходы:

IN (CLK, CLK_EN, RESET, "IN")
	WITH (PARITY = "ON/OFF", STOP_BIT = "1/2", WAIT_END = "0-11") ПОКА СДЕЛАЮ БЕЗ ПАРАМЕТРОВ!!!
OUT(DATA_OUT[7..0], DECODING, RD_EN, END_MESSAGE, ERROR)

Сигналы, идущие непосредственно к пинам ПЛИС (к RS), заключены в кавычки.

Декодер не имеет входные регистры данных.

Декодер принимает 11 бит:
1. Старт (GND).
2-9. Данные (выдаются младшим битом вперед)
10. Бит четности. (бит дополнения до нечетности информационного байта)
11. Стоп.

1. ДЕЙСТВИЕ СИГНАЛА RESET.

Обнуляется всё!

2. ОПИСАНИЕ РАБОТЫ ДЕКОДЕРА.
Декодер принимает послыки по RS-интерфейсу. Параметры PARITY_BIT и STOP_BIT задают есть ли во входной посылки "бит четности" и 
сколько "стоповых" битов 1 или 2. При приеме посылки сигнал ("DECODING" == 1'b1), при приеме каждого слова ("RD_EN" == 1'b1), 
при этом можгно считывать пришедшие данные с "DATA_OUT[7:0]". При окончании посылки выставляется сигнал "END_MESSAGE".
Если при приеме посылки происходит ошибка (неправильный код, ошибка четности, неправильный стоповый бит) выставляется сигнал "ERROR".

ИСТОРИЯ:
--------
v1.0 11/01/2006 - начало.
v1.1 10/03/2006 - добавил 				sync_en	 в
строчку 				if (END_MESSAGE | ERROR | sync_en) в конце файла., так как иногда и байт принимался и тайм-аут выскакивал, а
теперь он будет сбрасываться.	
v1.2 28/00/2006 - переписал все и добавил следующие параметры:
					PARITY_BIT - есть бит четности или 
					STOP_BIT - 1 или 2 "стоповых" бита после каждого байта
v1.3 20/09/2006 - Добавил  параметр:
					FIRST_BIT - какой бит выходит первым (MSB или LSB)
v1.4 22/03/2010 - добавил параметр 	WAIT_END.
v1.5 09/12/2010 - декодер, работающий от 4-хкратной частоты, а не от 8-кратной.
*/

module rs_decoder_4(
CLK, 
CLK_EN, 
RESET, 
IN,

DATA_OUT, 
DECODING, 
RD_EN, 
END_MESSAGE, 
ERROR);

parameter 	PARITY_BIT = "ON",	// "ON"					- Бит четности есть или нет
			STOP_BIT = 1,		// 1					- Стоп бит 1 или 2
			FIRST_BIT = "MSB",	// "MSB" или "LSB"		- старшим или младшим битом вперед
			WAIT_END = 1; // 1							- сколько тактов ждать окончания сообщения (от 1 до 19)

localparam BIT_NUMBER = (PARITY_BIT == "ON") ? ((STOP_BIT == 1) ? 10 : 11) : ((STOP_BIT == 1) ? 9 : 10);

localparam BIT_NUMBER_NEW_WORD = BIT_NUMBER + WAIT_END;

localparam TAKT_SAMPLE = 0; //2;
localparam TAKT_CHECK = 1; //4;

///////////////////////////////////////////////////////////////////
//
// Inputs, Outputs, InOuts
// 

// Входная частота. Декодер полностью синхронизирован от этой частоты.
// Входная частота (CLK + CLK_EN) должна ровно в 8 раз превышать частоту передачи по RS-интерфейсу. 
input 			CLK; 
// Сигнал "можно работать по фронту".
input 			CLK_EN;
// Общий ресет контроллера. GND - активный. (то есть при GND  всё в ресете.)
input 			RESET;
// входная линия RS-интерфейса.
input			IN; // (PIN)

// Выходные данные декодера.
output [7:0]	DATA_OUT;
// Сигнал декодирования декодера.
output			DECODING;
// строб чтения данных из декодера. Данные действительны синхронно CLK, при (RD_EN == VCC).
output			RD_EN;
// строб окончания приема сообщения. Данные действительны синхронно CLK, при (RD_EN == VCC).
output			END_MESSAGE;
// сигнал ошибки приема данных.
output			ERROR;

///////////////////////////////////////////////////////////////////
//
// Local Wires and Registers
// 

// Пересинхронизация входного сигнала
reg				IN_DFF;

// Получение спада входного сигнала ////////////
reg				spad_dff;
wire 			spad;

//////////////////////////////////////////////////////////////////////////////////////
//////////////////////////////// КОНТРОЛЛЕР //////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////////////

reg	[1:0]	fsm_state;

parameter	FSM_WAITING_NEW_MSG 	= 6'b00,
			FSM_START_BIT_CHECK		= 6'b01,
			FSM_RECEIVING_WORD 		= 6'b10,
			FSM_WAITING_NEW_WORD 	= 6'b11;

// КОНТРОЛЛЕР ДЕЙСТВИЙ
reg [7:0]	DATA_OUT;
reg			DECODING;
reg			RD_EN; 
reg			END_MESSAGE; 
reg			ERROR;

reg [1:0]	takt_count;
reg [4:0]	bit_count;
reg			dot;
			
// сигнал для установки бита ошибки и бита записи в сдвиговый регистр.
reg			shift_en;
reg			error_bit;

// четность
wire		parity;

///////////////////////////////////////////////////////////////////
//
// Begin

// Проверка параметров
initial /* synthesis enable_verilog_initial_construct */

begin
    if ((PARITY_BIT != "ON") && (PARITY_BIT != "OFF")) //Error: Parameter
    begin
        $display("Error: Параметр PARITY_BIT должен быть ON или OFF");
    end

    if ((STOP_BIT != 1) && (STOP_BIT != 2)) //Error: Parameter
    begin
        $display("Error: Параметр STOP_BIT должен быть 1 или 2");
    end

    if ((FIRST_BIT != "MSB") && (FIRST_BIT != "LSB")) //Error: Parameter
    begin
        $display("Error: Параметр FIRST_BIT должен быть MSB или LSB");
    end
    
	if ((WAIT_END < 1) || (WAIT_END > 19))
	begin
       	$display("Error: Параметр WAIT_END должен быть от 1 до 19");
    end
end

// Пересинхронизация входного сигнала
always @(posedge CLK)
begin 
	if (CLK_EN)	IN_DFF <= IN;
end		

// Получение спада входного сигнала ////////////
always @(posedge CLK)
begin 
	if (CLK_EN)	spad_dff <= IN_DFF;
end		

assign spad = ({spad_dff, IN_DFF} == 2'b10);

//////////////////////////////////////////////////////////////////////////////////////
//////////////////////////////// КОНТРОЛЛЕР //////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////////////

// КОНТРОЛЛЕР ДЕЙСТВИЙ
always @ (posedge CLK or negedge RESET)
begin
	if (~RESET) 
		begin
			fsm_state  <= FSM_WAITING_NEW_MSG;
			DECODING <= 1'b0;
			RD_EN <= 1'b0; 
			END_MESSAGE <= 1'b0; 
			ERROR <= 1'b0;
     	end 
	else if (CLK_EN) begin
       case(fsm_state)
	 FSM_WAITING_NEW_MSG : 
		begin
			takt_count <= 2'b00;
			bit_count <= 5'b00000;
			
			DECODING <= 1'b0;
			RD_EN <= 1'b0; 
			END_MESSAGE <= 1'b0; 
			ERROR <= 1'b0;
						
			if (spad)	fsm_state  <= FSM_START_BIT_CHECK;
	 	end
	 FSM_START_BIT_CHECK : 
		begin
			takt_count <= takt_count + 1'b1;

			if (takt_count == TAKT_SAMPLE) 	dot <= IN_DFF;
			
			if (takt_count == TAKT_CHECK)
				begin
					bit_count <= bit_count + 1'b1; //5
					
					if (error_bit)	
						begin
							if (DECODING)	END_MESSAGE <= 1'b1;
							fsm_state  <= FSM_WAITING_NEW_MSG;
						end
					else			fsm_state  <= FSM_RECEIVING_WORD;
				end			
	 	end
	 FSM_RECEIVING_WORD : 
		begin
			DECODING <= 1'b1;
			
			takt_count <= takt_count + 1'b1;
			if (takt_count == TAKT_CHECK)	bit_count <= bit_count + 1'b1; //5
			if (takt_count == TAKT_SAMPLE) 	dot <= IN_DFF;
			
			if ((takt_count == TAKT_CHECK) & shift_en)	
				begin
					DATA_OUT[7:0] <= (FIRST_BIT == "MSB") ? ({DATA_OUT[6:0], dot}) : ({dot, DATA_OUT[7:1]});
				end
			
			if (takt_count == TAKT_CHECK)
				begin
					if (error_bit)
						begin
							ERROR <= 1'b1;
							fsm_state  <= FSM_WAITING_NEW_MSG;
						end
					else if (bit_count == BIT_NUMBER)
						begin
							RD_EN <= 1'b1;
							fsm_state  <= FSM_WAITING_NEW_WORD;
						end
				end
	 	end
	 FSM_WAITING_NEW_WORD :
		begin 
			RD_EN <= 1'b0;
			
			if (takt_count == TAKT_SAMPLE) dot <= IN_DFF;
			
			if (spad)
				begin
					takt_count <= 2'b00;
					bit_count <= 5'b00000;
					
					//fsm_state  <= FSM_RECEIVING_WORD;
					fsm_state  <= FSM_START_BIT_CHECK;
				end
			else if ((bit_count == BIT_NUMBER_NEW_WORD) && (takt_count == TAKT_CHECK))
				begin
					takt_count <= takt_count + 1'b1;
					if (takt_count == TAKT_CHECK)	bit_count <= bit_count + 1'b1; //5
					
					END_MESSAGE <= 1'b1;
					fsm_state  <= FSM_WAITING_NEW_MSG;
				end
			else
				begin
					takt_count <= takt_count + 1'b1;
					if (takt_count == TAKT_CHECK)	bit_count <= bit_count + 1'b1; //5
				end
	 	end	
	default: 				fsm_state  <= FSM_WAITING_NEW_MSG;
       endcase
	end
end

// сигнал для установки бита ошибки и бита записи в сдвиговый регистр.
always @(*)
begin
case (bit_count)
	5'd0: 											// START_BIT
		begin
			shift_en = 1'b0;
			if (dot)		error_bit = 1'b1;
			else			error_bit = 1'b0;
		end
	5'd1, 5'd2, 5'd3, 5'd4, 5'd5, 5'd6, 5'd7, 5'd8: // DATA
		begin
			shift_en = 1'b1;
			error_bit = 1'b0;
		end
	5'd9: 											// PARITY_BIT or STOP_BIT
		begin
			shift_en = 1'b0;
			if (dot)		error_bit = (PARITY_BIT == "ON") ? ( parity) : 1'b0;
			else			error_bit = (PARITY_BIT == "ON") ? (~parity) : 1'b1;
		end
	5'd10, 5'd11: 									// STOP_BIT
		begin
			shift_en = 1'b0;
			if (dot)		error_bit = 1'b0;
			else			error_bit = 1'b1;
		end		
	default :										// OTHERS (NOT USED)
		begin
			shift_en = 1'b0;
		 	error_bit = 1'b1;	
		end
endcase
end

// четность
assign parity = ^DATA_OUT[7:0];



endmodule
