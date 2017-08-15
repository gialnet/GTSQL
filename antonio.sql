
--
--
-- AÑADIR O MODIFICAR UN CONTADOR DE CONCEPTOS Y EN EL CASO DE AÑADIR CONCEPTO
-- DARLO DE ALTA PARA TODOS LOS MUNICIPIOS 
-- 
-- xTarifa indica si tiene multiples tarifas o no. posibles valores ('S','N')
-- xCodTarifa código alfanumerico de la tarifa
--
CREATE OR REPLACE PROCEDURE ADD_CONCEPTO(
	xAYTO       	IN CHAR,
	xCONCEPTO 		IN CHAR,
	xTarifa		IN Char,
	xCodTarifa		IN Char,
	xDESCRIP 		IN CHAR,
	xFORMULA 		IN CHAR,
	xFORMULAB 		IN CHAR,
	xFORMULAC 		IN CHAR,
	xFORMULAD 		IN CHAR,
	xVARA 		IN CHAR,
	xVARB 		IN CHAR,
	xVARC 		IN CHAR,
	xVARD 		IN CHAR,
	xEXPLI 		IN CHAR,
	xOrigen		IN char,
	xTributo		IN char,
	xObjeto		IN char
)
AS

BEGIN



UPDATE CONCEPTOS SET DESCRIPCION=xDESCRIP
      WHERE CONCEPTO=xCONCEPTO;

--
-- si no existe el concepto lo insertamos en la tabla 
--

IF SQL%NOTFOUND THEN


	INSERT INTO CONCEPTOS (CONCEPTO, DESCRIPCION)
      	VALUES (xCONCEPTO, xDESCRIP);

      -- Inicialmente se pondrá la misma fórmula para
      -- todos los municipios del concepto creado 

	INSERT INTO CONTADOR_CONCEPTOS
	(MUNICIPIO,CONCEPTO,CONTADOR,TARIFAS,
		FORMULA,FORMULAB,FORMULAC,FORMULAD,
		TIPO1,TIPO2,TIPO3,TIPO4,EXPLICACION,
		TIPO_OBJETO, TIPO_TRIBUTO, CARACTER_TRIBUTO)

	SELECT MUNICIPIO,xCONCEPTO,0,xTarifa,
		xFORMULA,xFORMULAB,xFORMULAC,xFORMULAD,
		xVARA,xVARB,xVARC,xVARD,xEXPLI,
		xObjeto, xTributo, xOrigen

	FROM DATOSPER;

	if xTarifa='S' then

		INSERT INTO TARIFAS_CONCEPTOS
		(AYTO,CONCEPTO,TARIFA,
		FORMULA,FORMULAB,FORMULAC,FORMULAD,
		TIPO1,TIPO2,TIPO3,TIPO4,EXPLICACION,
		TIPO_OBJETO, TIPO_TRIBUTO, CARACTER_TRIBUTO)

		SELECT MUNICIPIO,xCONCEPTO,xCodTarifa,
		xFORMULA,xFORMULAB,xFORMULAC,xFORMULAD,
		xVARA,xVARB,xVARC,xVARD,xEXPLI,
		xObjeto, xTributo, xOrigen

		FROM DATOSPER;

	end if;

ELSE

	if xTarifa='N' then

         -- Al modificar un concepto, el cambio en la 
         -- formula se contemplará en un municipio en concreto 
          
      	UPDATE CONTADOR_CONCEPTOS SET FORMULA=xFORMULA,
                                    FORMULAB=xFORMULAB,
                                    FORMULAC=xFORMULAC,
                                    FORMULAD=xFORMULAD,
                                    TIPO1=xVARA,
                                    TIPO2=xVARB,
                                    TIPO3=xVARC,
                                    TIPO4=xVARD,
                                    EXPLICACION=xEXPLI,
						TIPO_OBJETO=xObjeto,
						TIPO_TRIBUTO=xTributo, 
						CARACTER_TRIBUTO=xOrigen,
						TARIFAS='N'
		WHERE MUNICIPIO=xAYTO 
		AND CONCEPTO=xCONCEPTO;

	else

		UPDATE CONTADOR_CONCEPTOS SET TARIFAS='S'
			WHERE CONCEPTO=xCONCEPTO 
			AND MUNICIPIO=xAYTO;

		-- Controlar si la tarifa existe
		UPDATE TARIFAS_CONCEPTOS SET FORMULA=xFORMULA,
                                    FORMULAB=xFORMULAB,
                                    FORMULAC=xFORMULAC,
                                    FORMULAD=xFORMULAD,
                                    TIPO1=xVARA,
                                    TIPO2=xVARB,
                                    TIPO3=xVARC,
                                    TIPO4=xVARD,
                                    EXPLICACION=xEXPLI
		WHERE AYTO=xAYTO 
		AND CONCEPTO=xCONCEPTO
		AND TARIFA=xCodTarifa;

		IF SQL%NOTFOUND THEN

		   INSERT INTO TARIFAS_CONCEPTOS
			(AYTO,CONCEPTO,TARIFA,
			FORMULA,FORMULAB,FORMULAC,FORMULAD,
			TIPO1,TIPO2,TIPO3,TIPO4,EXPLICACION,
			TIPO_OBJETO, TIPO_TRIBUTO, CARACTER_TRIBUTO)

			SELECT MUNICIPIO,xCONCEPTO,xCodTarifa,
			xFORMULA,xFORMULAB,xFORMULAC,xFORMULAD,
			xVARA,xVARB,xVARC,xVARD,xEXPLI,
			xObjeto, xTributo, xOrigen

			FROM DATOSPER; 

		END IF;

	end if;

END IF;

END;
/
