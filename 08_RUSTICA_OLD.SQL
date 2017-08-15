/********************************************************************************
Autor: Agustin Leon Robles
Fecha: 23/08/2001.
Acción:Añadir o eliminar un representante a un abonado 
********************************************************************************/

CREATE OR REPLACE PROCEDURE ADDDEL_RUSTICA_REPRESENTANTE 
		(xID 		IN 	integer,
		 xNIF		IN	char,
		 xAddDel	IN	char)
AS
BEGIN

	if xAddDel='A' then
		update Rus80 set representante=xNIF where id=xID;
	else
		update Rus80 set representante=NULL,IDDOMIALTER=NULL where id=xID;
	end if;
END;
/


/********************************************************************************
Acción: operaciones de grupo: añadir,pegar,quitar de un grupo. 
********************************************************************************/

CREATE OR REPLACE PROCEDURE CREA_PEGA_GRUPO_RUS80(
       xID 			    IN INTEGER,
       xTIPO 		    IN CHAR,
       xCODIGO_OPERACION    IN OUT INTEGER)
AS
BEGIN

  IF(xTIPO='C') THEN /*CREAR GRUPO*/
     ADD_COD_OPERACION(xCODIGO_OPERACION);
     UPDATE RUS80 SET CODIGO_OPERACION=xCODIGO_OPERACION WHERE ID=xID;
  END IF;

  IF (xTIPO='P') THEN /*PEGAR GRUPO*/ 
      UPDATE RUS80 SET CODIGO_OPERACION=xCODIGO_OPERACION WHERE ID=xID;
  END IF;

  IF (xTIPO='Q') THEN /*QUITAR GRUPO*/ 
      UPDATE RUS80 SET CODIGO_OPERACION=0 WHERE ID=xID;
  END IF;

END;
/

/********************************************************************************
Acción: operaciones de grupo: añadir,pegar,quitar de un grupo. 
********************************************************************************/

CREATE OR REPLACE PROCEDURE CREA_PEGA_GRUPO_RUS81(
       xID 			    IN INTEGER,
       xTIPO 		    IN CHAR,
       xCODIGO_OPERACION    IN OUT INTEGER)
AS
BEGIN

  IF(xTIPO='C') THEN /*CREAR GRUPO*/
     ADD_COD_OPERACION(xCODIGO_OPERACION);
     UPDATE RUS81 SET CODIGO_OPERACION=xCODIGO_OPERACION WHERE ID=xID;
  END IF;

  IF (xTIPO='P') THEN /*PEGAR GRUPO*/ 
      UPDATE RUS81 SET CODIGO_OPERACION=xCODIGO_OPERACION WHERE ID=xID;
  END IF;

  IF (xTIPO='Q') THEN /*QUITAR GRUPO*/ 
      UPDATE RUS81 SET CODIGO_OPERACION=0 WHERE ID=xID;
  END IF;

END;
/

/********************************************************************************
Acción: borra un disco de rústica, junto con sus recibos.
MODIFICACIÓN: 23/08/2001 Agustin Leon Robles.
********************************************************************************/

CREATE OR REPLACE PROCEDURE BORRA_VIEJO_RUS(
       xMUNICIPIO   IN CHAR,
       xYEAR 	  IN CHAR)
AS
BEGIN
	DELETE FROM RECIBOS_RUSTICA WHERE MUNICIPIO=xMUNICIPIO AND YEAR=xYEAR;
	DELETE FROM RUS81 WHERE MUNICIPIO=xMUNICIPIO AND YEAR=xYEAR;
	DELETE FROM RUS80 WHERE MUNICIPIO=xMUNICIPIO AND YEAR=xYEAR;
	DELETE FROM COTITULARES_RECIBO WHERE PROGRAMA='RUSTICA' 
		AND AYTO=xMUNICIPIO AND YEAR=xYEAR;
END;
/

/********************************************************************************
Acción: borrar un padrón.
MODIFICACIÓN: 23/08/2001 Agustin Leon Robles.
MODIFICACIÓN: 28/06/2002 M. Carmen Junco Gómez. Insertar una tupla en LogsPadrones
		  para controlar que se ha borrado un padrón.
MODIFICACIÓN: 04/12/2002 M. Carmen Junco Gómez. Insertamos el municipio y el periodo
		  en logspadrones.
********************************************************************************/

CREATE OR REPLACE PROCEDURE BORRA_PADRON_VIEJO_RUS(
       xPERIODO     IN CHAR,
       xYEAR        IN CHAR)
AS
   CURSOR CMUNI IS SELECT MUNICIPIO FROM TMP_AYTOS WHERE USUARIO=USER;
BEGIN

   FOR vMUNI IN CMUNI
   LOOP
      DELETE FROM RECIBOS_RUSTICA
	WHERE MUNICIPIO=vMUNI.MUNICIPIO AND YEAR=xYEAR AND PERIODO=xPERIODO;

	DELETE FROM COTITULARES_RECIBO 
      WHERE PROGRAMA='RUSTICA' AND AYTO=vMUNI.MUNICIPIO AND YEAR=xYEAR AND PERIODO=xPERIODO;

   	-- Insertamos una tupla en LOGSPADRONES para controlar que esta acción ha sido ejecutada
   	INSERT INTO LOGSPADRONES (MUNICIPIO,PROGRAMA,PYEAR,PERIODO,HECHO)
   	VALUES (vMUNI.MUNICIPIO,'RUSTICA',xYEAR,xPERIODO,'Se Borra un Padrón');     
   END LOOP;
END;
/

-- *****************************************************************************************
-- MODIFICACIÓN: 23/08/2001 Agustin Leon Robles
-- MODIFICACIÓN: 14/09/2001 M. Carmen Junco Gómez. Adaptación al euro.
-- Modificacion: 17/09/2001 Agustin Leon Robles. Se ha añadido que en el fichero del banco 
-- 		  salga el año y periodo
-- Modificación: 24/06/2002 M. Carmen Junco Gómez. Se añade bonificación al recibo.
-- MODIFICACIÓN: 11/07/2003 M. Carmen Junco Gómez. Se cambia el formato de la superficie de
-- 			  0D99 por 999D99, ya que para p.ejm. 77,52 pintaba ####
-- MODIFICACIÓN: 30/09/2003 Lucas Fernández Pérez. Se cambia el formato de la bonificación 
--					de 900 a 999G990D00, porque pasa de ser un porcentaje a un importe.
-- MODIFICACIÓN: 13/01/2004 Gloria Mª Calle Hernández. Se cambia el formato del tipo de Gravamen
--					de 0D99 a 0D999, porque pasa a arrastrar 3 dígitos decimales.
-- MODIFICACIÓN: 21/01/2004 Lucas Fernández Pérez. Bonificaciones por domiciliaciones.
--	  Obtiene de la tabla PROGRAMAS la bonificación por domiciliación y la aplica al 
--		importe del recibo, para que en el disco del c19 vaya el importe bonificado.
-- MODIFICACION: 28/05/2004 Gloria Maria Calle Hernandez. Añadido campo AYTO a la tabla 
--			  Recibos_Cuadreno19 para generar ficheros por ayuntamientos (xej. Catoure).
-- MODIFICACIÓN: 02/06/2004 Agustín León Robles. Cuando no hay el NIF del titular de la cuenta
--			se toman los datos del fichero de recibos_rustica
-- MODIFICACIÓN: 06/02/2007 Lucas Fernández Pérez. Ampliación de la variable xDomi_Titular para recoger el 
--					nuevo domicilio con bloque y portal.
-- *****************************************************************************************

CREATE OR REPLACE PROCEDURE CUADERNO19_RUSTICA (
	 xYEAR 	   IN CHAR,
       xPERI 	   IN CHAR,
       xESTADO 	   IN CHAR)
AS

	xNIF_TITULAR	    CHAR(10);
	xNOMBRE_TITULAR     CHAR(40);
	xDOMI_TITULAR       CHAR(60);
	x2                  CHAR(40);
	x3                  CHAR(40);
	x4                  CHAR(40);
	x5                  CHAR(40);
	x6                  CHAR(40);
	x7                  CHAR(40);
	x8			   		CHAR(40);
	x9			    	CHAR(40);

	I                   INTEGER;
	xREGIS              INTEGER default 0;
	xNIF                CHAR(10);
	xProvincia		    CONTRIBUYENTES.Provincia%Type;
	xCODPOSTAL          CHAR(5);
	xPoblacion		    CHAR(35);

	xCONCEPTO			CHAR(6);
	xBONIDOMI			FLOAT;
	xF_INGRESO			DATE;
	xFECHA_DE_BAJA		DATE;

CURSOR CRECRUS IS SELECT * FROM RECIBOS_RUSTICA
                  WHERE YEAR=xYEAR AND PERIODO=xPERI AND ESTADO_BANCO=xESTADO AND TOTAL>0
            		AND MUNICIPIO IN (SELECT DISTINCT MUNICIPIO FROM TMP_AYTOS WHERE USUARIO=USER);

BEGIN

	--Borrar los datos de este usuario de la tabla temporal
	DELETE FROM RECIBOS_CUADERNO19 WHERE USUARIO=USER;

	SELECT COUNT(*) INTO xREGIS FROM RECIBOS_RUSTICA
	 WHERE YEAR=xYEAR AND PERIODO=xPERI AND ESTADO_BANCO=xESTADO AND TOTAL>0
	   AND MUNICIPIO IN (SELECT DISTINCT MUNICIPIO FROM TMP_AYTOS WHERE USUARIO=USER);

	-- recogemos el concepto y la bonificacion por domiciliaciones para RUSTICA
	SELECT CONCEPTO,PORC_BONIFI_DOMI INTO xCONCEPTO, xBONIDOMI 
	FROM PROGRAMAS WHERE PROGRAMA='RUSTICA';

	FOR v_RRus IN CRECRUS 
	LOOP

		begin
			SELECT F_INGRESO,FECHA_DE_BAJA INTO xF_INGRESO,xFECHA_DE_BAJA
			FROM VALORES WHERE AYTO=v_RRus.MUNICIPIO AND PADRON=xCONCEPTO AND
						 YEAR=v_RRus.YEAR AND PERIODO=v_RRus.PERIODO AND
						 RECIBO=v_RRus.RECIBO AND TIPO_DE_OBJETO='R';
			Exception
			   When no_data_found then
				xF_INGRESO:=NULL;
				xFECHA_DE_BAJA:=NULL;
		end;

		IF ((xF_INGRESO IS NULL) AND (xFECHA_DE_BAJA IS NULL)) THEN	
			
			-- Datos del titular de la cuenta
			IF v_RRus.TITULAR IS NULL THEN
				xNIF_TITULAR:=v_RRus.NIF;
			ELSE
				xNIF_TITULAR:=v_RRus.TITULAR;
			END IF;
		   
			if RTRIM(xNIF_TITULAR) is null then
				xNOMBRE_TITULAR:=v_RRus.NOMBRE;
				xPoblacion:=v_RRus.POBLACION;
				xProvincia:=v_RRus.PROVINCIA;
				xCodPostal:=v_RRus.CODIGO_POSTAL;
				xDomi_Titular:=v_RRus.DOMICILIO;
			else
				GETContribuyente(xNIF_TITULAR,xNOMBRE_TITULAR,xPoblacion,xProvincia,xCodPostal,xDomi_Titular);
			end if;
  
			-- La variable I indica el número de campos opcionales que hay, si las variables
			-- llegan hasta x13 entonces son 12, porque se empieza en el x2, 
			-- si son x15 entonces son 14, etc...

			I:=8;
			x2:='NUMERO FIJO: '||LTRIM(RTRIM(v_RRus.NUM_FIJO));
			x3:='SUPERFICIE: ' ||LTRIM(RTRIM(TO_CHAR(v_RRus.SUPERFICIE, '999D99')));
			x4:='VALOR CATASTRAL: '||LTRIM(RTRIM(TO_CHAR(v_RRus.VALOR_CATASTRAL)));
			x5:='% PARTICIPACION: '||LTRIM(RTRIM(TO_CHAR(v_RRus.PORCEN_PARTICIPACION,'999')));
			x6:='BASE IMPONIBLE: '||LTRIM(RTRIM(TO_CHAR(v_RRus.BASE_IMPONIBLE)));
			x7:='TIPO GRAVAMEN: '||LTRIM(RTRIM(TO_CHAR(v_RRus.TIPO_GRAVAMEN,'0D999')));
			x8:='IMPORTE BONIFICADO: '||TO_CHAR(v_RRus.BONIFICACION,'999G990D00');
			x9:='AÑO: '||xYEAR||' PERIODO: '||xPERI;

      	   INSERT INTO RECIBOS_CUADERNO19
	      	(AYTO,ABONADO,NIF,NOMBRE,DOMICILIO,CODPOSTAL,MUNICIPIO,NOMBRE_TITULAR,
			 ENTIDAD,SUCURSAL,DC,CUENTA,
			 TOTAL, Campo2, Campo3, Campo4, Campo5, Campo6, Campo7, Campo8, Campo9,
			 CAMPOS_OPCIONALES, CUANTOS_REGISTROS)
		   VALUES 
	  		(V_RRus.MUNICIPIO,v_RRus.RECIBO,xNIF_TITULAR,v_RRus.NOMBRE,SUBSTR(xDOMI_TITULAR,1,40),
			 xCODPOSTAL,xPoblacion, xNOMBRE_TITULAR, 
			 v_RRus.ENTIDAD,v_RRus.SUCURSAL,v_RRus.DC,v_RRus.CUENTA,
 			 ROUND(v_RRus.TOTAL*(1-(xBoniDomi/100)),2), 
			 x2, x3, x4, x5, x6, x7, x8, x9, I, xREGIS);      

		END IF;
   	END LOOP;  
END;
/


/********************************************************************************
Acción: Comprobar cuantos registros hay en la tabla rus80 para un ayto y año.
********************************************************************************/

CREATE OR REPLACE PROCEDURE CHECK_EXIT_RUS(
       xMUNICIPIO    IN CHAR,
       xYEAR 	   IN CHAR,
       xCUANTOS 	   OUT INTEGER)
AS
BEGIN  
  SELECT COUNT(*) INTO xCUANTOS FROM RUS80
  WHERE MUNICIPIO=xMUNICIPIO AND YEAR=xYEAR;
END;
/

/********************************************************************************
Acción: Comprobar cuantos recibos hay para un año y periodo.
********************************************************************************/

CREATE OR REPLACE PROCEDURE CHECK_EXIT_PADRUS(
       xYEAR 	  IN CHAR,
       xPERIODO 	  IN CHAR,
       xCUANTOS 	  OUT INTEGER
)
AS
BEGIN  
  SELECT COUNT(*) INTO xCUANTOS FROM RECIBOS_RUSTICA
  WHERE YEAR=xYEAR AND PERIODO=xPERIODO AND 
        MUNICIPIO IN (SELECT MUNICIPIO FROM TMP_AYTOS WHERE USUARIO=USER);
END;
/

