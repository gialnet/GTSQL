/********************************************************************************
Acción: Insertar en historia de las liquidaciones. 
********************************************************************************/

CREATE OR REPLACE PROCEDURE INSERT_HISTORIA_LIQUI
	(xID		IN	INTEGER,
	xTipo		IN	CHAR,
	xTexto	IN 	CHAR)
AS
BEGIN
	INSERT INTO HISTORIA_LIQUI
		(LIQUI,TIPO_DATA,EXPLICACION,FECHA,USUARIO)
	VALUES
		(xID,xTipo,xTexto,SYSDATE,USER);

END;
/


/********************************************************************************
Acción: Aumentar el contador en una unidad antes de generar una nueva liquidación.
MODIFICACIÓN: 04/09/2001 Antonio Pérez Caballero.
********************************************************************************/

CREATE OR REPLACE PROCEDURE CALCULO_CONTADOR_CONCEPTOS(
	 xMUNICIPIO   IN CHAR,
       xCON 	  IN CHAR,
       xNUMERO 	  OUT CHAR)
AS
	xCONTADOR INTEGER;
BEGIN

	UPDATE CONTADOR_CONCEPTOS SET CONTADOR=CONTADOR+1
		WHERE CONCEPTO=xCON AND MUNICIPIO=xMUNICIPIO
		RETURNING CONTADOR INTO xCONTADOR;

	xNUMERO:=LPAD(xCONTADOR,7,'0');

END;
/

/********************************************************************************
Acción: Añadir una nueva liquidación.
MODIFICACIÓN: 22/08/2001 Antonio Pérez Caballero
MODIFICACIÓN: 04/09/2001 Antonio Pérez Caballero
MODIFICACIÓN: 10/09/2001 M. Carmen Junco Gómez. Adaptación al euro.
MODIFICACIÓN: 13/05/2002 M. Carmen Junco Gómez. Inserción del periodo en las liquidaciones.
MODIFICACION: 05/11/2002 Lucas Fernández Pérez. Adjunta a la liquidación la combinación de 
								tarifas que pueda tener.
MODIFICACION: 21/03/2003. Agustín León Robles. En vez de utilizar el final del periodo voluntario 
				se utiliza la fecha juliana. El final del periodo voluntario se calculará con los
				acuses de recibo o con la fecha de publicación en el BOP
MODIFICACIÓN: 15/05/2006. M. Carmen Junco Gómez. Adaptación al nuevo formato de RUSTICA.
********************************************************************************/

CREATE OR REPLACE PROCEDURE ADD_LIQUI(
     xMUNICIPIO 		IN CHAR,
     xCON 				IN CHAR,
     xYEAR 				IN CHAR,
	  xPERIODO			IN CHAR,
	  xContraido		IN CHAR,
     xNIF 				IN CHAR,
     xNIFREP 			IN CHAR,
     xDOMI 				IN CHAR,
     xFECHA_LIQUI 	IN DATE,
	  xF_FIN_PE_VOL	IN DATE,
     xIMPORTE 			IN FLOAT,
     xMOTIVO 			IN VARCHAR2,
	  xREF_CAT 			IN CHAR,
     xNUM_FIJO 		IN CHAR,	 
     xEXPE 				IN CHAR,
	  xIDAlternativo 	IN INTEGER,
	  xIDLiqui			IN INTEGER,
     xNUMERO 			OUT CHAR, 
	  xID 		    	OUT INTEGER)
AS
	xExpeAux		char(15);
	xRefCatAux	char(20);
	xFijoAux		char(8);
	xTOTAL		float;
	xNUM			CHAR(7);
	xCombinaTarifas	CHAR(1);
	xTipoObjeto		CHAR(1);
BEGIN

	-- Aumentar el contador de conceptos
	CALCULO_CONTADOR_CONCEPTOS(xMUNICIPIO,xCON,xNUM);
	xNUMERO:=xNUM;

	xExpeAux:=SUBSTR(xEXPE,1,15);
	IF xExpeAux is null THEN
   	xExpeAux:=xNUM;
	END IF;

	xRefCatAux:=xREF_CAT;
	IF xRefCatAux='' THEN
		xRefCatAux:=NULL;
	END IF;

	xFijoAux:=xNUM_FIJO;
	IF xFijoAux='' THEN
		xFijoAux:=NULL;
	END IF;


	xTOTAL:=ROUND(xIMPORTE, 2);
	INSERT INTO LIQUIDACIONES
		(MUNICIPIO,NUMERO,CONCEPTO,YEAR,PERIODO,NIF,NIFREP,DOMI_TRIBUTARIO,
		F_LIQUIDACION,IMPORTE,MOTIVO,EXPEDIENTE,REF_CATASTRAL,NUM_FIJO,
		IDDOMIALTER,CONTRAIDO,F_JULIANA,IDLIQUI)
	VALUES
		(xMUNICIPIO,xNUM,xCON,xYEAR,xPERIODO,xNIF,xNIFREP,xDOMI,xFECHA_LIQUI,
		xTOTAL,xMOTIVO,xExpeAux,xREF_CAT,xNUM_FIJO,DECODE(xIDAlternativo,0,NULL,xIDAlternativo),
		xCONTRAIDO,DECODE(TO_CHAR(xF_FIN_PE_VOL,'YYYY'),'1899', NULL, TO_CHAR(xF_FIN_PE_VOL,'ddd')),
		DECODE(xIDLIQUI,0,NULL,xIDLIQUI) )
	RETURNING ID INTO xID;

	-- Si el concepto tiene combinación de tarifas, éstas están en la tabla tarifas_combinadas
	-- con idliqui=0 y usuario=user porque todavia no se sabía. Ahora se actualiza el IDLIQUI.
	SELECT COMBINAR_TARIFAS,TIPO_OBJETO INTO xCombinaTarifas,xTipoObjeto
	FROM CONTADOR_CONCEPTOS	WHERE MUNICIPIO=xMUNICIPIO AND CONCEPTO=xCON;
	IF ((xCombinaTarifas='S') and (xTipoObjeto='L')) THEN
		UPDATE TARIFAS_COMBINADAS SET IDLIQUI=xID WHERE IDLIQUI=0 AND USUARIO=USER;
	END IF;

	INSERT_HISTORIA_LIQUI(xID,'A','SE AÑADE LA LIQUIDACION');

END;
/	


-- ****************************************************************************************
--Acción: Anular una liquidación.
-- ****************************************************************************************
-- Modificado: 04/09/2003. Lucas Fernández Pérez. Se añade el parámetro xCausa con la 
-- causa de la baja/reposición. Antes ponía siempre SE ANULA ó "SE QUITA ANULACION".
--
CREATE OR REPLACE PROCEDURE ANULAR_LIQUI(
       xID 		IN INTEGER,
       xFECHA 	IN DATE,
       xCAUSA 	IN CHAR,
       xGRUPO 	IN INTEGER)
AS
   xFANU        DATE;
   xFDES	    DATE;
   xPASADO      CHAR(1);
