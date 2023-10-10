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
