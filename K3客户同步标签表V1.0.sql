--����uploadCustflag��
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


--����uploadCust��
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


-------------��Ʒ��T_Organization������--------------------

--����insert�������ʹ�����
if (object_id('tgr_T_Organization_insertCust', 'tr') is not null)
    drop trigger tgr_T_Organization_insertCust
go
create trigger tgr_T_Organization_insertCust
on T_Organization
    for insert --���봥��
as
    --�������
    declare 
		@custid int, 
		@custcode varchar(100),
		@custname varchar(100),
		@flag int ;
		
    --��inserted���в�ѯ�Ѿ������¼��Ϣ
    select @custid = FItemID, @custcode = FNumber, @custname = FName  from inserted;
    set @flag = 0;    
    insert into uploadCustflag(custid,custcode,custname,flag) 
    values(@custid, @custcode, @custname, @flag);
go

 
--update�������ʹ�����
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
		
    --��inserted���в�ѯ�Ѿ����¼�¼��Ϣ
    select @custid = FItemID, @custcode = FNumber, @custname = FName, @custaddress = FAddress, 
		   @linkername = FContact, @phone = FMobilePhone, @email = FEmail
	from inserted;
    select @before_upload_flag = flag from uploadCustflag where custid = @custid;
    set @flag = 1; 
    
    --�ж���Ʒ�޸�ǰ�Ƿ�ͬ���ɹ�
    
    if(@before_upload_flag in (1, 2))	--ͬ���ɹ��޸�
		--�ж��޸���'delete'����'update'
		if exists(select 1 from T_Organization where FItemID = @custid and FDeleted = 1 )  --ɾ���ͻ�
			begin
				delete from uploadCustflag where custid = @custid;
				delete from uploadCust where custid = @custid;
				print 'ɾ��״̬�ɹ�';
			end
		else        --�޸Ŀͻ�������Ϣ
			begin  
				update uploadCustflag set custcode = @custcode, custname = @custname, flag = @flag where custid = @custid;
				update uploadCust set custcode = @custcode, custname = @custname, custaddress = @custaddress, 
					   linkername = @linkername, phone = @phone, email = @email
				where custid = @custid ;
				print '�޸Ŀͻ�������Ϣ״̬�ɹ�' ;
			end
			
	else		--ͬ��ʧ���޸�
		begin
			update uploadCustflag set custcode = @custcode, custname = @custname, flag = 0 where custid = @custid;
			print '��Ʒδͬ�����޸ĺ���Ҫͬ��'
		end
go