BEGIN

   SELECT F_ANULACION,F_DESCUBIERTO,PASADO 
   INTO xFANU,xFDES,xPASADO
   FROM LIQUIDACIONES WHERE ID=xID;

   /* si en descubierto y pasado a recaudación no se puede anular */
   IF ((xFDES IS NOT NULL AND xPASADO='N') OR (xFDES IS NULL)) THEN
      
      UPDATE LIQUIDACIONES SET F_DESCUBIERTO=NULL WHERE ID=xID;

      IF xGRUPO=0 THEN
         IF xFANU IS NULL THEN
		UPDATE LIQUIDACIONES SET F_ANULACION=xFECHA
		WHERE ID=xID AND F_INGRESO IS NULL AND F_ANULACION IS NULL;

		INSERT_HISTORIA_LIQUI(xID,'P',xCausa);
         ELSE
		UPDATE LIQUIDACIONES SET F_ANULACION=NULL
		WHERE ID=xID AND F_INGRESO IS NULL AND F_ANULACION IS NOT NULL;

		INSERT_HISTORIA_LIQUI(xID,'U',xCausa);
	   END IF;
      ELSE
         IF xFANU IS NULL THEN
 
	      /* con un insert y un select introducimos todos los registros a la vez*/
	      INSERT INTO HISTORIA_LIQUI (LIQUI,TIPO_DATA,EXPLICACION,FECHA,USUARIO)
	      SELECT ID,'P',xCausa,SYSDATE,USER FROM LIQUIDACIONES
	      WHERE GRUPO=xGRUPO AND F_INGRESO IS NULL AND F_ANULACION IS NULL;

	      UPDATE LIQUIDACIONES SET F_ANULACION=xFECHA
	      WHERE GRUPO=xGRUPO AND F_INGRESO IS NULL AND F_ANULACION IS NULL;
         ELSE

	      /* con un insert y un select introducimos todos los registros a la vez*/
	      INSERT INTO HISTORIA_LIQUI
               (LIQUI,TIPO_DATA,EXPLICACION,FECHA,USUARIO)
	         SELECT ID,'U',xCausa,SYSDATE,USER FROM LIQUIDACIONES
		   WHERE GRUPO=xGRUPO AND F_INGRESO IS NULL AND F_ANULACION IS NOT NULL;
		
	      UPDATE LIQUIDACIONES SET F_ANULACION=NULL
	      WHERE GRUPO=xGRUPO AND F_INGRESO IS NULL AND F_ANULACION IS NOT NULL;
         END IF;
      END IF;
   END IF;
END;
/

/********************************************************************************
Acción: Asignar año de contraido.
********************************************************************************/

CREATE OR REPLACE PROCEDURE ASIGNA_CONTRAIDO(
       xID 			IN INTEGER,
       xGRUPO 		IN INTEGER,
       xCONTRAIDO 	IN CHAR)
AS
BEGIN
   IF xID<>0 THEN
      UPDATE LIQUIDACIONES SET CONTRAIDO=xCONTRAIDO WHERE ID=xID;
   ELSE
      IF xGRUPO<>0 THEN
         UPDATE LIQUIDACIONES SET CONTRAIDO=xCONTRAIDO WHERE GRUPO=xGRUPO;
      END IF;
   END IF;
END;
/

/********************************************************************************
Acción: Crear, pegar o quitar una liquidación de un grupo de liquidaciones.
********************************************************************************/

CREATE OR REPLACE PROCEDURE CREA_PEGA_GRUPO_LIQUI(
       xID 			IN INTEGER,
       xTIPO 		IN CHAR,
       xGRUPO 		IN OUT INTEGER)
AS
BEGIN

   if xTipo='C' then
	ADD_COD_OPERACION(xGRUPO);
      UPDATE LIQUIDACIONES SET GRUPO=xGRUPO WHERE ID=xID;
   END IF;

   if xTipo='P' then
      UPDATE LIQUIDACIONES SET GRUPO=xGRUPO WHERE ID=xID;
   END IF;

   if xTipo='Q' then
      UPDATE LIQUIDACIONES SET GRUPO=0 WHERE ID=xID;
   END IF;

END;
/

/********************************************************************************
Autor: Antonio Pérez Caballero.
Fecha: 23/08/2001
Acción: Escribir en el punteo los datos de las liquidaciones.
MODIFICACIÓN: 05/11/2002 M. Carmen Junco Gómez. No se está pasando el periodo, y 
		  es necesario para las liquidaciones trimestrales del IAE.
********************************************************************************/

CREATE OR REPLACE PROCEDURE WRITE_LIQUI_PUNTEO(
	v_Liqui IN LIQUIDACIONES%ROWTYPE,
	xFECHA IN DATE,
	xN_CARGO IN CHAR,
	xSALTO IN CHAR)
AS
	xNOMBRE		VARCHAR2(40);
	xOBJ_TRIBUTARIO   VARCHAR2(1024);
	xTIPO_TRIBUTO	CHAR(2);
BEGIN

	SELECT TIPO_TRIBUTO INTO xTIPO_TRIBUTO
 	FROM CONTADOR_CONCEPTOS
	WHERE MUNICIPIO=v_Liqui.MUNICIPIO AND CONCEPTO=v_Liqui.CONCEPTO;

	SELECT NOMBRE INTO xNOMBRE FROM CONTRIBUYENTES WHERE NIF=v_Liqui.NIF;

	xOBJ_TRIBUTARIO:='LIQUIDACION Nº: '|| v_Liqui.NUMERO ||xSALTO;

	xOBJ_TRIBUTARIO:=xOBJ_TRIBUTARIO||'F. LIQUIDACION: '|| 
		to_char(v_Liqui.F_LIQUIDACION,'dd-mm-yyyy')||xSALTO;

	IF v_Liqui.F_NOTIFICACION IS NOT NULL THEN
         xOBJ_TRIBUTARIO:=xOBJ_TRIBUTARIO||'F.NOTIFICACION: ' ||
		to_char(v_Liqui.F_NOTIFICACION, 'dd-mm-yyyy') || xSALTO;
	END IF;

	IF v_Liqui.MOTIVO IS NOT NULL THEN
         xOBJ_TRIBUTARIO:=xOBJ_TRIBUTARIO||'MOTIVO: '||RTRIM(v_Liqui.MOTIVO)||xSALTO;
	END IF;

	IF v_Liqui.DOMI_TRIBUTARIO<>'' THEN
         xOBJ_TRIBUTARIO:=xOBJ_TRIBUTARIO || 'DOMICILIO TRIBUTARIO: '||
                           v_Liqui.DOMI_TRIBUTARIO || xSALTO;
	END IF;


	INSERT INTO PUNTEO
		(AYTO, PADRON, YEAR, PERIODO, RECIBO, NIF, NOMBRE, YEAR_CONTRAIDO,COTITULARES,
		CLAVE_CONCEPTO,CLAVE_RECIBO,
		VOL_EJE, F_CARGO, N_CARGO, INI_PE_VOL, FIN_PE_VOL,TIPO_DE_TRIBUTO,
		CUOTA_INICIAL, PRINCIPAL, OBJETO_TRIBUTARIO, TIPO_DE_OBJETO, DOM_TRIBUTARIO)
	VALUES
		(v_Liqui.MUNICIPIO, v_Liqui.CONCEPTO, v_Liqui.YEAR, v_Liqui.PERIODO,
		TO_NUMBER(v_Liqui.NUMERO), v_Liqui.NIF, xNOMBRE, v_Liqui.CONTRAIDO,
		v_Liqui.COTITULARES, v_Liqui.EXPEDIENTE,v_Liqui.ID,
		DECODE(v_Liqui.F_DESCUBIERTO,NULL, 'V', 'E'), xFECHA, xN_CARGO, 
		v_Liqui.F_NOTIFICACION, v_Liqui.F_FIN_PE_VOL, xTIPO_TRIBUTO,
		v_Liqui.IMPORTE, v_Liqui.IMPORTE, xOBJ_TRIBUTARIO, 'L', v_Liqui.DOMI_TRIBUTARIO);


	INSERT_HISTORIA_LIQUI(v_Liqui.ID,'X','SE PASA A RECAUDACION, CARGO:' || xN_CARGO);


