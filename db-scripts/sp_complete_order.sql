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