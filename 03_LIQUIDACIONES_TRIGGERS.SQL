/* ***********************************************************************************
modificación: 04/09/2001 Antonio Pérez Caballero
modificación: 29/05/2002 Antonio Pérez Caballero
              se pasaba la fecha de cargo como nulo ahora se pasa con sysdate
modificacion: 27/09/2002 Agustin Leon Robles
              solo se pasa a recaudacion las liquidaciones mayores de 0.
modificación: 15/01/2003 Mª Carmen Junco Gómez. Se estaba pasando '00' como 
              periodo para todas las liquidaciones.
MODIFICACION: 21/03/2003. Agustín León Robles. En vez de utilizar el final del periodo 
              voluntario se utiliza la fecha juliana. El final del periodo voluntario se 
              calculará con los acuses de recibo o con la fecha de publicación en el BOP.
MODIFICACIÓN: 02/04/2003 M. Carmen Junco Gómez. No se estaba indicando que estaba la
			  liquidación pasada a Recaudación PASADO='S' en el caso de pase 
			  automático.
Modificación: 05/11/2003. Agustín León Robles. La fecha de vencimiento se calcula con la
			  fecha de emision de la diligencias más los dias de la configuracion. De
			  esta manera evitamos que al final del año el campo digito_year tenga un 
			  valor correcto
Modificación: 05/02/2004. Gloria María Calle Hernández. Se inserta la fecha de cargo en la 
			  misma tabla donde se inserta el numero de cargo (DatoPerr) para poder especificar
			  dicha fecha el usuario. Entonces cambiada llamada al procedimiento InsertaValores
			  que ahora al ser llamado pasa la fecha de cargo especificada.
Modificación: 08/08/2006. Lucas Fernández Pérez. El tipo de Objeto del valor se toma de 
				contador_conceptos, porque puede ser 'A' ó 'L'
*************************************************************************************/

--
-- Para actualizar en Baza hay que quitar la linea IF xPASE='S' AND :NEW.IMPORTE>0 THEN y dejarla en
--   IF xPASE='S' THEN
--
CREATE OR REPLACE TRIGGER T_INS_LIQUIDACIONES
BEFORE INSERT ON LIQUIDACIONES
FOR EACH ROW
DECLARE
	xEMISOR 		CHAR(6);
	xTRIBUTO		CHAR(3);
	xDIG_C60_M2    	CHAR(2);
	xREFERENCIA 	CHAR(10);
	xIMPCADENA     	CHAR(12);

	xPASE 			CHAR(1);
	xNOTI    		CHAR(1);
	xNCARGO			CHAR(10);
	xFCARGO			DATE;
	xNOMBRE  		VARCHAR(40);
	xVALOR			INT;
	xFVencimiento	date;
	xDias			integer;
	xDiaSemana 		varchar2(15);
	xTipoObjeto     char(1);
