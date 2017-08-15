CREATE OR REPLACE PACKAGE PkDocdgc
AS
  -- Corrige la tabla IBI_DOCDGC de Alteraciones Repetidas, años de efecto superior al que se liquidadará...
  PROCEDURE IBI_DOCDGC_VALIDAR;

  -- Lee desde oracle cada campo en el fichero DOCDGC y lo inserta en la tabla IBI_DOCDGC
  PROCEDURE IBI_DOCDGC_READ (
		xAyto		IN  VARCHAR2,
		xFileName	IN  VARCHAR2,
		xPath		IN  VARCHAR2,
		xNumReg		OUT	INTEGER,
		xError		OUT	VARCHAR2);

  -- Valida parametros necesarios para calculos en el proceso de generacion de una liquidacion para ayto
  FUNCTION IBI_DOCDGC_VALIDAR_PARAMSAYTO (
		xAYTO				IN	VARCHAR2,
		xINCLUIR_ACTUAL		IN  BOOLEAN,
		xGENERADO			OUT	VARCHAR2,
		xMOTIVO				OUT VARCHAR2,
		xCONCEP				OUT	VARCHAR2,
		xYEARP				OUT	VARCHAR2,
		xNUMYEAR			OUT INTEGER)
  RETURN BOOLEAN;

  -- Procesa cada registro de alta de la tabla de Docdgc
  PROCEDURE IBI_DOCDGC_GENERAR (
    	xALTERACION		IN  VARCHAR2,
		xFLIQUI			IN  DATE,
		xINCLUIR_ACTUAL	IN  BOOLEAN,
	    xNUMLIQUI		OUT INTEGER);

  -- Procesa cada registro de alta en la tabla de DOCDGC siempre q sea para el mismo year_efectos_ibi
  -- Es llamado cuando se trata de impresion de las liquidaciones ya generadas desde el DOCDGC
  PROCEDURE IBI_DOCDGC_IDEMYEAR (
		xFLIQUI		IN  DATE,
		xYEARLIQUI  IN  VARCHAR2,
	    xREG_DOC	IN  IBI_DOCDGC%ROWTYPE);

  -- Función que inserta en una tabla temporal los datos del recibo para los años dentro del intervalo.
  -- Se utilizará en el caso de estar liquidando recibos de I.B.I.
  -- Identico a la funcion rellenar_tmp_atrasos pero tirando de la tabla ibi_docdgc en lugar de ibi
  PROCEDURE IBI_DOCDGC_FILL_TMP_ATRASOS (
  		xYEAR_INICIO  IN    VARCHAR2,
		xYEARLIQUI	  IN	VARCHAR2,
		xYEARP		  IN	VARCHAR2,
		xNUMYEARS	  IN	INTEGER,
		xREG_DOC	  IN	IBI_DOCDGC%ROWTYPE);

  -- Procdimiento q actualiza datos del titular: dni,nombre,direccion fiscal...
  PROCEDURE IBI_DOCDGC_MODIFY (
       xID 					IN INTEGER,
       xNIF 				IN VARCHAR2,
       xNOMBRE 				IN VARCHAR2,
       xVIAF 				IN VARCHAR2,
       xCALLEF 				IN VARCHAR2,
       xNUMEROF 			IN VARCHAR2,
       xLETRAF 				IN VARCHAR2,
       xBLOQUEF				IN VARCHAR2,
       xESCALERAF 			IN VARCHAR2,
       xPLANTAF 			IN VARCHAR2,
       xPISOF 				IN VARCHAR2,
       xCPF 				IN VARCHAR2,
       xPOBLACIONF 			IN VARCHAR2,
       xPROVINCIAF 			IN VARCHAR2,
	   xPAISF 				IN VARCHAR2,
       xVIAT 				IN VARCHAR2,
       xCALLET 				IN VARCHAR2,
       xNUMEROT 			IN VARCHAR2,
       xLETRAT 				IN VARCHAR2,
       xBLOQUET				IN VARCHAR2,
       xESCALERAT 			IN VARCHAR2,
       xPLANTAT 			IN VARCHAR2,
       xPISOT 				IN VARCHAR2,
       xCPT 				IN VARCHAR2,
	   xTIPOALTER			IN VARCHAR2,
	   xTODOS				IN BOOLEAN);

  -- Crea un grupo y pega todas las liquidaciones creadas a partir del DOCDGC en una fecha concreta,
  -- para su impresión.
  PROCEDURE IBI_DOCDGC_PRINT (
   	   xALTERACION		    IN  VARCHAR2,
   	   xF_LIQUIDACION	    IN  DATE,
	   xGRUPO				OUT INTEGER);

  -- Borra todas la liquidaciones para una fecha y un tipo de alteración concreta
  PROCEDURE IBI_DOCDGC_DELETE (
  	   xAYTO			  	IN  VARCHAR2,
   	   xALTERACION	   		IN  VARCHAR2,
	   xF_LIQUIDACION	    IN  DATE,
	   xNUMLIQUI		    OUT INTEGER	);

  --Bonifica y anula bonificacion del registro 
  PROCEDURE IBI_DOCDGC_BONIFI(
       xID 			IN INTEGER,
	   xMESINI		IN CHAR,
       xMES 		IN CHAR,
	   xYEARINI   	IN CHAR,
       xYEAR 		IN CHAR,
       xBONI 		IN FLOAT,
       xARTICULO  	IN CHAR);
END PkDocDgc;
/

/****************************************************************************************************
AUTOR: Gloria María Calle Hernández. 01/02/2002
FUNCION: Procedimientos para el tratamiento de las alteraciones del fichero DOCDGC enviado por Catastro
*****************************************************************************************************/

CREATE OR REPLACE PACKAGE BODY PkDocdgc
AS

/****************************************************************************************************
AUTOR: Gloria María Calle Hernández. 01/02/2002
FUNCION: Lee desde oracle cada campo en el fichero DOCDGC y lo inserta en la tabla IBI_DOCDGC
PARAMETROS: 	xAYTO: Codigo de Ayto
				xFILENAME: Nombre del fichero DOCDGC
				xPATH: Localizacion fisica de dicho fichero
MODIFICADO:	Gloria Maria Calle Hernandez. 26/11/2003
			Numero total de registros devueltos
MODIFICADO:	Gloria Maria Calle Hernandez. 12/01/2004
			No validamos al leer, sino antes de generar
*****************************************************************************************************/
PROCEDURE IBI_DOCDGC_READ (
	xAyto				IN  VARCHAR2,
	xFileName			IN	VARCHAR2,
	xPath				IN	VARCHAR2,
	xNumReg				OUT	INTEGER,
	xError				OUT	VARCHAR2)
