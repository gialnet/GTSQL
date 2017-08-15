/*******************************************************************************
Acci�n: Crear, pegar o quitae una exacci�n de un grupo.
*******************************************************************************/

CREATE or replace PROCEDURE CREA_PEGA_GRUPO_EXAC (
	xID		IN	INTEGER,
	xTIPO		IN	CHAR,
	xIN_COD_OPE IN	FLOAT,
	xOUT_COD_OPE OUT	FLOAT)
AS
BEGIN


  IF(xTIPO='C') THEN /*CREAR GRUPO*/
     ADD_COD_OPERACION(xOUT_COD_OPE);
     UPDATE RECIBOS_EXAC SET CODIGO_OPERACION=xOUT_COD_OPE WHERE ID=xID;
  END IF;

  IF (xTIPO='P') THEN /*PEGAR GRUPO*/ 
      UPDATE RECIBOS_EXAC SET CODIGO_OPERACION=xIN_COD_OPE WHERE ID=xID;
  END IF;

  IF (xTIPO='Q') THEN /*QUITAR GRUPO*/ 
      UPDATE RECIBOS_EXAC SET CODIGO_OPERACION=0 WHERE ID=xID;
  END IF;

END;
/

/*******************************************************************************
Acci�n: Pase a Recaudaci�n de un padr�n de Exacciones.
MODIFICACI�N: 22/08/2001 Antonio P�rez Caballero.
MODIFICACI�N: 
/09/2001 Lucas Fern�ndez P�rez. Adaptaci�n al euro.
MODIFICACI�N: 27/05/2002 M. Carmen Junco G�mez. Incluir o no los exentos dependiendo
		  del nuevo par�metro de entrada xEXENTOS.
MODIFICACI�N: 28/06/2002 M. Carmen Junco G�mez. Insertar una tupla en LogsPadrones
		  para controlar que se ha pasado un padr�n a Recaudaci�n.
MODIFICACI�N: 04/12/2002 M. Carmen Junco G�mez. Se a�aden los campos MUNICIPIO y
		  PERIODO en la tabla LOGSPADRONES. 
MODIFICACI�N: 09/06/2004 Gloria M� Calle Hern�ndez. Se guarda en el campo Clave_recibo el ID 
		  de la la tabla de recibos.
MODIFICACI�N: 28/09/2004 Gloria M� Calle Hern�ndez. Se elimina el domicilio tributario del 
			  objeto tributario, pues existiendo el campo dom_tributario es redundante.
MODIFICACION: 07/06/2006 Lucas Fern�ndez P�rez. El nif del valor en recaudaci�n ser� 
	DNI_FACTURA si tiene datos, o el NIF de recibos_exac si dni_factura is null
*********************************************************************************************************/
CREATE OR REPLACE PROCEDURE EXAC_PASE_RECA (
	xMunicipio			IN	CHAR,
	xPADRON				IN	CHAR,
	xYEAR 				IN	CHAR,
	xPERIODO 			IN	CHAR,
	xFECHA 				IN	DATE,
	xN_CARGO 			IN	CHAR,
	xYEARCONTRAIDO		IN	CHAR,
	xEXENTOS			IN  CHAR)
AS
	xRECIBO 			INTEGER;
	xSALTO 				CHAR(2);
	xDOMICILIO_TRIB		CHAR(60);
	xSITUACION			CHAR(40);
	xNUMERO				CHAR(6);
	xESCALERA			CHAR(2);
	xPLANTA				CHAR(3);
	xPUERTA				CHAR(3);

   xNIF				char(10);
   xDNI_FACTURA 	char(10);
   xNOMBRE		   VARchar2(40);

	/*EB: ENTREGADO EN EL BANCO; DB:DEVUELTO POR EL BANCO*/
	ESTADO_BANCO 			char(2);

	INICIO_PERIODO_VOLUN	DATE;
   FIN_PERIODO_VOLUNTARIO 	DATE;

   PRINCIPAL 				FLOAT;

	xIMPORTE1				FLOAT;
	xIMPORTE2				FLOAT;

	xTITULO1			 	char(50);
	xTITULO2			 	char(50);

   OBJETO_TRIBUTARIO 	 	VARCHAR2(1024);

	xBASE					FLOAT DEFAULT 0;
	xPOR_BONIFICACION			FLOAT DEFAULT 0;
	xIVA					FLOAT DEFAULT 0;

	xORDENANZA				VARCHAR2(50);
	xTARIFA					VARCHAR2(50);

	xTIPO_TRIBUTO			CHAR(2);
	xMOTIVO					VARCHAR2(40);
	xCOTITULARES		    CHAR(1);
	xID						INTEGER;

	CURSOR CURSOR_EXACCIONES_PASE_RECA IS
			SELECT ID,ABONADO,NIF,DNI_FACTURA,SITUACION,NUMERO,ESCALERA,PLANTA,PUERTA,
		 	DESDE,HASTA,TOTAL,ESTADO_BANCO,
			BASE,POR_BONIFICACION,IVA,ORDENANZA,TARIFA
			FROM RECIBOS_EXAC 
		WHERE COD_ORDENANZA=xPADRON
			AND MUNICIPIO=xMUNICIPIO 
			AND YEAR=xYEAR 
			AND PERIODO=xPERIODO;
BEGIN   

     SELECT TIPO_TRIBUTO INTO xTIPO_TRIBUTO 
     FROM CONTADOR_CONCEPTOS
     WHERE MUNICIPIO=xMUNICIPIO AND CONCEPTO=xPADRON;

     SELECT min(SALTO) INTO xSALTO FROM SALTO;

     OPEN CURSOR_EXACCIONES_PASE_RECA;
     LOOP

		FETCH CURSOR_EXACCIONES_PASE_RECA INTO xID,xRECIBO,xNIF,xDNI_FACTURA,
			xSITUACION,xNUMERO,xESCALERA,xPLANTA,xPUERTA,
			INICIO_PERIODO_VOLUN,FIN_PERIODO_VOLUNTARIO,
			PRINCIPAL,ESTADO_BANCO,xBASE,xPOR_BONIFICACION,
			xIVA,xORDENANZA,xTARIFA;

		EXIT WHEN CURSOR_EXACCIONES_PASE_RECA%NOTFOUND;


		SELECT NOMBRE INTO xNOMBRE FROM CONTRIBUYENTES WHERE NIF=DECODE(xDNI_FACTURA,NULL,xNIF,xDNI_FACTURA);
		
		SELECT COTITULARES INTO xCOTITULARES FROM EXACCIONES WHERE ABONADO=xRECIBO;

		xIMPORTE1:=Round(xBASE-(xBASE*xPOR_BONIFICACION/100),2);
		xIMPORTE2:=xIVA;

		SELECT MOTIVO INTO xMOTIVO 
		FROM EXACCIONES WHERE ABONADO=xRECIBO;

		OBJETO_TRIBUTARIO:='ABONADO N�: '||xRECIBO||xSALTO;
		OBJETO_TRIBUTARIO:=OBJETO_TRIBUTARIO||xORDENANZA||xSALTO;
		OBJETO_TRIBUTARIO:=OBJETO_TRIBUTARIO||xTARIFA||xSALTO;
		OBJETO_TRIBUTARIO:=OBJETO_TRIBUTARIO||'MOTIVO: '||xMOTIVO||xSALTO;
	      OBJETO_TRIBUTARIO:=OBJETO_TRIBUTARIO||'BASE: '||TO_CHAR(xBASE)||xSALTO;
		OBJETO_TRIBUTARIO:=OBJETO_TRIBUTARIO||'%PORCENTAJE: '||
							TO_CHAR(xPOR_BONIFICACION,'0D99')||xSALTO;
		OBJETO_TRIBUTARIO:=OBJETO_TRIBUTARIO||'I.V.A: '||TO_CHAR(xIVA)||xSALTO;

		xDOMICILIO_TRIB:=xSITUACION||' '||xNUMERO||' '||xESCALERA||' '||xPLANTA||' '||xPUERTA;

		IF NOT (xEXENTOS='N' AND PRINCIPAL<=0) THEN
		   INSERT INTO PUNTEO
		     (AYTO,PADRON,YEAR,PERIODO,RECIBO,NIF,NOMBRE,VOL_EJE,F_CARGO,N_CARGO,
		      PRINCIPAL,CUOTA_INICIAL,TIPO_DE_OBJETO,FIN_PE_VOL,INI_PE_VOL,TIPO_DE_TRIBUTO,
		      ESTADO_BANCO,DOM_TRIBUTARIO,OBJETO_TRIBUTARIO,
		      Importe1,Importe2,Titulo1,Titulo2,YEAR_CONTRAIDO, COTITULARES,CLAVE_RECIBO)
		   VALUES
		     (xMunicipio,xPadron,xYear,xPeriodo,xRECIBO,DECODE(xDNI_FACTURA,NULL,xNIF,xDNI_FACTURA),xNOMBRE,
		      'V',xFecha,xN_Cargo,Principal,Principal,'R',Fin_Periodo_Voluntario,
		      Inicio_Periodo_Volun,xTIPO_TRIBUTO,Estado_Banco,xDomicilio_Trib,
			Objeto_Tributario,xImporte1,xImporte2,'B. IMPONIBLE','I.V.A.',
		      xYEARCONTRAIDO,xCOTITULARES,xID);		 
	      END IF;
     END LOOP;

     CLOSE CURSOR_EXACCIONES_PASE_RECA;

     -- Insertamos una tupla en LOGSPADRONES para controlar que esta acci�n ha sido ejecutada
     INSERT INTO LOGSPADRONES (MUNICIPIO,PROGRAMA,PYEAR,PERIODO,COD_ORDENANZA,HECHO)
     VALUES (xMUNICIPIO,'EXACCIONES',xYEAR,xPERIODO,xPADRON,'Se Pasa un padr�n a Recaudaci�n');
END;
/

/*******************************************************************************
Acci�n: Gr�ficos de Exacciones.
*******************************************************************************/

CREATE OR REPLACE PROCEDURE EXAC_GRAFICOS (
	xMunicipio	in	char,
	xYEAR 	in	CHAR,
	xPERIODO 	in	CHAR,
	xORDE 	in	CHAR)
AS
	xTARIFA	VARCHAR(50);
	xSUMA		FLOAT;
	CURSOR cursor_exac_graficos IS
	   select Tarifa,sum(total) from recibos_exac
	   where municipio=xMunicipio and periodo=xPeriodo and year=xYear and 
	         cod_ordenanza=xOrde group by tarifa;
BEGIN

   delete from tabla_exac_graficos;
   open cursor_exac_graficos;

   loop
	fetch cursor_exac_graficos into xTarifa,xSuma;
	exit when cursor_exac_graficos%notfound;
	insert into tabla_exac_graficos 
      (TARIFA,SUMA)
      values (xTarifa,xSuma);
   end loop;

   close cursor_exac_graficos;

END;
/

/*******************************************************************************
Acci�n: Gr�ficos de Exacciones.
MODIFICACI�N: 20/09/2001 M. Carmen Junco G�mez. Adaptaci�n al euro.
*******************************************************************************/

CREATE OR REPLACE PROCEDURE EXAC_GRAFICOS_POCO(
	xMUNICIPIO	IN	CHAR,
	xYEAR 	IN	CHAR,
	xPERIODO 	IN	CHAR,
	xORDE 	IN	CHAR
)
AS
	xTARIFA	VARCHAR(50);
	xSUMA		FLOAT;
	xTOT 		FLOAT;
	xMEDIA 	FLOAT;
	xPARCIAL 	FLOAT;
	i 		integer;
	
	CURSOR CURSOR_EXAC_GRAFICOS_POCO IS 
	   SELECT TARIFA,SUMA FROM TABLA_EXAC_GRAFICOS ORDER BY SUMA DESC;

