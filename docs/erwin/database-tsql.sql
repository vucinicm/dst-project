-----------------------
-- SP_COMPLETE_ORDER --
-----------------------

use OnlineProdajaArtikala
go

DROP PROCEDURE IF EXISTS SP_COMPLETE_ORDER
GO

CREATE PROCEDURE SP_COMPLETE_ORDER
	@IdPorudzbine int,
	@Datum Date,
	@ReturnValue int OUTPUT,
	@ReturnMessage varchar(50) OUTPUT
AS
BEGIN
	-- racunanje ukupne cene porudzbine sa popustima
	DECLARE @UkupnaCena DECIMAL(10, 3);
	EXECUTE SP_FINAL_PRICE @IdPorudzbine, @Datum, @UkupnaCena OUTPUT;
	PRINT(CONCAT('UkupnaCena: ', @UkupnaCena));

	DECLARE @StanjeNaRacunu DECIMAL(10, 3);

	-- id kupca
	DECLARE @IdKupca int;
	SELECT @IdKupca = id_kupca FROM porudzbina WHERE id = @IdPorudzbine;

	-- stanje na racunu
	SELECT @StanjeNaRacunu = stanje_na_racunu FROM kupac WHERE id = @IdKupca
	PRINT(CONCAT('Stanje na racunu: ', @StanjeNaRacunu));

	-- nema dovoljno novca
	IF (@StanjeNaRacunu < @UkupnaCena)
	BEGIN
		SET @ReturnValue = -1;
		SET @ReturnMessage = 'Nema dovoljno novca na racunu!';
		RETURN;
	END
	
	-- skida se novac sa racuna kupca
	UPDATE kupac
	SET stanje_na_racunu = stanje_na_racunu - @UkupnaCena
	WHERE id = @IdKupca;

	-- najblizi grad gradu kupca koji ima prodavnicu
	DECLARE @IdGrada int;
	EXECUTE SP_NEAREST_CITY_TO_BUYER @IdKupca, @IdGrada OUTPUT;

	-- najduze vreme cekanja da artikli stignu u grad sa prodavnicom najblizi kupcu
	DECLARE @vremeCekanja INT;
	EXECUTE SP_FIND_MAX_TIME_TO_WAIT_ARTICLE @IdPorudzbine, @IdGrada, @vremeCekanja OUTPUT

	-- porudzbina
	UPDATE porudzbina
	SET stanje = 'sent',
	pocetni_grad = @IdGrada, -- najblizi grad gradu kupca koji ima prodavnicu
	ciljni_grad = (SELECT id_grada FROM kupac WHERE id = @IdKupca), -- grad kupca,
	trenutni_grad = @IdGrada, -- grad kupca,
	krajnja_cena = @UkupnaCena,
	vreme_slanja = @Datum,
	proteklo_vreme = 0,
	vreme_cekanja_na_artikle = @vremeCekanja
	WHERE id = @IdPorudzbine;

	-- transakcija
	INSERT INTO transakcija(id_kupca,id_prodavnice,id_porudzbine,tip,vreme_izvrsenja,iznos)
	VALUES(@IdKupca, NULL, @IdPorudzbine, 'kupac', @Datum, @UkupnaCena);

	SET @ReturnValue = 0;
	SET @ReturnMessage = 'OK!';

END
GO

--------------------
-- SP_FINAL_PRICE --
--------------------

use OnlineProdajaArtikala
go

DROP PROCEDURE IF EXISTS SP_FINAL_PRICE
GO

CREATE PROCEDURE SP_FINAL_PRICE
	@IdPorudzbine int,
	@TrenutniDatum DATE,
	@UkupnaCena DECIMAL(10, 3) OUTPUT