/********************************************************************************
Acción: Generación del padrón de Rústica.
MODIFICACIÓN: 23/08/2001 Agustin León Robles.
MODIFICACIÓN: 12/09/2001 Lucas Fernández Pérez. Adaptación al euro.
MODIFICACIÓN: 24/06/2002 M. Carmen Junco Gómez. Se añaden bonificaciones.
MODIFICACIÓN: 28/06/2002 M. Carmen Junco Gómez. Insertar una tupla en LogsPadrones
		  para controlar que se ha generado un padrón.
MODIFICACIÓN: 10/09/2002 M. Carmen Junco Gómez. Cuando la bonificación ha finalizado,
		  incluir como %Bonificación un 0 en el recibo, y no el %Bonificación
		  que tiene asignado el abonado de rustica.
MODIFICACIÓN: 04/12/2002 M. Carmen Junco Gómez. Insertamos los campos municipio y
		  periodo en logspadrones
Modificación: 29/05/2003. Agustín León Robles. Las bonificaciones ya bienen indicadas
			por el Catastro, con lo cual se cambia la forma de calcular las bonificaciones.
Modificacion: 17/05/2004. Gloria Maria Calle Hernandez. Cambiado MAX_VALOR_CATASTRAL por MAX_CUOTA.
Modificación: 01/06/2004. Agustín León Robles. Se cambia el select cuando se accede a la tabla de referencias_bancos
			Se quita los ltrim(rtrim(XX))
Modificación: 02/06/2004. Agustín León Robles. Si no tiene NIF del titular de la cuenta, el Nombre del titular 
			es el nombre de la tabla de Rus80
Modificación: 05/02/2007 Lucas Fernández Pérez. Ampliación del campo domicilio de la tabla RECIBOS_RUSTICA
********************************************************************************/

CREATE OR REPLACE PROCEDURE GENERA_PADRON_RUS (
       xMUNICIPIO 	IN CHAR,
       xYEAR 		IN CHAR,
       xDESDE 		IN DATE,
       xHASTA 		IN DATE,
	   xCARGO		IN DATE,
       xCONCEPTO 	IN CHAR,
       xLINEA1 		IN CHAR,
       xLINEA2 		IN CHAR,
       xLINEA3 		IN CHAR,
       xPERIODO 	IN CHAR)
AS
	xIMPORTE           	CHAR(12);
	xTOTAL             	FLOAT;
	xBaseImponible		FLOAT;
	xBONIFICACION		FLOAT default 0;
	xREFERENCIA         CHAR(10);
	xDIGITO_CONTROL     VARCHAR(2);
	xDIG_C60_M2         CHAR(2);
	xNUM_PER            INTEGER;
	xDOMICILIO          CHAR(60);
	xRECIBO             INTEGER;
	xGRAVAMEN 			FLOAT;
	xMAX_CUOTA			FLOAT;

	xPADRON				CHAR(6);
	xEMISOR 			CHAR(6);
	xTRIBUTO 			CHAR(3);

	xNOMBRE_TITULAR   	VARCHAR2(40);
	xCODPOSTAL 	    	CHAR(5);
	xPoblacion 	    	VARCHAR2(35);
	xPROVINCIA	    	VARCHAR2(35);

	CURSOR cRus80 IS
         SELECT * FROM RUS80 WHERE MUNICIPIO=xMUNICIPIO AND YEAR=xYEAR;
BEGIN

	SELECT RUSTICA_NUM_PERIODOS INTO xNUM_PER FROM DATOSPER WHERE MUNICIPIO=xMUNICIPIO;

	--Averiguar que concepto es el padron de vehiculos
	SELECT CONCEPTO INTO xPADRON FROM PROGRAMAS WHERE PROGRAMA='RUSTICA';

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

    BEGIN
   	   select GRAVAMEN,MAX_CUOTA INTO xGRAVAMEN,xMAX_CUOTA
		 from GRAVAMEN_IBI_RUS 
	    where MODULO='RUS' AND MUNICIPIO=xMUNICIPIO AND YEAR=xYEAR;
    EXCEPTION
	   when no_data_found then
		    xGRAVAMEN:=0;
	        xMAX_CUOTA:=0;
	END;
    
    FOR v_TRus IN cRus80 LOOP

      IF (v_TRus.DOMICILIADO='N') THEN
      
          xNOMBRE_TITULAR:=NULL;
          
      ELSE
      
			if RTRIM(v_TRus.DNI_FACTURA) IS NULL then
				xNOMBRE_TITULAR:=SUBSTR(v_TRus.NOMBRE,1,40);
			else
				SELECT NOMBRE INTO xNOMBRE_TITULAR FROM CONTRIBUYENTES WHERE NIF=v_TRus.DNI_FACTURA;
			end if;
			
      END IF;


	  xDOMICILIO:=SUBSTR( RTRIM(v_TRus.TIPO_VIA)||' '||
                          RTRIM(v_TRus.NOMBRE_VIA)||' '||
                          RTRIM(v_TRus.PRIMER_NUMERO)||' '||
                          RTRIM(v_TRus.BLOQUE)||' '||
                          RTRIM(v_TRus.ESCALERA)||' '||
			        	  RTRIM(v_TRus.PLANTA)||' '||
                          RTRIM(v_TRus.PUERTA) ,1 ,50);

	--domicilio fiscal en funcion de si tiene un representante o no.
	--Dentro de la funcion "GetDomicilioFiscal" se comprueba si tiene a su vez 
	--un domicilio alternativo.
	IF v_TRus.REPRESENTANTE IS NULL THEN		

		--En Rustica hay una variante ya que si no tiene representante y tampoco 
		--domicilios alternativos entonces se tiene que cojer los datos de la propia 
		--tabla de Rus80 y no de contribuyentes.

		IF v_TRus.IDDOMIALTER IS NULL THEN

			--xDomicilio ya estaria con datos 

			xPoblacion:=v_TRus.MUNICIPIO_FISCAL;
			xProvincia:=v_TRus.PROVINCIA;
			xCodPostal:=v_TRus.CODIGO_POSTAL;

		ELSE
			GetDomicilioFiscal(v_TRus.NIF,v_TRus.IDDOMIALTER,
					xDomicilio,xPoblacion,xProvincia,xCodPostal);
		END IF;

	ELSE
		GetDomicilioFiscal(v_TRus.REPRESENTANTE,v_TRus.IDDOMIALTER,
				xDomicilio,xPoblacion,xProvincia,xCodPostal);
	END IF;

	-- El número de recibo va a ser el ID de la tabla de Referencias_bancos.
      -- En el caso de genera el padrón por fincas nos encontraremos varios recibos del 
      -- mismo númro fijo, entonces cogemos cualquiera.

	SELECT MIN(ID) INTO xRECIBO FROM REFERENCIAS_BANCOS WHERE MUNICIPIO=xMUNICIPIO
			AND RTRIM(REF_RUSTICA)=RTRIM(v_TRus.NUM_FIJO) || RTRIM(v_TRus.NIF);
	
	-- al valor catastral se la calcula el % de participacion

	xBaseImponible:=ROUND((v_TRus.VALOR_CATASTRAL*v_TRus.COEFICIENTE_PARTICI)/100,2);

	xBonificacion:=0;

    select sum(VALOR_CATASTRAL_BONI) into xBonificacion
	from Rus81 where Abonado=v_TRus.ID;

	if xBonificacion is null then
	   xBonificacion:=0;
	end if;

	xBaseImponible := xBaseImponible - xBonificacion;

	xBaseImponible:=ROUND((xBaseImponible*xGRAVAMEN)/100,2);	

	xTOTAL:=ROUND( xBaseImponible / xNUM_PER, 2 );

    IF (xTOTAL<xMAX_CUOTA) THEN
	    xTOTAL:=0;
    END IF;	

	
    CALCULA_DC_60(xTOTAL,xRECIBO,xTRIBUTO,SUBSTR(xYEAR,3,2),xPERIODO,xEMISOR,xDIGITO_CONTROL);   

	--calcular los digitos de control del cuaderno 60 modalidad 2
	CALCULA_DC_MODALIDAD2_60(xTOTAL, xRECIBO, xTRIBUTO, SUBSTR(xYEAR,3,2), '1',
			to_char(xHASTA,'y'), to_char(xHASTA,'ddd'), xEMISOR, xDIG_C60_M2);
                                           
	-- convierte el Nº de Abonado en caracteres y rellena de ceros
      GETREFERENCIA(xRECIBO, xREFERENCIA); 

	-- convierte el importe relleno de ceros
      IMPORTEENCADENA(xTOTAL,xIMPORTE);

	--insertamos los cotitulares del recibo
	IF v_TRus.COTITULARES='S' THEN
		INSERT INTO COTITULARES_RECIBO(NIF,PROGRAMA,AYTO,PADRON,YEAR,PERIODO,RECIBO)
		SELECT NIF,'RUSTICA',xMUNICIPIO,xPADRON,xYEAR,xPERIODO,xRECIBO
		FROM COTITULARES
		WHERE ID_CONCEPTO=v_TRus.ID AND PROGRAMA='RUSTICA';
	END IF;

	INSERT INTO RECIBOS_RUSTICA
		(NUM_FIJO,ABONADO,YEAR,PERIODO,MUNICIPIO,SUPERFICIE,
		VALOR_CATASTRAL,PORCEN_PARTICIPACION,BASE_IMPONIBLE,TIPO_GRAVAMEN,BONIFICACION,
		TOTAL,IMPORTE,DESDE,HASTA,F_CARGO,
		CONCEPTO,LINEA1,LINEA2,LINEA3,EMISOR,TRIBUTO,EJERCICIO,
		REMESA,REFERENCIA,DIGITO_CONTROL,

		DOMICILIADO,ESTADO_BANCO,
		ENTIDAD,SUCURSAL,DC,CUENTA,F_DOMICILIACION,TITULAR,NOMBRE_TITULAR,

		RECIBO,NIF,NOMBRE,DOMICILIO,CODIGO_POSTAL,POBLACION,PROVINCIA,
		DISCRI_PERIODO,DIGITO_YEAR,F_JULIANA,DIGITO_C60_MODALIDAD2)
	VALUES
		(v_TRus.NUM_FIJO,v_TRus.ID,xYEAR,xPERIODO,xMUNICIPIO,v_TRus.SUPERFICIE_TOTAL,
		v_TRus.VALOR_CATASTRAL,v_TRus.COEFICIENTE_PARTICI,xBaseImponible,xGRAVAMEN,
		xBONIFICACION,xTOTAL,xIMPORTE,xDESDE,xHASTA,xCARGO,xCONCEPTO,
		xLINEA1,xLINEA2,xLINEA3,xEMISOR,xTRIBUTO,SUBSTR(xYEAR,3,2),xPERIODO,
		xREFERENCIA,xDIGITO_CONTROL,

		v_TRus.DOMICILIADO,DECODE(v_TRus.DOMICILIADO,'S','EB',NULL),
		DECODE(v_TRus.DOMICILIADO,'S',v_TRus.ENTIDAD,NULL),
		DECODE(v_TRus.DOMICILIADO,'S',v_TRus.SUCURSAL,NULL),
		DECODE(v_TRus.DOMICILIADO,'S',v_TRus.DC,NULL),
		DECODE(v_TRus.DOMICILIADO,'S',v_TRus.CUENTA,NULL),
		DECODE(v_TRus.DOMICILIADO,'S',v_TRus.F_DOMICILIACION,NULL),
		DECODE(v_TRus.DOMICILIADO,'S',v_TRus.DNI_FACTURA,NULL),
		xNOMBRE_TITULAR,

		xRECIBO,v_TRus.NIF,SUBSTR(v_TRus.NOMBRE,1,40),xDOMICILIO,xCODPOSTAL,xPOBLACION,
		xPROVINCIA,'1',to_char(xHASTA,'y'), to_char(xHASTA,'ddd'),xDIG_C60_M2);
    END LOOP;

   -- Insertamos una tupla en LOGSPADRONES para controlar que esta acción ha sido ejecutada
   INSERT INTO LOGSPADRONES (MUNICIPIO,PROGRAMA,PYEAR,PERIODO,HECHO)
   VALUES (xMUNICIPIO,'RUSTICA',xYEAR,xPERIODO,'Se Genera un Padrón');

END;
/

/********************************************************************************
Acción: Emite los recibos de Rústica
********************************************************************************/

CREATE OR REPLACE PROCEDURE GENERA_RECIBOS_RUS (
       xYEAR 		IN CHAR,
       xDESDE 		IN DATE,
       xHASTA 		IN DATE,
	 xCARGO		IN DATE,
       xCONCEPTO 		IN CHAR,
       xLINEA1 		IN CHAR,
       xLINEA2 		IN CHAR,
       xLINEA3 		IN CHAR,
       xPERIODO 		IN CHAR)

AS  
   CURSOR CAYTOS IS 
      SELECT MUNICIPIO FROM TMP_AYTOS WHERE USUARIO=USER;
BEGIN   
   FOR v_aytos IN CAYTOS 
   LOOP  
      GENERA_PADRON_RUS(v_aytos.MUNICIPIO,xYEAR,xDESDE,xHASTA,xCARGO,xCONCEPTO,
		            xLINEA1,xLINEA2,xLINEA3,xPERIODO);
   END LOOP;   
END;
/



--
-- Creado: 29/05/2003. Agustín León Robles
--		Dado el nuevo formato del padrón de Rústica viene información detallada de cada una 
--		las parcelas. Lo que se hace en este procedimiento es sumar los importes de cada una
--		las parcelas y anotarlas en la tabla de Rus80.
-- Modificado: 12/09/2003. Agustín León Robles
--		Se cambia el select de la tabla de Rus81 directamente por Abonado
create or replace procedure UpdateImporteRustica
		(xMUNICIPIO 			IN CHAR, 
	     	 xYEAR				IN CHAR)
as
xSuperficie			float default 0;
xValorCatastral		float default 0;
xValorParcela		float default 0;

cursor cRustica is select * from rus80 where Municipio=xMunicipio and Year=xYear
		for update of VALOR_CATASTRAL,SUPERFICIE_TOTAL,VALOR_TOTAL;

begin

	for vRustica in cRustica loop

		select sum(SUPERFICIE),sum(VALOR_CATASTRAL),sum(VALOR_PARCELA) 
		into xSuperficie,xValorCatastral,xValorParcela
		from Rus81 where Abonado=vRustica.ID;

		if xSuperficie is not null then

			update rus80 set VALOR_CATASTRAL=xValorCatastral,SUPERFICIE_TOTAL=xSuperficie,VALOR_TOTAL=xValorParcela
			where current of cRustica;

		end if;

		
	end loop;

end;
/


