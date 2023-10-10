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