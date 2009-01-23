// This file is auto-generated. Do not edit.
module XEM3010EndPoint(
  input clk,
  input resetb,
  input we,
  input [15:0] addr,
  input [15:0] datai,

  input      [1:0] buttons,
  output reg [7:0] led0,
  input      [15:0] counter_fifo,
  input      [15:0] counter_get,

  output reg[15:0] datao
);

// Create writable static registers
always @(posedge clk or negedge resetb) begin
  if(!resetb) begin
     led0 <= 85;
  end else if(we) begin
    case(addr)
      1: led0[7:0] <= datai[7:0];
    endcase
  end
end

// Create readable registers
always @(addr or buttons or led0 or counter_fifo or counter_get) begin
  case(addr)
    0: datao = { 14'b0, buttons[1:0] };
    1: datao = { 8'b0, led0[7:0] };
    2: datao = counter_fifo[15:0];
    3: datao = counter_get[15:0];
    default: datao = 0;
  endcase
end

endmodule
