/*****************************************************************************
Autor: M. Carmen Junco Gómez.
Fecha: 26/09/2001
Acción: Inserción de un nuevo expediente de Inspección.
*****************************************************************************/

CREATE OR REPLACE PROCEDURE ADD_INSPECCION (
		xEXPEDIENTE		IN	CHAR,
		xFECHA_APERTURA	IN	DATE,
		xINSPECTOR		IN	CHAR,
		xNIF_CONTRI		IN	CHAR,
		xNIF_REPRE		IN	CHAR,
		xQUIEN_IMPULSA	IN	CHAR,
		xORGANO		IN	CHAR,
		xTIPO_ACTUACION	IN	CHAR,
		xCARACTER_ACTUA	IN	CHAR,
		xID			OUT   INTEGER)
AS
BEGIN

   INSERT INTO INSPECCIONES (EXPEDIENTE,FECHA_APERTURA,INSPECTOR,NIF_CONTRI,
		NIF_REPRE,QUIEN_IMPULSA,ORGANO,TIPO_ACTUACION,CARACTER_ACTUA)
   VALUES (xEXPEDIENTE,xFECHA_APERTURA,xINSPECTOR,xNIF_CONTRI,
		xNIF_REPRE,xQUIEN_IMPULSA,xORGANO,xTIPO_ACTUACION,xCARACTER_ACTUA)
   RETURNING ID INTO xID;

END;
/

/*****************************************************************************
Autor: M. Carmen Junco Gómez.
Fecha: 28/09/2001
Acción: Modificación de un expediente de Inspección.
*****************************************************************************/

CREATE OR REPLACE PROCEDURE MODIFY_INSPECCION (
		xID			IN	INTEGER,
		xEXPEDIENTE		IN	CHAR,
		xFECHA_APERTURA	IN	DATE,
		xINSPECTOR		IN	CHAR,
		xNIF_CONTRI		IN	CHAR,
		xNIF_REPRE		IN	CHAR,
		xQUIEN_IMPULSA	IN	CHAR,
		xORGANO		IN	CHAR,
		xTIPO_ACTUACION	IN	CHAR,
		xCARACTER_ACTUA	IN	CHAR)
AS
BEGIN

   UPDATE INSPECCIONES SET EXPEDIENTE=xEXPEDIENTE,
				   FECHA_APERTURA=xFECHA_APERTURA,
				   INSPECTOR=xINSPECTOR,
				   NIF_CONTRI=xNIF_CONTRI,
				   NIF_REPRE=xNIF_REPRE,
				   QUIEN_IMPULSA=xQUIEN_IMPULSA,
				   ORGANO=xORGANO,
				   TIPO_ACTUACION=xTIPO_ACTUACION,
				   CARACTER_ACTUA=xCARACTER_ACTUA
   WHERE ID=xID;

END;
/

/*****************************************************************************
Autor: M. Carmen Junco Gómez.
Fecha: 26/09/2001
Acción: Inserción de un apunte en el seguimiento de un expediente de Inspección.
*****************************************************************************/

CREATE OR REPLACE PROCEDURE ADD_SEGUIMIENTO_INSPE (
		xIDINSPE		IN	INTEGER,
		xINSPECTOR		IN	CHAR,
		xF_ACTUACION	IN	DATE,
		xDESCRIPCION	IN	VARCHAR,
		xTIPO_DOCUMENTO	IN	CHAR,
		xTIPO_TUPLA		IN	CHAR,
		xNOTIFICABLE	IN	CHAR,
		xIDSEGUI		OUT	INTEGER)		

AS
BEGIN
	INSERT INTO SEGUIMIENTO_INSPE (IDINSPE,INSPECTOR,F_ACTUACION,DESCRIPCION,
		TIPO_DOCUMENTO,TIPO_TUPLA,NOTIFICABLE)
	VALUES (xIDINSPE,xINSPECTOR,xF_ACTUACION,xDESCRIPCION,
		xTIPO_DOCUMENTO,xTIPO_TUPLA,xNOTIFICABLE)
	RETURNING ID INTO xIDSEGUI;

	-- si ha de ser notificado se añade una tupla en la tabla de Notificaciones
	INSERT INTO NOTIFICACIONES_INSPE(IDSEGUI,N_ENVIOS,F_1INTENTO,F_INTENTO)
	VALUES (xIDSegui,1,SYSDATE,SYSDATE); 

