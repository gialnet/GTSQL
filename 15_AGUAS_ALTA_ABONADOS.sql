/*******************************************************************************
Acción: Leer todos los servicios de un determinado abonado.
*******************************************************************************/

CREATE OR REPLACE PROCEDURE LEER_SERVICIOS_ABONADO(
       xABONADO	IN	INTEGER,
	 xMunicipio	In	Char)
AS
BEGIN
	
	INSERT INTO TMP_SERVICIOS
	  (TARIFA,TIPO_TARIFA,Municipio)
       SELECT TARIFA,TIPO_TARIFA,xMunicipio FROM SERVICIOS
	   WHERE ABONADO=xABONADO and Municipio=xMunicipio;

END;
/

/*******************************************************************************
Acción: Para poder introducir tarifas antes de dar de alta a un abonado
	  y mas tarfe traspasarle estos servicios al nuevo abonado
*******************************************************************************/

CREATE OR REPLACE PROCEDURE INSERTA_TMP_SERVICIOS(
	 xMunicipio in    char,
       xTARIFA	IN	CHAR, 
       xTIPO	IN	CHAR)
AS 
	
BEGIN

  INSERT INTO TMP_SERVICIOS
      (Municipio,TARIFA,TIPO_TARIFA)	
  VALUES
      (xMunicipio,xTARIFA,xTIPO);
 	
END;
/

/*******************************************************************************
Acción: Borrar un servicio del temporal de servicios.
*******************************************************************************/

CREATE OR REPLACE PROCEDURE DEL_TMP_SERVICIOS(
	 xMUNICIPIO IN    CHAR,
       xTARIFA	IN	CHAR
)
AS 

BEGIN

   DELETE FROM TMP_SERVICIOS 
   WHERE USUARIO=USER AND TARIFA=xTARIFA
	AND MUNICIPIO=xMUNICIPIO;
END;
/

/*******************************************************************************
Acción: Limpia los datos del temporal de servicios.
*******************************************************************************/

CREATE OR REPLACE PROCEDURE INICIA_TMP_SERVICIOS
AS
BEGIN
   DELETE FROM TMP_SERVICIOS 
   WHERE USUARIO=USER;
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
MODIFICACION: 08/07/2002 M. Carmen Junco Gómez. El recibo de agua sólo se podrá modificar
		  si aún no se ha emitido el Cuaderno19 para el padrón al que pertenece.
		  Además, cuando modificamos en recaudación, debemos tener en cuenta si el
		  cargo se ha aceptado o no. Si aún no se ha aceptado habrá que hacer la
		  modificación en la tabla PUNTEO y no en VALORES.
MODIFICACIÓN: 03/12/2002 M. Carmen Junco Gómez. Insertamos los campos MUNICIPIO y 
		  PERIODO en LOGSPADRONES.
MODIFICACIÓN: 10/03/2005 M. Carmen Junco Gómez. Hasta ahora se comprobaban los recibos emitidos 
		  en el año en curso, de tal forma que no hacía la modificación del recibo si el padrón se
		  emitió el año anterior al actual. Lo que haremos será revisar los recibos emitidos desde
		  hace un año al día de hoy. 		  
MODIFICACIÓN: 18/07/2006 Lucas Fernández Pérez. En la búsqueda del recibo en valores y punteo
	no estaba en la condicion "TIPO_DE_OBJETO='R'" 
********************************************************************************/

CREATE OR REPLACE PROCEDURE AGUA_BANCOS(
       xABONADO			IN INTEGER,
	   xDOMICILIADO		IN CHAR,
       xENTIDAD 		IN CHAR,
       xSUCURSAL 		IN CHAR,
       xDC 				IN CHAR,
       xCUENTA 			IN CHAR,
	   xF_DOMICILIACION IN DATE,
       xTITULAR 		IN CHAR)
AS
	mVOL_EJE Char(1);
	mVALOR   Integer;
	mPUNTEO  Integer;
	mPADRON CHAR(6);
	xNOMBRE_TITULAR CHAR(40);
	xCuantos Integer;

   	mSUCURSAL  	  	char(4);
   	mDC		  	char(2);
   	mCUENTA	      char(10);
   	mF_DOMICILIACION 	Date;
   	mTITULAR	      char(10);

	-- cursor que recorre los distintos períodos de los distintos recibos que 
	-- se han podido emitir para este abonado, desde hace un año a la fecha de hoy,
	-- para comprobar para qué padrón se ha emitido ya el Cuaderno19, y por lo tanto 
	-- no modificar la domiciliación	de ese recibo.
	CURSOR CPERIODOS IS SELECT DISTINCT YEAR,PERIODO,ID,MUNICIPIO FROM RECIBOS_AGUA
				  WHERE ABONADO=xABONADO AND YEAR BETWEEN (TO_CHAR(sysdate,'yyyy')-1) AND TO_CHAR(sysdate,'yyyy');		

BEGIN

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
	end if;
  

	-- se actualiza en la tabla AGUA
	UPDATE AGUA SET DOMICILIADO=xDOMICILIADO,
			    ENTIDAD=xENTIDAD,
             SUCURSAL=mSUCURSAL,
             DC=mDC,CUENTA=mCUENTA,
			    F_DOMICILIACION=mF_DOMICILIACION,
			    DNI_TITULAR=mTITULAR
	WHERE ID=xABONADO;

	-- por cada periodo y año distintos de recibos sobre el abonado
	FOR vPERIODOS IN CPERIODOS 
	LOOP	 
         -- Comprobamos si se ha emitido ya el soporte del cuaderno 19
	   SELECT COUNT(*) INTO xCUANTOS FROM LOGSPADRONES 
	   WHERE MUNICIPIO=vPERIODOS.MUNICIPIO AND 
		     PROGRAMA ='AGUA' AND
	         PYEAR=vPERIODOS.YEAR AND
		     PERIODO=vPERIODOS.PERIODO AND
	         HECHO='Generación Cuaderno 19 (recibos domiciliados)';

	   IF xCUANTOS=0 THEN  -- aún no se ha emitido. Podemos modificar el recibo.

		-- Averiguar el código de padron de AGUA
		SELECT CONCEPTO INTO mPADRON FROM PROGRAMAS WHERE PROGRAMA='AGUA';
		
		-- Comprobar si ya se paso a recaudación    
		begin
	   		SELECT ID,VOL_EJE INTO mVALOR,mVOL_EJE FROM VALORES 
         	 WHERE AYTO=vPERIODOS.MUNICIPIO AND PADRON=mPADRON AND
		   		   YEAR=vPERIODOS.YEAR AND PERIODO=vPERIODOS.PERIODO AND RECIBO=xABONADO AND TIPO_DE_OBJETO='R';
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

		-- si el recibo está en Voluntaria en RECA o todavia no se ha pasado a recaudación
		IF ((mVOL_EJE='V') or (mVOL_EJE IS NULL)) THEN

	   		-- modificamos el recibo en gestión tributaria
	   		IF xDOMICILIADO='N' THEN
	      		UPDATE RECIBOS_AGUA SET DOMICILIADO='N',
							      ENTIDAD=NULL,
							      SUCURSAL=NULL,
							      DC=NULL,
							      CUENTA=NULL,
							      F_DOMICILIACION=NULL,
							      DNI_TITULAR=NULL,
							      NOMBRE_TITULAR=NULL,
							      ESTADO_BANCO=NULL
				WHERE ID=vPERIODOS.ID;
			ELSE
				SELECT SUBSTR(NOMBRE,1,40) INTO xNOMBRE_TITULAR 
				FROM CONTRIBUYENTES WHERE NIF=xTITULAR;

			      UPDATE RECIBOS_AGUA SET DOMICILIADO='S',
							      ENTIDAD=xENTIDAD,
							      SUCURSAL=mSUCURSAL,
							      DC=mDC,
							      CUENTA=mCUENTA,
							      F_DOMICILIACION=mF_DOMICILIACION,
							      DNI_TITULAR=mTITULAR,
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

/*******************************************************************************
Acción: Insertar un nuevo abonado.
MODIFICACIÓN: 30/08/2001 Antonio Pérez Caballero.
MODIFICACIÓN: 17/09/2001 Lucas Fernández Pérez. Adaptación al euro.
MODIFICACIÓN: 25/06/2002 M. Carmen Junco Gómez. Comprueba si hay recibo emitido 
              del padrón anual en curso y en tal caso modifica los datos de la 
              domiciliación para que entre en los soportes del cuaderno 19
Modificacion: 03/12/2003. Agustín León Robles.
			Se añaden 2 liquidaciones en la tabla de liquidaciones si el usuario así lo quiere.
			Una por el contrato de alta y la otra por la fianza
Modificación: 15/05/2006. M. Carmen Junco Gómez. Adaptación al nuevo formato de RUSTICA
*******************************************************************************/

