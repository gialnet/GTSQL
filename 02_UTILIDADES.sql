
-- *******************************************************************************************
-- Acción: Copiar los conceptos de un municipio a otro
--Modificación: 18/09/2002 M. Carmen Junco Gómez. Repaso general al incorporar Tarifas_Conceptos
-- Modificacion: 04/11/2002 Lucas Fernández Pérez. Copia el campo TARIFAS y COMBINAR_TARIFAS.
-- *******************************************************************************************

CREATE OR REPLACE PROCEDURE COPIAR_CONCEPTOS(
	xAytoOrigen       IN CHAR,
	xAytoDestino	IN CHAR)
AS
   xCONCEPTO CHAR(6);
   xCONCEP   CHAR(6);

   -- cursor que recorre todos los conceptos del ayuntamiento de origen
   CURSOR c_Aytos IS SELECT * FROM CONTADOR_CONCEPTOS 
	               WHERE MUNICIPIO=xAytoOrigen;
   -- cursor que recorre las posible tarifas asociadas a cada uno de los conceptos
   CURSOR c_Tarifas IS SELECT * FROM TARIFAS_CONCEPTOS
			   WHERE AYTO=xAytoOrigen and CONCEPTO=xCONCEPTO
			   ORDER BY AYTO,CONCEPTO;

BEGIN


   FOR v_Ayto IN c_Aytos LOOP	

	xCONCEPTO:=v_Ayto.CONCEPTO;

	begin
	   SELECT CONCEPTO INTO xCONCEP FROM CONTADOR_CONCEPTOS 
	   WHERE MUNICIPIO=xAytoDestino AND CONCEPTO=xCONCEPTO;
	   Exception
		When no_data_found then
	      begin
		   INSERT INTO CONTADOR_CONCEPTOS
	           (MUNICIPIO,CONCEPTO,CONTADOR,DOCUMENTO,
		      FORMULA,FORMULAB,FORMULAC,FORMULAD,
		      TIPO1,TIPO2,TIPO3,TIPO4,EXPLICACION,
		      TIPO_OBJETO, TIPO_TRIBUTO, CARACTER_TRIBUTO,TARIFAS,COMBINAR_TARIFAS)
	         values (xAytoDestino,xCONCEPTO,v_Ayto.CONTADOR,v_Ayto.DOCUMENTO,
		      v_Ayto.FORMULA,v_Ayto.FORMULAB,v_Ayto.FORMULAC,v_Ayto.FORMULAD,
		      v_Ayto.TIPO1,v_Ayto.TIPO2,v_Ayto.TIPO3,v_Ayto.TIPO4,v_Ayto.EXPLICACION,
		      v_Ayto.TIPO_OBJETO, v_Ayto.TIPO_TRIBUTO, v_Ayto.CARACTER_TRIBUTO,
			v_Ayto.TARIFAS,v_Ayto.COMBINAR_TARIFAS);
		   
	   	   FOR v_Tarifas IN c_Tarifas
	         LOOP
	            INSERT INTO TARIFAS_CONCEPTOS 
				(CONCEPTO,AYTO,TARIFA,FTOTAL,
			       FRESULTADO,FORMULA,FORMULAB,FORMULAC,FORMULAD,TIPO1,TIPO2,TIPO3,TIPO4,
			       EXPLICACION,RECA1,RECA2,RECA3,RECA4,OBJETO1,OBJETO2,OBJETO3,OBJETO4,
			       DOCUMENTO,EXPLICACION2,COBRAR_DEMORA,MAXIMO,MINIMO,COD_TARIFA,TIPO_IVA)
		      VALUES (v_Tarifas.CONCEPTO,xAytoDestino,v_Tarifas.TARIFA,v_Tarifas.FTOTAL,
			       v_Tarifas.FRESULTADO,v_Tarifas.FORMULA,v_Tarifas.FORMULAB,
				 v_Tarifas.FORMULAC,v_Tarifas.FORMULAD,v_Tarifas.TIPO1,
				 v_Tarifas.TIPO2,v_Tarifas.TIPO3,v_Tarifas.TIPO4,
			       v_Tarifas.EXPLICACION,v_Tarifas.RECA1,v_Tarifas.RECA2,v_Tarifas.RECA3,
				 v_Tarifas.RECA4,v_Tarifas.OBJETO1,v_Tarifas.OBJETO2,v_Tarifas.OBJETO3,
				 v_Tarifas.OBJETO4,v_Tarifas.DOCUMENTO,v_Tarifas.EXPLICACION2,
				 v_Tarifas.COBRAR_DEMORA,v_Tarifas.MAXIMO,v_Tarifas.MINIMO,
				 v_Tarifas.COD_TARIFA,v_Tarifas.TIPO_IVA);
	         END LOOP;		
	      end;
	end;		

   END LOOP;

