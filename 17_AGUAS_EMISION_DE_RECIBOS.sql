/*******************************************************************************
Acción: Obtener el desglose del recibo de un abonado es decir el importe de
cada uno de los conceptos del recibo incluso diferenciando base imponible de IVA.
Nos apoyamos en la tabla TIPO_TARIFA_ORDEN, para duplicar los conceptos con IVA.

MODIFICACIÓN: 14/09/2001 Lucas Fernández Pérez. Adaptación al euro.
*******************************************************************************/

CREATE OR REPLACE PROCEDURE SUBTOTALES (
	xMUNICIPIO	IN	CHAR,
	xYEAR		IN	CHAR,
	xPERIODO	IN	CHAR,
	xABONADO	IN	INTEGER,
 	x1 		OUT	FLOAT,
 	x2 		OUT	FLOAT,
 	x3 		OUT	FLOAT,
 	x4 		OUT	FLOAT,
 	x5 		OUT	FLOAT,
 	x6 		OUT	FLOAT,
 	x7 		OUT	FLOAT,

	xDES1 	OUT	CHAR,
	xDES2 	OUT	CHAR,
	xDES3 	OUT	CHAR,
	xDES4 	OUT	CHAR,
	xDES5 	OUT	CHAR,
	xDES6 	OUT	CHAR,
	xDES7 	OUT	CHAR
)
AS

Indice Integer;
SinDatos CHAR(1);
xIMPORTE FLOAT;
xTARIFA CHAR(4);
xDESCRI VARCHAR(50);

CURSOR CURSOR_SUBTOTALES IS
	SELECT TIPO,BI FROM TIPO_TARIFA_ORDEN
	WHERE MUNICIPIO=xMUNICIPIO
	ORDER BY TIPO,BI;

BEGIN

   x1:=0;
   x2:=0;
   x3:=0;
   x4:=0;
   x5:=0;
   x6:=0;
   x7:=0;

   xDes1:='';
   xDes2:='';
   xDes3:='';
   xDes4:='';
   xDes5:='';
   xDes6:='';
   xDes7:='';

Indice:=1;
SinDatos:='N';

FOR v_TDesg IN CURSOR_SUBTOTALES LOOP

-- COMPROBAR SI HAY DATOS DE UN TIPO DE TARIFA EN CASO CONTRARIO SALTARNOS EL IF
-- Un abonado no tiene porque tener de todos los tipos de tarifas, puede tener unos si y
-- otros no, por ejemplo tener agua y alcantarillado, pero no tener basura, etc.

begin
SELECT IMPORTE,TARIFA INTO xIMPORTE,xTARIFA
	from DESGLOSE_AGUAS
	where MUNICIPIO=xMUNICIPIO
	AND YEAR=xYEAR
	AND PERIODO=xPERIODO
	AND ABONADO=xABONADO
	AND BASE_IVA=v_TDesg.BI
	AND TIPO_TARIFA=v_TDesg.TIPO;

SELECT DECODE(v_TDesg.BI,'B',DESCRIPCION,'IVA DE '||DESCRIPCION)
	Into xDescri
	FROM tarifas_agua
	WHERE MUNICIPIO=xMUNICIPIO
	AND Tarifa=xTarifa;
exception
  when no_data_found then
   SinDatos:='S';
end;

if indice=1 and SinDatos='N' then
   x1 := xIMPORTE;
   xDes1:= xDescri;
end if;

if indice=2 and SinDatos='N' then
   x2 := xIMPORTE;
   xDes2:= xDescri;
end if;

if indice=3 and SinDatos='N' then
   x3 := xIMPORTE;
   xDes3:= xDescri;
end if;

if indice=4 and SinDatos='N' then
   x4 := xIMPORTE;
   xDes4:= xDescri;
end if;

if indice=5 and SinDatos='N' then
   x5 := xIMPORTE;
   xDes5:= xDescri;
end if;

if indice=6 and SinDatos='N' then
   x6 := xIMPORTE;
   xDes6:= xDescri;
end if;

if indice=7 and SinDatos='N' then
   x7 := xIMPORTE;
   xDes7:= xDescri;
end if;

	indice:=indice+1;
	SinDatos:='N';
	IF indice=8 THEN
	   EXIT;
      END IF;

END LOOP;

END;
/

/*******************************************************************************
Acción: Para el pase a un DBF para la Diputación.
MODIFICACIÓN: 18/09/2001 Lucas Fernández Pérez. Adaptación al euro.
*******************************************************************************/

CREATE OR REPLACE PROCEDURE PASE_DIPUTACION_AGUA (
	xMunicipio		In	Char,
	xYear			IN	CHAR,
	xPeri 		IN	CHAR)
AS
	xDomiTribu 			varchar(42);
	x1 				float;
	x2 				float;
	x3 				float;
	x4 				float;
	x5 				float;
	x6 				float;
	x7 				float;

	xDes1 			varchar2(50);
	xDes2 			varchar2(50);
	xDes3 			varchar2(50);
	xDes4 			varchar2(50);
	xDes5 			varchar2(50);
	xDes6 			varchar2(50);
	xDes7 			varCHAR2(50);

      --coger los recibos de un municipio año y periodo que tengan importe
      CURSOR CURSOR_PASE_DIPUTACION IS
	   SELECT * FROM RECIBOS_AGUA
  	   WHERE MUNICIPIO=xMUNICIPIO	and year=xYear and periodo=xPeri and total>0;

BEGIN

   DELETE FROM TABLA_PASE_DIPUTACION WHERE USUARIO=UID;

   FOR v_Agua IN CURSOR_PASE_DIPUTACION
   LOOP

	--coger el domicilio tributario
	xDOMITRIBU:='';
	xDOMITRIBU:=v_Agua.CALLE||' '||v_Agua.NUMERO||' '||v_Agua.BLOQUE||' '||
			v_Agua.ESCALERA||' '||v_Agua.PLANTA||' '||v_Agua.PISO||' '||v_Agua.LETRA;

	SUBTOTALES(xMunicipio,xYear,xPeri,v_Agua.Abonado,x1,x2,x3,x4,x5,x6,x7,
                 xDes1,xDes2,xDes3,xDes4,xDes5,xDes6,xDes7);

	INSERT INTO TABLA_PASE_DIPUTACION
	  (MUNICIPIO,ANIO,PERIODO,ABONADO,NIF,NOMBRE,DOMIFISCAL,CODPOSTAL,POBLACION,PROVINCIA,
	   INQUILINO,NOMINQUI,DOMITRIBU,CONTADOR,TITULO,DESDE,HASTA,REFERENCIA,D_CONTROL,TRIBUTO,
	   EJERCICIO,REMESA,IMPO,EMISOR,TEXTO1,TEXTO2,TEXTO3,DOMICI,ENTIDAD,SUCURSAL,DC,CUENTA,
	   TITULAR,NOMTITULAR,ANTERIOR,ACTUAL,CONSUMO,TOTAL,IMPORTE1,IMPORTE2,IMPORTE3,IMPORTE4,
	   IMPORTE5,IMPORTE6,IMPORTE7,DESCRIP1,DESCRIP2,DESCRIP3,DESCRIP4,DESCRIP5,DESCRIP6,
	   DESCRIP7)
	VALUES
        (xMUNICIPIO,xYEAR,xPERI,v_Agua.ABONADO,
         DECODE(v_Agua.DNI_FACTURA,NULL,v_Agua.NIF,v_Agua.DNI_FACTURA),v_Agua.NOMBRE,
	   v_Agua.DOMICILIO,v_Agua.CODIGO_POSTAL,v_Agua.POBLACION,v_Agua.PROVINCIA,
	   v_Agua.DNI_FACTURA,DECODE(v_Agua.DNI_FACTURA,NULL,NULL,v_Agua.NOMBRE),
	   xDOMITRIBU,v_Agua.CONTADOR,v_Agua.CONCEPTO_DEL_RECIBO,v_Agua.DESDE,
         v_Agua.HASTA,v_Agua.REFERENCIA,v_Agua.DIGITO_CONTROL,v_Agua.TRIBUTO,
	   v_Agua.EJERCICIO,v_Agua.REMESA,v_Agua.IMPORTE,v_Agua.EMISOR,v_Agua.TEXTO1,
	   v_Agua.TEXTO2,v_Agua.TEXTO3,v_Agua.DOMICILIADO,v_Agua.ENTIDAD,v_Agua.SUCURSAL,
	   v_Agua.DC,v_Agua.CUENTA,v_Agua.DNI_TITULAR,v_Agua.NOMBRE_TITULAR,
	   v_Agua.ANTERIOR,v_Agua.ACTUAL,v_Agua.CONSUMO,v_Agua.TOTAL,x1,x2,x3,x4,x5,x6,x7,
	   xDes1,xDes2,xDes3,xDes4,xDes5,xDes6,xDes7);

   END LOOP;

END;
/

/*******************************************************************************
Acción: Pase a Recaudación.
MODIFICACIÓN: 22/08/2001 Antonio Pérez Caballero.
MODIFICACIÓN: 17/09/2001 Lucas Fernández Pérez. Adaptación al euro.
modificación: 18/10/2001 Antonio Pérez Caballero
MODIFICACIÓN: 26/12/2001 Mª del Carmen Junco Gómez. Tener en cuenta si hay o no
			       inquilino para pasar unos datos u otros.
MODIFICACIÓN: 27/05/2002 M. Carmen Junco Gómez. Incluir o no los exentos dependiendo
		  del nuevo parámetro de entrada xEXENTOS.
MODIFICACIÓN: 1/07/2002 M. Carmen Junco Gómez. Insertar una tupla en LogsPadrones
		  para controlar que se ha pasado un padrón a Recaudación.
MODIFICACIÓN: 03/12/2002 M. Carmen Junco Gómez. Se añaden los campos MUNICIPIO y
		  PERIODO en la tabla LOGSPADRONES.
MODIFICACIÓN: 18/12/2002 M. Carmen Junco Gómez. No se guardaba correctamente el
		  domicilio tributario. Se comía dígitos del número.
MODIFICACIÓN: 29/01/2004. Agustín León Robles. En el objeto tributario del valor
		se pasa el desglose de los importes del agua
MODIFICACIÓN: 09/06/2004 Gloria Mª Calle Hernández. Se guarda en el campo Clave_recibo el ID 
	 	de la la tabla de recibos.
MODIFICACIÓN: 05/02/2007. Lucas Fernández Pérez. Se graba en los nuevos campos BLOQUE y PORTAL de PUNTEO.
*******************************************************************************/

CREATE OR REPLACE PROCEDURE AGUA_PASE_RECA (
	xMunicipio			IN	Char,
	xYEAR 				IN	CHAR,
	xPERIODO 			IN	CHAR,
	xFECHA 				IN	DATE,
	xN_CARGO 			IN	CHAR,
	xYEARCONTRAIDO		IN	CHAR,
	xEXENTOS			IN	CHAR)

AS

xPadron 		Char(6);
xDOMICILIO		CHAR(40);
xNOMBRE 		varchar2(40);
xCOTITULARES   	CHAR(1);

xIMPORTE1 		FLOAT;
xIMPORTE2 		FLOAT;
xIMPORTE3 		FLOAT;
xIMPORTE4 		FLOAT;
xIMPORTE5 		FLOAT;
xIMPORTE6 		FLOAT;
xIMPORTE7 		FLOAT;

xTITULO1 char(50);
xTITULO2 char(50);
xTITULO3 char(50);
xTITULO4 char(50);
xTITULO5 char(50);
xTITULO6 char(50);
xTITULO7 char(50);

xVIA	    CHAR(2);
xCALLE    VARCHAR2(30);
xNUMERO   CHAR(3);
xBLOQUE   CHAR(4);
xPORTAL   CHAR(2);
xESCALERA CHAR(2);
xPLANTA   CHAR(3);
xPISO     CHAR(2);
xPAIS     VARCHAR2(35);

xOBJETO_TRIBUTARIO VARCHAR2(1024);

xTIPO_TRIBUTO CHAR(2);

CURSOR CURSOR_AGUA_PASE_RECA IS
		SELECT * FROM RECIBOS_AGUA WHERE MUNICIPIO=xMUNICIPIO
			AND YEAR=xYEAR
			AND PERIODO=xPERIODO;
