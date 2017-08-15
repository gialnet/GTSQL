CREATE OR REPLACE PROCEDURE ADD_COD_OPERACION
       (xCodOperacion OUT INTEGER)
AS
BEGIN

SELECT GEN_CODIGO_OPERACION.NEXTVAL INTO xCodOperacion FROM DUAL;

END;
/


/*******************************************************************************************/
CREATE OR REPLACE PROCEDURE NEW_USER(
       xEXISTEUS 	OUT INTEGER
)
AS

xCONT  INTEGER;

BEGIN
   SELECT COUNT(*) INTO xCONT
   FROM USUARIOSGT WHERE USUARIO=USER;
   
   IF xCONT=0 THEN
      xEXISTEUS:=0;
   ELSE
      xEXISTEUS:=1;
   END IF;
END;
/

/*******************************************************************************************
Modificado: 23/02/2005. Gloria Maria Calle Hernandez. 
			Añadido tipo de Via para modificacion y alta.
*******************************************************************************************/

CREATE OR REPLACE PROCEDURE ADD_CALLES (
       xMUNICIPIO 	IN CHAR,
 	   xNUCLEO		IN CHAR,
       xMODI 		IN CHAR,
       xCODIGO 		IN CHAR,
       xCALLE 		IN CHAR,
       xTIPOVIA		IN CHAR,
       ERROR 		OUT INTEGER)
AS
    xNADA INTEGER;
BEGIN
   ERROR:=0;
   IF (xMODI<>'S') THEN
        SELECT COUNT(*) INTO xNADA FROM CALLES
        WHERE MUNICIPIO=xMUNICIPIO AND CODIGO_CALLE=xCODIGO;
        
	  IF xNADA=0 THEN
           INSERT INTO CALLES 
	       (MUNICIPIO, CODIGO_NUCLEO, CODIGO_CALLE, CALLE, TIPO_VIA)
           VALUES 
             (xMUNICIPIO, xNUCLEO, xCODIGO, xCALLE, xTIPOVIA);
	  ELSE
           ERROR:=1;
        END IF;
   ELSE
      UPDATE CALLES SET CALLE=xCALLE,CODIGO_NUCLEO=xNUCLEO,TIPO_VIA=xTIPOVIA
      WHERE MUNICIPIO=xMUNICIPIO AND CODIGO_CALLE=xCODIGO;
   END IF;
END;
/

/*************************************************************************************/

CREATE OR REPLACE PROCEDURE ADD_NUCLEOS 
	(xMUNICIPIO 	IN CHAR,
	 xNUCLEO		IN CHAR,
       xNOMBRE_NUCLEO 	IN CHAR,
       xMODI 		IN CHAR,
       ERROR 		OUT INTEGER)
AS
    xNADA INTEGER;
BEGIN
   ERROR:=0;

   IF (xMODI<>'S') THEN
      SELECT COUNT(*) INTO xNADA FROM NUCLEOS
      WHERE MUNICIPIO=xMUNICIPIO AND CODIGO_NUCLEO=xNUCLEO;
      IF xNADA=0 THEN
         INSERT INTO NUCLEOS
           (MUNICIPIO,CODIGO_NUCLEO,NOMBRE_NUCLEO)
         VALUES 
           (xMUNICIPIO,xNUCLEO,xNOMBRE_NUCLEO);
      ELSE
	   ERROR:=1;
      END IF;
   ELSE
      UPDATE NUCLEOS SET NOMBRE_NUCLEO=xNOMBRE_NUCLEO WHERE MUNICIPIO=xMUNICIPIO 
			AND CODIGO_NUCLEO=xNUCLEO;
   END IF;
END;
/


/*******************************************************************************************/

CREATE OR REPLACE PROCEDURE ADD_ENTIDADES (
       xMODI IN CHAR,
       xCODIGO IN CHAR,
       xNOMBRE IN CHAR,
       ERROR OUT INTEGER
)
AS

    xNADA INTEGER;

BEGIN
   ERROR:=0;

   IF (xMODI<>'S') THEN
      SELECT COUNT(CODIGO) INTO xNADA FROM ENTIDADES
      WHERE CODIGO=xCODIGO;
      IF xNADA=0 THEN
         INSERT INTO ENTIDADES 
           (CODIGO,NOMBRE)
         VALUES 
           (xCODIGO,xNOMBRE);
      ELSE
	   ERROR:=1;
      END IF;
   ELSE
      UPDATE ENTIDADES SET NOMBRE=xNOMBRE
      WHERE CODIGO=xCODIGO;
   END IF;
END;
/

/*******************************************************************************************/

CREATE OR REPLACE PROCEDURE ADD_OFICINAS (
       xMODI 	IN CHAR,
       xENTIDAD 	IN CHAR,
	 xSUCURSAL	IN CHAR,
       xNOMBRE 	IN CHAR,
	 xDIRE	IN CHAR,
	 xCP		IN CHAR,
	 xLOCALIDAD IN CHAR,
       ERROR OUT INTEGER
)
AS

    xNADA INTEGER;