END;
/

/********************************************************************************
Acción: Pasar liquidaciones directas a Recaudación.
MODIFICACIÓN: 23/08/2001 Antonio Pérez Caballero. 
		  Si Grupo > 0 indica que se quiere pasar un grupo de liquidaciones.
		  Si xConcepto <> '' indica que se quiere pasar un solo concepto.
********************************************************************************/

CREATE OR REPLACE PROCEDURE LIQUI_PASE_RECA(
		xGRUPO 		IN INTEGER,
		xFECHA 		IN DATE,
		xN_CARGO 	IN CHAR,
		xCONCEPTO 	IN CHAR,
		xVOL_EJE 	IN CHAR)
AS

xSALTO            CHAR(2);

CURSOR cLIQUIGrVol IS 
	SELECT * FROM LIQUIDACIONES 
	WHERE GRUPO=xGRUPO AND IMPORTE > 0
	AND F_INGRESO IS NULL
      AND F_ANULACION IS NULL
      AND F_SUSPENSION IS NULL
	AND F_DESCUBIERTO IS NULL
	AND PASADO<>'S'
	FOR UPDATE OF PASADO,NUMERO_DE_CARGO,F_CARGO;

CURSOR cLIQUIGrEje IS 
	SELECT * FROM LIQUIDACIONES 
	WHERE GRUPO=xGRUPO AND IMPORTE > 0
	AND F_INGRESO IS NULL
      AND F_ANULACION IS NULL
      AND F_SUSPENSION IS NULL
	AND F_DESCUBIERTO IS NOT NULL
	AND PASADO<>'S'
	FOR UPDATE OF PASADO,NUMERO_DE_CARGO,F_CARGO;

CURSOR cLIQUIConVol IS 
	SELECT * FROM LIQUIDACIONES 
	WHERE CONCEPTO=xCONCEPTO AND IMPORTE > 0
	AND F_INGRESO IS NULL
      AND F_ANULACION IS NULL
      AND F_SUSPENSION IS NULL
	AND F_DESCUBIERTO IS NULL
	AND PASADO<>'S'
	FOR UPDATE OF PASADO,NUMERO_DE_CARGO,F_CARGO;

CURSOR cLIQUIConEje IS 
	SELECT * FROM LIQUIDACIONES 
	WHERE CONCEPTO=xCONCEPTO AND IMPORTE > 0
	AND F_INGRESO IS NULL
      AND F_ANULACION IS NULL
      AND F_SUSPENSION IS NULL
	AND F_DESCUBIERTO IS NOT NULL
	AND PASADO<>'S'
	FOR UPDATE OF PASADO,NUMERO_DE_CARGO,F_CARGO;

CURSOR cLIQUIVol IS 
	SELECT * FROM LIQUIDACIONES 
	WHERE F_DESCUBIERTO IS NULL AND IMPORTE > 0
	AND F_INGRESO IS NULL
      AND F_ANULACION IS NULL
      AND F_SUSPENSION IS NULL
	AND PASADO<>'S'
	FOR UPDATE OF PASADO,NUMERO_DE_CARGO,F_CARGO;

CURSOR cLIQUIEje IS 
	SELECT * FROM LIQUIDACIONES 
	WHERE F_DESCUBIERTO IS NOT NULL AND IMPORTE > 0
	AND F_INGRESO IS NULL
      AND F_ANULACION IS NULL
      AND F_SUSPENSION IS NULL
	AND PASADO<>'S'
	FOR UPDATE OF PASADO,NUMERO_DE_CARGO,F_CARGO;

v_Liqui LIQUIDACIONES%ROWTYPE;

BEGIN

   SELECT min(SALTO) INTO xSALTO FROM SALTO;


IF xGRUPO > 0 THEN 

   IF xVOL_EJE='V' THEN

   	FOR v_Liqui IN cLIQUIGrVol LOOP

		WRITE_LIQUI_PUNTEO(v_Liqui,xFECHA,xN_CARGO,xSALTO);

		UPDATE LIQUIDACIONES SET PASADO='S',NUMERO_DE_CARGO=xN_CARGO,F_CARGO=xFECHA
		WHERE CURRENT OF cLIQUIGrVol;
	
   	END LOOP;

   ELSE

	FOR v_Liqui IN cLIQUIGrEje LOOP

		WRITE_LIQUI_PUNTEO(v_Liqui,xFECHA,xN_CARGO,xSALTO);

		UPDATE LIQUIDACIONES SET PASADO='S',NUMERO_DE_CARGO=xN_CARGO,F_CARGO=xFECHA
		WHERE CURRENT OF cLIQUIGrEje;
	
   	END LOOP;

   END IF;

   RETURN;

END IF;

IF LENGTH(xCONCEPTO) > 0 THEN 

   IF xVOL_EJE='V' THEN

   	FOR v_Liqui IN cLIQUIConVol LOOP

		WRITE_LIQUI_PUNTEO(v_Liqui,xFECHA,xN_CARGO,xSALTO);

		UPDATE LIQUIDACIONES SET PASADO='S',NUMERO_DE_CARGO=xN_CARGO,F_CARGO=xFECHA
		WHERE CURRENT OF cLIQUIConVol;	
   	END LOOP;

   ELSE

   	FOR v_Liqui IN cLIQUIConEje LOOP

		WRITE_LIQUI_PUNTEO(v_Liqui,xFECHA,xN_CARGO,xSALTO);

		UPDATE LIQUIDACIONES SET PASADO='S',NUMERO_DE_CARGO=xN_CARGO,F_CARGO=xFECHA
		WHERE CURRENT OF cLIQUIConEje;

   	END LOOP;

   END IF;

   RETURN;

END IF;


IF xVOL_EJE ='V' THEN 

   FOR v_Liqui IN cLIQUIVol LOOP

	WRITE_LIQUI_PUNTEO(v_Liqui,xFECHA,xN_CARGO,xSALTO);

	UPDATE LIQUIDACIONES SET PASADO='S',NUMERO_DE_CARGO=xN_CARGO,F_CARGO=xFECHA
	WHERE CURRENT OF cLIQUIVol;

   END LOOP;
   
END IF;

IF xVOL_EJE ='E' THEN 

   FOR v_Liqui IN cLIQUIEje LOOP

	WRITE_LIQUI_PUNTEO(v_Liqui,xFECHA,xN_CARGO,xSALTO);

	UPDATE LIQUIDACIONES SET PASADO='S',NUMERO_DE_CARGO=xN_CARGO,F_CARGO=xFECHA
	WHERE CURRENT OF cLIQUIEje;
	
   END LOOP;
   
END IF;

END;
/

/********************************************************************************
Acción: Modificar una liquidación.
MODIFICACIÓN: 12/09/2001 Lucas Fernández Pérez. Adaptación al Euro.
MODIFICACIÓN: 19/11/2001 M. Carmen Junco Gómez. Hay que actualizar el campo cotitulares
		  cuando se modifica la liquidación.
MODIFICACION: 21/03/2003. Agustín León Robles. En vez de utilizar el final del periodo voluntario 
				se utiliza la fecha juliana. El final del periodo voluntario se calculará con los
				acuses de recibo o con la fecha de publicación en el BOP
Modificación: 05/11/2003. Agustín León Robles.				
				El campo DIGITO_YEAR se actualiza aqui y no en el trigger T_UPD_LIQUIDACIONES				
********************************************************************************/

