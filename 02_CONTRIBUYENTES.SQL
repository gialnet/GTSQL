
--
-- PARA QUE A LA HORA DE HACER VISTAS NO SALGA EL CAMPO DOMICILIO NULO
--
-- Modificación: 05/02/2007. Lucas Fernández Pérez. Nuevos campos BLOQUE Y PORTAL de la tabla de CONTRIBUYENTES
--

CREATE OR REPLACE TRIGGER T_INS_CONTRI
BEFORE INSERT ON CONTRIBUYENTES
FOR EACH ROW
BEGIN

	IF (:NEW.VIA IS NULL) THEN
		:NEW.VIA:='';
	END IF;

	IF (:NEW.CALLE IS NULL) THEN
		:NEW.CALLE:='';
	END IF;

	IF (:NEW.NUMERO IS NULL) THEN
		:NEW.NUMERO:='';
	END IF;

	IF (:NEW.BLOQUE IS NULL) THEN
		:NEW.BLOQUE:='';
	END IF;
	
	IF (:NEW.PORTAL IS NULL) THEN
		:NEW.PORTAL:='';
	END IF;

	IF (:NEW.ESCALERA IS NULL) THEN
		:NEW.ESCALERA:='';
	END IF;

	IF (:NEW.PLANTA IS NULL) THEN
		:NEW.PLANTA:='';
	END IF;

	IF (:NEW.PISO IS NULL) THEN
		:NEW.PISO:='';
	END IF;

END T_INS_CONTRI;
/

/* devuelve el codigo postal, poblacion y provincia de un nif */
CREATE OR REPLACE FUNCTION GETCPPOBLAPROVI (xNIF IN CONTRIBUYENTES.NIF%TYPE)
RETURN CHAR
AS
   v_Poblacion CHAR(80);
BEGIN
   SELECT CODIGO_POSTAL||' '||POBLACION||' '||PROVINCIA
   INTO v_Poblacion
   FROM CONTRIBUYENTES
   WHERE NIF=xNIF;

   RETURN v_Poblacion;
END;
/


/* *******************************************************************************
Autor: Agustin Leon Robles
Fecha: 20 Agosto 2.001
Devuelve un domicilio concatenado mas poblacion,provincia y codigo postal, de un
Deudor o de su domicilio alternativo, cuando el campo xIDALTERNATIVO es nulo buscamos
en el domicilio fiscal del contribuyente
MODIFICACIÓN: 19/10/2001 M. Carmen Junco Gómez. Se incluye la comprobación
		  xNif is not null porque si el nif estaba nulo como parámetro el
		  select no devuelve valores y fallan los procedimientos que llaman
  		  a éste.
MODIFICACIÓN: 05/02/2007. Lucas Fernández Pérez. Accede a la nueva vista vwContribuyentes
		  y a los nuevos campos de bloque y portal
********************************************************************************************** */
CREATE OR REPLACE PROCEDURE GetDomicilioFiscal
	(xNIF 	IN Contribuyentes.NIF%TYPE,
 	 xIDALTERNATIVO in int,
	 xDomicilio OUT VARCHAR2,
	 xPoblacion OUT Contribuyentes.POBLACION%TYPE,
	 xProvincia OUT Contribuyentes.PROVINCIA%TYPE,
	 xCodPostal OUT Contribuyentes.CODIGO_POSTAL%TYPE)
AS
BEGIN

  IF xIDALTERNATIVO IS NOT NULL THEN
 	 SELECT trim(via)||' '||trim(calle)||' '||trim(numero)||' '||trim(bloque)||' '||trim(portal)||' '||trim(escalera)
		||' '||trim(planta)||' '||trim(piso) as domicilio,
	    POBLACION,PROVINCIA,CODIGO_POSTAL
	 INTO xDomicilio,xPoblacion,xProvincia,xCodPostal
	 FROM DOMICILIOS_ALTERNATIVOS
 	 WHERE ID=xIDALTERNATIVO;
  ELSE
     IF xNIF IS NOT NULL THEN
	    select Domicilio,Poblacion,Provincia,codigo_postal
	    into xDomicilio,xPoblacion,xProvincia,xCodPostal
	    from vwContribuyentes where nif=xNIF;
     END IF;
  END IF;

END;
/


/********************************************************************************
Acción: Devuelve el domicilio alternativo de un nif. 
Autor: Agustin Leon Robles
Fecha: 29 Agosto 2.001
MODIFICACIÓN: 05/02/2007. Lucas Fernández Pérez. Accede a los nuevos campos de bloque y portal
*********************************************************************************/

CREATE or replace FUNCTION DameDomiAlternativo (
	xID IN DOMICILIOS_ALTERNATIVOS.ID%TYPE)
RETURN VARCHAR2
AS
xDomicilio varchar2(150);
BEGIN

	select trim(VIA)||' '||trim(CALLE)||' '||trim(NUMERO)||' '||trim(BLOQUE)||' '||trim(PORTAL)||' '||trim(ESCALERA)
		||' '||trim(PLANTA)||' '||trim(PISO)
		||' '||trim(CODIGO_POSTAL) ||' '|| trim(POBLACION)||' '||trim(PROVINCIA)
		into xDomicilio
	from domicilios_alternativos where ID=xID;

	return rtrim(xDomicilio);
END;
/