BEGIN

	SELECT CONCEPTO INTO xPADRON FROM PROGRAMAS
	WHERE PROGRAMA='AGUA';

	SELECT TIPO_TRIBUTO INTO xTIPO_TRIBUTO FROM CONTADOR_CONCEPTOS
	WHERE MUNICIPIO=xMUNICIPIO AND CONCEPTO=xPADRON;	

	FOR v_RAgua IN CURSOR_AGUA_PASE_RECA LOOP


		SELECT COTITULARES INTO xCOTITULARES
		FROM AGUA
		WHERE ID=v_RAgua.ABONADO;

		-- Domicilio Fiscal de la persona a la que se factura el recibo 
		SELECT VIA,CALLE,SUBSTR(NUMERO,1,3),BLOQUE,PORTAL,ESCALERA,PLANTA,PISO,PAIS
		INTO xVIA,xCALLE,xNUMERO,xBLOQUE,xPORTAL,xESCALERA,xPLANTA,xPISO,xPAIS
		FROM CONTRIBUYENTES
		WHERE NIF=DECODE(v_RAgua.DNI_FACTURA,NULL,v_RAgua.NIF,v_RAgua.DNI_FACTURA);


		--Domicilio Tributario del abonado
		xDOMICILIO:=RTRIM(v_RAgua.CALLE)||' '||RTRIM(v_RAgua.NUMERO)||' '||
	            RTRIM(v_RAgua.BLOQUE)||' '||RTRIM(v_RAgua.ESCALERA)||' '||
	            RTRIM(v_RAgua.PLANTA)||' '||RTRIM(v_RAgua.PISO)||' '||RTRIM(v_RAgua.LETRA);

		IF (xDOMICILIO IS NOT NULL) THEN
			xOBJETO_TRIBUTARIO:='DOM.TRIBUTARIO: '||xDOMICILIO||' ';
		END IF;

		xOBJETO_TRIBUTARIO:=xOBJETO_TRIBUTARIO||'L. ANTERIOR: '||v_RAgua.ANTERIOR||' ';
		xOBJETO_TRIBUTARIO:=xOBJETO_TRIBUTARIO||'L. ACTUAL:'||v_RAgua.ACTUAL||' ';
		xOBJETO_TRIBUTARIO:=xOBJETO_TRIBUTARIO||'CONSUMO:'||v_RAgua.CONSUMO||' ';
		

		SUBTOTALES(xMunicipio,xYear,xPeriodo,v_RAgua.Abonado,
				xIMPORTE1,xIMPORTE2,xIMPORTE3,xIMPORTE4,
				xIMPORTE5,xIMPORTE6,xIMPORTE7,xTITULO1,
				xTITULO2,xTITULO3,xTITULO4,xTITULO5,xTITULO6,xTITULO7);
		
		if xImporte1 > 0 then
			xOBJETO_TRIBUTARIO:=xOBJETO_TRIBUTARIO||RTRIM(xTITULO1)||' : '||					
					RTRIM(TO_CHAR(xIMPORTE1,'999990D99'))||' ';
		end if;
		
		if xImporte2 > 0 then
			xOBJETO_TRIBUTARIO:=xOBJETO_TRIBUTARIO||RTRIM(xTITULO2)||' : '||
					RTRIM(TO_CHAR(xIMPORTE2,'999990D99'))||' ';
		end if;
		
		if xImporte3 > 0 then
			xOBJETO_TRIBUTARIO:=xOBJETO_TRIBUTARIO||RTRIM(xTITULO3)||' : '||
					RTRIM(TO_CHAR(xIMPORTE3,'999990D99'))||' ';
		end if;
		
		if xImporte4 > 0 then
			xOBJETO_TRIBUTARIO:=xOBJETO_TRIBUTARIO||RTRIM(xTITULO4)||' : '||
					RTRIM(TO_CHAR(xIMPORTE4,'999990D99'))||' ';
		end if;
		
		if xImporte5 > 0 then
			xOBJETO_TRIBUTARIO:=xOBJETO_TRIBUTARIO||RTRIM(xTITULO5)||' : '||
					RTRIM(TO_CHAR(xIMPORTE5,'999990D99'))||' ';
		end if;
		
		if xImporte6 > 0 then
			xOBJETO_TRIBUTARIO:=xOBJETO_TRIBUTARIO||RTRIM(xTITULO6)||' : '||
					RTRIM(TO_CHAR(xIMPORTE6,'999990D99'))||' ';
		end if;
		
		if xImporte7 > 0 then
			xOBJETO_TRIBUTARIO:=xOBJETO_TRIBUTARIO||RTRIM(xTITULO7)||' : '||
					RTRIM(TO_CHAR(xIMPORTE7,'999990D99'))||' ';
		end if;		
		
		xOBJETO_TRIBUTARIO:=xOBJETO_TRIBUTARIO||'CONTADOR:'||v_RAgua.CONTADOR||' ';
		
		IF NOT (xEXENTOS='N' AND v_RAgua.TOTAL<=0) THEN
	     INSERT INTO PUNTEO
		 (AYTO,PADRON,YEAR,PERIODO,RECIBO,NIF,NOMBRE,VIA,CALLE,NUMERO,BLOQUE,PORTAL,ESCALERA,PLANTA,
		  PISO,POBLACION,PROVINCIA,CODIGO_POSTAL,PAIS,VOL_EJE,F_CARGO,N_CARGO,
		  PRINCIPAL,CUOTA_INICIAL,TIPO_DE_OBJETO,
		  FIN_PE_VOL,INI_PE_VOL,TIPO_DE_TRIBUTO,ESTADO_BANCO,
		  DOM_TRIBUTARIO,OBJETO_TRIBUTARIO,
		  Importe1,Importe2,Importe3,Importe4,Importe5,Importe6,Importe7,Titulo1,Titulo2,
		  Titulo3,Titulo4,Titulo5,Titulo6,Titulo7,CLAVE_CONCEPTO, YEAR_CONTRAIDO, COTITULARES, CLAVE_RECIBO)
	     VALUES
		 (xMunicipio,xPadron,xYear,xPeriodo,v_RAgua.Abonado,
		  DECODE(v_RAgua.DNI_FACTURA,NULL,v_RAgua.NIF,v_RAgua.DNI_FACTURA),
		  v_RAgua.NOMBRE,xVIA,xCALLE,xNUMERO,xBLOQUE,xPORTAL,xESCALERA,xPLANTA,xPISO,v_RAgua.POBLACION,
		  v_RAgua.PROVINCIA,v_RAgua.CODIGO_POSTAL,xPAIS,'V',xFECHA,xN_CARGO,
		  v_RAgua.TOTAL,v_RAgua.TOTAL,'R',v_RAgua.HASTA,v_RAgua.DESDE,xTIPO_TRIBUTO,
		  v_RAgua.ESTADO_BANCO,xDomicilio,xObjeto_Tributario,
		  ROUND(xImporte1,2),ROUND(xImporte2,2),ROUND(xImporte3,2),ROUND(xImporte4,2),
		  ROUND(xImporte5,2),ROUND(xImporte6,2),ROUND(xImporte7,2),
		  xTitulo1,xTitulo2,xTitulo3,xTitulo4,xTitulo5,xTitulo6,xTitulo7,
		  'CONTADOR: '|| v_RAgua.CONTADOR, xYEARCONTRAIDO,xCOTITULARES,v_RAGUA.ID);
		END IF;

	END LOOP;

	-- Insertamos una tupla en LOGSPADRONES para controlar que esta acción ha sido ejecutada
	INSERT INTO LOGSPADRONES (MUNICIPIO,PROGRAMA,PYEAR,PERIODO,HECHO)
	VALUES (xMUNICIPIO,'AGUA',xYEAR,xPERIODO,'Se Pasa un padrón a Recaudación');

END;
/

/*******************************************************************************
Acción: Comprobar si existe el padrón.
*******************************************************************************/
CREATE OR REPLACE PROCEDURE CHECK_EXIT_PADAGUA(
	xYEAR		IN	CHAR,
	xPERIODO 	IN	CHAR,
	xCUANTOS 	OUT	INTEGER
)
AS
BEGIN

   SELECT COUNT(*) INTO xCUANTOS FROM RECIBOS_AGUA
   WHERE MUNICIPIO IN (SELECT MUNICIPIO FROM TMP_AYTOS WHERE USUARIO=USER) AND
         YEAR=xYEAR AND PERIODO=xPERIODO;
END;
/

/*******************************************************************************
Acción: Procedimiento que devuelve: 
		0 - Si existen vehículos en un municipio marcados para incorporarlos al padrón
		1 - Si no existen vehículos en un municipio
		2 - Si no se ha marcado ningún vehículo de un municipio

  Nota: Este procedimiento solo sirve cuando se trabaja con un solo municipio.
MODIFICADO:	10/12/2003 Gloria Maria Calle Hernandez. Tras añadir marca de incorporados al padron.
*******************************************************************************/
CREATE OR REPLACE PROCEDURE CHECK_EXIT_AGUA (
    xMUNICIPIO   IN CHAR,
    xRESP 	  	 OUT INTEGER
)
AS
	xTEMP	 	 INTEGER;

BEGIN
   
   xRESP:=0;

   SELECT COUNT(*) INTO xTEMP FROM AGUA
    WHERE MUNICIPIO=xMUNICIPIO;

   IF xTEMP=0 THEN
	  xRESP:=1;
   ELSE
      SELECT COUNT(*) INTO xTEMP FROM AGUA
       WHERE MUNICIPIO=xMUNICIPIO AND INCORPORADO='S';
      
      IF xTEMP=0 THEN
         xRESP:=2;
      END IF;
   END IF;

END;
/


/*******************************************************************************
Acción: Borrar un padrón completo.
MODIFICACIÓN: 28/06/2002 M. Carmen Junco Gómez. Insertar una tupla en LogsPadrones
		  para controlar que se ha borrado un padrón.
MODIFICACIÓN: 03/12/2002 M. Carmen Junco Gómez. Insertamos el municipio y el periodo
		  en logspadrones.
*******************************************************************************/

CREATE OR REPLACE PROCEDURE BORRA_PADRON_VIEJO_AGUA(
	xPERIODO	IN	CHAR,
	xYEAR 	IN	CHAR
)
AS
   CURSOR CMUNI IS SELECT MUNICIPIO FROM TMP_AYTOS WHERE USUARIO=USER;
BEGIN

   FOR vMUNI IN CMUNI
   LOOP
      DELETE FROM DESGLOSE_AGUAS
      WHERE MUNICIPIO=vMUNI.MUNICIPIO AND YEAR=xYEAR AND PERIODO=xPERIODO;

      DELETE FROM RECIBOS_AGUA
      WHERE MUNICIPIO=vMUNI.MUNICIPIO AND YEAR=xYEAR AND PERIODO=xPERIODO;

      -- Insertamos una tupla en LOGSPADRONES para controlar que esta acción ha sido ejecutada
      INSERT INTO LOGSPADRONES (MUNICIPIO,PROGRAMA,PYEAR,PERIODO,HECHO)
      VALUES (vMUNI.MUNICIPIO,'AGUA',xYEAR,xPERIODO,'Se Borra un Padrón');

      -- Se indica que el padron puede volver a generarse
      UPDATE DATOSPER SET ESTADO='PL' WHERE MUNICIPIO=vMUNI.MUNICIPIO;
   END LOOP;

END;
/