AS
  vOutFile 	   				UTL_FILE.FILE_TYPE;
  vReg30	   				VARCHAR2(720);
  vReg50					VARCHAR2(720);
  vID						INTEGER;
  vMUNICIPIO				VARCHAR2(3);
  vTIPO_REGISTRO			VARCHAR2(2);
  /* Identificacion del Inmueble */
  vCOD_DELEGACION_MEH		VARCHAR2(2);
  vCOD_GERENCIA				VARCHAR2(1);
  vCOD_MUNICIPIO			VARCHAR2(3);
  /*DATOS PARA LA REFERENCIA CATASTRAL*/
  vREF_CATASTRAL			VARCHAR2(14);
  vNUMERO_SECUENCIAL		VARCHAR2(4);
  vPRIMER_CARACTER_CONTROL	VARCHAR2(1);
  vSEGUN_CARACTER_CONTROL	VARCHAR2(1);
  vNUM_FIJO					VARCHAR2(8);
  vIDENTIFICACION			VARCHAR2(15);
  vCOEFICIENTE_PARTICI		VARCHAR2(5);
  vCOD_PROVI_INE			VARCHAR2(2);
  vCOD_MUNI_INE				VARCHAR2(3);
  vDISTRITO_MUNI			VARCHAR2(2);
  /* Domicilio Tributario */
  vCOD_ENTIDAD_MENOR		VARCHAR2(2);
  vCOD_VIA_PUBLICA			VARCHAR2(5);
  vTIPO_VIA					VARCHAR2(5);
  vNOMBRE_VIA				VARCHAR2(25);
  vPRIMER_NUMERO			VARCHAR2(4);
  vPRIMERA_LETRA			VARCHAR2(1);
  vSEGUNDO_NUMERO			VARCHAR2(4);
  vSEGUNDA_LETRA			VARCHAR2(1);
  vKILOMETRO				VARCHAR2(5);
  vBLOQUE					VARCHAR2(4);
  vTEXTO_DIRECCION			VARCHAR2(25);
  vCODIGO_POSTAL			VARCHAR2(5);
  vESCALERA					VARCHAR2(2);
  vPLANTA					VARCHAR2(3);
  vPUERTA					VARCHAR2(3);
  /* Identificacion del titular */
  vNIF						VARCHAR2(9);
  vPERSONALIDAD				VARCHAR2(1);
  vNOMBRE					VARCHAR2(60);
  vCOD_DEL_MEH		  		VARCHAR2(2);
  vCOD_MUNICIPIO_DGC		VARCHAR2(3);
  vCOD_PROVI_INE_FISCAL		VARCHAR2(2);
  vCOD_MUNI_INE_FISCAL		VARCHAR2(3);
  vCOD_VIA_PUBLICA_FISCAL	VARCHAR2(5);
  vTIPO_VIA_FISCAL			VARCHAR2(5);
  vNOMBRE_VIA_FISCAL   		VARCHAR2(25);
  vPRIMER_NUMERO_FISCAL		VARCHAR2(4);
  vPRIMERA_LETRA_FISCAL		VARCHAR2(1);
  vSEGUNDO_NUMERO_FISCAL	VARCHAR2(4);
  vSEGUNDA_LETRA_FISCAL		VARCHAR2(1);
  vKILOMETRO_FISCAL    		VARCHAR2(5);
  vBLOQUE_FISCAL			VARCHAR2(4);
  vTEXTO_DIRECCION_FISCAL	VARCHAR2(25);
  vESCALERA_FISCAL			VARCHAR2(2);
  vPLANTA_FISCAL			VARCHAR2(3);
  vPUERTA_FISCAL			VARCHAR2(3);
  vCOD_POSTAL_FISCAL   		VARCHAR2(5);
  vAPARTADO_CORREOS  		VARCHAR2(5);
  vPAIS   					VARCHAR2(25);
  vPROVINCIA		  		VARCHAR2(25);
  vMUNICIPIO_FISCAL  		VARCHAR2(25);
  /* Datos economicos del bien inmueble */
  vYEAR_VALOR_CATASTRAL	  	VARCHAR2(4);
  vVALOR_CATASTRAL			FLOAT;
  vVALOR_SUELO		  		FLOAT;
  vVALOR_CONSTRUCCION  		FLOAT;
  vBASE_LIQUIDABLE			FLOAT;
  vCLAVE_USO				VARCHAR2(1);
  vYEAR_ULTIMA_REVISION		VARCHAR2(4);
  vSUPERFICIE_FINCAS  		FLOAT;
  vSUPERFICIE_SOLARES		FLOAT;
  vCOEFICIENTE_FINCA		FLOAT;
  /* Datos de documento */
  vYEAR_EXPEDIENTE			VARCHAR2(4);
  vREF_EXPEDIENTE			VARCHAR2(13);
  vNUM_DOCUMENTO			VARCHAR2(8);
  vTIPO_EXPEDIENTE			VARCHAR2(4);
  vTIPO_DOCUMENTO			VARCHAR2(4);
  vFECHA_FIRMA				DATE;
  vFECHA_ENTREGA			DATE;
  vEXIS_INFOR_COMPLE		VARCHAR2(1);
  vTIPO_CATASTRO			VARCHAR2(1);
  vYEAR_EFECTOS_IBI			VARCHAR2(4);
  vYEAR_ENTRADA_PADRON		VARCHAR2(4);
  vYEAR_EFECTOS_REVISION	VARCHAR2(4);
  vTIPO_ALTERACION			VARCHAR2(1);
  vCLASE_ALTERACION			VARCHAR2(4);
  vYEAR_EXPEDIENTE_ORIGEN	VARCHAR2(4);
  vREF_EXPEDIENTE_ORIGEN	VARCHAR2(13);
  /* Identificacion del DESTinatario */
  vNIF_DEST					VARCHAR2(9);
  vNOMBRE_DEST				VARCHAR2(60);
  vCOD_DEL_MEH_DEST	  		VARCHAR2(2);
  vCOD_MUNICIPIO_DGC_DEST	VARCHAR2(3);
  vCOD_PROVI_INE_DEST		VARCHAR2(2);
  vCOD_MUNI_INE_DEST		VARCHAR2(3);
  vCOD_VIA_PUBLICA_DEST		VARCHAR2(5);
  vTIPO_VIA_DEST			VARCHAR2(5);
  vNOMBRE_VIA_DEST   		VARCHAR2(25);
  vPRIMER_NUMERO_DEST		VARCHAR2(4);
  vPRIMERA_LETRA_DEST		VARCHAR2(1);
  vSEGUNDO_NUMERO_DEST		VARCHAR2(4);
  vSEGUNDA_LETRA_DEST		VARCHAR2(1);
  vKILOMETRO_DEST    		VARCHAR2(5);
  vBLOQUE_DEST				VARCHAR2(4);
  vTEXTO_DIRECCION_DEST		VARCHAR2(25);
  vESCALERA_DEST			VARCHAR2(2);
  vPLANTA_DEST				VARCHAR2(3);
  vPUERTA_DEST				VARCHAR2(3);
  vCOD_POSTAL_DEST		  	VARCHAR2(5);
  vAPARTADO_CORREOS_DEST  	VARCHAR2(5);
  vPAIS_DEST   				VARCHAR2(25);
  vPROVINCIA_DEST		  	VARCHAR2(25);
  vMUNICIPIO_DEST		  	VARCHAR2(25);

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

	UTL_FILE.GET_LINE(vOutFile,vReg30); --para saltar la línea de cabecera

	LOOP
	BEGIN

	  UTL_FILE.GET_LINE(vOutFile,vReg30);
	  UTL_FILE.GET_LINE(vOutFile,vReg50);

	  WHILE ((SUBSTR(vReg30,1,2)='30') and (SUBSTR(vReg50,1,2)='80')) LOOP

	    UTL_FILE.GET_LINE(vOutFile,vReg30);
	    WHILE (SUBSTR(vReg30,1,2)='81') LOOP
	      UTL_FILE.GET_LINE(vOutFile,vReg30);
	    END LOOP;
	    UTL_FILE.GET_LINE(vOutFile,vReg50);
	  END LOOP;


	  IF ((SUBSTR(vReg30,1,2)='30') and (SUBSTR(vReg50,1,2)='50')) THEN

		vNUM_DOCUMENTO:=SUBSTR(vReg30,20,8);

		BEGIN
		   --Si ha sido ya leída y almacenada dicha alteración catastral no volver a almacenar
		   SELECT ID INTO vID FROM IBI_DOCDGC WHERE NUM_DOCUMENTO=vNUM_DOCUMENTO;
		EXCEPTION
		   WHEN NO_DATA_FOUND THEN
				vMUNICIPIO:=rtrim(xAyto);
			    vTIPO_REGISTRO:=SUBSTR(vReg30,1,2);
			    vCOD_DELEGACION_MEH:=SUBSTR(vReg50,3,2);
			    vCOD_GERENCIA:=SUBSTR(vReg50,5,1);
			    vCOD_MUNICIPIO:=SUBSTR(vReg50,6,3);
			    vREF_CATASTRAL:=SUBSTR(vReg50,9,14);
			    vNUMERO_SECUENCIAL:=SUBSTR(vReg50,23,4);
			    vPRIMER_CARACTER_CONTROL:=SUBSTR(vReg50,27,1);
			    vSEGUN_CARACTER_CONTROL:=SUBSTR(vReg50,28,1);
			    vNUM_FIJO:=SUBSTR(vReg50,29,8);
			    vIDENTIFICACION:=SUBSTR(vReg50,38,15);
			    vCOEFICIENTE_PARTICI:=SUBSTR(vReg50,53,5);
			    vCOD_PROVI_INE:=SUBSTR(vReg50,58,2);
			    vCOD_MUNI_INE:=SUBSTR(vReg50,60,3);
			    vDISTRITO_MUNI:=SUBSTR(vReg50,63,2);

			    --{ Domicilio Tributario }
			    vCOD_ENTIDAD_MENOR:=SUBSTR(vReg50,65,2);
			    vCOD_VIA_PUBLICA:=SUBSTR(vReg50,67,5);
			    vTIPO_VIA:=SUBSTR(vReg50,72,5);
			    vNOMBRE_VIA:=SUBSTR(vReg50,77,25);
			    vPRIMER_NUMERO:=SUBSTR(vReg50,102,4);
			    vPRIMERA_LETRA:=SUBSTR(vReg50,106,1);
			    vSEGUNDO_NUMERO:=SUBSTR(vReg50,107,4);
			    vSEGUNDA_LETRA:=SUBSTR(vReg50,111,1);
			    vKILOMETRO:=SUBSTR(vReg50,112,5);
			    vBLOQUE:=SUBSTR(vReg50,117,4);
			    vTEXTO_DIRECCION:=SUBSTR(vReg50,121,25);
			    vCODIGO_POSTAL:=SUBSTR(vReg50,146,5);
			    vESCALERA:=SUBSTR(vReg50,151,2);
			    vPLANTA:=SUBSTR(vReg50,153,3);
			    vPUERTA:=SUBSTR(vReg50,156,3);

			    --{ Identificacion del titular }
			    vNIF:=SUBSTR(vReg50,159,9);
			    vPERSONALIDAD:=SUBSTR(vReg50,168,1);
			    vNOMBRE:=SUBSTR(vReg50,169,60);
			    --{ Domicilio titular }
			    vCOD_DEL_MEH:=SUBSTR(vReg50,229,2);
			    vCOD_MUNICIPIO_DGC:=SUBSTR(vReg50,231,3);
			    vCOD_PROVI_INE_FISCAL:=SUBSTR(vReg50,234,2);
			    vCOD_MUNI_INE_FISCAL:=SUBSTR(vReg50,236,3);
			    vCOD_VIA_PUBLICA_FISCAL:=SUBSTR(vReg50,239,5);
			    vTIPO_VIA_FISCAL:=SUBSTR(vReg50,244,5);
			    vNOMBRE_VIA_FISCAL:=SUBSTR(vReg50,249,25);
			    vPRIMER_NUMERO_FISCAL:=SUBSTR(vReg50,274,4);
			    vPRIMERA_LETRA_FISCAL:=SUBSTR(vReg50,278,1);
			    vSEGUNDO_NUMERO_FISCAL:=SUBSTR(vReg50,279,4);
			    vSEGUNDA_LETRA_FISCAL:=SUBSTR(vReg50,283,1);
			    vKILOMETRO_FISCAL:=SUBSTR(vReg50,284,5);
			    vBLOQUE_FISCAL:=SUBSTR(vReg50,289,4);
			    vTEXTO_DIRECCION_FISCAL:=SUBSTR(vReg50,293,25);
			    vESCALERA_FISCAL:=SUBSTR(vReg50,318,2);
			    vPLANTA_FISCAL:=SUBSTR(vReg50,320,3);
			    vPUERTA_FISCAL:=SUBSTR(vReg50,323,3);
			    vCOD_POSTAL_FISCAL:=SUBSTR(vReg50,326,5);
			    vAPARTADO_CORREOS:=SUBSTR(vReg50,331,5);
			    vPAIS:=SUBSTR(vReg50,336,25);
			    vPROVINCIA:=SUBSTR(vReg50,361,25);
			    vMUNICIPIO_FISCAL:=SUBSTR(vReg50,386,25);

			    --{ Datos economicos del bien inmueble }
			    vYEAR_VALOR_CATASTRAL:=SUBSTR(vReg50,411,4);
			    --En Euros se trabaja en centimos para los intercambios de datos
				vVALOR_CATASTRAL:=TO_NUMBER(SUBSTR(vReg50,415,12))/100;
			    vVALOR_SUELO:=TO_NUMBER(SUBSTR(vReg50,427,12))/100;
			    vVALOR_CONSTRUCCION:=TO_NUMBER(SUBSTR(vReg50,439,12))/100;
			    vBASE_LIQUIDABLE:=TO_NUMBER(SUBSTR(vReg50,451,12))/100;
			    vCLAVE_USO:=SUBSTR(vReg50,463,1);
			    vYEAR_ULTIMA_REVISION:=SUBSTR(vReg50,464,4);
			    vSUPERFICIE_FINCAS:=TO_NUMBER(SUBSTR(vReg50,478,7));
			    vSUPERFICIE_SOLARES:=TO_NUMBER(SUBSTR(vReg50,485,7));
			    vCOEFICIENTE_FINCA:=TO_NUMBER(SUBSTR(vReg50,492,7));

			    --{ Datos de movimiento }
			    vYEAR_EXPEDIENTE:=SUBSTR(vReg30,3,4);
			    vREF_EXPEDIENTE:=SUBSTR(vReg30,7,13);
			    --vNUM_DOCUMENTO:=SUBSTR(vReg30,20,8); Leído al principio para comprobar si ya está cargado
			    vTIPO_EXPEDIENTE:=SUBSTR(vReg30,28,4);
			    vTIPO_DOCUMENTO:=SUBSTR(vReg30,32,4);
				IF SUBSTR(vReg30,36,8)='00000000' THEN
				  vFECHA_FIRMA:=NULL;
				ELSE vFECHA_FIRMA:=TO_DATE(SUBSTR(vReg30,36,8),'YYYYMMDD');
				END IF;
				IF SUBSTR(vReg30,44,8)='00000000' THEN
				  vFECHA_ENTREGA:=NULL;
				ELSE vFECHA_ENTREGA:=TO_DATE(SUBSTR(vReg30,44,8),'YYYYMMDD');
				END IF;
			    vEXIS_INFOR_COMPLE:=SUBSTR(vReg30,52,1);
			    vTIPO_CATASTRO:=SUBSTR(vReg30,53,1);
			    vYEAR_EFECTOS_IBI:=SUBSTR(vReg30,54,4);
			    vYEAR_ENTRADA_PADRON:=SUBSTR(vReg30,58,4);
			    vYEAR_EFECTOS_REVISION:=SUBSTR(vReg30,62,4);
			    vTIPO_ALTERACION:=SUBSTR(vReg30,66,1);
			    vCLASE_ALTERACION:=SUBSTR(vReg30,67,4);
			    vYEAR_EXPEDIENTE_ORIGEN:=SUBSTR(vReg30,71,4);
			    vREF_EXPEDIENTE_ORIGEN:=SUBSTR(vReg30,75,13);

			    --{ Identificacion del destinatario }
			    vNIF_DEST:=SUBSTR(vReg30,88,9);
			    vNOMBRE_DEST:=SUBSTR(vReg30,97,60);
			    --{ Domicilio titular }
			    vCOD_DEL_MEH_DEST:=SUBSTR(vReg30,157,2);
			    vCOD_MUNICIPIO_DGC_DEST:=SUBSTR(vReg30,159,3);
			    vCOD_PROVI_INE_DEST:=SUBSTR(vReg30,162,2);
			    vCOD_MUNI_INE_DEST:=SUBSTR(vReg30,164,3);
			    vCOD_VIA_PUBLICA_DEST:=SUBSTR(vReg30,167,5);
			    vTIPO_VIA_DEST:=SUBSTR(vReg30,172,5);
			    vNOMBRE_VIA_DEST:=SUBSTR(vReg30,177,25);
			    vPRIMER_NUMERO_DEST:=SUBSTR(vReg30,202,4);
			    vPRIMERA_LETRA_DEST:=SUBSTR(vReg30,206,1);
			    vSEGUNDO_NUMERO_DEST:=SUBSTR(vReg30,207,4);
			    vSEGUNDA_LETRA_DEST:=SUBSTR(vReg30,211,1);
			    vKILOMETRO_DEST:=SUBSTR(vReg30,212,5);
			    vBLOQUE_DEST:=SUBSTR(vReg30,217,4);
			    vTEXTO_DIRECCION_DEST:=SUBSTR(vReg30,221,25);
			    vESCALERA_DEST:=SUBSTR(vReg30,246,2);
			    vPLANTA_DEST:=SUBSTR(vReg30,248,3);
			    vPUERTA_DEST:=SUBSTR(vReg30,251,3);
			    vCOD_POSTAL_DEST:=SUBSTR(vReg30,254,5);
			    vAPARTADO_CORREOS_DEST:=SUBSTR(vReg30,259,5);
			    vPAIS_DEST:=SUBSTR(vReg30,264,25);
			    vPROVINCIA_DEST:=SUBSTR(vReg30,289,25);
			    vMUNICIPIO_DEST:=SUBSTR(vReg30,314,25);

				INSERT INTO IBI_DOCDGC (
					MUNICIPIO,TIPO_REGISTRO,COD_DELEGACION_MEH,COD_GERENCIA,COD_MUNICIPIO,REF_CATASTRAL,
					NUMERO_SECUENCIAL,PRIMER_CARACTER_CONTROL,SEGUN_CARACTER_CONTROL,NUM_FIJO,IDENTIFICACION,
					COEFICIENTE_PARTICI,COD_PROVI_INE,COD_MUNI_INE,DISTRITO_MUNI,
					/* Domicilio Tributario */
					COD_ENTIDAD_MENOR,COD_VIA_PUBLICA,TIPO_VIA,NOMBRE_VIA,PRIMER_NUMERO,PRIMERA_LETRA,SEGUNDO_NUMERO,
					SEGUNDA_LETRA,KILOMETRO,BLOQUE,TEXTO_DIRECCION,CODIGO_POSTAL,ESCALERA,PLANTA,PUERTA,
					/* Identificacion del titular */
					NIF,PERSONALIDAD,NOMBRE,
					/* Domicilio titular */
					COD_DEL_MEH,COD_MUNICIPIO_DGC,COD_PROVI_INE_FISCAL,COD_MUNI_INE_FISCAL,COD_VIA_PUBLICA_FISCAL,
					TIPO_VIA_FISCAL,NOMBRE_VIA_FISCAL,PRIMER_NUMERO_FISCAL,PRIMERA_LETRA_FISCAL,SEGUNDO_NUMERO_FISCAL,
					SEGUNDA_LETRA_FISCAL,KILOMETRO_FISCAL,BLOQUE_FISCAL,TEXTO_DIRECCION_FISCAL,ESCALERA_FISCAL,PLANTA_FISCAL,
					PUERTA_FISCAL,COD_POSTAL_FISCAL,APARTADO_CORREOS,PAIS,PROVINCIA,MUNICIPIO_FISCAL,
					/* Datos economicos del bien inmueble */
					YEAR_VALOR_CATASTRAL,VALOR_CATASTRAL,VALOR_SUELO,VALOR_CONSTRUCCION,BASE_LIQUIDABLE,CLAVE_USO,
					YEAR_ULTIMA_REVISION,SUPERFICIE_FINCAS,SUPERFICIE_SOLARES,COEFICIENTE_FINCA,
					/* Datos de documento */
					YEAR_EXPEDIENTE,REF_EXPEDIENTE,NUM_DOCUMENTO,TIPO_EXPEDIENTE,TIPO_DOCUMENTO,FECHA_FIRMA,FECHA_ENTREGA,
					EXIS_INFOR_COMPLE,TIPO_CATASTRO,YEAR_EFECTOS_IBI,YEAR_ENTRADA_PADRON,YEAR_EFECTOS_REVISION,TIPO_ALTERACION,
					CLASE_ALTERACION,YEAR_EXPEDIENTE_ORIGEN,REF_EXPEDIENTE_ORIGEN,
					/* Identificacion del titular */
					NIF_DEST,NOMBRE_DEST,COD_DEL_MEH_DEST,COD_MUNICIPIO_DGC_DEST,COD_PROVI_INE_DEST,COD_MUNI_INE_DEST,
					COD_VIA_PUBLICA_DEST,TIPO_VIA_DEST,NOMBRE_VIA_DEST,PRIMER_NUMERO_DEST,PRIMERA_LETRA_DEST,
					SEGUNDO_NUMERO_DEST,SEGUNDA_LETRA_DEST,KILOMETRO_DEST,BLOQUE_DEST,TEXTO_DIRECCION_DEST,ESCALERA_DEST,
					PLANTA_DEST,PUERTA_DEST,COD_POSTAL_DEST,APARTADO_CORREOS_DEST,PAIS_DEST,PROVINCIA_DEST,MUNICIPIO_DEST)
			  	VALUES (
					vMUNICIPIO,vTIPO_REGISTRO,vCOD_DELEGACION_MEH,vCOD_GERENCIA,vCOD_MUNICIPIO,vREF_CATASTRAL,
					vNUMERO_SECUENCIAL,vPRIMER_CARACTER_CONTROL,vSEGUN_CARACTER_CONTROL,vNUM_FIJO,vIDENTIFICACION,
					vCOEFICIENTE_PARTICI,vCOD_PROVI_INE,vCOD_MUNI_INE,vDISTRITO_MUNI,
					/* Domicilio Tributario */
					vCOD_ENTIDAD_MENOR,vCOD_VIA_PUBLICA,vTIPO_VIA,vNOMBRE_VIA,vPRIMER_NUMERO,vPRIMERA_LETRA,vSEGUNDO_NUMERO,
					vSEGUNDA_LETRA,vKILOMETRO,vBLOQUE,vTEXTO_DIRECCION,vCODIGO_POSTAL,vESCALERA,vPLANTA,vPUERTA,
					/* Identificacion del titular */
					vNIF,vPERSONALIDAD,vNOMBRE,
					/* Domicilio titular */
					vCOD_DEL_MEH,vCOD_MUNICIPIO_DGC,vCOD_PROVI_INE_FISCAL,vCOD_MUNI_INE_FISCAL,vCOD_VIA_PUBLICA_FISCAl,
					vTIPO_VIA_FISCAL,vNOMBRE_VIA_FISCAL,vPRIMER_NUMERO_FISCAL,vPRIMERA_LETRA_FISCAL,vSEGUNDO_NUMERO_FISCAL,
					vSEGUNDA_LETRA_FISCAL,vKILOMETRO_FISCAL,vBLOQUE_FISCAL,vTEXTO_DIRECCION_FISCAL,vESCALERA_FISCAL,vPLANTA_FISCAL,
					vPUERTA_FISCAL,vCOD_POSTAL_FISCAL,vAPARTADO_CORREOS,vPAIS,vPROVINCIA,vMUNICIPIO_FISCAL,
					/* Datos economicos del bien inmueble */
					vYEAR_VALOR_CATASTRAL,vVALOR_CATASTRAL,vVALOR_SUELO,vVALOR_CONSTRUCCION,vBASE_LIQUIDABLE,vCLAVE_USO,
					vYEAR_ULTIMA_REVISION,vSUPERFICIE_FINCAS,vSUPERFICIE_SOLARES,vCOEFICIENTE_FINCA,
					/* Datos de documento */
					vYEAR_EXPEDIENTE,vREF_EXPEDIENTE,vNUM_DOCUMENTO,vTIPO_EXPEDIENTE,vTIPO_DOCUMENTO,vFECHA_FIRMA,vFECHA_ENTREGA,
					vEXIS_INFOR_COMPLE,vTIPO_CATASTRO,vYEAR_EFECTOS_IBI,vYEAR_ENTRADA_PADRON,vYEAR_EFECTOS_REVISION,vTIPO_ALTERACION,
					vCLASE_ALTERACION,vYEAR_EXPEDIENTE_ORIGEN,vREF_EXPEDIENTE_ORIGEN,
					/* Identificacion del destinatario */
					vNIF_DEST,vNOMBRE_DEST,vCOD_DEL_MEH_DEST,vCOD_MUNICIPIO_DGC_DEST,vCOD_PROVI_INE_DEST,vCOD_MUNI_INE_DEST,
					vCOD_VIA_PUBLICA_DEST,vTIPO_VIA_DEST,vNOMBRE_VIA_DEST,vPRIMER_NUMERO_DEST,vPRIMERA_LETRA_DEST,
					vSEGUNDO_NUMERO_DEST,vSEGUNDA_LETRA_DEST,vKILOMETRO_DEST,vBLOQUE_DEST,vTEXTO_DIRECCION_DEST,vESCALERA_DEST,
					vPLANTA_DEST,vPUERTA_DEST,vCOD_POSTAL_DEST,vAPARTADO_CORREOS_DEST,vPAIS_DEST,vPROVINCIA_DEST,vMUNICIPIO_DEST);

				xNumReg:=xNumReg+1;
		END;
	  END IF;

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