/* recoger los datos de un contribuyente 
MODIFICACIÓN: 05/02/2007. Lucas Fernández Pérez. Accede a la nueva vista vwContribuyentes
		  y a los nuevos campos de bloque y portal
*/
CREATE OR REPLACE PROCEDURE GETContribuyente(
	xNIF IN Contribuyentes.NIF%TYPE,
	xNombre OUT Contribuyentes.NOMBRE%TYPE,
	xPoblacion OUT Contribuyentes.POBLACION%TYPE,
	xProvincia OUT Contribuyentes.PROVINCIA%TYPE,
	xCodPostal OUT Contribuyentes.CODIGO_POSTAL%TYPE,
	xDomicilio OUT VARCHAR2
)
as
v_RegistroContri Contribuyentes%ROWTYPE;
BEGIN

   xNombre:='';
   xPoblacion:='';
   xProvincia:='';
   xCodPostal:='';

   begin
      SELECT NOMBRE,DOMICILIO,POBLACION,PROVINCIA,CODIGO_POSTAL 
      INTO xNombre,xDomicilio,xPoblacion,xProvincia,xCodPostal
      from vwContribuyentes
      where nif=xNIF;

	Exception
	   When no_data_found then
		null;
   end;

END;
/


CREATE OR REPLACE TRIGGER TR_ADD_TRIBUTOS_CONTRI
BEFORE INSERT ON TributosContri
FOR EACH ROW
BEGIN
   SELECT GENTributosContri.NextVal INTO :NEW.ID From Dual;
END;
/


/* *********************************** */
/* Domiciliaciones de un contribuyente */
CREATE OR REPLACE TRIGGER TR_ADD_DOMI_CONTRI
BEFORE INSERT ON DomiContri
FOR EACH ROW
BEGIN
	SELECT GENDomiContri.NextVal INTO :NEW.ID From Dual;
END;
/


/****************************************************************************************
-- ultima modificacion: 19 de Noviembre 2001 Agustin Leon Robles
--				Se ha añadido que en el IAE cuando sean trimestres que siempre genere
--				una nueva referencia. Ejemplo: en el primer trimestre viene un alta
--				y en el tercer trimestre viene la baja, no se podria generar
--				liquidacion porque se repetiria el mismo numero de liquidacion.
-- última modificación: 2 de Enero del 2.002 Antonio Pérez Caballero
-- última modificación: 3 de Enero del 2.002 Antonio Pérez Caballero
-- Modificación: 08/05/2006 M. Carmen Junco Gómez. Adapatación al cambio de formato de Rústica.
****************************************************************************************/
CREATE OR REPLACE PROCEDURE INSERTA_REFERENCIA_BANCO (
      xMUNICIPIO	IN 	CHAR,
	 	xYEAR			IN 	CHAR,
	 	xPERIODO		IN 	CHAR,
	 	xNIF			IN		CHAR,
	 	xREFRUSTICA	IN    CHAR,
      xREFCAT 		IN 	CHAR,
      xREFIAE 		IN 	CHAR)
AS
	xCONT	INTEGER;
BEGIN

	-- RUSTICA SE COMPRUEBA EL NIF o CLAVE DE IDENTIFICACIÓN
	IF (xREFRUSTICA IS NOT NULL) THEN

		UPDATE REFERENCIAS_BANCOS set YEAR=xYEAR
		WHERE MUNICIPIO=xMUNICIPIO AND REF_RUSTICA=xREFRUSTICA;

		if SQL%NOTFOUND then

		   INSERT INTO REFERENCIAS_BANCOS
				(MUNICIPIO,YEAR,NIF,REF_RUSTICA)
		   VALUES 
		   	(xMUNICIPIO,xYEAR,xNIF,xREFRUSTICA);

		end if;
	END IF;

	-- PARA EL IBI SE COMPRUEBA LA REF. CATASTRAL
	IF (xREFCAT IS NOT NULL) THEN

		-- Comprobar si existe esta referencia para este municipio
	      UPDATE REFERENCIAS_BANCOS SET YEAR=xYEAR
				WHERE MUNICIPIO=xMUNICIPIO
				AND REF_CATASTRAL=xREFCAT;

		if SQL%NOTFOUND then
		   INSERT INTO REFERENCIAS_BANCOS( MUNICIPIO, YEAR, REF_CATASTRAL, NIF)
				VALUES (xMUNICIPIO, xYEAR, xREFCAT, xNIF);
		end if;
	END IF;

	-- PARA EL IAE SE COMPRUEBA LA REFERENCIA
	IF (xREFIAE IS NOT NULL) THEN

		--cuando se trata del padron anual sólo se modifica el año
		if xPERIODO='00' then

			update REFERENCIAS_BANCOS set YEAR=xYEAR
					WHERE MUNICIPIO=xMUNICIPIO
						AND REFERENCIA_IAE=xREFIAE
						AND PERIODO=xPERIODO;

			if SQL%NOTFOUND then
			   INSERT INTO REFERENCIAS_BANCOS(MUNICIPIO,YEAR,PERIODO,REFERENCIA_IAE,NIF)
			   VALUES (xMUNICIPIO, xYEAR, xPERIODO, xREFIAE, xNIF);
			end if;

		else
			-- En caso de trimestres solo se inserta sino existe. Cada trimestre tendra
			-- nuevas referencias aunque exista la referencia.
			SELECT COUNT(*) INTO xCONT FROM REFERENCIAS_BANCOS
					WHERE MUNICIPIO=xMUNICIPIO
						AND REFERENCIA_IAE=xREFIAE
						AND PERIODO=xPERIODO;
			if (xCont=0) then
			   INSERT INTO REFERENCIAS_BANCOS(MUNICIPIO,YEAR,PERIODO,REFERENCIA_IAE, NIF)
			   VALUES (xMUNICIPIO, xYEAR, xPERIODO, xREFIAE, xNIF);
			end if;

		end if;

	END IF;
