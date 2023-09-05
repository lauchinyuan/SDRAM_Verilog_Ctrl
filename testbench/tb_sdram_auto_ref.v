`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Engineer: lauchinyuan
// Email: lauchinyuan@yeah.net
// Create Date: 2023/09/05 16:55:39
// Module Name: tb_sdram_auto_ref
// Description: testbench for sdram_auto_ref module
//////////////////////////////////////////////////////////////////////////////////


module tb_sdram_auto_ref(

    );
    
    reg          clk             ;
    wire         clk_100M        ;
    wire         clk_100M_shift  ;
    wire         clk_50M         ;
    wire         locked          ;
    reg          rst_n           ;
    
    //复位信号与锁定信号相与,表示真正有效的复位
    wire         locked_rst_n    ;
    reg          aref_en         ;
    
    //自动刷新模块输出
    wire         aref_req        ;
    wire [3:0]   aref_cmd        ;
    wire [12:0]  aref_addr       ;
    wire [1:0]   aref_bank_addr  ;
    wire         aref_end        ;
    
    //初始化模块输出
    wire [3:0]   init_cmd        ;
    wire [12:0]  init_addr       ;
    wire [1:0]   init_bank_addr  ;
    wire         init_end        ;   
    
    //输入到SDRAM仿真模型的信号
    wire [3:0]   sdram_cmd        ;
    wire [12:0]  sdram_addr       ;
    wire [1:0]   sdram_bank_addr  ;
    
    //重定义sdram仿真模型参数
    defparam sdram_model_plus_init.addr_bits = 13;
    defparam sdram_model_plus_init.data_bits = 16;
    defparam sdram_model_plus_init.col_bits = 9;
    defparam sdram_model_plus_init.mem_sizes = 2*1024*1024;
    
    //选择输入到SDRAM仿真模型的数据源
    assign  sdram_cmd       = (init_end)? aref_cmd      : init_cmd      ;
    assign  sdram_addr      = (init_end)? aref_addr     : init_addr     ;
    assign  sdram_bank_addr = (init_end)? aref_bank_addr: init_bank_addr;
    
    
    //复位信号与锁定信号相与
    assign locked_rst_n = rst_n & locked;
    assign reset = ~rst_n;
    
    initial begin
        clk = 1'b1;
        rst_n <= 1'b0;
    #20
        rst_n <= 1'b1;
    end
    
    always#10 clk = ~clk;
    
    
   //时钟生成IP核
   clk_gen clk_gen_inst
   (
        // Clock out ports
        .clk_50M(clk_50M),                  // output clk_50M
        .clk_100M(clk_100M),                // output clk_100M
        .clk_100M_shift(clk_100M_shift),    // output clk_100M_shift
        
        // Status and control signals
        .reset(reset),                      // input reset
        .locked(locked),                    // output locked
        // Clock in ports
        .clk_in1(clk)  //50M时钟输入
    
    ); 
    
    //aref_en
    //相当于起到仲裁模块的作用
    always@(posedge clk_100M or negedge locked_rst_n) begin
        if(!locked_rst_n) begin
            aref_en <= 1'b0;
        end else if(init_end && aref_req) begin
            aref_en <= 1'b1;
        end else if(aref_end) begin
            aref_en <= 1'b0;
        end else begin
            aref_en <= aref_en;
        end
    end
    
    
    //自动刷新模块
    sdram_auto_ref sdram_auto_ref_inst(
        .clk             (clk_100M      ),
        .rst_n           (locked_rst_n  ),
        .init_end        (init_end      ),   //初始化结束标志
        .aref_en         (aref_en       ),   //仲裁模块判定可以进行自动刷新

        .aref_req        (aref_req      ),   //输出到仲裁模块的刷新请求
        .aref_cmd        (aref_cmd      ),   //输出命令
        .aref_addr       (aref_addr     ),   //地址总线
        .aref_bank_addr  (aref_bank_addr),   //bank 地址
        .aref_end        (aref_end      )    //自动刷新完成标志
    );
    
    
    //初始化模块
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
        .Addr    (sdram_addr),  
        .Ba      (sdram_bank_addr), 
        .Clk     (clk_100M_shift),   //使用有相位偏移的时钟
        .Cke     (1'b1), 
        .Cs_n    (sdram_cmd[3]), 
        .Ras_n   (sdram_cmd[2]), 
        .Cas_n   (sdram_cmd[1]), 
        .We_n    (sdram_cmd[0]), 
        .Dqm     (2'b00),  //相当于不使用掩码
        .Debug   (1'b1)
    );
endmodule
