/****************************************************************************************************
AUTOR: Gloria María Calle Hernández. 01/02/2002
FUNCION: Procedimientos para el tratamiento de las alteraciones del fichero DOCDGC enviado por Catastro
*****************************************************************************************************/

CREATE OR REPLACE PACKAGE PkPlusvaNotarias
AS
  -- Corrige la tabla IBI_DOCDGC de Alteraciones Repetidas, años de efecto superior al que se liquidadará...
  PROCEDURE VALIDAR_ (
  		xYEARLIQUI	IN  VARCHAR2);
  
  -- Lee desde oracle cada campo en el fichero DOCDGC y lo inserta en la tabla IBI_DOCDGC 
  PROCEDURE READ (
		xAyto		IN  VARCHAR2,
		xFileName	IN  VARCHAR2,
		xPath		IN  VARCHAR2,
		xNumReg		OUT	INTEGER,
		xError		OUT	VARCHAR2); 

  -- Procesa cada registro de alta de la tabla de Docdgc 
  PROCEDURE GENERAR (
    	xALTERACION	IN  VARCHAR2,	   
		xFLIQUI		IN  DATE,
		xYEARLIQUI  IN  VARCHAR2,
	    xNUMLIQUI	OUT INTEGER);

  -- Procdimiento q actualiza datos del titular: dni,nombre,direccion fiscal...
  PROCEDURE MODIFY (
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
	   xTODOS				IN BOOLEAN);

  -- Crea un grupo y pega todas las liquidaciones creadas a partir del DOCDGC en una fecha concreta,
  -- para su impresión.  
  PROCEDURE PRINT (
   	   xALTERACION		    IN  VARCHAR2,	   
   	   xF_LIQUIDACION	    IN  DATE,
	   xGRUPO				OUT INTEGER);
  
  -- Borra todas la liquidaciones para una fecha y un tipo de alteración concreta
  PROCEDURE DELETE (
  	   xAYTO			  	IN  VARCHAR2,
   	   xALTERACION	   		IN  VARCHAR2,	   
	   xF_LIQUIDACION	    IN  DATE,
	   xNUMLIQUI		    OUT INTEGER	);

END PkPlusvaNotarias;
/


CREATE OR REPLACE PACKAGE BODY PkPlusvaNotarias
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
PROCEDURE READ (
	xAyto				IN  VARCHAR2,
	xFileName			IN	VARCHAR2,
	xPath				IN	VARCHAR2,
	xNumReg				OUT	INTEGER,
	xError				OUT	VARCHAR2) 
