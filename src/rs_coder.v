/*
MODULE: RS_CODER. v1.2 20/09/2006.

Written by Nikiforov Andrey (C)2005,IKI,Moscow,Russia

ОПИСАНИЕ РАБОТЫ:
----------------
Входы и выходы:

IN (CLK, CLK_EN, RESET, WR_DATA[7..0], WR_EN)
	WITH (PARITY_BIT = "ON/OFF", STOP_BIT = "1/2", WAIT_END = "1-10")
OUT("OUT", CODING, FULL)

Сигналы, идущие непосредственно к пинам ПЛИС (к RS), заключены в кавычки.

Кодер имеет входные регистры данных.

Декодер выдает 11 бит:
1. Старт (GND).
2-9. Данные (выдаются младшим битом вперед)
10. Бит четности. (бит дополнения до нечетности информационного байта)
11. Стоп.

1. ДЕЙСТВИЕ СИГНАЛА RESET.
Сигнал RESET обнуляет следующие сигналы:

-- главный сигнал работы кодера (SRFFE)
CODING
-- счетчик кодера
count[3..0]
-- сигнал занятости кодера (SRFFE)
FULL

2. ЗАПИСЬ В ДАННЫХ В КОДЕР.
Для передачи данных в кодер надо выставить сигнал WR_EN и данные WR_DATA[7..0], контроллер 
защелкнет данные во входной регистр данных и выдаст сигнал занятости (FULL) и кодирования CODING, 
затем перепишет данные из входного регистра в выходной сдвиговый регистр и опустит сигнал занятости.
Если мастер в течении 10 ТАКТОВ после этого запишет еще данные, то они будут выданы сразу вслед за первыми
(в этом же сообщении).
Если мастер не будет дописывать данные, то по окончании 10 тактов кодер еще в течении 11 ТАКТОВ
будет держать сигнал CODING (обозначае тем самым конец сообщения), а затем опустит CODING.

ИСТОРИЯ:
--------
v1.0 10/01/2006 - начало.
v1.1 25/08/2006 - Добавил 3 параметра:
					PARITY_BIT - посылать бит четности или нет
					STOP_BIT - 1 или 2 "стоповых" бита после каждого байта
					WAIT_END - расстояние между посылками в тактах (от 1 до 10)
v1.2 20/09/2006 - Добавил  параметр:
					FIRST_BIT - какой бит выходит первым (MSB или LSB)
*/

module rs_coder(
CLK,
CLK_EN,
RESET,
WR_DATA, 
WR_EN,
OUT,
CODING,
FULL,
TIME_OUT
);

parameter 	PARITY_BIT = "ON",	// "ON"
			STOP_BIT = 1,		// 1
			WAIT_END = 1,		// 10
			FIRST_BIT = "MSB";	// "MSB" или "LSB"

localparam BIT_COUNT = (PARITY_BIT == "ON") ? ((STOP_BIT == 1) ? 10 : 11) : ((STOP_BIT == 1) ? 9 : 10);


///////////////////////////////////////////////////////////////////
//
// Inputs, Outputs, InOuts
// 

// Входная частота. Контроллер полностью синхронизирован от этой частоты 
// (частота CLK вместе с сигналом CLK_EN образовывают чатоту передачи данных по RS-интерфейсу)
input 			CLK; 
// Сигнал "можно работать по фронту".
input 			CLK_EN;
// Общий ресет контроллера. GND - активный. (то есть при GND  всё в ресете.)
input 			RESET;
// входные данные для передачи в RS.
input [7:0]		WR_DATA;
// строб записи данных в кодер. Данные действительны синхронно CLK, при (WR_EN == VCC). 
input 			WR_EN;

// Выходная линия кодера
output			OUT; // (PIN)
// Сигнал работы кодера. (VCC - кодер работает)
output			CODING;
// Сигнал занятости кодера (VCC - в кодер нельзя писать новые данные) 
output			FULL;
// Сигнал окончания пакета (VCC - в кодер нельзя писать новые данные) 
output			TIME_OUT;

///////////////////////////////////////////////////////////////////
//
// Local Wires and Registers
// 

