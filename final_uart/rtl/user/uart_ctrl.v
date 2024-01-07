module ctrl(
    input wire        rst_n,
    input wire        clk,
    input wire        i_wb_valid,
    input wire [31:0] i_wb_adr,
    input wire        i_wb_we,
    input wire [31:0] i_wb_dat,
    input wire [3:0]  i_wb_sel,
    output reg        o_wb_ack,
    output reg [31:0] o_wb_dat,
    input wire [7:0]  i_rx,
    input wire        i_irq,
    input wire        i_rx_busy,
    input wire        i_frame_err,
    output reg        o_rx_finish,
    output reg [7:0]  o_tx,
    input wire        i_tx_start_clear,
    input wire        i_tx_busy,
    output reg        o_tx_start
);

// Declare the UART memory mapped registers address
localparam RX_DATA  = 32'h3000_0000;

localparam TX_DATA	= 32'h3000_0004;

localparam STAT_REG = 32'h3000_0008;

//+------+-------+-------+-------+-------+-------+-------+-------+-------+-------+-------+
//|RX_DATA |  RESERVERD  |                        DATA BITS                              |
//|        |    31-8     |  7    |  6    |  5    |  4    |  3    |  2    |  1    |  0    |
//+------+-------+-------+-------+-------+-------+-------+-------+-------+-------+-------+
//|TX_DATA |  RESERVERD  |                        DATA BITS                              |
//|        |    31-8     |  7    |  6    |  5    |  4    |  3    |  2    |  1    |  0    |
//+------+-------+-------+-------+-------+-------+-------+-------+-------+-------+-------+-------+-------+
//|STAT_REG|  RESERVERD  |  Frame Err  |  Overrun Err  |  Tx_full  |  Tx_empty  |  Rx_full  |  Rx_empty |
//|        |    31-6     |  5          |  4            |  3        |  2         |  1        |  0        |
//+------+-------+-------+-------+-------+-------+-------+-------+-------+-------+-------+-------+-------+

reg [31:0] rx_buffer;
reg [31:0] tx_buffer;
reg [31:0] stat_reg;    
reg tx_start_local;


//fifo recive
reg rxw_en;
reg rxr_en;
wire [7:0]rxfifo_rdata;
wire rxfifo_empty;
wire rxfifo_full;

//fifo transmittwer
reg txw_en;
reg txr_en;
reg [7:0]txfifo_wdata;
wire [7:0]txfifo_rdata;
wire txfifo_empty;
wire txfifo_full;