CREATE OR REPLACE PROCEDURE MOD_LIQUI(
	xMUNICIPIO 		IN CHAR,
	xCON 			IN CHAR,
	xYEAR 		IN CHAR,
	xPERIODO		IN CHAR,
	xNUMERO 		IN CHAR,
	xNIF 			IN CHAR,
	xNIFREP		IN CHAR,
	xDOMI 		IN CHAR,
	xFECHA_LIQUI 	IN DATE,
	xFIN_PE_VOL		IN DATE,
	xIMPORTE 		IN FLOAT,
	xMOTIVO 		IN VARCHAR2,
	xEXPE 		IN CHAR,
	xCOTITULARES	IN CHAR,
	xIDAlternativo    IN INTEGER,
	xREF_CAT 		IN CHAR,
	xNUM_FIJO 		IN CHAR,
	xID 			IN INTEGER)
AS
	xCaracter	Char(7);
	xExpeAux	char(15);
	xRefCatAux	char(20);
	xFijoAux	char(8);
BEGIN
	xCaracter:=substr(xNumero,1,7);

	xExpeAux:=xEXPE;
	IF xExpeAux is null THEN
		xExpeAux:=xCaracter;
	END IF;

	xRefCatAux:=xREF_CAT;
	IF xRefCatAux='' THEN
		xRefCatAux:=NULL;
	END IF;

	xFijoAux:=xNUM_FIJO;
	IF xFijoAux='' THEN
		xFijoAux:=NULL;
	END IF;

	xExpeAux:=SUBSTR(xExpeAux,1,15);

	UPDATE LIQUIDACIONES SET 
				MUNICIPIO=xMUNICIPIO,
				NUMERO=xCaracter,
				CONCEPTO=xCON,
				YEAR=xYEAR,
				PERIODO=xPERIODO,
				NIF=xNIF,
				NIFREP=xNIFREP,
				DOMI_TRIBUTARIO=xDOMI,
				F_LIQUIDACION=xFECHA_LIQUI,
				F_JULIANA=DECODE(TO_CHAR(xFIN_PE_VOL,'YYYY'),'1899', NULL, TO_CHAR(xFIN_PE_VOL,'ddd')),
				DIGITO_YEAR=DECODE(TO_CHAR(xFIN_PE_VOL,'y'),'1899', NULL, TO_CHAR(xFIN_PE_VOL,'y')),
				FVENCIMIENTO=DECODE(TO_CHAR(xFIN_PE_VOL,'YYYY'),'1899', NULL, xFIN_PE_VOL),
				IMPORTE=xIMPORTE,
				MOTIVO=xMOTIVO,
				EXPEDIENTE=xExpeAux,
				COTITULARES=xCOTITULARES,
				IDDOMIALTER=DECODE(xIDAlternativo,0,NULL,xIDAlternativo),
				REF_CATASTRAL=xRefCatAux,
				NUM_FIJO=xFijoAux
	WHERE ID=xID;

	INSERT_HISTORIA_LIQUI(xID,'M','SE MODIFICA LA LIQUIDACION');
END;
/

/********************************************************************************
Acción: Dar por ingresada una liquidación.
MODIFICACIÓN: 05/08/2001 Antonio Pérez Caballero.
MODIFICACIÓN: 15/07/2003 M. Carmen Junco Gómez. Sólo se ejecutará WriteIngreso si
			  el pase automático está activo.
********************************************************************************/

CREATE OR REPLACE PROCEDURE PAGA_LIQUI(
       xID 			IN INTEGER,
       xFECHA 		IN DATE,
       xCOD_ING 		IN CHAR,
       xGRUPO 		IN INTEGER)
AS

	xCodigoOperacion INT;
	xIDVALOR INT;
	xIMPORTE float;
	xPASE CHAR(1);

	CURSOR cLIQUI IS 
		SELECT ID,IDVALOR,IMPORTE FROM LIQUIDACIONES
			WHERE GRUPO=xGRUPO 
			AND F_INGRESO IS NULL 
			AND F_ANULACION IS NULL;
BEGIN

	begin
      SELECT PASE_AUTOMATICO INTO xPASE
      FROM DATOSPERR WHERE EMPRESA IS NOT NULL;	
      EXCEPTION
         when no_data_found then	  
	      xPASE:='N';	
    end;

   IF xGRUPO=0 THEN

	BEGIN
		SELECT IDVALOR,IMPORTE INTO xIDVALOR,xIMPORTE FROM LIQUIDACIONES
			WHERE ID=xID AND F_INGRESO IS NULL AND F_ANULACION IS NULL;
	EXCEPTION
		when no_data_found then
		     xIDVALOR:=null;
	END;

   	-- Si fué pasado a recaudación de forma automática, proceder a su ingreso o compensación
   	-- en recaudación
   	IF ((xPASE='S') AND (xIDVALOR IS NOT NULL)) THEN
	   CODIGO_OPERACION(xCodigoOperacion);
	   PkIngresos.WRITE_INGRESO(xIDVALOR, 'INGRESADO DESDE LIQUIDACIONES DIRECTAS',
		xCOD_ING, SYSDATE, xIMPORTE, 0, 0, 0, xCodigoOperacion, 'C');

	ELSE
		-- Los ingresos de liquidaciones van por otro canal o no hay recaudación
		UPDATE LIQUIDACIONES SET F_INGRESO=xFECHA,CODIGO_INGRESO=xCOD_ING
      		WHERE ID=xID AND F_INGRESO IS NULL AND F_ANULACION IS NULL;

   	END IF;

	INSERT_HISTORIA_LIQUI(xID, 'I', 'SE INGRESA');

   ELSE

	-- Un grupo de liquidaciones
	FOR v_Liqui IN cLIQUI LOOP

	    IF ((xPASE='S') AND (v_Liqui.IDVALOR IS NOT NULL)) THEN
	       CODIGO_OPERACION(xCodigoOperacion);
	       PkIngresos.WRITE_INGRESO(v_Liqui.IDVALOR, 'INGRESADO DESDE LIQUIDACIONES DIRECTAS',
		   xCOD_ING, SYSDATE, v_Liqui.IMPORTE, 0, 0, 0, xCodigoOperacion, 'C');
	    ELSE
		-- Los ingresos de liquidaciones van por otro canal o no hay recaudación
		UPDATE LIQUIDACIONES SET F_INGRESO=xFECHA,CODIGO_INGRESO=xCOD_ING
      		WHERE ID=v_Liqui.ID;
   	    END IF;

	END LOOP;

	 INSERT INTO HISTORIA_LIQUI
               (LIQUI,TIPO_DATA,EXPLICACION,FECHA,USUARIO)
	         SELECT ID,'I','SE INGRESA',SYSDATE,USER FROM LIQUIDACIONES
		   WHERE GRUPO=xGRUPO;


   END IF;

END;
/

/********************************************************************************
Acción: Reponer una liquidación.
MODIFICACIÓN: 05/08/2001 Antonio Pérez Caballero.
MODIFICACIÓN: 12/09/2001 Lucas Fernández Pérez.
********************************************************************************/

CREATE OR REPLACE PROCEDURE REPONER_LIQUI(
       xID 		IN INTEGER,
       xFECHA 	IN DATE,
       xCAUSA 	IN CHAR,
       xGRUPO 	IN INTEGER)
AS   
xIDVALOR INT;

CURSOR cLIQUI IS 
	SELECT ID,IDVALOR FROM LIQUIDACIONES
		WHERE GRUPO=xGRUPO 
		AND F_INGRESO IS NOT NULL;
