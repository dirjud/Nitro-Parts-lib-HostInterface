  wire [1:0] buttons;
  wire [7:0] led0;
  wire [15:0] counter;
  wire XEM3010EndPoint_write = diWrite && (diEpAddr == 0);
  wire [15:0] XEM3010EndPoint_out;
  XEM3010EndPoint XEM3010EndPoint(
     .clk(clk),
     .resetb(resetb),
     .we(XEM3010EndPoint_write),
     .addr(diRegAddr),
     .datai(diRegDataIn),
     .datao(XEM3010EndPoint_out),

     .buttons(buttons),
     .led0(led0),
     .counter(counter)
     );

