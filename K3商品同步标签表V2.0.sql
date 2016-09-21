--创建uploadGoodsflag表
if exists(select * from sysobjects where id = object_id(N'uploadGoodsflag') and OBJECTPROPERTY(id, N'IsUserTable') = 1)
drop table uploadGoodsflag
create table uploadGoodsflag
(
	id int IDENTITY(1,1) primary key NOT NULL,
	spinnerid int NOT NULL,
	spcode varchar(100) NULL,
	spname varchar(100) NULL,
	flag int not null,
	syncedflag int not null, --初始化获取易订货商品标记
)

ALTER table uploadGoodsflag ADD  DEFAULT (0) FOR spinnerid
go

ALTER table uploadGoodsflag ADD  DEFAULT ('') FOR spcode
go

ALTER table uploadGoodsflag ADD  DEFAULT ('') FOR spname
go

ALTER table uploadGoodsflag ADD  DEFAULT (0) FOR flag
go

ALTER table uploadGoodsflag ADD  DEFAULT (0) FOR syncedflag
go

delete from uploadGoodsflag
insert into uploadGoodsflag(spinnerid,spcode,spname,flag,syncedflag)
select FItemID ,FNumber, FName, 0, 0
from t_ICItemCore 
--where FNumber like '06.%'


--创建uploadGoods表
if exists(select * from sysobjects where id = object_id(N'uploadGoods') and OBJECTPROPERTY(id, N'IsUserTable') = 1)
drop table uploadGoods
create table uploadGoods
(
	id int  primary key NOT NULL,
	code varchar(100) not NULL,
	barcode varchar(100) not NULL,
	name varchar(100) NULL,
	productUnitName varchar(60) null,
	mulspec1Name varchar(60) NULL,
	mulspec1Value varchar(60) NULL,
	mulspec2Name varchar(60) NULL,
	mulspec2Value varchar(60) NULL,
	flag int not null
)
go


-------------商品表触发器--------------------

--创建insert插入类型触发器
if (object_id('tgr_t_ICItemCore_insertGoods', 'tr') is not null)
    drop trigger tgr_t_ICItemCore_insertGoods
go
create trigger tgr_t_ICItemCore_insertGoods
on t_ICItemCore
    for insert --插入触发
as
    --定义变量
    declare 
		@spinnerid int, 
		@spcode varchar(100),
		@spname varchar(100),
		@flag int ;
		
    --在inserted表中查询已经插入记录信息
    select @spinnerid = FItemID, @spcode = FNumber, @spname = FName  from inserted;
    set @flag = 0;    
    insert into uploadGoodsflag(spinnerid,spcode,spname,flag, syncedflag) 
    values(@spinnerid, @spcode, @spname, @flag, 0);
go

 
--update更新类型触发器
if (object_id('tgr_t_ICItemCore_updateGoods', 'TR') is not null)
    drop trigger tgr_t_ICItemCore_updateGoods
go
create trigger tgr_t_ICItemCore_updateGoods
on t_ICItemCore
    for update
as
    declare 
		@spinnerid int, 
		@spcode varchar(100),
		@spname varchar(100),
		--@hshsj decimal(14, 3),
		@mulspec1Value varchar(60),
		@unit varchar(10),
		@flag int ,
		@before_upload_flag int ,
		@before_upload_spcode varchar(100);
    --在inserted表中查询已经更新记录信息
    select @spinnerid = FItemID, @spcode = FNumber, @spname = FName, @mulspec1Value = case when FModel = '' then '无' else FModel end  from inserted;
    select @unit = u.FName from (
		select t1.FItemID, t1.FUnitID, t2.FMeasureUnitID, t2.FName 
		from t_ICItemBase t1 inner join t_MeasureUnit t2 on t1.FUnitID = t2.FMeasureUnitID 
		)u
    where u.FItemID = @spinnerid;
    select @before_upload_flag = flag,@before_upload_spcode = spcode from uploadGoodsflag where spinnerid = @spinnerid;
    set @flag = 1; 
    --判断商品修改前是否同步成功
    if(@before_upload_flag in (1, 2))	--同步成功修改
		--判断修改是'delete'还是'update'
		if exists(select 1 from t_ICItemCore where FItemID = @spinnerid and FDeleted = 1 )  --删除商品
			begin
				delete from uploadGoodsflag where spinnerid = @spinnerid;
				delete from uploadGoods where barcode = cast(@spinnerid as varchar(100));
				print '删除状态成功';
			end
		else if exists(select 1 from t_ICItemCore where  FNumber = @before_upload_spcode)  --修改商品基本信息
			begin  
				update uploadGoodsflag set spname = @spname, flag = @flag where spinnerid = @spinnerid;
				update uploadGoods set name = @spname, productUnitName = @unit, mulspec1Value = @mulspec1Value, flag = @flag where code = @spcode;
				print '修改商品基本信息状态成功' ;
			end
		else	 --修改商品编码
			begin  
				update uploadGoodsflag set spcode = @spcode, spname = @spname, flag = 0 where spinnerid = @spinnerid;
				update uploadGoods set code = @spcode, name = @spname, productUnitName = @unit, mulspec1Value = @mulspec1Value, flag = 0 where code = @spcode;
				print '修改商品编码状态成功' ;
			end
			
	else		--同步失败修改
		begin
			update uploadGoodsflag set spcode = @spcode, spname = @spname, flag = 0 where spinnerid = @spinnerid;
			print '商品未同步，修改后需要同步'
		end
go


-------------uploadGoods表触发器--------------------
/*
	处理初始化商品时barcode为空的情况
*/
--创建insert插入类型触发器
if (object_id('tgr_uploadGoods_insert', 'tr') is not null)
    drop trigger tgr_uploadGoods_insert
go
create trigger tgr_uploadGoods_insert
on uploadGoods
    for insert --插入触发
as
    --定义变量
    declare 
		@id int,
		@code varchar(60), 
		@barcode varchar(15),
		@name varchar(60);
		
    --在inserted表中查询已经插入记录信息
    select @id = id, @code = code, @barcode = barcode, @name = name from inserted;
    if (@barcode = '' or @barcode is null )
		begin
			select @barcode = Fnumber from t_ICItemCore where FNumber = @code  
			update uploadGoods set barcode = @barcode, flag = 1 where id = @id and code = @code
			update uploadGoodsflag set syncedflag = 1 where spcode = @code
			print 'barcode为空，syncedflag = 1'
		end
go