CREATE OR REPLACE PROCEDURE Inserta_Abonados_Agua(
	xABONADO			IN 		INTEGER,
	xMunicipio			IN    	CHAR,
	xCod_Postal			IN 		CHAR,
	xDomi				IN		CHAR,
	xNIF				IN		CHAR, 
	xDNI_FACTURA 		IN		CHAR,
	xDNI_REPRE			IN		CHAR,
	xCODIGO_CALLE		IN    	CHAR,
	xNUMERO				IN		CHAR, 
	xBLOQUE				IN		CHAR, 
	xESCALERA			IN		CHAR, 
	xPLANTA				IN		CHAR, 
	xPISO				IN		CHAR, 
	xLETRA				IN		CHAR,

	xCALIBRE			IN		CHAR, 
	xVIVIENDAS			IN		INTeger,
	xHABITACIONES		IN		INTeger,
 	xCONTADOR			IN		CHAR, 
	xSI_FECHA			IN		CHAR,
	xFECHA_CONTADOR		IN		DATE,

	xFECHA_ALTA			IN		DATE,
	xLIBRO				IN		CHAR, 
	xORDEN				IN		CHAR, 
	xLUGAR 				IN		VARCHAR, 
	xID_EPIGRAFE		IN		INTEGER,
      xSECCION			IN		CHAR,
	xEPIGRAFE 			IN		CHAR,

	xDNI_TITULAR		IN		CHAR,
	xENTIDAD			IN		CHAR, 
	xSUCURSAL			IN		CHAR, 
	xDC					IN		CHAR, 
	xCUENTA				IN		CHAR,
	xF_DOMICILIACION	IN		DATE,

	xTIPO_CONTADOR		IN		CHAR,
	xTIPO_CONTRATO		IN		CHAR,
	xDURACION 			IN		CHAR,
	xF_TERMINACION 		IN		DATE,
	xCON_DNI 			IN		CHAR,
	xDISPONIBILIDAD 	IN		CHAR,
	xPERMISO_OBRA 		IN		CHAR,
	xPRI_OCUPACION 		IN		CHAR,
	xMEMORIA_TECNICA 	IN		CHAR,
	xSERVIDUMBRE 		IN		CHAR,
	xOTROS 				IN		CHAR,
	xCAUDAL_INSTALADO 	IN		CHAR,
	xTIPO_SUMINISTRO 	IN		CHAR,
	xCAUDAL_CONTRATADO	IN		CHAR,
	xPRESION 			IN		CHAR,
	xACOMETIDA_INTERIOR	IN		CHAR,
	xACOMETIDA_EXTERIOR IN		CHAR,
	xNUMERO_BOLETIN 	IN		CHAR,
	xNUMERO_INSTALADOR 	IN		CHAR,
	xCUOTA_CONTRATACION IN		FLOAT,
	xDERECHOS_INSTALACION 	IN		FLOAT,
	xFIANZA 				IN		FLOAT,
	xIVA 					IN		FLOAT,
	xPOZO_J_INMUEBLE 		IN		CHAR,
	xPOZO_COLECTOR 			IN		CHAR,
	xPOZO_I_INMUEBLE 		IN		CHAR,
	xVERTIDO_ADMISIBLE 		IN		CHAR,
	xCALIBRE_ACOMETIDA_EXT 	IN		CHAR,
	xCALIBRE_ACOMETIDA_INT 	IN		CHAR,
	xEXPEDIENTE 			IN		CHAR,
	xIDAlternativo    		IN		INTEGER,
	xSiGeneraLiqui			IN		CHAR)
AS
   xCOMO        		INTEGER;
   xID          		INTEGER;   
   xIDLiquiFianza		integer;
   xIDLiqui				integer;
   xRECIBO		 		CHAR(7); --NO SE UTILIZA PARA NADA
   xMOTIVO	       		VARCHAR2(1024);
   xCONCEPTO			CHAR(6);	
   xTOTAL				FLOAT;
   xDOM_SUMINISTRO		VARCHAR2(60);
   xCALLE_SUMINISTRO	VARCHAR(25);
   xFinPeVol			date;
   xDias				integer;
      
   
BEGIN

	SELECT dias_vencimiento,COMO_INSERTO_AGUA INTO xDias,xCOMO FROM DATOSPER WHERE MUNICIPIO=xMUNICIPIO;

	-- El 0 es que lo crea automáticamente el programa
	IF (xCOMO=0) THEN
		xID:=0;
	ELSE
		xID:=xABONADO;
	END IF;   
  
	-- si en la configuración está que lo crea automáticamente el programa,
	-- el xAbonado será nulo y en el trigger se controla
	
	IF xSiGeneraLiqui='S' THEN		
		
		SELECT CALLE INTO xCALLE_SUMINISTRO FROM CALLES
		WHERE CODIGO_CALLE=xCODIGO_CALLE and municipio=xMunicipio;	
		
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
		
		xDOM_SUMINISTRO:=RTRIM(xCALLE_SUMINISTRO)||' '||xNUMERO||' '||xBLOQUE||' '||
				xESCALERA||' '||xPLANTA||' '||xPISO||' '||xLETRA;
	
		--se genera 2 liquidaciones :
		--La primera liquidacion por la cuota de contratacion
		--Y la segunda liquidacion es por la Fianza		
		
		--se añadiran la liquidaciones siempre que tenga importe, porque puede ser que algunos abonados
		--no tengan fianza o no tenga cuota de contratacion
		if xCUOTA_CONTRATACION > 0 then
		
			SELECT CODIGO INTO xCONCEPTO FROM AGUACOD_TARIFA 
			WHERE MUNICIPIO=xMUNICIPIO AND DESCRIPCION='LIQ. POR ALTAS';
		
			xMOTIVO:='ALTA DE CONTRATO DE AGUA '||'N.CONTADOR: '|| xCONTADOR || ' EXPEDIENTE: '|| xEXPEDIENTE;	
		
			ADD_LIQUI(xMUNICIPIO,xCONCEPTO,TO_CHAR(xFECHA_ALTA,'YYYY'),'00',TO_CHAR(xFECHA_ALTA,'YYYY'),
				xNIF, xDNI_REPRE, xDOM_SUMINISTRO, xFECHA_ALTA, xFinPeVol,
				xCUOTA_CONTRATACION, xMOTIVO,'','',xEXPEDIENTE,null,0,xRECIBO,xIDLiqui);
		end if;
			
		if xFIANZA > 0 then
		
			SELECT CODIGO INTO xCONCEPTO FROM AGUACOD_TARIFA 
			WHERE MUNICIPIO=xMUNICIPIO AND DESCRIPCION='LIQ. POR FIANZA EN ALTAS';
			
			xMOTIVO:='FIANZA '||'N.CONTADOR: '|| xCONTADOR || ' EXPEDIENTE: '|| xEXPEDIENTE;	
		
			ADD_LIQUI(xMUNICIPIO,xCONCEPTO,TO_CHAR(xFECHA_ALTA,'YYYY'),'00',TO_CHAR(xFECHA_ALTA,'YYYY'),
				xNIF, xDNI_REPRE, xDOM_SUMINISTRO, xFECHA_ALTA, xFinPeVol,
				xFIANZA, xMOTIVO,'','',xEXPEDIENTE,null,0,xRECIBO,xIDLiquiFianza);
		end if;			
		
	ELSE
		xIDLiqui:=null;
		xIDLiquiFianza:=null;
	
	END IF;
	
	
	INSERT INTO AGUA 
		(ID,municipio,NIF,DNI_FACTURA,DNI_REPRESENTANTE,CODIGO_CALLE,NUMERO,
		BLOQUE,ESCALERA,PLANTA,PISO,LETRA,CALIBRE,VIVIENDAS,HABITACIONES,CONTADOR,
		FECHA_CONTADOR,FECHA_ALTA,LIBRO,ORDEN,LUGAR,ID_EPIGRAFE,SECCION,EPIGRAFE,
		TIPO_CONTADOR,TIPO_CONTRATO,DURACION,F_TERMINACION,CON_DNI,DISPONIBILIDAD,
		PERMISO_OBRA,PRI_OCUPACION,MEMORIA_TECNICA,SERVIDUMBRE,OTROS,CAUDAL_INSTALADO,
		TIPO_SUMINISTRO,CAUDAL_CONTRATADO,PRESION,ACOMETIDA_INTERIOR,ACOMETIDA_EXTERIOR,
		NUMERO_BOLETIN,NUMERO_INSTALADOR,CUOTA_CONTRATACION,DERECHOS_INSTALACION,
		FIANZA,IVA,POZO_J_INMUEBLE,POZO_COLECTOR,POZO_I_INMUEBLE,VERTIDO_ADMISIBLE,
		CALIBRE_ACOMETIDA_EXT,CALIBRE_ACOMETIDA_INT,EXPEDIENTE,COD_POSTAL,IDDOMIALTER,LIQUIDACION,LIQUIFIANZA)
	VALUES
		(xID,substr(xMunicipio,1,3),xNIF,xDNI_FACTURA,xDNI_REPRE,rtrim(xCODIGO_CALLE),
		xNUMERO,xBLOQUE,xESCALERA,xPLANTA,xPISO,xLETRA,xCALIBRE,xVIVIENDAS,xHABITACIONES,
		xCONTADOR,xFECHA_CONTADOR,xFECHA_ALTA,xLIBRO,xORDEN,xLUGAR,xID_EPIGRAFE,xSECCION,
		xEPIGRAFE,xTIPO_CONTADOR,xTIPO_CONTRATO,
		xDURACION,xF_TERMINACION,xCON_DNI,xDISPONIBILIDAD, xPERMISO_OBRA,xPRI_OCUPACION,
		xMEMORIA_TECNICA,xSERVIDUMBRE,xOTROS,xCAUDAL_INSTALADO, xTIPO_SUMINISTRO,
		xCAUDAL_CONTRATADO,xPRESION,xACOMETIDA_INTERIOR,xACOMETIDA_EXTERIOR,xNUMERO_BOLETIN,
		xNUMERO_INSTALADOR,ROUND(xCUOTA_CONTRATACION,2),ROUND(xDERECHOS_INSTALACION,2),
		ROUND(xFIANZA,2),ROUND(xIVA,2),xPOZO_J_INMUEBLE,xPOZO_COLECTOR,xPOZO_I_INMUEBLE,
		xVERTIDO_ADMISIBLE,xCALIBRE_ACOMETIDA_EXT,xCALIBRE_ACOMETIDA_INT,xEXPEDIENTE,
		xCod_Postal,DECODE(xIDAlternativo,0,NULL,xIDAlternativo),xIDLiqui,xIDLiquiFianza)
	
	RETURNING ID INTO xID;

	-- Comprobar domiciliación del pago
	AGUA_BANCOS(xID,xDOMI,xENTIDAD,xSUCURSAL,xDC,xCUENTA,xF_DOMICILIACION,xDNI_TITULAR);

	INSERT INTO SERVICIOS (ABONADO,MUNICIPIO,TARIFA,TIPO_TARIFA)
	SELECT xID, substr(xMunicipio,1,3), TARIFA, TIPO_TARIFA 	
	FROM TMP_SERVICIOS WHERE USUARIO=USER;

