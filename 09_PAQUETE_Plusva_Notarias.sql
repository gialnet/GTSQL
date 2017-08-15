CREATE OR REPLACE PACKAGE PkPlusvaNotarias
AS
  -- Lee desde oracle un fichero de notarias y lo guarda en las tablas NOTARIAS y NOTARIAS_DETALLE
  PROCEDURE READ (
		xFileName	IN  VARCHAR2,
		xPath		IN  VARCHAR2,
		xNumReg		OUT	INTEGER,
		xError		OUT	VARCHAR2);
  
  -- Revisa las tablas de NOTARIAS y NOTARIAS_DETALLE buscando Registros Repetidos, contribuyentes desconocidos...
  PROCEDURE VALIDAR ( 		
  		xIBI		IN  BOOLEAN,
		xNOTARIOS	IN  BOOLEAN,
		xPLUSVA		IN  BOOLEAN,
		xCODOPE     IN  BOOLEAN,
		xCORREGIR	IN	BOOLEAN,
		xCONTRI		IN  BOOLEAN,
		xGENERACONTRI IN BOOLEAN);

  -- Genera los requerimientos de plusvalias de un notario (los que se puedan generar, que pasasen la validación)
  PROCEDURE GENERAR (
	xFECHA				IN  DATE,
	xNOTARIO			IN  INTEGER,
	xNUMREQUE			OUT INTEGER);

  -- Procedimiento que actualiza datos del titular: dni,nombre,direccion fiscal...
  PROCEDURE MODIFY (
    xID 					IN INTEGER,
	--{ Identificacion del bien inmueble }
    xREF_CATASTRAL			IN VARCHAR2,
    xTIPO_VIA				IN VARCHAR2,
    xNOMBRE_VIA				IN VARCHAR2,
    xNUMERO_VIA				IN VARCHAR2,
    xBLOQUE					IN VARCHAR2,
    xESCALERA				IN VARCHAR2,
    xPLANTA					IN VARCHAR2,
    xPUERTA					IN VARCHAR2,
	xRESTO_DIRECCION		IN VARCHAR2,
    xCOD_POSTAL				IN VARCHAR2,
    xCOD_PROVINCIA_INE		IN VARCHAR2,
    xCOD_MUNICIPIO_INE		IN VARCHAR2,
    xNOMBRE_MUNICIPIO		IN VARCHAR2,
    --{ Identificacion del nuevo titular }
    xNIF_TIT				IN VARCHAR2,
    xNOMBRE_TIT				IN VARCHAR2,
    --{ Domicilio del nuevo titular }
    xTIPO_VIA_TIT			IN VARCHAR2,
	xNOMBRE_VIA_TIT			IN VARCHAR2,
    xNUMERO_VIA_TIT			IN VARCHAR2,
    xBLOQUE_TIT				IN VARCHAR2,
    xESCALERA_TIT			IN VARCHAR2,
    xPLANTA_TIT				IN VARCHAR2,
    xPUERTA_TIT				IN VARCHAR2,
    xRESTO_DIRECCION_TIT	IN VARCHAR2,
    xCOD_POSTAL_TIT			IN VARCHAR2,
    xCOD_PROVI_INE_TIT		IN VARCHAR2,
    xCOD_MUNI_INE_TIT		IN VARCHAR2,
    xNOMBRE_MUNI_TIT		IN VARCHAR2,
    --{ Identificacion del transmitente }
    xNIF_TRAN				IN VARCHAR2,
    xNOMBRE_TRAN			IN VARCHAR2,
    -- { Domicilio del transmitente }
    xTIPO_VIA_TRAN			IN VARCHAR2,
    xNOMBRE_VIA_TRAN		IN VARCHAR2,
    xNUMERO_VIA_TRAN		IN VARCHAR2,
    xBLOQUE_TRAN			IN VARCHAR2,
    xESCALERA_TRAN			IN VARCHAR2,
    xPLANTA_TRAN			IN VARCHAR2,
    xPUERTA_TRAN			IN VARCHAR2,
    xRESTO_DIRECCION_TRAN	IN VARCHAR2,
    xCOD_POSTAL_TRAN		IN VARCHAR2,
    xCOD_PROVI_INE_TRAN		IN VARCHAR2,
    xCOD_MUNI_INE_TRAN		IN VARCHAR2,
    xNOMBRE_MUNI_TRAN		IN VARCHAR2,
	-- {Parametro para indicar si dichos cambios son realizados en los requerimientos
	--  correspondientes si hubieren sido generados ya }
	xCHANGE_REQUE		    IN BOOLEAN	);

	--Procedimiento para impresion individual o masiva de los requerimientos
	PROCEDURE PRINT (
		xIDREQUERIMIENTO   IN INTEGER,
	    xFPLUSVA		   IN  DATE,
	    xGRUPO			   OUT INTEGER);

	--Enviar Fichero a la AEAT
	PROCEDURE AEAT (
	    xCABECERA		   IN CHAR,
	    xPATH			   IN CHAR,
	    xNOMBREFILE		   IN CHAR,
	    xTIPO			   IN CHAR);

	
END PkPlusvaNotarias;
/


CREATE OR REPLACE PACKAGE BODY PkPlusvaNotarias

AS

/****************************************************************************************************
AUTOR: Gloria María Calle Hernández. 01/02/2002
FUNCION: Lee desde oracle un fichero de notarias y lo guarda en las tablas NOTARIAS y NOTARIAS_DETALLE
		 Los ficheros deben estar en el servidor, porque se leen desde Oracle.
PARAMETROS: 	xFILENAME: Nombre del fichero DOCDGC
				xPATH: Localizacion fisica de dicho fichero
				xNUMREG: Devuelve el número de registros leidos
				xERROR: Devuelve algún posible error producido durante la lectura
MODIFICACION: 27/04/05. Reemplazadas vocales con acento por vocales sin acento en el nombre de los notarios 
			  para cruce con notarios.
MODIFICACION: 07/09/2006. Lucas Fernández Pérez. Revisión General. 
	Graba en la tabla de notarías el nombre del fichero y la primera 
	línea, y si coincide con datos existentes no permite volver a grabar el mismo fichero por segunda vez.
*****************************************************************************************************/
PROCEDURE READ (
	xFileName			IN	VARCHAR2,
	xPath				IN	VARCHAR2,
	xNumReg				OUT	INTEGER,
	xError				OUT	VARCHAR2)
