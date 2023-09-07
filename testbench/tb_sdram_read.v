`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Engineer: lauchinyuan
// Email: lauchinyuan@yeah.net
// Create Date: 2023/09/06 22:13:41
// Module Name: tb_sdram_read
// Description: testbench for sdram_read module
//////////////////////////////////////////////////////////////////////////////////


module tb_sdram_read(

    );

    reg          clk             ;
    wire         clk_100M        ;
    wire         clk_100M_shift  ;
    wire         clk_50M         ;
    wire         locked          ;
    reg          rst_n           ;
    
    //复位信号与锁定信号相与,表示真正有效的复位
    wire         locked_rst_n    ;
    
    // init模块输出
    wire [3:0]   init_cmd        ;
    wire [1:0]   init_bank_addr  ;
    wire         init_end        ;
    wire [12:0]  init_addr       ;

    //SDRAM地址、控制线
    wire [3:0]   sdram_cmd        ;
    wire [1:0]   sdram_bank_addr  ;
    wire [12:0]  sdram_addr       ; 
    //SDRAM数据线
    wire [15:0]  sdram_dq         ;

    //write模块输入
    reg        wr_en              ;   
    reg [15:0] wr_data            ;  
    
    
    //write模块输出
    wire [3:0]   wr_cmd           ;
    wire [1:0]   wr_bank_addr     ;
    wire [12:0]  wr_sdram_addr    ;
    wire [15:0]  wr_sdram_data    ;
    wire         wr_end           ;
    wire         wr_ack           ;
    wire         wr_sdram_en      ;

    //sdram_read模块输入
    reg          rd_en            ;
    
    //sdram_read模块输出
    wire         rd_ack           ;
    wire [3:0]   rd_cmd           ;
    wire [1:0]   rd_bank_addr     ;
    wire [12:0]  rd_sdram_addr    ;
    wire         rd_end           ;
    wire [15:0]  rd_data          ;
    
    
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

    //数据总线, 需要写入操作时为写入数据,其余情况下拉高
    assign sdram_dq = (wr_sdram_en)? wr_sdram_data: 16'hzzzz;
    
    //地址、命令总线仲裁
    assign sdram_cmd        = (init_end)?((rd_en)?rd_cmd        :    wr_cmd          ):init_cmd      ;    
    assign sdram_bank_addr  = (init_end)?((rd_en)?rd_bank_addr  :    wr_bank_addr    ):init_bank_addr;     
    assign sdram_addr       = (init_end)?((rd_en)?rd_sdram_addr :    wr_sdram_addr   ):init_addr     ;
    
    
    
    
    //wr_data, 写入数据产生器, 起到系统中FIFO的作用
    always@(posedge clk_100M or negedge locked_rst_n) begin
        if(!locked_rst_n) begin
            wr_data <= 16'b0;
        end else if(wr_end) begin
            wr_data <= 16'b0;
        end else if(wr_ack) begin
            wr_data <= wr_data + 16'd1;
        end else begin
            wr_data <= wr_data;
        end
    end
    
    //wr_en
    always@(posedge clk_100M or negedge locked_rst_n) begin
        if(!locked_rst_n) begin
            wr_en <= 1'b0;
        end else if(wr_end) begin
            wr_en <= 1'b0;
        end else if(rd_en) begin //在读使能时,表示当前进行读操作,防止读写冲突, 不拉高写使能
            wr_en <= 1'b0;
        end else if(init_end) begin  //仿真时暂时设置为init完成后进行写, 实际上需要仲裁模块决定
            wr_en <= 1'b1;
        end else begin
            wr_en <= wr_en;
        end
    end
    
    //rd_en
    always@(posedge clk_100M or negedge locked_rst_n) begin
        if(!locked_rst_n) begin
            rd_en <= 1'b0;
        end else if(rd_end) begin //读完成后拉低读使能
            rd_en <= 1'b0;
        end else if(wr_end) begin //写完成之后拉高读使能信号
            rd_en <= 1'b1;
        end else begin
            rd_en <= rd_en;
        end
    end
    
    //潜伏期重配置, CAS要保持一致
    defparam sdram_init_inst.CAS = 3'b010;
    defparam sdram_read_inst.CAS = 3'b010;
    
    //时钟生成IP核
      clk_gen clk_gen_inst
   (
        // Clock out ports
        .clk_50M(clk_50M),     
        .clk_100M(clk_100M),     
        .clk_100M_shift(clk_100M_shift),    
        // Status and control signals
        .reset(reset), 
        .locked(locked),       
        // Clock in ports
        .clk_in1(clk)  //50M时钟输入
    
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
        .Dq      (sdram_dq          ),  
        .Addr    (sdram_addr        ),  
        .Ba      (sdram_bank_addr   ), 
        .Clk     (clk_100M_shift    ),   //使用有相位偏移的时钟
        .Cke     (1'b1              ), 
        .Cs_n    (sdram_cmd[3]      ), 
        .Ras_n   (sdram_cmd[2]      ), 
        .Cas_n   (sdram_cmd[1]      ), 
        .We_n    (sdram_cmd[0]      ), 
        .Dqm     (2'b00             ),  //相当于不使用掩码
        .Debug   (1'b1              )
    );        
    
    //sdram写模块
    sdram_write sdram_write_inst(
        .clk             (clk_100M        ),
        .rst_n           (locked_rst_n    ),
        .wr_en           (wr_en           ),
        .wr_addr         (24'h000_000     ),  //2bit Bank_addr + 13bit Row_addr + 9bit Column_addr
        .wr_data         (wr_data         ),
        .wr_burst_len    (10'd2          ),  //使用full-page突发传输

        .wr_cmd          (wr_cmd          ),
        .wr_bank_addr    (wr_bank_addr    ),
        .wr_sdram_addr   (wr_sdram_addr   ),
        .wr_sdram_data   (wr_sdram_data   ),
        .wr_end          (wr_end          ),
        .wr_ack          (wr_ack          ),
        .wr_sdram_en     (wr_sdram_en     )
    );    
    
    //sdram读模块
    sdram_read sdram_read_inst(
        .clk             (clk_100M        ),
        .rst_n           (locked_rst_n    ),
        .rd_addr         (24'h000_000     ), //与写模块的地址保持一致
        .rd_sdram_data   (sdram_dq        ),
        .rd_burst_len    (10'd2          ),
        .rd_en           (rd_en           ),
                          
        .rd_ack          (rd_ack          ),
        .rd_cmd          (rd_cmd          ),
        .rd_bank_addr    (rd_bank_addr    ),
        .rd_sdram_addr   (rd_sdram_addr   ),
        .rd_end          (rd_end          ),
        .rd_data         (rd_data         )
    );
endmodule
