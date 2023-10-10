--drop database OnlineProdajaArtikala
--go

--create database OnlineProdajaArtikala
--go

use OnlineProdajaArtikala
go

drop table transakcija;
drop table artikal_pripada_porudzbini;
drop table porudzbina;
drop table povezanost;
drop table artikal;
drop table prodavnica;
drop table kupac;
drop table grad;


-- grad
CREATE TABLE [grad]
( 
	[id]                 integer IDENTITY NOT NULL ,
	[naziv]              varchar(50)  NULL ,
)
go

ALTER TABLE [grad]
	ADD CONSTRAINT [XPKgrad] PRIMARY KEY  CLUSTERED ([id] ASC)
go


-- povezanost
CREATE TABLE [povezanost]
( 
	[id]                 integer IDENTITY NOT NULL ,
	[id_grad_1]          integer  NOT NULL ,
	[id_grad_2]          integer  NOT NULL ,
	[razdaljina]         integer  NOT NULL ,
)
go

ALTER TABLE [povezanost]
	ADD CONSTRAINT [XPKpovezanost] PRIMARY KEY  CLUSTERED ([id] ASC)
go


-- kupac
CREATE TABLE [kupac]
( 
	[id]                 integer IDENTITY NOT NULL ,
	[ime]                varchar(50) NOT NULL ,
	[id_grada]           integer  NOT NULL ,
	[stanje_na_racunu]   decimal(10, 3)
)
go

ALTER TABLE [kupac]
	ADD CONSTRAINT [XPKkupac] PRIMARY KEY  CLUSTERED ([id] ASC)
go

ALTER TABLE [kupac]
	ADD CONSTRAINT [R_1] FOREIGN KEY ([id_grada]) REFERENCES [grad]([id])
		ON DELETE NO ACTION
		ON UPDATE CASCADE
go


-- prodavnica
CREATE TABLE [prodavnica]
( 
	[id]                 integer IDENTITY NOT NULL ,
	[naziv]              varchar(50) UNIQUE NOT NULL ,
	[id_grada]           integer  NOT NULL,
	[popust]			 integer
)
go

ALTER TABLE [prodavnica]
	ADD CONSTRAINT [XPKprodavnica] PRIMARY KEY  CLUSTERED ([id] ASC)
go

ALTER TABLE [prodavnica]
	ADD CONSTRAINT [R_2] FOREIGN KEY ([id_grada]) REFERENCES [grad]([id])
		ON DELETE NO ACTION
		ON UPDATE CASCADE
go


-- artikal
CREATE TABLE [artikal]
( 
	[id]					integer IDENTITY NOT NULL ,
	[naziv]					varchar(50) NOT NULL ,
	[cena]					decimal(10,3) NOT NULL ,
	[kolicina_na_stanju]    integer NOT NULL ,
	[id_prodavnice]			integer NOT NULL 
)
go

ALTER TABLE [artikal]
	ADD CONSTRAINT [XPKartikal] PRIMARY KEY  CLUSTERED ([id] ASC)
go

ALTER TABLE [artikal]
	ADD CONSTRAINT [R_3] FOREIGN KEY ([id_prodavnice]) REFERENCES [prodavnica]([id])
		ON DELETE NO ACTION
		ON UPDATE CASCADE
go

-- porudzbina
CREATE TABLE [porudzbina]
( 
	[id]						integer IDENTITY NOT NULL ,
	[stanje]					varchar(50) NOT NULL ,
	[id_kupca]					integer NOT NULL ,
	[vreme_slanja]				Date,
	[vreme_prijema]				Date,
	[krajnja_cena]				decimal(10,3),
	[vreme_cekanja_na_artikle]	integer,
	[pocetni_grad]				integer,
	[ciljni_grad]				integer,
	[trenutni_grad]				integer,
	[proteklo_vreme]			integer,
	[dodatan_popust]			bit
)
go

ALTER TABLE [porudzbina]
	ADD CONSTRAINT [XPKporudzbina] PRIMARY KEY  CLUSTERED ([id] ASC)
go

ALTER TABLE [porudzbina]
	ADD CONSTRAINT [R_4] FOREIGN KEY ([id_kupca]) REFERENCES [kupac]([id])
		ON DELETE NO ACTION
		ON UPDATE CASCADE
go


-- artikal pripada porudzbini
CREATE TABLE [artikal_pripada_porudzbini]
( 
	[id]					integer IDENTITY NOT NULL ,
	[id_porudzbine]			integer NOT NULL ,
	[id_artikla]			integer NOT NULL ,
	[kolicina]				integer NOT NULL
)
go

ALTER TABLE [artikal_pripada_porudzbini]
	ADD CONSTRAINT [XPKartikal_pripada_porudzbini] PRIMARY KEY  CLUSTERED ([id] ASC)
go

ALTER TABLE [artikal_pripada_porudzbini]
	ADD CONSTRAINT [R_6] FOREIGN KEY ([id_porudzbine]) REFERENCES [porudzbina]([id])
		ON DELETE NO ACTION
		ON UPDATE CASCADE
go

ALTER TABLE [artikal_pripada_porudzbini]
	ADD CONSTRAINT [R_7] FOREIGN KEY ([id_artikla]) REFERENCES [artikal]([id])
		ON DELETE NO ACTION
		ON UPDATE NO ACTION
go

-- transakcija
CREATE TABLE [transakcija]
( 
	[id]					integer IDENTITY NOT NULL ,
	[id_kupca]				integer ,
	[id_prodavnice]			integer ,
	[id_porudzbine]			integer NOT NULL ,
	[tip]					varchar(50) NOT NULL ,
	[vreme_izvrsenja]		Date NOT NULL ,
	[iznos]					decimal(10,3) NOT NULL 
)
go

ALTER TABLE [transakcija]
	ADD CONSTRAINT [XPKtransakcija] PRIMARY KEY  CLUSTERED ([id] ASC)
go

ALTER TABLE [transakcija]
	ADD CONSTRAINT [R_8] FOREIGN KEY ([id_kupca]) REFERENCES [kupac]([id])
		ON DELETE NO ACTION
		ON UPDATE NO ACTION
go

ALTER TABLE [transakcija]
	ADD CONSTRAINT [R_9] FOREIGN KEY ([id_prodavnice]) REFERENCES [prodavnica]([id])
		ON DELETE NO ACTION
		ON UPDATE NO ACTION
go

ALTER TABLE [transakcija]
	ADD CONSTRAINT [R_10] FOREIGN KEY ([id_porudzbine]) REFERENCES [porudzbina]([id])
		ON DELETE NO ACTION
		ON UPDATE CASCADE
go