END IBI_DOCDGC_READ;



/****************************************************************************************************
AUTOR: Gloria María Calle Hernández. 01/02/2002
FUNCION: La tabla puede contener registros repetidos, por lo cual pondremos GENERADO='E',
 		 Motivo='ALTERACION REPETIDA' y F_GENERACION a la actual, siempre de aquel registro
		 cuya fecha_firma sea primera, pues suponemos q una fecha posterior mantendrá
		 los primero y ultimos cambios, será posterior al primer cambio.
		 La tabla puede contener alteraciones para años posterior al que queremos liquidar, cuyos registros
		 actualizaremos como GENERADO='E',Motivo='AÑO EFECTO MAYOR AL DE LIQUIDACIÓN',F_GENERACION actual.
MODIFICADO: Gloria Maria Calle Hernandez. 12/01/2004
			Hasta ahora se validaban comparando con el año actual y las erróneas no se volvían a validar;
			cambiado para q valide comparando con año a liquidar pasado como parámetro y validando
			también las erróneas de años superiores, posibilitando su liquidación posterior.
MODIFICADO: Gloria Maria Calle Hernandez. 23/12/2004.
			Comprobociones: si YEAR_EFECTOS_IBI > YEAR_ENTRADA_PADRON -> ERROR
				 		 	si YEAR_EFECTOS_IBI > ACTUAL -> ERROR
			Cambiado comprobación de repetidos para minimizar el tiempo de respuesta
*****************************************************************************************************/
PROCEDURE IBI_DOCDGC_VALIDAR
AS
  	vYEARACTUAL			VARCHAR2(4);
	vREF_CATASTRAL		VARCHAR2(20);

    CURSOR cREG_REPETIDOS IS SELECT distinct I1.ref_catastral||I1.numero_secuencial||I1.primer_caracter_control||I1.segun_caracter_control as REF_CATASTRAL,
		   				  	 		I1.GENERADO,I1.ID,I1.FECHA_FIRMA
		   	   			  	   FROM IBI_DOCDGC I1 JOIN IBI_DOCDGC I2
	       					     ON I1.MUNICIPIO=I2.MUNICIPIO
								AND I1.REF_CATASTRAL||I1.NUMERO_SECUENCIAL||I1.PRIMER_CARACTER_CONTROL||I1.SEGUN_CARACTER_CONTROL=I2.REF_CATASTRAL||I2.NUMERO_SECUENCIAL||I2.PRIMER_CARACTER_CONTROL||I2.SEGUN_CARACTER_CONTROL
 						 	  WHERE I1.GENERADO NOT IN ('E','S') AND I2.GENERADO NOT IN ('E','S')
 						 	    AND I1.ID<>I2.ID AND I1.YEAR_EFECTOS_IBI=I2.YEAR_EFECTOS_IBI
							  ORDER BY I1.REF_CATASTRAL||I1.NUMERO_SECUENCIAL||I1.PRIMER_CARACTER_CONTROL||I1.SEGUN_CARACTER_CONTROL,
							  		   I1.GENERADO DESC,I1.FECHA_FIRMA DESC;

	CURSOR cIDs_YEARMAYOR IS SELECT ID,GENERADO,YEAR_EFECTOS_IBI,YEAR_ENTRADA_PADRON FROM IBI_DOCDGC
		   				 	  WHERE GENERADO<>'S';

BEGIN

	vYEARACTUAL:=TO_CHAR(SYSDATE,'YYYY');

	--Validamos q YEAR_EFECTOS_IBI sea igual o inferior YEAR_ENTRADA_PADRON y YEAR_EFECTOS_IBI sea menor o igual al año actual
	FOR vIDs_YEARMAYOR IN cIDs_YEARMAYOR
	LOOP
		IF vIDs_YEARMAYOR.YEAR_EFECTOS_IBI>vIDs_YEARMAYOR.YEAR_ENTRADA_PADRON THEN
	       UPDATE IBI_DOCDGC SET GENERADO='E',MOTIVO='AÑO DE EFECTOS SUPERIOR AL AÑO DE ENTRADA EN PADRON.',
		   		  			 	 F_GENERACION=TRUNC(SYSDATE,'DD')
	       WHERE ID=vIDs_YEARMAYOR.ID;
	    ELSIF vIDs_YEARMAYOR.YEAR_EFECTOS_IBI>vYEARACTUAL THEN
	       UPDATE IBI_DOCDGC SET GENERADO='E',MOTIVO='AÑO EFECTOS SUPERIOR AL AÑO ACTUAL. NO ES POSIBLE GENERAR.',
		   		  			 	 F_GENERACION=TRUNC(SYSDATE,'DD')
	       WHERE ID=vIDs_YEARMAYOR.ID;
	    ELSIF vIDs_YEARMAYOR.GENERADO='E' THEN
	       UPDATE IBI_DOCDGC SET GENERADO='N',MOTIVO=NULL,F_GENERACION=NULL
	       WHERE ID=vIDs_YEARMAYOR.ID;
	    END IF;
	END LOOP;

	vREF_CATASTRAL:= '00000000000000000000';
	--Validamos q no haya registros repetidos para el mismo bien inmueble...
	FOR vREG_REPETIDOS IN cREG_REPETIDOS
	LOOP
		IF (vREF_CATASTRAL<>vREG_REPETIDOS.REF_CATASTRAL) THEN
		    vREF_CATASTRAL:= vREG_REPETIDOS.REF_CATASTRAL;
 	        UPDATE IBI_DOCDGC SET GENERADO='N',MOTIVO=NULL,F_GENERACION=NULL
	         WHERE ID=vREG_REPETIDOS.ID;
		ELSE
		    UPDATE IBI_DOCDGC SET GENERADO='E',MOTIVO='ALTERACIÓN REPETIDA',F_GENERACION=TRUNC(SYSDATE,'DD')
			 WHERE ID=vREG_REPETIDOS.ID;
		END IF;
	END LOOP;

