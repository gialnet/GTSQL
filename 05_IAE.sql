/********************************************************************************
Autor: Agustin Leon Robles
Fecha: 22/08/2001.
Acción:Añadir o eliminar un representante a un abonado
Mofificado: 12/06/2006. Nuevo parámetro con el motivo por el que cambia el 
	representante, que se graba en usuariosgt y lo recoge el trigger T_UPDATE_IAE
********************************************************************************/

CREATE OR REPLACE PROCEDURE ADDDEL_IAE_REPRESENTANTE
		(xID 		IN 	integer,
		 xNIF		IN	char,
		 xMotivo IN varchar,
		 xAddDel	IN	char)
AS
BEGIN

	UPDATE USUARIOSGT SET TEXTO=xMotivo WHERE USUARIO=USER;
	
	if xAddDel='A' then
		update IAE set representante=xNIF where id=xID;
	else
		update IAE set representante=NULL,IDDOMIALTER=NULL where id=xID;
	end if;
	
END;
/


/********************************************************************************
Autor: Agustin Leon Robles
Fecha: 22/08/2001.
Acción:Añade o modifica la categoría de una calle.
MODIFICACIÓN: 30/09/2002 M. Carmen Junco Gómez. Se añade el año para guardar las
		  categorías de las calles por años.
DELPHI
********************************************************************************/

CREATE OR REPLACE PROCEDURE ADD_MOD_CALLE_IAE(
               xMUNICIPIO IN CHAR,
 		           xYEAR	  IN CHAR,
               xID        IN INTEGER,
               xCODIGO    IN CHAR,
               xCATEGORIA IN CHAR,
               xDESDE     IN INTEGER,
               xHASTA     IN INTEGER,
               xAMBITO    IN CHAR,
               xRESULT    OUT INTEGER)
AS
BEGIN

	-- Comprobamos que el intervalo a introducir no se solape con otro ya existente
	SELECT count(*) INTO xRESULT
	FROM CALLES_IAE
	WHERE MUNICIPIO=xMUNICIPIO AND YEAR=xYEAR AND CODIGO=xCODIGO AND
		xDESDE <= HASTA
		AND AMBITO=xAMBITO
		AND ID<>xID;

	-- no se solapa o no existe ningún otro intervalo
	IF (xRESULT=0) THEN
		IF (xID<>0) THEN
			UPDATE CALLES_IAE SET
					CATEGORIA=xCATEGORIA,
					DESDE=xDESDE,
					HASTA=xHASTA,
					AMBITO=xAMBITO
			WHERE ID=xID;
		ELSE
			INSERT INTO CALLES_IAE
				(MUNICIPIO, YEAR, CODIGO, CATEGORIA, DESDE, HASTA, AMBITO)
			VALUES(xMUNICIPIO, xYEAR, xCODIGO, xCATEGORIA,xDESDE, xHASTA, xAMBITO);
		END IF;
	END IF;

END;
/

/********************************************************************************
Autor:  Mª del Carmen Junco Gómez
Fecha:  30/09/2002.
Acción: Copia las categorías definidas de un año a otro.
DELPHI
********************************************************************************/

CREATE OR REPLACE PROCEDURE COPIA_CALLES_IAE(
               xMUNICIPIO   IN CHAR,
		   xYEAR	    IN CHAR,
		   xYEARDESTINO IN CHAR)

AS
BEGIN
	-- borramos las categoría que pueda haber definidas para el año destino
	DELETE FROM CALLES_IAE WHERE MUNICIPIO=xMUNICIPIO AND YEAR=xYEARDESTINO;

	-- copiamos las categorías desde el año xYear al año destino
	INSERT INTO CALLES_IAE (MUNICIPIO,YEAR,CODIGO,DESDE,HASTA,CATEGORIA,AMBITO)
	SELECT MUNICIPIO,xYEARDESTINO,CODIGO,DESDE,HASTA,CATEGORIA,AMBITO
	FROM CALLES_IAE WHERE MUNICIPIO=xMUNICIPIO AND YEAR=xYEAR;
END;
/

/********************************************************************************
Acción: Corrección de las calles del fichero que se ha leído para emparejarlo con
        la base de datos de calles del municipio que se pasa como parámetro.
Modificado: 25/10/2005. Gloria Maria Calle Hernandez. Añadido campo a la tabla de 
	IAE para saber que calles son corregisdas cuando vienen mal en disco y poder 
	recorregirlas. Desde este procedimiento es cambiado dicho campo.
********************************************************************************/

CREATE OR REPLACE PROCEDURE AJUSTA_CALLE_IAE(
               xMUNICIPIO IN CHAR,
               xALL       IN CHAR,
               xID        IN INTEGER,
               xOLD_CALLE IN CHAR,
               xNEW_VIA   IN CHAR,
               xNEW_CALLE IN CHAR,
               xNEW_COD   IN CHAR)
AS
    xYEAR CHAR(4);
    xPERIODO CHAR(2);
BEGIN

  SELECT YEAR,PERIODO INTO xYEAR,xPERIODO
  FROM IAE WHERE ID=xID;

  -- Si la calle viene vacía y queremos corregir todas estas ocurrencias
  IF xOLD_CALLE='NO' AND xALL='S' THEN
      UPDATE IAE SET CODIGO_VIA=xNEW_COD,CALLE_ACTIVIDAD=xNEW_CALLE,VIA_ACTIVIDAD=xNEW_VIA,
      				 MODIFICADO_CODVIA='S'
      WHERE MUNICIPIO=xMUNICIPIO AND YEAR=xYEAR AND PERIODO=xPERIODO
			AND (rtrim(CALLE_ACTIVIDAD) is null or CALLE_ACTIVIDAD='');
	RETURN;
  END IF;

  -- se corrigen todas las ocurrencias del nombre de calle xOLD_CALLE
  IF xALL='S' THEN
      UPDATE IAE SET CODIGO_VIA=xNEW_COD,CALLE_ACTIVIDAD=xNEW_CALLE,VIA_ACTIVIDAD=xNEW_VIA,
      				 MODIFICADO_CODVIA='S'
      WHERE MUNICIPIO=xMUNICIPIO AND YEAR=xYEAR AND PERIODO=xPERIODO
			AND rtrim(CALLE_ACTIVIDAD)=rtrim(xOLD_CALLE);

  ELSE
      UPDATE IAE SET CODIGO_VIA=xNEW_COD,CALLE_ACTIVIDAD=xNEW_CALLE,VIA_ACTIVIDAD=xNEW_VIA,
      				 MODIFICADO_CODVIA='S'
      WHERE ID=xID;
  END IF;
END;
/


/********************************************************************************
Acción: Cuando se genera el padrón se comprueba si el índice de calles está activo
        para el municipio dado, y si es así se recogen el índice de situación,
        el coeficiente de incremento y el recargo especificados en la configuración
        de cuotas.
MODIFICACIÓN: 30/09/2002 Mª Carmen Junco Gómez. Se incluye el Año en las cuotas y las
		  categorías para poder liquidar años anteriores.
********************************************************************************/

CREATE OR REPLACE PROCEDURE CALCULA_INDICE_CALLE(
               xMUNICIPIO  IN CHAR,
		   	   xYEAR	   IN CHAR,
               xCODIGO_VIA IN CHAR,
               xNUMERO     IN CHAR,
               xINDICE     OUT FLOAT,
               xCUOTA      OUT FLOAT,
               xRECARGO    OUT FLOAT)
AS
     xAMBITO     CHAR(1);
     xCATEGORIA  CHAR(1);
     xTEMP       INTEGER;
     xIND1       FLOAT;
     xIND2       FLOAT;
     xIND3       FLOAT;
     xIND4       FLOAT;
     xIND5       FLOAT;
     xIND6       FLOAT;
     xIND7       FLOAT;
     xIND8       FLOAT;
     xIND9       FLOAT;
     xIND10      FLOAT;
     xAUX        CHAR(1);
     xNUM        INTEGER;
     xContador   integer;
BEGIN

   --comprobamos si el índice está activo para el municipio
   SELECT IAE_CALLES_INDICE INTO xAUX FROM DATOSPER WHERE MUNICIPIO=xMUNICIPIO;

   --se recoge la cuota,recargo y los índices según categoría
   begin
      SELECT CUOTA,RECARGO,IN_1,IN_2,IN_3,IN_4,IN_5,IN_6,IN_7,IN_8,IN_9,IN_10
		INTO xCUOTA, xRECARGO, xIND1, xIND2, xIND3,xIND4, xIND5, xIND6, xIND7,
		xIND8, xIND9, xIND10
      FROM CUOTAS_IAE WHERE MUNICIPIO=xMUNICIPIO AND YEAR=xYEAR;
   Exception
	When no_data_found then
	   xAUX:='N';
   end;

   IF xAUX='S' THEN
      xNUM:=to_number(xNumero);

      xTEMP:=MOD(xNUM, 2); --comprobamos si el número de calles es par o impar
      IF (xTEMP=0) THEN
         xAMBITO:='P';
      ELSE
         xAMBITO:='I';
      END IF;

      SELECT count(CATEGORIA) INTO xContador
      FROM CALLES_IAE WHERE MUNICIPIO=xMUNICIPIO AND YEAR=xYEAR AND CODIGO=xCODIGO_VIA
           AND AMBITO=xAMBITO AND ((DESDE<=xNUM) AND (xNUM<=HASTA));

      IF (xContador=0) THEN  --en el ámbito par o impar no posee categoría
		SELECT count(CATEGORIA) INTO xContador
		FROM CALLES_IAE
		WHERE MUNICIPIO=xMUNICIPIO AND YEAR=xYEAR AND CODIGO=xCODIGO_VIA AND AMBITO='T'
                   AND ((DESDE<=xNUM) AND (xNUM<=HASTA));
		xAMBITO:='T';
      END IF;

      if xContador>0 then
         SELECT CATEGORIA INTO xCategoria FROM CALLES_IAE
         WHERE MUNICIPIO=xMUNICIPIO AND YEAR=xYEAR AND CODIGO=xCODIGO_VIA AND AMBITO=xAMBITO
                   AND ((DESDE<=xNUM) AND (xNUM<=HASTA));
      end if;

      IF (xContador=0) THEN  --Por defecto el índice es 1
         xINDICE:=1;
      ELSE  --dependiendo de la categoría devolvemos un índice
         IF (xCATEGORIA='1') THEN
            xINDICE:=xIND1;
         ELSIF (xCATEGORIA='2') THEN
            xINDICE:=xIND2;
         ELSIF (xCATEGORIA='3') THEN
	      xINDICE:=xIND3;
         ELSIF (xCATEGORIA='4') THEN
    	      xINDICE:=xIND4;
         ELSIF (xCATEGORIA='5') THEN
    	      xINDICE:=xIND5;
         ELSIF (xCATEGORIA='6') THEN
	      xINDICE:=xIND6;
         ELSIF (xCATEGORIA='7') THEN
	      xINDICE:=xIND7;
         ELSIF (xCATEGORIA='8') THEN
	      xINDICE:=xIND8;
         ELSIF (xCATEGORIA='9') THEN
	      xINDICE:=xIND9;
	   ELSE
            xINDICE:=xIND10;
         END IF;
      END IF;

   ELSE
     xINDICE:=1;  /* Si no se activó el índice de calles para el municipio, por defecto
		         éste toma el valor 1 */
   END IF;
END;
/


/********************************************************************************
Acción: Para el municipio dado cambia la configuración de periodos.
********************************************************************************/

CREATE OR REPLACE PROCEDURE CAMBIA_CONF_TRIMESTRE_IAE(
               xMUNICIPIO IN VARCHAR2,
               xTIPO      IN CHAR)
AS
BEGIN
   UPDATE DATOSPER SET IAE_CONF_PERIODOS_TRI=xTIPO
   WHERE MUNICIPIO=xMUNICIPIO ;
END;
/


/********************************************************************************
Acción: Comprobamos si el fichero ya ha sido leido.
********************************************************************************/

CREATE OR REPLACE PROCEDURE CHECK_EXIT_IAE(
               xYEAR      IN CHAR,
               xPERIODO   IN CHAR,
               xMUNICIPIO IN VARCHAR2,
               xCUANTOS   OUT INTEGER)
AS
BEGIN
   SELECT COUNT(*) INTO xCUANTOS
   FROM IAE
   WHERE MUNICIPIO=xMUNICIPIO AND YEAR=xYEAR AND PERIODO=xPERIODO;
END;
/

/********************************************************************************
Acción: Comprobamos si el padrón para el/los municipios,año y periodo dados ya se
        ha generado.
********************************************************************************/

CREATE OR REPLACE PROCEDURE CHECK_EXIT_PADIAE(
               xYEAR      IN CHAR,
               xPERIODO   IN CHAR,
               xCUANTOS   OUT INTEGER)
AS
BEGIN
   SELECT COUNT(*) INTO xCUANTOS
   FROM RECIBOS_IAE
   WHERE YEAR=xYEAR AND PERIODO=xPERIODO AND
         MUNICIPIO IN (SELECT MUNICIPIO FROM TMP_AYTOS WHERE USUARIO=USER);
END;
/

/********************************************************************************
Acción: Cuando generamos el padrón, si se ha dado de baja debemos calcular el importe
        para los trimestres transcurridos hasta la fecha de baja.
Modificado: 
********************************************************************************/

CREATE OR REPLACE PROCEDURE COMPRUEBA_BAJA (
			xPERIODO	IN CHAR,
			xFECHA_BAJA IN DATE,
			xFECHA_ALTA IN DATE,
			xIMPORTE_MINIMO OUT FLOAT,
			xCUOTA_MINIMA IN FLOAT,
			xCUOTA_MAQUINA IN OUT FLOAT)
AS
    YEAR_BAJA INTEGER;
    YEAR_ALTA INTEGER;
    TRIM_ALTA INTEGER;
    TRIM_BAJA INTEGER;
    xNumPeriodos integer;
BEGIN
    YEAR_BAJA:=F_YEAR(xFECHA_BAJA);
    YEAR_ALTA:=F_YEAR(xFECHA_ALTA);
    TRIM_ALTA:=QUARTER(xFECHA_ALTA);
    TRIM_BAJA:=QUARTER(xFECHA_BAJA);

/*    Si se da de baja en un año distinto al que se dio de alta
      calculamos el importe de los trimestres transcurridos hasta la fecha de baja
      desde enero de ese año */

   IF to_char(sysdate,'yyyy')>YEAR_BAJA THEN
   --EN ESTE CASO NO LIQUIDAR
	 xIMPORTE_MINIMO:=0;
	 xCUOTA_MAQUINA:=0;
         
   ELSIF YEAR_ALTA<>YEAR_BAJA OR YEAR_ALTA IS NULL THEN
	--EN ESTE CASO YA SE HA PAGADO TODO EL AÑO Y NO HAY QUE DEVOLVER NADA
      IF TRIM_BAJA=4 THEN
         xIMPORTE_MINIMO:=xCUOTA_MINIMA;
      ELSIF TRIM_BAJA=3 THEN
	 xIMPORTE_MINIMO:=(xCUOTA_MINIMA*3)/4;
	 xCUOTA_MAQUINA:=(xCUOTA_MAQUINA*3)/4;
      ELSIF TRIM_BAJA=2 THEN
	 xIMPORTE_MINIMO:=xCUOTA_MINIMA/2;
	 xCUOTA_MAQUINA:=xCUOTA_MAQUINA/2;
      ELSIF TRIM_BAJA=1 THEN
	 xIMPORTE_MINIMO:=xCUOTA_MINIMA/4;
	 xCUOTA_MAQUINA:=xCUOTA_MAQUINA/4;
      END IF;
   ELSE  /* Si se da de alta y de baja en el mismo año */
      IF TRIM_ALTA=TRIM_BAJA THEN
		xIMPORTE_MINIMO:=xCUOTA_MINIMA/4;
		xCUOTA_MAQUINA:=xCUOTA_MAQUINA/4;
  	  ELSE
		IF TRIM_ALTA<TRIM_BAJA THEN
			IF TRIM_ALTA < TO_number(xPERIODO) THEN
				xIMPORTE_MINIMO:=0;
				xCUOTA_MAQUINA:=0;
				RETURN;
			END IF;
			xNumPeriodos:=(TRIM_BAJA-TRIM_ALTA)+1;
			xIMPORTE_MINIMO:=(xCUOTA_MINIMA*xNumPeriodos)/4;
			xCUOTA_MAQUINA:=(xCUOTA_MAQUINA*xNumPeriodos)/4;
		END IF;
      END IF;
   END IF;
END;
/

/********************************************************************************
Acción: Crea, pega, quita o ve un grupo de IAE.
MODIFICACIÓN: 27/08/2001 Agustin Leon Robles.
********************************************************************************/

CREATE OR REPLACE PROCEDURE CREA_PEGA_GRUPO_IAE(
               xID IN INTEGER,
               xTIPO IN CHAR,
               xCODIGO_OPERACION IN OUT FLOAT)
AS
BEGIN

 IF xTIPO='C' THEN
	ADD_COD_OPERACION(xCODIGO_OPERACION);
	UPDATE IAE SET CODIGO_OPERACION=xCODIGO_OPERACION WHERE ID=xID;
 END IF;


 IF xTIPO='P' THEN
     UPDATE IAE SET CODIGO_OPERACION=xCODIGO_OPERACION WHERE ID=xID;
 END IF;


 IF xTIPO='Q' THEN
     UPDATE IAE SET CODIGO_OPERACION=0 WHERE ID=xID;
 END IF;

END;
/

-- *******************************************************************************
-- Acción: Generación del cuaderno19. Inserción de datos en tabla temporal.
-- MODIFICACIÓN: 27/08/2001 Agustin Leon Robles.
-- Modificacion: 17/09/2001 Agustin Leon Robles. Se ha añadido que en el fichero del banco
--								salga el año y periodo
-- MODIFICACIÓN: 20/09/2001 M. Carmen Junco Gómez. Adaptación al Euro. En las descripciones no
--		  podemos hacer to_char(float) porque se redondean los importes.
-- MODIFICACIÓN: 27/12/2001 Agustin Leon Robles. El numero de abonado que guardaba para el
--		cuaderno 19 era el numero de abonado cuando tiene que ser el numero de recibo,
--		el mismo que se pasa a recaudacion.
--
-- MODIFICACIÓN: 19/08/2002 Lucas Fernández Pérez. No deberán entrar en el disco aquellos
--		  recibos que se hayan pasado ya a Recaudación y que se encuentren
--		  ingresados o dados de baja.
-- MODIFICACIÓN: 21/01/2004 Lucas Fernández Pérez. Bonificaciones por domiciliaciones.
--	  Obtiene de la tabla PROGRAMAS la bonificación por domiciliación y la aplica al 
--		importe del recibo, para que en el disco del c19 vaya el importe bonificado.
--
-- MODIFICACION: 28/05/2004 Gloria Maria Calle Hernandez. Añadido campo AYTO a la tabla 
--			  Recibos_Cuadreno19 para generar ficheros por ayuntamientos (xej. Catoure).
--
-- MODIFICACIÓN: 06/02/2007 Lucas Fernández Pérez. Ampliación de la variable xDomi_Titular para recoger el 
--					nuevo domicilio con bloque y portal.
-- *****************************************************************************************

CREATE OR REPLACE PROCEDURE CUADERNO19_IAE (
               xYEAR      IN CHAR,
               xPERI      IN CHAR,
               xESTADO    IN CHAR)
AS
     xNOM_EPI    		CHAR(50);
     xNIF_TITULAR		CHAR(10);
     xNOMBRE_TITULAR 	CHAR(40);
     xDOMI_TITULAR 	CHAR(60);
     x2 			CHAR(40);
     x3 			CHAR(40);
     x4 			CHAR(40);
     x5 			CHAR(40);
     x6 			CHAR(40);
     x7 			CHAR(40);
     x8 			CHAR(40);
     x9 			CHAR(40);
     x10 			CHAR(40);
     x11 			CHAR(40);
     x12 			CHAR(40);
     x13 			CHAR(40);
     x14			CHAR(40);
     x15			CHAR(40);
     x16			char(40);

     xCODPOSTAL 		CONTRIBUYENTES.Codigo_Postal%Type;
     xProvincia		CONTRIBUYENTES.Provincia%Type;
     xPoblacion		CONTRIBUYENTES.Poblacion%Type;
     I           		INTEGER;
     xREGIS      		INTEGER;

	xCONCEPTO			CHAR(6);
	xBONIDOMI			FLOAT;
	xF_INGRESO			DATE;
	xFECHA_DE_BAJA		DATE;

	CURSOR CRECIAE IS SELECT * FROM RECIBOS_IAE
	   WHERE YEAR=xYEAR AND PERIODO=xPERI AND ESTADO_BANCO=xESTADO and total>0
		  AND MUNICIPIO IN (SELECT DISTINCT MUNICIPIO FROM TMP_AYTOS WHERE USUARIO=USER);
 