BEGIN

  xTOT:=0;
  i:=0;
  xPARCIAL:=0;

  DELETE FROM TABLA_EXAC_GRAFICOS_POCO;

  EXAC_GRAFICOS(xMUNICIPIO,xYEAR,xPERIODO,xORDE);

  SELECT AVG(SUMA) INTO xMEDIA
  FROM TABLA_EXAC_GRAFICOS;
  
  SELECT SUM(SUMA) INTO xTOT
  FROM TABLA_EXAC_GRAFICOS;
 
  OPEN CURSOR_EXAC_GRAFICOS_POCO;
  LOOP
	FETCH CURSOR_EXAC_GRAFICOS_POCO INTO xTARIFA,xSUMA;
	EXIT WHEN CURSOR_EXAC_GRAFICOS_POCO%NOTFOUND;
	INSERT INTO TABLA_EXAC_GRAFICOS_POCO 
      (TARIFA,SUMA)
	VALUES (xTARIFA,round(xSUMA,2));
      i:=i+1;
      xPARCIAL:=xPARCIAL+xSUMA;
  	IF ((i>11) or ((i>11) and ((xPARCIAL+xMEDIA)>xTOT))) THEN
     		xTARIFA:='VARIOS';
     		xSUMA:=xTOT-xPARCIAL;
		INSERT INTO TABLA_EXAC_GRAFICOS_POCO VALUES (xTARIFA,round(xSUMA,2));
    	END IF;
   END LOOP;
   CLOSE CURSOR_EXAC_GRAFICOS_POCO;
END;
/

/*******************************************************************************
Acci�n: Inserci�n de los datos de un abonado en una tabla temporal.
MODIFICACI�N: 23/08/2001 Agustin Leon Robles.
MODIFICACI�N: 18/09/2002 M. Carmen Junco G�mez. Desaparece la tabla Tarifas_Exacciones
		  por la tabla Tarifas_conceptos.
MODIFICACI�N: 01/06/2006 Lucas Fern�ndez P�rez. Miraba DNI_TITULAR en vez de 
					DNI_FACTURA para obtener el domicilio fiscal.
MODIFICACION: 07/06/2006 Lucas Fern�ndez P�rez. El nif y nombre de TABLA_EXAC ser�
	REPRESENTANTE si tiene datos, o DNI_FACTURA si tiene datos, o el NIF de exacciones si los
	otros dos estan vacios
MODIFICACI�N: 05/02/2007 Lucas Fern�ndez P�rez. Ampliaci�n del campo domicilio de la tabla TABLA_EXAC
****************************************************************************************/

CREATE OR REPLACE PROCEDURE PROC_TABLA_EXAC(xID IN INTEGER)
AS
   xNIF           CHAR(10);
	xNOMBRE			VARCHAR(40);
	xDomicilio			VARCHAR2(60);
   xPOBLACION_FISCAL		VARCHAR(35);
   xPROVINCIA_FISCAL		VARCHAR(35);
   xCODIGO_POSTAL_FISCAL	CHAR(5);

	xSITUACION			VARCHAR(40);
	xORDENANZA			VARCHAR(50);
	xTARIFA			VARCHAR(50);
	xNOMBRE_TITULAR		VARCHAR(40);
	xPOBLACION			VARCHAR(35);

	v_RegistroExac      Exacciones%ROWTYPE;
BEGIN

	delete from tabla_exac WHERE USUARIO=UID;

	SELECT * INTO v_RegistroExac FROM EXACCIONES WHERE ABONADO=xID;

	--nombre del abonado, es decir, a nombre de quien saldr� el recibo
	SELECT NOMBRE INTO xNOMBRE FROM CONTRIBUYENTES
		WHERE NIF=DECODE(v_RegistroExac.REPRESENTANTE,NULL,DECODE(v_RegistroExac.DNI_FACTURA, NULL, v_RegistroExac.NIF, v_RegistroExac.DNI_FACTURA),v_RegistroExac.REPRESENTANTE);
	
	--domicilio fiscal en funcion de si tiene un representante o no.
	--Dentro de la funcion "GetDomicilioFiscal" se comprueba si tiene a su vez un domicilio
	--alternativo.
	IF v_RegistroExac.REPRESENTANTE IS NULL THEN
		IF v_RegistroExac.DNI_FACTURA IS NULL THEN
			xNIF:=v_RegistroExac.NIF;
		   GetDomicilioFiscal(v_RegistroExac.NIF, v_RegistroExac.IDDOMIALTER,
				xDomicilio,xPOBLACION_FISCAL,xPROVINCIA_FISCAL,xCODIGO_POSTAL_FISCAL);
		ELSE 
         xNIF:=v_RegistroExac.DNI_FACTURA;
		   GetDomicilioFiscal(v_RegistroExac.DNI_FACTURA, v_RegistroExac.IDDOMIALTER,
				xDomicilio,xPOBLACION_FISCAL,xPROVINCIA_FISCAL,xCODIGO_POSTAL_FISCAL);
		END IF;
	ELSE
	   xNIF:=v_RegistroExac.REPRESENTANTE;
		GetDomicilioFiscal(v_RegistroExac.REPRESENTANTE,v_RegistroExac.IDDOMIALTER,
				xDomicilio,xPOBLACION_FISCAL,xPROVINCIA_FISCAL,xCODIGO_POSTAL_FISCAL);
	END IF;


	SELECT CALLE INTO xSITUACION FROM CALLES 
	WHERE MUNICIPIO=v_RegistroExac.MUNICIPIO AND CODIGO_CALLE=v_RegistroExac.COD_SITUACION;
	
	SELECT DESCRIPCION INTO xORDENANZA FROM VWORDENANZAS 
	WHERE MUNICIPIO=v_RegistroExac.MUNICIPIO AND CONCEPTO=v_RegistroExac.COD_ORDENANZA;

	SELECT TARIFA INTO xTARIFA FROM TARIFAS_CONCEPTOS
 	WHERE AYTO=v_RegistroExac.MUNICIPIO 
		AND CONCEPTO=v_RegistroExac.COD_ORDENANZA 
		AND COD_TARIFA=v_RegistroExac.COD_TARIFA;	
	
	IF v_RegistroExac.DOMICILIADO='S' THEN
		SELECT NOMBRE INTO xNOMBRE_TITULAR FROM CONTRIBUYENTES 
			WHERE NIF=v_RegistroExac.DNI_TITULAR;
	END IF;

	SELECT POBLACION INTO xPOBLACION FROM DATOSPER WHERE MUNICIPIO=v_RegistroExac.MUNICIPIO;

	INSERT INTO TABLA_EXAC(
		ID,NIF,NOMBRE,DOMICILIO,POBLACION_FISCAL,PROVINCIA_FISCAL,CODIGO_POSTAL_FISCAL,
		COD_SITUACION,SITUACION,NUMERO,ESCALERA,PLANTA,PUERTA,COD_ORDENANZA,
		ORDENANZA,COD_TARIFA,TARIFA,UNIDADES,MOTIVO,TOTAL,TIPO_ALTA,F_ALTA,
		F_BAJA,DOMICILIADO,ENTIDAD,SUCURSAL,DC,CUENTA,TITULAR,NOMBRE_TITULAR,
		INCORPORADO,F_INCORPORACION,POBLACION)
	   VALUES(
		v_RegistroExac.ABONADO,xNIF,xNOMBRE,
		xDOMICILIO,xPOBLACION_FISCAL,xPROVINCIA_FISCAL,xCODIGO_POSTAL_FISCAL,
		v_RegistroExac.COD_SITUACION,xSITUACION,v_RegistroExac.NUMERO,
		v_RegistroExac.ESCALERA,
		v_RegistroExac.PLANTA,
		v_RegistroExac.PUERTA,
		v_RegistroExac.COD_ORDENANZA,xORDENANZA,
		v_RegistroExac.COD_TARIFA,xTARIFA,
		v_RegistroExac.UNIDADES,v_RegistroExac.MOTIVO,
		v_RegistroExac.TOTAL,v_RegistroExac.TIPO_ALTA,
		v_RegistroExac.F_ALTA,v_RegistroExac.F_BAJA,
      	v_RegistroExac.DOMICILIADO,
		DECODE(v_RegistroExac.DOMICILIADO,'S',v_RegistroExac.ENTIDAD,NULL),
		DECODE(v_RegistroExac.DOMICILIADO,'S',v_RegistroExac.SUCURSAL,NULL),
		DECODE(v_RegistroExac.DOMICILIADO,'S',v_RegistroExac.DC,NULL),
		DECODE(v_RegistroExac.DOMICILIADO,'S',v_RegistroExac.CUENTA,NULL),
		DECODE(v_RegistroExac.DOMICILIADO,'S',v_RegistroExac.DNI_TITULAR,NULL),
		xNOMBRE_TITULAR,
		v_RegistroExac.INCORPORADO,v_RegistroExac.F_INCORPORACION,xPOBLACION);

END;
/

/********************************************************************************
Acci�n: domiciliaci�n de un recibo.
Autor: 2706/2002 M. Carmen Junco G�mez. Modifica los datos de domiciliaci�n de 
		  un abonado y comprueba si hay recibo emitido 
              del padr�n anual en curso y en tal caso modifica los datos de la 
              domiciliaci�n para que entre en los soportes del cuaderno 19
MODIFICACION: 03/07/2002 M. Carmen Junco G�mez. Si no se encontraba el recibo en la 
		  tabla de valores estavamos asign�ndole a mVOL_EJE:=''; En mi m�quina,
		  por ejemplo, funcionaba correctamente, pero en Salobre�a estaba fallando
		  el procedimiento (no domiciliaba el recibo) debido a esta asignaci�n.
		  Se ha cambiado por mVOL_EJE:=NULL;		 
MODIFICACION: 05/07/2002 M. Carmen Junco G�mez. El recibo s�lo se podr� modificar
		  si a�n no se ha emitido el Cuaderno19 para el padr�n al que pertenece.
		  Adem�s, cuando modificamos en recaudaci�n, debemos tener en cuenta si el
		  cargo se ha aceptado o no. Si a�n no se ha aceptado habr� que hacer la
		  modificaci�n en la tabla PUNTEO y no en VALORES.
MODIFICACI�N: 04/12/2002 M. Carmen Junco G�mez. Insertamos los campos MUNICIPIO y 
		  PERIODO en LOGSPADRONES.
MODIFICACI�N: 10/03/2005 Lucas Fern�ndez P�rez. Hasta ahora se comprobaban los recibos emitidos 
		  en el a�o en curso, de tal forma que no hac�a la modificaci�n del recibo si el padr�n se
		  emiti� el a�o anterior al actual. Lo que haremos ser� revisar los recibos emitidos desde
		  hace un a�o al d�a de hoy. 		  
MODIFICACI�N: 18/07/2006 Lucas Fern�ndez P�rez. En la b�squeda del recibo en valores y punteo
	no estaba en la condicion "TIPO_DE_OBJETO='R'" 
********************************************************************************/

CREATE OR REPLACE PROCEDURE EXACCIONES_BANCOS(
       xABONADO		IN INTEGER,
	   xDOMICILIADO	IN CHAR,
       xENTIDAD 	IN CHAR,
       xSUCURSAL 	IN CHAR,
       xDC 			IN CHAR,
       xCUENTA 		IN CHAR,
	   xF_DOMICILIACION IN DATE,
       xTITULAR 	IN CHAR)