END IBI_DOCDGC_VALIDAR;


/****************************************************************************************************
AUTOR: Gloria María Calle Hernández. 01/02/2002
FUNCION: Valida los parametros necesarios para los calculos en el proceso de generacion
		 de una liquidacion para un ayto
PARAMETROS: 	xAYTO: ENTRADA: Codigo de Ayto
				xGENERADO: SALIDA: Nombre del fichero DOCDGC
				xMOTIVO: SALIDA: Localizacion fisica de dicho fichero
				xCONCEP: SALIDA: Código de concepto
				xYEARP: SALIDA: Año de ultima ponencia
				xNUMYEAR: SALIDA: Rango de años para cada revisión catastral
MODIFICADO: 23/12/04. Gloria Maria Calle Hernandez.
			El año hasta el cual se liquida es el YEAR_ENTRADA_PADRON-1 o YEAR_ENTRADA_PADRON. Se introduce por pantalla.
			Entonces se comprueban 5 o 4 años atrás realmente.
			Cuatro años atrás contanto el actual o sin contarlo. Se introduce por pantalla.
			Parametro: xINCLUIR_ACTUAL
*****************************************************************************************************/
FUNCTION IBI_DOCDGC_VALIDAR_PARAMSAYTO (
		xAYTO				IN	VARCHAR2,
		xINCLUIR_ACTUAL		IN  BOOLEAN,
		xGENERADO			OUT	VARCHAR2,
		xMOTIVO				OUT VARCHAR2,
		xCONCEP				OUT	VARCHAR2,
		xYEARP				OUT	VARCHAR2,
		xNUMYEAR			OUT INTEGER)
RETURN BOOLEAN
AS
	   vNUM_YEAR_ATRAS			INTEGER;
	   vLISTA					VARCHAR2(50)	DEFAULT NULL;
BEGIN
   	BEGIN
    	SELECT LIQUIDACION INTO xCONCEP FROM PROGRAMAS WHERE PROGRAMA='IBI';
    EXCEPTION
		WHEN NO_DATA_FOUND THEN
		     xGENERADO:= 'E';
			 xMOTIVO:= 'NO ESTA DEFINIDO EL CONCEPTO PARA IBI EN EL AYTO '||xAYTO;
			 RETURN FALSE;
    END;

   	BEGIN
		SELECT YEAR_LAST_PONENCIA,YEARS_PRORRATEO INTO xYEARP,xNUMYEAR FROM DATOSPER
		WHERE MUNICIPIO=xAYTO;
	EXCEPTION
		WHEN NO_DATA_FOUND THEN
		     xGENERADO:= 'E';
			 xMOTIVO:= 'DEBE INDICAR EL AÑO DE LA ULTIMA PONENCIA DE VALORES PARA EL AYTO '||xAYTO;
			 RETURN FALSE;
	END;

	IF xINCLUIR_ACTUAL THEN vNUM_YEAR_ATRAS:=3;
	ELSE vNUM_YEAR_ATRAS:=4;
	END IF;
	-- Si existe gravamen para cada año de liquidacion
	--Maximo año liquidable atrás en el tiempo = año actual - vNum_Year_Atras, es decir, 4 años atrás
	FOR vYEARS IN (SELECT DISTINCT YEAR_EFECTOS_IBI FROM IBI_DOCDGC
       			   WHERE MUNICIPIO=xAYTO AND TIPO_ALTERACION='A'
				     AND YEAR_EFECTOS_IBI BETWEEN TO_CHAR(SYSDATE,'YYYY')-vNUM_YEAR_ATRAS AND TO_CHAR(SYSDATE,'YYYY')
				     AND YEAR_EFECTOS_IBI NOT IN (SELECT distinct YEAR FROM GRAVAMEN_IBI_RUS
       											   WHERE MUNICIPIO=xAYTO AND MODULO='IBI')) LOOP
		vLISTA:= vLISTA||' '||vYEARS.YEAR_EFECTOS_IBI;
	END LOOP;
	IF vLISTA IS NOT NULL THEN
	   xGENERADO:= 'E';
	   xMOTIVO:= 'PARA LOS AÑOS '||vLISTA||' NO SE HA ESPECIFICADO GRAVAMEN NI % DE '||
	   			 'INCREMENTO PARA EL AYTO '||xAYTO;
	   RETURN FALSE;
	END IF;

	-- Si toda toda comprobacion es correcta
	RETURN TRUE;
END IBI_DOCDGC_VALIDAR_PARAMSAYTO;



/****************************************************************************************************
AUTOR: Gloria María Calle Hernández. 01/02/2002
FUNCION: Segun el parámetro xINSERTA bien procesa cada registro de la tabla IBI_DocDgc
		 segun tipo_alteracion especificada, o bien rellena tabla de impresión
PARAMETROS: 	xALTERACION: Tipo_alteracion que se quiere aplicar. Si su valor es 'T' se aplicarán todas.
				xFLIQUI: Fecha en que se aplicarán dichas alteraciones
				xYEARLIQUI: Año a liquidar
				xINSERTA: Determina si se generarán alteraciones o se prepará tabla para impresión
MODIFICADO: Gloria Maria Calle Hernandez
			Al año a liquidar se comparaba con el año actual, ahora se envía como parámetro
MODIFICADO: 24/03/2004. Gloria Maria Calle Hernandez
			Al montar el Objeto_tributario solo incluir los años entre el año de efectos ibi y el año
			hasta el cual liquidamos. Los anteriores si existen sólo son usados para realizar calculos.
			Cambiar la impresión del Objeto_tributario, para escribir cada año en una misma linea.
MODIFICADO: 17/05/04. Gloria Maria Calle Hernandez. Cambiado MAX_VALOR_CATASTRAL por MAX_CUOTA.
MODIFICADO: 23/12/04. Gloria Maria Calle Hernandez.
			El año hasta el cual se liquida es el YEAR_ENTRADA_PADRON-1 o YEAR_ENTRADA_PADRON. Se introduce por pantalla.
			Cuatro años atrás contanto el actual o sin contarlo. Se introduce por pantalla.
			Parametro: xINCLUIR_ACTUAL
MODIFICADO: 21/01/2005. Gloria MAria Calle Hernandez. Compensado no toda la cantidad ingresada en recaudación, sino
			el importe de lo liquidado, esté o no ingresado y sólo correspondiente al principal.
			Por otro lado, si lo que hay que restar es menor que lo que el total de la liquidacion a crear,
			entonces no se creará liquidación y se quedará reflejado como 'E', 'CONCEPTO Y AÑO LIQUIDADO EN RECAUDACION'
MODIFICADO: 16/02/2005. Gloria Maria Calle Hernandez. Para compensar lo liquidado mirar no sólo por ref. catastral
			sino también por NIF. (No es justo compensar a una persona lo que otra ha pagado).
MODIFICADO: 18/03/2005. Gloria Maria Calle Hernandez. Nunca liquidar el YEAR_ENTRADA_PADRON a menos que sea igual que el
			YEAR_EFECTOS_IBI, en cuyo caso, si parametro de entrado xINCLUIR_ACTUAL es True se liquidará, pues en el caso
			de Torrejon notifica el Ayuntamiento con primer cobro como liquidación, el recibo si viene se bonificará según
			artículo de la ley tributaria y si es False no se liquidará, se cobrará	el recibo correspondiente, pues en Catoure,
			por ejemplo, notifica catastro. En el caso de haber geneado ya el padron nunca se liquidarán dichos casos.
MODIFICACIÓN: 25/05/2006. Lucas Fernández Pérez. Adaptación al nuevo formato de RUSTICA, se elimina en la llamada 
			a ADD_LIQUI los parámetros XPARCELA y XCODPOLIGONO, a los que se llamaba con valores null.
MODIFICADO: 09/06/2006. Lucas Fernández Pérez. Si la bonificacion es del 0% no se mete en objeto_tributario
	(por problemas de espacio, que es reducido en los preimpresos)
MODIFICADO: 10/10/2006 Lucas Fernández. La busqueda de valores estaba mal (ponía muchas comas simples).
		Además se comentan unas lineas del objeto tributario a petición de Catoure
MODIFICADO: 05/02/2007. Lucas Fernández Pérez. Cambia la llamada de InsertaModiContribuyente a Ins_Upd_Contri
*****************************************************************************************************/
PROCEDURE IBI_DOCDGC_GENERAR (
    xALTERACION			IN  VARCHAR2,
	xFLIQUI				IN  DATE,
	xINCLUIR_ACTUAL		IN  BOOLEAN,
	xNUMLIQUI			OUT INTEGER)
AS
	vMUNI					CHAR(3);
	vDOMI_FISCAL			VARCHAR2(60);
	vDOMI_TRIBUTARIO		VARCHAR2(60);
	vOBJ_TRIBU				VARCHAR2(1024);
	vSALTO					CHAR(2);
	vFINPEVOL				DATE;
	vCONTADOR				INTEGER;
	vGRAVAMEN 				FLOAT;
	vNUM_PER          		INTEGER;
	vBASE_IMPONIBLE   		FLOAT;
	vBONIFICACION			FLOAT;
	vDMUNI					VARCHAR2(50);
	vREFERENCIA				CHAR(10);
	vDIGITO_C60_MODALIDAD2	CHAR(2);
	vTRIBUTO				CHAR(3);
	vIMP_CADENA				CHAR(12);
	vEMISOR					CHAR(6);
	vDISCRI_PERIODO			CHAR(1);
	vDIGITO_YEAR			CHAR(1);
	vEJER_C60				CHAR(2);
	vF_JULIANA				CHAR(3);
	vDIAS					INTEGER;
	vYEARP					CHAR(4);
	vNUMYEARS				INTEGER;
	vCONCEP					CHAR(6);
	vREF_CATASTRAL			VARCHAR2(20);
	vGENERADO				VARCHAR2(1);
	vMOTIVO					VARCHAR2(100);
	vCOUNT					INTEGER;
	vINGRESADO				FLOAT;
	vTOTAL					FLOAT;
	vNUMERO_LIQUI			CHAR(7);
	vID_LIQUI				INTEGER;
	vLISTA_ALTERACIONES		VARCHAR2(20);
	vYEAR_EFECTOS			VARCHAR2(4); --Almacena YEAR_EFECTOS_IBI nunca menor q cuatro años atrás en el tiempo
	vYEAR_ENTRADA			VARCHAR2(4); --Almacena YEAR_ENTRADA_PADRON-1 si YEAR_EFECTOS_IBI<YEAR_ENTRADA_PADRON y
										 -- YEAR_ENTRADA_PADRON si YEAR_EFECTOS_IBI=YEAR_ENTRADA_PADRON

	CURSOR CAYTOS IS SELECT MUNICIPIO FROM TMP_AYTOS WHERE USUARIO=USER;

	CURSOR cLIQUIDOC IS SELECT * FROM IBI_DOCDGC
						WHERE MUNICIPIO=vMUNI AND TIPO_ALTERACION IN (vLISTA_ALTERACIONES) AND GENERADO='N'
	FOR UPDATE;

