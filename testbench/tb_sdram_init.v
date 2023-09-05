`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2023/09/04 21:55:46
// Design Name: 
// Module Name: tb_sdram_init
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: testbench for sdram_init module
//////////////////////////////////////////////////////////////////////////////////
module tb_sdram_init(

    );
    reg          clk             ;
    wire         clk_100M        ;
    wire         clk_100M_shift  ;
    wire         clk_50M         ;
    wire         locked          ;
    reg          rst_n           ;
    
    //复位信号与锁定信号相与,表示真正有效的复位
    wire         locked_rst_n    ;
    
    
    wire [3:0]   init_cmd        ;
    wire [1:0]   init_bank_addr  ;
    wire         init_end        ;
    wire [12:0]  init_addr       ;
    
    //clk_gen模块的复位信号高电平有效
    assign reset = ~rst_n;
    
    //复位信号与锁定信号相与
    assign locked_rst_n = rst_n & locked;
    
    //系统时钟和复位
    initial begin
        clk = 1'b1;
        rst_n <= 1'b0;
    #20
        rst_n <= 1'b1;
    end
    
    always#10 clk = ~clk;
    
    
    //重定义sdram仿真模型参数
    defparam sdram_model_plus_init.addr_bits = 13;
    defparam sdram_model_plus_init.data_bits = 16;
    defparam sdram_model_plus_init.col_bits = 9;
    defparam sdram_model_plus_init.mem_sizes = 2*1024*1024;
    
    
    //时钟生成IP核
      clk_gen clk_gen_inst
   (
    // Clock out ports
    .clk_50M(clk_50M),     // output clk_50M
    .clk_100M(clk_100M),     // output clk_100M
    .clk_100M_shift(clk_100M_shift),     // output clk_100M_shift
    // Status and control signals
    .reset(reset), // input reset
    .locked(locked),       // output locked
   // Clock in ports
    .clk_in1(clk)  //50M时钟输入
    
    );      // input clk_in1
    
    
    sdram_init sdram_init_inst(
        .clk             (clk_100M      ),  //100MHz
        .rst_n           (locked_rst_n  ),
                          
        .init_cmd        (init_cmd      ),
        .init_bank_addr  (init_bank_addr),
        .init_end        (init_end      ),
        .init_addr       (init_addr     )
    );
    
    
    
    //sdram仿真模块
    sdram_model_plus sdram_model_plus_init
    (
        .Dq      (),  //初始化时没有数据交互,先不连接
        .Addr    (init_addr),  
        .Ba      (init_bank_addr), 
        .Clk     (clk_100M_shift),   //使用有相位偏移的时钟
        .Cke     (1'b1), 
        .Cs_n    (init_cmd[3]), 
        .Ras_n   (init_cmd[2]), 
        .Cas_n   (init_cmd[1]), 
        .We_n    (init_cmd[0]), 
        .Dqm     (2'b00),  //相当于不使用掩码
        .Debug   (1'b1)
    );
    
    
    
    
endmodule