BEGIN

   IF xGRUPO=0 THEN

	BEGIN
		SELECT IDVALOR INTO xIDVALOR FROM LIQUIDACIONES
			WHERE ID=xID AND F_INGRESO IS NOT NULL;
	EXCEPTION
		when no_data_found then
		     xIDVALOR:=null;
	END;

   	-- Si fué pasado a recaudación de forma automática, proceder a su ingreso o compensación
   	-- en recaudación
   	IF xIDVALOR IS NOT NULL THEN

	   -- Pasar a la tabla intermedia el texto para que el disparador lo lea
         UPDATE USUARIOS SET TEXTO=xCAUSA WHERE USUARIO=USER;
	   DELETE FROM INGRESOS WHERE VALOR=xIDVALOR;

	ELSE
		-- Los ingresos de liquidaciones van por otro canal o no hay recaudación
      	UPDATE LIQUIDACIONES SET F_INGRESO=NULL,CODIGO_INGRESO=NULL
      	WHERE ID=xID AND F_INGRESO IS NOT NULL
		RETURNING IDVALOR INTO xIDVALOR;

		INSERT_HISTORIA_LIQUI(xID, 'R', xCAUSA);

   	END IF;


   ELSE

	-- Pasar a la tabla intermedia el texto para que el disparador lo lea
      UPDATE USUARIOS SET TEXTO=xCAUSA WHERE USUARIO=USER;

	-- Un grupo de liquidaciones
	FOR v_Liqui IN cLIQUI LOOP

	    IF v_Liqui.IDVALOR IS NOT NULL THEN

	   	 DELETE FROM INGRESOS WHERE VALOR=v_Liqui.IDVALOR;

	    ELSE
		-- Los ingresos de liquidaciones van por otro canal o no hay recaudación
      	UPDATE LIQUIDACIONES SET F_INGRESO=NULL,CODIGO_INGRESO=NULL
      		WHERE ID=v_Liqui.ID;

		INSERT_HISTORIA_LIQUI(v_Liqui.ID, 'R', xCAUSA);
   	    END IF;

	END LOOP;


   END IF;

END;
/

/********************************************************************************
Acción: Pasar a descubierto.
MODIFICACION: 13/02/2006. Gloria Calle Hernandez. Modificacion del procedimiento 
permitiendo el pase a descubierto tanto de un grupo de liquidaciones como de una en concreto.
********************************************************************************/
CREATE OR REPLACE PROCEDURE PASAR_A_DESCUBIERTO (xID INTEGER, xGRUPO INTEGER)
AS
CURSOR cLiquis IS
       SELECT ID FROM LIQUIDACIONES
       WHERE MUNICIPIO IN (SELECT MUNICIPIO FROM TMP_AYTOS WHERE USUARIO=USER)
		AND F_INGRESO IS NULL
		AND F_ANULACION IS NULL
		AND F_SUSPENSION IS NULL
		AND F_DESCUBIERTO IS NULL
		AND F_NOTIFICACION IS NOT NULL
		AND F_FIN_PE_VOL<=SYSDATE
	FOR UPDATE OF F_DESCUBIERTO;

CURSOR cGrupo IS
       SELECT ID FROM LIQUIDACIONES
       WHERE MUNICIPIO IN (SELECT MUNICIPIO FROM TMP_AYTOS WHERE USUARIO=USER)
		AND F_INGRESO IS NULL
		AND F_ANULACION IS NULL
		AND F_SUSPENSION IS NULL
		AND F_DESCUBIERTO IS NULL
		AND F_NOTIFICACION IS NOT NULL
		AND F_FIN_PE_VOL<=SYSDATE
		AND GRUPO=xGRUPO
	FOR UPDATE OF F_DESCUBIERTO;

BEGIN
	IF xGRUPO<>0 THEN
		FOR vGrupo IN cGrupo LOOP
			UPDATE LIQUIDACIONES SET F_DESCUBIERTO=SYSDATE WHERE CURRENT OF cGrupo;
			INSERT_HISTORIA_LIQUI(vGrupo.ID,'D','SE PASA A DESCUBIERTO');
   		END LOOP;

	ELSIF xID=0 THEN
		FOR vLiquis IN cLiquis LOOP
			UPDATE LIQUIDACIONES SET F_DESCUBIERTO=SYSDATE WHERE CURRENT OF cLiquis;
			INSERT_HISTORIA_LIQUI(vLiquis.ID,'D','SE PASA A DESCUBIERTO');
   		END LOOP;

   	ELSE
		UPDATE LIQUIDACIONES SET F_DESCUBIERTO=SYSDATE WHERE ID=xID
		AND MUNICIPIO IN (SELECT MUNICIPIO FROM TMP_AYTOS WHERE USUARIO=USER)
		AND F_INGRESO IS NULL AND F_ANULACION IS NULL AND F_SUSPENSION IS NULL
		AND F_DESCUBIERTO IS NULL AND F_NOTIFICACION IS NOT NULL AND F_FIN_PE_VOL<=SYSDATE;

		INSERT_HISTORIA_LIQUI(xID,'D','SE PASA A DESCUBIERTO');
   	END IF;
END;
/

/********************************************************************************
Acción: Fechad de Resolución.
********************************************************************************/

CREATE OR REPLACE PROCEDURE RESOLVER_LIQUI(
       xID 		IN INTEGER,
       xFECHA 	IN DATE,
       xNUM_RE 	IN CHAR,
       xGRUPO 	IN INTEGER)
AS
BEGIN
   IF xGRUPO=0 THEN
      UPDATE LIQUIDACIONES SET F_RESOLUCION=xFECHA,N_RESOLUCION=xNUM_RE
      WHERE ID=xID;

	INSERT_HISTORIA_LIQUI(xID,'L','SE INTRODUCE LA F. DE RESOLUCION');

   ELSE
      UPDATE LIQUIDACIONES SET F_RESOLUCION=xFECHA,N_RESOLUCION=xNUM_RE
      WHERE GRUPO=xGRUPO;

	INSERT INTO HISTORIA_LIQUI (LIQUI,TIPO_DATA,EXPLICACION,FECHA,USUARIO)
	SELECT ID,'L','SE INTRODUCE LA F. DE RESOLUCION',SYSDATE,USER FROM LIQUIDACIONES
	WHERE GRUPO=xGRUPO;
   END IF;
END;
/

/********************************************************************************
Acción: Suspender una liquidación.
********************************************************************************/
CREATE OR REPLACE PROCEDURE SUSPEN_LIQUI(
       xID 		IN INTEGER,
       xFECHA 	IN DATE,
       xGRUPO 	IN INTEGER,
   	 xF_ACUERDO   IN DATE,
	 xORGANISMO   IN CHAR,
     	 xDESCRIPCION IN CHAR )

