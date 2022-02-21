
`timescale 1ns/10ps
module LBP ( clk, reset, gray_addr, gray_req, gray_ready, gray_data, lbp_addr, lbp_valid, lbp_data, finish);
input   	clk;
input   	reset;
output reg [13:0] gray_addr;
output         	gray_req;
input   	gray_ready;
input   [7:0] 	gray_data;
output   [13:0] 	lbp_addr;
output  	lbp_valid;
output  [7:0] 	lbp_data;
output  	finish;
//====================================================================
parameter IDLE=3'd0,
          READ_C=3'd1,
          OPERATION=3'd2,
          WRITE=3'd3,
          DONE=3'd4;

reg [2:0] state,n_state;
reg [2:0] counter,next_counter;
reg [6:0] row,col;
reg [6:0] next_row,next_col;
reg [7:0] center;
reg [7:0] psum,next_psum;
reg [7:0] bias;

wire store;
wire op;
wire [8:0] s;
wire [7:0] tmp;
//=====================================================================
assign store=(state==READ_C)?1'b1:1'b0;
assign op=(state==OPERATION)?1'b1:1'b0;
assign gray_req=(state==READ_C||state==OPERATION)?1'b1:1'b0;
assign lbp_valid=(state==WRITE)?1'b1:1'b0;
assign lbp_addr={row,7'd0}+col; //row*128+col
assign lbp_data=(state==WRITE)?psum:8'd0;
assign finish=(state==DONE)?1'b1:1'b0;

assign s=gray_data-center;
assign tmp=(s[8])?8'd0:(1<<counter);

//FSM
always@(posedge clk or posedge reset)begin
    if(reset)begin
        state<=IDLE;
    end
    else begin
        state<=n_state;
    end
end
always@(*)begin
    case(state)
        IDLE:begin
            if(gray_ready)begin
                n_state=READ_C;
            end
            else begin
                n_state=IDLE;
            end
        end
        READ_C:begin
            n_state=OPERATION;
        end
        OPERATION:begin
            if(counter==3'd7)begin
                n_state=WRITE;
            end
            else begin
                n_state<=OPERATION;
            end
        end
        WRITE:begin
            if(row==7'd126 && col==7'd126)begin
                n_state=DONE;
            end
            else begin
                n_state=READ_C;
            end
        end
        DONE:begin
            n_state=DONE;
        end
        default:begin
            n_state=IDLE;
        end
    endcase
end

// row, col
always@(posedge clk or posedge reset)begin
    if(reset)begin
        row<=7'd1;
        col<=7'd1;
    end
    else if(lbp_valid)begin
        row<=next_row;
        col<=next_col;
    end
    else begin
    end
end
always@(*)begin
    if(lbp_valid)begin
        if(row==7'd126 && col==7'd126)begin
            next_row=row;
            next_col=col;
        end
        else if(col==7'd126)begin
            next_col=7'd1;
            next_row=row+7'd1;
        end
        else begin
            next_row=row;
            next_col=col+7'd1;
        end
    end
    else begin
        next_row=row;
        next_col=col;
    end
end

// center pixel
always@(posedge clk or posedge reset)begin
    if(reset)begin
        center<=8'd0;
    end
    else if(store)begin
        center<=gray_data;
    end
    else begin
    end
end
 //counter
always@(posedge clk or posedge reset)begin
    if(reset)begin
        counter<=3'd0;
    end
    else if(op)begin
        counter<=next_counter;
    end
    else begin
        counter<=3'd0;
    end
end
always@(*)begin
    if(op)begin
        if(counter==3'd7)begin
            next_counter=3'd0;
        end
        else begin
            next_counter=counter+3'd1;
        end
    end
    else begin
        next_counter=counter;
    end
end


// gray_addr
always@(*)begin
    if(state==OPERATION)begin
        if(counter<3'd4)begin
            gray_addr=lbp_addr-bias;
        end
        else begin
            gray_addr=lbp_addr+bias;
        end        
    end
    else begin
        gray_addr=lbp_addr;
    end
end

// bias
always@(*)begin
    case(counter)
        3'd0:bias=8'd129;
        3'd1:bias=8'd128;
        3'd2:bias=8'd127;
        3'd3:bias=8'd1;
        3'd4:bias=8'd1;
        3'd5:bias=8'd127;
        3'd6:bias=8'd128;
        3'd7:bias=8'd129;
        default:bias=8'd0;
    endcase
end

// psum
always@(posedge clk or posedge reset)begin
    if(reset)begin
        psum<=8'd0;
    end
    else if(op)begin
        psum<=next_psum;
    end
    else begin
        psum<=8'd0;
    end
end
always@(*)begin
    if(op)begin
        next_psum=psum+tmp;
    end
    else begin
        next_psum=psum;
    end
end




//====================================================================
endmodule
