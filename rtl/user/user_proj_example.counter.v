// SPDX-FileCopyrightText: 2020 Efabless Corporation
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//      http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.
// SPDX-License-Identifier: Apache-2.0

`default_nettype wire
/*
 *-------------------------------------------------------------
 *
 * user_proj_example
 *
 * This is an example of a (trivially simple) user project,
 * showing how the user project can connect to the logic
 * analyzer, the wishbone bus, and the I/O pads.
 *
 * This project generates an integer count, which is output
 * on the user area GPIO pads (digital output only).  The
 * wishbone connection allows the project to be controlled
 * (start and stop) from the management SoC program.
 *
 * See the testbenches in directory "mprj_counter" for the
 * example programs that drive this user project.  The three
 * testbenches are "io_ports", "la_test1", and "la_test2".
 *
 *-------------------------------------------------------------
 */

module user_proj_example #(
    parameter BITS = 32,
    parameter DELAYS=10
)(
`ifdef USE_POWER_PINS
    inout vccd1,	// User area 1 1.8V supply
    inout vssd1,	// User area 1 digital ground
`endif

`define MPRJ_IO_PADS_1 19	/* number of user GPIO pads on user1 side */
`define MPRJ_IO_PADS_2 19	/* number of user GPIO pads on user2 side */
`define MPRJ_IO_PADS (`MPRJ_IO_PADS_1 + `MPRJ_IO_PADS_2)

    // Wishbone Slave ports (WB MI A)
    input wb_clk_i,
    input wb_rst_i,
    input wbs_stb_i,
    input wbs_cyc_i,
    input wbs_we_i,
    input [3:0] wbs_sel_i,
    input [31:0] wbs_dat_i,
    input [31:0] wbs_adr_i,
    output wbs_ack_o,
    output [31:0] wbs_dat_o,

    // Logic Analyzer Signals
    input  [127:0] la_data_in,
    output [127:0] la_data_out,
    input  [127:0] la_oenb,

    // IOs
    input  [`MPRJ_IO_PADS-1:0] io_in,
    output [`MPRJ_IO_PADS-1:0] io_out,
    output [`MPRJ_IO_PADS-1:0] io_oeb,

    // IRQ
    output [2:0] irq
);
    //tap_ram
    wire tap_WE;
    wire tap_EN;
    wire [11:0]tap_AW;
    wire [11:0]tap_AR;
    wire [31:0]tap_Di;
    wire [31:0]tap_Do;

    //data_ram
    wire data_WE;
    wire data_EN;
    wire [11:0]data_AW;
    wire [11:0]data_AR;
    wire [31:0]data_Di;
    wire [31:0]data_Do;
    wire clk;
    wire rst;

    wire [`MPRJ_IO_PADS-1:0] io_in;
    wire [`MPRJ_IO_PADS-1:0] io_out;
    wire [`MPRJ_IO_PADS-1:0] io_oeb;

    wire [31:0] exmem_rdata; 
    wire [31:0] wdata;
    wire [BITS-1:0] count;

    wire valid;
    wire [3:0] wstrb;
    wire [31:0] la_write;

    wire [31:0]exmem_addr;
    assign exmem_addr = { {8{1'b0}}, wbs_adr_i[23:0]};
    reg ready;
    reg [BITS-17:0] delayed_count;

    // WB MI A
    assign valid = wbs_cyc_i && wbs_stb_i && decoded; 
    assign wstrb = wbs_sel_i & {4{wbs_we_i}};
    assign wdata = wbs_dat_i;

    //wb output
    assign wbs_dat_o = decoded       == 1'b1 ? exmem_rdata : 
                       axi_l_decoded == 1'b1 ? rdata : 
                       axi_s_decoded == 1'b1 ? fir_sm_tdata : mm_sm_tdata ;
                       
                       //mm_decoded    == 1'b1 ? mm_sm_tdata : 
                       //qs_decoded == 1'b1 ? qs_sm_tdata ;   

    assign wbs_ack_o = ready || fir_ready || mm_ready;
    //assign wbs_ack_o = ready || fir_ready ;

    // IO
    assign io_out = count;
    assign io_oeb = {(`MPRJ_IO_PADS-1){rst}};

    // IRQ
    assign irq = 3'b000;	// Unused

    // LA
    assign la_data_out = {{(127-BITS){1'b0}}, count};
    // Assuming LA probes [63:32] are for controlling the count register  
    assign la_write = ~la_oenb[63:32] & ~{BITS{valid}};
    // Assuming LA probes [65:64] are for controlling the count clk & reset  
    assign clk = (~la_oenb[64]) ? la_data_in[64]: wb_clk_i;
    assign rst = (~la_oenb[65]) ? la_data_in[65]: wb_rst_i;


    wire decoded;
    assign decoded = wbs_adr_i[31:20] == 12'h380 ? 1'b1 : 1'b0;

    wire fir_decodeed;
    assign fir_decodeed = {wbs_adr_i[31:20],wbs_adr_i[11:8] } == 16'h3000 ? 1'b1 : 1'b0;

    wire mm_decoded;
    assign mm_decoded = {wbs_adr_i[31:20],wbs_adr_i[11:8] } == 16'h3001 ? 1'b1 : 1'b0;

    wire qs_decoded;
    assign qs_decoded = {wbs_adr_i[31:20],wbs_adr_i[11:8] } == 16'h3002 ? 1'b1 : 1'b0;

    //fir
    wire fir_ready;
    assign fir_ready = wready || arready || fir_ss_tready || fir_sm_tready;

    //fri Axi lite
    wire [11:0]awaddr;
    wire [11:0]araddr;
    wire wvalid;
    wire awvalid;
    wire wready;
    wire arvalid;
    wire [31:0]rdata;
    wire axi_l_decoded;
    wire arready;
    wire rready;
    wire rvalid;

    assign axi_l_decoded = fir_decodeed & ~wbs_adr_i[7];
    assign wvalid = wbs_cyc_i && wbs_stb_i && axi_l_decoded && wbs_sel_i && wbs_we_i;
    assign awvalid = wbs_cyc_i && wbs_stb_i && axi_l_decoded && wbs_sel_i && wbs_we_i;
    assign awaddr = wbs_adr_i[11:0];
    assign araddr = wbs_adr_i[11:0];
    assign arvalid = wbs_cyc_i && wbs_stb_i && axi_l_decoded && wbs_sel_i && !wbs_we_i;

    //fir Axi stream
    wire axi_s_decoded;
    wire fir_ss_tvalid;
    wire fir_ss_tready;
    wire fir_ss_tlast;
    wire fir_sm_tvalid;
    wire fir_sm_tlast;
    wire [31:0]fir_sm_tdata;
    reg fir_sm_tready;
    assign axi_s_decoded = fir_decodeed & wbs_adr_i[7];
    assign fir_ss_tvalid = wbs_cyc_i && wbs_stb_i && axi_s_decoded && wbs_sel_i && wbs_we_i;


    //mm
    wire mm_ready;
    assign mm_ready = mm_ss_tready ||  mm_sm_tready;

    //mm Axi stream
    wire mm_ss_tvalid;
    wire mm_ss_tready;
    wire mm_ss_tlast;

    wire mm_sm_tvalid;
    wire mm_sm_tlast;
    wire [31:0]mm_sm_tdata;
    reg mm_sm_tready;

    assign mm_ss_tvalid = wbs_cyc_i && wbs_stb_i && mm_decoded && wbs_sel_i && wbs_we_i;


    integer sm_DELAYS =10;

//fir_sm_output delay
    always @(posedge clk) begin

            fir_sm_tready <= 1'b0;

            if ( fir_sm_tvalid && !fir_sm_tready && axi_s_decoded) begin
                if ( delayed_count == sm_DELAYS ) begin
                    delayed_count <= 16'b0;
                    fir_sm_tready <= 1'b1;
                    //$display(fir_sm_tdata);
                end else begin
                    delayed_count <= delayed_count + 1;
                end
            end
    end


//mm_sm output delay
    always @(posedge clk) begin

            mm_sm_tready <= 1'b0;

            if ( mm_sm_tvalid && !mm_sm_tready && mm_decoded) begin
                if ( delayed_count == sm_DELAYS ) begin
                    delayed_count <= 16'b0;
                    mm_sm_tready <= 1'b1;
                    $display(mm_sm_tdata);
                end else begin
                    delayed_count <= delayed_count + 1;
                end
            end
    end


//exmem delay
    always @(posedge clk) begin
        if (rst) begin
            ready <= 1'b0;
            delayed_count <= 16'b0;
        end else begin
            ready <= 1'b0;
            if ( valid && !ready ) begin
                if ( delayed_count == DELAYS ) begin
                    delayed_count <= 16'b0;
                    ready <= 1'b1;
                end else begin
                    delayed_count <= delayed_count + 1;
                end
            end
        end
    end


    bram user_bram (
        .CLK(clk),
        .WE0(wstrb),
        .EN0(valid),
        .Di0(wbs_dat_i),
        .Do0(exmem_rdata),
        .A0(exmem_addr)
    );

    bram11 tap_RAM (
        .clk(clk),
        .we(tap_WE),
        .re(tap_EN),
        .waddr(tap_AW),
        .raddr(tap_AR),
        .wdi(tap_Di),
        .rdo(tap_Do)
    );

    bram11 data_RAM (
        .clk(clk),
        .we(data_WE),
        .re(data_EN),
        .waddr(data_AW),
        .raddr(data_AR),
        .wdi(data_Di),
        .rdo(data_Do)
    );

    fir fir_DUT(

        .awready(wready),
        .wready(wready),
        .awvalid(awvalid),
        .awaddr(awaddr),
        .wvalid(wvalid),
        .wdata(wdata),

        .arready(arready),
        .rready(rready),
        .arvalid(arvalid),
        .araddr(araddr),
        .rvalid(rvalid),
        .rdata(rdata),


        .ss_tvalid(fir_ss_tvalid),
        .ss_tdata(wdata),
        .ss_tlast(fir_ss_tlast),
        .ss_tready(fir_ss_tready),

        .sm_tready(fir_sm_tready),
        .sm_tvalid(fir_sm_tvalid),
        .sm_tdata(fir_sm_tdata),
        .sm_tlast(fir_sm_tlast),

        // ram for tap
        .tap_WE(tap_WE),
        .tap_EN(tap_EN),
        .tap_Di(tap_Di),
        .tap_AW(tap_AW),
        .tap_AR(tap_AR),
        .tap_Do(tap_Do),

        // ram for data
        .data_WE(data_WE),
        .data_EN(data_EN),
        .data_Di(data_Di),
        .data_AW(data_AW),
        .data_AR(data_AR),
        .data_Do(data_Do),

        .axis_clk(clk),
        .axis_rst_n(rst)

        );

    Matmul matmul(

        .ss_tvalid_A(mm_ss_tvalid),
        .ss_tdata_A(wdata),
        .ss_tlast_A(mm_ss_tlast),
        .ss_tready_A(mm_ss_tready),

        .sm_tready(mm_sm_tready),
        .sm_tvalid(mm_sm_tvalid),
        .sm_tdata(mm_sm_tdata),
        .sm_tlast(mm_sm_tlast),

        .axis_clk(clk),
        .axis_rst_n(rst)

    );

endmodule





`default_nettype wire