/****************************************************************************************
Autor: 29/05/2003 Gloria Maria Calle Hernandez.
Acción: Leer registros del disco de rústica usando utilidad UTL_FILE de Oracle.
*****************************************************************************************/ 
CREATE OR REPLACE PROCEDURE Read_RUSTICA (
	 xAyto					CHAR,
	 xYear					CHAR,
	 xFileName				CHAR,
	 xPath					CHAR
) as
     vOutFile 				UTL_FILE.FILE_TYPE;
     vReg				    VARCHAR2(720);
  
     vMUNICIPIO 			CHAR(3); 
     vYEAR					CHAR(4); 
     vCOD_DELEGACION		CHAR(2);
	 vCOD_GERENCIA			CHAR(1);
	 vCOD_MUNICIPIO			CHAR(3);
	 vRC_COD_DELEGACION		CHAR(2);
	 vRC_COD_MUNICIPIO		CHAR(3);
	 vRC_COD_SECTOR			CHAR(1);
	 vRC_COD_POLIGONO		CHAR(3);
	 vRC_NUM_PARCELA		CHAR(5);
	 vRC_NUM_SECUENCIAL		CHAR(4);
	 vRC_PRIMER_CONTROL		CHAR(1);
	 vRC_SEGUNDO_CONTROL	CHAR(1);
	 vRC_NUM_FIJO			CHAR(7);
	 vREG_TITULARIDAD		CHAR(2);
	 vCOEFICIENTE_PARTICI	FLOAT;
	 vINDI_COMUNIDAD_BIENES	CHAR(1);
	 vNUMERO_COMPONENTES	CHAR(3);
	 vCOD_PROVI_INE			CHAR(2);
	 vCOD_MUNI_INE			CHAR(3);
	 vCOD_MUNI_ORIGEN		CHAR(3);
	 vLP_COD_ZONA			CHAR(2);
	 vLP_COD_POLIGONO		CHAR(3);
	 vLP_NUM_PARCELA		CHAR(5);
	 vPARAJE				CHAR(30);
	 vNIF					CHAR(9);
	 vPERSONALIDAD			CHAR(1);
	 vNOMBRE				CHAR(60);
	 vCOD_DEL_MEH			CHAR(2);
	 vCOD_MUNICIPIO_DGC		CHAR(3);
	 vCOD_PROVI_INE_FISCAL 	CHAR(2);
	 vCOD_MUNI_INE_FISCAL	CHAR(3);
	 vCOD_VIA_PUBLICA		CHAR(5);
	 vTIPO_VIA				CHAR(5);
	 vNOMBRE_VIA			CHAR(25);
	 vPRIMER_NUMERO			CHAR(4);
	 vPRIMERA_LETRA			CHAR(1);
	 vSEGUNDO_NUMERO		CHAR(4);
	 vSEGUNDA_LETRA			CHAR(1);
	 vKILOMETRO				CHAR(5);
	 vBLOQUE				CHAR(4);
	 vTEXTO_DIRECCION		CHAR(25);
	 vESCALERA				CHAR(2);
	 vPLANTA				CHAR(3);
	 vPUERTA				CHAR(3);
	 vCODIGO_POSTAL			CHAR(5);
	 vAPARTADO_CORREOS		CHAR(5);
	 vPAIS					CHAR(25);
	 vPROVINCIA				CHAR(25);
	 vMUNICIPIO_FISCAL		CHAR(25);
	 vSUPERFICIE			FLOAT;
	 vVALOR_CATASTRAL		FLOAT;
	 vVALOR_CONDONADO		FLOAT;
	 vVALOR_CATASTRAL_BONI  FLOAT;
	 vCLAVE_BONI 			CHAR(1);
	 vYEAR_ALTA_PADRON		CHAR(4);

     PROCEDURE recNgo (str VARCHAR2)
     IS
     BEGIN
        DBMS_OUTPUT.PUT_LINE ('UTL_FILE error ' || str);
        UTL_FILE.FCLOSE (vOutFile);
     END;

begin

   vOutFile:=UTL_FILE.FOPEN(trim(xPath),trim(xFileName),'R');

   LOOP
   BEGIN

	  UTL_FILE.GET_LINE(vOutFile,vReg);
	  
      IF SUBSTR(vReg,1,1)='6' THEN
        
		vMUNICIPIO:=trim(xAyto);
        vYEAR:= trim(xYear);

        vCOD_DELEGACION:=SUBSTR(vReg,3,2);
        vCOD_GERENCIA:=SUBSTR(vReg,5,1);
        vCOD_MUNICIPIO:=SUBSTR(vReg,6,3);

        --Referencia Catastral
        vRC_COD_DELEGACION:=SUBSTR(vReg,9,2);
        vRC_COD_MUNICIPIO:=SUBSTR(vReg,11,3);
        vRC_COD_SECTOR:=SUBSTR(vReg,14,1);
        vRC_COD_POLIGONO:=SUBSTR(vReg,15,3);
        vRC_NUM_PARCELA:=SUBSTR(vReg,18,5);
        vRC_NUM_SECUENCIAL:=SUBSTR(vReg,23,4);
        vRC_PRIMER_CONTROL:=SUBSTR(vReg,27,1);
        vRC_SEGUNDO_CONTROL:=SUBSTR(vReg,28,1);
        vRC_NUM_FIJO:=SUBSTR(vReg,29,7);
        vREG_TITULARIDAD:=SUBSTR(vReg,36,2);

        BEGIN
           vCOEFICIENTE_PARTICI:=TO_NUMBER(SUBSTR(vReg,38,5));
        EXCEPTION
           WHEN OTHERS THEN
              vCOEFICIENTE_PARTICI:=0;
        END;

        vINDI_COMUNIDAD_BIENES:=SUBSTR(vReg,43,1);
        vNUMERO_COMPONENTES:=SUBSTR(vReg,44,3);

        --Localización de Parcela
        vCOD_PROVI_INE:=SUBSTR(vReg,58,2);
        vCOD_MUNI_INE:=SUBSTR(vReg,60,3);
        vCOD_MUNI_ORIGEN:=SUBSTR(vReg,63,3);
        vLP_COD_ZONA:=SUBSTR(vReg,66,2);
        vLP_COD_POLIGONO:=SUBSTR(vReg,68,3);
        vLP_NUM_PARCELA:=SUBSTR(vReg,71,5);
        vPARAJE:=SUBSTR(vReg,76,30);

        --Identificación del Titular
        vNIF:=SUBSTR(vReg,159,9);
        vPERSONALIDAD:=SUBSTR(vReg,168,1);
        vNOMBRE:=SUBSTR(vReg,169,60);

        --Domicilio Fiscal
        vCOD_DEL_MEH:=SUBSTR(vReg,229,2);
        vCOD_MUNICIPIO_DGC:=SUBSTR(vReg,231,3);
        vCOD_PROVI_INE_FISCAL:=SUBSTR(vReg,234,2);
        vCOD_MUNI_INE_FISCAL:=SUBSTR(vReg,236,3);
        vCOD_VIA_PUBLICA:=SUBSTR(vReg,239,5);
        vTIPO_VIA:=SUBSTR(vReg,244,5);
        vNOMBRE_VIA:=SUBSTR(vReg,249,25);
        vPRIMER_NUMERO:=SUBSTR(vReg,274,4);
        vPRIMERA_LETRA:=SUBSTR(vReg,278,1);
        vSEGUNDO_NUMERO:=SUBSTR(vReg,279,4);
        vSEGUNDA_LETRA:=SUBSTR(vReg,283,1);
        vKILOMETRO:=SUBSTR(vReg,284,5);
        vBLOQUE:=SUBSTR(vReg,289,4);
        vTEXTO_DIRECCION:=SUBSTR(vReg,293,25);
        vESCALERA:=SUBSTR(vReg,318,2);
        vPLANTA:=SUBSTR(vReg,320,3);
        vPUERTA:=SUBSTR(vReg,323,3);
        vCODIGO_POSTAL:=SUBSTR(vReg,326,5);
        vAPARTADO_CORREOS:=SUBSTR(vReg,331,5);
        vPAIS:=SUBSTR(vReg,336,25);
        vPROVINCIA:=SUBSTR(vReg,361,25);
        vMUNICIPIO_FISCAL:=SUBSTR(vReg,386,25);

        --Datos económicos de la Parcela
        BEGIN
           vSUPERFICIE:=TO_NUMBER(SUBSTR(vReg,411,10));
        EXCEPTION
           WHEN OTHERS THEN
              vSUPERFICIE:=0;
        END;

        BEGIN
           vVALOR_CATASTRAL:=TO_NUMBER(SUBSTR(vReg,421,12));
        EXCEPTION
           WHEN OTHERS THEN
              vVALOR_CATASTRAL:=0;
        END;

        BEGIN
           vVALOR_CONDONADO:=TO_NUMBER(SUBSTR(vReg,433,12));
        EXCEPTION
           WHEN OTHERS THEN
              vVALOR_CONDONADO:=0;
        END;

        BEGIN
           vVALOR_CATASTRAL_BONI:=TO_NUMBER(SUBSTR(vReg,445,12));
        EXCEPTION
           WHEN OTHERS THEN
              vVALOR_CATASTRAL_BONI:=0;
        END;
 
        vCLAVE_BONI:=SUBSTR(vReg,457,1);
        vYEAR_ALTA_PADRON:=SUBSTR(vReg,458,4);

	
        INSERTA_RUSTICA(vMUNICIPIO,vYEAR,vCOD_DELEGACION,vCOD_GERENCIA,vCOD_MUNICIPIO,vRC_COD_DELEGACION,vRC_COD_MUNICIPIO,
						vRC_COD_SECTOR,vRC_COD_POLIGONO,vRC_NUM_PARCELA,vRC_NUM_SECUENCIAL,vRC_PRIMER_CONTROL,vRC_SEGUNDO_CONTROL,
						vRC_NUM_FIJO,vREG_TITULARIDAD,vCOEFICIENTE_PARTICI,vINDI_COMUNIDAD_BIENES,vNUMERO_COMPONENTES,
						vCOD_PROVI_INE,vCOD_MUNI_INE,vCOD_MUNI_ORIGEN,vLP_COD_ZONA,vLP_COD_POLIGONO,vLP_NUM_PARCELA,
						vPARAJE,vNIF,vPERSONALIDAD,vNOMBRE,vCOD_DEL_MEH,vCOD_MUNICIPIO_DGC,vCOD_PROVI_INE_FISCAL,
						vCOD_MUNI_INE_FISCAL,vCOD_VIA_PUBLICA,vTIPO_VIA,vNOMBRE_VIA,vPRIMER_NUMERO,vPRIMERA_LETRA,
						vSEGUNDO_NUMERO,vSEGUNDA_LETRA,vKILOMETRO,vBLOQUE,vTEXTO_DIRECCION,vESCALERA,vPLANTA,vPUERTA,
						vCODIGO_POSTAL,vAPARTADO_CORREOS,vPAIS,vPROVINCIA,vMUNICIPIO_FISCAL,vSUPERFICIE,vVALOR_CATASTRAL,
						vVALOR_CONDONADO,vVALOR_CATASTRAL_BONI,vCLAVE_BONI,vYEAR_ALTA_PADRON);		 
	  END IF;

  	  EXCEPTION
	  WHEN NO_DATA_FOUND THEN
	   	  EXIT;
	  END;

   END LOOP;

   UTL_FILE.FCLOSE(vOutFile);

   EXCEPTION
   	  WHEN NO_DATA_FOUND
    	THEN recNgo ('no_data_found');
      WHEN UTL_FILE.INVALID_PATH
       THEN recNgo ('invalid_path');
      WHEN UTL_FILE.INVALID_MODE
       THEN recNgo ('invalid_mode');
      WHEN UTL_FILE.INVALID_FILEHANDLE
       THEN recNgo ('invalid_filehandle');
      WHEN UTL_FILE.INVALID_OPERATION
       THEN recNgo ('invalid_operation');
      WHEN UTL_FILE.READ_ERROR
       THEN recNgo ('read_error');
      WHEN UTL_FILE.WRITE_ERROR
       THEN recNgo ('write_error');
      WHEN UTL_FILE.INTERNAL_ERROR
       THEN recNgo ('internal_error');
	  WHEN VALUE_ERROR
	   THEN recNgo ('value_error'); 
	  WHEN OTHERS
	   THEN recNgo (To_Char(SQLCODE)||SQLERRM); 

   COMMIT;   
END Read_RUSTICA;
/


/****************************************************************************************
Autor: 29/05/2003 Agustín León Robles.
Acción: Nuevo formato de lectura del padrón de Rústica para el año 2003 y posteriores.
MODIFICACIÓN: 18/08/2003 M. Carmen Junco Gómez. Al seleccionar los datos de la domiciliación
			  del año anterior se podían seleccionar más de una tupla para el mismo año,
			  numero fijo y nif.
MODIFICACION: 07/02/2007. Lucas Fernández Pérez. Nuevos parametros letra-bloque en la llamada a InsertaModiContribuyente.
*****************************************************************************************/ 
create or replace procedure Inserta_Rustica
	(xMUNICIPIO 			IN CHAR, 
     	 xYEAR				IN CHAR, 
     	 xCOD_DELEGACION			IN CHAR,
	 xCOD_GERENCIA			IN CHAR,
	 xCOD_MUNICIPIO			IN CHAR,
	 xRC_COD_DELEGACION		IN CHAR,
	 xRC_COD_MUNICIPIO		IN CHAR,
	 xRC_COD_SECTOR			IN CHAR,
	 xRC_COD_POLIGONO			IN CHAR,
	 xRC_NUM_PARCELA			IN CHAR,
	 xRC_NUM_SECUENCIAL		IN CHAR,
	 xRC_PRIMER_CONTROL		IN CHAR,
	 xRC_SEGUNDO_CONTROL		IN CHAR,
	 xRC_NUM_FIJO			IN CHAR,
	 xREG_TITULARIDAD			IN CHAR,
	 xCOEFICIENTE_PARTICI		IN FLOAT,
	 xINDI_COMUNIDAD_BIENES		IN CHAR,
	 xNUMERO_COMPONENTES		IN CHAR,
	 xCOD_PROVI_INE			IN CHAR,
	 xCOD_MUNI_INE			IN CHAR,
	 xCOD_MUNI_ORIGEN			IN CHAR,
	 xLP_COD_ZONA			IN CHAR,
	 xLP_COD_POLIGONO			IN CHAR,
	 xLP_NUM_PARCELA			IN CHAR,
	 xPARAJE				IN CHAR,
	 xNIF					IN CHAR,
	 xPERSONALIDAD			IN CHAR,
	 xNOMBRE				IN CHAR,
	 xCOD_DEL_MEH			IN CHAR,
	 xCOD_MUNICIPIO_DGC		IN CHAR,
	 xCOD_PROVI_INE_FISCAL 		IN CHAR,
	 xCOD_MUNI_INE_FISCAL		IN CHAR,
	 xCOD_VIA_PUBLICA			IN CHAR,
	 xTIPO_VIA				IN CHAR,
	 xNOMBRE_VIA			IN CHAR,
	 xPRIMER_NUMERO			IN CHAR,
	 xPRIMERA_LETRA			IN CHAR,
	 xSEGUNDO_NUMERO			IN CHAR,
	 xSEGUNDA_LETRA			IN CHAR,
	 xKILOMETRO				IN CHAR,
	 xBLOQUE				IN CHAR,
	 xTEXTO_DIRECCION			IN CHAR,
	 xESCALERA				IN CHAR,
	 xPLANTA				IN CHAR,
	 xPUERTA				IN CHAR,
	 xCODIGO_POSTAL			IN CHAR,
	 xAPARTADO_CORREOS		IN CHAR,
	 xPAIS				IN CHAR,
	 xPROVINCIA				IN CHAR,
	 xMUNICIPIO_FISCAL		IN CHAR,
	 xSUPERFICIE			IN FLOAT,
	 xVALOR_CATASTRAL			IN FLOAT,
	 xVALOR_CONDONADO			IN FLOAT,
	 xVALOR_CATASTRAL_BONI  	IN FLOAT,
	 xCLAVE_BONI 			IN CHAR,
	 xYEAR_ALTA_PADRON		IN CHAR)
as

xID					integer;

xNIF_old 				char(10);
xNOMBRE_old 			char(60);
xTIPO_VIA_FISCAL_old		CHAR(5);
xNOMBRE_VIA_FISCAL_old		CHAR(25);
xPRIMER_NUMERO_FISCAL_old	CHAR(4);
xESCALERA_FISCAL_old		CHAR(2);
xPLANTA_FISCAL_old		CHAR(3);
xPUERTA_FISCAL_old		CHAR(3);
xCOD_POSTAL_FISCAL_old		CHAR(5);
xMUNICIPIO_FISCAL_old		CHAR(25);
xPROVINCIA_old			CHAR(25);
xPAIS_OLD				CHAR(25);

