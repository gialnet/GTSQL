/*******************************************************************************
Acción: Modifica o añade un tipo de bonificación
*******************************************************************************/

CREATE OR REPLACE PROCEDURE ADDMOD_BONIF_VEHI (
       xID 		IN 		INTEGER,
       xAYTO 	IN 		CHAR,
       xTIPO 	IN 		CHAR,
       xBONIF 	IN 		FLOAT,
       xDESCRIP 	IN 		VARCHAR2
)
AS

BEGIN

  -- Si se pasa el identificador de un tipo de bonificación ya existente, 
  -- se modifican los datos para esta bonificación. 
  IF xID>0 THEN
     UPDATE BONIFI_VEHICULOS SET AYTO=xAYTO, 
                                 TIPO=xTIPO, 
                                 BONIFICACION=xBONIF,
                                 DESCRIPCION=xDESCRIP
     WHERE ID=xID;
  ELSE
     -- Si la bonificación no existe, se incluye como nuevo tipo de bonificación
     -- (o exención) para el municipo seleccionado.
     INSERT INTO BONIFI_VEHICULOS 
	(AYTO,TIPO,BONIFICACION,DESCRIPCION)
     VALUES 
	(xAYTO, xTIPO, xBONIF, xDESCRIP);
  END IF;

END;
/

/*******************************************************************************
Acción: Marcar o desmarcar un vehículo para su incorporación al padrón.
*******************************************************************************/

CREATE OR REPLACE PROCEDURE ANADE_PADRON_VEHI (
       xABONADO   IN INTEGER,
       xFECHA     IN DATE,
	 xTIPO	IN INTEGER)
AS

BEGIN
  
  IF xTIPO=0 THEN
     -- marcar el vehículo para incorporarlo al padrón	
     UPDATE VEHICULOS SET INCORPORADO='S',F_INCORPORACION=xFECHA
     WHERE ABONADO=xABONADO;
  ELSE
     -- desmarcar el vehículo para no incorporarlo al padrón
     UPDATE VEHICULOS SET INCORPORADO='N',F_INCORPORACION=NULL
     WHERE ABONADO=xABONADO;
  END IF;

END;
/

/*******************************************************************************
Acción: Dar de baja o anular la baja de un vehículo.
MODIFICACIÓN: 14/08/2001 Antonio Pérez Caballero.
*******************************************************************************/

CREATE OR REPLACE PROCEDURE DAR_BAJA_RESTAURA_VEHI(
       xABONADO IN INTEGER,
       xFECHA   IN DATE,
	 xMOTIVO  IN CHAR)
AS
xFECHA_ANT DATE;
BEGIN

SELECT F_BAJA INTO xFECHA_ANT FROM VEHICULOS WHERE ABONADO=xABONADO;

  -- si el vehículo no está dado de baja, darlo de baja y desmarcarlo para su no
  -- incorporación al padrón
  IF xFECHA_ANT IS NULL THEN
     UPDATE VEHICULOS SET F_BAJA=xFECHA,INCORPORADO='N',
					F_INCORPORACION=NULL,MOTIVO_BAJA=xMOTIVO
     WHERE ABONADO=xABONADO;
  ELSE
     -- Dar de alta de nuevo un vehículo. No se incorpora automáticamente.
     UPDATE VEHICULOS SET F_BAJA=NULL, MOTIVO_BAJA=NULL
     WHERE ABONADO=xABONADO;

  END IF;

END;
/

/*******************************************************************************
Acción: Borrar un determinado padrón.
MODIFICACIÓN: 28/06/2002 M. Carmen Junco Gómez. Insertar una tupla en LogsPadrones
		  para controlar que se ha borrado un padrón.
MODIFICACIÓN: 03/12/2002 M. Carmen Junco Gómez. Insertamos el municipio y el periodo
		  en logspadrones.
*******************************************************************************/

CREATE OR REPLACE PROCEDURE BORRA_PADRON_VIEJO_VEHI(
	       xPERIODO 	IN CHAR,
      	 xYEAR 	IN CHAR)
AS
   CURSOR CMUNI IS SELECT MUNICIPIO FROM TMP_AYTOS WHERE USUARIO=USER;
BEGIN

   FOR vMUNI IN CMUNI 
   LOOP
	DELETE FROM RECIBOS_VEHI WHERE MUNICIPIO=vMUNI.MUNICIPIO
			AND YEAR=xYEAR AND PERIODO=xPERIODO;

	DELETE FROM COTITULARES_RECIBO WHERE PROGRAMA='VEHICULOS' 
		AND AYTO=vMUNI.MUNICIPIO AND YEAR=xYEAR AND PERIODO=xPERIODO;

   	-- Insertamos una tupla en LOGSPADRONES para controlar que esta acción ha sido ejecutada
   	INSERT INTO LOGSPADRONES (MUNICIPIO,PROGRAMA,PYEAR,PERIODO,HECHO)
   	VALUES (vMUNI.MUNICIPIO,'VEHICULOS',xYEAR,xPERIODO,'Se Borra un Padrón');     
   END LOOP;

END;
/

-- ***************************************************************************************
-- Acción: Inserción de datos en tabla temporal para la generación del Cuaderno19.
-- MODIFICACIÓN: 17/09/2001 Agustin Leon Robles. Se ha añadido que en el fichero
--		  del banco salga el año y periodo.
-- MODIFICACIÓN: 20/09/2001 M. Carmen Junco Gómez. Se estaban seleccionando datos 
--	        de Vehiculos que ya están en la tabla Recibos_Vehi.
--		  Adaptación al Euro.	
--
-- MODIFICACIÓN: 19/08/2002 Lucas Fernández Pérez. No deberán entrar en el disco aquellos
--		  recibos que se hayan pasado ya a Recaudación y que se encuentren 
--		  ingresados o dados de baja.
--
-- MODIFICACIÓN: 21/01/2004 Lucas Fernández Pérez. Bonificaciones por domiciliaciones.
--  Obtiene de la tabla PROGRAMAS la bonificación por domiciliación y la aplica al 
--	importe del recibo, para que en el disco del c19 vaya el importe bonificado.
--
-- MODIFICACION: 28/05/2004 Gloria Maria Calle Hernandez. Añadido campo AYTO a la tabla 
--			  Recibos_Cuadreno19 para generar ficheros por ayuntamientos (xej. Catoure).
-- MODIFICACIÓN: 22/03/2005 M. Carmen Junco Gómez. Si existe bonificación por domiciliación,
--				se indicará en el séptimo campo de concepto.
-- MODIFICACION: 31/03/2005 Gloria Maria Calle Hernandez. No se incluyen ni propuestos de baja
--				ni suspendidos.
-- MODIFICACION: 01/06/2006 Agustín León Robles. Según el comentario de Gloria anterior los suspendidos
--				y propuestas de baja no entraban en el disco. Lo que ocurre con esto es que luego cuando
--				se aplica el procedimiento PAGAR_BANCOS_DOMICILIADOS para dar por pagados los domiciliados
--				no se puede controlar si los suspendidos o propuestos hay que darlos por ingresados o hacer 
--				un ingreso indebido, ya que estas fechas se pueden poner y quitar en la tabla de valores.
-- MODIFICACIÓN: 06/02/2007 Lucas Fernández Pérez. Ampliación de la variable xDomi_Titular para recoger el 
--					nuevo domicilio con bloque y portal.
-- ****************************************************************************************

CREATE OR REPLACE PROCEDURE CUADERNO19_VEHI (
			xYEAR 		IN CHAR,
			xPERI 		IN CHAR,
			xESTADO 	IN CHAR)
AS
	xNIF_TITULAR		CHAR(10);
	xNOMBRE_TITULAR 	CHAR(40);
	xDOMI_TITULAR 		CHAR(60);
    
	x2 			CHAR(40);
	x3 			CHAR(40);
	x4 			CHAR(40);
	x5 			CHAR(40);
	x6 			CHAR(40);
	x7				char(40);
	x8				char(40);

	xCODPOSTAL 		CHAR(5);    
	xMUNITITULAR 	CHAR(35);
	xPROVINCIA		VARCHAR2(35);
	I 				INTEGER;
	J				INTEGER;
	xREGIS 			INTEGER;
	xMATRI 			CHAR(15);

	xCONCEPTO				CHAR(6);
	xBONIDOMI				FLOAT;
	xF_INGRESO				DATE;
	xFECHA_DE_BAJA			DATE;

	-- cursor que recorre todos los recibos de vehículos del año,periodo,estado_banco
	-- especificados, siempre que el total del recibo sea mayor a 0 euros.
	CURSOR CRECVEHI IS SELECT * FROM RECIBOS_VEHI
			WHERE YEAR=xYEAR AND PERIODO=xPERI AND ESTADO_BANCO=xESTADO AND TOTAL>0
		  AND MUNICIPIO IN (SELECT DISTINCT MUNICIPIO FROM TMP_AYTOS WHERE USUARIO=USER);

BEGIN

	-- Borrar los datos de este usuario de la tabla temporal 
	DELETE FROM RECIBOS_CUADERNO19 WHERE USUARIO=USER;

	xREGIS:=0;

	SELECT COUNT(*) INTO xREGIS FROM RECIBOS_VEHI
	 WHERE YEAR=xYEAR AND PERIODO=xPERI AND ESTADO_BANCO=xESTADO AND TOTAL>0
	   AND MUNICIPIO IN (SELECT DISTINCT MUNICIPIO FROM TMP_AYTOS WHERE USUARIO=USER);
 
 	-- recogemos el concepto y la bonificacion por domiciliaciones para VEHICULOS
	SELECT CONCEPTO,PORC_BONIFI_DOMI INTO xCONCEPTO, xBONIDOMI 
	FROM PROGRAMAS WHERE PROGRAMA='VEHICULOS';	
	
	-- si hay bonificación por domiciliación, se indicará en el séptimo campo de concepto
	J:=6;
	IF ( xBONIDOMI > 0) THEN
		J:=7;
	END IF;

	FOR v_ReciVEHI IN CRECVEHI LOOP			         

		begin
			SELECT F_INGRESO,FECHA_DE_BAJA
			INTO xF_INGRESO,xFECHA_DE_BAJA
			FROM VALORES 
			WHERE AYTO=v_ReciVEHI.MUNICIPIO AND PADRON=xCONCEPTO AND YEAR=v_ReciVEHI.YEAR 
			AND PERIODO=v_ReciVEHI.PERIODO AND RECIBO=v_ReciVEHI.ABONADO  AND TIPO_DE_OBJETO='R';
		Exception
			When no_data_found then
				xF_INGRESO:=NULL;
				xFECHA_DE_BAJA:=NULL;
		end;

		IF ((xF_INGRESO IS NULL) AND (xFECHA_DE_BAJA IS NULL)) THEN	

			IF v_ReciVEHI.DNI_TITULAR IS NULL THEN
				xNIF_TITULAR:=v_ReciVEHI.NIF;
			ELSE
				xNIF_TITULAR:=v_ReciVEHI.DNI_TITULAR;
			END IF;
			
			GETContribuyente(xNIF_TITULAR,xNOMBRE_TITULAR,xMuniTitular,xProvincia,xCodPostal,xDomi_Titular);

			xMATRI:=GetMatricula(v_ReciVEHI.MATRICULA,v_ReciVEHI.NUMERO,v_ReciVEHI.LETRA);
   
			I:=J;
			x2:='MARCA: ' ||v_ReciVEHI.MARCA;
			x3:='MODELO: ' ||v_ReciVEHI.MODELO;
			x4:='MATRICULA: ' ||xMATRI;
			x5:=SUBSTR(ltrim(rtrim(v_ReciVEHI.TARIFA)), 1, 40);
			x6:='BASTIDOR: '||v_ReciVEHI.BASTIDOR;
			x7:='AÑO: '||xYEAR||' PERIODO: '||xPERI;
			IF (I=7) THEN
				x8:='BONIFICACIÓN DEL '||xBONIDOMI||'% POR DOMICILIACIÓN';
			END IF;
	   
			INSERT INTO RECIBOS_CUADERNO19
				(AYTO,ABONADO,NIF,NOMBRE,DOMICILIO,CODPOSTAL,MUNICIPIO,NOMBRE_TITULAR,
				ENTIDAD,SUCURSAL,DC,CUENTA,TOTAL,
				Campo2, Campo3, Campo4, Campo5, Campo6, Campo7, Campo8,
				CAMPOS_OPCIONALES, CUANTOS_REGISTROS)
			VALUES 
				(v_ReciVEHI.MUNICIPIO,v_ReciVEHI.ABONADO,xNIF_TITULAR,v_ReciVEHI.NOMBRE,
				SUBSTR(xDOMI_TITULAR,1,40),
				xCODPOSTAL,xMUNITITULAR, xNOMBRE_TITULAR, 
				v_ReciVEHI.ENTIDAD,v_ReciVEHI.SUCURSAL,v_ReciVEHI.DC,v_ReciVEHI.CUENTA,
				ROUND(v_ReciVEHI.TOTAL*(1-(xBoniDomi/100)),2),
				x2, x3, x4, x5, x6, x7, x8, I, xREGIS);
		END IF;

	END LOOP;
  
END;
/

/*******************************************************************************
Acción: Devuelve el número de recibos que componen un determinado padrón.
*******************************************************************************/
CREATE OR REPLACE PROCEDURE CHECK_EXIT_PADVEHI (
	       xYEAR 		IN  CHAR,
      	   xPERIODO 	IN  CHAR,
	       xCUANTOS 	OUT INTEGER)
AS
BEGIN

   SELECT COUNT(*) INTO xCUANTOS FROM RECIBOS_VEHI
   WHERE MUNICIPIO IN (SELECT MUNICIPIO FROM TMP_AYTOS WHERE USUARIO=USER)
		AND YEAR=xYEAR AND PERIODO=xPERIODO;

END;
/

/*******************************************************************************
Acción: 
  Procedimiento que devuelve: 0 - Si existen vehículos en un municipio o si hay vehículos
                                  marcados para incorporarlos al padrón
					1 - Si no existen vehículos en un municipio
					2 - Si no se ha marcado ningún vehículo de un municipio

  Nota: Este procedimiento solo sirve cuando se trabaja con un solo municipio.

*******************************************************************************/
CREATE OR REPLACE PROCEDURE CHECK_EXIT_VEHICULOS(
    xMUNICIPIO   IN CHAR,
    xRESP 	  	 OUT INTEGER
)
AS
	xTEMP	 	 INTEGER;

BEGIN
   
   xRESP:=0;

   SELECT COUNT(*) INTO xTEMP FROM VEHICULOS
   WHERE MUNICIPIO=xMUNICIPIO;

   IF xTEMP=0 THEN
	xRESP:=1;
   ELSE
      SELECT COUNT(*) INTO xTEMP FROM VEHICULOS
      WHERE MUNICIPIO=xMUNICIPIO AND INCORPORADO='S';
      
      IF xTEMP=0 THEN
         xRESP:=2;
      END IF;
   END IF;

END;
/


/*******************************************************************************
Acción: Procedimiento para copiar tarifas de un ayto y año a otro ayto y año.
	  No se copiarán las tarifas ya existentes.
*******************************************************************************/

CREATE OR REPLACE PROCEDURE COPIAR_TARIFAS(
       xAYTO_1    IN CHAR,
       xAYTO_2    IN CHAR,
       xYEAR      IN CHAR,
       xACTUAL    IN CHAR
)
AS

BEGIN

   INSERT INTO TARIFAS_VEHICULOS 
       (CODIGO, MUNICIPIO, ANNE, DESCRIPCION, CABALLOS_MIN, CABALLOS_MAX, IMPORTE,
        CUOTA_BASE, COEFICIENTE, VEHI_TRAFICO)
       (SELECT CODIGO, xAYTO_2, xACTUAL, DESCRIPCION, CABALLOS_MIN, CABALLOS_MAX, IMPORTE,
              CUOTA_BASE, COEFICIENTE, VEHI_TRAFICO
       FROM TARIFAS_VEHICULOS 
       WHERE MUNICIPIO=xAYTO_1 AND ANNE=xYEAR AND 
             CODIGO NOT IN (SELECT CODIGO FROM TARIFAS_VEHICULOS
 				    WHERE MUNICIPIO=xAYTO_2 AND ANNE=xACTUAL));

END;
/

/*******************************************************************************
Acción: Procedimiento para datar las liquidaciones de los vehículos, de manera 
        que todas las liquidaciones realizadas en años posteriores o iguales a 
        un año dado que no estén datadas se datarán con un número y año
*******************************************************************************/  

CREATE OR REPLACE PROCEDURE DATAR_RECIBOS_VEHI(
       xAYTO 	IN 	CHAR,
       xYEAR 	IN 	CHAR,
       xDATA 	IN 	INTEGER,
       xSALIDA 	OUT 	INTEGER
)
AS

    xCONT       INTEGER;
    xCONCEPTO   CHAR(6);

BEGIN

  SELECT LIQUIDACION INTO xCONCEPTO FROM PROGRAMAS
  WHERE PROGRAMA='VEHICULOS';

  -- Comprobamos si existen liquidaciones para datar
  SELECT COUNT(*) INTO xCONT FROM LIQUIDACIONES
  WHERE NUM_DATA IS NULL AND CONCEPTO=xCONCEPTO AND MUNICIPIO=xAYTO AND
        TO_NUMBER(TO_CHAR(F_LIQUIDACION,'YYYY')) <= TO_NUMBER(xYEAR);

  -- hay liquidaciones para datar 
  IF xCONT>0 THEN

     -- Comprobamos si existen liquidaciones datadas con el mismo número de data y año
     -- para el mismo municipio. Si es así se cancelará el proceso

     SELECT COUNT(*) INTO xCONT FROM LIQUIDACIONES
     WHERE NUM_DATA=xDATA AND YEAR_DATA=xYEAR AND CONCEPTO=xCONCEPTO AND MUNICIPIO=xAYTO;

     -- existen liquidaciones datadas con el mismo número de data para el mismo año y 
     -- municipio 
     IF xCONT>0 THEN
        xSALIDA:=2;
     ELSE
        xSALIDA:=0;
	  -- marcar las liquidaciones como datadas.
        UPDATE LIQUIDACIONES SET NUM_DATA=xDATA,YEAR_DATA=xYEAR
        WHERE NUM_DATA IS NULL AND CONCEPTO=xCONCEPTO AND MUNICIPIO=xAYTO AND
              TO_NUMBER(TO_CHAR(F_LIQUIDACION,'YYYY')) <= TO_NUMBER(xYEAR); 
     END IF;

  -- no hay liquidaciones para datar
  ELSE
     xSALIDA:=1;
  END IF;

END;
/

/*******************************************************************************
Acción: Procedimiento para borrar todos los registros de tráfico.
*******************************************************************************/

CREATE OR REPLACE PROCEDURE BORRA_TRAFICO(xSALIDA OUT INTEGER) AS
BEGIN
  
  DELETE FROM TMP_INCIDENCIAS_TRAFICO;
  DELETE FROM TRAFICO_NEW;  

  IF SQL%NOTFOUND THEN
     xSALIDA:=1;
  ELSE
     xSALIDA:=0;
  END IF;
  