/*******************************************************************************
Acción: Emite los recibos de los abonados de Agua.
MODIFICACIÓN: 17/09/2001 Lucas Fernández Pérez. Adaptación al euro.
MODIFICACIÓN: 12/02/2002 M. Carmen Junco Gómez. No actualizaba el valor de la
		  variable xNombre_Titular, con lo cual incluso los no domiciliados
		  aparecían con datos en este campo.
MODIFICACIÓN: 28/06/2002 M. Carmen Junco Gómez. Insertar una tupla en LogsPadrones
		  para controlar que se ha generado un padrón.
MODIFICACIÓN: 03/12/2002 M. Carmen Junco Gómez. Insertamos los campos municipio y
		  periodo en logspadrones
MODIFICACIÓN: 27/01/2004 Agustín León Robles. Hace el calculo del recibo por prorrateo de la cuotas fijas
		 en funcion de la fecha de alta y del trimestre que estemos generando el padron
MODIFICACIÓN: 15/11/2005 Gloria Maria Calle Hernandez. Protegido select sobre el nombre del titular.
MODIFICACIÓN: 05/02/2007 Lucas Fernández Pérez. Ampliación del campo domicilio de la tabla recibos_agua
*******************************************************************************/
CREATE OR REPLACE PROCEDURE GEN_RECIBOS_AGUA (
	xMUNICIPIO	IN	CHAR,
	xYEAR		IN	CHAR,
	xPERIODO	IN	CHAR,
	xDESDE		IN	DATE,
	xHASTA		IN	DATE,
	xCARGO		IN 	DATE,
	xCONCEPTO	IN	VARCHAR,
	xTEXTO1		IN	VARCHAR,
	xTEXTO2		IN	VARCHAR,
	xTEXTO3		IN	VARCHAR)
AS

	xABONADO 		INTEGER;
	xNIF			CHAR(10);
	xCODIGO_CALLE	CHAR(4);
	xCALLE			VARCHAR(25);
	xNUMERO			CHAR(3);
	xBLOQUE			CHAR(1);
	xESCALERA		CHAR(1);
	xPLANTA			CHAR(2);
	xPISO			CHAR(2);
	xLETRA			CHAR(2);
	xCPOSTAL		CHAR(5);
	xCONTADOR	 	CHAR(10);
	xCALIBRE	 	CHAR(4);
	xF_L_ACTUAL	 	DATE;
	xF_L_ANTERIOR 	DATE;
	xACTUAL			INTEGER;
	xANTERIOR		INTEGER;
	xDOMICILIADO	CHAR(1);
	xENTIDAD		CHAR(4);
	xSUCURSAL		CHAR(4);
	xDC				CHAR(2);
	xCUENTA			CHAR(10);
	xDNI_TITULAR	CHAR(10);
	xNOMBRE_TITULAR	CHAR(40);
	xDNI_FACTURA	CHAR(10);
	xINCIDENCIA		CHAR(2);

	xCONSUMO		INTEGER;
	xIMPORTE_RECIBO FLOAT;
	xIMPORTE 		CHAR(12);
	xREFE 			CHAR(10);
	xDCONTROL 		CHAR(2);
	xDIG_C60_M2     CHAR(2);

	xTARIFA_AGUA 	CHAR(4);
	xBL_TA 			CHAR(2);
	xRANGO 			INTEGER;
	xNOMBRE 		VARCHAR(40);
	xDOMIFISCAL		varchar(60);
    xCODPOSTAL 		CHAR(5);
    xPOBLACION 		CHAR(35);
    xPROVINCIA		VARCHAR2(35);
    xIDDOMIALTER	INTEGER;
	xCOTITULARES	CHAR(1);


    xPADRON		    CHAR(6);
    xEMISOR 	    CHAR(6);
    xTRIBUTO 	    CHAR(3);
    xFAlta			date;

	CURSOR CURSOR_GEN_RECIBOS_AGUA IS
	SELECT ID,NIF,CODIGO_CALLE,NUMERO,BLOQUE,ESCALERA,PLANTA,PISO,LETRA,COD_POSTAL,
	       CONTADOR,CALIBRE,F_L_ACTUAL,F_L_ANTERIOR,ACTUAL,ANTERIOR,DOMICILIADO,
           ENTIDAD,SUCURSAL,DC,CUENTA,DNI_TITULAR,DNI_FACTURA,INCIDENCIA,
           IDDOMIALTER,COTITULARES,FECHA_ALTA
      FROM AGUA
  	 WHERE MUNICIPIO=xMunicipio AND FECHA_BAJA IS NULL AND INCORPORADO='S';

BEGIN

	--Averiguar que concepto es el padron de AGUA
	SELECT CONCEPTO INTO xPADRON FROM PROGRAMAS WHERE PROGRAMA='AGUA';

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

   OPEN CURSOR_GEN_RECIBOS_AGUA;
   LOOP
	   FETCH CURSOR_GEN_RECIBOS_AGUA INTO xABONADO,xNIF,xCODIGO_CALLE,xNUMERO,xBLOQUE,xESCALERA,
		xPLANTA,xPISO,xLETRA,xCPOSTAL,xCONTADOR,xCALIBRE,xF_L_ACTUAL,xF_L_ANTERIOR,xACTUAL,
		xANTERIOR,xDOMICILIADO,xENTIDAD,xSUCURSAL,xDC,xCUENTA,xDNI_TITULAR,xDNI_FACTURA,
		xINCIDENCIA,xIDDOMIALTER,xCOTITULARES,xFAlta;

	   EXIT WHEN CURSOR_GEN_RECIBOS_AGUA%NOTFOUND;

	   --convierte el numero de abonado en caracter y relleno de ceros
	   GETREFERENCIA(xABONADO,xREFE);

       --nombre del abonado, es decir, a nombre de quien saldrá el recibo
	   SELECT NOMBRE INTO xNOMBRE FROM CONTRIBUYENTES
		WHERE NIF=DECODE(xDNI_FACTURA, NULL, xNIF, xDNI_FACTURA);

	   --domicilio fiscal en funcion de si tiene inquilino o no
	   --Dentro de la funcion "GetDomicilioFiscal" se comprueba si tiene a su vez un domicilio
	   --alternativo.
	   IF xDNI_FACTURA IS NULL THEN
	      GetDomicilioFiscal(xNIF, xIDDOMIALTER,
				xDomiFiscal,xPoblacion,xProvincia,xCodPostal);
	   ELSE
	      GetDomicilioFiscal(xDNI_FACTURA, xIDDOMIALTER,
				xDomiFiscal,xPoblacion,xProvincia,xCodPostal);
	   END IF;

	   --NOMBRE DEL TITULAR DE LA CUENTA
	   IF (xDOMICILIADO='S') THEN
           begin
		       select nombre into xNombre_titular from contribuyentes where nif=xDni_titular;
	       exception
               when no_data_found then
			         xNombre_titular:=null;
		   end;
	   ELSE
	        xNombre_Titular:= null;
	   END IF;

	   --NOMBRE DE LA CALLE DEL SUMINISTRO
	   SELECT CALLE INTO xCALLE FROM CALLES
	    WHERE CODIGO_CALLE=xCODIGO_CALLE and municipio=xMunicipio;

	   --CALCULA LAS LINEAS DE DETALLE Y NOS PERMITE CONOCER EL IMPORTE DEL RECIBO
	   IF (xACTUAL < xANTERIOR) THEN
   	       AVERIGUA_PESO(xACTUAL,xANTERIOR,xCONSUMO,xRANGO);
	   ELSE
    	   xCONSUMO := xACTUAL - xANTERIOR;
	   END IF;

	   --En la primera pasada solo calcula los importes
	   CALCULA_LINEAS_RECIBO(xMunicipio,xABONADO,xYEAR,xPERIODO,xNIF,xCONSUMO,'N',xFAlta,
			xIMPORTE_RECIBO,xTARIFA_AGUA,xBL_TA);

	   --convierte el importe en caracter y relleno de CEROS
	   IMPORTEENCADENA(xIMPORTE_RECIBO,xIMPORTE);

   	   --para el calculo de digitos de control del cuarderno 60
	   CALCULA_DC_60(xIMPORTE_RECIBO,xABONADO,xTRIBUTO,SUBSTR(xYEAR,3,2),xPERIODO,xEMISOR,xDCONTROL);

	   --calcular los digitos de control del cuaderno 60 modalidad 2
	   CALCULA_DC_MODALIDAD2_60(xIMPORTE_RECIBO, xABONADO, xTRIBUTO, SUBSTR(xYEAR,3,2), '1',
			to_char(xHASTA,'y'), to_char(xHASTA,'ddd'), xEMISOR, xDIG_C60_M2);

	   --insertamos los cotitulares del recibo
	   IF xCOTITULARES='S' THEN
	  	  INSERT INTO COTITULARES_RECIBO(NIF,PROGRAMA,AYTO,PADRON,YEAR,PERIODO,RECIBO)
		  SELECT NIF,'AGUA',xMUNICIPIO,xPADRON,xYEAR,xPERIODO,xABONADO
		    FROM COTITULARES
		   WHERE ID_CONCEPTO=xABONADO AND PROGRAMA='AGUA';
	   END IF;

 	   INSERT INTO RECIBOS_AGUA
	     (YEAR,PERIODO,ABONADO,NIF,NOMBRE,DOMICILIADO,ENTIDAD,SUCURSAL,
	  	  DC,CUENTA,DNI_TITULAR,NOMBRE_TITULAR,CALLE,NUMERO,BLOQUE,ESCALERA,PLANTA,PISO,LETRA,
		  COD_POSTAL,ANTERIOR,ACTUAL,CONSUMO,F_LECTURA_ACTUAL,F_LECTURA_ANTERIOR,INCIDENCIA,
		  CONTADOR,CALIBRE,DESDE,HASTA,F_CARGO,CONCEPTO_DEL_RECIBO,TEXTO1,TEXTO2,TEXTO3,
		  DNI_FACTURA,
		  REFERENCIA,TRIBUTO,EJERCICIO,REMESA,EMISOR,MUNICIPIO,IMPORTE,TOTAL,DIGITO_CONTROL,
		  TARIFA_AGUA,BLOQUE_TA,ESCALERA_CONSUMO,ESTADO_BANCO,
		  DOMICILIO,POBLACION,PROVINCIA,CODIGO_POSTAL,
		  DISCRI_PERIODO,DIGITO_YEAR,F_JULIANA,DIGITO_C60_MODALIDAD2)
	   VALUES
	  	(xYEAR,xPERIODO,xABONADO,xNIF,xNOMBRE,xDOMICILIADO,

		DECODE(xDOMICILIADO,'S',xENTIDAD,NULL),
		DECODE(xDOMICILIADO,'S',xSUCURSAL,NULL),
		DECODE(xDOMICILIADO,'S',xDC,NULL),
		DECODE(xDOMICILIADO,'S',xCUENTA,NULL),
		DECODE(xDOMICILIADO,'S',xDNI_TITULAR,NULL),

		xNOMBRE_TITULAR,xCALLE,xNUMERO,xBLOQUE,xESCALERA,xPLANTA,xPISO,xLETRA,
		xCPOSTAL,xANTERIOR,xACTUAL,xCONSUMO,xF_L_ACTUAL,xF_L_ANTERIOR,xINCIDENCIA,
		xCONTADOR,xCALIBRE,xDESDE,xHASTA,xCARGO,xCONCEPTO,xTEXTO1,xTEXTO2,xTEXTO3,
		xDNI_FACTURA,xREFE,xTRIBUTO,SUBSTR(xYEAR,3,2),xPERIODO,xEMISOR,xMunicipio,
		xIMPORTE,xIMPORTE_RECIBO,xDCONTROL,xTARIFA_AGUA,xBL_TA,xRANGO,

		DECODE(xDOMICILIADO,'S','EB',NULL),

		xDOMIFISCAL,xPOBLACION,xPROVINCIA,xCODPOSTAL,
		'1',to_char(xHASTA,'y'), to_char(xHASTA,'ddd'),xDIG_C60_M2);

	   --en esta pasada graba en el desglose
	   CALCULA_LINEAS_RECIBO(xMunicipio,xABONADO,xYEAR,xPERIODO,xNIF,xCONSUMO,'S',xFAlta,
			xIMPORTE_RECIBO,xTARIFA_AGUA,xBL_TA);

   END LOOP;
   CLOSE CURSOR_GEN_RECIBOS_AGUA;

   -- Insertamos una tupla en LOGSPADRONES para controlar que esta acción ha sido ejecutada
   INSERT INTO LOGSPADRONES (MUNICIPIO,PROGRAMA,PYEAR,PERIODO,HECHO)
   VALUES (xMUNICIPIO,'AGUA',xYEAR,xPERIODO,'Se Genera un Padrón');

END;
/