END;
/

/*******************************************************************************
Acción: Modificación de los datos de un abonado de agua.
MODIFICACIÓN: 30/08/2001 Antonio Pérez Caballero.
MODIFICACIÓN: 17/09/2001 Lucas Fernández Pérez. Adaptación al euro.
MODIFICACIÓN: 25/06/2002 M. Carmen Junco Gómez. Comprueba si hay recibo emitido 
              del padrón anual en curso y en tal caso modifica los datos de la 
              domiciliación para que entre en los soportes del cuaderno 19
Modificacion: 17/12/2003. Lucas Fernández Pérez.
			Actualiza el nuevo campo Nif_Anterior si en la modificación cambia el titular.
			Nuevo parámetro xSiGeneraLiqui. Con valor 'S' se genera una liquidacion
			por cambio de titularidad. 
			IMPORTANTE: El concepto de la liquidación por cambio de titularidad se toma
							de la tabla de programas, y la tarifa será la 0001 SIEMPRE.
MODIFICACIÓN: 23/12/2003. Actualiza el campo NIF_REPRESENTANTE, que se pasaba como 
			parámetro pero no se actualizaba en la tabla AGUA
MODIFICACION: 02/02/2004. Gloria Maria Calle Hernandez. 
			Eliminada llamada a MOD_TRIBUTOS_CONTRI, pues la tabla TributosContri a la cual
			actualizaba pasa a rellenarse como una tabla temporal y dicho procedimiento ha sido eliminado
MODIFICACIÓN: 31/01/2005 M. Carmen Junco Gómez. Se añade un parámetro TEXTO que contendrá el motivo del
			cambio en la titularidad del impuesto (cambio de titular, facturar a o representante). Este parámetro
			se almacena en el campo TEXTO de la tabla usuariosgt, para después recogerlo en el trigger que hace
			el insert en el histórico de motivos de cambios de titularidad.
MODIFICACIÓN: 31/01/2005 M. Carmen Junco Gómez. Se elimina el campo NIF_ANTERIOR de la tabla AGUA. Esta 
			información se almacenará ahora en la tabla MOTIVOS_CAMBIO_TITULARIDAD.
MODIFICACIÓN: 31/01/2005 Lucas Fernandez Pérez. Se eliminan los campos USR_CHG_ CUENTA y F_CHG_ CUENTA
			La información se almacenará ahora en la tabla HISTO_DOMICILIACIONES.			
MODIFICACIÓN: 15/05/2006 M. Carmen Junco Gómez. Adaptación al nuevo formato de RUSTICA
*******************************************************************************************/

CREATE OR REPLACE PROCEDURE Modifica_Abonados_Agua (
	xABONADO				IN	INTEGER,
	xMunicipio			IN CHAR,
	xCod_Postal			IN CHAR,
	xDomi 				IN	CHAR,
	xNIF					IN	CHAR, 
	xDNI_FACTURA 		IN	CHAR,
	xDNI_REPRE 			IN	CHAR,
	xCODIGO_CALLE 		IN	CHAR,
	xNUMERO				IN	CHAR, 
	xBLOQUE				IN	CHAR, 
	xESCALERA			IN	CHAR, 
	xPLANTA				IN	CHAR, 
	xPISO					IN	CHAR,
	xLETRA				IN	CHAR,
	xCALIBRE				IN	CHAR,
	xVIVIENDAS			IN	SMALLINT, 
	xHABITACIONES		IN	SMALLINT, 
	xCONTADOR			IN	CHAR,
	xSi_Fecha			IN	CHAR,
	xFECHA_CONTADOR	IN	DATE,
	xFECHA_ALTA			IN	DATE,
	xLIBRO				IN	CHAR,
	xORDEN				IN	CHAR,
	xLUGAR				IN	VARCHAR,
	xID_EPIGRAFE		IN	INTEGER,
      xSECCION			IN	CHAR,
	xEPIGRAFE			IN	CHAR,
	xDNI_TITULAR		IN	CHAR,
	xENTIDAD				IN	CHAR,
	xSUCURSAL			IN	CHAR,
	xDC					IN	CHAR,
	xCUENTA				IN	CHAR,
	xF_DOMICILIACION	IN	DATE,

	xTIPO_CONTADOR		IN	CHAR,
	xTIPO_CONTRATO		IN	CHAR,
	xDURACION			IN	CHAR,
	xF_TERMINACION		IN	DATE,
	xCON_DNI				IN	CHAR,
	xDISPONIBILIDAD	IN	CHAR,
	xPERMISO_OBRA		IN	CHAR,
	xPRI_OCUPACION		IN	CHAR,
	xMEMORIA_TECNICA	IN	CHAR,
	xSERVIDUMBRE		IN	CHAR,
	xOTROS				IN	CHAR,
	xCAUDAL_INSTALADO	IN	CHAR,
	xTIPO_SUMINISTRO	IN	CHAR,
	xCAUDAL_CONTRATADO	IN	CHAR,
	xPRESION				IN	CHAR,
	xACOMETIDA_INTERIOR	IN	CHAR,
	xACOMETIDA_EXTERIOR	IN	CHAR,
	xNUMERO_BOLETIN		IN	CHAR,
	xNUMERO_INSTALADOR	IN	CHAR,
	xCUOTA_CONTRATACION	IN	FLOAT,
	xDERECHOS_INSTALACION	IN	FLOAT,
	xFIANZA				IN	FLOAT,
	xIVA					IN	FLOAT,
	xPOZO_J_INMUEBLE	IN	CHAR,
	xPOZO_COLECTOR		IN	CHAR,
	xPOZO_I_INMUEBLE	IN	CHAR,
	xVERTIDO_ADMISIBLE	IN	CHAR,
	xCALIBRE_ACOMETIDA_EXT 	IN	CHAR,
	xCALIBRE_ACOMETIDA_INT 	IN	CHAR,
	xEXPEDIENTE			IN	CHAR,
	xIDAlternativo    IN	INTEGER,
	xSiGeneraLiqui		IN	CHAR,
	xTEXTO				IN	VARCHAR2,
	xMotivoCambioDomi   IN  VARCHAR2)