END;
/

/********************************************************************************************
Acción: Añadir o modificar un concepto base
********************************************************************************************/

CREATE OR REPLACE PROCEDURE ADDMODCONCEPTOBASE(
	xCONCEPTO 		IN CHAR,
	xDESCRIP 		IN CHAR)
AS
BEGIN

   UPDATE CONCEPTOS SET DESCRIPCION=xDESCRIP
   WHERE CONCEPTO=xCONCEPTO;

   -- si no existe el concepto lo insertamos en la tabla 
   IF SQL%NOTFOUND THEN
      INSERT INTO CONCEPTOS (CONCEPTO, DESCRIPCION)
      VALUES (xCONCEPTO, xDESCRIP);

      --Inicialmente se COPIAN A TODOS LOS MUNICIPIOS
	INSERT INTO CONTADOR_CONCEPTOS (MUNICIPIO,CONCEPTO)
	SELECT MUNICIPIO,xCONCEPTO FROM DATOSPER;

   END IF;

END;
/

-- ****************************************************************************************
-- Acción: Añadir o modificar un contador de conceptos. Si se da de alta el concepto, se dará
--        de alta para todos los municipios.
-- MODIFICACIÓN: 02/07/2002 Antonio Pérez Caballero.
--		  xTarifa indica si tiene multiples tarifas o no; posibles valores ('S','N')
--		  xCodTarifa código alfanumerico de la tarifa
-- MODIFICACIÓN: 08/07/2002 Mª Carmen Junco Gómez.
--		  En el caso de que el concepto posea tarifas, las fórmulas se darán de alta
--		  para la tarifa, pero no en la tabla contador_conceptos.
-- MODIFICACIÓN: 23/07/2002 Mª Carmen Junco Gómez.
--		  Separamos la inserción de las modificaciones. Cuando insertamos un nuevo 
--		  concepto este se dará de alta para todos los municipios, al igual que
--		  la posible fórmula inicial, pero la creación de tarifas se hará sólo 
--		  desde la opción de modificación del concepto.
-- MODIFICACIÓN: 09/09/2002 Antonio Pérez Caballero.
--	Se añaden los campos mínimo y máximo a petición de Javier Romeo Torrejón de Ardoz
-- MODIFICACIÓN: 04/11/2002 Lucas Fernández Pérez. Inserta el nuevo campo COMBINAR_TARIFAS.
-- ******************************************************************************************

CREATE OR REPLACE PROCEDURE ADD_CONCEPTO(
	xCONCEPTO 		IN CHAR,
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
	xObjeto		IN char,
	xCombinarTarifas	IN char,
	xMinimo		IN FLOAT,
	xMaximo		IN FLOAT
)
AS