END;
/

/*******************************************************************************
Acción: Procedimiento para borrar un registro de tráfico.
*******************************************************************************/

CREATE OR REPLACE PROCEDURE BORRA_TRAFICO_UNO(xID IN INTEGER) AS

BEGIN
    DELETE FROM TMP_INCIDENCIAS_TRAFICO WHERE ID_TRAFICO=xID;
    DELETE FROM TRAFICO_NEW WHERE ID=xID;
END;
/

/*******************************************************************************
Acción: Comprueba si existe un vehículo sin estar de baja.
*******************************************************************************/

CREATE OR REPLACE PROCEDURE EXISTE_VEHICULO(
       xMATRICULA IN 	CHAR,
       xNUMERO 	IN 	CHAR,
       xLETRA 	IN 	CHAR,
       xRESP 	OUT 	INTEGER
)
AS

    xCONT       INTEGER;

BEGIN

  SELECT COUNT(*) INTO xCONT FROM VEHICULOS
  WHERE MATRICULA=xMATRICULA AND NUMERO=xNUMERO AND LETRA=xLETRA AND F_BAJA IS NULL;

  IF (xCONT<>0) THEN
    xRESP:=1;
  ELSE
    xRESP:=0;
  END IF;

END;
/

/*******************************************************************************
Acción: Generar el padrón de vehículos.
MODIFICACIÓN: 20/08/2001 Agustin Leon Robles. Se han ncluido los domicilios alternativos
	        y el tema del representante.
MODIFICACIÓN: 12/09/2001 Lucas Fernández Pérez. Adaptación al euro.
MODIFICACIÓN: 28/06/2002 M. Carmen Junco Gómez. Insertar una tupla en LogsPadrones
		  para controlar que se ha generado un padrón.
MODIFICACIÓN: 03/12/2002 M. Carmen Junco Gómez. Insertamos los campos municipio y
		  periodo en logspadrones
MODIFICACIÓN: 05/02/2007 Lucas Fernández Pérez. Ampliación del campo domicilio de la tabla RECIBOS_VEHI
*******************************************************************************/

CREATE OR REPLACE PROCEDURE GENERA_PADRON_VEHI (
       xMUNICIPIO 	IN CHAR,
       xYEAR 		IN CHAR,
       xDESDE 		IN DATE,	
       xHASTA 		IN DATE,
	   xCARGO		IN DATE,
       xCONCEPTO	IN CHAR,
       xLINEA1 		IN CHAR,
       xLINEA2 		IN CHAR,
       xLINEA3 		IN CHAR,
	   xPERIODO		IN CHAR)
AS
    xTARIFA           CHAR(50);
    xIMPORTE          FLOAT;
    xDCONTROL         VARCHAR(2);
    xDIG_C60_M2       CHAR(2);    
    xREFERENCIA       CHAR(10);
    xREF_DC           CHAR(2);
    xIMPORTE_CAD      CHAR(12);
    xNOMBRE           VARCHAR(40);
    xDOMICILIO        VARCHAR(60);
    xVIA              CHAR(2);
    xCALLE            VARCHAR(30);
    xNUM              CHAR(5);
    xESC              CHAR(2);
    xPLANTA           CHAR(3);
    xPISO             CHAR(2);
    xYEAR_NUM         INTEGER;
    xYEAR_BONI_NUM    INTEGER;
    xBONIFICACION     FLOAT;
    xNUM_PER	      INTEGER;
    xNOMBRE_TITULAR   VARCHAR2(40);
    xCODPOSTAL 	      CHAR(5);
    xPoblacion 	      CHAR(35);
    xPROVINCIA	      VARCHAR2(35);

    xPADRON		      CHAR(6);
    xEMISOR 	      CHAR(6);
    xTRIBUTO 	      CHAR(3);


    -- cursor con todos los vehículos incorporados al padrón y no dados de baja para 
    -- un municipio especificado.
    CURSOR CDATOSVEHI IS 
	SELECT ABONADO,NIF,MARCA,MODELO,BASTIDOR,DOMICILIADO,MATRICULA,NUMERO,LETRA,ENTIDAD,
		SUCURSAL,DC,CUENTA,F_DOMICILIACION,TITULAR,TIPO_VEHICULO,TIPO_BONI_EX,ID_BONI_EX,
		YEAR_BONI,REPRESENTANTE,IDDOMIALTER,COTITULARES
	FROM VEHICULOS 
	WHERE INCORPORADO='S' AND F_BAJA IS NULL AND MUNICIPIO=xMUNICIPIO;

BEGIN

	--Para saber si se van a generar mas de un padron en un mismo año
	SELECT VEHI_NUM_PERIODOS INTO xNUM_PER FROM DATOSPER WHERE MUNICIPIO=xMUNICIPIO;

	--Averiguar que concepto es el padron de vehiculos
	SELECT CONCEPTO INTO xPADRON FROM PROGRAMAS WHERE PROGRAMA='VEHICULOS';

	--recoger los datos para el cuaderno 60
	BEGIN
		select EMISORA,CONCEPTO_BANCO into xEMISOR,xTRIBUTO from RELA_APLI_BANCOS
				where AYTO=xMUNICIPIO and CONCEPTO=xPADRON;
	EXCEPTION
		when no_data_found then
			BEGIN
			xEMISOR:='000000';
			xTRIBUTO:='000';
			END;
	END;


  FOR REG_CDATOSVEHI IN CDATOSVEHI LOOP

      IF (REG_CDATOSVEHI.DOMICILIADO='N') THEN
          xNOMBRE_TITULAR:=NULL;
      ELSE
          SELECT NOMBRE INTO xNOMBRE_TITULAR FROM CONTRIBUYENTES WHERE NIF=REG_CDATOSVEHI.TITULAR;

      END IF;

	--nombre del abonado, es decir, a nombre de quien saldra el recibo
	SELECT NOMBRE INTO xNOMBRE FROM CONTRIBUYENTES WHERE NIF=REG_CDATOSVEHI.NIF;

	--domicilio fiscal en funcion de si tiene un representante o no.
	--Dentro de la funcion "GetDomicilioFiscal" se comprueba si tiene a su vez un domicilio
	--alternativo.
	IF REG_CDATOSVEHI.REPRESENTANTE IS NULL THEN
		GetDomicilioFiscal(REG_CDATOSVEHI.NIF,REG_CDATOSVEHI.IDDOMIALTER,
					xDomicilio,xPoblacion,xProvincia,xCodPostal);
	ELSE
		GetDomicilioFiscal(REG_CDATOSVEHI.REPRESENTANTE,REG_CDATOSVEHI.IDDOMIALTER,
					xDomicilio,xPoblacion,xProvincia,xCodPostal);
	END IF;

      SELECT DESCRIPCION,IMPORTE INTO xTARIFA,xIMPORTE FROM TARIFAS_VEHICULOS
      WHERE MUNICIPIO=xMUNICIPIO AND CODIGO=REG_CDATOSVEHI.TIPO_VEHICULO AND ANNE=xYEAR;

      xYEAR_BONI_NUM := TO_NUMBER(REG_CDATOSVEHI.YEAR_BONI,9999);
      xYEAR_NUM:= TO_NUMBER(xYEAR,9999);

	-- comprobar si se ha de bonificar el importe del recibo.
      IF xYEAR_BONI_NUM >= xYEAR_NUM THEN

         IF REG_CDATOSVEHI.TIPO_BONI_EX='E' THEN
            xIMPORTE:=0;
         ELSE
           IF REG_CDATOSVEHI.TIPO_BONI_EX='B' THEN
              SELECT BONIFICACION INTO xBONIFICACION FROM BONIFI_VEHICULOS 
		  WHERE ID=REG_CDATOSVEHI.ID_BONI_EX;
              xIMPORTE:=xIMPORTE-((xIMPORTE*xBONIFICACION)/100);
           END IF;

         END IF;

      END IF;

      xIMPORTE:=ROUND(xIMPORTE/xNUM_PER,2);

	-- calcular dígitos de control 
      CALCULA_DC_60(xIMPORTE,REG_CDATOSVEHI.ABONADO,xTRIBUTO,SUBSTR(xYEAR,3,2),
			xPERIODO,xEMISOR,xDCONTROL);

	--calcular los digitos de control del cuaderno 60 modalidad 2
	CALCULA_DC_MODALIDAD2_60(xIMPORTE, REG_CDATOSVEHI.ABONADO, xTRIBUTO, SUBSTR(xYEAR,3,2), 
			'1',to_char(xHASTA,'y'), to_char(xHASTA,'ddd'), xEMISOR, xDIG_C60_M2);

    GETREFERENCIA(REG_CDATOSVEHI.ABONADO,xREFERENCIA);

    IMPORTEENCADENA(xIMPORTE,xIMPORTE_CAD);
	
	--insertamos los cotitulares del recibo
	IF REG_CDATOSVEHI.COTITULARES='S' THEN
		INSERT INTO COTITULARES_RECIBO(NIF,PROGRAMA,AYTO,PADRON,YEAR,PERIODO,RECIBO)
		SELECT NIF,'VEHICULOS',xMUNICIPIO,xPADRON,xYEAR,xPERIODO,REG_CDATOSVEHI.ABONADO
		FROM COTITULARES
		WHERE ID_CONCEPTO=REG_CDATOSVEHI.ABONADO AND PROGRAMA='VEHICULOS';
	END IF;

      -- insertar los recibos en la tabla de recibos de vehículos.
	INSERT INTO RECIBOS_VEHI
         (ABONADO,YEAR,MUNICIPIO,NIF,MARCA,MODELO,TARIFA,BASTIDOR,IMPORTE,TOTAL,
		  MATRICULA,NUMERO,LETRA,
		  DOMICILIADO,ESTADO_BANCO,ENTIDAD,SUCURSAL,DC,CUENTA,F_DOMICILIACION,DNI_TITULAR,
		  NOMBRE_TITULAR,
		  DESDE,HASTA,F_CARGO,CONCEPTO,LINEA1,LINEA2,LINEA3,
		  EMISOR,TRIBUTO,EJERCICIO,REMESA,
		  REFERENCIA,DIGITO_CONTROL,PERIODO,NOMBRE,DOMICILIO,
		  DISCRI_PERIODO,DIGITO_YEAR,F_JULIANA,DIGITO_C60_MODALIDAD2,
  		  POBLACION,PROVINCIA,CODIGO_POSTAL)
      VALUES 
		 (REG_CDATOSVEHI.ABONADO,xYEAR,xMUNICIPIO,REG_CDATOSVEHI.NIF,REG_CDATOSVEHI.MARCA,
		  REG_CDATOSVEHI.MODELO,xTARIFA,REG_CDATOSVEHI.BASTIDOR,
		  xIMPORTE_CAD,xIMPORTE,REG_CDATOSVEHI.MATRICULA,REG_CDATOSVEHI.NUMERO,
		  REG_CDATOSVEHI.LETRA,

		  REG_CDATOSVEHI.DOMICILIADO,DECODE(REG_CDATOSVEHI.DOMICILIADO,'S','EB',NULL),
		  DECODE(REG_CDATOSVEHI.DOMICILIADO,'S',REG_CDATOSVEHI.ENTIDAD,NULL),
		  DECODE(REG_CDATOSVEHI.DOMICILIADO,'S',REG_CDATOSVEHI.SUCURSAL,NULL),
		  DECODE(REG_CDATOSVEHI.DOMICILIADO,'S',REG_CDATOSVEHI.DC,NULL),
		  DECODE(REG_CDATOSVEHI.DOMICILIADO,'S',REG_CDATOSVEHI.CUENTA,NULL),
		  DECODE(REG_CDATOSVEHI.DOMICILIADO,'S',REG_CDATOSVEHI.F_DOMICILIACION,NULL),
		  DECODE(REG_CDATOSVEHI.DOMICILIADO,'S',REG_CDATOSVEHI.TITULAR,NULL),
		  
		  xNOMBRE_TITULAR,xDESDE,xHASTA,xCARGO,xCONCEPTO,
		  xLINEA1,xLINEA2,
		  xLINEA3,xEMISOR,xTRIBUTO,SUBSTR(xYEAR,3,2),xPERIODO,xREFERENCIA,xDCONTROL,
		  xPERIODO,xNOMBRE,xDomicilio,
		  '1',to_char(xHASTA,'y'), to_char(xHASTA,'ddd'),xDIG_C60_M2,
  		  xPoblacion,xProvincia,xCodPostal);

  END LOOP;

   -- Insertamos una tupla en LOGSPADRONES para controlar que esta acción ha sido ejecutada
   INSERT INTO LOGSPADRONES (MUNICIPIO,PROGRAMA,PYEAR,PERIODO,HECHO)
   VALUES (xMUNICIPIO,'VEHICULOS',xYEAR,xPERIODO,'Se Genera un Padrón');

END;
/

/*******************************************************************************
Acción: Genera todos los padrones de los municipios seleccionados.
*******************************************************************************/

CREATE OR REPLACE PROCEDURE GEN_PADRON_VEHI (
		xYEAR		IN	CHAR, 
		xPERIODO	IN	CHAR,
		xDESDE	IN	DATE,
		xHASTA	IN	DATE,	
		xCARGO	IN 	DATE,		
		xCONCEPTO	IN	VARCHAR,
		xTEXTO1	IN	VARCHAR,
		xTEXTO2	IN	VARCHAR,
		xTEXTO3	IN	VARCHAR)
AS  
   CURSOR CAYTOS IS 
      SELECT MUNICIPIO FROM TMP_AYTOS WHERE USUARIO=USER;
BEGIN   
   FOR v_aytos IN CAYTOS 
   LOOP  
      GENERA_PADRON_VEHI(v_aytos.MUNICIPIO,xYEAR,xDESDE,xHASTA,xCARGO,xCONCEPTO,
                       xTEXTO1,xTEXTO2,xTEXTO3,xPERIODO);
   END LOOP;   
END;
/


--
-- Creado: Agustín León Robles
-- Fecha: 25/02/2003
--
CREATE OR REPLACE PROCEDURE DAME_TIPO_VEHICULOS
				(xAbonado 	in 	integer,
				xYear		in 	char,
				xMunicipio	in 	char,
				xCV		out	float, 
				xKG		out	float,
 				xCC	 	out	float,
 				xPLAZAS	out	float)
AS
   xTarifa		 char(5);
   xTipoTarifa	 char(24);
   xPotencia	 float;
BEGIN

	SELECT TIPO_VEHICULO,CABALLOS_EXAC INTO xTarifa,xPotencia
		FROM VEHICULOS WHERE ABONADO=xABONADO;

	SELECT VEHI_TRAFICO INTO xTipoTarifa FROM TARIFAS_VEHICULOS 
		WHERE MUNICIPIO=xMUNICIPIO AND CODIGO=xTarifa AND ANNE=xYEAR;

	xCV:=NULL;
	xKG:=NULL;
	xCC:=NULL;
	xPLAZAS:=NULL;

	IF xTipoTarifa='TURISMO' THEN
		xCV:=xPotencia;
	ELSE
		IF xTipoTarifa='CAMION' OR xTipoTarifa='TRACTOR' OR xTipoTarifa='REMOLQUE' THEN
			xKG:=xPotencia;
		ELSE
			IF xTipoTarifa='CICLOMOTOR' OR xTipoTarifa='MOTOCICLETA' THEN
				xCC:=xPotencia;
			ELSE
				IF xTipoTarifa='AUTOBUS' THEN
					xPLAZAS:=xPotencia;
				END IF;
			END IF;
		END IF;
	END IF;

END;
/

/*******************************************************************************
Autor: Agustin Leon Robles
Fecha: 21/08/2001
Acción: Para la impresión de recibos de vehículos.
*******************************************************************************/

CREATE OR REPLACE PROCEDURE WriteTempVehi
		(v_RegistroVehi 	IN Recibos_vehi%ROWTYPE,
		xYEAR			IN CHAR,
		xPERI			IN CHAR)
AS
   xNOMBRE_ENTIDAD CHAR(50);
   xHASTA1         DATE;
   xMATRICULA 	 VARCHAR2(15);
   xCV		 FLOAT;
   xKG		 FLOAT;
   xCC		 FLOAT;
   xPLAZAS		 FLOAT;
BEGIN


	DAME_TIPO_VEHICULOS(v_RegistroVehi.ABONADO,xYear,v_RegistroVehi.MUNICIPIO,xCV,xKG,xCC,xPLAZAS);

	xMATRICULA:=GETMATRICULA(v_RegistroVehi.MATRICULA,v_RegistroVehi.NUMERO,
			v_RegistroVehi.LETRA);

	/* En caso de estar domiciliado, nombre de la Entidad */
	xNOMBRE_ENTIDAD:='';
	begin
	   SELECT NOMBRE INTO xNOMBRE_ENTIDAD FROM ENTIDADES 
				WHERE CODIGO=v_RegistroVehi.ENTIDAD;
	EXCEPTION
	   WHEN NO_DATA_FOUND THEN
	        NULL;
	end;

   	xHASTA1:=v_RegistroVehi.HASTA+1; /* fecha del hasta mas un día */   

      INSERT INTO IMP_RECIBOS_VEHI 
      (USUARIO,ANIO,PERIODO,ABONADO,NIF,NOMBRE,DOMIFISCAL,CODPOSTAL,
	POBLACION,PROVINCIA,TOTAL,TARIFA,MARCA,MODELO,MATRICULA,
      REFERENCIA,DC,TRIBUTO,EJERCICIO,REMESA,IMPO,EMISOR,DESDE,
	HASTA,CARGO,HASTA1,ENTIDAD,SUCURSAL,DIGITOS,CUENTA,TITULAR,
	NOMBRE_ENTIDAD,NOMBRE_TITULAR,CONCEPTO,
	DISCRI_PERIODO,DIGITO_YEAR,F_JULIANA,DIGITO_C60_MODALIDAD2,
 	COD_BARRAS_MOD1,COD_BARRAS_MOD2,
	BASTIDOR,CV,KG,CC,PLAZAS)
      VALUES           
      (UID,xYEAR,xPERI,v_RegistroVehi.ABONADO,v_RegistroVehi.NIF,
	v_RegistroVehi.NOMBRE,v_RegistroVehi.DOMICILIO,
	v_RegistroVehi.CODIGO_POSTAL,v_RegistroVehi.POBLACION,
	v_RegistroVehi.PROVINCIA,v_RegistroVehi.TOTAL,v_RegistroVehi.TARIFA,
	v_RegistroVehi.MARCA,v_RegistroVehi.MODELO,xMATRICULA,
      v_RegistroVehi.REFERENCIA,v_RegistroVehi.DIGITO_CONTROL,
	v_RegistroVehi.TRIBUTO,v_RegistroVehi.EJERCICIO,v_RegistroVehi.REMESA,
	v_RegistroVehi.IMPORTE,v_RegistroVehi.EMISOR,v_RegistroVehi.DESDE,
	v_RegistroVehi.HASTA,v_RegistroVehi.F_CARGO,xHASTA1,
	v_RegistroVehi.ENTIDAD,v_RegistroVehi.SUCURSAL,v_RegistroVehi.DC,
	v_RegistroVehi.CUENTA,v_RegistroVehi.DNI_TITULAR,
	xNOMBRE_ENTIDAD,v_RegistroVehi.NOMBRE_TITULAR,v_RegistroVehi.CONCEPTO,
	v_RegistroVehi.DISCRI_PERIODO,v_RegistroVehi.DIGITO_YEAR,
	v_RegistroVehi.F_JULIANA,v_RegistroVehi.DIGITO_C60_MODALIDAD2,
			
	'90502'||v_RegistroVehi.EMISOR||v_RegistroVehi.REFERENCIA||
	v_RegistroVehi.DIGITO_CONTROL||v_RegistroVehi.TRIBUTO||
	v_RegistroVehi.EJERCICIO||v_RegistroVehi.REMESA||
	LPAD(v_RegistroVehi.IMPORTE*100,8,'0'),

	'90521'||v_RegistroVehi.EMISOR||v_RegistroVehi.REFERENCIA||
	v_RegistroVehi.DIGITO_C60_MODALIDAD2||v_RegistroVehi.DISCRI_PERIODO||
	v_RegistroVehi.TRIBUTO||v_RegistroVehi.EJERCICIO||
	v_RegistroVehi.DIGITO_YEAR||v_RegistroVehi.F_JULIANA||
	LPAD(v_RegistroVehi.IMPORTE*100,8,'0')||'0',
	v_RegistroVehi.BASTIDOR,xCV,xKG,xCC,xPLAZAS);