END;
/


/* *******************************************************************************
Autor: Antonio Pérez Caballero
Fecha: 7 Agosto 2.001
Devuelve un string de caracteres con la palabra 'DOMICILIADO' O '--NO ESTA--'
Se utilizó la primera vez para un JSP que nos devuelve la relación de tributos y
si esta domiciliado Tributos.jsp
Modificación: 15/05/2006 M. Carmen Junco Gómez. Adaptación al nuevo formato de RUSTICA
   ******************************************************************************* */
CREATE OR REPLACE FUNCTION EstaDomiciliado(PROGRAMA in char,ID_CONCEPTO in int)
RETURN CHAR
AS
xDOMI CHAR(1):='N';
BEGIN

IF PROGRAMA='VEHICULOS' THEN
   SELECT DOMICILIADO INTO xDOMI FROM VEHICULOS WHERE ABONADO=ID_CONCEPTO;
END IF;

IF PROGRAMA='EXACCIONES' THEN
   SELECT DOMICILIADO INTO xDOMI FROM EXACCIONES WHERE ABONADO=ID_CONCEPTO;
END IF;

IF PROGRAMA='AGUA' THEN
   SELECT DOMICILIADO INTO xDOMI FROM AGUA WHERE ID=ID_CONCEPTO;
END IF;

IF PROGRAMA='IAE' THEN
   SELECT DOMICILIADO INTO xDOMI FROM IAE WHERE ID=ID_CONCEPTO;
END IF;

IF PROGRAMA='IBI' THEN
   SELECT DOMICILIADO INTO xDOMI FROM IBI WHERE ID=ID_CONCEPTO;
END IF;

IF PROGRAMA='RUSTICA' THEN
   SELECT DOMICILIADO INTO xDOMI FROM RUS_TITULARES WHERE ID=ID_CONCEPTO;
END IF;

if xDOMI='S' then
   RETURN 'DOMICILIADO';
else
   RETURN '--NO ESTA--';
end if;

END;
/


--
-- Registrar la asistencia en GT
--'PL': CAMBIO DE TITULARIDAD EN IBI DESDE PLUSVALIAS;
--'IB': MODIFICACIÓN DATOS FISCALES Y TRIBUTARIOS EN IBI;
--'RU': MODIFICACIÓN DATOS FISCALES EN RUSTICA;
--'LQ': LIQUIDACIONES DIRECTAS
--'AG': ALTA-BAJA EN AGUAS
--'AV': ALTA-BAJA EN VEHICULOS
--'AX': ALTA-BAJA EN EXACCIONES
--'MU': ALEGACION EN MULTAS DE TRAFICO
--'RE': SOLICITUD EN EL REGISTRO DE ENTRADA/SALIDA
--'AI': ACTA DE INSPECCIÓN DE TRIBUTOS
CREATE OR REPLACE PROCEDURE NewAsistenciaGT(
	xID		IN INTEGER,
	xNIF		IN CHAR,
	xMOTIVO	IN CHAR,
	xVALIDA	IN CHAR)
AS
BEGIN
   INSERT INTO ASISTENCIA (IDINGRESO,NIF,MOTIVO,VALIDA,GTR)
   VALUES (xID,xNIF,xMOTIVO,xVALIDA,'G');
END;
/


/****************************************************************************************
 Le entra un DNI y nos devuelve su NIF
 ****************************************************************************************/
CREATE OR REPLACE FUNCTION CalNif(xDNI IN CHAR)
RETURN CHAR

AS

letra char(1);
ValorNumerico float;
code integer;
xNIF Char(10);
xLetras Char(28);

BEGIN


xLetras:='TRWAGMYFPDXBNJZSQVHLCKEI';
--	   '012345678901234567890123

ValorNumerico:=0;

-- le quitamos los caracteres en blanco

xNIF:=RTrim(LTrim(xDNI));

xNIF:=SubStr(xNIF,1,8);

-- Si hay menos de ocho dígitos no seguimos

IF LENGTH(xNIF) < 8 THEN
   RETURN xDNI;
END IF;

-- si comienza por algo distinto de un valor numérico

IF Substr(xNIF,1,1) NOT IN ('0','1','2','3','4','5','6','7','8','9') THEN
   RETURN xDNI;
END IF;

IF Substr(xNIF,2,1) NOT IN ('0','1','2','3','4','5','6','7','8','9') THEN
   RETURN xDNI;
END IF;

IF Substr(xNIF,3,1) NOT IN ('0','1','2','3','4','5','6','7','8','9') THEN
   RETURN xDNI;
END IF;

IF Substr(xNIF,4,1) NOT IN ('0','1','2','3','4','5','6','7','8','9') THEN
   RETURN xDNI;
END IF;

IF Substr(xNIF,5,1) NOT IN ('0','1','2','3','4','5','6','7','8','9') THEN
   RETURN xDNI;
END IF;

IF Substr(xNIF,6,1) NOT IN ('0','1','2','3','4','5','6','7','8','9') THEN
   RETURN xDNI;
END IF;

IF Substr(xNIF,7,1) NOT IN ('0','1','2','3','4','5','6','7','8','9') THEN
   RETURN xDNI;
END IF;

