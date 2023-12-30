  module fir 
#(  parameter pADDR_WIDTH = 12,
    parameter pDATA_WIDTH = 32,
    parameter Tape_Num    = 11
)
(
    output  wire                     awready,
    input   wire [(pADDR_WIDTH-1):0] awaddr,
    input   wire                     awvalid,
    output  wire                     wready,
    input   wire                     wvalid,
    input   wire [(pDATA_WIDTH-1):0] wdata,
    output  wire                     arready,
    input   wire                     arvalid,
    input   wire [(pADDR_WIDTH-1):0] araddr,
    input   wire                     rready,
    output  wire                     rvalid,
    output  wire [(pDATA_WIDTH-1):0] rdata, 
    
    input   wire                     ss_tvalid, 
    input   wire [(pDATA_WIDTH-1):0] ss_tdata, 
    input   wire                     ss_tlast, 
    output  wire                     ss_tready, 
    input   wire                     sm_tready, 
    output  wire                     sm_tvalid, 
    output  wire [(pDATA_WIDTH-1):0] sm_tdata, 
    output  wire                     sm_tlast, 
    
    output  wire                     tap_WE,
    output  wire                     tap_EN,
    output  wire [(pDATA_WIDTH-1):0] tap_Di,
    output  wire [(pADDR_WIDTH-1):0] tap_AW,
    output  wire [(pADDR_WIDTH-1):0] tap_AR,
    input   wire [(pDATA_WIDTH-1):0] tap_Do,
    output  wire                     data_WE,
    output  wire                     data_EN,
    output  wire [(pDATA_WIDTH-1):0] data_Di,
    output  wire [(pADDR_WIDTH-1):0] data_AW,
    output  wire [(pADDR_WIDTH-1):0] data_AR,
    input   wire [(pDATA_WIDTH-1):0] data_Do, 

    input   wire                     axis_clk,
    input   wire                     axis_rst_n
    

);
//bram initialization
reg bram_init = 1;
reg [(pADDR_WIDTH-1):0]init_adddr = 0;

//data_ram
reg data_we;
reg data_en;
reg [(pADDR_WIDTH-1):0]data_a;
reg [(pDATA_WIDTH-1):0]data_di;
assign data_WE = data_we;
assign data_EN = data_en;
assign data_AW = data_a;
assign data_AR = data_a;
assign  data_Di = data_di;

//tap_ram
reg tap_we;
reg tap_en;
reg [(pADDR_WIDTH-1):0]tap_a;
reg [(pDATA_WIDTH-1):0]tap_di;
assign tap_WE = tap_we;
assign tap_EN = tap_en;
assign tap_AW = tap_a;
assign tap_AR = tap_a;
assign tap_Di = tap_di;

//ap_ctr
reg[(pDATA_WIDTH-1):0] ap_ctr = 32'b100;

//datalength
reg [31:0]data_length = 0;

//axi lite
reg Wready=0;
reg Awready=0;
reg Arready=0;
reg Rvalid=0;
reg [(pDATA_WIDTH-1):0] Rdata;
//bram read delay
reg [4:0]delay_count = 0;
integer  bram_read_delay = 2;
assign wready = Wready;
assign awready = Awready;
assign arready = Arready;
assign rvalid = Rvalid;
assign rdata = Rdata;

//axi stream
reg Ss_tready = 0;
reg Sm_tvalid = 0;
reg Sm_tlast = 0;
reg [5:0]count = 0;
reg [11:0]data_addr = 0;
reg [5:0]shift_addr = 0;
reg [5:0]shift_addr_reg = 0;
reg [(pDATA_WIDTH-1):0] Sm_tdata;
assign ss_tready = Ss_tready;
assign sm_tdata = Sm_tdata;
assign sm_tvalid = Sm_tvalid;
assign sm_tlast = Sm_tlast;

//fir
reg [31:0]coef;
reg [31:0]data;
reg [31:0]temp = 0;
reg [31:0]result = 0;
//fir delay
reg [3:0]fir_delay = 0; 
//state
reg start = 0;
reg fir = 0;
reg [6:0]data_count = 0;

