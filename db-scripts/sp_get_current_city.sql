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

DECLARE @startCityId INT;
exec SP_GET_CURRENT_CITY 185, 183, 19, @startCityId OUTPUT
PRINT(CONCAT('Trenutni grad je: ', @startCityId))


--select * from porudzbina
--select * from kupac
--select * from grad
--select * from povezanost