BEGIN

   ERROR:=0;

   IF (xMODI<>'S') THEN  /* una inserción */

      begin
         INSERT INTO OFICINAS 
         VALUES (xENTIDAD,xSUCURSAL,xNOMBRE,xDIRE,xCP,xLOCALIDAD);

    	   exception
   	      when dup_val_on_index then
               ERROR:=1;	
	end;

   ELSE

      UPDATE OFICINAS SET NOMBRE=xNOMBRE,
				   DIRECCION=xDIRE,
				   CODPOSTAL=xCP,
				   POBLACION=xLOCALIDAD
      WHERE ENTIDAD=xENTIDAD AND SUCURSAL=xSUCURSAL;

   END IF;
END;
/

/*******************************************************************************************/

CREATE OR REPLACE PROCEDURE ADD_EPIGRAFES (
       xMODI IN CHAR,
       xCODIGO IN CHAR,
       xNOMBRE IN CHAR,
       xSECCION IN CHAR,
	 xACTIVIDAD IN CHAR,
       ERROR OUT INTEGER
)
AS

    xNADA NUMBER;

BEGIN
   ERROR:=0;

   IF (xMODI<>'S') THEN
	SELECT COUNT(EPIGRAFE) INTO xNADA FROM EPIGRAFE
      WHERE EPIGRAFE=xCODIGO AND SECCION=xSECCION;
      
	IF xNADA=0 THEN
         INSERT INTO EPIGRAFE 
		(EPIGRAFE,NOMBRE,SECCION,TIPO_ACTIVIDAD)
         VALUES 
		(xCODIGO,xNOMBRE,xSECCION,xACTIVIDAD);
      ELSE
	   ERROR:=1;
      END IF;

   ELSE
      UPDATE EPIGRAFE SET NOMBRE=xNOMBRE, TIPO_ACTIVIDAD=xACTIVIDAD
      WHERE EPIGRAFE=xCODIGO AND SECCION=xSECCION;
   END IF;

END;
/

/*******************************************************************************************/

CREATE OR REPLACE PROCEDURE ADD_INCIDENCIAS (
       xMODI IN CHAR,
       xCODIGO IN CHAR,
       xDESCRIP IN CHAR,
       ERROR OUT INTEGER
)
AS

    xNADA INTEGER;

BEGIN
   ERROR:=0;

   IF (xMODI<>'S') THEN
      SELECT COUNT(CODIGO) INTO xNADA FROM INCIDENCIAS
      WHERE CODIGO=xCODIGO;
      
	IF xNADA=0 THEN
         INSERT INTO INCIDENCIAS 
		(CODIGO,DESCRIPCION)
         VALUES 
		(xCODIGO,xDESCRIP);
      ELSE
	   ERROR:=1;
      END IF;

   ELSE
      UPDATE INCIDENCIAS SET DESCRIPCION=xDESCRIP
      WHERE CODIGO=xCODIGO;
   END IF;

END;
/

/*******************************************************************************************
MODIFICACIÓN: 1/02/2002 M. Carmen Junco Gómez. Añadir mensajes de error en la conversión
		  de la emisora y la identificación.
*******************************************************************************************/
CREATE OR REPLACE PROCEDURE F_DC60(
		EMISORA 		IN CHAR,
		REFERENCIA 		IN INTEGER,
		IDENTIFICACION 	IN CHAR,
		IMPORTE 		IN FLOAT,
		DC 			IN OUT INTEGER)
AS
    xRESULT FLOAT;
    xEMISORA INTEGER;
    xIDENTIFICACION INTEGER;
BEGIN

      IF LENGTH(EMISORA)<6 THEN
         raise_application_error(-20011,'Error de conversión a valor numérico: '||
						    'comprobar valor de EMISORA');
      END IF;

	xEMISORA:=TO_NUMBER(EMISORA,999999);

	--ahora se pone diez digitos para que tambien sirva para la modalidad 2 del cuaderno 60
	--la variable IDENTIFICACION tendra unas veces valor de 7 para la modalidad 1
	--						y otras valor de 10 para la modalidad 2
	IF LENGTH(IDENTIFICACION)<7 THEN
         raise_application_error(-20012,'Error de conversión a valor numérico: '||
                                        'comprobar valor de SUFIJO');
      END IF;

	xIDENTIFICACION:=TO_NUMBER(IDENTIFICACION,9999999999);
	xRESULT:=(xEMISORA*76) + (REFERENCIA*9) +(((xIDENTIFICACION+IMPORTE)-1)*55);
	xRESULT:=xRESULT/97;
	xRESULT:=xRESULT-(TRUNC(xRESULT,0));
	xRESULT:=xRESULT*100;

	xRESULT:=TRUNC(xRESULT,0); 

	xRESULT:=99-xRESULT;       
    
	IF (xRESULT=0) THEN
		DC:=99;
	ELSE
		DC:=xRESULT;
	END IF;

END;
/


--calcular los digitos de control del cuaderno 60 modalidad 2
CREATE OR REPLACE PROCEDURE CALCULA_DC_MODALIDAD2_60(
	xIMPORTE 		IN FLOAT,
	xREFERENCIA 	IN INTEGER,
	xTRIBUTO 		IN CHAR,
	xEJERCICIO 		IN CHAR,
	xDISCRI_PERIODO	IN CHAR,
	xDIGITO_YEAR	IN CHAR,
	xF_JULIANA		IN CHAR,
	xEMISOR 		IN CHAR,
	xDC 			OUT VARCHAR2)