/*******************************************************************************
Acción: Emite los recibos de los abonados de Agua.
*******************************************************************************/
CREATE OR REPLACE PROCEDURE GENERA_RECIBOS_AGUA (
	xYEAR		IN	CHAR,
	xPERIODO	IN	CHAR,
	xDESDE		IN	DATE,
	xHASTA		IN	DATE,
	xCARGO		IN 	DATE,
	xCONCEPTO	IN	VARCHAR,
	xTEXTO1		IN	VARCHAR,
	xTEXTO2		IN	VARCHAR,
	xTEXTO3		IN	VARCHAR)
AS
   CURSOR CAYTOS IS
      SELECT MUNICIPIO FROM TMP_AYTOS WHERE USUARIO=USER;
BEGIN

   FOR v_aytos IN CAYTOS
   LOOP
      GEN_RECIBOS_AGUA(v_aytos.MUNICIPIO,xYEAR,xPERIODO,xDESDE,xHASTA,xCARGO,xCONCEPTO,
                       xTEXTO1,xTEXTO2,xTEXTO3);
   END LOOP;

END;
/

/*******************************************************************************
Acción: Recibos domiciliados y no domiciliados en formato de la Caixa.
MODIFICACIÓN: 17/09/2001 Lucas Fernández Pérez. Adaptación al euro.
MODIFICACIÓN: 20/09/2001 M. Carmen Junco Gómez. Seleccionaba datos de la tabla
              de Agua que ya estaban en la tabla de Recibos.
*******************************************************************************/

CREATE OR REPLACE PROCEDURE Proc_Caixa_Agua (
	xMunicipio in char,
	xYear      in char,
	xPeri      in char)
AS

xNombre 			char(40);
xDomicilio	 		char(60);
xAbonado 			Integer;

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

xImporte1	float;
xImporte2	float;
xImporte3	float;
xImporte4	float;
xImporte5	float;
xImporte6	float;
xImporte7	float;

xDES1	char(50);
xDES2	char(50);
xDES3	char(50);
xDES4	char(50);
xDES5	char(50);
xDES6	char(50);
xDES7	char(50);

xCodPostal 			char(5);
xNIF	 			CHAR(10);
xMuniFiscal 		char(35);
i 				integer;
xRegis 			integer;

xPoblacion		      CONTRIBUYENTES.Poblacion%Type;
xProvincia		      CONTRIBUYENTES.Provincia%Type;


CURSOR CRECAGUA IS Select * FROM recibos_agua
		    WHERE municipio=xMunicipio and year=xYear and periodo=xPeri and total>0;
BEGIN

	DELETE FROM RECIBOS_CAIXA WHERE USUARIO=USER;

	xRegis:=0;

	SELECT count(*) into xRegis FROM recibos_agua
	WHERE municipio=xMunicipio and year=xYear and periodo=xPeri and total>0;

	FOR v_TAGUA IN CRECAGUA LOOP

		if (v_TAGUA.DNI_FACTURA IS NOT NULL ) THEN
			xNIF:=v_TAGUA.DNI_FACTURA;
		else
			xNIF:=v_TAGUA.NIF;
		end if;

		GETContribuyente(xNIF,xNOMBRE,
			xMuniFiscal,xProvincia,xCodPostal,xDomicilio);

		i:=11;
		x2:=  v_TAGUA.CALLE||' '||v_TAGUA.NUMERO||' '||v_TAGUA.BLOQUE||
			v_TAGUA.ESCALERA||v_TAGUA.PLANTA||v_TAGUA.PISO||v_TAGUA.LETRA;
		x3 := 'Lectura anterior: ' || v_TAGUA.ANTERIOR;
		x4 := 'Lectura actual: ' || v_TAGUA.ACTUAL;
		x5 := 'Consumo: ' || v_TAGUA.CONSUMO;

		SUBTOTALES (xMUNICIPIO,xYEAR,xPERI,v_TAGUA.ABONADO,
	 		xImporte1,xImporte2,xImporte3,xImporte4,xImporte5,xImporte6,xImporte7,
			xDES1,xDES2,xDES3,xDES4,xDES5,xDES6,xDES7);

		x6:='';
		x7:='';
		x8:='';
		x9:='';
		x10:='';
		x11:='';
		x12:='';

		if xImporte1>0 then
			x6 :=  SUBSTR(RTRIM(xDes1),1,29)  || ': ' || xImporte1;
		end if;

		if xImporte2>0 then
			x7 :=  SUBSTR(RTRIM(xDes2),1,29)  || ': ' || xImporte2;
		end if;

		if xImporte3>0 then
			x8 :=  SUBSTR(RTRIM(xDes3),1,29)  || ': ' || xImporte3;
		end if;

		if xImporte4>0 then
			x9 :=  SUBSTR(RTRIM(xDes4),1,29)  || ': ' || xImporte4;
		end if;

		if xImporte5>0 then
			x10 := SUBSTR(RTRIM(xDes5),1,29) || ': ' || xImporte5;
		end if;

		if xImporte6>0 then
			x11 := SUBSTR(RTRIM(xDes6),1,29) || ': ' || xImporte6;
		end if;

		if xImporte7>0 then
			x12 := SUBSTR(RTRIM(xDes7),1,29) || ': ' || xImporte7;
		end if;

		INSERT INTO RECIBOS_CAIXA
			(ABONADO,NIF,NOMBRE,DOMICILIO,CODPOSTAL,MUNICIPIO,
			ENTIDAD,SUCURSAL,DC,CUENTA,
			TOTAL, Campo2, Campo3, Campo4, Campo5, Campo6, Campo7,Campo8,Campo9,Campo10,
			Campo11,Campo12,CAMPOS_OPCIONALES, CUANTOS_REGISTROS)
		VALUES
			(v_TAGUA.ABONADO, xNif, xNombre, substr(xDomicilio,1,40),
			xCodPostal, xMuniFiscal,
			v_TAGUA.Entidad, v_TAGUA.Sucursal, v_TAGUA.DC, v_TAGUA.Cuenta,
			v_TAGUA.TOTAL*100, x2, x3, x4, x5, x6, x7,x8,x9,x10,x11,x12, i, xRegis);

	END LOOP; --del cursor CRECAGUA

END;
/

/*******************************************************************************
Autor: M. Carmen Junco Gómez. 09/05/2002
Acción: Recibos domiciliados y no domiciliados en formato de Caja Madrid.

Modificación: 05/02/2007. Lucas Fernández Pérez. Se accede al campo DOMICILIO de la nueva vista vwCONTRIBUYENTES.

*******************************************************************************/

CREATE OR REPLACE PROCEDURE Proc_CajaMadrid_Agua (
	xMunicipio in char,
	xYear      in char,
	xPeri      in char)
AS

   	xNombre 	char(40);
   	xDomicilio	char(60);
   	xAbonado 	Integer;

	x1 			char(40);
	x2 			char(40);
	x3 			char(40);
	x4 			char(40);
	x5 			char(40);
	x6 			char(40);
	x7 			char(40);
	x8 			char(40);
	x9 			char(40);
	x10 		char(40);
	x11			char(40);

	xImporte1	float;
	xImporte2	float;
	xImporte3	float;
	xImporte4	float;
	xImporte5	float;
	xImporte6	float;
	xImporte7	float;

	xDES1	char(50);
	xDES2	char(50);
	xDES3	char(50);
	xDES4	char(50);
	xDES5	char(50);
	xDES6	char(50);
    xDES7	char(50);

    xCodPostal 	char(5);
    xNIF	 	CHAR(10);
    i 			integer;
    xRegis 		integer;

    xPoblacion	CONTRIBUYENTES.Poblacion%Type;
    xProvincia	CONTRIBUYENTES.Provincia%Type;
	xPais		CONTRIBUYENTES.Pais%Type;


      CURSOR CRECAGUA IS Select * FROM recibos_agua
	       WHERE municipio=xMunicipio and year=xYear and periodo=xPeri and total>0;

BEGIN

	DELETE FROM RECIBOS_CAJAMADRID WHERE USUARIO=USER;

	xRegis:=0;

	SELECT count(*) into xRegis FROM recibos_agua
	WHERE municipio=xMunicipio and year=xYear and periodo=xPeri and total>0;

	FOR v_TAGUA IN CRECAGUA LOOP

		if (v_TAGUA.DNI_FACTURA IS NOT NULL ) THEN
			xNIF:=v_TAGUA.DNI_FACTURA;
		else
			xNIF:=v_TAGUA.NIF;
		end if;

		SELECT NOMBRE,CODIGO_POSTAL,POBLACION,PROVINCIA,PAIS,DOMICILIO
		INTO xNombre,xCodPostal,xPoblacion,xProvincia,xPais,xDomicilio
		FROM vwCONTRIBUYENTES WHERE NIF=xNIF;


		i:=11;

		x1:='';
		x2:='';
		x3:='';
		x4:='';
		x5:='';
		x6:='';
		x7:='';
		x8:='';
		x9:='';
		x10:='';
		x11:='';

		x1:=  v_TAGUA.CALLE||' '||v_TAGUA.NUMERO||' '||v_TAGUA.BLOQUE||
			v_TAGUA.ESCALERA||v_TAGUA.PLANTA||v_TAGUA.PISO||v_TAGUA.LETRA;
		x2 := 'Lectura anterior: ' || v_TAGUA.ANTERIOR;
		x3 := 'Lectura actual: ' || v_TAGUA.ACTUAL;
		x4 := 'Consumo: ' || v_TAGUA.CONSUMO;

		SUBTOTALES (xMUNICIPIO,xYEAR,xPERI,v_TAGUA.ABONADO,
	 		xImporte1,xImporte2,xImporte3,xImporte4,xImporte5,xImporte6,xImporte7,
			xDES1,xDES2,xDES3,xDES4,xDES5,xDES6,xDES7);

		if xImporte1>0 then
			x5 :=  SUBSTR(RTRIM(xDes1),1,29)  || ': ' || xImporte1;
		end if;

		if xImporte2>0 then
			x6 :=  SUBSTR(RTRIM(xDes2),1,29)  || ': ' || xImporte2;
		end if;

		if xImporte3>0 then
			x7 :=  SUBSTR(RTRIM(xDes3),1,29)  || ': ' || xImporte3;
		end if;

		if xImporte4>0 then
			x8 :=  SUBSTR(RTRIM(xDes4),1,29)  || ': ' || xImporte4;
		end if;

		if xImporte5>0 then
			x9 := SUBSTR(RTRIM(xDes5),1,29) || ': ' || xImporte5;
		end if;

		if xImporte6>0 then
			x10 := SUBSTR(RTRIM(xDes6),1,29) || ': ' || xImporte6;
		end if;

		if xImporte7>0 then
			x11 := SUBSTR(RTRIM(xDes7),1,29) || ': ' || xImporte7;
		end if;

		INSERT INTO RECIBOS_CAJAMADRID
			(ABONADO,NIF,NOMBRE,DOMICILIO,CODPOSTAL,POBLACION,PROVINCIA,PAIS,
			 REFERENCIA,DOMICILIADO,ENTIDAD,SUCURSAL,DC,CUENTA,
			 TOTAL,Campo1,Campo2,Campo3,Campo4,Campo5,Campo6,Campo7,Campo8,
			 Campo9,Campo10,Campo11,CAMPOS_OPCIONALES,CUANTOS_REGISTROS)
		VALUES
			(v_TAGUA.ABONADO, xNif, xNombre, substr(xDomicilio,1,40),xCODPOSTAL,
			 xPOBLACION,xPROVINCIA,xPAIS,
			 DECODE(v_TAGUA.DOMICILIADO,'S',v_TAGUA.REFERENCIA||v_TAGUA.DIGITO_CONTROL,
			        v_TAGUA.REFERENCIA),
			 DECODE(v_TAGUA.DOMICILIADO,'S','D',' '),
			 v_TAGUA.Entidad,v_TAGUA.Sucursal,v_TAGUA.DC,v_TAGUA.Cuenta,
			 v_TAGUA.TOTAL*100,x1,x2,x3,x4,x5,x6,x7,x8,x9,x10,x11,i,xRegis);

	END LOOP; --del cursor CRECAGUA