BEGIN


	-- Borrar los datos de este usuario de la tabla temporal
	DELETE FROM RECIBOS_CUADERNO19 WHERE USUARIO=USER;

	xREGIS:=0;

	SELECT COUNT(*) INTO xREGIS FROM RECIBOS_IAE
	 WHERE YEAR=xYEAR AND PERIODO=xPERI AND ESTADO_BANCO=xESTADO AND TOTAL>0
  	   AND MUNICIPIO IN (SELECT DISTINCT MUNICIPIO FROM TMP_AYTOS WHERE USUARIO=USER);

 	-- recogemos el concepto y la bonificacion por domiciliaciones para el IAE
	SELECT CONCEPTO,PORC_BONIFI_DOMI INTO xCONCEPTO, xBONIDOMI 
	FROM PROGRAMAS WHERE PROGRAMA='IAE';

      FOR v_IAE IN CRECIAE
      LOOP
		begin
			SELECT F_INGRESO,FECHA_DE_BAJA INTO xF_INGRESO,xFECHA_DE_BAJA
			FROM VALORES WHERE AYTO=v_IAE.MUNICIPIO AND PADRON=xCONCEPTO AND
						 YEAR=v_IAE.YEAR AND PERIODO=v_IAE.PERIODO AND
						 RECIBO=v_IAE.RECIBO AND TIPO_DE_OBJETO='R';
			Exception
			   When no_data_found then
				xF_INGRESO:=NULL;
				xFECHA_DE_BAJA:=NULL;
		end;

		IF ((xF_INGRESO IS NULL) AND (xFECHA_DE_BAJA IS NULL)) THEN

	         -- Domicilio del titular de la cuenta
		   IF v_IAE.TITULAR IS NULL THEN
			xNIF_TITULAR:=v_IAE.NIF;
		   ELSE
		 	xNIF_TITULAR:=v_IAE.TITULAR;
		   END IF;
		   GETContribuyente(xNIF_TITULAR,xNOMBRE_TITULAR,xPoblacion,xProvincia,
				  xCodPostal,xDomi_Titular);

	         xNOM_EPI:='';

      	   begin
            	SELECT NOMBRE INTO xNOM_EPI FROM EPIGRAFE WHERE ID=v_IAE.ID_EPIGRAFE;

		      EXCEPTION
      	         WHEN NO_DATA_FOUND THEN
            	      NULL;
	         end;

      	   I:=15;
		   x2:='REFERENCIA  '|| v_IAE.REFE;
      	   x3:='CALLE  ' || SUBSTR(LTRIM(RTRIM(v_IAE.CALLE)), 1, 30);
	         x4:='ESCALERA  ' ||  v_IAE.ESCALERA;
      	   x5:='PLANTA  ' ||  v_IAE.PLANTA;
	         x6:='PUERTA  ' ||  v_IAE.PUERTA;
      	   x7:='NUMERO  ' ||  v_IAE.NUMERO;
	         x8:='CUOTA MINIMA  '|| v_IAE.CUOTA_MINIMA;
		   x9:='%BONIFICACION  '|| TO_CHAR(v_IAE.PORCENT_BENE,'900');
	         x10:='CUOTA BONIFI  '|| v_IAE.CUOTA_BONI;
      	   x11:='CUOTA INGRE.  '|| v_IAE.CUOTA_INCRE;
	         x12:='CUOTA MUNIC.  '|| v_IAE.CUOTA_MUNI;
      	   x13:='RECARGO  '|| v_IAE.RECARGO;
	         x14:='EPIGRAFE  '|| v_IAE.EPIGRAFE || ' SECCION  ' || v_IAE.SECCION;
      	   x15:=SUBSTR(LTRIM(RTRIM(xNOM_EPI)), 1, 40);
		   x16:='AÑO: '||xYEAR||' PERIODO: '||xPERI;

      	   INSERT INTO RECIBOS_CUADERNO19
	      	(AYTO,ABONADO,NIF,NOMBRE,DOMICILIO,CODPOSTAL,MUNICIPIO,NOMBRE_TITULAR,
			 ENTIDAD,SUCURSAL,DC,CUENTA,TOTAL,
			 Campo2, Campo3, Campo4, Campo5, Campo6, Campo7,
			 Campo8, Campo9, Campo10, Campo11, Campo12, Campo13, Campo14, Campo15, Campo16,
			 CAMPOS_OPCIONALES, CUANTOS_REGISTROS)
 		   VALUES
	  		(v_IAE.MUNICIPIO,v_IAE.RECIBO,xNIF_TITULAR,v_IAE.NOMBRE,SUBSTR(xDOMI_TITULAR,1,40),
			 xCodPostal,xPOBLACION, xNOMBRE_TITULAR,
			 v_IAE.ENTIDAD,v_IAE.SUCURSAL,v_IAE.DC,v_IAE.CUENTA,
 			 ROUND(v_IAE.TOTAL*(1-(xBoniDomi/100)),2), 
            	 x2, x3, x4, x5, x6, x7, x8, x9, x10, x11, x12, x13, x14, x15, x16, I,xREGIS);

		END IF;
      END LOOP;
END;
/

/********************************************************************************
Acción: Borra una calle de la lista de calles con categorías.
********************************************************************************/

CREATE OR REPLACE PROCEDURE BORRA_CALLE_IAE(
               xID IN INTEGER)
AS
BEGIN
        DELETE FROM CALLES_IAE WHERE ID=xID;
END;
/

/********************************************************************************
Acción: Borra de la tabla de IAE los valores que existieran con el municipio,
        año y periodo que se pasan como parámetros.
********************************************************************************/

CREATE OR REPLACE PROCEDURE BORRA_VIEJO_IAE(
               xYEAR      IN CHAR,
               xPERIODO   IN CHAR,
               xMUNICIPIO IN VARCHAR2)
AS
BEGIN

	/* primero borramos los recibos que puedan existir */
	DELETE FROM RECIBOS_IAE
	WHERE MUNICIPIO=xMUNICIPIO AND YEAR=xYEAR AND PERIODO=xPERIODO;

	/* después borramos de la tabla de IAE */
	DELETE FROM IAE
	WHERE MUNICIPIO=xMUNICIPIO AND YEAR=xYEAR AND PERIODO=xPERIODO;

	DELETE FROM COTITULARES_RECIBO WHERE PROGRAMA='IAE' AND AYTO=xMUNICIPIO AND YEAR=xYEAR
			AND PERIODO=xPERIODO;

END;
/

/********************************************************************************
Acción: Borra el padrón generado para el/los municipios,año y periodo.
MODIFICACIÓN: 28/06/2002 M. Carmen Junco Gómez. Insertar una tupla en LogsPadrones
		  para controlar que se ha borrado un padrón.
MODIFICACIÓN: 04/12/2002 M. Carmen Junco Gómez. Insertamos el municipio y el periodo
		  en logspadrones.
********************************************************************************/

CREATE OR REPLACE PROCEDURE BORRA_PADRON_VIEJO_IAE(
               xPERIODO   IN CHAR,
               xYEAR      IN CHAR)
AS
   CURSOR CMUNI IS SELECT MUNICIPIO FROM TMP_AYTOS WHERE USUARIO=USER;
BEGIN

   FOR vMUNI IN CMUNI
   LOOP
   	DELETE FROM RECIBOS_IAE
   	WHERE MUNICIPIO=vMUNI.MUNICIPIO AND
            YEAR=xYEAR AND PERIODO=xPERIODO;

   	DELETE FROM COTITULARES_RECIBO WHERE PROGRAMA='IAE'
		AND AYTO=vMUNI.MUNICIPIO AND YEAR=xYEAR AND PERIODO=xPERIODO;

   	-- Insertamos una tupla en LOGSPADRONES para controlar que esta acción ha sido ejecutada
   	INSERT INTO LOGSPADRONES (MUNICIPIO,PROGRAMA,PYEAR,PERIODO,HECHO)
   	VALUES (vMUNI.MUNICIPIO,'IAE',xYEAR,xPERIODO,'Se Borra un Padrón');
   END LOOP;

END;
/

/********************************************************************************
Acción: Añade o quita una señal para incorporar o no un registro al padrón.
********************************************************************************/

CREATE OR REPLACE PROCEDURE REGISTRO_EN_PADRON(
               xID        IN INTEGER,
               xEN_PADRON IN CHAR)
AS
BEGIN
     UPDATE IAE SET EN_PADRON=xEN_PADRON WHERE ID=xID;
END;
/

/***************************************************************************************
Acción: añadir una liquidacion pero solo para IAE.
MODIFICACIÓN: 20 de Septiembre de 2002. Agustin Leon Robles
		  No grababa la fecha del final del periodo voluntario en la tabla de liqu.
		  en funcion de la configuracion del municipio
MODIFICACIÓN: 09/01/2003 Mª del Carmen Junco Gómez. El contador en contador_conceptos sólo
		  se ha de aumentar si el año del padrón coincide con el año de trabajo. 
MODIFICACION: 21/03/2003. Agustín León Robles. En vez de utilizar el final del periodo voluntario 
				se utiliza la fecha juliana. El final del periodo voluntario se calculará con los
				acuses de recibo o con la fecha de publicación en el BOP
MODIFICACIÓN: 10/04/2003. M. Carmen Junco Gómez. Daba error al insertar en liquidaciones
		  porque se estaba pasando como fecha juliana la variable xFinPeVol sin
		  darle formato.
MODIFICACIÓN: 01/07/2003 M. Carmen Junco Gómez. No se estaba insertando en la liquidación
		      el año de contraido, lo que daba posteriores problemas en las cuentas anuales.
***************************************************************************************/

CREATE OR REPLACE PROCEDURE ADD_LIQUI_PADRON(
      xMUNI	    IN	CHAR,
	xNUMERO   IN      CHAR,
	xCON 	    IN	CHAR,
	xYEAR     IN	CHAR,
	xPERIODO  IN	CHAR,
	xNIF 	    IN	CHAR,
	xDOMI     IN	CHAR,
	xFECHA_LIQUI IN	DATE,
	xIMPORTE  IN	FLOAT,
	xMOTIVO   IN	VARCHAR2,
	xEXPE     IN	CHAR)
AS
	xID 		INTEGER;
	xFinPeVol	date;
	xDias		integer;
      xYearWork	char(4);
BEGIN

	select dias_vencimiento into xDias from datosper where municipio=xMuni;

	if xDias > 0 then
		xFinPeVol:=SysDate+xDias;

		--es sabado
		if to_char(xFinPeVol,'d')=6 then
			xFinPeVol:=xFinPeVol+2;
		-- es domingo
		elsif to_char(xFinPeVol,'d')=7 then
			xFinPeVol:=xFinPeVol+1;
		end if;

	else
		xFinPeVol:=null;
	end if;

	SELECT YEARWORK INTO xYEARWORK FROM DATOSPER WHERE MUNICIPIO=xMUNI;

	IF (xYEAR=xYEARWORK) THEN
	   UPDATE CONTADOR_CONCEPTOS SET CONTADOR=CONTADOR+1 
	   WHERE CONCEPTO=xCon AND MUNICIPIO=xMuni;
	END IF;

	INSERT INTO LIQUIDACIONES (USUARIO,MUNICIPIO,NUMERO,CONCEPTO,YEAR,CONTRAIDO,
			PERIODO,NIF,DOMI_TRIBUTARIO,F_LIQUIDACION,IMPORTE,MOTIVO,EXPEDIENTE,
			F_JULIANA)
	VALUES (USER,xMuni,xNUMERO,xCon,xYEAR,xYEAR,xPERIODO,xNIF,xDomi,xFECHA_LIQUI,
			xIMPORTE,xMOTIVO,xEXPE,to_char(xFinPeVol,'ddd'))
	RETURNING ID INTO xID;

	INSERT_HISTORIA_LIQUI(xID,'A','SE AÑADE LA LIQUIDACION');

END;
/

/********************************************************************************
Acción: Calcula la cuota_maquina y la cuota_bonificación (si se ha de aplicar
        una bonificación).
********************************************************************************/

CREATE OR REPLACE PROCEDURE IAE_BONIFICACION(
			xPORCENT_BENE   IN NUMBER,
		      xFECHA_LIMITE   IN DATE,
			xIMPORTE_MINIMO IN FLOAT,
			xCUOTA_MAQUINA  IN OUT FLOAT,
			xCUOTA_BONI     OUT FLOAT)
AS
BEGIN
      IF (xPORCENT_BENE>0) AND ((xFECHA_LIMITE >=SYSDATE) OR (xFECHA_LIMITE IS NULL)) THEN
         xCUOTA_BONI:=xIMPORTE_MINIMO - (xIMPORTE_MINIMO*(xPORCENT_BENE/100));
	   xCUOTA_MAQUINA:=xCUOTA_MAQUINA - (xCUOTA_MAQUINA*(xPORCENT_BENE/100));
      ELSE
         xCUOTA_BONI:=xIMPORTE_MINIMO;
      END IF;
END;
/

/********************************************************************************
Acción: generar las liquidaciones de IAE.
********************************************************************************/

CREATE OR REPLACE PROCEDURE IAE_GENERA_LIQUIDACIONES (
			xMUNICIPIO       IN IAE.MUNICIPIO%TYPE,
			xNIF             IN IAE.NIF%TYPE,
			xCALLE           IN IAE.CALLE_ACTIVIDAD%TYPE,
			xESCALERA        IN IAE.ESCALERA_ACTIVI%TYPE,
			xPLANTA          IN IAE.PISO_ACTIVI%TYPE,
			xPUERTA          IN IAE.PUERTA_ACTIVI%TYPE,
			xNUMERO          IN IAE.NUMERO_ACTIVI%TYPE,
			xYEAR            IN IAE.YEAR%TYPE,
			xPERIODO         IN IAE.PERIODO%TYPE,
			xREFE            IN IAE.REFERENCIA%TYPE,
			xEPIGRAFE        IN IAE.EPIGRAFE%TYPE,
			xSECCION         IN IAE.SECCION%TYPE,
			xTIPO_ACTIVIDAD  IN IAE.TIPO_ACTIVIDAD%TYPE,
			xCUOTA_MINIMA    IN RECIBOS_IAE.CUOTA_MINIMA%TYPE,
			xIMPORTE_MINIMO  IN IAE.IMPORTE_MINIMO%TYPE,
			xPORCENT_BENE    IN NUMBER,
			xCUOTA_BONI      IN RECIBOS_IAE.CUOTA_BONI%TYPE,
			xCUOTA_INCRE     IN RECIBOS_IAE.CUOTA_INCRE%TYPE,
			xCUOTA_MUNI      IN RECIBOS_IAE.CUOTA_MUNI%TYPE,
			xRECARGO         IN RECIBOS_IAE.RECARGO%TYPE,
			xCUOTA_MAQUINA   IN RECIBOS_IAE.CUOTA_MAQUINA%TYPE,
			xTOTAL           IN RECIBOS_IAE.TOTAL%TYPE,
			xRECIBO          IN RECIBOS_IAE.RECIBO%TYPE,
			xCONCEPLIQUI     IN PROGRAMAS.LIQUIDACION%TYPE,
			xCANT_ELEMENTO_1 IN IAE.CANTIDAD_ELEMENTO_1%TYPE


)
AS
   xSALTO		   CHAR(2);
   xDOM            CHAR(60);
   xCONCEPTO_LIQUI VARCHAR2(512);
   xEXPE	       CHAR(10);
   xVARNUMERO      CHAR(7);
BEGIN

   SELECT SALTO INTO xSALTO FROM SALTO;

   xDOM:=substr(xCALLE||' '||xESCALERA||' '||xPLANTA||' '||xPUERTA||' '||xNUMERO,1,60);
   xCONCEPTO_LIQUI:=NULL;
   xCONCEPTO_LIQUI:='AÑO  '|| xYEAR||' PERIODO '|| xPERIODO|| xSALTO;
   xCONCEPTO_LIQUI:= xCONCEPTO_LIQUI || 'REFERENCIA  '||xREFE|| ' EPIGRAFE  '||xEPIGRAFE||
     	               ' SECCION  '||xSECCION|| 'TIPO DE ACTIVIDAD '||xTIPO_ACTIVIDAD||xSALTO;
   xCONCEPTO_LIQUI:= xCONCEPTO_LIQUI ||'CUOTA MINIMA  '||TO_CHAR(xCUOTA_MINIMA)||
	 	         ' CUOTA PERIODO  '||TO_CHAR(xIMPORTE_MINIMO)|| xSALTO;
   xCONCEPTO_LIQUI:= xCONCEPTO_LIQUI ||'%BONIFICACION  '||TO_CHAR(xPORCENT_BENE)||
			   ' CUOTA BONIFI  '||TO_CHAR(xCUOTA_BONI)||' CUOTA INCREM.  '||
			     TO_CHAR(xCUOTA_INCRE)||xSALTO;
   xCONCEPTO_LIQUI:=xCONCEPTO_LIQUI||'CUOTA MUNICIPAL  ' ||TO_CHAR(xCUOTA_MUNI)||
                     ' REC. PROVINCIAL: '||TO_CHAR(xRECARGO)||xSALTO;
   xCONCEPTO_LIQUI:=xCONCEPTO_LIQUI||'CUOTA MAQUINA  '||TO_CHAR(xCUOTA_MAQUINA);

   xEXPE:=substr(xYEAR||'/'||xRecibo,1,10);

   xVarNumero:=LPAD(xRecibo,7,'0');

		/* PEDIDO POR SALOBREÑA */

   IF (xEPIGRAFE='0833' AND xSECCION='1') THEN
      xCONCEPTO_LIQUI:=RTRIM(LTRIM(xCONCEPTO_LIQUI))||'  CUOTA METROS='|| xCANT_ELEMENTO_1;
   END IF;

   ADD_LIQUI_PADRON(xMUNICIPIO,xVARNUMERO,xCONCEPLiqui,xYEAR,xPERIODO,xNIF,xDOM,
                    SYSDATE,xTOTAL,xCONCEPTO_LIQUI,xEXPE);


END;
/

/********************************************************************************
Acción:
   EL IMPORTE MINIMO TIENE INCLUIDO LA CUOTA MAQUINA.
   EL CALCULO ES EL SIGUIENTE:
	 Cuota incrementada: cuota de tarifa con maquina * coeficiente de incremento

	 Cuota municipal:
	(Cuota tarifa sin maquina * coeficiente de incremento) * indice de situacion +
		Cuota maquina * coeficiente de incremento

	 Recargo 40%: la cuota tarifa que ya tiene la cuota maquina incluida * 40%

	 Total a pagar
    xTOTAL:=Round(xRECARGO+xCUOTA_MUNI,2);

MODIFICACIÓN: 13/09/2001 M. Carmen Junco Gómez. Adaptación al euro.
MODIFICACIÓN: 28/06/2002 M. Carmen Junco Gómez. Insertar una tupla en LogsPadrones
		  para controlar que se ha generado un padrón.
MODIFICACIÓN: 30/09/2002 M. Carmen Junco Gómez. Se incluye el año en las cuotas del
		  IAE para mantener un histórico para las liquidaciones de años anteriores.
MODIFICACIÓN: 04/12/2002 M. Carmen Junco Gómez. Insertamos los campos municipio y
		  periodo en logspadrones
MODIFICACIÓN: 30/04/2003 M. Carmen Junco Gómez. Sólo se liquidarán aquellos abonados
		  que no estén exentos: Sólo los que COD_EXENCION in (5,6,7)		  
MODIFICACIÓN: 02/09/03   M. Carmen Junco Gómez. Se cambia el cálculo del total a pagar
		  teniendo en cuenta el coeficiente de ponderación.
MODIFICACIÓN: 09/09/03   Gloria Mª Calle Hernández. Se considera si el registro tiene 
		  direccion en local afecto en cuyo caso los cálculos se harán sobre dicha calle.
MODIFICACIÓN: 08/03/2004 M. Carmen Junco Gómez. Si el año de inicio de la actividad es anterior 
		  al que estamos generando se hará un cálculo anual.
      	  Si la fecha de inicio de la actividad no encuadra con el trimestre que estamos generando
      	  se calculará el importe según el trimestre de la fecha de inicio (siempre que sea del 
      	  mismo año)
MODIFICACIÓN: 10/11/2005 Gloria Maria Calle Hernandez. Para los periodos Hacienda ha cambiada la informacion
		  que envia y solo se debe generar el padron para el mimso filtro de antes de solo los
		  tipos de operacion 'A' y 'W' y de los que tengan año de efectividad actual. 
MODIFICACIÓN: 13/02/2006 Gloria Maria Calle Hernandez. Cuando no tienen local afecto y el domicilio de la 
actividad no es en el municipio no se aplica indice de situacion alguno, se deja igual => Indice_Situacion=1
MODIFICACIÓN: 09/03/2006 Mª del Carmen Junco Gómez. Corrección del último cambio, ya que el código del domicilio
		  de la actividad tiene 5 dígitos, y se está comparando con el de la aplicación, de 3. Hay que recoger
		  los tres últimos dígitos del código de municipio de la actividad.
MODIFICACIÓN: 27/04/2006 M. Carmen Junco Gómez. Por recomendación de Ricardo de Torrejón.
		  Si el tipo de operación='W' se trata normalmente de liquidaciones a promotoras por
        venta de m2. Están obligadas a informar en enero del año siguiente, y es una liquidación puntual
        por el importe enviado (no tienen nada que ver el trimestre en el que se informe).
MODIFICACIÓN: 01/06/2006 Lucas Fernández Pérez. Corrección del cambio del 09/03/2006, sólo cogía los 3 digitos 
		  en el if inicial, no en el else que iba a continuación, por lo que seguía fallando en esos casos.
MODIFICACIÓN: 28/09/2006 Lucas Fernández Pérez. 
	Se busca en los epígrafes de sólo cálculo anual si el tipo de operación es W. Si no es W, xAnual=0
	(antes no tenía en cuenta el tipo de operación, y hacía calculo anual para los tipos A, por ejemplo)
MODIFICACIÓN: 05/02/2007 Lucas Fernández Pérez. Ampliación del campo domicilio de la tabla RECIBOS_IAE
******************************************************************************************/
CREATE OR REPLACE PROCEDURE GENERA_PADRON_IAE(
	xMUNICIPIO 	IN CHAR,
	xYEAR 		IN CHAR,
	xDESDE 		IN DATE,
	xHASTA 		IN DATE,
	xCARGO 		IN DATE,
	xCONCEPTO 	IN CHAR,
	xLINEA1 	IN CHAR,
	xLINEA2 	IN CHAR,
	xLINEA3 	IN CHAR,
	xPERIODO 	IN CHAR)