// главный сигнал работы кодера
reg			CODING;
// счетчик кодера (до 40)
reg	[3:0]	count;
// сигнал занятости кодера 
reg			FULL;
// входной регистр данных
reg	[7:0]	reg_data_in;	
// сдвиговый регистр принятых данных
reg	[9:0]	shift_data;
// бит дополнения до нечетности информационного байта
wire		parity;
// сигнал окончания работы кодера
reg			TIME_OUT;	
// Выходные линии кодера
reg			OUT;

///////////////////////////////////////////////////////////////////
//
// Begin

// Проверка на правильную частоту кварца
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

    if ((PARITY_BIT == "OFF") && (STOP_BIT == 1)) //Error: Parameter
    	begin
			if ((WAIT_END < 1) || (WAIT_END > 9))
       			$display("Error: Параметр WAIT_END должен быть от 1 до 9");
    	end
	else
		begin
			if ((WAIT_END < 1) || (WAIT_END > 10))
       			$display("Error: Параметр WAIT_END должен быть от 1 до 10");
		end

    if ((FIRST_BIT != "MSB") && (FIRST_BIT != "LSB")) //Error: Parameter
    begin
        $display("Error: Параметр FIRST_BIT должен быть MSB или LSB");
    end

end

// главный сигнал работы кодера
always @(posedge CLK or negedge RESET)
begin 
	if (~RESET)  							// глобальный сброс
		CODING <= 1'b0;
	else 
		if (CLK_EN)
				if (FULL) 	
						CODING <= 1'b1;
				else
				if (TIME_OUT & (count[3:0] == WAIT_END)) 	
						CODING <= 1'b0;		
end		

// счетчик кодера
always @(posedge CLK)
begin 
		if (CLK_EN)
			if (CODING)	
				begin
					if (count[3:0] == BIT_COUNT)
							count[3:0] <= 4'b0;
					else
							count[3:0] <= count[3:0] + 1'b1;
				end
			else
				count[3:0] <= 4'b0;
end		

// сигнал занятости кодера 
always @(posedge CLK or negedge RESET)
begin 
	if (~RESET)  							// глобальный сброс
		FULL <= 1'b0;
	else 
		if (CLK_EN)
				if ((count[3:0] == 0) & CODING) 	
						FULL <= 1'b0;
				else if (WR_EN & ~TIME_OUT) 	
						FULL <= 1'b1;
end		

// входной регистр данных
always @(posedge CLK)
begin 
		if (CLK_EN & WR_EN & ~FULL)
				reg_data_in[7:0] <= WR_DATA[7:0];
end	

// сдвиговый регистр принятых данных
always @(posedge CLK or negedge RESET)
begin 
	if (~RESET)  							// глобальный сброс
		shift_data[9:0] <= 10'b1111111111;
	else 
		if (CLK_EN)
			if ((count[3:0] == 0) & FULL & CODING)	
						shift_data[9:0] <= (FIRST_BIT == "MSB") ? 
												({1'b0, 	reg_data_in[7:0], ((PARITY_BIT == "ON") ? (~parity) : 1'b1)})	// 1
												:
												({1'b0, 	reg_data_in[0], 												// 2
														reg_data_in[1], 
														reg_data_in[2], 
														reg_data_in[3], 
														reg_data_in[4], 
														reg_data_in[5], 
														reg_data_in[6], 
														reg_data_in[7], 
														((PARITY_BIT == "ON") ? (~parity) : 1'b1)});
			else
						shift_data[9:0] <= {shift_data[8:0], 1'b1};					
end		

// бит дополнения до нечетности информационного байта
assign	parity = ^reg_data_in[7:0];


// сигнал окончания работы кодера
always @(posedge CLK)
begin 	
	if (CLK_EN)	
		if (CODING)
			begin
				if ((count[3:0] == BIT_COUNT) & ~TIME_OUT)
					begin
						TIME_OUT <= ~(FULL | WR_EN);
					end
				else if ((count[3:0] == WAIT_END) & TIME_OUT)
					begin
						TIME_OUT <= 1'b0;
					end
			end
		else	TIME_OUT <= 1'b0;
end	


// Выходные линии кодера
always @(posedge CLK or negedge RESET)
begin 
		if (!RESET)
			begin
				OUT <= 1'b1;
			end
		else
			begin
				if (CLK_EN)
					if (CODING)	
						OUT <= shift_data[9];

					else
						OUT <= 1'b1;	
			end	
end		

endmodule