always  @(posedge  axis_clk) begin 
  ap_ctr[4] <= 1'b0; 

    if(ap_ctr[0] && !fir) start <= 1;

    if(start && !fir) ap_ctr[4] <= 1'b1;

    if(start && fir) begin
        if(count < Tape_Num)begin
            if(fir_delay < 3)begin
                tap_a <= count;
                data_a <= (shift_addr-count);
                coef <= tap_Do;
                data <= data_Do; 
                fir_delay <= fir_delay+1;end
            else begin
                fir_delay <= 0;                
                if((shift_addr-count) == 0) shift_addr = 11 + shift_addr_reg;
                count <= count+1;
                temp <= coef*data;
                result <= result+temp;end 
        end
        else begin 
        count <= 0;
            if(shift_addr_reg == 10) begin 
            shift_addr_reg <= 0;
            shift_addr <= 0;
            end
            else begin            
            shift_addr_reg <= shift_addr_reg+1;
            shift_addr <= shift_addr_reg+1;
            end
        Sm_tdata <= result;
        Sm_tvalid <= 1;
        fir <= 0;   
        //ready to recive x[n]
        ap_ctr[4] <= 1'b1;  
        //ready to send y[n]
        ap_ctr[5] <= 1'b1;  
        result <= 0;
        end
    end
end

always  @(posedge  axis_clk) begin 
Sm_tlast <= 0;
if(sm_tready) begin
    Sm_tvalid <= 0;

    //reset all state
    if(data_count == data_length) begin
        //set ap_done = 1;ap_idle = 1; (000011)
        ap_ctr <= 6;
        data_count <= 0;
        bram_init <= 1;
        fir <= 0;
        start <= 0;
        Sm_tlast <= 1;
    end
end
end

always  @(posedge  axis_clk) begin     
    if(!bram_init && ss_tvalid && !Ss_tready && !fir) begin 
        data_we <= 1'b1;
        data_en <= 1'b1;
        data_a <= shift_addr-count;
        data_di <= ss_tdata;     
        fir <= 1;  
        data_addr <= data_addr+1;
        Ss_tready <= 1; 
        data_count <= data_count+1;end
    else begin
        data_we <= 1'b0;
        Ss_tready <= 0;end
end


//axi lite write
always  @(posedge  axis_clk) begin  
    Wready <= 0; Awready <= 0; tap_we <= 1'b0; 
    if(!bram_init && wvalid && !Wready) begin   
        case(awaddr[6:4])
            3'b000: begin   
                ap_ctr <= wdata; 
                Wready <= 1; Awready <= 1;end
            3'b001: begin 
                data_length <= wdata;
                Wready <= 1; Awready <= 1;end              
            3'b010,
            3'b011,
            3'b100: begin  
                if(ram_delay < 2)begin            
                tap_we <= 1'b1;
                tap_en <= 1'b1;
                tap_a <= {8'b0,awaddr[6],awaddr[4:2]};
                tap_di <= wdata;
                ram_delay <= ram_delay+1;end
                else begin
                Wready <= 1;
                Awready <= 1;
                ram_delay <= 0;end 
            end         
            endcase 
    end
end

//axi lit read
always @(posedge axis_clk) begin
Arready <= 0;Rvalid <= 0;
if(!bram_init && arvalid && !Arready) begin   
        case(araddr[6:4])
            3'b000: begin
                Rdata <= ap_ctr; 
                Arready <= 1;end
            3'b001: begin
                Rdata <= data_length;
                Arready <= 1;end              
            3'b010,
            3'b011,
            3'b100: begin              
                tap_en <= 1'b1;
                tap_a <= {8'b0,araddr[6],araddr[4:2]};               
                Rdata <= tap_Do;
                if(delay_count == bram_read_delay)  begin
                 Arready <= 1;
                 Rvalid <= 1;
                 delay_count <= 0; end
                else delay_count <= delay_count+1;
                end          
            endcase 
end 
end


integer ram_delay =0;
//bram_initialization
integer x=0;
always @(posedge axis_clk) begin
if(bram_init) begin
    ap_ctr <= 32'b100;
    if(x<11)begin
        if(ram_delay < 2)begin
        data_we <= 1'b1; tap_we <= 1'b1;
        data_en <= 1'b1; tap_en <= 1'b1;
        data_a <= init_adddr; tap_a <= init_adddr;
        data_di <= 32'b0; tap_di <= 32'b0;
        ram_delay <= ram_delay+1;
        end
        else begin
        init_adddr <= init_adddr+1;
        x <= x+1;
        ram_delay <= 0; end   
    end
    else begin
        x <= 0;
        bram_init <= 0;
        data_we = 1'b0; tap_we = 1'b0;
        data_en = 1'b1; tap_en = 1'b1;
        init_adddr <= 0;end
end
end


endmodule