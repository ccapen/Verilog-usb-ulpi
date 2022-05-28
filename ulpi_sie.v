// Tokens
`define PID_OUT                    8'hE1
`define PID_IN                     8'h69
`define PID_SOF                    8'hA5
`define PID_SETUP                  8'h2D

// Data
`define PID_DATA0                  8'hC3
`define PID_DATA1                  8'h4B
`define PID_DATA2                  8'h87
`define PID_MDATA                  8'h0F

// Handshake
`define PID_ACK                    8'hD2
`define PID_NAK                    8'h5A
`define PID_STALL                  8'h1E
`define PID_NYET                   8'h96

// Special
`define PID_PRE                    8'h3C
`define PID_ERR                    8'h3C
`define PID_SPLIT                  8'h78
`define PID_PING                   8'hB4

module ulpi_sie(

input clk,
input dir,
input nxt,

inout[7:0]data,

output reg stp,

input en,
input[7:0] cmd,
input[7:0] regwd,
output reg[7:0] regrd,
output reg busy,
input rst,

output reg [  7:0]  datai_rx
,output   reg        push_rx
,input          full_rx
,input empty_rx
,output flusho_rx

,input[7:0] ep1rddata
,output reg[5:0] ep1rdaddr
,input ep1tx
,output reg ep1txd
	 
	 ,output reg setupdataactive

	 ,input[8:0] romaddr_i
	 ,input[7:0] romnum_i
	 ,input[6:0] devaddress_i
);
reg setupactive;
reg outactive;
reg[6:0] devaddress;

reg flush_rx;
assign flusho_rx=flush_rx;//(rst|flush_rx);

localparam STATE_W                       = 8;
localparam STATE_IDLE                 = 8'd0;
localparam STATE_ABORT						=8'd1;
localparam STATE_TX_PID                  = 3'd1;
localparam STATE_TX_DATA                 = 3'd2;
localparam STATE_TX_CRC1                 = 3'd3;
localparam STATE_TX_CRC2                 = 3'd4;
localparam STATE_TX_DONE                 = 3'd5;
localparam STATE_TX_CHIRP                = 3'd6;
localparam REGWT1=8'h41;
localparam REGWT2=8'h42;
localparam REGWT3=8'h43;
localparam REGWT4=8'h44;
localparam REGWT5=8'h45;
localparam REGRT1=8'h51;
localparam REGRT2=8'h52;
localparam REGRT3=8'h53;
localparam REGRT4=8'h54;
localparam REGRT5=8'h55;

localparam RXSTART=8'h60;
localparam DATA1=8'h62;
//localparam IN=8'h63;
//localparam OUT=8'h64;

localparam SETUP=8'h71;
localparam SETUP2=8'h72;
localparam SETUPCRC=8'h73;
localparam DATA0=8'h74;
localparam SETUPDATA16=8'h75;
localparam SETUPDATA16CRC=8'h76;
localparam SETUPDATA16CRCW=8'h77;
localparam TXACK=8'h78;
localparam TXACK2=8'h79;
localparam TXACK3=8'h7A;
localparam TXNAK=8'h7b;
localparam TXNAK2=8'h7c;

localparam IN=8'h80;
localparam IN2=8'h81;
localparam INCRC=8'h82;
localparam TXDES=8'h83;
localparam TXDES2=8'h84;
localparam TXDES3=8'h85;
localparam TXDES4=8'h86;
localparam TXDES5=8'h87;
localparam TXDES6=8'h88;
localparam TXACKPAK=8'h89;
localparam TXACKPAK2=8'h8a;
localparam TXSEGM=8'h8b;

localparam OUT=8'h8d;
localparam OUT2=8'h8e;
localparam OUTCRC=8'h8f;

localparam TXKEYBDPROT=8'h91;
localparam TXKEYBDPROT2=8'h92;
localparam TXKEYBDPROT3=8'h93;
localparam TXKEYBDPROT4=8'h94;
localparam TXKEYBDPROT5=8'h95;