BEGIN

  SELECT GENLIQUI.NEXTVAL INTO :NEW.ID FROM DUAL;


  --la fecha de vencimimiento de pago en banco se insertara cuando damos de alta una liq.
  --si se va a dar por pagado a traves del cuaderno 60 modalidad 2 y 3

  IF :NEW.F_JULIANA IS NOT NULL THEN

	BEGIN
	  select EMISORA,CONCEPTO_BANCO into xEMISOR,xTRIBUTO from RELA_APLI_BANCOS
		where AYTO=:NEW.MUNICIPIO and CONCEPTO=:NEW.CONCEPTO;
	EXCEPTION
		when no_data_found then
		BEGIN
			xEMISOR:='000000';
			xTRIBUTO:='000';
		END;
	END;


	select dias_vencimiento into xDias from datosper where municipio=:NEW.MUNICIPIO;


	--la fecha de vencimiento del pago en el banco sera hoy mas los dias que se le de por
	--configuracion, en el caso de que el resultado de la suma fuera sabado o domingo se pasaría a
	--lunes
	select to_char(:NEW.F_LIQUIDACION+xDias,'Day') into xDiaSemana from Dual;

	--SABADO
	if Upper(RTRIM(xDiaSemana)) in ('SÁBADO','SABADO','SATURDAY') then
		xFVencimiento:=trunc(:NEW.F_LIQUIDACION,'DD')+xDias+2;
	--DOMINGO
	elsif Upper(RTRIM(xDiaSemana)) IN ('DOMINGO','SUNDAY') then
		xFVencimiento:=trunc(:NEW.F_LIQUIDACION,'DD')+xDias+1;
	else
		xFVencimiento:=trunc(:NEW.F_LIQUIDACION,'DD')+xDias;
	end if;


	--calcular los digitos de control del cuaderno 60 modalidad 2
	CALCULA_DC_MODALIDAD2_60(:NEW.IMPORTE, :NEW.ID, xTRIBUTO, SUBSTR(:NEW.YEAR,3,2), '1',
				to_char(xFVencimiento,'y'), to_char(xFVencimiento,'ddd'),
				xEMISOR, xDIG_C60_M2);

	xDIG_C60_M2:=SUBSTR(xDIG_C60_M2,1,2);

	--CONVIERTE NºABONADO EN CARACTER Y RELLENO DE CEROS
	GETREFERENCIA(:NEW.ID, xREFERENCIA);

	--CONVIERTE EL IMPORTE RELLENO DE CEROS
	IMPORTEENCADENA(:NEW.IMPORTE, xIMPCADENA);

	:NEW.EMISOR:=xEMISOR;

	:NEW.TRIBUTO:=xTRIBUTO;

	:NEW.EJER_C60:=SUBSTR(:NEW.YEAR,3,2);

	:NEW.REFERENCIA:=xREFERENCIA;

	:NEW.IMP_CADENA:=xIMPCADENA;

	:NEW.DISCRI_PERIODO:='1';

	:NEW.DIGITO_YEAR:=to_char(xFVencimiento,'y');

	:NEW.DIGITO_C60_MODALIDAD2:=xDIG_C60_M2;

	:NEW.FVENCIMIENTO:=xFVencimiento;

  END IF;


  BEGIN
     SELECT PASE_AUTOMATICO,NCARGO,FCARGO INTO xPASE,xNCARGO,xFCARGO
     FROM DATOSPERR WHERE EMPRESA IS NOT NULL;
     EXCEPTION
        when no_data_found then
	   xPASE:='N';
  END;

  --las exentas de pago o liquidaciones con importes negativos no pasan a recaudacion
  IF xPASE='S' AND :NEW.IMPORTE>0 THEN

			-- NOMBRE DEL DEUDOR
	SELECT NOMBRE INTO xNOMBRE FROM CONTRIBUYENTES WHERE NIF=:NEW.NIF;

	IF :NEW.F_NOTIFICACION IS NULL THEN
	   	xNOTI:='N';
	ELSE
	   	xNOTI:='S';
	END IF;

	BEGIN
	  select TIPO_OBJETO INTO xTipoObjeto from CONTADOR_CONCEPTOS
		where MUNICIPIO=:NEW.MUNICIPIO and CONCEPTO=:NEW.CONCEPTO;
	EXCEPTION
		when no_data_found then
		BEGIN
			xTipoObjeto:='L';
		END;
	END;

	INSERTAVALORES(:NEW.CONCEPTO,:NEW.YEAR,:NEW.PERIODO,TO_NUMBER(:NEW.NUMERO),:NEW.NIF,
	   xNOMBRE,xFCARGO,xNCARGO,:NEW.MUNICIPIO,:NEW.F_NOTIFICACION,NULL,
	   :NEW.F_NOTIFICACION,xNOTI,NULL,:NEW.DOMI_TRIBUTARIO,NULL,xTipoObjeto,
	   :NEW.MOTIVO,:NEW.CONTRAIDO,:NEW.IMPORTE,:NEW.IMPORTE,0,0,0,'V',
	   NULL,'N',:NEW.EXPEDIENTE,:NEW.ID,xVALOR);

    -- Asignamos la relación unívoca entre recaudación y valores
    :NEW.IDVALOR:=xVALOR;
    :NEW.NUMERO_DE_CARGO:=xNCARGO;
    :NEW.F_CARGO:=xFCARGO;
    :NEW.PASADO:='S';

  END IF;