BEGIN

	IBI_DOCDGC_VALIDAR;

    xNUMLIQUI:=0;

	IF (RTRIM(xALTERACION)='T') THEN
	    vLISTA_ALTERACIONES:='A'',''B'',''M';
	ELSE
		vLISTA_ALTERACIONES:=RTRIM(xALTERACION);
	END IF;

	-- Cursor de ayuntamientos
	FOR vAYTOS IN CAYTOS
	LOOP
        vMUNI:=vAYTOS.MUNICIPIO;

	   /* Comprobamos los parámetros para cada ayuntamiento */
	    IF IBI_DOCDGC_VALIDAR_PARAMSAYTO(vMUNI,xINCLUIR_ACTUAL,vGENERADO,vMOTIVO,vCONCEP,vYEARP,vNUMYEARS) THEN

		  -- Cursor sobre los registros de la tabla IBI_DOCDGC
		  FOR vLIQUIDOC IN cLIQUIDOC LOOP

			-- Comprobamos q el Año de Efectos no sea inferior a cuatro años atrás
   			-- número máximo de años a liquidar atrás en el tiempo legalmente
   			IF vLIQUIDOC.YEAR_EFECTOS_IBI<(TO_CHAR(SYSDATE,'YYYY')-4) THEN
      		   vYEAR_EFECTOS:= TO_CHAR(SYSDATE,'YYYY')-4;
			ELSE vYEAR_EFECTOS:= vLIQUIDOC.YEAR_EFECTOS_IBI;
   			END IF;

			-- Comprobamos q el Año de Entrada en Padron sea igual al año Efectos IBI, de ser igual:
			-- Para TORREJON: generaremos la liquidacion para dicho año, pues ellos notifican el primer año
			   			   -- y no generaremos su recibo si viene.
			-- Para CATOURE: no generaremos la liquidacion para dicho año, pues notifica catastro por ellos
			   			   -- y generaremos su recibo si viene.
			-- Esto vendrá como parámetro de entrada.
			-- De no ser iguales, el año de entrada en padron nunca se liquida pues se supone entró en padrón
			-- es decir, se generó su correspondiente recibo
			SELECT COUNT(*) INTO vCOUNT FROM RECIBOS_IBI WHERE YEAR=vLIQUIDOC.YEAR_ENTRADA_PADRON;
   			IF (vLIQUIDOC.YEAR_EFECTOS_IBI=vLIQUIDOC.YEAR_ENTRADA_PADRON) AND --nunca será mayor por la validacion...
			   (xINCLUIR_ACTUAL) AND (vCOUNT=0) THEN -- Si se ha generado el padron ya no podrá liquidarse...
    		    vYEAR_ENTRADA:= vLIQUIDOC.YEAR_ENTRADA_PADRON;
			ELSE vYEAR_ENTRADA:= vLIQUIDOC.YEAR_ENTRADA_PADRON-1;
   			END IF;

			/* Comprobamos q el contribuyente exista en nuestra base de datos,
			   insertandolo en su defecto */
   			SELECT COUNT(*) INTO vCOUNT FROM CONTRIBUYENTES
			WHERE RTRIM(NIF)=RTRIM(vLIQUIDOC.NIF);
			IF (vCOUNT=0) THEN

  			    INS_UPD_CONTRI('A',vLIQUIDOC.NIF,SUBSTR(RTRIM(vLIQUIDOC.NOMBRE),1,40),
								SUBSTR(RTRIM(vLIQUIDOC.TIPO_VIA_FISCAL),1,2),vLIQUIDOC.NOMBRE_VIA_FISCAL,
								vLIQUIDOC.PRIMER_NUMERO_FISCAL,vLIQUIDOC.BLOQUE,vLIQUIDOC.PRIMERA_LETRA,
								vLIQUIDOC.ESCALERA_FISCAL,vLIQUIDOC.PLANTA_FISCAL,
								SUBSTR(RTRIM(vLIQUIDOC.PUERTA_FISCAL),1,2),
								vLIQUIDOC.MUNICIPIO_FISCAL,vLIQUIDOC.PROVINCIA,vLIQUIDOC.COD_POSTAL_FISCAL,
								vLIQUIDOC.PAIS,NULL, '' ,'','','');
			END IF;

			/* Si year_efectos es el año de liquidacion llamamos a MAKELIQUIDOC_IDEMYEAR,
			   q crea la liquidacion sin tanto calculo en este caso innecesario.
			   Tambien si lo q queremos es imprimir las liquidaciones en lugar de generarlas,
			   llamamos a MAKELIQUIDOC_IDEMYEAR. */
			IF (vYEAR_EFECTOS=vYEAR_ENTRADA) THEN
			    IBI_DOCDGC_IDEMYEAR(xFLIQUI,vYEAR_ENTRADA,vLIQUIDOC);
				xNUMLIQUI:=xNUMLIQUI+1;
			ELSIF (vYEAR_EFECTOS<vYEAR_ENTRADA) THEN
			    -- Montar referencia catastral
				vREF_CATASTRAL:=vLIQUIDOC.REF_CATASTRAL||vLIQUIDOC.NUMERO_SECUENCIAL||
             			  		vLIQUIDOC.PRIMER_CARACTER_CONTROL||vLIQUIDOC.SEGUN_CARACTER_CONTROL;

				IBI_DOCDGC_FILL_TMP_ATRASOS(vYEAR_EFECTOS,vYEAR_ENTRADA,vYEARP,vNUMYEARS,vLIQUIDOC);

				/* Comprobamos q se hayan encontrado e insertados datos para
				   poder generar la liquidacion. */
				SELECT COUNT(*) INTO vCOUNT FROM TMP_ATRASOS_IBI WHERE USUARIO=UID;
				IF vCOUNT=0 THEN
				   vGENERADO:= 'E';
				   vMOTIVO:= 'NO HAY DATOS PARA GENERAR LA LIQUIDACION';
				   GOTO Next_Liqui;
				END IF;

				LIQUIDAR_ATRASOS_IBI(vYEAR_EFECTOS,vYEAR_ENTRADA,vYEARP,vNUMYEARS);

				/* Comprobamos si en recaudacion existen recibos pagados correspondientes
   				   a este concepto entre los años elegidos. */
          		SELECT SUM(V.PRINCIPAL) INTO vINGRESADO
   	      		  FROM VALORES V
       	  		 WHERE V.YEAR BETWEEN vYEAR_EFECTOS AND vYEAR_ENTRADA
				   AND V.OBJETO_TRIBUTARIO LIKE '%'||vREF_CATASTRAL||'%'
				   AND V.NIF=vLIQUIDOC.NIF;
				IF vINGRESADO IS NULL THEN
				   vINGRESADO:=0;
				END IF;

		    	/* Calcular el total de la liquidación. Nunca esta sentencia causará excepcion
			       puesto q anteriormente hemos comprobado q existian datos en dicha tabla */
				SELECT SUM(TOTAL)-vINGRESADO INTO vTOTAL FROM TMP_ATRASOS_IBI
				WHERE USUARIO=UID AND YEAR BETWEEN vYEAR_EFECTOS AND vYEAR_ENTRADA;

				IF vTOTAL IS NULL THEN
				   vTOTAL:=0;

				ELSIF vTOTAL<0 THEN
					 vGENERADO:= 'E';
					 vMOTIVO:= 'IMPORTE DE LA LIQUIDACION INFERIOR AL ANTERIORMENTE LIQUIDADO SOBRE DICHO TRIBUTO';

				ELSE --vTOTAL>0
  		    		 /* Crear el motivo para la liquidacion */
					 vOBJ_TRIBU:='REF. CATASTRAL: '||vREF_CATASTRAL||
							'  NÚM. FIJO: '||vLIQUIDOC.NUM_FIJO||
						    '  IMPORTE DE LA LIQUIDACIÓN DESGLOSADO: '||CHR(13);

					 FOR vATRASOS_IBI IN (SELECT * FROM TMP_ATRASOS_IBI
								 	  WHERE USUARIO=UID AND YEAR BETWEEN vYEAR_EFECTOS AND vYEAR_ENTRADA
									  ORDER BY YEAR DESC) LOOP

				    		vOBJ_TRIBU:=vOBJ_TRIBU||'AÑO:'||vATRASOS_IBI.YEAR||'   BASE LIQUIDABLE='||
	   									LTRIM(TO_CHAR(vATRASOS_IBI.BLIQUIDABLE,'999G999D99'))||' Euros'||
            			        		'   GRAVAMEN APLICADO='||LTRIM(TO_CHAR(vATRASOS_IBI.GRAVAMEN,'0D999'))||' %';
							
            			IF (vATRASOS_IBI.BONIFICACION<>0) THEN
              				vOBJ_TRIBU:=vOBJ_TRIBU||'   BONIFICACIÓN:'||TO_CHAR(vATRASOS_IBI.BONIFICACION,'900')||' %';
							END IF;
							
            			vOBJ_TRIBU:=vOBJ_TRIBU||'   CUOTA='||LTRIM(TO_CHAR(vATRASOS_IBI.TOTAL,'999G999D99'))||' Euros'||CHR(13);
            			
					 END LOOP;

					 
					 IF vINGRESADO>0 THEN
				        vOBJ_TRIBU:=vOBJ_TRIBU||CHR(13)||'     ANTERIORMENTE LIQUIDADO SOBRE EL MISMO TRIBUTO: '||LTRIM(TO_CHAR(vINGRESADO,'999G999D99'))||' Euros'||CHR(13);
					 END IF;

					 -- 10/10/2006 Lucas Fernández. Se comenta estas lineas por petición de Catoure
				     --vOBJ_TRIBU:=vOBJ_TRIBU||'V. SUELO: '||vLIQUIDOC.VALOR_SUELO||' Euros'||CHR(13)||
					 --				    'V. CONSTRUCCION: '||vLIQUIDOC.VALOR_CONSTRUCCION||' Euros'||CHR(13)||
					 --					'V. CATASTRAL: '||vLIQUIDOC.VALOR_CATASTRAL||' Euros';

				     -- Añadir la liquidacion
			       	 ADD_LIQUI(vMUNI,vCONCEP,TO_CHAR(SYSDATE,'YYYY'),'00',TO_CHAR(SYSDATE,'YYYY'),vLIQUIDOC.NIF,NULL,
						  RTRIM(vLIQUIDOC.TIPO_VIA)||' '||RTRIM(vLIQUIDOC.NOMBRE_VIA)||' '||
						  RTRIM(vLIQUIDOC.PRIMER_NUMERO)||' '||RTRIM(vLIQUIDOC.BLOQUE)||' '||
						  RTRIM(vLIQUIDOC.ESCALERA)||' '||RTRIM(vLIQUIDOC.PLANTA)||' '||RTRIM(vLIQUIDOC.PUERTA),
						  xFLIQUI,GETFINPEVOL(vMUNI),vTOTAL,vOBJ_TRIBU,vREF_CATASTRAL,
						  vLIQUIDOC.NUM_FIJO,vLIQUIDOC.REF_EXPEDIENTE,NULL,NULL,vNUMERO_LIQUI,vID_LIQUI);

					 vGENERADO:= 'S';
					 vMOTIVO:= 'GENERADA LA LIQUIDACION COMO ALTA - AÑO EFECTO DIFERENTE DEL AÑO LIQUIDACIÓN';
					 xNUMLIQUI:=xNUMLIQUI+1;

				END IF;

  		        <<Next_Liqui>>
		  		UPDATE IBI_DOCDGC SET GENERADO=vGENERADO,MOTIVO=vMOTIVO,F_GENERACION=xFLIQUI
		  		 WHERE CURRENT OF cLIQUIDOC;

			END IF; -- vYEAR_EFECTOS <> xYEARLIQUI
		  END LOOP; -- cLIQUIDOC

		ELSE
			UPDATE IBI_DOCDGC SET GENERADO=vGENERADO,MOTIVO=vMOTIVO WHERE MUNICIPIO=vMUNI;
		    /* Actualizamos todos los registros para este ayto, es decir:
		       Generado='E',Motivo correspondiente al parametro incorrecto,
		       Y pasamos al siguiente registro */
	    END IF; -- IF VALIDAR_PARAMETROS_AYTO

	END LOOP;	-- cAYTOS
END IBI_DOCDGC_GENERAR;




/****************************************************************************************************
AUTOR: Gloria María Calle Hernández. 01/02/2002
FUNCION: Procesa cada registro en la tabla de DOCDGC siempre q year_efectos_ibi=yearliqui
  		 Es llamado cuando se trata de impresion de las liquidaciones ya generadas desde el DOCDGC
PARAMETROS: 	xREG_DOC: Registro completo de la tabla IBI_DocDgc a procesar
				xFLIQUI: Fecha en que se aplicarán dichas alteraciones
				xYEARLIQUI: Año a liquidar
MODIFICADO: Gloria Maria Calle Hernandez
			Al año a liquidar se comparaba con el año actual, ahora se envía como parámetro
MODIFICADO: 17/05/04. Gloria Maria Calle Hernandez. Cambiado MAX_VALOR_CATASTRAL por MAX_CUOTA
	        y añadido campo CLAVE (para los bienes de caracteristicas especiales).
MODIFICADO: 09/06/2006. Lucas Fernández Pérez. Si la bonificacion es del 0% no se mete en objeto_tributario
	(por problemas de espacio, que es reducido en los preimpresos)
*****************************************************************************************************/
PROCEDURE IBI_DOCDGC_IDEMYEAR (
	xFLIQUI			IN	DATE,
	xYEARLIQUI		VARCHAR2,
	xREG_DOC		IN	IBI_DOCDGC%ROWTYPE)
AS
	vCONCEP					CHAR(6);
	vFINPEVOL				DATE;
	vREF_CATASTRAL			CHAR(20)		   DEFAULT '';
	vNUM_PER          		INTEGER;
	vRECIBO           		INTEGER;
	vCONTADOR				INTEGER;
	vTOTAL            		FLOAT;
	vGRAVAMEN 				FLOAT;
	vMAX_CUOTA				FLOAT;
	vSALTO					CHAR(2);
	vOBJETO_TRIBUTARIO 		VARCHAR(1024)	   DEFAULT '';
	vDOMI_TRIBUTARIO		VARCHAR2(50)	   DEFAULT '';
	vDMUNI					VARCHAR2(50);
	vBASE_IMPONIBLE   		FLOAT;
	vID_LIQUI				INTEGER;
	vEXPE					CHAR(15);