AS
  	vOutFile 	   		UTL_FILE.FILE_TYPE;
  	vReg				VARCHAR2(720);
  	vID					INTEGER;

  	--{ Registro de Cabecera }
  	vTIPO_REGISTRO			VARCHAR2(2);
  	vCOD_REG_PROPIEDAD		VARCHAR2(5);
  	vCOD_NOTARIA			VARCHAR2(9);
  	vF_GENERACION			DATE;
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
    vNUM_COTITULARES_TITU	VARCHAR2(4);
    vDESC_COTITULARIDAD		VARCHAR2(20);
    vNIF_TITU				VARCHAR2(9);
    vNOMBRE_TITU			VARCHAR2(62);
	
    --{ Domicilio del nuevo titular }
    vCOD_PROVI_INE_TITU		VARCHAR2(2);
    vCOD_MUNI_INE_TITU		VARCHAR2(3);
    vNOMBRE_MUNI_TITU		VARCHAR2(40);
    vCOD_TIPO_VIA_TITU		VARCHAR2(5);
	vNOMBRE_VIA_TITU		VARCHAR2(25);
    vNUMERO_VIA_TITU		VARCHAR2(4);
    vDUPLICADO_TITU			VARCHAR2(1);
    vBLOQUE_TITU			VARCHAR2(4);
    vESCALERA_TITU			VARCHAR2(2);
    vPLANTA_TITU			VARCHAR2(2);
    vPUERTA_TITU			VARCHAR2(3);
    vRESTO_DIRECCION_TITU	VARCHAR2(25);
    vAPROX_POSTAL_KM_TITU	VARCHAR2(6);
    vCOD_POSTAL_TITU		VARCHAR2(5);
    
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
	
	UTL_FILE.GET_LINE(vOutFile,vReg); --para saltar la línea de cabecera 
	
	vTIPO_REGISTRO:=SUBSTR(vReg,1,2);

	--{ Registro de Cabecera }
	vCOD_REG_PROPIEDAD:=SUBSTR(vReg,3,7);
    vCOD_NOTARIA:=SUBSTR(vReg,8,15);

    IF SUBSTR(vReg,17,24)='00000000' THEN
	  vF_GENERACION:=NULL;
	ELSE vF_GENERACION:=TO_DATE(SUBSTR(vReg,17,24),'YYYYMMDD');
	END IF;
    
    IF SUBSTR(vReg,25,32)='00000000' THEN
	  vF_INI_PERIODO:=NULL;
	ELSE vF_INI_PERIODO:=TO_DATE(SUBSTR(vReg,25,32),'YYYYMMDD');
	END IF;

    IF SUBSTR(vReg,33,40)='00000000' THEN
	  vF_FIN_PERIODO:=NULL;
	ELSE vF_FIN_PERIODO:=TO_DATE(SUBSTR(vReg,33,40),'YYYYMMDD');
	END IF;
    
    vCOD_PROVINCIA:=SUBSTR(vReg,41,42);
    vCOD_AYUNTAMIENTO:=SUBSTR(vReg,43,44);
    vCOD_NOTARIO:=SUBSTR(vReg,46,52);
    vNOMBRE_NOTARIO:=SUBSTR(vReg,53,96);
    
	LOOP
	BEGIN
	
	  UTL_FILE.GET_LINE(vOutFile,vReg);
	  
	  IF ((SUBSTR(vReg,1,2)='02') and (vTIPO_REGISTRO='01')) THEN
	    
		--{ Identificacion del movimiento }
	  	IF SUBSTR(vReg,3,10)='00000000' THEN
	      vF_ESCRITURA_DOC:=NULL;
	    ELSE vF_ESCRITURA_DOC:=TO_DATE(SUBSTR(vReg,3,10),'YYYYMMDD');
	    END IF;
     
	    vCLASE_ALTERACION:=SUBSTR(vReg,11,11);
	    vCUMPLIMIENTO_ARTICULO:=SUBSTR(vReg,12,12);
	    
		--{ Identificacion del bien inmueble }
	    vREF_CATASTRAL:=SUBSTR(vReg,13,32);
	    vNUM_FIJO:=SUBSTR(vReg,33,46);
	    vYEAR_PROTOCOLO:=SUBSTR(vReg,47,50);
	    vNUMERO_PROTOCOLO:=SUBSTR(vReg,51,54);
	    vVALOR_TRANSMISION:=SUBSTR(vReg,55,66);
	    vCOD_PROVINCIA_INE:=SUBSTR(vReg,67,68);
	    vCOD_MUNICIPIO_INE:=SUBSTR(vReg,69,71);
	    vNOMBRE_MUNICIPIO:=SUBSTR(vReg,72,96);
	    vNOMBRE_ENTIDAD_MENOR:=SUBSTR(vReg,97,111);
	    vTIPO_VIA:=SUBSTR(vReg,112,116);
	    vNOMBRE_VIA:=SUBSTR(vReg,117,141);
	    vNUMERO_VIA:=SUBSTR(vReg,142,145);
	    vDUPLICADO:=SUBSTR(vReg,146,146);
	    vBLOQUE:=SUBSTR(vReg,147,150);
	    vESCALERA:=SUBSTR(vReg,151,152);
	    vPLANTA:=SUBSTR(vReg,153,154);
	    vPUERTA:=SUBSTR(vReg,155,157);
		vRESTO_DIRECCION:=SUBSTR(vReg,158,182);
	    vAPROX_POSTAL_KM:=SUBSTR(vReg,183,188);
	    vCOD_POSTAL:=SUBSTR(vReg,189,193);
	
	    --{ Identificacion del transmitente }
	    vNUM_COTITULARES_TRAN:=SUBSTR(vReg,194,197);
	    vNIF_TRAN:=SUBSTR(vReg,198,206);
	    vNOMBRE_TRAN:=SUBSTR(vReg,207,268);

	    --{ Identificacion del nuevo titular }
	    vNUM_COTITULARES_TITU:=SUBSTR(vReg,269,272);
	    vDESC_COTITULARIDAD:=SUBSTR(vReg,273,292);
	    vNIF_TITU:=SUBSTR(vReg,293,301);
	    vNOMBRE_TITU:=SUBSTR(vReg,302,363);

	    --{ Domicilio del nuevo titular }
	    vCOD_PROVI_INE_TITU:=SUBSTR(vReg,364,365);
	    vCOD_MUNI_INE_TITU:=SUBSTR(vReg,366,368);
	    vNOMBRE_MUNI_TITU:=SUBSTR(vReg,369,408);
	    vCOD_TIPO_VIA_TITU:=SUBSTR(vReg,409,413);
		vNOMBRE_VIA_TITU:=SUBSTR(vReg,414,438);
	    vNUMERO_VIA_TITU:=SUBSTR(vReg,439,442);
	    vDUPLICADO_TITU:=SUBSTR(vReg,443,443);
	    vBLOQUE_TITU:=SUBSTR(vReg,444,447);
	    vESCALERA_TITU:=SUBSTR(vReg,448,449);
	    vPLANTA_TITU:=SUBSTR(vReg,450,451);
	    vPUERTA_TITU:=SUBSTR(vReg,452,454);
	    vRESTO_DIRECCION_TITU:=SUBSTR(vReg,455,479);
	    vAPROX_POSTAL_KM_TITU:=SUBSTR(vReg,480,485);
	    vCOD_POSTAL_TITU:=SUBSTR(vReg,486,490);
	    
	    -- { Domicilio del transmitente }
	    vCOD_PROVI_INE_TRAN:=SUBSTR(vReg,491,492);
	    vCOD_MUNI_INE_TRAN:=SUBSTR(vReg,493,495);
	    vNOMBRE_MUNI_TRAN:=SUBSTR(vReg,496,535);
	    vTIPO_VIA_TRAN:=SUBSTR(vReg,536,540);
	    vNOMBRE_VIA_TRAN:=SUBSTR(vReg,541,565);
	    vNUMERO_VIA_TRAN:=SUBSTR(vReg,566,569);
	    vDUPLICADO_TRAN:=SUBSTR(vReg,570,570);
	    vBLOQUE_TRAN:=SUBSTR(vReg,571,574);
	    vESCALERA_TRAN:=SUBSTR(vReg,575,576);
	    vPLANTA_TRAN:=SUBSTR(vReg,577,578);
	    vPUERTA_TRAN:=SUBSTR(vReg,579,581);
	    vRESTO_DIRECCION_TRAN:=SUBSTR(vReg,582,606);
	    vAPROX_POSTAL_KM_TRAN:=SUBSTR(vReg,607,612);
	    vCOD_POSTAL_TRAN:=SUBSTR(vReg,613,617);
	    
	    vDESC_OPERACION:=SUBSTR(vReg,618,647);
	    vCOD_OPERACION:=SUBSTR(vReg,648,657);
	
		INSERT INTO  (
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
			NIF_TRAN,NOMBRE_TRAN,COD_DEL_MEH_TRAN,COD_MUNICIPIO_DGC_TRAN,COD_PROVI_INE_TRAN,COD_MUNI_INE_TRAN,
			COD_VIA_PUBLICA_TRAN,TIPO_VIA_TRAN,NOMBRE_VIA_TRAN,PRIMER_NUMERO_TRAN,PRIMERA_LETRA_TRAN,
			SEGUNDO_NUMERO_TRAN,SEGUNDA_LETRA_TRAN,KILOMETRO_TRAN,BLOQUE_TRAN,TEXTO_DIRECCION_TRAN,ESCALERA_TRAN,
			PLANTA_TRAN,PUERTA_TRAN,COD_POSTAL_TRAN,APARTADO_CORREOS_TRAN,PAIS_TRAN,PROVINCIA_TRAN,MUNICIPIO_TRAN)
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
			/* Identificacion del TRANinatario */
			vNIF_TRAN,vNOMBRE_TRAN,vCOD_DEL_MEH_TRAN,vCOD_MUNICIPIO_DGC_TRAN,vCOD_PROVI_INE_TRAN,vCOD_MUNI_INE_TRAN,
			vCOD_VIA_PUBLICA_TRAN,vTIPO_VIA_TRAN,vNOMBRE_VIA_TRAN,vPRIMER_NUMERO_TRAN,vPRIMERA_LETRA_TRAN,
			vSEGUNDO_NUMERO_TRAN,vSEGUNDA_LETRA_TRAN,vKILOMETRO_TRAN,vBLOQUE_TRAN,vTEXTO_DIRECCION_TRAN,vESCALERA_TRAN,
			vPLANTA_TRAN,vPUERTA_TRAN,vCOD_POSTAL_TRAN,vAPARTADO_CORREOS_TRAN,vPAIS_TRAN,vPROVINCIA_TRAN,vMUNICIPIO_TRAN);
		
		xNumReg:=xNumReg+1;		 
		D;
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