AS
xFSUS       DATE;
BEGIN

   SELECT F_SUSPENSION INTO xFSUS FROM LIQUIDACIONES WHERE ID=xID;

   IF xGRUPO=0 THEN
      IF xFSUS IS NULL THEN

		UPDATE LIQUIDACIONES SET F_SUSPENSION=xFECHA
		WHERE ID=xID AND F_INGRESO IS NULL 
			AND F_ANULACION IS NULL AND F_SUSPENSION IS NULL;

		INSERT_HISTORIA_LIQUI(xID,'S','SE SUSPENDE');

		INSERT INTO SUSPENSIONES_LIQUIDACIONES
	         (ID_LIQUI,F_ACUERDO,ORGANISMO,DESCRIPCION)
		VALUES (xID,xF_ACUERDO,xORGANISMO,xDESCRIPCION);

      ELSE

		UPDATE LIQUIDACIONES SET F_SUSPENSION=NULL
		WHERE ID=xID AND F_INGRESO IS NULL 
			AND F_ANULACION IS NULL AND F_SUSPENSION IS NOT NULL;

		INSERT_HISTORIA_LIQUI(xID,'E','SE QUITA LA SUSPENSION');

		DELETE FROM SUSPENSIONES_LIQUIDACIONES WHERE ID_LIQUI=xID;

      END IF;
   ELSE
      IF xFSUS IS NULL THEN
		INSERT INTO HISTORIA_LIQUI (LIQUI,TIPO_DATA,EXPLICACION,FECHA,USUARIO)
		SELECT ID,'S','SE SUSPENDE',SYSDATE,USER FROM LIQUIDACIONES
		WHERE GRUPO=xGRUPO AND F_INGRESO IS NULL 
			AND F_ANULACION IS NULL AND F_SUSPENSION IS NULL;

		INSERT INTO SUSPENSIONES_LIQUIDACIONES
	         (ID_LIQUI,F_ACUERDO,ORGANISMO,DESCRIPCION)
		SELECT ID,xF_ACUERDO,xORGANISMO,xDESCRIPCION FROM LIQUIDACIONES
		WHERE GRUPO=xGRUPO AND F_INGRESO IS NULL 
			AND F_ANULACION IS NULL AND F_SUSPENSION IS NULL;

		UPDATE LIQUIDACIONES SET F_SUSPENSION=xFECHA
		WHERE GRUPO=xGRUPO AND F_INGRESO IS NULL 
			AND F_ANULACION IS NULL AND F_SUSPENSION IS NULL;

      ELSE
		INSERT INTO HISTORIA_LIQUI (LIQUI,TIPO_DATA,EXPLICACION,FECHA,USUARIO)
		SELECT ID,'E','SE QUITA LA SUSPENSION',SYSDATE,USER FROM LIQUIDACIONES
		WHERE GRUPO=xGRUPO AND F_INGRESO IS NULL AND F_ANULACION IS NULL AND 
               F_SUSPENSION IS NOT NULL;

		DELETE FROM SUSPENSIONES_LIQUIDACIONES 
		WHERE ID_LIQUI IN (SELECT ID FROM LIQUIDACIONES 
				  WHERE GRUPO=xGRUPO AND F_INGRESO IS NULL 
					AND F_ANULACION IS NULL AND F_SUSPENSION IS NOT NULL);

		UPDATE LIQUIDACIONES SET F_SUSPENSION=NULL
		WHERE GRUPO=xGRUPO AND F_INGRESO IS NULL AND F_ANULACION IS NULL AND 
               F_SUSPENSION IS NOT NULL;

      END IF;
   END IF;
END;
/

/********************************************************************************
Acción: Cambiar año de trabajo.
********************************************************************************/

CREATE OR REPLACE PROCEDURE CAMBIA_YEARWORK_LIQUI(
	 xMUNICIPIO  IN  CHAR,
       xYEAR       IN CHAR)
AS

xCONCEPTO       CHAR(6);
xCONTADOR       INTEGER;
   
CURSOR CCONCEPTOS IS SELECT CONCEPTO FROM CONCEPTOS; 

BEGIN
   UPDATE DATOSPER SET YEARWORK=xYEAR WHERE MUNICIPIO=xMUNICIPIO;

   OPEN CCONCEPTOS;
   LOOP
      FETCH CCONCEPTOS INTO xCONCEPTO;
      EXIT WHEN CCONCEPTOS%NOTFOUND;

      SELECT TO_NUMBER(MAX(NUMERO)) INTO xCONTADOR
      FROM LIQUIDACIONES
      WHERE CONCEPTO=xCONCEPTO AND YEAR=xYEAR AND MUNICIPIO=xMUNICIPIO;

      IF xCONTADOR IS NULL THEN
         xCONTADOR:=0;
      END IF;

      UPDATE CONTADOR_CONCEPTOS SET CONTADOR=xCONTADOR
      WHERE CONCEPTO=xCONCEPTO AND MUNICIPIO=xMUNICIPIO;

   END LOOP;
   CLOSE CCONCEPTOS;
END;
/

/********************************************************************************
Autor: Agustin Leon Robles.
Fecha: 30/08/2001
Acción: Cambiar todos los años de trabajo de las liquidaciones de todos los aytos.
********************************************************************************/

CREATE OR REPLACE PROCEDURE CAMBIA_ALLYEARWORK_LIQUI(
       xYEAR       IN CHAR)
AS

xCONCEPTO       CHAR(6);
xCONTADOR       INTEGER;
   
CURSOR cConceptos IS SELECT CONCEPTO FROM CONCEPTOS; 
CURSOR cAytos IS SELECT MUNICIPIO FROM DATOSPER; 
BEGIN

	UPDATE DATOSPER SET YEARWORK=xYEAR;

	FOR v_Aytos IN cAytos LOOP

		FOR v_Conceptos IN cConceptos LOOP

			SELECT TO_NUMBER(MAX(NUMERO)) INTO xCONTADOR
			FROM LIQUIDACIONES
			WHERE MUNICIPIO=v_Aytos.MUNICIPIO 
				AND CONCEPTO=v_Conceptos.CONCEPTO 
				AND YEAR=xYEAR;

			IF xCONTADOR IS NULL THEN
				xCONTADOR:=0;
			END IF;

			UPDATE CONTADOR_CONCEPTOS SET CONTADOR=xCONTADOR

			WHERE MUNICIPIO=v_Aytos.MUNICIPIO 
				AND CONCEPTO=v_Conceptos.CONCEPTO;

		END LOOP;

	END LOOP;
END;
/

/******************************************************************************************
Acción: Anular un Cargo en Liquidaciones. 
Parámetros: xCargo: Número de Cargo
*******************************************************************************************/

CREATE OR REPLACE PROCEDURE ANULAR_CARGO(
		xCARGO IN CHAR)
AS
BEGIN

   INSERT INTO HISTORIA_LIQUI (LIQUI,TIPO_DATA,EXPLICACION,FECHA,USUARIO)
        SELECT ID,'H','SE ANULA EL CARGO: '||xCARGO,SYSDATE,USER 
        FROM LIQUIDACIONES
        WHERE NUMERO_DE_CARGO=xCARGO;

   UPDATE LIQUIDACIONES SET PASADO='N',
				    NUMERO_DE_CARGO=NULL,
				    F_CARGO=NULL
   WHERE NUMERO_DE_CARGO=xCARGO;  

END;
/

/******************************************************************************************
Autor: M. Carmen Junco Gómez. 14/05/2002
Acción: Cambiar número de cargo para pase automático de liquidaciones. 
Parámetros: xCargo: Número de Cargo
			xERROR: Valdrá 0 si no ha habido problemas y 1 si no se ha podido realizar
			la operación porque el cargo ya exista en la tabla de CARGOS
Modificacion: 05/02/2004. Gloria María Calle Hernández. Añadida FCARGO a la tabla DatosPerr
			  para introducir la fecha de cargo junto con el número de cargo para posteriores
			  consultas e inserciones en las tablas correspondientes.
*******************************************************************************************/
CREATE OR REPLACE PROCEDURE CARGO_AUTOMATICO_UPD(
		xNCARGO IN  CHAR,
		xFCARGO	IN	DATE,
		xERROR  OUT VARCHAR2)
AS
   mCARGO CHAR(10);
   mContador integer;
BEGIN

   -- Comprobamos si el cargo ya existe en la tabla CARGOS y en la tabla PUNTEO
 
   select count(*) into mContador from punteo where n_cargo=xNCargo;
   
   if (mContador=0) then
      select count(*) into mContador from cargos where cargo=xNCargo;
      
      if (mContador=0) then
         -- Introducimos xCargo como nuevo cargo para pase automático
         update datosperr set ncargo=xNCargo, fcargo=xFCargo where empresa is not null;
         xError:=0;
      end if;
               
   end if;   
   
