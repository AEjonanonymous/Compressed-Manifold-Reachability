/**
 * @file testbench.sv
 * @brief Comprehensive Verification Suite for CMR AXI-Lite Pipeline
 * @author Jonathan f(n) Reed
 * @license GNU Affero General Public License v3.0 (AGPL-3.0)
 */

module testbench;

    parameter int WIDTH = 32;
    parameter int R = 4;
    parameter int D = 6;

    logic clk;
    logic rst_n;
    logic [7:0] awaddr, araddr;
    logic awvalid, awready;
    logic [WIDTH-1:0] wdata;
    logic wvalid, wready;
    logic [1:0] bresp;
    logic bvalid, bready;
    logic arvalid, arready;
    logic [WIDTH-1:0] rdata;
    logic [1:0] rresp;
    logic rvalid, rready;

    cmr_axi_pipeline #(.WIDTH(WIDTH), .R(R), .D(D)) uut (
        .s_axi_aclk(clk),
        .s_axi_aresetn(rst_n),
        .s_axi_awaddr(awaddr),
        .s_axi_awvalid(awvalid),
        .s_axi_awready(awready),
        .s_axi_wdata(wdata),
        .s_axi_wstrb(4'hf),
        .s_axi_wvalid(wvalid),
        .s_axi_wready(wready),
        .s_axi_bresp(bresp),
        .s_axi_bvalid(bvalid),
        .s_axi_bready(bready),
        .s_axi_araddr(araddr),
        .s_axi_arvalid(arvalid),
        .s_axi_arready(arready),
        .s_axi_rdata(rdata),
        .s_axi_rresp(rresp),
        .s_axi_rvalid(rvalid),
        .s_axi_rready(rready)
    );

    always #5 clk = ~clk;

    task axi_write(input [7:0] addr, input [WIDTH-1:0] data);
        @(posedge clk);
        awaddr = addr;
        wdata = data;
        awvalid = 1'b1;
        wvalid = 1'b1;
        bready = 1'b1;
        @(posedge clk);
        awvalid = 1'b0;
        wvalid = 1'b0;
        #1;
    endtask

    task axi_read(input [7:0] addr, output [WIDTH-1:0] data);
        @(posedge clk);
        araddr = addr;
        arvalid = 1'b1;
        rready = 1'b1;
        @(posedge clk);
        #1;
        data = rdata;
        arvalid = 1'b0;
        @(posedge clk);
    endtask

    initial begin
        logic [WIDTH-1:0] read_val;
        logic [WIDTH-1:0] done_val;

        clk = 0;
        rst_n = 0;
        awvalid = 0; wvalid = 0; bready = 0; arvalid = 0; rready = 1;
        awaddr = 0; araddr = 0; wdata = 0;

        $display("------------------------------------------------------------");
        $display("[INFO] Initializing CMR AXI-Lite Hardware Testbench...");
        $display("------------------------------------------------------------");

        #15 rst_n = 1;
        #10;

        $display("[INFO] Writing test vectors across d = %0d dimensions...", D);
        axi_write(8'h04, 32'sd5);  // dt = 5
        axi_write(8'h08, 32'sd100); // v[0] = 100
        axi_write(8'h0C, 32'sd90);  // v[1] = 90
        axi_write(8'h10, 32'sd110); // v[2] = 110
        axi_write(8'h14, 32'sd95);  // v[3] = 95
        axi_write(8'h18, 32'sd105); // v[4] = 105
        axi_write(8'h1C, 32'sd85);  // v[5] = 85

        axi_write(8'h20, 32'sd10); // h[0] = 10
        axi_write(8'h24, 32'sd8);  // h[1] = 8
        axi_write(8'h28, 32'sd12); // h[2] = 12
        axi_write(8'h2C, 32'sd9);  // h[3] = 9
        axi_write(8'h30, 32'sd11); // h[4] = 11
        axi_write(8'h34, 32'sd7);  // h[5] = 7

        $display("[INFO] Triggering hardware execution pulse...");
        axi_write(8'h00, 32'sd1);
        axi_write(8'h00, 32'sd0);

        #40;

        $display("[INFO] Polling AXI-Lite bus for completion and safety result...");
        axi_read(8'h3C, done_val);
        axi_read(8'h38, read_val);

        $display("------------------------------------------------------------");
        $display("[RESULTS SUMMARY]");
        $display("  - Hardware Done Status Flag : %0d", done_val[0]);
        $display("  - Read Safety Result (0x38) : %0d", signed'(read_val));
        $display("------------------------------------------------------------");

        if (signed'(read_val) == 50) begin
            $display("[COMMERCIAL IP PASS] AXI-Lite Pipeline Verified Successfully.");
        end else begin
            $display("[FAIL] Unexpected safety result value: %0d", signed'(read_val));
        end
        $display("------------------------------------------------------------");
        $finish;
    end

endmodule