END;
/


-- *****************************************************************************************
-- Acción: Para la creación del disquete de domiciliaciones.
-- MODIFICACIÓN: 17/09/2001 Lucas Fernández Pérez. Adaptación al euro.
-- MODIFICACIÓN: 20/09/2001 M. Carmen Junco Gómez. Seleccionaba datos de la tabla
--               de Agua que ya estaban en la tabla de Recibos.
-- MODIFICACIÓN: 19/08/2002 Lucas Fernández Pérez. No deberán entrar en el disco aquellos
--		         recibos que se hayan pasado ya a Recaudación y que se encuentren
--		         ingresados o dados de baja.
--
-- MODIFICACIÓN: 03/11/2003 Lucas Fernández Pérez. Consultaba en valores sin filtrar que
--		         el tipo de objeto fuese 'R', por lo que podría consultar una liquidacion.
-- MODIFICACIÓN: 21/01/2004 Lucas Fernández Pérez. Bonificaciones por domiciliaciones.
--               Obtiene de la tabla PROGRAMAS la bonificación por domiciliación y la aplica al 
--	             importe del recibo, para que en el disco del c19 vaya el importe bonificado.
--
-- MODIFICACION: 28/05/2004 Gloria Maria Calle Hernandez. Añadido campo AYTO a la tabla 
--			  Recibos_Cuadreno19 para generar ficheros por ayuntamientos (xej. Catoure).
--
-- MODIFICACIÓN: 06/02/2007 Lucas Fernández Pérez. Ampliación de la variable xDomi_Titular para recoger el 
--					nuevo domicilio con bloque y portal.
-- 
-- ****************************************************************************************

CREATE OR REPLACE PROCEDURE Cuaderno19_Agua (
	xYear 		IN	CHAR,
	xPeri 		IN	CHAR,
	xEstado 		IN	CHAR)
AS
	xNIF_TITULAR		CHAR(10);
	xNombre 			char(40);
	xNombre_Titular 	char(40);
	xDomi_Titular 		char(60);
	xEntidad 			char(4);
	xSucursal 			char(4);
	xDC 				char(2);
	xCuenta 			char(10);
	xAbonado 			INTEGER;
    xMuni				char(3);

	x2 				char(40);
	x3				char(40);
	x4 				char(40);
	x5 				char(40);
	x6 				char(40);
	x7 				char(40);
	x8 				char(40);
	x9 				char(40);
	x10 				char(40);
	x11 				char(40);
	x12 				char(40);
	x13 				char(40);
	x14 				char(40);
	x15 				char(40);
	x16 				char(40);
	xCodPostal 			char(5);
	xTitular 			char(10);
	xMuniTitular 		char(35);
	xProvincia			CONTRIBUYENTES.Provincia%Type;

	I 				INTEGER;
	xRegis 			INTEGER;


	xDescrip 	char(50);
	xDOMICILIO 	char(60);

	xCONCEPTO			CHAR(6);
	xBONIDOMI			FLOAT;
	xF_INGRESO			DATE;
	xFECHA_DE_BAJA		DATE;

	CURSOR CRECIAGUA IS SELECT * FROM RECIBOS_AGUA
				  WHERE YEAR=xYEAR AND PERIODO=xPERI AND ESTADO_BANCO=xESTADO AND TOTAL>0
		  	       AND MUNICIPIO IN (SELECT DISTINCT MUNICIPIO FROM TMP_AYTOS WHERE USUARIO=USER);

	CURSOR CDESGLOSE_AGUA IS SELECT MUNICIPIO,TARIFA,BASE_IVA,IMPORTE
					 FROM DESGLOSE_AGUAS
				       WHERE MUNICIPIO=xMUNI AND YEAR=xYEAR AND
						 PERIODO=xPERI AND ABONADO=xABONADO;

 BEGIN

   --Borrar los datos de este usuario de la tabla temporal
   DELETE FROM RECIBOS_CUADERNO19 WHERE USUARIO=USER;

   xRegis:=0;

   SELECT COUNT(*) INTO xREGIS FROM RECIBOS_AGUA
    WHERE YEAR=xYEAR AND PERIODO=xPERI AND ESTADO_BANCO=xESTADO AND TOTAL>0
	  AND MUNICIPIO IN (SELECT DISTINCT MUNICIPIO FROM TMP_AYTOS WHERE USUARIO=USER);

    -- recogemos el concepto y la bonificacion por domiciliaciones para el AGUA
   SELECT CONCEPTO,PORC_BONIFI_DOMI INTO xCONCEPTO,xBoniDomi
    FROM PROGRAMAS WHERE PROGRAMA='AGUA';

   FOR v_RecAGUA IN CRECIAGUA
   LOOP

	begin
		SELECT F_INGRESO,FECHA_DE_BAJA INTO xF_INGRESO,xFECHA_DE_BAJA
		FROM VALORES WHERE AYTO=v_RecAGUA.MUNICIPIO AND PADRON=xCONCEPTO AND
					 YEAR=v_RecAGUA.YEAR AND PERIODO=v_RecAGUA.PERIODO AND
					 RECIBO=v_RecAGUA.ABONADO AND TIPO_DE_OBJETO='R';
		Exception
		   When no_data_found then
			xF_INGRESO:=NULL;
			xFECHA_DE_BAJA:=NULL;
	end;

	IF ((xF_INGRESO IS NULL) AND (xFECHA_DE_BAJA IS NULL)) THEN

		xABONADO:=v_RecAGUA.ABONADO;
	    xMUNI:=v_RecAGUA.MUNICIPIO;

		IF v_RecAGUA.DNI_TITULAR IS NULL THEN
		   xNIF_TITULAR:=v_RecAGUA.NIF;
		ELSE
		   xNIF_TITULAR:=v_RecAGUA.DNI_TITULAR;
		END IF;
      	GETContribuyente(xNIF_TITULAR,xNOMBRE_TITULAR,xMuniTitular,
                       xProvincia,xCodPostal,xDomi_Titular);


		I:=1;

		--segundo campo de concepto opcional (introducimos el domicilio tributario)
		x2 := rtrim(substr(v_RecAGUA.CALLE,1,23))||' '||rtrim(v_RecAGUA.NUMERO)||' '||
			rtrim(v_RecAGUA.BLOQUE)||' '||rtrim(v_RecAGUA.ESCALERA)||' '||
			rtrim(v_RecAGUA.PLANTA)||' '||rtrim(v_RecAGUA.PISO)||' '||
			rtrim(v_RecAGUA.LETRA);

		--esto es para controlar que el Ayuntamiento tenga servicio de agua, como Salobreña
		if (v_RecAGUA.Consumo > 0) then
		   x3 := 'Lectura anterior: '||v_RecAGUA.ANTERIOR;
		   x4 := 'Lectura actual: '||v_RecAGUA.ACTUAL;
		   x5 := 'Consumo: ' ||v_RecAGUA.CONSUMO;
		   I:=4;
		end if;


		FOR v_Desglose IN CDESGLOSE_AGUA
		LOOP

	 	   begin
  		      SELECT DESCRIPCION INTO xDESCRIP FROM TARIFAS_AGUA
	            WHERE TARIFA=v_Desglose.Tarifa AND MUNICIPIO=v_Desglose.MUNICIPIO;
		   Exception
			   When no_data_found then
				xDESCRIP:='';
		   end;

		   if (v_Desglose.Base_IVA='I') then
			xDescrip:='IVA ' ||lTrim(rTrim(xDescrip));
		   END IF;

	   	   I:=I+1;
   		   if (I=2) then
			x3 := SUBSTR(rTrim(xDescrip),1,30)||': '||v_Desglose.Importe;
		   elsif (I=3) then
			x4 := SUBSTR(rTrim(xDescrip),1,30)||': '||v_Desglose.Importe;
	   	   elsif (I=4) then
			x5 := substr(rTrim(xDescrip),1,30)||': '||v_Desglose.Importe;
		   elsif (I=5) then
			x6 := substr(rTrim(xDescrip),0,29)||': '||v_Desglose.Importe;
	         elsif (I=6) then
			x7 := substr(rTrim(xDescrip),0,29)||': '||v_Desglose.Importe;
		   elsif (I=7) then
			x8 := substr(rTrim(xDescrip),0,29)||': '||v_Desglose.Importe;
		   elsif (I=8) then
			x9 := substr(rTrim(xDescrip),0,29)||': '||v_Desglose.Importe;
		   elsif (I=9) then
	      	x10:= substr(rTrim(xDescrip),0,29)||': '||v_Desglose.Importe;
		   elsif (I=10) then
			x11:= substr(rTrim(xDescrip),0,29)||': '||v_Desglose.Importe;
		   elsif (I=11) then
			x12:= substr(rTrim(xDescrip),0,29)||': '||v_Desglose.Importe;
		   elsif (I=12) then
			x13:= substr(rTrim(xDescrip),0,29)||': '||v_Desglose.Importe;
		   elsif (I=13) then
			x14:= substr(rTrim(xDescrip),0,29)||': '||v_Desglose.Importe;
	  	   elsif (I=14) then
			x15:= substr(rTrim(xDescrip),0,29)||': '||v_Desglose.Importe;
		   elsif (I=15) then
			x16:= substr(rTrim(xDescrip),0,29)||': '||v_Desglose.Importe;
		   end if;

		END LOOP;


      	INSERT Into RECIBOS_CUADERNO19
	       (AYTO,ABONADO,NIF,NOMBRE,DOMICILIO,CODPOSTAL,MUNICIPIO,NOMBRE_TITULAR,
		    ENTIDAD,SUCURSAL,DC,CUENTA,TOTAL,
		    Campo2, Campo3, Campo4, Campo5, Campo6, Campo7, Campo8, Campo9,
		    Campo10, Campo11, Campo12, Campo13, Campo14, Campo15, Campo16,
		    CAMPOS_OPCIONALES, CUANTOS_REGISTROS)
 		VALUES
		   (v_RecAGUA.MUNICIPIO,v_RecAGUA.ABONADO,xNIF_TITULAR,v_RecAGUA.NOMBRE,
			SUBSTR(xDOMI_TITULAR,1,40),xCODPOSTAL,xMUNITITULAR, xNOMBRE_TITULAR,
		    	v_RecAGUA.ENTIDAD,v_RecAGUA.SUCURSAL,v_RecAGUA.DC,v_RecAGUA.CUENTA,
		    	ROUND(v_RecAGUA.TOTAL*(1-(xBoniDomi/100)),2),
		    	x2, x3, x4, x5, x6, x7, x8, x9, x10, x11, x12, x13,
			x14, x15, x16, I, xREGIS);

	END IF;

   END LOOP;

END;
/

/*******************************************************************************
Acción: Para el listado del padrón de Aguas.
MODIFICACIÓN: 17/09/2001 Lucas Fernández Pérez. Adaptación al euro.
   No se necesita leer el nombre pues está en la tabla de referencia, la se ejecuta más
   rápido de esta manera.
MODIFICACION: 11/01/2005. Gloria Maria Calle Hernandez. Añadido campo contador a la tabla 
   de impresión.
*******************************************************************************/

CREATE OR REPLACE PROCEDURE Listado_Padron_Agua (
    xMunicipio		IN	char,
	xYear 			IN	char,
	xPeri 			IN	char,
	xDOMI			IN	CHAR)
as
	xAbonado 		integer;
	xNif			char(10);
	xNombre	 		char(40);

	xCALLE			char(25);
	xNUMERO 		char(3);
	xBLOQUE 		char(1);
	xESCALERA 		char(1);
	xPLANTA 		char(2);
	xPISO 			char(2);
	xLETRA 			char(2);

	xAnterior 		integer;
	xActual 		integer;
	xConsumo 		integer;
	xTotal			FLOAT;
	x1 				FLOAT;
	x2 				FLOAT;
	x3 				FLOAT;
	x4 				FLOAT;
	x5 				FLOAT;
	x6 				FLOAT;
	x7 				FLOAT;
	xDOMICILIADO 	char(1);

	xDes1 			char(50);
	xDes2 			char(50);
	xDes3 			char(50);
	xDes4 			char(50);
	xDes5 			char(50);
	xDes6 			char(50);
	xDes7 			char(50);
	
	xCONTADOR		VARCHAR2(10);

	CURSOR CURSOR_LISTADO_PADRON_AGUA IS
	   SELECT NIF,ABONADO,TOTAL,ANTERIOR,ACTUAL,CONSUMO,CALLE,BLOQUE,
                NUMERO,ESCALERA,PLANTA,PISO,LETRA,DOMICILIADO,NOMBRE,CONTADOR
	   FROM RECIBOS_AGUA WHERE MUNICIPIO=xMUNICIPIO AND YEAR=xYEAR AND PERIODO=xPERI;
