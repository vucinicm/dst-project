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