AS
    xID CHAR(10);
    xNUM INTEGER;
    xIMPOR	FLOAT;
BEGIN
	xID:=SUBSTR(xDISCRI_PERIODO,1,1)||SUBSTR(xTRIBUTO,1,3)||SUBSTR(xEJERCICIO,1,2)||
			SUBSTR(xDIGITO_YEAR,1,1)||SUBSTR(xF_JULIANA,1,3);

	--el importe en euros se toma como si se tratara de una cantidad entera, ejemplo:
	--125,25 euros es 12525
	--26,00 euros es 2600	
	xIMPOR:=xIMPORTE*100;

	F_DC60(xEMISOR,xREFERENCIA,xID,xIMPOR,xNUM);

	IF (xNUM < 10) THEN
		xDC:='0'||SUBSTR(xNUM,1,1);
	ELSE
		xDC:=SUBSTR(xNUM,1,2);
	END IF;
END;
/

/*******************************************************************************************/
--calcular los digitos de control para el cuaderno 60 modalidad 1
CREATE OR REPLACE PROCEDURE CALCULA_DC_60(
       xIMPORTE IN FLOAT,
       xREFERENCIA IN INTEGER,
       xTRIBUTO IN CHAR,
       xEJERCICIO IN CHAR,
       xREMESA IN CHAR,
       xEMISOR IN CHAR,
       xDC OUT VARCHAR2)
AS

    xIMPOR	FLOAT;
    xID 	CHAR(7);
    xNUM 	INTEGER;

BEGIN
	xID:=SUBSTR(xTRIBUTO,1,3)||SUBSTR(xEJERCICIO,1,2)||SUBSTR(xREMESA,1,2);

	--el importe en euros se toma como si se tratara de una cantidad entera, ejemplo:
	--125,25 euros es 12525
	--26,00 euros es 2600	
	xIMPOR:=xIMPORTE*100;

	F_DC60(xEMISOR,xREFERENCIA,xID,xIMPOR,xNUM);

	IF (xNUM < 10) THEN
		xDC:='0'||SUBSTR(xNUM,1,1);
	ELSE
		xDC:=SUBSTR(xNUM,1,2);
	END IF;
END;
/

/*******************************************************************************************/

/* función que indica en que trimestre del año se encuentra la fecha dada */
/* se podría usar to_char(fecha,'Q'): devuelve el trimestre de la fecha en string */
CREATE OR REPLACE FUNCTION QUARTER ( 
       xFECHA IN DATE
) RETURN INTEGER 
AS
  TRIMESTRE INTEGER;

BEGIN
  TRIMESTRE:=TO_NUMBER(SUBSTR(TO_CHAR(xFECHA,'dd/mm/yy'),4,2));
  
  IF TRIMESTRE<4 THEN
     RETURN 1;
   ELSIF TRIMESTRE<7 THEN
     RETURN 2;
  ELSIF TRIMESTRE<10 THEN
     RETURN 3;
  ELSE 
     RETURN 4;
  END IF;

END;
/       

/*******************************************************************************************/
CREATE OR REPLACE PROCEDURE GETREFERENCIA(
       xABONADO IN INTEGER,
       xREFERENCIA OUT CHAR)
AS
BEGIN

xREFERENCIA:=LPAD(xABONADO,10,'0');

END;
/

/*******************************************************************************************/
-- MODIFICACIÓN: 10/09/2001 M. Carmen Junco Gómez. Adaptación al euro
--Modificado: 10/09/2003. Agustín León Robles. Se cambia la forma de convertir el importe en cadena porque
--		en algunos clientes salian datos : 912.12,00, entonces daba error a la hora de imprimir los recibos
--
CREATE OR REPLACE PROCEDURE IMPORTEENCADENA(
       xIMPORTE_RECIBO IN FLOAT,
       xIMPORTE OUT CHAR)
AS   
BEGIN

	xIMPORTE:=substr(lpad(xIMPORTE_RECIBO*100,11,'0'),1,9) ||','||substr(lpad(xIMPORTE_RECIBO*100,11,'0'),10,2); 
   
END;
/

/*******************************************************************************************/
-- Modificación: 05/02/2007. Lucas Fernández Pérez. Nuevos parámetros xBLOQUE y xPORTAL para insertar
--								en los nuevos campos de la tabla de CONTRIBUYENTES
--
CREATE OR REPLACE PROCEDURE InsertaModiContribuyente(
       xNIF 		IN CHAR,
       xNOMBRE 		IN CHAR,
       xVIA 		IN CHAR,
       xCALLE 		IN VARCHAR2,
       xNUMERO 		IN CHAR,
       xBLOQUE 		IN CHAR,
       xPORTAL		IN CHAR,
       xESCALERA 	IN CHAR,
       xPLANTA 		IN CHAR,
       xPISO 		IN CHAR,
       xPOBLACION 	IN VARCHAR2,
       xPROVINCIA 	IN VARCHAR2,
       xCODIGO_POSTAL IN CHAR,
       xPAIS 		IN VARCHAR2)
AS
   CONTADOR INTEGER;
