module usb_stdrequest(
	input clk
	,input rst
	
	,output reg pop_rx
	,input empty_rx
	,input [7:0] datao_rx
	
	,input setupdataactive
	,output reg[8:0] romaddr
	,output reg[7:0] romnum
	,output reg[6:0] devaddress
);

localparam 	REQ_IDLE=6'h00;
localparam  REQ_BMREQ=6'h01;
localparam 	REQSRC=6'h02;

localparam 	REQGETDES=6'h10;
localparam 	REQGETDES2=6'h11;
localparam 	REQGETDEVDES=6'h12;
localparam  REQGETCONDES=6'h13;
localparam  REQGETSTRDES=6'h14;
localparam  REQGETSTRDESFULL=6'h15;
localparam  REQGETSTRDESFULL2=6'h16;
localparam  REQGETSTRDESFULL3=6'h17;
localparam  REQGETINTFDES=6'h18;

localparam 	REQSETADDR=6'h20;

localparam 	REQ_ABORT=6'h3f;
localparam  REQO=6'h3e;
	
reg[5:0] reqstate;
reg[7:0] bmreq;
reg[7:0] desindex;
reg[7:0] wLengthL;
always@(posedge clk)
if(rst)begin
		romaddr<=9'b0;
		romnum<=8'b0;
		devaddress<=7'b0;
		reqstate<=REQ_IDLE;
		pop_rx<=0;
		end
else case(reqstate)
			REQ_IDLE:if(setupdataactive)begin
						romnum<=8'b0;
						reqstate<=REQ_BMREQ;
						pop_rx<=1;
						end
						else reqstate<=reqstate;
			//REQO:reqstate<=REQ_BMREQ;
			REQ_BMREQ:begin
						bmreq<=datao_rx;
						reqstate<=REQSRC;
						end
			REQSRC:case(datao_rx)
						8'h05:reqstate<=REQSETADDR;
						8'h06:reqstate<=REQGETDES;
						default:reqstate<=REQ_ABORT;
					endcase
			REQGETDES:begin
						desindex<=datao_rx;
						reqstate<=REQGETDES2;
						end
			REQGETDES2:case(datao_rx)
						8'h01:reqstate<=REQGETDEVDES;
						8'h02:reqstate<=REQGETCONDES;
						8'h03:reqstate<=REQGETSTRDES;
						8'h22:reqstate<=REQGETINTFDES;
						default:reqstate<=REQ_ABORT;
					endcase
			REQGETDEVDES:begin
							romaddr<=9'b0;
							romnum<=8'd18;
							reqstate<=REQ_ABORT;
							end
			REQGETCONDES:if(datao_rx==8'b0)reqstate<=reqstate;
							else if(datao_rx>8'd59)begin
										romaddr<=9'd24;
										romnum<=8'd59;
										reqstate<=REQ_ABORT;
										end
									else begin
										romaddr<=9'd24;
										romnum<=datao_rx;
										reqstate<=REQ_ABORT;
									end
			REQGETSTRDES:if(desindex==8'b0)begin//STRDESAREA
									romaddr<=9'd88;
									romnum<=8'd4;
									reqstate<=REQ_ABORT;
									end
							else reqstate<=REQGETSTRDESFULL;
			REQGETSTRDESFULL:reqstate<=REQGETSTRDESFULL2;
			REQGETSTRDESFULL2:begin
										wLengthL<=datao_rx;
										reqstate<=REQGETSTRDESFULL3;
										end
			REQGETSTRDESFULL3:if((datao_rx)||(wLengthL>8'd52))begin
										romaddr<=9'd96;
										romnum<=8'd52;
										reqstate<=REQ_ABORT;
										end
									else begin
										romaddr<=9'd96;
										romnum<=wLengthL;
										reqstate<=REQ_ABORT;
										end
			REQGETINTFDES:if(datao_rx==8'b0)begin
									romaddr<=9'd160;
									romnum<=8'd65;
									reqstate<=REQ_ABORT;
									end
								else begin
									romaddr<=9'd232;
									romnum<=8'd109;
									reqstate<=REQ_ABORT;
									end
			
			REQSETADDR:begin
							devaddress<=datao_rx[6:0];
							reqstate<=REQ_ABORT;
							end
							
			REQ_ABORT:if(empty_rx)
							begin
							pop_rx<=0;
							reqstate<=REQ_IDLE;
							end
						else reqstate<=reqstate;
			
			endcase

	
endmodule