END;
/

/*****************************************************************************
Autor: M. Carmen Junco Gómez.
Fecha: 28/09/2001
Acción: Modificación de un apunte del seguimiento de un expediente de Inspección.
*****************************************************************************/

CREATE OR REPLACE PROCEDURE MODIFY_SEGUIMIENTO_INSPE (
		xID			IN	INTEGER,
		xIDINSPE		IN	INTEGER,
		xINSPECTOR		IN	CHAR,
		xF_ACTUACION	IN	DATE,
		xDESCRIPCION	IN	VARCHAR,
		xTIPO_DOCUMENTO	IN	CHAR,
		xTIPO_TUPLA		IN	CHAR,
		xNOTIFICABLE	IN	CHAR)		

AS
BEGIN
	UPDATE SEGUIMIENTO_INSPE SET IDINSPE=xIDINSPE,
					     INSPECTOR=xINSPECTOR,
					     F_ACTUACION=xF_ACTUACION,
					     DESCRIPCION=xDESCRIPCION,
					     TIPO_DOCUMENTO=xTIPO_DOCUMENTO,
					     TIPO_TUPLA=xTIPO_TUPLA,
					     NOTIFICABLE=xNOTIFICABLE
	WHERE ID=xID;
END;
/

/*****************************************************************************
Autor: M. Carmen Junco Gómez.
Fecha: 28/09/2001
Acción: Añade un nuevo documento o imagen asociado al apunte en el seguimiento
	  de una Inspección.
*****************************************************************************/

CREATE OR REPLACE PROCEDURE ADD_DOCSEGUI( 
	xIDSEGUI 	IN INTEGER,
	xREFERENCIA IN VARCHAR2,
	xFICHERO 	IN VARCHAR2,	
	xID 		OUT INTEGER)
AS
BEGIN

	INSERT INTO DOCSEGUI (IDSEGUI,REFERENCIA,FICHERORIGINAL,IMAGEN) 
	VALUES (xIDSEGUI,xREFERENCIA,xFICHERO,empty_blob() )
	RETURNING ID INTO xID;

END;
/

/*****************************************************************************
Autor: M. Carmen Junco Gómez.
Fecha: 01/10/2001
Acción: Escribir el acuse de recibo de una notificación.
Parametros:
		xID: Id de Notificaciones
		xIDSegui: ID del Apunte en el Seguimiento.
		xFRecibi: Fecha del Recibi
		xAcuse: Código de Acuse de Recibo
		xTercero: Datos para el tipo de acuse TERCERO
		xTipo: 1-El interesado, 2-Un tercero, 3-Rehusado, 4-Desconocido, 5-Ausente
		xReferencia: Referencia donde está el acuse
*****************************************************************************/

CREATE OR REPLACE PROCEDURE WRITEACUSE_INSPE(
         xID          IN INTEGER,
         xIDSEGUI     IN INTEGER,
         xFRecibi     IN DATE,
         xAcuse       IN CHAR,
         xTercero     IN VARCHAR,
         xTipo        IN CHAR,
	   xReferencia  IN VARCHAR,
	   xNumNoti	    IN INTEGER)

AS  
    xNoti char(1); 

BEGIN

   --xNoti: si esta notificado o no, 
   
   SELECT NOTIFICADO INTO xNOTI
   FROM TIPO_ACUSES
   WHERE TIPO=xTIPO;


   /* Primer o Segundo intento */
   IF (xNumNoti=1) THEN
     	UPDATE NOTIFICACIONES_INSPE Set F_1ACUSE=xFRecibi, 
				        	  ACUSE1=xAcuse,
					        TERCERO_1NOTIFI=xTercero, 
					        NOTIFICADO=xNoti,
					        F_NOTIFICACION=xFRecibi, 
					        F_LAST_ACUSE=xFRecibi,
					        LAST_ACUSE=xAcuse,
					        Referencia=xReferencia 
      WHERE id=xID and F_PUBLICACION is null;
   ELSE
	UPDATE NOTIFICACIONES_INSPE Set F_2ACUSE=xFRecibi, 
					  	  ACUSE2=xAcuse,
					  	  TERCERO_2NOTIFI=xTercero, 
					  	  NOTIFICADO=xNoti,
					  	  F_NOTIFICACION=xFRecibi, 
					  	  F_LAST_ACUSE=xFRecibi,
				        	  LAST_ACUSE=xAcuse,
					  	  Referencia2=xReferencia
      WHERE id=xID and F_PUBLICACION is null;
   END IF;  
   