BEGIN

	-- Este procedimiento sólo se debería de utilizar para el IBI y la RUSTICA.
	-- solamente se inserta en contribuyentes si no existe el NIF. Nunca se modifica 
	SELECT COUNT(*) INTO CONTADOR FROM CONTRIBUYENTES WHERE NIF=xNIF;

	IF (CONTADOR=0) AND (xNIF IS NOT NULL) THEN
	   INSERT INTO CONTRIBUYENTES
		(NIF, NOMBRE, VIA, CALLE, NUMERO, BLOQUE, PORTAL, ESCALERA, PLANTA, PISO, POBLACION, PROVINCIA,
		CODIGO_POSTAL, PAIS)
	   VALUES 
		(xNIF, xNOMBRE, xVIA, xCALLE, xNUMERO, xBLOQUE, xPORTAL, xESCALERA, xPLANTA, xPISO, xPOBLACION, 
		xPROVINCIA,xCODIGO_POSTAL, xPAIS);
	END IF;

END;
/

/*******************************************************************************************/

CREATE OR REPLACE FUNCTION MONTH (
       xFECHA IN DATE
) RETURN INTEGER
AS

    MES INTEGER;

BEGIN
  MES:=TO_NUMBER(SUBSTR(TO_CHAR(xFECHA,'dd/mm/yy'),4,2));
  RETURN MES;
END;
/

/*******************************************************************************************/

CREATE OR REPLACE FUNCTION DAYOFMONTH (
       xFECHA IN DATE
) RETURN INTEGER
AS

    DAY INTEGER;

BEGIN
  DAY:=TO_NUMBER(SUBSTR(TO_CHAR(xFECHA,'dd/mm/yy'),1,2));
  RETURN DAY;
END;
/

/*******************************************************************************************/

CREATE OR REPLACE FUNCTION F_YEAR (
	 xFECHA IN DATE
) RETURN INTEGER
AS

    ANIO INTEGER;

BEGIN
  ANIO:=TO_NUMBER(SUBSTR(TO_CHAR(xFECHA,'yyyy'),1,4));
  RETURN ANIO;
END;
/


/*******************************************************************************************/


CREATE OR REPLACE PROCEDURE READ_COMO_CREO_VADOS(
	 xMUNICIPIO	  IN  CHAR,
	 xCOMO 	  OUT INTEGER
)
AS

BEGIN
   SELECT COMO_INSERTO_VADOS INTO xCOMO 
   FROM DATOSPER WHERE MUNICIPIO=xMUNICIPIO;
END;
/


/************************************************************/

CREATE OR REPLACE PROCEDURE PUT_COMO_CREO_VADOS(
	 xMUNICIPIO   IN CHAR,
	 xCOMO 	  IN INTEGER
)
AS

BEGIN
   UPDATE DATOSPER SET COMO_INSERTO_VADOS=xCOMO 
   WHERE MUNICIPIO=xMUNICIPIO;
END;
/


/*******************************************************************************************/

CREATE OR REPLACE PROCEDURE AVERIGUA_PESO (
	xACTUAL 	IN	INTEGER,
	xANTERIOR	IN	INTEGER,
	xCONSUMO	OUT	INTEGER,
	xRANGO	OUT	INTEGER
)
AS
	I FLOAT;
	PESO INTEGER;
BEGIN

   PESO:=0;
   I:=xANTERIOR;
   xCONSUMO:=0;

   WHILE (I >= 1) LOOP
	I:= I / 10;
	PESO:=PESO+1;
   END LOOP;

   PESO:=SUBSTR('1000000000',0,PESO+1);
   xCONSUMO:=PESO-xANTERIOR+xACTUAL;

   xRANGO:=(xCONSUMO/5);
   IF ((MOD(xConsumo,5)<2.5) and (MOD(xConsumo,5)<>0)) THEN 
	xRango:=xRango+1;
   END IF;

   xRango:=xRango*5;

   IF (xRango>=125) THEN
      xRango:=125;
   END IF;

END;
/

/******************************************************************************************/

CREATE OR REPLACE PROCEDURE BUSCA_CONTRI (
	xNIF		IN	CHAR, 
	xSI		OUT	CHAR,
	xNOMBRE 	OUT	CHAR
)
AS
	xCONTADOR	INTEGER;
BEGIN

   xSI:='N';
   xNOMBRE:='';

   SELECT COUNT(*) INTO xCONTADOR FROM CONTRIBUYENTES
   WHERE NIF=xNIF;
   IF xCONTADOR<>0 THEN
      SELECT NOMBRE INTO xNOMBRE FROM CONTRIBUYENTES 
      WHERE NIF=xNIF;
	xSI:='S';
   END IF;
END;
/

/********************************************************************/
/* función que dada una lista de elementos separados por un caracter que se manda
como parámetro, me devuelve el primer elemento de la lista y el resto de ésta */

CREATE OR REPLACE PROCEDURE NEXT_ITEM(
		xCADENA IN CHAR,
		xSEPARADOR IN CHAR,
		xITEM OUT CHAR,
		xRESTO OUT CHAR)
AS   
   POSIC INTEGER;   
BEGIN
   POSIC:=INSTR(xCADENA,xSEPARADOR);
   IF POSIC=0 THEN   
      xITEM:=xCADENA;
      xRESTO:='';
   ELSE   
      xITEM:=SUBSTR(xCADENA,1,POSIC-1);
      xRESTO:=SUBSTR(xCADENA,POSIC+1,LENGTH(xCADENA));
   END IF;