END;
/


/*******************************************************************************
AUTOR: Mª del Carmen Junco Gómez.
FECHA: 8/11/2001
ACCIÓN: Si una liquidación se modifica para quitarle los cotitulares, habrá que
	  borrar estos de la tabla COTITULARES.
MODIFICACION: 21/03/2003. Agustín León Robles. En vez de utilizar el final del periodo voluntario 
				se utiliza la fecha juliana. El final del periodo voluntario se calculará con los
				acuses de recibo o con la fecha de publicación en el BOP
Modificación: 05/11/2003. Agustín León Robles.				
				El campo DIGITO_YEAR se actualiza desde el procedimiento LIQUI_CAMBIA_FECHAFIN
Modificación: 18/03/2006. Error al convertir 366 (ultimo día de año bisiesto, por ejemplo: 31/12/2004) 
		cuando no estamos en año bisiesto. 
*******************************************************************************/
CREATE OR REPLACE TRIGGER T_UPD_LIQUIDACIONES
BEFORE UPDATE ON LIQUIDACIONES
FOR EACH ROW
DECLARE
	xEMISOR 		CHAR(6);
	xTRIBUTO		CHAR(3);
	xDIG_C60_M2    	CHAR(2);
	xREFERENCIA 	CHAR(10);
	xIMPCADENA     	CHAR(12);
	xFVencimiento	date;
	CURSOR CCOTITULARES IS SELECT ID FROM COTITULARES
				  WHERE PROGRAMA='LIQUIDACIO' AND ID_CONCEPTO=:NEW.ID;
BEGIN
   IF ((:NEW.COTITULARES<>:OLD.COTITULARES) AND (:NEW.COTITULARES='N')) THEN
		FOR v_COTI IN CCOTITULARES LOOP
			DELETE FROM COTITULARES WHERE ID=v_COTI.ID;
		END LOOP;
   END IF;
   IF (:OLD.F_JULIANA IS NULL AND :NEW.F_JULIANA IS NOT NULL) OR
		(:OLD.F_JULIANA IS NOT NULL AND :NEW.F_JULIANA IS NOT NULL) THEN
		BEGIN
			select EMISORA,CONCEPTO_BANCO into xEMISOR,xTRIBUTO from RELA_APLI_BANCOS
			Where AYTO=:NEW.MUNICIPIO and CONCEPTO=:NEW.CONCEPTO;
		EXCEPTION
			when no_data_found then
				BEGIN
					xEMISOR:='000000';
					xTRIBUTO:='000';
				END;
		END;
		--Error al convertir 366 (ultimo día de año bisiesto, por ejemplo: 31/12/2004) cuando no estamos en año bisiesto. 
		BEGIN
		     xFVencimiento:=to_date(:NEW.F_JULIANA,'ddd');
		EXCEPTION
		     WHEN OTHERS THEN
			      xFVencimiento:=to_date(:NEW.F_JULIANA-1,'ddd');
		END;
		
		CALCULA_DC_MODALIDAD2_60(:NEW.IMPORTE, :NEW.ID, xTRIBUTO, SUBSTR(:NEW.YEAR,3,2), '1',
				:NEW.DIGITO_YEAR, to_char(xFVencimiento,'ddd'),
				xEMISOR, xDIG_C60_M2);
				
		xDIG_C60_M2:=SUBSTR(xDIG_C60_M2,1,2);
		GETREFERENCIA(:NEW.ID, xREFERENCIA);
		IMPORTEENCADENA(:NEW.IMPORTE, xIMPCADENA);
    	:NEW.EMISOR:=xEMISOR;
    	:NEW.TRIBUTO:=xTRIBUTO;
    	:NEW.EJER_C60:=SUBSTR(:NEW.YEAR,3,2);
    	:NEW.REFERENCIA:=xREFERENCIA;
    	:NEW.IMP_CADENA:=xIMPCADENA;
		:NEW.DISCRI_PERIODO:='1';
		:NEW.DIGITO_C60_MODALIDAD2:=xDIG_C60_M2;
	ELSE
		IF (:OLD.F_JULIANA IS NOT NULL AND :NEW.F_JULIANA IS NULL) THEN
			:NEW.EMISOR:='000000';
			:NEW.TRIBUTO:='000';
			:NEW.EJER_C60:=NULL;
			:NEW.REFERENCIA:=NULL;
			:NEW.IMP_CADENA:='0';
			:NEW.DISCRI_PERIODO:=NULL;
			:NEW.DIGITO_YEAR:=NULL;
			:NEW.F_JULIANA:=NULL;
			:NEW.DIGITO_C60_MODALIDAD2:=NULL;
			:NEW.FVENCIMIENTO:=NULL;
		END IF;
   END IF;