END;
/



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
*****************************************************************************************************/
PROCEDURE VALIDAR (
	xYEARLIQUI			IN	VARCHAR2)
AS
	vREF_CATASTRAL		VARCHAR2(20);
	vCOUNT				INTEGER;

  	CURSOR cREG_REPETIDOS IS SELECT REF_CATASTRAL||NUMERO_SECUENCIAL||PRIMER_CARACTER_CONTROL||SEGUN_CARACTER_CONTROL 
		   				  	 	 AS REF_CATASTRAL,COUNT(*) AS xCOUNT
							   FROM IBI_DOCDGC WHERE GENERADO<>'E' 
						   GROUP BY REF_CATASTRAL||NUMERO_SECUENCIAL||PRIMER_CARACTER_CONTROL||SEGUN_CARACTER_CONTROL,
						  		    TIPO_ALTERACION HAVING COUNT(*)>1;
	
	CURSOR cIDs_REPETIDOS IS SELECT ID FROM IBI_DOCDGC 
		   				 	  WHERE REF_CATASTRAL||NUMERO_SECUENCIAL||PRIMER_CARACTER_CONTROL||SEGUN_CARACTER_CONTROL=vREF_CATASTRAL
							    AND GENERADO<>'E' 
						   ORDER BY FECHA_FIRMA;

	CURSOR cIDs_YEARMAYOR IS SELECT ID,GENERADO,YEAR_EFECTOS_IBI FROM IBI_DOCDGC 
		   				 	  WHERE GENERADO<>'S'; 

