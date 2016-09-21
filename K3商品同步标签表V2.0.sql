--����uploadGoodsflag��
if exists(select * from sysobjects where id = object_id(N'uploadGoodsflag') and OBJECTPROPERTY(id, N'IsUserTable') = 1)
drop table uploadGoodsflag
create table uploadGoodsflag
(
	id int IDENTITY(1,1) primary key NOT NULL,
	spinnerid int NOT NULL,
	spcode varchar(100) NULL,
	spname varchar(100) NULL,
	flag int not null,
	syncedflag int not null, --��ʼ����ȡ�׶�����Ʒ���
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


--����uploadGoods��
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


-------------��Ʒ������--------------------

--����insert�������ʹ�����
if (object_id('tgr_t_ICItemCore_insertGoods', 'tr') is not null)
    drop trigger tgr_t_ICItemCore_insertGoods
go
create trigger tgr_t_ICItemCore_insertGoods
on t_ICItemCore
    for insert --���봥��
as
    --�������
    declare 
		@spinnerid int, 
		@spcode varchar(100),
		@spname varchar(100),
		@flag int ;
		
    --��inserted���в�ѯ�Ѿ������¼��Ϣ
    select @spinnerid = FItemID, @spcode = FNumber, @spname = FName  from inserted;
    set @flag = 0;    
    insert into uploadGoodsflag(spinnerid,spcode,spname,flag, syncedflag) 
    values(@spinnerid, @spcode, @spname, @flag, 0);
go

 
--update�������ʹ�����
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
    --��inserted���в�ѯ�Ѿ����¼�¼��Ϣ
    select @spinnerid = FItemID, @spcode = FNumber, @spname = FName, @mulspec1Value = case when FModel = '' then '��' else FModel end  from inserted;
    select @unit = u.FName from (
		select t1.FItemID, t1.FUnitID, t2.FMeasureUnitID, t2.FName 
		from t_ICItemBase t1 inner join t_MeasureUnit t2 on t1.FUnitID = t2.FMeasureUnitID 
		)u
    where u.FItemID = @spinnerid;
    select @before_upload_flag = flag,@before_upload_spcode = spcode from uploadGoodsflag where spinnerid = @spinnerid;
    set @flag = 1; 
    --�ж���Ʒ�޸�ǰ�Ƿ�ͬ���ɹ�
    if(@before_upload_flag in (1, 2))	--ͬ���ɹ��޸�
		--�ж��޸���'delete'����'update'
		if exists(select 1 from t_ICItemCore where FItemID = @spinnerid and FDeleted = 1 )  --ɾ����Ʒ
			begin
				delete from uploadGoodsflag where spinnerid = @spinnerid;
				delete from uploadGoods where barcode = cast(@spinnerid as varchar(100));
				print 'ɾ��״̬�ɹ�';
			end
		else if exists(select 1 from t_ICItemCore where  FNumber = @before_upload_spcode)  --�޸���Ʒ������Ϣ
			begin  
				update uploadGoodsflag set spname = @spname, flag = @flag where spinnerid = @spinnerid;
				update uploadGoods set name = @spname, productUnitName = @unit, mulspec1Value = @mulspec1Value, flag = @flag where code = @spcode;
				print '�޸���Ʒ������Ϣ״̬�ɹ�' ;
			end
		else	 --�޸���Ʒ����
			begin  
				update uploadGoodsflag set spcode = @spcode, spname = @spname, flag = 0 where spinnerid = @spinnerid;
				update uploadGoods set code = @spcode, name = @spname, productUnitName = @unit, mulspec1Value = @mulspec1Value, flag = 0 where code = @spcode;
				print '�޸���Ʒ����״̬�ɹ�' ;
			end
			
	else		--ͬ��ʧ���޸�
		begin
			update uploadGoodsflag set spcode = @spcode, spname = @spname, flag = 0 where spinnerid = @spinnerid;
			print '��Ʒδͬ�����޸ĺ���Ҫͬ��'
		end
go


-------------uploadGoods������--------------------
/*
	�����ʼ����ƷʱbarcodeΪ�յ����
*/
--����insert�������ʹ�����
if (object_id('tgr_uploadGoods_insert', 'tr') is not null)
    drop trigger tgr_uploadGoods_insert
go
create trigger tgr_uploadGoods_insert
on uploadGoods
    for insert --���봥��
as
    --�������
    declare 
		@id int,
		@code varchar(60), 
		@barcode varchar(15),
		@name varchar(60);
		
    --��inserted���в�ѯ�Ѿ������¼��Ϣ
    select @id = id, @code = code, @barcode = barcode, @name = name from inserted;
    if (@barcode = '' or @barcode is null )
		begin
			select @barcode = Fnumber from t_ICItemCore where FNumber = @code  
			update uploadGoods set barcode = @barcode, flag = 1 where id = @id and code = @code
			update uploadGoodsflag set syncedflag = 1 where spcode = @code
			print 'barcodeΪ�գ�syncedflag = 1'
		end
go