BEGIN

   --recoger el gravamen para cada Clave de bien inmueble
   BEGIN
      SELECT GRAVAMEN,MAX_CUOTA INTO vGRAVAMEN,vMAX_CUOTA
	    FROM GRAVAMEN_IBI_RUS
   	   WHERE MODULO='IBI' AND MUNICIPIO=xREG_DOC.MUNICIPIO AND YEAR=xYEARLIQUI
	     AND CLAVE=xREG_DOC.CLAVE_USO AND xREG_DOC.VALOR_CATASTRAL>MAX_VCATASTRAL;
	--Si estamos en un año anterior al 2005 o si para dicha clave de uso no supera el valor catastral minimo
	--la consulta no devolverá gravamen alguno y se buscará el gravamen general para clave nula.
   EXCEPTION
       WHEN NO_DATA_FOUND THEN
 	      BEGIN
             SELECT GRAVAMEN,MAX_CUOTA INTO vGRAVAMEN,vMAX_CUOTA
	           FROM GRAVAMEN_IBI_RUS
              WHERE MODULO='IBI' AND MUNICIPIO=xREG_DOC.MUNICIPIO  AND YEAR=xYEARLIQUI
			    AND TRIM(CLAVE) IS NULL;
		  EXCEPTION
			  WHEN NO_DATA_FOUND THEN
                   vGRAVAMEN:=0;
                   vMAX_CUOTA:=0;
		  END;
   END;

   -- Hallamos la base imponible
   IF xREG_DOC.VALOR_CATASTRAL=xREG_DOC.BASE_LIQUIDABLE THEN
   	  vBASE_IMPONIBLE:=ROUND((xREG_DOC.VALOR_CATASTRAL * vGRAVAMEN)/100,2);
   ELSE vBASE_IMPONIBLE:=ROUND((xREG_DOC.BASE_LIQUIDABLE * vGRAVAMEN)/100,2);
   END IF;

   SELECT LIQUIDACION INTO vCONCEP FROM PROGRAMAS WHERE PROGRAMA='IBI';

   -- Montar referencia catastral
   vREF_CATASTRAL:=xREG_DOC.REF_CATASTRAL||xREG_DOC.NUMERO_SECUENCIAL||
  				   xREG_DOC.PRIMER_CARACTER_CONTROL||xREG_DOC.SEGUN_CARACTER_CONTROL;

   SELECT IBI_NUM_PERIODOS INTO vNUM_PER FROM DATOSPER WHERE MUNICIPIO=xREG_DOC.MUNICIPIO;

   -- Aumentar el contador de conceptos
   CALCULO_CONTADOR_CONCEPTOS(xREG_DOC.MUNICIPIO,vCONCEP,vRECIBO);

   IF (xREG_DOC.REF_EXPEDIENTE IS NULL) THEN
       vEXPE:=LPAD(vRECIBO,15,'0');
   ELSE vEXPE:=xREG_DOC.REF_EXPEDIENTE;
   END IF;

   -- Si el año es mayor no se aplica bonificacion
   IF (xYEARLIQUI > xREG_DOC.YEAR_BONI OR xREG_DOC.YEAR_BONI IS NULL) THEN
	   vTOTAL:=ROUND(vBASE_IMPONIBLE/vNUM_PER,2);
   ELSE -- Aplicar bonificacion a todos los meses
	   IF (xYEARLIQUI < xREG_DOC.YEAR_BONI) THEN
		   vTOTAL:=ROUND((vBASE_IMPONIBLE*(1-(xREG_DOC.BONIFICACION/100)))/vNUM_PER,2);
	   ELSE -- Aplicar la bonificacion a los meses q correspondan
		   vTOTAL:=ROUND(((vBASE_IMPONIBLE/12)* TO_NUMBER(xREG_DOC.MES_BONI)*
				 	      (1-(xREG_DOC.BONIFICACION/100)))+((vBASE_IMPONIBLE/12)*
				 	      (12- TO_NUMBER(xREG_DOC.MES_BONI))),2);
	       -- Meses sin bonificacion
	       vTOTAL:=ROUND(vTOTAL/vNUM_PER,2);
	   END IF;
   END IF;

   IF (vTOTAL<vMAX_CUOTA) THEN
       vTOTAL:=0;
   END IF;
   vTOTAL:=ROUND(vTOTAL,2);

   SELECT SALTO INTO vSALTO FROM SALTO;

   /* Devuelve el fin de periodo voluntario en funcion del numero de dias
	  de la configuracion de la tabla de datosper */
   vFINPEVOL:=GETFINPEVOL(xREG_DOC.MUNICIPIO);

   -- Domicilio tributario
   vDOMI_TRIBUTARIO:=RTRIM(xREG_DOC.TIPO_VIA)||' '||RTRIM(xREG_DOC.NOMBRE_VIA)||' '||
       			     RTRIM(xREG_DOC.PRIMER_NUMERO)||' '||RTRIM(xREG_DOC.PRIMERA_LETRA)||' '||
               		 RTRIM(xREG_DOC.ESCALERA)||' '||RTRIM(xREG_DOC.PLANTA)||' '||RTRIM(xREG_DOC.PUERTA);

   /* Crear el motivo para la liquidacion */
   vOBJETO_TRIBUTARIO:='REF. CATASTRAL: '||vREF_CATASTRAL||
   					   '  NÚM. FIJO '||xREG_DOC.NUM_FIJO||
					   '  IMPORTE DE LA LIQUIDACIÓN DESGLOSADO: '||CHR(13);
   vOBJETO_TRIBUTARIO:= vOBJETO_TRIBUTARIO||'AÑO:'||xYEARLIQUI||'   BASE LIQUIDABLE='||
   						LTRIM(TO_CHAR(xREG_DOC.BASE_LIQUIDABLE,'999G999D99'))||' Euros'||
           			   '   GRAVAMEN APLICADO='||LTRIM(TO_CHAR(vGRAVAMEN,'0D999'))||' %';
   IF (xREG_DOC.BONIFICACION<>0) THEN
   	   vOBJETO_TRIBUTARIO:=vOBJETO_TRIBUTARIO||'   BONIFICACIÓN:'||TO_CHAR(xREG_DOC.BONIFICACION,'900')||' %';
   END IF;
   vOBJETO_TRIBUTARIO:=vOBJETO_TRIBUTARIO||'   CUOTA='||LTRIM(TO_CHAR(vTOTAL,'999G999D99'))||' Euros'||CHR(13);

   vOBJETO_TRIBUTARIO:=vOBJETO_TRIBUTARIO||'V. SUELO: '||xREG_DOC.VALOR_SUELO||' Euros'||CHR(13)||
									       'V. CONSTRUCCION: '||xREG_DOC.VALOR_CONSTRUCCION||' Euros'||CHR(13)||
										   'V. CATASTRAL: '||xREG_DOC.VALOR_CATASTRAL||' Euros';

   -- Comprobamos si existe ya la liquidacion. Sólo si no existe la insertamos
   BEGIN
   		SELECT ID INTO vID_LIQUI FROM LIQUIDACIONES
		WHERE MUNICIPIO=xREG_DOC.MUNICIPIO AND NUMERO=LPAD(vRECIBO,7,'0')
		  AND CONCEPTO=vCONCEP AND YEAR=TO_CHAR(SYSDATE,'YYYY');
   EXCEPTION
   		WHEN NO_DATA_FOUND THEN
			 INSERT INTO LIQUIDACIONES
		  	 		(USUARIO,MUNICIPIO,NUMERO,CONCEPTO,YEAR,CONTRAIDO,PERIODO,NIF,
	 	   			 DOMI_TRIBUTARIO,F_LIQUIDACION,IMPORTE,MOTIVO,EXPEDIENTE,F_JULIANA,
	 	   			 REF_CATASTRAL,NUM_FIJO)
   		     VALUES
		  	 		(USER,xREG_DOC.MUNICIPIO,LPAD(vRECIBO,7,'0'),vCONCEP,TO_CHAR(SYSDATE,'YYYY'),TO_CHAR(SYSDATE,'YYYY'),
 	 	   			 '00',xREG_DOC.NIF,vDOMI_TRIBUTARIO,xFLIQUI,vTOTAL,
 	 	   			 vOBJETO_TRIBUTARIO,vEXPE,TO_CHAR(vFINPEVOL,'ddd'),
 	 	   			 vREF_CATASTRAL,xREG_DOC.NUM_FIJO)
   			 RETURNING ID INTO vID_LIQUI;

   			 INSERT_HISTORIA_LIQUI(vID_LIQUI,'A','SE AÑADE LA LIQUIDACION');
   END;

   -- Cuando se genera una liquidacion hay q actualizar en Contador_conceptos
   SELECT MAX(NUMERO) INTO vCONTADOR FROM LIQUIDACIONES
    WHERE MUNICIPIO=xREG_DOC.MUNICIPIO AND CONCEPTO=vCONCEP
  	  AND YEAR=TO_CHAR(SYSDATE,'YYYY') AND PERIODO='00';

   UPDATE CONTADOR_CONCEPTOS SET CONTADOR=vCONTADOR
	WHERE MUNICIPIO=xREG_DOC.MUNICIPIO AND CONCEPTO=vCONCEP;

   -- Se actualiza el registro en ibi_docdgc como generado y dado de alta
   UPDATE IBI_DOCDGC SET GENERADO='S',MOTIVO='GENERADA LA LIQUIDACION COMO ALTA - AÑO EFECTO IGUAL AL AÑO DE LIQUIDACIÓN',
   		  			 	 F_GENERACION=xFLIQUI WHERE ID=xREG_DOC.ID;

END IBI_DOCDGC_IDEMYEAR;



/****************************************************************************************************
AUTOR: Gloria María Calle Hernández. 01/02/2002
FUNCION: Procedimiento que calcula el total a pagar por un año dependiendo del gravamen
         para ese año y de las posibles bonificaciones.
         El procedimiento RELLENAR_TMP_ATRASOS hace lo mismo pero consultando en la tabla de IBI.
PARAMETROS: 	xYEARP
				xNUMYEARS
				xREG_DOC
				xYEAR_INICIO: Año a partir del cual liquidar
				xYEARLIQUI: Año a liquidar
MODIFICADO: Gloria Maria Calle Hernandez
			Al año a liquidar se comparaba con el año actual, ahora se envía como parámetro
MODIFICADO: 17/05/04. Gloria Maria Calle Hernandez. Cambiado MAX_VALOR_CATASTRAL por MAX_CUOTA
			y añadido campo CLAVE (para los bienes de caracteristicas especiales).
MODIFICADO: 17/05/04. Gloria Maria Calle Hernandez. Pasados parámetros de inicio y fin: YEAR_INICIO y YEARLIQUI
MODIFICADO: 05/05/05. Gloria Maria Calle Hernandez. Por modificaciones realizadas para aplicar la bonificación,
					  que ahora se almacena en el mismo registro Doc_Dgc.
MODIFICADO: 10/05/05. Gloria Maria Calle Hernandez. Para que añada los años a la tabla tmp_atrasos_ibi
					  necesarios para hacer los calculos, es decir, años que tengan valor catastral y/o base 
					  liquidable sobre los cuales hacer los cálculos aunque se borren posteriormente de dicha 
					  tabla temporal para obtener el total resultante.
MODIFICADO: 09/10/06. Lucas Fernández Pérez. El cálculo del valor catastral y base liquidable debe hacerse
						sin tener en cuenta los datos de ibi, por lo que se comenta el código que rellena esos
						campos en tmp_atrasos_ibi para que no se haga el cálculo sobre datos de ibi. El motivo
						según catoure es que se liquida hacia atrás, pero partiendo de la valoración del disco,
						ya que las valoraciones de años anteriores (si existen) eran incorrectas y no se puede
						liquidar por esas valoraciones incorrectas. Por ejemplo, si en 2003 se solicita una 
						ampliación de valor catastral, y hasta 2006 no llega ese movimiento, se debe liquidar
						los años anteriores partiendo de la valoración de 2006, sin tener en cuenta las 
						valoraciones "erróneas" de 2003,2004,2005 que estaban con la valoración antigua.
*****************************************************************************************************/
PROCEDURE IBI_DOCDGC_FILL_TMP_ATRASOS (
    xYEAR_INICIO  IN    VARCHAR2,
	xYEARLIQUI	  IN	VARCHAR2,
	xYEARP		  IN	VARCHAR2,
	xNUMYEARS	  IN	INTEGER,
	xREG_DOC	  IN	IBI_DOCDGC%ROWTYPE)