BEGIN

   DELETE FROM TABLA_LISTADO_PADRON WHERE USUARIO=USER;


   OPEN CURSOR_LISTADO_PADRON_AGUA;
   LOOP
	  FETCH CURSOR_LISTADO_PADRON_AGUA INTO xNif,xAbonado,xTotal,xANTERIOR,
                  xACTUAL,xCONSUMO,xCALLE,xBLOQUE,xNUMERO,xESCALERA,xPLANTA,xPISO,
                  xLETRA,xDOMICILIADO,xNOMBRE,xCONTADOR;
	  EXIT WHEN CURSOR_LISTADO_PADRON_AGUA%NOTFOUND;


	  SUBTOTALES(xMunicipio,xYear,xPeri,xAbonado,x1,x2,x3,x4,x5,x6,x7,xDes1,xDes2,xDes3,xDes4,
		     xDes5,xDes6,xDes7);

 	  IF (xDOMICILIADO=xDOMI OR xDOMI='T') THEN
	     
 	      INSERT INTO TABLA_LISTADO_PADRON
	       (usuario,xMunicipio,xYear,xPeriodo,xDomiciliado,xNIF,xAbonado,xNombre,xTotal,
            xANTERIOR,xACTUAL,xCONSUMO,x1,x2,x3,x4,x5,x6,x7,xCALLE,xBLOQUE,xNUMERO,
            xESCALERA,xPLANTA,xPISO,xLETRA,xCONTADOR)
	   	  VALUES
	       (USER,xMunicipio,xYear,xPeri,xDomiciliado,xNIF,xAbonado,xNombre,
		    ROUND(xTotal,2),xANTERIOR,xACTUAL,xCONSUMO,
			ROUND(x1,2),ROUND(x2,2),ROUND(x3,2),ROUND(x4,2),ROUND(x5,2),ROUND(x6,2),
            ROUND(x7,2),xCALLE,xBLOQUE,xNUMERO,xESCALERA,xPLANTA,xPISO,xLETRA,xCONTADOR);
	  END IF;
   END LOOP;
   CLOSE CURSOR_LISTADO_PADRON_AGUA;
END;
/

/*******************************************************************************
Acción: Para imprimir los recibos de agua.
MODIFICACIÓN: 14/09/2001 Lucas Fernández Pérez. Adaptación al euro.
MODIFICACIÓN: 25/07/2005 Gloria Maria Calle Hernandez. Tomar direccion fiscal del inquilino o titular de la cuenta.
Modificación: 05/02/2007. Lucas Fernández Pérez. Se accede al campo DOMICILIO de la nueva vista vwCONTRIBUYENTES.
*******************************************************************************/
CREATE OR REPLACE PROCEDURE DAME_DATOS (
	xMUNICIPIO		IN	CHAR,
	xNIF			IN	CHAR,
	xINQUILINO		IN	CHAR,
	xYEAR 			IN	CHAR,
	xPERI 			IN	CHAR,
	xABONADO 		IN	INTEGER,

	xNombre 		OUT	char,
	xDomiFiscal 	OUT	char,
	xCodPostal 		OUT	char,
	xPoblacion 		OUT	char,
	xProvincia 		OUT	char,
	xNombreInqui 	OUT	char,
	xDomiFisInqui   OUT	char,
	xCodPostalInqui	OUT	char,
	xPoblacionInqui	OUT	char,
	xProvinciaInqui	OUT	char,
	x1 			OUT	FLOAT,
	x2 			OUT	FLOAT,
	x3 			OUT	FLOAT,
	x4			OUT	FLOAT,
	x5 			OUT	FLOAT,
	x6 			OUT	FLOAT,
	x7			OUT	FLOAT,

	xDes1 		OUT	CHAR,
	xDes2 		OUT	CHAR,
	xDes3 		OUT	CHAR,
	xDes4 		OUT	CHAR,
	xDes5 		OUT	CHAR,
	xDes6 		OUT	CHAR,
	xDes7 		OUT	CHAR
)
AS
BEGIN
   xNombreInqui:=null;
   xDomiFisInqui:=null;
   xPoblacionInqui:=null;
   xProvinciaInqui:=null;
   xCodPostalInqui:=null;
   xNombre:=null;
   xDomiFiscal:=null;
   xPoblacion:=null;
   xProvincia:=null;
   xCodPostal:=null;

   select nombre,DOMICILIO,POBLACION,PROVINCIA,CODIGO_POSTAL
     INTO xNombre,xDOMIFISCAL,xPoblacion,xProvincia,xCodPostal
   from vwContribuyentes where nif=xNif;

  /*para saber el nombre y direccion del inquilino*/
   begin
      select nombre,DOMICILIO,POBLACION,PROVINCIA,CODIGO_POSTAL
        INTO xNombreInqui,xDOMIFISInqui,xPoblacionInqui,xProvinciaInqui,xCodPostalInqui
        from vwContribuyentes where nif=xINQUILINO;
   
	Exception
	   When no_data_found then
	      null;
   end;

   SUBTOTALES(xMunicipio,xYear,xPeri,xAbonado,x1,x2,x3,x4,x5,x6,x7,xDes1,xDes2,xDes3,xDes4,
		  xDes5,xDes6,xDes7);
END;
/


/*******************************************************************************
Acción: Para la impresión de los recibos de Agua.
MODIFICACIÓN: 14/09/2001 Lucas Fernández Pérez. Adaptación al euro.
MODIFICACIÓN: 18/09/2001 M. Carmen Junco Gómez. En la inserción se estaba pasando al
		  usuario USER en vez del UID.
		  Sólo 8 caracteres del importe para el código de barras.
MODIFICACIÓN: 26/02/2002 M. Carmen Junco Gómez. Redondeaba los importes porque en el
		  procedimiento estaban las variables definidas como enteros.
MODIFICACIÓN: 22/07/2004 Gloria Maria Calle Hernandez. Añadidos campos f_lectura_actual
		  y f_lectura_anterior a la impresion de los recibos de agua.
MODIFICACIÓN: 24/09/2004 Gloria Maria Calle Hernandez. Modulado junto con el procedimiento 
      WriteTempAgua por la necesidad de imprimir recibos almacenandolos uno a uno sin borrar
      de la tabla temporal de impresion.
MODIFICACIÓN: 05/09/2005 Gloria Mª Calle Hernandez. Añadido impresión ordenada por
		  codigo postal y domicilio fiscal.
*******************************************************************************/

CREATE OR REPLACE PROCEDURE Imprime_Recibos_Agua (
               xMUNICIPIO IN CHAR,
               xID 	  	  IN INTEGER,
               xYEAR 	  IN CHAR,
               xPERI 	  IN CHAR,
               xDOMI 	  IN CHAR,
               xRECIDESDE IN INTEGER,
               xRECIHASTA IN INTEGER,
		   	   		 xOrden	  IN char)
AS
   x_RegistroAgua	Recibos_Agua%ROWTYPE;
   I		        INTEGER;

CURSOR CAlfabetico IS
	   select * FROM RECIBOS_AGUA
         WHERE MUNICIPIO=xMUNICIPIO	and YEAR=xYear and PERIODO=xPeri and DOMICILIADO=xDomi
	order by nombre,abonado;

CURSOR CCallejero IS
	   select * FROM RECIBOS_AGUA
         WHERE MUNICIPIO=xMUNICIPIO	and YEAR=xYear and PERIODO=xPeri and DOMICILIADO=xDomi
	order by domicilio,abonado;

CURSOR CCodPostalDom IS
	   select * FROM RECIBOS_AGUA
         WHERE MUNICIPIO=xMUNICIPIO	and YEAR=xYear and PERIODO=xPeri and DOMICILIADO=xDomi
	order by codigo_postal,domicilio;

BEGIN

   I:=0;

   DELETE FROM IMP_RECIBOS_AGUA WHERE USUARIO=UID;

   IF (xID<>0 ) then
	  SELECT * INTO x_RegistroAgua FROM RECIBOS_AGUA
   	   WHERE ID=xID;

	  WriteTempAgua(x_RegistroAgua,xMUNICIPIO,xYEAR,xPERI); 

    ELSE  /* DEL xID<>0 */

	if xOrden='A' then

	   OPEN CAlfabetico;
	   LOOP
	      FETCH CAlfabetico INTO x_RegistroAgua;
  	  	  EXIT WHEN CAlfabetico%NOTFOUND;

 		  I:=I+1;

		  IF (I >= xReciDesde and I <= xReciHasta) THEN
		  	 
			  WriteTempAgua(x_RegistroAgua,xMUNICIPIO,xYEAR,xPERI); 
		  ELSE
               IF I > XRECIHASTA THEN
		          EXIT;
               END IF;
          END IF;

	   END LOOP;
	   CLOSE CAlfabetico;

	elsif xOrden='D' then

	   OPEN CCodPostalDom;
	   LOOP
	      FETCH CCodPostalDom INTO x_RegistroAgua;
  	  	  EXIT WHEN CCodPostalDom%NOTFOUND;

 		  I:=I+1;

		  IF (I >= xReciDesde and I <= xReciHasta) THEN
		  	 
			  WriteTempAgua(x_RegistroAgua,xMUNICIPIO,xYEAR,xPERI); 
		  ELSE
               IF I > XRECIHASTA THEN
		          EXIT;
               END IF;
          END IF;

	   END LOOP;
	   CLOSE CCodPostalDom;

	else

	   OPEN CCallejero;
	   LOOP
	      FETCH CCallejero INTO x_RegistroAgua;
		  EXIT WHEN CCallejero%NOTFOUND;

  		  I:=I+1;

		  IF (I >= xReciDesde and I <= xReciHasta) THEN

   		  	  WriteTempAgua(x_RegistroAgua,xMUNICIPIO,xYEAR,xPERI); 

		  ELSE
               IF I > XRECIHASTA THEN
  		          EXIT;
               END IF;
          END IF;

	   END LOOP;
	   CLOSE CCallejero;
	END IF;

    END IF;	 /* DEL xID<>0 */
END;
/



/*******************************************************************************
Acción: Para el almacenamiento y posterior impresion de un recibo de agua univoco
CREACION: 24/09/2004 Gloria Maria Calle Hernandez
MODIFICACION: 27/09/2004 Mª del Carmen Junco Gómez. Se estaban incluyendo los dígitos
				  de control bancarios como los dígitos de control modalidad 1
MODIFICACION: 25/07/2005 Gloria Maria Calle Hernandez. Añadidos campos sobre domicilio fiscal
				del titular de la cuenta. 
MODIFICACION: 28/07/2005 Agustín León Robles. El codigo de barras estaba 90501 y tiene que ser 90502
MODIFICACION: 05/02/2007 Lucas Fernández Pérez. La llamada a DAME_DATOS devuelve los domicilios con longitud 60,
				se modifica la longitud de las variables que lo recojen para que no falle.
*******************************************************************************/

CREATE OR REPLACE PROCEDURE WriteTempAgua (
	   xRegistroAgua 	IN Recibos_Agua%ROWTYPE,
	   xMUNICIPIO 		IN CHAR,
	   xYEAR 	  		IN CHAR,
	   xPERI 	  		IN CHAR)
