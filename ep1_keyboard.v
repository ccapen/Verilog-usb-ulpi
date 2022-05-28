module ep1_keyboard(
	input clk
	,input rst
	,input key1
	,input key2
	
	,output reg[7:0] ep1wrdata
	,output reg[5:0] ep1wraddr
	,output reg ep1wr
	,input ep1txd
	,output reg ep1tx
	
	,output reg[3:0] row
	,input[3:0] line
);


reg[7:0] kbdata[7:0];
reg[7:0] kbdatao[7:0];
wire[7:0] diffkbdata;
genvar i;
generate
for(i=0;i<8;i=i+1)
begin:diffkb
	assign diffkbdata[i]=(kbdatao[i]!=kbdata[i]);
	end
endgenerate

wire[7:0] zerokbdata;
generate
for(i=0;i<8;i=i+1)
begin:zerokb
	assign zerokbdata[i] = (kbdata[i]==8'b0);
	end
endgenerate
reg[3:0] keyplus;
reg macromode,macrosend;
reg[7:0] macroaddr;
reg[7:0] macroaddrend;
wire[7:0] macrodata;
macrokey256 macrokey(.clock(clk),.address(macroaddr),.q(macrodata));

always@(posedge ep1tx or posedge rst)
if(rst)begin
	keyplus<=4'b0;
	macromode<=0;
	end
else begin
	if((keyplus>4'd9)&&(kbdatao[2]==8'b0))begin
			macromode<=!macromode;
			keyplus<=4'b0;
			end
	else if((kbdatao[2]==8'd87)||(kbdatao[2]==8'b0))//'+' or null  (8'd87 or 8'b0)
				keyplus<=keyplus+1'b1;//({zerokbdata[7:3],zerokbdata[0]}==6'b111111)&&
			else keyplus<=4'b0;
	end

reg ep1txd_old;
reg[3:0] state_ep1;

localparam EP1_IDLE=4'd0;
localparam EP1_MEMSET=4'd1;
localparam EP1_MACROMODE=4'd2;
localparam EP1_MACROSEND0=4'd3;
localparam EP1_MACROSEND=4'd4;

always@(posedge clk)
if(rst)begin
	ep1wr<=1;
	ep1txd_old<=ep1txd;
	ep1tx<=0;
	state_ep1<=EP1_IDLE;
	macrosend<=0;
	macroaddr<=8'b0;
	macroaddrend<=8'b0;
	end