AS
   vYEARDesde			VARCHAR2(4);
   vYEARHasta			VARCHAR2(4);
   vGRAVAMEN		   	FLOAT;
   vINCREMENTO		   	FLOAT;
   vEXENCION		   	FLOAT;
   vVC					FLOAT;
   vBL					FLOAT;
   i 				   	INTEGER;
   vCONTADOR		   	INTEGER;
   vDIFERENTES		   	CHAR(1);

   -- cursor que recoge los datos que poseamos del abonado con ID=xID para años anteriores,
   -- hasta el año inferior del intervalo de liquidación.
   CURSOR CIBI IS SELECT YEAR,VALOR_CATASTRAL,BASE_LIQUIDABLE,BONIFICACION,YEAR_INI_BONI,
			      MES_INI_BONI,YEAR_BONI,MES_BONI FROM IBI
		          WHERE MUNICIPIO=xREG_DOC.MUNICIPIO AND REF_CATASTRAL=xREG_DOC.REF_CATASTRAL
                    AND NUMERO_SECUENCIAL=xREG_DOC.NUMERO_SECUENCIAL
                    AND PRIMER_CARACTER_CONTROL=xREG_DOC.PRIMER_CARACTER_CONTROL
 				    AND SEGUN_CARACTER_CONTROL=xREG_DOC.SEGUN_CARACTER_CONTROL
				    AND YEAR BETWEEN xYEAR_INICIO AND xYEARLIQUI ORDER BY YEAR DESC;
BEGIN

   DELETE FROM TMP_ATRASOS_IBI WHERE USUARIO=UID;

   IF (xREG_DOC.YEAR_VALOR_CATASTRAL>xYEARLIQUI) THEN
       vYEARHasta:= xREG_DOC.YEAR_VALOR_CATASTRAL;
   ELSE vYEARHasta:= xYEARLIQUI;
   END IF;

   IF (xREG_DOC.YEAR_VALOR_CATASTRAL<xYEAR_INICIO) THEN
       vYEARDesde:= xREG_DOC.YEAR_VALOR_CATASTRAL;
   ELSE vYEARDesde:= xYEAR_INICIO;
   END IF;

   FOR i IN REVERSE TO_NUMBER(vYEARDesde)..TO_NUMBER(vYEARHasta)
   LOOP
      -- Recogemos el gravamen e incremento para cada año.
      BEGIN
	     SELECT GRAVAMEN,INCREMENTO_VC,MAX_CUOTA
           INTO vGRAVAMEN,vINCREMENTO,vEXENCION
 	       FROM GRAVAMEN_IBI_RUS
   	      WHERE MODULO='IBI' AND MUNICIPIO=xREG_DOC.MUNICIPIO AND YEAR=TO_CHAR(i)
	        AND CLAVE=xREG_DOC.CLAVE_USO AND xREG_DOC.VALOR_CATASTRAL>MAX_VCATASTRAL;
	  --Si estamos en un año anterior al 2005 o si para dicha clave de uso no supera el valor catastral minimo
	  --la consulta no devolverá gravamen alguno y se buscará el gravamen general para clave nula.
      EXCEPTION
          WHEN NO_DATA_FOUND THEN
 	         BEGIN
                SELECT GRAVAMEN,INCREMENTO_VC,MAX_CUOTA
                  INTO vGRAVAMEN,vINCREMENTO,vEXENCION
	              FROM GRAVAMEN_IBI_RUS
                 WHERE MODULO='IBI' AND MUNICIPIO=xREG_DOC.MUNICIPIO  AND YEAR=TO_CHAR(i)
			       AND TRIM(CLAVE) IS NULL;
		     EXCEPTION
			    WHEN NO_DATA_FOUND THEN
		   			vGRAVAMEN:=0;
		   			vINCREMENTO:=0;
  		   			vEXENCION:=0;
		     END;
      END;

      -- insertamos en la tabla temporal tantas tuplas como años desde el mayor año
      -- hasta el inicio del intervalo (desde).
      INSERT INTO TMP_ATRASOS_IBI (YEAR,DIFERENTES,GRAVAMEN,INCREMENTO,EXENCION,
      		BONIFICACION,YEAR_INI_BONI,MES_INI_BONI,YEAR_BONI,MES_BONI)
      VALUES (TO_CHAR(i),'N',vGRAVAMEN,vINCREMENTO,vEXENCION,
      		xREG_DOC.BONIFICACION,xREG_DOC.YEAR_INI_BONI,xREG_DOC.MES_INI_BONI,xREG_DOC.YEAR_BONI,xREG_DOC.MES_BONI);


	  -- si el año está en el intervalo (año_prorrateo,año_prorrateo+xNUMYEARS-1)
      -- el VC<>BL; si es menor o mayor supondremos que el VC=BL
	  IF (TO_CHAR(i) BETWEEN xYEARP AND XYEARP+xNUMYEARS-1) THEN
		UPDATE TMP_ATRASOS_IBI SET DIFERENTES='S'
		WHERE USUARIO=UID AND YEAR=TO_CHAR(i);
	  END IF;

   END LOOP;

/* COMENTADO EN LA MODIFICACIÓN DEL 09/10/2006
   -- ahora actualizamos, si los datos existen en la B.D. de IBI,
   -- el Valor Catastral y la Base Liquidable de los años insertados en la tabla temporal
   FOR v_ibi IN CIBI
   LOOP
      UPDATE TMP_ATRASOS_IBI SET VCATASTRAL=v_ibi.VALOR_CATASTRAL,
	   			         		 BLIQUIDABLE=v_ibi.BASE_LIQUIDABLE
	  WHERE USUARIO=UID AND YEAR=v_ibi.YEAR;
   END LOOP;
*/
   -- Actualizamos datos a partir de los datos del ultimo año q son los unicos q tenemos
   UPDATE TMP_ATRASOS_IBI SET VCATASTRAL=xREG_DOC.VALOR_CATASTRAL,
   			         	      BLIQUIDABLE=xREG_DOC.BASE_LIQUIDABLE
   WHERE USUARIO=UID AND YEAR=xREG_DOC.YEAR_VALOR_CATASTRAL;

   -- actualizamos las bonificaciones para todos los años dentro del intervalo, ya que
   -- es muy posible que esta información sólo se encuentre en el registro mas actual
   ACTUALIZAR_BONIFICACIONES(xYEARLIQUI,xYEARLIQUI);

   -- Finalmente se insertan los datos que podamos poseer del recibo para el
   -- año de la última ponencia, siempre que este no se encontrara dentro del
   -- intervalo xDesde->xYear y si para algún año (o algunos) del intervalo
   -- su valor catastral no coincide con la base liquidable
   IF (xYEARP<vYEARDesde) THEN
       SELECT COUNT(*) INTO vCONTADOR FROM TMP_ATRASOS_IBI
	   WHERE USUARIO=UID AND DIFERENTES='S';

	IF (vCONTADOR>0) THEN
	    begin
          SELECT VALOR_CATASTRAL,BASE_LIQUIDABLE INTO vVC,vBL
          FROM IBI
	      WHERE MUNICIPIO=xREG_DOC.MUNICIPIO AND REF_CATASTRAL=xREG_DOC.REF_CATASTRAL
            AND NUMERO_SECUENCIAL=xREG_DOC.NUMERO_SECUENCIAL
            AND PRIMER_CARACTER_CONTROL=xREG_DOC.PRIMER_CARACTER_CONTROL
 			AND SEGUN_CARACTER_CONTROL=xREG_DOC.SEGUN_CARACTER_CONTROL AND YEAR=xYEARP;
	    Exception
		   When no_data_found then
		      vVC:=NULL;
	  		  vBL:=NULL;
	    end;

	    INSERT INTO TMP_ATRASOS_IBI (YEAR,VCATASTRAL,BLIQUIDABLE,DIFERENTES)
        VALUES (xYEARP,vVC,vBL,'S');
	END IF;
  END IF;

END IBI_DOCDGC_FILL_TMP_ATRASOS;



/****************************************************************************************************
AUTOR: Gloria María Calle Hernández. 01/02/2002
FUNCION: Procdimiento q actualiza datos del titular: dni,nombre,direccion fiscal...
PARAMETROS: 	xID: Identificador del registro de la tabla IBI_DocDgc a modificar
				x... Datos posibles a modificar
				xTODOS: Parámetro con el cual podremos elegir entre modificar sólo el registro espeificado,
						o todos los registros para el mismo dni o titular
MODIFICACIÓN: 21/10/2003 Gloria Maria Calle Hernandez
			  Modificado el procedimiento para actualizar no sólo los datos fiscales sino tb el domicilio
			  tributario.
MODIFICACIÓN: 17/12/2004 Gloria Maria Calle Hernandez
			  Modificado para cambiar el tipo de alteracion también.
MODIFICACION: 10/04/2005. Gloria Maria Calle Hernandez. Añadido el procedimiento INSERT_HISTO, para insertar
			  en la tabla de historico cada cambio realizado por los usuarios sobre dicha tabla.
*****************************************************************************************************/
PROCEDURE IBI_DOCDGC_MODIFY (
       xID 					IN INTEGER,
       xNIF 				IN VARCHAR2,
       xNOMBRE 				IN VARCHAR2,
       xVIAF 				IN VARCHAR2,
       xCALLEF 				IN VARCHAR2,
       xNUMEROF 			IN VARCHAR2,
       xLETRAF 				IN VARCHAR2,
       xBLOQUEF 			IN VARCHAR2,
       xESCALERAF 			IN VARCHAR2,
       xPLANTAF 			IN VARCHAR2,
       xPISOF 				IN VARCHAR2,
       xCPF 				IN VARCHAR2,
       xPOBLACIONF 			IN VARCHAR2,
       xPROVINCIAF 			IN VARCHAR2,
	   xPAISF 				IN VARCHAR2,
       xVIAT 				IN VARCHAR2,
       xCALLET 				IN VARCHAR2,
       xNUMEROT 			IN VARCHAR2,
       xLETRAT 				IN VARCHAR2,
       xBLOQUET 			IN VARCHAR2,
       xESCALERAT 			IN VARCHAR2,
       xPLANTAT 			IN VARCHAR2,
       xPISOT 				IN VARCHAR2,
       xCPT 				IN VARCHAR2,
	   xTIPOALTER			IN VARCHAR2,
	   xTODOS				IN BOOLEAN)
AS
	   vNIF 				CHAR(10);
       vREGISTRO			IBI_DOCDGC%ROWTYPE;

       /* Cursor que recorre todos los registros para el mismo nif anterior actualizando
       	  sus datos fiscales. */
       CURSOR cIBIDOC IS SELECT * FROM IBI_DOCDGC WHERE NIF=vNIF
	   FOR UPDATE OF NIF,NOMBRE,TIPO_VIA_FISCAL,NOMBRE_VIA_FISCAL,PRIMER_NUMERO_FISCAL,PRIMERA_LETRA_FISCAL,BLOQUE_FISCAL,
	   	   		     ESCALERA_FISCAL,PLANTA_FISCAL,PUERTA_FISCAL,COD_POSTAL_FISCAL,MUNICIPIO_FISCAL,PROVINCIA,PAIS,
					 PRIMER_NUMERO,PRIMERA_LETRA,BLOQUE,ESCALERA,PLANTA,PUERTA,CODIGO_POSTAL,TIPO_ALTERACION;
					 
	   PROCEDURE INSERT_HISTO (xID IN INTEGER)
	   IS
	   BEGIN
   		  INSERT INTO HISTO_DOCDGC (IDDOCDGC,COD_PROVI_INE,COD_MUNI_INE,DISTRITO_MUNI,COD_ENTIDAD_MENOR,
   		  COD_VIA_PUBLICA,TIPO_VIA,NOMBRE_VIA,PRIMER_NUMERO,PRIMERA_LETRA,SEGUNDO_NUMERO,SEGUNDA_LETRA,KILOMETRO,
		  BLOQUE,TEXTO_DIRECCION,CODIGO_POSTAL,ESCALERA,PLANTA,PUERTA,NIF,PERSONALIDAD,NOMBRE,COD_DEL_MEH,
		  COD_MUNICIPIO_DGC,COD_PROVI_INE_FISCAL,COD_MUNI_INE_FISCAL,COD_VIA_PUBLICA_FISCAL,TIPO_VIA_FISCAL,
		  NOMBRE_VIA_FISCAL,PRIMER_NUMERO_FISCAL,PRIMERA_LETRA_FISCAL,SEGUNDO_NUMERO_FISCAL,SEGUNDA_LETRA_FISCAL,
		  KILOMETRO_FISCAL,BLOQUE_FISCAL,TEXTO_DIRECCION_FISCAL,ESCALERA_FISCAL,PLANTA_FISCAL,PUERTA_FISCAL,
		  COD_POSTAL_FISCAL,APARTADO_CORREOS,PAIS,PROVINCIA,MUNICIPIO_FISCAL,YEAR_VALOR_CATASTRAL,TIPO_ALTERACION,
		  F_GRABACION,GENERADO,MOTIVO,F_GENERACION,BONIFICACION,YEAR_INI_BONI,MES_INI_BONI,YEAR_BONI,MES_BONI,
		  ARTICULO) 
   		  SELECT ID,COD_PROVI_INE,COD_MUNI_INE,DISTRITO_MUNI,COD_ENTIDAD_MENOR,
   		  COD_VIA_PUBLICA,TIPO_VIA,NOMBRE_VIA,PRIMER_NUMERO,PRIMERA_LETRA,SEGUNDO_NUMERO,SEGUNDA_LETRA,KILOMETRO,
		  BLOQUE,TEXTO_DIRECCION,CODIGO_POSTAL,ESCALERA,PLANTA,PUERTA,NIF,PERSONALIDAD,NOMBRE,COD_DEL_MEH,
		  COD_MUNICIPIO_DGC,COD_PROVI_INE_FISCAL,COD_MUNI_INE_FISCAL,COD_VIA_PUBLICA_FISCAL,TIPO_VIA_FISCAL,
		  NOMBRE_VIA_FISCAL,PRIMER_NUMERO_FISCAL,PRIMERA_LETRA_FISCAL,SEGUNDO_NUMERO_FISCAL,SEGUNDA_LETRA_FISCAL,
		  KILOMETRO_FISCAL,BLOQUE_FISCAL,TEXTO_DIRECCION_FISCAL,ESCALERA_FISCAL,PLANTA_FISCAL,PUERTA_FISCAL,
		  COD_POSTAL_FISCAL,APARTADO_CORREOS,PAIS,PROVINCIA,MUNICIPIO_FISCAL,YEAR_VALOR_CATASTRAL,TIPO_ALTERACION,
		  F_GRABACION,GENERADO,MOTIVO,F_GENERACION,BONIFICACION,YEAR_INI_BONI,MES_INI_BONI,YEAR_BONI,MES_BONI,
		  ARTICULO FROM IBI_DOCDGC WHERE ID=xID;
	   END;
					 