AS
   xCONCEPTO			CHAR(6);	
   xCALLE_SUMINISTRO	VARCHAR(25);
   xDias				integer;
   xFinPeVol			date;
   xDOM_SUMINISTRO		VARCHAR2(60);
   xIDCambioTitularLiq 	INTEGER;
   xRECIBO		 		CHAR(7); --NO SE UTILIZA PARA NADA
   xMOTIVO	       		VARCHAR2(1024);
   xImporteTarifa		FLOAT;
BEGIN


	-- almacenamos el parámetro xTEXTO en la tabla USUARIOSGT
	-- y se pone el posible motivo del cambio en la domiciliación en TEXTO2.
	UPDATE USUARIOSGT SET TEXTO=xTEXTO, TEXTO2=xMotivoCambioDomi WHERE USUARIO=USER;

	
	IF xSiGeneraLiqui='S' THEN	--se genera una liquidación por cambio de titularidad	
	
		SELECT dias_vencimiento INTO xDias FROM DATOSPER WHERE MUNICIPIO=xMUNICIPIO;		
		
		SELECT CALLE INTO xCALLE_SUMINISTRO FROM CALLES
		WHERE CODIGO_CALLE=xCODIGO_CALLE and municipio=xMunicipio;	

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
		
		xDOM_SUMINISTRO:=RTRIM(xCALLE_SUMINISTRO)||' '||xNUMERO||' '||xBLOQUE||' '||
				xESCALERA||' '||xPLANTA||' '||xPISO||' '||xLETRA;			
				
				
		SELECT CODIGO INTO xCONCEPTO FROM AGUACOD_TARIFA 
		WHERE MUNICIPIO=xMUNICIPIO AND DESCRIPCION='LIQ. POR CAMBIO DE TITULAR';
		
		SELECT FORMULA Into xImporteTarifa FROM CONTADOR_CONCEPTOS
		WHERE CONCEPTO=xCONCEPTO AND MUNICIPIO=xMunicipio;
		
		IF xImporteTarifa is null then
			xImporteTarifa:=0;
		end if;
		
		
		--se añadiran la liquidaciones siempre que tenga importe, porque puede ser que algunos abonados
		--no tengan fianza o no tenga cuota de contratacion
		if xImporteTarifa > 0 then
		
			xMOTIVO:='CAMBIO DE TITULARIDAD '||'N.CONTADOR: '|| xCONTADOR || ' EXPEDIENTE: '|| xEXPEDIENTE;	
		
			ADD_LIQUI(xMUNICIPIO,xCONCEPTO,TO_CHAR(SYSDATE,'YYYY'),'00',TO_CHAR(SYSDATE,'YYYY'),
				xNIF, xDNI_REPRE, xDOM_SUMINISTRO, SYSDATE, xFinPeVol, xImporteTarifa, 
				xMOTIVO,'','',xEXPEDIENTE,xIDAlternativo,0,xRECIBO,xIDCambioTitularLiq);
		end if;
			
	ELSE
		xIDCambioTitularLiq:=null;
	END IF;

	UPDATE AGUA SET MUNICIPIO=xMUNICIPIO,COD_POSTAL=xCod_Postal,
	   NIF=xNIF, DNI_FACTURA=xDNI_FACTURA,DNI_REPRESENTANTE=xDNI_REPRE,
	   CODIGO_CALLE=xCODIGO_CALLE,
	   NUMERO=xNUMERO,BLOQUE=xBLOQUE,ESCALERA=xESCALERA,PLANTA=xPLANTA,PISO=xPISO,
	   LETRA=xLETRA,CALIBRE=xCALIBRE,VIVIENDAS=xVIVIENDAS,HABITACIONES=xHABITACIONES,
	   CONTADOR=xCONTADOR,FECHA_CONTADOR=xFECHA_CONTADOR,FECHA_ALTA=xFECHA_ALTA,
	   LIBRO=xLIBRO,ORDEN=xORDEN,LUGAR=xLUGAR,ID_EPIGRAFE=xID_EPIGRAFE,SECCION=xSECCION,
	   EPIGRAFE=xEPIGRAFE,TIPO_CONTADOR=xTIPO_CONTADOR,
	   TIPO_CONTRATO=xTIPO_CONTRATO,DURACION=xDURACION,F_TERMINACION=xF_TERMINACION,
	   CON_DNI=xCON_DNI,DISPONIBILIDAD=xDISPONIBILIDAD,PERMISO_OBRA=xPERMISO_OBRA,
	   PRI_OCUPACION=xPRI_OCUPACION,MEMORIA_TECNICA=xMEMORIA_TECNICA,
	   SERVIDUMBRE=xSERVIDUMBRE,OTROS=xOTROS,CAUDAL_INSTALADO=xCAUDAL_INSTALADO,
	   TIPO_SUMINISTRO=xTIPO_SUMINISTRO,CAUDAL_CONTRATADO=xCAUDAL_CONTRATADO,PRESION=xPRESION,
	   ACOMETIDA_INTERIOR=xACOMETIDA_INTERIOR,ACOMETIDA_EXTERIOR=xACOMETIDA_EXTERIOR,
	   NUMERO_BOLETIN=xNUMERO_BOLETIN,NUMERO_INSTALADOR=xNUMERO_INSTALADOR,
	   CUOTA_CONTRATACION=ROUND(xCUOTA_CONTRATACION,2),
	   DERECHOS_INSTALACION=ROUND(xDERECHOS_INSTALACION,2),FIANZA=ROUND(xFIANZA,2),
	   IVA=ROUND(xIVA,2),POZO_J_INMUEBLE=xPOZO_J_INMUEBLE,POZO_COLECTOR=xPOZO_COLECTOR,
	   POZO_I_INMUEBLE=xPOZO_I_INMUEBLE,VERTIDO_ADMISIBLE=xVERTIDO_ADMISIBLE,
	   CALIBRE_ACOMETIDA_EXT=xCALIBRE_ACOMETIDA_EXT,
	   CALIBRE_ACOMETIDA_INT=xCALIBRE_ACOMETIDA_INT,EXPEDIENTE=xEXPEDIENTE,
	   IDDOMIALTER=DECODE(xIDAlternativo,0,NULL,xIDAlternativo),
	   LIQUICAMBIOTITULAR=xIDCambioTitularLiq	   
      WHERE ID=xABONADO;

	-- Comprobar domiciliación del pago
	AGUA_BANCOS(xABONADO,xDOMI,xENTIDAD,xSUCURSAL,xDC,xCUENTA,xF_DOMICILIACION,xDNI_TITULAR);

	-- borrar los servicios anteriores
	DELETE FROM SERVICIOS WHERE ABONADO=xABONADO;

	-- Introducir los servicios después de modificar
	INSERT INTO SERVICIOS (ABONADO,MUNICIPIO,TARIFA,TIPO_TARIFA)
	SELECT xABONADO, xMUNICIPIO, TARIFA, TIPO_TARIFA 
		FROM TMP_SERVICIOS 
	WHERE USUARIO=USER;

END;
/


/*******************************************************************************
Acción: Pasa las lecturas del estado ANTERIOR -> ACTUAL.
	  Sólo actúa cuando el campo "ESTADO" de la tabla "DATOSPER" se encuentra
	  en el estado PG->padrón generado, y pone ete campo en el estado
	  AA->pase de Actual a Anterior
*******************************************************************************/

CREATE OR REPLACE PROCEDURE PASE_LECTURAS (
	xMuni		in	char,
	xRESULT	OUT	CHAR
)
AS
	xESTADO 	CHAR(2);