AS
	mVOL_EJE 		Char(1);
	mVALOR   		Integer;
	mPUNTEO  		INTEGER;
	mPADRON 		CHAR(6);
	xNOMBRE_TITULAR CHAR(40);
	xCuantos 		Integer;

   	mSUCURSAL  	  	char(4);
   	mDC		  		char(2);
   	mCUENTA	      	char(10);
   	mF_DOMICILIACION 	Date;
   	mTITULAR	    char(10);	

	-- cursor que recorre los distintos periodos de los distintos recibos que 
	-- se han podido emitir para este abonado, para comprobar para que padr�n
	-- se ha emitido ya el Cuaderno19, y por lo tanto no modificar la domiciliaci�n
	-- de ese recibo. Han de ser recibos emitidos en el a�o en curso.
	CURSOR CPERIODOS IS SELECT DISTINCT YEAR,PERIODO,ID,MUNICIPIO FROM RECIBOS_EXAC
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

	-- se actualiza en la tabla EXACCIONES
	UPDATE EXACCIONES SET DOMICILIADO=xDOMICILIADO,
			         ENTIDAD=xENTIDAD,
                     SUCURSAL=mSUCURSAL,
                     DC=mDC,CUENTA=mCUENTA,
			         F_DOMICILIACION=mF_DOMICILIACION,
			         DNI_TITULAR=mTITULAR                      
	WHERE ABONADO=xABONADO
	RETURNING COD_ORDENANZA INTO mPADRON;

	-- por cada periodo distinto de recibos sobre el abonado
	FOR vPERIODOS IN CPERIODOS 
	LOOP	 
       -- Comprobamos si se ha emitido ya el soporte del cuaderno 19
	   SELECT COUNT(*) INTO xCUANTOS FROM LOGSPADRONES 
	   WHERE MUNICIPIO=vPERIODOS.MUNICIPIO AND 
		   PROGRAMA ='EXACCIONES' AND 
		   COD_ORDENANZA=mPADRON AND
		   PYEAR=vPERIODOS.YEAR AND
		   PERIODO=vPERIODOS.PERIODO AND 	
	       HECHO='Generaci�n Cuaderno 19 (recibos domiciliados)';

	   IF xCUANTOS=0 THEN  -- a�n no se ha emitido. Podemos modificar el recibo.	      
        -- Comprobar si ya se paso a recaudaci�n    
	    begin
	   	   SELECT ID,VOL_EJE INTO mVALOR,mVOL_EJE FROM VALORES 
         	   WHERE AYTO=vPERIODOS.MUNICIPIO AND PADRON=mPADRON AND
		   	   YEAR=vPERIODOS.YEAR AND PERIODO=vPERIODOS.PERIODO AND RECIBO=xABONADO AND TIPO_DE_OBJETO='R';
	    Exception
	   	      When no_data_found then
	      	   mVOL_EJE:=NULL;
	    end;

		-- Si no se encuentra el valor, comprobar si est� en el punteo
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

		-- si el recibo est� en Voluntaria en RECA o todavia no se ha pasado a recaudaci�n
		IF ((mVOL_EJE='V') or (mVOL_EJE IS NULL)) THEN
	   		-- modificamos el recibo en gesti�n tributaria
	   		IF xDOMICILIADO='N' THEN
	      		UPDATE RECIBOS_EXAC SET DOMICILIADO='N',
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
				SELECT SUBSTR(NOMBRE,1,40) INTO xNOMBRE_TITULAR FROM CONTRIBUYENTES WHERE NIF=xTITULAR;

		        UPDATE RECIBOS_EXAC SET DOMICILIADO='S',
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
  	         			UPDATE VALORES SET ESTADO_BANCO=DECODE(ESTADO_BANCO, 'EB', NULL, ESTADO_BANCO)
	         			   WHERE ID=mVALOR;
					ELSE
					   UPDATE PUNTEO SET ESTADO_BANCO=DECODE(ESTADO_BANCO, 'EB', NULL, ESTADO_BANCO)
					   WHERE ID=mPUNTEO;
					END IF;
				ELSE		
					IF mVALOR IS NOT NULL THEN
  	         		   UPDATE VALORES SET ESTADO_BANCO=DECODE(ESTADO_BANCO, NULL, 'EB',ESTADO_BANCO)
	         			   WHERE ID=mVALOR;		
					ELSE
					   UPDATE PUNTEO SET ESTADO_BANCO=DECODE(ESTADO_BANCO, NULL, 'EB',ESTADO_BANCO)
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
Acci�n: Insertar un nuevo abonado en exacciones.
MODIFICACI�N: 22/08/2001 Antonio P�rez Caballero.
MODIFICACI�N: 18/09/2001 Lucas Fern�ndez P�rez. Adaptaci�n al euro.
MODIFICACI�N: 27/06/2002 M. Carmen Junco G�mez. Se llama al procedimiento 
		  EXACCIONES_BANCOS para dar de alta la domiciliaci�n.
MODIFICACI�N: 24/09/2002 M. Carmen Junco G�mez. Al llamar a Exacciones_bancos
		  hay que enviarle xNum_Abonado y no xAbon.
MODIFICACION: 10/01/2005. Gloria Maria Calle Hernandez. A�adidos campos Ref_catastral
		  y Num_fijo a la tabla.
MODIFICACI�N: 01/06/2006 Lucas Fern�ndez P�rez. Grababa en el campo DNI_TITULAR 
					el valor de DNI_FACTURA.
*******************************************************************************/

CREATE or replace PROCEDURE INSERTA_EXACCION (
	xMunicipio		in	char,
	xABON			in	INTEGER,
	xNIF 			in	CHAR,
	xNOMBRE 		in	VARCHAR,

	xDNI_FACTURA	in	CHAR,
	xRepresentante	IN	CHAR,
	xCOD_SITUACION	in	CHAR,
	xNUMERO 		in	CHAR,
	xESCALERA		in	CHAR,		
	xPLANTA			in	CHAR,
	xPUERTA			in	CHAR,
	xREF_CATASTRAL	in	CHAR,
	xNUM_FIJO		in	CHAR,

    xID_EPIGRAFE	in	INTEGER,
	xEPIGRAFE		in	CHAR,
	xSECCION		in	CHAR,

	xCOD_ORDENANZA	in	CHAR,
	xCOD_TARIFA		in	CHAR,
	xUNIDADES		in	float,
	xMOTIVO			in	VARCHAR,
	xTIPO_ALTA		in	CHAR,
	xF_ALTA 		in	DATE,
      xDOMICILIADO 	in	CHAR,
	xENTIDAD 		in	CHAR,
	xSUCURSAL 		in	CHAR,
	xDC 			in	CHAR,
	xCUENTA 		in	CHAR,
	xDNI_TITULAR 	in	CHAR,
	xF_DOMICILIACION	IN	DATE,
	xBase			in	float,
	xPorBon			in	float,
	xIVA			in	float,
	xTotal			in	float,
	xTipo1			in  float,
	xTipo2			in  float,
	xTipo3			in  float,
	xTipo4			in  float,
	xIDAlternativo  IN	INTEGER,
	xNUM_ABONADO 	out	CHAR)

AS
BEGIN   

   INSERT INTO EXACCIONES(ABONADO,Municipio,NIF,DNI_FACTURA,ID_EPIGRAFE,EPIGRAFE,SECCION,
 	COD_SITUACION, NUMERO, ESCALERA, PLANTA, PUERTA, REF_CATASTRAL, NUM_FIJO,
 	COD_ORDENANZA, COD_TARIFA, UNIDADES, MOTIVO, TIPO_ALTA, F_ALTA,
	BASE,POR_BONIFICACION,IVA, TOTAL,
	Tipo1,Tipo2,Tipo3,Tipo4,REPRESENTANTE,IDDOMIALTER)
   VALUES( xABON, xMunicipio, xNIF, xDNI_FACTURA, xID_EPIGRAFE, xEPIGRAFE, xSECCION,
	xCOD_SITUACION, xNUMERO, xESCALERA, xPLANTA, xPUERTA, xREF_CATASTRAL, xNUM_FIJO, 
	xCOD_ORDENANZA, xCOD_TARIFA, xUNIDADES, xMOTIVO, xTIPO_ALTA, xF_ALTA,
	ROUND(xBase,2), xPorBon, ROUND(xIVA,2), ROUND(xTOTAL,2),
	ROUND(xTipo1,2), ROUND(xTipo2,2), ROUND(xTipo3,2), ROUND(xTipo4,2),
	xRepresentante,DECODE(xIDAlternativo,0,NULL,xIDAlternativo))
   RETURN ABONADO into xNum_abonado;

   EXACCIONES_BANCOS(xNum_abonado,xDOMICILIADO,xENTIDAD,xSUCURSAL,xDC,xCUENTA,
		   xF_DOMICILIACION,xDNI_TITULAR);

END;
/

/*******************************************************************************
Acci�n: Modificaci�n de los datos de un abonado de exacciones.
MODIFICACI�N: 18/09/2001 Lucas Fern�ndez P�rez. Adaptaci�n al euro.
MODIFICACI�N: 27/06/2002 M. Carmen Junco G�mez. Se llama al procedimiento 
		     EXACCIONES_BANCOS para modificar, si procede, la domiciliaci�n.
MODIFICACI�N: 28/09/2004 Gloria M� Calle Hern�ndez. Se a�ade la llamada al 
			  procedimiento Recibos_exac_modifi para cambiar dichas variaciones
			  en recaudacion. 
MODIFICACION: 10/01/2005. Gloria Maria Calle Hernandez. A�adidos campos Ref_catastral
		  y Num_fijo a la tabla.
MODIFICACI�N: 31/01/2005 Lucas Fernandez P�rez. Se a�ade el par�metro xMotivoCambioDomi.
		  Se eliminan los campos USR_CHG__CUENTA y F_CHG__CUENTA.
		  La informaci�n se almacenar� ahora en la tabla HISTO_DOMICILIACIONES.
*******************************************************************************/

CREATE or replace PROCEDURE MODIFICA_EXACCION(
	xMunicipio			in	char,
	xABONADO   			in	INTEGER,
	xNIF 				in	CHAR,
	xDNI_FACTURA		in	CHAR,
	xRepresentante		IN	CHAR,
	xCOD_SITUACION		in	CHAR,
	xNUMERO 			in	CHAR,
	xESCALERA			in	CHAR,		
	xPLANTA				in	CHAR,
	xPUERTA				in	CHAR,
	xREF_CATASTRAL		in	CHAR,
	xNUM_FIJO			in	CHAR,
	xID_EPIGRAFE		in	INTEGER,
	xEPIGRAFE			in	CHAR,
	xSECCION			in	CHAR,
	xCOD_ORDENANZA		in	CHAR,
	xCOD_TARIFA			in	CHAR,
	xUNIDADES			in	float,
	xMOTIVO				in	VARCHAR,
	xTIPO_ALTA			in	VARCHAR,
	xF_ALTA 			in	DATE,
    xDOMICILIADO 		in	CHAR,
 	xENTIDAD 			in	CHAR,
	xSUCURSAL 			in	CHAR,
	xDC 				in	CHAR,
	xCUENTA 			in	CHAR,
	xDNI_TITULAR 		in	CHAR,
	xF_DOMICILIACION	IN	DATE,
	xBase				in	float,
	xPorBon				in	float,
	xIVA				in	float,
	xTotal				in	float,
	xTipo1				in  float,
	xTipo2				in  float,
	xTipo3				in  float,
	xTipo4				in  float,
	xIDAlternativo    	IN	INTEGER,
	xMotivoCambioDomi 	IN  VARCHAR2,
	xTEXTO				IN	VARCHAR2,
	xCambiarRecibos		IN	CHAR)
AS
BEGIN  

	-- Se pone el posible motivo del cambio en la domiciliaci�n en USUARIOSGT (campo TEXTO2).
	-- Se indica el posible motivo por cambio de titularidad en TEXTO
    UPDATE USUARIOSGT SET TEXTO=xTEXTO, TEXTO2=xMotivoCambioDomi WHERE USUARIO=USER;

	UPDATE EXACCIONES 
	SET NIF=xNIF,DNI_FACTURA=xDNI_FACTURA,ID_EPIGRAFE=xID_EPIGRAFE,EPIGRAFE=xEPIGRAFE,
	SECCION=xSECCION,COD_SITUACION=xCOD_SITUACION,NUMERO=xNUMERO,
	ESCALERA=xESCALERA,PLANTA=xPLANTA,PUERTA=xPUERTA,
	REF_CATASTRAL=xREF_CATASTRAL,NUM_FIJO=xNUM_FIJO,
	COD_ORDENANZA=xCOD_ORDENANZA,COD_TARIFA=xCOD_TARIFA,
	UNIDADES=xUNIDADES,MOTIVO=xMOTIVO,TIPO_ALTA=xTIPO_ALTA,
	F_ALTA=xF_ALTA,BASE=ROUND(xBase,2), POR_BONIFICACION=xPorBon, IVA=ROUND(xIVA,2), 
	TOTAL=ROUND(xTotal,2),Tipo1=ROUND(xTipo1,2),Tipo2=ROUND(xTipo2,2),
	Tipo3=ROUND(xTipo3,2),Tipo4=ROUND(xTipo4,2),
	IDDOMIALTER=DECODE(xIDAlternativo,0,NULL,xIDAlternativo),
	REPRESENTANTE=xREPRESENTANTE
	WHERE ABONADO=xABONADO;

	EXACCIONES_BANCOS(xABONADO,xDOMICILIADO,xENTIDAD,xSUCURSAL,xDC,xCUENTA,xF_DOMICILIACION,xDNI_TITULAR);
	
  	IF (xCambiarRecibos='S') THEN   
  	    RECIBOS_EXAC_MODIFI(xABONADO);
	END IF;