xDOMICILIADO                  CHAR(1);
xENTIDAD                      CHAR(4);
xSUCURSAL                     CHAR(4);
xDC                           CHAR(2);
xCUENTA                       CHAR(10);
xF_DOMICILIACION			DATE;
xDNI_FACTURA                  CHAR(10);

xREPRESENTANTE			CHAR(10);
xIDDOMIALTER			INTEGER;
xCOTITULARES			CHAR(1);

xIDRUS80				INTEGER;
mNIF					CHAR(10);  --vamos a guardar el NIF actual del registro
xVARIACION				CHAR(1);
xCORREGIDOS				CHAR(1);

begin


	-- Tendremos que averiguar si ha habido alguna variación del registro que
	-- queremos insertar en años anteriores. Para ello hacemos uso de la tabla 
 	-- HIS_CARGOREAL_RUS.   
   
	-- el Nif es un dato que se puede variar, con lo cual tendremos que hacer dos
	-- comprobaciones, ya que si este dato se modificó en un año anterior, no sabemos
	-- si en la cinta de este año vendrá ya corregido o sin corregir.

	SELECT MAX(IDRUS80) INTO xIDRUS80
	FROM HIS_CARGOREAL_RUS
	WHERE AYTO=xMUNICIPIO AND NUM_FIJO=xRC_NUM_FIJO AND (NIF_OLD=xNIF or NIF_NEW=xNIF)
		AND TIPO_VARIACION='M' AND ULTIMA_VARIACION='N';

	IF xIDRUS80 IS NULL THEN	
		xVARIACION:='N';
	ELSE
		xVARIACION:='S';
	END IF;        

	IF xVARIACION='S' THEN

		SELECT NIF_NEW INTO mNIF FROM HIS_CARGOREAL_RUS WHERE IDRUS80=xIDRUS80 AND 
			FECHA=(SELECT MAX(FECHA) FROM HIS_CARGOREAL_RUS WHERE IDRUS80=xIDRUS80);

	ELSE
		mNIF:=xNIF;
	END IF;

	-- en este punto ya tenemos almacenado el nif con el que tenemos que trabajar en mNIF
	-- y sabemos si ha habido o no variación en los datos a través de xVARIACION


	-- lee los datos de la domiciliacion de la cinta del año anterior,
	-- tambien los datos del representante,domicilios alternativos,cotitulares y 
	-- posibles datos que estén variados en el año anterior.
	
	SELECT MAX(ID) INTO xID FROM RUS80 
	WHERE MUNICIPIO=xMUNICIPIO AND YEAR=xYEAR-1 AND NUM_FIJO=xRC_NUM_FIJO AND
		  NIF=mNIF;			  
		  
    IF (xID IS NOT NULL) THEN
    	SELECT DOMICILIADO,ENTIDAD,SUCURSAL,DC,CUENTA,F_DOMICILIACION,	
			DNI_FACTURA,REPRESENTANTE,IDDOMIALTER,COTITULARES,
			NIF,NOMBRE,TIPO_VIA,NOMBRE_VIA,PRIMER_NUMERO,ESCALERA,PLANTA,PUERTA,
			CODIGO_POSTAL,MUNICIPIO_FISCAL,PROVINCIA,PAIS
		INTO xDOMICILIADO, xENTIDAD, xSUCURSAL, xDC,xCUENTA,xF_DOMICILIACION, 
			xDNI_FACTURA,xREPRESENTANTE,xIDDOMIALTER,xCOTITULARES,
			xNIF_OLD,xNOMBRE_OLD,xTIPO_VIA_FISCAL_OLD,xNOMBRE_VIA_FISCAL_OLD,
			xPRIMER_NUMERO_FISCAL_OLD,xESCALERA_FISCAL_OLD,xPLANTA_FISCAL_OLD,
			xPUERTA_FISCAL_OLD,xCOD_POSTAL_FISCAL_OLD,xMUNICIPIO_FISCAL_OLD,
			xPROVINCIA_OLD,xPAIS_OLD

		FROM RUS80 WHERE ID=xID;
    ELSE
       	xDOMICILIADO:='N';
		xENTIDAD:=Null;
		xSUCURSAL:=Null; 
		xDC:=Null;
		xCUENTA:=Null;
		xF_DOMICILIACION:=Null;	
		xDNI_FACTURA:=Null;		
		xREPRESENTANTE:=Null;
		xIDDOMIALTER:=Null;
		xCOTITULARES:='N';
    END IF;	
	

	--insertamos la informacion de la finca
	--solamente se inserta la primera vez la informacion referente a la finca en la tabla Rus80. 
	--Cuando aparezcan más registros del mismo número fijo y NIF solamente se inserta en la tabla de Rus81
	begin
		select ID into xID from Rus80 
		where Municipio=xMunicipio and Year=xYear and Num_Fijo=xRC_NUM_FIJO and NIF=mNIF;
	exception
		when no_data_found then
			xID:=Null;
	end;
	

	if (xID is null) then

		xCORREGIDOS:='N';

		-- si ha habido variación cambiamos los datos de la cinta por estos otros recogidos
		-- de los datos del año anterior.
		IF xVARIACION='S' THEN	   

			-- antes de hacer el cambio comprobaremos si los datos que vienen en la Cinta de 
			-- Hacienda este año vienen ya corregidos o no.
			IF (mNIF=xNIF AND
				 xNOMBRE=xNOMBRE_old AND
				 xTIPO_VIA=xTIPO_VIA_FISCAL_old AND
				 xNOMBRE_VIA=xNOMBRE_VIA_FISCAL_old AND
				 xPRIMER_NUMERO=xPRIMER_NUMERO_FISCAL_old AND
				 xESCALERA=xESCALERA_FISCAL_old AND
				 xPLANTA=xPLANTA_FISCAL_old AND
				 xPUERTA=xPUERTA_FISCAL_old AND
				 xCODIGO_POSTAL=xCOD_POSTAL_FISCAL_old AND
				 xMUNICIPIO_FISCAL=xMUNICIPIO_FISCAL_old AND
				 xPROVINCIA=xPROVINCIA_old AND
				 xPAIS=xPAIS_OLD) THEN

				-- Si los datos están corregidos lo indicamos en la tabla HIS_CARGOREAL_RUS 
				-- modificando el valor de ULTIMA_VARIACION='S' para la tupla de variaciones 
				-- con IDRUS80=xIDRUS80
				xCORREGIDOS:='S';

				UPDATE HIS_CARGOREAL_RUS SET ULTIMA_VARIACION='S' WHERE IDRUS80=xIDRUS80;
			ELSE
		      	xCORREGIDOS:='X';
			END IF;

		END IF;   


		InsertaModiContribuyente(mNIF,substr(xNOMBRE,1,40),
					substr(xTIPO_VIA,1,2),xNOMBRE_VIA,
					xPRIMER_NUMERO,'','',xESCALERA,xPLANTA,
					substr(xPUERTA,1,2),
					xMUNICIPIO_FISCAL,xPROVINCIA,xCODIGO_POSTAL,xPAIS);

		insert into rus80(MUNICIPIO,YEAR,COD_DELEGACION_MEH,COD_MUNICIPIO,
			NUM_FIJO,COEFICIENTE_PARTICI,COD_GERENCIA,
			COD_PROVI_INE,COD_MUNI_INE,NIF,PERSONALIDAD,NOMBRE,
			INDI_COMUNIDAD_BIENES,NUMERO_COMPONENTES,COD_DEL_MEH,
			COD_MUNICIPIO_DGC,COD_PROVI_INE_FISCAL,COD_MUNI_INE_FISCAL,
			COD_VIA_PUBLICA,TIPO_VIA,NOMBRE_VIA,PRIMER_NUMERO,
			PRIMERA_LETRA,SEGUNDO_NUMERO,SEGUNDA_LETRA,KILOMETRO,BLOQUE,
			TEXTO_DIRECCION,ESCALERA,PLANTA,PUERTA,CODIGO_POSTAL,
			APARTADO_CORREOS,PAIS,PROVINCIA,MUNICIPIO_FISCAL,
			YEAR_ALTA_PADRON,
			DOMICILIADO,ENTIDAD,SUCURSAL,DC,CUENTA,F_DOMICILIACION,
			DNI_FACTURA,REPRESENTANTE,IDDOMIALTER,COTITULARES)

		values (xMUNICIPIO,xYEAR,xCOD_DELEGACION,xCOD_MUNICIPIO,xRC_NUM_FIJO,xCOEFICIENTE_PARTICI/100,xCOD_GERENCIA,
			xCOD_PROVI_INE,xCOD_MUNI_INE,mNIF,xPERSONALIDAD,
			decode(xCORREGIDOS,'X',xNOMBRE_old,xNOMBRE),
			xINDI_COMUNIDAD_BIENES,xNUMERO_COMPONENTES,
			xCOD_DEL_MEH,xCOD_MUNICIPIO_DGC,xCOD_PROVI_INE_FISCAL,xCOD_MUNI_INE_FISCAL,
			xCOD_VIA_PUBLICA,
			decode(xCORREGIDOS,'X',xTIPO_VIA_FISCAL_old,xTIPO_VIA),
			decode(xCORREGIDOS,'X',xNOMBRE_VIA_FISCAL_old,xNOMBRE_VIA),
			decode(xCORREGIDOS,'X',xPRIMER_NUMERO_FISCAL_old,xPRIMER_NUMERO),
			xPRIMERA_LETRA,xSEGUNDO_NUMERO,xSEGUNDA_LETRA,xKILOMETRO,xBLOQUE,xTEXTO_DIRECCION,
			decode(xCORREGIDOS,'X',xESCALERA_FISCAL_old,xESCALERA),
			decode(xCORREGIDOS,'X',xPLANTA_FISCAL_old,xPLANTA),
			decode(xCORREGIDOS,'X',xPUERTA_FISCAL_old,xPUERTA),
			decode(xCORREGIDOS,'X',xCOD_POSTAL_FISCAL_old,xCODIGO_POSTAL),
			xAPARTADO_CORREOS,
			decode(xCORREGIDOS,'X',xPAIS_OLD,xPAIS),
			decode(xCORREGIDOS,'X',xPROVINCIA_old,xPROVINCIA),
			decode(xCORREGIDOS,'X',xMUNICIPIO_FISCAL_old,xMUNICIPIO_FISCAL),
			xYEAR_ALTA_PADRON,
			xDOMICILIADO,xENTIDAD,xSUCURSAL,xDC,xCUENTA,xF_DOMICILIACION,
			xDNI_FACTURA,xREPRESENTANTE,xIDDOMIALTER,xCOTITULARES)

		return ID into xID;

		-- si no vienen los datos corregidos en la cinta de este año, insertamos una nueva tupla 
		-- de variaciones, indicando que la ha generado el programa automáticamente 
		-- (no se debe a una variación manual por parte del usuario a petición del sujeto pasivo)
		IF (xCORREGIDOS='X') THEN

			INSERT INTO HIS_CARGOREAL_RUS
				(IDRUS80,AYTO,TIPO_VARIACION,NUM_FIJO,NIF_NEW,NIF_OLD,NOMBRE,
				TIPO_VIA_FISCAL,NOMBRE_VIA_FISCAL,PRIMER_NUMERO_FISCAL,ESCALERA_FISCAL,
				PLANTA_FISCAL,PUERTA_FISCAL,COD_POSTAL_FISCAL,MUNICIPIO_FISCAL,PROVINCIA,PAIS)
			VALUES
				(xID,xMUNICIPIO,'A',xRC_NUM_FIJO,xNIF,mNIF,xNOMBRE,xTIPO_VIA,xNOMBRE_VIA,
				xPRIMER_NUMERO,xESCALERA,xPLANTA,xPUERTA,xCODIGO_POSTAL,xMUNICIPIO_FISCAL,xPROVINCIA,xPAIS);

		END IF;

	end if; --final del: if (xID is null) then

	--insertamos la informacion de la parcela
	insert into rus81(ABONADO,MUNICIPIO,YEAR,COD_DELEGACION_MEH,COD_MUNICIPIO,
		COD_MUNICIPIO_ORIGEN,COD_ZONA,COD_POLIGONO_CATASTRAL,
		NUMERO_PARCELA,PRIMER_CONTROL,SEGUNDO_CONTROL,
		NUM_FIJO,COD_GERENCIA,COD_PROVI_INE,
		COD_MUNI_INE,PARAJE,REGIMEN_TITULARIDAD,SUPERFICIE,VALOR_CATASTRAL,VALOR_PARCELA,
		VALOR_CATASTRAL_BONI,CLAVE_BONI,NUM_SECUENCIAL_PARCELA)

	values (xID,xMUNICIPIO,xYEAR,xRC_COD_DELEGACION,xRC_COD_MUNICIPIO,
		xCOD_MUNI_ORIGEN,xLP_COD_ZONA,xRC_COD_POLIGONO,
		xLP_NUM_PARCELA,xRC_PRIMER_CONTROL,xRC_SEGUNDO_CONTROL,
		xRC_NUM_FIJO,xCOD_GERENCIA,xCOD_PROVI_INE,
		xCOD_MUNI_INE,substr(xPARAJE,1,20),xREG_TITULARIDAD,
		xSUPERFICIE/10000,xVALOR_CATASTRAL/100,xVALOR_CONDONADO/100,
		xVALOR_CATASTRAL_BONI/100,RTRIM(xCLAVE_BONI),xRC_NUM_SECUENCIAL);

end;
/



/********************************************************************************
Acción: domiciliación de un recibo.
MODIFICACIÓN: 25/06/2002 M. Carmen Junco Gómez. Comprueba si hay recibo emitido 
              del padrón anual en curso y en tal caso modifica los datos de la 
              domiciliación para que entre en los soportes del cuaderno 19
MODIFICACION: 03/07/2002 M. Carmen Junco Gómez. Si no se encontraba el recibo en la 
		  tabla de valores estavamos asignándole a mVOL_EJE:=''; En mi máquina,
		  por ejemplo, funcionaba correctamente, pero en Salobreña estaba fallando
		  el procedimiento (no domiciliaba el recibo) debido a esta asignación.
		  Se ha cambiado por mVOL_EJE:=NULL;		 
MODIFICACION: 08/07/2002 M. Carmen Junco Gómez. El recibo de Rústica sólo se podrá modificar
		  si aún no se ha emitido el Cuaderno19 para el padrón al que pertenece.
		  Además, cuando modificamos en recaudación, debemos tener en cuenta si el
		  cargo se ha aceptado o no. Si aún no se ha aceptado habrá que hacer la
		  modificación en la tabla PUNTEO y no en VALORES.
MODIFICACIÓN: 04/12/2002 M. Carmen Junco Gómez. Insertamos los campos MUNICIPIO y 
		  PERIODO en LOGSPADRONES.
Modificado: 02/06/2004. Agustín Léon Robles. 
			Puede darse el caso de que no tengamos el NIF del titular de la cuenta, entonces
			el nombre del titular será el de la tabla de Rus80
MODIFICACIÓN: 01/02/2005 Lucas Fernandez Pérez. Se añade el parámetro xMotivoCambioDomi.
		  Se eliminan los campos USR_CHG__CUENTA y F_CHG__CUENTA.
		  La información se almacenará ahora en la tabla HISTO_DOMICILIACIONES.
MODIFICACIÓN: 10/03/2005 Lucas Fernández Pérez. Hasta ahora se comprobaban los recibos emitidos 
		  en el año en curso, de tal forma que no hacía la modificación del recibo si el padrón se
		  emitió el año anterior al actual. Lo que haremos será revisar los recibos emitidos desde
		  hace un año al día de hoy. 		  
********************************************************************************/