END;
/ 



/* *******************************************************************************
Autor: Agustin Leon Robles
Fecha: 21 Agosto 2.001
Acción: Añadir un cotitular a un abonado en concreto. 
Modificación: 09/05/2006 M. Carmen Junco Gómez. Adaptación al nuevo formato de Rústica
*********************************************************************************/

CREATE OR REPLACE PROCEDURE AddCOTITULARES(
		xPrograma 		COTITULARES.PROGRAMA%Type,
		xNIF 			COTITULARES.NIF%Type,
		xID_CONCEPTO 	COTITULARES.ID_CONCEPTO%Type)
AS
BEGIN

	INSERT INTO COTITULARES (PROGRAMA,NIF,ID_CONCEPTO) 
	VALUES (xPROGRAMA,xNIF,xID_CONCEPTO);

	IF xPROGRAMA='VEHICULOS' THEN
		UPDATE VEHICULOS SET COTITULARES='S' WHERE ABONADO=xID_CONCEPTO AND COTITULARES='N';
	END IF;

	IF xPROGRAMA='IBI' THEN
		UPDATE IBI SET COTITULARES='S' WHERE ID=xID_CONCEPTO AND COTITULARES='N';
	END IF;

	IF xPROGRAMA='RUSTICA' THEN
		UPDATE RUS_TITULARES SET COTITULARES='S' WHERE ID=xID_CONCEPTO AND COTITULARES='N';
	END IF;

	IF xPROGRAMA='IAE' THEN
		UPDATE IAE SET COTITULARES='S' WHERE ID=xID_CONCEPTO AND COTITULARES='N';
	END IF;

	IF xPROGRAMA='EXACCIONES' THEN
		UPDATE EXACCIONES SET COTITULARES='S' WHERE ABONADO=xID_CONCEPTO AND COTITULARES='N';
	END IF;

	IF xPROGRAMA='LIQUIDACIO' THEN
   	UPDATE LIQUIDACIONES SET COTITULARES='S' WHERE ID=xID_CONCEPTO AND COTITULARES='N';
	END IF;

	IF xPROGRAMA='PLUSVALIA' THEN
   	UPDATE PLUSVALIAS SET COTITULARES='S' WHERE ID=xID_CONCEPTO AND COTITULARES='N';
	END IF;

	IF xPROGRAMA='AGUA' THEN
   	UPDATE AGUA SET COTITULARES='S' WHERE ID=xID_CONCEPTO AND COTITULARES='N';
	END IF;


END;
/



/* *******************************************************************************
Autor: Agustin Leon Robles
Fecha: 21 Agosto 2.001
Acción: Eliminar un cotitular de un abonado. 
MODIFICACIÓN: 15/05/2006 M. Carmen Junco Gómez. Adaptación al nuevo formato de RUSTICA
***************************************************************************/
CREATE OR REPLACE PROCEDURE DelCOTITULARES
		(xID 			IN 	INTEGER,
		xPrograma 		IN	COTITULARES.PROGRAMA%Type,
		xID_CONCEPTO 	IN	COTITULARES.ID_CONCEPTO%Type)
AS
xCUANTOS	INTEGER DEFAULT 0;
BEGIN

--borramos el cotitular que ha elegido por pantalla
DELETE FROM COTITULARES WHERE ID=xID;

--contamos por si ya no hubiera ningun cotitular asociado a este abonado entones hay que 
--desactivar el campo cotitulares en la tabla del padron correspondiente
SELECT COUNT(*) INTO xCuantos FROM COTITULARES 
WHERE ID_CONCEPTO=xID_CONCEPTO AND PROGRAMA=xPROGRAMA;

IF xCUANTOS=0 THEN

	IF xPROGRAMA='VEHICULOS' THEN
		UPDATE VEHICULOS SET COTITULARES='N' WHERE ABONADO=xID_CONCEPTO;
	END IF;

	IF xPROGRAMA='IBI' THEN
		UPDATE IBI SET COTITULARES='N' WHERE ID=xID_CONCEPTO;
	END IF;

	IF xPROGRAMA='RUSTICA' THEN
		UPDATE RUS_TITULARES SET COTITULARES='N' WHERE ID=xID_CONCEPTO;
	END IF;

	IF xPROGRAMA='IAE' THEN
		UPDATE IAE SET COTITULARES='N' WHERE ID=xID_CONCEPTO;
	END IF;

	IF xPROGRAMA='EXACCIONES' THEN
		UPDATE EXACCIONES SET COTITULARES='N' WHERE ABONADO=xID_CONCEPTO;
	END IF;

	IF xPROGRAMA='LIQUIDACIO' THEN
		UPDATE LIQUIDACIONES SET COTITULARES='N' WHERE ID=xID_CONCEPTO;
	END IF;

	IF xPROGRAMA='PLUSVALIA' THEN
   		UPDATE PLUSVALIAS SET COTITULARES='N' WHERE ID=xID_CONCEPTO;
	END IF;

	IF xPROGRAMA='AGUA' THEN
   		UPDATE AGUA SET COTITULARES='N' WHERE ID=xID_CONCEPTO;
	END IF;


END IF;

END;
/