AS
     -- domicilio fiscal
     xDomiFiscal		 varchar(60);

     xCODIGO_POSTAL      CHAR(5);
     xPOBLACION          varchar2(35);
     xPROVINCIA          varchar2(35);
     xProvincia_Tri	 	 varchar2(35);
     xIndCalleLAfecto	 CHAR(4);

     xINDICE_CALLE       FLOAT;
     xCUOTA_MINIMA       FLOAT;
     xCUOTA_BONI         FLOAT;
     xCOEFI_INCREMENTO   FLOAT;
     xCUOTA_INCRE        FLOAT;
     xCUOTA_MUNI         FLOAT;
     xRECARGO            FLOAT;
     xCUOTA_MAQUINA      FLOAT;
     xIMPORTE_MINIMO     FLOAT;
     xTOTAL              FLOAT;
     xNOMBRE_TITULAR     VARCHAR(40);
     xDCONTROL           VARCHAR(2);
     xDIG_C60_M2         CHAR(2);
     xREFERENCIA         CHAR(10);
     xIMPORTE_CAD        CHAR(12);
     xTEMP               CHAR(1);
     xCONCEPLiqui        CHAR(6);
     xANUAL              INTEGER;
     xRECIBO             INTEGER DEFAULT 0;
     xPADRON		 	 CHAR(6);
     xEMISOR 	    	 CHAR(6);
     xTRIBUTO 	    	 CHAR(3);
     xTRIMINICIO		 INTEGER;

     -- Variables para crear la sentencia
     TYPE tCURSOR IS REF CURSOR;  -- define REF CURSOR type
      vRECIBOS  	   tCURSOR;     -- declare cursor variable
	  v_TIAE					   IAE%ROWTYPE;
	  vSENTENCIA   VARCHAR2(1000);