CREATE OR REPLACE PROCEDURE RUS_BANCOS(
       xID 				IN INTEGER,
       xENTIDAD 		IN CHAR,
       xSUCURSAL 		IN CHAR,
       xDC 				IN CHAR,
       xCUENTA 			IN CHAR,
	   xF_DOMICILIACION IN DATE,
       xTITULAR 		IN CHAR,
       xDOMICILIADO 	IN CHAR,
       xMotivoCambioDomi IN  VARCHAR2)
AS

	mVOL_EJE 	Char(1);
	mVALOR   	Integer;
	mPUNTEO  	Integer;
	mPADRON 	CHAR(6);
	xNOMBRE_TITULAR CHAR(40);
	xCuantos 	Integer;
	xNombre		varchar2(40);

	-- cursor que recorre los distintos periodos de los distintos recibos que 
	-- se han podido emitir para este abonado, para comprobar para que padrón
	-- se ha emitido ya el Cuaderno19, y por lo tanto no modificar la domiciliación
	-- de ese recibo. Han de ser recibos emitidos en el año en curso.
	CURSOR CPERIODOS IS SELECT DISTINCT YEAR,PERIODO,ID,MUNICIPIO,RECIBO FROM RECIBOS_RUSTICA
				  WHERE ABONADO=xID 
				  		AND YEAR BETWEEN (TO_CHAR(sysdate,'yyyy')-1) AND TO_CHAR(sysdate,'yyyy');
				  

BEGIN


	-- Se pone el posible motivo del cambio en la domiciliación en USUARIOSGT (campo TEXTO2).
    UPDATE USUARIOSGT SET TEXTO2=xMotivoCambioDomi WHERE USUARIO=USER;

    -- se actualiza en la tabla RUS80
	UPDATE RUS80 SET ENTIDAD=xENTIDAD,
                   		SUCURSAL=xSUCURSAL,
                   		DC=xDC,CUENTA=xCUENTA,
			 			F_DOMICILIACION=xF_DOMICILIACION,
                   		DNI_FACTURA=xTITULAR,
                   		DOMICILIADO=xDOMICILIADO
                   		
	WHERE ID=xID RETURN substr(NOMBRE,1,40) INTO xNombre;

	-- por cada periodo distinto de recibos sobre el abonado
	FOR vPERIODOS IN CPERIODOS 
	LOOP	 

         -- Comprobamos si se ha emitido ya el soporte del cuaderno 19
	   SELECT COUNT(*) INTO xCUANTOS FROM LOGSPADRONES 
	   WHERE MUNICIPIO=vPERIODOS.MUNICIPIO AND 
		   PROGRAMA ='RUSTICA' AND 
		   PYEAR=vPERIODOS.YEAR AND
		   PERIODO=vPERIODOS.PERIODO AND 
		   HECHO='Generación Cuaderno 19 (recibos domiciliados)';

	   IF xCUANTOS=0 THEN  -- aún no se ha emitido. Podemos modificar el recibo.
	   
	      -- Averiguar el código de padron de RUSTICA
		SELECT CONCEPTO INTO mPADRON FROM PROGRAMAS WHERE PROGRAMA='RUSTICA';
		
		-- Comprobar si ya se paso a recaudación    
		begin
	   		SELECT ID,VOL_EJE INTO mVALOR,mVOL_EJE FROM VALORES 
         		WHERE AYTO=vPERIODOS.MUNICIPIO AND PADRON=mPADRON AND
		   		YEAR=vPERIODOS.YEAR AND PERIODO=vPERIODOS.PERIODO AND 
				RECIBO=vPERIODOS.RECIBO;
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
					AND RECIBO=vPERIODOS.RECIBO;
				Exception
					When no_data_found then
						mVOL_EJE:=NULL;
			end;
		END IF;

		-- si el recibo está en Voluntaria en RECA o todavia no se ha pasado a recaudación
		IF ((mVOL_EJE='V') or (mVOL_EJE IS NULL)) THEN

	   		-- modificamos el recibo en gestión tributaria
	   		IF xDOMICILIADO='N' THEN
	      		UPDATE RECIBOS_RUSTICA SET DOMICILIADO='N',
								   ENTIDAD=NULL,
								   SUCURSAL=NULL,
								   DC=NULL,
								   CUENTA=NULL,
								   F_DOMICILIACION=NULL,
								   TITULAR=NULL,
								   NOMBRE_TITULAR=NULL,
								   ESTADO_BANCO=NULL
				WHERE ID=vPERIODOS.ID;
			ELSE				
				
				--Puede darse el caso de que no tengamos el NIF del titular de la cuenta
				if RTRIM(xTitular) is null then				
					xNOMBRE_TITULAR:=xNombre;
				else
					SELECT NOMBRE INTO xNOMBRE_TITULAR FROM CONTRIBUYENTES WHERE NIF=xTITULAR;
				end if;

	   			UPDATE RECIBOS_RUSTICA SET DOMICILIADO='S',
							 	   ENTIDAD=xENTIDAD,
								   SUCURSAL=xSUCURSAL,
								   DC=xDC,
								   CUENTA=xCUENTA,
								   F_DOMICILIACION=xF_DOMICILIACION,
								   TITULAR=xTITULAR,
								   NOMBRE_TITULAR=xNOMBRE_TITULAR,
								   ESTADO_BANCO='EB'
			    WHERE ID=vPERIODOS.ID;
			END IF;

	   		-- modificamos los datos del valor (o del punteo)
	   		IF mVOL_EJE='V' THEN				
				IF xDOMICILIADO = 'N' THEN
					IF mVALOR IS NOT NULL THEN
  	         			   UPDATE VALORES SET 
					   ESTADO_BANCO=DECODE(ESTADO_BANCO, 'EB', NULL, ESTADO_BANCO)
	         			   WHERE ID=mVALOR;
					ELSE
					   UPDATE PUNTEO SET
					   ESTADO_BANCO=DECODE(ESTADO_BANCO, 'EB', NULL, ESTADO_BANCO)
					   WHERE ID=mPUNTEO;
					END IF;
				ELSE		
					IF mVALOR IS NOT NULL THEN
  	         			   UPDATE VALORES SET 
					   ESTADO_BANCO=DECODE(ESTADO_BANCO, NULL, 'EB',ESTADO_BANCO)
	         			   WHERE ID=mVALOR;		
					ELSE
					   UPDATE PUNTEO SET
					   ESTADO_BANCO=DECODE(ESTADO_BANCO, NULL, 'EB',ESTADO_BANCO)
	         			   WHERE ID=mPUNTEO;			
					END IF;
				END IF; 						
	   		END IF; 

     		END IF; -- ((mVOL_EJE='V') or (mVOL_EJE IS NULL))	 

         END IF;

     END LOOP;

END;
/

/********************************************************************************
Acción: Modificación de un registro.
MODIFICACIÓN: 26/03/2002 M. del Carmen Junco Gómez. 
		Permitimos cambiar los datos fiscales
		del fichero RUS80 por indicación del sujeto pasivo, guardando los datos que venían
		en cita en una tabla histórica. 
		En cargas posteriores tenedremos que buscar posibles variaciones (utilizando la tabla
		HIS_CARGOREAL_RUS) para no perder los datos actualizados.
MODIFICACIÓN: A petición de Agustín: 20/05/2002. M. Carmen Junco Gómez. 
		Se van a guardar todas las variaciones (no sólo los datos que venían en disco) para 
		poder tener un histórico. También podremos modificar de forma masiva los datos fiscales
		en la tabla de Rus80 (por código de operación).
MODIFICACIÓN: 01/06/2004. Agustín León Robles. 
		Se cambia el select cuando se accede a la tabla de referencias_bancos. 
		Se quita los ltrim(rtrim(XX))
MODIFICACIÓN: 31/01/2005. M. Carmen Junco Góemz.
		Se añade el motivo del cambio.
********************************************************************************/

CREATE OR REPLACE PROCEDURE RUS_MODIFICA(
       xID 				IN INTEGER,
       xNIF 			IN CHAR,
       xNOMBRE 		IN CHAR,
       xVIAF 			IN CHAR,
       xCALLEF 		IN VARCHAR2,
       xNUMEROF 		IN CHAR,
       xESCALERAF 	IN CHAR,
       xPLANTAF 		IN CHAR,
       xPISOF 			IN CHAR,
       xCPF 			IN CHAR,
       xPOBLACIONF 	IN VARCHAR2,
       xPROVINCIAF 	IN VARCHAR2,
	    xPAISF 			IN CHAR,
	    xCODIGO_OPERACION IN INTEGER,
	    xMOTIVO			IN	VARCHAR2)       
AS

	mNIF 		CHAR(10);    
	v_registro		RUS80%ROWTYPE;

	-- cursor que recorre todos los registros con código de operacion=xCodigo_Operacion
	-- de forma que se puedan actualizar los datos fiscales a la vez para más de un 
	-- registro de la tabla de RUS80.
	-- Guardaremos los datos actuales en la tabla HIS_CARGOREAL_RUS para mantener 
	-- un histórico.

	CURSOR CRUS80 IS SELECT * FROM RUS80 WHERE CODIGO_OPERACION=xCODIGO_OPERACION
			      FOR UPDATE OF NIF,NOMBRE,TIPO_VIA,NOMBRE_VIA,PRIMER_NUMERO,
                   	              ESCALERA,PLANTA,PUERTA,CODIGO_POSTAL,
					        MUNICIPIO_FISCAL,PROVINCIA,PAIS;
BEGIN   

   -- Si trabajamos sólo sobre un registro
   IF xCODIGO_OPERACION=0 THEN 

		-- recogemos los datos actuales que para este ID hay en la tabla RUS80.
		SELECT * INTO v_registro FROM RUS80 WHERE ID=xID;

		INSERT INTO HIS_CARGOREAL_RUS
			(IDRUS80,AYTO,TIPO_VARIACION,NUM_FIJO,NIF_NEW,NIF_OLD,NOMBRE,
			TIPO_VIA_FISCAL,NOMBRE_VIA_FISCAL,PRIMER_NUMERO_FISCAL,ESCALERA_FISCAL,
			PLANTA_FISCAL,PUERTA_FISCAL,COD_POSTAL_FISCAL,MUNICIPIO_FISCAL,PROVINCIA,PAIS,MOTIVO)
		VALUES
			(v_registro.ID,v_registro.MUNICIPIO,'M',v_registro.NUM_FIJO,xNIF,
			v_registro.NIF,v_registro.NOMBRE,v_registro.TIPO_VIA,v_registro.NOMBRE_VIA,
			v_registro.PRIMER_NUMERO,v_registro.ESCALERA,v_registro.PLANTA,
			v_registro.PUERTA,v_registro.CODIGO_POSTAL,v_registro.MUNICIPIO_FISCAL,
			v_registro.PROVINCIA,v_registro.PAIS,xMOTIVO);

		-- guardamos el nif que tenemos antes de modificar los datos, ya que 
		-- este dato puede ser modificado y lo necesitamos como clave en la tabla
		-- Referencias_bancos
		mNIF:=v_registro.NIF;

		-- modificamos los datos en la tabla RUS80   
		UPDATE RUS80 SET NIF=xNIF,
                       NOMBRE=xNOMBRE,
                       TIPO_VIA=xVIAF,
                       NOMBRE_VIA=SUBSTR(xCALLEF,1,25),
                       PRIMER_NUMERO=xNUMEROF,
                       ESCALERA=xESCALERAF,
                       PLANTA=xPLANTAF,
                       PUERTA=xPISOF,
                       CODIGO_POSTAL=xCPF,
                       MUNICIPIO_FISCAL=xPOBLACIONF,
                       PROVINCIA=SUBSTR(xPROVINCIAF,1,25),
                       PAIS=SUBSTR(xPAISF,1,25)
		WHERE ID=xID;

		-- Si se ha modificado el nif tendremos que modificar la referencia para rústica
		-- en la tabla REFERENCIAS_BANCOS.

		IF mNIF<>xNIF THEN	
			UPDATE REFERENCIAS_BANCOS SET 
						NIF=xNIF,
						REF_RUSTICA=RTRIM(v_registro.NUM_FIJO)|| RTRIM(xNIF)
			WHERE MUNICIPIO=v_registro.MUNICIPIO AND RTRIM(REF_RUSTICA)=RTRIM(v_registro.NUM_FIJO)||RTRIM(mNIF);
		END IF;

		
   -- si se van a modificar más de un registro a la vez
   ELSE  

      FOR vRUS IN CRUS80 
      LOOP	            

   	   -- Insertamos en el historico la información que hasta ahora poseíamos
	   -- para el registro en la tabla de RUS80.

	   INSERT INTO HIS_CARGOREAL_RUS
	      (IDRUS80,AYTO,TIPO_VARIACION,NUM_FIJO,NIF_NEW,NIF_OLD,NOMBRE,
	       TIPO_VIA_FISCAL,NOMBRE_VIA_FISCAL,PRIMER_NUMERO_FISCAL,ESCALERA_FISCAL,
	       PLANTA_FISCAL,PUERTA_FISCAL,COD_POSTAL_FISCAL,MUNICIPIO_FISCAL,PROVINCIA,
	       PAIS,MOTIVO)
	   VALUES
	      (vRUS.ID,vRUS.MUNICIPIO,'M',vRUS.NUM_FIJO,xNIF,
	       vRUS.NIF,vRUS.NOMBRE,vRUS.TIPO_VIA,vRUS.NOMBRE_VIA,
	       vRUS.PRIMER_NUMERO,vRUS.ESCALERA,vRUS.PLANTA,
	       vRUS.PUERTA,vRUS.CODIGO_POSTAL,vRUS.MUNICIPIO_FISCAL,
	       vRUS.PROVINCIA,vRUS.PAIS,xMOTIVO);

	   mNIF:=vRUS.NIF;

	   -- modificamos los datos en la tabla RUS80   
         UPDATE RUS80 SET NIF=xNIF,
                   	  NOMBRE=xNOMBRE,
                   	  TIPO_VIA=xVIAF,
                   	  NOMBRE_VIA=SUBSTR(xCALLEF,1,25),
                   	  PRIMER_NUMERO=xNUMEROF,
                   	  ESCALERA=xESCALERAF,
                   	  PLANTA=xPLANTAF,
                   	  PUERTA=xPISOF,
                   	  CODIGO_POSTAL=xCPF,
                   	  MUNICIPIO_FISCAL=xPOBLACIONF,
                   	  PROVINCIA=SUBSTR(xPROVINCIAF,1,25),
                   	  PAIS=SUBSTR(xPAISF,1,25)
	   WHERE CURRENT OF CRUS80;

         -- Si se ha modificado el nif tendremos que modificar la referencia para rústica
         -- en la tabla REFERENCIAS_BANCOS.

         IF mNIF<>xNIF THEN	
	      UPDATE REFERENCIAS_BANCOS SET NIF=xNIF,
					            REF_RUSTICA=RTRIM(vRUS.NUM_FIJO)|| RTRIM(xNIF)
	      WHERE MUNICIPIO=vRUS.MUNICIPIO AND RTRIM(REF_RUSTICA)=RTRIM(vRUS.NUM_FIJO)||RTRIM(mNIF);
	   END IF;

      END LOOP;

   END IF;	