AS
BEGIN
	DECLARE @Artikli CURSOR;
	DECLARE @CenaArtikla DECIMAL(10, 3);
	DECLARE @Popust INT;
	DECLARE @Kolicina INT;

	SET @UkupnaCena = 0.0;

	-- popust ako je kupac u zadnjih 30 dana narucio nesto u vrednosti od 10000

	DECLARE @IznosUZadnjih30Dana DECIMAL(10, 3);

	SELECT @IznosUZadnjih30Dana = COALESCE(SUM(iznos), 0)
	FROM transakcija
	WHERE tip = 'kupac' AND id_kupca = (SELECT id_kupca FROM porudzbina WHERE id = @IdPorudzbine) AND vreme_izvrsenja > CONVERT(Date, DATEADD(DAY, -30, @TrenutniDatum));

	IF @IznosUZadnjih30Dana > 10000
	BEGIN
		UPDATE porudzbina
		SET dodatan_popust = 2;
	END

	------------------------------------------------------------------------------

	DECLARE @DodatanPopust INT;
	SELECT @DodatanPopust = dodatan_popust
	FROM porudzbina
	WHERE id = @IdPorudzbine;

	SET @Artikli = CURSOR FOR
	SELECT A.cena, PR.popust, P.kolicina
	FROM artikal_pripada_porudzbini P JOIN artikal A on (P.id_artikla = A.id) JOIN prodavnica PR on (PR.id = A.id_prodavnice)
	WHERE P.id_porudzbine = @IdPorudzbine;

	OPEN @Artikli;

	FETCH NEXT FROM @Artikli
	INTO @CenaArtikla, @Popust, @Kolicina;

	WHILE @@FETCH_STATUS = 0
	BEGIN
		PRINT(CONCAT('Cena: ', @CenaArtikla, ' Popust:', @Popust));

		SET @UkupnaCena = @UkupnaCena + @CenaArtikla * @Kolicina * (100 - COALESCE(@Popust, 0)) / 100.00 * (100 - COALESCE(@DodatanPopust, 0)) / 100.00;

		PRINT(CONCAT('UkupnaCena: ', @UkupnaCena));

		FETCH NEXT FROM @Artikli
		INTO @CenaArtikla, @Popust, @Kolicina;
	END

	CLOSE @Artikli;
	DEALLOCATE @Artikli;
END
GO

--DECLARE @UkupnaCena DECIMAL(10, 3);
--EXECUTE  SP_FINAL_PRICE 24, @UkupnaCena OUTPUT
--PRINT(CONCAT('UkupnaCena: ', @UkupnaCena));


--------------------------------------
-- SP_FIND_MAX_TIME_TO_WAIT_ARTICLE --
--------------------------------------

USE OnlineProdajaArtikala
GO

DROP PROCEDURE IF EXISTS SP_FIND_MAX_TIME_TO_WAIT_ARTICLE
GO

CREATE PROCEDURE SP_FIND_MAX_TIME_TO_WAIT_ARTICLE
	@IdPorudzbine INT,
	@IdCiljnogGrada INT,
	@MaksimalnoVremeCekanja INT OUTPUT
