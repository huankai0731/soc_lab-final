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

//reg [3:0] a11,a12,a13,a14,a21,a22,a23,a24,a31,a32,a33,a34,a41,a42,a43,a44;//A矩陣16個元素
//reg [3:0] b11,b12,b13,b14,b21,b22,b23,b24,b31,b32,b33,b34,b41,b42,b43,b44;//矩陣16個元素
reg ss_tready_A_w,ss_tready_B_w,sm_tvalid_w,sm_tlast_w;
//register
reg [2:0] state_r,state_w;
reg [(pDATA_WIDTH-1):0] A_w[0:3],A_r[0:3];
reg [(pDATA_WIDTH-1):0] B_w[0:3],B_r[0:3];
reg [(pDATA_WIDTH-1):0] C_w[0:3],C_r[0:3];

reg [3:0] counter_w,counter_r,cout_w,cout_r;
//parameer & integer
parameter   Idle=0,
            Load_A=1,
            Load_B=2,
            Alu=3,
            Out=4;
            
integer i,j,k;
//continuous assignment
assign ss_tready_A=ss_tready_A_w;
assign ss_tready_B=ss_tready_B_w;
assign sm_tvalid  =sm_tvalid_w;
assign sm_tlast   =sm_tlast_w;
assign sm_tdata   =C_r[cout_r];

//Finite State Machine
    always@(*)begin
       case (state_r)
        Idle:begin //結束要做reset
            if ("接收CPU訊號準備開始運作"==1) begin
                state_w=Load_A;//要檢查是否下個cycle就會正確給直
            end else begin
                state_w = Idle;
            end
        end
            
        Load_A:begin
            state_w=Load_A;
            if(counter_r==15 && ss_tlast_A==1)begin //判斷條件也許擇一就可以
            state_w=Load_B;
            end
        end

        Load_B:begin
            state_w=Load_B; 
            if(counter_r==15 && ss_tlast_B==1)begin
            state_w=Alu;
            end
        end

        Alu:begin
            if(counter_r == 15) state_w=Out;
            else state_w = Alu;
        end
        
        Out:begin
            if(sm_tlast==1)begin
                state_w = Idle;
            end else state_w = Out;
        end
        default:state_w= state_r; 
       endcase
    end

//Combinational block
    always@(*)begin
    //initiallize
    sm_tvalid_w=0;
    sm_tlast_w=0;
    ss_tready_A_w=0;
    ss_tready_B_w=0;
    cout_w = cout_r;
    counter_w=counter_r;
    for (i=0; i<16; i=i+1)A_w[i] <=0;
    for (j=0; j<16; j=j+1)B_w[j] <=0;
    for (k=0; k<16; k=k+1)C_w[k] <=0;
        case (state_r)
         Idle:begin
            ss_tready_A_w=1;
        //reset
            cout_r                       = 0;
            counter_r                    = 0;
            for (i=0; i<16; i=i+1)A_r[i] = 0;
            for (j=0; j<16; j=j+1)B_r[j] = 0;
            for (k=0; k<16; k=k+1)C_r[k] = 0;
         end
         Load_A:begin
            counter_w=counter_r+1;
            A_w[counter_r]=ss_tdata_A;
            if(counter_r==15)begin
                ss_tready_A_w=0;
                ss_tready_B_w=1;
                counter_w=0;
            end
         end
         Load_B:begin
            counter_w=counter_r+1;
            B_w[counter_r]=ss_tdata_B;
            if(counter_r==15)begin
                ss_tready_B_w=0;
                counter_w=0;
            end
         end
         Alu:begin
            counter_w=counter_r+1;
            case (counter_r[3:2])
                2'd0:C_w[counter_r]=A_r[0]*B_r[counter_r[1:0]]+A_r[1]*B_r[counter_r[1:0]+4]+A_r[2]*B_r[counter_r[1:0]+8]+A_r[3]*B_r[counter_r[1:0]+12];
                2'd1:C_w[counter_r]=A_r[4]*B_r[counter_r[1:0]]+A_r[5]*B_r[counter_r[1:0]+4]+A_r[6]*B_r[counter_r[1:0]+8]+A_r[7]*B_r[counter_r[1:0]+12];
                2'd2:C_w[counter_r]=A_r[8]*B_r[counter_r[1:0]]+A_r[9]*B_r[counter_r[1:0]+4]+A_r[10]*B_r[counter_r[1:0]+8]+A_r[11]*B_r[counter_r[1:0]+12];
                2'd3:C_w[counter_r]=A_r[12]*B_r[counter_r[1:0]]+A_r[13]*B_r[counter_r[1:0]+4]+A_r[14]*B_r[counter_r[1:0]+8]+A_r[15]*B_r[counter_r[1:0]+12];
                default:C_w[0]=C_r[0];
            endcase
            cout_w = 0;
         end
         Out:begin
            if(sm_tready)begin
                sm_tvalid_w=1;
                cout_w=cout_r+1;
            end
            if(cout_r==15)sm_tlast_w=1;
         end
        default:state_w=7;
        endcase
    end
 //Sequential block
    always @(posedge axis_clk or posedge axis_rst_n) begin
        if(~axis_rst_n)begin
            state_r                      <= 0;
            cout_r                       <= 0;
            counter_r                    <= 0;
            for (i=0; i<16; i=i+1)A_r[i] <= 0;
            for (j=0; j<16; j=j+1)B_r[j] <= 0;
            for (k=0; k<16; k=k+1)C_r[k] <= 0;
        end else begin
            state_r                      <= state_w;
            cout_r                       <= cout_w;
            counter_r                    <= counter_w;
            for (i=0; i<16; i=i+1)A_r[i] <=A_w[i];
            for (j=0; j<16; j=j+1)B_r[j] <=B_w[j];
            for (k=0; k<16; k=k+1)C_r[k] <=C_w[k];
        end
    end 
endmodule