BEGIN	

   SELECT ESTADO INTO xESTADO FROM DATOSPER WHERE MUNICIPIO=xMUNI;

   xRESULT:='N';

   IF (xESTADO= 'PG') then		/* Si el Padrón no ha sido Listado */ 
	xRESULT:='S';
   
   /*EL RESTO DE LOS CAMPOS EN EL TRIGGER "T_UPD_AGUA" */
   
      UPDATE AGUA SET ACTUAL=0
      WHERE MUNICIPIO=xMUNI AND FECHA_BAJA IS NULL;		

      UPDATE DATOSPER SET ESTADO='PL' 
      WHERE MUNICIPIO=xMUNI;	
   END IF;

END;
/



/* 			SIGNIFICADO DE LOS ESTADOS                            

	PL->	"Periodo de Lecturas" 
	PG->	"Padrón Generado"
	AA->	"Pase de Actual->Anterior"	

*/

/*******************************************************************************
Acción: Dar de baja o restaurar un abonado de agua.
*******************************************************************************/
-- Modificado: 08/04/2005. Lucas Fernández Pérez.
-- Al llamar a ADDLIQUI, enviaba xFinPeVol=null, y eso hacía que no se rellenasen datos
--  del cuaderno 60. Se modifica para que calcule el finpevol de la liquidación y lo pase a add__liqui
--MODIFICACIÓN: 15/05/2006. M. Carmen Junco Gómez. Adaptación al nuevo formato de RUSTICA.
CREATE OR REPLACE PROCEDURE AGUA_BAJA_RESTAURA(
			xID 			IN 		INTEGER,
			xFECHA 			IN 		DATE,
			xMotivoBaja		IN 		CHAR,
			xSiGeneraLiqui	IN		CHAR,
			xDesde			IN		date,
			xHasta			IN		date)
AS

	xFECHA_BAJA 		DATE;
	xMUNICIPIO			CHAR(3);
	xCONCEPTO			CHAR(6);
	xNIF				CHAR(10);
	xCODIGO_CALLE		char(4);
	xCALLE_SUMINISTRO	VARCHAR(25);	   
	xDOM_SUMINISTRO		VARCHAR2(60);	
   	xFIANZA				FLOAT;
   	xCONTADOR			CHAR(10);
   	xEXPEDIENTE			CHAR(10);
	xIDLiqui			integer;
	xRECIBO		 		CHAR(7); --NO SE UTILIZA PARA NADA
	xMOTIVO	       		VARCHAR2(1024);
	
	xNUMERO 			CHAR(3);
    xBLOQUE 			CHAR(1);
    xESCALERA 			CHAR(1);
    xPLANTA 			CHAR(2);
    xPISO 				CHAR(2);
    xLETRA 				CHAR(2);
    xAnterior			integer;
    xActual				integer;
    xLiquiBajaConsumo	integer;
    xFinPeVol           date;
    xDias               integer;

BEGIN

	SELECT FECHA_BAJA,MUNICIPIO,NIF,CODIGO_CALLE,FIANZA,CONTADOR,EXPEDIENTE,
			NUMERO,BLOQUE,ESCALERA,PLANTA,PISO,LETRA,ANTERIOR,ACTUAL
	INTO xFECHA_BAJA,xMUNICIPIO,xNIF,xCODIGO_CALLE,xFIANZA,xCONTADOR,xEXPEDIENTE,
			xNUMERO,xBLOQUE,xESCALERA,xPLANTA,xPISO,xLETRA,xANTERIOR,xACTUAL
	FROM AGUA WHERE ID=xID; 	
	
	
	IF xFECHA_BAJA IS NULL THEN  

		xIDLiqui:=NULL;
		
		IF xSiGeneraLiqui='S' THEN
			--Generar liquidacion por el importe de la fianza, 
			--en este caso sería un importe a devolver al contribuyente			
		
			SELECT CALLE INTO xCALLE_SUMINISTRO FROM CALLES
			WHERE CODIGO_CALLE=xCODIGO_CALLE and municipio=xMunicipio;	
		
			xDOM_SUMINISTRO:=RTRIM(xCALLE_SUMINISTRO)||' '||xNUMERO||' '||xBLOQUE||' '||
					xESCALERA||' '||xPLANTA||' '||xPISO||' '||xLETRA;			
			
			if xFIANZA > 0 then
			
				SELECT CODIGO INTO xCONCEPTO FROM AGUACOD_TARIFA 
				WHERE MUNICIPIO=xMUNICIPIO AND DESCRIPCION='LIQ. POR FIANZA EN BAJAS';
				
               	SELECT dias_vencimiento INTO xDias FROM DATOSPER WHERE MUNICIPIO=xMUNICIPIO;
               	
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
			
				xMOTIVO:='BAJA DE SUMINISTRO DE AGUA '||'N.CONTADOR: '|| xCONTADOR || ' EXPEDIENTE: '|| xEXPEDIENTE;	
		
				ADD_LIQUI(xMUNICIPIO,xCONCEPTO,TO_CHAR(SYSDATE,'YYYY'),'00',TO_CHAR(SYSDATE,'YYYY'),
					xNIF, NULL, xDOM_SUMINISTRO, SYSDATE, xFinPeVol,
					xFIANZA*-1, xMOTIVO,'','',xEXPEDIENTE,null,0,xRECIBO,xIDLiqui);
			end if;
			
			SELECT CODIGO INTO xCONCEPTO FROM AGUACOD_TARIFA 
			WHERE MUNICIPIO=xMUNICIPIO AND DESCRIPCION='LIQ. POR BAJA EN EL CONSUMO';
				
			--Hacer la liquidacion por el consumo y la parte proporcional de las cuotas fijas
			Calculo_Cuota_Liqui_Agua(xMUNICIPIO,xCONCEPTO,xID,xNIF,xDOM_SUMINISTRO,xExpediente,
					xAnterior, xActual,xDesde,xHasta,xLiquiBajaConsumo);
  
		END IF;
			
		UPDATE AGUA SET FECHA_BAJA=xFECHA, 
						MOTIVO_BAJA=xMotivoBaja, 
						LIQUIBAJAFIANZA=xIDLiqui,
						LIQUIBAJACONSUMO=xLiquiBajaConsumo
		WHERE ID=xID;

	ELSE
  
		UPDATE AGUA SET FECHA_BAJA=NULL, MOTIVO_BAJA=NULL WHERE ID=xID;

	END IF;
	
END;
/




-- Creado: 22/12/2003. Agustín León Robles. 
--	Acción: Impresion en Word de las diferentes liquidaciones generadas por el agua.
-- Modificación: 23/12/2003. Lucas Fernández Pérez. 
--	Rellena los campos nuevos NOM_FACTURA y NOM_REPRESENTANTE
-- Modificación: 30/12/2003. Agustín León Robles. 
-- No se grababa en la tabla de impresión el NIF del titular anterior
-- Modificación: 31/01/2005 M. Carmen Junco Gómez.
-- Se elimina el campo NIF_ANTERIOR de la tabla de AGUA. Esta información será ahora accesible
-- a través del histórico MOTIVOS_CAMBIO_TITULARIDAD.
-- Modificación: 05/02/2007. Lucas Fernández Pérez. Se accede al campo DOMICILIO de la nueva vista vwCONTRIBUYENTES,
--					y a los nuevos campos de BLOQUE y PORTAL de las tablas CONTRIBUYENTES y DocImprimeAgua .
--

CREATE OR REPLACE PROCEDURE WriteDocAgua
					(xID		IN		integer, 
					 xTipoLiqui	IN		char)
AS
v_RegAgua 			Agua%ROWTYPE;

xNOMBRE_CONTRI		VARCHAR2(40);	
xPOBLACION_CONTRI	VARCHAR2(35);
xPROVINCIA_CONTRI	VARCHAR2(35);
xCP_CONTRI			CHAR(5);
xVIA_CONTRI			CHAR(2);
xCALLE_CONTRI		CHAR(30);
xNUMERO_CONTRI		CHAR(5);
xBLOQUE_CONTRI		CHAR(4);
xPORTAL_CONTRI		CHAR(2);
xESCALERA_CONTRI	CHAR(2);
xPLANTA_CONTRI		CHAR(3);
xPISO_CONTRI		CHAR(2);
xDOMI_CONTRI		VARCHAR2(60);
xDOMI_SUMINISTRO	VARCHAR2(60);