always@(posedge clk or negedge rst_n)begin
    if(!rst_n)begin
        stat_reg <= 32'h0000_0005;
    end else begin
        if(i_wb_valid && !i_wb_we)begin
            if(i_wb_adr==STAT_REG)
                stat_reg[5:4] <= 2'b00;
        end

        if(i_tx_busy)
            stat_reg[3:2] <= 2'b10;
        else
            stat_reg[3:2] <= 2'b01;

        if(i_frame_err && i_rx_busy)
            stat_reg[5] <= 1'b1;




        else if(i_rx_busy && stat_reg[1:0]==2'b10)
            stat_reg[4] <= 1'b1;
/////////////////////////////

/*
        //when rx send data to ctr
        else if(i_irq && !stat_reg[1] && !i_frame_err)
            stat_reg[1:0] <= 2'b10;

        //change  when fifo write done
        else if((i_wb_valid && i_wb_adr==RX_DATA && !i_wb_we && stat_reg[1:0]==2'b10) || i_frame_err)
            stat_reg[1:0] <= 2'b01;
*/        

    end
end

/*
always@(posedge clk or negedge rst_n)begin
    if(!rst_n || i_tx_start_clear)begin
        tx_buffer <= 32'h00000000;
        tx_start_local <= 1'b0;
    end else begin
        if(i_wb_valid && i_wb_we && i_wb_adr==TX_DATA && !i_tx_busy)begin
            tx_buffer <= i_wb_dat;
            tx_start_local <= 1'b1;
        end
    end
end

always@(posedge clk or negedge rst_n)begin
    if(!rst_n || i_tx_start_clear)begin
        o_tx <= 8'b0;
        o_tx_start <= 1'b0;
    end else begin
        o_tx <= tx_buffer[7:0];
        o_tx_start <= tx_start_local;
    end
end
*/

reg recive_data;
//write from wb to fifo
always@(posedge clk or negedge rst_n)begin
    if(!rst_n || i_tx_start_clear)begin
        txfifo_wdata <= 32'h00000000;
        txw_en <= 1'b0;
        txr_en <= 1'b0;
        recive_data <= 1'b0;
    end 
    else begin
        if(i_wb_valid && i_wb_we && i_wb_adr==TX_DATA && !recive_data)begin
            txfifo_wdata <= i_wb_dat[7:0];
            txw_en <= 1'b1;
            recive_data <= 1'b1;
        end
        else txw_en <= 1'b0;
        if(!i_wb_valid) recive_data <= 1'b0;
    end
end

reg [7:0]tx_d;
reg en_d;
always@(posedge clk or negedge rst_n)begin
    if(!rst_n || i_tx_start_clear)begin
        o_tx <= 8'b0;
        o_tx_start <= 1'b0;
        tx_start_local <= 1'b0;
        en_d <= 0;
    end else if(!i_tx_busy && !txfifo_empty) begin
        
        txr_en <= 1'b1;
        en_d <= txr_en;

    end
    if(en_d) begin
        o_tx <= txfifo_rdata;
        o_tx_start <= 1'b1;
        txr_en <= 1'b0;
        en_d <= 1'b0;
    end
end




















/////////////////////////////

always@(posedge clk or negedge rst_n)begin
    if(!rst_n)begin
        rx_buffer <= 32'h00000000;
        o_rx_finish <= 1'b0;
    end else begin
        if(i_irq && !stat_reg[1] && !i_frame_err)begin 
            rxw_en <= 1;
            o_rx_finish <= 1'b1;
            rx_buffer <= i_rx;
            $display("rx_buffer: %d", i_rx);
            stat_reg[1:0] <= 2'b01;
        end
        else begin
            rxw_en <= 0;
            o_rx_finish <= 1'b0;
        end
    end
end

always@(posedge clk or negedge rst_n)begin
    if(!rst_n)begin
        o_wb_dat <= 32'h00000000;
        rxr_en <= 1'b0;
    end else begin
        if(i_wb_valid && !i_wb_we)begin
            case(i_wb_adr)
                RX_DATA:begin
                    o_wb_dat <= {24'b0,rxfifo_rdata};
                    rxr_en <= 1'b1;
                    $display("rx read");
                end
                STAT_REG:begin
                    o_wb_dat <= stat_reg;
                end
                default:begin 
                    o_wb_dat <= 32'h00000000;
                end
            endcase
        end
        else rxr_en <= 1'b0;
    end
end


reg o_wb_ack_d;
reg o_wb_ack_d2;
always@(posedge clk or negedge rst_n)begin
    if(!rst_n)begin
        o_wb_ack <= 1'b0;
        o_wb_ack_d <= 1'b0;
        o_wb_ack_d2 <= 1'b0;
    end else begin
        if(i_wb_valid )  begin        

                o_wb_ack_d <= 1'b1;
                o_wb_ack_d2 <= o_wb_ack_d;
                o_wb_ack <= o_wb_ack_d2;
        end
        else  begin          
            o_wb_ack <= 1'b0;
            o_wb_ack_d <= 1'b0;
            o_wb_ack_d2 <= 1'b0;
        end
    end
end

/////////////////////////////

/*
always@(posedge clk or negedge rst_n)begin
    if(!rst_n)begin
        o_rx_finish <= 1'b0;
    end else begin
        if((i_wb_valid && i_wb_adr==RX_DATA && !i_wb_we && stat_reg[1:0]==2'b10) || i_frame_err)
            o_rx_finish <= 1'b1;
        else 
            o_rx_finish <= 1'b0;
    end
end

always@(posedge clk or negedge rst_n)begin
    if(!rst_n)begin
        rx_buffer <= 32'h00000000;
    end else begin
        if(i_irq && !stat_reg[1] && !i_frame_err)begin 
            rx_buffer <= i_rx;
            $display("rx_buffer: %d", i_rx);
        end
    end
end

always@(posedge clk or negedge rst_n)begin
    if(!rst_n)begin
        o_wb_dat <= 32'h00000000;
    end else begin
        if(i_wb_valid && !i_wb_we)begin
            case(i_wb_adr)
                RX_DATA:begin
                    o_wb_dat <= rx_buffer;
                end
                STAT_REG:begin
                    o_wb_dat <= stat_reg;
                end
                default:begin 
                    o_wb_dat <= 32'h00000000;
                end
            endcase
        end
    end
end

always@(posedge clk or negedge rst_n)begin
    if(!rst_n)begin
        o_rx_finish <= 1'b0;
    end else begin
        if((i_wb_valid && i_wb_adr==RX_DATA && !i_wb_we && stat_reg[1:0]==2'b10) || i_frame_err)
            o_rx_finish <= 1'b1;
        else 
            o_rx_finish <= 1'b0;
    end
end
*/




fifo transmitter_fifo(
    .clk(clk),
    .rstn(rst_n),
    .wr_en(txw_en),
    .rd_en(txr_en),
    .wr_data(txfifo_wdata),
    .rd_data(txfifo_rdata),
    .fifo_full(txfifo_full),
    .fifo_empty(txfifo_empty)
);

fifo receiver_fifo(
    .clk(clk),
    .rstn(rst_n),
    .wr_en(rxw_en),
    .rd_en(rxr_en),
    .wr_data(rx_buffer[7:0]),
    .rd_data(rxfifo_rdata),
    .fifo_full(rxfifo_full),
    .fifo_empty(rxfifo_empty)
);




endmodule

module fifo(clk, rstn, wr_en, rd_en, wr_data, rd_data, fifo_full, fifo_empty);

    
    parameter   width = 8;
    parameter   depth = 8;
    parameter   addr  = 3;


    input   clk;   
    input   rstn;   
    input   wr_en;  
    input   rd_en;


    input   [width - 1 : 0] wr_data; 
    output  [width - 1 : 0] rd_data;   

    reg [width - 1 : 0] rd_data;

  
    output  fifo_full;
    output  fifo_empty;

    
    reg [$clog2(depth): 0] cnt;

    reg [depth - 1 : 0] wr_ptr;
    reg [depth - 1 : 0] rd_ptr;

    reg [width - 1 : 0] fifo [depth - 1 : 0];

    always @ (posedge clk or negedge rstn) begin
        if(!rstn)
            wr_ptr <= 0;
        else if(wr_en && !fifo_full)   
            wr_ptr <= wr_ptr + 1;
        else
            wr_ptr <= wr_ptr;
    end

    always @ (posedge clk or negedge rstn) begin
        if(!rstn)
            rd_ptr <= 0;
        else if(rd_en && !fifo_empty)   
            rd_ptr <= rd_ptr + 1;
        else
            rd_ptr <= rd_ptr;
    end

    integer i;

    always @ (posedge clk or negedge rstn) begin
        if(!rstn) begin 
            for(i = 0; i < depth; i = i + 1)
                fifo[i] <= 0;
        end
        else if(wr_en)  
            fifo[wr_ptr] <= wr_data;
        else   
            fifo[wr_ptr] <= fifo[wr_ptr];
    end

    always @ (posedge clk or negedge rstn) begin
        if(!rstn)
            rd_data <= 0;
        else if (rd_en)
            rd_data <= fifo[rd_ptr];    
        else
            rd_data <= rd_data;
    end


    always @ (posedge clk or negedge rstn) begin
        if(!rstn)
            cnt <= 0;
        else if (wr_en && !rd_en && !fifo_full) 
            cnt <= cnt + 1;
        else if (!wr_en && rd_en && !fifo_empty) 
            cnt <= cnt - 1;
        else 
            cnt <= cnt;
    end

    assign fifo_full = (cnt == depth)? 1 : 0;
    assign fifo_empty = (cnt == 0) ? 1 : 0;
endmodule