BEGIN
	--Validamos q el año de efectos sea igual o inferior al q estamos liquidando, si fuere mayor no se liquidaria 
	FOR vIDs_YEARMAYOR IN cIDs_YEARMAYOR
	LOOP
		IF vIDs_YEARMAYOR.YEAR_EFECTOS_IBI>xYEARLIQUI THEN 
	       UPDATE IBI_DOCDGC SET GENERADO='E',MOTIVO='AÑO EFECTOS SUPERIOR AL DE LIQUIDACIÓN',F_GENERACION=TRUNC(SYSDATE,'DD')
	       WHERE ID=vIDs_YEARMAYOR.ID;
	    ELSIF vIDs_YEARMAYOR.GENERADO='E' THEN
	       UPDATE IBI_DOCDGC SET GENERADO='N',MOTIVO=NULL,F_GENERACION=NULL
	       WHERE ID=vIDs_YEARMAYOR.ID;
	    END IF;
	END LOOP;

	--Validamos q no haya registros repetidos para el mismo bien inmueble...
	FOR vREG_REPETIDOS IN cREG_REPETIDOS 
	LOOP
		vREF_CATASTRAL:= vREG_REPETIDOS.REF_CATASTRAL;
		vCOUNT:= vREG_REPETIDOS.xCOUNT; 
		FOR vIDs_REPETIDOS IN cIDs_REPETIDOS
		LOOP
			WHILE vCOUNT>1 LOOP
			   UPDATE IBI_DOCDGC SET GENERADO='E',MOTIVO='ALTERACIÓN REPETIDA',F_GENERACION=TRUNC(SYSDATE,'DD')
			   WHERE ID=vIDs_REPETIDOS.ID;
			   vCOUNT:=vCOUNT-1;
			   --Actualizamos todos menos el ultimo 
			END LOOP; -- WHILE  
		END LOOP; 
	END LOOP;
