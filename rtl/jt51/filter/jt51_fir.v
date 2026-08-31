`timescale 1ns / 1ps

module jt51_fir
#(parameter data_width=9, output_width=12, coeff_width=9,
	addr_width=7, stages=81, acc_extra=1)
(
	input	clk,
	input	rst,
	input	sample,
	input	signed [data_width-1:0] left_in,
	input	signed [data_width-1:0] right_in,
	input	signed [coeff_width-1:0] coeff,
	output	reg 	[addr_width-1:0] cnt,
	output	reg signed [output_width-1:0] left_out,
	output	reg signed [output_width-1:0] right_out,
	output	reg sample_out
);

wire signed [data_width-1:0] mem_left, mem_right;

reg [addr_width-1:0] addr_left, addr_right,
	forward, rev, in_pointer;

reg update, last_sample;

reg	[1:0]	state;
parameter IDLE=2'b00, LEFT=2'b01, RIGHT=2'b10;

jt51_fir_ram #(.data_width(data_width),.addr_width(addr_width)) chain_left(
	.clk	( clk		),
	.data	( left_in 	),
	.addr	( addr_left ),
	.we		( update	),
	.q		( mem_left	)
);

jt51_fir_ram #(.data_width(data_width),.addr_width(addr_width)) chain_right(
	.clk	( clk		),
	.data	( right_in 	),
	.addr	( addr_right),
	.we		( update	),
	.q		( mem_right)
);

always @(posedge clk)
	if( rst )
		{ update, last_sample } <= 2'b00;
	else begin
		last_sample <= sample;
		update <= sample && !last_sample;
	end

parameter mac_width=(data_width+1)+coeff_width;
parameter acc_width=output_width;
reg	signed [acc_width-1:0] acc_left, acc_right;

wire [addr_width-1:0]  next = cnt+1'b1;

reg signed [data_width:0] sum;

wire last_stage = cnt==(stages-1)/2;

reg signed [data_width-1:0] buffer_left, buffer_right;

always @(*) begin
	if( state==LEFT) begin
		if( last_stage )
			sum = buffer_left;
		else
			sum = buffer_left + mem_left;
		end
	else begin
		if( last_stage )
			sum = buffer_right;
		else
			sum = buffer_right + mem_right;
	end
end

wire signed [mac_width-1:0] mac = coeff*sum;
wire signed [acc_width-1:0] mac_trim = mac[mac_width-1:mac_width-acc_width];

wire [addr_width-1:0]
	in_pointer_next = in_pointer - 1'b1,
	forward_next = forward+1'b1,
	rev_next = rev-1'b1;

always @(*)  begin
	case( state )
		default: begin
			addr_left = update ? rev : in_pointer;
			addr_right= in_pointer;
		end
		LEFT: begin
			addr_left = forward_next;
			addr_right= rev;
		end
		RIGHT: begin
			if( cnt==(stages-1)/2 ) begin
				addr_left = in_pointer_next;
				addr_right= in_pointer_next;
			end
			else begin
				addr_left = rev_next;
				addr_right= forward;
			end
		end
	endcase
end

always @(posedge clk)
if( rst ) begin
	sample_out <= 1'b0;
	state	<= IDLE;
	in_pointer <= 7'd0;

end else begin
	case(state)
		default: begin
			if( update ) begin
				state <= LEFT;
				buffer_left <= left_in;

			end
			cnt <= 6'd0;
			acc_left <= {acc_width{1'b0}};
			acc_right <= {acc_width{1'b0}};
			rev <= in_pointer+stages-1'b1;
			forward <= in_pointer;
			sample_out <= 1'b0;
		end
		LEFT: begin
				acc_left <= acc_left + mac_trim;

				buffer_right <= mem_right;

				forward<=forward_next;
				state <= RIGHT;
			end
		RIGHT:
			if( cnt==(stages-1)/2 ) begin
				left_out  <= acc_left;
				right_out <= acc_right + mac_trim;
				sample_out <= 1'b1;
				in_pointer  <= in_pointer_next;

				state <= IDLE;
			end else begin
				acc_right <= acc_right + mac_trim;

				buffer_left <= mem_left;

				cnt<=next;
				rev<=rev-1'b1;
				state <= LEFT;
			end
	endcase
end
endmodule