END;
/

/*****************************************************************************
Autor: M. Carmen Junco Gómez.
Fecha: 01/10/2001
Acción: Mandar a publicar en el BOP.
Parámetros: xFECHAENVIO: Fecha de envío para publicar en el B.O.P.
		xTIPO_ACUSE: 0 -> desconocidos o ausentes en segunda notificación
				 1 -> casos especiales en 2ª notificación.
				 2 -> casos especiales en 1ª notificación.
				 3 -> sin acuse en 1ª notificación.
*****************************************************************************/

CREATE OR REPLACE PROCEDURE PUBLICAR_INSPE_BOP
	(xFECHAENVIO 	IN 	DATE,
	 xTIPO_ACUSE      IN   INTEGER)
AS
	MNUMERO 		CHAR(10);
    	MCUANTOSRECIBOS 	INTEGER;
    	xVALOR 		INTEGER;
    	xZONA 		CHAR(2);
   	CURSOR C0 IS 
	   SELECT ID FROM NOTIFICACIONES_INSPE 
	   WHERE SUBSTR(ACUSE2,1,2) IN ('03','04')	   
	   FOR UPDATE OF F_ENVIO_BOP;

	CURSOR C1 IS
	   SELECT ID FROM NOTIFICACIONES_INSPE
	   WHERE ACUSE2 IN (SELECT CODIGO FROM TMP_BOP WHERE USUARIO=USER)
	   FOR UPDATE OF F_ENVIO_BOP;

	CURSOR C2 IS 
	   SELECT ID FROM NOTIFICACIONES_INSPE
	   WHERE ACUSE1 IN (SELECT CODIGO FROM TMP_BOP WHERE USUARIO=USER)
	   FOR UPDATE OF F_ENVIO_BOP;

	CURSOR C3 IS 
	   SELECT ID FROM NOTIFICACIONES_INSPE
	   WHERE ACUSE1 IS NULL
	   FOR UPDATE OF F_ENVIO_BOP;

BEGIN

   IF xTIPO_ACUSE=0 THEN
	FOR v0 IN C0
      LOOP
         UPDATE NOTIFICACIONES_INSPE SET F_ENVIO_BOP=xFECHAENVIO
	   WHERE CURRENT OF C0;
      END LOOP;
   ELSIF xTIPO_ACUSE=1 THEN
	FOR v1 IN C1
      LOOP
         UPDATE NOTIFICACIONES_INSPE SET F_ENVIO_BOP=xFECHAENVIO
	   WHERE CURRENT OF C1;
      END LOOP;
   ELSIF xTIPO_ACUSE=2 THEN
	FOR v2 IN C2
      LOOP
         UPDATE NOTIFICACIONES_INSPE SET F_ENVIO_BOP=xFECHAENVIO
	   WHERE CURRENT OF C2;
      END LOOP;
   ELSIF xTIPO_ACUSE=3 THEN
	FOR v3 IN C3
      LOOP
         UPDATE NOTIFICACIONES_INSPE SET F_ENVIO_BOP=xFECHAENVIO
	   WHERE CURRENT OF C3;
      END LOOP;
   END IF;

END;
/

/*****************************************************************************
Autor: M. Carmen Junco Gómez.
Fecha: 01/10/2001
Acción: Poner fecha de publicación a todos los enviados a publicar.
Parámetro: xFPUBLICACION: Fecha de publicar en el B.O.P.		
*****************************************************************************/

CREATE OR REPLACE PROCEDURE PON_FECHA_BOP_INSPE(
      xFPUBLICACION 	IN 	DATE)
AS
   CURSOR CPublicacion IS 
      SELECT ID FROM NOTIFICACIONES_INSPE
      WHERE F_ENVIO_BOP IS NOT NULL AND F_PUBLICACION IS NULL AND NOTIFICADO='N'
	FOR UPDATE OF F_PUBLICACION,NOTIFICADO,F_NOTIFICACION;