END;
/

/***************************************************************************************
Autor: M. Carmen Junco Gómez. 06/03/2003
Acción: Cambia la fecha de final del periodo voluntario de una liquidación, recalculando
        los datos para el cuaderno60 y actualizando la fecha en valores.
Modificación: 05/11/2003. Agustín León Robles.				
				El campo DIGITO_YEAR se actualiza aqui y no en el trigger T_UPD_LIQUIDACIONES
Modificación: 03/05/2006. Lucas Fernández Pérez.
				Nueva funcionalidad si xID=0, se cambia la fecha a las liquidaciones que están en valores
				en voluntaria de los cargos de la tabla TMP_LISTACARGOS sin ingresar ni anular 
****************************************************************************************/

CREATE OR REPLACE PROCEDURE LIQUI_CAMBIA_FECHAFIN
			(xID		IN	INTEGER,
			 xFECHA	IN	DATE)
AS
   xFVencimiento	DATE;
   xDia 	     	integer;

BEGIN


	xFVencimiento:=xFECHA;    
	xDia:=TO_CHAR(xFVencimiento,'d');

	IF (xDia=6) then --sabado
      	xFVencimiento:=xFVencimiento+2;
	ELSIF (xDia=7) then --domingo
	      xFVencimiento:=xFVencimiento+1;
	END IF;

	if (xID<>0) then -- Tratamiento individual, sólo se cambia la fecha a una liquidación
	  --el trigger T_UPD_LIQUIDACIONES actualiza el resto de campos del C60
	  UPDATE LIQUIDACIONES SET F_JULIANA=to_char(xFVencimiento,'ddd'),
							DIGITO_YEAR=to_char(xFVencimiento,'y'),
							FVENCIMIENTO=xFVencimiento
	  WHERE ID=xID;
	
	else -- xID=0: Tratamiento por cargos. Se cambia la fecha a todas las liquidaciones que están en valores
	     -- en voluntaria de los cargos de TMP_LISTACARGOS sin ingresar NI anular
	
	  UPDATE LIQUIDACIONES SET F_JULIANA=to_char(xFVencimiento,'ddd'),
							DIGITO_YEAR=to_char(xFVencimiento,'y'),
							FVENCIMIENTO=xFVencimiento
	  WHERE IDVALOR IN (SELECT ID FROM VALORES WHERE F_INGRESO IS NULL AND FECHA_DE_BAJA IS NULL AND VOL_EJE='V'
	  		AND N_CARGO IN (SELECT CARGO FROM TMP_LISTACARGOS WHERE USUARIO=USER AND SESIONID=GETSID()))
	  		AND IDVALOR IS NOT NULL;
	
	end if;

END;
/


--
-- Autor: 09/05/2006 Agustín León Robles. Se inserta en la tabla de impresion temporal de liquidaciones
--
-- Modificado: 05/02/2007. Lucas Fernández Pérez. Se guarda en la tabla temporal los nuevos campos BLOQUE y PORTAL
--
CREATE OR REPLACE PROCEDURE RellenaLiquiImpresion(vGrupo IN	LIQUIDACIONES%ROWTYPE)
AS

	xNOMBRE			VARCHAR2 (40);
  	xVIA			CHAR(2);
  	xCALLE			VARCHAR2(30);
  	xNUMERO			CHAR(5);
  	xBLOQUE			CHAR(4);
  	xPORTAL			CHAR(2);
  	xESCALERA		CHAR(2);				  
  	xPLANTA			CHAR(3);
  	xPISO			CHAR(2);
  	xPOBLACION		VARCHAR2(35);
  	xPROVINCIA		VARCHAR2(35);
  	xCODIGO_POSTAL	CHAR(5);
  	xPAIS			VARCHAR2(35);
  	xNIFREP         CHAR (10);
  	xNOMBREREPRE	VARCHAR2(40);
  	xDESCRIPCION	VARCHAR2(50);
BEGIN

		xNOMBRE:='';
		xVIA:='';
		xCALLE:='';
		xNUMERO:='';
		xBLOQUE:='';
		xPORTAL:='';
		xESCALERA:='';
		xPLANTA:='';
		xPISO:='';
		xPOBLACION:='';
		xPROVINCIA:='';
	    xCODIGO_POSTAL:='';
	    xPAIS:='';
	    xNOMBREREPRE:='';
		
		SELECT NOMBRE,VIA,CALLE,NUMERO,BLOQUE,PORTAL,ESCALERA,PLANTA,PISO,POBLACION,PROVINCIA,
	           CODIGO_POSTAL,PAIS
		INTO xNOMBRE,xVIA,xCALLE,xNUMERO,xBLOQUE,xPORTAL,xESCALERA,xPLANTA,xPISO,xPOBLACION,xPROVINCIA,
	     	 xCODIGO_POSTAL,xPAIS
		FROM CONTRIBUYENTES WHERE NIF=vGRUPO.NIF;
	
		IF vGRUPO.NIFREP IS NOT NULL THEN
			SELECT NOMBRE INTO xNOMBREREPRE FROM CONTRIBUYENTES 
			WHERE NIF=vGRUPO.NIFREP;
		END IF;
	
	    SELECT DESCRIPCION INTO xDESCRIPCION FROM CONCEPTOS WHERE CONCEPTO=vGRUPO.CONCEPTO;

	    INSERT INTO IMP_LIQUIDACION
			(MUNICIPIO,CONCEPTO,YEAR,CONTRAIDO,NUMERO_LIQUI,EJERCICIO,EXPEDIENTE, 
           	N_RESOLUCION,NIF,NOMBRE,VIA,CALLE,NUMERO,BLOQUE,PORTAL,ESCALERA,PLANTA,PISO,POBLACION,				  		   
		 	PROVINCIA,CODIGO_POSTAL,PAIS,NIFREP,NOMBREREPRE,DOMI_TRIBUTARIO, 
		 	F_LIQUIDACION,F_RESOLUCION,F_NOTIFICACION,F_INGRESO,F_ANULACION, 
  		 	F_SUSPENSION,F_OTORGACION,F_DESCUBIERTO,F_FIN_PE_VOL,CODIGO_INGRESO, 
  		 	IMPORTE,AUTOLIQ,RECARGO,SANCION,NUMERO_DE_CARGO,F_CARGO,MOTIVO,   
  		 	YEAR_DATA,NUM_DATA,REF_CATASTRAL,NUM_FIJO,NUMERO_PARCELA,
  		 	COD_POLIGONO_CATASTRAL,EMISOR,TRIBUTO,EJER_C60,REFERENCIA, 
  		 	IMP_CADENA,DISCRI_PERIODO,DIGITO_YEAR,F_JULIANA,DIGITO_C60_MODALIDAD2,
  		 	CODIGO_BARRAS,PERIODO,ID,DESC_CONCEPTO,DOMICILIO_ALTERNATIVO)
  		VALUES
  			(vGRUPO.MUNICIPIO,vGRUPO.CONCEPTO,vGRUPO.YEAR,
  		 	vGRUPO.CONTRAIDO,vGRUPO.NUMERO,vGRUPO.EJERCICIO,
  		 	vGRUPO.EXPEDIENTE,vGRUPO.N_RESOLUCION,vGRUPO.NIF,
  		 	xNOMBRE,xVIA,xCALLE,xNUMERO,xBLOQUE,xPORTAL,xESCALERA,xPLANTA,xPISO,xPOBLACION,				  		   
  		 	xPROVINCIA,xCODIGO_POSTAL,xPAIS,vGRUPO.NIFREP,xNOMBREREPRE,
  		 	vGRUPO.DOMI_TRIBUTARIO,vGRUPO.F_LIQUIDACION,
  		 	vGRUPO.F_RESOLUCION,vGRUPO.F_NOTIFICACION,vGRUPO.F_INGRESO,
  		 	vGRUPO.F_ANULACION,vGRUPO.F_SUSPENSION,vGRUPO.F_OTORGACION,
  		 	vGRUPO.F_DESCUBIERTO,vGRUPO.F_FIN_PE_VOL,vGRUPO.CODIGO_INGRESO, 
  		 	vGRUPO.IMPORTE,vGRUPO.AUTOLIQ,vGRUPO.RECARGO,
  		 	vGRUPO.SANCION,vGRUPO.NUMERO_DE_CARGO,vGRUPO.F_CARGO,
  		 	vGRUPO.MOTIVO,vGRUPO.YEAR_DATA,vGRUPO.NUM_DATA,
  		 	vGRUPO.REF_CATASTRAL,vGRUPO.NUM_FIJO,vGRUPO.NUMERO_PARCELA,
  		 	vGRUPO.COD_POLIGONO_CATASTRAL,vGRUPO.EMISOR,vGRUPO.TRIBUTO,
  		 	vGRUPO.EJER_C60,vGRUPO.REFERENCIA,vGRUPO.IMP_CADENA,
  		 	vGRUPO.DISCRI_PERIODO,vGRUPO.DIGITO_YEAR,vGRUPO.F_JULIANA,
  		 	vGRUPO.DIGITO_C60_MODALIDAD2,
  		 
  		 	'90521'||vGRUPO.EMISOR||vGRUPO.REFERENCIA||
		 	vGRUPO.DIGITO_C60_MODALIDAD2||vGRUPO.DISCRI_PERIODO||
		 	vGRUPO.TRIBUTO||vGRUPO.EJER_C60||vGRUPO.DIGITO_YEAR||
		 	vGRUPO.F_JULIANA|| LPAD(vGRUPO.IMPORTE*100,8,'0') ||'0',  			 
			 
  		 	vGRUPO.PERIODO,vGRUPO.ID,xDESCRIPCION,DameDomiAlternativo(vGRUPO.IDDOMIALTER));


