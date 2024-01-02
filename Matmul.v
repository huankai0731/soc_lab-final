module Matmul 
#(  parameter pDATA_WIDTH = 32
)
(
    input   wire                     ss_tvalid_A, //stream write?
    input   wire [(pDATA_WIDTH-1):0] ss_tdata_A,
    input   wire                     ss_tlast_A,
    output  wire                     ss_tready_A,

    input   wire                     ss_tvalid_B, //stream write?
    input   wire [(pDATA_WIDTH-1):0] ss_tdata_B,
    input   wire                     ss_tlast_B,
    output  wire                     ss_tready_B,

    input   wire                     sm_tready, //stream read
    output  wire                     sm_tvalid,
    output  wire [(pDATA_WIDTH-1):0] sm_tdata,
    output  wire                     sm_tlast,
    
    input   wire                     axis_clk,
    input   wire                     axis_rst_n
);

assign ss_tready_A = ready;
reg ready=0;
always @(ss_tvalid_A) begin
//$display("%d:",ss_tdata_A);
$display("data:%d",ss_tdata_A);
end


always @(posedge axis_clk) begin
if(ss_tvalid_A)
ready= 1;
else
ready=0;


end

endmodule