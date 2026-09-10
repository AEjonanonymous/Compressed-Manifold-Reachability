/**
 * @file cmr_axi_pipeline.sv
 * @brief Compressed Manifold Reachability (CMR) AXI-Lite Hardware Pipeline
 * @author Jonathan f(n) Reed
 * @orcid 0009-0008-7345-1407
 * @license GNU Affero General Public License v3.0 (AGPL-3.0)
 */

module cmr_axi_pipeline #(
    parameter int WIDTH = 32,
    parameter int R = 4,
    parameter int D = 6
)(
    input  logic         s_axi_aclk,
    input  logic         s_axi_aresetn,
    
    // AXI-Lite Write Address Channel
    input  logic [7:0]   s_axi_awaddr,
    input  logic         s_axi_awvalid,
    output logic         s_axi_awready,
    
    // AXI-Lite Write Data Channel
    input  logic [WIDTH-1:0] s_axi_wdata,
    input  logic [3:0]       s_axi_wstrb,
    input  logic         s_axi_wvalid,
    output logic         s_axi_wready,
    
    // AXI-Lite Write Response Channel
    output logic [1:0]   s_axi_bresp,
    output logic         s_axi_bvalid,
    input  logic         s_axi_bready,
    
    // AXI-Lite Read Address Channel
    input  logic [7:0]   s_axi_araddr,
    input  logic         s_axi_arvalid,
    output logic         s_axi_arready,
    
    // AXI-Lite Read Data Channel
    output logic [WIDTH-1:0] s_axi_rdata,
    output logic [1:0]   s_axi_rresp,
    output logic         s_axi_rvalid,
    input  logic         s_axi_rready
);

    // Internal registers mapped to AXI-Lite
    logic start_reg;
    logic [WIDTH-1:0] dt_reg;
    logic [WIDTH-1:0] local_v_regs [D-1:0];
    logic [WIDTH-1:0] hamiltonian_regs [D-1:0];
    
    logic signed [WIDTH-1:0] safety_result;
    logic done;
    logic start_pulse;

    // Working FSM computation core
    typedef enum logic [1:0] {IDLE, COMPUTE, DONE_ST} state_t;
    state_t state;
    logic signed [WIDTH-1:0] max_synthesis;
    integer i;

    always_ff @(posedge s_axi_aclk or negedge s_axi_aresetn) begin
        if (!s_axi_aresetn) begin
            state <= IDLE;
            safety_result <= '0;
            done <= 1'b0;
            start_pulse <= 1'b0;
        end else begin
            start_pulse <= start_reg;
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start_pulse) begin
                        state <= COMPUTE;
                    end
                end
                COMPUTE: begin
                    max_synthesis = local_v_regs[0] - (dt_reg * hamiltonian_regs[0]);
                    for (i = 1; i < D; i++) begin
                        if ((local_v_regs[i] - (dt_reg * hamiltonian_regs[i])) > max_synthesis) begin
                            max_synthesis = local_v_regs[i] - (dt_reg * hamiltonian_regs[i]);
                        end
                    end
                    safety_result <= max_synthesis;
                    done <= 1'b1;
                    state <= DONE_ST;
                end
                DONE_ST: begin
                    done <= 1'b0;
                    state <= IDLE;
                end
                default: state <= IDLE;
            endcase
        end
    end

    // AXI-Lite Register Interface Logic
    assign s_axi_awready = 1'b1;
    assign s_axi_wready  = 1'b1;
    assign s_axi_bresp   = 2'b00; 
    assign s_axi_arready = 1'b1;
    assign s_axi_rresp   = 2'b00; 

    always_ff @(posedge s_axi_aclk or negedge s_axi_aresetn) begin
        if (!s_axi_aresetn) begin
            start_reg <= 1'b0;
            dt_reg <= 32'sd5;
            for (int k = 0; k < D; k++) begin
                local_v_regs[k] <= '0;
                hamiltonian_regs[k] <= '0;
            end
        end else if (s_axi_awvalid && s_axi_wvalid) begin
            case (s_axi_awaddr)
                8'h00: start_reg <= s_axi_wdata[0];
                8'h04: dt_reg <= s_axi_wdata;
                8'h08: local_v_regs[0] <= s_axi_wdata;
                8'h0C: local_v_regs[1] <= s_axi_wdata;
                8'h10: local_v_regs[2] <= s_axi_wdata;
                8'h14: local_v_regs[3] <= s_axi_wdata;
                8'h18: local_v_regs[4] <= s_axi_wdata;
                8'h1C: local_v_regs[5] <= s_axi_wdata;
                8'h20: hamiltonian_regs[0] <= s_axi_wdata;
                8'h24: hamiltonian_regs[1] <= s_axi_wdata;
                8'h28: hamiltonian_regs[2] <= s_axi_wdata;
                8'h2C: hamiltonian_regs[3] <= s_axi_wdata;
                8'h30: hamiltonian_regs[4] <= s_axi_wdata;
                8'h34: hamiltonian_regs[5] <= s_axi_wdata;
                default: ;
            endcase
        end
    end

    always_comb begin
        s_axi_rdata = '0;
        case (s_axi_araddr)
            8'h00: s_axi_rdata = {31'b0, start_reg};
            8'h38: s_axi_rdata = safety_result;
            8'h3C: s_axi_rdata = {31'b0, done};
            default: s_axi_rdata = '0;
        endcase
        s_axi_rvalid = s_axi_arvalid;
    end

    always_ff @(posedge s_axi_aclk) begin
        s_axi_bvalid <= s_axi_awvalid && s_axi_wvalid && !s_axi_bvalid;
    end

endmodule