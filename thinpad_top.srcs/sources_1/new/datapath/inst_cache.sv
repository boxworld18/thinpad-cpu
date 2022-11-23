`timescale 1ns / 1ps
`default_nettype none
`include "../defines.svh"

/*
    * combinational logic
    * Instruction cache design
    * each set(56 bits) is as follows:
        * 31:0 - inst
        * 54:32 - tag
        * 55 - valid bit
    * 4-way set associative
    * so each cache line is 224 bits
    * FIFO replacement policy
 */


module inst_cache(
        input wire clk_i,
        input wire rst_i,
        input wire [`ADDR_WIDTH-1:0] addr_i,
        input wire [`DATA_WIDTH-1:0] inst_i,
        input wire is_add_i,
        output wire [`DATA_WIDTH-1:0] inst_o,
        output wire is_hit_o
    );

    // define the cache
    logic [`INST_CACHE_SIZE-1:0][`INST_CACHELINE_WIDTH-1:0] cache;
    logic [`INST_CACHELINE_WIDTH-1:0] cache_line;
    logic [`INST_CACHE_TAG_WIDTH-1:0] tag;
    logic [`INST_CACHE_INDEX_WIDTH-1:0] index;
    assign tag = addr_i[`ADDR_WIDTH-1:`INST_CACHE_INDEX_WIDTH+2];
    assign index = addr_i[`INST_CACHE_INDEX_WIDTH+1:2];
    assign cache_line = cache[index];

    logic valid0;
    logic valid1;
    logic valid2;
    logic valid3;
    assign valid0 = cache_line[224-1];
    assign valid1 = cache_line[168-1];
    assign valid2 = cache_line[112-1];
    assign valid3 = cache_line[56-1];

    always_comb begin
        // get 4 tags and valid bits
        logic [`INST_CACHE_TAG_WIDTH-1:0] tag0 = cache_line[223-1:200];
        logic [`INST_CACHE_TAG_WIDTH-1:0] tag1 = cache_line[167-1:144];
        logic [`INST_CACHE_TAG_WIDTH-1:0] tag2 = cache_line[111-1:88];
        logic [`INST_CACHE_TAG_WIDTH-1:0] tag3 = cache_line[55-1:32];

        // get the instruction
        logic [`DATA_WIDTH-1:0] inst0 = cache_line[200-1:168];
        logic [`DATA_WIDTH-1:0] inst1 = cache_line[144-1:112];
        logic [`DATA_WIDTH-1:0] inst2 = cache_line[88-1:56];
        logic [`DATA_WIDTH-1:0] inst3 = cache_line[32-1:0];

        // check for a hit
        logic hit0 = valid0 & (tag0 == tag);
        logic hit1 = valid1 & (tag1 == tag);
        logic hit2 = valid2 & (tag2 == tag);
        logic hit3 = valid3 & (tag3 == tag);

        // output the instruction
        if(hit0) begin
            inst_o = inst0;
            is_hit_o = 1'b1;
        end else if(hit1) begin
            inst_o = inst1;
            is_hit_o = 1'b1;
        end else if(hit2) begin
            inst_o = inst2;
            is_hit_o = 1'b1;
        end else if(hit3) begin
            inst_o = inst3;
            is_hit_o = 1'b1;
        end else begin
            inst_o = 32'b0;
            is_hit_o = 1'b0;
        end
    end

    always_ff @ (posedge clk_i) begin
        if (rst_i) begin
            cache <= 0;
        end else begin
            // add the instruction to the cache
            if(is_add_i) begin
                if(!valid0) begin
                    cache_line[224-1] <= 1'b1;
                    cache_line[223-1:200] <= tag;
                    cache_line[200-1:168] <= inst_i;
                end else if(!valid1) begin
                    cache_line[168-1:0] <= 1'b1;
                    cache_line[167-1:144] <= tag;
                    cache_line[144-1:112] <= inst_i;
                end else if(!valid2) begin
                    cache_line[112-1:0] <= 1'b1;
                    cache_line[111-1:88] <= tag;
                    cache_line[88-1:56] <= inst_i;
                end else if(!valid3) begin
                    cache_line[56-1:0] <= 1'b1;
                    cache_line[55-1:32] <= tag;
                    cache_line[32-1:0] <= inst_i;
                end else begin
                    cache_line[224-1:0] <= {cache_line[168-1:0], 1'b1, tag, inst_i};
                end
            end
        end
    end
    
endmodule
