`timescale 1ns/1ps

module vsi_suspi();

reg bb_clk_in;
reg rst_h;
reg start;

wire DATA1;
wire DATA2;
reg COM1;
reg COM2;

wire RX_RAM_REQ_WR;
reg RX_RAM_RDY_WR;
reg suspi_clk;

wire FLAG_DATA_OUT;

reg [7:0] test_data [0:2047];
reg [15:0] crc_table [0:255];
reg [15:0] current_crc;
integer i, j;

top dut (
    .bb_clk_in(bb_clk_in),
    .rst_h(rst_h),
    .DATA1(DATA1),
    .DATA2(DATA2),
    .COM1(COM1),
    .COM2(COM2),
    .RX_RAM_REQ_WR(RX_RAM_REQ_WR),
    .RX_RAM_RDY_WR(RX_RAM_RDY_WR)
);

wire clk_tx = dut.strobe_1mhz;
wire clk_rx = dut.strobe_4mhz;

// Генерация тактового сигнала 12 МГц
always #41.667 bb_clk_in = ~bb_clk_in;

always #500 suspi_clk = ~suspi_clk;

// Функция расчета бита четности (нечетный паритет)
function calculate_parity;
    input [7:0] data;
    begin
        calculate_parity = ~(^data); // Нечетный паритет
    end
endfunction

// Функция расчета CRC-16 (соответствует модулю crc16)
function [15:0] calculate_crc;
    input [7:0] data;
    input [15:0] crc;
    
    reg [15:0] temr;
    reg [15:0] xor_out;
    begin
        // Расчет промежуточных значений temr
        temr[0] = data[4] ^ data[0];
        temr[1] = data[5] ^ data[1];
        temr[2] = data[6] ^ data[2];
        temr[3] = data[7] ^ data[3];
        temr[4] = crc[12] ^ crc[8];
        temr[5] = crc[13] ^ crc[9];
        temr[6] = crc[14] ^ crc[10];
        temr[7] = crc[15] ^ crc[11];
        temr[8] = data[4] ^ crc[12];
        temr[9] = data[5] ^ crc[13];
        temr[10] = data[6] ^ crc[14];
        temr[11] = data[7] ^ crc[15];
        temr[12] = temr[0] ^ temr[4];
        temr[13] = temr[1] ^ temr[5];
        temr[14] = temr[2] ^ temr[6];
        temr[15] = temr[3] ^ temr[7];
        
        // Расчет выходного значения XOR
        xor_out[0] = temr[12];
        xor_out[1] = temr[13];
        xor_out[2] = temr[14];
        xor_out[3] = temr[15];
        xor_out[4] = temr[8];
        xor_out[5] = temr[9] ^ temr[12];
        xor_out[6] = temr[10] ^ temr[13];
        xor_out[7] = temr[11] ^ temr[14];
        xor_out[8] = temr[15] ^ crc[0];
        xor_out[9] = temr[8] ^ crc[1];
        xor_out[10] = temr[9] ^ crc[2];
        xor_out[11] = temr[10] ^ crc[3];
        xor_out[12] = temr[11] ^ temr[12] ^ crc[4];
        xor_out[13] = temr[13] ^ crc[5];
        xor_out[14] = temr[14] ^ crc[6];
        xor_out[15] = temr[15] ^ crc[7];
        
        calculate_crc = xor_out;
    end
endfunction

initial begin
    // Инициализация таблицы CRC-16
    for (i = 0; i < 256; i = i + 1) begin
        crc_table[i] = i;
        for (j = 0; j < 8; j = j + 1) begin
            crc_table[i] = crc_table[i][0] ? 
                (crc_table[i] >> 1) ^ 16'hA001 : 
                (crc_table[i] >> 1);
        end
    end
    
    // Заполнение тестовых данных
    for (i = 0; i < 2032; i = i + 1) begin
        test_data[i] = i;
    end
    
    // Инициализация сигналов
    suspi_clk = 0;
    bb_clk_in = 0;
    rst_h = 0;
    start = 0;
    COM1 = 1; // Стоповый бит по умолчанию
    COM2 = 1;
    RX_RAM_RDY_WR = 0;

    // Сброс
    #50 rst_h = 1;
    #50 rst_h = 0;
  
end

// Генератор строба для передачи (каждые 3 такта)
reg [2:0] tx_counter = 0;
wire tx_strobe = (tx_counter == 2);

always @(posedge bb_clk_in) begin
    tx_counter <= tx_counter + 1;
end

// Генератор строба для приема (каждые 12 тактов)
reg [3:0] rx_counter = 0;
wire rx_strobe = (rx_counter == 11);

always @(posedge bb_clk_in) begin
    rx_counter <= rx_counter + 1;
end

// Основной процесс тестирования
reg [7:0] tx_byte;
reg [3:0] tx_bit_counter;
reg [7:0] rx_byte;
reg [3:0] rx_bit_counter;
reg [15:0] data_length;
reg [15:0] expected_crc;
reg [15:0] calculated_crc;

reg [7:0] status_byte1;
reg [7:0] status_byte2; 
reg [7:0] status_byte3;
reg [7:0] status_byte4;
reg [7:0] status_crc_low;
reg [7:0] status_crc_high;

// Регистры для сохранения данных пакета
reg [7:0] packet_marker;
reg [7:0] packet_flag;
reg [7:0] packet_length_high;
reg [7:0] packet_length_low;
reg [7:0] packet_data [0:2047];
reg [7:0] packet_crc_low;
reg [7:0] packet_crc_high;
integer packet_data_index;

initial begin
    tx_byte = 0;
    tx_bit_counter = 0;
    rx_byte = 0;
    rx_bit_counter = 0;
    data_length = 0;
    expected_crc = 0;
    calculated_crc = 16'hFFFF;
    
    // Отправка команды "Запрос статуса"
    send_command(8'hA5, 8'h03, 16'h0000);
    
    // Ожидание ответа статуса
    receive_status();
    
    // Отправка команды "Запрос пакета"
    send_command(8'hA5, 8'h04, 16'h0000);
    
    // Прием пакета данных
    receive_data_packet();

    // Отправка команды "Запрос пакета"
    send_command(8'hA5, 8'h04, 16'h0000);

    // Прием пакета данных
    receive_data_packet();

end

// Задача отправки команды с 11-битной последовательной передачей
task send_command;
    input [7:0] marker;
    input [7:0] flag;
    input [15:0] length;
    
    reg [15:0] crc;
    begin
        crc = 16'hFFFF;
        
        // Отправка маркера
        send_11bit_byte(marker);
        crc = calculate_crc(marker, crc);
        
        // Отправка флага
        send_11bit_byte(flag);
        crc = calculate_crc(flag, crc);
        
        // Отправка длины (старший байт)
        send_11bit_byte(length[15:8]);
        crc = calculate_crc(length[15:8], crc);
        
        // Отправка длины (младший байт)
        send_11bit_byte(length[7:0]);
        crc = calculate_crc(length[7:0], crc);
        
        // Отправка CRC (младший байт)
        send_11bit_byte(crc[15:8]);
        
        // Отправка CRC (старший байт)
        send_11bit_byte(crc[7:0]);
    end
endtask

// Задача отправки байта в 11-битном формате
task send_11bit_byte;
    input [7:0] data_byte;
    reg parity_bit;
    integer i;
    begin
        parity_bit = calculate_parity(data_byte);
        
        // Стартовый бит (0)
        @(posedge suspi_clk);
        COM1 <= 1'b0;
        
        // 8 бит данных (младшим битом вперед)
        for (i = 0; i < 8; i = i + 1) begin
            @(posedge suspi_clk);
            COM1 <= data_byte[i];
        end
        
        // Бит четности
        @(posedge suspi_clk);
        COM1 <= parity_bit;
        
        // Стоповый бит (1)
        @(posedge suspi_clk);
        COM1 <= 1'b1;
        
    end
endtask

// Задача приема статуса
task receive_status;
    begin
        // Ожидание начала приема
        wait(dut.DECODING);
        
        // Прием 6 байт статуса в 11-битном формате
        receive_11bit_byte(); // B6
        status_byte1 = rx_byte;
        
        receive_11bit_byte(); // 02
        status_byte2 = rx_byte;
        
        receive_11bit_byte(); // 00
        status_byte3 = rx_byte;
        
        receive_11bit_byte(); // 00
        status_byte4 = rx_byte;
        
        receive_11bit_byte(); // CRC младший
        status_crc_low = rx_byte;
        
        receive_11bit_byte(); // CRC старший
        status_crc_high = rx_byte;
    end
endtask

// Задача приема байта в 11-битном формате
task receive_11bit_byte;
    reg parity_bit, received_parity;
    integer i;
    begin
        // Ожидание стартового бита
        wait(DATA1 == 1'b0);
        @(posedge clk_tx);
        
        // Прием 8 бит данных (младшим битом вперед)
        for (i = 0; i < 8; i = i + 1) begin
            @(posedge clk_tx);
            rx_byte[i] <= DATA1;
        end
        
        // Прием бита четности
        @(posedge clk_tx);
        received_parity <= DATA1;
        
        // Прием стопового бита
        @(posedge clk_tx);
        
        // Проверка четности (можно добавить при необходимости)
        parity_bit = calculate_parity(rx_byte);
        // if (parity_bit != received_parity) $display("Parity error");
    end
endtask

// Задача приема пакета данных
task receive_data_packet;
    integer i;
    begin
        // Ожидание начала приема
        wait(dut.DECODING);
        
        // Прием заголовка
        receive_11bit_byte(); // Маркер
        packet_marker = rx_byte;
        
        receive_11bit_byte(); // Флаг
        packet_flag = rx_byte;
        
        receive_11bit_byte(); // Длина старший
        packet_length_high = rx_byte;
        
        receive_11bit_byte(); // Длина младший
        packet_length_low = rx_byte;
        
        data_length = {packet_length_high, packet_length_low};
        
        // Прием данных
        packet_data_index = 0;
        for (i = 0; i < data_length; i = i + 1) begin
            receive_11bit_byte();
            packet_data[packet_data_index] = rx_byte;
            packet_data_index = packet_data_index + 1;
        end
        
        // Прием CRC
        receive_11bit_byte(); // CRC младший
        packet_crc_low = rx_byte;
        
        receive_11bit_byte(); // CRC старший
        packet_crc_high = rx_byte;
    end
endtask

endmodule