xNOM_TITULAR_OLD		VARCHAR2(40);
xVIA_TITULAR_OLD		CHAR(2);
xCALLE_TITULAR_OLD		CHAR(30);
xNUMERO_TITULAR_OLD		CHAR(5);
xBLOQUE_TITULAR_OLD		CHAR(4);
xPORTAL_TITULAR_OLD		CHAR(2);
xESCALERA_TITULAR_OLD	CHAR(2);
xPLANTA_TITULAR_OLD		CHAR(3);
xPISO_TITULAR_OLD		CHAR(2);
xCP_TITULAR_OLD			CHAR(5);
xPOBLACION_TITULAR_OLD	VARCHAR2(35);
xPROVINCIA_TITULAR_OLD	VARCHAR2(35);
xDOMI_TITULAR_OLD		VARCHAR2(60);

xNOM_FACTURA			VARCHAR2(40);
xNOM_REPRESENTANTE		VARCHAR2(40);

xEMISOR					char(6);
xTRIBUTO				CHAR(3);
xEJER_C60				CHAR(2);
xREFERENCIA				CHAR(10);
xIMP_CADENA				CHAR(12);
xDISCRI_PERIODO			CHAR(1);
xDIGITO_YEAR			CHAR(1);
xF_JULIANA				CHAR(3);
xDIGITO_C60_MODALIDAD2	CHAR(2);
xFVENCIMIENTO			DATE;
xImporteLiqui			FLOAT;

xCALLE_SUMINISTRO		VARCHAR(25);

xTIPO_CONTADOR			VARCHAR2(15);
xTIPO_CONTRATO			VARCHAR2(25);
xDURACION				VARCHAR2(15);
xLiquiClave				integer;

xMOTIVO					varchar2(1024);
xNUM_LIQUI				char(7);
xYEAR_LIQUI				char(4);

xNIF_ANTERIOR			CHAR(10);
xIDHISTO				INTEGER;

