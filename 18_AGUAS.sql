/*******************************************************************************
Acción: Añadir tipos de tarifas de agua.
MODIFICACIÓN: 09/09/2002 M. Carmen Junco Gómez. Al modificar un tipo de tarifa,
	        cuando se borraba de la tabla de apoyo se estaba borrando 
		  comparando TIPO=xTipoIva, en vez de TIPO=xTipo; 
*******************************************************************************/

CREATE OR REPLACE PROCEDURE ADDTIPOS_TARIFA_AGUA (
	xMODI       in 	char,
	xMunicipio	in	char,
	xTipo 	in	char,
	xDescrip 	in	varchar,
	xIVA 		in	char,
	xTipoIva 	in	FLOAT)
AS
   mTipo char(2);
   mTipoINT integer;
BEGIN



IF xMODI='S' THEN
   UPDATE TIPO_TARIFA SET DESCRIPCION=xDescrip,IVA=xIVA,TIPO_IVA=xTipoIva
		WHERE MUNICIPIO=xMUNICIPIO
		AND TIPO=xTipo;


	/*TABLA PARALELA DE APOYO*/

	DELETE FROM TIPO_TARIFA_ORDEN 
		WHERE Municipio=xMUNICIPIO AND TIPO=xTipo;

	IF xIva='S' THEN
		INSERT INTO TIPO_TARIFA_ORDEN(Municipio,TIPO,BI)
		VALUES (xMunicipio,xTipo,'B');
		INSERT INTO TIPO_TARIFA_ORDEN(Municipio,TIPO,BI)
		VALUES (xMunicipio,xTipo,'I');
	ELSE
		INSERT INTO TIPO_TARIFA_ORDEN(Municipio,TIPO,BI)
		VALUES (xMunicipio,xTipo,'B');
	END IF;


ELSE

      SELECT MAX(TIPO) INTO mTIPO FROM TIPO_TARIFA 
		 WHERE MUNICIPIO=xMUNICIPIO;

	IF mTIPO IS NULL THEN
         mTIPO:='00';
	END IF;

      mTipoINT:=TO_NUMBER(mTIPO);
      mTipoINT:=mTipoINT+1;
	mTIPO:=LPAD(TO_CHAR(mTipoINT),2,'0');
	
	INSERT INTO TIPO_TARIFA 
		(Municipio,TIPO,DESCRIPCION,IVA,TIPO_IVA)
	VALUES 
		(xMunicipio,mTipo,xDescrip,xIVA,xTipoIva);

	/*TABLA PARALELA DE APOYO*/
	IF xIva='S' THEN
		INSERT INTO TIPO_TARIFA_ORDEN(Municipio,TIPO,BI)
		VALUES (xMunicipio,mTipo,'B');
		INSERT INTO TIPO_TARIFA_ORDEN(Municipio,TIPO,BI)
		VALUES (xMunicipio,mTipo,'I');
	ELSE
		INSERT INTO TIPO_TARIFA_ORDEN(Municipio,TIPO,BI)
		VALUES (xMunicipio,mTipo,'B');
	END IF;
END IF;

END;
/

/*******************************************************************************
Acción: Añadir tarifas de Agua.
MODIFICACIÓN: 18/09/2001 Lucas Fernández Pérez. Adaptación al euro.
Modificacion: 21/07/2004. Gloria Maria Calle Hernandez:
Arrastramos hasta seis decimales por Precio Unitario y Redondeamos por Tramos.
*******************************************************************************/

CREATE OR REPLACE PROCEDURE ADD_TARIFA_AGUA (
	xMunicipio		in	char,
	xModi			in	char,
	xTARIFA 		in	char,
	xTIPO_TARIFA 	in	char,
	xDESCRIPCION 	in	varchar,

      xBLOQUE1 		in	INTEGER,
	xBLOQUE2 		in	INTEGER,
	xBLOQUE3 		in	INTEGER,
	xBLOQUE4 		in	INTEGER,

	xPRECIO1 		in	FLOAT,
	xPRECIO2 		in	FLOAT,
	xPRECIO3 		in	FLOAT,
	xPRECIO4 		in	FLOAT,

      xFIJO1 		in	FLOAT,
	xFIJO2 		in	FLOAT,
	xFIJO3 		in	FLOAT,
	xFIJO4 		in	FLOAT
)
AS
	xNada integer;
	TARIFA_DUPLICADA EXCEPTION;
