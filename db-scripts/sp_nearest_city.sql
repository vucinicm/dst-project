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

DECLARE @startCityId INT;
exec SP_NEAREST_CITY_TO_BUYER 199, @startCityId OUTPUT
PRINT(CONCAT('Najblizi grad je: ', @startCityId))


--select * from porudzbina
--select * from kupac
--select * from grad
--select * from povezanost