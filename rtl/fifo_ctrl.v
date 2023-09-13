`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Engineer: lauchinyuan
// Email:lauchinyuan@yeah.net
// Create Date: 2023/09/08 15:06:31
// Module Name: fifo_ctrl
// Description: SDRAM的读写FIFO控制模块,实现SDRAM的跨时钟域读写,内含读FIFO和写FIFO
// 主要职能是生成SDRAM读写请求信号以及读写地址,而SDRAM读写数据则从FIFO中获取(通过异步FIFO读写使能信号)
// 数据流:
// 向SDRAM写数据时: 待写入数据 --> 写FIFO      --> SDRAM控制器 --> SDRAM
// 从SDRAM读数据时: SDRAM      --> SDRAM控制器 --> 读FIFO      --> 读得数据
//////////////////////////////////////////////////////////////////////////////////


module fifo_ctrl(
        input   wire         clk                 ,
        input   wire         rst_n               ,
        //fifo_write模块        
        input   wire         wr_rst              ,  //写复位
        input   wire         fifo_wr_clk         ,
        input   wire         fifo_wr_req         ,
        input   wire [15:0]  fifo_wr_data        ,
        input   wire [23:0]  sdram_wr_beg_addr   ,  //写SDRAM的起始地址
        input   wire [23:0]  sdram_wr_end_addr   ,  //终止地址
        input   wire [9:0]   wr_burst_len        ,  
        input   wire         sdram_wr_ack        ,  //sdram_ctrl模块发出的写响应信号
        output  reg          sdram_wr_req        ,  //向SDRAM控制器发送写SDRAM请求
        output  reg  [23:0]  sdram_wr_addr       ,  //发送到SDRAM控制模块
        output  wire [15:0]  sdram_wr_data       ,  //发送到SDRAM控制模块
        output  wire         fifo_wr_rst_busy    ,  //写FIFO复位忙碌信号,只有当该信号为低电平,写FIFO才能进行写入
        //fifo_read模块      
        input   wire         rd_rst              ,
        input   wire         fifo_rd_clk         ,
        input   wire         fifo_rd_req         ,
        output  wire [15:0]  fifo_rd_data        ,  //从FIFO中读取的数据,向外界输出
        input   wire [23:0]  sdram_rd_beg_addr   ,  //写SDRAM的起始地址
        input   wire [23:0]  sdram_rd_end_addr   ,  //终止地址
        input   wire [9:0]   rd_burst_len        , 
        input   wire         sdram_rd_valid      ,  //SDRAM读有效信号,该信号为高电平时才能进行读SDRAM操作
        input   wire         sdram_rd_ack        ,  //sdram_ctrl模块发出的读响应信号        
        output  reg          sdram_rd_req        ,  //向SDRAM控制器发送读SDRAM请求
        output  reg  [23:0]  sdram_rd_addr       ,
        input   wire [15:0]  sdram_rd_data       ,
        output  wire  [9:0]  rd_fifo_cnt            //读FIFO数据个数
    );
    
    parameter FIFO_CNT_DELAY = 4'd9;  //FIFO数据个数计数器的更新延时周期
    
    //中间连线
    wire [9:0]  rd_fifo_data_cnt    ; //读FIFO的数据个数
    wire [9:0]  wr_fifo_data_cnt    ; //写FIFO的数据个数
    
    //辅助地址更新的变量
    reg         sdram_wr_ack_d1     ; //sdram_wr_ack打一拍  
    wire        sdram_wr_ack_fall   ; //sdram_wr_ack下降沿,用作判断写SDRAM地址是否超限的依据
    
    reg         sdram_rd_ack_d1     ; //sdram_rd_ack打一拍  
    wire        sdram_rd_ack_fall   ; //sdram_rd_ack下降沿,用作判断读SDRAM地址是否超限的依据 
    
    //辅助写请求信号产生的中间变量
    wire        sdram_wr_req_disable; //写FIFO数量计数器有延时,在正真的fifo数据个数出现之前,SDRAM写请求无效
    reg [3:0]   cnt_wr_req_disable  ; //等待写FIFO数量计数器更新的周期计数器
    wire        sdram_wr_req_wait   ; //写请求等待标志
    wire        sdram_rd_req_disable; //写FIFO数量计数器有延时,在正真的fifo数据个数出现之前,SDRAM读请求无效
    

    //sdram_wr_ack_d1
    always@(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            sdram_wr_ack_d1 <= 1'b0;
        end else begin
            sdram_wr_ack_d1 <= sdram_wr_ack;
        end 
    end
    
    //sdram_rd_ack_d1
    always@(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            sdram_rd_ack_d1 <= 1'b0;
        end else begin
            sdram_rd_ack_d1 <= sdram_rd_ack;
        end 
    end
    
    //sdram_wr_ack_fall
    assign sdram_wr_ack_fall = (sdram_wr_ack == 1'b0 && sdram_wr_ack_d1 == 1'b1)?1'b1:1'b0;

    //sdram_rd_ack_fall
    assign sdram_rd_ack_fall = (sdram_rd_ack == 1'b0 && sdram_rd_ack_d1 == 1'b1)?1'b1:1'b0;
    
    //cnt_wr_req_disable
    always@(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            cnt_wr_req_disable <= 4'd0;
        end else if(sdram_wr_ack_fall) begin //SDRAM写操作(写FIFO读操作)完成, 开始等待FIFO数据个数计数器更新
            cnt_wr_req_disable <= 4'd1;
        end else if(cnt_wr_req_disable == FIFO_CNT_DELAY - 4'd1) begin //最大值
            cnt_wr_req_disable <= 4'd0;
        end else if(cnt_wr_req_disable > 4'd0) begin
            cnt_wr_req_disable <= cnt_wr_req_disable + 4'd1;
        end else begin
            cnt_wr_req_disable <= cnt_wr_req_disable;
        end
    end
    
    //sdram_wr_req_wait
    assign sdram_wr_req_wait = (cnt_wr_req_disable > 4'd0)?1'b1:1'b0;
    
    //sdram_wr_req_disable
    assign sdram_wr_req_disable = sdram_wr_req_wait | sdram_wr_ack | sdram_wr_ack_d1;  //等待FIFO更新数据个数、写响应过程中都使得写请求无效
    
    //sdram_rd_req_disable
    assign sdram_rd_req_disable = sdram_rd_ack | sdram_rd_ack_d1; //读FIFO读计数端口延时1个周期
    
    //SDRAM读写地址
    //sdram_wr_addr
    always@(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            sdram_wr_addr <= 24'b0;
        end else if(wr_rst) begin
            sdram_wr_addr <= sdram_wr_beg_addr;  //初始化为起始地址
        end else if(sdram_wr_ack_fall && (sdram_wr_addr + wr_burst_len - 24'd1) > sdram_wr_end_addr) begin  
        //在sdram_wr_ack下降沿判断下次写操作将到达写地址上限
            sdram_wr_addr <= sdram_wr_beg_addr;  
        end else if(sdram_wr_ack) begin  //向SDRAM写了数据, 需要更新写地址
            sdram_wr_addr <= sdram_wr_addr + 24'd1;
        end else begin
            sdram_wr_addr <= sdram_wr_addr;
        end
    end 
    
    //sdram_rd_addr
    always@(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            sdram_rd_addr <= 24'b0;
        end else if(wr_rst) begin
            sdram_rd_addr <= sdram_rd_beg_addr;  //初始化为起始地址
        end else if(sdram_rd_ack_fall && (sdram_rd_addr + rd_burst_len - 24'd1) > sdram_rd_end_addr) begin   
        //在sdram_rd_ack下降沿判断下次读操作将到达读地址上限
            sdram_rd_addr <= sdram_rd_beg_addr;
        end else if(sdram_rd_ack) begin  //从SDRAM读取了数据, 需要更新读地址
            sdram_rd_addr <= sdram_rd_addr + 24'd1;
        end else begin
            sdram_rd_addr <= sdram_rd_addr;
        end
    end 
    
    //SDRAM读写请求
    //写FIFO存储数据个数达到wr_burst_len,发送写SDRAM请求
    //读FIFO存储个数小于rd_burst_len,且sdram_rd_valid有效,则发送读SDRAM请求
    always@(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            sdram_wr_req <= 1'b0;
            sdram_rd_req <= 1'b0;           
        end else if(sdram_wr_req_disable) begin  //收到写请求失效信号,将写请求拉低
            sdram_wr_req <= 1'b0;
            sdram_rd_req <= 1'b0;
        end else if(wr_fifo_data_cnt >= wr_burst_len) begin  
        //写FIFO数据满足wr_burst_len,且当前写请求有效,发起写请求
            sdram_wr_req <= 1'b1;
            sdram_rd_req <= 1'b0; 
        end else if(sdram_rd_req_disable) begin //读请求无效信号, 将读请求拉低
            sdram_wr_req <= 1'b0;
            sdram_rd_req <= 1'b0;  
        end else if(sdram_rd_valid && rd_fifo_data_cnt < rd_burst_len) begin  //读FIFO数据小于rd_burst_len,拉高读请求
        //为了防止在SDRAM没有写入时就先读取,故需要外部传入的sdram_rd_valid信号来控制读操作
            sdram_wr_req <= 1'b0;
            sdram_rd_req <= 1'b1;            
        end else begin
            sdram_wr_req <= sdram_wr_req;
            sdram_rd_req <= sdram_rd_req;         
        end
    end
    
    
    
    
    //写FIFO
    fifo wr_fifo (
        //User end
        .rst            (wr_rst | (~rst_n)  ),  
        .wr_clk         (fifo_wr_clk        ),  
        .din            (fifo_wr_data       ),  
        .wr_en          (fifo_wr_req        ),  
            
        //SDRAM end 
        .rd_clk         (clk                ),  
        .rd_en          (sdram_wr_ack       ),  
        .dout           (sdram_wr_data      ),  
 
        
        //计数端口
        .wr_data_count  (wr_fifo_data_cnt   ), 

        //初始化忙碌标志
        .wr_rst_busy    (fifo_wr_rst_busy   ),  
        
        //未使用
        .rd_data_count  (), 
        .empty          (),  

        .rd_rst_busy    (),   
        .full           () 
    );


    //读FIFO
    fifo rd_fifo (
        //User end
        .rst            (rd_rst | (~rst_n)  ),   
        .rd_clk         (fifo_rd_clk        ),  
        .dout           (fifo_rd_data       ),
        .rd_en          (fifo_rd_req        ),          
    
            
        //SDRAM end 
        .wr_clk         (clk                ),          
        .din            (sdram_rd_data      ),   
        .wr_en          (sdram_rd_ack       ),   
            
        //计数端口  
        .wr_data_count  (),  
        
        //未使用
        .rd_data_count  (rd_fifo_data_cnt   ),  
        .empty          (),   
        .wr_rst_busy    (),   
        .rd_rst_busy    (),
        .full           ()           
    );
    
    //读FIFO数据个数输出,作为外部使用
    assign rd_fifo_cnt = rd_fifo_data_cnt;
endmodule
