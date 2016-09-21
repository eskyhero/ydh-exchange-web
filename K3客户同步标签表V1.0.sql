--创建uploadCustflag表
if exists(select * from sysobjects where id = object_id(N'uploadCustflag') and OBJECTPROPERTY(id, N'IsUserTable') = 1)
drop table uploadCustflag
create table uploadCustflag
(
	id int IDENTITY(1,1) primary key NOT NULL,
	custid int not null,
	custcode varchar(100) NOT NULL,
	custname varchar(100) NULL,
	flag int not null
)

ALTER table uploadCustflag ADD  DEFAULT (0) FOR custid
go

ALTER table uploadCustflag ADD  DEFAULT ('') FOR custcode
go

ALTER table uploadCustflag ADD  DEFAULT ('') FOR custname
go

ALTER table uploadCustflag ADD  DEFAULT (0) FOR flag
go


delete from uploadCustflag
insert into uploadCustflag(custid,custcode,custname,flag)
select FItemID ,FNumber, FName, 0
from T_Organization 
--where FDeleted = 0


--创建uploadCust表
if exists(select * from sysobjects where id = object_id(N'uploadCust') and OBJECTPROPERTY(id, N'IsUserTable') = 1)
drop table uploadCust
create table uploadCust
(
	custid int primary key NOT NULL,
	custcode varchar(100) not NULL,
	custname varchar(100) NULL,
	custaddress varchar(100) null,
	linkername varchar(50) NULL,
	phone varchar(50) NULL,
	email varchar(50) NULL
)
go


-------------商品表T_Organization触发器--------------------

--创建insert插入类型触发器
if (object_id('tgr_T_Organization_insertCust', 'tr') is not null)
    drop trigger tgr_T_Organization_insertCust
go
create trigger tgr_T_Organization_insertCust
on T_Organization
    for insert --插入触发
as
    --定义变量
    declare 
		@custid int, 
		@custcode varchar(100),
		@custname varchar(100),
		@flag int ;
		
    --在inserted表中查询已经插入记录信息
    select @custid = FItemID, @custcode = FNumber, @custname = FName  from inserted;
    set @flag = 0;    
    insert into uploadCustflag(custid,custcode,custname,flag) 
    values(@custid, @custcode, @custname, @flag);
go

 
--update更新类型触发器
if (object_id('tgr_T_Organization_updateCust', 'TR') is not null)
    drop trigger tgr_T_Organization_updateCust
go
create trigger tgr_T_Organization_updateCust
on T_Organization
    for update
as
    declare 
		@custid int, 
		@custcode varchar(100),
		@custname varchar(100),
		@custaddress varchar(100),
		@linkername varchar(50),
		@phone varchar(50),
		@email varchar(50),
		@flag int ,
		@before_upload_flag int ;
		
    --在inserted表中查询已经更新记录信息
    select @custid = FItemID, @custcode = FNumber, @custname = FName, @custaddress = FAddress, 
		   @linkername = FContact, @phone = FMobilePhone, @email = FEmail
	from inserted;
    select @before_upload_flag = flag from uploadCustflag where custid = @custid;
    set @flag = 1; 
    
    --判断商品修改前是否同步成功
    
    if(@before_upload_flag in (1, 2))	--同步成功修改
		--判断修改是'delete'还是'update'
		if exists(select 1 from T_Organization where FItemID = @custid and FDeleted = 1 )  --删除客户
			begin
				delete from uploadCustflag where custid = @custid;
				delete from uploadCust where custid = @custid;
				print '删除状态成功';
			end
		else        --修改客户基本信息
			begin  
				update uploadCustflag set custcode = @custcode, custname = @custname, flag = @flag where custid = @custid;
				update uploadCust set custcode = @custcode, custname = @custname, custaddress = @custaddress, 
					   linkername = @linkername, phone = @phone, email = @email
				where custid = @custid ;
				print '修改客户基本信息状态成功' ;
			end
			
	else		--同步失败修改
		begin
			update uploadCustflag set custcode = @custcode, custname = @custname, flag = 0 where custid = @custid;
			print '商品未同步，修改后需要同步'
		end
go

