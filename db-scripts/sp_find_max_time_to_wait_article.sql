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

DECLARE @startCityId INT;
exec SP_FIND_MAX_TIME_TO_WAIT_ARTICLE 6, 31, @startCityId OUTPUT
PRINT(CONCAT('Najdalji grad je: ', @startCityId))


--select * from porudzbina
--select * from kupac
--select * from grad
--select * from povezanost