END;
/

/*******************************************************************************
Acción: Impresión de los recibos de Vehículos.
MODIFICACIÓN: 26/04/2005 M. Carmen Junco Gómez. Se modifica el procedimiento
	para pasar la sentencia del cursor ya compuesta como parámetro, al incluir
	en delphi una nueva opción para imprimir los recibos de un mismo nif, de 
	un municipio, año y periodo determinados.
MODIFICACIÓN: 05/09/2005 Gloria Mª Calle Hernandez. Añadido impresión ordenada por
		  codigo postal y domicilio fiscal.
*******************************************************************************/

CREATE OR REPLACE PROCEDURE IMPRIME_RECIBOS_VEHI (
		xMUNICIPIO 	IN CHAR,
		xID 	  		IN INTEGER,
		xYEAR 		IN CHAR,
		xPERI 		IN CHAR,
		xRECIDESDE 	IN INTEGER,
		xRECIHASTA 	IN INTEGER,
		xSENTENCIA	IN	VARCHAR2)
AS 

	TYPE tCURSOR 		IS REF CURSOR;  -- define REF CURSOR type
    vCURSOR    	 		tCURSOR;     -- declare cursor variable
    v_RegistroVehi    Recibos_vehi%ROWTYPE;

	I INTEGER;	   

BEGIN

   I:=0;

   DELETE FROM IMP_RECIBOS_VEHI WHERE USUARIO=UID;
  
   --imprimir un solo recibo
   IF xID<>0 THEN

      SELECT * INTO v_RegistroVehi FROM RECIBOS_VEHI WHERE ID=xID;
		WriteTempVehi(v_RegistroVehi,xYear,xPeri);

	ELSE /* Si se ha de imprimir más de un recibo */
	
	
		--Asignar consulta a cursor, abrirlo y recorrerlo
		OPEN vCURSOR FOR xSENTENCIA USING xMUNICIPIO,xYEAR,xPERI;
		LOOP
			FETCH vCURSOR INTO v_RegistroVehi;
			EXIT WHEN vCURSOR%NOTFOUND;
			
			IF (xRECIHASTA>0) THEN
			
				I:=I+1;	      
      
				IF (I >= xRECIDESDE AND I <= xRECIHASTA) THEN
					WriteTempVehi(v_RegistroVehi,xYear,xPeri);
	      	ELSE
         		IF I > xRECIHASTA THEN
		      		EXIT;
            	END IF;
         	END IF;
         	
         ELSE
         
         	WriteTempVehi(v_RegistroVehi,xYear,xPeri);
         	
         END IF;

   	END LOOP;
	   CLOSE vCURSOR;
		
   END IF; /* del IF xID<>0 THEN */

END;
/

/*******************************************************************************
Acción: Marcar vehículos para incorporarlos al padrón.
MODIFICACIÓN: 28/06/2002 M. Carmen Junco Gómez. Insertar una tupla en LogsPadrones
		  para controlar que se han incorporado al padrón aquellos abonados que
		  no estaban incorporados y cuya fecha de alta es menor o igual a la 
		  pasado como parámetro.
MODIFICACIÓN: 03/12/2002 M. Carmen Junco Gómez. Insertamos los campos municipio y
		  periodo en logspadrones
MODIFICACIÓN: 01/02/2005 Gloria Maria Calle Hernandez. Marcamos como 'N' aquellos 
		  abonados a los que se les haya liquidado dicho año.
MODIFICACIÓN: 15/02/2005 Lucas Fernández Pérez. Sólo incorpora vehículos del 
		municipio del usuario o de los municipios que el usuario haya seleccionado. 
		Antes incorporaba los vehículos de todos los municipios.
MODIFICACIÓN: 06/02/2006 Gloria Maria Calle. Al añadir campo F_Liquidacion a vehi 
		hay que especificar el campo de la tabla a la cual pertenece.
*******************************************************************************/

CREATE OR REPLACE PROCEDURE INCOR_PADRON_VEHI (
		xFECHA_EMISION 	IN DATE,
		xFECHA_ALTA 	IN DATE)
AS
   -- cursor que recorre los distintos municipios de los recibos que se han 
   -- incorporado al padrón en la fecha=xFecha_Emision
   CURSOR CMUNI IS SELECT DISTINCT MUNICIPIO FROM VEHICULOS
			 WHERE F_INCORPORACION=xFECHA_EMISION AND
  		 		   MUNICIPIO IN (SELECT MUNICIPIO FROM TMP_AYTOS WHERE USUARIO=USER);
BEGIN

   UPDATE VEHICULOS SET INCORPORADO='S',F_INCORPORACION=xFECHA_EMISION
   WHERE INCORPORADO ='N' AND F_BAJA IS NULL AND F_ALTA<=xFECHA_ALTA
			AND MUNICIPIO IN (SELECT MUNICIPIO FROM TMP_AYTOS WHERE USUARIO=USER);

   update vehiculos set incorporado='N' 
    where abonado in (select distinct v.abonado from liquidaciones l join vehiculos v 
                          on l.nif=v.nif and v.municipio=l.municipio 
 	      		   	   where concepto=(select concepto from programas where programa='VEHICULOS')
					     and to_char(l.f_liquidacion,'yyyy')=to_char(sysdate,'yyyy')  
					     and v.f_baja is null and v.incorporado='S' 
                		 AND v.MUNICIPIO IN (SELECT MUNICIPIO FROM TMP_AYTOS WHERE USUARIO=USER)
					  --   and instr(l.motivo,v.marca)>0 and instr(l.motivo,trim(v.modelo))>0 
					     and (instr(l.motivo,trim(v.bastidor))>0 
					          or 
						      instr(l.motivo,trim(v.numero))>0 
						      and 
						      decode(v.letra,null,instr(l.motivo,trim(v.matricula)),instr(l.motivo,trim(v.letra)))>0)); 

   FOR vMUNI IN CMUNI 
   LOOP
      -- Insertamos una tupla en LOGSPADRONES para controlar que esta acción ha sido ejecutada
      INSERT INTO LOGSPADRONES (MUNICIPIO,PROGRAMA,HECHO)
      VALUES (vMUNI.MUNICIPIO,'VEHICULOS','Se realiza una Incorporación al Padrón');     
   END LOOP;

END;
/

/*******************************************************************************
Acción: Crear una nueva tarifa de tráfico o modificar una existente.
MODIFICACIÓN: 12/09/2001 Lucas Fernández Pérez. Adaptación al euro.
*******************************************************************************/

CREATE OR REPLACE PROCEDURE INSER_MOD_TAR_VEHI(
       xID 			IN INTEGER,
       xTARIFA 		IN CHAR,
       xVEHI_TRAFICO 	IN CHAR,
       xMUNICIPIO 	IN CHAR,
       xANNE 		IN CHAR,
       xDESCRIPCION 	IN CHAR,
       xCABALLOS_MI 	IN FLOAT,
       xCABALLOS_MA 	IN FLOAT,
       xCUOTA_BASE 	IN FLOAT,
       xCOEFICIENTE 	IN FLOAT,
       xIMPORTE 		IN FLOAT
)
AS

BEGIN

  /* Se crea una nueva tarifa */

  IF xID=0 THEN

      INSERT INTO TARIFAS_VEHICULOS
          (CODIGO, VEHI_TRAFICO, MUNICIPIO, ANNE, DESCRIPCION,CABALLOS_MIN, CABALLOS_MAX,
           CUOTA_BASE, COEFICIENTE, IMPORTE)
      VALUES
          (xTARIFA, xVEHI_TRAFICO, xMUNICIPIO, xANNE, xDESCRIPCION,xCABALLOS_MI,xCABALLOS_MA,
           ROUND(xCUOTA_BASE,2), xCOEFICIENTE, ROUND(xIMPORTE,2));

  /* Se modifica una nueva tarifa */

  ELSE

      UPDATE TARIFAS_VEHICULOS SET VEHI_TRAFICO=xVEHI_TRAFICO,DESCRIPCION=xDESCRIPCION,
                                   CUOTA_BASE=ROUND(xCUOTA_BASE,2),COEFICIENTE=xCOEFICIENTE,
                                   IMPORTE=ROUND(xIMPORTE,2),CABALLOS_MIN=xCABALLOS_MI,
                                   CABALLOS_MAX=xCABALLOS_MA
      WHERE ID=xID;

  END IF;

END;
/




--
-- CREADO: 12/06/2006. AGUSTIN LEON ROBLES.
-- PARA AVERIGUAR LA TARIFA SEGUN LA POTENCIA, CILINDRADA,CARGA O PLAZAS
--
CREATE OR REPLACE PROCEDURE DAMETARIFAVEHICULO
	(xAYTO IN CHAR,xTIPO_VEHICULO in VARCHAR2,xPOTENCIA IN FLOAT,
	xCILINDRADA IN FLOAT,xCARGA IN FLOAT, xPLAZAS IN FLOAT, 
	xTARIFA OUT FLOAT, xCOD_TARIFA OUT CHAR)
AS
BEGIN

	xTARIFA:='00022';

	--TURISMOS
	IF TRIM(xTIPO_VEHICULO)='TURISMO' THEN
		SELECT CODIGO INTO xCOD_TARIFA FROM TARIFAS_VEHICULOS 
		WHERE MUNICIPIO=xAyto AND TRIM(VEHI_TRAFICO)='TURISMO' AND ANNE=TO_CHAR(SYSDATE,'YYYY')
		AND CABALLOS_MIN<=xPOTENCIA AND CABALLOS_MAX>=xPOTENCIA;
		
		xTARIFA:=xPOTENCIA;
	END IF;
	     			
	--CAMIONES
	IF TRIM(xTIPO_VEHICULO)='CAMION' THEN
		SELECT CODIGO INTO xCOD_TARIFA FROM TARIFAS_VEHICULOS 
		WHERE MUNICIPIO=xAyto AND TRIM(VEHI_TRAFICO)='CAMION' AND ANNE=TO_CHAR(SYSDATE,'YYYY')
		AND CABALLOS_MIN<=xCARGA AND CABALLOS_MAX>=xCARGA;
		
		xTARIFA:=xCARGA;
	END IF;
	     			
	--CICLOMOTOR
	IF TRIM(xTIPO_VEHICULO)='CICLOMOTOR' THEN
		SELECT CODIGO INTO xCOD_TARIFA FROM TARIFAS_VEHICULOS 
		WHERE MUNICIPIO=xAyto AND TRIM(VEHI_TRAFICO)='CICLOMOTOR' AND ANNE=TO_CHAR(SYSDATE,'YYYY');
		
		xTARIFA:=xCILINDRADA;
	END IF;
	     			
	--MOTOCICLETA
	IF TRIM(xTIPO_VEHICULO)='MOTOCICLETA' THEN
		SELECT CODIGO INTO xCOD_TARIFA FROM TARIFAS_VEHICULOS 
		WHERE MUNICIPIO=xAyto AND TRIM(VEHI_TRAFICO)='MOTOCICLETA' AND ANNE=TO_CHAR(SYSDATE,'YYYY')
		AND CABALLOS_MIN<=xCILINDRADA AND CABALLOS_MAX>=xCILINDRADA;
		
		xTARIFA:=xCILINDRADA;
		
	END IF;
	     			
	--TRACTOR
	IF TRIM(xTIPO_VEHICULO)='TRACTOR' THEN
		SELECT CODIGO INTO xCOD_TARIFA FROM TARIFAS_VEHICULOS 
		WHERE MUNICIPIO=xAyto AND TRIM(VEHI_TRAFICO)='TRACTOR' AND ANNE=TO_CHAR(SYSDATE,'YYYY')
		AND CABALLOS_MIN<=xPOTENCIA AND CABALLOS_MAX>=xPOTENCIA;
		
		xTARIFA:=xPOTENCIA;
	END IF;
	
	--REMOLQUE
	IF TRIM(xTIPO_VEHICULO)='REMOLQUE' THEN
		SELECT CODIGO INTO xCOD_TARIFA FROM TARIFAS_VEHICULOS 
		WHERE MUNICIPIO=xAyto AND TRIM(VEHI_TRAFICO)='REMOLQUE' AND ANNE=TO_CHAR(SYSDATE,'YYYY')
		AND CABALLOS_MIN<=xCARGA AND CABALLOS_MAX>=xCARGA;
		
		xTARIFA:=xPOTENCIA;
	END IF;
	
	--AUTOBUS
	IF TRIM(xTIPO_VEHICULO)='AUTOBUS' THEN
		SELECT CODIGO INTO xCOD_TARIFA FROM TARIFAS_VEHICULOS 
		WHERE MUNICIPIO=xAyto AND TRIM(VEHI_TRAFICO)='AUTOBUS' AND ANNE=TO_CHAR(SYSDATE,'YYYY')
		AND CABALLOS_MIN<=xPLAZAS AND CABALLOS_MAX>=xPLAZAS;
		
		xTARIFA:=xPOTENCIA;
	END IF;
	
END;
/

--********************************************************************************************
-- Carga el registro de tráfico que se pasa como parámetro. Devuelve salida 1: sin problemas
-- o 0: no cargado por incidencias
-- Modificado: 29-01-2003. Lucas Fernández Pérez. Añade un nuevo código de error (10) si
-- el tipo de registro y el codigo de tramite son incompatibles. Ej: A - BAJAD, no tiene
-- sentido un alta de una baja definitiva.
-- Modificado: 12/06/2006. Agustín León Robles. Adaptación para que se pueda cargar un disco sin 
--					tener previamente cargada la información en VEHICULOS.
-- Modificado: 09/10/2006. Agustín León Robles. Se incluyen la adaptación para los registros DUPLI.
-- Modificado: 23/10/2006. Lucas Fernández Pérez. Las rematriculaciones ponían como nueva matricula
--				la misma matrícula anterior. Se cambia para que la nueva matricula se ponga como 
--				matricula del vehículo. 
--				También se cambia para que busque bien las matriculas sin letra
-- Modificado: 30/10/2006. Lucas Fernández Pérez. Ajuste en las liquidaciones.
-- Modificado: 31/10/2006. Lucas Fernández Pérez. Refresca el bastidor en vehículos siempre que puede.
--							En los movimientos A-MATRI, A-MATCI no limpiaba la tabla de incidencias al matricular
-- Modificado: 15/02/2007. Lucas Fernández Pérez. Se protege la consulta que comprueba si se ha generado un
--							padron en el mismo año
CREATE OR REPLACE PROCEDURE CargarRegistroTrafico(
				IDTemp 		IN 		INTEGER,	
				xSALIDA 	OUT 	INTEGER)  
AS

	xREGTRAFICO TRAFICO_NEW%ROWTYPE;
	xABONADO 		INTEGER;
	xNIF     		CHAR(10);
	
	xCIUDAD  		CHAR(3);
	xNUMERO  		CHAR(6);
	xLETRAS  		CHAR(3);	
	xCIUDAD_OLD		CHAR(3);
	xNUMERO_OLD		CHAR(6);
	xLETRAS_OLD		CHAR(3);	
	xF_BAJA  		DATE;
	xCONTINUAR 		BOOLEAN;
	xCuantos 		INTEGER;
	xCOD_TARIFA		CHAR(5);
	xTARIFA			FLOAT;
	xPadronGenerado INTEGER;
	xCreaVehi 		CHAR(1);
   