BEGIN

   FOR vVALORPublica IN cPublicacion 
   LOOP		
      UPDATE NOTIFICACIONES_INSPE SET F_PUBLICACION=xFPUBLICACION,
					        NOTIFICADO='S',
                			        F_NOTIFICACION=xFPUBLICACION
      WHERE CURRENT OF cPublicacion;
   END LOOP;

END;
/


/*****************************************************************************
Autor: Gloria Maria Calle Hernandez.
Fecha: 05/11/2003
Acción: Añadir o modificar organos de inspeccion.
Modificación: 28/01/2004 Mª del Carmen Junco Gómez. Si la tabla está vacía no
              se controlaba el nº de código a insertar. No se incrementaba el
              nº de código con respecto al máximo encontrado.
*****************************************************************************/
CREATE OR REPLACE PROCEDURE ADD_MODY_ORGANO (
       xMUNICIPIO 	IN  VARCHAR2,
       xCODIGO 		IN  VARCHAR2,
       xDESCRIPCION	IN  VARCHAR2
)
AS
	   vCODIGO		INTEGER;
BEGIN
   
   UPDATE INSPE_ORGANOS SET DESCRIPCION=xDESCRIPCION
   WHERE MUNICIPIO=xMUNICIPIO AND CODIGO=xCODIGO;
 
   IF SQL%NOTFOUND THEN /* Si el codigo de organo no existe, se crea */
   	  SELECT MAX(TO_NUMBER(CODIGO)) INTO vCODIGO FROM INSPE_ORGANOS
      WHERE MUNICIPIO=xMUNICIPIO;
      
      -- si la tabla está vacía la consulta devuelve NULL
      IF vCODIGO IS NULL THEN
         vCODIGO:=0;
      END IF;

      INSERT INTO INSPE_ORGANOS (MUNICIPIO,CODIGO,DESCRIPCION) 
      VALUES (xMUNICIPIO,LPAD(TO_CHAR(vCODIGO+1),2,'0'),xDESCRIPCION);
   END IF;
END;
/


--
-- Autor: 20/11/2003. Agustín León Robles.
-- Para imprimir los documentos de Inspecciones
-- Modificación: 22/06/2004. Mª del Carmen Junco Gómez. Se añade el parámetro del ID del seguimiento y 
--					se da valor con la información recogida de éste a cuatro campos más en la tabla.
-- Modificación: 05/02/2007. Lucas Fernández Pérez. Se accede al campo DOMICILIO de la nueva vista vwCONTRIBUYENTES,
--					y a los nuevos campos BLOQUE y PORTAL de las tablas CONTRIBUYENTES e IMPRIME_INSPECCIONES.
--
create or replace procedure ImprimeExpeInspeccion
			(xID	IN	integer,
			 xIDSEGUI IN integer)
as
v_RegInspeccion 	Inspecciones%ROWTYPE;
v_RegSeguimiento  Seguimiento_Inspe%ROWTYPE;


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

xNOMBRE_REPRE 		VARCHAR2(40);	
xPOBLACION_REPRE 	VARCHAR2(35);
xPROVINCIA_REPRE 	VARCHAR2(35);
xCP_REPRE 			CHAR(5);
xVIA_REPRE 			CHAR(2);
xCALLE_REPRE 		CHAR(30);
xNUMERO_REPRE 		CHAR(5);
xBLOQUE_REPRE		CHAR(4);
xPORTAL_REPRE		CHAR(2);
xESCALERA_REPRE 	CHAR(2);
xPLANTA_REPRE 		CHAR(3);
xPISO_REPRE 		CHAR(2);
xDOMI_REPRE			VARCHAR2(60);

xQUIEN_IMPULSA		VARCHAR2(80);
xTIPO_ACTUACION		VARCHAR2(100);
xCARACTER_ACTUA		VARCHAR2(80);	
xF_ACTUACION 		DATE;
xDESCRIPCION 		VARCHAR2(300);
xTIPO_DOCUMENTO		VARCHAR2(50);
xTIPO_TUPLA			VARCHAR2(100);


