

module IOBuf(
    inout wire data,
    output wire in,
    input wire out,
    input wire we // output enable
);

 assign data = (we) ? out : 1'bz;
 assign in = data;

endmodule