BEGIN

	-- Estado sin incidencias
	xSALIDA:=1;

	SELECT * INTO xREGTRAFICO FROM TRAFICO_NEW WHERE ID=IDTEMP;

	-- descomponemos la matrícula en ciudad,numero y letras
	SplitMatricula(xREGTRAFICO.MATRICULA,xCIUDAD,xNUMERO,xLETRAS);

	-- Comprobamos incidencias básicas que se pueden producir
	TRAFICO_INCIDENCIAS_BASICAS(IDTEMP,xREGTRAFICO.MUNICIPIO,xREGTRAFICO.TIPO_REGISTRO,xREGTRAFICO.TIPO_VEHICULO);

	-- si se han producido incidencias diferentes a 
	-- 0: REGISTRO NO CARGADO y 8: PENDIENTE SELECCIONA CARGA MANUAL
	-- abortamos el proceso 
	SELECT COUNT(*) INTO xCuantos FROM TMP_INCIDENCIAS_TRAFICO WHERE ID_TRAFICO=IDTEMP AND MARCA_ERROR NOT IN (0,8);
	
	IF xCuantos > 0 THEN
	
		xSALIDA:=0;		
		RETURN;	
		
	END IF;   
	
	--LOS CASOS MODIF,MODIT NO SE TRATAN
	IF xREGTRAFICO.CODIGO_TRAMITE IN ('MODIF','MODIT') THEN
				
		INSERT INTO TMP_INCIDENCIAS_TRAFICO(ID_TRAFICO,MARCA_ERROR,DESC_ERROR) VALUES (IDTEMP,9,'NO CARGADO POR SER DE TIPO MODIT,MODIF');
		xSALIDA:=0;
		RETURN;
		
	END IF;
	
	
	--SIEMPRE BUSCAMOS EL VEHICULO POR MATRICULA
	if TRIM(xCiudad) is null then
		select count(*),MAX(ABONADO),MAX(F_BAJA) into xCuantos,xABONADO,xF_BAJA FROM VEHICULOS
		WHERE MUNICIPIO=xREGTRAFICO.AYTO AND TRIM(MATRICULA) is null AND TRIM(NUMERO)=TRIM(xNUMERO) AND TRIM(LETRA)=TRIM(xLETRAS);	
	elsif TRIM(xLetras) is null then -- Las matriculas antiguas no tienen letra. Ej: B272139
		select count(*),MAX(ABONADO),MAX(F_BAJA) into xCuantos,xABONADO,xF_BAJA FROM VEHICULOS
		WHERE MUNICIPIO=xREGTRAFICO.AYTO AND TRIM(MATRICULA)=TRIM(xCIUDAD) AND TRIM(NUMERO)=TRIM(xNUMERO) AND TRIM(LETRA) is null;
	else
		select count(*),MAX(ABONADO),MAX(F_BAJA) into xCuantos,xABONADO,xF_BAJA FROM VEHICULOS
		WHERE MUNICIPIO=xREGTRAFICO.AYTO AND TRIM(MATRICULA)=TRIM(xCIUDAD) AND TRIM(NUMERO)=TRIM(xNUMERO) AND TRIM(LETRA)=TRIM(xLETRAS);
	end if;
	
	-- un alta nueva o un alta por transferencia
	IF xREGTRAFICO.TIPO_REGISTRO='A' THEN
	
		IF (xREGTRAFICO.CODIGO_TRAMITE IN ('MATCI','MATRI','TRANS','DUPLI')) THEN	    
		
			--
	      	-- Alta por matriculacion de vehiculo o ciclomotor
	      	--
	      	IF xREGTRAFICO.CODIGO_TRAMITE IN ('MATCI','MATRI') THEN
	   			
				-- Si el vehículo estaba ya dado de alta (poseía matrícula)
 				-- se marca como 3: ERROR: ALTA YA EXISTE
				IF xCUANTOS > 0 THEN
			
					INSERT INTO TMP_INCIDENCIAS_TRAFICO(ID_TRAFICO,MARCA_ERROR,DESC_ERROR) VALUES (IDTEMP,3,'ERROR: ALTA YA EXISTE');						
					
					--ES POSIBLE QUE ADEMAS PUEDIERA ESTAR DADO DE BAJA EL VEHICULO
					IF (xF_BAJA IS NOT NULL) THEN
						INSERT INTO TMP_INCIDENCIAS_TRAFICO(ID_TRAFICO,MARCA_ERROR,DESC_ERROR) VALUES (IDTEMP,6,'ERROR: VEHÍCULO DADO DE BAJA');
					END IF;
						
					xSALIDA:=0;
						
					RETURN;
					
				ELSE
					
					--es posible que lo tengamos dado de alta, para solo grabarle la matricula, en el caso de haber generado la autoliquidacion
					select count(*) into xCuantos FROM VEHICULOS
					WHERE MUNICIPIO=xREGTRAFICO.AYTO AND TRIM(BASTIDOR)=TRIM(xREGTRAFICO.BASTIDOR);
					if xCuantos > 0 then
					
						UPDATE VEHICULOS SET MATRICULA=xCiudad,NUMERO=xNumero,LETRA=xLetras,
	                           MOTIVO_ALTA='TRÁFICO INFORMA DE LA MATRÍCULA, FECHA: '||TO_CHAR(xREGTRAFICO.FECHA_TRAMITE)
	      				WHERE MUNICIPIO=xREGTRAFICO.AYTO AND TRIM(BASTIDOR)=TRIM(xREGTRAFICO.BASTIDOR);
	      				
	      				DELETE FROM TMP_INCIDENCIAS_TRAFICO WHERE ID_TRAFICO=IDTEMP;

	      				return;
	      									
					end if;
	   		
				END IF;
	      		
				-- Aqui llegados, no se ha encontrado el vehículo ni por matricula ni por bastidor.
				-- Dependiendo de la configuración del municipio, se inserta el vehículo o se da un error de tipo 4
				select trafico_creavehi_matri into xCreaVehi from datosper where municipio=xREGTRAFICO.AYTO;
				if xCreaVehi='N' then
   					INSERT INTO TMP_INCIDENCIAS_TRAFICO(ID_TRAFICO,MARCA_ERROR,DESC_ERROR) VALUES (IDTEMP,4,'ERROR: EL VEHÍCULO NO EXISTE');
   					xSALIDA:=0;
	   				RETURN;
	   			end if;
	   			
				-- Aqui llega si por configuración se indica que se deben insertar los vehiculos no encontrados
	   			--  cuando se está matriculando.
	   			
	     		--RECOJER EL CODIGO DE LA TARIFA Y LA POTENCIA REAL O CARGA O CILINDRADA O PLAZAS
	     		DAMETARIFAVEHICULO(xREGTRAFICO.Ayto,xREGTRAFICO.TIPO_VEHICULO,xREGTRAFICO.POTENCIA,xREGTRAFICO.CILINDRADA,
	     							xREGTRAFICO.CARGA,xREGTRAFICO.PLAZAS,xTARIFA,xCOD_TARIFA);
	     	
	     		--DAR DE ALTA EL NUEVO VEHICULO
	      		INSERTAVEHICULO(xREGTRAFICO.DNI,null,xREGTRAFICO.Ayto,substr(xREGTRAFICO.Marca_Modelo,1,instr(xREGTRAFICO.Marca_Modelo,' ')-1),
       				substr(xREGTRAFICO.marca_modelo,instr(xREGTRAFICO.marca_modelo,' ')+1,25),
       				xCOD_TARIFA,TRIM(xREGTRAFICO.BASTIDOR),'N',TRIM(xCIUDAD),TRIM(xNUMERO),TRIM(xLETRAS),xREGTRAFICO.CILINDRADA,xTARIFA,
       				NULL,NULL,NULL,NULL,NULL,NULL,xREGTRAFICO.FECHA_TRAMITE,'TRAFICO INFORMA DEL ALTA',NULL,NULL,NULL,NULL,xABONADO);
       				
		   	END IF; --FINAL DEL IF xREGTRAFICO.CODIGO_TRAMITE IN ('MATCI','MATRI') 
	      		
			-- si se trata de una transferencia, modificaremos también los datos fiscales
			-- puede que no sea necesario si la baja está en otro municipio, pero así 
			-- contemplamos ambas posibilidades
			IF xREGTRAFICO.CODIGO_TRAMITE IN ('TRANS','DUPLI') THEN
				--
				-- PUEDE SER UN ALTA POR TRANSFERENCIA DE OTRO MUNICIPIO, CON LO CUAL HAY QUE DARLO DE ALTA
				--
				IF xABONADO IS NULL THEN
					
					--RECOJER EL CODIGO DE LA TARIFA Y LA POTENCIA REAL O CARGA O CILINDRADA O PLAZAS
	     			DAMETARIFAVEHICULO(xREGTRAFICO.Ayto,xREGTRAFICO.TIPO_VEHICULO,xREGTRAFICO.POTENCIA,xREGTRAFICO.CILINDRADA,
	     							xREGTRAFICO.CARGA,xREGTRAFICO.PLAZAS,xTARIFA,xCOD_TARIFA);
	     	
	     			--DAR DE ALTA EL NUEVO VEHICULO
	      			INSERTAVEHICULO(xREGTRAFICO.DNI,null,xREGTRAFICO.Ayto,substr(xREGTRAFICO.Marca_Modelo,1,instr(xREGTRAFICO.Marca_Modelo,' ')-1),
       					substr(xREGTRAFICO.marca_modelo,instr(xREGTRAFICO.marca_modelo,' ')+1,25),
       					xCOD_TARIFA,TRIM(xREGTRAFICO.BASTIDOR),'N',TRIM(xCIUDAD),TRIM(xNUMERO),TRIM(xLETRAS),xREGTRAFICO.CILINDRADA,xTARIFA,
       					NULL,NULL,NULL,NULL,NULL,NULL,xREGTRAFICO.FECHA_TRAMITE,'TRAFICO INFORMA DEL ALTA POR A-DUPLI',NULL,NULL,NULL,NULL,xABONADO);
       				
       				--	
       				--En los movimientos de Trans y Dupli correspondientes al año anterior se ha de generar 
       				--una liquidacion si el padron este año ya se ha generado, y no hay un movimiento de baja
       				--que anule este alta y sea también la baja en el año anterior
       				--Insertamos en la tabla temporal porque en otra fecha de tramite puede venir una baja, con lo cual
       				--no habria que hacer nada si la baja fuese en el año anterior. 
       				--Al final de todo el proceso se generaran las liquidaciones de los registros
       				--que queden en esta tabla temporal
       				--Esto se hace sobre el año anterior, porque si el alta es del año actual, corresponde cobrarla
       				--al municipio del que proviene el vehículo. P.ej: un A-Trans por compra de vehiculo con fecha de
       				--3 de enero lo debe cobrar el municipio del antiguo propietario, y ese año no lo cobra nuestro municipio.
       				--
       				IF To_Char(xREGTRAFICO.FECHA_TRAMITE,'yyyy') < substr(xREGTRAFICO.Fich_Trafico,5,4) then
       					
       					begin
       					 	-- Busca en logspadrones si se ha generado ya el padrón o no.
       					 	SELECT DECODE(HECHO,'Se Genera un Padrón',1,0) INTO xPadronGenerado
       					 	FROM LOGSPADRONES WHERE id=
 							(SELECT MAX(id) FROM LOGSPADRONES WHERE PROGRAMA='VEHICULOS' 
 								AND PYEAR=substr(xREGTRAFICO.Fich_Trafico,5,4)
 								AND HECHO IN  ('Se Genera un Padrón','Se Borra un Padrón'));
 						exception
 							when no_data_found then
 								xPadronGenerado:=0;
 						end;
       					
 						-- Si el padrón se ha generado ya, este registro es posible que se necesite liquidar
 						if (xPadronGenerado=1) then
    	   					INSERT INTO TMP_LISTACARGOS(USUARIO,CARGO,FECHA,SESIONID) 
	       					values (user,xREGTRAFICO.MATRICULA,xREGTRAFICO.FECHA_TRAMITE,xREGTRAFICO.ID);
 						end if;
 						
       				End IF;
       				
				ELSE
				
					UPDATE USUARIOSGT SET TEXTO='Cambio de titular por estado A-TRANS'
					WHERE USUARIO=USER;
					
		   			UPDATE VEHICULOS SET NIF=trim(xREGTRAFICO.DNI),
						REPRESENTANTE=NULL,
				      	IDDOMIALTER=NULL,
				      	COTITULARES='N',
				      	DOMICILIADO='N',ENTIDAD=NULL,SUCURSAL=NULL,DC=NULL,CUENTA=NULL,TITULAR=NULL,
				      	F_ALTA=xREGTRAFICO.FECHA_TRAMITE,
					  	F_BAJA=NULL,
					  	MOTIVO_BAJA=NULL,
						INCORPORADO='S',
						F_INCORPORACION=sysdate,
				      	MOTIVO_ALTA='Transferencia del NIF: '||NIF||' al NIF: '|| trim(xREGTRAFICO.DNI)||
				      				'. Fecha anterior alta: '|| TO_CHAR(F_ALTA,'DD/MM/YYYY'),
				      	TIPO_BONI_EX=NULL,ID_BONI_EX=0,YEAR_BONI=NULL,
				      	BASTIDOR=TRIM(xREGTRAFICO.BASTIDOR) -- refresca el bastidor
	        		WHERE ABONADO=xABONADO;
	         		
	        		-- si había cotitulares los borramos
	        		DELETE FROM COTITULARES WHERE PROGRAMA='VEHICULOS' AND ID_CONCEPTO=xABONADO;
	        	END IF;
			END IF;

			DELETE FROM TMP_INCIDENCIAS_TRAFICO WHERE ID_TRAFICO=IDTEMP;
         	
				
		ELSE 
			
			INSERT INTO TMP_INCIDENCIAS_TRAFICO(ID_TRAFICO,MARCA_ERROR,DESC_ERROR)
			VALUES (IDTEMP,10,'EL TIPO DE REGISTRO Y CÓDIGO DE TRAMITE SON INCOMPATIBLES');
			xSALIDA:=0;
						
		END IF; --final del IF (xREGTRAFICO.CODIGO_TRAMITE IN ('MATCI','MATRI','TRANS','DUPLI')) THEN	    

		
		RETURN;
		
	END IF; --final del IF xREGTRAFICO.TIPO_REGISTRO='A' THEN

   
   
	--
	-- BAJAS
	--
	IF xREGTRAFICO.TIPO_REGISTRO='B' THEN
		
		--PARA LAS BAJAS TIENE QUE EXISTIR EL VEHICULO GRABADO PREVIAMENTE
		IF xABONADO IS NULL THEN
	  
   			INSERT INTO TMP_INCIDENCIAS_TRAFICO(ID_TRAFICO,MARCA_ERROR,DESC_ERROR) VALUES (IDTEMP,4,'ERROR: EL VEHÍCULO NO EXISTE');
   			xSALIDA:=0;
   			RETURN;
   		
		END IF;
	
		IF (xREGTRAFICO.CODIGO_TRAMITE IN ('BAJAD','BAJAT','TRANS','DUPLI')) THEN
 		
			-- Tendremos que comprobar que el DNI del propietario del	
			-- vehículo sea el mismo del que pretende dar la baja, y que el vehículo no esté ya 
			-- dado de baja. 	

	   		xCONTINUAR:=TRUE;		

	   		-- recogemos los datos que faltan
	   		SELECT NIF,F_BAJA INTO xNIF,xF_BAJA FROM VEHICULOS WHERE ABONADO=xABONADO;
	   		

	   		-- si ya está dado de baja informamos del error
	   		IF xF_BAJA IS NOT NULL THEN
	      	
	   			INSERT INTO TMP_INCIDENCIAS_TRAFICO(ID_TRAFICO,MARCA_ERROR,DESC_ERROR) VALUES (IDTEMP,6,'ERROR: VEHÍCULO DADO DE BAJA');
	      		xCONTINUAR:=FALSE;
	      		xSALIDA:=0;
	   		END IF;	

	   		-- si el dni del propietario no coincide con el del disco, informamos del error
	   		IF (TRIM(xREGTRAFICO.DNI)<>TRIM(xNIF)) THEN
	      		INSERT INTO TMP_INCIDENCIAS_TRAFICO(ID_TRAFICO,MARCA_ERROR,DESC_ERROR) VALUES (IDTEMP,5,'ERROR: DNI NO ASOCIADO AL VEHÍCULO');
	      		xCONTINUAR:=FALSE;	
	      		xSALIDA:=0;
	   		END IF;

	   		-- si no se produce ninguna incidencia, damos la baja
	   		IF xCONTINUAR THEN
	   		
	   			UPDATE VEHICULOS SET F_BAJA=xREGTRAFICO.FECHA_TRAMITE,
					MOTIVO_BAJA=DECODE(xREGTRAFICO.CODIGO_TRAMITE,
										'TRANS','Baja por Transferencia. Fecha: '||to_char(xREGTRAFICO.FECHA_TRAMITE,'dd/mm/yyyy')||' F. Proceso:'||to_char(sysdate,'dd/mm/yyyy'),
										'DUPLI','Baja por B-DUPLI. Fecha: '||to_char(xREGTRAFICO.FECHA_TRAMITE,'dd/mm/yyyy')||' F. Proceso:'||to_char(sysdate,'dd/mm/yyyy'),
	   			    					'Baja enviada por tráfico. Fecha: '||TO_CHAR(xREGTRAFICO.FECHA_TRAMITE)||' F. Proceso:'||to_char(sysdate,'dd/mm/yyyy')),
					INCORPORADO='N',
					F_INCORPORACION=NULL,
			      	BASTIDOR=TRIM(xREGTRAFICO.BASTIDOR) -- refresca el bastidor
		   		WHERE ABONADO=xABONADO;
		   		
				DELETE FROM TMP_INCIDENCIAS_TRAFICO WHERE ID_TRAFICO=IDTEMP;
				
				-- Si la baja es del año anterior, y en una fecha igual o posterior (pero en el mismo año)
				-- a algún movimiento de alta que insertase en tmp__listacargos, se borra
				-- la posible liquidacion que se fuera a generar
   				if To_Char(xREGTRAFICO.FECHA_TRAMITE,'yyyy') < substr(xREGTRAFICO.Fich_Trafico,5,4) then
					Delete From TMP_LISTACARGOS 
					where USUARIO=user and CARGO=xREGTRAFICO.MATRICULA and FECHA<=xREGTRAFICO.FECHA_TRAMITE;
				end if;
				
	   		END IF;
	   		
		ELSE
			INSERT INTO TMP_INCIDENCIAS_TRAFICO(ID_TRAFICO,MARCA_ERROR,DESC_ERROR)
			VALUES (IDTEMP,10,'EL TIPO DE REGISTRO Y CÓDIGO DE TRAMITE SON INCOMPATIBLES');
			xSALIDA:=0;
			
		END IF; --final del IF (xREGTRAFICO.CODIGO_TRAMITE IN ('BAJAD','BAJAT','TRANS','DUPLI')) 
		
	END IF; --final del IF xREGTRAFICO.TIPO_REGISTRO='B' 


 	--
 	--
 	-- REMATRICULACIONES
	--
 	IF xREGTRAFICO.TIPO_REGISTRO='R' THEN     
 	
 		xCONTINUAR:=TRUE;

 		-- descomponemos la matrícula ANTERIOR en ciudad,numero y letras
		SplitMatricula(xREGTRAFICO.MATRICULA_ANTERIOR,xCIUDAD_OLD,xNUMERO_OLD,xLETRAS_OLD); 
	
		--BUSCAMOS EL VEHICULO POR MATRICULA ANTERIOR
		if xCiudad_Old is null then
			select count(*),MAX(ABONADO),MAX(F_BAJA) into xCuantos,xABONADO,xF_BAJA FROM VEHICULOS
			WHERE MUNICIPIO=xREGTRAFICO.AYTO AND TRIM(MATRICULA) is null AND TRIM(NUMERO)=TRIM(xNUMERO_OLD) 
					AND TRIM(LETRA)=TRIM(xLETRAS_OLD);	
		else	
			select count(*),MAX(ABONADO),MAX(F_BAJA) into xCuantos,xABONADO,xF_BAJA FROM VEHICULOS
			WHERE MUNICIPIO=xREGTRAFICO.AYTO AND TRIM(MATRICULA)=TRIM(xCIUDAD_OLD) AND TRIM(NUMERO)=TRIM(xNUMERO_OLD) 
					AND TRIM(LETRA)=TRIM(xLETRAS_OLD);
		end if;
	
		--PARA LAS REMATRICULACIONES TIENE QUE EXISTIR EL VEHICULO GRABADO PREVIAMENTE
		IF xABONADO IS NULL THEN
	  
   			INSERT INTO TMP_INCIDENCIAS_TRAFICO(ID_TRAFICO,MARCA_ERROR,DESC_ERROR) VALUES (IDTEMP,4,'ERROR: EL VEHÍCULO NO EXISTE');
   			xSALIDA:=0;
   			RETURN;
   		
		END IF;
		
		-- si ya está dado de baja informamos de la incidencia
		IF xF_BAJA IS NOT NULL THEN
			INSERT INTO TMP_INCIDENCIAS_TRAFICO(ID_TRAFICO,MARCA_ERROR,DESC_ERROR) VALUES (IDTEMP,6,'ERROR: VEHÍCULO DADO DE BAJA');
			xCONTINUAR:=FALSE;
			xSALIDA:=0;
		END IF;

		-- si no se produce ninguna incidencia hacemos la rematriculación
		IF xCONTINUAR THEN
		
			UPDATE VEHICULOS SET 
					MATRICULA=xCIUDAD,NUMERO=xNUMERO,LETRA=xLETRAS,
					MOTIVO_ALTA='REMATRICULACIÓN MATRÍCULA ANTERIOR: ' ||xREGTRAFICO.MATRICULA_ANTERIOR||' FECHA: '||TO_CHAR(xREGTRAFICO.FECHA_TRAMITE),
			      	BASTIDOR=TRIM(xREGTRAFICO.BASTIDOR) -- refresca el bastidor
	   		WHERE ABONADO=xABONADO;
	   		
	   		DELETE FROM TMP_INCIDENCIAS_TRAFICO WHERE ID_TRAFICO=IDTEMP;	      
		END IF;     
   
	END IF;