BEGIN

	DELETE FROM DocImprimeAgua WHERE USUARIO=UID;

	select * into v_RegAgua from Agua Where ID=xID;	
	
	SELECT CALLE INTO xCALLE_SUMINISTRO FROM CALLES
		WHERE CODIGO_CALLE=v_RegAgua.CODIGO_CALLE and municipio=v_RegAgua.Municipio;
	
	--liquidacion por alta	
	if (xTipoLiqui='L') then
		xLiquiClave:=v_RegAgua.LIQUIDACION;
	end if;
	
	--liquidacion del cambio de titular
	if (xTipoLiqui='T') then
		xLiquiClave:=v_RegAgua.LIQUICAMBIOTITULAR;			
	end if;
		
	--liquidacion por baja de fianza
	if (xTipoLiqui='F') then
		xLiquiClave:=v_RegAgua.LIQUIBAJAFIANZA;
	end if;	
	
	--liquidacion por baja en el consumo
	if 	(xTipoLiqui='C') then
		xLiquiClave:=v_RegAgua.LIQUIBAJACONSUMO;
	end if;
	
	
	if xLiquiClave is not null then
	
		BEGIN
			SELECT EMISOR,TRIBUTO,EJER_C60,REFERENCIA,IMP_CADENA,DISCRI_PERIODO,DIGITO_YEAR,F_JULIANA,
				DIGITO_C60_MODALIDAD2,FVENCIMIENTO,IMPORTE,MOTIVO,NUMERO,YEAR
			INTO xEMISOR,xTRIBUTO,xEJER_C60,xREFERENCIA,xIMP_CADENA,xDISCRI_PERIODO,xDIGITO_YEAR,xF_JULIANA,
				xDIGITO_C60_MODALIDAD2,xFVENCIMIENTO,xImporteLiqui,xMOTIVO,xNUM_LIQUI,xYEAR_LIQUI
			FROM LIQUIDACIONES WHERE ID=xLiquiClave;
		EXCEPTION
			WHEN NO_DATA_FOUND THEN
				xEMISOR:=NULL;
		END;
	
	end if;
	
		
	IF v_RegAgua.TIPO_CONTADOR='I' THEN
		xTIPO_CONTADOR:='INDIVIDUAL';
	ELSIF v_RegAgua.TIPO_CONTADOR='H' THEN
		xTIPO_CONTADOR:='HIJO';
	ELSIF v_RegAgua.TIPO_CONTADOR='P' THEN
		xTIPO_CONTADOR:='PADRE';
	END IF;
		
		
	IF v_RegAgua.TIPO_CONTRATO='D' THEN
		xTIPO_CONTRATO:='DOMESTICO';
	ELSIF v_RegAgua.TIPO_CONTRATO='I' THEN
		xTIPO_CONTRATO:='INDUSTRIAL';
	ELSIF v_RegAgua.TIPO_CONTRATO='M' THEN
		xTIPO_CONTRATO:='MUNICIPAL';
	ELSIF v_RegAgua.TIPO_CONTRATO='O' THEN
		xTIPO_CONTRATO:='ORGANISMOS PUBLICOS';
	END IF;
			
	IF v_RegAgua.DURACION='I' THEN
		xDURACION:='INDEFINIDO';
	ELSE
		xDURACION:='DEFINIDO';
	END IF;
		
		
	--DATOS DEL TITULAR
	BEGIN
		SELECT NOMBRE,VIA,CALLE,NUMERO,BLOQUE,PORTAL,ESCALERA,PLANTA,PISO,CODIGO_POSTAL,POBLACION,PROVINCIA,DOMICILIO
		INTO xNOMBRE_CONTRI,xVIA_CONTRI,xCALLE_CONTRI,xNUMERO_CONTRI,xBLOQUE_CONTRI,xPORTAL_CONTRI,xESCALERA_CONTRI,
			xPLANTA_CONTRI,xPISO_CONTRI,xCP_CONTRI,xPOBLACION_CONTRI,xPROVINCIA_CONTRI,xDOMI_CONTRI
		FROM vwCONTRIBUYENTES WHERE NIF=v_RegAgua.NIF;
	EXCEPTION
		WHEN NO_DATA_FOUND THEN
			xNOMBRE_CONTRI:=NULL;
	END;
	
	SELECT MAX(ID) INTO xIDHISTO FROM MOTIVOS_CAMBIO_TITULARIDAD WHERE PROGRAMA='AGUA' AND IDCAMBIO=xID;
	
	IF xIDHISTO IS NOT NULL THEN
		SELECT NIF INTO xNIF_ANTERIOR FROM MOTIVOS_CAMBIO_TITULARIDAD WHERE ID=xIDHISTO AND TIPO_TITULAR='T';
		
		--DATOS DEL TITULAR ANTERIOR
		BEGIN
			SELECT NOMBRE,VIA,CALLE,NUMERO,BLOQUE,PORTAL,ESCALERA,PLANTA,PISO,CODIGO_POSTAL,POBLACION,PROVINCIA,DOMICILIO
			INTO xNOM_TITULAR_OLD,xVIA_TITULAR_OLD,xCALLE_TITULAR_OLD,xNUMERO_TITULAR_OLD,xBLOQUE_TITULAR_OLD,
				xPORTAL_TITULAR_OLD,xESCALERA_TITULAR_OLD,xPLANTA_TITULAR_OLD,xPISO_TITULAR_OLD,xCP_TITULAR_OLD,
				xPOBLACION_TITULAR_OLD,xPROVINCIA_TITULAR_OLD,xDOMI_TITULAR_OLD
			FROM vwCONTRIBUYENTES WHERE NIF=xNIF_ANTERIOR;
		EXCEPTION
			WHEN NO_DATA_FOUND THEN
			BEGIN
				xNOM_TITULAR_OLD:=NULL;
				xVIA_TITULAR_OLD:=NULL;
				xCALLE_TITULAR_OLD:=NULL;
				xNUMERO_TITULAR_OLD:=NULL;
				xBLOQUE_TITULAR_OLD:=NULL;
				xPORTAL_TITULAR_OLD:=NULL;
				xESCALERA_TITULAR_OLD:=NULL;			
				xPLANTA_TITULAR_OLD:=NULL;
				xPISO_TITULAR_OLD:=NULL;
				xCP_TITULAR_OLD:=NULL;
				xPOBLACION_TITULAR_OLD:=NULL;
				xPROVINCIA_TITULAR_OLD:=NULL;
			END;
		END;	

	END IF;
				
				
	xDOMI_SUMINISTRO:=RTRIM(xCALLE_SUMINISTRO)||' '||v_RegAgua.NUMERO||' '||v_RegAgua.BLOQUE||' '||v_RegAgua.ESCALERA
				||' '||v_RegAgua.PLANTA||' '||v_RegAgua.PISO||' '||v_RegAgua.LETRA;
	
	
	begin -- Se obtiene el nombre del DNI de la factura
		SELECT NOMBRE INTO xNOM_FACTURA	FROM CONTRIBUYENTES WHERE NIF=v_RegAgua.DNI_FACTURA;
	exception
		when  NO_DATA_FOUND then
			xNOM_FACTURA:='';
	end;
	
	begin -- Se obtiene el nombre del representante
		SELECT NOMBRE INTO xNOM_REPRESENTANTE FROM CONTRIBUYENTES WHERE NIF=v_RegAgua.DNI_REPRESENTANTE;
	exception
		when  NO_DATA_FOUND then
			xNOM_REPRESENTANTE:='';
	end;
	
							
	INSERT INTO DocImprimeAgua (ABONADO,MUNICIPIO,	
   		NIF,NOMBRE_CONTRI,DOMI_CONTRI,VIA,CALLE,NUMERO,ESCALERA,PLANTA,PISO,POBLACION,PROVINCIA,CODIGO_POSTAL,
   
	    DNI_FACTURA,NOM_FACTURA,DNI_REPRESENTANTE,NOM_REPRESENTANTE,
		    
		--Dirección del suministro
   		CALLE_SUMINISTRO,NUMERO_SUMINISTRO,BLOQUE_SUMINISTRO,ESCALERA_SUMINISTRO,PLANTA_SUMINISTRO,
   		PISO_SUMINISTRO,LETRA_SUMINISTRO,DOMI_SUMINISTRO,COD_POSTAL_SUMINISTRO,
	
		--SE GUARDA NORMALMENTE EL NUMERO DE CONTRATO
		EXPEDIENTE,   
      
   		F_L_ACTUAL,F_L_ANTERIOR,ACTUAL,ANTERIOR,FECHA_ALTA,FECHA_BAJA,MOTIVO_BAJA,
    
		TIPO_CONTADOR,TIPO_CONTRATO,DURACION,F_TERMINACION,	

		CAUDAL_INSTALADO,TIPO_SUMINISTRO,CAUDAL_CONTRATADO,PRESION,CALIBRE,ACOMETIDA_INTERIOR,ACOMETIDA_EXTERIOR,
	
		FECHA_CONTADOR,CONTADOR,
				
		NUMERO_BOLETIN,NUMERO_INSTALADOR,
	
		CUOTA_CONTRATACION,DERECHOS_INSTALACION,FIANZA,IVA,TOTAL,IMPORTE_LIQUI,
		
		EMISOR,TRIBUTO,EJER_C60,REFERENCIA,IMP_CADENA,DISCRI_PERIODO,DIGITO_YEAR,F_JULIANA,
		DIGITO_C60_MODALIDAD2,FVENCIMIENTO,
		
		NIF_TITULAR_OLD,NOM_TITULAR_OLD,VIA_TITULAR_OLD,CALLE_TITULAR_OLD,NUMERO_TITULAR_OLD,ESCALERA_TITULAR_OLD,
		PLANTA_TITULAR_OLD,PISO_TITULAR_OLD,CP_TITULAR_OLD,POBLACION_TITULAR_OLD,PROVINCIA_TITULAR_OLD,
		DOMI_TITULAR_OLD,YEAR_LIQUI,NUM_LIQUI,MOTIVO)
	VALUES
		(xID,v_RegAgua.Municipio,v_RegAgua.NIF,xNOMBRE_CONTRI,xDOMI_CONTRI,xVIA_CONTRI,xCALLE_CONTRI,
		xNUMERO_CONTRI,xESCALERA_CONTRI,xPLANTA_CONTRI,xPISO_CONTRI,xPOBLACION_CONTRI,xPROVINCIA_CONTRI,xCP_CONTRI,
			
		v_RegAgua.DNI_FACTURA,xNOM_FACTURA,v_RegAgua.DNI_REPRESENTANTE,xNOM_REPRESENTANTE,
			
		xCALLE_SUMINISTRO,v_RegAgua.NUMERO,v_RegAgua.BLOQUE,v_RegAgua.ESCALERA,v_RegAgua.PLANTA,
   		v_RegAgua.PISO,v_RegAgua.LETRA,xDOMI_SUMINISTRO,v_RegAgua.COD_POSTAL,
      		
  		v_RegAgua.EXPEDIENTE,v_RegAgua.F_L_ACTUAL,v_RegAgua.F_L_ANTERIOR,v_RegAgua.ACTUAL,v_RegAgua.ANTERIOR,
   		v_RegAgua.FECHA_ALTA,v_RegAgua.FECHA_BAJA,v_RegAgua.MOTIVO_BAJA,
      		
   		xTIPO_CONTADOR,xTIPO_CONTRATO,xDURACION,v_RegAgua.F_TERMINACION,
      		
  		v_RegAgua.CAUDAL_INSTALADO,v_RegAgua.TIPO_SUMINISTRO,v_RegAgua.CAUDAL_CONTRATADO,
   		v_RegAgua.PRESION,v_RegAgua.CALIBRE,v_RegAgua.ACOMETIDA_INTERIOR,v_RegAgua.ACOMETIDA_EXTERIOR,
	
		v_RegAgua.FECHA_CONTADOR,v_RegAgua.CONTADOR,
				
		v_RegAgua.NUMERO_BOLETIN,v_RegAgua.NUMERO_INSTALADOR,
	
		v_RegAgua.CUOTA_CONTRATACION,v_RegAgua.DERECHOS_INSTALACION,v_RegAgua.FIANZA,v_RegAgua.IVA,
			
		v_RegAgua.CUOTA_CONTRATACION+v_RegAgua.DERECHOS_INSTALACION+v_RegAgua.FIANZA+v_RegAgua.IVA,xImporteLiqui,
		
		xEMISOR,xTRIBUTO,xEJER_C60,xREFERENCIA,xIMP_CADENA,xDISCRI_PERIODO,xDIGITO_YEAR,xF_JULIANA,
		xDIGITO_C60_MODALIDAD2,xFVENCIMIENTO,
		
		xNIF_ANTERIOR,xNOM_TITULAR_OLD,xVIA_TITULAR_OLD,xCALLE_TITULAR_OLD,xNUMERO_TITULAR_OLD,
		xESCALERA_TITULAR_OLD,xPLANTA_TITULAR_OLD,xPISO_TITULAR_OLD,xCP_TITULAR_OLD,xPOBLACION_TITULAR_OLD,
		xPROVINCIA_TITULAR_OLD,xDOMI_TITULAR_OLD,xYEAR_LIQUI,xNUM_LIQUI,xMOTIVO);

END;
/




--
-- Creado: 22/12/2003. Agustín León Robles. 
-- Modificado 21/07/2004. Gloria Maria Calle Hernandez:
-- 		Arrastramos hasta seis decimales por Precio Unitario y Redondeamos por Tramos.
--
CREATE OR REPLACE PROCEDURE Importes_Calculo_Agua
	(
	xCONSUMO		IN		FLOAT,
	xPRECIO1		IN		FLOAT,
	xBLOQUE1		IN		FLOAT,
	xFIJO1			IN		FLOAT,
	xPRECIO2		IN		FLOAT,
	xBLOQUE2		IN		FLOAT,
	xFIJO2			IN		FLOAT,
	xPRECIO3		IN		FLOAT,
	xBLOQUE3		IN		FLOAT,
	xFIJO3			IN		FLOAT,
	xPRECIO4		IN		FLOAT,
	xBLOQUE4		IN		FLOAT,
	xFIJO4			IN		FLOAT,
	xDiasPeriodo	IN		INTEGER,
	xDias			IN		INTEGER,
	xBASE			OUT		FLOAT)
AS
	xTRAMO		INTEGER;
	xTotalFijo	float;
