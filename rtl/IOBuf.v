

module IOBuf(
    inout wire data,
    output wire in,
    input wire out,
    input wire oe // output enable
);

 assign data = (oe) ? out : 1'bz;
 assign in = data;

endmodule