END;
/

/*******************************************************************************
AUTOR:  06/05/2003 M. del Carmen Junco Gómez.
ACCIÓN: Antes de borrar una liquidación hay que comprobar si tiene valor asociado o no
MODIFICADO: 09/05/2006 Lucas Fernández Pérez. xPRINCIPAL estaba definido como INTEGER,
   por lo que al borrar una liquidación el cargo no lo deja bien ajustado.
*******************************************************************************/

CREATE OR REPLACE TRIGGER T_DEL_LIQUIDACIONES
BEFORE DELETE ON LIQUIDACIONES
FOR EACH ROW

DECLARE

   xAYTO 		    CHAR(3);
   xPADRON 			CHAR(6);
   xYEAR 			CHAR(4);
   xPERIODO			CHAR(2);
   xTIPO_DE_OBJETO 	CHAR(1);
   xYEAR_CONTRAIDO	CHAR(4);      
   xCARGO 			CHAR(10);
   xPRINCIPAL		FLOAT;
   xID_DESGLOSE		INTEGER;
   xCUANTOS			INTEGER;
   
BEGIN
   --antes de borrar la liquidación hay que borrar el valor asociado
   --(si lo tuviese)  
   
   IF (:OLD.IDVALOR IS NOT NULL) THEN
   
      SELECT AYTO,PADRON,YEAR,PERIODO,TIPO_DE_OBJETO,YEAR_CONTRAIDO,N_CARGO,PRINCIPAL
      INTO xAYTO,xPADRON,xYEAR,xPERIODO,xTIPO_DE_OBJETO,xYEAR_CONTRAIDO,xCARGO,xPRINCIPAL 
      FROM VALORES WHERE ID=:OLD.IDVALOR;
      
   	UPDATE DESGLOSE_CARGOS SET RECIBOS=RECIBOS-1,
   	  							 TOTAL_CARGO=TOTAL_CARGO-xPRINCIPAL
	   WHERE AYTO=xAYTO AND CARGO=xCARGO AND PADRON=xPADRON AND YEAR=xYEAR AND
	  		PERIODO=xPERIODO AND TIPO_DE_OBJETO=xTIPO_DE_OBJETO AND 
	  		YEAR_CONTRAIDO=xYEAR_CONTRAIDO
	   RETURNING ID,RECIBOS INTO xID_DESGLOSE,xCUANTOS;
	  		
	  IF SQL%FOUND THEN	  	
	  	IF xCUANTOS=0 THEN
	  		DELETE FROM DESGLOSE_CARGOS WHERE ID=xID_DESGLOSE;
	  	END IF;
	  END IF;
	  
	  UPDATE CARGOS SET RECIBOS=RECIBOS-1,
	  				    TOTAL_CARGO=TOTAL_CARGO-xPRINCIPAL
	  WHERE AYTO=xAYTO AND CARGO=xCARGO;
	  
	  DELETE FROM VALORES WHERE ID=:OLD.IDVALOR;	  				    
      
   END IF;
   
   DELETE FROM HISTORIA_LIQUI WHERE LIQUI=:OLD.ID;   
   
END;
/

