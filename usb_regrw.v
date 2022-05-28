module usb_regrw(

input clk,
input skrst,
output reg rst,

output reg sie_en,
input sie_busy,
output reg[7:0] cmd,
output reg[7:0] regwd,
input[7:0] regrd
);

localparam STATE_W =4;
localparam IDLE =4'b0;
localparam RST1=4'd1;
localparam RSTWT=4'd2;
localparam REGW1=4'd3;
localparam REGWW1=4'd4;
localparam REGW2=4'd5;
localparam REGWW2=4'd6;
localparam REGWWT=4'd7;
localparam REGR1=4'd8;
localparam REGRR1=4'd9;
localparam WRST=4'd10;

localparam DELAY=4'b1111;

reg[3:0] num;
reg[31:0] lnum;
reg[STATE_W-1:0] state;
always@(posedge clk)
	case(state)
	IDLE:if(skrst) state<=IDLE;
			else begin
					state<=DELAY;
					sie_en<=0;
					cmd<=0;
					regwd<=0;
					rst<=0;
					num<=0;
					lnum<=0;
				end
	DELAY:if(lnum==32'b00001000_00000000_00000000_00000000)
				state<=RST1;
			else lnum<=lnum+1'b1;
	RST1:begin
		rst<=1;
		num<=4'b0;
		state<=RSTWT;
		end
	RSTWT:begin
		num<=num+4'b1;
		if(num==4'b0011)begin
			state<=REGW1;
			rst<=0;
			end
		end
	REGW1:if(sie_busy) state<=state;
			else begin
				cmd<=8'b1000_1010;
				regwd<=8'b0000_0000;
				sie_en<=1;
				state<=REGWW1;
				end
	REGWW1:if(sie_busy)
				begin
				sie_en<=0;
				state<=REGW2;
				end
			else state<=state;
	REGW2:if(sie_busy) state<=state;
			else begin
				cmd<=8'b1000_0100;
				regwd<=8'b0110_0101;//fs_1.1
				//regwd<=8'b0111_0100;//chirp
				//regwd<=8'b0110_0110;//ls_1.0
				sie_en<=1;
				state<=REGWW2;
				end
	REGWW2:if(sie_busy)
				begin
				sie_en<=0;
				state<=REGWWT;
				end
			else state<=state;
	REGWWT:begin
			if(sie_busy) state<=state;
			else state<=IDLE;
			end
//	REGR1:if(sie_busy) state<=state;
//			else begin
//				cmd<=8'b1101_0101;
//				sie_en<=1;
//				state<=REGRR1;
//				end
//	REGRR1:if(sie_busy)
//				begin
//				sie_en<=0;
//				state<=REGWWT;
//				end
//			else state<=state;
//	WRST:if(rstd==1)state<=IDLE;//STADD;
//			else state<=state;
//
//	WGETDESC:
//	WINPID:
//	WACK:
//	WOUT:
	endcase

endmodule