BEGIN
  IF xTODOS THEN
	 -- Recogemos los datos actuales que para este ID hay en la tabla IBI_DOCDGC.
     SELECT * INTO vREGISTRO FROM IBI_DOCDGC WHERE ID=xID;
     vNIF:= vREGISTRO.NIF;

     FOR vIBIDOC IN cIBIDOC
     LOOP
    	-- Modificamos los datos en la tabla IBI_DOCDGC
    	UPDATE IBI_DOCDGC SET 	NIF=xNIF,
                       			NOMBRE=xNOMBRE,
                       			TIPO_VIA_FISCAL=xVIAF,
                       			NOMBRE_VIA_FISCAL=xCALLEF,
                       			PRIMER_NUMERO_FISCAL=xNUMEROF,
                       			PRIMERA_LETRA_FISCAL=xLETRAF,
                       			BLOQUE_FISCAL=xBLOQUEF,
                       			ESCALERA_FISCAL=xESCALERAF,
                       			PLANTA_FISCAL=xPLANTAF,
                       			PUERTA_FISCAL=xPISOF,
                       			COD_POSTAL_FISCAL=xCPF,
                       			MUNICIPIO_FISCAL=xPOBLACIONF,
                       			PROVINCIA=xPROVINCIAF,
                       			PAIS=xPAISF,
                       			TIPO_VIA=xVIAT,
                       			NOMBRE_VIA=xCALLET,
                       			PRIMER_NUMERO=xNUMEROT,
                       			PRIMERA_LETRA=xLETRAT,
                       			BLOQUE=xBLOQUET,
                       			ESCALERA=xESCALERAT,
                       			PLANTA=xPLANTAT,
                       			PUERTA=xPISOT,
                       			CODIGO_POSTAL=xCPT
	    WHERE CURRENT OF cIBIDOC;
	    
	    INSERT_HISTO(vIBIDOC.ID);
     END LOOP;
  ELSE
  	 -- Modificamos los datos en la tabla IBI_DOCDGC
    	UPDATE IBI_DOCDGC SET 	NIF=xNIF,
                       			NOMBRE=xNOMBRE,
                       			TIPO_VIA_FISCAL=xVIAF,
                       			NOMBRE_VIA_FISCAL=xCALLEF,
                       			PRIMER_NUMERO_FISCAL=xNUMEROF,
                       			PRIMERA_LETRA_FISCAL=xLETRAF,
                       			BLOQUE_FISCAL=xBLOQUEF,
                       			ESCALERA_FISCAL=xESCALERAF,
                       			PLANTA_FISCAL=xPLANTAF,
                       			PUERTA_FISCAL=xPISOF,
                       			COD_POSTAL_FISCAL=xCPF,
                       			MUNICIPIO_FISCAL=xPOBLACIONF,
                       			PROVINCIA=xPROVINCIAF,
                       			PAIS=xPAISF,
                       			TIPO_VIA=xVIAT,
                       			NOMBRE_VIA=xCALLET,
                       			PRIMER_NUMERO=xNUMEROT,
                       			PRIMERA_LETRA=xLETRAT,
                       			BLOQUE=xBLOQUET,
                       			ESCALERA=xESCALERAT,
                       			PLANTA=xPLANTAT,
                       			PUERTA=xPISOT,
                       			CODIGO_POSTAL=xCPT,
								TIPO_ALTERACION=xTIPOALTER
	   WHERE ID=xID;

	   INSERT_HISTO(xID);
  END IF;
END IBI_DOCDGC_MODIFY;



/****************************************************************************************************
AUTOR: Gloria María Calle Hernández. 01/02/2002
FUNCION: Crea un grupo y pega todas las liquidaciones creadas a partir del DOCDGC en una fecha concreta,
		 para su impresión.
PARAMETROS: 	xALTERACION: Tipo de alteraciones a imprimir
				xF_LIQUIDACION: Fecha de generacion de las liquidaciones a imprimir
				xGRUPO: Parámetro de salida para devolver el grupo creado e imprimirlo
*****************************************************************************************************/
PROCEDURE IBI_DOCDGC_PRINT (
   	 xALTERACION	   IN  VARCHAR2,
	 xF_LIQUIDACION	   IN  DATE,
	 xGRUPO			   OUT INTEGER
) AS
  	 vLISTA_ALTERACIONES   VARCHAR2(20);
	 vMUNI				   VARCHAR2(3);

	 CURSOR CAYTOS IS SELECT MUNICIPIO FROM TMP_AYTOS WHERE USUARIO=USER;

     CURSOR cLIQUIDACIONES IS SELECT DISTINCT L.ID,L.GRUPO FROM LIQUIDACIONES L, IBI_DOCDGC I
 	 					   	   WHERE L.MUNICIPIO=I.MUNICIPIO AND L.MUNICIPIO=vMUNI
   							     AND SUBSTR(L.REF_CATASTRAL,1,14)=I.REF_CATASTRAL
								 AND SUBSTR(L.REF_CATASTRAL,15,4)=I.NUMERO_SECUENCIAL
   								 AND SUBSTR(L.REF_CATASTRAL,19,1)=I.PRIMER_CARACTER_CONTROL
								 AND SUBSTR(L.REF_CATASTRAL,20,1)=I.SEGUN_CARACTER_CONTROL
   								 AND L.F_LIQUIDACION=I.F_GENERACION
								 AND I.F_GENERACION=xF_LIQUIDACION
								 AND I.TIPO_ALTERACION IN (vLISTA_ALTERACIONES);
BEGIN
	IF (RTRIM(xALTERACION)='A') THEN vLISTA_ALTERACIONES:='A';
	ELSIF (RTRIM(xALTERACION)='B') THEN vLISTA_ALTERACIONES:='B';
	ELSIF (RTRIM(xALTERACION)='M') THEN vLISTA_ALTERACIONES:='M';
	ELSE vLISTA_ALTERACIONES:='A'',''B'',''M';
	END IF;

    ADD_COD_OPERACION(xGRUPO);

	FOR vAYTOS IN CAYTOS
	LOOP
        vMUNI:=vAYTOS.MUNICIPIO;

		FOR vLIQUIDACIONES IN cLIQUIDACIONES
		LOOP
   	   		UPDATE LIQUIDACIONES SET GRUPO=xGRUPO WHERE ID=vLIQUIDACIONES.ID;
		END LOOP;

    END LOOP;
END IBI_DOCDGC_PRINT;



/****************************************************************************************************
AUTOR: Gloria María Calle Hernández. 01/02/2002
FUNCION: Borra todas la liquidaciones para una fecha y un tipo de alteración concreta
PARAMETROS: 	xAYTO: Ayuntamiento seleccionado del cual borrar las liquidaciones
				xALTERACION: Tipo de alteraciones a borrar
				xF_LIQUIDACION: Fecha de generacion de las liquidaciones a borrar
				xNUMLIQUI: Parámetro de salida para devolver el número de liquidaciones borradas
*****************************************************************************************************/
PROCEDURE IBI_DOCDGC_DELETE (
   	 xAYTO			   IN  VARCHAR2,
   	 xALTERACION	   IN  VARCHAR2,
	 xF_LIQUIDACION	   IN  DATE,
	 xNUMLIQUI		   OUT INTEGER
) AS
  	 vLISTA_ALTERACIONES   VARCHAR2(20);
	 vID				   INTEGER;
BEGIN
	xNUMLIQUI:=0;

	IF (RTRIM(xALTERACION)='A') THEN vLISTA_ALTERACIONES:='A';
	ELSIF (RTRIM(xALTERACION)='B') THEN vLISTA_ALTERACIONES:='B';
	ELSIF (RTRIM(xALTERACION)='M') THEN vLISTA_ALTERACIONES:='M';
	ELSE vLISTA_ALTERACIONES:='A'',''B'',''M';
	END IF;

	-- Comprobacion realizada desde Delphi
    BEGIN
   	   SELECT L.ID INTO vID FROM LIQUIDACIONES L, VALORES V
 	    WHERE L.IDVALOR=V.ID AND TRUNC(L.F_LIQUIDACION,'DD')=xF_LIQUIDACION AND L.MUNICIPIO=xAYTO
   		  AND (L.F_INGRESO IS NOT NULL OR L.F_ANULACION IS NOT NULL OR L.F_SUSPENSION IS NOT NULL OR V.VOL_EJE='E')
    	  AND L.REF_CATASTRAL IN (SELECT I.REF_CATASTRAL||I.NUMERO_SECUENCIAL||I.PRIMER_CARACTER_CONTROL||I.SEGUN_CARACTER_CONTROL
					         	    FROM IBI_DOCDGC I
					        	   WHERE I.MUNICIPIO=L.MUNICIPIO AND I.F_GENERACION=TRUNC(L.F_LIQUIDACION,'DD')
					          	 	 AND I.TIPO_ALTERACION IN (vLISTA_ALTERACIONES) AND GENERADO='S');
	EXCEPTION
		WHEN NO_DATA_FOUND THEN

    		 DELETE LIQUIDACIONES L
			  WHERE TRUNC(L.F_LIQUIDACION,'DD')=xF_LIQUIDACION AND L.MUNICIPIO=xAYTO
	  			AND L.REF_CATASTRAL IN (SELECT I.REF_CATASTRAL||I.NUMERO_SECUENCIAL||I.PRIMER_CARACTER_CONTROL||I.SEGUN_CARACTER_CONTROL
	  						    		  FROM IBI_DOCDGC I
	  						   			 WHERE I.MUNICIPIO=L.MUNICIPIO AND I.F_GENERACION=TRUNC(L.F_LIQUIDACION,'DD')
							     		   AND I.TIPO_ALTERACION IN (vLISTA_ALTERACIONES) AND GENERADO='S');

			 xNUMLIQUI:=SQL%ROWCOUNT;

			 UPDATE IBI_DOCDGC SET GENERADO='N',F_GENERACION=NULL,MOTIVO=NULL
			  WHERE MUNICIPIO=xAYTO AND F_GENERACION=xF_LIQUIDACION
	  			AND TIPO_ALTERACION IN (vLISTA_ALTERACIONES) AND GENERADO='S';

	END;
END IBI_DOCDGC_DELETE;


/****************************************************************************************************
AUTOR: Gloria María Calle Hernández. 30/03/2005
FUNCION: Bonifica o Anula Bonificacion del registro
*****************************************************************************************************/
PROCEDURE IBI_DOCDGC_BONIFI(
       xID 			IN INTEGER,
	   xMESINI		IN CHAR,
       xMES 		IN CHAR,
	   xYEARINI   	IN CHAR,
       xYEAR 		IN CHAR,
       xBONI 		IN FLOAT,
       xARTICULO  	IN CHAR)
AS
BEGIN
   IF (xARTICULO IS NOT NULL) THEN
     UPDATE IBI_DOCDGC SET YEAR_INI_BONI=xYEARINI,
				  MES_INI_BONI=xMESINI,
				  YEAR_BONI=xYEAR,
                  MES_BONI=xMES,
                  BONIFICACION=xBONI,
                  ARTICULO=xARTICULO
      WHERE ID=xID;

   ELSE
     UPDATE IBI_DOCDGC SET BONIFICACION=0,
   				  YEAR_INI_BONI='0000',
   				  MES_INI_BONI='00',
   				  YEAR_BONI='0000',
   				  MES_BONI='00',
   				  ARTICULO=NULL
      WHERE ID=xID;
   END IF;

END IBI_DOCDGC_BONIFI;


END PkDocDgc;
/