AS
  	vOutFile 	   		UTL_FILE.FILE_TYPE;
  	vReg				VARCHAR2(659);
  	vID					INTEGER;

  	--{ Registro de Cabecera }
  	vTIPO_REGISTRO			VARCHAR2(2);
  	vCOD_REG_PROPIEDAD		VARCHAR2(5);
  	vCOD_NOTARIA			VARCHAR2(9);
  	vF_GENERACION_FILE		DATE;
  	vF_INI_PERIODO			DATE;
  	vF_FIN_PERIODO			DATE;
    vCOD_PROVINCIA			VARCHAR2(2);
    vCOD_AYUNTAMIENTO		VARCHAR2(3);
    vCOD_NOTARIO			VARCHAR2(7);
    vNOMBRE_NOTARIO			VARCHAR2(45);

  	--{ Registro Detalle }
    vF_ESCRITURA_DOC		DATE;
    vCLASE_ALTERACION		VARCHAR2(1);
	vCUMPLIMIENTO_ARTICULO	VARCHAR2(1);

	--{ Identificacion del bien inmueble }
	vREF_CATASTRAL			VARCHAR2(20);
	vNUM_FIJO				VARCHAR2(14);
    vYEAR_PROTOCOLO			VARCHAR2(4);
    vNUMERO_PROTOCOLO		VARCHAR2(4);
    vVALOR_SUELO			FLOAT;
    vVALOR_TRANSMISION		VARCHAR2(12);
    vCOD_PROVINCIA_INE		VARCHAR2(2);
    vCOD_MUNICIPIO_INE		VARCHAR2(3);
    vNOMBRE_MUNICIPIO		VARCHAR2(25);
    vNOMBRE_ENTIDAD_MENOR	VARCHAR2(15);
    vTIPO_VIA				VARCHAR2(5);
    vNOMBRE_VIA				VARCHAR2(25);
    vNUMERO_VIA				VARCHAR2(4);
    vDUPLICADO				VARCHAR2(1);
    vBLOQUE					VARCHAR2(4);
    vESCALERA				VARCHAR2(2);
    vPLANTA					VARCHAR2(2);
    vPUERTA					VARCHAR2(3);
	vRESTO_DIRECCION		VARCHAR2(25);
    vAPROX_POSTAL_KM		VARCHAR2(6);
    vCOD_POSTAL				VARCHAR2(5);

    --{ Identificacion del transmitente }
    vNUM_COTITULARES_TRAN	VARCHAR2(4);
    vNIF_TRAN				VARCHAR2(9);
    vNOMBRE_TRAN			VARCHAR2(62);

    --{ Identificacion del nuevo titular }
    vNUM_COTITULARES_TIT	VARCHAR2(4);
    vDESC_COTITULARIDAD		VARCHAR2(20);
    vNIF_TIT				VARCHAR2(9);
    vNOMBRE_TIT				VARCHAR2(62);

    --{ Domicilio del nuevo titular }
    vCOD_PROVI_INE_TIT		VARCHAR2(2);
    vCOD_MUNI_INE_TIT		VARCHAR2(3);
    vNOMBRE_MUNI_TIT		VARCHAR2(40);
    vCOD_TIPO_VIA_TIT		VARCHAR2(5);
	vNOMBRE_VIA_TIT 		VARCHAR2(25);
    vNUMERO_VIA_TIT	    	VARCHAR2(4);
    vDUPLICADO_TIT			VARCHAR2(1);
    vBLOQUE_TIT				VARCHAR2(4);
    vESCALERA_TIT			VARCHAR2(2);
    vPLANTA_TIT				VARCHAR2(2);
    vPUERTA_TIT 			VARCHAR2(3);
    vRESTO_DIRECCION_TIT	VARCHAR2(25);
    vAPROX_POSTAL_KM_TIT	VARCHAR2(6);
    vCOD_POSTAL_TIT			VARCHAR2(5);

    -- { Domicilio del transmitente }
    vCOD_PROVI_INE_TRAN		VARCHAR2(2);
    vCOD_MUNI_INE_TRAN		VARCHAR2(3);
    vNOMBRE_MUNI_TRAN		VARCHAR2(40);
    vTIPO_VIA_TRAN			VARCHAR2(5);
    vNOMBRE_VIA_TRAN		VARCHAR2(25);
    vNUMERO_VIA_TRAN		VARCHAR2(4);
    vDUPLICADO_TRAN			VARCHAR2(1);
    vBLOQUE_TRAN			VARCHAR2(4);
    vESCALERA_TRAN			VARCHAR2(2);
    vPLANTA_TRAN			VARCHAR2(2);
    vPUERTA_TRAN			VARCHAR2(3);
    vRESTO_DIRECCION_TRAN	VARCHAR2(25);
    vAPROX_POSTAL_KM_TRAN	VARCHAR2(6);
    vCOD_POSTAL_TRAN		VARCHAR2(5);

    vDESC_OPERACION			VARCHAR2(30);
    vCOD_OPERACION			VARCHAR2(10);
    
    xCuantos				INTEGER;

  PROCEDURE recNgo (str IN VARCHAR2, xError OUT VARCHAR2)
  IS
  BEGIN
   xError:= 'UTL_FILE error '||str;
   UTL_FILE.FCLOSE (vOutFile);
  END;