else case(state_ep1)
		EP1_IDLE:if(ep1txd!=ep1txd_old)begin
						ep1txd_old<=ep1txd;
						if(macrosend) state_ep1<=EP1_MACROSEND;
						else if(diffkbdata)begin
								kbdatao[0]<=kbdata[0];
								kbdatao[1]<=kbdata[1];
								kbdatao[2]<=kbdata[2];
								kbdatao[3]<=kbdata[3];
								kbdatao[4]<=kbdata[4];
								kbdatao[5]<=kbdata[5];
								kbdatao[6]<=kbdata[6];
								kbdatao[7]<=kbdata[7];
								ep1tx<=1;
								ep1wraddr<=6'b0;
								ep1wrdata<=kbdata[0];
								if(macromode) state_ep1<=EP1_MACROMODE;
								else state_ep1<=EP1_MEMSET;
								end
							else ep1tx<=0;
						end
					else state_ep1<=state_ep1;
		EP1_MEMSET:if(ep1wraddr<6'd8)begin
							ep1wrdata<=kbdatao[ep1wraddr];
							ep1wraddr<=ep1wraddr+1'b1;
							state_ep1<=state_ep1;
							end
						else state_ep1<=EP1_IDLE;
		EP1_MACROMODE:case(kbdatao[2])
						8'd30:begin
									macroaddr<=8'd0;
									macroaddrend<=8'd40;
									macrosend<=1;
									state_ep1<=EP1_MACROSEND0;
									end
						8'd31:begin
									macroaddr<=8'd32;
									macroaddrend<=8'd104;
									macrosend<=1;
									state_ep1<=EP1_MACROSEND0;
									end
						default:state_ep1<=EP1_IDLE;
						endcase
		EP1_MACROSEND0:begin
								ep1wraddr<=6'b0;
								ep1wrdata<=macrodata;
								state_ep1<=EP1_MACROSEND;
								end
		EP1_MACROSEND:if(macroaddr<macroaddrend)
								if(ep1wraddr<6'd8)begin
									ep1wrdata<=macrodata;
									ep1wraddr<=ep1wraddr+1'b1;
									macroaddr<=macroaddr+1'b1;
									state_ep1<=state_ep1;
									end
								else begin
										ep1wraddr<=6'b0;
										state_ep1<=EP1_IDLE;
										end
							else begin
									macrosend<=0;
									state_ep1<=EP1_IDLE;
									end
		default:state_ep1<=EP1_IDLE;
endcase

reg[15:0] counter;
reg keyarrclk;
always@(posedge clk)
if(rst) begin
		counter<=16'b0;
		keyarrclk<=1;
		end
else begin
	counter<=counter+1'b1;
	if(counter==16'b0) keyarrclk<=!keyarrclk;
	end
		
reg[15:0] keyarr;
always@(posedge keyarrclk)
if(rst)begin
	row<=4'b1;
	keyarr<=16'b0;
end
else case(row)
		4'b0001:begin
				keyarr[3:0]<=line;
				row<=4'b0010;
				end
		4'b0010:begin
				keyarr[7:4]<=line;
				row<=4'b0100;
				end
		4'b0100:begin
				keyarr[11:8]<=line;
				row<=4'b1000;
				end
		4'b1000:begin
				keyarr[15:12]<=line;
				row<=4'b0001;
				end
		default:row<=4'b1;
endcase


reg[15:0] keyarro;
reg key1o,key2o;
reg[3:0] kbpointer;
reg[4:0] karrpointer;
wire[7:0] keyarrvalue;

keyarray keyarray(.clock(clk),.address(karrpointer),.q(keyarrvalue));

reg[3:0] keydata_state;
localparam KEYDATA_IDLE=4'b0;	
localparam KEYDATA1=4'd1;	
localparam KEYARRAY=4'd2;	

always@(posedge clk)
if(rst)begin
	keyarro[15:0]<=16'b0;
	key1o<=0;
	key2o<=1;//pushdown:(key2==0)
	keydata_state<=KEYDATA_IDLE;
	kbdata[0]<=8'b0;
	kbdata[1]<=8'b0;
	kbdata[2]<=8'b0;
	kbdata[3]<=8'b0;
	kbdata[4]<=8'b0;
	kbdata[5]<=8'b0;
	kbdata[6]<=8'b0;
	kbdata[7]<=8'b0;
	end
else case(keydata_state)
		KEYDATA_IDLE:if((key1o!=key1)||(key2o!=key2)||(keyarro!=keyarr))begin
								keyarro<=keyarr;
								key1o<=key1;
								key2o<=key2;
								kbdata[1]<=8'b0;
								keydata_state<=KEYDATA1;
								end
						else keydata_state<=keydata_state;
		KEYDATA1:begin
						if(key1) kbdata[0]<=8'h02;//Left Shift
						else kbdata[0]<=8'b0;
						if(!key2)begin
							kbdata[2]<=8'h04;//A
							kbpointer<=4'd3;
							end
						else kbpointer<=4'd2;
						karrpointer<=5'b0;
						keydata_state<=KEYARRAY;
						end
		KEYARRAY:if(kbpointer<4'd8)
						if(karrpointer<5'd16)begin
							karrpointer<=karrpointer+1'b1;
							if(keyarro[karrpointer])begin
									kbdata[kbpointer]<=keyarrvalue;
									kbpointer<=kbpointer+1'b1;
									end
							else keydata_state<=keydata_state;
							end
						else begin
								kbdata[kbpointer]<=8'b0;
								kbpointer<=kbpointer+1'b1;
								end
					else keydata_state<=KEYDATA_IDLE;
					
		endcase
endmodule
