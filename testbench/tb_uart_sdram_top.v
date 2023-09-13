`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Engineer: lauchinyuan
// Email: lauchinyuan@yeah.net
// Create Date: 2023/09/12 10:42:56
// Module Name: tb_uart_sdram_top
// Description: testbench for uart_sdram_top
//////////////////////////////////////////////////////////////////////////////////


module tb_uart_sdram_top(

    );
    //数据存储寄存器
    reg [7:0] data_mem[599:0];
    
    
    //中间连线
    reg        clk                  ;  //50MHz时钟
    reg        rst_n                ;
                                    
    //RS232串口                     
    reg         rx                  ;
    wire        tx                  ;
                                    
    //SDRAM写                       
    wire [23:0] sdram_wr_beg_addr   ; //SDRAM写起始地址
    wire [23:0] sdram_wr_end_addr   ; //SDRAM写起始地址
    wire [9:0]  wr_burst_len        ; //SDRAM写突发长度
                                    
    //SDRAM读                       
    wire [23:0] sdram_rd_beg_addr   ; //SDRAM读起始地址
    wire [23:0] sdram_rd_end_addr   ; //SDRAM读起始地址
    wire [9:0]  rd_burst_len        ; //SDRAM读突发长度 
    reg         sdram_rd_valid      ; //SDRAM读有效信号
                                    
                                    
    //SDRAM物理接口                 
    wire        sdram_clk           ;
    wire        cke                 ;  //SDRAM时钟使能  
    wire        sdram_cs_n          ;
    wire        sdram_ras_n         ;
    wire        sdram_cas_n         ;
    wire        sdram_we_n          ;
    wire [1:0]  sdram_ba            ;
    wire [12:0] sdram_addr          ;        
    wire [15:0] sdram_dq            ;  //读写SDRAM的数据总线
    wire [1:0]  sdram_dqm           ;
    
    
    
    //产生系统时钟、复位及SDRAM读有效信号
    initial begin
        clk = 1'b1;
        rst_n <= 1'b0;
    #20
        rst_n <= 1'b1;
    end
    
    //50MHz时钟
    always#10 clk = ~clk;
    
    //读写起始地址、突发长度
    assign sdram_wr_beg_addr = 24'd0    ;
    assign sdram_wr_end_addr = 24'd3    ;
    assign sdram_rd_beg_addr = 24'd0    ;
    assign sdram_rd_end_addr = 24'd3    ;
    assign wr_burst_len      = 10'd2    ;
    assign rd_burst_len      = 10'd2    ;    
    
    //模拟产生串口rx数据和SDRAM读有效信号
    initial begin
        rx <= 1'b1;  //rx空闲
        sdram_rd_valid <= 1'b0;
    #200
        rx_byte();
    #300000   //等待大约300us(SDRAM初始化至少占据200us时间),必须确保SDRAM中已经有被写入的数据了
        sdram_rd_valid <= 1'b1;  //数据已经写入完毕, 可以拉高读请求
    end
    
    
    //读取txt数据,保存到寄存器
    initial begin
        $readmemh("C:/Users/Lau Chinyuan/OneDrive - email.szu.edu.cn/FPGA_project/SDRAM/data/conv1.weight_int8.txt", data_mem);
    end
    
    
    //rx_byte任务,连续读取data_mem寄存器内的内容
    task rx_byte();
        integer j;
        for(j=0;j<4;j=j+1) begin
            rx_bit(data_mem[j]);  //调用rx_bit子任务
        end
    endtask
    
    
    //rx_bit
    //RS232bit生成任务,模仿RS232串口一个字符帧的时序
    task rx_bit(input [7:0] data);
        integer i;
        for(i=0;i<10;i=i+1) begin //每个rx数据帧有10bit数据流
            case(i) 
                0: rx <=  1'b0;   //起始位
                1: rx <=  data[0];
                2: rx <=  data[1];
                3: rx <=  data[2];
                4: rx <=  data[3];
                5: rx <=  data[4];
                6: rx <=  data[5];
                7: rx <=  data[6];
                8: rx <=  data[7];
                9: rx <= 1'b1;     //停止位
                default: rx <= 1'b0;
            endcase
        #(5207*20);  //数据每个bit之间的时间差
        end
    endtask
    
    
    
    //顶层仿真模块例化
    uart_sdram_top uart_sdram_top_inst(
        .clk                 (clk                 ),  //50MHz时钟
        .rst_n               (rst_n               ),

        //RS232串口
        .rx                  (rx                  ),
        .tx                  (tx                  ),
        
        //SDRAM写
        .sdram_wr_beg_addr   (sdram_wr_beg_addr   ), //SDRAM写起始地址
        .sdram_wr_end_addr   (sdram_wr_end_addr   ), //SDRAM写起始地址
        .wr_burst_len        (wr_burst_len        ), //SDRAM写突发长度

        //SDRAM读
        .sdram_rd_beg_addr   (sdram_rd_beg_addr   ), //SDRAM读起始地址
        .sdram_rd_end_addr   (sdram_rd_end_addr   ), //SDRAM读起始地址
        .rd_burst_len        (rd_burst_len        ), //SDRAM读突发长度 
        .sdram_rd_valid      (sdram_rd_valid      ), //SDRAM读有效信号
        

        //SDRAM物理接口
        .sdram_clk           (sdram_clk           ),
        .cke                 (cke                 ),  //SDRAM时钟使能  
        .sdram_cs_n          (sdram_cs_n          ),
        .sdram_ras_n         (sdram_ras_n         ),
        .sdram_cas_n         (sdram_cas_n         ),
        .sdram_we_n          (sdram_we_n          ),
        .sdram_ba            (sdram_ba            ),
        .sdram_addr          (sdram_addr          ),        
        .sdram_dq            (sdram_dq            ),  //读写SDRAM的数据总线  
        .sdram_dqm           (sdram_dqm           )
    );
    
    //重定义sdram仿真模型参数
    defparam sdram_model_plus_init.addr_bits = 13;
    defparam sdram_model_plus_init.data_bits = 16;
    defparam sdram_model_plus_init.col_bits = 9;
    defparam sdram_model_plus_init.mem_sizes = 2*1024*1024;    
    
    //sdram仿真模块
    sdram_model_plus sdram_model_plus_init
    (
        .Dq      (sdram_dq              ),  
        .Addr    (sdram_addr            ),  
        .Ba      (sdram_ba              ), 
        .Clk     (sdram_clk             ),   
        .Cke     (cke                   ), 
        .Cs_n    (sdram_cs_n            ), 
        .Ras_n   (sdram_ras_n           ), 
        .Cas_n   (sdram_cas_n           ), 
        .We_n    (sdram_we_n            ), 
        .Dqm     (sdram_dqm             ),  
        .Debug   (1'b1                  )
    );    
    
endmodule