begin

	xError:= null;
	vOutFile:=UTL_FILE.FOPEN(rtrim(xPath),rtrim(xFileName),'R');
	xNumReg:= 0;

	UTL_FILE.GET_LINE(vOutFile,vReg); --para leer la línea de cabecera

	vTIPO_REGISTRO:=SUBSTR(vReg,1,2);

	if vTIPO_REGISTRO<>'01' then -- este fichero no cumple el formato, se cierra y se sale del procedimiento
		UTL_FILE.FCLOSE(vOutFile);
		xError:='El fichero no tiene el formato correcto';
		RETURN;
	end if;

	--{ Registro de Cabecera }
	vCOD_REG_PROPIEDAD:=TRIM(SUBSTR(vReg,3,5));
    vCOD_NOTARIA:=SUBSTR(vReg,8,9);

    IF SUBSTR(vReg,17,24)='00000000' THEN
	  vF_GENERACION_FILE:=NULL;
	ELSE vF_GENERACION_FILE:=TO_DATE(SUBSTR(vReg,17,8),'DDMMYYYY');
	END IF;

    IF SUBSTR(vReg,25,8)='00000000' THEN
	  vF_INI_PERIODO:=NULL;
	ELSE vF_INI_PERIODO:=TO_DATE(SUBSTR(vReg,25,8),'DDMMYYYY');
	END IF;

    IF SUBSTR(vReg,33,8)='00000000' THEN
	  vF_FIN_PERIODO:=NULL;
	ELSE vF_FIN_PERIODO:=TO_DATE(SUBSTR(vReg,33,8),'DDMMYYYY');
	END IF;

    vCOD_PROVINCIA:=SUBSTR(vReg,41,2);
    vCOD_AYUNTAMIENTO:=SUBSTR(vReg,43,3);
    vCOD_NOTARIO:=SUBSTR(vReg,46,7);
    vNOMBRE_NOTARIO:=REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(SUBSTR(vReg,53,45),'Á','A'),'É','E'),'Í','I'),'Ó','O'),'Ú','U');

	vID:=0;
    UTL_FILE.GET_LINE(vOutFile,vReg); -- Lee la primera línea de datos (aunque en ciertos ficheros 
    								  --  lee una linea vacia antes de leer cada linea de datos)

    LOOP
	BEGIN

	  IF SUBSTR(vReg,1,2)='02' THEN
	  
	  	IF vID=0 THEN --Todavía no ha insertado en la tabla notarías, ahora inserta
	  	
			SELECT COUNT(*) INTO xCUANTOS -- Antes comprueba si el fichero se ha leido anteriormente
			FROM NOTARIAS 
			WHERE COD_NOTARIA=vCOD_NOTARIA AND F_GENERACION_FILE=vF_GENERACION_FILE AND PRIMER_REGISTRO=vReg;
	
			if xCUANTOS>0 then -- este fichero ya se ha leido, no hace nada más
				UTL_FILE.FCLOSE(vOutFile);
				xError:='El fichero ya se ha cargado anteriormente';
				RETURN;
			end if;
	
			INSERT INTO NOTARIAS ( -- Inserta el Registro de Cabecera 
				TIPO_REGISTRO,COD_REG_PROPIEDAD,COD_NOTARIA,F_GENERACION_FILE,F_INI_PERIODO,F_FIN_PERIODO,COD_PROVINCIA,
	  			COD_AYUNTAMIENTO,COD_NOTARIO,NOMBRE_NOTARIO,FICHERO,PRIMER_REGISTRO)
    		VALUES (
				vTIPO_REGISTRO,vCOD_REG_PROPIEDAD,vCOD_NOTARIA,vF_GENERACION_FILE,vF_INI_PERIODO,vF_FIN_PERIODO,vCOD_PROVINCIA,
				vCOD_AYUNTAMIENTO,vCOD_NOTARIO,UPPER(vNOMBRE_NOTARIO),rtrim(xPath)||'\'||rtrim(xFileName),SUBSTR(vReg,1,659))
			RETURNING ID INTO vID;
			
	  	END IF;

		--{ Identificacion del movimiento }
	  	IF SUBSTR(vReg,3,8)='00000000' THEN
	      vF_ESCRITURA_DOC:=NULL;
	    ELSE vF_ESCRITURA_DOC:=TO_DATE(SUBSTR(vReg,3,8),'DDMMYYYY');
	    END IF;

	    vCLASE_ALTERACION:=SUBSTR(vReg,11,1);
	    vCUMPLIMIENTO_ARTICULO:=SUBSTR(vReg,12,1);

		--{ Identificacion del bien inmueble }
	    vREF_CATASTRAL:=SUBSTR(vReg,13,20);
	    vNUM_FIJO:=SUBSTR(vReg,33,14);
	    vYEAR_PROTOCOLO:=SUBSTR(vReg,47,4);
	    vNUMERO_PROTOCOLO:=SUBSTR(vReg,51,4);
	    vVALOR_TRANSMISION:=SUBSTR(vReg,55,12);
	    vCOD_PROVINCIA_INE:=SUBSTR(vReg,67,2);
	    vCOD_MUNICIPIO_INE:=SUBSTR(vReg,69,3);
	    vNOMBRE_MUNICIPIO:=SUBSTR(vReg,72,25);
	    vNOMBRE_ENTIDAD_MENOR:=SUBSTR(vReg,97,15);
	    vTIPO_VIA:=SUBSTR(vReg,112,5);
	    vNOMBRE_VIA:=SUBSTR(vReg,117,25);
	    vNUMERO_VIA:=SUBSTR(vReg,142,4);
	    vDUPLICADO:=SUBSTR(vReg,146,1);
	    vBLOQUE:=SUBSTR(vReg,147,4);
	    vESCALERA:=SUBSTR(vReg,151,2);
	    vPLANTA:=SUBSTR(vReg,153,2);
	    vPUERTA:=SUBSTR(vReg,155,3);
		vRESTO_DIRECCION:=SUBSTR(vReg,158,25);
	    vAPROX_POSTAL_KM:=SUBSTR(vReg,183,6);
	    vCOD_POSTAL:=SUBSTR(vReg,189,5);

	    --{ Identificacion del transmitente }
	    vNUM_COTITULARES_TRAN:=SUBSTR(vReg,194,4);
	    vNIF_TRAN:=SUBSTR(vReg,198,9);
	    vNOMBRE_TRAN:=SUBSTR(vReg,207,62);

	    --{ Identificacion del nuevo titular }
	    vNUM_COTITULARES_TIT:=SUBSTR(vReg,269,4);
	    vDESC_COTITULARIDAD:=SUBSTR(vReg,273,20);
	    vNIF_TIT:=SUBSTR(vReg,293,9);
	    vNOMBRE_TIT:=SUBSTR(vReg,302,62);

	    --{ Domicilio del nuevo titular }
	    vCOD_PROVI_INE_TIT:=SUBSTR(vReg,364,2);
	    vCOD_MUNI_INE_TIT:=SUBSTR(vReg,366,3);
	    vNOMBRE_MUNI_TIT:=SUBSTR(vReg,369,40);
	    vCOD_TIPO_VIA_TIT:=SUBSTR(vReg,409,5);
		vNOMBRE_VIA_TIT:=SUBSTR(vReg,414,25);
	    vNUMERO_VIA_TIT:=SUBSTR(vReg,439,4);
	    vDUPLICADO_TIT:=SUBSTR(vReg,443,1);
	    vBLOQUE_TIT:=SUBSTR(vReg,444,4);
	    vESCALERA_TIT:=SUBSTR(vReg,448,2);
	    vPLANTA_TIT:=SUBSTR(vReg,450,2);
	    vPUERTA_TIT:=SUBSTR(vReg,452,3);
	    vRESTO_DIRECCION_TIT:=SUBSTR(vReg,455,25);
	    vAPROX_POSTAL_KM_TIT:=SUBSTR(vReg,480,6);
	    vCOD_POSTAL_TIT:=SUBSTR(vReg,486,5);

	    -- { Domicilio del transmitente }
	    vCOD_PROVI_INE_TRAN:=SUBSTR(vReg,491,2);
	    vCOD_MUNI_INE_TRAN:=SUBSTR(vReg,493,3);
	    vNOMBRE_MUNI_TRAN:=SUBSTR(vReg,496,40);
	    vTIPO_VIA_TRAN:=SUBSTR(vReg,536,5);
	    vNOMBRE_VIA_TRAN:=SUBSTR(vReg,541,25);
	    vNUMERO_VIA_TRAN:=SUBSTR(vReg,566,4);
	    vDUPLICADO_TRAN:=SUBSTR(vReg,570,1);
	    vBLOQUE_TRAN:=SUBSTR(vReg,571,4);
	    vESCALERA_TRAN:=SUBSTR(vReg,575,2);
	    vPLANTA_TRAN:=SUBSTR(vReg,577,2);
	    vPUERTA_TRAN:=SUBSTR(vReg,579,3);
	    vRESTO_DIRECCION_TRAN:=SUBSTR(vReg,582,25);
	    vAPROX_POSTAL_KM_TRAN:=SUBSTR(vReg,607,6);
	    vCOD_POSTAL_TRAN:=SUBSTR(vReg,613,5);

	    vDESC_OPERACION:=SUBSTR(vReg,618,30);
	    vCOD_OPERACION:=SUBSTR(vReg,648,10);

		INSERT INTO NOTARIAS_DETALLE (
  			IDNOTARIA,
			--{ Registro Detalle }
    		F_ESCRITURA_DOC,CLASE_ALTERACION,CUMPLIMIENTO_ARTICULO,
			--{ Identificacion del bien inmueble }
			REF_CATASTRAL,NUM_FIJO,YEAR_PROTOCOLO,NUMERO_PROTOCOLO,VALOR_SUELO,VALOR_TRANSMISION,COD_PROVINCIA_INE,COD_MUNICIPIO_INE,
    		NOMBRE_MUNICIPIO,NOMBRE_ENTIDAD_MENOR,TIPO_VIA,NOMBRE_VIA,NUMERO_VIA,DUPLICADO,BLOQUE,ESCALERA,PLANTA,PUERTA,
			RESTO_DIRECCION,APROX_POSTAL_KM,COD_POSTAL,
    		--{ Identificacion del transmitente }
    		NUM_COTITULARES_TRAN,NIF_TRAN,NOMBRE_TRAN,
    		--{ Identificacion del nuevo titular }
    		NUM_COTITULARES_TIT,DESC_COTITULARIDAD,NIF_TIT,NOMBRE_TIT,
    		--{ Domicilio del nuevo titular }
    		COD_PROVI_INE_TIT,COD_MUNI_INE_TIT,NOMBRE_MUNI_TIT,TIPO_VIA_TIT,NOMBRE_VIA_TIT,NUMERO_VIA_TIT,
    		DUPLICADO_TIT,BLOQUE_TIT,ESCALERA_TIT,PLANTA_TIT,PUERTA_TIT,RESTO_DIRECCION_TIT,APROX_POSTAL_KM_TIT,
    		COD_POSTAL_TIT,
    		-- { Domicilio del transmitente }
    		COD_PROVI_INE_TRAN,COD_MUNI_INE_TRAN,NOMBRE_MUNI_TRAN,TIPO_VIA_TRAN,NOMBRE_VIA_TRAN,NUMERO_VIA_TRAN,DUPLICADO_TRAN,
    		BLOQUE_TRAN,ESCALERA_TRAN,PLANTA_TRAN,PUERTA_TRAN,RESTO_DIRECCION_TRAN,APROX_POSTAL_KM_TRAN,COD_POSTAL_TRAN,
    		DESC_OPERACION,COD_OPERACION)
	  	VALUES (
  			vID,
			--{ Registro Detalle }
    		vF_ESCRITURA_DOC,vCLASE_ALTERACION,vCUMPLIMIENTO_ARTICULO,
			--{ Identificacion del bien inmueble }
			vREF_CATASTRAL,vNUM_FIJO,vYEAR_PROTOCOLO,vNUMERO_PROTOCOLO,vVALOR_SUELO,vVALOR_TRANSMISION,vCOD_PROVINCIA_INE,vCOD_MUNICIPIO_INE,
    		vNOMBRE_MUNICIPIO,vNOMBRE_ENTIDAD_MENOR,vTIPO_VIA,vNOMBRE_VIA,vNUMERO_VIA,vDUPLICADO,vBLOQUE,vESCALERA,vPLANTA,vPUERTA,
			vRESTO_DIRECCION,vAPROX_POSTAL_KM,vCOD_POSTAL,
    		--{ Identificacion del transmitente }
    		vNUM_COTITULARES_TRAN,TRIM(vNIF_TRAN),vNOMBRE_TRAN,
    		--{ Identificacion del nuevo titular }
    		vNUM_COTITULARES_TIT,vDESC_COTITULARIDAD,TRIM(vNIF_TIT),vNOMBRE_TIT,
    		--{ Domicilio del nuevo titular }
    		vCOD_PROVI_INE_TIT,vCOD_MUNI_INE_TIT,vNOMBRE_MUNI_TIT,vCOD_TIPO_VIA_TIT,vNOMBRE_VIA_TIT,vNUMERO_VIA_TIT,
    		vDUPLICADO_TIT,vBLOQUE_TIT,vESCALERA_TIT,vPLANTA_TIT,vPUERTA_TIT,vRESTO_DIRECCION_TIT,vAPROX_POSTAL_KM_TIT,
    		vCOD_POSTAL_TIT,
    		-- { Domicilio del transmitente }
    		vCOD_PROVI_INE_TRAN,vCOD_MUNI_INE_TRAN,vNOMBRE_MUNI_TRAN,vTIPO_VIA_TRAN,vNOMBRE_VIA_TRAN,vNUMERO_VIA_TRAN,vDUPLICADO_TRAN,
    		vBLOQUE_TRAN,vESCALERA_TRAN,vPLANTA_TRAN,vPUERTA_TRAN,vRESTO_DIRECCION_TRAN,vAPROX_POSTAL_KM_TRAN,vCOD_POSTAL_TRAN,
    		vDESC_OPERACION,vCOD_OPERACION);

		xNumReg:=xNumReg+1;
		
	  END IF;

	  UTL_FILE.GET_LINE(vOutFile,vReg); -- Lee la siguiente línea

	  EXCEPTION
	    WHEN NO_DATA_FOUND THEN
		   EXIT;
	  END;
	END LOOP;

	UTL_FILE.FCLOSE(vOutFile);

	EXCEPTION
		WHEN NO_DATA_FOUND 					THEN recNgo ('no_data_found',xError);
	    WHEN UTL_FILE.INVALID_PATH 			THEN recNgo ('invalid_path',xError);
	    WHEN UTL_FILE.INVALID_MODE 			THEN recNgo ('invalid_mode',xError);
	    WHEN UTL_FILE.INVALID_FILEHANDLE 	THEN recNgo ('invalid_filehandle',xError);
	    WHEN UTL_FILE.INVALID_OPERATION 	THEN recNgo ('invalid_operation',xError);
	    WHEN UTL_FILE.READ_ERROR 			THEN recNgo ('read_error',xError);
	    WHEN UTL_FILE.WRITE_ERROR 			THEN recNgo ('write_error',xError);
	    WHEN UTL_FILE.INTERNAL_ERROR 		THEN recNgo ('internal_error',xError);
		WHEN VALUE_ERROR 					THEN recNgo ('value_error',xError);
		WHEN OTHERS 						THEN recNgo (To_CHAR(SQLCODE)||SQLERRM,xError);

END READ;

/****************************************************************************************************
AUTOR: Gloria María Calle Hernández. 01/02/2002
FUNCION: Revisa las tablas de NOTARIAS y NOTARIAS_DETALLE buscando incidencias.
		 La tabla puede contener registros repetidos, notarios, adquirientes o transmitentes desconocidos
	 	 que se marcaran como GENERADO='E',Motivo="correspondiente".
MODIFICACION: 12/04/2005. Gloria Maria Calle Hernandez. Cambiado proceso de validación, reestructurados
		 por partes y acelerados actualizaciones.
Modificado: 27/04/05. Gloria Maria Calle Hernandez. Añadido campo Liquidado y F_Liquidacion para marcar 
		 los liquidados a parte de los generados.
MODIFICACION: 07/09/2006. Lucas Fernández Pérez. Revisión General. 
MODIFICACION: 14/09/2006. Lucas Fernández Pérez. Optimización de las consultas.
	Sólo se revisan los registros no generados (Generado= 'N','E')
MODIFICACION: 25/09/2006. Lucas Fernández Pérez. Nuevo parámetro xCodOpe para validar los cod.operacion.
MODIFICACION: 10/10/2006. Lucas Fernández Pérez. Nuevo parámetro xGeneraContri para crear los adqui/transmitentes
					que no existan en la base de datos de contribuyentes
MODIFICACION: 05/02/2007. Lucas Fernández Pérez. Cambia la llamada de InsertaModiContribuyente a Ins_Upd_Contri
***************************************************************************************************************/
PROCEDURE VALIDAR (
  		xIBI		IN  BOOLEAN,
		xNOTARIOS	IN  BOOLEAN,
		xPLUSVA		IN  BOOLEAN,
		xCODOPE     IN  BOOLEAN,
		xCORREGIR	IN	BOOLEAN,
		xCONTRI		IN	BOOLEAN,
		xGENERACONTRI IN	BOOLEAN)
AS
	vREF_CATASTRAL		VARCHAR2(20);
	vAYTO				VARCHAR2(3);

	xNIF			VARCHAR2(9);
	xNOMBRE			VARCHAR2(62);
	xCOD_PROVI_INE	VARCHAR2(2);
	xNOMBRE_MUNI	VARCHAR2(40);
	xTIPO_VIA		VARCHAR2(5);
	xNOMBRE_VIA		VARCHAR2(25);
	xNUMERO_VIA		VARCHAR2(4);
	xBLOQUE			VARCHAR2(4);
	xESCALERA		VARCHAR2(2);
	xPLANTA			VARCHAR2(2);
	xPUERTA			VARCHAR2(3);
	xCOD_POSTAL		VARCHAR2(5);
	xPROVINCIA		VARCHAR2(35);
	
	CURSOR CAYTOS IS SELECT MUNICIPIO FROM TMP_AYTOS WHERE USUARIO=USER;

	CURSOR cREG_REPETIDOS IS SELECT distinct N1.REF_CATASTRAL,N1.GENERADO,N1.ID,N1.F_ESCRITURA_DOC
		   	   			  	   FROM NOTARIAS_DETALLE N1 JOIN NOTARIAS_DETALLE N2
	       					     ON N1.REF_CATASTRAL=N2.REF_CATASTRAL
								AND N1.F_ESCRITURA_DOC=N2.F_ESCRITURA_DOC
								AND N1.NIF_TIT=N2.NIF_TIT AND N1.NIF_TRAN=N2.NIF_TRAN
								AND N1.COD_MUNICIPIO_INE=N2.COD_MUNICIPIO_INE AND N1.COD_MUNICIPIO_INE=vAYTO
 						 	  WHERE N1.GENERADO IN ('N','E') AND N2.GENERADO IN ('N','E') AND N1.ID<>N2.ID
 						 	  		AND TRIM(N1.REF_CATASTRAL) IS NOT NULL
							  ORDER BY N1.REF_CATASTRAL,N1.GENERADO DESC,N1.F_ESCRITURA_DOC DESC;
							  
	CURSOR cPlusva IS SELECT DISTINCT(NIF) FROM TMP_PLUSVA_IBI WHERE USUARIO=USER ORDER BY NIF;
	
BEGIN
  --Cursor de Ayuntamientos
  FOR vAYTOS IN CAYTOS
  LOOP

    vAYTO:=vAYTOS.MUNICIPIO;

    IF xIBI THEN
 	  --Actualizamos el valor_suelo y year_valor suelo de NOTARIAS_DETALLE si estaba vacío 
 	  -- y lo podemos obtener casando por referencia catastral de ibi.
      BEGIN
		DELETE TMP_PLUSVA_IBI WHERE USUARIO=USER;

		-- 1. Inserta en una tabla temporal los datos a modificar en notarias_detalle. Esto es para acelerar en tiempo.
		--     Por cada referencia catastral graba en la tabla los valores de los distintos años, y en el punto 2
		--		accede al mayor año para tomar el valor catastral. Si se hace esto en una consulta va muy lento.
		INSERT INTO TMP_PLUSVA_IBI (USUARIO,REF_CATASTRAL,YEAR_VALOR_CATASTRAL,VALOR_CATASTRAL)
		SELECT USER,I.REF_CATASTRAL||I.NUMERO_SECUENCIAL||I.PRIMER_CARACTER_CONTROL||I.SEGUN_CARACTER_CONTROL,
				I.YEAR_VALOR_CATASTRAL,I.VALOR_CATASTRAL 
			FROM IBI I WHERE I.MUNICIPIO=vAYTO AND
				 I.REF_CATASTRAL||I.NUMERO_SECUENCIAL||I.PRIMER_CARACTER_CONTROL||I.SEGUN_CARACTER_CONTROL
				 IN (SELECT N.REF_CATASTRAL FROM NOTARIAS_DETALLE N WHERE N.COD_MUNICIPIO_INE=vAYTO
 		 			AND TRIM(N.REF_CATASTRAL) IS NOT NULL AND (N.VALOR_SUELO IS NULL OR N.VALOR_SUELO=0)
 		 			AND N.GENERADO IN ('N','E'));

 		 -- 2. Modifica en notarías detalle el valor del suelo si no tenía ninguno.
		UPDATE NOTARIAS_DETALLE N SET (YEAR_VALOR_SUELO,VALOR_SUELO)=
       	(SELECT YEAR_VALOR_CATASTRAL,VALOR_CATASTRAL FROM TMP_PLUSVA_IBI T
         WHERE USUARIO=USER 
	      AND YEAR_VALOR_CATASTRAL IN (SELECT MAX(YEAR_VALOR_CATASTRAL) 
       								  FROM TMP_PLUSVA_IBI WHERE N.REF_CATASTRAL=T.REF_CATASTRAL AND USUARIO=USER)
		  AND N.REF_CATASTRAL=T.REF_CATASTRAL AND ROWNUM=1
		)
		WHERE N.COD_MUNICIPIO_INE=vAYTO AND TRIM(REF_CATASTRAL) IS NOT NULL AND (VALOR_SUELO IS NULL OR VALOR_SUELO=0)
			AND N.REF_CATASTRAL IN (SELECT REF_CATASTRAL FROM TMP_PLUSVA_IBI WHERE USUARIO=USER)
			AND N.GENERADO IN ('N','E');
	  EXCEPTION
	     WHEN OTHERS THEN
	   	  	NULL;
	  END;
    END IF;

    IF xNOTARIOS THEN --Validamos que existan los notarios en nuestra base de datos
	BEGIN

	  	-- Borra del motivo el texto de que no conocía al notario, cuando ya sí se conoce.
  	    UPDATE NOTARIAS_DETALLE SET MOTIVO=REPLACE(MOTIVO,'NOTARIO DESCONOCIDO. ','') 
		 WHERE COD_MUNICIPIO_INE=vAYTO AND GENERADO='E' AND INSTR(MOTIVO,'NOTARIO')<>0
		 	AND IDNOTARIA IN 
		 	(SELECT N.ID FROM NOTARIAS N, NOTARIOS O WHERE N.COD_NOTARIO=O.COD_NOTARIO AND N.COD_AYUNTAMIENTO=vAYTO);

		-- Graba el motivo si no se conoce el notario.
  	    UPDATE NOTARIAS_DETALLE SET MOTIVO=MOTIVO||'NOTARIO DESCONOCIDO. '
		 WHERE COD_MUNICIPIO_INE=vAYTO AND GENERADO IN ('N','E') 
		 	AND IDNOTARIA IN 
		 	(SELECT ID FROM NOTARIAS WHERE COD_AYUNTAMIENTO=vAYTO AND 
		 		COD_NOTARIO NOT IN (SELECT COD_NOTARIO FROM NOTARIOS WHERE COD_NOTARIO IS NOT NULL)
		 	) AND (INSTR(MOTIVO,'NOTARIO')=0 OR MOTIVO IS NULL);

	  EXCEPTION
	     WHEN OTHERS THEN
	   		NULL;
	  END;
    END IF;

    IF xCONTRI THEN
      --Validamos que los contribuyenters existan en nuestra base de datos, y si se pide, creamos los que no existen.
	  BEGIN
	  
	  	-- 1. Adquirente: Busca los adquirientes que no se conocen.
		DELETE TMP_PLUSVA_IBI WHERE USUARIO=USER;

		INSERT INTO TMP_PLUSVA_IBI(USUARIO,NIF)
			SELECT USER,TRIM(NIF_TIT) FROM NOTARIAS_DETALLE WHERE COD_MUNICIPIO_INE=vAYTO  AND GENERADO IN ('N','E')  
		 	MINUS
			SELECT USER,TRIM(NIF) FROM CONTRIBUYENTES;

		-- 2. Si se pide generar los adquirientes desconocidos, se crean los contribuyentes.
		IF xGENERACONTRI=true THEN		 	
			
			FOR vPlusva IN cPlusva LOOP
			
				SELECT NIF_TIT, NOMBRE_TIT, COD_PROVI_INE_TIT, NOMBRE_MUNI_TIT, trim(TIPO_VIA_TIT), trim(NOMBRE_VIA_TIT),
					trim(NUMERO_VIA_TIT), trim(BLOQUE_TIT), trim(ESCALERA_TIT), trim(PLANTA_TIT), trim(PUERTA_TIT),
					COD_POSTAL_TIT 
					INTO xNIF, xNOMBRE, xCOD_PROVI_INE, xNOMBRE_MUNI, xTIPO_VIA, xNOMBRE_VIA,
					xNUMERO_VIA, xBLOQUE, xESCALERA, xPLANTA, xPUERTA, xCOD_POSTAL
				FROM NOTARIAS_DETALLE 
				WHERE ID=(SELECT MAX(ID) FROM NOTARIAS_DETALLE WHERE trim(NIF_TIT)=trim(vPlusva.NIF));
				
				BEGIN				
				
				  SELECT PROVINCIA INTO xPROVINCIA FROM COD_PROVINCIAS WHERE CODPROV=xCOD_PROVI_INE;
				  EXCEPTION
	    			WHEN NO_DATA_FOUND THEN
		   			xPROVINCIA:='';
		   			
				END;
				
				INS_UPD_CONTRI('A',xNIF, SUBSTR(xNOMBRE,1,40), SUBSTR(xTIPO_VIA,1,2), xNOMBRE_VIA,
					xNUMERO_VIA, xBLOQUE, '' , xESCALERA, xPLANTA, substr(xPUERTA,1,2), 
					SUBSTR(xNOMBRE_MUNI,1,35), xPROVINCIA, xCOD_POSTAL, '',NULL, '' ,'','','');
					
			END LOOP;
			
			DELETE TMP_PLUSVA_IBI WHERE USUARIO=USER; -- Ya no hay adquirientes desconocidos, se han dado de alta

		
		END IF;

	  	-- 3. Adquirentes: Borra del motivo el texto de que no conocía al adquiriente, cuando ya sí se conoce.
	    UPDATE NOTARIAS_DETALLE N SET MOTIVO=REPLACE(MOTIVO,'ADQUIRIENTE DESCONOCIDO. ','') 
		 WHERE COD_MUNICIPIO_INE=vAYTO AND GENERADO='E' AND TRIM(NIF_TIT) IN (SELECT TRIM(NIF) FROM CONTRIBUYENTES)
			   AND INSTR(MOTIVO,'ADQUIRIENTE')<>0;

		-- 4. Adquirentes: Graba en el motivo el texto de que no conoce al adquiriente para los desconocidos.
	    UPDATE NOTARIAS_DETALLE N SET MOTIVO=MOTIVO||'ADQUIRIENTE DESCONOCIDO. ' 
		 WHERE COD_MUNICIPIO_INE=vAYTO AND GENERADO IN ('N','E') 
		 	AND TRIM(NIF_TIT) IN (SELECT TRIM(NIF) FROM TMP_PLUSVA_IBI WHERE USUARIO=USER)
			AND (INSTR(MOTIVO,'ADQUIRIENTE')=0 OR MOTIVO IS NULL);

			
			
	  	-- 5. Transmitente: Busca los Transmitentes que no se conocen.
		DELETE TMP_PLUSVA_IBI WHERE USUARIO=USER;

		INSERT INTO TMP_PLUSVA_IBI(USUARIO,NIF)
			SELECT USER,TRIM(NIF_TRAN) FROM NOTARIAS_DETALLE WHERE COD_MUNICIPIO_INE=vAYTO  AND GENERADO IN ('N','E')  
		 	MINUS
			SELECT USER,TRIM(NIF) FROM CONTRIBUYENTES;

		-- 6. Si se pide generar los transmitentes desconocidos, se crean los contribuyentes.
		IF xGENERACONTRI=true THEN		 	
		
			FOR vPlusva IN cPlusva LOOP
			
				SELECT NIF_TRAN,NOMBRE_TRAN,COD_PROVI_INE_TRAN,NOMBRE_MUNI_TRAN, trim(TIPO_VIA_TRAN), 
					trim(NOMBRE_VIA_TRAN), trim(NUMERO_VIA_TRAN), trim(BLOQUE_TRAN), trim(ESCALERA_TRAN),
					trim(PLANTA_TRAN), trim(PUERTA_TRAN), COD_POSTAL_TRAN  
					INTO xNIF, xNOMBRE, xCOD_PROVI_INE, xNOMBRE_MUNI, xTIPO_VIA, xNOMBRE_VIA,
					xNUMERO_VIA, xBLOQUE, xESCALERA, xPLANTA, xPUERTA, xCOD_POSTAL
				FROM NOTARIAS_DETALLE 
				WHERE ID=(SELECT MAX(ID) FROM NOTARIAS_DETALLE WHERE trim(NIF_TRAN)=trim(vPlusva.NIF));
				
				BEGIN				
				
				  SELECT PROVINCIA INTO xPROVINCIA FROM COD_PROVINCIAS WHERE CODPROV=xCOD_PROVI_INE;
				  EXCEPTION
	    			WHEN NO_DATA_FOUND THEN
		   			xPROVINCIA:='';
		   			
				END;
				
				INS_UPD_CONTRI('A',xNIF, SUBSTR(xNOMBRE,1,40), SUBSTR(xTIPO_VIA,1,2), xNOMBRE_VIA,
					xNUMERO_VIA, xBLOQUE, '' , xESCALERA, xPLANTA, substr(xPUERTA,1,2), 
					SUBSTR(xNOMBRE_MUNI,1,35), xPROVINCIA, xCOD_POSTAL, '',NULL, '' ,'','','');
					
			END LOOP;
			
			DELETE TMP_PLUSVA_IBI WHERE USUARIO=USER; -- Ya no hay transmitentes desconocidos, se han dado de alta
			
		END IF;
				
			
	  	-- 7. Transmitentes: Borra del motivo el texto de que no conocía al transmitente, cuando ya sí se conoce.
		UPDATE NOTARIAS_DETALLE N SET MOTIVO=REPLACE(MOTIVO,'TRANSMITENTE DESCONOCIDO. ','')
		 WHERE COD_MUNICIPIO_INE=vAYTO AND GENERADO='E' AND TRIM(NIF_TRAN) IN (SELECT TRIM(NIF) FROM CONTRIBUYENTES)
			   AND INSTR(MOTIVO,'TRANSMITENTE')<>0;

	  	-- 8. Transmitente: Graba en el motivo el texto de que no conoce al transmitente para los desconocidos.
		UPDATE NOTARIAS_DETALLE N SET MOTIVO=MOTIVO||'TRANSMITENTE DESCONOCIDO. '
		 WHERE COD_MUNICIPIO_INE=vAYTO AND GENERADO IN ('N','E') 
		 	AND TRIM(NIF_TRAN) IN (SELECT TRIM(NIF) FROM TMP_PLUSVA_IBI WHERE USUARIO=USER)
			AND (INSTR(MOTIVO,'TRANSMITENTE')=0 OR MOTIVO IS NULL);
			   
	  EXCEPTION
	    WHEN OTHERS THEN
	         NULL;
	  END;
    END IF;

    IF xCODOPE THEN

	  	-- 1. Borra del motivo el texto de que no conocía el codigo de operacion, cuando ya sí se conoce.
	    UPDATE NOTARIAS_DETALLE N SET MOTIVO=REPLACE(MOTIVO,'CÓDIGO DE OPERACIÓN DESCONOCIDO. ','') 
		 WHERE COD_MUNICIPIO_INE=vAYTO AND GENERADO='E' AND COD_OPERACION IN 
		 		(SELECT CODIGO_OPERACION FROM COD_OPE_PLUSVALIAS WHERE AYTO=vAYTO)
			   AND INSTR(MOTIVO,'CÓDIGO DE OPERACIÓN')<>0;

	  	-- 1. Anota en el motivo el hecho de que se no conoce el codigo de operacion.
	    UPDATE NOTARIAS_DETALLE N SET MOTIVO=MOTIVO||'CÓDIGO DE OPERACIÓN DESCONOCIDO. ' 
		 WHERE COD_MUNICIPIO_INE=vAYTO AND GENERADO IN ('N','E') 
		 	AND COD_OPERACION NOT IN 
		 		(SELECT CODIGO_OPERACION FROM COD_OPE_PLUSVALIAS WHERE AYTO=vAYTO)
		 		AND (INSTR(MOTIVO,'CÓDIGO DE OPERACIÓN')=0 OR MOTIVO IS NULL);
		 	
    END IF;

    IF xCORREGIR THEN
	  vREF_CATASTRAL:= '00000000000000000000';
	  --Validamos que no haya registros repetidos para el mismo bien inmueble... (EL CURSOR RESTRINGE POR MUNICIPIO)
	  FOR vREG_REPETIDOS IN cREG_REPETIDOS
	  LOOP
		IF (vREF_CATASTRAL<>vREG_REPETIDOS.REF_CATASTRAL) THEN -- La primera vez borra el motivo
		    vREF_CATASTRAL:= vREG_REPETIDOS.REF_CATASTRAL;
 	        UPDATE NOTARIAS_DETALLE SET MOTIVO=REPLACE(MOTIVO,'ALTERACIÓN REPETIDA. ','')
	         WHERE ID=vREG_REPETIDOS.ID AND INSTR(MOTIVO,'REPETIDA')<>0;
		ELSE -- La segunda y siguientes repeticiones graba el motivo
		    UPDATE NOTARIAS_DETALLE SET MOTIVO=MOTIVO||'ALTERACIÓN REPETIDA. '
			 WHERE ID=vREG_REPETIDOS.ID AND (INSTR(MOTIVO,'REPETIDA')=0 OR MOTIVO IS NULL);
		END IF;
	  END LOOP;

	  --Validamos aquellos registros de distinta direccion y titulares de venta-compra pero igual ref_catastral...
	  BEGIN
		UPDATE NOTARIAS_DETALLE N1 SET MOTIVO=MOTIVO||'MISMA REF_CATASTRAL PARA DISTINTA DIRECCION. '
		 WHERE N1.COD_MUNICIPIO_INE=vAYTO AND (INSTR(MOTIVO,'REF_CATASTRAL')=0 OR MOTIVO IS NULL)
		   AND N1.ID IN (SELECT N1.ID FROM NOTARIAS_DETALLE N1
		 	   		 				  JOIN NOTARIAS_DETALLE N2 ON N1.ID<>N2.ID 
		 	   		 				   AND N1.COD_MUNICIPIO_INE=N2.COD_MUNICIPIO_INE
		 	   		 				   AND N1.REF_CATASTRAL=N2.REF_CATASTRAL
									   AND TRIM(N1.NOMBRE_VIA)<>TRIM(N2.NOMBRE_VIA)
									   AND TRIM(N1.REF_CATASTRAL) IS NOT NULL
									   AND N1.GENERADO IN ('N','E') AND N2.GENERADO IN ('N','E'));
	  EXCEPTION
	    WHEN OTHERS THEN
		     NULL;
	  END;
    END IF;

    --Actualizar campo Generado de la tabla tras toda validacion 
    UPDATE NOTARIAS_DETALLE SET GENERADO=DECODE(GENERADO,'S','S',DECODE(TRIM(MOTIVO),NULL,'N','E'));
    
    IF xPLUSVA THEN
	  --Validamos aquellas plusvalias que hayan sido ya liquidadas
	  BEGIN
	  	
		UPDATE NOTARIAS_DETALLE D SET D.LIQUIDADO='L'
 		 WHERE (D.COD_MUNICIPIO_INE,D.YEAR_PROTOCOLO,
 		 		TRIM(GETPROTOCOLO(D.COD_MUNICIPIO_INE,D.YEAR_PROTOCOLO,D.NUMERO_PROTOCOLO)),
 		 		(SELECT MAX(ID) FROM NOTARIOS WHERE COD_NOTARIO=(SELECT COD_NOTARIO FROM NOTARIAS WHERE ID=D.IDNOTARIA))
 		 		) IN
	   (SELECT vAYTO,P.YEAR,
	   		   TRIM(P.PROTOCOLO),
	   		   P.NOTARIO
   		  FROM PLUSVALIAS P) AND LIQUIDADO='N';
	  EXCEPTION
	    WHEN OTHERS THEN
		     NULL;
	  END;
    END IF;

  END LOOP;
END VALIDAR;



/****************************************************************************************************
AUTOR: Gloria María Calle Hernández. 01/02/2002
FUNCION: Genera los requerimientos de plusvalias de un notario (los que se puedan generar, que pasasen la validación)
		  y de los municipios que haya en TMP_AYTOS.
PARAMETROS: 	xFECHA   : Fecha de los requerimientos
				xNOTARIO : Notario sobre el que se van a generar los requerimientos. 
				xNUMREQUE: Devuelve el número de requerimientos que se han generado.
MODIFICACION: 07/09/2006. Lucas Fernández Pérez. Revisión General. 
*****************************************************************************************************/
PROCEDURE GENERAR (
	xFECHA				IN  DATE,
	xNOTARIO			IN INTEGER,
	xNUMREQUE			OUT INTEGER)
AS
	vAYTO		CHAR(3);
	vCOUNT		INTEGER;
	vNOTARIO	INTEGER;
	vID_REQUE	INTEGER;
	vOBJ_TRIBU	VARCHAR2(40);
	vGENERADO	BOOLEAN;
	vMOTIVO		VARCHAR2(100);
	vTITULO     CHAR(1);  
	vCLASE      CHAR(1);
	vDEUDOR CHAR(10);

	CURSOR CAYTOS IS SELECT MUNICIPIO FROM TMP_AYTOS WHERE USUARIO=USER;

	CURSOR cPLUSVA IS SELECT * FROM NOTARIAS_DETALLE 
	 WHERE COD_MUNICIPIO_INE=vAYTO AND GENERADO='N' AND LIQUIDADO='N' AND MOTIVO IS NULL AND IDNOTARIA IN
	 	(SELECT ID FROM NOTARIAS WHERE COD_NOTARIO=xNOTARIO)
	FOR UPDATE;

BEGIN

   xNUMREQUE:=0;

   -- Cursor de ayuntamientos
   FOR vAYTOS IN CAYTOS
   LOOP
      vAYTO:=vAYTOS.MUNICIPIO;

	  UPDATE NOTARIAS_DETALLE D SET D.LIQUIDADO='L'
 	  WHERE (D.COD_MUNICIPIO_INE,D.YEAR_PROTOCOLO,
 				TRIM(GETPROTOCOLO(D.COD_MUNICIPIO_INE,D.YEAR_PROTOCOLO,D.NUMERO_PROTOCOLO)),
 				(SELECT MAX(ID) FROM NOTARIOS WHERE COD_NOTARIO=(SELECT COD_NOTARIO FROM NOTARIAS WHERE ID=D.IDNOTARIA))
 			) 
 			IN (SELECT vAYTO,P.YEAR, TRIM(P.PROTOCOLO), P.NOTARIO FROM PLUSVALIAS P) 
	  		AND D.LIQUIDADO='N';
	    
      -- Cursor sobre los registros de la tabla NOTARIAS
      FOR vPLUSVA IN cPLUSVA LOOP

	   	/* Crear el objeto tributario */
		vOBJ_TRIBU:=SUBSTR(TRIM(vPLUSVA.TIPO_VIA)||' '||TRIM(vPLUSVA.NOMBRE_VIA)||' '||TRIM(vPLUSVA.NUMERO_VIA)||' '||
				    TRIM(vPLUSVA.DUPLICADO)||' '||TRIM(vPLUSVA.BLOQUE)||' '||TRIM(vPLUSVA.ESCALERA)||' '||
				    TRIM(vPLUSVA.PLANTA)||' '||TRIM(vPLUSVA.PUERTA)||' '||TRIM(vPLUSVA.COD_POSTAL),1,40);

		BEGIN
	   	   SELECT N.ID INTO vNOTARIO FROM NOTARIOS N JOIN NOTARIAS N1 
		   		  	   				   ON N.COD_NOTARIO=N1.COD_NOTARIO AND N1.ID=vPLUSVA.IDNOTARIA AND ROWNUM=1;
   		EXCEPTION
	       WHEN OTHERS THEN
		        NULL;
	   	END;

	   	-- Se busca el titulo y clase de la plusvalía para generar el requerimiento	   	
	   	SELECT CLASE,TITULO INTO vCLASE, vTITULO FROM COD_OPE_PLUSVALIAS 
	   	WHERE AYTO=vAYTO AND CODIGO_OPERACION=vPLUSVA.COD_OPERACION;
	   	
	    if vCLASE='O' and vTITULO<>'R' then -- Si es onerosa y no es residente, paga el transmitente
	    	vDEUDOR:=vPLUSVA.NIF_TRAN;
	    else
	    	vDEUDOR:=vPLUSVA.NIF_TIT;
	    end if;

		-- Añadir el requerimiento
		ADDMOD_REQUE(0,vAYTO, GETPROTOCOLO(vAYTO,vPLUSVA.YEAR_PROTOCOLO,vPLUSVA.NUMERO_PROTOCOLO),
					 vNOTARIO, vDEUDOR,
					 vPLUSVA.REF_CATASTRAL,vOBJ_TRIBU,vPLUSVA.F_ESCRITURA_DOC,vPLUSVA.NIF_TRAN,vPLUSVA.NIF_TIT,
					 vCLASE,vTITULO,vID_REQUE);

		xNUMREQUE:=xNUMREQUE+1;

 	    UPDATE NOTARIAS_DETALLE SET IDREQUE=vID_REQUE, GENERADO='S', F_GENERACION=SYSDATE,
			   						MOTIVO='GENERADO EL REQUERIMIENTO DE LA PLUSVALIA DESDE FICHERO'
	  	WHERE CURRENT OF cPLUSVA;

	 END LOOP; -- cPLUSVA

   END LOOP;	-- cAYTOS
   
END GENERAR;


/****************************************************************************************************
AUTOR: Gloria María Calle Hernández. 01/02/2002
FUNCION: Procdimiento q actualiza datos del titular: dni,nombre,direccion fiscal...
PARAMETROS: 	xID: Identificador del registro de la tabla NOTARIAS a modificar
				x... Datos posibles a modificar
				xTODOS: Parámetro con el cual podremos elegir entre modificar sólo el registro espeificado,
						o todos los registros para el mismo dni o titular
*****************************************************************************************************/
PROCEDURE MODIFY (
    xID 					IN INTEGER,
	--{ Identificacion del bien inmueble }
    xREF_CATASTRAL			IN VARCHAR2,
    xTIPO_VIA				IN VARCHAR2,
    xNOMBRE_VIA				IN VARCHAR2,
    xNUMERO_VIA				IN VARCHAR2,
    xBLOQUE					IN VARCHAR2,
    xESCALERA				IN VARCHAR2,
    xPLANTA					IN VARCHAR2,
    xPUERTA					IN VARCHAR2,
	xRESTO_DIRECCION		IN VARCHAR2,
    xCOD_POSTAL				IN VARCHAR2,
    xCOD_PROVINCIA_INE		IN VARCHAR2,
    xCOD_MUNICIPIO_INE		IN VARCHAR2,
    xNOMBRE_MUNICIPIO		IN VARCHAR2,
    --{ Identificacion del nuevo titular }
    xNIF_TIT				IN VARCHAR2,
    xNOMBRE_TIT				IN VARCHAR2,
    --{ Domicilio del nuevo titular }
    xTIPO_VIA_TIT			IN VARCHAR2,
	xNOMBRE_VIA_TIT			IN VARCHAR2,
    xNUMERO_VIA_TIT			IN VARCHAR2,
    xBLOQUE_TIT				IN VARCHAR2,
    xESCALERA_TIT			IN VARCHAR2,
    xPLANTA_TIT				IN VARCHAR2,
    xPUERTA_TIT				IN VARCHAR2,
    xRESTO_DIRECCION_TIT	IN VARCHAR2,
    xCOD_POSTAL_TIT			IN VARCHAR2,
    xCOD_PROVI_INE_TIT		IN VARCHAR2,
    xCOD_MUNI_INE_TIT		IN VARCHAR2,
    xNOMBRE_MUNI_TIT		IN VARCHAR2,
    --{ Identificacion del transmitente }
    xNIF_TRAN				IN VARCHAR2,
    xNOMBRE_TRAN			IN VARCHAR2,
    -- { Domicilio del transmitente }
    xTIPO_VIA_TRAN			IN VARCHAR2,
    xNOMBRE_VIA_TRAN		IN VARCHAR2,
    xNUMERO_VIA_TRAN		IN VARCHAR2,
    xBLOQUE_TRAN			IN VARCHAR2,
    xESCALERA_TRAN			IN VARCHAR2,
    xPLANTA_TRAN			IN VARCHAR2,
    xPUERTA_TRAN			IN VARCHAR2,
    xRESTO_DIRECCION_TRAN	IN VARCHAR2,
    xCOD_POSTAL_TRAN		IN VARCHAR2,
    xCOD_PROVI_INE_TRAN		IN VARCHAR2,
    xCOD_MUNI_INE_TRAN		IN VARCHAR2,
    xNOMBRE_MUNI_TRAN		IN VARCHAR2,
	-- {Parametro para indicar si dichos cambios son realizados en los requerimientos
	--  correspondientes si hubieren sido generados ya }
	xCHANGE_REQUE		    IN BOOLEAN	)
AS
    vAYTO             CHAR(3);
	vYEAR			  VARCHAR2(4);
	vPROTOCOLO		  VARCHAR2(10);
	vGENERADO		  VARCHAR2(1);
	vID_NOTARIO		  INTEGER;
	vNOTARIO		  INTEGER;
BEGIN
	-- Modificamos los datos en la tabla NOTARIAS
    UPDATE NOTARIAS_DETALLE SET
    --{ Identificacion del bien inmueble }
    REF_CATASTRAL=xREF_CATASTRAL,
    TIPO_VIA=xTIPO_VIA,
    NOMBRE_VIA=xNOMBRE_VIA,
    NUMERO_VIA=xNUMERO_VIA,
    BLOQUE=xBLOQUE,
    ESCALERA=xESCALERA,
    PLANTA=xPLANTA,
    PUERTA=xPUERTA,
	RESTO_DIRECCION=xRESTO_DIRECCION,
    COD_POSTAL=xCOD_POSTAL,
    COD_PROVINCIA_INE=xCOD_PROVINCIA_INE,
    COD_MUNICIPIO_INE=xCOD_MUNICIPIO_INE,
    NOMBRE_MUNICIPIO=xNOMBRE_MUNICIPIO,
    --{ Identificacion del nuevo titular }
    NIF_TIT=xNIF_TIT,
    NOMBRE_TIT=xNOMBRE_TIT,
    --{ Domicilio del nuevo titular }
    TIPO_VIA_TIT=xTIPO_VIA_TIT,
	NOMBRE_VIA_TIT=xNOMBRE_VIA_TIT,
    NUMERO_VIA_TIT=xNUMERO_VIA_TIT,
    BLOQUE_TIT=xBLOQUE_TIT,
    ESCALERA_TIT=xESCALERA_TIT,
    PLANTA_TIT=xPLANTA_TIT,
    PUERTA_TIT=xPUERTA_TIT,
    RESTO_DIRECCION_TIT=xRESTO_DIRECCION_TIT,
    COD_POSTAL_TIT=xCOD_POSTAL_TIT,
    COD_PROVI_INE_TIT=xCOD_PROVI_INE_TIT,
    COD_MUNI_INE_TIT=xCOD_MUNI_INE_TIT,
    NOMBRE_MUNI_TIT=xNOMBRE_MUNI_TIT,
    --{ Identificacion del transmitente }
    NIF_TRAN=xNIF_TRAN,
    NOMBRE_TRAN=xNOMBRE_TRAN,
    -- { Domicilio del transmitente }
    TIPO_VIA_TRAN=xTIPO_VIA_TRAN,
    NOMBRE_VIA_TRAN=xNOMBRE_VIA_TRAN,
    NUMERO_VIA_TRAN=xNUMERO_VIA_TRAN,
    BLOQUE_TRAN=xBLOQUE_TRAN,
    ESCALERA_TRAN=xESCALERA_TRAN,
    PLANTA_TRAN=xPLANTA_TRAN,
    PUERTA_TRAN=xPUERTA_TRAN,
    RESTO_DIRECCION_TRAN=xRESTO_DIRECCION_TRAN,
    COD_POSTAL_TRAN=xCOD_POSTAL_TRAN,
    COD_PROVI_INE_TRAN=xCOD_PROVI_INE_TRAN,
    COD_MUNI_INE_TRAN=xCOD_MUNI_INE_TRAN,
    NOMBRE_MUNI_TRAN=xNOMBRE_MUNI_TRAN
    WHERE ID=xID
	RETURN COD_MUNICIPIO_INE,IDNOTARIA,YEAR_PROTOCOLO,NUMERO_PROTOCOLO,GENERADO
	  INTO vAYTO,vID_NOTARIO,vYEAR,vPROTOCOLO,vGENERADO;

	IF (xCHANGE_REQUE AND vGENERADO='S') THEN
	   BEGIN
	   	  SELECT N.ID INTO vNOTARIO FROM NOTARIOS N
 	       		    JOIN NOTARIAS N1 ON N.COD_NOTARIO=N1.COD_NOTARIO AND N1.ID=vID_NOTARIO;
	   EXCEPTION
	      WHEN OTHERS THEN
		       NULL;
	   END;

	   UPDATE REQUERIR_PLUSVA SET OBJETO=xREF_CATASTRAL,
	   				   	   	  	  DIRECCION_OBJ=TRIM(xTIPO_VIA)||' '||TRIM(xNOMBRE_VIA)||' '||TRIM(xNUMERO_VIA)||' '||
								  				TRIM(xBLOQUE)||' '||TRIM(xESCALERA)||' '||TRIM(xPLANTA)||' '||TRIM(xPUERTA),
								  DEUDOR=DECODE(CLASE,'O', DECODE(TITULO,'R',xNIF_TIT,xNIF_TRAN),xNIF_TIT),
	   				   	   		  TRANSMITENTE=xNIF_TIT,
						   		  ADQUIRENTE=xNIF_TRAN
		WHERE YEAR=vYEAR AND trim(PROTOCOLO)=TRIM(GETPROTOCOLO(vAYTO,vYEAR,vPROTOCOLO))
			 AND NOTARIO=vNOTARIO;
	END IF;
END MODIFY;

/****************************************************************************************************
AUTOR: Gloria María Calle Hernández. 01/02/2002
FUNCION: xIDREQUERIMIENTO = 0  -> Crea un grupo y pega todos los requerimientos creados a partir del 
		 						FICHERO de Plusvalias en una fecha concreta, para su impresión.
		 xIDREQUERIMIENTO <> 0 -> Solo crea el grupo para un requerimiento
PARAMETROS: xIDREQUERIMIENTO: Id de Requerir_plusva
			xFPLUSVA: Fecha de generacion de los requerimientos a imprimir
			xGRUPO: Parámetro de salida para devolver el grupo creado e imprimirlo
MODIFICACION: 07/09/2006. Lucas Fernández Pérez. Revisión General. 
MODIFICACION: 17/09/2006. Lucas Fernández Pérez. Llama a Proc_tablaReque_Plusva para rellenar la tabla
  temporal con los datos a imprimir
*****************************************************************************************************/
PROCEDURE PRINT (
	 xIDREQUERIMIENTO  IN INTEGER,
	 xFPLUSVA		   IN  DATE,
	 xGRUPO			   OUT INTEGER
) AS
	 CURSOR CAYTOS IS SELECT MUNICIPIO FROM TMP_AYTOS WHERE USUARIO=USER;
BEGIN

	ADD_COD_OPERACION(xGRUPO);

    IF xIDREQUERIMIENTO=0 THEN
    
		FOR vAYTOS IN CAYTOS LOOP
        	UPDATE REQUERIR_PLUSVA SET GRUPO=xGRUPO
		 	WHERE ID IN (SELECT DISTINCT R.ID
			            FROM REQUERIR_PLUSVA R, NOTARIAS_DETALLE P
					   WHERE R.MUNICIPIO=P.COD_MUNICIPIO_INE AND R.MUNICIPIO=vAYTOS.MUNICIPIO
						 AND trunc(R.FECHA)=trunc(P.F_GENERACION) AND trunc(P.F_GENERACION)=trunc(xFPLUSVA));
    	END LOOP;
    	
    ELSE
    
		UPDATE REQUERIR_PLUSVA SET GRUPO=xGRUPO WHERE ID=xIDREQUERIMIENTO;
		
	END IF;
	
	PROC_TABLA_REQUE_PLUSVA(xGRUPO,'N');

END PRINT;


/****************************************************************************************************
AUTOR: Gloria María Calle Hernández. 25/04/2005
FUNCION: Genera Fichero para la AEAT.
*****************************************************************************************************/
PROCEDURE AEAT (
	  xCABECERA			IN CHAR,
	  xPATH				IN CHAR,
	  xNOMBREFILE		IN CHAR,
	  xTIPO				IN CHAR
) AS
   TYPE tCURSOR IS REF CURSOR;  -- define REF CURSOR type
   vCURSOR    	tCURSOR;     -- declare cursor variable
   vSENTENCIA   VARCHAR2(500);
   vNIF        	VARCHAR2(9);
   vNOMBRE		VARCHAR2(62);
   vOutFile UTL_FILE.FILE_TYPE;
BEGIN

   vOutFile:=UTL_FILE.FOPEN(xPATH,xNOMBREFILE,'w');
   UTL_FILE.PUT_LINE(vOutFile,RPAD(xCABECERA,100,' '));

   IF xTIPO='TIT' THEN
     vSENTENCIA:='SELECT NIF_TIT,NOMBRE_TIT FROM NOTARIAS_DETALLE'||
      			 ' WHERE INSTR(MOTIVO,''ADQUIRIENTE'')<>0';
   ELSE
     vSENTENCIA:='SELECT NIF_TRAN,NOMBRE_TRAN FROM NOTARIAS_DETALLE'||
      			 ' WHERE INSTR(MOTIVO,''TRANSMITENTE'')<>0';
   END IF;

   OPEN vCURSOR FOR vSENTENCIA;
   LOOP
     FETCH vCURSOR INTO vNIF,vNOMBRE;
     EXIT WHEN vCURSOR%NOTFOUND;

     UTL_FILE.PUT_LINE(vOutFile,RPAD(SUBSTR(RPAD(TRIM(vNIF),9,'0'),1,9)||TRIM(vNOMBRE),100,' '));
   END LOOP;

   UTL_FILE.FCLOSE(vOutFile);
END AEAT;
	 
	    
END PkPlusvaNotarias;
/