localparam SENDDEVDES =4'h1;
localparam SENDACKPAK =4'h2;


wire[7:0] indata;
reg[7:0] outdata;

assign indata=data;
assign data=dir?8'bz:outdata;

reg[STATE_W-1:0] state;

reg[7:0] setupdatanum;
wire[4:0]crco;
reg[15:0] dst;
crc5 Crc5(.crc_i(5'b11111),.data_i(dst[10:0]),.crco(crco));
reg[15:0] crc16regr;
reg[15:0] crc16reg;
wire[15:0] crc16o;
wire[15:0] fcrc16o;
assign fcrc16o=~crc16o;
reg[7:0] crc16in;
crc16 Crc16(.crc_in_i(crc16reg),.din_i(crc16in),.crc_out_o(crc16o));
reg[8:0] romaddr;
wire[7:0] romq;
desrom512 rom(.address(romaddr),.clock(clk),.q(romq));
wire[7:0] romnum;
wire[8:0] romnum2;
assign romnum2=romaddr-romaddr_i;
assign romnum[7:0]=romnum2[7:0];

reg txsegment;
reg[7:0] paklen;

reg data_0;

always@(posedge clk)
begin
	if(rst)begin
		busy<=0;
		regrd<=8'b0;
		stp<=0;
		outdata<=8'b0;
		state<=0;
		crc16reg<=16'hffff;
		crc16in<=8'h00;
		outactive<=0;
		setupactive<=0;
		setupdataactive<=0;
		devaddress<=7'b0;
		txsegment<=0;
		paklen<=8'd64;
		ep1txd<=0;
		data_0<=0;
		end
	else	
	case(state)
	STATE_IDLE:begin
		if(en)
			case(cmd[7:6])
				2'b11:begin//read reg
					state<=REGRT1;
					busy<=1;
					end
				2'b10:begin//wirte reg
					state<=REGWT1;
					busy<=1;
					end
				default:state<=STATE_IDLE;
			endcase
		else if((!full_rx&&dir&&nxt)||(!full_rx&&dir&&!nxt&&indata[5:4]==2'b01))
				state<=RXSTART;
		else state<=STATE_IDLE;
		end
	REGWT1:
		if(dir==1)state<=state;
		else begin
		outdata<=cmd;
		state<=state+1'b1;
		end
	REGWT2:
		if(dir==1)state<=REGWT1;
		else if(nxt==1)
				begin
				outdata<=regwd;
				state<=state+1'b1;
				end
			else state<=state;
	REGWT3:
		if(dir==1) state<=REGWT1;
		else if(nxt==1)
			begin
			outdata<=8'b0;
			stp<=1;
			state<=state+1'b1;
			end
		else state<=state;
	REGWT4:begin
		stp<=0;
		busy<=0;
		state<=STATE_IDLE;
		end
		
	REGRT1:
		if(dir==1)state<=state;
		else begin
			outdata<=cmd;
			state<=state+1'b1;
			end
	REGRT2:
		if(dir==1)state<=REGRT1;
		else if(nxt)state<=state+1'b1;
				else state<=state;
	REGRT3:
		if(dir)state<=state+1'b1;
		else state<=state;
	REGRT4:begin
		regrd[7:0]<=indata[7:0];
		outdata<=0;
		busy<=0;
		state<=STATE_IDLE;
		end
	
	STATE_ABORT:if(dir==0)state<=STATE_IDLE;
					else state<=state;
	RXSTART:if(dir==0)state<=STATE_IDLE;
			else if(nxt)
					case(indata)
					8'h2d:state<=SETUP;
					8'h69:state<=IN;
					8'he1:state<=OUT;
					8'hc3:state<=DATA0;
					8'h4b:state<=DATA1;
					default:state<=STATE_ABORT;
					endcase
					else state<=state;
	SETUP:begin
			devaddress<=devaddress_i;
			if(dir==0)state<=STATE_IDLE;
			else if(nxt)begin
					dst[7:0]<=indata;
					state<=SETUP2;
					end
					else state<=state;
			end
	SETUP2:if(dir==0)state<=STATE_IDLE;
			else if(nxt)begin
					dst[15:8]<=indata;
					state<=SETUPCRC;
					end
					else state<=state;
	SETUPCRC:if(dst[6:0]==devaddress)//({dst[15:11],dst[6:0]}=={crco,addr})
					if(dst[10:7]==4'b0)
						begin
						setupactive<=1;
						state<=STATE_IDLE;
						end
					else state<=STATE_IDLE;
				else state<=STATE_IDLE;
				
	DATA0:if(setupactive)begin
					state<=SETUPDATA16;
					setupactive<=0;
					setupdatanum<=8'h00;
					end
			else state<=STATE_IDLE;
	SETUPDATA16:begin
			if(dir==0)begin
					state<=STATE_IDLE;
					push_rx<=0;
					end
			else if(nxt)
						if(setupdatanum<8'd8)begin
							datai_rx<=indata;
							push_rx<=1;
							setupdatanum<=setupdatanum+1'b1;
							crc16in<=indata;
							crc16reg<=(empty_rx?16'hffff:crc16o);
							end
						else begin
								push_rx<=0;
								setupdatanum<=setupdatanum+1'b1;
								if(setupdatanum==8'd8) crc16regr[7:0]<=indata;
								else if(setupdatanum==8'd9)begin
											crc16regr[15:8]<=indata;
											state<=SETUPDATA16CRC;
											end
										else state<=state;
								end
					else begin
						state<=state;
						push_rx<=0;
						end
			end
	SETUPDATA16CRC:if(1)//if(crc16regr==(~crco))
					begin
					state<=TXACK;
					setupdataactive<=1;
					end
				else begin
						state<=SETUPDATA16CRCW;
						flush_rx<=1;
						end
	SETUPDATA16CRCW:begin
							state<=STATE_IDLE;
							flush_rx<=0;
						end
	
	TXACK:begin
			setupdataactive<=0;
			if(dir||nxt)state<=state;
			else begin
			outdata<=8'h42;//ack
			state<=state+1'b1;
			end
		end
	TXACK2:
		if(dir==1)state<=TXACK;
		else if(nxt==1)
				begin
				outdata<=8'b0;
				stp<=1;
				state<=state+1'b1;
				end
			else state<=state;
	TXACK3:begin
		stp<=0;
		state<=STATE_IDLE;
		end
	TXNAK:begin
			if(dir||nxt)state<=state;
			else begin
			outdata<=8'h4a;//nak
			state<=state+1'b1;
			end
		end
	TXNAK2:
		if(dir==1)state<=TXNAK;
		else if(nxt==1)
				begin
				outdata<=8'b0;
				stp<=1;
				state<=TXACK3;
				end
			else state<=state;
	
	IN:if(dir==0)state<=STATE_IDLE;
			else if(nxt)begin
					dst[7:0]<=indata;
					state<=IN2;
					end
					else state<=state;
	IN2:if(dir==0)state<=STATE_IDLE;
			else if(nxt)begin
					dst[15:8]<=indata;
					state<=INCRC;
					end
					else state<=state;
	INCRC:if(dst[6:0]==devaddress)//({dst[15:11],dst[6:0]}=={crco,addr})
				case(dst[10:7])
					4'b0:if(txsegment) state<=TXSEGM;
							else state<=TXDES;
					4'b1:begin
							ep1txd<=(!ep1txd);
							if(ep1tx) state<=TXKEYBDPROT;
							else state<=TXNAK;
							end
				default:state<=TXNAK;
				endcase
			else state<=STATE_IDLE;
			
	TXSEGM:if(dir||nxt) state<=state;
		else begin
			outdata<=8'h43;//data0
			txsegment<=0;
			if(romnum_i==8'd64)
				state<=TXACKPAK;
			else begin
				state<=TXDES2;
				paklen<=romnum_i;
				end
			end			
	TXDES:if(dir||nxt) state<=state;
		else begin
			outdata<=8'h4b;//data1
			paklen<=8'd64;
			if(romnum_i>8'd63) txsegment<=1;
			if(romnum_i==8'b0)
				state<=TXACKPAK;
			else begin
				state<=state+1'b1;
				romaddr<=romaddr_i;
				end
			end
	TXDES2:
		if(dir==1)state<=TXDES;
		else if(nxt==1)
					if((romnum<romnum_i)&&(romnum<paklen))
						begin
						crc16reg<=((romnum[5:0]==6'b0)?16'hffff:crc16o);
						crc16in<=romq;
						outdata<=romq;
						romaddr<=romaddr+1'b1;
						end
					else begin
						//outdata<=8'h6c;
						outdata<=fcrc16o[7:0];
						state<=state+1'b1;
						end
			else state<=state;
	TXDES3:if(dir==1)state<=TXDES;
		else if(nxt==1)
				begin
				//outdata<=8'h88;
				outdata<=fcrc16o[15:8];
				state<=state+1'b1;
				end
			else state<=state;
	TXDES4:if(dir==1)state<=TXDES;
		else if(nxt==1)
				begin
				outdata<=8'b0;
				stp<=1;
				state<=state+1'b1;
				end
			else state<=state;
	TXDES5:if(dir==1)state<=TXDES;
		else begin
					stp<=0;
					state<=STATE_IDLE;
					end	
			
	TXACKPAK:if(dir==1)state<=TXDES;
		else if(nxt==1)
				begin
				outdata<=8'b0;
				state<=state+1'b1;
				end
			else state<=state;
	TXACKPAK2:if(dir==1)state<=TXDES;
		else if(nxt==1)
				begin
				state<=TXDES4;
				end
			else state<=state;
	
	OUT:if(dir==0)state<=STATE_IDLE;
			else if(nxt)begin
					dst[7:0]<=indata;
					state<=state+1'b1;
					end
					else state<=state;
	OUT2:if(dir==0)state<=STATE_IDLE;
			else if(nxt)begin
					dst[15:8]<=indata;
					state<=state+1'b1;
					end
					else state<=state;
	OUTCRC:if(dst[6:0]==devaddress)//({dst[15:11],dst[6:0]}=={crco,addr})
					begin
					outactive<=1;
					state<=STATE_IDLE;
					end
				else state<=STATE_IDLE;
	DATA1:if(outactive)begin
					state<=TXACK;
					outactive<=0;
					end
			else state<=STATE_IDLE;
	
	TXKEYBDPROT:if(dir||nxt) state<=state;
		else begin
			if(data_0) outdata<=8'h4b;//data1
			else outdata<=8'hc3;//data0
			data_0<=(!data_0);
			state<=state+1'b1;
			ep1rdaddr<=6'b0;
			end
	TXKEYBDPROT2:
		if(dir==1)state<=TXKEYBDPROT;
		else if(nxt==1)
					if(ep1rdaddr<6'd8)
						begin
						crc16reg<=(ep1rdaddr?crc16o:16'hffff);
						crc16in<=ep1rddata;
						outdata<=ep1rddata;
						ep1rdaddr<=ep1rdaddr+1'b1;
						end
					else begin
						outdata<=fcrc16o[7:0];
						state<=state+1'b1;
						end
			else state<=state;
	TXKEYBDPROT3:if(dir==1)state<=TXKEYBDPROT;
		else if(nxt==1)
				begin
				outdata<=fcrc16o[15:8];
				state<=state+1'b1;
				end
			else state<=state;
	TXKEYBDPROT4:if(dir==1)state<=TXKEYBDPROT;
		else if(nxt==1)
				begin
				outdata<=8'b0;
				stp<=1;
				state<=state+1'b1;
				end
			else state<=state;
	TXKEYBDPROT5:begin
		stp<=0;
		state<=STATE_IDLE;
		end	
	
	default:state<=STATE_IDLE;
	endcase
end


endmodule