END;
/	

/*******************************************************************************
Acci�n: Dar de baja o restaurar un abonado de exacciones.
*******************************************************************************/

CREATE OR REPLACE PROCEDURE DAR_BAJA_RESTAURA_EXACCION (
	xABONADO IN	INTEGER,
	xFECHA   IN	DATE,
	xMOTIVO  IN CHAR
)
AS
	xNEW_FECHA	DATE;
BEGIN

    -- PARA DAR DE BAJA Y RESTAURAR  
 	SELECT F_BAJA INTO xNEW_FECHA FROM EXACCIONES 
    	WHERE ABONADO=xABONADO;

	IF (xNEW_FECHA IS NULL) THEN 
		UPDATE EXACCIONES set F_BAJA=xFECHA,INCORPORADO='N',
					F_INCORPORACION=NULL, MOTIVO_BAJA=xMOTIVO
		Where ABONADO=xABONADO;
	ELSE
		UPDATE EXACCIONES Set F_BAJA=NULL, MOTIVO_BAJA=NULL
		Where ABONADO=xABONADO;
	END IF;
END;
/

/*******************************************************************************
Acci�n: Comprobar si hay recibos para un padr�n determinado.
*******************************************************************************/

CREATE or replace PROCEDURE CHECK_EXIT_PADEXACCION (
		xYEAR		in	CHAR,
		xPERIODO	in	CHAR,
		xORDENANZA	in	CHAR,
		xCUANTOS	out	INTEGER)
AS
BEGIN
	SELECT count(ABONADO) into xCuantos FROM RECIBOS_EXAC
	WHERE MUNICIPIO IN (SELECT MUNICIPIO FROM TMP_AYTOS WHERE USUARIO=USER)
		AND YEAR=xYEAR AND PERIODO=xPERIODO 
		AND COD_ORDENANZA=xORDENANZA;
END;
/

/*******************************************************************************
Acci�n: Comprobar si hay exacciones para una ordenanza y municipio determinados.
*******************************************************************************/

CREATE OR REPLACE PROCEDURE CHECK_EXIT_EXACCION (
		xMUNICIPIO  	IN CHAR,
		xCOD_ORDENANZA 	IN CHAR,
		xRESP 	 	OUT INTEGER)
AS
  ESTA INTEGER;
BEGIN

  xRESP:=0;
  SELECT COUNT(*) INTO ESTA
  FROM EXACCIONES WHERE MUNICIPIO=xMUNICIPIO AND COD_ORDENANZA=xCOD_ORDENANZA;
  
  IF (ESTA>0) THEN
      xRESP:=1;
  END IF;

END;
/

/*******************************************************************************
Acci�n: Borrar un padr�n completo.
MODIFICACI�N: 28/06/2002 M. Carmen Junco G�mez. Insertar una tupla en LogsPadrones
		  para controlar que se ha borrado un padr�n.
MODIFICACI�N: 04/12/2002 M. Carmen Junco G�mez. Insertamos el municipio y el periodo
		  en logspadrones.
*******************************************************************************/

CREATE OR REPLACE PROCEDURE BORRA_PADRON_VIEJO_EXAC (
		xPERIODO 	IN	CHAR,
		xYEAR 	IN	CHAR,
		xORDENANZA 	IN	CHAR)
AS
   CURSOR CMUNI IS SELECT MUNICIPIO FROM TMP_AYTOS WHERE USUARIO=USER;
BEGIN

   FOR vMUNI IN CMUNI 
   LOOP
      DELETE FROM RECIBOS_EXAC 
	WHERE MUNICIPIO=vMUNI.MUNICIPIO 
		AND YEAR=xYEAR 
		AND PERIODO=xPERIODO 
		AND COD_ORDENANZA=xORDENANZA;

	DELETE FROM COTITULARES_RECIBO WHERE PROGRAMA='EXACCIONES' 
		AND AYTO=vMUNI.MUNICIPIO
		AND PADRON=xORDENANZA AND YEAR=xYEAR AND PERIODO=xPERIODO;

   	-- Insertamos una tupla en LOGSPADRONES para controlar que esta acci�n ha sido ejecutada
   	INSERT INTO LOGSPADRONES (MUNICIPIO,PROGRAMA,PYEAR,PERIODO,COD_ORDENANZA,HECHO)
   	VALUES (vMUNI.MUNICIPIO,'EXACCIONES',xYEAR,xPERIODO,xORDENANZA,'Se Borra un Padr�n');     
   END LOOP;

END;
/

/*******************************************************************************
Acci�n: Incorporar un abonado al padr�n.
*******************************************************************************/

CREATE OR REPLACE PROCEDURE ANADE_PADRON_EXACCIONES 
			(xMUNICIPIO		IN	CHAR,
			xABONADO		IN	INTEGER,
			xF_INCORPORACION 	IN	DATE,
			xTIPO			IN    INTEGER)
AS
BEGIN

	IF xTIPO=0 THEN
		UPDATE EXACCIONES Set INCORPORADO='S',F_INCORPORACION=xF_INCORPORACION
		Where ABONADO=xABONADO;
	ELSE
		UPDATE EXACCIONES Set INCORPORADO='N',F_INCORPORACION=NULL
		Where ABONADO=xABONADO;
	END IF;

END;
/

/*******************************************************************************
Acci�n: Incorporar al padr�n todos los abonados dados de alta hasta una fecha
        determinada, siempre que no est�n ya incorporados o dados de baja.
MODIFICACI�N: 28/06/2002 M. Carmen Junco G�mez. Insertar una tupla en LogsPadrones
		  para controlar que se han incorporado al padr�n aquellos abonados que
		  no estaban incorporados y cuya fecha de alta es menor o igual a la 
		  pasado como par�metro.
MODIFICACI�N: 04/12/2002 M. Carmen Junco G�mez. Insertamos los campos municipio y
		  periodo en logspadrones
MODIFICACI�N: 15/02/2004 Lucas Fern�ndez P�rez. S�lo incorpora exacciones del 
		municipio del usuario o de los municipios que el usuario haya seleccionado. 
		Antes incorporaba las exacciones de todos los municipios.
*******************************************************************************/

CREATE OR REPLACE PROCEDURE INCOR_PADRON_EXACCIONES
		(xFECHA_EMISION	IN	DATE, 
		xFECHA_ALTA 	IN	DATE,
		xORDENANZA		IN	CHAR)
AS 
   -- cursor que recorre los distintos municipios de los recibos que se han 
   -- incorporado al padr�n en la fecha=xFecha_Emision
   CURSOR CMUNI IS SELECT DISTINCT MUNICIPIO FROM EXACCIONES
			 WHERE F_INCORPORACION=xFECHA_EMISION AND
  		 		   MUNICIPIO IN (SELECT MUNICIPIO FROM TMP_AYTOS WHERE USUARIO=USER);
BEGIN

	UPDATE EXACCIONES SET INCORPORADO='S', F_INCORPORACION =xFECHA_EMISION
		WHERE COD_ORDENANZA=xORDENANZA
			AND INCORPORADO='N' 
			AND F_BAJA IS NULL 
			AND F_ALTA<=xFECHA_ALTA
			AND MUNICIPIO IN (SELECT MUNICIPIO FROM TMP_AYTOS WHERE USUARIO=USER);

     -- Insertamos una tupla en LOGSPADRONES para controlar que esta acci�n ha sido ejecutada
     -- Una tupla por cada municipio
      FOR vMUNI IN CMUNI
      LOOP   	
   	   INSERT INTO LOGSPADRONES (MUNICIPIO,PROGRAMA,COD_ORDENANZA,HECHO)
   	   VALUES (vMUNI.MUNICIPIO,'EXACCIONES',xORDENANZA,
		     'Se realiza una Incorporaci�n al Padr�n');     
	END LOOP;

END;
/

/*******************************************************************************
Acci�n: Generaci�n de un padr�n de Exacciones.
MODIFICACI�N: 18/09/2001 Lucas Fern�ndez P�rez. Adaptaci�n al euro.
MODIFICACI�N: 28/06/2002 M. Carmen Junco G�mez. Insertar una tupla en LogsPadrones
		  para controlar que se ha generado un padr�n.
MODIFICACI�N: 18/09/2002 M. Carmen Junco G�mez. Se quita la tabla Tarifas_Exacciones
		  por la tabla Tarifas_Conceptos.
MODIFICACI�N: 04/12/2002 M. Carmen Junco G�mez. Insertamos los campos municipio y
		  periodo en logspadrones
MODIFICACI�N: 01/06/2006 Lucas Fern�ndez P�rez. Miraba DNI_TITULAR en vez de 
					DNI_FACTURA para obtener el domicilio fiscal.
MODIFICACI�N: 07/06/2006 Lucas Fern�ndez P�rez. NIF ser� el nif de exacciones,
	DNI_FACTURA ser� el representante o el dni_factura si no hay representante, y
	NOMBRE_FACTURA	ser� el nombre a quien va la factura (1.representante,2.dni_factura, 3.nif)
MODIFICACI�N: 05/02/2007 Lucas Fern�ndez P�rez. Ampliaci�n del campo domicilio de la tabla RECIBOS_EXAC
*******************************************************************************/

CREATE OR REPLACE PROCEDURE GENERA_PADRON_EXACCIONES (
	xORDENANZA		in	CHAR,
	xMUNICIPIO		in	CHAR,
	xYEAR 		in	CHAR,
	xPeriodo		in    CHAR,
	xDESDE		in	DATE,
	xHASTA		in	DATE,
	xCARGO		in	DATE,
	xCONCEPTO 		in	CHAR,
	xLINEA1 		in	CHAR,
	xLINEA2 		in	CHAR,
	xLINEA3 		in	CHAR)
AS

	xABONADO 		INTEGER;
	xSITUACION		VARCHAR(40);
	xDESCRIPCION      CHAR(50);
	xTARIFA 		CHAR(50);
	xNOMBRE	    VARCHAR(40);
	xDOMICILIO	    varchar(60);
	xCODPOSTAL 	    CHAR(5);
	xPoblacion 	    CHAR(35);
	xPROVINCIA	    VARCHAR2(35);


	xDCONTROL 		CHAR(2);
	xDIG_C60_M2       CHAR(2);
	xREFERENCIA 	CHAR(10);
	xREF_DC 		CHAR(2);
	xIMPORTE_CAD	CHAR(12);

	xEMISOR 	    	CHAR(6);
	xTRIBUTO 	    	CHAR(3);

	xNOMBRE_TITULAR   VARCHAR2(40);

	CURSOR c_CURSOR_GENERA_PADRON IS
      	SELECT * FROM EXACCIONES
            WHERE MUNICIPIO=xMUNICIPIO AND COD_ORDENANZA=xORDENANZA
		      AND INCORPORADO='S' AND F_BAJA IS NULL;