IF Substr(xNIF,8,1) NOT IN ('0','1','2','3','4','5','6','7','8','9') THEN
   RETURN xDNI;
END IF;


ValorNumerico:=to_number( SubStr(xNIF,1,8) );

code:=Trunc(ValorNumerico - (Trunc(ValorNumerico/23) * 23));

Letra:=SubStr(xLetras, code+1, 1);

Return SubStr(xNIF,1,8) || Letra;


END;
/





/************************************************************************************
Autor: Gloria Maria Calle Hernandez
Fecha: 02/02/2004
Rellena la tabla TributosContri por usuario para cada NIF o contribuyente con todos los
Tributos q le correspondan (como una tabla temporal).
Modificación: 22/03/2004 Mª Carmen Junco Gómez. En vez de filtrar por usuario lo haremos
				  por NIF para su utlización en la WEB.
MODIFICACIÓN: 15/05/2006. M. Carmen Junco Gómez. Adaptación al nuevo formato de RUSTICA.
MODIFICACIÓN: 07/06/2006. Agustín León Robles. Se incluyen las plusvalias y liquidaciones
************************************************************************************/
CREATE OR REPLACE PROCEDURE FillTributosContri (
	xNif		char)
AS
	-- Variables para crear la sentencia 
    TYPE tCURSOR IS REF CURSOR;  -- define REF CURSOR type 
    vCURSOR    	 	tCURSOR;     -- declare cursor variable 
    TYPE tTRIBUTO IS RECORD (
       MUNICIPIO  		CHAR(3),
       NIF		  		CHAR(10),
       ID_CONCEPTO 		INTEGER,
	   CLAVE_TRIBUTO	VARCHAR2(50),
	   DESCRIPCION		VARCHAR2(100),
	   PROGRAMA			CHAR(10),
	   ESTADO 			CHAR(1),
	   FESTADO			DATE);
	   
    vREG 			tTRIBUTO;
    vSentencia		VARCHAR2(2000);
	vDESCRIP		VARCHAR2(100);
    vORDENANZA		VARCHAR2(50);
    vTARIFA			VARCHAR2(50);
    vCALLE			VARCHAR2(25);	
	vNIF			CHAR(10);
	xCONCEPTO 		CHAR(6);