AS
   xNOMBRE         CHAR(40);
   xDOMIFISCAL     CHAR(60);
   xCODPOSTAL      CHAR(5);
   xPOBLACION      CHAR(35);
   xPROVINCIA      CHAR(35);
   xNOMBRE_TIT     CHAR(40);
   xDOMIFISCAL_TIT CHAR(60);
   xCODPOSTAL_TIT  CHAR(5);
   xPOBLACION_TIT  CHAR(35);
   xPROVINCIA_TIT  CHAR(35);

   xDOMITRIBU 	   CHAR(50);
   xNOMBRE_ENTIDAD CHAR(50);
   xHASTA1		   DATE;

   x1 		 	   FLOAT;
   x2 			   FLOAT;
   x3 		 	   FLOAT;
   x4 		 	   FLOAT;
   x5 		 	   FLOAT;
   x6 		 	   FLOAT;
   x7 		 	   FLOAT;

   xDes1 	 	   CHAR(50);
   xDes2 	 	   CHAR(50);
   xDes3 	 	   CHAR(50);
   xDes4 	 	   CHAR(50);
   xDes5 	 	   CHAR(50);
   xDes6 	 	   CHAR(50);
   xDes7 	 	   CHAR(50);

BEGIN

	 xDOMITRIBU:=xRegistroAgua.CALLE||' '||xRegistroAgua.NUMERO||' '||xRegistroAgua.BLOQUE||' '||
	  						xRegistroAgua.ESCALERA||' '||xRegistroAgua.PLANTA||' '||xRegistroAgua.PISO||' '||xRegistroAgua.LETRA;

	 DAME_DATOS(xMUNICIPIO,xRegistroAgua.NIF,xRegistroAgua.DNI_FACTURA,xYEAR,xPERI,xRegistroAgua.ABONADO,xNOMBRE,
	            xDOMIFISCAL,xCODPOSTAL,xPOBLACION,xPROVINCIA,xNOMBRE_TIT,xDOMIFISCAL_TIT,xCODPOSTAL_TIT,xPOBLACION_TIT,xPROVINCIA_TIT,
				x1,x2,x3,x4,x5,x6,x7,xDes1,xDes2,xDes3,xDes4,xDes5,xDes6,xDes7);

 	  /* En caso de estar domiciliado, nombre de la Entidad */
     xNOMBRE_ENTIDAD:='';
	 begin
	     SELECT NOMBRE INTO xNOMBRE_ENTIDAD FROM ENTIDADES WHERE CODIGO=xRegistroAgua.ENTIDAD;
     EXCEPTION
		 WHEN NO_DATA_FOUND THEN
		      NULL;
	 end;

	 xHASTA1:=xRegistroAgua.HASTA+1; /* fecha del hasta mas un día */

     INSERT INTO IMP_RECIBOS_AGUA
		(USUARIO,ANIO,PERIODO,ABONADO,NIF,NOMBRE,DOMIFISCAL,CODPOSTAL,POBLACION,
		 PROVINCIA,DOMITRIBU,Anterior,Actual,Consumo,Total,IMPORTE1,IMPORTE2,IMPORTE3,
		 IMPORTE4,IMPORTE5,IMPORTE6,IMPORTE7,TITULO1,TITULO2,TITULO3,TITULO4,TITULO5,
     	 TITULO6,TITULO7,REFERENCIA,DC,TRIBUTO,EJERCICIO,
     	 REMESA,IMPO,EMISOR,DESDE,HASTA,CARGO,HASTA1,ENTIDAD,SUCURSAL,DIGITOS,
     	 CUENTA,TITULAR,NOMBRE_ENTIDAD,
     	 NOMBRE_TITULAR,DOMIFISCAL_TIT,CODPOSTAL_TIT,POBLACION_TIT,PROVINCIA_TIT,
     	 CONCEPTO,DISCRI_PERIODO,DIGITO_YEAR,F_JULIANA,DIGITO_C60_MODALIDAD2,
		 COD_BARRAS_MOD1,COD_BARRAS_MOD2,
		 F_LECTURA_ACTUAL,F_LECTURA_ANTERIOR)
    VALUES
		(UID,xYEAR,xPERI,xRegistroAgua.ABONADO,xRegistroAgua.NIF,xNOMBRE,xDOMIFISCAL,
		 xCODPOSTAL,xPOBLACION,xPROVINCIA,xDOMITRIBU,xRegistroAgua.Anterior,xRegistroAgua.Actual,
		 xRegistroAgua.Consumo,xRegistroAgua.Total,x1,x2,x3,x4,x5,x6,x7,xDes1,xDes2,xDes3,xDes4,xDes5,xDes6,xDes7,
		 xRegistroAgua.REFERENCIA,xRegistroAgua.DIGITO_CONTROL,xRegistroAgua.TRIBUTO,xRegistroAgua.EJERCICIO,
     	 xRegistroAgua.REMESA,xRegistroAgua.IMPORTE,xRegistroAgua.EMISOR,xRegistroAgua.DESDE,xRegistroAgua.HASTA,
     	 xRegistroAgua.F_CARGO,xHASTA1,xRegistroAgua.ENTIDAD,xRegistroAgua.SUCURSAL,xRegistroAgua.DC,xRegistroAgua.CUENTA,
     	 xRegistroAgua.DNI_FACTURA,xNOMBRE_ENTIDAD,
     	 xNOMBRE_TIT,xDOMIFISCAL_TIT,xCODPOSTAL_TIT,xPOBLACION_TIT,xPROVINCIA_TIT,
		 xRegistroAgua.CONCEPTO_DEL_RECIBO,xRegistroAgua.DISCRI_PERIODO,xRegistroAgua.DIGITO_YEAR,xRegistroAgua.F_JULIANA,
     	 xRegistroAgua.DIGITO_C60_MODALIDAD2,
		 '90502'||xRegistroAgua.EMISOR||xRegistroAgua.REFERENCIA||xRegistroAgua.DIGITO_CONTROL||xRegistroAgua.TRIBUTO||xRegistroAgua.EJERCICIO||
		 xRegistroAgua.REMESA||LPAD(xRegistroAgua.IMPORTE*100,8,'0'),

		 '90521'||xRegistroAgua.EMISOR||xRegistroAgua.REFERENCIA||xRegistroAgua.DIGITO_C60_MODALIDAD2||xRegistroAgua.DISCRI_PERIODO||
		 xRegistroAgua.TRIBUTO||xRegistroAgua.EJERCICIO||xRegistroAgua.DIGITO_YEAR||xRegistroAgua.F_JULIANA||LPAD(xRegistroAgua.IMPORTE*100,8,'0')||'0',

 		 xRegistroAgua.F_LECTURA_ACTUAL,xRegistroAgua.F_LECTURA_ANTERIOR);
END;
/





/*******************************************************************************
Acción: Para el cálculo de un abonado cuando se modifican sus lecturas en los recibos.
MODIFICACIÓN: 17/09/2001 Lucas Fernández Pérez. Adaptación al euro.

MODIFICACIÓN: 27/01/2004 Agustín León Robles. 
			  Hace el prorrateo de la cuota fija en funcion de la fecha de alta
*******************************************************************************/

CREATE OR REPLACE PROCEDURE ESPECIAL_LINEAS_RECIBO (
	xMUNICIPIO		IN		CHAR,
	xABONADO		IN		INTEGER,
	xYEAR			IN		CHAR,
	xPERIODO		IN		CHAR,
	xNIF 			IN		CHAR,
	xCONSUMO 		IN OUT	INTEGER,
	SiGraba			IN 		CHAR,
	xID_VARIACIONES	IN		INTEGER,
	xSuma 			OUT  	FLOAT,
	xTARIFA_AGUA 	OUT		CHAR,
	xBL_TA 			OUT		CHAR
)
AS

	xTARIFA			CHAR(4);
	xTIPO_IVA 		FLOAT;
	xTieneIVA 		CHAR(1);
	xTIPO 			CHAR(2);
	xBASE 			FLOAT;
	xIVA  			FLOAT;
	xIMPORTE		FLOAT;

	xBLOQUE1 		INTEGER;
	xBLOQUE2 		INTEGER;
	xBLOQUE3		INTEGER;
	xBLOQUE4 		INTEGER;
	xPRECIO1		FLOAT;
	xPRECIO2		FLOAT;
	xPRECIO3		FLOAT;
	xPRECIO4		FLOAT;
	xFIJO1			FLOAT;
	xFIJO2			FLOAT;
	xFIJO3			FLOAT;
	xFIJO4			FLOAT;
	
	xFAlta			date;
	xDias			integer;
	xDiasPeriodo	integer;

	CURSOR CURSOR_ESPECIAL_LINEAS_RECIBO IS
		SELECT TARIFA FROM HISTO_DESGLOSE_AGUAS
		WHERE MUNICIPIO=xMUNICIPIO AND YEAR=xYEAR AND PERIODO=xPERIODO 
		AND ABONADO=xABONADO AND BASE_IVA='B' AND ID=xID_VARIACIONES;
BEGIN

   xSuma:=0;

   select Fecha_Alta into xFAlta from Agua where ID=xAbonado; 
      
   PutDatosAguaPeriodos(xMUNICIPIO,xYEAR,xPERIODO,xFAlta,xDias,xDiasPeriodo);

   /* Se busca en esta tabla porque puede que varien los servicios contratados por el abonado */
   OPEN CURSOR_ESPECIAL_LINEAS_RECIBO;
   LOOP
	FETCH CURSOR_ESPECIAL_LINEAS_RECIBO INTO xTARIFA;
	EXIT WHEN CURSOR_ESPECIAL_LINEAS_RECIBO%NOTFOUND;
	xTIPO:=NULL;

      begin

	   SELECT BLOQUE1,BLOQUE2,BLOQUE3,BLOQUE4,PRECIO1,PRECIO2,PRECIO3,PRECIO4,
                FIJO1,FIJO2,FIJO3,FIJO4,IVA,TIPO_IVA,TIPO_TARIFA
   	   INTO xBLOQUE1,xBLOQUE2,xBLOQUE3,xBLOQUE4,xPRECIO1,xPRECIO2,xPRECIO3,xPRECIO4,
                xFIJO1,xFIJO2,xFIJO3,xFIJO4,xTieneIVA,xTIPO_IVA,xTIPO
	   FROM  HISTO_TARIFAS_AGUA
	   WHERE MUNICIPIO=xMUNICIPIO AND YEAR=xYEAR AND PERIODO=xPERIODO AND TARIFA=xTARIFA;

	   Exception
		When no_data_found then
		   xTIPO:=NULL;
      end;

	/* Si es nulo es porque es una tarifa que está todavía vigente */
	IF (xTIPO IS NULL) THEN
	  Select IVA,TIPO_IVA,T.TIPO Into xTieneIVA,xTIPO_IVA,xTIPO
	  From TIPO_TARIFA T, TARIFAS_AGUA A
	  Where T.TIPO=A.TIPO_TARIFA and A.TARIFA=xTARIFA and T.MUNICIPIO=A.MUNICIPIO and
		  T.MUNICIPIO=xMUNICIPIO;

	  Select BLOQUE1,BLOQUE2,BLOQUE3,BLOQUE4,PRECIO1,PRECIO2,PRECIO3,PRECIO4,FIJO1,FIJO2,
		   FIJO3,FIJO4 Into xBLOQUE1,xBLOQUE2,xBLOQUE3,xBLOQUE4,xPRECIO1,xPRECIO2,xPRECIO3,
		   xPRECIO4,xFIJO1,xFIJO2,xFIJO3,xFIJO4
	  From  TARIFAS_AGUA Where TARIFA=xTARIFA AND MUNICIPIO=xMUNICIPIO;

	END IF;

	/* Averiguamos el código de tarifa del agua (para las estadísticas */
	IF (xTIPO='01') THEN
	  xTARIFA_AGUA:=xTARIFA;
	  IF (xCONSUMO<=xBLOQUE1) THEN
	    xBL_TA:='B1';
	  ELSIF (xCONSUMO<=xBLOQUE2 AND xCONSUMO>xBLOQUE1) THEN
	    xBL_TA:='B2';
	  ELSIF (xCONSUMO<=xBLOQUE3 AND xCONSUMO>xBLOQUE2) THEN
	    xBL_TA:='B3';
        ELSIF (xCONSUMO<=xBLOQUE4 AND xCONSUMO>xBLOQUE3) THEN
	    xBL_TA:='B4';
	  END IF;
	END IF;

	xIVA:=0;
	
    If (xBLOQUE1=0) then	  
		xBASE:=Round( (xFIJO1 * xDias) / xDiasPeriodo , 2);
	else
		Importes_Calculo_Agua(xCONSUMO, xPRECIO1, xBLOQUE1, xFIJO1,xPRECIO2 ,xBLOQUE2,xFIJO2,
				xPRECIO3 ,xBLOQUE3,xFIJO3,xPRECIO4 ,xBLOQUE4,xFIJO4,xDiasPeriodo,xDias,xBASE);
	end if;

	/* Apunte de la base imponible */
	IF (SiGraba='S') THEN
	  Insert Into DESGLOSE_AGUAS
		(ABONADO,MUNICIPIO,YEAR,PERIODO,NIF,TARIFA,IMPORTE,BASE_IVA,TIPO_TARIFA)
 	  Values
		(xABONADO,xMUNICIPIO,xYEAR,xPERIODO,xNIF,xTARIFA,ROUND(xBASE,2),'B',xTIPO);
	end if;

	/* Apunte del IVA si tuviera */
	IF (xTieneIVA='S' AND xBase >0) THEN
         xIVA:=xBase*xTipo_IVA/100;
	   IF (SiGraba='S') THEN
	 	Insert Into DESGLOSE_AGUAS
			(ABONADO,MUNICIPIO,YEAR,PERIODO,NIF,TARIFA,IMPORTE,BASE_IVA,TIPO_TARIFA)
	 	Values
			(xABONADO,xMUNICIPIO,xYEAR,xPERIODO,xNIF,xTARIFA,ROUND(xIVA,2),'I',xTIPO);
	   end if;

	   xSuma:=ROUND(xSuma + (xBASE + xIVA),2);
	end if;

   End loop;
   close cursor_especial_lineas_recibo;