END;
/



--
--
-- Creado: 09/10/2006. Agustín León Robles.
--Eliminar los movimientos TRANS que tengan mas de 3 registros, aquellos que tengan un NIF un movimiento de Alta y otro de Baja,
--Siempre suelen ser los concesionarios que hacen de intermediarios entre 2 compradores.
--
--
CREATE OR REPLACE PROCEDURE TraficoDELMasde3Movimientos
as
begin

	--Se reutiliza una tabla temporal para no tener que crear una nueva

	--Primero se insertan los registros de Alta
	Insert into TMP_C60 (NCOBROS,Usuario)  
	(SELECT ID,UID from trafico_new where codigo_tramite='TRANS' AND TIPO_REGISTRO in ('A')
				AND MATRICULA||DNI IN (select MATRICULA||DNI from trafico_new where codigo_tramite='TRANS' AND TIPO_REGISTRO='B')
				and matricula in (select matricula from trafico_new where codigo_tramite='TRANS' group BY MATRICULA having count(*)>3));
				
	--En segundo lugar se insertan los registros de Baja
	Insert into TMP_C60 (NCOBROS,Usuario)  
	(SELECT ID,UID from trafico_new where codigo_tramite='TRANS' AND TIPO_REGISTRO in ('B')
				AND MATRICULA||DNI IN (select MATRICULA||DNI from trafico_new where codigo_tramite='TRANS' AND TIPO_REGISTRO='A')
				and matricula in (select matricula from trafico_new where codigo_tramite='TRANS' group BY MATRICULA having count(*)>3));
	

	Delete from TMP_INCIDENCIAS_TRAFICO where ID_TRAFICO IN (Select NCOBROS From TMP_C60 where usuario=UID);
	
	Delete from Trafico_New where ID in (Select NCOBROS From TMP_C60 where usuario=UID);
		
end;
/	

--********************************************************************************************
-- Proceso de carga automática. Se recorren todos los registros marcados como únicas entradas
-- por bastidor durante el proceso de lectura del fichero de tráfico, así como para los que no
-- se haya detectado ninguna incidencia durante la carga.
-- Parámetro xNADA necesario (pero sin utilidad) 

-- Modificado: 09/10/2006. Agustín León Robles. Se incluyen la adaptación para los registros DUPLI.
-- Modificado: 30/10/2006. Lucas Fernández Pérez. Ajuste en los registros DUPLI y liquidaciones.
-- Modificado: 07/11/2006. Lucas Fernández Pérez. Movimientos A-B del mismo nif y fecha-hora se procesa
--		siempre primero el alta y luego la baja (antes tenían que ser de tipo trans, ahora no es necesario)
--		Además, se añade el ejercicio en el motivo de la liquidación.
-- Modificado: 08/11/2006. Lucas Fernández Pérez. Se deshace el movimiento anterior porque con los dupli el 
--		funcionamiento no es correcto. Además, se fuerza a que sean dos movimientos y que no haya mas movimientos
--		de esa misma matrícula.
-- Modificado: 05/02/2007. Lucas Fernández Pérez. 
--		Se guardan en el historico del contribuyente los nuevos campos BLOQUE y PORTAL
--
CREATE OR REPLACE PROCEDURE CargarAutosAuto(xNADA IN INTEGER)
AS
	xSALIDA 			INTEGER;
	xNombreProvincia	varchar2(35);
	xReg	 			CONTRIBUYENTES%ROWTYPE;
	xRegTrafico			TRAFICO_NEW%ROWTYPE;
	xConcepto			Char(6);
	xCOD_TARIFA			CHAR(5);
	xTARIFA				FLOAT;
	xImporte 			FLOAT;
	xNUMERO				CHAR(7);
	xID					INTEGER;
	mDNI				CHAR(9);
   
	CURSOR cLiqui IS Select * From TMP_LISTACARGOS where USUARIO=user;
	
	-- Cursor que obtiene los registros A DUPLI de los que hay un movimiento B DUPLI, y ningún otro movimiento mas.
	CURSOR cDupli IS SELECT * from trafico_new t where codigo_tramite='DUPLI' AND TIPO_REGISTRO='A'
				AND MATRICULA IN (select MATRICULA from trafico_new where codigo_tramite='DUPLI' AND TIPO_REGISTRO='B') 
				AND ID IN (SELECT ID_TRAFICO FROM TMP_INCIDENCIAS_TRAFICO WHERE MARCA_ERROR=0) 
				AND MATRICULA IN 
					(SELECT MATRICULA FROM trafico_new WHERE matricula=t.matricula GROUP BY matricula HAVING COUNT(*)=2)
				ORDER BY DNI;

	CURSOR cTrans IS SELECT ID FROM trafico_new T
		WHERE (dni,MATRICULA||DNI||fecha_tramite||hora) IN
	   		(SELECT dni,MATRICULA||DNI||fecha_tramite||hora
				FROM trafico_new WHERE codigo_tramite='TRANS' 
				GROUP BY dni,MATRICULA||DNI||fecha_tramite||hora
				HAVING COUNT(*)=2) 
			AND MATRICULA IN 
				(SELECT MATRICULA FROM trafico_new WHERE matricula=t.matricula GROUP BY matricula HAVING COUNT(*)=2)
		ORDER BY FECHA_TRAMITE,HORA,tipo_registro;

	CURSOR CAUTOS IS SELECT ID FROM TRAFICO_NEW WHERE ID IN (SELECT ID_TRAFICO FROM TMP_INCIDENCIAS_TRAFICO WHERE MARCA_ERROR=0) 
				AND ID IN (SELECT ID_TRAFICO FROM TMP_INCIDENCIAS_TRAFICO HAVING COUNT(*)=1 GROUP BY ID_TRAFICO)
				ORDER BY FECHA_TRAMITE,HORA,tipo_registro desc;
BEGIN

	Delete from TMP_C60 where Usuario=UID;
	Delete From TMP_LISTACARGOS where USUARIO=user;

	-- Este primer cursor tiene que hacerse obligatoriamente antes de llamar a CargarRegistroTrafico
	-- Los que tienen un registro de A-DUPLI y otro de B-DUPLI es solo por cambio en el domicilio dentro del mismo municipio
	mDNI:='';
	For vDupli in cDupli LOOP

		--Solamente se cambiara de domicilio la primera vez, para el resto de vehiculos no hace falta	
		if mDNI <> vDupli.DNI then
			mDNI:= vDupli.DNI;
		
			Select Provincia into xNombreProvincia from Cod_Provincias Where CodProv=substr(vDupli.Codigo_Postal,1,2);
		
			BEGIN
	   			SELECT * INTO xReg FROM CONTRIBUYENTES WHERE NIF=vDupli.DNI;
			EXCEPTION
	   			WHEN NO_DATA_FOUND THEN
	        		NULL;
			END;
		
			--Insertamos en el Historico los datos antes de hacer las modificaciones
			INSERT INTO HDOMICONTRI
	    	(USUARIO,FECHA,NIF,NOMBRE,VIA,CALLE,NUMERO,BLOQUE,PORTAL,ESCALERA,
		 	PLANTA,PISO,POBLACION,PROVINCIA,CODIGO_POSTAL,PAIS,F_FALLECIMIENTO,TELEFONO,MOVIL,EMAIL,MOTIVO)
			VALUES
	    	(USER,SYSDATE,xReg.NIF,xReg.NOMBRE,xReg.VIA,xReg.CALLE,xReg.NUMERO,xReg.BLOQUE,xReg.PORTAL,xReg.ESCALERA,
	    	xReg.PLANTA,xReg.PISO,
	     	xReg.POBLACION,xReg.PROVINCIA,xReg.CODIGO_POSTAL,xReg.PAIS,xReg.FECHA_FALLECIMIENTO,xReg.TELEFONO,xReg.MOVIL,xReg.EMAIL,
	     	'CAMBIO DE DOMICILIO A TRAVES DE LOS DISCOS DE TRAFICO, REGISTRO A-DUPLI Y B-DUPLI');	
	
			Update Contribuyentes set Calle=vDupli.Calle,IDCalle=null,Codigo_Postal=vDupli.Codigo_Postal,
				Poblacion=vDupli.Municipio,Provincia=xNombreProvincia Where NIF=vDupli.DNI;
		
			--Borramos las incidencias de los 2 registro de A-DUPLI y B-DUPLI para que en el cursor de más abajo
			--no entren estos registros
			DELETE FROM TMP_INCIDENCIAS_TRAFICO WHERE ID_TRAFICO IN (Select ID From Trafico_New where Matricula=vDupli.Matricula and Ayto=vDupli.Ayto);
			
		end if;
		
	End Loop;
	
	
	--
	--Eliminar los movimientos TRANS que tengan mas de 3 registros, aquellos que tengan un NIF un movimiento de Alta y otro de Baja,
	--Siempre suelen ser los concesionarios que hacen de intermediarios entre 2 compradores.
	TraficoDELMasde3Movimientos;
	
	--
	-- Aquellas matriculas con solo 3 movimientos TRANS hay que eliminar los 2 movimientos 
	-- (siempre sera un Alta y una Baja) del mismo NIF.
	-- Al final quedan el registro de Baja o el de Alta del NIF que no se repetia
	--
	-- IMPORTANTE: Este delete debe de estar en esta posicion, no se puede variar
	Delete FROM TRAFICO_NEW WHERE (DNI,MATRICULA||DNI||fecha_tramite||hora) IN 
	(
	SELECT DNI,MATRICULA||DNI||fecha_tramite||hora FROM trafico_new 
		WHERE codigo_tramite='TRANS' AND TIPO_REGISTRO IN ('A')
		AND MATRICULA||DNI||fecha_tramite||hora IN (SELECT MATRICULA||DNI||fecha_tramite||hora 
		FROM trafico_new WHERE codigo_tramite='TRANS' AND TIPO_REGISTRO='B')
		AND matricula IN (SELECT matricula FROM trafico_new WHERE codigo_tramite='TRANS' 
		GROUP BY MATRICULA HAVING COUNT(*)=3)
	);

	
	--Una vez eliminados los registros de los cursores de arriba, volvemos a comprobar si hay que marcar
	--algunos con la incidencia de 8:Pendiente de seleccion carga manual. Para ello primero borramos todas
	--las incidencias de Error 8 y luego volvemos a crearlas.
	DELETE FROM TMP_INCIDENCIAS_TRAFICO WHERE MARCA_ERROR='8';
	
	INSERT INTO TMP_INCIDENCIAS_TRAFICO(ID_TRAFICO,MARCA_ERROR,DESC_ERROR)
	SELECT ID,8,'PENDIENTE SELECCIÓN CARGA MANUAL'
	FROM TRAFICO_NEW
	WHERE CODIGO_TRAMITE<>'MODIT' AND CODIGO_TRAMITE<>'MODIF' 
		AND BASTIDOR IN (select bastidor from trafico_new having count(*) > 2 group by bastidor);

	
		
	--
	-- Movimientos con A-TRANS y B-TRANS del mismo NIF se procesan siempre en orden de A,B.
	-- Son registros para darlos de alta y luego darlos de Baja.
	--
	FOR vTrans IN cTrans LOOP
	
		CargarRegistroTrafico(vTrans.ID,xSALIDA);
		
	END LOOP;

	
	--
	-- Intentamos cargar el resto de registros
	--		
	FOR vAUTOS IN CAUTOS LOOP
		CargarRegistroTrafico(vAUTOS.ID,xSALIDA);
	END LOOP;
	
	--
	--Por ultimo aquellos movimientos del año anterior hay que generarle una liquidacion,
	--serán los registros de la tabla temporal TMP_LISTACARGOS 
	--
	FOR vLiqui IN cLiqui LOOP
	
		Select * into xRegTrafico from Trafico_NEW where ID=vLiqui.SesionID;
	
		select liquidacion into xConcepto from programas WHERE programa='VEHICULOS';
		
		DAMETARIFAVEHICULO(xRegTrafico.Ayto,xRegTrafico.TIPO_VEHICULO,xRegTrafico.POTENCIA,xRegTrafico.CILINDRADA,
	     							xRegTrafico.CARGA,xRegTrafico.PLAZAS,xTARIFA,xCOD_TARIFA);
	     	
		Select Importe into xImporte FROM TARIFAS_VEHICULOS 
		WHERE MUNICIPIO=xRegTrafico.Ayto AND CODIGO=xCOD_TARIFA AND ANNE=TO_CHAR(SYSDATE,'YYYY');
		
		ADD_LIQUI(xRegTrafico.Ayto,xConcepto,to_char(sysdate,'yyyy'),'00',to_char(sysdate,'yyyy'),
				xRegTrafico.DNI,NULL,NULL,sysdate,GetFinPeVol(xRegTrafico.Ayto),xImporte,'LIQUIDACION CON MOTIVO DEL ALTA DEL VEHICULO MARCA: '||
				xRegTrafico.MARCA_MODELO||' BASTIDOR: '||xRegTrafico.BASTIDOR||' Y MATRICULA: '||xRegTrafico.MATRICULA||
				' PROVENIENTE DE LA INFORMACIÓN DE TRAFICO. EJERCICIO: '||to_char(sysdate,'yyyy'),NULL,NULL,NULL,NULL,NULL,xNUMERO,xID);
				
		Update Trafico_New set Genera_Liquidacion='S' where ID=vLiqui.SesionID;
		
	END LOOP;
	
END;
/


--********************************************************************************************
-- Entra una cadena con la marca y el modelo y la divide en dos: marca y modelo
CREATE OR REPLACE PROCEDURE SplitMarcaModelo(
	xMARCAMODELO	IN	STRING,
	xMARCA		OUT 	STRING,
	xMODELO		OUT 	STRING)
AS
   xPOSIC INTEGER;
BEGIN
   xPOSIC:=INSTR(xMARCAMODELO,' ');
   IF xPOSIC>0 THEN
      xMARCA:=SUBSTR(SUBSTR(xMARCAMODELO,1,xPOSIC),1,25);
	xMODELO:=SUBSTR(SUBSTR(xMARCAMODELO,xPOSIC+1,LENGTH(xMARCAMODELO)),1,25);
   ELSE
      xMARCA:=SUBSTR(xMARCAMODELO,1,16);
      xMODELO:=SUBSTR(xMARCAMODELO,17,16);
   END IF;
END;
/

--********************************************************************************************
-- Entra una matricula en un string y lo divide en ciudad, numero y letras

CREATE OR REPLACE PROCEDURE SplitMatricula(
	xMatricula IN Char,
	xCiudad OUT Char,
	xNumero OUT Char,
	xLetras OUT Char)
AS

j integer;
elemento integer default 1;
posicion integer;
numeroletra Char(1) default 'N';
BEGIN

for j in 1..9 loop

     
	if SubStr(xMatricula,j,1) in ('0','1','2','3','4','5','6','7','8','9') then

         -- es un número
 	   if elemento=1 and numeroletra='N' then
  		elemento:=2;
	   end if;

 	   if elemento=1 and numeroletra='L' then
  		elemento:=2;
		xCiudad:=SubStr(xMatricula,1,j-1);
		posicion:=j;
	   end if;

	else

	   -- es una letra
	   if elemento=2 and numeroletra='N' then
		elemento:=3;
		xNumero:=SubStr(xMatricula,1,j-1);
		xLetras:=SubStr(xMatricula,j,3);
		return;
	   end if;

	   if elemento=2 and numeroletra='L' then
		elemento:=3;
		xNumero:=SubStr(xMatricula,posicion,j-posicion);
		xLetras:=SubStr(xMatricula,j,3);
		return;
	   end if;

	   -- empieza por letra

 	   if elemento=1 then
		numeroletra:='L';
	   end if;

	end if;

end loop;

xCIUDAD:=SUBSTR(ltrim(rtrim(xCIUDAD)),1,3);
if xCiudad='' then
	xCiudad:=NULL;
end if;

xLETRAS:=SUBSTR(ltrim(rtrim(xLETRAS)),1,3);
if xLETRAS='' then
	xLETRAS:=NULL;
end if;

xNUMERO:=SUBSTR(ltrim(rtrim(xNUMERO)),1,6);
if xNUMERO='' then
	xNUMERO:=NULL;
end if;

END;
/

--********************************************************************************************
--autor: M. Carmen Junco Gómez
--Fecha: 29/02/2002
--Acción:Procedimiento para la carga manual de un registro
--Parámetros: xID: ID del registro que se desea cargar de Tráfico
--		  xERROR: 1: Cargado sin errores
--			    0: Error, el vehículo no existe

CREATE OR REPLACE PROCEDURE CargarAutosManual(
			xID	IN	INTEGER,
			xERROR OUT  INTEGER)
AS
   v_Registro TRAFICO_NEW%ROWTYPE;
   
   -- cursor que recorre los registros que se refieren al mismo vehículo que el 
   -- registro que se quiere cargar pero con una fecha de trámite inferior.
   -- Lo que haremos será procesar el registro de entrada (xID) y anular los anteriores.
   CURSOR CTRAFICO IS SELECT ID FROM TRAFICO_NEW 
                      WHERE AYTO=v_Registro.AYTO AND 
   			    BASTIDOR=v_Registro.BASTIDOR AND 
   			    (FECHA_TRAMITE<v_Registro.FECHA_TRAMITE OR  
   			    (FECHA_TRAMITE=v_Registro.FECHA_TRAMITE AND 
			     TO_CHAR(HORA,'HH24:MI:SS')<TO_CHAR(v_Registro.HORA,'HH24:MI:SS')));						
BEGIN

   xERROR:=1;

   SELECT * INTO v_Registro FROM TRAFICO_NEW WHERE ID=xID;

   CargarRegistroTrafico(xID,xERROR);

   -- si se ha cargado sin problemas anularemos los registros de tráfico anteriores a
   -- éste indicando que se ha cargado un registro con una fecha de trámite posterior
   IF xERROR=1 THEN
      FOR vTRAFICO IN CTRAFICO
	LOOP
         INSERT INTO TMP_INCIDENCIAS_TRAFICO(ID_TRAFICO,MARCA_ERROR,DESC_ERROR)
   	   VALUES (vTRAFICO.ID,10,'NO CARGADO POR HABERSE PROCESADO UN REGISTRO '||
		                    'CON FECHA DE TRAMITE POSTERIOR');
	END LOOP;
   END IF;