BEGIN

	xBASE:=0;
	
	IF (xCONSUMO > xBLOQUE3 AND xBLOQUE4 <> 0) THEN
		xTRAMO := xCONSUMO - xBLOQUE3;
		xBASE := ROUND(xPRECIO1 * xBLOQUE1, 2);
		xBASE := xBASE+ ROUND(xPRECIO2 * (xBLOQUE2-xBLOQUE1), 2); 
		xBASE := xBASE+ ROUND(xPRECIO3 * (xBLOQUE3-xBLOQUE2), 2);
		xBASE := xBASE+ ROUND(xPRECIO4 * xTRAMO, 2);
		
		xTotalFijo := xFijo4 + xFijo3 + xFijo2 + xFijo1;		
		
	ELSIF (xCONSUMO > xBLOQUE2 and xBLOQUE3 <> 0) THEN
		xTRAMO := xCONSUMO-xBLOQUE2;
		xBASE := ROUND(xPRECIO1 * xBLOQUE1, 2);
		xBASE := xBASE+ROUND(xPRECIO2 * (xBLOQUE2 - xBLOQUE1), 2); 
		xBASE := xBASE+ROUND(xPRECIO3 * xTRAMO, 2);
		
		xTotalFijo := xFijo3 + xFijo2 + xFijo1;
		
	ELSIF (xCONSUMO > xBLOQUE1 and xBLOQUE2 <> 0) THEN
		xTRAMO := xCONSUMO-xBLOQUE1;
		xBASE := ROUND(xPRECIO1 * xBLOQUE1, 2);
		xBASE := xBASE+ROUND(xPRECIO2 * xTRAMO, 2);
		
		xTotalFijo := xFijo2 + xFijo1;
		
	ELSE
		xBASE := ROUND(xPRECIO1*xCONSUMO, 2);
		
		xTotalFijo := xFijo1;
		
	END IF;

	--averiguamos la parte proporcional de la cuota fija
	xTotalFijo := Round( (xTotalFijo * xDias) / xDiasPeriodo, 2);
		
	xBASE:=ROUND(xBASE+xTotalFijo, 2);

END;
/



--
-- Creado: 22/12/2003. Agustín León Robles. 
--
-- Modificado: 08/04/2005. Lucas Fernández Pérez.
-- Al llamar a ADDLIQUI, enviaba xFinPeVol=null, y eso hacía que no se rellenasen datos
--  del cuaderno 60. Se modifica para que calcule el finpevol de la liquidación y lo pase a add__liqui
--MODIFICACIÓN: 15/05/2006. M. Carmen Junco Gómez. Adaptación al nuevo formato de RUSTICA.
CREATE OR REPLACE PROCEDURE Calculo_Cuota_Liqui_Agua(
		xMUNICIPIO		IN		CHAR,
		xCONCEPTO		IN		char,
		xABONADO		IN		INTEGER, 
		xNIF 			IN		CHAR,
		xDOM_SUMINISTRO	IN		varchar2,
		xExpediente		IN		char,
		xAnterior 		IN		INTEGER, 
		xActual			IN		integer,
		xDesde			IN		date,
		xHasta			IN		date,
		xIDLiqui		OUT		integer)
AS	
	xTIPO_IVA 	FLOAT;
	xTieneIVA 	CHAR(1);	
	xBASE 		FLOAT;
	xIVA  		FLOAT;
	xIMPORTE	FLOAT;

	xBLOQUE1 	INTEGER;
	xBLOQUE2 	INTEGER;
	xBLOQUE3	INTEGER;
	xBLOQUE4 	INTEGER;
	xPRECIO1	FLOAT;
	xPRECIO2	FLOAT;
	xPRECIO3	FLOAT;
	xPRECIO4	FLOAT;
	xFIJO1		FLOAT;
	xFIJO2		FLOAT;
	xFIJO3		FLOAT;
	xFIJO4		FLOAT;
	
	xDescripTarifa	varchar2(35);
	xCONSUMO 		INTEGER;
	xRANGO 			INTEGER;
	xRECIBO		 	CHAR(7); --NO SE UTILIZA PARA NADA
	xDias			integer;
	xDiasPeriodo	integer;
	xPerCobro		char(1);
	xMOTIVO			VARCHAR2(1024) default '';
	xSUMA			FLOAT default 0;
	xSALTO 			CHAR(2);
	xFinPeVol		DATE;
	xDiasVenci     INTEGER;
	
	CURSOR C_SERVICIOS IS SELECT * FROM SERVICIOS WHERE ABONADO=xABONADO;
	
BEGIN	

	SELECT agua_tipo_periodo,dias_vencimiento into xPerCobro,xDiasVenci FROM DATOSPER WHERE MUNICIPIO=xMUNICIPIO;
	
	SELECT min(SALTO) INTO xSALTO FROM SALTO;
	
	if xPerCobro='B' then
		xDiasPeriodo:=60;
	elsif xPerCobro='T' then
		xDiasPeriodo:=90;
	elsif xPerCobro='C' then
		xDiasPeriodo:=120;
	elsif xPerCobro='S' then
		xDiasPeriodo:=180;
	else	
		xDiasPeriodo:=365;
	end if;

	
	--CALCULA LAS LINEAS DE DETALLE Y NOS PERMITE CONOCER EL IMPORTE DEL RECIBO
	IF (xACTUAL < xANTERIOR) THEN
		AVERIGUA_PESO(xACTUAL,xANTERIOR,xCONSUMO,xRANGO);
	ELSE
		xCONSUMO := xACTUAL - xANTERIOR;
	END IF;
	
	xMotivo:='Liquidación por baja en el suministro, fechas para el cálculo de la liquidación: '|| xDesde ||' - '|| xHasta || xSalto;
	xMotivo:=xMotivo || 'Lec. Anterior: '|| xAnterior ||' Lec. Actual: '|| xActual ||' Consumo: '|| xConsumo || xSalto;
	
	--numero de dias para hacer el calculo proporcional de las cuotas fijas
	xDias:= Trunc(xHasta,'dd') - Trunc(xDesde,'dd');

	
	-- Selección de todos los servicios de un abonado 
	FOR v_TServicios IN C_SERVICIOS LOOP

		-- Para saber el IVA aplicado a cada de cada Tarifa 
		SELECT IVA,TIPO_IVA,DESCRIPCION INTO xTIENEIVA,xTIPO_IVA,xDescripTarifa
		FROM TIPO_TARIFA 
		WHERE municipio=xMunicipio and TIPO=v_TServicios.TIPO_TARIFA;
		
		SELECT BLOQUE1,BLOQUE2,BLOQUE3,BLOQUE4,PRECIO1,PRECIO2,PRECIO3,PRECIO4, 
				FIJO1,FIJO2,FIJO3,FIJO4
		INTO xBLOQUE1,xBLOQUE2,xBLOQUE3,xBLOQUE4,xPRECIO1,xPRECIO2,xPRECIO3,xPRECIO4, 
				xFIJO1,xFIJO2,xFIJO3,xFIJO4
		FROM  TARIFAS_AGUA
		WHERE Municipio=xMunicipio AND TARIFA=v_TServicios.TARIFA;	

		xIVA:=0;

		-- Importe Fijo. Sin bloques 
		IF (xBLOQUE1=0) THEN
		
			xBASE:=Round( (xFIJO1 * xDias) / xDiasPeriodo , 2);
			
		ELSE
		
			Importes_Calculo_Agua(xCONSUMO, xPRECIO1, xBLOQUE1, xFIJO1,xPRECIO2 ,xBLOQUE2,xFIJO2,
					  xPRECIO3 ,xBLOQUE3,xFIJO3,xPRECIO4 ,xBLOQUE4,xFIJO4,xDiasPeriodo,xDias,xBASE);
					  
		END IF; 

		xMotivo:=xMotivo || ' '||xDescripTarifa||': '||xBASE;
		
		-- Apunte del iva si tuviera 	
		IF (xTIENEIVA='S' AND xBase >0) THEN
		
			xIVA:=xBASE * xTIPO_IVA/100;
			
			xMotivo:=xMotivo || ' IVA: '||Round(xIVA,2);
			
		END IF;

		
		xMotivo:=xMotivo || xSalto;
		
		xSUMA:=ROUND(xSUMA+xBASE+xIVA,2);

	END LOOP;

	if xDiasVenci > 0 then
		xFinPeVol:=SysDate+xDiasVenci;
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
	
	--Generar la liquidacion
	ADD_LIQUI(xMUNICIPIO,xCONCEPTO,TO_CHAR(SYSDATE,'YYYY'),'00',TO_CHAR(SYSDATE,'YYYY'),
				xNIF, NULL, xDOM_SUMINISTRO, SYSDATE, xFinPeVol,
				xSUMA, xMOTIVO,'','',xEXPEDIENTE,null,0,xRECIBO,xIDLiqui);	
	
END;
/


/********************************************************************/
COMMIT;
/********************************************************************/
