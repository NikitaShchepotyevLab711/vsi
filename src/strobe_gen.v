module strobe_generator #(
    parameter STROBE_PERIOD = 3  
) (
    input wire clk,
    input wire rst_l,
    output reg strobe
);

localparam COUNTER_WIDTH = $clog2(STROBE_PERIOD);
reg [COUNTER_WIDTH-1:0] counter;

always @(posedge clk or negedge rst_l) begin
    if (!rst_l) begin
        counter <= 0;
        strobe <= 1'b0;
    end else begin
        if (counter >= STROBE_PERIOD - 1) begin
            counter <= 0;
            strobe <= 1'b1;
        end else begin
            counter <= counter + 1;
            strobe <= 1'b0;
        end
    end
end

endmodule