BEGIN


	--recoger los datos para el cuaderno 60
	BEGIN
		select EMISORA,CONCEPTO_BANCO into xEMISOR,xTRIBUTO from RELA_APLI_BANCOS
				where AYTO=xMUNICIPIO and CONCEPTO=xORDENANZA;
	EXCEPTION
		when no_data_found then
			BEGIN
			xEMISOR:='000000';
			xTRIBUTO:='000';
			END;
	END;


   FOR v_TExac IN c_CURSOR_GENERA_PADRON LOOP


	--nombre del abonado, es decir, a nombre de quien saldr� el recibo
	SELECT NOMBRE INTO xNOMBRE FROM CONTRIBUYENTES
		WHERE NIF=DECODE(v_TExac.REPRESENTANTE,NULL,DECODE(v_TExac.DNI_FACTURA, NULL, v_TExac.NIF, v_TExac.DNI_FACTURA),v_TExac.REPRESENTANTE);

	--domicilio fiscal en funcion de si tiene un representante o no.
	--Dentro de la funcion "GetDomicilioFiscal" se comprueba si tiene a su vez un domicilio
	--alternativo.
	IF v_TExac.REPRESENTANTE IS NULL THEN
		IF v_TExac.DNI_FACTURA IS NULL THEN
		   GetDomicilioFiscal(v_TExac.NIF, v_TExac.IDDOMIALTER,
				xDomicilio,xPoblacion,xProvincia,xCodPostal);
		ELSE
		   GetDomicilioFiscal(v_TExac.DNI_FACTURA, v_TExac.IDDOMIALTER,
				xDomicilio,xPoblacion,xProvincia,xCodPostal);
		END IF;
	ELSE
		GetDomicilioFiscal(v_TExac.REPRESENTANTE,v_TExac.IDDOMIALTER,
					xDomicilio,xPoblacion,xProvincia,xCodPostal);
	END IF;


	IF (v_TExac.DOMICILIADO='S') THEN
		SELECT NOMBRE INTO xNOMBRE_TITULAR FROM CONTRIBUYENTES
				WHERE NIF=v_TExac.DNI_TITULAR;
   ELSE
		xNOMBRE_TITULAR:=NULL;
	END IF;

	-- Protegido por integridad refencial
	SELECT CALLE INTO xSITUACION FROM CALLES WHERE CODIGO_CALLE=v_TExac.COD_SITUACION
	AND MUNICIPIO=xMUNICIPIO;

	SELECT TARIFA INTO xTARIFA FROM TARIFAS_CONCEPTOS
	WHERE AYTO=xMUNICIPIO AND CONCEPTO=v_TExac.COD_ORDENANZA
	AND COD_TARIFA=v_TExac.COD_TARIFA;

	SELECT DESCRIPCION INTO xDESCRIPCION FROM VWORDENANZAS WHERE MUNICIPIO=xMUNICIPIO
	AND CONCEPTO=v_TExac.COD_ORDENANZA;

      CALCULA_DC_60(v_TExac.TOTAL,v_TExac.ABONADO,
					xTRIBUTO,SUBSTR(xYEAR,3,2),xPERIODO,xEMISOR,xDCONTROL);

	--calcular los digitos de control del cuaderno 60 modalidad 2
	CALCULA_DC_MODALIDAD2_60(v_TExac.TOTAL,v_TExac.ABONADO,
							xTRIBUTO, SUBSTR(xYEAR,3,2), '1',
			to_char(xHASTA,'y'), to_char(xHASTA,'ddd'), xEMISOR, xDIG_C60_M2);

	--convierte el numero de abonado en caracter y relleno de ceros
	GETREFERENCIA(v_TExac.ABONADO,xREFERENCIA);

	ImporteEnCadena(v_TExac.TOTAL,xIMPORTE_CAD);


	--insertamos los cotitulares del recibo
	IF v_TExac.COTITULARES='S' THEN
		INSERT INTO COTITULARES_RECIBO(NIF,PROGRAMA,AYTO,PADRON,YEAR,PERIODO,RECIBO)
		SELECT NIF,'EXACCIONES',xMUNICIPIO,xORDENANZA,xYEAR,xPERIODO,v_TExac.ABONADO
		FROM COTITULARES
		WHERE ID_CONCEPTO=v_TExac.ABONADO AND PROGRAMA='EXACCIONES';
	END IF;


	INSERT INTO RECIBOS_EXAC
	     (ABONADO,MUNICIPIO,YEAR,PERIODO,NIF,	COD_ORDENANZA, ORDENANZA,
		COD_TARIFA,TARIFA,SITUACION,ESCALERA,PLANTA,PUERTA,NUMERO,
		UNIDADES,IMPORTE,TOTAL,BASE,POR_BONIFICACION,IVA,TIPO1,TIPO2,TIPO3,TIPO4,
		DOMICILIADO,ESTADO_BANCO,ENTIDAD,SUCURSAL,DC,CUENTA,F_DOMICILIACION,
		DNI_TITULAR,NOMBRE_TITULAR,
		DESDE,HASTA,F_CARGO,CONCEPTO,LINEA1,LINEA2,LINEA3,EMISOR,
		TRIBUTO,EJERCICIO,REMESA,REFERENCIA,DIGITO_CONTROL,
		DNI_FACTURA,NOMBRE_FACTURA,
		DISCRI_PERIODO,DIGITO_YEAR,F_JULIANA,DIGITO_C60_MODALIDAD2,
		DOMICILIO,POBLACION,PROVINCIA,CODIGO_POSTAL)
	VALUES
	     (v_TExac.ABONADO, xMUNICIPIO,xYEAR,xPERIODO, 
	     
      v_TExac.NIF,
		v_TExac.COD_ORDENANZA,RTRIM(xDESCRIPCION),
		v_TExac.COD_TARIFA, xTARIFA,

		xSITUACION,	v_TExac.ESCALERA,	v_TExac.PLANTA,v_TExac.PUERTA,v_TExac.NUMERO,

		v_TExac.UNIDADES,	xIMPORTE_CAD,v_TExac.TOTAL,
            v_TExac.BASE,v_TExac.POR_BONIFICACION,v_TExac.IVA,
		v_TExac.TIPO1,v_TExac.TIPO2,v_TExac.TIPO3,v_TExac.TIPO4,


		v_TExac.DOMICILIADO,DECODE(v_TExac.DOMICILIADO,'S','EB',NULL),
		DECODE(v_TExac.DOMICILIADO,'S',v_TExac.ENTIDAD,NULL),
		DECODE(v_TExac.DOMICILIADO,'S',v_TExac.SUCURSAL,NULL),
		DECODE(v_TExac.DOMICILIADO,'S',v_TExac.DC,NULL),
		DECODE(v_TExac.DOMICILIADO,'S',v_TExac.CUENTA,NULL),
		DECODE(v_TExac.DOMICILIADO,'S',v_TExac.F_DOMICILIACION,NULL),
		DECODE(v_TExac.DOMICILIADO,'S',v_TExac.DNI_TITULAR,NULL),
		xNOMBRE_TITULAR,

		xDESDE,xHASTA,xCARGO,RTRIM(xCONCEPTO),RTRIM(xLINEA1),RTRIM(xLINEA2),RTRIM(xLINEA3),
		xEMISOR,xTRIBUTO,SUBSTR(xYEAR,3,2),xPERIODO,xREFERENCIA,xDCONTROL,

		-- DNI_FACTURA tendr� el dni del representante o de la factura si no hay representante
		DECODE(v_TExac.REPRESENTANTE,NULL,v_TExac.DNI_FACTURA, v_TExac.REPRESENTANTE),
		xNOMBRE, -- nombre del representante,o de la factura si no hay representante, o del nif si o hay de dni_factura

		'1',to_char(xHASTA,'y'), to_char(xHASTA,'ddd'),xDIG_C60_M2,
		xDOMICILIO,xPoblacion,xProvincia,xCodPostal);

 END LOOP;

 -- Insertamos una tupla en LOGSPADRONES para controlar que esta acci�n ha sido ejecutada
 INSERT INTO LOGSPADRONES (MUNICIPIO,PROGRAMA,PYEAR,PERIODO,COD_ORDENANZA,HECHO)
 VALUES (xMUNICIPIO,'EXACCIONES',xYEAR,xPERIODO,xORDENANZA,'Se Genera un Padr�n');

END;
/

/*******************************************************************************
Acci�n: Genera todos los padrones de los municipios seleccionados.
   15/02/2005 Lucas Fern�ndez P�rez. Pongo el procedimiento en el fichero, 
   se hab�a perdido. Lo recupero de la base de datos.
*******************************************************************************/
CREATE OR REPLACE PROCEDURE GENERA_RECIBOS_EXACCIONES (
	xORDENANZA		in	CHAR,
	xYEAR 		in	CHAR,
	xPeriodo		in    CHAR,
	xDESDE		in	DATE,
	xHASTA		in	DATE,
	xCARGO		in	DATE,
	xCONCEPTO 		in	CHAR,
	xLINEA1 		in	CHAR,
	xLINEA2 		in	CHAR,
	xLINEA3 		in	CHAR)
AS
CURSOR CAYTOS IS
      SELECT MUNICIPIO FROM TMP_AYTOS WHERE USUARIO=USER;

BEGIN
   FOR v_aytos IN CAYTOS
   LOOP
      GENERA_PADRON_EXACCIONES(xORDENANZA,v_aytos.MUNICIPIO,
		xYEAR,xPeriodo,xDESDE,xHASTA,xCARGO,xCONCEPTO,xLINEA1,xLINEA2,xLINEA3);
   END LOOP;
END;
/

/*******************************************************************************
Acci�n: Para recibos domiciliados y no domiciliados de La Caixa.
MODIFICACI�N: 19/09/2001 Lucas Fern�ndez P�rez. Adaptaci�n al euro.
MODIFICACI�N: 20/09/2001 M. Carmen Junco G�mez. Seleccionaba datos de tablas como
              Exacciones que ya estaban en la tabla de Recibos.
MODIFICACI�N: 16/01/2004 Gloria Maria Calle Hernandez. Imprime las Tariras.
*******************************************************************************/

CREATE OR REPLACE PROCEDURE Proc_Caixa_EXAC
		(xMunicipio   IN CHAR,
		 xOrdenanza   IN CHAR,
		 xYear 	  IN CHAR, 
		 xPeri 	  IN CHAR)

AS
	xBoni			Float;	

	x2 				char(40);
	x3 				char(40);
	x4 				char(40);
	x5 				char(40);
	x6 				char(40);
	x7 				char(40);
	x8 				char(40);
	x9 				char(40);
	x10 			char(40);
	x11 			char(40);
	x12 			char(40);
	i 				integer;
	xRegis 			integer;
	
	mTipo1			varchar2(30);
	mTipo2			varchar2(30);
	mTipo3			varchar2(30);
	mTipo4			varchar2(30);
	
	HayTarifas		boolean;

	CURSOR CRECEXAC IS SELECT *
		FROM RECIBOS_EXAC
		WHERE MUNICIPIO=xMUNICIPIO and YEAR=xYear and PERIODO=xPeri and
			COD_ORDENANZA=xORDENANZA AND TOTAL>0;
BEGIN
  
	DELETE FROM RECIBOS_CAIXA WHERE USUARIO=USER;
	xRegis:=0;

	select count(*) into xRegis FROM recibos_Exac
	WHERE municipio=xMunicipio and year=xYear and periodo=xPeri AND 
		COD_ORDENANZA=xORDENANZA AND TOTAL>0;

	FOR v_RExac IN CRECEXAC LOOP

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
	   x12:='';
	   
	   HayTarifas:= True; -- Por defecto suponemos q siempre existen tarifas declaradas
	
	   i:=11;
	   x2:='SITUACION:' || substr(rTrim(v_RExac.Situacion),1,27);
	   x3:='ESCALERA: ' || v_RExac.Escalera || ' PLANTA: ' || v_RExac.Planta;
	   x4:='PUERTA: ' || v_RExac.Puerta;
	   x5:='NUMERO: ' || v_RExac.Numero;

	   select motivo INTO x6 from exacciones
		WHERE ABONADO=v_RExac.Abonado;
	  
	   x6:=substr(rTrim(x6),1,39);
	   x7:=substr(rTrim(v_RExac.ORDENANZA),1,39);
	   x8:=substr(rTrim(v_RExac.TARIFA),1,39);


   	BEGIN
	      select tipo1,tipo2,tipo3,tipo4 into mTipo1,mTipo2,mTipo3,mTipo4 from tarifas_conceptos 
   	      where concepto=v_RExac.cod_ordenanza and cod_tarifa=v_RExac.cod_tarifa;
	   EXCEPTION
	   	  WHEN NO_DATA_FOUND THEN
		  	   HayTarifas:= False;
	   END;
	   

	   IF HayTarifas THEN
	   	  IF mTipo1 is not null THEN
	   	  	 x9:= SUBSTR(mTipo1||': '||V_RExac.Tipo1,1,40);
		  END IF;
	   
	      IF mTipo2 is not null THEN
	   	     x10:= SUBSTR(mTipo2||': '||V_RExac.Tipo2,1,40);
   	      END IF;
	   
	      IF mTipo3 is not null THEN
	   	     x11:= SUBSTR(mTipo3||': '||V_RExac.Tipo3,1,40);
	      END IF;
	   
	      IF mTipo4 is not null THEN
	   	     x12:= SUBSTR(mTipo4||': '||V_RExac.Tipo4,1,40);
 	      END IF;
	   END IF;
	   
	   /* base
	      bonificacion
	      iva
	      Total */
	   --x9:='Base: '||To_Char(v_RExac.Base);
	   --xBoni:=ROUND(v_RExac.Base * v_RExac.POR_BONIFICACION /100,2);
	   --x10:='Bonificacion: ' || To_Char(xBoni,'0D99');
	   --x11:='IVA: ' || v_RExac.IVA;

	   INSERT INTO RECIBOS_CAIXA
		(ABONADO,NIF,NOMBRE,DOMICILIO,CODPOSTAL,MUNICIPIO,
		 ENTIDAD,SUCURSAL,DC,CUENTA,
		 TOTAL, Campo2, Campo3, Campo4, Campo5, Campo6, Campo7, 
		 Campo8, Campo9, Campo10, Campo11, Campo12,
		 CAMPOS_OPCIONALES, CUANTOS_REGISTROS)
	   VALUES
		(v_RExac.Abonado, 
		 DECODE(v_RExac.DNI_FACTURA,NULL,v_RExac.NIF,v_RExac.DNI_FACTURA),
		 v_RExac.Nombre_Factura, substr(v_RExac.Domicilio,1,40), 
		 v_RExac.Codigo_Postal, v_RExac.Poblacion, 
		 v_RExac.Entidad, v_RExac.Sucursal, v_RExac.DC, v_RExac.Cuenta, 
		 v_RExac.TOTAL*100, x2, x3, x4, x5, x6, x7, x8, x9, x10, x11, x12,
		 i, xRegis);	

	END LOOP;