END VALIDAR;



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
MODIFICADO: 25/05/2006. Lucas Fernández Pérez. Adaptación al nuevo formato de RUSTICA, se elimina en la llamada 
			a ADD_LIQUI los parámetros XPARCELA y XCODPOLIGONO, a los que se llamaba con valores null.
MODIFICADO: 09/06/2006. Lucas Fernández Pérez. Si la bonificacion es del 0% no se mete en objeto_tributario
	(por problemas de espacio, que es reducido en los preimpresos)
*****************************************************************************************************/
PROCEDURE GENERAR (
    xALTERACION			IN  VARCHAR2,	   
	xFLIQUI				IN  DATE,
	xYEARLIQUI			IN  VARCHAR2,
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
		
	CURSOR CAYTOS IS SELECT MUNICIPIO FROM TMP_AYTOS WHERE USUARIO=USER;
	
	CURSOR cLIQUIDOC IS SELECT * FROM IBI_DOCDGC 
						WHERE MUNICIPIO=vMUNI AND YEAR_EFECTOS_IBI <= xYEARLIQUI
						AND TIPO_ALTERACION IN (vLISTA_ALTERACIONES)
						AND GENERADO='N' 
	FOR UPDATE; 	
	
BEGIN

	VALIDAR(xYEARLIQUI);

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
	    IF VALIDAR_PARAMSAYTO(vMUNI,vGENERADO,vMOTIVO,vCONCEP,vYEARP,vNUMYEARS) THEN

		  -- Cursor sobre los registros de la tabla IBI_DOCDGC 
		  FOR vLIQUIDOC IN cLIQUIDOC LOOP
			/* Comprobamos q el contribuyente exista en nuestra base de datos, 
			   insertandolo en su defecto */
   			SELECT COUNT(*) INTO vCOUNT FROM CONTRIBUYENTES 
			WHERE RTRIM(NIF)=RTRIM(vLIQUIDOC.NIF);
			IF (vCOUNT=0) THEN
  			    INSERTAMODICONTRIBUYENTE(vLIQUIDOC.NIF,SUBSTR(RTRIM(vLIQUIDOC.NOMBRE),1,40),
										 SUBSTR(RTRIM(vLIQUIDOC.TIPO_VIA_FISCAL),1,2),vLIQUIDOC.NOMBRE_VIA_FISCAL,
										 vLIQUIDOC.PRIMER_NUMERO_FISCAL,vLIQUIDOC.ESCALERA_FISCAL,
										 vLIQUIDOC.PLANTA_FISCAL,SUBSTR(RTRIM(vLIQUIDOC.PUERTA_FISCAL),1,2),
										 vLIQUIDOC.MUNICIPIO_FISCAL,vLIQUIDOC.PROVINCIA,vLIQUIDOC.COD_POSTAL_FISCAL,
										 vLIQUIDOC.PAIS);
			END IF;
						   		
			-- Comprobamos q el Año de Efectos no sea inferior a cuatro años atrás 
   			-- número máximo de años a liquidar atrás en el tiempo legalmente   
   			vYEAR_EFECTOS:= vLIQUIDOC.YEAR_EFECTOS_IBI;
   			IF vYEAR_EFECTOS<(TO_CHAR(SYSDATE,'YYYY')-4) THEN
      		   vYEAR_EFECTOS:= TO_CHAR(SYSDATE,'YYYY')-4;
   			END IF;

			/* Si year_efectos es el año de liquidacion llamamos a MAKELIQUIDOC_IDEMYEAR, 
			   q crea la liquidacion sin tanto calculo en este caso innecesario. 
			   Tambien si lo q queremos es imprimir las liquidaciones en lugar de generarlas,
			   llamamos a MAKELIQUIDOC_IDEMYEAR. */
			IF (vYEAR_EFECTOS=xYEARLIQUI) THEN 
			    IDEMYEAR(xFLIQUI,xYEARLIQUI,vLIQUIDOC);
				xNUMLIQUI:=xNUMLIQUI+1;
			ELSE -- Montar referencia catastral 
				vREF_CATASTRAL:=vLIQUIDOC.REF_CATASTRAL||vLIQUIDOC.NUMERO_SECUENCIAL||
             			  		vLIQUIDOC.PRIMER_CARACTER_CONTROL||vLIQUIDOC.SEGUN_CARACTER_CONTROL;
			
				FILL_TMP_ATRASOS(vYEARP,xYEARLIQUI,vNUMYEARS,vLIQUIDOC);
			
				/* Comprobamos q se hayan encontrado e insertados datos para 
				   poder generar la liquidacion. */
				SELECT COUNT(*) INTO vCOUNT FROM TMP_ATRASOS_IBI WHERE USUARIO=UID;
				IF vCOUNT=0 THEN
				   vGENERADO:= 'E';
				   vMOTIVO:= 'NO HAY DATOS PARA GENERAR LA LIQUIDACION';
				   GOTO Next_Liqui;
				END IF;
			
				LIQUIDAR_ATRASOS_IBI(vYEARP,vYEAR_EFECTOS,vNUMYEARS);
			
				/* Comprobamos si en recaudacion existen recibos pagados correspondientes 
   				   a este concepto entre los años elegidos. */
          		SELECT SUM(I.PRINCIPAL+I.RECARGO+I.COSTAS+I.DEMORA) INTO vINGRESADO 
   	      		  FROM IMPORTE_INGRESOS I, VALORES V 
       	  		 WHERE I.VALOR=V.ID AND V.YEAR BETWEEN vYEAR_EFECTOS
				   AND xYEARLIQUI AND V.CLAVE_CONCEPTO=vREF_CATASTRAL;
				IF vINGRESADO IS NULL THEN 
				   vINGRESADO:=0;
				END IF;
				
		    	/* Calcular el total de la liquidación. Nunca esta sentencia causará excepcion 
			       puesto q anteriormente hemos comprobado q existian datos en dicha tabla */
				SELECT SUM(TOTAL)-vINGRESADO INTO vTOTAL FROM TMP_ATRASOS_IBI
				WHERE USUARIO=UID AND YEAR BETWEEN vYEAR_EFECTOS AND xYEARLIQUI;
				IF vTOTAL IS NULL THEN 
				   vTOTAL:=0;
				END IF;

		    	/* Crear el motivo para la liquidacion */
				vOBJ_TRIBU:='REF. CATASTRAL: '||vREF_CATASTRAL||
							'  NÚM. FIJO: '||vLIQUIDOC.NUM_FIJO||
						    '  V. CATASTRAL: '||vLIQUIDOC.VALOR_CATASTRAL||CHR(13)||
						    'IMPORTE DE LA LIQUIDACIÓN DESGLOSADO: '||CHR(13);

				FOR vATRASOS_IBI IN (SELECT * FROM TMP_ATRASOS_IBI 
								 	  WHERE USUARIO=UID AND YEAR BETWEEN vYEAR_EFECTOS AND xYEARLIQUI 
									  ORDER BY YEAR DESC) LOOP
				    vOBJ_TRIBU:=vOBJ_TRIBU||'AÑO:'||vATRASOS_IBI.YEAR||'   BASE LIQUIDABLE='||
	   							LTRIM(TO_CHAR(vATRASOS_IBI.BLIQUIDABLE,'999G999D99'))||' Euros'||
            			        '   GRAVAMEN APLICADO='||LTRIM(TO_CHAR(vATRASOS_IBI.GRAVAMEN,'0D999'))||' %';
					IF (vATRASOS_IBI.BONIFICACION<>0) THEN
              		vOBJ_TRIBU:=vOBJ_TRIBU||'   BONIFICACIÓN EN '||TO_CHAR(vATRASOS_IBI.BONIFICACION,'900')||' %'||
							       ' MESES:'||TO_CHAR(vATRASOS_IBI.MESES_BONI);
					END IF;
            		vOBJ_TRIBU:=vOBJ_TRIBU||'   CUOTA='||LTRIM(TO_CHAR(vATRASOS_IBI.TOTAL,'999G999D99'))||' Euros'||CHR(13);
				END LOOP;

				IF vINGRESADO>0 THEN
				   vOBJ_TRIBU:=vOBJ_TRIBU||CHR(13)||'     INGRESADO YA EN RECAUDACIÓN: '||LTRIM(TO_CHAR(vINGRESADO,'999G999D99'))||' Euros';
				END IF;

				-- Añadir la liquidacion
				ADD_LIQUI(vMUNI,vCONCEP,xYEARLIQUI,'00',xYEARLIQUI,vLIQUIDOC.NIF,NULL,
						  RTRIM(vLIQUIDOC.TIPO_VIA)||' '||RTRIM(vLIQUIDOC.NOMBRE_VIA)||' '||
						  RTRIM(vLIQUIDOC.PRIMER_NUMERO)||' '||RTRIM(vLIQUIDOC.BLOQUE)||' '||
						  RTRIM(vLIQUIDOC.ESCALERA)||' '||RTRIM(vLIQUIDOC.PLANTA)||' '||RTRIM(vLIQUIDOC.PUERTA),
						  xFLIQUI,GETFINPEVOL(vMUNI),vTOTAL,vOBJ_TRIBU,vREF_CATASTRAL,
						  vLIQUIDOC.NUM_FIJO,vLIQUIDOC.REF_EXPEDIENTE,NULL,NULL,vNUMERO_LIQUI,vID_LIQUI);
						  
				vGENERADO:= 'S';
				vMOTIVO:= 'GENERADA LA LIQUIDACION COMO ALTA - AÑO EFECTO DIFENTE DEL AÑO LIQUIDACIÓN';
				xNUMLIQUI:=xNUMLIQUI+1;
		
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
END GENERAR;





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
*****************************************************************************************************/
PROCEDURE MODIFY (
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
	   xTODOS				IN BOOLEAN)       
AS
	   vNIF 				CHAR(10);    
       vREGISTRO			IBI_DOCDGC%ROWTYPE;

       /* Cursor que recorre todos los registros para el mismo nif anterior actualizando
       	  sus datos fiscales. */
       CURSOR cIBIDOC IS SELECT * FROM IBI_DOCDGC WHERE NIF=vNIF
	   FOR UPDATE OF NIF,NOMBRE,TIPO_VIA_FISCAL,NOMBRE_VIA_FISCAL,PRIMER_NUMERO_FISCAL,PRIMERA_LETRA_FISCAL,BLOQUE_FISCAL,
	   	   		     ESCALERA_FISCAL,PLANTA_FISCAL,PUERTA_FISCAL,COD_POSTAL_FISCAL,MUNICIPIO_FISCAL,PROVINCIA,PAIS,
					 PRIMER_NUMERO,PRIMERA_LETRA,BLOQUE,ESCALERA,PLANTA,PUERTA,CODIGO_POSTAL;
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
                       			CODIGO_POSTAL=xCPT
	   WHERE ID=xID;
  END IF;
END MODIFY;



/****************************************************************************************************
AUTOR: Gloria María Calle Hernández. 01/02/2002
FUNCION: Crea un grupo y pega todas las liquidaciones creadas a partir del DOCDGC en una fecha concreta, 
		 para su impresión. 
PARAMETROS: 	xALTERACION: Tipo de alteraciones a imprimir  
				xF_LIQUIDACION: Fecha de generacion de las liquidaciones a imprimir
				xGRUPO: Parámetro de salida para devolver el grupo creado e imprimirlo 
*****************************************************************************************************/
PROCEDURE PRINT (
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
	ELSE vLISTA_ALTERACIONES:='A'',''B'',''C';
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
END PRINT;



/****************************************************************************************************
AUTOR: Gloria María Calle Hernández. 01/02/2002
FUNCION: Borra todas la liquidaciones para una fecha y un tipo de alteración concreta 
PARAMETROS: 	xAYTO: Ayuntamiento seleccionado del cual borrar las liquidaciones 
				xALTERACION: Tipo de alteraciones a borrar  
				xF_LIQUIDACION: Fecha de generacion de las liquidaciones a borrar
				xNUMLIQUI: Parámetro de salida para devolver el número de liquidaciones borradas 
*****************************************************************************************************/
PROCEDURE DELETE (
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
	ELSE vLISTA_ALTERACIONES:='A'',''B'',''C';
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
END DELETE;

END PkPlusvaNotarias;
/