/* *******************************************************************************
Autor: Agustin Leon Robles
Fecha: 22 Agosto 2.001
Acción: Añadir o eliminar un domicilio alternativo. 
		  En Ibi, rustica, iae y multas se pueden añadir y quitar. 
		  En el resto de modulos solo se pueden quitar, ya que se añaden cuando se da 
		  de alta el abonado. En estos casos tambien se pueden quitar modificando
		  el abonado.
Modificación: 17/01/2005 Lucas Fernández Pérez. Se permite añadir el domicilio
		alternativo cuando el programa es MULTAS.
Modificación: 09/05/2006 M. Carmen Junco Gómez. Se adapta al nuevo formato de rústica
********************************************************************************/

CREATE OR REPLACE PROCEDURE ADDDEL_DOMIALTERNATIVOS
		(xID IN integer,
		 xIDDOMIALTER IN integer,
		 xPrograma IN char,
		 xAddDel IN	char)
AS
BEGIN

	if xPrograma='VEHICULOS' then
		update vehiculos set IDDOMIALTER=NULL where Abonado=xID;
	end if;

	if xPrograma='IBI' then
		if xAddDel='A' then
			update ibi set IDDOMIALTER=xIDDOMIALTER where ID=xID;
		else
			update ibi set IDDOMIALTER=NULL where ID=xID;
		end if;
	end if;

	if xPrograma='RUSTICA' then
		if xAddDel='A' then
			update RUS_TITULARES set IDDOMIALTER=xIDDOMIALTER where ID=xID;
		else
			update RUS_TITULARES set IDDOMIALTER=NULL where ID=xID;
		end if;
	end if;

	if xPrograma='IAE' then
		if xAddDel='A' then
			update IAE set IDDOMIALTER=xIDDOMIALTER where ID=xID;
		else
			update IAE set IDDOMIALTER=NULL where ID=xID;
		end if;
	end if;

	if xPrograma='EXACCIONES' then
		update exacciones set IDDOMIALTER=NULL where Abonado=xID;
	end if;

	IF xPROGRAMA='LIQUIDACIO' THEN
		UPDATE LIQUIDACIONES SET IDDOMIALTER=NULL WHERE ID=xID;
	END IF;

	IF xPROGRAMA='MULTAS' THEN
		if xAddDel='A' then
			UPDATE MULTAS SET IDDOMIALTER=xIDDOMIALTER where ID=xID;
		else
		    UPDATE MULTAS SET IDDOMIALTER=NULL WHERE ID=xID;
		end if;
	END IF;

	IF xPROGRAMA='PLUSVALIA' THEN
   		UPDATE PLUSVALIAS SET IDDOMIALTER=NULL WHERE ID=xID;
	END IF;

	IF xPROGRAMA='AGUA' THEN
   		UPDATE AGUA SET IDDOMIALTER=NULL WHERE ID=xID;
	END IF;

END;
/



-- Autor: Antonio Pérez Caballero
-- Fecha: 31/08/2001
-- Añadir un responsable solidario a un recibo determinado
--

CREATE OR REPLACE PROCEDURE ADDCOTITULARESREC(
	xIDVALOR IN COTITULARES_RECIBO.ID%TYPE,
	xNIF IN COTITULARES_RECIBO.NIF%TYPE,
	xPROGRAMA IN COTITULARES_RECIBO.PROGRAMA%TYPE,
	xAYTO IN COTITULARES_RECIBO.AYTO%TYPE,
	xPADRON IN COTITULARES_RECIBO.PADRON%TYPE,
	xYEAR IN COTITULARES_RECIBO.YEAR%TYPE,
	xPERIODO IN COTITULARES_RECIBO.PERIODO%TYPE,
	xRECIBO IN COTITULARES_RECIBO.RECIBO%TYPE)
AS
BEGIN


	INSERT INTO COTITULARES_RECIBO (NIF,PROGRAMA,AYTO,PADRON,YEAR,PERIODO,RECIBO)
	VALUES (xNIF,xPROGRAMA,xAYTO,xPADRON,xYEAR,xPERIODO,xRECIBO);


	-- Si en valores no había cotitulares se lo incamos a la tabla
	UPDATE VALORES SET COTITULARES='S' WHERE ID=xIDVALOR AND COTITULARES='N';

END;
/

-- Autor: Antonio Pérez Caballero
-- Fecha: 31/08/2001
-- Borrar un responsable solidario a un recibo determinado
--

CREATE OR REPLACE PROCEDURE DELCOTITULARESREC(
	xID IN COTITULARES_RECIBO.ID%TYPE,
	xIDVALOR IN COTITULARES_RECIBO.ID%TYPE)
AS
	xCUANTOS	INTEGER DEFAULT 0;
	xAYTO COTITULARES_RECIBO.AYTO%TYPE;
	xPADRON COTITULARES_RECIBO.PADRON%TYPE;
	xYEAR COTITULARES_RECIBO.YEAR%TYPE;
	xPERIODO COTITULARES_RECIBO.PERIODO%TYPE;
	xRECIBO COTITULARES_RECIBO.RECIBO%TYPE;