END;
/

-- ***********************************************************************************
-- Autor: M. Carmen Junco G�mez. 09/05/2002
-- Acci�n: Para recibos domiciliados y no domiciliados de Caja Madrid.
--
-- Modificado : 16/09/2003. Lucas Fern�ndez P�rez. 
--		El campo MOTIVO no lo imprim�a por error. El texto "Base" lo cambia por "Cuota"
-- ************************************************************************************

CREATE OR REPLACE PROCEDURE Proc_CajaMadrid_EXAC
		(xMunicipio   IN CHAR,
		 xOrdenanza   IN CHAR,
		 xYear 	  IN CHAR, 
		 xPeri 	  IN CHAR)

AS
	xBoni			Float;	
	x1 			char(40);
	x2 			char(40);
	x3 			char(40);
	x4 			char(40);
	x5 			char(40);
	x6 			char(40);
	x7 			char(40);
	x8 			char(40);	
	x9 			char(40);
	x10 			char(40);

	i 			integer;
	xRegis 		integer;
      xPAIS			char(35);

      CURSOR CRECEXAC IS SELECT *
		FROM RECIBOS_EXAC
		WHERE MUNICIPIO=xMUNICIPIO and YEAR=xYear and PERIODO=xPeri and
			COD_ORDENANZA=xORDENANZA AND TOTAL>0;
BEGIN
  
	DELETE FROM RECIBOS_CAJAMADRID WHERE USUARIO=USER;
	xRegis:=0;

	select count(*) into xRegis FROM recibos_Exac
	WHERE MUNICIPIO=xMunicipio and YEAR=xYear and PERIODO=xPeri AND 
		COD_ORDENANZA=xORDENANZA AND TOTAL>0;

	FOR v_RExac IN CRECEXAC LOOP

		SELECT PAIS INTO xPAIS FROM CONTRIBUYENTES
		WHERE NIF=v_RExac.NIF;

		i:=10;
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

	      x1:='SITUACION:' || substr(rTrim(v_RExac.Situacion),1,30);
	      x2:='ESCALERA: ' || v_RExac.Escalera || ' PLANTA: ' || v_RExac.Planta;
	      x3:='PUERTA: ' || v_RExac.Puerta;
	      x4:='NUMERO: ' || v_RExac.Numero;

	      SELECT MOTIVO INTO x5 FROM EXACCIONES
		WHERE ABONADO=v_RExac.Abonado;

	      
	      x6:=substr(rTrim(v_RExac.ORDENANZA),1,40);
	      x7:=substr(rTrim(v_RExac.TARIFA),1,40);


	      --base bonificacion iva Total 

	      x8:='Cuota: '||To_Char(v_RExac.Base);

	      xBoni:=ROUND(v_RExac.Base * v_RExac.POR_BONIFICACION /100,2);
	      x9:='Bonificacion: ' || To_Char(xBoni,'0D99');
	      x10:='IVA: ' || v_RExac.IVA;

		INSERT INTO RECIBOS_CAJAMADRID
			(ABONADO,NIF,NOMBRE,DOMICILIO,CODPOSTAL,POBLACION,PROVINCIA,PAIS,
			 REFERENCIA,DOMICILIADO,ENTIDAD,SUCURSAL,DC,CUENTA,
			 TOTAL,Campo1,Campo2,Campo3,Campo4,Campo5,Campo6,Campo7,Campo8,
			 Campo9,Campo10,CAMPOS_OPCIONALES,CUANTOS_REGISTROS)
		VALUES
			(v_RExac.ABONADO,
			 DECODE(v_RExac.DNI_FACTURA,NULL,v_RExac.NIF,v_RExac.DNI_FACTURA),
		       v_RExac.Nombre_Factura,substr(v_RExac.Domicilio,1,40),v_RExac.Codigo_Postal,
			 v_RExac.Poblacion,v_RExac.Provincia,xPais,
			 DECODE(v_RExac.DOMICILIADO,'S',v_RExac.REFERENCIA||v_RExac.DIGITO_CONTROL,
			        v_RExac.REFERENCIA),	
			 DECODE(v_RExac.DOMICILIADO,'S','D',' '),v_RExac.Entidad,v_RExac.Sucursal,
			 v_RExac.DC,v_RExac.Cuenta,v_RExac.TOTAL*100,
			 x1,x2,x3,x4,x5,x6,x7,x8,x9,x10,i,xRegis);	

	END LOOP;

END;
/

-- *******************************************************************************
-- Acci�n: Inserci�n de datos en tabla temporal para la generaci�n del Cuaderno19.
-- MODIFICACI�N: 17/09/2001 Agustin Leon Robles. Se ha a�adido que en el fichero
--		  del banco salga el a�o y el periodo.
-- MODIFICACI�N: 19/09/2001 Lucas Fern�ndez P�rez. Adaptaci�n al euro.
-- MODIFICACI�N: 19/08/2002 Lucas Fern�ndez P�rez. No deber�n entrar en el disco aquellos
--		  recibos que se hayan pasado ya a Recaudaci�n y que se encuentren 
--		  ingresados o dados de baja.
-- MODIFICACI�N: 19/08/2002 Lucas Fern�ndez P�rez. El t�tulo "Base" se cambia por "Cuota"
-- MODIFICACI�N: 11/12/2003 Lucas Fern�ndez P�rez. Los recibos ingresados no pueden entrar
--	en el disco de domiciliaciones. Para comprobar si el recibo estaba ingresado consultaba
--	en valores where PADRON=SELECT CONCEPTO FROM PROGRAMAS WHERE PROGRAMA='EXACCIONES';
--	Esa sentencia era err�nea, puesto que las exacciones no tienen un concepto �nico.
--  Se cambia por where PADRON=xOrdenanza, un parametro que si indica el Padron en Valores
-- MODIFICACI�N: 21/01/2004 Lucas Fern�ndez P�rez. Bonificaciones por domiciliaciones.
--	  Obtiene de la tabla PROGRAMAS la bonificaci�n por domiciliaci�n y la aplica al 
--		importe del recibo, para que en el disco del c19 vaya el importe bonificado.
-- MODIFICACION: 28/05/2004 Gloria Maria Calle Hernandez. A�adido campo AYTO a la tabla 
--			  Recibos_Cuadreno19 para generar ficheros por ayuntamientos (xej. Catoure).
-- MODIFICACI�N: 07/06/2006 Lucas Fern�ndez P�rez. Si DNI_TITULAR es null, el dni_titular lo tomaba
--  del nif de recibos_exac, y ahora intenta tomar primero el dni_factura y luego el nif.
-- MODIFICACI�N: 06/02/2007 Lucas Fern�ndez P�rez. Ampliaci�n de la variable xDomi_Titular para recoger el 
--					nuevo domicilio con bloque y portal.
-- ****************************************************************************************

CREATE OR REPLACE PROCEDURE MakeCuaderno19_Exacciones (
	xYear 	in	char,
	xPeri 	in	char,
	xOrdenanza 	in	char,
	xEstado 	in	char,
	xRegis	in 	integer)

AS
	xNIF_TITULAR	CHAR(10);
	xNombre_Titular 	char(40);
	xDomi_Titular 	char(60);
	xTotal 		float;
	x2 			char(40);
	x3 			char(40);
	x4 			char(40);
	x5 			char(40);
	x6 			char(40);
	x7			char(40);
	x8 			char(40);
	x9 			char(40);
	x10			char(40);
	x11			char(40);
	x12			char(40);

	xPoblacion		CONTRIBUYENTES.Poblacion%Type;
	xProvincia		CONTRIBUYENTES.Provincia%Type;
	xCodPostal	 	char(5);
	xBoni			Float;

	xF_INGRESO			DATE;
	xFECHA_DE_BAJA		DATE;
	xBONIDOMI			FLOAT;

	cursor CRECIEXAC is select * from recibos_exac 
		              where cod_ordenanza=xOrdenanza
			   		  and year=xYear 
					  and periodo=xPeri 
					  and estado_banco=xEstado
					  and total>0
		  			  AND MUNICIPIO IN (SELECT DISTINCT MUNICIPIO FROM TMP_AYTOS WHERE USUARIO=USER);
					  
BEGIN

    

 	-- recogemos la bonificacion por domiciliaciones para las exacciones
	SELECT PORC_BONIFI_DOMI INTO  xBONIDOMI FROM PROGRAMAS WHERE PROGRAMA='EXACCIONES';

   FOR v_RExac IN CRECIEXAC
   LOOP

	begin
		SELECT F_INGRESO,FECHA_DE_BAJA INTO xF_INGRESO,xFECHA_DE_BAJA
		FROM VALORES WHERE AYTO=v_RExac.MUNICIPIO AND PADRON=xOrdenanza AND
					 YEAR=v_RExac.YEAR AND PERIODO=v_RExac.PERIODO AND
					 RECIBO=v_RExac.ABONADO AND TIPO_DE_OBJETO='R';
		Exception
		   When no_data_found then
			xF_INGRESO:=NULL;
			xFECHA_DE_BAJA:=NULL;
	end;

	IF ((xF_INGRESO IS NULL) AND (xFECHA_DE_BAJA IS NULL)) THEN	

		-- Datos del TITULAR de la cuenta 
		IF v_RExac.DNI_TITULAR IS NULL THEN
			if v_RExac.DNI_FACTURA IS NULL THEN
				xNIF_TITULAR:=v_RExac.NIF;
			else
			   xNIF_TITULAR:=v_RExac.DNI_FACTURA;
		   end if;
		ELSE
		   xNIF_TITULAR:=v_RExac.DNI_TITULAR;
		END IF;
		GETContribuyente(xNIF_TITULAR, 
			xNOMBRE_TITULAR, xPoblacion, xProvincia, xCodPostal, xDomi_Titular);

		x2:='SITUACION:' || substr(rTrim(v_RExac.Situacion),1,30);
		x3:='ESCALERA: ' || v_RExac.Escalera || ' PLANTA: ' || v_RExac.Planta;
		x4:='PUERTA: ' || v_RExac.Puerta;
		x5:='NUMERO: ' || v_RExac.Numero;

		-- por ejemplo en la guarderia, en este campo tendremos el nombre del ni�o
		begin
		   SELECT motivo INTO x6 FROM exacciones WHERE ABONADO=v_RExac.Abonado;
		   EXCEPTION
			WHEN NO_DATA_FOUND THEN
			   x6:='';
		end;
	
		x7:=substr(rTrim(v_RExac.ORDENANZA),1,40);
		x8:=substr(rTrim(v_RExac.TARIFA),1,40);


		-- base
		-- bonificacion
		-- iva
		-- Total 
		x9:='Cuota: '||To_Char(v_RExac.Base);
		xBoni:=Round(v_RExac.Base * v_RExac.POR_BONIFICACION /100,2);
		x10:='Bonificacion: ' || To_Char(xBoni);
		x11:='IVA: ' || v_RExac.IVA;
		x12:='A�O: '||xYEAR||' PERIODO: '||xPERI;

      	INSERT Into RECIBOS_CUADERNO19 
	       (AYTO,ABONADO,NIF,NOMBRE,DOMICILIO,CODPOSTAL,MUNICIPIO,NOMBRE_TITULAR,
		    ENTIDAD,SUCURSAL,DC,CUENTA,TOTAL,
		    Campo2, Campo3, Campo4, Campo5, Campo6, Campo7, Campo8, Campo9,
		    Campo10, Campo11, Campo12, CAMPOS_OPCIONALES, CUANTOS_REGISTROS)
	 	VALUES 
		   (v_RExac.MUNICIPIO,v_RExac.ABONADO,xNIF_TITULAR,v_RExac.NOMBRE_FACTURA,
			SUBSTR(xDOMI_TITULAR,1,40),xCODPOSTAL,xPoblacion, xNOMBRE_TITULAR, 
			v_RExac.ENTIDAD,v_RExac.SUCURSAL,v_RExac.DC,v_RExac.CUENTA,
			ROUND(v_RExac.TOTAL*(1-(xBoniDomi/100)),2), 
			x2, x3, x4, x5, x6, x7, x8, x9, x10, x11, x12, 11,xREGIS);
	END IF;
   END LOOP;
	
