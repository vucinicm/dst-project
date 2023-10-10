USE OnlineProdajaArtikala
GO

DROP TRIGGER IF EXISTS TR_TRANSFER_MONEY_TO_SHOPS
GO

CREATE TRIGGER TR_TRANSFER_MONEY_TO_SHOPS
	ON porudzbina
	FOR UPDATE
AS 
BEGIN

	PRINT('tRIGER:')

	DECLARE @IdPorudzbineI INT;
	DECLARE @StanjeI VARCHAR(50);
	DECLARE @VremePrijemaI DATE;

	DECLARE @IdPorudzbineD INT;
	DECLARE @StanjeD VARCHAR(50);
	DECLARE @VremePrijemaD DATE;

	DECLARE @KursorInsert CURSOR;
	DECLARE @KursorDelete CURSOR;

	SET @KursorInsert = CURSOR FOR
	SELECT id, stanje, vreme_prijema
	FROM inserted;

	SET @KursorDelete = CURSOR FOR
	SELECT id, stanje, vreme_prijema
	FROM deleted;

	OPEN @KursorInsert;
	OPEN @KursorDelete;

	fetch from @KursorInsert
	into @IdPorudzbineI, @StanjeI, @VremePrijemaI;

	fetch from @KursorDelete
	into @IdPorudzbineD, @StanjeD, @VremePrijemaD;

	while @@FETCH_STATUS = 0
	begin

		PRINT(CONCAT('IdPorudzbineI: ', @IdPorudzbineI, ' StanjeI: ', @StanjeI, ' VremePrijemaI: ', @VremePrijemaI))
		PRINT(CONCAT('IdPorudzbineD: ', @IdPorudzbineD, ' StanjeD: ', @StanjeD, ' VremePrijemaD: ', @VremePrijemaD))

		IF @StanjeD = 'sent' AND @StanjeI = 'arrived'
		BEGIN

			PRINT('Uslii')

			DECLARE @IdProdavnice INT;
			DECLARE @UkupnaCena DECIMAL(10, 3);

			DECLARE @ProvizijaZaSistem INT;
			SET @ProvizijaZaSistem = 5;

			DECLARE @KursorProdavnice CURSOR;

			SET @KursorProdavnice = CURSOR FOR
			SELECT P.id, SUM(AP.kolicina * A.cena * (100 - COALESCE(P.popust, 0)) / 100.00) AS ukupna_cena
			FROM artikal_pripada_porudzbini AP JOIN artikal A ON (AP.id_artikla = A.id) JOIN prodavnica P ON (A.id_prodavnice = P.id)
			WHERE id_porudzbine = @IdPorudzbineI
			GROUP BY P.id;
			
			OPEN @KursorProdavnice;
			
			fetch from @KursorProdavnice
			into @IdProdavnice, @UkupnaCena;

			while @@FETCH_STATUS = 0
			begin

				IF (SELECT dodatan_popust FROM porudzbina WHERE id = @IdPorudzbineI) IS NOT NULL
				BEGIN
					SET @ProvizijaZaSistem = 3;
				END;
				
				PRINT(CONCAT('IdProdavnice: ', @IdProdavnice, ' UkupnaCena: ', @UkupnaCena))

				INSERT INTO transakcija(id_kupca,id_prodavnice,id_porudzbine,tip,vreme_izvrsenja,iznos)
				VALUES(NULL, @IdProdavnice, @IdPorudzbineI, 'prodavnica', @VremePrijemaI, @UkupnaCena * (100 - @ProvizijaZaSistem) / 100.00);

				INSERT INTO transakcija(id_kupca,id_prodavnice,id_porudzbine,tip,vreme_izvrsenja,iznos)
				VALUES(NULL, @IdProdavnice, @IdPorudzbineI, 'sistem', @VremePrijemaI, @UkupnaCena * @ProvizijaZaSistem / 100.00);

				fetch from @KursorProdavnice
				into @IdProdavnice, @UkupnaCena;
			end

			close @KursorProdavnice
			deallocate @KursorProdavnice

		END

		fetch from @KursorInsert
		into @IdPorudzbineI, @StanjeI, @VremePrijemaI;

		fetch from @KursorDelete
		into @IdPorudzbineD, @StanjeD, @VremePrijemaD;
	end

	close @KursorInsert
	deallocate @KursorInsert

	close @KursorDelete
	deallocate @KursorDelete

END
GO


--SELECT SUM(AP.kolicina * A.cena * (100 - COALESCE(P.popust, 0)) / 100.00) AS ukupna_cena, P.id
--FROM artikal_pripada_porudzbini AP JOIN artikal A ON (AP.id_artikla = A.id) JOIN prodavnica P ON (A.id_prodavnice = P.id)
--GROUP BY P.id
--WHERE id_porudzbine = @IdPorudzbineI;

--select * from grad

--select * from transakcija

--select * from porudzbina

--UPDATE porudzbina
--set stanje = 'arrived'
--where id = 24



--SELECT SUM(iznos)
--FROM transakcija
--WHERE tip = 'kupac'