BEGIN

	DELETE FROM COTITULARES_RECIBO WHERE ID=xID 
	RETURNING AYTO,PADRON,YEAR,PERIODO,RECIBO 
	INTO xAYTO,xPADRON,xYEAR,xPERIODO,xRECIBO;

	SELECT COUNT(*) INTO xCuantos FROM COTITULARES_RECIBO
	WHERE AYTO=xAYTO AND PADRON=xPADRON
      	AND YEAR=xYEAR AND PERIODO=xPERIODO 
			AND RECIBO=xRECIBO;

	IF xCUANTOS = 0 THEN
   	-- Si en valores no había cotitulares se lo incamos a la tabla
   	UPDATE VALORES SET COTITULARES='N' WHERE ID=xIDVALOR;
	END IF;

END;
/


/***************************************************************************************
Autor:  15/07/2002 Antonio Pérez Caballero 
Acción: Poner la variable del menu principal de gestión tributaria a un usuario
MODIFICACIÓN: 23/07/2002 Antonio Pérez Caballero. Un parámetro más para identificar el menu.
              xMenu indica qué opcion de menu se está modificando.
MODIFICACIÓN: 26/07/2002 Mª del Carmen Junco Gómez. Hay menús con mas de 30 opciones. Para
		  ellos se van a utilizar dos variables (por ahora) para completar el resto
		  de opciones de menú.
		  Se añade el parámetro xPermiso2 para indicar el resto de opciones excedentes
		  de las treinta primeras.
MODIFICACIÓN: 30/03/2006 Gloria Maria Calle Hernandez. Ampliacion del Menu de RUS a 31 opciones. 
		  Para ellos se van a utilizar dos variables (por ahora) para completar el resto
		  de opciones de menú. Se añade el parámetro xPermiso2 para indicar el resto de opciones 
		  excedentes de las treinta primeras.
MODIFICACIÓN: 15/05/2006. M. Carmen Junco Gómez. Adaptación al nuevo formato de RUSTICA
***************************************************************************************/
CREATE OR REPLACE PROCEDURE SetMainMenu(
	xUser In Char,
	xMenu In Char,
	xPermiso In Integer,
	xPermiso2 In Integer)
AS
BEGIN

	IF xMenu=0 THEN
   		Update USUARIOSGT Set MenuMain=xPermiso
      	where USUARIO=xUser;
	END IF;

	IF xMenu=1 THEN
   		Update USUARIOSGT Set MENULIQUI=xPermiso
      	where USUARIO=xUser;
	END IF;

	IF xMenu=2 THEN
   		Update USUARIOSGT Set MENUAGUA=xPermiso,
					    MENUAGUA2=xPermiso2
      	where USUARIO=xUser;
	END IF;

	IF xMenu=3 THEN
   		Update USUARIOSGT Set MENUVEHI=xPermiso,
					    MENUVEHI2=xPermiso2
      	where USUARIO=xUser;
	END IF;

	IF xMenu=4 THEN
   		Update USUARIOSGT Set MENUIBI=xPermiso,
					    MENUIBI2=xPermiso2
      	where USUARIO=xUser;
	END IF;

	IF xMenu=5 THEN
   		Update USUARIOSGT Set MENUPLUSVA=xPermiso
      	where USUARIO=xUser;
	END IF;

	IF xMenu=6 THEN
   		Update USUARIOSGT Set MENUINSPE=xPermiso
      	where USUARIO=xUser;
	END IF;

	IF xMenu=7 THEN
   		Update USUARIOSGT Set MENURUS=xPermiso					    
      	where USUARIO=xUser;
	END IF;

	IF xMenu=8 THEN
   		Update USUARIOSGT Set MENUEXAC=xPermiso
      	where USUARIO=xUser;
	END IF;

	IF xMenu=9 THEN
   		Update USUARIOSGT Set MENUREGIS=xPermiso
      	where USUARIO=xUser;
	END IF;

	IF xMenu=10 THEN
   		Update USUARIOSGT Set MENUIAE=xPermiso,
					    MENUIAE2=xPermiso2
      	where USUARIO=xUser;
	END IF;

	IF xMenu=11 THEN
   		Update USUARIOSGT Set MENUMULTAS=xPermiso,
					    MENUMULTAS2=xPermiso2
      	where USUARIO=xUser;
	END IF;

	IF xMenu=12 THEN
   		Update USUARIOSGT Set MENUCONFI=xPermiso
      	where USUARIO=xUser;
	END IF;

END;
/

/***************************************************************************************/

CREATE OR REPLACE function GetFinPeVol(xMunicipio in char)
RETURN date
as
	xDias		integer;
	xFinPeVol	date;
begin

	select dias_vencimiento into xDias from datosper where municipio=xMunicipio;

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

	RETURN xFinPeVol;

end;
/