END;
/

-- ****************************************************************************************
-- Acción: Pase a recaudación de un padrón.
-- MODIFICACIÓN: 23/08/2001 Agustin Leon Robles.
-- MODIFICACIÓN: 12/09/2001 Lucas Fernández Pérez. Adaptación al euro.
-- MODIFICACIÓN: 27/05/2002 M. Carmen Junco Gómez. Incluir o no los exentos dependiendo
-- 		  del nuevo parámetro de entrada xEXENTOS.
-- MODIFICACIÓN: 24/06/2002 M. Carmen Junco Gómez. Añadir Bonificación al recibo.
-- MODIFICACIÓN: 1/07/2002 M. Carmen Junco Gómez. Insertar una tupla en LogsPadrones
-- 		  para controlar que se ha pasado un padrón a Recaudación.
-- MODIFICACIÓN: 04/12/2002 M. Carmen Junco Gómez. Se añaden los campos MUNICIPIO y
-- 		  PERIODO en la tabla LOGSPADRONES.
-- MODIFICACIÓN: 30/09/2003 Lucas Fernández Pérez. Se cambia el formato de la bonificación 
--					de 900 a 999G990D00, porque pasa de ser un porcentaje a un importe.
-- MODIFICACIÓN: 13/01/2004 Gloria Mª Calle Hernández. Se cambia el formato del tipo de Gravamen
--					de 0D99 a 0D999, porque pasa a arrastrar 3 dígitos decimales.
-- MODIFICACIÓN: 09/06/2004 Gloria Mª Calle Hernández. Se guarda en el campo Clave_recibo el ID 
--			 	 de la la tabla de recibos.
--*****************************************************************************************

CREATE OR REPLACE PROCEDURE RUS_PASE_RECA(
       xMUNICIPIO 		IN CHAR,
       xYEAR 			IN CHAR,
       xPERIODO 		IN CHAR,
       xFECHA 			IN DATE,
       xN_CARGO 		IN CHAR,
	   xYEARCONTRAIDO	IN CHAR,
	   xEXENTOS			IN CHAR)
AS
	NUM_FIJO              	  CHAR(8);
	VALOR_CATASTRAL       	  FLOAT;
	PORCEN_PARTI		  	  FLOAT;
	BASE_IMPONIBLE		  	  FLOAT;
	TIPO_GRAVAMEN		  	  FLOAT;
	BONIFICACION		  	  FLOAT;
	SUPERFICIE_REAL           FLOAT;
	SUPERFICIE                CHAR(50);
	RECIBO                    INTEGER;
	xSALTO                    CHAR(2);
	xPADRON                   CHAR(6);
	xNIF		              CHAR(10);
	xNOMBRE                   VARCHAR(40);
	ESTADO_BANCO              CHAR(2);
	INICIO_PERIODO_VOLUN      DATE;
	FIN_PERIODO_VOLUNTARIO    DATE;
	PRINCIPAL                 FLOAT;
	OBJETO_TRIBUTARIO         VARCHAR(1024);
	xTIPO_TRIBUTO		  	  CHAR(2);
	xID						  INTEGER;


	CURSOR CRECRUS IS 
		SELECT ID,NIF,NOMBRE,DESDE,HASTA,TOTAL,NUM_FIJO, 
		       VALOR_CATASTRAL,PORCEN_PARTICIPACION,BASE_IMPONIBLE,TIPO_GRAVAMEN,
			   BONIFICACION,SUPERFICIE,ESTADO_BANCO,RECIBO 
		FROM RECIBOS_RUSTICA 
		WHERE MUNICIPIO=xMUNICIPIO AND YEAR=xYEAR AND PERIODO=xPERIODO;

BEGIN

	SELECT CONCEPTO INTO xPADRON FROM PROGRAMAS WHERE PROGRAMA='RUSTICA';

	SELECT TIPO_TRIBUTO INTO xTIPO_TRIBUTO
	FROM CONTADOR_CONCEPTOS
	WHERE MUNICIPIO=xMUNICIPIO AND CONCEPTO=xPADRON;

	SELECT min(SALTO) INTO xSALTO FROM SALTO;

	OPEN CRECRUS;
	LOOP
        FETCH CRECRUS INTO xID,xNIF,xNOMBRE,INICIO_PERIODO_VOLUN,FIN_PERIODO_VOLUNTARIO,
   			          PRINCIPAL,NUM_FIJO,VALOR_CATASTRAL,PORCEN_PARTI,BASE_IMPONIBLE,
				      TIPO_GRAVAMEN,BONIFICACION,SUPERFICIE_REAL,ESTADO_BANCO,RECIBO;
        EXIT WHEN CRECRUS%NOTFOUND;
 
        SUPERFICIE:=TO_CHAR(SUPERFICIE_REAL,'000D99');

        OBJETO_TRIBUTARIO:='ABONADO Nº: '||
                            RTRIM(TO_CHAR(RECIBO))||xSALTO;
 
        OBJETO_TRIBUTARIO:=OBJETO_TRIBUTARIO||'NUMERO FIJO: '||NUM_FIJO||xSALTO;

        OBJETO_TRIBUTARIO:=OBJETO_TRIBUTARIO||'SUPERFICIE: '||
                           RTRIM(SUPERFICIE)||' H. '||xSALTO;

        OBJETO_TRIBUTARIO:=OBJETO_TRIBUTARIO||'VALOR CATASTRAL: '||
                           RTRIM(TO_CHAR(VALOR_CATASTRAL))||xSALTO;

	  OBJETO_TRIBUTARIO:=OBJETO_TRIBUTARIO||'% PARTICIPACION: '||
				   RTRIM(TO_CHAR(PORCEN_PARTI))||xSALTO;

	  OBJETO_TRIBUTARIO:=OBJETO_TRIBUTARIO||'BASE IMPONIBLE: '||
				   RTRIM(TO_CHAR(BASE_IMPONIBLE))||' Euros '||xSALTO;

	  OBJETO_TRIBUTARIO:=OBJETO_TRIBUTARIO||'TIPO DE GRAVAMEN: '||
				   RTRIM(TO_CHAR(TIPO_GRAVAMEN,'0D999'))||xSALTO;

	  IF BONIFICACION IS NOT NULL THEN
	     OBJETO_TRIBUTARIO:=OBJETO_TRIBUTARIO||'IMPORTE BONIFICADO: '
                                ||TO_CHAR(BONIFICACION, '999G990D00')||XSALTO;
        END IF;
			
	  IF NOT (xEXENTOS='N' AND PRINCIPAL<=0) THEN   
           INSERT INTO PUNTEO
              (AYTO, PADRON, YEAR, PERIODO, RECIBO,
               NIF, NOMBRE, VOL_EJE, F_CARGO, N_CARGO, 
               INI_PE_VOL, FIN_PE_VOL, TIPO_DE_TRIBUTO, CUOTA_INICIAL, 
               PRINCIPAL, OBJETO_TRIBUTARIO, 
               ESTADO_BANCO, TIPO_DE_OBJETO, CLAVE_CONCEPTO, YEAR_CONTRAIDO, CLAVE_RECIBO)
           VALUES
              (xMUNICIPIO, xPADRON, xYEAR, xPERIODO, RECIBO, xNIF, xNOMBRE, 
               'V',xFECHA, xN_CARGO,
               INICIO_PERIODO_VOLUN, FIN_PERIODO_VOLUNTARIO,xTIPO_TRIBUTO,
               PRINCIPAL, PRINCIPAL, OBJETO_TRIBUTARIO,
               ESTADO_BANCO,'R', NUM_FIJO, xYEARCONTRAIDO, xID);
        END IF;

      END LOOP;
      CLOSE CRECRUS;

      -- Insertamos una tupla en LOGSPADRONES para controlar que esta acción ha sido ejecutada
      INSERT INTO LOGSPADRONES (MUNICIPIO,PROGRAMA,PYEAR,PERIODO,HECHO)
      VALUES (xMUNICIPIO,'RUSTICA',xYEAR,xPERIODO,'Se Pasa un padrón a Recaudación');
END;
/

/********************************************************************************
Acción: Configuración.
********************************************************************************/
CREATE OR REPLACE PROCEDURE RUS_CONF_RECIBOS(
       xMUNICIPIO   IN CHAR,
       xNUM 	  IN INTEGER
)
AS

BEGIN
  UPDATE DATOSPER SET RUSTICA_CONF_RECIBOS=xNUM
  WHERE MUNICIPIO=xMUNICIPIO;
END;
/

/********************************************************************************
Acción: Modificación del número de periodos.
********************************************************************************/

CREATE OR REPLACE PROCEDURE RUS_MOD_NUM_PERIODOS(
       xMUNICIPIO   IN CHAR,
       xNUM 	  IN INTEGER
)
AS

BEGIN
  UPDATE DATOSPER SET RUSTICA_NUM_PERIODOS=xNUM
  WHERE MUNICIPIO=xMUNICIPIO;
END;
/

-- ****************************************************************************************
-- Acción: PARA RECIBOS DOMICILIADOS Y NO DOMICILIADOS DE LA CAIXA.
-- MODIFICACIÓN: 14/09/2001 M. Carmen Junco Gómez. Adaptación al euro y eliminación 
-- 		  de una consulta innecesaria al tener los datos fiscales en 
-- 		  la tabla de recibos.
-- MODIFICACIÓN: 20/09/2001 M. Carmen Junco Gómez. Parcela, Polígono y Paraje ya no 
--               hay que escribirlos en el disco.
-- 		  Adaptación al Euro.
-- MODIFICACIÓN: 24/06/2002 M. Carmen Junco Gómez. Bonificaciones en los recibos.
-- MODIFICACIÓN: 30/09/2003 Lucas Fernández Pérez. Se cambia el texto "%bonificacion" por
--					"importe bonificado", porque pasa de ser un porcentaje a un importe.
-- MODIFICACIÓN: 13/01/2004 Gloria Mª Calle Hernández. Se cambia el formato del tipo de Gravamen
--					de 0D99 a 0D999, porque pasa a arrastrar 3 dígitos decimales.
-- ****************************************************************************************

CREATE OR REPLACE PROCEDURE Proc_Caixa_Rustica (
       xMUNICIPIO  IN CHAR,
       xYear 	 IN char, 
       xPeri 	 IN char) 
AS
	x2 				char(40);
	x3 				char(40);
	x4 				char(40);
	x5 				char(40);
	x6 				char(40);
	x7 				char(40);
	x8				char(40);
	i 				integer;
	xRegis 			integer;

	CURSOR CRECRUS IS
	   SELECT *  FROM RECIBOS_RUSTICA 
	   WHERE MUNICIPIO=xMUNICIPIO and year=xYear and periodo=xPeri and total>0;

BEGIN

	DELETE FROM RECIBOS_CAIXA WHERE USUARIO=USER;
	xRegis:=0;

	select count(*) into xRegis FROM recibos_rustica
	WHERE municipio=xMunicipio and year=xYear and periodo=xPeri and total>0;

	FOR v_TRustica IN CRECRUS LOOP

		i:=7;

		x2:='VALOR CATASTRAL: '||v_TRustica.VALOR_CATASTRAL;
		x3:='% PARTICIPACIÓN: '||v_TRustica.PORCEN_PARTICIPACION;
		x4:='BASE IMPONIBLE: '||v_TRustica.BASE_IMPONIBLE;
		x5:='TIPO GRAVAMEN: '||TO_CHAR(v_TRustica.TIPO_GRAVAMEN,'0D999');
		x6:='IMPORTE BONIFICADO: '||v_TRustica.BONIFICACION;
		x7:='SUPERFICIE: '||v_TRustica.SUPERFICIE;
		x8:='NUMERO FIJO: '||v_TRustica.NUM_FIJO;

		INSERT INTO RECIBOS_CAIXA
			(ABONADO,NIF,NOMBRE,DOMICILIO,CODPOSTAL,MUNICIPIO,
			ENTIDAD,SUCURSAL,DC,CUENTA,
			TOTAL, Campo2, Campo3, Campo4, Campo5, Campo6, Campo7, Campo8,
			CAMPOS_OPCIONALES, CUANTOS_REGISTROS)
		VALUES
			(v_TRustica.RECIBO, v_TRustica.Nif, v_TRustica.Nombre, 
                   substr(v_TRustica.Domicilio,1,40), v_TRustica.Codigo_Postal, 
                   v_TRustica.Poblacion, v_TRustica.Entidad, v_TRustica.Sucursal, 
                   v_TRustica.DC, v_TRustica.Cuenta, (v_TRustica.TOTAL*100), x2, 
                   x3, x4, x5, x6, x7, x8, i, xRegis); 
	END LOOP;
END;
/

-- ****************************************************************************************
-- Autor: M. Carmen Junco Gómez. 09/05/2002
-- Acción: PARA RECIBOS DOMICILIADOS Y NO DOMICILIADOS DE CAJA MADRID.
-- MODIFICACIÓN: 24/06/2002 M. Carmen Junco Gómez. Bonificación de los recibos
-- MODIFICACIÓN: 30/09/2003 Lucas Fernández Pérez. Se cambia el texto "%bonificacion" por
--					"importe bonificado", porque pasa de ser un porcentaje a un importe.
-- MODIFICACIÓN: 13/01/2004 Gloria Mª Calle Hernández. Se cambia el formato del tipo de Gravamen
--					de 0D99 a 0D999, porque pasa a arrastrar 3 dígitos decimales.
-- ****************************************************************************************

CREATE OR REPLACE PROCEDURE Proc_CajaMadrid_Rustica (
       xMUNICIPIO  IN CHAR,
       xYear 	 IN char, 
       xPeri 	 IN char) 
AS
	x1 			char(40);
	x2 			char(40);
	x3 			char(40);
	x4 			char(40);
	x5 			char(40);
	x6 			char(40);
      x7			char(40);
	i 			integer;
	xRegis 		integer;
	xPAIS			char(25);

	CURSOR CRECRUS IS
	   SELECT *  FROM RECIBOS_RUSTICA 
	   WHERE MUNICIPIO=xMUNICIPIO and year=xYear and periodo=xPeri and total>0;

BEGIN

	DELETE FROM RECIBOS_CAJAMADRID WHERE USUARIO=USER;
	xRegis:=0;

	select count(*) into xRegis FROM recibos_rustica
	WHERE municipio=xMunicipio and year=xYear and periodo=xPeri and total>0;

	FOR v_TRustica IN CRECRUS LOOP
		
		SELECT PAIS INTO xPAIS FROM RUS80 WHERE ID=v_TRustica.ABONADO;

		i:=7;

		x1:='';
		x2:='';
		x3:='';
		x4:='';
		x5:='';
		x6:='';
		x7:='';

		x1:='VALOR CATASTRAL: '||v_TRustica.VALOR_CATASTRAL;
		x2:='% PARTICIPACIÓN: '||v_TRustica.PORCEN_PARTICIPACION;
		x3:='BASE IMPONIBLE: '||v_TRustica.BASE_IMPONIBLE;
		x4:='TIPO GRAVAMEN: '||TO_CHAR(v_TRustica.TIPO_GRAVAMEN,'0D999');
		x5:='IMPORTE BONIFICADO:     '||TO_CHAR(v_TRustica.BONIFICACION,'999G990D00');
		x6:='SUPERFICIE: '||v_TRustica.SUPERFICIE;
		x7:='NUMERO FIJO: '||v_TRustica.NUM_FIJO;

		INSERT INTO RECIBOS_CAJAMADRID
			(ABONADO,NIF,NOMBRE,DOMICILIO,CODPOSTAL,POBLACION,PROVINCIA,PAIS,
			 REFERENCIA,DOMICILIADO,ENTIDAD,SUCURSAL,DC,CUENTA,
			 TOTAL, Campo1, Campo2, Campo3, Campo4, Campo5, Campo6, Campo7,
			 CAMPOS_OPCIONALES, CUANTOS_REGISTROS)
		VALUES
			(v_TRustica.RECIBO, v_TRustica.Nif, v_TRustica.Nombre, 
                   substr(v_TRustica.Domicilio,1,40), v_TRustica.Codigo_Postal, 
                   v_TRustica.Poblacion, v_TRustica.PROVINCIA,xPAIS,
			 DECODE(v_TRustica.DOMICILIADO,'S',v_TRustica.REFERENCIA||v_TRustica.DIGITO_CONTROL,
			        v_TRustica.REFERENCIA),	
			 DECODE(v_TRustica.DOMICILIADO,'S','D',' '),
		       v_TRustica.Entidad, v_TRustica.Sucursal,v_TRustica.DC, v_TRustica.Cuenta,
                  (v_TRustica.TOTAL*100),x1,x2,x3,x4,x5,x6,x7,i,xRegis); 
	END LOOP;