xNombreInspector	VARCHAR2(40);
begin

	DELETE FROM IMPRIME_INSPECCIONES WHERE USUARIO=UID;


	select * into v_RegInspeccion from Inspecciones Where ID=xID;		
	
	--DATOS DEL TITULAR
	BEGIN
		SELECT NOMBRE,VIA,CALLE,NUMERO,BLOQUE,PORTAL,ESCALERA,PLANTA,PISO,CODIGO_POSTAL,POBLACION,PROVINCIA,DOMICILIO
		INTO xNOMBRE_CONTRI,xVIA_CONTRI,xCALLE_CONTRI,xNUMERO_CONTRI,xBLOQUE_CONTRI,xPORTAL_CONTRI,xESCALERA_CONTRI,
			xPLANTA_CONTRI,xPISO_CONTRI,xCP_CONTRI,xPOBLACION_CONTRI,xPROVINCIA_CONTRI,xDOMI_CONTRI
		FROM vwCONTRIBUYENTES WHERE NIF=v_RegInspeccion.NIF_CONTRI;
	EXCEPTION
		WHEN NO_DATA_FOUND THEN
		   xNOMBRE_CONTRI:=NULL;
	END;
	
	--DATOS DEL REPRESENTANTE
	BEGIN
		SELECT NOMBRE,VIA,CALLE,NUMERO,BLOQUE,PORTAL,ESCALERA,PLANTA,PISO,CODIGO_POSTAL,POBLACION,PROVINCIA,DOMICILIO
		INTO xNOMBRE_REPRE,xVIA_REPRE,xCALLE_REPRE,xNUMERO_REPRE,xBLOQUE_REPRE,xPORTAL_REPRE,xESCALERA_REPRE,
			xPLANTA_REPRE,xPISO_REPRE,xCP_REPRE,xPOBLACION_REPRE,xPROVINCIA_REPRE,xDOMI_REPRE
		FROM vwCONTRIBUYENTES WHERE NIF=v_RegInspeccion.NIF_REPRE;
	EXCEPTION
		WHEN NO_DATA_FOUND THEN
		   xNOMBRE_REPRE:=NULL;
	END;
	
	IF v_RegInspeccion.QUIEN_IMPULSA='I' THEN
	   xQUIEN_IMPULSA:= 'INSPECTOR';
	ELSIF v_RegInspeccion.QUIEN_IMPULSA='O' THEN
	   xQUIEN_IMPULSA:= 'ÓRGANO DE GESTIÓN TRIBUTARIA';
 	ELSIF v_RegInspeccion.QUIEN_IMPULSA='S' THEN
	   xQUIEN_IMPULSA:= 'ORDEN SUPERIOR';
 	ELSIF v_RegInspeccion.QUIEN_IMPULSA='D' THEN
	   xQUIEN_IMPULSA:= 'DENUNCIA';
 	ELSE xQUIEN_IMPULSA:= 'A PETICIÓN DEL OBLIGADO TRIBUTARIO'; --P 
 	END IF;
 	
 	IF v_RegInspeccion.TIPO_ACTUACION='a' THEN
 	   xTIPO_ACTUACION:= 'DE COMPROBACIÓN E INVESTIGACIÓN';
 	ELSIF v_RegInspeccion.TIPO_ACTUACION='b' THEN
 	   xTIPO_ACTUACION:= 'OBTENCIÓN DE INFORMACIÓN';
 	ELSIF v_RegInspeccion.TIPO_ACTUACION='c' THEN
 	   xTIPO_ACTUACION:= 'VALORACIÓN';
 	ELSIF v_RegInspeccion.TIPO_ACTUACION='d' THEN
 	   xTIPO_ACTUACION:= 'INFORME Y ASESORAMIENTO';
 	ELSE xTIPO_ACTUACION:= 'OTRAS ACTUACIONES';
 	END IF;

 	IF v_RegInspeccion.CARACTER_ACTUA='P' THEN
 	   xCARACTER_ACTUA:= 'PARCIAL';
 	ELSE xCARACTER_ACTUA:=' GENERAL';
 	END IF; 	
	
 	BEGIN
 		SELECT NOMBRE INTO xNombreInspector FROM USUARIOSGT WHERE USUARIO=v_RegInspeccion.INSPECTOR;
 	EXCEPTION
 		WHEN NO_DATA_FOUND THEN
 			xNombreInspector:=NULL;
 	END;
 	
 	-- si estamos imprimiendo un apunte del seguimiento necesitamos información del mismo
 	if xIDSEGUI>0 then
	   select * into v_RegSeguimiento from Seguimiento_Inspe Where ID=xIDSEGUI;
	   	   
	   xF_ACTUACION:=v_RegSeguimiento.F_ACTUACION;
		xDESCRIPCION:=v_RegSeguimiento.DESCRIPCION;
		
		
		IF v_RegSeguimiento.Tipo_Documento='C' then
		   xTIPO_DOCUMENTO:='COMUNICACION';
		ELSIF v_RegSeguimiento.Tipo_Documento='D' then
		   xTIPO_DOCUMENTO:='DILIGENCIA';
		ELSIF v_RegSeguimiento.Tipo_Documento='I' then
		   xTIPO_DOCUMENTO:='INFORME';
		ELSIF v_RegSeguimiento.Tipo_Documento='A' then
		   xTIPO_DOCUMENTO:='ACTA';
		ELSIF v_RegSeguimiento.Tipo_Documento='O' then
		   xTIPO_DOCUMENTO:='OTROS';
		END IF;
		
		
		IF v_RegSeguimiento.Tipo_Tupla='I' then
		   xTIPO_TUPLA:='INFORMATIVO';
		ELSIF v_RegSeguimiento.Tipo_Tupla='E' then
		   xTIPO_TUPLA:='DE ENTRADA';
		ELSIF v_RegSeguimiento.Tipo_Tupla='S' then
		   xTIPO_TUPLA:='DE SALIDA';
		END IF;		   		
	else
	   xF_ACTUACION:=NULL;
	   xDESCRIPCION:=NULL;
	   xTIPO_DOCUMENTO:=NULL;
	   xTIPO_TUPLA:=NULL;	   
	end if; 	
 	
	insert into IMPRIME_INSPECCIONES(ID,EXPEDIENTE,FECHA_APERTURA,	
		INSPECTOR,NIF_CONTRI,NOMBRE_CONTRI,VIA,CALLE,NUMERO,ESCALERA,PLANTA,PISO,
		POBLACION,PROVINCIA,CODIGO_POSTAL,DOMI_CONTRI,
		NIF_REPRE,NOMBRE_REPRE,VIA_REPRE,CALLE_REPRE,NUMERO_REPRE,ESCALERA_REPRE,PLANTA_REPRE,
    	PISO_REPRE,POBLACION_REPRE,PROVINCIA_REPRE,C_POSTAL_REPRE,DOMI_REPRE,
		QUIEN_IMPULSA,ORGANO,TIPO_ACTUACION,CARACTER_ACTUA,F_ACTUACION,DESCRIPCION,TIPO_DOCUMENTO,TIPO_TUPLA)
	values(v_RegInspeccion.ID,v_RegInspeccion.EXPEDIENTE,v_RegInspeccion.FECHA_APERTURA,xNombreInspector,
		v_RegInspeccion.NIF_CONTRI,xNOMBRE_CONTRI,xVIA_CONTRI,xCALLE_CONTRI,xNUMERO_CONTRI,xESCALERA_CONTRI,
		xPLANTA_CONTRI,xPISO_CONTRI,xPOBLACION_CONTRI,xPROVINCIA_CONTRI,xCP_CONTRI,xDOMI_CONTRI,		
		v_RegInspeccion.NIF_REPRE,xNOMBRE_REPRE,xVIA_REPRE,xCALLE_REPRE,xNUMERO_REPRE,xESCALERA_REPRE,
		xPLANTA_REPRE,xPISO_REPRE,xPOBLACION_REPRE,xPROVINCIA_REPRE,xCP_REPRE,xDOMI_REPRE,		
		xQUIEN_IMPULSA,v_RegInspeccion.ORGANO,xTIPO_ACTUACION,xCARACTER_ACTUA,xF_ACTUACION,xDESCRIPCION,xTIPO_DOCUMENTO,xTIPO_TUPLA);
end;
/



/****************************************************************************/
COMMIT;
/****************************************************************************/