BEGIN

   /*SOLO EN CASO DE DAR DE ALTAS TARIFAS,
		COMPROBAMOS QUE ESTA NO ESTE DADO DE ALTA CON ANTERIORIDAD*/

   if (xModi<>'S') then
	SELECT COUNT(TARIFA) into xNada FROM TARIFAS_AGUA 
	WHERE MUNICIPIO=xMUNICIPIO AND TARIFA=xTARIFA;

	IF (xNada<>0) THEN
	   raise TARIFA_DUPLICADA;
	end if;

   end if;

  /*xModi significar si vamos a modificar*/

   IF (xModi='S') then

	UPDATE TARIFAS_AGUA SET 
	    TIPO_TARIFA=xTIPO_TARIFA,DESCRIPCION=ltrim(rtrim(xDESCRIPCION)),BLOQUE1=xBLOQUE1,
          BLOQUE2=xBLOQUE2,BLOQUE3=xBLOQUE3,BLOQUE4=xBLOQUE4,PRECIO1=ROUND(xPRECIO1,6),
          PRECIO2=ROUND(xPRECIO2,6),PRECIO3=ROUND(xPRECIO3,6),PRECIO4=ROUND(xPRECIO4,6),
          FIJO1=ROUND(xFIJO1,2),FIJO2=ROUND(xFIJO2,2),FIJO3=ROUND(xFIJO3,2),
          FIJO4=ROUND(xFIJO4,2)
      WHERE MUNICIPIO=xMUNICIPIO AND TARIFA=xTARIFA;

   ELSE

	INSERT INTO TARIFAS_AGUA 
  	  (MUNICIPIO,TARIFA,TIPO_TARIFA,DESCRIPCION,BLOQUE1,BLOQUE2,BLOQUE3,BLOQUE4,PRECIO1,
	   PRECIO2,PRECIO3,PRECIO4,FIJO1,FIJO2,FIJO3,FIJO4)
	VALUES
        (xMUNICIPIO,xTARIFA,xTIPO_TARIFA,xDESCRIPCION,xBLOQUE1,xBLOQUE2,xBLOQUE3,xBLOQUE4,
    	   ROUND(xPRECIO1,6),ROUND(xPRECIO2,6),ROUND(xPRECIO3,6),ROUND(xPRECIO4,6),
	   ROUND(xFIJO1,2),ROUND(xFIJO2,2),ROUND(xFIJO3,2),ROUND(xFIJO4,2));
    END IF;
   EXCEPTION
	WHEN TARIFA_DUPLICADA THEN
		RAISE_APPLICATION_ERROR(-20500,'ESTE CODIGO DE TARIFA YA ESTÁ DADO DE ALTA');
END;
/

/*******************************************************************************
Acción: Para pasar las tarifas al histórico de tarifas.
*******************************************************************************/

CREATE OR REPLACE PROCEDURE PASA_TARIFAS_AGUAS (
	xMunicipio	in	char,
	xYear 	in	char,
	xPeri 	in	char
)
AS

	xIva char(1);
	xTipo_Iva float;

	xTIPO_TARIFA CHAR(2);
	xTARIFA CHAR(4);
	xDESCRIPCION CHAR(40);

	xBLOQUE1 INTEGER;
	xBLOQUE2 INTEGER;
	xBLOQUE3 INTEGER;
	xBLOQUE4 INTEGER;

	xPRECIO1 FLOAT;
	xPRECIO2 FLOAT;
	xPRECIO3 FLOAT;
	xPRECIO4 FLOAT;

	xFIJO1 FLOAT;
	xFIJO2 FLOAT;
	xFIJO3 FLOAT;
	xFIJO4 FLOAT;

	CURSOR CURSOR_PASA_TARIFAS IS
	   SELECT TIPO_TARIFA,TARIFA,DESCRIPCION,BLOQUE1,BLOQUE2,BLOQUE3,BLOQUE4,PRECIO1,PRECIO2,
		    PRECIO3,PRECIO4,FIJO1,FIJO2,FIJO3,FIJO4 
   	   FROM TARIFAS_AGUA where municipio=xMunicipio;
	
BEGIN

  /*primero borramos por si ya estuvieran*/
   delete from HISTO_TARIFAS_AGUA 
   where MUNICIPIO=xMunicipio and YEAR=xYear and PERIODO=xPeri;
    
   OPEN CURSOR_PASA_TARIFAS;
   LOOP
	FETCH CURSOR_PASA_TARIFAS 
	   INTO xTIPO_TARIFA,xTARIFA,xDESCRIPCION,xBLOQUE1,xBLOQUE2,xBLOQUE3,xBLOQUE4,
		  xPRECIO1,xPRECIO2,xPRECIO3,xPRECIO4,xFIJO1,xFIJO2,xFIJO3,xFIJO4;
	EXIT WHEN CURSOR_PASA_TARIFAS%NOTFOUND;

	select iva,tipo_iva into xIva,xTipo_Iva from tipo_tarifa 
	where municipio=xMunicipio and tipo=xTIPO_TARIFA;

	INSERT INTO HISTO_TARIFAS_AGUA 
	  (MUNICIPIO,YEAR,PERIODO,TIPO_TARIFA,TARIFA,DESCRIPCION,IVA,TIPO_IVA,BLOQUE1,BLOQUE2,
	   BLOQUE3,BLOQUE4,PRECIO1,PRECIO2,PRECIO3,PRECIO4,FIJO1,FIJO2,FIJO3,FIJO4)
	VALUES 
	  (xMunicipio,xYear,xPeri,xTIPO_TARIFA,xTarifa,xDESCRIPCION,xIva,xTipo_Iva,xBLOQUE1,
	   xBLOQUE2,xBLOQUE3,xBLOQUE4,xPRECIO1,xPRECIO2,xPRECIO3,xPRECIO4,xFIJO1,xFIJO2,xFIJO3,xFIJO4);
   END LOOP;
   CLOSE CURSOR_PASA_TARIFAS;