END;
/

/*******************************************************************************
Acción: Para modificar un recibo.
MODIFICACIÓN: 17/09/2001 Lucas Fernández Pérez. Adaptación al euro.
MODIFICAcion: 02/02/2004. Gloria Maria Calle Hernandez. 
			  Eliminada actualizacion sobre TRIBUTOSCONTRI, pues esta tabla pasa a rellenarse 
			  como una tabla temporal
*******************************************************************************************/

CREATE OR REPLACE PROCEDURE MODIFICA_UN_RECIBO_AGUA(
	xID			IN    INTEGER,
	xACTUAL 		IN	INTEGER,
	xANTERIOR 		IN	INTEGER,
	xID_VARIACIONES   IN	INTEGER
)
AS

	xTRIBUTO CHAR(3);
	xEJERCICIO CHAR(2);
	xREMESA CHAR(2);
	xEMISOR CHAR(6);

	xIMPORTE_RECIBO FLOAT;
	xIMPORTE CHAR(12);
	xDCONTROL CHAR(2);
	xCONSUMO INTEGER;
	xNIF CHAR(10);
	xTARIFA_AGUA CHAR(4);
	xBL_TA CHAR(2);
	xRANGO INTEGER;

	xMUNICIPIO CHAR(3);
	xYEAR CHAR(4);
	xPERIODO CHAR(2);
	xABONADO INTEGER;

BEGIN

   SELECT MUNICIPIO,YEAR,PERIODO,ABONADO,TRIBUTO,EJERCICIO,REMESA,EMISOR,NIF
   INTO xMUNICIPIO,xYEAR,xPERIODO,xABONADO,xTRIBUTO,xEJERCICIO,xREMESA,xEMISOR,xNIF
   FROM RECIBOS_AGUA
   WHERE ID=xID;

   /* CALCULA LAS LINEAS DE DETALLE Y NOS PERMITE CONOCER EL IMPORTE DEL RECIBO */
   if (xACTUAL < xANTERIOR) then
	AVERIGUA_PESO(xACTUAL,xANTERIOR,xCONSUMO,xRANGO);
   else
	xCONSUMO := xACTUAL - xANTERIOR;
   END IF;

   /*En la primera pasada solo calcula los importes*/
   ESPECIAL_LINEAS_RECIBO(xMUNICIPIO,xABONADO,xYEAR,xPERIODO,xNIF,xCONSUMO,'N',xID_VARIACIONES,
                          xIMPORTE_RECIBO,xTARIFA_AGUA,xBL_TA);

   /*convierte el importe en caracter y relleno de CEROS*/

   xIMPORTE_RECIBO:=ROUND(xIMPORTE_RECIBO,2);
   ImporteEnCadena(xIMPORTE_RECIBO,xIMPORTE);

   /*para el calculo de digitos de control del cuarderno 60*/
   CALCULA_DC_60(xIMPORTE_RECIBO,xABONADO,xTRIBUTO,xEJERCICIO,xREMESA,xEMISOR,xDCONTROL);


   /*BORRA TODOS LOS IMPORTES ANTIGUOS*/
   DELETE FROM DESGLOSE_AGUAS
   WHERE YEAR=xYEAR AND PERIODO=xPERIODO AND ABONADO=xABONADO AND MUNICIPIO=xMUNICIPIO;

   /*ACTUALIZAMOS LOS NUEVOS DATOS*/
   UPDATE RECIBOS_AGUA SET ACTUAL=xACTUAL,ANTERIOR=xANTERIOR,CONSUMO=xCONSUMO,IMPORTE=xIMPORTE,
   				   TOTAL=xIMPORTE_RECIBO,DIGITO_CONTROL=xDCONTROL,BLOQUE_TA=xBL_TA,
				   ESCALERA_CONSUMO=xRANGO
   WHERE ID=xID;


   /* en esta pasada graba en el desglose */

   ESPECIAL_LINEAS_RECIBO(xMUNICIPIO,xABONADO,xYEAR,xPERIODO,xNIF,xCONSUMO,'S',xID_VARIACIONES,
		              xIMPORTE_RECIBO,xTARIFA_AGUA,xBL_TA);

END;
/

/*******************************************************************************
Acción: Modificación de las lecturas.
*******************************************************************************/

CREATE or Replace PROCEDURE MODIFI_LECTURAS (
	xID		IN    INTEGER,
	xACTUAL 	in	INTEGER,
	xANTERIOR 	in	INTEGER
)
AS
      xMUNICIPIO		CHAR(3);
      xYEAR			CHAR(4);
	xPERIODO	      CHAR(2);
	xABONADO		INTEGER;
	xCUANTOS		INTEGER;
 	xORIGINAL 		CHAR(1);
 	xOLD_ACTUAL 	INTEGER;
 	xOLD_ANTERIOR 	INTEGER;
 	xOLD_CONSUMO 	INTEGER;
 	xID_VARIACIONES   INTEGER;
 	xTARIFA_AGUA 	char(4);
 	xBLOQUE_TA 		char(2);
 	xESCALERA_CONSUMO integer;
BEGIN

	/* Primero averiguamos las lecturas anteriores, para insertarlo en variaciones */

	SELECT MUNICIPIO,YEAR,PERIODO,ABONADO,ACTUAL,ANTERIOR,CONSUMO,TARIFA_AGUA,
		 BLOQUE_TA,ESCALERA_CONSUMO
	INTO   xMUNICIPIO,xYEAR,xPERIODO,xABONADO,xOld_Actual,xOld_Anterior,xOld_Consumo,
		 xTarifa_Agua,xBloque_Ta,xEscalera_Consumo
	FROM RECIBOS_AGUA
	WHERE ID=xID;


	/* para saber si era el dato original, o si ya son varias modificaciones */

	SELECT COUNT(*) into xCuantos FROM VARIACIONES_RECIBOS_AGUA
	WHERE MUNICIPIO=xMUNICIPIO AND YEAR=xYEAR AND PERIODO=xPERIODO AND ABONADO=xABONADO;

	IF (xCUANTOS > 0) THEN
		xORIGINAL:='N';
	ELSE
		xORIGINAL:='S';
	end if;

	INSERT INTO VARIACIONES_RECIBOS_AGUA
	   (MUNICIPIO,YEAR,PERIODO,ABONADO,ORIGINAL,ANTERIOR,ACTUAL,CONSUMO,TARIFA_AGUA,
	    BLOQUE_TA,ESCALERA_CONSUMO)
	VALUES
	   (xMUNICIPIO,xYEAR,xPERIODO,xABONADO,xORIGINAL,xOLD_ANTERIOR,xOLD_ACTUAL,xOLD_CONSUMO,
	    xTARIFA_AGUA,xBLOQUE_TA,xESCALERA_CONSUMO);


	/* Recogemos el ID de variaciones_recibos_agua */
	SELECT ID_AGUA into xID_VARIACIONES FROM USUARIOSGT WHERE USUARIO=USER;

	/* Aquí insertamos para tener la historia de los importes */

	INSERT INTO HISTO_DESGLOSE_AGUAS
		(ID,MUNICIPIO,ABONADO,YEAR,PERIODO,NIF,TARIFA,
		 BLOQUE_TA,BASE_IVA,IMPORTE)

	SELECT xID_VARIACIONES,MUNICIPIO,ABONADO,YEAR,PERIODO,NIF,TARIFA,
		 BLOQUE_TA,BASE_IVA,IMPORTE
	FROM DESGLOSE_AGUAS
	WHERE YEAR=xYEAR AND PERIODO=xPERIODO AND ABONADO=xABONADO AND MUNICIPIO=xMUNICIPIO;


	MODIFICA_UN_RECIBO_AGUA(xID,xACTUAL,xANTERIOR,xID_VARIACIONES);


END;
/

/*******************************************************************************
Acción: Marcar abonados para incorporarlos al padrón.
MODIFICACIÓN: 15/02/2004 Lucas Fernández Pérez. Sólo incorpora abonados del 
		municipio del usuario o de los municipios que el usuario haya seleccionado. 
		Antes incorporaba los abonados de todos los municipios.
*******************************************************************************/
CREATE OR REPLACE PROCEDURE INCOR_PADRON_AGUA (
		xFECHA_EMISION 	IN DATE,
		xFECHA_ALTA 	IN DATE)
AS
   -- cursor que recorre los distintos municipios de los recibos que se han 
   -- incorporado al padrón en la fecha=xFecha_Emision
   CURSOR CMUNI IS SELECT DISTINCT MUNICIPIO FROM AGUA 
   			   WHERE F_INCORPORACION=xFECHA_EMISION AND
      			   MUNICIPIO IN (SELECT MUNICIPIO FROM TMP_AYTOS WHERE USUARIO=USER);
       
BEGIN

	UPDATE AGUA SET INCORPORADO='S',F_INCORPORACION=xFECHA_EMISION
	WHERE INCORPORADO='N' AND FECHA_BAJA IS NULL AND 
	(TRUNC(FECHA_ALTA,'DD')<=TRUNC(xFECHA_ALTA,'DD') OR FECHA_ALTA IS NULL)
			AND MUNICIPIO IN (SELECT MUNICIPIO FROM TMP_AYTOS WHERE USUARIO=USER);

	FOR vMUNI IN CMUNI LOOP
	
		-- Insertamos una tupla en LOGSPADRONES para controlar que esta acción ha sido ejecutada
		INSERT INTO LOGSPADRONES (MUNICIPIO,PROGRAMA,HECHO)
		VALUES (vMUNI.MUNICIPIO,'AGUA','Se realiza una Incorporación al Padrón');     
		
	END LOOP;

END;
/

/*******************************************************************************
Acción: Marcar o desmarcar un abonado para su incorporación al padrón.
*******************************************************************************/
CREATE OR REPLACE PROCEDURE ANADE_PADRON_AGUA (
       xABONADO   IN INTEGER,
       xFECHA     IN DATE,
	   xTIPO	  IN INTEGER)
AS
BEGIN
  
  IF xTIPO=0 THEN
     -- marcar el abonado para incorporarlo al padrón	
     UPDATE AGUA SET INCORPORADO='S',F_INCORPORACION=xFECHA
     WHERE ID=xABONADO;
  ELSE
     -- desmarcar el abonado para no incorporarlo al padrón
     UPDATE AGUA SET INCORPORADO='N',F_INCORPORACION=NULL
     WHERE ID=xABONADO;
  END IF;

END;
/


/********************************************************************/
COMMIT;
/********************************************************************/
