module usb(data,stp,nxt,dir,clk,rst,skrst,inclk0,key1,key2,line,row);
input skrst;

inout[7:0]data;
input nxt,dir,clk;
output stp,rst;

input key1,key2;

input inclk0;

input[3:0] line;
output[3:0] row;

wire c0;

wire sie_en,sie_busy;
wire[7:0] cmd;
wire[7:0] regwd;
wire[7:0] regrd;

wire[7:0] datai_rx,datai_tx;
wire ep0aclr,push_rx,full_rx,empty_rx,pop_rx,empty_tx;
wire[7:0] datao_tx,datao_rx;

wire setupdataactive;
wire[8:0] romaddr_i;
wire[7:0] romnum_i;
wire[6:0] devaddress_i;

wire[7:0] ep1wrdata,ep1rddata;
wire[5:0] ep1wraddr,ep1rdaddr;
wire ep1wr;
wire ep1tx,ep1txd;

ulpi_sie Sie(.clk(clk),.dir(dir),.nxt(nxt),.data(data),.stp(stp),.rst(rst),
				.en(sie_en),.cmd(cmd),.regrd(regrd),.regwd(regwd),.busy(sie_busy),
				.datai_rx(datai_rx),.push_rx(push_rx),.full_rx(full_rx),.flusho_rx(ep0aclr),.empty_rx(empty_rx),
				.ep1rddata(ep1rddata),.ep1rdaddr(ep1rdaddr),.ep1tx(ep1tx),.ep1txd(ep1txd),
				.setupdataactive(setupdataactive),.romaddr_i(romaddr_i),.romnum_i(romnum_i),
				.devaddress_i(devaddress_i));

usb_regrw physetconfig(.clk(clk),.rst(rst),.sie_en(sie_en),.sie_busy(sie_busy),
				.cmd(cmd),.regwd(regwd),.regrd(regrd),.skrst(skrst));
			
ep1_keyboard ep1(.clk(clk),.rst(rst),.key1(key1),.key2(key2),
				.ep1wr(ep1wr),.ep1wrdata(ep1wrdata),.ep1wraddr(ep1wraddr),.ep1tx(ep1tx),.ep1txd(ep1txd),
				.row(row),.line(line));
				
usb_stdrequest enumeration(.clk(clk),.rst(rst),.devaddress(devaddress_i),
				.empty_rx(empty_rx),.pop_rx(pop_rx),.datao_rx(datao_rx),
				.setupdataactive(setupdataactive),.romaddr(romaddr_i),.romnum(romnum_i));
				
fifo128 ep0_in(.aclr(ep0aclr),.clock(clk),.data(datai_rx),.rdreq(pop_rx),.wrreq(push_rx),.empty(empty_rx),
					.full(full_rx),.q(datao_rx));

ram64 ep1_out(.clock(clk),.wren(ep1wr),.data(ep1wrdata),.wraddress(ep1wraddr),.rdaddress(ep1rdaddr),.q(ep1rddata));

endmodule