END;
/

/*******************************************************************************
Acci�n: Cuaderno19 para una Ordenanza de Exacciones.
MODIFICACI�N: 20/09/2001 M. Carmen Junco G�mez. Hay que borrar la tabla temporal
	        al comienzo de este procedimiento y no en el MakeCuaderno19_Exacciones.
MODIFICACION: 28/05/2004 Gloria Maria Calle Hernandez. A�adido campo AYTO a la tabla 
			  Recibos_Cuadreno19 para generar ficheros por ayuntamientos (xej. Catoure).
*******************************************************************************/

CREATE OR REPLACE PROCEDURE Cuaderno19_Exacciones (
	xYear 	in	char,
	xPeri 	in	char,
	xOrdenanza 	in	char,
	xEstado 	in	char)
as
xRegis Integer;
begin

   /* Borrar los datos de este usuario de la tabla temporal */
   DELETE FROM RECIBOS_CUADERNO19 WHERE USUARIO=USER;

   xRegis:=0;

   select count(*) into xRegis FROM recibos_Exac
   where cod_Ordenanza=xOrdenanza
		and year=xYear 
		and periodo=xPeri
	 	and Estado_banco=xEstado
		and total>0
	    AND MUNICIPIO IN (SELECT DISTINCT MUNICIPIO FROM TMP_AYTOS WHERE USUARIO=USER);


if (xRegis > 0) then
   MakeCuaderno19_Exacciones(xYear, xPeri, xOrdenanza , xEstado, xRegis);
end if;

end;
/

/*******************************************************************************
Autor: Agustin Leon Robles.
Fecha: 23/08/2001
Acci�n: Inserci�n de datos en tabla temporal para la Impresi�n de recibos en Exacc.
MODIFICACI�N: 02/09/2002 M� Carmen Junco G�mez. Incluimos los campos Muni, DMunicipio, 
		  CodConcepto y Plazo para indicar el c�digo del m�nicipio, 
		  descripci�n de �ste, c�digo del concepto
		  y un texto indicando el n�mero de plazo que se imprime.
MODIFICACI�N: 18/09/2002 M. Carmen Junco G�mez. Se cambia la Tabla Tarifas_Exacciones
		  por la tabla Tarifas_Conceptos.
MODIFICACI�N: 18/09/2002 Agustin Leon Robles. Para que se pueda imprimir el numero de metros
		  de los vados, el numero de plazas y el numero de placa 			
MODIFICACI�N: 07/06/2006 Lucas Fern�ndez P�rez. En la tabla escrib�a en el campo nif el nif 
  de recibos_exac, y ahora intenta tomar primero el dni_factura y luego el nif.

*******************************************************************************/

CREATE OR REPLACE PROCEDURE WriteTempExac
		(v_RegistroExac 	IN Recibos_Exac%ROWTYPE,
		xMUNICIPIO		IN CHAR,
		xYEAR			IN CHAR,
		xPERI			IN CHAR,
		xCODCONCEPTO      IN CHAR)
AS
	xNOMBRE_ENTIDAD	CHAR(50);
	xHASTA1		DATE;
	xDomiTribu		char(60);	
	xDMUNICIPIO       VARCHAR2(50);
	xPLAZO            CHAR(15);
	xMOTIVO		VARCHAR(40);

BEGIN

	SELECT MOTIVO INTO xMOTIVO FROM EXACCIONES WHERE ABONADO=v_RegistroExac.ABONADO;

	-- recogemos la descripci�n del municipio
	SELECT POBLACION INTO xDMUNICIPIO FROM DATOSPER WHERE MUNICIPIO=xMUNICIPIO;

	-- dependiendo del periodo ponemos un texto u otro en xPlazo
	IF xPERI='00' THEN
         xPLAZO:='PLAZO UNICO';
	ELSIF xPERI<'10' THEN
	   xPLAZO:='PLAZO '||SUBSTR(xPERI,2,1);
	ELSE
	   xPLAZO:='PLAZO '||xPERI;
	END IF;

	/* Domicilio tributario */
	xDomiTribu:=v_RegistroExac.Situacion||' '||v_RegistroExac.Numero||' '||
			v_RegistroExac.Escalera||' '||v_RegistroExac.Planta||' '||
			v_RegistroExac.Puerta;
	
      /* En caso de estar domiciliado, nombre de la Entidad */          
      xNOMBRE_ENTIDAD:='';
	begin
	   SELECT NOMBRE INTO xNOMBRE_ENTIDAD FROM ENTIDADES WHERE CODIGO=v_RegistroExac.ENTIDAD;
      EXCEPTION
		WHEN NO_DATA_FOUND THEN
		   NULL;
	end;

	xHASTA1:=v_RegistroExac.HASTA+1; /* fecha del hasta mas un d�a */          

      INSERT INTO IMP_RECIBOS_EXAC 
           (USUARIO,MUNI,DMUNICIPIO,CODCONCEPTO,Anio,Periodo,PLAZO,Abonado,Nif,Nombre,
		DomiFiscal,CodPostal,Poblacion,
            Provincia,Total,Por_Bonificacion,Iva,Base,COD_ORDENANZA,COD_TARIFA,
		Ordenanza,Tarifa,UNIDADES,DomiTribu,Refe,DC,TRIBUTO,EJERCICIO,REMESA,
		IMPO,EMISOR,Desde,Hasta,Cargo,Hasta1,ENTIDAD,SUCURSAL,DCCUENTA,
		CUENTA,TITULAR,NOMBRE_ENTIDAD,NOMBRE_TITULAR,CONCEPTO,
		DISCRI_PERIODO,DIGITO_YEAR,F_JULIANA,DIGITO_C60_MODALIDAD2,
 		COD_BARRAS_MOD1,COD_BARRAS_MOD2,
		TIPO1,TIPO2,TIPO3,TIPO4,MOTIVO)
	VALUES
           (UID,xMUNICIPIO,xDMUNICIPIO,xCODCONCEPTO,v_RegistroExac.YEAR,v_RegistroExac.Periodo,
		xPLAZO,v_RegistroExac.Abonado,
		DECODE(v_RegistroExac.Dni_Factura,NULL,v_RegistroExac.Nif,v_RegistroExac.DNI_Factura),
		v_RegistroExac.NOMBRE_FACTURA,v_RegistroExac.Domicilio,
		v_RegistroExac.Codigo_Postal,v_RegistroExac.Poblacion,v_RegistroExac.Provincia,
		v_RegistroExac.Total,v_RegistroExac.Por_Bonificacion,v_RegistroExac.Iva,
		v_RegistroExac.BASE,v_RegistroExac.COD_ORDENANZA,v_RegistroExac.COD_TARIFA,
		v_RegistroExac.Ordenanza,v_RegistroExac.Tarifa,v_RegistroExac.UNIDADES,
		xDomiTribu,v_RegistroExac.Referencia,v_RegistroExac.DIGITO_CONTROL,
		v_RegistroExac.TRIBUTO,v_RegistroExac.EJERCICIO,v_RegistroExac.REMESA,
		v_RegistroExac.IMPORTE,v_RegistroExac.EMISOR,v_RegistroExac.Desde,
		v_RegistroExac.Hasta,v_RegistroExac.F_Cargo,xHasta1,
		v_RegistroExac.ENTIDAD,v_RegistroExac.SUCURSAL,v_RegistroExac.DC,
		v_RegistroExac.CUENTA,v_RegistroExac.DNI_TITULAR,xNOMBRE_ENTIDAD,
		v_RegistroExac.NOMBRE_TITULAR,v_RegistroExac.CONCEPTO,
		v_RegistroExac.DISCRI_PERIODO,v_RegistroExac.DIGITO_YEAR,v_RegistroExac.F_JULIANA,
		v_RegistroExac.DIGITO_C60_MODALIDAD2,

		'90502'||v_RegistroExac.EMISOR||v_RegistroExac.Referencia||
		v_RegistroExac.DIGITO_CONTROL||
		v_RegistroExac.TRIBUTO||v_RegistroExac.EJERCICIO||v_RegistroExac.REMESA||
		LPAD(v_RegistroExac.IMPORTE*100,8,'0'),

		'90521'||v_RegistroExac.EMISOR||v_RegistroExac.REFERENCIA||
		v_RegistroExac.DIGITO_C60_MODALIDAD2||v_RegistroExac.DISCRI_PERIODO||
		v_RegistroExac.TRIBUTO||v_RegistroExac.EJERCICIO||
		v_RegistroExac.DIGITO_YEAR||v_RegistroExac.F_JULIANA||
		LPAD(v_RegistroExac.IMPORTE*100,8,'0')||'0',
		v_RegistroExac.TIPO1,v_RegistroExac.TIPO2,
		v_RegistroExac.TIPO3,v_RegistroExac.TIPO4,xMOTIVO);

END;
/

/*******************************************************************************
Acci�n: Impresi�n de recibos de exacciones seg�n el c�digo de la ordenanza dado.
MODIFICACI�N: 23/08/2001 Agustin Leon Robles.
MODIFICACI�N: 02/09/2002 M� Carmen Junco G�mez. Se a�aden dos nuevos par�metros en 
		  la llamada a WriteTempExac (xMunicipio,xCodConcepto)
MODIFICACI�N: 05/09/2005 Gloria M� Calle Hernandez. A�adido impresi�n ordenada por
		  codigo postal y domicilio fiscal.
*******************************************************************************/

CREATE OR REPLACE PROCEDURE Imprime_Recibos_Exac (
		xMUNICIPIO    IN CHAR,
		xID           IN INTEGER,
		xYear         IN CHAR, 
		xPeri         IN CHAR, 
		xDomi         IN CHAR,
		xReciDesde    IN INTEGER,
		xReciHasta    IN INTEGER,
		xCodOrdenanza IN CHAR,
		xOrden	  IN CHAR)
AS
	I INTEGER;

	CURSOR COrdenAlfabetico IS 
		SELECT * FROM RECIBOS_EXAC 
		WHERE MUNICIPIO=xMUNICIPIO and year=xYear and periodo=xPeri		
		      and cod_ordenanza=xCodOrdenanza and domiciliado=xDomi
		order by nombre_factura,abonado;

	CURSOR COrdenFiscal IS 
		SELECT * FROM RECIBOS_EXAC 
		WHERE MUNICIPIO=xMUNICIPIO and year=xYear and periodo=xPeri		
		      and cod_ordenanza=xCodOrdenanza and domiciliado=xDomi
		order by domicilio,abonado;

	CURSOR COrdenTributario IS 
		SELECT * FROM RECIBOS_EXAC 
		WHERE MUNICIPIO=xMUNICIPIO and year=xYear and periodo=xPeri		
		      and cod_ordenanza=xCodOrdenanza and domiciliado=xDomi
		order by situacion,numero,escalera,planta,puerta,abonado;

	CURSOR COrdenCodPostalDom IS 
		SELECT * FROM RECIBOS_EXAC 
		WHERE MUNICIPIO=xMUNICIPIO and year=xYear and periodo=xPeri		
		      and cod_ordenanza=xCodOrdenanza and domiciliado=xDomi
		order by codigo_postal,domicilio;

	v_RegistroExac      Recibos_Exac%ROWTYPE;