END;
/

/*******************************************************************************
Acción: Para crear los grupos en agua. 
*******************************************************************************/

CREATE OR REPLACE PROCEDURE CREA_PEGA_GRUPO_AGUA (
	xID				IN		INTEGER,
	xTIPO				IN		CHAR,
	xCODIGO_OPERACION 	IN OUT	FLOAT
)
AS

BEGIN

   IF (xTIPO='C') THEN  /* CREAR GRUPO */
      ADD_COD_OPERACION(xCODIGO_OPERACION);
	UPDATE AGUA SET CODIGO_OPERACION=xCODIGO_OPERACION WHERE ID=xID;
   END IF;	

   IF (xTIPO='P') THEN  /* PEGAR AL GRUPO */
	UPDATE AGUA SET CODIGO_OPERACION=xCODIGO_OPERACION WHERE ID=xID;
   END IF;

   IF (xTIPO='Q') THEN  /* QUITAR GRUPO */
	UPDATE AGUA SET CODIGO_OPERACION=0 WHERE ID=xID;
   END IF;

END;
/

/*******************************************************************************
Acción: Procedimiento de estimación del consumo de agua por media aritmética de los
        últimos seis meses.

   FORMULAS: 
	- SEMESTRAL: recoger consumo semestre anterior.
	- CUATRIMESTRAL:[(consumo_cuat_anterior + (consumo_cuat_ant_ant/2))/6]*4
	- TRIMESTRAL:[(consumo_trim_anterior + consumo_trim_ant_ant)/6]*3
	- BIMESTRAL:[(consumo_bim_ant + consumo_bim_ant_ant + consumo_bim_ant_ant_ant)/6]*2

*******************************************************************************/

CREATE OR REPLACE PROCEDURE ESTIMACION_MEDIA_ARITMETICA(
	xTipoPeriodo	IN	CHAR,
	xAbonado		IN	INTEGER,
	mConsumo		OUT	INTEGER)
AS  
   xLAnterior  integer;
   xL1 	   integer;
   xL2	   integer;
   xL3	   integer;
BEGIN

   begin
  
      SELECT ANTERIOR,LECTURA1,LECTURA2,LECTURA3 INTO xLAnterior,xL1,xL2,xL3
	FROM AGUA
	WHERE ID=xAbonado;

	Exception
	   When no_data_found then
	      mConsumo:=0;

   end;

   IF (xTipoPeriodo='S') then	
      mConsumo:=xLAnterior-xL1;
   elsif (xTipoPeriodo='C') then
      mConsumo:=(( (xLAnterior-xL1) + ((xL1-xL2)/2))/6) *4;
   elsif (xTipoPeriodo='T') then
	mConsumo:=(( (xLAnterior-xL1) + (xL1-xL2) )/6) *3;
   elsif (xTipoPeriodo='B') then
	mConsumo:=(( (xLAnterior-xL1) + (xL1-xL2)+ (xL2-xL3) )/6) *2;
   END IF;

END;
/

/*******************************************************************************
Acción: Lectura estimada. El cálculo sería:
   1) consumo del año anterior y mismo periodo
   2) media aritmetica de los ultimos 6 meses 
   3) ultima lectura conocida
*******************************************************************************/

CREATE OR REPLACE PROCEDURE LECTURA_ESTIMADA(
		xMUNICIPIO		IN	CHAR,
		xYEAR			IN	CHAR,
		xPERIODO		IN	CHAR,
		xABONADO		IN	INTEGER,
		xUltimaLectura	IN	INTEGER,
		xESTIMACION 	OUT   INTEGER)
AS
   mConsumo   integer;
   mTipoPeriodo char(1);
BEGIN  
   
   SELECT AGUA_TIPO_PERIODO INTO mTipoPeriodo FROM DATOSPER WHERE MUNICIPIO=xMUNICIPIO;
  
   begin
      --se buscan los datos del año anterior y mismo periodo. xYear tiene restado el año
	SELECT CONSUMO INTO mConsumo
	FROM RECIBOS_AGUA
	WHERE ABONADO=xABONADO AND MUNICIPIO=xMUNICIPIO 
		AND YEAR=xYEAR AND PERIODO=xPERIODO;

   	Exception
	   When no_data_found then
		IF mTipoPeriodo<>'A' then  --si es anual no va a encontrar datos
		   ESTIMACION_MEDIA_ARITMETICA(mTipoPeriodo,xAbonado,mConsumo);
		ELSE
		   mConsumo:=0;
		END IF;

   end;	
	

   --la nueva lectura
   xESTIMACION:=mConsumo+xUltimaLectura;
   
END;
/


/********************************************************************/
COMMIT;
/********************************************************************/