BEGIN

   -- Insertamos el concepto en la tabla 
   INSERT INTO CONCEPTOS (CONCEPTO, DESCRIPCION)
   VALUES (xCONCEPTO, xDESCRIP);

   -- Inicialmente se pondrá la misma fórmula para
   -- todos los municipios del concepto creado 
	
   INSERT INTO CONTADOR_CONCEPTOS
      (MUNICIPIO,CONCEPTO,CONTADOR,
      FORMULA,FORMULAB,FORMULAC,FORMULAD,
      TIPO1,TIPO2,TIPO3,TIPO4,EXPLICACION,
      TIPO_OBJETO,TIPO_TRIBUTO,CARACTER_TRIBUTO,COMBINAR_TARIFAS,MINIMO,MAXIMO)
   SELECT MUNICIPIO,xCONCEPTO,0,
      xFORMULA,xFORMULAB,xFORMULAC,xFORMULAD,
      xVARA,xVARB,xVARC,xVARD,xEXPLI,
      xObjeto, xTributo, xOrigen, xCombinarTarifas, xMinimo, xMaximo
   FROM DATOSPER;	

END;
/

-- ****************************************************************************************
-- Autor: 23/07/2002 Mª Carmen Junco Gómez
-- Acción: Modificar la descripción de un concepto, así como la posible fórmula asociada
--	  y tarifas (añadir o modificar tarifas). 
-- MODIFICACIÓN: 09/09/2002 Antonio Pérez Caballero.
--	Se añaden los campos mínimo y máximo a petición de Javier Romeo Torrejón de Ardoz
-- MODIFICACIÓN: 18/09/2002 M. Carmen Junco Gómez. Modificación de la tabla 
--	tarifas_conceptos añadiendo un código tarifa de cuatro dígitos y clave 
--	primaria de ayto,concepto y cod_tarifa.
-- MODIFICACIÓN: 04/11/2002 Lucas Fernández Pérez. Modifica el nuevo campo COMBINAR_TARIFAS.
-- ****************************************************************************************

CREATE OR REPLACE PROCEDURE MODIFY_CONCEPTO(
	xAYTO       	IN CHAR,
	xCONCEPTO 		IN CHAR,
	xCodTarifa		IN Char,
	xTarifa		IN Char,	
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
	xObjeto		IN char,
	xCombinarTarifas	IN char,
	xMinimo		IN FLOAT,
	xMaximo    		IN FLOAT,
	xTIPOIVA		IN FLOAT
)
AS
BEGIN

   -- modificamos la descripción del concepto para el código xConcepto
   UPDATE CONCEPTOS SET DESCRIPCION=xDESCRIP
   WHERE CONCEPTO=xCONCEPTO;

   -- si no tiene tarifas asociadas, modificamos sólo la tabla Contador_Conceptos
   IF (xTarifa is null) THEN
      -- Al modificar un concepto, el cambio en la 
      -- formula se contemplará en un municipio en concreto 
          
      UPDATE CONTADOR_CONCEPTOS SET TARIFAS='N',
						FORMULA=xFORMULA,
                                    FORMULAB=xFORMULAB,
                                    FORMULAC=xFORMULAC,
                                    FORMULAD=xFORMULAD,
                                    TIPO1=xVARA,
                                    TIPO2=xVARB,
                                    TIPO3=xVARC,
                                    TIPO4=xVARD,
						COMBINAR_TARIFAS=xCombinarTarifas,
					      MINIMO=xMINIMO,
					      MAXIMO=xMAXIMO,
                                    EXPLICACION=xEXPLI,
						TIPO_OBJETO=xObjeto,
						TIPO_TRIBUTO=xTributo, 
						CARACTER_TRIBUTO=xOrigen						
	WHERE MUNICIPIO=xAYTO 
	AND CONCEPTO=xCONCEPTO;

	-- borramos de la tabla Tarifas_Conceptos por si antes había
      DELETE FROM TARIFAS_CONCEPTOS WHERE AYTO=xAYTO AND CONCEPTO=xCONCEPTO;

   ELSE
   
      UPDATE CONTADOR_CONCEPTOS SET TARIFAS='S',
						FORMULA=NULL,
						FORMULAB=NULL,
						FORMULAC=NULL,
						FORMULAD=NULL,
                                    TIPO1=NULL,
                                    TIPO2=NULL,
                                    TIPO3=NULL,
                                    TIPO4=NULL,
						COMBINAR_TARIFAS=xCombinarTarifas,
					      MINIMO=0,
					      MAXIMO=0,
                                    EXPLICACION=NULL,
						TIPO_OBJETO=xOBJETO,
						TIPO_TRIBUTO=xTRIBUTO,
						CARACTER_TRIBUTO=xORIGEN					
	WHERE MUNICIPIO=xAYTO AND
		CONCEPTO=xCONCEPTO;

	-- Controlar si la tarifa existe
	UPDATE TARIFAS_CONCEPTOS SET TARIFA=xTARIFA,
					     FORMULA=xFORMULA,
                                   FORMULAB=xFORMULAB,
                                   FORMULAC=xFORMULAC,
                                   FORMULAD=xFORMULAD,
                                   TIPO1=xVARA,
                                   TIPO2=xVARB,
                                   TIPO3=xVARC,
                                   TIPO4=xVARD,
					     MINIMO=xMINIMO,
					     MAXIMO=xMAXIMO,
					     TIPO_IVA=DECODE(xORIGEN,'O',xTIPOIVA,0),
                                   EXPLICACION=xEXPLI				           
	WHERE AYTO=xAYTO 
	AND CONCEPTO=xCONCEPTO
	AND COD_TARIFA=xCodTarifa;

	IF SQL%NOTFOUND THEN
	   INSERT INTO TARIFAS_CONCEPTOS
	      (AYTO,CONCEPTO,TARIFA,FORMULA,FORMULAB,FORMULAC,FORMULAD,
		 TIPO1,TIPO2,TIPO3,TIPO4,EXPLICACION,MINIMO,MAXIMO,TIPO_IVA)
	   VALUES (xAYTO,xCONCEPTO,xTARIFA,xFORMULA,xFORMULAB,xFORMULAC,xFORMULAD,
	  	 xVARA,xVARB,xVARC,xVARD,xEXPLI,xMINIMO,xMAXIMO,
		 DECODE(xORIGEN,'O',xTIPOIVA,0));
	END IF;	

   END IF;