END;
/


/* 

Listado de posibles errores a la hora de cargar los registros (tanto manual como auto):

0: REGISTRO NO CARGADO: es el estado inicial de un registro, de forma que una vez elegida su 
   carga, pasará siempre a otro estado, salvo cuando tenga una fecha de trámite inferior al 
   año actual.
1: MUNICIPIO no existe: es el estado en el que un registro no se ha cargado por no existir el 
   MUNICIPIO en la base de datos.
2: INCIDENCIA, TIPO DE VEHICULO erróneo: es el estado en el que un registro no ha sido cargado 
   por error en el tipo de vehículo al ser uno de los siguientes: vehículo articulado,
   vehículo mixto, furgoneta, furgoneta mixta, vehículo especial, ambulancia o máquina agrícola.
3: ERROR: ALTA YA EXISTE: es el estado en el que un registro ha intentado ser dado de alta 
   cuando en realidad ya lo está.
4: ERROR: EL VEHÍCULO NO EXISTE: es el estado en el que un registro ha intentado darse de baja 
   o ser rematriculado y no existía previamente.
5: ERROR: DNI NO ASOCIADO AL VEHÍCULO: es el estado en el que un registro ha intentado darse 
   de baja sin que coincida el DNI de su propietario con el que figura como tal en nuestra 
   base de datos.
6: ERROR: VEHÍCULO DADO DE BAJA: Se producirá cuando se quiera dar de baja un vehículo que ya
   lo está, o se quiera dar de alta o rematricular un vehículo dado de baja.
7: ERROR: MATRÍCULA IDÉNTICA: Si se va a rematricular un vehículo y la nueva matrícula 
   coincide con la anterior.
8: PENDIENTE SELECCIÓN CARGA MANUAL
9: NO CARGADO POR SER DE TIPO MODIT,MODIF O DUPLI
10: NO CARGADO POR HABERSE PROCESADO UN REGISTRO CON FECHA DE TRAMITE POSTERIOR
11: NO CARGADO POR NO ENCONTRAR SU TARIFA
12: REGISTRO DUPLICADO EN LA BASE DE DATOS. SE DEJA PARA SER ARREGLADO MANUALMENTE
*/
--********************************************************************************************
-- Procedimiento que comprueba tipos de incidencias básicas:
-- 	1: Municipio no existe
--	2: Tarifa no existe
--	4: Tipo de Vehículo erróneo
-- Modificado: 09/06/2006. Agustín León Robles. Para el error 1 se busca los 7 primeros caracteres del municipio
-- Modificado: 12/06/2006. Agustín León Robles.	Solo se comprueba el tipo de vehiculo en el caso de altas
CREATE OR REPLACE PROCEDURE TRAFICO_INCIDENCIAS_BASICAS(
		xID		   			IN  INTEGER,
		xMUNICIPIO	   		IN	CHAR,
		xTIPO_MOVIMIENTO	IN	CHAR,
		xTIPO_VEHICULO 		IN  VARCHAR2)
AS
   xCONT INTEGER;   
   xAYTO CHAR(3);
BEGIN

	-- Indicar que el registro no ha sido cargado
	SELECT COUNT(*) INTO xCONT FROM TMP_INCIDENCIAS_TRAFICO WHERE ID_TRAFICO=xID AND MARCA_ERROR=0;
   
	IF xCONT=0 THEN
		INSERT INTO TMP_INCIDENCIAS_TRAFICO(ID_TRAFICO) VALUES (xID);
	END IF;
	
   -- Comprobar la existencia del municipio 
	BEGIN
		SELECT MUNICIPIO INTO xAYTO FROM DATOSPER WHERE EMPRESA LIKE '%'||SUBSTR(TRIM(xMUNICIPIO),1,7)||'%';
	EXCEPTION
		WHEN NO_DATA_FOUND THEN
			SELECT COUNT(*) INTO xCONT FROM TMP_INCIDENCIAS_TRAFICO WHERE ID_TRAFICO=xID AND MARCA_ERROR=1;
			
			IF xCONT=0 THEN
				INSERT INTO TMP_INCIDENCIAS_TRAFICO(ID_TRAFICO,MARCA_ERROR,DESC_ERROR) VALUES (xID,1,'MUNICIPIO no existe');
			END IF;
	END;

	--
	-- SOLO EN EL CASO DE ALTA ES CUANDO HAY QUE COMPROBAR EL TIPO DEL VEHICULO, EN LAS BAJAS Y REMATRICULACIONES NO HACE FALTA
	-- PUESTO QUE SOLO SE PONE FECHA DE BAJA O SE ACTUALIZA LA MATRICULA
	--
	IF xTIPO_MOVIMIENTO='A' THEN
		
		-- Comprobar si el típo de vehículo es correcto
		SELECT COUNT(*) INTO xCONT FROM VEHICULOS_TRAFICO WHERE RTRIM(VEHICULO)=RTRIM(xTIPO_VEHICULO);
	
		IF xCONT=0 THEN   
	
			SELECT COUNT(*) INTO xCONT FROM TMP_INCIDENCIAS_TRAFICO WHERE ID_TRAFICO=xID AND MARCA_ERROR=2;
		
			IF xCONT=0 THEN
				INSERT INTO TMP_INCIDENCIAS_TRAFICO(ID_TRAFICO,MARCA_ERROR,DESC_ERROR) 
				VALUES (xID,2,'INCIDENCIA, TIPO DE VEHICULO erroneo');
			END IF;
		
		END IF;
		
	END IF;

END;
/


/*******************************************************************************
Acción: Lee el fichero de tráfico y lo pasa a un temporal, realizando unas 
        comprobaciones previas acerca del sujeto pasivo, del municipio y el 
        tipo de vehículo.
MODIFICACION: 10/02/2003. Lucas Fernández Pérez. Insertaba en TRAFICO_NEW DNI´s 
              vacios cuando el DNI no estaba en la aplicación, aunque se insertara 
              correctamente en la tabla de contribuyentes.         
MODIFICACIÓN: 16/05/2003. Mª del Carmen Junco Gómez. Si en la BD existía el DNI y el
			  Nif, al comprobar antes la existencia del DNI recogía éste como nifbueno.
			  Se ha cambiado el orden de comprobación.
Modificado: 09/06/2006. Agustín León Robles. Para el error 1 se busca los 7 primeros caracteres del municipio
Modificado: 12/06/2006. Agustín León Robles. Solo se comprueba el tipo de vehiculo en el caso de altas
Modificado: 09/10/2006. Agustín León Robles. Se crea un campo nuevo "NUEVO_CONTRIBUYENTE" para saber los nuevos
				contribuyentes que se han dado de alta y antes se grababa la provincia con solo 2 digitos, ahora
				se accede a la tabla de cod_provincias
Modificado: 31/10/2006. Lucas Fernández Pérez. Se cambiaba el tipo de vehículo pero se consultaba el viejo, por
				lo que se grabaja en trafico_new por ejemplo TURISMO y daba error por buscar COCHE FUNEBRE
MODIFICACION: 05/02/2007. Lucas Fernández Pérez. Cambia la llamada de InsertaModiContribuyente a Ins_Upd_Contri
*******************************************************************************/

CREATE OR REPLACE PROCEDURE LEER_TRAFICO(
       xFICH_TRAFICO 		IN VARCHAR2,
       xTIPO_REGISTRO 		IN CHAR,
       xCODIGO_TRAMITE 		IN CHAR,
       xMATRICULA 			IN CHAR,
       xDNI 				IN CHAR,
       xAPELLIDO_1 			IN CHAR,
       xAPELLIDO_2 			IN CHAR,
       xNOMBRE 				IN CHAR,
       xV2IND 				IN CHAR,
       xPROVINCIA 			IN CHAR,
       xCODIGO_POSTAL 		IN CHAR,
       xMUNICIPIO 			IN CHAR,
       xPUEBLO 				IN CHAR,
       xCALLE 				IN CHAR,
       xCODIGO_TIPO 		IN CHAR,
       xTIPO_VEHICULO 		IN CHAR,
       xMARCA_MODELO 		IN CHAR,
       xBASTIDOR 			IN CHAR,
       xSERVICIO 			IN CHAR,
       xCILINDRADA 			IN CHAR,
       xPOTENCIA 			IN CHAR,
       xPLAZAS 				IN CHAR,
       xCARGA 				IN CHAR,
       xFECHA_TRAMITE 		IN DATE,
       xMATRICULA_ANTERIOR 	IN CHAR,
       xHORA 				IN DATE,
       xMATRICULA_AYTO		IN CHAR
)
AS
	xID		 	 		INTEGER;
	xNIF         		CHAR(10);
    xNOMBREAPELL 		VARCHAR2(40);
	xNIFBueno    		CHAR(10);
	xAYTO        		CHAR(3);
	xNuevoContri		char(1);
	xNombreProvincia 	varchar2(35);
	xTipoVehiculo 		CHAR(24);
BEGIN 

   -- Calculamos el Nif a partir del DNI que viene en el fichero de tráfico y
   -- comprobamos si es mote de algún otro NIF o si existe en nuestra base de datos.   
   -- xNIFBueno valdrá: NIF VÁLIDO: si xNif era mote.
   --				    xNif: si no era mote pero está dado de alta en Contribuyentes
   --			        NULLO: Si no es mote ni está dado de alta en Contribuyentes
   
	xNIF:=CalNIF(xDNI);
	xNiFBueno:=GetExisteNif(xNIF);      
	xNuevoContri:='N';

	-- Si xNIFBueno es nulo haremos la misma comprobación pero con el DNI
   
	IF (xNIFBueno IS NULL) THEN        
		xNIFBueno:=GetExisteNIF(xDNI);
      
		IF (xNIFBueno IS NULL) THEN
      
			xNOMBREAPELL:=SUBSTR(TRIM(xAPELLIDO_1)||' '||TRIM(xAPELLIDO_2)||
			    ' '||TRIM(xNOMBRE), 1, 40);
			    
			Select Provincia into xNombreProvincia from Cod_Provincias Where CodProv=substr(xCODIGO_POSTAL,1,2);
		
			INS_UPD_CONTRI('A',xNIF, xNOMBREAPELL, '', xNOMBRE_VIA, '', '', '' , '', '', '', 
					xMUNICIPIO,xNombreProvincia,xCODIGO_POSTAL, '',NULL, '' ,'','','');

         
			xNIFBueno:=xNIF; -- Para evitar que inserte en TRAFICO_NEW un DNI nulo.
	     	xNuevoContri:='S';
		END IF;
      
	END IF;  
	
	-- recogemos el ayto que le corresponde para poder insertarlo en trafico_new
	begin
		SELECT MUNICIPIO INTO xAYTO FROM DATOSPER WHERE EMPRESA LIKE '%'||SUBSTR(TRIM(xMUNICIPIO),1,7)||'%';
	EXCEPTION
		WHEN NO_DATA_FOUND THEN
			xAYTO:='';
	end;   
	
	If xTipo_Vehiculo='FURGONETA' Then xTipoVehiculo:='CAMION';
	ElsIf xTipo_Vehiculo='HORMIGONERA' Then xTipoVehiculo:='CAMION';
	ElsIf xTipo_Vehiculo='CAMIONETA' Then xTipoVehiculo:='CAMION';
	ElsIf xTipo_Vehiculo='FURGONETA MIXTA' Then xTipoVehiculo:='CAMION';
	ElsIf xTipo_Vehiculo='VEHIC. ESPECIAL' Then xTipoVehiculo:='TURISMO';
	ElsIf xTipo_Vehiculo='COCHE FUNEBRE' Then xTipoVehiculo:='TURISMO';
	ElsIf xTipo_Vehiculo='VEHIC. MIXTO' Then xTipoVehiculo:='CAMION';
	ElsIf xTipo_Vehiculo='MAQUINA AGRICOLA' Then xTipoVehiculo:='TRACTOR';
	ElsIf xTipo_Vehiculo='VEHIC. VIVIENDA' Then xTipoVehiculo:='CAMION';
	ElsIf xTipo_Vehiculo='VOLQUETE' Then xTipoVehiculo:='CAMION';
	ElsIf xTipo_Vehiculo='VEH. ARTICULADO' Then xTipoVehiculo:='CAMION';
	ElsIf xTipo_Vehiculo='TIPO NO CONOCIDO' Then xTipoVehiculo:='MOTOCICLETA';
	ElsIf xTipo_Vehiculo='AMBULANCIA' Then xTipoVehiculo:='TURISMO';
	Else xTipoVehiculo:= xTipo_Vehiculo;
	End If;

	INSERT INTO TRAFICO_NEW
		(FICH_TRAFICO, TIPO_REGISTRO, CODIGO_TRAMITE, MATRICULA, DNI,APELLIDO_1, APELLIDO_2,NOMBRE,
		V2IND, PROVINCIA,CODIGO_POSTAL, MUNICIPIO, PUEBLO, CALLE, CODIGO_TIPO,TIPO_VEHICULO,
		MARCA_MODELO, BASTIDOR, SERVICIO,CILINDRADA, POTENCIA, PLAZAS, CARGA, FECHA_TRAMITE,
		MATRICULA_ANTERIOR, HORA, MATRICULA_AYTO, AYTO,NUEVO_CONTRIBUYENTE)
	VALUES
		(xFICH_TRAFICO, xTIPO_REGISTRO, xCODIGO_TRAMITE, xMATRICULA,SubStr(xNIFBueno,1,9),
		xAPELLIDO_1, xAPELLIDO_2,xNOMBRE, 
		xV2IND, xPROVINCIA,xCODIGO_POSTAL, xMUNICIPIO, xPUEBLO, xCALLE, xCODIGO_TIPO,
		xTIPOVEHICULO, xMARCA_MODELO, xBASTIDOR, xSERVICIO,xCILINDRADA, xPOTENCIA, xPLAZAS, 
		xCARGA, xFECHA_TRAMITE,xMATRICULA_ANTERIOR, xHORA, xMATRICULA_AYTO, xAYTO, xNuevoContri)
	RETURNING ID INTO xID;

	TRAFICO_INCIDENCIAS_BASICAS(xID,xMUNICIPIO,xTIPO_REGISTRO,xTIPOVEHICULO);

END;
/

/********************************************************************************
Acción: domiciliación de un recibo.
Autor: 25/06/2002 M. Carmen Junco Gómez. Modifica los datos de domiciliación de 
		  un abonado y comprueba si hay recibo emitido 
              del padrón anual en curso y en tal caso modifica los datos de la 
              domiciliación para que entre en los soportes del cuaderno 19
MODIFICACION: 03/07/2002 M. Carmen Junco Gómez. Si no se encontraba el recibo en la 
		  tabla de valores estabamos asignándole a mVOL_EJE:=''; En mi máquina,
		  por ejemplo, funcionaba correctamente, pero en Salobreña estaba fallando
		  el procedimiento (no domiciliaba el recibo) debido a esta asignación.
		  Se ha cambiado por mVOL_EJE:=NULL;		 
MODIFICACION: 08/07/2002 M. Carmen Junco Gómez. El recibo de Vehículos sólo se podrá modificar
		  si aún no se ha emitido el Cuaderno19 para el padrón al que pertenece.
		  Además, cuando modificamos en recaudación, debemos tener en cuenta si el
		  cargo se ha aceptado o no. Si aún no se ha aceptado habrá que hacer la
		  modificación en la tabla PUNTEO y no en VALORES.
MODIFICACIÓN: 03/12/2002 M. Carmen Junco Gómez. Insertamos los campos MUNICIPIO y 
		  PERIODO en LOGSPADRONES.
MODIFICACIÓN: 18-03-2003. Agustín León Robles. Nuevo parametro de salida xDOMI_C19.
	Con este parametro de salida lo que queremos avisar al usuario que el recibo esta domiciliado 
	y por consiguiente saldra en el disco del C19, para que avise al contribuyente que no vaya a 
	pagar el recibo de este año en ventanilla de la recaudacion o en ventanilla del banco
MODIFICACIÓN: 10/03/2005 Lucas Fernández Pérez. Hasta ahora se comprobaban los recibos emitidos 
		  en el año en curso, de tal forma que no hacía la modificación del recibo si el padrón se
		  emitió el año anterior al actual. Lo que haremos será revisar los recibos emitidos desde
		  hace un año al día de hoy. 		  
MODIFICACIÓN: 18/07/2006 Lucas Fernández Pérez. En la búsqueda del recibo en valores y punteo
	no estaba en la condicion "TIPO_DE_OBJETO='R'" y se habían dado situaciones de que existía 
	la misma clave de valor para recibo y liquidación, y fallaba este proceso.
********************************************************************************/

CREATE OR REPLACE PROCEDURE VEHI_BANCOS(
		       xABONADO			IN 	INTEGER,
			   xDOMICILIADO		IN 	CHAR,
		       xENTIDAD 		IN 	CHAR,
		       xSUCURSAL 		IN 	CHAR,
		       xDC 				IN 	CHAR,
		       xCUENTA 			IN 	CHAR,
			   xF_DOMICILIACION IN 	DATE,
		       xTITULAR 		IN 	CHAR,
			   xDOMI_C19		OUT INTEGER)
AS
	mVOL_EJE 		Char(1);
	mVALOR   		Integer;
	mPUNTEO  		Integer;
	mPADRON 		CHAR(6);	
	xNOMBRE_TITULAR 	CHAR(40);
	xCuantos 		Integer;

   	mSUCURSAL  	  	char(4);
   	mDC		  	char(2);
   	mCUENTA	      char(10);
   	mF_DOMICILIACION 	Date;
   	mTITULAR	      char(10);	
	xFIngreso		date;

      -- cursor que recorre los distintos periodos de los distintos recibos que 
	-- se han podido emitir para este abonado, para comprobar para que padrón
	-- se ha emitido ya el Cuaderno19, y por lo tanto no modificar la domiciliación
	-- de ese recibo. Han de ser recibos emitidos en el año en curso.
	CURSOR CPERIODOS IS SELECT DISTINCT YEAR,PERIODO,ID,MUNICIPIO FROM RECIBOS_VEHI
				  WHERE ABONADO=xABONADO 
				  		AND YEAR BETWEEN (TO_CHAR(sysdate,'yyyy')-1) AND TO_CHAR(sysdate,'yyyy');