END;
/

/********************************************************************************
Acción: Recoge los datos de las parcelas.
********************************************************************************/

CREATE OR REPLACE PROCEDURE DAME_DATOS_PARCELAS
	(xID80			IN INTEGER,
	xVALOR_CATASTRAL1  	OUT FLOAT,
	xSUPERFICIE1		OUT FLOAT,
	xNUMERO_PARCELA1		OUT CHAR,
	xPARAJE1			OUT CHAR,
	xCOD_POLIGONO1		OUT CHAR,

	xVALOR_CATASTRAL2 	OUT FLOAT,		
	xSUPERFICIE2		OUT FLOAT,
	xNUMERO_PARCELA2		OUT CHAR,
	xPARAJE2			OUT CHAR,
	xCOD_POLIGONO2		OUT CHAR,

	xVALOR_CATASTRAL3 	OUT FLOAT,		
	xSUPERFICIE3		OUT FLOAT,
	xNUMERO_PARCELA3		OUT CHAR,
	xPARAJE3			OUT CHAR,
	xCOD_POLIGONO3		OUT CHAR,

	xVALOR_CATASTRAL4 	OUT FLOAT,		
	xSUPERFICIE4		OUT FLOAT,
	xNUMERO_PARCELA4		OUT CHAR,
	xPARAJE4			OUT CHAR,
	xCOD_POLIGONO4		OUT CHAR,

	xVALOR_CATASTRAL5 	OUT FLOAT,
	xSUPERFICIE5		OUT FLOAT,
	xNUMERO_PARCELA5		OUT CHAR,
	xPARAJE5			OUT CHAR,
	xCOD_POLIGONO5		OUT CHAR,

	xVALOR_CATASTRAL6 	OUT FLOAT,		
	xSUPERFICIE6		OUT FLOAT,
	xNUMERO_PARCELA6		OUT CHAR,
	xPARAJE6			OUT CHAR,
	xCOD_POLIGONO6		OUT CHAR,

	xVALOR_CATASTRAL7 	OUT FLOAT,
	xSUPERFICIE7		OUT FLOAT,
	xNUMERO_PARCELA7		OUT CHAR,
	xPARAJE7			OUT CHAR,
	xCOD_POLIGONO7		OUT CHAR,

	xVALOR_CATASTRAL8 	OUT FLOAT,		
	xSUPERFICIE8		OUT FLOAT,
	xNUMERO_PARCELA8		OUT CHAR,
	xPARAJE8			OUT CHAR,
	xCOD_POLIGONO8		OUT CHAR)

AS
Z	INTEGER;
CURSOR CPARCELAS IS 
	SELECT ID,COD_POLIGONO_CATASTRAL,NUMERO_PARCELA,PARAJE,SUPERFICIE,
		 VALOR_CATASTRAL 
	FROM RUS81 WHERE ABONADO=xID80;

BEGIN

	/* recogemos los datos de hasta 8 posibles parcelas */
	xVALOR_CATASTRAL1:=NULL;
	xSUPERFICIE1:=NULL;
	xNUMERO_PARCELA1:=NULL;
	xPARAJE1:=NULL;
	xCOD_POLIGONO1:=NULL;
	xVALOR_CATASTRAL2:=NULL;
	xSUPERFICIE2:=NULL;
	xNUMERO_PARCELA2:=NULL;
	xPARAJE2:=NULL;
	xCOD_POLIGONO2:=NULL;
	xVALOR_CATASTRAL3:=NULL;
	xSUPERFICIE3:=NULL;
	xNUMERO_PARCELA3:=NULL;
	xPARAJE3:=NULL;
	xCOD_POLIGONO3:=NULL;
	xVALOR_CATASTRAL4:=NULL;
	xSUPERFICIE4:=NULL;
	xNUMERO_PARCELA4:=NULL;
	xPARAJE4:=NULL;
	xCOD_POLIGONO4:=NULL;
	xVALOR_CATASTRAL5:=NULL;
	xSUPERFICIE5:=NULL;
	xNUMERO_PARCELA5:=NULL;
	xPARAJE5:=NULL;
	xCOD_POLIGONO5:=NULL;
	xVALOR_CATASTRAL6:=NULL;
	xSUPERFICIE6:=NULL;
	xNUMERO_PARCELA6:=NULL;
	xPARAJE6:=NULL;
	xCOD_POLIGONO6:=NULL;
	xVALOR_CATASTRAL7:=NULL;
	xSUPERFICIE7:=NULL;
	xNUMERO_PARCELA7:=NULL;
	xPARAJE7:=NULL;
	xCOD_POLIGONO7:=NULL;
	xVALOR_CATASTRAL8:=NULL;
	xSUPERFICIE8:=NULL;
	xNUMERO_PARCELA8:=NULL;
	xPARAJE8:=NULL;
	xCOD_POLIGONO8:=NULL;

	Z:=1;

	FOR v_parcelas IN CPARCELAS
	LOOP
 	   IF (Z=1) THEN
		xVALOR_CATASTRAL1:=v_parcelas.VALOR_CATASTRAL;	
		xSUPERFICIE1:=v_parcelas.SUPERFICIE;
		xNUMERO_PARCELA1:=v_parcelas.NUMERO_PARCELA;
		xPARAJE1:=v_parcelas.PARAJE;
		xCOD_POLIGONO1:=v_parcelas.COD_POLIGONO_CATASTRAL;
	   ELSIF (Z=2) THEN
		xVALOR_CATASTRAL2:=v_parcelas.VALOR_CATASTRAL;	
		xSUPERFICIE2:=v_parcelas.SUPERFICIE;
		xNUMERO_PARCELA2:=v_parcelas.NUMERO_PARCELA;
		xPARAJE2:=v_parcelas.PARAJE;
		xCOD_POLIGONO2:=v_parcelas.COD_POLIGONO_CATASTRAL;
	   ELSIF (Z=3) THEN
		xVALOR_CATASTRAL3:=v_parcelas.VALOR_CATASTRAL;	
		xSUPERFICIE3:=v_parcelas.SUPERFICIE;
		xNUMERO_PARCELA3:=v_parcelas.NUMERO_PARCELA;
		xPARAJE3:=v_parcelas.PARAJE;
		xCOD_POLIGONO3:=v_parcelas.COD_POLIGONO_CATASTRAL;
	   ELSIF (Z=4) THEN
		xVALOR_CATASTRAL4:=v_parcelas.VALOR_CATASTRAL;	
		xSUPERFICIE4:=v_parcelas.SUPERFICIE;
		xNUMERO_PARCELA4:=v_parcelas.NUMERO_PARCELA;
		xPARAJE4:=v_parcelas.PARAJE;
		xCOD_POLIGONO4:=v_parcelas.COD_POLIGONO_CATASTRAL;
	   ELSIF (Z=5) THEN
		xVALOR_CATASTRAL5:=v_parcelas.VALOR_CATASTRAL;	
		xSUPERFICIE5:=v_parcelas.SUPERFICIE;
		xNUMERO_PARCELA5:=v_parcelas.NUMERO_PARCELA;
		xPARAJE5:=v_parcelas.PARAJE;
		xCOD_POLIGONO5:=v_parcelas.COD_POLIGONO_CATASTRAL;
	   ELSIF (Z=6) THEN
		xVALOR_CATASTRAL6:=v_parcelas.VALOR_CATASTRAL;	
		xSUPERFICIE6:=v_parcelas.SUPERFICIE;
		xNUMERO_PARCELA6:=v_parcelas.NUMERO_PARCELA;
		xPARAJE6:=v_parcelas.PARAJE;
		xCOD_POLIGONO6:=v_parcelas.COD_POLIGONO_CATASTRAL;
	   ELSIF (Z=7) THEN
		xVALOR_CATASTRAL7:=v_parcelas.VALOR_CATASTRAL;	
		xSUPERFICIE7:=v_parcelas.SUPERFICIE;
		xNUMERO_PARCELA7:=v_parcelas.NUMERO_PARCELA;
		xPARAJE7:=v_parcelas.PARAJE;
		xCOD_POLIGONO7:=v_parcelas.COD_POLIGONO_CATASTRAL;
	   ELSIF (Z=8) THEN
		xVALOR_CATASTRAL8:=v_parcelas.VALOR_CATASTRAL;	
		xSUPERFICIE8:=v_parcelas.SUPERFICIE;
		xNUMERO_PARCELA8:=v_parcelas.NUMERO_PARCELA;
		xPARAJE8:=v_parcelas.PARAJE;
		xCOD_POLIGONO8:=v_parcelas.COD_POLIGONO_CATASTRAL;
	   ELSE
		EXIT;
	   END IF;

	   Z:=Z+1;

	END LOOP;
END;
/

/********************************************************************************
Acción: Inserta datos en tabla temporal para la impresión de los recibos.
Autor: Agustin Leon Robles.
Fecha: 23/08/2001
MODIFICACIÓN: 14/09/2001 M. Carmen Junco Gómez. Adaptación al euro.
MODIFICACIÓN: 24/06/2002 M. Carmen Junco Gómez. Bonificación en los recibos.
MODIFICACION: 31/05/2004 Gloria Maria Calle Hernandez. Añadido campo AYTO a la tabla 
			  Datos_Ordenante para generar ficheros por ayuntamientos (xej. Catoure).
			  Sólo cuando se trata de una diputación se almacena el campo Ayto vacio (en principio).
********************************************************************************/

CREATE OR REPLACE PROCEDURE WriteTempRustica
		(v_RegistroRus 	IN Recibos_Rustica%ROWTYPE,
		xMUNICIPIO		IN CHAR,
		xYEAR			IN CHAR,
		xPERI			IN CHAR)
AS
	xNOMBRE_ENTIDAD 	CHAR(50);
	xHASTA1         	DATE;

	xVALOR_CATASTRAL1  FLOAT;		
	xSUPERFICIE1	FLOAT;
	xNUMERO_PARCELA1	CHAR(5);
	xPARAJE1		CHAR(20);
	xCOD_POLIGONO1	CHAR(3);		

	xVALOR_CATASTRAL2 FLOAT;		
	xSUPERFICIE2	FLOAT;
	xNUMERO_PARCELA2	CHAR(5);
	xPARAJE2		CHAR(20);
	xCOD_POLIGONO2	CHAR(3);

	xVALOR_CATASTRAL3 FLOAT;		
	xSUPERFICIE3	FLOAT;
	xNUMERO_PARCELA3	CHAR(5);
	xPARAJE3		CHAR(20);
	xCOD_POLIGONO3	CHAR(3);

	xVALOR_CATASTRAL4 FLOAT;		
	xSUPERFICIE4	FLOAT;
	xNUMERO_PARCELA4	CHAR(5);
	xPARAJE4		CHAR(20);
	xCOD_POLIGONO4	CHAR(3);

	xVALOR_CATASTRAL5 FLOAT;		
	xSUPERFICIE5	FLOAT;
	xNUMERO_PARCELA5	CHAR(5);
	xPARAJE5		CHAR(20);
	xCOD_POLIGONO5	CHAR(3);

	xVALOR_CATASTRAL6 FLOAT;		
	xSUPERFICIE6	FLOAT;
	xNUMERO_PARCELA6	CHAR(5);
	xPARAJE6		CHAR(20);
	xCOD_POLIGONO6	CHAR(3);

	xVALOR_CATASTRAL7 FLOAT;		
	xSUPERFICIE7	FLOAT;
	xNUMERO_PARCELA7	CHAR(5);
	xPARAJE7		CHAR(20);
	xCOD_POLIGONO7	CHAR(3);

	xVALOR_CATASTRAL8 FLOAT;		
	xSUPERFICIE8	FLOAT;
	xNUMERO_PARCELA8	CHAR(5);
	xPARAJE8		CHAR(20);
	xCOD_POLIGONO8	CHAR(3);
	
	xDMUNICIPIO       VARCHAR2(50);
	xCODCONCEPTO      CHAR(6);

     	xNOMBREORD VARCHAR2(40);
	xNIFORD    CHAR(10);
	xTIPOENT			 	 CHAR(1);