BEGIN

   IF (xPERIODO='00') THEN
        vSENTENCIA:= 'SELECT * FROM IAE WHERE MUNICIPIO=:xMUNICIPIO AND YEAR='''||xYEAR||
					 ''' AND PERIODO='''||xPERIODO||''' AND EN_PADRON=''S'' and COD_EXENCION IN (5,6,7)';
   ELSE 
        vSENTENCIA:= 'SELECT * FROM IAE WHERE MUNICIPIO=:xMUNICIPIO AND YEAR='''||xYEAR||
					 ''' AND PERIODO='''||xPERIODO||''' AND EN_PADRON=''S'' and COD_EXENCION IN (5,6,7)'||
					' AND TIPO_OPERACION IN (''A'',''W'') AND EJERCICIO_EFECTI='''||xYEAR||'''';
   END IF;

   -- Sólo la primera vez
   SELECT CONCEPTO,LIQUIDACION INTO xPADRON,xCONCEPLiqui FROM PROGRAMAS WHERE PROGRAMA='IAE';

   -- Para ver qué hay que hacer:
   -- 0  RECIBOS Y LIQUIDACIONES
   -- 1  SOLO RECIBOS
   -- 2  SOLO LIQUIDACIONES
   SELECT IAE_CONF_PERIODOS_TRI INTO xTEMP FROM DATOSPER WHERE MUNICIPIO=xMUNICIPIO;

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

   OPEN vRECIBOS FOR vSENTENCIA USING xMUNICIPIO;
   LOOP
	  FETCH vRECIBOS INTO v_TIAE;
	  EXIT WHEN vRECIBOS%NOTFOUND;

 	  xCUOTA_MAQUINA:= v_TIAE.CUOTA_MAQUINA;
	  xCUOTA_MINIMA:= v_TIAE.IMPORTE_MINIMO;

	  --EL NUMERO DE RECIBO VA A SER EL ID DE LA TABLA DE REFERENCIAS_BANCOS 
      SELECT ID INTO xRECIBO FROM REFERENCIAS_BANCOS WHERE MUNICIPIO=xMUNICIPIO
			AND YEAR=xYEAR AND PERIODO=xPERIODO AND REFERENCIA_IAE=v_TIAE.REFERENCIA;


      IF (v_TIAE.DOMICILIADO='N') THEN
          xNOMBRE_TITULAR:=NULL;
      ELSE
	    --nombre del titular de la cuenta, para el cuaderno 19 
         SELECT NOMBRE INTO xNOMBRE_TITULAR FROM CONTRIBUYENTES WHERE NIF=v_TIAE.DNI_FACTURA;
      END IF;


	  xDomiFiscal:=v_TIAE.VIA||' '||v_TIAE.CALLE||' '||v_TIAE.NUMERO||' '||
			v_TIAE.LETRA||' '||v_TIAE.ESCALERA||' '||v_TIAE.PISO||' '||v_TIAE.PUERTA;

	  BEGIN
		--buscamos la provincia del codigo postal de la actividad
        IF RTRIM(v_TIAE.CALLE_LOCAL) IS NULL THEN
		  SELECT PROVINCIA INTO xProvincia_Tri FROM COD_PROVINCIAS
		  WHERE CODPROV=SUBSTR(v_TIAE.COD_POSTAL_ACTIVI,1,2);
		ELSE
		   SELECT PROVINCIA INTO xProvincia_Tri FROM COD_PROVINCIAS
		   WHERE CODPROV=SUBSTR(v_TIAE.COD_POSTAL_LOCAL,1,2);
		END IF;
	  EXCEPTION
		 when no_data_found then
			xProvincia_Tri:=NULL;
	  END;

	  --domicilio fiscal en funcion de si tiene un representante o no.
	  --Dentro de la funcion "GetDomicilioFiscal" se comprueba si tiene a su vez
	  --un domicilio alternativo.
	  IF v_TIAE.REPRESENTANTE IS NULL THEN

		 --En el IAE hay una variante ya que si no tiene representante y tampoco
		 --domicilios alternativos entonces se tiene que coger los datos de la propia
		 --tabla de IAE y no de contribuyentes.
		 IF v_TIAE.IDDOMIALTER IS NULL THEN
			--xDomiFiscal ya estaria con datos
			xPoblacion:=v_TIAE.MUNICIPIO_FISCAL;
			xCODIGO_POSTAL:=v_TIAE.CODIGO_POSTAL;

			BEGIN
				SELECT PROVINCIA INTO xProvincia FROM COD_PROVINCIAS
					WHERE CODPROV=SUBSTR(v_TIAE.CODIGO_POSTAL,1,2);
			EXCEPTION
				when no_data_found then
					xProvincia:=NULL;
			END;
		 ELSE
			GetDomicilioFiscal(v_TIAE.NIF,v_TIAE.IDDOMIALTER,
					xDomiFiscal,xPoblacion,xProvincia,xCODIGO_POSTAL);
		 END IF;
  	  ELSE
		 GetDomicilioFiscal(v_TIAE.REPRESENTANTE,v_TIAE.IDDOMIALTER,
				xDomiFiscal,xPoblacion,xProvincia,xCODIGO_POSTAL);
	  END IF;

      -- inicializamos valores
      xCUOTA_INCRE:=0;
      xRECARGO:=0;
      xIMPORTE_MINIMO:=0;
      xANUAL:=0;

      --Calculamos indice diferenciando si tiene calle local afecto o en su defecto calle actividad
      IF RTRIM(v_TIAE.CALLE_LOCAL) IS NULL AND (substr(v_TIAE.COD_MUNICIPIO_ACT,3,3)<>v_TIAE.MUNICIPIO) THEN
         xINDICE_CALLE:= 1;
      
      ELSIF RTRIM(v_TIAE.CALLE_LOCAL) IS NULL AND (substr(v_TIAE.COD_MUNICIPIO_ACT,3,3)=v_TIAE.MUNICIPIO) THEN
         -- Vemos el índice de situación de la calle, y el coeficiente de incremento y recargo
         CALCULA_INDICE_CALLE(xMUNICIPIO, xYEAR, v_TIAE.CODIGO_VIA, v_TIAE.NUMERO_ACTIVI,
	   			              xINDICE_CALLE, xCOEFI_INCREMENTO, xRECARGO);
      ELSE
         BEGIN
		    --Buscamos codigo de la calle 
		    SELECT CODIGO_CALLE INTO xIndCalleLAfecto FROM CALLES 
			WHERE RTRIM(CALLE)=RTRIM(v_TIAE.CALLE_LOCAL) AND ROWNUM=1;
	     EXCEPTION
		    when no_data_found then
			   xIndCalleLAfecto:=NULL;
	     END;       
         -- Vemos el índice de situación de la calle, y el coeficiente de incremento y recargo
         CALCULA_INDICE_CALLE(xMUNICIPIO, xYEAR, xIndCalleLAfecto, v_TIAE.NUMERO_LOCAL,
	   			              xINDICE_CALLE, xCOEFI_INCREMENTO, xRECARGO);
	  END IF;

      IF xINDICE_CALLE IS NULL THEN
     	  xINDICE_CALLE:=1;  -- Valor por defecto del índice de calle
      END IF;

      -- Se busca en los epígrafes de sólo cálculo anual si el tipo de operación es W. Si no es W, xAnual=0
      SELECT DECODE(v_TIAE.TIPO_OPERACION,'W',COUNT(*),0) INTO xANUAL FROM IAE_EPIGRAFE
			WHERE EPIGRAFE=v_TIAE.EPIGRAFE AND SECCION=v_TIAE.SECCION;

      -- Epígrafes con W en el campo tipo de operación sólo liquidación anual según Salobreña y Torrejón.
      -- Si el Epígrafe está entonces se hace cálculo anual siempre
      IF (v_TIAE.TIPO_REGISTRO='S' OR xANUAL>0) THEN
    	   xANUAL:=1;
    	   xIMPORTE_MINIMO:=xCUOTA_MINIMA;
      END IF;

	  -- Si se ha dado de baja debemos comprobar hasta que trimestre
      --  del año en el que se da de baja la actividad se ha de pagar
      IF v_TIAE.F_BAJA IS NOT NULL THEN
         COMPRUEBA_BAJA(xPERIODO,v_TIAE.F_BAJA,	v_TIAE.FECHA_INICIO_ACTI,
 											xIMPORTE_MINIMO,xCUOTA_MINIMA,xCUOTA_MAQUINA);
      ELSE  -- No se ha dado de baja
      
      	-- si el año de inicio de la actividad es anterior al que estamos generando
      	-- se hará un cálculo anual.
      	-- si la fecha de inicio de la actividad no encuadra con el trimestre que estamos generando
      	-- se calculará el importe según el trimestre de la fecha de inicio
      	-- si el tipo de operación='W' se trata normalmente de liquidaciones a promotoras por
      	-- venta de m2. Están obligadas a informar en enero del año siguiente, y es una liquidación puntual
      	-- por el importe enviado (no tienen nada que ver el trimestre en el que se informe).
        IF (xANUAL=0) THEN -- si no es anual calculamos los importes según periodos
        
           IF ((F_YEAR(v_TIAE.FECHA_INICIO_ACTI) < xYEAR ) OR (xPERIODO='00') OR (xPERIODO='01') OR 
           		(v_TIAE.TIPO_OPERACION='W')) THEN
           		xTRIMINICIO:='00';
           ELSE
     	   		xTRIMINICIO:='0'||QUARTER(v_TIAE.FECHA_INICIO_ACTI);   	        
     	     END IF;
        
           IF (xTRIMINICIO='00') OR (xTRIMINICIO='01') THEN
              xIMPORTE_MINIMO:=xCUOTA_MINIMA;
           ELSIF (xTRIMINICIO='02') THEN
	       	  xIMPORTE_MINIMO:=(xCUOTA_MINIMA*3)/4;
	          xCUOTA_MAQUINA:=(xCUOTA_MAQUINA*3)/4;
           ELSIF (xTRIMINICIO='03') THEN
              xIMPORTE_MINIMO:=xCUOTA_MINIMA/2;
 	          xCUOTA_MAQUINA:=xCUOTA_MAQUINA/2;
           ELSIF (xTRIMINICIO='04') THEN
	          xIMPORTE_MINIMO:=xCUOTA_MINIMA/4;
   	          xCUOTA_MAQUINA:=xCUOTA_MAQUINA/4;
	       END IF;
        END IF;
      END IF;

      -- Se aplica bonificación, si procede
      IAE_BONIFICACION(TO_NUMBER(v_TIAE.BENEFICIOS_PORCEN),v_TIAE.FECHA_LIMITE_BENE,
				xIMPORTE_MINIMO,xCUOTA_MAQUINA,xCUOTA_BONI);

	  xIMPORTE_MINIMO:=Round(xIMPORTE_MINIMO,2);
	  xCUOTA_MAQUINA:=Round(xCUOTA_MAQUINA,2);
	  xCUOTA_BONI:=Round(xCUOTA_BONI,2);

	  -- Cuota incrementada: cuota de tarifa con maquina * coeficiente de incremento
      xCUOTA_INCRE:=Round((xCUOTA_BONI * v_TIAE.COEF_PONDERACION),2);

	  --Cuota municipal:
      --(Cuota tarifa sin maquina * coeficiente de ponderacion) * indice de situacion +
      --cuota maquina * coeficiente de ponderacion
	  xCUOTA_MUNI:=Round((((xCUOTA_BONI-xCUOTA_MAQUINA) * v_TIAE.COEF_PONDERACION) * 
	             xINDICE_CALLE + (xCUOTA_MAQUINA * v_TIAE.COEF_PONDERACION)),2);

	  -- Recargo 40%: la cuota tarifa que ya tiene la cuota maquina incluida * 40%
	  xRECARGO:=Round(((xCUOTA_BONI * v_TIAE.COEF_PONDERACION) * xRECARGO * 0.01),2);

	  -- Total a pagar
      xTOTAL:=Round((xRECARGO+ xCUOTA_MUNI),2);

	  -- Cálculo de los dígitos de control para la Emisora
      CALCULA_DC_60(xTotal,xRECIBO,xTRIBUTO,SUBSTR(xYear,3,2),xPeriodo,xEMISOR,xDCONTROL);

	  --calcular los digitos de control del cuaderno 60 modalidad 2
	  CALCULA_DC_MODALIDAD2_60(xTotal, xRECIBO, xTRIBUTO, SUBSTR(xYear,3,2), '1',
			to_char(xHASTA,'y'), to_char(xHASTA,'ddd'), xEMISOR, xDIG_C60_M2);

      -- Convierte el número de recibo a carácteres y rellena de ceros
      GETREFERENCIA(xRECIBO,xREFERENCIA);

      -- Importe a pagar expresado en caracteres
      IMPORTEENCADENA(xTotal,xIMPORTE_CAD);

	  --insertamos los cotitulares del recibo
	  IF v_TIAE.COTITULARES='S' THEN
		INSERT INTO COTITULARES_RECIBO(NIF,PROGRAMA,AYTO,PADRON,YEAR,PERIODO,RECIBO)
		SELECT NIF,'IAE',xMUNICIPIO,xPADRON,xYEAR,xPERIODO,xRECIBO
		FROM COTITULARES
		WHERE ID_CONCEPTO=v_TIAE.ID AND PROGRAMA='IAE';
	  END IF;

      IF (xTEMP='0' OR xTEMP='1' OR xPERIODO='00') THEN
		if xTOTAL>0 then
 		   INSERT INTO RECIBOS_IAE (Recibo,ABONADO,REFE,YEAR,PERIODO,MUNICIPIO,
 			 NIF,NOMBRE,DOMICILIO,CODIGO_POSTAL,POBLACION,PROVINCIA,
			 --DOM. TRIBUTARIO
			 CODIGO_VIA,CALLE,ESCALERA,PLANTA,PUERTA,NUMERO,
			 CODPOSTAL_TRI,POBLACION_TRI,PROVINCIA_TRI,
			 ID_EPIGRAFE,EPIGRAFE,SECCION,
			 CUOTA_PERIODO,PORCENT_BENE,CUOTA_MINIMA,
             CUOTA_BONI,CUOTA_INCRE,CUOTA_MUNI,RECARGO,CUOTA_MAQUINA,
			 TIPO_MUNICIPIO,SUPERFICIE_DECLARADA,SUPERFICIE_RECTIFICADA,
			 SUPERFICIE_COMPUTABLE,YEAR_INICIO,FECHA_LIMITE,TIPO_ACTIVIDAD,IMPORTE,TOTAL,
			 DOMICILIADO,ESTADO_BANCO,
			 ENTIDAD,SUCURSAL,DC,CUENTA,F_DOMICILIACION,TITULAR,NOMBRE_TITULAR,
			 DESDE,HASTA,F_CARGO,CONCEPTO,LINEA1,LINEA2,LINEA3,EMISOR,TRIBUTO,EJERCICIO,
			 REMESA,REFERENCIA,DIGITO_CONTROL,
			 DISCRI_PERIODO,DIGITO_YEAR,F_JULIANA,DIGITO_C60_MODALIDAD2)
      	   VALUES
             (xRecibo,v_TIAE.ID,v_TIAE.REFERENCIA,xYear,xPeriodo,xMUNICIPIO,
			  v_TIAE.NIF,v_TIAE.NOMBRE,xDomiFiscal,xCODIGO_POSTAL,xPOBLACION,xPROVINCIA,
			  --DOM. TRIBUTARIO
              DECODE(RTRIM(v_TIAE.CALLE_LOCAL),NULL,v_TIAE.CODIGO_VIA,xIndCalleLAfecto),
              DECODE(RTRIM(v_TIAE.CALLE_LOCAL),NULL,v_TIAE.CALLE_ACTIVIDAD,v_TIAE.CALLE_LOCAL),
              DECODE(RTRIM(v_TIAE.CALLE_LOCAL),NULL,v_TIAE.ESCALERA_ACTIVI,v_TIAE.ESCALERA_LOCAL),
              DECODE(RTRIM(v_TIAE.CALLE_LOCAL),NULL,v_TIAE.PISO_ACTIVI,v_TIAE.PISO_LOCAL),
              DECODE(RTRIM(v_TIAE.CALLE_LOCAL),NULL,v_TIAE.PUERTA_ACTIVI,v_TIAE.PUERTA_LOCAL),
              DECODE(RTRIM(v_TIAE.CALLE_LOCAL),NULL,v_TIAE.NUMERO_ACTIVI,v_TIAE.NUMERO_LOCAL),
              DECODE(RTRIM(v_TIAE.CALLE_LOCAL),NULL,v_TIAE.COD_POSTAL_ACTIVI,v_TIAE.COD_POSTAL_LOCAL),
              DECODE(RTRIM(v_TIAE.CALLE_LOCAL),NULL,v_TIAE.MUNICIPIO_ACTIVI,v_TIAE.MUNICIPIO_LOCAL),
			  xProvincia_Tri,v_TIAE.ID_EPIGRAFE,v_TIAE.EPIGRAFE,v_TIAE.SECCION,
			  xIMPORTE_MINIMO,TO_NUMBER(v_TIAE.BENEFICIOS_PORCEN),xCUOTA_MINIMA,
			  xCUOTA_BONI,xCUOTA_INCRE,xCUOTA_MUNI,xRECARGO,xCUOTA_MAQUINA,
			  xINDICE_CALLE,v_TIAE.SUPERFICIE_DECLARADA,v_TIAE.SUPERFICIE_RECTIFICADA,
              v_TIAE.SUPERFICIE_COMPUTABLE,v_TIAE.YEAR_INICIO_ACTI,
			  v_TIAE.FECHA_LIMITE_BENE,v_TIAE.TIPO_ACTIVIDAD,xIMPORTE_CAD,xTOTAL,
			  v_TIAE.DOMICILIADO,DECODE(v_TIAE.DOMICILIADO,'S','EB',NULL),
			  DECODE(v_TIAE.DOMICILIADO,'S',v_TIAE.ENTIDAD,NULL),
			  DECODE(v_TIAE.DOMICILIADO,'S',v_TIAE.SUCURSAL,NULL),
			  DECODE(v_TIAE.DOMICILIADO,'S',v_TIAE.DC,NULL),
			  DECODE(v_TIAE.DOMICILIADO,'S',v_TIAE.CUENTA,NULL),
			  DECODE(v_TIAE.DOMICILIADO,'S',v_TIAE.F_DOMICILIACION,NULL),
			  DECODE(v_TIAE.DOMICILIADO,'S',v_TIAE.DNI_FACTURA,NULL),
              xNOMBRE_TITULAR,xDESDE,xHASTA,xCARGO,xCONCEPTO,
     		  xLINEA1,xLINEA2,xLINEA3,xEMISOR,xTRIBUTO,SUBSTR(xYear,3,2),xPeriodo,
			  xREFERENCIA,xDCONTROL,'1',to_char(xHASTA,'y'), to_char(xHASTA,'ddd'),xDIG_C60_M2);
		 end if;

	  END IF;


	  --Generamos liquidación
      IF (xTEMP='0' OR xTEMP='2') AND (xPERIODO<>'00') THEN
		if xTOTAL>0 then
          IF RTRIM(v_TIAE.CALLE_LOCAL) IS NULL THEN
			 IAE_GENERA_LIQUIDACIONES
			    (xMUNICIPIO,v_TIAE.NIF,v_TIAE.CALLE_ACTIVIDAD,v_TIAE.ESCALERA_ACTIVI,
			     v_TIAE.PISO_ACTIVI,v_TIAE.PUERTA_ACTIVI,v_TIAE.NUMERO_ACTIVI,xYEAR,xPERIODO,
			     v_TIAE.REFERENCIA,v_TIAE.EPIGRAFE,v_TIAE.SECCION,v_TIAE.TIPO_ACTIVIDAD,
	             xCUOTA_MINIMA,xIMPORTE_MINIMO,TO_NUMBER(v_TIAE.BENEFICIOS_PORCEN),
			     xCUOTA_BONI,xCUOTA_INCRE,xCUOTA_MUNI,xRECARGO,xCUOTA_MAQUINA,
	             xTOTAL,xRECIBO,xCONCEPLIQUI,v_TIAE.CANTIDAD_ELEMENTO_1);
		  ELSE
			 IAE_GENERA_LIQUIDACIONES
			    (xMUNICIPIO,v_TIAE.NIF,v_TIAE.CALLE_LOCAL,v_TIAE.ESCALERA_LOCAL,
			     v_TIAE.PISO_LOCAL,v_TIAE.PUERTA_LOCAL,v_TIAE.NUMERO_LOCAL,xYEAR,xPERIODO,
			     v_TIAE.REFERENCIA,v_TIAE.EPIGRAFE,v_TIAE.SECCION,v_TIAE.TIPO_ACTIVIDAD,
	             xCUOTA_MINIMA,xIMPORTE_MINIMO,TO_NUMBER(v_TIAE.BENEFICIOS_PORCEN),
			     xCUOTA_BONI,xCUOTA_INCRE,xCUOTA_MUNI,xRECARGO,xCUOTA_MAQUINA,
	             xTOTAL,xRECIBO,xCONCEPLIQUI,v_TIAE.CANTIDAD_ELEMENTO_1);
		  END IF;
		end if;
	  END IF;

   END LOOP;

   -- Insertamos una tupla en LOGSPADRONES para controlar que esta acción ha sido ejecutada
   INSERT INTO LOGSPADRONES (MUNICIPIO,PROGRAMA,PYEAR,PERIODO,HECHO)
   VALUES (xMUNICIPIO,'IAE',xYEAR,xPERIODO,'Se Genera un Padrón');

END;
/

/********************************************************************************
Acción: Generar el padrón de IAE.
********************************************************************************/

CREATE OR REPLACE PROCEDURE GENERA_RECIBOS_IAE (
	xYEAR 	IN CHAR,
	xDESDE 	IN DATE,
	xHASTA 	IN DATE,
	xCARGO 	IN DATE,
	xCONCEPTO 	IN CHAR,
	xLINEA1 	IN CHAR,
	xLINEA2 	IN CHAR,
	xLINEA3 	IN CHAR,
	xPERIODO 	IN CHAR)
AS
   CURSOR CAYTOS IS
      SELECT MUNICIPIO FROM TMP_AYTOS WHERE USUARIO=USER;
BEGIN
   FOR v_aytos IN CAYTOS
   LOOP
      GENERA_PADRON_IAE(v_aytos.MUNICIPIO,xYEAR,xDESDE,xHASTA,xCARGO,xCONCEPTO,
 	                  xLINEA1,xLINEA2,xLINEA3,xPERIODO);
   END LOOP;
END;
/

/*******************************************************************************
Acción: Añade o quita domiciliaciones a los registros de ibi, tanto a un registro 
		individual como a un grupo activo.
MODIFICACION: 13/02/2006. Gloria Calle Hernandez. Modificacion del cursor cIAEDomi.
*******************************************************************************/
CREATE OR REPLACE PROCEDURE DOMICILIA_IAE(
            xID 	     IN INTEGER,
            xENTIDAD     IN CHAR,
            xSUCURSAL    IN CHAR,
            xDC          IN CHAR,
            xCUENTA      IN CHAR,
            xTITULAR     IN CHAR,
            xDOMICILIADO IN CHAR,
		    xFECHA_DOMI  IN DATE,
		    xMotivoCambioDomi IN  VARCHAR2,
       		xGrupo		 IN INTEGER)
AS
    CURSOR CIAEDOMI IS SELECT ID FROM IAE WHERE CODIGO_OPERACION=xGRUPO;
BEGIN

	IF (xGRUPO=0 or xGRUPO is null) THEN
	   IAE_BANCOS(xID,xENTIDAD,xSUCURSAL,xDC,xCUENTA,xTITULAR,xDOMICILIADO,xFECHA_DOMI,xMotivoCambioDomi);
	ELSE 
	   FOR vIAEDOMI IN cIAEDOMI LOOP
	       IAE_BANCOS(vIAEDOMI.ID,xENTIDAD,xSUCURSAL,xDC,xCUENTA,xTITULAR,xDOMICILIADO,xFECHA_DOMI,xMotivoCambioDomi);
	   END LOOP;
	END IF;

END;
/


/********************************************************************************
Acción: Añade,modifica o quita los datos de una domiciliación.
MODIFICACIÓN: 26/06/2002 M. Carmen Junco Gómez. Comprueba si hay recibo emitido
              del padrón anual en curso y en tal caso modifica los datos de la
              domiciliación para que entre en los soportes del cuaderno 19
MODIFICACION: 03/07/2002 M. Carmen Junco Gómez. Si no se encontraba el recibo en la
		  tabla de valores estavamos asignándole a mVOL_EJE:=''; En mi máquina,
		  por ejemplo, funcionaba correctamente, pero en Salobreña estaba fallando
		  el procedimiento (no domiciliaba el recibo) debido a esta asignación.
		  Se ha cambiado por mVOL_EJE:=NULL;
MODIFICACION: 08/07/2002 M. Carmen Junco Gómez. El recibo de IAE sólo se podrá modificar
		  si aún no se ha emitido el Cuaderno19 para el padrón al que pertenece.
		  Además, cuando modificamos en recaudación, debemos tener en cuenta si el
		  cargo se ha aceptado o no. Si aún no se ha aceptado habrá que hacer la
		  modificación en la tabla PUNTEO y no en VALORES.
MODIFICACIÓN: 04/12/2002 M. Carmen Junco Gómez. Insertamos los campos MUNICIPIO y
		  PERIODO en LOGSPADRONES.
MODIFICACIÓN: 31/01/2005 Lucas Fernandez Pérez. Se añade el parámetro xMotivoCambioDomi.
		  Se eliminan los campos USR_CHG__CUENTA y F_CHG__CUENTA.
		  La información se almacenará ahora en la tabla HISTO_DOMICILIACIONES.
MODIFICACIÓN: 10/03/2005 Lucas Fernández Pérez. Hasta ahora se comprobaban los recibos emitidos 
		  en el año en curso, de tal forma que no hacía la modificación del recibo si el padrón se
		  emitió el año anterior al actual. Lo que haremos será revisar los recibos emitidos desde
		  hace un año al día de hoy. 		  
MODIFICACIÓN: 18/07/2006 Lucas Fernández Pérez. En la búsqueda del recibo en valores y punteo
	no estaba en la condicion "TIPO_DE_OBJETO='R'" 
********************************************************************************/

CREATE OR REPLACE PROCEDURE IAE_BANCOS(
               xID 	    IN INTEGER,
               xENTIDAD     IN CHAR,
               xSUCURSAL    IN CHAR,
               xDC          IN CHAR,
               xCUENTA      IN CHAR,
               xTITULAR     IN CHAR,
               xDOMICILIADO IN CHAR,
		       xFECHA_DOMI  IN DATE,
		       xMotivoCambioDomi IN  VARCHAR2)
AS
	mVOL_EJE Char(1);
	mVALOR   Integer;
	mPUNTEO  Integer;
	mPADRON CHAR(6);
	xNOMBRE_TITULAR CHAR(40);
	xCuantos Integer;

	-- cursor que recorre los distintos periodos de los distintos recibos que
	-- se han podido emitir para este abonado, para comprobar para que padrón
	-- se ha emitido ya el Cuaderno19, y por lo tanto no modificar la domiciliación
	-- de ese recibo. Han de ser recibos emitidos en el año en curso.
	CURSOR CPERIODOS IS SELECT DISTINCT YEAR,PERIODO,ID,MUNICIPIO,RECIBO FROM RECIBOS_IAE
				  WHERE ABONADO=xID 
				  		AND YEAR BETWEEN (TO_CHAR(sysdate,'yyyy')-1) AND TO_CHAR(sysdate,'yyyy');
BEGIN




	-- Se pone el posible motivo del cambio en la domiciliación en USUARIOSGT (campo TEXTO2).
    UPDATE USUARIOSGT SET TEXTO2=xMotivoCambioDomi WHERE USUARIO=USER;

    -- Actualizar en la tabla de IAE
	UPDATE IAE SET ENTIDAD=xENTIDAD,
			   SUCURSAL=xSUCURSAL,
			   DC=xDC,
			   CUENTA=xCUENTA,
			   F_DOMICILIACION=xFECHA_DOMI,
			   DNI_FACTURA=xTITULAR,
               DOMICILIADO=xDOMICILIADO
  	WHERE ID=xID;

	-- por cada periodo distinto de recibos sobre el abonado
	FOR vPERIODOS IN CPERIODOS
	LOOP

         -- Comprobamos si se ha emitido ya el soporte del cuaderno 19
	   SELECT COUNT(*) INTO xCUANTOS FROM LOGSPADRONES
	   WHERE MUNICIPIO=vPERIODOS.MUNICIPIO AND
		   PROGRAMA ='IAE' AND
		   PYEAR=vPERIODOS.YEAR AND
		   PERIODO=vPERIODOS.PERIODO AND
	         HECHO='Generación Cuaderno 19 (recibos domiciliados)';

	   IF xCUANTOS=0 THEN  -- aún no se ha emitido. Podemos modificar el recibo.
	      -- Averiguar el código de padron de IAE
		SELECT CONCEPTO INTO mPADRON FROM PROGRAMAS WHERE PROGRAMA='IAE';

		-- Comprobar si ya se paso a recaudación
		begin
	   		SELECT ID,VOL_EJE INTO mVALOR,mVOL_EJE FROM VALORES
         		WHERE AYTO=vPERIODOS.MUNICIPIO
		   		AND PADRON=mPADRON
		   		AND YEAR=vPERIODOS.YEAR
		   		AND PERIODO=vPERIODOS.PERIODO
		  		AND RECIBO=vPERIODOS.RECIBO
		  		AND TIPO_DE_OBJETO='R';
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
					AND RECIBO=vPERIODOS.RECIBO
					AND TIPO_DE_OBJETO='R';
				Exception
					When no_data_found then
						mVOL_EJE:=NULL;
			end;
		END IF;

		-- si el recibo está en Voluntaria en RECA o todavia no se ha pasado a recaudación
		IF ((mVOL_EJE='V') or (mVOL_EJE IS NULL)) THEN
		   	-- modificamos el recibo en gestión tributaria
	   		IF xDOMICILIADO = 'N' THEN
	      		UPDATE RECIBOS_IAE SET DOMICILIADO='N',
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
				SELECT SUBSTR(NOMBRE,1,40) INTO xNOMBRE_TITULAR
				FROM CONTRIBUYENTES WHERE NIF=xTITULAR;

	      		UPDATE RECIBOS_IAE SET DOMICILIADO='S',
							     ENTIDAD=xENTIDAD,
							     SUCURSAL=xSUCURSAL,
							     DC=xDC,
							     CUENTA=xCUENTA,
							     F_DOMICILIACION=xFECHA_DOMI,
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
Acción: Da de baja o restaura un registro.
MODIFICADO: 31/10/2005. Gloria MAria Calle Hernandez. Añadido campo usuario_baja para
		poder saber que usuario da la baja.
********************************************************************************/

CREATE OR REPLACE PROCEDURE IAE_BORRA(
               xID IN INTEGER,
               xFECHA IN DATE,
               xTIPO IN CHAR)
AS
BEGIN

  IF (xTIPO='B') THEN
     UPDATE IAE SET F_BAJA=XFECHA,USUARIO_BAJA=USER WHERE ID=xID;
  ELSE
     UPDATE IAE SET F_BAJA=NULL,USUARIO_BAJA=USER WHERE ID=XID;
  END IF;
END;
/

/********************************************************************************
Acción: Inserción de datos en tabla temporal para creación de gráficos.
********************************************************************************/

CREATE OR REPLACE PROCEDURE IAE_GRAFICOS(
               xMUNICIPIO IN VARCHAR2,
               xYEAR      IN CHAR,
               xPERIODO   IN CHAR)
AS
   xID_EPIGRAFE INTEGER;
   TARIFA VARCHAR(50);
   SUMA FLOAT;
   CONTADOR INTEGER;
   CURSOR CEPI IS
        SELECT ID_EPIGRAFE, SUM(TOTAL)
        FROM RECIBOS_IAE
        WHERE MUNICIPIO=xMUNICIPIO AND PERIODO=xPERIODO AND YEAR=xYEAR
        GROUP BY ID_EPIGRAFE;
BEGIN
   OPEN CEPI;
   LOOP
      FETCH CEPI INTO xID_EPIGRAFE, SUMA;
      EXIT WHEN CEPI%NOTFOUND;

      begin
         SELECT NOMBRE INTO TARIFA
         FROM EPIGRAFE
         WHERE ID=xID_EPIGRAFE;

         Exception
		When no_data_found then
		   TARIFA:='SIN EPIGRAFE CODIFICADO';
      end;

      INSERT INTO IAE_GRAFICOS_AUX
        (TARIFA,SUMA)
      VALUES
        (TARIFA,SUMA);
   END LOOP;
   CLOSE CEPI;
END;
/

/********************************************************************************
Acción: Pasa a recaudación el padrón generado para el municipio, año y
        periodo seleccionados.
MODIFICACIÓN: 27/05/2002 M. Carmen Junco Gómez. Incluir o no los exentos dependiendo
		  del nuevo parámetro de entrada xEXENTOS.
MODIFICACIÓN: 1/07/2002 M. Carmen Junco Gómez. Insertar una tupla en LogsPadrones
		  para controlar que se ha pasado un padrón a Recaudación.
MODIFICACIÓN: 04/12/2002 M. Carmen Junco Gómez. Se añaden los campos MUNICIPIO y
		  PERIODO en la tabla LOGSPADRONES.
MODIFICACIÓN: 20/12/2002 M. Carmen Junco Gómez. Se pasa el recargo provincial al
		  punteo en el campo recargo_o_e.
MODIFICACIÓN: 09/06/2004 Gloria Mª Calle Hernández. Se guarda en el campo Clave_recibo el ID 
		  de la la tabla de recibos.
MODIFICACIÓN: 16/02/2005 Gloria Mª Calle Hernández. Se guarda en el desglose de valores sólo
		  la cuota municipal y el recargo provincial.
********************************************************************************/

CREATE OR REPLACE PROCEDURE IAE_PASE_RECA(
               xMUNICIPIO 		IN VARCHAR2,
               xYEAR 	  		IN CHAR,
               xPERIODO   		IN CHAR,
               xFECHA 	  		IN DATE,
               xN_CARGO   		IN CHAR,
		       xYEARCONTRAIDO	IN CHAR,
		   	   xEXENTOS			IN CHAR)
AS
    xPADRON             		CHAR(6);
    DOMICILIO_TRIBUTARIO 		VARCHAR(60);
    OBJETO_TRIBUTARIO 			VARCHAR(1024);
    xSALTO      	      		CHAR(2);
    xNOM_EPI    	      		VARCHAR(50);
    xTIPO_TRIBUTO	 			CHAR(2);

CURSOR CRECIBOS IS  SELECT * FROM RECIBOS_IAE
	WHERE MUNICIPIO=xMUNICIPIO AND YEAR=xYEAR AND PERIODO=xPERIODO;
BEGIN

     SELECT CONCEPTO INTO xPADRON FROM PROGRAMAS WHERE PROGRAMA='IAE';

     SELECT TIPO_TRIBUTO INTO xTIPO_TRIBUTO
     FROM CONTADOR_CONCEPTOS
     WHERE MUNICIPIO=xMUNICIPIO AND CONCEPTO=xPADRON;

     SELECT min(SALTO) INTO xSALTO FROM SALTO;

     FOR v_RECIBOS IN CRECIBOS
     LOOP

        DOMICILIO_TRIBUTARIO:=v_RECIBOS.CALLE || ' ' ||v_RECIBOS.NUMERO
				||' '||v_RECIBOS.ESCALERA||' '|| v_RECIBOS.PLANTA
				||' ' ||v_RECIBOS.PUERTA||' '||SUBSTR(v_RECIBOS.POBLACION_TRI,1,18);


	  /* Obtenemos la descripción del epigrafe */
        begin
 	     SELECT NOMBRE INTO xNOM_EPI FROM EPIGRAFE WHERE ID=v_RECIBOS.ID_EPIGRAFE;
	     Exception
		  When no_data_found then
		     xNOM_EPI:='';
        end;

        OBJETO_TRIBUTARIO:='';
        OBJETO_TRIBUTARIO:='REFERENCIA: '||v_RECIBOS.REFE||xSALTO;

        IF DOMICILIO_TRIBUTARIO IS NOT NULL THEN
      	  OBJETO_TRIBUTARIO:=OBJETO_TRIBUTARIO||'DOM.TRIBUTARIO: '||DOMICILIO_TRIBUTARIO||xSALTO;
        END IF;

        IF xNOM_EPI IS NOT NULL THEN
            OBJETO_TRIBUTARIO:=OBJETO_TRIBUTARIO||'EPIGRAFE: '||xNOM_EPI||xSALTO;
        END IF;

        OBJETO_TRIBUTARIO:=OBJETO_TRIBUTARIO ||
		'CUOTA MINIMA: ' ||TO_CHAR(v_RECIBOS.CUOTA_MINIMA)||xSALTO;
        OBJETO_TRIBUTARIO:=OBJETO_TRIBUTARIO ||
		'%BONIFICACIÓN: ' ||TO_CHAR(v_RECIBOS.PORCENT_BENE)||xSALTO;
        OBJETO_TRIBUTARIO:=OBJETO_TRIBUTARIO ||
		'CUOTA PERIODO: ' ||TO_CHAR(v_RECIBOS.CUOTA_PERIODO)||xSALTO;
        OBJETO_TRIBUTARIO:=OBJETO_TRIBUTARIO ||
		'CUOTA BONIFI: ' ||TO_CHAR(v_RECIBOS.CUOTA_BONI)||xSALTO;
        OBJETO_TRIBUTARIO:=OBJETO_TRIBUTARIO ||
		'CUOTA INCREM.: '||TO_CHAR(v_RECIBOS.CUOTA_INCRE)||xSALTO;
        OBJETO_TRIBUTARIO:=OBJETO_TRIBUTARIO ||
		'CUOTA MUNICIPAL: '||TO_CHAR(v_RECIBOS.CUOTA_MUNI)||xSALTO;
        OBJETO_TRIBUTARIO:=OBJETO_TRIBUTARIO ||
		'RECARGO: '||TO_CHAR(v_RECIBOS.RECARGO)||xSALTO;
        OBJETO_TRIBUTARIO:=OBJETO_TRIBUTARIO ||
		'CUOTA MAQUINA: '||TO_CHAR(v_RECIBOS.CUOTA_MAQUINA)||xSALTO;

	  IF NOT (xEXENTOS='N' AND v_RECIBOS.TOTAL<=0) THEN
  	     INSERT INTO PUNTEO
              (AYTO, PADRON, YEAR, PERIODO, RECIBO, NIF,
               NOMBRE, VOL_EJE, F_CARGO, N_CARGO,
               PRINCIPAL, CUOTA_INICIAL, RECARGO_O_E,
		   	   IMPORTE1, IMPORTE2, TITULO1, TITULO2, 
		   	   DOM_TRIBUTARIO, FIN_PE_VOL, INI_PE_VOL, 
		   	   TIPO_DE_TRIBUTO, OBJETO_TRIBUTARIO, ESTADO_BANCO,
               TIPO_DE_OBJETO, CLAVE_CONCEPTO, YEAR_CONTRAIDO, CLAVE_RECIBO)
           VALUES
              (xMUNICIPIO, xPADRON, xYEAR, xPERIODO,
               v_RECIBOS.RECIBO, v_RECIBOS.NIF, v_RECIBOS.NOMBRE, 'V',
               xFECHA, xN_CARGO, v_RECIBOS.TOTAL, v_RECIBOS.TOTAL,v_RECIBOS.RECARGO,

               v_RECIBOS.CUOTA_MUNI,v_RECIBOS.RECARGO,
		       'CUOTA MUNICIPAL', 'RECARGO PROVINCIAL',
               DOMICILIO_TRIBUTARIO, v_RECIBOS.HASTA,
               v_RECIBOS.DESDE, xTIPO_TRIBUTO, OBJETO_TRIBUTARIO,
               v_RECIBOS.ESTADO_BANCO, 'R', v_RECIBOS.REFE, xYEARCONTRAIDO, v_RECIBOS.ID);
	  END IF;

     END LOOP;

     -- Insertamos una tupla en LOGSPADRONES para controlar que esta acción ha sido ejecutada
     INSERT INTO LOGSPADRONES (MUNICIPIO,PROGRAMA,PYEAR,PERIODO,HECHO)
     VALUES (xMUNICIPIO,'IAE',xYEAR,xPERIODO,'Se Pasa un padrón a Recaudación');

END;
/

/********************************************************************************
Acción: Inserción de datos en tabla temporal para impresión de recibos de IAE.
Autor: Agustin Leon Robles.
Fecha: 27/08/2001
MODIFICACIÓN: 05/08/2002 M. Carmen Junco Gómez.
		  En el campo xAbonado de la tabla imp_recibos_iae hay que meter el número de
		  registro (recogido de la tabla referencias_bancos) y no el abonado de la tabla
		  de recibos (que es el ID de la tabla de IAE).
		  Incluimos también los campos Muni, DMunicipio, CodConcepto y Plazo para
		  indicar el código del múnicipio, descripción de éste, código del concepto
		  y un texto indicando el número de plazo que se imprime.
MODIFICACIÓN: 13/08/2002 M. Carmen Junco Gómez.
		  No se estaban rellenando los campos de la tabla temporal relacionados con
		  el codigo postal,poblacion y provincia tributarios.
MODIFICACIÓN: 09/09/2002 M. Carmen Junco Gómez.
		  El select sobre la tabla CALLES_IAE no estaba restringido por municipio.
MODIFICACIÓN: 11/09/2002 M. Carmen Junco Gómez.
		  Para recoger la categoría no basta con indicar el código de calle y el
		  municipio, sino que tambíen hay que indicar el número, ya que una misma
		  calle puede tener más de una categoría dependiendo del número y paridad
		  de éste.
MODIFICACIÓN: 30/09/2002 M. Carmen Junco Gómez. Se añade el año a las cuotas del IAE
		  para poder liquidar años anteriores.

MODIFICACIÓN: 15/09/2003 Lucas Fernández Pérez. Se añaden los campos CUOTA_INCRE y 
		  COEF_PONDERACION en la tabla IMP_RECIBOS_IAE.
		  
MODIFICACIÓN: 01/03/2004 Mª Carmen Junco Gómez. Se incluye el campo FECHA_INICIO_ACTI
		  a petición de Ricardo de Torrejón.
		  
MODIFICACIÓN: 15/09/2004 Mª Carmen Junco Gómez. El índice de situación no se ponía por
		  defecto a 1 si la calle no tenía categoría. Se hacía un select para recogerlo, 
		  cuando ya lo teníamos almacenado en el campo TIPO_MUNICIPIO del recibo.
		  También se incluye en la tabla temporal la cuota mínima.
		  
********************************************************************************/

CREATE OR REPLACE PROCEDURE WriteTempIAE
		(v_RegistroIAE 	IN Recibos_IAE%ROWTYPE,
		xMUNICIPIO		IN CHAR,
		xYEAR			IN CHAR,
		xPERI			IN CHAR)
AS
	xNOMBRE_ENTIDAD 	CHAR(50);
	xHASTA1         	DATE;
	xDOMITRIBU      	CHAR(50);
	xFECHA_INICIO_ACTI	DATE;
	xNOM_EPIGRAFE   	VARCHAR2(50);
	xDMUNICIPIO       	VARCHAR2(50);
	xCODCONCEPTO     	CHAR(6);
	xPLAZO            	CHAR(15);
    xCategoriaCalle	  	CHAR(1);
	xIndiceCalle	  	FLOAT;
	xNUM			  	INTEGER;
	xTEMP		      	INTEGER;
	xCONTADOR		  	INTEGER;
	xAMBITO			  	CHAR(1);
	xCoef_Ponderacion	FLOAT;
BEGIN

	-- recogemos la descripción del municipio
	SELECT POBLACION INTO xDMUNICIPIO FROM DATOSPER WHERE MUNICIPIO=xMUNICIPIO;

	-- recogemos el código del concepto
	SELECT CONCEPTO INTO xCODCONCEPTO FROM PROGRAMAS WHERE PROGRAMA='IAE';

	-- dependiendo del periodo ponemos un texto u otro en xPlazo
	IF xPERI='00' THEN
         xPLAZO:='PLAZO UNICO';
	ELSIF xPERI<'10' THEN
	   xPLAZO:='PLAZO '||SUBSTR(xPERI,2,1)||'º';
	ELSE
	   xPLAZO:='PLAZO '||xPERI||'º';
	END IF;


    -- Domicilio tributario
	xDOMITRIBU:=v_RegistroIAE.CALLE||' '||v_RegistroIAE.NUMERO||' '||
			v_RegistroIAE.ESCALERA||' '||v_RegistroIAE.PLANTA||' '||v_RegistroIAE.PUERTA;

	-- Obtenemos la descripción del epigrafe
      begin
 	  SELECT NOMBRE INTO xNOM_EPIGRAFE FROM EPIGRAFE WHERE ID=v_RegistroIAE.ID_EPIGRAFE;
      EXCEPTION
	    WHEN NO_DATA_FOUND THEN
	       xNOM_EPIGRAFE:='';
      end;

	-- En caso de estar domiciliado, nombre de la Entidad
    xNOMBRE_ENTIDAD:='';
	begin
	   SELECT NOMBRE INTO xNOMBRE_ENTIDAD FROM ENTIDADES WHERE CODIGO=v_RegistroIAE.ENTIDAD;
      EXCEPTION
	   WHEN NO_DATA_FOUND THEN
	        NULL;
	end;

	-- Categoria de la calle (del domicilio tributario)
      xNUM:=to_number(v_RegistroIAE.NUMERO);

      xTEMP:=MOD(xNUM, 2); /* comprobamos si el número de calles es par o impar */
      IF (xTEMP=0) THEN
         xAMBITO:='P';
      ELSE
         xAMBITO:='I';
      END IF;

	SELECT count(CATEGORIA) INTO xContador
      FROM CALLES_IAE WHERE MUNICIPIO=xMUNICIPIO AND YEAR=xYEAR AND
	     CODIGO=v_RegistroIAE.CODIGO_VIA
           AND AMBITO=xAMBITO AND ((DESDE<=xNUM) AND (xNUM<=HASTA));

	IF (xContador=0) THEN  --en el ámbito par o impar no posee categoría
		SELECT count(CATEGORIA) INTO xContador
		FROM CALLES_IAE
		WHERE MUNICIPIO=xMUNICIPIO AND YEAR=xYEAR AND
		      CODIGO=v_RegistroIAE.CODIGO_VIA AND AMBITO='T'
                  AND ((DESDE<=xNUM) AND (xNUM<=HASTA));
		xAMBITO:='T';
	END IF;

	if xContador>0 then
         SELECT CATEGORIA INTO xCategoriaCalle FROM CALLES_IAE
         WHERE MUNICIPIO=xMUNICIPIO AND YEAR=xYEAR AND CODIGO=v_RegistroIAE.CODIGO_VIA AND
		   AMBITO=xAMBITO AND ((DESDE<=xNUM) AND (xNUM<=HASTA));
	else
         xCategoriaCalle:=NULL;
	end if;	
	
   -- el indice de la calle está almacenado en el registro del recibo
	xIndiceCalle:=v_RegistroIAE.Tipo_Municipio;	

    SELECT COEF_PONDERACION,FECHA_INICIO_ACTI INTO xCoef_Ponderacion,xFECHA_INICIO_ACTI 
    FROM IAE WHERE ID=v_RegistroIAE.ABONADO;

	xHASTA1:=v_RegistroIAE.HASTA+1; -- fecha del hasta mas un día

      INSERT INTO IMP_RECIBOS_IAE
		(USUARIO,MUNI,DMUNICIPIO,CODCONCEPTO,ANIO,PERIODO,PLAZO,ABONADO,NIF,NOMBRE,
		DOMIFISCAL,CODPOSTAL,POBLACION,
            PROVINCIA,EPIGRAFE,SECCION,NOM_EPIGRAFE,DOMITRIBU,CODPOSTAL_TRI,
		POBLACION_TRI,PROVINCIA_TRI,FECHA_INICIO_ACTI,CATEGORIA_CALLE,INDICE_CALLE,REFE,TOTAL,
	      CUOTA_MINIMA,CUOTA_PERIODO,CUOTA_BONI,CUOTA_MUNI,RECARGO,CUOTA_INCRE,COEF_PONDERACION,
	      BENEFICIOS_PORCEN,REFERENCIA,DC,TRIBUTO,EJERCICIO,REMESA,
	      IMPO,EMISOR,DESDE,HASTA,CARGO,HASTA1,ENTIDAD,SUCURSAL,DIGITOS,CUENTA,
   		TITULAR,NOMBRE_ENTIDAD,NOMBRE_TITULAR,CONCEPTO,
		DISCRI_PERIODO,DIGITO_YEAR,F_JULIANA,DIGITO_C60_MODALIDAD2,
	      COD_BARRAS_MOD1,COD_BARRAS_MOD2)

      VALUES(UID,xMUNICIPIO,xDMUNICIPIO,xCODCONCEPTO,xYEAR,xPERI,xPLAZO,v_RegistroIAE.RECIBO,
		v_RegistroIAE.NIF,v_RegistroIAE.NOMBRE,
		v_RegistroIAE.DOMICILIO,v_RegistroIAE.CODIGO_POSTAL,v_RegistroIAE.POBLACION,
            v_RegistroIAE.PROVINCIA,v_RegistroIAE.EPIGRAFE,v_RegistroIAE.SECCION,
		xNOM_EPIGRAFE,xDOMITRIBU,v_RegistroIAE.CODPOSTAL_TRI,
		v_RegistroIAE.POBLACION_TRI,v_RegistroIAE.PROVINCIA_TRI,xFECHA_INICIO_ACTI,xCategoriaCalle,xIndiceCalle,
		v_RegistroIAE.REFE,v_RegistroIAE.TOTAL,v_RegistroIAE.CUOTA_MINIMA,
	      v_RegistroIAE.CUOTA_PERIODO,v_RegistroIAE.CUOTA_BONI,v_RegistroIAE.CUOTA_MUNI,
		v_RegistroIAE.RECARGO,v_RegistroIAE.CUOTA_INCRE,xCoef_Ponderacion, 
		v_RegistroIAE.PORCENT_BENE,

            v_RegistroIAE.REFERENCIA,v_RegistroIAE.DIGITO_CONTROL,v_RegistroIAE.TRIBUTO,
		v_RegistroIAE.EJERCICIO,v_RegistroIAE.REMESA,
	      v_RegistroIAE.IMPORTE,v_RegistroIAE.EMISOR,v_RegistroIAE.DESDE,v_RegistroIAE.HASTA,
		v_RegistroIAE.F_CARGO,xHASTA1,v_RegistroIAE.ENTIDAD,v_RegistroIAE.SUCURSAL,
		v_RegistroIAE.DC,v_RegistroIAE.CUENTA,
   		v_RegistroIAE.TITULAR,xNOMBRE_ENTIDAD,v_RegistroIAE.NOMBRE_TITULAR,
		v_RegistroIAE.CONCEPTO,
		v_RegistroIAE.DISCRI_PERIODO,v_RegistroIAE.DIGITO_YEAR,v_RegistroIAE.F_JULIANA,
		v_RegistroIAE.DIGITO_C60_MODALIDAD2,

		'90502'||v_RegistroIAE.EMISOR||v_RegistroIAE.REFERENCIA||
		v_RegistroIAE.DIGITO_CONTROL||
		v_RegistroIAE.TRIBUTO||v_RegistroIAE.EJERCICIO||v_RegistroIAE.REMESA||
		LPAD(v_RegistroIAE.IMPORTE*100,8,'0'),

		'90521'||v_RegistroIAE.EMISOR||v_RegistroIAE.REFERENCIA||
		v_RegistroIAE.DIGITO_C60_MODALIDAD2||v_RegistroIAE.DISCRI_PERIODO||
		v_RegistroIAE.TRIBUTO||v_RegistroIAE.EJERCICIO||v_RegistroIAE.DIGITO_YEAR||
		v_RegistroIAE.F_JULIANA|| LPAD(v_RegistroIAE.IMPORTE*100,8,'0')||'0');
END;
/

/********************************************************************************
Acción: Procedimiento que rellena una tabla temporal con la información necesaria
        para la impresión de recibos domiciliados y no domiciliados.
MODIFICACIÓN: 27/08/2001 Agustin Leon Robles.
MODIFICACIÓN: 05/08/2002 Mª del Carmen Junco Gómez. Se añade un nuevo parámetro en
		  la llamada a WriteTempIAE (xMunicipio)
MODIFICACIÓN: 05/09/2005 Gloria Mª Calle Hernandez. Añadido impresión ordenada por
		  codigo postal y domicilio fiscal.
********************************************************************************/

CREATE OR REPLACE PROCEDURE IMPRIME_RECIBOS_IAE (
               xMUNICIPIO IN CHAR,
               xID 	  IN INTEGER,
               xYEAR 	  IN CHAR,
               xPERI 	  IN CHAR,
               xDOMI 	  IN CHAR,
               xRECIDESDE IN INTEGER,
               xRECIHASTA IN INTEGER,
		   xOrden	  IN CHAR)
AS

	I INTEGER;

	CURSOR CAlfabetico IS
      	SELECT * FROM RECIBOS_IAE
	      WHERE MUNICIPIO=xMUNICIPIO AND YEAR=xYEAR AND PERIODO=xPERI AND DOMICILIADO=xDOMI
		order by nombre,recibo;

	CURSOR CFiscal IS
      	SELECT * FROM RECIBOS_IAE
	      WHERE MUNICIPIO=xMUNICIPIO AND YEAR=xYEAR AND PERIODO=xPERI AND DOMICILIADO=xDOMI
		order by domicilio,recibo;

	CURSOR CTributario IS
      	SELECT * FROM RECIBOS_IAE
	      WHERE MUNICIPIO=xMUNICIPIO AND YEAR=xYEAR AND PERIODO=xPERI AND DOMICILIADO=xDOMI
		order by calle,numero,escalera,planta,puerta,recibo;

	CURSOR CCodPostalDom IS
      	SELECT * FROM RECIBOS_IAE
	      WHERE MUNICIPIO=xMUNICIPIO AND YEAR=xYEAR AND PERIODO=xPERI AND DOMICILIADO=xDOMI
		order by codigo_postal,domicilio;

	v_RegistroIAE      Recibos_IAE%ROWTYPE;

BEGIN

   I:=0;

   DELETE FROM IMP_RECIBOS_IAE WHERE USUARIO=UID;

   IF (xID<>0 ) then
	SELECT * INTO v_RegistroIAE FROM RECIBOS_IAE WHERE ID=xID;
	WriteTempIAE(v_RegistroIAE,xMunicipio,xYear,xPeri);

   ELSE

	if xOrden='A' then
        OPEN CAlfabetico;
	  LOOP
           FETCH CAlfabetico INTO v_RegistroIAE;
           EXIT WHEN CAlfabetico%NOTFOUND;

	     I:=I+1;

           IF I >= xRECIDESDE AND I <= xRECIHASTA THEN
			IF v_RegistroIAE.TOTAL>0 THEN
				WriteTempIAE(v_RegistroIAE,xMunicipio,xYear,xPeri);
			END IF;
	     ELSE
              IF I > xRECIHASTA THEN
		    EXIT;
              END IF;
           END IF;

   	  END LOOP;
        CLOSE CAlfabetico;

	--codigo postal y domicilio fiscal
	elsif xOrden='D' then
        OPEN CCodPostalDom;
	  LOOP
           FETCH CCodPostalDom INTO v_RegistroIAE;
           EXIT WHEN CCodPostalDom%NOTFOUND;

	     I:=I+1;

           IF I >= xRECIDESDE AND I <= xRECIHASTA THEN
			IF v_RegistroIAE.TOTAL>0 THEN
				WriteTempIAE(v_RegistroIAE,xMunicipio,xYear,xPeri);
			END IF;
	     ELSE
              IF I > xRECIHASTA THEN
		    EXIT;
              END IF;
           END IF;

   	  END LOOP;
        CLOSE CCodPostalDom;

	--orden fiscal o tributario
	else
		if xOrden='F' then

	        OPEN CFiscal;
		  LOOP
	           FETCH CFiscal INTO v_RegistroIAE;
      	     EXIT WHEN CFiscal%NOTFOUND;

		     I:=I+1;

      	     IF I >= xRECIDESDE AND I <= xRECIHASTA THEN
				IF v_RegistroIAE.TOTAL>0 THEN
					WriteTempIAE(v_RegistroIAE,xMunicipio,xYear,xPeri);
				END IF;
		     ELSE
            	  IF I > xRECIHASTA THEN
			    EXIT;
      	        END IF;
	           END IF;

   		  END LOOP;
	        CLOSE CFiscal;

		else
	        OPEN CTributario;
		  LOOP
	           FETCH CTributario INTO v_RegistroIAE;
      	     EXIT WHEN CTributario%NOTFOUND;

		     I:=I+1;

      	     IF I >= xRECIDESDE AND I <= xRECIHASTA THEN
				IF v_RegistroIAE.TOTAL>0 THEN
					WriteTempIAE(v_RegistroIAE,xMunicipio,xYear,xPeri);
				END IF;
		     ELSE
            	  IF I > xRECIHASTA THEN
			    EXIT;
      	        END IF;
	           END IF;

   		  END LOOP;
	        CLOSE CTributario;
		end if;
	end if;

   END IF; /*  del IF (xID<>0 ) then */
END;
/

-- ******************************************************************************************
--Acción: Se inserta el registro que se lee desde disco en la tabla IAE.
--MODIFICACIÓN: 13/09/2001 M. Carmen Junco Gómez. Adaptación al euro.
--Modificado: 19/08/2004 Lucas Fernández Pérez. Nuevo parámetro xORIGEN_CIFRA_NEGOCIO, que 
--	indica el origen de la cifra de negocio para cada contribuyente.
-- MODIFICACION: 05/02/2007. Lucas Fernández Pérez. InsertaModiContribuyente tiene 2 parametros más
--	 (bloque y portal) que se pasan valores ('',xLETRA)
-- ******************************************************************************************

CREATE OR REPLACE PROCEDURE INSERTA_REGISTRO_IAE(
               xMUNICIPIO 		IN CHAR,
               xYEAR 			IN CHAR,
               xPERIODO 		IN CHAR,
               xTIPO_REGISTRO 	IN CHAR,
               xTIPO_OPERACION 	IN CHAR,
               xREFERENCIA 		IN CHAR,
               xTIPO_ACTIVIDAD 	IN CHAR,
               xNIF 			IN CHAR,
               xNOMBRE 			IN CHAR,
               xANAGRAMA 		IN CHAR,
               xVIA 			IN CHAR,
               xCALLE 			IN CHAR,
               xNUMERO 			IN CHAR,
               xLETRA 			IN CHAR,
               xESCALERA 		IN CHAR,
               xPISO 			IN CHAR,
               xPUERTA 			IN CHAR,
               xCODIGO_MUNICIPIO 	IN CHAR,
               xMUNICIPIO_FISCAL 	IN CHAR,
               xCODIGO_POSTAL 	IN CHAR,
               xSECCION 		IN CHAR,
               xEPIGRAFE 		IN CHAR,
               xTIPO_CUOTA 		IN CHAR,
               xFECHA_INICIO_ACTI 	IN DATE,
               xNOTAS_AGRUPACION 	IN CHAR,
               xNOTAS_GRUPO 		IN CHAR,
               xNOTAS_EPIGRAFE 	IN CHAR,
               xREGLA_APLICACION 	IN CHAR,
               xCODIGO_ACTIVIDAD 	IN CHAR,
               xEXENCION 		IN CHAR,
               xBENEFICIOS_FISCAL 	IN CHAR,
               xBENEFICIOS_PORCEN 	IN CHAR,
               xFECHA_LIMITE_BENE 	IN DATE,
               xYEAR_INICIO_ACTI 	IN CHAR,
               xINFORMACION 		IN CHAR,
               xFECHA_VARIACION 	IN DATE,
               xCAUSA_VARIACION 	IN CHAR,
               xEJERCICIO_EFECTI 	IN CHAR,
               xFECHA_PRESENTA 	IN DATE,
               xCODIGO_ELEMENTO_1 	IN CHAR,
               xCODIGO_ELEMENTO_2 	IN CHAR,
               xCODIGO_ELEMENTO_3 	IN CHAR,
               xCODIGO_ELEMENTO_4 	IN CHAR,
               xCODIGO_ELEMENTO_5 	IN CHAR,
               xCODIGO_ELEMENTO_6 	IN CHAR,
               xCODIGO_ELEMENTO_7 	IN CHAR,
               xCODIGO_ELEMENTO_8 	IN CHAR,
               xCODIGO_ELEMENTO_9 	IN CHAR,
               xCODIGO_ELEMENTO_10 	IN CHAR,
               xCANTIDAD_ELEMENTO_1 IN FLOAT,
               xCANTIDAD_ELEMENTO_2 IN FLOAT,
               xCANTIDAD_ELEMENTO_3 IN FLOAT,
               xCANTIDAD_ELEMENTO_4 IN FLOAT,
               xCANTIDAD_ELEMENTO_5 IN FLOAT,
               xCANTIDAD_ELEMENTO_6 IN FLOAT,
               xCANTIDAD_ELEMENTO_7 IN FLOAT,
               xCANTIDAD_ELEMENTO_8 IN FLOAT,
               xCANTIDAD_ELEMENTO_9 IN FLOAT,
               xCANTIDAD_ELEMENTO_10 IN FLOAT,
               xSUPERFICIE_DECLARADA 	IN FLOAT,
               xSUPERFICIE_RECTIFICADA 	IN FLOAT,
               xSUPERFICIE_COMPUTABLE 	IN FLOAT,
               xCUOTA_MAQUINA 		IN FLOAT,
               xIMPORTE_MINIMO 		IN FLOAT,
               xCODIGO_VIA 			IN CHAR,
               xVIA_ACTIVIDAD 		IN CHAR,
               xCALLE_ACTIVIDAD 		IN CHAR,
               xNUMERO_ACTIVI 		IN CHAR,
       	   	   xLETRA_ACTIVI    		IN CHAR,
        	   xESCALERA_ACTIVI 		IN CHAR,
               xPISO_ACTIVI     		IN CHAR,
               xPUERTA_ACTIVI   		IN CHAR,
        	   xPUNTO_KILOMETRO 		IN CHAR,
               xPUESTO_UBICACION    	IN CHAR,
        	   xCOD_MUNICIPIO_ACT   	IN CHAR,
               xMUNICIPIO_ACTIVI    	IN CHAR,
        	   xCOD_POSTAL_ACTIVI   	IN CHAR,
        	   xTELEFONO        		IN CHAR,
		   	   xRESTOLINEA				IN CHAR,
		   	   xCOD_EXENCION		    IN INTEGER,
		   	   xORIGEN_CIFRA_NEGOCIO	IN CHAR,
			   xCIFRA_NEGOCIO	   		IN FLOAT,
			   xCOEF_PONDERACION		IN FLOAT)
AS

    xCLAVE_USO       		CHAR(2);
    xCODIGO_VIA_LOCAL    	CHAR(5);
    xVIA_LOCAL       		CHAR(2);
    xCALLE_LOCAL     		CHAR(25);
    xNUMERO_LOCAL    		CHAR(4);
    xLETRA_LOCAL     		CHAR(1);
    xESCALERA_LOCAL  		CHAR(2);
    xPISO_LOCAL      		CHAR(2);
    xPUERTA_LOCAL    		CHAR(2);
    xPUNTO_KILO_LOCAL		CHAR(5);
    xPUESTO_UBI_LOCAL    	CHAR(4);
    xCOD_MUNICIPIO_LOC   	CHAR(5);
    xMUNICIPIO_LOCAL     	CHAR(25);
    xCOD_POSTAL_LOCAL    	CHAR(5);
    xTELEFONO_LOCAL      	CHAR(7);
    xINDI_CALCULO_CUOTA 	CHAR(1);
    xREDUCCION_DEUDA_TRI 	INTEGER;
    xESTADO_BONIFICACION 	CHAR(1);
    xFECHA_CONCESION 		DATE;
    xFECHA_PRESENTACION 	DATE;


    xF_BAJA      DATE;
    xDOMICILIADO CHAR(1);
    xENTIDAD     CHAR(4);
    xSUCURSAL    CHAR(4);
    xDC          CHAR(2);
    xCUENTA      CHAR(10);
    xF_DOMICILIACION DATE;
    xDNI_FACTURA CHAR(10);

    xCE1         CHAR(9);
    xCE2         CHAR(9);
    xCE3         CHAR(9);
    xCE4         CHAR(9);
    xCE5         CHAR(9);
    xCE6         CHAR(9);
    xCE7         CHAR(9);
    xCE8         CHAR(9);
    xCE9         CHAR(9);
    xCE10        CHAR(9);
    xFECHA_INICIO_ACTIAUX 	DATE;
    xFECHA_LIMITE_BENEAUX 	DATE;
    xFECHA_VARIACIONAUX 	DATE;
    xFECHA_PRESENTAAUX 		DATE;
    xTIPO_ACTIVIDADAUX 		CHAR(1);
    xPERIODOAUX 			CHAR(2);
    xCUOTA_MAQUINAAUX 		FLOAT;
    xIMPORTE_MINIMOAUX 		FLOAT;
    xNUMERO_ACTIVIAUX 		CHAR(4);
    xCODIGO_VIAAUX 		CHAR(4);
    xEPI				CHAR(4);
    xID_EPIGRAFE			INTEGER;

    xREPRESENTANTE		CHAR(10);
    xIDDOMIALTER			INTEGER;
    xCOTITULARES			CHAR(1);

 BEGIN


   xCLAVE_USO:=SUBSTR(xRESTOLINEA,1,2);
   xCODIGO_VIA_LOCAL:=SUBSTR(xRESTOLINEA,3,5);
   xVIA_LOCAL:=SUBSTR(xRESTOLINEA,8,2);
   xCALLE_LOCAL:=SUBSTR(xRESTOLINEA,10,25);
   xNUMERO_LOCAL:=SUBSTR(xRESTOLINEA,35,4);
   xLETRA_LOCAL:=SUBSTR(xRESTOLINEA,39,1);
   xESCALERA_LOCAL:=SUBSTR(xRESTOLINEA,40,2);
   xPISO_LOCAL:=SUBSTR(xRESTOLINEA,42,2);
   xPUERTA_LOCAL:=SUBSTR(xRESTOLINEA,44,2);
   xPUNTO_KILO_LOCAL:=SUBSTR(xRESTOLINEA,46,5);
   xPUESTO_UBI_LOCAL:=SUBSTR(xRESTOLINEA,51,4);
   xCOD_MUNICIPIO_LOC:=SUBSTR(xRESTOLINEA,55,5);
   xMUNICIPIO_LOCAL:=SUBSTR(xRESTOLINEA,60,25);
   xCOD_POSTAL_LOCAL:=SUBSTR(xRESTOLINEA,85,5);
   xTELEFONO_LOCAL:=SUBSTR(xRESTOLINEA,90,7);
   xINDI_CALCULO_CUOTA:=SUBSTR(xRESTOLINEA,97,1);

   if SUBSTR(xRESTOLINEA,98,9)<>'         ' then
      xREDUCCION_DEUDA_TRI:=TO_NUMBER(SUBSTR(xRESTOLINEA,98,9));
   else
	xREDUCCION_DEUDA_TRI:=0;
   end if;


   xESTADO_BONIFICACION:=SUBSTR(xRESTOLINEA,107,1);

   if SUBSTR(xRESTOLINEA,108,8)<>'00000000' then
      xFECHA_CONCESION:=TO_DATE(SUBSTR(xRESTOLINEA,108,8),'YYYYMMDD');
   else
	xFECHA_CONCESION:=null;
   end if;

   if SUBSTR(xRESTOLINEA,116,8)<>'00000000' then
      xFECHA_PRESENTACION:=TO_DATE(SUBSTR(xRESTOLINEA,116,8),'YYYYMMDD');
   else
      xFECHA_PRESENTACION:=null;
   end if;


  /* Se tratan las fechas que se han pasado como parámetro */
  xFECHA_INICIO_ACTIAUX:=xFECHA_INICIO_ACTI;
  IF to_char(xFECHA_INICIO_ACTIAUX,'yyyy')='1899' THEN
    xFECHA_INICIO_ACTIAUX:=NULL;
  END IF;

  xFECHA_LIMITE_BENEAUX:=xFECHA_LIMITE_BENE;
  IF to_char(xFECHA_LIMITE_BENEAUX,'yyyy')='1899' THEN
    xFECHA_LIMITE_BENEAUX:=NULL;
  END IF;

  xFECHA_VARIACIONAUX:=xFECHA_VARIACION;
  IF to_char(xFECHA_VARIACIONAUX,'yyyy')='1899' THEN
    xFECHA_VARIACIONAUX:=NULL;
  END IF;

  xFECHA_PRESENTAAUX:=xFECHA_PRESENTA;
  IF to_char(xFECHA_PRESENTAAUX,'yyyy')='1899' THEN
    xFECHA_PRESENTAAUX:=NULL;
  END IF;


  /* Si la operación es una baja se da fecha a la fecha de baja */
  IF (xTIPO_OPERACION='B') THEN
      xF_BAJA:=xFECHA_VARIACION;
  END IF;

  /* Le damos valor al tipo de actividad:
      1: E Empresarial
	2: P Profesional
	3: A Artistica
   */

  xTIPO_ACTIVIDADAUX:=xTIPO_ACTIVIDAD;
  IF (xTIPO_ACTIVIDADAUX='1') THEN
      xTIPO_ACTIVIDADAUX:='E';
  END IF;

  IF (xTIPO_ACTIVIDADAUX='2') THEN
      xTIPO_ACTIVIDADAUX:='P';
  END IF;

  IF (xTIPO_ACTIVIDADAUX='3') THEN
      xTIPO_ACTIVIDADAUX:='A';
  END IF;

  /* ajustamos el epigrafe a cuatro caracteres */
  IF (LENGTH(LTRIM(RTRIM(xEPIGRAFE)))=1) THEN
     xEPI:='000'||LTRIM(RTRIM(xEPIGRAFE));
  ELSIF (LENGTH(LTRIM(RTRIM(xEPIGRAFE)))=2) THEN
     xEPI:='00'||LTRIM(RTRIM(xEPIGRAFE));
  ELSIF (LENGTH(LTRIM(RTRIM(xEPIGRAFE)))=3) THEN
     xEPI:='0'||LTRIM(RTRIM(xEPIGRAFE));
  ELSE
     xEPI:=xEPIGRAFE;
  END IF;

  /* buscamos el id del epigrafe; si no lo encontramos => id_epigrafe=null */
  begin
     SELECT ID INTO xID_EPIGRAFE FROM EPIGRAFE WHERE EPIGRAFE=xEPI AND SECCION=xSECCION;
     Exception
	  When no_data_found then
		xID_EPIGRAFE:=NULL;
  end;

  /* Se le da valor al periodo dependiendo de lo que leemos de disco */
  xPERIODOAUX:=xPERIODO;
  IF (xPERIODOAUX='0A') THEN
      xPERIODOAUX:='00';
  END IF;

  IF (xPERIODOAUX='1T') THEN
      xPERIODOAUX:='01';
  END IF;

  IF (xPERIODOAUX='2T') THEN
      xPERIODOAUX:='02';
  END IF;

  IF (xPERIODOAUX='3T') THEN
      xPERIODOAUX:='03';
  END IF;

  IF (xPERIODOAUX='4T') THEN
      xPERIODOAUX:='04';
  END IF;

  xCODIGO_VIAAUX:=NULL;

  /* Comprobamos si la calle que leemos está en nuestra base de datos. Si
     es así recogemos el código de la calle */

  SELECT MAX(CODIGO_CALLE) INTO xCODIGO_VIAAUX
  FROM CALLES
  WHERE MUNICIPIO=xMUNICIPIO AND ltrim(rtrim(CALLE))=ltrim(rtrim(xCALLE_ACTIVIDAD));

  xNUMERO_ACTIVIAUX:=xNUMERO_ACTIVI;
  IF xNUMERO_ACTIVIAUX='' OR xNUMERO_ACTIVIAUX IS NULL THEN
      xNUMERO_ACTIVIAUX:='0000';
  END IF;

  xCE1:=TO_CHAR(ROUND(xCANTIDAD_ELEMENTO_1,0));
  xCE2:=TO_CHAR(ROUND(xCANTIDAD_ELEMENTO_2,0));
  xCE3:=TO_CHAR(ROUND(xCANTIDAD_ELEMENTO_3,0));
  xCE4:=TO_CHAR(ROUND(xCANTIDAD_ELEMENTO_4,0));
  xCE5:=TO_CHAR(ROUND(xCANTIDAD_ELEMENTO_5,0));
  xCE6:=TO_CHAR(ROUND(xCANTIDAD_ELEMENTO_6,0));
  xCE7:=TO_CHAR(ROUND(xCANTIDAD_ELEMENTO_7,0));
  xCE8:=TO_CHAR(ROUND(xCANTIDAD_ELEMENTO_8,0));
  xCE9:=TO_CHAR(ROUND(xCANTIDAD_ELEMENTO_9,0));
  xCE10:=TO_CHAR(ROUND(xCANTIDAD_ELEMENTO_10,0));

  xCUOTA_MAQUINAAUX:=xCUOTA_MAQUINA;
  IF xCUOTA_MAQUINAAUX IS NULL THEN
      xCUOTA_MAQUINAAUX:=0;
  END IF;

  xIMPORTE_MINIMOAUX:=xIMPORTE_MINIMO;
  IF xIMPORTE_MINIMOAUX IS NULL THEN
      xIMPORTE_MINIMOAUX:=0;
  END IF;


	InsertaModiContribuyente(xNIF,xNOMBRE,
			xVIA,xCALLE,xNUMERO,'',xLETRA,xESCALERA,xPISO,xPUERTA,
			xMUNICIPIO_FISCAL,'',xCODIGO_POSTAL,'');

	-- Comprobamos si otro registro con la misma referencia había sido
	-- domiciliado con anterioridad. Si es así recogemos los datos de la domiciliación
	-- Siempre se intenta cojer los datos de la matricula anual Periodo='00'
	BEGIN
        SELECT DOMICILIADO,ENTIDAD,SUCURSAL,DC,CUENTA,F_DOMICILIACION,DNI_FACTURA,
					REPRESENTANTE,IDDOMIALTER,COTITULARES

        INTO xDOMICILIADO, xENTIDAD, xSUCURSAL, xDC, xCUENTA, xF_DOMICILIACION,xDNI_FACTURA,
					xREPRESENTANTE,xIDDOMIALTER,xCOTITULARES
        FROM IAE
	  WHERE MUNICIPIO=xMUNICIPIO AND YEAR=xYEAR-1 AND PERIODO='00' AND REFERENCIA=xREFERENCIA;
	EXCEPTION
	     WHEN NO_DATA_FOUND THEN
	        NULL;
	END;

	IF xDOMICILIADO IS NULL THEN
		xENTIDAD:=NULL;
		xDOMICILIADO:='N';
		xSUCURSAL:=NULL;
		xDC:=NULL;
		xCUENTA:=NULL;
		xF_DOMICILIACION:=NULL;
		xDNI_FACTURA:=NULL;
		xREPRESENTANTE:=NULL;
		xIDDOMIALTER:=NULL;
		xCOTITULARES:='N';
	END IF;

  
  INSERT INTO IAE(MUNICIPIO,YEAR,PERIODO,TIPO_REGISTRO,TIPO_OPERACION,
      REFERENCIA,TIPO_ACTIVIDAD,NIF,NOMBRE,ANAGRAMA,VIA,CALLE,NUMERO,
	  LETRA,ESCALERA,PISO,PUERTA,CODIGO_MUNICIPIO,MUNICIPIO_FISCAL,
	  CODIGO_POSTAL,ID_EPIGRAFE,SECCION,EPIGRAFE,TIPO_CUOTA,FECHA_INICIO_ACTI,
	  NOTAS_AGRUPACION,NOTAS_GRUPO,NOTAS_EPIGRAFE,REGLA_APLICACION,
	  CODIGO_ACTIVIDAD,EXENCION,BENEFICIOS_FISCAL,
	  BENEFICIOS_PORCEN,FECHA_LIMITE_BENE,YEAR_INICIO_ACTI,INFORMACION,
	  FECHA_VARIACION,CAUSA_VARIACION,EJERCICIO_EFECTI,FECHA_PRESENTA,
	  CODIGO_ELEMENTO_1,CODIGO_ELEMENTO_2,CODIGO_ELEMENTO_3,CODIGO_ELEMENTO_4,
	  CODIGO_ELEMENTO_5,CODIGO_ELEMENTO_6,CODIGO_ELEMENTO_7,CODIGO_ELEMENTO_8,
	  CODIGO_ELEMENTO_9,CODIGO_ELEMENTO_10,CANTIDAD_ELEMENTO_1,CANTIDAD_ELEMENTO_2,
	  CANTIDAD_ELEMENTO_3,CANTIDAD_ELEMENTO_4,CANTIDAD_ELEMENTO_5,
	  CANTIDAD_ELEMENTO_6,CANTIDAD_ELEMENTO_7,CANTIDAD_ELEMENTO_8,
	  CANTIDAD_ELEMENTO_9,CANTIDAD_ELEMENTO_10,SUPERFICIE_DECLARADA,
	  SUPERFICIE_RECTIFICADA,SUPERFICIE_COMPUTABLE,CUOTA_MAQUINA,IMPORTE_MINIMO,
	  CODIGO_VIA,VIA_ACTIVIDAD,CALLE_ACTIVIDAD,NUMERO_ACTIVI,LETRA_ACTIVI,
	  ESCALERA_ACTIVI,PISO_ACTIVI,PUERTA_ACTIVI,PUNTO_KILOMETRO,
	  PUESTO_UBICACION,COD_MUNICIPIO_ACT,
	  MUNICIPIO_ACTIVI,COD_POSTAL_ACTIVI,TELEFONO,CLAVE_USO,CODIGO_VIA_LOCAL,
	  VIA_LOCAL, CALLE_LOCAL,NUMERO_LOCAL,LETRA_LOCAL,ESCALERA_LOCAL,PISO_LOCAL,
	  PUERTA_LOCAL, PUNTO_KILO_LOCAL,PUESTO_UBI_LOCAL,COD_MUNICIPIO_LOC,
        MUNICIPIO_LOCAL,COD_POSTAL_LOCAL,TELEFONO_LOCAL,INDI_CALCULO_CUOTA,
	  REDUCCION_DEUDA_TRI,ESTADO_BONIFICACION,FECHA_CONCESION,FECHA_PRESENTACION,
	  F_BAJA,COD_EXENCION,ORIGEN_CIFRA_NEGOCIO,CIFRA_NEGOCIO,COEF_PONDERACION,
	  DOMICILIADO, SUCURSAL,ENTIDAD,DC,CUENTA,F_DOMICILIACION,DNI_FACTURA,
	  REPRESENTANTE,IDDOMIALTER,COTITULARES)

  VALUES(xMUNICIPIO, xYEAR, xPERIODOAUX, xTIPO_REGISTRO, xTIPO_OPERACION, xREFERENCIA,
	  xTIPO_ACTIVIDADAUX, Ltrim(Rtrim(xNIF)), Ltrim(Rtrim(xNOMBRE)), xANAGRAMA, xVIA,
	  xCALLE,xNUMERO, xLETRA,xESCALERA, xPISO, xPUERTA,xCODIGO_MUNICIPIO,
	  xMUNICIPIO_FISCAL, xCODIGO_POSTAL,xID_EPIGRAFE,xSECCION,xEPI,xTIPO_CUOTA,
	  xFECHA_INICIO_ACTIAUX,xNOTAS_AGRUPACION,xNOTAS_GRUPO, xNOTAS_EPIGRAFE,
	  xREGLA_APLICACION, xCODIGO_ACTIVIDAD, xEXENCION,xBENEFICIOS_FISCAL,
	  xBENEFICIOS_PORCEN,xFECHA_LIMITE_BENEAUX, xYEAR_INICIO_ACTI,
      xINFORMACION, xFECHA_VARIACIONAUX, xCAUSA_VARIACION,xEJERCICIO_EFECTI,
	  xFECHA_PRESENTAAUX, xCODIGO_ELEMENTO_1,xCODIGO_ELEMENTO_2, xCODIGO_ELEMENTO_3,
      xCODIGO_ELEMENTO_4, xCODIGO_ELEMENTO_5,xCODIGO_ELEMENTO_6, xCODIGO_ELEMENTO_7,
      xCODIGO_ELEMENTO_8, xCODIGO_ELEMENTO_9,xCODIGO_ELEMENTO_10, xCE1,xCE2,xCE3,xCE4,
	  xCE5,xCE6,xCE7,xCE8,xCE9,xCE10,xSUPERFICIE_DECLARADA,xSUPERFICIE_RECTIFICADA,
	  xSUPERFICIE_COMPUTABLE,ROUND(xCUOTA_MAQUINAAUX,2), ROUND(xIMPORTE_MINIMOAUX,2),
      xCODIGO_VIAAUX,xVIA_ACTIVIDAD,xCALLE_ACTIVIDAD,xNUMERO_ACTIVIAUX,xLETRA_ACTIVI,
	  xESCALERA_ACTIVI, xPISO_ACTIVI,xPUERTA_ACTIVI, xPUNTO_KILOMETRO,
	  xPUESTO_UBICACION, xCOD_MUNICIPIO_ACT, xMUNICIPIO_ACTIVI,xCOD_POSTAL_ACTIVI,
	  xTELEFONO,xCLAVE_USO,xCODIGO_VIA_LOCAL,xVIA_LOCAL,xCALLE_LOCAL,
	  xNUMERO_LOCAL, xLETRA_LOCAL, xESCALERA_LOCAL,xPISO_LOCAL,
	  xPUERTA_LOCAL, xPUNTO_KILO_LOCAL,xPUESTO_UBI_LOCAL, xCOD_MUNICIPIO_LOC,
      xMUNICIPIO_LOCAL,xCOD_POSTAL_LOCAL, xTELEFONO_LOCAL,xINDI_CALCULO_CUOTA,
	  xREDUCCION_DEUDA_TRI,xESTADO_BONIFICACION, xFECHA_CONCESION,
	  xFECHA_PRESENTACION,xF_BAJA,xCOD_EXENCION,DECODE(xORIGEN_CIFRA_NEGOCIO,' ',null,TO_NUMBER(xORIGEN_CIFRA_NEGOCIO)),
	  xCIFRA_NEGOCIO,xCOEF_PONDERACION,
	  xDOMICILIADO, xSUCURSAL, xENTIDAD,xDC, xCUENTA,xF_DOMICILIACION,xDNI_FACTURA,
	  xREPRESENTANTE,xIDDOMIALTER,xCOTITULARES);
END;
/

/********************************************************************************
Acción: Si el índice está activo para el/los municipios y existen calles que no se
        han corregido con la lista de calles del municipio, no se permite seguir con
        la generación del padrón hasta que se corrijan esas calles.
MODIFICACIÓN: 09/08/2002 Mª Carmen Junco Gómez. Se estaba comprobando que el tipo
		  de actividad fuera <> 'E' y es lo contrario.
********************************************************************************/

CREATE OR REPLACE PROCEDURE MIRA_CALLES_IAE(
               xYEAR IN CHAR,
               xPERIODO IN CHAR,
               xRESP OUT INTEGER)
AS
    xTEMP      CHAR(1);
    CONTADOR       INTEGER;
    CURSOR CAYTOS IS SELECT MUNICIPIO FROM TMP_AYTOS WHERE USUARIO=USER;
BEGIN

   xRESP:=0;
   FOR v_aytos IN CAYTOS
   LOOP
      SELECT IAE_CALLES_INDICE INTO xTEMP
      FROM DATOSPER WHERE MUNICIPIO=v_aytos.MUNICIPIO;

      IF (xTEMP='S') THEN
         SELECT COUNT(*) INTO CONTADOR FROM IAE
         WHERE MUNICIPIO=v_aytos.MUNICIPIO AND YEAR=xYEAR
			AND PERIODO=xPERIODO AND CODIGO_VIA IS NULL AND TIPO_ACTIVIDAD='E';
         IF (CONTADOR>0) THEN
            xRESP:=xRESP+1;
         END IF;
      END IF;
   END LOOP;
END;
/

/********************************************************************************
Acción: Inserta o modifica las cuotas definidas para una determinado municipio.
MODIFICACIÓN: 30/09/2002 Mª Carmen Junco Gómez. Se introduce el año para mantener
		  un histórico y poder liquidar años anteriores.
********************************************************************************/

CREATE OR REPLACE PROCEDURE MODIFICA_CUOTAS_IAE(
               xMUNICIPIO IN VARCHAR2,
		   xYEAR	  IN CHAR,
               xID        IN INTEGER,
               xCUOTA     IN FLOAT,
               xRECARGO   IN FLOAT,
               xIN_1      IN FLOAT,
               xIN_2      IN FLOAT,
               xIN_3      IN FLOAT,
               xIN_4      IN FLOAT,
               xIN_5      IN FLOAT,
               xIN_6      IN FLOAT,
               xIN_7      IN FLOAT,
               xIN_8      IN FLOAT,
               xIN_9      IN FLOAT,
               xIN_10     IN FLOAT)
AS
BEGIN
   IF (xID=0) THEN
      INSERT INTO CUOTAS_IAE(MUNICIPIO,YEAR,CUOTA,RECARGO,
             IN_1,IN_2,IN_3,IN_4,IN_5,IN_6,IN_7,IN_8,IN_9,IN_10)
      VALUES(xMUNICIPIO, xYEAR, xCUOTA, xRECARGO, xIN_1,
             xIN_2, xIN_3, xIN_4, xIN_5, xIN_6, xIN_7, xIN_8,
             xIN_9, xIN_10);
   ELSE
      UPDATE CUOTAS_IAE SET CUOTA=xCUOTA,RECARGO=xRECARGO,
             IN_1=xIN_1,IN_2=xIN_2,IN_3=xIN_3,
               IN_4=xIN_4,IN_5=xIN_5,IN_6=xIN_6,
             IN_7=xIN_7,IN_8=xIN_8,IN_9=xIN_9,IN_10=xIN_10
      WHERE ID=xID;
   END IF;
END;
/

/********************************************************************************
Acción: Para indicar si tenemos en cuenta o no el índice de situación a la hora
        de generar el padrón.
********************************************************************************/

CREATE OR REPLACE PROCEDURE MOD_INDICE_IAE(
               xMUNICIPIO IN VARCHAR2,
               xINDICE    IN CHAR)
AS
BEGIN
   UPDATE DATOSPER SET IAE_CALLES_INDICE=xINDICE
   WHERE  MUNICIPIO=xMUNICIPIO;
END;
/

/********************************************************************************
Acción: Para indicar por Municipio a qué epígrafes sólo se les hará un cálculo anual.
********************************************************************************/

CREATE OR REPLACE PROCEDURE RELLENA_IAE_EPIGRAFE(
               xMUNICIPIO IN VARCHAR2,
               xEPIGRAFE  IN CHAR,
               xSECCION   IN CHAR,
		   xTIPO_ACTI IN CHAR,
               xTIPO      IN CHAR)
AS
BEGIN
   IF (XTIPO='B') THEN
        DELETE FROM IAE_EPIGRAFE WHERE MUNICIPIO=xMUNICIPIO;
   ELSE
        INSERT INTO IAE_EPIGRAFE(MUNICIPIO,EPIGRAFE,SECCION,TIPO_ACTIVIDAD)
        VALUES(xMUNICIPIO,xEPIGRAFE,xSECCION,xTIPO_ACTI);
   END IF;
END;
/

/********************************************************************************
Acción: PARA RECIBOS DOMICILIADOS Y NO DOMICILIADOS DE LA CAIXA
MODIFICACIÓN: 20/09/2001 M. Carmen Junco Gómez. Se seleccionaban de IAE datos
		  que ya están en la tabla de Recibos de IAE.
MODIFICACIÓN: 20/09/2001 M. Carmen Junco Gómez. Adaptación al Euro. En las descripciones no
		  podemos hacer to_char(float) porque se redondean los importes.
********************************************************************************/

CREATE OR REPLACE PROCEDURE Proc_Caixa_IAE (
	 xMUNICIPIO  CHAR,
	 xYear 	 char,
	 xPeri 	 char)
AS
	xAbonado 			Integer;
	xTotal			FLOAT;
	x2 				char(40);
	x3 				char(40);
	x4 				char(40);
	x5 				char(40);
	x6 				char(40);
	x7 				char(40);
	x8 				char(40);
	x9 				char(40);
	x10 				char(40);
	x11 				char(40);
	x12				char(40);
	x13				char(40);
	x14				char(40);

	i 				integer;
	xRegis 			integer;

	xBASE_LIQUIDABLE		FLOAT;
	xNOMBRE_VIA			CHAR(25);
	xESCALERA			CHAR(2);
	xPLANTA			CHAR(3);
	xPUERTA			CHAR(3);
	xPRIMER_Numero 		char(6);

	xNOM_EPI			char(50);

	CURSOR CRECIAE IS
	  select * FROM recibos_IAE
		WHERE MUNICIPIO=xMUNICIPIO and year=xYear and periodo=xPeri AND TOTAL>0;

BEGIN

	DELETE FROM RECIBOS_CAIXA WHERE USUARIO=USER;
	xRegis:=0;

	select count(*) into xRegis
	FROM recibos_IAE
      WHERE municipio=xMunicipio and year=xYear and periodo=xPeri AND TOTAL>0;

	FOR v_TIAE IN CRECIAE LOOP

		begin
		   SELECT NOMBRE INTO xNOM_EPI FROM EPIGRAFE
		   WHERE ID=v_TIAE.ID_EPIGRAFE;
		   EXCEPTION
		      WHEN NO_DATA_FOUND THEN
			   xNOM_EPI:='';
		end;

		i:=13;
		/*domicilio tributario*/
		x2:='CALLE: '||v_TIAE.CALLE;
		x3:='NUMERO: '||v_TIAE.Numero;
		x4:='ESCALERA: '||v_TIAE.Escalera;
		x5:='PLANTA: '||v_TIAE.Planta;
		x6:='PUERTA: '||v_TIAE.Puerta;

		x7:='CUOTA MINIMA: '||v_TIAE.CUOTA_MINIMA;
		x8:='CUOTA BONIFI: '||v_TIAE.CUOTA_BONI;
		x9:='CUOTA INCRE.: '||v_TIAE.CUOTA_INCRE;
		x10:='CUOTA MUNIC.: '||v_TIAE.CUOTA_MUNI;
		x11:='RECARGO: '||v_TIAE.RECARGO;
		x12:='EPIGRAFE: '||v_TIAE.EPIGRAFE||' SECCION: '||v_TIAE.SECCION;
		x13:=SUBSTR(xNOM_EPI,1,39);
		x14:='REFERENCIA: '||v_TIAE.REFE;

		INSERT INTO RECIBOS_CAIXA
			(ABONADO,NIF,NOMBRE,DOMICILIO,CODPOSTAL,MUNICIPIO,
			ENTIDAD,SUCURSAL,DC,CUENTA,
			TOTAL, Campo2, Campo3, Campo4, Campo5, Campo6, Campo7,
			Campo8, Campo9, Campo10, Campo11, Campo12, Campo13, Campo14,
			CAMPOS_OPCIONALES, CUANTOS_REGISTROS)
		VALUES
			(v_TIAE.RECIBO, v_TIAE.NIF, v_TIAE.Nombre, substr(v_TIAE.Domicilio,1,40),
			v_TIAE.Codigo_Postal, v_TIAE.Poblacion,
			v_TIAE.Entidad, v_TIAE.Sucursal, v_TIAE.DC, v_TIAE.Cuenta,
			v_TIAE.TOTAL*100, x2, x3, x4, x5, x6, x7, x8, x9, x10, x11, x12,x13,x14,
			i, xRegis);
	END LOOP;

END;
/

-- ********************************************************************************
-- Autor: M. Carmen Junco Gómez. 09/02/2002
-- Acción: Para recibos domiciliados y no domiciliados de Caja Madrid
--
-- Modificado: 16/09/2003. Lucas Fernández Pérez. 
--   Se añaden los campos Coef.Ponderacion y Total.
-- ********************************************************************************

CREATE OR REPLACE PROCEDURE Proc_CajaMadrid_IAE (
	 xMUNICIPIO  CHAR,
	 xYear 	 char,
	 xPeri 	 char)
AS
	xAbonado 			Integer;
	xTotal			FLOAT;
	x1				CHAR(40);
	x2 				char(40);
	x3 				char(40);
	x4 				char(40);
	x5 				char(40);
	x6 				char(40);
	x7 				char(40);
	x8 				char(40);
	x9 				char(40);
	x10 				char(40);
	x11 				char(40);
	x12				char(40);
	x13				char(40);
	x14				char(40);
	x15				char(40);

	i 				integer;
	xRegis 			integer;

	xBASE_LIQUIDABLE		FLOAT;
	xCoef_Ponderacion		FLOAT;
	xNOMBRE_VIA			CHAR(25);
	xESCALERA			CHAR(2);
	xPLANTA			CHAR(3);
	xPUERTA			CHAR(3);
	xPRIMER_Numero 		char(6);
	xPAIS				char(35);

	xNOM_EPI			char(50);

	CURSOR CRECIAE IS
	  select * FROM recibos_IAE
		WHERE MUNICIPIO=xMUNICIPIO and year=xYear and periodo=xPeri AND TOTAL>0;

BEGIN

	DELETE FROM RECIBOS_CAJAMADRID WHERE USUARIO=USER;
	xRegis:=0;

	select count(*) into xRegis
	FROM recibos_IAE
      WHERE municipio=xMunicipio and year=xYear and periodo=xPeri AND TOTAL>0;

	FOR v_TIAE IN CRECIAE LOOP

		begin
		   SELECT NOMBRE INTO xNOM_EPI FROM EPIGRAFE
		   WHERE ID=v_TIAE.ID_EPIGRAFE;
		   EXCEPTION
		      WHEN NO_DATA_FOUND THEN
			   xNOM_EPI:='';
		end;

		begin
		   SELECT PAIS INTO xPAIS FROM CONTRIBUYENTES
		   WHERE NIF=v_TIAE.NIF;
		   Exception
			When no_data_found then
			   xPAIS:=NULL;
		end;

    	SELECT COEF_PONDERACION INTO xCoef_Ponderacion 
    	FROM IAE WHERE ID=v_TIAE.ABONADO;

    	i:=15;

		--domicilio tributario
		x1:='CALLE: '||v_TIAE.CALLE;
		x2:='NUMERO: '||v_TIAE.Numero;
		x3:='ESCALERA: '||v_TIAE.Escalera;
		x4:='PLANTA: '||v_TIAE.Planta;
		x5:='PUERTA: '||v_TIAE.Puerta;

		x6:='CUOTA MINIMA: '||v_TIAE.CUOTA_MINIMA;
		x7:='CUOTA BONIFI: '||v_TIAE.CUOTA_BONI;
		x8:='CUOTA INCRE.: '||v_TIAE.CUOTA_INCRE;
		x9:='CUOTA MUNIC.: '||v_TIAE.CUOTA_MUNI;
		x10:='RECARGO: '||v_TIAE.RECARGO;
		x11:='EPIGRAFE: '||v_TIAE.EPIGRAFE||' SECCION: '||v_TIAE.SECCION;
		x12:=SUBSTR(xNOM_EPI,1,39);
		x13:='REFERENCIA: '||v_TIAE.REFE;
		x14:='COEF.PONDER.: '||xCoef_Ponderacion;
		x15:='IMPORTE TOTAL: '||v_TIAE.TOTAL;

		INSERT INTO RECIBOS_CAJAMADRID
		   (ABONADO,NIF,NOMBRE,DOMICILIO,CODPOSTAL,POBLACION,PROVINCIA,PAIS,
			REFERENCIA,DOMICILIADO,ENTIDAD,SUCURSAL,DC,CUENTA,
			TOTAL, Campo1, Campo2, Campo3, Campo4, Campo5, Campo6, Campo7, 
			Campo8, Campo9, Campo10, Campo11, Campo12, Campo13,Campo14,Campo15,
			CAMPOS_OPCIONALES, CUANTOS_REGISTROS)
		VALUES
		   (v_TIAE.RECIBO, v_TIAE.NIF, v_TIAE.Nombre, substr(v_TIAE.Domicilio,1,40),
			v_TIAE.Codigo_Postal, v_TIAE.Poblacion,v_TIAE.Provincia,xPAIS,
			DECODE(v_TIAE.DOMICILIADO,'S',v_TIAE.REFERENCIA||v_TIAE.DIGITO_CONTROL,v_TIAE.REFERENCIA),
			DECODE(v_TIAE.DOMICILIADO,'S','D',' '),
			v_TIAE.Entidad, v_TIAE.Sucursal, v_TIAE.DC, v_TIAE.Cuenta,v_TIAE.TOTAL*100, 
			x1, x2, x3, x4, x5, x6, x7, x8, x9, x10, x11, x12, x13, x14, x15,
			i, xRegis);

	END LOOP;

END;
/

/********************************************************************************
Acción: Corrección de los códigos de calle en la tabla IAE.
********************************************************************************/

CREATE OR REPLACE PROCEDURE CORREGIR_CALLES (
		xMUNICIPIO IN CHAR,
		xYEAR      IN CHAR,
		xPERIODO   IN CHAR)
AS
   xCODIGO_VIA CHAR(4);
   CURSOR CIAE IS SELECT * FROM IAE WHERE MUNICIPIO=xMUNICIPIO
                  AND YEAR=xYEAR AND PERIODO=xPERIODO
			AND CODIGO_VIA IS NULL
	FOR UPDATE OF CODIGO_VIA;
BEGIN

   FOR v_IAE IN CIAE LOOP

      xCODIGO_VIA:=NULL;

      SELECT MAX(CODIGO_CALLE) INTO xCODIGO_VIA
      FROM CALLES WHERE MUNICIPIO=xMUNICIPIO AND rtrim(CALLE)=rtrim(v_IAE.CALLE_ACTIVIDAD);

      IF xCODIGO_VIA IS NOT NULL THEN
	   UPDATE IAE SET CODIGO_VIA=xCODIGO_VIA WHERE CURRENT OF CIAE;
      END IF;

   END LOOP;

END;
/

/********************************************************************************
Autor: Mª del Carmen Junco Gómez. 14/05/2002
Acción: Calcular el importe de una liquidación de IAE dadas la cuota máquina y
	  el importe mínimo
MODIFICACIÓN: 30/09/2002 M. Carmen Junco Gómez. Se añade el año en las cuotas del
		  IAE para liquidar años anteriores.
********************************************************************************/

CREATE OR REPLACE PROCEDURE IAE_LIQUIDAR(
		xID				IN	INTEGER,
		xMAQUINA		IN	FLOAT,
		xMINIMA			IN	FLOAT,
		xTOTAL	    	OUT   FLOAT,
		xCUOTA_MINIMA   OUT FLOAT,
		xIMPORTE_MINIMO OUT FLOAT,
		xPORCENT_BENE   OUT FLOAT,
		xCUOTA_BONI	    OUT FLOAT,
		xCUOTA_INCRE    OUT FLOAT,
		xCUOTA_MUNI     OUT FLOAT,
	    xRECARGO	    OUT FLOAT,
	    xCUOTA_MAQUINA  OUT FLOAT)
AS
   v_IAE IAE%ROWTYPE;

   xINDICE_CALLE       FLOAT;
   xCOEFI_INCREMENTO   FLOAT;

BEGIN
   -- recogemos todos los datos del registro de IAE que se va a liquidar
   SELECT * INTO v_IAE FROM IAE WHERE ID=xID;

   xCUOTA_MAQUINA:=xMAQUINA;
   xCUOTA_MINIMA:=xMINIMA;

   --inicializamos valores
   xCUOTA_INCRE:=0;
   xRECARGO:=0;
   xIMPORTE_MINIMO:=0;

   --Vemos el índice de situación de la calle, y el coeficiente de incremento y recargo
   CALCULA_INDICE_CALLE(v_IAE.MUNICIPIO, v_IAE.YEAR, v_IAE.CODIGO_VIA,v_IAE.NUMERO_ACTIVI,
 				xINDICE_CALLE,xCOEFI_INCREMENTO,xRECARGO);

   IF xINDICE_CALLE IS NULL THEN
      xINDICE_CALLE:=1;  --Valor por defecto del índice de calle
   END IF;

   --Si se ha dado de baja debemos comprobar hasta que trimestre
   --del año en el que se da de baja la actividad se ha de pagar
   IF v_IAE.F_BAJA IS NOT NULL THEN
      COMPRUEBA_BAJA(v_IAE.PERIODO,
	               v_IAE.F_BAJA,
			   v_IAE.FECHA_INICIO_ACTI,
			   xIMPORTE_MINIMO,
			   xCUOTA_MINIMA,
			   xCUOTA_MAQUINA);

   ELSE  --No se ha dado de baja
      IF (v_IAE.PERIODO='00' OR v_IAE.PERIODO='01') THEN
              xIMPORTE_MINIMO:=xCUOTA_MINIMA;
      ELSIF (v_IAE.PERIODO='02') THEN
	        xIMPORTE_MINIMO:=(xCUOTA_MINIMA*3)/4;
	        xCUOTA_MAQUINA:=(xCUOTA_MAQUINA*3)/4;
      ELSIF (v_IAE.PERIODO='03') THEN
              xIMPORTE_MINIMO:=xCUOTA_MINIMA/2;
 	        xCUOTA_MAQUINA:=xCUOTA_MAQUINA/2;
      ELSIF (v_IAE.PERIODO='04') THEN
	        xIMPORTE_MINIMO:=xCUOTA_MINIMA/4;
   	        xCUOTA_MAQUINA:=xCUOTA_MAQUINA/4;
	END IF;
   END IF;

   --Se aplica bonificación, si procede
   IAE_BONIFICACION(TO_NUMBER(v_IAE.BENEFICIOS_PORCEN),v_IAE.FECHA_LIMITE_BENE,
	 		  xIMPORTE_MINIMO,xCUOTA_MAQUINA,xCUOTA_BONI);

   xIMPORTE_MINIMO:=Round(xIMPORTE_MINIMO,2);
   xCUOTA_MAQUINA:=Round(xCUOTA_MAQUINA,2);
   xCUOTA_BONI:=Round(xCUOTA_BONI,2);

   --Cuota incrementada: cuota de tarifa con maquina * coeficiente de incremento
   xCUOTA_INCRE:=Round((xCUOTA_BONI * v_IAE.COEF_PONDERACION),2);

   --Cuota municipal:
   --(Cuota tarifa sin maquina * coeficiente de ponderacion) * indice de situacion +
   --cuota maquina * coeficiente de ponderacion
   xCUOTA_MUNI:=Round((((xCUOTA_BONI-xCUOTA_MAQUINA) * v_IAE.COEF_PONDERACION) 
            * xINDICE_CALLE
		    + (xCUOTA_MAQUINA * v_IAE.COEF_PONDERACION)),2);

   --Recargo 40%: la cuota tarifa que ya tiene la cuota maquina incluida * 40%
   xRECARGO:=Round(((xCUOTA_BONI * v_IAE.COEF_PONDERACION) * xRECARGO * 0.01),2);

   --Total a pagar
   xTOTAL:=Round((xRECARGO+ xCUOTA_MUNI),2);

   --Porcentaje de Bonificacion
   xPORCENT_BENE:=TO_NUMBER(v_IAE.BENEFICIOS_PORCEN);


END;
/

/***************************************************************************************/
--Autor: M. Carmen Junco Gómez. 17/05/2002
--Acción: Al dar de alta una liquidación manual de IAE, se comprobará si el recibo o liquidación
--	  que se corrige con esta nueva liquidación está en Recaudación.
--	  Si es así y está pendiente, se dará de baja.
-- Parámetros: xABONADO: Abonado de IAE al que se le está practicando la liquidación.
--		xIDNEW: ID de la nueva liquidación.
/***************************************************************************************/

CREATE OR REPLACE PROCEDURE IAE_COMPROBAR_RECA(
	xABONADO	IN	INTEGER,
	xIDNEW	IN	INTEGER)
AS
   xIDRECIBO INTEGER;
   xIDOLD    INTEGER;
   xIDVALOR  INTEGER;
   xF_INGRESO DATE;
   xF_BAJA    DATE;
   xRECIBO  INTEGER;
   xCONCEPTO CHAR(6);
   xLIQUIDACION CHAR(6);
   v_IAE IAE%ROWTYPE;
   xERROR INTEGER;
BEGIN

   -- recogemos los datos del abonado al que le estamos generando la liquidación
   SELECT * INTO v_IAE FROM IAE WHERE ID=xABONADO;

   -- el número de recibo va a ser el ID de la tabla de REFERENCIAS_BANCOS
   SELECT ID INTO xRECIBO FROM REFERENCIAS_BANCOS
   WHERE MUNICIPIO=v_IAE.MUNICIPIO AND YEAR=v_IAE.YEAR AND
	   PERIODO=v_IAE.PERIODO AND REFERENCIA_IAE=v_IAE.REFERENCIA;

   -- recogemos el concepto asociado a las liquidaciones de IAE
   begin
      SELECT CONCEPTO,LIQUIDACION INTO xCONCEPTO,xLIQUIDACION
      FROM PROGRAMAS WHERE PROGRAMA='IAE';
      Exception
	   When no_data_found then
		xCONCEPTO:=NULL;
		xLIQUIDACION:=NULL;
   end;

   -- Buscamos si el recibo correspondiente está generado
   begin
      SELECT ID INTO xIDRECIBO FROM RECIBOS_IAE
	WHERE MUNICIPIO=v_IAE.MUNICIPIO AND YEAR=v_IAE.YEAR AND
            PERIODO=v_IAE.PERIODO AND RECIBO=xRECIBO;
	Exception
	   When no_data_found then
            xIDRECIBO:=0;
   end;

   -- buscamos si hay una liquidación generada
   begin
	SELECT ID INTO xIDOLD FROM LIQUIDACIONES
      WHERE MUNICIPIO=v_IAE.MUNICIPIO AND CONCEPTO=xLIQUIDACION AND
            YEAR=v_IAE.YEAR AND PERIODO=v_IAE.PERIODO AND NUMERO=xRECIBO;
      Exception
         When no_data_found then
	      xIDOLD:=0;
   end;

   -- Si está generado el recibo (o la liquidación), comprobamos si se encuentra en
   -- Recaudación y su estado. Si está ingresada no haremos nada; si está pendiente
   -- lo daremos de baja

   -- Primero comprobamos el recibo
   IF xIDRECIBO<>0 THEN
      begin
         SELECT ID,F_INGRESO,FECHA_DE_BAJA INTO xIDVALOR,xF_INGRESO,xF_BAJA FROM VALORES
	   WHERE AYTO=v_IAE.MUNICIPIO AND PADRON=xCONCEPTO AND
		   YEAR=v_IAE.YEAR AND PERIODO=v_IAE.PERIODO AND RECIBO=xRECIBO;
	   Exception
	      When no_data_found then
	         xIDVALOR:=0;
	end;

	-- si el recibo está en Recaudación y no se encuentra ni ingresado ni dado de baja,
	-- lo damos de baja nosotros
	IF ((xIDVALOR<>0) AND (xF_INGRESO IS NULL) AND (xF_BAJA IS NULL)) THEN
         MAKE_BAJA(xIDVALOR,'BA',SYSDATE,SYSDATE,'',
                  'Se da de baja el valor al dar de alta una Liquidación sobre el '||
                  'mismo objeto tributario',xERROR);
	END IF;
   END IF;

   -- Se comprueba también la liquidación
   IF xIDOLD<>0 THEN
	begin
	   SELECT ID,F_INGRESO,FECHA_DE_BAJA INTO xIDVALOR,xF_INGRESO,xF_BAJA FROM VALORES
	   WHERE AYTO=v_IAE.MUNICIPIO AND PADRON=xLIQUIDACION AND
		   YEAR=v_IAE.YEAR AND PERIODO=v_IAE.PERIODO AND RECIBO=xRECIBO;
         Exception
	      When no_data_found then
	         xIDVALOR:=0;
	end;

	-- si la liquidación está en Recaudación y no se encuentra ni ingresada ni dada de baja,
	-- la damos de baja nosotros
	IF ((xIDVALOR<>0) AND (xF_INGRESO IS NULL) AND (xF_BAJA IS NULL)) THEN
         MAKE_BAJA(xIDVALOR,'BA',SYSDATE,SYSDATE,'',
                  'Se da de baja el valor al dar de alta una Liquidación sobre el '||
                  'mismo objeto tributario',xERROR);
	END IF;

	-- Anulamos la liquidación en Gestión Tributaria
      UPDATE LIQUIDACIONES SET F_ANULACION=SYSDATE
	WHERE ID=xIDOLD AND F_INGRESO IS NULL AND F_ANULACION IS NULL;

	INSERT_HISTORIA_LIQUI(xIDOLD,'E','SE ANULA AL DAR DE ALTA OTRA LIQUIDACIÓN '||
				       'POR EL MISMO TRIBUTO');

	-- Relacionamos ambas liquidaciones
	UPDATE LIQUIDACIONES SET IDLIQUI=xIDNEW
	WHERE ID=xIDOLD;

   END IF;

END;
/

/******************************************************************************************
Acción: Rellena una tabla temporal para imprimir liquidaciones de IAE
MODIFICACIÓN: 30/09/2002 M. Carmen Junco Gómez. Se añade el año en las cuotas del IAE
		  para poder liquidar años anteriores.
MODIFICACIÓN: 26/08/2003 M. Carmen Junco Gómez. Se incluye el campo código de barras
		  en la tabla temporal para su impresión a través de Fast Report.
MODIFICACIÓN: 01/03/2004 Mª Carmen Junco Gómez. Se incluyen los campos COEF_PONDERACION y 
		  FECHA_INICIO_ACTI a petición de Ricardo de Torrejón.
******************************************************************************************/

CREATE OR REPLACE PROCEDURE ImprimeLiquiIAE(
			xYEAR 	IN CHAR,
			xPERI	IN CHAR,
			xMUNI	IN CHAR,
			xDESDE 	IN INTEGER,
			xHASTA 	IN INTEGER)
AS

	-- Datos de la liquidacion
	xCONCEPTO				CHAR(6);
	xNUMERO					CHAR(7);
	xNIF	 				CHAR(10);
	xNIFREP					CHAR(10);
	xDOMI_TRIBUTARIO		VARCHAR(60);
	xF_LIQUIDACION			DATE;
	xF_FIN_PE_VOL			DATE;
	xMOTIVO					VARCHAR(1024);
	xEMISOR					CHAR(6);

	xTRIBUTO 				CHAR(3);
	xEJER_C60 				CHAR(2);
	xREFERENCIA				CHAR(10);
	xDISCRI_PERIODO			CHAR(1);
	xDIGITO_YEAR 			CHAR(1);
	xF_JULIANA 				CHAR(3);
	xDIGITO_C60_MODALIDAD2 	CHAR(2);

	xCUOTA_INCREMENTADA 	FLOAT DEFAULT 0;
	xRECARGO_PROVINCIAL		FLOAT DEFAULT 0;
	xINDICE					FLOAT DEFAULT 0;
	xSUPERFICIE_DECLARADA	FLOAT DEFAULT 0;
	xSUPERFICIE_RECTIFICADA	FLOAT DEFAULT 0;
	xSUPERFICIE_COMPUTABLE	FLOAT DEFAULT 0;
	xYEAR_INICIO			CHAR(4);
	xFECHA_LIMITE			DATE;

	-- Datos del representante
	xNIFREPRE				CHAR(10);
	xNOMBREREPRE			VARCHAR(40);
	xDOMIREPRE				VARCHAR(200);
	xPOBLAREPRE				VARCHAR(200);

	xNOMBRE_EPIGRAFE		VARCHAR2(50); -- Epigrafes.
	xPadron					char(6);
	xTipo_Actividad   		char(12);
	
	xCOEF_PONDERACION		FLOAT;
	xFECHA_INICIO_ACTI		DATE;

	cursor cRecIAE is SELECT * FROM RECIBOS_IAE
			WHERE MUNICIPIO=xMuni AND YEAR=xYear AND PERIODO=xPeri
			AND RECIBO BETWEEN xDESDE AND xHASTA;
BEGIN


   SELECT LIQUIDACION INTO xPADRON FROM PROGRAMAS WHERE PROGRAMA='IAE';

   DELETE FROM TMP_IAE_LIQUIDACIONES WHERE USUARIO=USER;

   FOR vRec in cRecIAE LOOP


	-- Datos que se toman de la tabla de LIQUIDACIONES
	SELECT CONCEPTO,NUMERO,EMISOR,TRIBUTO,EJER_C60,REFERENCIA,DISCRI_PERIODO,DIGITO_YEAR,
		F_JULIANA,DIGITO_C60_MODALIDAD2,NIF,NIFREP,
		DOMI_TRIBUTARIO,F_LIQUIDACION,F_FIN_PE_VOL,MOTIVO
	INTO
		xCONCEPTO,xNUMERO,xEMISOR,xTRIBUTO,xEJER_C60,xREFERENCIA,xDISCRI_PERIODO,
		xDIGITO_YEAR,xF_JULIANA,xDIGITO_C60_MODALIDAD2,xNIF,xNIFREP,
		xDOMI_TRIBUTARIO,xF_LIQUIDACION,xF_FIN_PE_VOL,xMOTIVO
	FROM LIQUIDACIONES
	WHERE MUNICIPIO=vRec.MUNICIPIO AND CONCEPTO=xPADRON AND YEAR=vRec.YEAR
		AND PERIODO=vRec.PERIODO
		AND TO_NUMBER(NUMERO)=vRec.RECIBO;

	-- Datos del representante (se toman de la tabla de CONTRIBUYENTES)
	IF xNIFREP IS NULL THEN -- Los datos del representante son los del titular del recibo.
	   xNIFREPRE:=xNIF;
	   xNOMBREREPRE:=vREc.NOMBRE;
	   xDOMIREPRE:=vREc.DOMICILIO;
	   xPOBLAREPRE:=rtrim(vREc.CODIGO_POSTAL)||' '||rtrim(vREc.POBLACION)||' '
				||rtrim(vREc.PROVINCIA);

	ELSE -- Hay representante, se buscan sus datos fiscales
	   xNIFREPRE:=xNIFREP;

	   SELECT GETNOMBRE(xNIFREP),GETDOMICILIO(xNIFREP),GETCPPOBLAPROVI(NIF)
	   INTO xNOMBREREPRE,xDOMIREPRE,xPOBLAREPRE
  	   FROM CONTRIBUYENTES WHERE NIF=xNIFREP;
	END IF;

	-- Datos que se toman de la tabla CUOTAS_IAE
	CALCULA_INDICE_CALLE(xMUNI,xYEAR,vRec.CODIGO_VIA,vRec.NUMERO,
		xINDICE,xCuota_Incrementada,xRecargo_Provincial);

	-- Datos que se toman de la tabla EPIGRAFE
	begin
		SELECT NOMBRE INTO xNOMBRE_EPIGRAFE FROM EPIGRAFE WHERE ID=vRec.ID_EPIGRAFE;
	exception
		when no_data_found then
			xNOMBRE_EPIGRAFE:=null;
	end;

	IF vRec.TIPO_ACTIVIDAD='E' THEN
	   xTipo_Actividad:='EMPRESARIAL';
	ELSIF vRec.TIPO_ACTIVIDAD='P' THEN
	   xTipo_Actividad:='PROFESIONAL';
	ELSIF vRec.TIPO_ACTIVIDAD='A' THEN
	   xTipo_Actividad:='ARTISTICA';
	END IF;
	
	SELECT COEF_PONDERACION,FECHA_INICIO_ACTI
	INTO xCOEF_PONDERACION,xFECHA_INICIO_ACTI
	FROM IAE WHERE ID=vRec.ABONADO;

	INSERT INTO TMP_IAE_LIQUIDACIONES(
		MUNICIPIO,CONCEPTO,YEAR,PERIODO,NUMERO,NIF,
		NOMBRE,DOMICILIO,POBLACION,PROVINCIA,CODIGO_POSTAL,
		NOMBREREPRE,DOMIREPRE,POBLAREPRE,DOMI_TRIBUTARIO,
		F_LIQUIDACION,F_FIN_PE_VOL,MOTIVO,EMISOR,TRIBUTO,EJER_C60,REFERENCIA,
		DISCRI_PERIODO,DIGITO_YEAR,F_JULIANA,DIGITO_C60_MODALIDAD2,CODIGO_BARRAS,
		DESCRIPCION,NOMBRE_EPIGRAFE,
		EPIGRAFE,SECCION,TIPO_ACTIVIDAD,
		SUPERFICIE_DECLARADA,SUPERFICIE_RECTIFICADA,SUPERFICIE_COMPUTABLE,
		YEAR_INICIO,FECHA_LIMITE,
		REFE,	CUOTA_PERIODO,PORCENT_BENE,CUOTA_MINIMA,CUOTA_BONI,
		CUOTA_INCRE,CUOTA_MUNI,RECARGO,COEF_PONDERACION,FECHA_INICIO_ACTI,CUOTA_MAQUINA,TOTAL,
		INDICE, CUOTA_INCREMENTADA, RECARGO_PROVINCIAL)


	VALUES(
		vRec.MUNICIPIO,xCONCEPTO,vRec.YEAR,vRec.PERIODO,xNUMERO,xNIF,
		vRec.NOMBRE, vRec.DOMICILIO, vRec.POBLACION, vRec.PROVINCIA, vRec.CODIGO_POSTAL,
		xNOMBREREPRE,xDOMIREPRE,xPOBLAREPRE,xDOMI_TRIBUTARIO,
		xF_LIQUIDACION,xF_FIN_PE_VOL,xMOTIVO,xEMISOR,xTRIBUTO,xEJER_C60,xREFERENCIA,
		xDISCRI_PERIODO,xDIGITO_YEAR,xF_JULIANA,xDIGITO_C60_MODALIDAD2,
		
		'90521'||xEMISOR||xREFERENCIA||
		xDIGITO_C60_MODALIDAD2||xDISCRI_PERIODO||
		xTRIBUTO||xEJER_C60||xDIGITO_YEAR||
		xF_JULIANA||LPAD(vRec.TOTAL*100,8,'0') ||'0',  			 
		
		vRec.CONCEPTO,xNOMBRE_EPIGRAFE,
		vRec.EPIGRAFE,vRec.SECCION,xTIPO_ACTIVIDAD,
		vRec.SUPERFICIE_DECLARADA,vRec.SUPERFICIE_RECTIFICADA,vRec.SUPERFICIE_COMPUTABLE,
		vRec.YEAR_INICIO,vRec.FECHA_LIMITE,
		vRec.REFE,vRec.CUOTA_PERIODO,vRec.PORCENT_BENE,vRec.CUOTA_MINIMA,vRec.CUOTA_BONI,
		vRec.CUOTA_INCRE,vRec.CUOTA_MUNI,vRec.RECARGO,xCOEF_PONDERACION,xFECHA_INICIO_ACTI,
		vRec.CUOTA_MAQUINA,vRec.TOTAL,
		xINDICE, xCUOTA_INCREMENTADA, xRECARGO_PROVINCIAL);

   END LOOP;

end;
/
/********************************************************************/
COMMIT;
/********************************************************************/