BEGIN

	--con este parametro de salida lo que queremos avisar al usuario que el recibo esta domiciliado y por consiguiente
	--saldra en el disco del C19, para que avise al contribuyente que no vaya a pagar el recibo de este año en ventanilla
	--de la recaudacion o en ventanilla del banco
	xDOMI_C19:=0;

	if (rtrim(xENTIDAD)='') or (xEntidad is null) then
		mSUCURSAL:=null;
		mDC:=null;
		mCUENTA:=null;
		mF_DOMICILIACION:=null;
		mTITULAR:=null;
	else
		mSUCURSAL:=xSUCURSAL;
		mDC:=xDC;
		mCUENTA:=xCUENTA;
		mF_DOMICILIACION:=xF_DOMICILIACION;
		mTITULAR:=xTITULAR;

		SELECT NOMBRE INTO xNOMBRE_TITULAR FROM CONTRIBUYENTES WHERE NIF=xTITULAR;

	end if;


	-- se actualiza en la tabla VEHICULOS
	UPDATE VEHICULOS SET DOMICILIADO=xDOMICILIADO,
			         ENTIDAD=xENTIDAD,
                           SUCURSAL=mSUCURSAL,
                           DC=mDC,CUENTA=mCUENTA,
			         F_DOMICILIACION=mF_DOMICILIACION,
			         TITULAR=mTITULAR                      
	WHERE ABONADO=xABONADO;	

      -- Averiguar el código de padron de VEHICULOS
	SELECT CONCEPTO INTO mPADRON FROM PROGRAMAS WHERE PROGRAMA='VEHICULOS';		

	-- por cada periodo distinto de recibos sobre el abonado
	FOR vPERIODOS IN CPERIODOS 
	LOOP	 

         -- Comprobamos si se ha emitido ya el soporte del cuaderno 19
	   SELECT COUNT(*) INTO xCUANTOS FROM LOGSPADRONES 
	   WHERE MUNICIPIO=vPERIODOS.MUNICIPIO AND 
		   PROGRAMA ='VEHICULOS' AND 
		   PYEAR=vPERIODOS.YEAR AND
		   PERIODO=vPERIODOS.PERIODO AND 
		   HECHO='Generación Cuaderno 19 (recibos domiciliados)';

	   IF xCUANTOS=0 THEN  -- aún no se ha emitido. Podemos modificar el recibo.

		-- Comprobar si ya se paso a recaudación    
		begin
	   		SELECT ID,VOL_EJE,F_INGRESO INTO mVALOR,mVOL_EJE,xFIngreso FROM VALORES 
         		WHERE AYTO=vPERIODOS.MUNICIPIO AND PADRON=mPADRON AND
		   	YEAR=VPERIODOS.YEAR AND PERIODO=vPERIODOS.PERIODO AND RECIBO=xABONADO AND TIPO_DE_OBJETO='R';
		Exception
			When no_data_found then
	     			mVOL_EJE:=NULL;
		end;

		-- Si no se encuentra el valor, comprobar si está en el punteo
		IF (mVOL_EJE IS NULL) THEN
			begin
				SELECT ID,VOL_EJE INTO mPUNTEO,mVOL_EJE FROM PUNTEO
				WHERE AYTO=vPERIODOS.MUNICIPIO
					AND PADRON=mPADRON
					AND YEAR=vPERIODOS.YEAR
					AND PERIODO=vPERIODOS.PERIODO
					AND RECIBO=xABONADO
					AND TIPO_DE_OBJETO='R';
			Exception
				When no_data_found then
					mVOL_EJE:=NULL;
			end;
		END IF;

		-- si el recibo está en Voluntaria en RECA o todavia no se ha pasado a recaudación.
		-- Además también tiene que el recibo estar pendiente de ingreso en recaudacion, porque aunque a lo hora
		-- de generar el disco del C19 se controla que si esta ingresado no sale en el disco,
		-- quedaria en recaudación la marca de que esta domiciliado cuando no sería correcto, para posteriores listados
		IF (xFIngreso is null and (mVOL_EJE='V' or mVOL_EJE IS NULL)) THEN

	   		-- modificamos el recibo en gestión tributaria
	   		IF xDOMICILIADO='N' THEN
				UPDATE RECIBOS_VEHI SET DOMICILIADO='N',
							      ENTIDAD=NULL,
							      SUCURSAL=NULL,
							      DC=NULL,
							      CUENTA=NULL,
							      F_DOMICILIACION=NULL,
							      DNI_TITULAR=NULL,
							      NOMBRE_TITULAR=NULL,
							      ESTADO_BANCO=NULL
				WHERE ID=vPERIODOS.ID;

				IF mVALOR IS NOT NULL THEN
         			   UPDATE VALORES SET 
							   ESTADO_BANCO=DECODE(ESTADO_BANCO, 'EB', NULL, ESTADO_BANCO)
         			   WHERE ID=mVALOR;
				END IF;

				IF mPUNTEO IS NOT NULL THEN
				   UPDATE PUNTEO SET
							   ESTADO_BANCO=DECODE(ESTADO_BANCO, 'EB', NULL, ESTADO_BANCO)
				   WHERE ID=mPUNTEO;
				END IF;

			ELSE

			      UPDATE RECIBOS_VEHI SET DOMICILIADO='S',
							      ENTIDAD=xENTIDAD,
							      SUCURSAL=mSUCURSAL,
							      DC=mDC,
							      CUENTA=mCUENTA,
							      F_DOMICILIACION=mF_DOMICILIACION,
					      		DNI_TITULAR=mTITULAR,
							      NOMBRE_TITULAR=xNOMBRE_TITULAR,
							      ESTADO_BANCO='EB'
			     	WHERE ID=vPERIODOS.ID;

				IF mVALOR IS NOT NULL THEN
         			   UPDATE VALORES SET 
							   ESTADO_BANCO=DECODE(ESTADO_BANCO, NULL, 'EB',ESTADO_BANCO)
         			   WHERE ID=mVALOR;		
				END IF;

				IF mPUNTEO IS NOT NULL THEN
				   UPDATE PUNTEO SET
							   ESTADO_BANCO=DECODE(ESTADO_BANCO, NULL, 'EB',ESTADO_BANCO)
         			   WHERE ID=mPUNTEO;			
				END IF;

				xDOMI_C19:=1;

			END IF;

     		END IF; -- ((mVOL_EJE='V') or (mVOL_EJE IS NULL))	 

        END IF; --xCUANTOS=0 

   END LOOP;

END;
/

/*******************************************************************************
Acción: Procedimiento para dar de alta un nuevo vehículo.
MODIFICACIÓN: 12/09/2001 M. Carmen Junco Gómez.
		  Duplicaba la inserción del Representante en la tabla "VEHICULOS".
MODIFICACIÓN: 15/11/2001 M. Carmen Junco Gómez.
		  Si en matrícula se incluye un espacio en blanco, introducirlo en la BD como
		  nulo para que en las consultas no aparezca como ' -2222-BDP', sino '2222-BDP'
*******************************************************************************/

CREATE OR REPLACE PROCEDURE INSERTAVEHICULO(
       xNIF 		IN 		CHAR,
	 xREPRESENTANTE   IN          CHAR,
       xMUNICIPIO 	IN 		CHAR,
       xMARCA 		IN 		CHAR,
       xMODELO 		IN		VARCHAR2,
       xTIPO_VEHICULO 	IN 		CHAR,
       xBASTIDOR 		IN 		VARCHAR2,
       xDOMICILIADO 	IN 		CHAR,
       xMATRICULA 	IN 		CHAR,
       xNUMERO 		IN 		CHAR,
       xLETRA 		IN 		CHAR,
       xCABALLOS 		IN 		INTEGER,
	 xCABALLOS_E 	IN 		FLOAT,
       xENTIDAD 		IN 		CHAR,
       xSUCURSAL		IN 		CHAR,
       xDC 			IN 		CHAR,
       xCUENTA		IN 		CHAR,
	 xF_DOMICILIACION IN		DATE,
       xTITULAR 		IN 		CHAR,
       xF_ALTA 		IN 		DATE,
       xMOTIVO_ALTA 	IN 		VARCHAR2,
       xTIPO_BONI_EX	IN 		CHAR,
       xID_BONI_EX 	IN 		INTEGER,
       xYEAR_BONI 	IN 		CHAR,
	 xIDAlternativo   IN		INTEGER,
       xNUM_ABONADO 	OUT    	INTEGER)
AS
xDOMI_C19	integer;
BEGIN

	INSERT INTO VEHICULOS
		(MUNICIPIO, NIF,REPRESENTANTE,MARCA,MODELO,TIPO_VEHICULO,BASTIDOR,MATRICULA,
		NUMERO,LETRA,CABALLOS,CABALLOS_EXAC,F_ALTA,MOTIVO_ALTA,
		TIPO_BONI_EX,ID_BONI_EX,YEAR_BONI,IDDOMIALTER)
	VALUES 
	     (xMUNICIPIO, xNIF, xREPRESENTANTE, xMARCA, xMODELO,xTIPO_VEHICULO,xBASTIDOR,
		DECODE(xMATRICULA,' ',NULL,xMATRICULA),xNUMERO,xLETRA,xCABALLOS,xCABALLOS_E, 
		xF_ALTA,xMOTIVO_ALTA,xTIPO_BONI_EX,xID_BONI_EX,xYEAR_BONI,
		DECODE(xIDAlternativo,0,NULL,xIDAlternativo))

	RETURN ABONADO INTO xNUM_ABONADO;

	--en las altas el parametro xDOMI_C19 no sirve para nada
	VEHI_BANCOS(xNUM_ABONADO,xDOMICILIADO,xENTIDAD,xSUCURSAL,xDC,xCUENTA,
		   xF_DOMICILIACION,xTITULAR,xDOMI_C19);

END;
/

/*******************************************************************************
Acción: Modificación de los datos de un vehículo.
MODIFICACIÓN: 15/11/2001 M. Carmen Junco Gómez. 
		  Si en matrícula se incluye un espacio en blanco, introducirlo en la BD como
		  nulo para que en las consultas no aparezca como ' -2222-BDP', sino '2222-BDP'
MODIFICACIÓN: 31/01/2005 M. Carmen Junco Gómez. Se añade un parámetro TEXTO que contendrá el motivo del
			cambio en la titularidad del impuesto (cambio de titular o representante). Este parámetro
			se almacena en el campo TEXTO de la tabla usuariosgt, para después recogerlo en el trigger que hace
			el insert en el histórico de motivos de cambios de titularidad.
MODIFICACIÓN: 01/02/2005 Lucas Fernandez Pérez. Se añade el parámetro xMotivoCambioDomi.
		  Se eliminan los campos USR_CHG__CUENTA y F_CHG__CUENTA.
		  La información se almacenará ahora en la tabla HISTO_DOMICILIACIONES.
MODIFICACIÓN: 04/10/2005 Gloria MAria Calle Hernandez. Se añade el parámetro xGrupo.
		  Para la domicilacion de un mismo grupo de vehiculos.
*******************************************************************************/

CREATE OR REPLACE PROCEDURE MODIFICAVEHICULO(
      xABONADO 		IN 	INTEGER,
      xMUNICIPIO 		IN 	CHAR,
      xNIF 				IN 	CHAR,
 	  xREPRESENTANTE	IN 	CHAR,
      xMARCA 			IN 	CHAR,
      xMODELO 			IN 	VARCHAR2,
      xTIPO_VEHICULO	IN 	CHAR,
      xBASTIDOR 		IN 	VARCHAR2,
      xDOMICILIADO 	    IN 	CHAR,
      xMATRICULA 		IN 	CHAR,
      xNUMERO 			IN 	CHAR,
      xLETRA 			IN 	CHAR,
      xCABALLOS 		IN 	INTEGER,
      xCABALLOS_E 	    IN 	FLOAT,
      xENTIDAD 		    IN 	CHAR,
      xSUCURSAL 		IN 	CHAR,
      xDC 				IN 	CHAR,
      xCUENTA 			IN 	CHAR,
	  xF_DOMICILIACION  IN 	DATE,
      xTITULAR 		    IN 	CHAR,
      xF_ALTA 			IN 	DATE,
      xMOTIVO_ALTA 	    IN 	VARCHAR2,
      xTIPO_BONI_EX 	IN 	CHAR,
      xID_BONI_EX 	    IN 	INTEGER,
	  xIDAlternativo    IN 	INTEGER,
      xYEAR_BONI 		IN 	CHAR,
      xTEXTO			IN	VARCHAR2,
      xMotivoCambioDomi IN  VARCHAR2,
      xGrupo			IN  INTEGER,
	  xDOMI_C19		OUT	integer)
AS
    CURSOR CVEHIDOMI IS SELECT ABONADO FROM VEHICULOS WHERE GRUPO=xGRUPO;
BEGIN

	-- Se rellena Texto y texto2 para ser recogidos en el triger before update de vehículos
	UPDATE USUARIOSGT SET TEXTO=xTEXTO, TEXTO2=xMotivoCambioDomi WHERE USUARIO=USER;

	UPDATE VEHICULOS SET 
		NIF=xNIF, MARCA=xMARCA,MUNICIPIO=xMUNICIPIO,MODELO=xMODELO,TIPO_VEHICULO=xTIPO_VEHICULO,
		BASTIDOR=xBASTIDOR,MATRICULA=DECODE(xMATRICULA,' ',NULL,xMATRICULA),
		NUMERO=xNUMERO,LETRA=xLETRA,CABALLOS=xCABALLOS,
		CABALLOS_EXAC=xCABALLOS_E,F_ALTA=xF_ALTA,
		MOTIVO_ALTA=xMOTIVO_ALTA, TIPO_BONI_EX=xTIPO_BONI_EX, 
		ID_BONI_EX=xID_BONI_EX,YEAR_BONI=xYEAR_BONI,REPRESENTANTE=xREPRESENTANTE,
		IDDOMIALTER=DECODE(xIDAlternativo,0,NULL,xIDAlternativo)
	WHERE ABONADO=xABONADO;

	IF (xGRUPO=0 or xGRUPO is null) THEN
	   VEHI_BANCOS(xABONADO,xDOMICILIADO,xENTIDAD,xSUCURSAL,xDC,xCUENTA,xF_DOMICILIACION,xTITULAR,xDOMI_C19);
	ELSE 
	   FOR vVEHIDOMI IN cVEHIDOMI LOOP
	       VEHI_BANCOS(vVEHIDOMI.ABONADO,xDOMICILIADO,xENTIDAD,xSUCURSAL,xDC,xCUENTA,xF_DOMICILIACION,xTITULAR,xDOMI_C19);
	   END LOOP;
	END IF;

END;
/

/*******************************************************************************
Acción: Procedimiento para modificar un registro de tráfico.
Modificado 06/09/2006. Agustín León Robles. Se busca en la tabla datosper para saber el nombre de la poblacion
Modificado 20/10/2006 Lucas Fernandez Pérez. Se modificaba el nombre del municipio pero no el campo ayto de la tabla.
*******************************************************************************/

CREATE OR REPLACE PROCEDURE MODIFICA_TRAFICO(
       xID 				IN INTEGER,
       xTIPO_REGISTRO 		IN CHAR,
       xCODIGO_TRAMITE 		IN CHAR,
       xMATRICULA 		IN CHAR,
       xDNI 			IN CHAR,
       xAPELLIDO_1 		IN CHAR,
       xAPELLIDO_2 		IN CHAR,
       xNOMBRE 			IN CHAR,
       xPROVINCIA 		IN CHAR,
       xCODIGO_POSTAL 		IN CHAR,
       xMUNICIPIO 		IN CHAR,
       xPUEBLO 			IN CHAR,
       xCALLE 			IN CHAR,
       xCODIGO_TIPO 		IN CHAR,
       xTIPO_VEHICULO 		IN CHAR,
       xMARCA_MODELO 		IN CHAR,
       xBASTIDOR 			IN CHAR,
       xSERVICIO 			IN CHAR,
       xCILINDRADA 		IN CHAR,
       xPOTENCIA 			IN CHAR,
       xPLAZAS 			IN CHAR,
       xCARGA 			IN CHAR,
       xFECHA_TRAMITE 		IN DATE,
       xMATRICULA_ANTERIOR	IN CHAR,
       xHORA 			IN DATE,
       xMATRICULA_AYTO 		IN CHAR
)
AS
xPoblacion	varchar2(24);
BEGIN

	Select substr(Poblacion,1,24) into xPoblacion from Datosper Where Municipio=xMunicipio;

	UPDATE TRAFICO_NEW SET 
		TIPO_REGISTRO=xTIPO_REGISTRO,CODIGO_TRAMITE=xCODIGO_TRAMITE,MATRICULA=xMATRICULA,DNI=xDNI,
		APELLIDO_1=xAPELLIDO_1,APELLIDO_2=xAPELLIDO_2,NOMBRE=xNOMBRE,PROVINCIA=xPROVINCIA,
		CODIGO_POSTAL=xCODIGO_POSTAL,AYTO=xMUNICIPIO,MUNICIPIO=xPoblacion,PUEBLO=xPUEBLO,CALLE=xCALLE,
		CODIGO_TIPO=xCODIGO_TIPO,TIPO_VEHICULO=xTIPO_VEHICULO,MARCA_MODELO=xMARCA_MODELO,
		BASTIDOR=xBASTIDOR,SERVICIO=xSERVICIO,CILINDRADA=xCILINDRADA,POTENCIA=xPOTENCIA,
		PLAZAS=xPLAZAS,CARGA=xCARGA,FECHA_TRAMITE=xFECHA_TRAMITE,
		MATRICULA_ANTERIOR=xMATRICULA_ANTERIOR,HORA=xHORA,MATRICULA_AYTO=xMATRICULA_AYTO
	WHERE ID=xID;

END;
/

/*******************************************************************************
Acción: Devuelve la potencia determinada de la tarifa según el tipo de vehículo.
*******************************************************************************/

CREATE OR REPLACE PROCEDURE TRAFICO_TIPO_VEHI(
       xCILINDRADA 	IN 		CHAR,
       xPLAZAS 		IN 		CHAR,
       xCARGA 		IN 		CHAR,
       xPOTENCIA 		IN 		CHAR,
       xTIPO_VEHICULO	IN 		CHAR,
       xVALOR 		OUT 		FLOAT
)
AS

BEGIN

  IF (xTIPO_VEHICULO='MOTOCICLETA') OR (xTIPO_VEHICULO='CICLOMOTOR') THEN
    xVALOR:=TO_NUMBER(xCILINDRADA);
  ELSIF (xTIPO_VEHICULO='TURISMO') OR (xTIPO_VEHICULO='TRACTOR') THEN
     xVALOR:=TO_NUMBER(xPOTENCIA); 
  ELSIF xTIPO_VEHICULO='AUTOBUS' THEN
    xVALOR:=TO_NUMBER(xPLAZAS);
  ELSIF xTIPO_VEHICULO='CAMION' THEN
    xVALOR:=TO_NUMBER(xCARGA);
  ELSIF xTIPO_VEHICULO='REMOLQUE' THEN
    xVALOR:=TO_NUMBER(xCARGA);
  ELSE
    xVALOR:=TO_NUMBER(LTRIM(RTRIM(xPOTENCIA)),'99999999999.9999999999999999');
  END IF;

END;
/

/*******************************************************************************
Acción: El resultado se utiliza para gráficos.
*******************************************************************************/