BEGIN

	-- recogemos los datos del ordenante (nombre y nif)
      begin
           SELECT TIPO_ENTIDAD INTO xTipoEnt FROM CONFIGURACION C, MUNICIPIOS M 
            WHERE C.ZONA=M.ZONA AND AYTO=xMUNICIPIO;
           IF xTIPOENT='S' THEN
              SELECT NIF,NOMBRE INTO xNIFORD,xNOMBREORD FROM DATOS_ORDENANTE WHERE AYTO IS NULL;
           ELSE 
              SELECT NIF,NOMBRE INTO xNIFORD,xNOMBREORD FROM DATOS_ORDENANTE WHERE AYTO=xMUNICIPIO;
           END IF;
      Exception
	      When no_data_found then
	         xNIFORD:=NULL;
               xNOMBREORD:=NULL;
      end;

	-- recogemos la descripción del municipio
	SELECT EMPRESA INTO xDMUNICIPIO FROM DATOSPER WHERE MUNICIPIO=xMUNICIPIO;

	-- recogemos el código del concepto
	SELECT CONCEPTO INTO xCODCONCEPTO FROM PROGRAMAS WHERE PROGRAMA='RUSTICA';


	DAME_DATOS_PARCELAS(v_RegistroRus.ABONADO,
		xVALOR_CATASTRAL1,xSUPERFICIE1,xNUMERO_PARCELA1,xPARAJE1,xCOD_POLIGONO1,
		xVALOR_CATASTRAL2,xSUPERFICIE2,xNUMERO_PARCELA2,xPARAJE2,xCOD_POLIGONO2,
		xVALOR_CATASTRAL3,xSUPERFICIE3,xNUMERO_PARCELA3,xPARAJE3,xCOD_POLIGONO3,
		xVALOR_CATASTRAL4,xSUPERFICIE4,xNUMERO_PARCELA4,xPARAJE4,xCOD_POLIGONO4,
		xVALOR_CATASTRAL5,xSUPERFICIE5,xNUMERO_PARCELA5,xPARAJE5,xCOD_POLIGONO5,
		xVALOR_CATASTRAL6,xSUPERFICIE6,xNUMERO_PARCELA6,xPARAJE6,xCOD_POLIGONO6,
		xVALOR_CATASTRAL7,xSUPERFICIE7,xNUMERO_PARCELA7,xPARAJE7,xCOD_POLIGONO7,
		xVALOR_CATASTRAL8,xSUPERFICIE8,xNUMERO_PARCELA8,xPARAJE8,xCOD_POLIGONO8);
	
      --En caso de estar domiciliado, nombre de la Entidad
      xNOMBRE_ENTIDAD:='';
	begin
	   SELECT NOMBRE INTO xNOMBRE_ENTIDAD FROM ENTIDADES WHERE CODIGO=v_RegistroRus.ENTIDAD;
	EXCEPTION
	   WHEN NO_DATA_FOUND THEN
	      NULL;
	end;

	xHASTA1:=v_RegistroRus.HASTA+1; --fecha del hasta mas un día          

	INSERT INTO IMP_RECIBOS_RUS 
	   	(USUARIO,MUNI,DMUNICIPIO,CODCONCEPTO,xAnio,xPeriodo,xAbonado,xNif,xNombre,xDomiFiscal,xCodPostal,xPoblacion,
		 xProvincia,xTotal,xNUM_FIJO,xTIPO_GRAVAMEN,xBONIFICACION,
		 xVALOR_CATASTRAL,xPORCEN_PARTI,xBASE_IMPONIBLE,xSUPERFICIE,
		 xVALOR_CATASTRAL1,xSUPERFICIE1,xNUMERO_PARCELA1,xPARAJE1,xCOD_POLIGONO1,
		 xVALOR_CATASTRAL2,xSUPERFICIE2,xNUMERO_PARCELA2,xPARAJE2,xCOD_POLIGONO2,
		 xVALOR_CATASTRAL3,xSUPERFICIE3,xNUMERO_PARCELA3,xPARAJE3,xCOD_POLIGONO3,
		 xVALOR_CATASTRAL4,xSUPERFICIE4,xNUMERO_PARCELA4,xPARAJE4,xCOD_POLIGONO4,
		 xVALOR_CATASTRAL5,xSUPERFICIE5,xNUMERO_PARCELA5,xPARAJE5,xCOD_POLIGONO5,
		 xVALOR_CATASTRAL6,xSUPERFICIE6,xNUMERO_PARCELA6,xPARAJE6,xCOD_POLIGONO6,
		 xVALOR_CATASTRAL7,xSUPERFICIE7,xNUMERO_PARCELA7,xPARAJE7,xCOD_POLIGONO7,
		 xVALOR_CATASTRAL8,xSUPERFICIE8,xNUMERO_PARCELA8,xPARAJE8,xCOD_POLIGONO8,
		 xRefe,xDC,xTRIBUTO,xEJERCICIO,xREMESA,xIMPO,xEMISOR,xDesde,
		 xHasta,xCargo,xHasta1,xENTIDAD,xSUCURSAL,xDCCUENTA,xCUENTA,xTITULAR,
		 xNOMBRE_ENTIDAD,xNOMBRE_TITULAR,xCONCEPTO,
		 DISCRI_PERIODO,DIGITO_YEAR,F_JULIANA,DIGITO_C60_MODALIDAD2,
		 COD_BARRAS_MOD1,COD_BARRAS_MOD2,xNIFORDENANTE,xNOMBREORDENANTE)
      VALUES
	   	(UID,xMUNICIPIO,xDMUNICIPIO,xCODCONCEPTO,xYear,xPeri,v_RegistroRus.RECIBO,v_RegistroRus.Nif,
		 v_RegistroRus.Nombre,
		 v_RegistroRus.Domicilio,v_RegistroRus.Codigo_Postal,v_RegistroRus.Poblacion,
		 v_RegistroRus.Provincia,v_RegistroRus.Total,v_RegistroRus.NUM_FIJO,
		 v_RegistroRus.TIPO_GRAVAMEN,v_RegistroRus.BONIFICACION,
		 v_RegistroRus.VALOR_CATASTRAL,v_RegistroRus.PORCEN_PARTICIPACION,
		 v_RegistroRus.BASE_IMPONIBLE,v_RegistroRus.SUPERFICIE,
		 xVALOR_CATASTRAL1,xSUPERFICIE1,xNUMERO_PARCELA1,xPARAJE1,xCOD_POLIGONO1,
		 xVALOR_CATASTRAL2,xSUPERFICIE2,xNUMERO_PARCELA2,xPARAJE2,xCOD_POLIGONO2,
		 xVALOR_CATASTRAL3,xSUPERFICIE3,xNUMERO_PARCELA3,xPARAJE3,xCOD_POLIGONO3,
		 xVALOR_CATASTRAL4,xSUPERFICIE4,xNUMERO_PARCELA4,xPARAJE4,xCOD_POLIGONO4,
		 xVALOR_CATASTRAL5,xSUPERFICIE5,xNUMERO_PARCELA5,xPARAJE5,xCOD_POLIGONO5,
		 xVALOR_CATASTRAL6,xSUPERFICIE6,xNUMERO_PARCELA6,xPARAJE6,xCOD_POLIGONO6,
		 xVALOR_CATASTRAL7,xSUPERFICIE7,xNUMERO_PARCELA7,xPARAJE7,xCOD_POLIGONO7,
		 xVALOR_CATASTRAL8,xSUPERFICIE8,xNUMERO_PARCELA8,xPARAJE8,xCOD_POLIGONO8,

		 v_RegistroRus.REFERENCIA,v_RegistroRus.DIGITO_CONTROL,v_RegistroRus.TRIBUTO,
		 v_RegistroRus.EJERCICIO,v_RegistroRus.REMESA,v_RegistroRus.IMPORTE,
		 v_RegistroRus.EMISOR,v_RegistroRus.Desde,v_RegistroRus.Hasta,
		 v_RegistroRus.F_Cargo,xHasta1,v_RegistroRus.ENTIDAD,v_RegistroRus.SUCURSAL,
		 v_RegistroRus.DC,v_RegistroRus.CUENTA,v_RegistroRus.TITULAR,
		 xNOMBRE_ENTIDAD,v_RegistroRus.NOMBRE_TITULAR,v_RegistroRus.CONCEPTO,
		 v_RegistroRus.DISCRI_PERIODO,v_RegistroRus.DIGITO_YEAR,v_RegistroRus.F_JULIANA,
		 v_RegistroRus.DIGITO_C60_MODALIDAD2,

		 '90502'||v_RegistroRus.EMISOR||v_RegistroRus.REFERENCIA||
		 v_RegistroRus.DIGITO_CONTROL||
		 v_RegistroRus.TRIBUTO||v_RegistroRus.EJERCICIO||v_RegistroRus.REMESA||
		 LPAD(v_RegistroRus.IMPORTE*100,8,'0'),

		 '90521'||v_RegistroRus.EMISOR||v_RegistroRus.REFERENCIA||
		 v_RegistroRus.DIGITO_C60_MODALIDAD2||v_RegistroRus.DISCRI_PERIODO||
		 v_RegistroRus.TRIBUTO||v_RegistroRus.EJERCICIO||v_RegistroRus.DIGITO_YEAR||
		 v_RegistroRus.F_JULIANA||LPAD(v_RegistroRus.IMPORTE*100,8,'0')||'0',
		 xNIFORD,xNOMBREORD);
END;
/

/********************************************************************************
Acción: Impresión de recibos de rústica.
MODIFICACIÓN: 23/08/2001 Agustin Leon Robles.
MODIFICACIÓN: 05/09/2005 Gloria Mª Calle Hernandez. Añadido impresión ordenada por
		  codigo postal y domicilio fiscal.
********************************************************************************/

CREATE OR REPLACE PROCEDURE Imprime_Recibos_Rus (
		xMUNICIPIO 	IN CHAR,
		xID        	IN INTEGER,
		xYear      	IN CHAR, 
		xPeri      	IN CHAR, 
		xDomi      	IN CHAR,
		xReciDesde 	IN INTEGER,
		xReciHasta 	IN INTEGER,
		xOrden	IN CHAR)
AS

I INTEGER;

CURSOR CRecibosAlfabetico IS
	SELECT * FROM RECIBOS_RUSTICA
	WHERE MUNICIPIO=xMUNICIPIO and year=xYear and periodo=xPeri	and domiciliado=xDomi
	ORDER BY NOMBRE,RECIBO;

CURSOR CRecibosCallejero IS
	SELECT * FROM RECIBOS_RUSTICA
	WHERE MUNICIPIO=xMUNICIPIO and year=xYear and periodo=xPeri	and domiciliado=xDomi
	ORDER BY DOMICILIO,RECIBO;

CURSOR CRecibosCPDomi IS
	SELECT * FROM RECIBOS_RUSTICA
	WHERE MUNICIPIO=xMUNICIPIO and year=xYear and periodo=xPeri	and domiciliado=xDomi
	ORDER BY CODIGO_POSTAL,DOMICILIO;

v_RegistroRus      Recibos_Rustica%ROWTYPE;

BEGIN

   I:=0;

   DELETE FROM IMP_RECIBOS_RUS WHERE USUARIO=UID;

   IF (xID<>0 ) then 
		SELECT * INTO v_RegistroRus FROM RECIBOS_RUSTICA WHERE ID=xID;
		WriteTempRustica(v_RegistroRus,xMUNICIPIO,xYear,xPeri);

   ELSE /*DEL IF (xID<>0 ) */

	--imprimir en orden alfabetico
	if xOrden='A' then
		OPEN CRecibosAlfabetico;
		LOOP 
		   FETCH CRecibosAlfabetico INTO v_RegistroRus;
		   EXIT WHEN CRecibosAlfabetico%NOTFOUND;
	
  		   I:=I+1;				

		   IF (I >= xReciDesde and I <= xReciHasta) then

			IF v_RegistroRus.TOTAL>0 THEN
			 	WriteTempRustica(v_RegistroRus,xMUNICIPIO,xYear,xPeri);				
			END IF;

		   ELSE
		      IF (I > xRECIHASTA) THEN
      		   EXIT;
			END IF;
  		   END IF;	

		END LOOP;
		CLOSE CRecibosAlfabetico;

	--imprimir en orden codigopostal y domicilio fiscal
	elsif xOrden='D' then
		OPEN CRecibosCPDomi;
		LOOP 
		   FETCH CRecibosCPDomi INTO v_RegistroRus;
		   EXIT WHEN CRecibosCPDomi%NOTFOUND;
	
  		   I:=I+1;				

		   IF (I >= xReciDesde and I <= xReciHasta) then

			IF v_RegistroRus.TOTAL>0 THEN
			 	WriteTempRustica(v_RegistroRus,xMUNICIPIO,xYear,xPeri);				
			END IF;

		   ELSE
		      IF (I > xRECIHASTA) THEN
      		   EXIT;
			END IF;
  		   END IF;	

		END LOOP;
		CLOSE CRecibosCPDomi;

	ELSE /*if xOrden='A' then*/
		--orden callejero	
		OPEN CRecibosCallejero;
		LOOP 
		   FETCH CRecibosCallejero INTO v_RegistroRus;
		   EXIT WHEN CRecibosCallejero%NOTFOUND;
	
  		   I:=I+1;				

		   IF (I >= xReciDesde and I <= xReciHasta) then
		 	IF v_RegistroRus.TOTAL>0 THEN
			 	WriteTempRustica(v_RegistroRus,xMUNICIPIO,xYear,xPeri);				
			END IF;
		   ELSE
		      IF (I > xRECIHASTA) THEN
      		   EXIT;
			END IF;
  		   END IF;	

		END LOOP;
		CLOSE CRecibosCallejero;

	end if; /*DEL if xOrden='A' then*/

END IF; /*DEL IF (xID<>0 ) */

END;
/
/*******************************************************************************
Autor: 21/06/2002 Mª del Carmen Junco Gómez.
Acción: Añade un nuevo tipo de bonificación o exención a la lista existente según municipio. 
*******************************************************************************/

CREATE OR REPLACE PROCEDURE RUS_ADD_BONI (
       xMUNICIPIO   IN CHAR,
       xTIPO 	  IN CHAR,
       xBONI 	  IN FLOAT,
       xARTICULO 	  IN CHAR,
       xDESC 	  IN CHAR
)
AS
BEGIN
   INSERT INTO BONI_EXEN_RUS (MUNICIPIO,TIPO,BONIFICACION,ARTICULO,DESCRIPCION)
   VALUES (xMUNICIPIO, xTIPO, xBONI, xARTICULO, xDESC);
END;
/

/*******************************************************************************
Autor: 21/06/2002 Mª del Carmen Junco Gómez.
Acción: Modifica los datos de una bonificación o exención de la lista de bonificaciones.
*******************************************************************************/

CREATE OR REPLACE PROCEDURE RUS_MODIF_BONI(
       xID 		IN INTEGER,
       xTIPO 	IN CHAR,
       xBONI 	IN FLOAT,
       xARTICULO  IN CHAR,
       xDESC 	IN CHAR
)
AS

BEGIN
   UPDATE BONI_EXEN_RUS SET TIPO=xTIPO, 
				    BONIFICACION=xBONI,
                            ARTICULO=xARTICULO,
                            DESCRIPCION=xDESC
   WHERE ID=xID;
END;
/

/*******************************************************************************
Autor: 24/06/2002 Mª Carmen Junco Gómez. 
Acción: Modifica la bonificación de un registro de rústica identificado por ID=xID.
MODIFICADO: 30/03/2005. Gloria Maria Calle Hernandez. Anula la domiciliacion también.
MODIFICADO: 31/05/2005. Lucas Fernández Pérez. 
  Desaparecen los parámetros xMes,xYear,xMesIni y xYearIni porque lo que bonifica
  es ahora en rus81, no en rus80. Desaparecen de rus80 los datos de la bonificación,
  puesto que ahora es en rus81 (campos valor_catastral_boni y clave_boni) donde están.
*******************************************************************************/

CREATE OR REPLACE PROCEDURE RUS_BONIFI(
       xID 			IN INTEGER,
       xMODO        IN INTEGER,
       xBONI 		IN FLOAT,
       xARTICULO  	IN CHAR)
AS
BEGIN
   IF (xARTICULO IS NOT NULL) THEN -- Se graba la bonificación
   
     if xMODO=0 then -- Sólo bonifica una parcela
       
       UPDATE RUS81 SET 
         VALOR_CATASTRAL_BONI=ROUND(VALOR_CATASTRAL*(xBONI/100),2), CLAVE_BONI=xARTICULO
       WHERE ID=xID;
       
     elsif xMODO=1 then -- Bonifica todas las parcelas de la finca

       UPDATE RUS81 SET 
         VALOR_CATASTRAL_BONI=ROUND(VALOR_CATASTRAL*(xBONI/100),2), CLAVE_BONI=xARTICULO
       WHERE ABONADO= (SELECT ABONADO FROM RUS81 WHERE ID=xID);
       
     end if;

      
   ELSE -- Se anula la bonificación
   
     if xMODO=0 then -- Sólo anula una parcela
       
       UPDATE RUS81 SET 
         VALOR_CATASTRAL_BONI=0, CLAVE_BONI=NULL
       WHERE ID=xID;
       
     elsif xMODO=1 then -- Anula todas las parcelas de la finca

       UPDATE RUS81 SET 
         VALOR_CATASTRAL_BONI=0, CLAVE_BONI=NULL
       WHERE ABONADO= (SELECT ABONADO FROM RUS81 WHERE ID=xID);
       
     end if;
     
   END IF;
   
END;
/

/********************************************************************/
COMMIT;
/********************************************************************/