END;
/

-- ****************************************************************************************
-- Autor: 22/08/2003 M. Carmen Junco Gómez. 
-- Acción: Procedimiento que rellena la tabla temporal imp_liquidacion para la impresión de
-- 	    liquidaciones con plantillas de fast report.
-- MODIFICACIÓN: 21/10/2003 Gloria Maria Calle Hernandez
-- 			  Modificación realizada para añadir en la tabla imp_liquidacion los campos ID
-- 			  y DESC_CONCEPTO.
-- Modificado: 15/12/2003. Lucas Fernández Pérez. Se elimina el parámetro xID porque 	
--	siempre se llama desde un grupo, por lo que era código obsoleto. Además, se corrige
--	el relleno del campo ID (que ponía en los masivos xID) y se añade el campo
--	DOMICILIO_ALTERNATIVO
-- Modificación: 09/05/2006. Agustín León Robles. Se puede imprimir liquidaciones por grupos o una sola
-- ****************************************************************************************

CREATE OR REPLACE PROCEDURE FR_IMP_LIQUIDACION(xGRUPO IN INTEGER)
AS
	
	CURSOR cGrupo IS SELECT * FROM LIQUIDACIONES WHERE GRUPO=xGRUPO;
	vLiquidaciones	Liquidaciones%ROWTYPE;
BEGIN

    -- Borramos los datos q pueda contaner la tabla para dicho usuario
    DELETE FROM IMP_LIQUIDACION WHERE USUARIO=USER;

    --Una sola liquidacion
    if xGrupo < 0 then
    
    	SELECT * into vLiquidaciones FROM LIQUIDACIONES WHERE ID=xGRUPO*-1;
    	
    	RellenaLiquiImpresion(vLiquidaciones);
    	
    else
    	--Un grupo de liquidaciones
		FOR vGrupo IN cGrupo LOOP
		
			RellenaLiquiImpresion(vGrupo);
		
		END LOOP;
		
	end if;

END;
/


-- ****************************************************************************************
-- Autor: 10/08/2006 Lucas Fernández Pérez
-- Acción: Procedimiento que rellena la tabla temporal imp_liquidacion para la impresión de
-- 	    autoliquidaciones con plantillas de fast report. Aumenta el contador secuencial
--		del concepto que se va a imprimir en la tabla rela_apli_bancos.
CREATE OR REPLACE PROCEDURE GENERAIMPRES_AUTOLIQUI(
							xAYTO		  IN CHAR,
							xCONCEPTO	  IN CHAR,
							xDATOSCAPTURA IN CHAR,
							xN_IMPRESOS	  IN INTEGER)
AS 
	xEMISOR 	CHAR(6);
	xTRIBUTO 	CHAR(3);
	xAUTOLIQUISECUENCIAL INTEGER;
	
  	xDESCRIPCION   VARCHAR2(50);
  	xREFERENCIA    CHAR(10);
  	xDC			   CHAR(1);
	xNUM		   INTEGER;
	xContador	   INTEGER;
BEGIN

    -- Borramos los datos que pueda contener la tabla para dicho usuario
    DELETE FROM IMP_LIQUIDACION WHERE USUARIO=USER;

	BEGIN
		select EMISORA, CONCEPTO_BANCO, AUTOLIQUISECUENCIAL 
		into xEMISOR, xTRIBUTO, xAUTOLIQUISECUENCIAL from RELA_APLI_BANCOS
		where AYTO=xAYTO and CONCEPTO=xCONCEPTO;
	EXCEPTION
		when no_data_found then
			BEGIN
			xEMISOR:='000000';
			xTRIBUTO:='000';
			END;
	END;
	
	SELECT DESCRIPCION INTO xDESCRIPCION FROM CONCEPTOS WHERE CONCEPTO=xCONCEPTO;

	
	FOR xContador IN 1..xN_IMPRESOS LOOP
	
		
		xREFERENCIA:=LPAD(TO_CHAR(xAUTOLIQUISECUENCIAL+xContador),8,'0');
		
		xNUM:=TO_NUMBER(xEMISOR)+TO_NUMBER(xTRIBUTO||xDATOSCAPTURA||xREFERENCIA);
		xDC:=TO_CHAR(MOD(xNUM,7));

		xREFERENCIA:=xDATOSCAPTURA||trim(xREFERENCIA)||xDC; -- Referencia:= datos a capturar+secuencial+dc (longitud 10)
		
	    INSERT INTO IMP_LIQUIDACION
			(MUNICIPIO,CONCEPTO,EMISOR,TRIBUTO,REFERENCIA, 
  		 	CODIGO_BARRAS,DESC_CONCEPTO)
  		VALUES
  			(xAYTO,xCONCEPTO,xEMISOR, xTRIBUTO, xREFERENCIA,
  			'90523'||xEMISOR||xTRIBUTO||xREFERENCIA, xDESCRIPCION);
  		 	
	END LOOP;
	
	UPDATE RELA_APLI_BANCOS SET AUTOLIQUISECUENCIAL=AUTOLIQUISECUENCIAL+xN_IMPRESOS
	WHERE AYTO=xAYTO AND CONCEPTO=xCONCEPTO;
	
	
END;
/

/********************************************************************/
COMMIT;
/********************************************************************/
