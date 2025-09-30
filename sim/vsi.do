vlib work
vmap work work

vlog "../tb/vsi_suspi.v"\
 "../src/top.v"\
 "../src/strobe_gen.v"\
 "../src/slave_device.v"\
 "../src/codegen.v"\
 "../src/crc16.v"\
 "../src/mod_hi_speed_protocol_coder.v"\
 "../src/mod_hi_speed_protocol_decoder.v"\
 "../src/mod_hi_speed_protocol_rx.v"\
 "../src/psevdo_ram_block.v"\
 "../src/xci2_buf.v"\
 "../src/rs_coder.v"\
 "../src/reset_sync.v"\
 "../src/rs_decoder_4.v"

vsim -debugDB -gui work.vsi_suspi

do {wave.do}

run 300us