CREATE OR REPLACE PROCEDURE VEHI_GRAFICOS_POCO(
       xMUNICIPIO	IN 		CHAR,
       xYEAR 	IN 		CHAR,
       xPERIODO 	IN 		CHAR,
       xTOTAL 	IN OUT	FLOAT
)
AS
    xTARIFA       VARCHAR(50);
    xSUMA         FLOAT;
    CONT          INTEGER DEFAULT 0;
    xTOT          FLOAT DEFAULT 0;
    xMEDIA        FLOAT DEFAULT 0;
    xPARCIAL      FLOAT;
    I             INTEGER;
    SALIR         INTEGER DEFAULT 0;

    CURSOR CRECVEHI1 IS 
	 SELECT TARIFA,SUM(TOTAL) FROM RECIBOS_VEHI 
       WHERE MUNICIPIO=xMUNICIPIO AND PERIODO=xPERIODO AND YEAR=xYEAR 
       GROUP BY TARIFA;

    CURSOR CRECVEHI2 IS 
	 SELECT TARIFA,SUM(TOTAL) AS SUM_TOTAL FROM RECIBOS_VEHI 
   	 WHERE MUNICIPIO=xMUNICIPIO AND PERIODO=xPERIODO AND YEAR=xYEAR 
	 GROUP BY TARIFA ORDER BY SUM_TOTAL DESC;

BEGIN

    I:=0;
    xPARCIAL:=0;
    OPEN CRECVEHI1;

    LOOP
       FETCH CRECVEHI1 INTO xTARIFA,xSUMA;
       EXIT WHEN CRECVEHI1%NOTFOUND;

       xTOT:=xTOT+xSUMA;
       CONT:=CONT+1;
    END LOOP;

  CLOSE CRECVEHI1;

  IF xTOT>0 THEN
 	xMEDIA:=xTOT/CONT;
  END IF;

  OPEN CRECVEHI2;
  LOOP

      FETCH CRECVEHI2 INTO xTARIFA,xSUMA;
      EXIT WHEN CRECVEHI2%NOTFOUND;

      xTOTAL:=xTOTAL+xSUMA;
      I:=I+1;
      xPARCIAL:=xPARCIAL+xSUMA;
      xPARCIAL:=xPARCIAL+xSUMA;

      IF (I>11) THEN
     	   xTARIFA:='VARIOS';
	   xSUMA:=xTOT-xPARCIAL;
	   xTOTAL:=xTOTAL+xSUMA;
	   SALIR:=1;
      END IF;
   END LOOP;

  CLOSE CRECVEHI2;
END;
/

/*******************************************************************************
Acción: Pasar a recaudación el padrón de vehículos.
MODIFICACION: 27/05/2002 M. Carmen Junco Gómez. Incluir o no los exentos dependiendo
		  del nuevo parámetro de entrada xEXENTOS.
MODIFICACIÓN: 1/07/2002 M. Carmen Junco Gómez. Insertar una tupla en LogsPadrones
		  para controlar que se ha pasado un padrón a Recaudación.
MODIFICACIÓN: 03/12/2002 M. Carmen Junco Gómez. Se añaden los campos MUNICIPIO y
		  PERIODO en la tabla LOGSPADRONES.
MODIFICACIÓN: 09/06/2004 Gloria Mª Calle Hernández. Se guarda en el campo Clave_recibo el ID 
		 	 de la la tabla de recibos.
*******************************************************************************/

CREATE OR REPLACE PROCEDURE VEHI_PASE_RECA(
       xMUNICIPIO			IN CHAR,
       xYEAR 				IN CHAR,
       xPERIODO 			IN CHAR,
       xFECHA 				IN DATE,
       xN_CARGO 			IN CHAR,
	   xYEARCONTRAIDO		IN CHAR,
	   xEXENTOS				IN CHAR) -- incluir o no recibos exentos (total=0)
AS

    xPADRON                       CHAR(6);
    xNUMERO_DE_RECIBO             CHAR(7);
    xDNI_DEUDOR                   CHAR(10);
    xNOMBRE                       VARCHAR(40);   
    xESTADO_BANCO                 CHAR(2);
    xINICIO_PERIODO_VOLUN         DATE;
    xFIN_PERIODO_VOLUNTARIO       DATE;
    xPRINCIPAL                    FLOAT;
    xMATRICULA                    VARCHAR(20);
    xMATRI                        CHAR(3);
    xNUM                          CHAR(6);
    xLETRA                        CHAR(3);
    xOBJETO_TRIBUTARIO            VARCHAR(1024);
    xMARCA                        CHAR(25);
    xMODELO                       CHAR(25);
    xTARIFA                       CHAR(50);
    xBASTIDOR                     CHAR(21);
    xRECIBO                       INTEGER;
    xRECIBO_CAD                   CHAR(12);
    xSALTO                        CHAR(2);
    xDOMICILIO_TRIBUTARIO	      VARCHAR2(60);
    xTIPO_TRIBUTO			      CHAR(2);
    xCOTITULARES			      CHAR(1);
    xTOTAL			          	  FLOAT;
    xID							  INTEGER;

    -- cursor que selecciona aquellos recibos de vehículos de un municipio, año y 
    -- periodo determinados, cuyo impore es mayor a 0 euros.
    CURSOR CRECVEHI IS
	SELECT ID,ABONADO,NIF,DESDE,HASTA,TOTAL,MATRICULA,NUMERO,LETRA,MARCA,MODELO,TARIFA,
              BASTIDOR,ESTADO_BANCO,NOMBRE,DOMICILIO,TOTAL
	FROM RECIBOS_VEHI  
	WHERE MUNICIPIO=xMUNICIPIO AND YEAR=xYEAR AND PERIODO=xPERIODO;

BEGIN

	SELECT CONCEPTO INTO xPADRON FROM PROGRAMAS WHERE PROGRAMA='VEHICULOS';

	SELECT TIPO_TRIBUTO INTO xTIPO_TRIBUTO
	FROM CONTADOR_CONCEPTOS
	WHERE MUNICIPIO=xMUNICIPIO AND CONCEPTO=xPADRON;

	SELECT min(SALTO) INTO xSALTO FROM SALTO;

	-- recorrer el cursor
	OPEN CRECVEHI;
	LOOP
        FETCH CRECVEHI INTO xID,xRECIBO,xDNI_DEUDOR,xINICIO_PERIODO_VOLUN,xFIN_PERIODO_VOLUNTARIO,
                            xPRINCIPAL,xMATRI,xNUM,xLETRA,xMARCA,xMODELO,xTARIFA,xBASTIDOR,
   	  		  	    xESTADO_BANCO,xNOMBRE,xDOMICILIO_TRIBUTARIO,xTOTAL;
        EXIT WHEN CRECVEHI%NOTFOUND;

	  -- recoger los posibles cotitulares
	  SELECT COTITULARES INTO xCOTITULARES FROM VEHICULOS WHERE ABONADO=xRECIBO;

        IMPORTEENCADENA(xRECIBO,xRECIBO_CAD);
        xNUMERO_DE_RECIBO:=SUBSTR(xRECIBO_CAD, 6, 7);

	  -- crear el objeto tributario con todos los datos del vehículo (siempre que
        -- no sean nulos): matrícula, marca, modelo, nº de bastidor y tarifa.
        xOBJETO_TRIBUTARIO:='ABONADO Nº: '||TO_CHAR(xRECIBO)||xSALTO;

        xMATRICULA:=GetMatricula(xMATRI,xNUM,xLETRA);

        IF xMATRICULA IS NOT NULL THEN
           xOBJETO_TRIBUTARIO:=xOBJETO_TRIBUTARIO||'MATRICULA: '||xMATRICULA||xSALTO;
        END IF;

        IF xMARCA IS NOT NULL THEN
           xOBJETO_TRIBUTARIO:=xOBJETO_TRIBUTARIO||'MARCA: '||xMARCA||xSALTO;
        END IF;

        IF xMODELO IS NOT NULL THEN
           xOBJETO_TRIBUTARIO:=xOBJETO_TRIBUTARIO||'MODELO: '||xMODELO||xSALTO;
        END IF;

        IF xBASTIDOR IS NOT NULL THEN
           xOBJETO_TRIBUTARIO:=xOBJETO_TRIBUTARIO||'BASTIDOR: '||xBASTIDOR||xSALTO;
        END IF;

        IF xTARIFA IS NOT NULL THEN
           xOBJETO_TRIBUTARIO:=xOBJETO_TRIBUTARIO||'TARIFA: '||xTARIFA||xSALTO;
        END IF;

	  -- insertar en el punteo de valores
	  IF NOT(xEXENTOS='N' AND xTOTAL<=0) THEN
           INSERT INTO PUNTEO
              (AYTO, PADRON, YEAR, PERIODO, RECIBO, NIF, NOMBRE, VOL_EJE, F_CARGO,
               N_CARGO, INI_PE_VOL, FIN_PE_VOL, TIPO_DE_TRIBUTO, CUOTA_INICIAL, PRINCIPAL, 
               OBJETO_TRIBUTARIO, TIPO_DE_OBJETO, ESTADO_BANCO, DOM_TRIBUTARIO, 
		       CLAVE_CONCEPTO, YEAR_CONTRAIDO, COTITULARES, CLAVE_RECIBO)
           VALUES
              (xMUNICIPIO, xPADRON, xYEAR, xPERIODO,xRECIBO,xDNI_DEUDOR, xNOMBRE,
	          'V',xFECHA, xN_CARGO,xINICIO_PERIODO_VOLUN,
	          xFIN_PERIODO_VOLUNTARIO, xTIPO_TRIBUTO, xPRINCIPAL, xPRINCIPAL, 
		      xOBJETO_TRIBUTARIO,'R', xESTADO_BANCO, xDOMICILIO_TRIBUTARIO, xMATRICULA,
		      xYEARCONTRAIDO,xCOTITULARES,xID);
	  END IF;
     END LOOP;
	 
     CLOSE CRECVEHI;

     -- Insertamos una tupla en LOGSPADRONES para controlar que esta acción ha sido ejecutada
     INSERT INTO LOGSPADRONES (MUNICIPIO,PROGRAMA,PYEAR,PERIODO,HECHO)
     VALUES (xMUNICIPIO,'VEHICULOS',xYEAR,xPERIODO,'Se Pasa un padrón a Recaudación');

END;
/

/*******************************************************************************
Acción: Para recibos domiciliados y no domiciliados de La Caixa.
MODIFICACIÓN: 20/09/2001 M. Carmen Junco Gómez. Se estaban seleccionando datos 
	        de Vehiculos que ya están en la tabla Recibos_Vehi.
		  Adaptación al Euro.
*******************************************************************************/

CREATE OR REPLACE PROCEDURE Proc_Caixa_Vehi (
	 xMUNICIPIO   IN CHAR,
       xYear 	  IN char, 
       xPeri 	  IN char)
AS

	xAbonado 			Integer;
	xTotal 			Float;
	x2 				char(40);
	x3 				char(40);
	x4 				char(40);
	x5 				char(40);
	x6 				char(40);
	i 				integer;
	xRegis 			integer;

	CURSOR CRECVEHI IS
	   select *  FROM recibos_vehi WHERE MUNICIPIO=xMUNICIPIO and year=xYear and 
                                           periodo=xPeri AND TOTAL>0;

BEGIN

  DELETE FROM RECIBOS_CAIXA WHERE USUARIO=USER;

  xRegis:=0;
  select count(*) into xRegis FROM recibos_vehi
  WHERE municipio=xMunicipio and year=xYear and periodo=xPeri AND TOTAL>0;

  FOR REG_CRECVEHI IN CRECVEHI LOOP
	
	i:=5;	
	x2:='MARCA: '||REG_CRECVEHI.Marca;
	x3:='MODELO: '||REG_CRECVEHI.Modelo;
	x4:='MATRICULA: '||RTRIM(REG_CRECVEHI.Matricula)||'-'||
           RTRIM(REG_CRECVEHI.NUMERO)||'-'||RTRIM(REG_CRECVEHI.LETRA);
	x5:=SUBSTR(RTrim(REG_CRECVEHI.Tarifa),1,39);
	x6:='BASTIDOR: '||REG_CRECVEHI.Bastidor;

	INSERT INTO RECIBOS_CAIXA
		(ABONADO,NIF,NOMBRE,DOMICILIO,CODPOSTAL,MUNICIPIO,
		ENTIDAD,SUCURSAL,DC,CUENTA,
		TOTAL, Campo2, Campo3, Campo4, Campo5, Campo6, 
		CAMPOS_OPCIONALES, CUANTOS_REGISTROS)
	VALUES
		(REG_CRECVEHI.ABONADO, REG_CRECVEHI.NIF, REG_CRECVEHI.Nombre, 
		substr(REG_CRECVEHI.Domicilio,1,40), REG_CRECVEHI.Codigo_Postal, 
		REG_CRECVEHI.Poblacion, 
		REG_CRECVEHI.Entidad, REG_CRECVEHI.Sucursal, REG_CRECVEHI.DC, REG_CRECVEHI.Cuenta, 
		REG_CRECVEHI.TOTAL*100, x2, x3, x4, x5, x6, 
		i, xRegis);
  END LOOP;		

END;
/

/*******************************************************************************
Autor: M. Carmen Junco Gómez. 09/05/2002
Acción: Para recibos domiciliados y no domiciliados de Caja Madrid.
*******************************************************************************/
CREATE OR REPLACE PROCEDURE Proc_CajaMadrid_Vehi (
	 xMUNICIPIO   IN CHAR,
       xYear 	  IN char, 
       xPeri 	  IN char)
AS

	xAbonado 			Integer;
	xTotal 			Float;
	x1 			char(40);
	x2 			char(40);
	x3 			char(40);
	x4 			char(40);
	x5 			char(40);
	x6 			char(40);
	x7 			char(40);

	i 			integer;
	xRegis 		integer;

	xPAIS			CHAR(35);
	xTIPO			CHAR(24);
      xCODIGO		CHAR(5);
	xCABALLOS		FLOAT;
	xDESCRIPCION	CHAR(10);

	CURSOR CRECVEHI IS
	   select *  FROM recibos_vehi WHERE MUNICIPIO=xMUNICIPIO and year=xYear and 
                                           periodo=xPeri AND TOTAL>0;

BEGIN

  	DELETE FROM RECIBOS_CAJAMADRID WHERE USUARIO=USER;

	xRegis:=0;
	Select count(*) into xRegis FROM recibos_vehi
      WHERE municipio=xMunicipio and year=xYear and periodo=xPeri AND TOTAL>0;

      FOR v_RVEHI IN CRECVEHI LOOP
	
	   -- recogemos tipo de vehículo y caballos (o plazas o carga..)
	   SELECT CABALLOS,TIPO_VEHICULO INTO xCABALLOS,xCODIGO FROM VEHICULOS
	   WHERE ABONADO=v_RVEHI.ABONADO;

	   SELECT VEHI_TRAFICO INTO xTIPO FROM TARIFAS_VEHICULOS 
	   WHERE MUNICIPIO=xMUNICIPIO AND ANNE=xYEAR AND 
	   CODIGO=xCODIGO;	

	   -- recogemos el pais
	   begin
	      SELECT PAIS INTO xPAIS FROM CONTRIBUYENTES
	      WHERE NIF=v_RVEHI.NIF;
	      Exception
		   When no_data_found then
			xPAIS:=NULL;
         end;

	   IF xTIPO IN ('TRACTOR','TURISMO') THEN
            xDESCRIPCION:='CABALLOS: ';
	   ELSIF xTIPO IN ('CAMION','REMOLQUE') THEN
            xDESCRIPCION:='CARGA: ';
	   ELSIF xTIPO='AUTOBUS' THEN
		xDESCRIPCION:='PLAZAS: ';
	   ELSIF xTIPO IN ('CICLOMOTOR','MOTOCICLETA') THEN
	      xDESCRIPCION:='C.C.: ';
	   END IF;
	
	   i:=7;	

	   x1:='';
	   x2:='';
	   x3:='';
	   x4:='';
	   x5:='';
	   x6:='';
	   x7:='';

	   x1:='MARCA: '||v_RVEHI.Marca;
	   x2:='MODELO: '||v_RVEHI.Modelo;
	   x3:='MATRICULA: '||RTRIM(v_RVEHI.Matricula)||'-'||
              RTRIM(v_RVEHI.NUMERO)||'-'||RTRIM(v_RVEHI.LETRA);
	   x4:=SUBSTR(RTrim(v_RVEHI.Tarifa),1,39);
	   x5:='BASTIDOR: '||v_RVEHI.Bastidor;
         x6:='TIPO VEHICULO: '||xTIPO;
	   x7:=xDESCRIPCION||xCABALLOS;

	   INSERT INTO RECIBOS_CAJAMADRID
	      (ABONADO,NIF,NOMBRE,DOMICILIO,CODPOSTAL,POBLACION,PROVINCIA,PAIS,
		 REFERENCIA,DOMICILIADO,ENTIDAD,SUCURSAL,DC,CUENTA,
		 TOTAL,Campo1,Campo2,Campo3,Campo4,Campo5,Campo6,Campo7,
		 CAMPOS_OPCIONALES,CUANTOS_REGISTROS)
	   VALUES
		(v_RVEHI.ABONADO,v_RVEHI.NIF,v_RVEHI.NOMBRE,SUBSTR(v_RVEHI.DOMICILIO,1,40),
		 v_RVEHI.CODIGO_POSTAL,v_RVEHI.POBLACION,v_RVEHI.PROVINCIA,xPAIS,
		 DECODE(v_RVEHI.DOMICILIADO,'S',v_RVEHI.REFERENCIA||v_RVEHI.DIGITO_CONTROL,
			  v_RVEHI.REFERENCIA),	
		 DECODE(v_RVEHI.DOMICILIADO,'S','D',' '),
		 v_RVEHI.Entidad,v_RVEHI.Sucursal,v_RVEHI.DC,v_RVEHI.Cuenta, 
		 v_RVEHI.TOTAL*100,x1,x2,x3,x4,x5,x6,x7,i,xRegis);
   	END LOOP;		

END;
/


/*******************************************************************************
Acción: Procedimientos para modificar el número de periodos 
*******************************************************************************/

CREATE OR REPLACE PROCEDURE VEHI_MOD_NUM_PERIODOS(
       xMUNICIPIO   IN CHAR,
       xNUM 	  IN INTEGER
)
AS

BEGIN

  UPDATE DATOSPER SET VEHI_NUM_PERIODOS=xNUM
  WHERE MUNICIPIO=xMUNICIPIO;

END;
/


/*******************************************************************************
Creacion: 04/10/2005. Gloria Maria Calle Hernandez
Acción: Procedimiento para Crear, Pegar y Quitar de Grupo Activo.
*******************************************************************************/

CREATE OR REPLACE PROCEDURE CREA_PEGA_GRUPO_VEHI(
       xABONADO 			IN INTEGER,
       xTIPO 		IN CHAR,
       xGRUPO 		IN OUT INTEGER)
AS
BEGIN

   IF xTipo='C' then
	  ADD_COD_OPERACION(xGRUPO);
      UPDATE VEHICULOS SET GRUPO=xGRUPO WHERE ABONADO=xABONADO;
   END IF;

   if xTipo='P' then
      UPDATE VEHICULOS SET GRUPO=xGRUPO WHERE ABONADO=xABONADO;
   END IF;

   if xTipo='Q' then
      UPDATE VEHICULOS SET GRUPO=0 WHERE ABONADO=xABONADO;
   END IF;
   
END;
/

/********************************************************************/
COMMIT;
/********************************************************************/