AS
BEGIN

	-- Tabela koja sadrzi informaciju o tome koji su poseceni gradovi i minimalnim distancama do njih
    CREATE TABLE #PoseceniGradovi (
        id_grad INT PRIMARY KEY,
		posecen BIT NOT NULL,
        najkrace_rastojanje BIGINT
    );

	-- Gradovi u kojima su artikli
	CREATE TABLE #GradoviSaArtiklima(id_grada INT PRIMARY KEY);
	INSERT INTO #GradoviSaArtiklima(id_grada)
	SELECT DISTINCT P.id_grada
	FROM artikal_pripada_porudzbini AP JOIN artikal A ON (AP.id_artikla = A.id) JOIN prodavnica P ON (A.id_prodavnice = P.id) 
	WHERE AP.id_porudzbine = @IdPorudzbine

	
    INSERT INTO #PoseceniGradovi (id_grad, posecen, najkrace_rastojanje)
    SELECT id AS id_grad, 0, CASE WHEN id = @IdCiljnogGrada THEN 0 ELSE 2147483647 END AS najkrace_rastojanje
    FROM grad;

	-- Dijkstra's algorithm
    WHILE EXISTS (SELECT * FROM #PoseceniGradovi WHERE posecen = 0)
    BEGIN
        -- Nadji grad sa najmanjim rastojanjem koji jos nije posecen
        DECLARE @trenutniGrad INT;
        SELECT TOP 1 @trenutniGrad = id_grad
        FROM #PoseceniGradovi
		WHERE posecen = 0
        ORDER BY najkrace_rastojanje;

		DECLARE @RastojanjeDoTrenutnogGrada BIGINT;
        SELECT @RastojanjeDoTrenutnogGrada = najkrace_rastojanje
        FROM #PoseceniGradovi
		WHERE id_grad = @trenutniGrad;

		UPDATE #PoseceniGradovi SET posecen = 1 WHERE id_grad = @trenutniGrad;

		PRINT(CONCAT('Trenutni grad je: ', @trenutniGrad))

		-- Kursor za neposecene gradove
		DECLARE @NeposeceniGradovi CURSOR;
		SET @NeposeceniGradovi = CURSOR FOR
		SELECT id_grad, najkrace_rastojanje FROM #PoseceniGradovi WHERE posecen = 0;

		DECLARE @IdNeposecenogGrada INT;
		DECLARE @RastojanjeDoNeposecenogGrada BIGINT;

		OPEN @NeposeceniGradovi;

		FETCH NEXT FROM @NeposeceniGradovi
		INTO @IdNeposecenogGrada, @RastojanjeDoNeposecenogGrada;

		WHILE @@FETCH_STATUS = 0
		BEGIN
			-- Ako postoji putanja izmedju trenutno posmatranog cvora i neposecenog, probaj da azuriras
			IF EXISTS (SELECT * FROM povezanost WHERE id_grad_1 = @trenutniGrad AND id_grad_2 = @IdNeposecenogGrada OR id_grad_2 = @trenutniGrad AND id_grad_1 = @IdNeposecenogGrada)
			BEGIN
				DECLARE @Razdaljina INT;

				SELECT @Razdaljina = razdaljina
				FROM  povezanost
				WHERE id_grad_1 = @trenutniGrad AND id_grad_2 = @IdNeposecenogGrada OR id_grad_2 = @trenutniGrad AND id_grad_1 = @IdNeposecenogGrada

				IF @RastojanjeDoTrenutnogGrada + @Razdaljina < @RastojanjeDoNeposecenogGrada
				BEGIN
					UPDATE #PoseceniGradovi
					SET najkrace_rastojanje = @RastojanjeDoTrenutnogGrada + @Razdaljina
					WHERE id_grad = @IdNeposecenogGrada

					PRINT(CONCAT('Azurirano rastojanje od ', @trenutniGrad, ' do ', @IdNeposecenogGrada, ' = ',  @RastojanjeDoTrenutnogGrada + @Razdaljina))
				END
			END

			FETCH NEXT FROM @NeposeceniGradovi
			INTO @IdNeposecenogGrada, @RastojanjeDoNeposecenogGrada;
		END

		CLOSE @NeposeceniGradovi;
		DEALLOCATE @NeposeceniGradovi;
    END;

	-- Nadji najblizi grad u kojem postoji prodavnica
    SELECT TOP 1 @MaksimalnoVremeCekanja = najkrace_rastojanje
    FROM #PoseceniGradovi
    WHERE id_grad <> @IdCiljnogGrada AND id_grad IN (SELECT id_grada FROM #GradoviSaArtiklima)
    ORDER BY najkrace_rastojanje DESC;

	DROP TABLE #GradoviSaArtiklima;
	DROP TABLE #PoseceniGradovi;

END
GO

--DECLARE @startCityId INT;
--exec SP_FIND_MAX_TIME_TO_WAIT_ARTICLE 6, 31, @startCityId OUTPUT
--PRINT(CONCAT('Najdalji grad je: ', @startCityId))


--select * from porudzbina
--select * from kupac
--select * from grad
--select * from povezanost

-------------------------
-- SP_GET_CURRENT_CITY --
-------------------------

USE OnlineProdajaArtikala
GO

DROP PROCEDURE IF EXISTS SP_GET_CURRENT_CITY
GO

CREATE PROCEDURE SP_GET_CURRENT_CITY
	@IdPocetnogGrada INT,
	@IdCiljnogGrada INT,
	@ProtekloVreme INT,
	@IdTrenutnogGrada INT OUTPUT
AS
BEGIN
	-- Tabela koja sadrzi informaciju o tome koji su poseceni gradovi i minimalnim distancama do njih
    CREATE TABLE #PoseceniGradovi (
        id_grad INT PRIMARY KEY,
		posecen BIT NOT NULL,
        najkrace_rastojanje BIGINT,
		id_prethodnog_grada INT,
		rastojanje_do_prethodnog INT
    );
	
    INSERT INTO #PoseceniGradovi (id_grad, posecen, najkrace_rastojanje, id_prethodnog_grada, rastojanje_do_prethodnog)
    SELECT id AS id_grad, 0, CASE WHEN id = @IdCiljnogGrada THEN 0 ELSE 2147483647 END AS najkrace_rastojanje, -1, -1
    FROM grad;

	-- Dijkstra's algorithm
    WHILE EXISTS (SELECT * FROM #PoseceniGradovi WHERE posecen = 0)
    BEGIN
        -- Nadji grad sa najmanjim rastojanjem koji jos nije posecen
        DECLARE @trenutniGrad INT;
        SELECT TOP 1 @trenutniGrad = id_grad
        FROM #PoseceniGradovi
		WHERE posecen = 0
        ORDER BY najkrace_rastojanje;

		DECLARE @RastojanjeDoTrenutnogGrada BIGINT;
        SELECT @RastojanjeDoTrenutnogGrada = najkrace_rastojanje
        FROM #PoseceniGradovi
		WHERE id_grad = @trenutniGrad;

		UPDATE #PoseceniGradovi SET posecen = 1 WHERE id_grad = @trenutniGrad;

		PRINT(CONCAT('Trenutni grad je: ', @trenutniGrad))

		-- Kursor za neposecene gradove
		DECLARE @NeposeceniGradovi CURSOR;
		SET @NeposeceniGradovi = CURSOR FOR
		SELECT id_grad, najkrace_rastojanje FROM #PoseceniGradovi WHERE posecen = 0;

		DECLARE @IdNeposecenogGrada INT;
		DECLARE @RastojanjeDoNeposecenogGrada BIGINT;

		OPEN @NeposeceniGradovi;

		FETCH NEXT FROM @NeposeceniGradovi
		INTO @IdNeposecenogGrada, @RastojanjeDoNeposecenogGrada;

		WHILE @@FETCH_STATUS = 0
		BEGIN
			-- Ako postoji putanja izmedju trenutno posmatranog cvora i neposecenog, probaj da azuriras
			IF EXISTS (SELECT * FROM povezanost WHERE id_grad_1 = @trenutniGrad AND id_grad_2 = @IdNeposecenogGrada OR id_grad_2 = @trenutniGrad AND id_grad_1 = @IdNeposecenogGrada)
			BEGIN
				DECLARE @Razdaljina INT;

				SELECT @Razdaljina = razdaljina
				FROM  povezanost
				WHERE id_grad_1 = @trenutniGrad AND id_grad_2 = @IdNeposecenogGrada OR id_grad_2 = @trenutniGrad AND id_grad_1 = @IdNeposecenogGrada

				IF @RastojanjeDoTrenutnogGrada + @Razdaljina < @RastojanjeDoNeposecenogGrada
				BEGIN
					UPDATE #PoseceniGradovi
					SET najkrace_rastojanje = @RastojanjeDoTrenutnogGrada + @Razdaljina,
					id_prethodnog_grada = @trenutniGrad,
					rastojanje_do_prethodnog = @Razdaljina
					WHERE id_grad = @IdNeposecenogGrada

					PRINT(CONCAT('Azurirano rastojanje od ', @trenutniGrad, ' do ', @IdNeposecenogGrada, ' = ',  @RastojanjeDoTrenutnogGrada + @Razdaljina))
					PRINT(CONCAT('Prethodnik: ', @trenutniGrad))
				END
			END

			FETCH NEXT FROM @NeposeceniGradovi
			INTO @IdNeposecenogGrada, @RastojanjeDoNeposecenogGrada;
		END

		CLOSE @NeposeceniGradovi;
		DEALLOCATE @NeposeceniGradovi;

	END;


	-- Ako je proteklo vreme vece ili jednako vremenu da se stigne u ciljni grad, smatramo da smo vec u njemu
	DECLARE @RastojanjeDoCiljnogGrada INT;

	SELECT @RastojanjeDoCiljnogGrada = najkrace_rastojanje
	FROM #PoseceniGradovi
	WHERE id_grad = @IdPocetnogGrada;

	PRINT(CONCAT('Rastojanje je: ', @RastojanjeDoCiljnogGrada))

	IF @ProtekloVreme >= @RastojanjeDoCiljnogGrada 
	BEGIN
		SET @IdTrenutnogGrada = @IdCiljnogGrada;
		RETURN;
	END

	-- Trazimo u kojem smo gradu
	DECLARE @IdPretGrada INT;
	DECLARE @IdTrenGrada INT;

	SET @IdTrenGrada = @IdPocetnogGrada;

	DECLARE @PredjenoRastojanje INT;

	SET @PredjenoRastojanje = 0;

	DECLARE @Flag BIT;
	SET @Flag = 0;

	WHILE @Flag <> 1 AND @IdTrenGrada <> @IdCiljnogGrada
	BEGIN
		SELECT @IdPretGrada = id_prethodnog_grada
		FROM #PoseceniGradovi
		WHERE id_grad = @IdTrenGrada;

		DECLARE @RastojanjeIzmedjuTrenIPret INT;

		SELECT @RastojanjeIzmedjuTrenIPret = rastojanje_do_prethodnog
		FROM #PoseceniGradovi
		WHERE id_grad = @IdTrenGrada;

		PRINT(CONCAT('Trenutni grad: ', @IdTrenGrada, ' Prethodni grad: ', @IdPretGrada, ' Rastojanje do prethodnog: ',  @RastojanjeIzmedjuTrenIPret))

		SET @PredjenoRastojanje = @PredjenoRastojanje + @RastojanjeIzmedjuTrenIPret;

		IF @ProtekloVreme < @PredjenoRastojanje
		BEGIN
			SET @IdTrenutnogGrada = @IdTrenGrada
			SET @Flag = 1;
		END

		SET @IdTrenGrada = @IdPretGrada;
	END;

	DROP TABLE #PoseceniGradovi;

END
GO

--DECLARE @startCityId INT;
-- SP_GET_CURRENT_CITY 185, 183, 19, @startCityId OUTPUT
--PRINT(CONCAT('Trenutni grad je: ', @startCityId))


--select * from porudzbina
--select * from kupac
--select * from grad
--select * from povezanost

-------------------------
-- SP_GET_DISCOUNT_SUM --
-------------------------

use OnlineProdajaArtikala
go

DROP PROCEDURE IF EXISTS SP_GET_DISCOUNT_SUM
GO

CREATE PROCEDURE SP_GET_DISCOUNT_SUM
	@IdPorudzbine int,
	@UkupanPopust DECIMAL(10, 3) OUTPUT
AS
BEGIN
	DECLARE @Artikli CURSOR;
	DECLARE @CenaArtikla DECIMAL(10, 3);
	DECLARE @Popust INT;
	DECLARE @Kolicina INT;

	SET @UkupanPopust = 0.0;

	SET @Artikli = CURSOR FOR
	SELECT A.cena, PR.popust, P.kolicina
	FROM artikal_pripada_porudzbini P JOIN artikal A on (P.id_artikla = A.id) JOIN prodavnica PR on (PR.id = A.id_prodavnice)
	WHERE P.id_porudzbine = @IdPorudzbine;

	OPEN @Artikli;

	FETCH NEXT FROM @Artikli
	INTO @CenaArtikla, @Popust, @Kolicina;

	WHILE @@FETCH_STATUS = 0
	BEGIN
		PRINT(CONCAT('Cena: ', @CenaArtikla, ' Popust:', @Popust));

		IF (@Popust IS NOT NULL)
		BEGIN
			SET @UkupanPopust = @UkupanPopust + @CenaArtikla * @Kolicina * (@Popust / 100.00);
		END

		FETCH NEXT FROM @Artikli
		INTO @CenaArtikla, @Popust, @Kolicina;
	END

	CLOSE @Artikli;
	DEALLOCATE @Artikli;
END
GO

------------------------------
-- SP_NEAREST_CITY_TO_BUYER --
------------------------------

use OnlineProdajaArtikala
go

DROP PROCEDURE IF EXISTS SP_NEAREST_CITY_TO_BUYER
GO

CREATE PROCEDURE SP_NEAREST_CITY_TO_BUYER
	@IdKupca int,
	@IdGrada int OUTPUT
AS
BEGIN

	DECLARE @startCityId INT;
	SELECT @startCityId = id_grada FROM kupac WHERE id = @IdKupca;

	CREATE TABLE #GradoviSaProdavnicom(id_grada INT PRIMARY KEY);
	INSERT INTO #GradoviSaProdavnicom(id_grada)
	SELECT id
	FROM grad
	WHERE id IN (SELECT id_grada from prodavnica)

	-- Tabela koja sadrzi informaciju o tome koji su poseceni gradovi i minimalnim distancama do njih
    CREATE TABLE #PoseceniGradovi (
        id_grad INT PRIMARY KEY,
		posecen BIT NOT NULL,
        najkrace_rastojanje BIGINT
    );

    INSERT INTO #PoseceniGradovi (id_grad, posecen, najkrace_rastojanje)
    SELECT id AS id_grad, 0, CASE WHEN id = @startCityId THEN 0 ELSE 2147483647 END AS najkrace_rastojanje
    FROM grad;

	-- Dijkstra's algorithm
    WHILE EXISTS (SELECT * FROM #PoseceniGradovi WHERE posecen = 0)
    BEGIN
        -- Nadji grad sa najmanjim rastojanjem koji jos nije posecen
        DECLARE @trenutniGrad INT;
        SELECT TOP 1 @trenutniGrad = id_grad
        FROM #PoseceniGradovi
		WHERE posecen = 0
        ORDER BY najkrace_rastojanje;

		DECLARE @RastojanjeDoTrenutnogGrada BIGINT;
        SELECT @RastojanjeDoTrenutnogGrada = najkrace_rastojanje
        FROM #PoseceniGradovi
		WHERE id_grad = @trenutniGrad;

		UPDATE #PoseceniGradovi SET posecen = 1 WHERE id_grad = @trenutniGrad;

		PRINT(CONCAT('Trenutni grad je: ', @trenutniGrad))

		-- Kursor za neposecene gradove
		DECLARE @NeposeceniGradovi CURSOR;
		SET @NeposeceniGradovi = CURSOR FOR
		SELECT id_grad, najkrace_rastojanje FROM #PoseceniGradovi WHERE posecen = 0;

		DECLARE @IdNeposecenogGrada INT;
		DECLARE @RastojanjeDoNeposecenogGrada BIGINT;

		OPEN @NeposeceniGradovi;

		FETCH NEXT FROM @NeposeceniGradovi
		INTO @IdNeposecenogGrada, @RastojanjeDoNeposecenogGrada;

		WHILE @@FETCH_STATUS = 0
		BEGIN
			-- Ako postoji putanja izmedju trenutno posmatranog cvora i neposecenog, probaj da azuriras
			IF EXISTS (SELECT * FROM povezanost WHERE id_grad_1 = @trenutniGrad AND id_grad_2 = @IdNeposecenogGrada OR id_grad_2 = @trenutniGrad AND id_grad_1 = @IdNeposecenogGrada)
			BEGIN
				DECLARE @Razdaljina INT;

				SELECT @Razdaljina = razdaljina
				FROM  povezanost
				WHERE id_grad_1 = @trenutniGrad AND id_grad_2 = @IdNeposecenogGrada OR id_grad_2 = @trenutniGrad AND id_grad_1 = @IdNeposecenogGrada

				IF @RastojanjeDoTrenutnogGrada + @Razdaljina < @RastojanjeDoNeposecenogGrada
				BEGIN
					UPDATE #PoseceniGradovi
					SET najkrace_rastojanje = @RastojanjeDoTrenutnogGrada + @Razdaljina
					WHERE id_grad = @IdNeposecenogGrada
				END
			END

			FETCH NEXT FROM @NeposeceniGradovi
			INTO @IdNeposecenogGrada, @RastojanjeDoNeposecenogGrada;
		END

		CLOSE @NeposeceniGradovi;
		DEALLOCATE @NeposeceniGradovi;
    END;

	-- Nadji najblizi grad u kojem postoji prodavnica
    SELECT TOP 1 @IdGrada = id_grad
    FROM #PoseceniGradovi
    WHERE id_grad <> @startCityId AND id_grad IN (SELECT id_grada FROM #GradoviSaProdavnicom)
    ORDER BY najkrace_rastojanje;

	DROP TABLE #GradoviSaProdavnicom;
	DROP TABLE #PoseceniGradovi;

END
GO

--DECLARE @startCityId INT;
--exec SP_NEAREST_CITY_TO_BUYER 199, @startCityId OUTPUT
--PRINT(CONCAT('Najblizi grad je: ', @startCityId))


--select * from porudzbina
--select * from kupac
--select * from grad
--select * from povezanost

---------------------
-- SP_TIME_ELAPSED --
---------------------

USE OnlineProdajaArtikala
GO

DROP PROCEDURE IF EXISTS SP_TIME_ELAPSED
GO

CREATE PROCEDURE SP_TIME_ELAPSED
	@NumberOfDaysElapsed INT
AS
BEGIN

	-- Kursor za porudzbine
	DECLARE @Porudzbine CURSOR;

	SET @Porudzbine = CURSOR FOR
	SELECT id, vreme_cekanja_na_artikle, pocetni_grad, ciljni_grad, proteklo_vreme 
	FROM porudzbina P
	WHERE P.stanje = 'sent';

	DECLARE @IdPorudzbine INT;
	DECLARE @VremeCekanjaNaArtikle INT;
	DECLARE @PocetniGrad INT;
	DECLARE @CiljniGrad INT;
	DECLARE @ProtekloVreme INT;
	DECLARE @TrenutniGrad INT;

	OPEN @Porudzbine;

	FETCH NEXT FROM @Porudzbine
	INTO @IdPorudzbine, @VremeCekanjaNaArtikle, @PocetniGrad, @CiljniGrad, @ProtekloVreme;

	WHILE @@FETCH_STATUS = 0
	BEGIN
		 -- Jos uvek se cekaju artikli
		IF @VremeCekanjaNaArtikle > 0
		BEGIN
			DECLARE @Diff INT;

			SET @Diff = ABS(@VremeCekanjaNaArtikle - @NumberOfDaysElapsed);

			UPDATE porudzbina
			SET vreme_cekanja_na_artikle = vreme_cekanja_na_artikle - @NumberOfDaysElapsed
			WHERE id = @IdPorudzbine AND stanje = 'sent';

			SELECT @VremeCekanjaNaArtikle = vreme_cekanja_na_artikle
			FROM porudzbina
			WHERE id = @IdPorudzbine;

			IF @VremeCekanjaNaArtikle <= 0
			BEGIN
				EXECUTE SP_GET_CURRENT_CITY @PocetniGrad, @CiljniGrad, @Diff, @TrenutniGrad OUTPUT

				UPDATE porudzbina
				SET vreme_cekanja_na_artikle = 0,
				proteklo_vreme = @Diff,
				trenutni_grad = @TrenutniGrad
				WHERE id = @IdPorudzbine AND stanje = 'sent';
			END

		END
		ELSE
		BEGIN
			SET @ProtekloVreme = @ProtekloVreme + @NumberOfDaysElapsed;
			EXECUTE SP_GET_CURRENT_CITY @PocetniGrad, @CiljniGrad, @ProtekloVreme, @TrenutniGrad OUTPUT

			UPDATE porudzbina
			SET proteklo_vreme = @ProtekloVreme,
			trenutni_grad = @TrenutniGrad
			WHERE id = @IdPorudzbine AND stanje = 'sent';
		END

		FETCH NEXT FROM @Porudzbine
		INTO @IdPorudzbine, @VremeCekanjaNaArtikle, @PocetniGrad, @CiljniGrad, @ProtekloVreme;
	END

	CLOSE @Porudzbine;
	DEALLOCATE @Porudzbine;

	UPDATE porudzbina
	SET stanje = 'arrived',
	vreme_prijema = DATEADD(DAY, proteklo_vreme + 1, vreme_slanja) 
	WHERE trenutni_grad = ciljni_grad AND stanje = 'sent';

END
GO

--------------------------------
-- TR_TRANSFER_MONEY_TO_SHOPS --
--------------------------------

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