onerror {resume}
quietly WaveActivateNextPane {} 0
add wave -noupdate /vsi_suspi/dut/bb_clk_in
add wave -noupdate /vsi_suspi/clk_tx
add wave -noupdate /vsi_suspi/clk_rx
add wave -noupdate /vsi_suspi/dut/rst_h
add wave -noupdate /vsi_suspi/dut/rst_l
add wave -noupdate /vsi_suspi/dut/DATA1
add wave -noupdate /vsi_suspi/dut/COM1
add wave -noupdate /vsi_suspi/dut/FLAG_DATA_OUT
add wave -noupdate /vsi_suspi/dut/rd_addr
add wave -noupdate /vsi_suspi/dut/ram_rd_rq
add wave -noupdate /vsi_suspi/dut/slave_device_inst/data_o
add wave -noupdate /vsi_suspi/dut/slave_device_inst/data_inf
add wave -noupdate /vsi_suspi/dut/slave_device_inst/data_h
add wave -noupdate /vsi_suspi/dut/slave_device_inst/ram0/RDB
add wave -noupdate /vsi_suspi/dut/slave_device_inst/ram0/WRB
add wave -noupdate /vsi_suspi/dut/slave_device_inst/data_inf
add wave -noupdate /vsi_suspi/dut/slave_device_inst/data_ram
add wave -noupdate /vsi_suspi/dut/slave_device_inst/data_h
add wave -noupdate /vsi_suspi/dut/slave_device_inst/ram0/DIn
add wave -noupdate /vsi_suspi/dut/slave_device_inst/ram0/DO1
add wave -noupdate /vsi_suspi/dut/hi_speed_protocol_rx_inst/mod_hi_speed_protocol_coder_inst/rs_coder_inst/WR_DATA
TreeUpdate [SetDefaultTree]
WaveRestoreCursors {{Cursor 2} {297245680 ps} 0} {{Cursor 2} {29801881387 ps} 0}
quietly wave cursor active 1
configure wave -namecolwidth 580
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
WaveRestoreZoom {296327641 ps} {300193283 ps}