BEGIN

	DELETE TRIBUTOSCONTRI WHERE NIF=xNIF;
	
	vNif:=SUBSTR(xNif,1,10);
	
	--IBI**********************************************************
	vSentencia:= 'SELECT MUNICIPIO,NIF,ID as ID_CONCEPTO,'||
				 'REF_CATASTRAL||NUMERO_SECUENCIAL||PRIMER_CARACTER_CONTROL||SEGUN_CARACTER_CONTROL as CLAVE_TRIBUTO,'||
				 'SUBSTR(''Ref.Cat: ''||REF_CATASTRAL||NUMERO_SECUENCIAL||PRIMER_CARACTER_CONTROL||SEGUN_CARACTER_CONTROL||'||
				 '''-V.Cat: ''||VALOR_CATASTRAL||''-D.Trib: ''||RTRIM(TIPO_VIA)||'' ''||RTRIM(NOMBRE_VIA)||'' ''||PRIMER_NUMERO||'||
				 ''' ''||PRIMERA_LETRA||'' ''||ESCALERA||'' ''||PLANTA||'' ''||PUERTA,1,100) as DESCRIPCION,''IBI'' as PROGRAMA,'||
				 '''A'' as ESTADO,SYSDATE as FESTADO FROM IBI WHERE YEAR = (SELECT MAX(YEAR) FROM IBI) AND NIF=:xNif';

	InsertFillTributosContri(vSentencia,vNIF);	
    
	
	
	--IAE**********************************************************
	vSentencia:= 'SELECT MUNICIPIO,NIF,ID as ID_CONCEPTO,REFERENCIA as CLAVE_TRIBUTO,ID_EPIGRAFE as DESCRIPCION,''IAE'' as PROGRAMA,'||
		 		 'DECODE(F_BAJA,NULL,''A'',''B'') as ESTADO,DECODE(F_BAJA,NULL,FECHA_INICIO_ACTI,F_BAJA) as FESTADO '||
				 'FROM IAE WHERE YEAR = (SELECT MAX(YEAR) FROM IAE) AND NIF=:xNif';

    --Asignar consulta a cursor, abrirlo y recorrerlo 
    OPEN vCURSOR FOR vSENTENCIA USING vNif;
    LOOP
		FETCH vCURSOR INTO vREG;
   	   	EXIT WHEN vCURSOR%NOTFOUND;

		begin
        	SELECT EPIGRAFE||' '||SECCION||' '||TIPO_ACTIVIDAD||' '||NOMBRE
	   		INTO vDESCRIP FROM EPIGRAFE WHERE ID=TO_NUMBER(vREG.DESCRIPCION);
	   		vDESCRIP:=SUBSTR('Referencia: '||vREG.CLAVE_TRIBUTO||'-Epígrafe: '||vDESCRIP,1,100);
		Exception
	   		When no_data_found then
				 vDESCRIP:='Referencia: '||vREG.CLAVE_TRIBUTO;
		end;

   	INSERT INTO TributosContri
		(MUNICIPIO,NIF,ID_CONCEPTO,CLAVE_TRIBUTO,DESCRIPCION,PROGRAMA,ESTADO,FESTADO)
		VALUES
		(vREG.MUNICIPIO,xNIF,vREG.ID_CONCEPTO,vREG.CLAVE_TRIBUTO,vDESCRIP,vREG.PROGRAMA,vREG.ESTADO,vREG.FESTADO);
		
   		
    END LOOP;
	CLOSE vCURSOR;
	
	
	--RUSTICA**********************************************************
	vSentencia:='SELECT MUNICIPIO,NIF,ID AS ID_CONCEPTO,'||
					'DECODE(NIF,NULL,CLAVE_IDENTIFICACION,NIF) AS CLAVE_TRIBUTO,'||
					'''Tributación por ''||TO_CHAR((SELECT COUNT(*) FROM RUS_PARCELAS WHERE ABONADO=R.ID)) ||'' parcelas'' AS DESCRIPCION,'||
					'''RUSTICA'' AS PROGRAMA,''A'' AS ESTADO,SYSDATE AS FESTADO '||
					'FROM RUS_TITULARES R WHERE YEAR=(SELECT MAX(YEAR) FROM RUS_TITULARES) AND NIF=:xNif';
					
	InsertFillTributosContri(vSentencia,vNIF);	
    

	--EXACCIONES**********************************************************
	vSentencia:= 'SELECT MUNICIPIO,NIF,ABONADO as ID_CONCEPTO,'||'COD_ORDENANZA||COD_TARIFA as CLAVE_TRIBUTO,'||
				 'MOTIVO as DESCRIPCION,''EXACCIONES'' as PROGRAMA,DECODE(F_BAJA,NULL,''A'',''B'') as ESTADO,'||
				 'DECODE(F_BAJA,NULL,F_ALTA,F_BAJA) as FESTADO FROM EXACCIONES WHERE NIF=:xNif';

    --Asignar consulta a cursor, abrirlo y recorrerlo 
    OPEN vCURSOR FOR vSENTENCIA USING vNif;
    LOOP
		FETCH vCURSOR INTO vREG;
   	   	EXIT WHEN vCURSOR%NOTFOUND;

		SELECT TRIM(DESCRIPCION) INTO vORDENANZA FROM CONCEPTOS
		WHERE CONCEPTO=SUBSTR(vREG.CLAVE_TRIBUTO,1,6);

		SELECT TRIM(TARIFA) INTO vTARIFA FROM TARIFAS_CONCEPTOS
		WHERE AYTO=vREG.MUNICIPIO 
		  AND CONCEPTO=SUBSTR(vREG.CLAVE_TRIBUTO,1,6) AND COD_TARIFA=SUBSTR(vREG.CLAVE_TRIBUTO,7,4);

	    INSERT INTO TributosContri
		(MUNICIPIO,NIF,ID_CONCEPTO,CLAVE_TRIBUTO,DESCRIPCION,PROGRAMA,ESTADO,FESTADO)
		VALUES
		(vREG.Municipio,xNIF,vREG.ID_CONCEPTO,vREG.CLAVE_TRIBUTO,SUBSTR(vORDENANZA||'-'||vTARIFA||'-'||vREG.DESCRIPCION,1,100),
		 vREG.PROGRAMA,vREG.ESTADO,vREG.FESTADO);
   		
    END LOOP;
	CLOSE vCURSOR;

	
	--AGUA**********************************************************
	vSentencia:= 'SELECT MUNICIPIO,NIF,ID as ID_CONCEPTO,''CONTADOR: ''||CONTADOR as CLAVE_TRIBUTO,'||
				 'CODIGO_CALLE||'' ''||NUMERO||'' ''||BLOQUE||'' ''||ESCALERA||'' ''||PLANTA||'' ''||'||
				 'PISO||'' ''||LETRA as DESCRIPCION,''AGUA'' as PROGRAMA,DECODE(FECHA_BAJA,NULL,''A'',''B'') as ESTADO,'||
		 		 'DECODE(FECHA_BAJA,NULL,FECHA_ALTA,FECHA_BAJA) as FESTADO FROM AGUA WHERE NIF=:xNif';

	
    --Asignar consulta a cursor, abrirlo y recorrerlo 
    OPEN vCURSOR FOR vSENTENCIA USING vNif;
    LOOP
		FETCH vCURSOR INTO vREG;
   	   	EXIT WHEN vCURSOR%NOTFOUND;

		SELECT CALLE INTO vCALLE FROM CALLES
    	WHERE MUNICIPIO=vREG.MUNICIPIO AND CODIGO_CALLE=SUBSTR(vREG.DESCRIPCION,1,4);

	    INSERT INTO TributosContri
		(MUNICIPIO,NIF,ID_CONCEPTO,CLAVE_TRIBUTO,DESCRIPCION,PROGRAMA,ESTADO,FESTADO)
		VALUES
		(vREG.Municipio,xNIF,vREG.ID_CONCEPTO,vREG.CLAVE_TRIBUTO,
		'Dir.SUMINISTRO: '||vCALLE||' '||vREG.DESCRIPCION,vREG.PROGRAMA,vREG.ESTADO,vREG.FESTADO);
   		
    END LOOP;
	CLOSE vCURSOR;

	
	--VEHICULOS**********************************************************
	vSentencia:= 'SELECT MUNICIPIO,NIF,ABONADO as ID_CONCEPTO,GETMATRICULA(MATRICULA,NUMERO,LETRA) as CLAVE_TRIBUTO,'||
				 '''Marca: ''||TRIM(MARCA)||'' Modelo: ''||TRIM(MODELO)||''  Matrícula: ''||GETMATRICULA(MATRICULA,NUMERO,LETRA) as DESCRIPCION,'||
				 '''VEHICULOS'' as PROGRAMA,DECODE(F_BAJA,NULL,''A'',''B'') as ESTADO,DECODE(F_BAJA,NULL,F_ALTA,F_BAJA) as FESTADO '||
				 'FROM VEHICULOS WHERE NIF=:xNif';
				 
	InsertFillTributosContri(vSentencia,vNIF);
    

	
	
	SELECT CONCEPTO INTO xCONCEPTO FROM PROGRAMAS WHERE PROGRAMA='PLUSVALIA';
	
	--LIQUIDACIONES**********************************************************
	--NO MOSTRAMOS LAS LIQUIDACIONES DE PLUSVALIAS YA QUE SE HACEN MAS ABAJO 
	vSentencia:= 'SELECT MUNICIPIO,NIF,ID as ID_CONCEPTO,CONCEPTO||''-''||YEAR||''-''||PERIODO||''-''||NUMERO as CLAVE_TRIBUTO,'||
				 '''Expediente: ''||TRIM(EXPEDIENTE)||'' F. Liquidación: ''||TO_CHAR(F_LIQUIDACION,''DD/MM/YYYY'')||''  Importe: ''||TO_CHAR(IMPORTE) as DESCRIPCION,'||
				 '''LIQUIDACIO'' as PROGRAMA,DECODE(F_ANULACION,NULL,''A'',''B'') as ESTADO,DECODE(F_ANULACION,NULL,F_LIQUIDACION,F_ANULACION) as FESTADO '||
				 'FROM LIQUIDACIONES WHERE CONCEPTO<>'||xCONCEPTO||' AND NIF=:xNif';

	InsertFillTributosContri(vSentencia,vNIF);
	
	
	--PLUSVALIAS**********************************************************
	--PARA LAS PLUSVALIAS MIRAMOS EN LA PROPIA TABLA DE LIQUIDACIONES PARA AVERIGUAR MAS RAPIDO LAS PLUSVALIAS DE UN NIF
	
	
	vSentencia:= 'SELECT MUNICIPIO,NIF,ID as ID_CONCEPTO,CONCEPTO||''-''||YEAR||''-''||PERIODO||''-''||NUMERO as CLAVE_TRIBUTO,'||
				 '''Expediente: ''||TRIM(EXPEDIENTE)||'' F. Liquidación: ''||TO_CHAR(F_LIQUIDACION,''DD/MM/YYYY'')||''  Importe: ''||TO_CHAR(IMPORTE) as DESCRIPCION,'||
				 '''PLUSVALIA'' as PROGRAMA,DECODE(F_ANULACION,NULL,''A'',''B'') as ESTADO,DECODE(F_ANULACION,NULL,F_LIQUIDACION,F_ANULACION) as FESTADO '||
				 'FROM LIQUIDACIONES WHERE CONCEPTO='||xCONCEPTO ||' AND NIF=:xNif';

	InsertFillTributosContri(vSentencia,vNIF);	

    
END;
/

--
-- Autor: Agustín León Robles
-- Fecha: 07/06/2006
-- Inserta en la tabla de TributosContri
--
--
CREATE OR REPLACE PROCEDURE InsertFillTributosContri
			(vSentencia	VARCHAR2, xNIF char)
AS
	TYPE tCURSOR IS REF CURSOR;  -- define REF CURSOR type 
    vCURSOR    	 	tCURSOR;     -- declare cursor variable 
    TYPE tTRIBUTO IS RECORD (
		MUNICIPIO  		CHAR(3),
       	NIF		  		CHAR(10),
       	ID_CONCEPTO 	INTEGER,
	   	CLAVE_TRIBUTO	VARCHAR2(50),
	   	DESCRIPCION		VARCHAR2(100),
	   	PROGRAMA		CHAR(10),
	   	ESTADO 			CHAR(1),
	   	FESTADO			DATE);
	   
    vREG 			tTRIBUTO;
BEGIN

	--Asignar consulta a cursor, abrirlo y recorrerlo 
    OPEN vCURSOR FOR vSENTENCIA USING xNif;
    LOOP
		FETCH vCURSOR INTO vREG;
   	   	EXIT WHEN vCURSOR%NOTFOUND;

	    INSERT INTO TributosContri
		(MUNICIPIO,NIF,ID_CONCEPTO,CLAVE_TRIBUTO,DESCRIPCION,PROGRAMA,ESTADO,FESTADO)
		VALUES
		(vREG.Municipio,xNIF,vREG.ID_CONCEPTO,vREG.CLAVE_TRIBUTO,vREG.DESCRIPCION,vREG.PROGRAMA,vREG.ESTADO,vREG.FESTADO);
   		
    END LOOP;
	CLOSE vCURSOR;

END;
/




/************************************************************************************
Autor: Gloria Maria Calle Hernandez
Fecha: 04/02/2004
Rellena la tabla DomiContri por usuario para cada NIF o contribuyente con todos las
domiciliaciones q le correspondan (como una tabla temporal).
Modificación: 25/02/2004. Gloria Maria Calle Hernandez. Restringir en los cursores dinámicos 
			  por Domiciliado='S', pues sino inserta para todo tributo una domiciliacion.
Modificación: 22/03/2004 Mª Carmen Junco Gómez. En vez de filtrar por usuario lo haremos
		      por NIF para su utlización en la WEB.
Modificación: 21/05/2004. Gloria Maria Calle Hernandez. Modificación realizada para sólo 
			  tomar las domiciliaciones de los tributos de alta.
MODIFICACIÓN: 15/05/2006. M. Carmen Junco Gómez. Adaptación al nuevo formato de RUSTICA.
************************************************************************************/
CREATE OR REPLACE PROCEDURE FillDomiContri (
	xNif		char)
AS
	-- Variables para crear la sentencia 
    TYPE tCURSOR IS REF CURSOR;  -- define REF CURSOR type 
    vCURSOR    	 	tCURSOR;     -- declare cursor variable 
    TYPE tDOMI IS RECORD (
       MUNICIPIO  		CHAR(3),
       NIF		  		CHAR(10),
       DNI_TITULAR 		CHAR(10),
       ID_CONCEPTO 		INTEGER,
	   DESCRIPCION		VARCHAR2(100),
	   ENTIDAD	  		CHAR(4),
	   SUCURSAL			CHAR(4),
	   DC				CHAR(2),
	   CUENTA			CHAR(10),
	   F_DOMICILIACION	DATE,
	   PROGRAMA			CHAR(10));
    vREG 				tDOMI;

    vSentencia		VARCHAR2(2000);
	 vNIF			CHAR(10);

BEGIN

	DELETE DOMICONTRI WHERE NIF=xNIF;
	
	vNif:=SUBSTR(xNif,1,10);
	
	--IBI**********************************************************
	vSentencia:= 'SELECT MUNICIPIO,NIF,DNI_FACTURA as DNI_TITULAR,ID as ID_CONCEPTO,'||
				 'SUBSTR(''Año: ''||YEAR||''-Ref.Cat: ''||REF_CATASTRAL||NUMERO_SECUENCIAL||PRIMER_CARACTER_CONTROL||'||
				 'SEGUN_CARACTER_CONTROL,1,100) as DESCRIPCION,ENTIDAD,SUCURSAL,DC,CUENTA,F_DOMICILIACION,''IBI'' as PROGRAMA '||
				 'FROM IBI WHERE DOMICILIADO=''S'' AND YEAR = (SELECT MAX(YEAR) FROM IBI) AND NIF=:xNif';

    --Asignar consulta a cursor, abrirlo y recorrerlo 
    OPEN vCURSOR FOR vSENTENCIA USING vNif;
    LOOP
		FETCH vCURSOR INTO vREG;
   	   	EXIT WHEN vCURSOR%NOTFOUND;

	    INSERT INTO DomiContri
		(MUNICIPIO,NIF,DNI_TITULAR,PROGRAMA,ENTIDAD,SUCURSAL,DC,CUENTA,F_DOMICILIACION,ID_CONCEPTO,DESCRIPCION)
		VALUES
		(vREG.MUNICIPIO,xNIF,vREG.DNI_TITULAR,vREG.PROGRAMA,vREG.ENTIDAD,vREG.SUCURSAL,vREG.DC,vREG.CUENTA,
		 vREG.F_DOMICILIACION,vREG.ID_CONCEPTO,vREG.DESCRIPCION);
   		
    END LOOP;
	CLOSE vCURSOR;
	
	
	--IAE**********************************************************
	vSentencia:= 'SELECT MUNICIPIO,NIF,DNI_FACTURA as DNI_TITULAR,ID as ID_CONCEPTO,'||
				 '''Año: ''||YEAR||'' Referencia I.A.E: ''||REFERENCIA as DESCRIPCION,'||
				 'ENTIDAD,SUCURSAL,DC,CUENTA,F_DOMICILIACION,''IAE'' as PROGRAMA '||
				 'FROM IAE WHERE DOMICILIADO=''S'' AND F_BAJA IS NULL '||
				 'AND YEAR = (SELECT MAX(YEAR) FROM IAE) AND NIF=:xNif';

    --Asignar consulta a cursor, abrirlo y recorrerlo 
    OPEN vCURSOR FOR vSENTENCIA USING vNif;
    LOOP
		FETCH vCURSOR INTO vREG;
   	   	EXIT WHEN vCURSOR%NOTFOUND;

	    INSERT INTO DomiContri
		(MUNICIPIO,NIF,DNI_TITULAR,PROGRAMA,ENTIDAD,SUCURSAL,DC,CUENTA,F_DOMICILIACION,ID_CONCEPTO,DESCRIPCION)
		VALUES
		(vREG.MUNICIPIO,xNIF,vREG.DNI_TITULAR,vREG.PROGRAMA,vREG.ENTIDAD,vREG.SUCURSAL,vREG.DC,vREG.CUENTA,
		 vREG.F_DOMICILIACION,vREG.ID_CONCEPTO,vREG.DESCRIPCION);
		
    END LOOP;
	CLOSE vCURSOR;
	
	
	--RUSTICA**********************************************************
	vSentencia:= 'SELECT MUNICIPIO,NIF,DNI_TITULAR,ID AS ID_CONCEPTO,'||
				'''Año: ''||YEAR||'' Tributación por ''||TO_CHAR((SELECT COUNT(*) FROM RUS_PARCELAS WHERE ABONADO=R.ID)) ||'' parcelas'' AS DESCRIPCION,'||
				'ENTIDAD,SUCURSAL,DC,CUENTA,F_DOMICILIACION,''RUSTICA'' AS PROGRAMA '||
				'FROM RUS_TITULARES R WHERE DOMICILIADO=''S'' AND YEAR = (SELECT MAX(YEAR) FROM RUS_TITULARES) AND NIF=:xNIF';

    --Asignar consulta a cursor, abrirlo y recorrerlo 
    OPEN vCURSOR FOR vSENTENCIA USING vNif;
    LOOP
		FETCH vCURSOR INTO vREG;
   	   	EXIT WHEN vCURSOR%NOTFOUND;

	    INSERT INTO DomiContri
		(MUNICIPIO,NIF,DNI_TITULAR,PROGRAMA,ENTIDAD,SUCURSAL,DC,CUENTA,F_DOMICILIACION,ID_CONCEPTO,DESCRIPCION)
		VALUES
		(vREG.MUNICIPIO,xNIF,vREG.DNI_TITULAR,vREG.PROGRAMA,vREG.ENTIDAD,vREG.SUCURSAL,vREG.DC,vREG.CUENTA,
		 vREG.F_DOMICILIACION,vREG.ID_CONCEPTO,vREG.DESCRIPCION);
   		
    END LOOP;
	CLOSE vCURSOR;


	--EXACCIONES**********************************************************
	vSentencia:= 'SELECT MUNICIPIO,NIF,DNI_TITULAR,ABONADO as ID_CONCEPTO,'||
				 'COD_TARIFA as DESCRIPCION,ENTIDAD,SUCURSAL,DC,CUENTA,F_DOMICILIACION,''EXACCIONES'' as PROGRAMA '||
				 'FROM EXACCIONES WHERE DOMICILIADO=''S'' AND F_BAJA IS NULL AND NIF=:xNif';

    --Asignar consulta a cursor, abrirlo y recorrerlo 
    OPEN vCURSOR FOR vSENTENCIA USING vNif;
    LOOP
		FETCH vCURSOR INTO vREG;
   	   	EXIT WHEN vCURSOR%NOTFOUND;

	    INSERT INTO DomiContri
		(MUNICIPIO,NIF,DNI_TITULAR,PROGRAMA,ENTIDAD,SUCURSAL,DC,CUENTA,F_DOMICILIACION,ID_CONCEPTO,DESCRIPCION)
		VALUES
		(vREG.MUNICIPIO,xNIF,vREG.DNI_TITULAR,vREG.PROGRAMA,vREG.ENTIDAD,vREG.SUCURSAL,vREG.DC,vREG.CUENTA,
		 vREG.F_DOMICILIACION,vREG.ID_CONCEPTO,vREG.DESCRIPCION);
   		
    END LOOP;
	CLOSE vCURSOR;

	
	--AGUA**********************************************************
	vSentencia:= 'SELECT MUNICIPIO,NIF,DNI_TITULAR,ID as ID_CONCEPTO, ''Contador: ''||CONTADOR as DESCRIPCION,ENTIDAD,'||
				 'SUCURSAL,DC,CUENTA,F_DOMICILIACION,''AGUA'' as PROGRAMA '||
				 'FROM AGUA WHERE DOMICILIADO=''S'' AND FECHA_BAJA IS NULL AND NIF=:xNif';

    --Asignar consulta a cursor, abrirlo y recorrerlo 
    OPEN vCURSOR FOR vSENTENCIA USING vNif;
    LOOP
		FETCH vCURSOR INTO vREG;
   	   	EXIT WHEN vCURSOR%NOTFOUND;

	    INSERT INTO DomiContri
		(MUNICIPIO,NIF,DNI_TITULAR,PROGRAMA,ENTIDAD,SUCURSAL,DC,CUENTA,F_DOMICILIACION,ID_CONCEPTO,DESCRIPCION)
		VALUES
		(vREG.MUNICIPIO,xNIF,vREG.DNI_TITULAR,vREG.PROGRAMA,vREG.ENTIDAD,vREG.SUCURSAL,vREG.DC,vREG.CUENTA,
		 vREG.F_DOMICILIACION,vREG.ID_CONCEPTO,vREG.DESCRIPCION);
   		
    END LOOP;
	CLOSE vCURSOR;

	
	--VEHICULOS**********************************************************
	vSentencia:= 'SELECT MUNICIPIO,NIF,TITULAR as DNI_TITULAR,ABONADO as ID_CONCEPTO,'||
				 '''Marca: ''||TRIM(MARCA)||'' Modelo: ''||TRIM(MODELO)||''  Matrícula: ''||GETMATRICULA(MATRICULA,NUMERO,LETRA) as DESCRIPCION,'||
				 'ENTIDAD,SUCURSAL,DC,CUENTA,F_DOMICILIACION,''VEHICULOS'' as PROGRAMA '||
				 'FROM VEHICULOS WHERE DOMICILIADO=''S'' AND F_BAJA IS NULL AND NIF=:xNif';

    --Asignar consulta a cursor, abrirlo y recorrerlo 
    OPEN vCURSOR FOR vSENTENCIA USING vNif;
    LOOP
		FETCH vCURSOR INTO vREG;
   	   	EXIT WHEN vCURSOR%NOTFOUND;

	    INSERT INTO DomiContri
		(MUNICIPIO,NIF,DNI_TITULAR,PROGRAMA,ENTIDAD,SUCURSAL,DC,CUENTA,F_DOMICILIACION,ID_CONCEPTO,DESCRIPCION)
		VALUES
		(vREG.MUNICIPIO,xNIF,vREG.DNI_TITULAR,vREG.PROGRAMA,vREG.ENTIDAD,vREG.SUCURSAL,vREG.DC,vREG.CUENTA,
		 vREG.F_DOMICILIACION,vREG.ID_CONCEPTO,vREG.DESCRIPCION);
   		
    END LOOP;
	CLOSE vCURSOR;

END;
/