/*******************************************************************************************
Autor: Gloria Maria Calle Hernandez
Fecha: 20 de Agosto de 2003

Añadir un nuevo codigo postal. (Para la direcciones de los contribuyentes).
Si el código de provincia correspondiente con los dos primeros digitos del 
codigo postal no exite en la tabla de provincias no insertará dicho código, devolviendo 
ERROR=0.

Modificación: 29/03/2004 Mª Carmen Junco Gómez. Si es una modificación devolvía 0 en el 
Error, con lo que se informaba de un error en la aplicación delphi.
	
********************************************************************************************/
CREATE OR REPLACE PROCEDURE ADD_CODIGO_POSTAL(
       xCODIGO_POSTAL 	IN CHAR,
       xPOBLACION 	   IN CHAR,
	    ERROR		      OUT INTEGER
)
AS
BEGIN

	ERROR:=1;
 
   UPDATE CODIGOS_POSTALES SET POBLACION=xPOBLACION WHERE CODIGO_POSTAL=xCODIGO_POSTAL;
 
   IF SQL%NOTFOUND THEN /* Si el codigo postal no existe, se crea */

     SELECT COUNT(*) INTO ERROR FROM COD_PROVINCIAS
     WHERE CODPROV=SUBSTR(xCODIGO_POSTAL,1,2);

     IF ERROR>0 THEN 
       INSERT INTO CODIGOS_POSTALES (CODPROV,POBLACION,CODIGO_POSTAL)
	    VALUES (SUBSTR(xCODIGO_POSTAL,1,2),xPOBLACION,xCODIGO_POSTAL);
	  END IF;

   END IF;
   
END;
/


/*******************************************************************************************
Autor: Mª del Carmen Junco Gómez.
Fecha: 14/03/2005

Acción: Procedimiento que rellena la tabla tcalendario con los dias del año que se pasa como parámetro.		  
Modificado: 09 de Junio de 2006. Lucas Fernández Pérez. Se añade el parametro xAYTO para
	distinguir el municipio sobre el que se graba el calendario
*******************************************************************************************/
CREATE OR REPLACE PROCEDURE RELLENA_TCALENDARIO(
			xAYTO IN CHAR,
			xYEAR IN CHAR)
AS	
	xDATE DATE;	
	xCONTADOR INTEGER;	
	
BEGIN	

	SELECT COUNT(*) INTO xCONTADOR FROM TCALENDARIO
	WHERE TO_CHAR(FECHA,'YYYY')=TRIM(xYEAR) AND AYTO=xAYTO;
	
	IF (xCONTADOR=0) THEN

		xDATE:=TO_DATE('01/01/'||TRIM(xYEAR),'DD/MM/YYYY');		
	
		WHILE (TO_CHAR(xDATE,'YYYY')=TRIM(xYEAR)) 
		LOOP			
				
			INSERT INTO TCALENDARIO (AYTO,FECHA,INHABIL) VALUES (xAYTO,xDATE,'N');
			xDATE:=xDATE+1;
		
		END LOOP;
	
	END IF;
	
END;
/

/*******************************************************************************************
Autor: Mª del Carmen Junco Gómez.
Fecha: 15/03/2005

Acción: Función que devuelve la próxima fecha hábil dada una pasada como parámetro.
*******************************************************************************************/
CREATE OR REPLACE FUNCTION NEXT_DIA_HABIL(
			xFECHA	IN	DATE)
RETURN DATE
AS
	xRESULTADO DATE;
BEGIN
	SELECT MIN(FECHA) INTO xRESULTADO FROM TCALENDARIO WHERE INHABIL='N' AND FECHA>xFECHA;
	RETURN xRESULTADO;
END;
/

/*******************************************************************************************
Autor: Mª del Carmen Junco Gómez.
Fecha: 15/03/2005

Acción: Función que devuelve una fecha como resultado de sumar x Días hábiles a la fecha pasada como parámetro.
*******************************************************************************************/
CREATE OR REPLACE FUNCTION SUMAR_DIAS_HABILES(
			xFECHA IN DATE,
			xDIAS	IN	INTEGER
) RETURN DATE
AS
	i INTEGER;
	xRESULTADO DATE;
BEGIN
	xRESULTADO:=xFECHA;
	i:=xDIAS;
	
	WHILE (i>0) 
	LOOP
		xRESULTADO:=NEXT_DIA_HABIL(xRESULTADO);
		i:=i-1;	
	END LOOP;	
	
	RETURN xRESULTADO;
END;
/


/*******************************************************************************************
Acción: Función que devuelve una MATRÍCULA.
*******************************************************************************************/

CREATE OR REPLACE FUNCTION GETMATRICULA(
	xCIUDAD IN Vehiculos.MATRICULA%TYPE,
	xNUMERO IN Vehiculos.NUMERO%TYPE,
	xLETRA  IN Vehiculos.LETRA%TYPE)
RETURN VARCHAR2
AS
xMATRICULA VARCHAR2(15);
xMATRI	varchar2(15) default null;
i	integer;
BEGIN

	if xCiudad is null and xNumero is null and xLetra is null then
		return null;
	end if;

	IF xCIUDAD IS NULL OR LENGTH(RTRIM(xCIUDAD))=0 OR LENGTH(RTRIM(xCIUDAD)) IS NULL THEN
	   xMATRICULA:=xNUMERO;
	   IF xLETRA IS NOT NULL THEN
		xMATRICULA:=xMATRICULA|| '-' || xLETRA;
	   END IF;
	ELSE
	   xMATRICULA:=xCIUDAD || '-' || xNUMERO;
	   IF xLETRA IS NOT NULL OR LENGTH(RTRIM(xCIUDAD)) > 0 THEN
		xMATRICULA:=xMATRICULA|| '-' || xLETRA;
	   END IF;
	END IF;

	i:=1;
	for i in 1..15 Loop
		if substr(xMatricula,i,1)<>' ' then
			xMatri:=xMatri||substr(xMatricula,i,1);
		end if;
	end loop;

RETURN xMATRI;

END;
/


COMMIT;
/********************************************************************/