END;
/

/********************************************************************************************/

/* ASIGNAR LOS CONCEPTOS Y LAS LIQUIDACIONES A UN PROGRAMA */

CREATE OR REPLACE PROCEDURE ASIGNARCONCEPTOS(
	xConcepto IN CHAR,
	xLiquidacion IN CHAR,
	xPrograma IN CHAR)
AS
BEGIN


UPDATE PROGRAMAS SET CONCEPTO=xConcepto, LIQUIDACION=xLiquidacion
	WHERE PROGRAMA=xPrograma;

END;
/


/* COMPROBAR SI EXISTEN DATOS EN RECAUDACION ANTES DE PASARLOS */ 

CREATE OR REPLACE PROCEDURE EXISTEN_DATOS_ENRECA (
	xAYTO 		IN	CHAR,
	xYEAR 		IN	CHAR,
	xPERIODO 		IN	CHAR,
	xPROGRAMA         IN    CHAR,
	xORDENANZA		IN 	CHAR,
	xCUANTOS		OUT INTEGER)
AS
xPADRON CHAR(6);
BEGIN

xCUANTOS:=0;

--Cuando se compruebe padrones de impuestos o de exacciones
IF xORDENANZA='' OR xORDENANZA IS NULL THEN
	SELECT CONCEPTO INTO xPADRON FROM PROGRAMAS WHERE PROGRAMA=xPROGRAMA;

	SELECT COUNT(*) INTO xCUANTOS FROM PUNTEO
		WHERE AYTO=xAYTO AND PADRON=xPADRON 
			AND YEAR=xYEAR AND PERIODO=xPERIODO 
			AND TIPO_DE_OBJETO='R';
ELSE
	SELECT COUNT(*) INTO xCUANTOS FROM PUNTEO
		WHERE AYTO=xAYTO AND PADRON=xORDENANZA
			AND YEAR=xYEAR AND PERIODO=xPERIODO 
			AND TIPO_DE_OBJETO='R';
END IF;

END;
/