BEGIN

   I:=0;

   DELETE FROM IMP_RECIBOS_EXAC WHERE USUARIO=UID;

   /*imprimir un recibo*/
   IF (xID<>0 ) then 
		SELECT * INTO v_RegistroExac FROM RECIBOS_EXAC WHERE ID=xID;
		WriteTempExac(v_RegistroExac,xMUNICIPIO,xYear,xPeri,xCODORDENANZA);
   ELSE /*del IF (xID<>0 ) then */

	if xOrden='A' then
         
		OPEN COrdenAlfabetico;
		LOOP
			FETCH COrdenAlfabetico INTO v_RegistroExac;
			EXIT WHEN COrdenAlfabetico%NOTFOUND;
	
			I:=I+1;

			IF (I >= xReciDesde and I <= xReciHasta) then
				WriteTempExac(v_RegistroExac,xMUNICIPIO,xYear,xPeri,xCODORDENANZA);
			ELSE
					IF I > xRECIHASTA THEN
						EXIT;
					END IF;
			END IF;    	    

	   	  END LOOP;
      	  CLOSE COrdenAlfabetico;

	--order codigo_postal, domicilio
	elsif xOrden='C' then
         
		OPEN COrdenCodPostalDom;
		LOOP
			FETCH COrdenCodPostalDom INTO v_RegistroExac;
			EXIT WHEN COrdenCodPostalDom%NOTFOUND;
	
			I:=I+1;

			IF (I >= xReciDesde and I <= xReciHasta) then
				WriteTempExac(v_RegistroExac,xMUNICIPIO,xYear,xPeri,xCODORDENANZA);
			ELSE
					IF I > xRECIHASTA THEN
						EXIT;
					END IF;
			END IF;    	    

	   	  END LOOP;
      	  CLOSE COrdenCodPostalDom;

	--order fiscal o tributario
	else

		if xOrden='F' then
			OPEN COrdenFiscal;
			LOOP
				FETCH COrdenFiscal INTO v_RegistroExac;
				EXIT WHEN COrdenFiscal%NOTFOUND;
	
				I:=I+1;
	
				IF (I >= xReciDesde and I <= xReciHasta) then
					WriteTempExac(v_RegistroExac,xMUNICIPIO,xYear,xPeri,xCODORDENANZA);
				ELSE
					IF I > xRECIHASTA THEN
						EXIT;
					END IF;
				END IF;    	    

			END LOOP;
			CLOSE COrdenFiscal;

		else	--orden tributario
			OPEN COrdenTributario;
			LOOP
				FETCH COrdenTributario INTO v_RegistroExac;
				EXIT WHEN COrdenTributario%NOTFOUND;
	
				I:=I+1;
	
				IF (I >= xReciDesde and I <= xReciHasta) then
					WriteTempExac(v_RegistroExac,xMUNICIPIO,xYear,xPeri,xCODORDENANZA);
				ELSE
					IF I > xRECIHASTA THEN
						EXIT;
					END IF;
				END IF;    	    

			END LOOP;
			CLOSE COrdenTributario;
		end if;

	end if; /*del if xOrden='A' then*/

   END IF; /*del IF (xID<>0 ) then */
END;
/



/**************************************************************************************
 Autor: 28/09/2004 Gloria Maria Calle Hernandez 
 Acci�n: Modifica recibo/s de EXAC, tanto en GT como en RECA, cuando se modifican los 
	  datos de un abonado, y siempre que el recibo est� en voluntaria.
 Par�metros: xABONADO: ID del abonado de la tabla de IBI que se est� modificando.
 MODIFICADO: 15/10/2004. Gloria Maria Calle Hernandez.
 						 Modificaba todo lo q estuviera en voluntaria sin restringuir o comprobar q
 						 estuviera pendiente, as� modificaba erroneamnete incluso lo pagado. Corregido.
 MODIFICACI�N: 01/06/2006 Lucas Fern�ndez P�rez. No ten�a en cuenta el dni_representante.

 MODIFICACI�N: 07/06/2006 Lucas Fern�ndez P�rez. Toma para recibos_exac los datos del representante,
   o de dni_factura si no existe representante, o de nif si no existe representante ni dni_factura.
   Esos datos tambi�n los pasa a valores.
MODIFICACI�N: 05/02/2007 Lucas Fern�ndez P�rez. Ampliaci�n del campo domicilio de la tabla RECIBOS_EXAC
*****************************************************************************************/
CREATE OR REPLACE PROCEDURE RECIBOS_EXAC_MODIFI(
	xABONADO IN INTEGER)
AS

	v_registro	 EXACCIONES%ROWTYPE;
	v_recibo	 RECIBOS_EXAC%ROWTYPE;
	
	mVOL_EJE 	 CHAR(1);
	mPENDIENTE 	 CHAR(1);
	mVALOR	 	 INTEGER;
	mPUNTEO	 	 INTEGER;

	xDOMI_TRIBUTARIO VARCHAR2(50);
	xDOMICILIO		 VARCHAR2(60);
	xPOBLACION		 VARCHAR2(35);
	xPROVINCIA		 VARCHAR2(35);
	xCP			 	 CHAR(5);

	xCUANTOS 		 INTEGER;
	
	xDOMI_OLD		 CHAR(1);
	
	xSITUACION		 VARCHAR2(40);
	xNOMBRE			 VARCHAR2(40);

	-- cursor que recorre los distintos periodos de los distintos recibos que 
	-- se han podido emitir para este abonado. Han de ser recibos emitidos en el
	-- a�o en curso.
	CURSOR CPERIODOS IS SELECT DISTINCT PERIODO,ID FROM RECIBOS_EXAC
				  WHERE ABONADO=xABONADO;				  

BEGIN

	-- Leer todos los datos de la ficha de un abonado
	SELECT * INTO v_registro FROM EXACCIONES WHERE ABONADO=xABONADO;

	-- recorrer los distintos recibos que se han podido generar para este abonado
	FOR vPERIODOS IN CPERIODOS 
	LOOP
		-- Recogemos los datos del recibo
	    SELECT * INTO v_recibo FROM RECIBOS_EXAC WHERE ID=vPERIODOS.ID;
	    
	    begin
	       SELECT ID,VOL_EJE,DECODE(F_INGRESO,NULL,DECODE(F_SUSPENSION,NULL,DECODE(FECHA_DE_BAJA,NULL,
				  			 DECODE(FECHA_PROPUESTA_BAJA,NULL,'S','N'),'N'),'N'),'N') INTO mVALOR,mVOL_EJE,mPENDIENTE 
	         FROM VALORES 
            WHERE AYTO=v_recibo.MUNICIPIO 
		      AND PADRON=v_recibo.COD_ORDENANZA 
		      AND YEAR=v_recibo.YEAR 
		      AND PERIODO=v_recibo.PERIODO 
		      AND RECIBO=v_recibo.ABONADO;
	       Exception
	          When no_data_found then
	  	         mVOL_EJE:=NULL;
	    end;
	   
	    -- Si no se encuentra el valor, comprobar si est� en el punteo, estando en punteo siempre estar� pendiente 
	    IF (mVOL_EJE IS NULL) THEN
	       begin
		      SELECT ID,VOL_EJE INTO mPUNTEO,mVOL_EJE FROM PUNTEO
			   WHERE AYTO=v_recibo.MUNICIPIO
			     AND PADRON=v_recibo.COD_ORDENANZA 
				 AND YEAR=v_recibo.YEAR
				 AND PERIODO=v_recibo.PERIODO
				 AND RECIBO=v_recibo.ABONADO;
			  Exception
			     When no_data_found then
			        mVOL_EJE:=NULL;
		   end;
	    END IF;

	    -- si el recibo est� en Voluntaria en RECA a�n PENDIENTE o todavia no se ha pasado a recaudaci�n 
	    IF ((mVOL_EJE='V' and mPENDIENTE='S') or (mVOL_EJE IS NULL)) THEN

	        xDOMI_OLD:=v_recibo.DOMICILIADO;
 
			-- Protegido por integridad refencial 
			SELECT CALLE INTO xSITUACION FROM CALLES WHERE CODIGO_CALLE=v_Registro.COD_SITUACION
			AND MUNICIPIO=v_Registro.MUNICIPIO;

	        --domicilio tributario 
	        xDOMI_TRIBUTARIO:=LTRIM(RTRIM(xSITUACION))||' '||
				      LTRIM(RTRIM(v_registro.ESCALERA))||' '||
				      LTRIM(RTRIM(v_registro.PLANTA))||' '||
				      LTRIM(RTRIM(v_registro.PUERTA))||' '||
	  			      LTRIM(RTRIM(v_registro.NUMERO));
     
	       --domicilio fiscal en funcion de si tiene un representante o no, y de si tiene dni_factura o no.
	       --Dentro de la funcion "GetDomicilioFiscal" se comprueba si tiene a su vez 
	       --un domicilio alternativo.
	       IF v_registro.REPRESENTANTE IS NULL THEN		

				IF v_registro.DNI_FACTURA IS NULL THEN
		          GetDomicilioFiscal(v_registro.NIF,v_Registro.IDDOMIALTER,
		  	            xDomicilio,xPoblacion,xProvincia,xCP);
				ELSE 
		          GetDomicilioFiscal(v_registro.DNI_FACTURA,v_Registro.IDDOMIALTER,
		  	            xDomicilio,xPoblacion,xProvincia,xCP);
				END IF;
				
	       ELSE
		      GetDomicilioFiscal(v_Registro.REPRESENTANTE,v_Registro.IDDOMIALTER,
		 	                xDomicilio,xPoblacion,xProvincia,xCP);
	       END IF;

	       -- modificamos el recibo en gesti�n tributaria y recaudaci�n
	       xDOMI_OLD:=v_recibo.DOMICILIADO;

		   --nombre del abonado, es decir, a nombre de quien saldr� el recibo
		   SELECT NOMBRE INTO xNOMBRE FROM CONTRIBUYENTES
		   WHERE NIF=DECODE(v_Registro.REPRESENTANTE,NULL,DECODE(v_Registro.DNI_FACTURA,NULL,v_Registro.NIF,v_Registro.DNI_FACTURA),v_Registro.REPRESENTANTE);
	       
           UPDATE RECIBOS_EXAC SET NIF=v_registro.NIF,
           				DNI_FACTURA=DECODE(v_Registro.REPRESENTANTE,NULL,v_Registro.DNI_FACTURA,v_Registro.REPRESENTANTE),
	  			         NOMBRE_FACTURA=SUBSTR(xNOMBRE,1,40),
				         DOMICILIO=xDOMICILIO,
				         POBLACION=xPOBLACION,
				         PROVINCIA=xPROVINCIA,
				         CODIGO_POSTAL=xCP,
						 SITUACION=xSITUACION,
						 ESCALERA=v_Registro.ESCALERA,
						 PLANTA=v_Registro.PLANTA,
						 PUERTA=v_Registro.PUERTA,
						 NUMERO=v_Registro.NUMERO
	       WHERE ID=vPERIODOS.ID;

	       -- si est� pasado a Recaudaci�n, modificamos los datos del valor (o del punteo)
	       IF mVOL_EJE='V' THEN

	          -- refrescamos los datos seleccionados del recibo
	          SELECT * INTO v_recibo FROM RECIBOS_EXAC WHERE ID=vPERIODOS.ID;

              IF mVALOR IS NOT NULL THEN
                 UPDATE VALORES SET NIF=DECODE(v_recibo.DNI_FACTURA,NULL,v_recibo.NIF,v_recibo.DNI_FACTURA),
               		                NOMBRE=xNOMBRE,
				                    DOM_TRIBUTARIO=xDOMI_TRIBUTARIO
	             WHERE ID=mVALOR;

		      ELSE --si mVALOR IS NULL y mVOL_EJE='V' es porque est� en el punteo
                 UPDATE PUNTEO SET NIF=DECODE(v_recibo.DNI_FACTURA,NULL,v_recibo.NIF,v_recibo.DNI_FACTURA),
               		               NOMBRE=xNOMBRE,
				                   DOM_TRIBUTARIO=xDOMI_TRIBUTARIO
	             WHERE ID=mPUNTEO;	
		      END IF; -- mVALOR IS NOT NULL 
						
	       END IF; -- mVOL_EJE='V'

        END IF; -- ((mVOL_EJE='V' and mPENDIENTE='S') or (mVOL_EJE IS NULL))	 

	 END LOOP;  
END;
/


/*****************************************************************************************/
COMMIT;
/********************************************************************/
