onerror {resume}
quietly WaveActivateNextPane {} 0
add wave -noupdate /vsi_suspi/dut/bb_clk_in
add wave -noupdate /vsi_suspi/dut/strobe_1mhz
add wave -noupdate /vsi_suspi/dut/strobe_4mhz
add wave -noupdate /vsi_suspi/dut/rst_h
add wave -noupdate /vsi_suspi/dut/strobegen_1mhz/rst_l
add wave -noupdate /vsi_suspi/dut/DATA1
add wave -noupdate /vsi_suspi/dut/DATA2
add wave -noupdate /vsi_suspi/dut/COM1
add wave -noupdate /vsi_suspi/dut/COM2
add wave -noupdate /vsi_suspi/dut/FLAG_DATA_OUT
add wave -noupdate /vsi_suspi/dut/rd_addr
add wave -noupdate /vsi_suspi/dut/ram_rd_rq
add wave -noupdate /vsi_suspi/dut/hi_speed_protocol_rx_inst/mod_hi_speed_protocol_coder_inst/TX_RAM_RDY_RD
add wave -noupdate /vsi_suspi/dut/hi_speed_protocol_rx_inst/mod_hi_speed_protocol_coder_inst/TX_RAM_ADDR_OUT
add wave -noupdate /vsi_suspi/dut/hi_speed_protocol_rx_inst/mod_hi_speed_protocol_coder_inst/TX_RAM_DATA_IN
add wave -noupdate /vsi_suspi/dut/slave_device_inst/data_o
add wave -noupdate /vsi_suspi/dut/slave_device_inst/data_inf
add wave -noupdate /vsi_suspi/dut/slave_device_inst/data_h
add wave -noupdate /vsi_suspi/dut/slave_device_inst/ram0/DIn
add wave -noupdate /vsi_suspi/dut/slave_device_inst/ram0/DO1
add wave -noupdate /vsi_suspi/dut/slave_device_inst/codegen_inst/ready
add wave -noupdate /vsi_suspi/dut/slave_device_inst/codegen_inst/increment
add wave -noupdate /vsi_suspi/dut/slave_device_inst/ram0/RADDR
add wave -noupdate /vsi_suspi/dut/slave_device_inst/ram0/WADDR
add wave -noupdate /vsi_suspi/dut/slave_device_inst/ram0/RDB
add wave -noupdate /vsi_suspi/dut/slave_device_inst/ram0/WRB
add wave -noupdate /vsi_suspi/dut/slave_device_inst/raddr
add wave -noupdate /vsi_suspi/dut/slave_device_inst/is_special_address
TreeUpdate [SetDefaultTree]
WaveRestoreCursors {{Cursor 2} {106578081 ps} 0} {{Cursor 2} {29801881387 ps} 0}
quietly wave cursor active 2
configure wave -namecolwidth 531
configure wave -valuecolwidth 100
configure wave -justifyvalue left
configure wave -signalnamewidth 0
configure wave -snapdistance 10
configure wave -datasetprefix 0
configure wave -rowmargin 4
configure wave -childrowmargin 2
configure wave -gridoffset 0
configure wave -gridperiod 1
configure wave -griddelta 40
configure wave -timeline 0
configure wave -timelineunits ns
update
WaveRestoreZoom {29696338747 ps} {30015982172 ps}
