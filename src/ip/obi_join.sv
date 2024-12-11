module obi_join #()(
  OBI_BUS.Subordinate Src,
  OBI_BUS.Manager     Dst
);

assign Dst.req    = Src.req;
assign Src.gnt    = Dst.gnt;
assign Src.rvalid = Dst.rvalid;
assign Dst.addr   = Src.addr;
assign Dst.wdata  = Src.wdata;
assign Src.rdata  = Dst.rdata;
assign Dst.we     = Src.we;
assign Dst.be     = Src.be;

assign Src.gntpar    = '0;
assign Src.rvalidpar = '0;

endmodule : obi_join
