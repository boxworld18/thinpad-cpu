`timescale 1ns / 1ps
`default_nettype none
`include "../defines.svh"

/*
    * Data cache design
    * each set(56 bits) is as follows:
        * 31:0 - data
        * 54:32 - tag
        * 55 - valid bit
    * 4-way set associative
    * so each cache line is 224 bits
    * FIFO replacement policy
*/


module data_cache(
        input wire clk_i,
        input wire rst_i,
        input wire [`ADDR_WIDTH-1:0] addr_i,
        input wire [`DATA_WIDTH-1:0] data_i,
        input wire is_add_i,
        output reg [`DATA_WIDTH-1:0] data_o,
        output reg is_hit_o
    );

    logic [`DATA_CACHE_SIZE-1:0][`DATA_CACHELINE_WIDTH-1:0] cache;
    logic [`DATA_CACHELINE_WIDTH-1:0] cache_line;
    logic [`DATA_CACHE_TAG_WIDTH-1:0] tag;
    logic [`DATA_CACHE_INDEX_WIDTH-1:0] index;
    assign tag = addr_i[`ADDR_WIDTH-1:`DATA_CACHE_INDEX_WIDTH+2];
    assign index = addr_i[`DATA_CACHE_INDEX_WIDTH+1:2];
    assign cache_line = cache[index];

    logic valid0;
    logic valid1;
    logic valid2;
    logic valid3;
    assign valid0 = cache_line[224-1];
    assign valid1 = cache_line[168-1];
    assign valid2 = cache_line[112-1];
    assign valid3 = cache_line[56-1];
    
    logic [`DATA_CACHE_TAG_WIDTH-1:0] tag0;
    assign tag0 = cache_line[223-1:200];
    logic [`DATA_CACHE_TAG_WIDTH-1:0] tag1;
    assign tag1 = cache_line[167-1:144];
    logic [`DATA_CACHE_TAG_WIDTH-1:0] tag2;
    assign tag2 = cache_line[111-1:88];
    logic [`DATA_CACHE_TAG_WIDTH-1:0] tag3;
    assign tag3 = cache_line[55-1:32];

    logic [`DATA_WIDTH-1:0] data0;
    assign data0 = cache_line[200-1:168];
    logic [`DATA_WIDTH-1:0] data1;
    assign data1 = cache_line[144-1:112];
    logic [`DATA_WIDTH-1:0] data2;
    assign data2 = cache_line[88-1:56];
    logic [`DATA_WIDTH-1:0] data3;
    assign data3 = cache_line[32-1:0];

    logic hit0;
    assign hit0 = valid0 & (tag0 == tag);
    logic hit1;
    assign hit1 = valid1 & (tag1 == tag);
    logic hit2;
    assign hit2 = valid2 & (tag2 == tag);
    logic hit3;
    assign hit3 = valid3 & (tag3 == tag);

    always_comb begin
        // output the data
        if(hit0) begin
            data_o = data0;
            is_hit_o = 1'b1;
        end else if(hit1) begin
            data_o = data1;
            is_hit_o = 1'b1;
        end else if(hit2) begin
            data_o = data2;
            is_hit_o = 1'b1;
        end else if(hit3) begin
            data_o = data3;
            is_hit_o = 1'b1;
        end else begin
            data_o = 32'b0;
            is_hit_o = 1'b0;
        end
    end

    always_ff @ (posedge clk_i) begin
        if (rst_i) begin
            cache <= 0;
        end else begin
            // add the data to the cache
            if(is_add_i) begin
                if(!valid0) begin
                    cache[index][224-1] <= 1'b1;
                    cache[index][223-1:200] <= tag;
                    cache[index][200-1:168] <= data_i;
                end else if(!valid1) begin
                    cache[index][168-1:0] <= 1'b1;
                    cache[index][167-1:144] <= tag;
                    cache[index][144-1:112] <= data_i;
                end else if(!valid2) begin
                    cache[index][112-1:0] <= 1'b1;
                    cache[index][111-1:88] <= tag;
                    cache[index][88-1:56] <= data_i;
                end else if(!valid3) begin
                    cache[index][56-1:0] <= 1'b1;
                    cache[index][55-1:32] <= tag;
                    cache[index][32-1:0] <= data_i;
                end else begin
                    cache[index][224-1:0] <= {cache[index][168-1:0], 1'b1, tag, data_i};
                end
            end
        end
    end

endmodule
