-- *************************************************************************************
-- MODIFICACIÓN: 04/11/2002 M. Carmen Junco Gómez. Según el código de entrega se 
-- 			  considerará notificada o no la denuncia.
-- MODIFICACIÓN: 02/12/2003  Agustín León Robles
-- 			  En vez de insertar en recaudacion cuando se imprimian las notificaciones ahora
-- 		 	  se hace cuando se inserta la tabla de multas
-- MODIFICACION: 05/02/2004. Gloria María Calle Hernández. Se inserta la fecha de cargo en 
-- 			  la misma tabla donde se inserta el numero de cargo (DatoPerr) para poder 
-- 			  especificar dicha fecha el usuario. Entonces cambiada llamada al procedimiento
-- 			  InsertaValores que ahora al ser llamado pasa la fecha de cargo especificada.
-- MODIFICACIÓN: 18/02/2004. Lucas Fernández Pérez. Antes, si no tenía propietario se pasaba
-- 			  a estado 'FD'. Ahora pasa a estado 'FD' si no tiene CONDUCTOR.
-- MODIFICACIÓN: 27/05/2004  Agustín León Robles
-- 			  El parametro de Notificado en la llamada a InsertaValores se estaba poniendo a nulo, ahora se
--				cambia a 'N'
-- MODIFICACION: 09/07/2004. Gloria Maria Calle Hernandez. Añadidos campos NCargoMultas y FCargoMultas 
--		      a la tabla DatosPerr, para su pase a un cargo distinto al de liquidaciones.
-- MODIFICACION: 26/01/2005. Mª del Carmen Junco Gómez. Se añade la hora y lugar al objeto tributario
-- MODIFICACIÓN: 08/02/2005. M. Carmen Junco Gómez. Además del expediente, almacenamos el ID en usuariosgt
-- MODIFICACIÓN: 24/02/2005. M. Carmen Junco Gómez. En el objeto tributario se camia la descripción del artículo
--				por el hecho denunciado, ya que se va a componer por la sanción más información adicional incluida 
--				por el usuario al dar de alta el boletín.
-- MODIFICACIÓN: 09/05/2006. Lucas Fernández Pérez. 
--		Se cambia SELECT min(SALTO) INTO xSALTO FROM SALTO por SELECT SALTO por problemas en torrejon
-- MODIFICACIÓN: 26/09/2006. Lucas Fernández Pérez. 
--   El valor se da de alta con fecha de contraido: to_char(xFCARGO,'YYYY') (antes era :New.year)
-- ****************************************************************************************
CREATE OR REPLACE TRIGGER SET_BOLETIN
BEFORE INSERT ON MULTAS
FOR EACH ROW
DECLARE

	varTrg 			INTEGER;
	varYear 		char(4);
	xESTADO			CHAR(2);

	xNIF			CHAR(10);
	xNOMBRE			VARCHAR2(40);
	xPASE 			CHAR(1);
	xNCARGO			CHAR(10);
	xFCargo			DATE;
	xVALOR			INT;
	xPADRON			CHAR(6);
	xPorDescuento	float;
	xImporte		FLOAT;
	xSALTO			CHAR(2);
	xOBJ_TRIBUTARIO VARCHAR2(1024);
	xARTICULO 		CHAR(3);
	xAPARTADO		CHAR(2);
	xOPCION 		CHAR(2);	
BEGIN

	SELECT GEN_MULTAS.NEXTVAL INTO :NEW.ID FROM DUAL;

	UPDATE MULTASWORK SET BOLETIN=BOLETIN+1 WHERE MUNICIPIO=:NEW.MUNICIPIO
	RETURNING BOLETIN,YEAR_WORK INTO varTrg,varYear;

	IF SQL%NOTFOUND THEN

		INSERT INTO MULTASWORK (YEAR_WORK,MUNICIPIO,BOLETIN)
		VALUES (f_Year(:NEW.FECHA_BOLETIN),:NEW.MUNICIPIO,1);

		varTrg:=1;
		varYear:=f_Year(:NEW.FECHA_BOLETIN);

	END IF;


	:NEW.YEAR:=to_char(:NEW.FECHA_BOLETIN,'yyyy');
	:NEW.MES:=to_char(:NEW.FECHA_BOLETIN,'mm');
	:NEW.Expediente:=varYear || '/'|| LPAD(varTrg,5,'0');

	UPDATE USUARIOSGT SET LAST_INT=:NEW.ID,LAST_TEMP=:NEW.expediente WHERE USUARIO=USER;

	SELECT DECODE(NOTIFICADO,'S','A1','P1') INTO xESTADO FROM ENTREGA_DENUNCIA
	WHERE CODIGO=:NEW.COD_ENTREGA AND MUNICIPIO=:NEW.MUNICIPIO;

	IF (:NEW.DNI_CONDUCTOR IS NULL) THEN
		:NEW.ESTADO_ACTUAL:='FD';
	ELSE
		:NEW.ESTADO_ACTUAL:=xESTADO;
	END IF;

	:NEW.FECHA_ESTADO_ACTUAL:=:NEW.FECHA_BOLETIN;


	--
	--	DAR DE ALTA LA MULTA EN RECAUDACION SI ESTA LA OPCION ACTIVADA
	--

	BEGIN
		SELECT PASE_AUTOMATICO_MULTAS,NCARGOMULTAS,FCARGOMULTAS INTO xPASE,xNCARGO,xFCARGO FROM DATOSPERR WHERE EMPRESA IS NOT NULL;
	EXCEPTION
		WHEN NO_DATA_FOUND THEN
			xPASE:='N';
	END;

	IF xPASE='S' THEN

		SELECT CONCEPTO INTO xPADRON FROM PROGRAMAS WHERE PROGRAMA='MULTAS';

		SELECT ARTICULO,APARTADO,OPCION,DESCUENTO INTO xARTICULO,xAPARTADO,xOPCION,xPorDescuento
		FROM SANCION WHERE ID=:NEW.ID_ARTICULO;

		SELECT SALTO INTO xSALTO FROM SALTO;

		xOBJ_TRIBUTARIO:='BOLETIN Nº: '|| :NEW.BOLETIN ||xSALTO;

		xOBJ_TRIBUTARIO:=xOBJ_TRIBUTARIO||'F. DENUNCIA: '|| to_char(:NEW.FECHA_BOLETIN,'dd-mm-yyyy')||' HORA:'|| to_char(TO_CHAR(:NEW.FECHA_BOLETIN,'HH24:MI'))||xSALTO;

		xOBJ_TRIBUTARIO:=xOBJ_TRIBUTARIO||'EXPEDIENTE: '|| :NEW.EXPEDIENTE||xSALTO;

		xOBJ_TRIBUTARIO:=xOBJ_TRIBUTARIO||'MATRICULA: ' ||GetMatricula(:NEW.MATRICULA,:NEW.NUMERO,:NEW.LETRA)||xSALTO;

		IF :NEW.MARCA IS NOT NULL THEN
			xOBJ_TRIBUTARIO:=xOBJ_TRIBUTARIO||'MARCA: '||RTRIM(:NEW.MARCA)||xSALTO;
		END IF;

		IF :NEW.TIPO IS NOT NULL THEN
			xOBJ_TRIBUTARIO:=xOBJ_TRIBUTARIO || 'TIPO: '|| RTRIM(:NEW.TIPO) || xSALTO;
		END IF;

		xOBJ_TRIBUTARIO:=xOBJ_TRIBUTARIO || 'ARTICULO: ' ||RTRIM(xArticulo)||'.'||
			     RTRIM(xApartado)||'.'||RTRIM(xOpcion)||' '|| RTRIM(:NEW.HECHO) || xSALTO;
			     
		xOBJ_TRIBUTARIO:=xOBJ_TRIBUTARIO || 'LUGAR: '||RTRIM(:NEW.LUGAR) || xSALTO;


		IF :NEW.ESTADO_ACTUAL='FD' THEN

			xNIF:=NULL;
			xNOMBRE:=NULL;

		ELSE

			IF :NEW.DNI_TUTOR IS NULL THEN
				xNIF:=:NEW.DNI_CONDUCTOR;
				xNOMBRE:=:NEW.NOMBRE_CONDUCTOR;
			ELSE
				xNIF:=:NEW.DNI_TUTOR;
				xNOMBRE:=:NEW.NOMBRE_TUTOR;
			END IF;

		END IF;

		xImporte:=:NEW.IMPORTE - ROUND(:NEW.IMPORTE*(xPorDescuento/100),2);

		INSERTAVALORES(xPADRON,:NEW.YEAR,'00',:NEW.ID,xNIF,xNOMBRE,
			xFCARGO, xNCARGO,:NEW.MUNICIPIO,NULL,NULL,
			NULL,'N',NULL,NULL,NULL,'L',
			xOBJ_TRIBUTARIO,to_char(xFCARGO,'YYYY'),:NEW.IMPORTE,xImporte,0,0,0,'V',
			NULL,'N',rtrim(:NEW.MATRICULA)||rtrim(:NEW.NUMERO)||rtrim(:NEW.LETRA),:NEW.ID,xVALOR);

		update valores set  POR_BONIFICACION=xPorDescuento,
							IMPORTE_BONIFICADO=xImporte,
							NIF=xNIF,
							NOMBRE=xNOMBRE
		where id=xVALOR;

	      -- Asignamos la relación unívoca entre recaudación y valores
		:NEW.IDVALOR:=xVALOR;
		:NEW.NUMERO_DE_CARGO:=xNCARGO;
		:NEW.F_CARGO:=xFCargo;
		:NEW.PASADO:='S';

	END IF;

END;
/

/***************************************************************************************
Autor: 01/04/2003 M. Carmen Junco Gómez.
Acción: Trigger que se activa al modificar el campo IMP_CADENA de la tabla de multas
	    para actualizar a su vez el importe PRINCIPAL de la tabla de VALORES.
MODIFICACIÓN: 26/01/2004. Agustín Léon Robles. Se elimina los update que habían en la tabla de cargos
				  y en la tabla de desglose_cargos.
MODIFICACIÓN: 05/04/2005. M. Carmen Junco Gómez. Al modificar una matrícula en gestión, se modificarán los
				campos clave_concepto y objeto_tributario del valor asociado (si existe).
***************************************************************************************/

CREATE OR REPLACE TRIGGER T_IMPORTE_MULTAS
AFTER UPDATE ON MULTAS
FOR EACH ROW

DECLARE
   xPADRON CHAR(6);   
   xOLDPRINCIPAL FLOAT;
   xDIFERENCIA FLOAT;
BEGIN

    IF ((:OLD.IMP_CADENA<>:NEW.IMP_CADENA) AND (:NEW.IDVALOR IS NOT NULL)) THEN	
	
		SELECT PRINCIPAL INTO xOLDPRINCIPAL FROM VALORES
		WHERE ID=:NEW.IDVALOR;				
		
		SELECT CONCEPTO INTO xPADRON FROM PROGRAMAS WHERE PROGRAMA='MULTAS';						
		
		xDIFERENCIA:=TO_NUMBER(:NEW.IMP_CADENA) - xOLDPRINCIPAL;		
		
		-- si la diferencia es positiva hemos quitado la bonificación
		-- si es negativa la hemos reestablecido
		IF xDIFERENCIA > 0 THEN
		
			UPDATE VALORES SET PRINCIPAL=TO_NUMBER(:NEW.IMP_CADENA),
		                   	   F_ANULACION_BONI=SYSDATE
			WHERE ID=:NEW.IDVALOR;  
			
		ELSIF xDIFERENCIA<0 THEN
		
		   UPDATE VALORES SET PRINCIPAL=TO_NUMBER(:NEW.IMP_CADENA),
		   					  F_ANULACION_BONI=NULL
		   WHERE ID=:NEW.IDVALOR;
		   
		END IF;		
		      
	END IF;		
	
	-- si hay una modificación de la matrícula, se ha de modificar en el valor la clave_concepto y el objeto_tributario
	IF (((:OLD.MATRICULA<>:NEW.MATRICULA) OR (:OLD.NUMERO<>:NEW.NUMERO) OR (:OLD.LETRA<>:NEW.LETRA)) AND (:NEW.IDVALOR IS NOT NULL)) THEN
		UPDATE VALORES SET CLAVE_CONCEPTO=rtrim(:NEW.MATRICULA)||rtrim(:NEW.NUMERO)||rtrim(:NEW.LETRA),
								 OBJETO_TRIBUTARIO=REPLACE(OBJETO_TRIBUTARIO,GETMATRICULA(:OLD.MATRICULA,:OLD.NUMERO,:OLD.LETRA),GETMATRICULA(:NEW.MATRICULA,:NEW.NUMERO,:NEW.LETRA))
		WHERE ID=:NEW.IDVALOR;
	END IF;
   
END;
/

--
--
--
-- *****************************************************************************************
--  MODIFICACIÓN: 23/10/2003  Gloria Maria calle Hernandez. 
-- 		 Se añade un nuevo estado T1 (Notificacion de la Denuncia a un Tercero)
--  MODIFICACIÓN: 31/10/2003  Agustín León Robles
--  	 En el campo clave_concepto de la tabla de valores se graba el número de matrícula
--  MODIFICACIÓN: 06/11/2003  Agustín León Robles
--		 Se cambia la fecha de vencimiento en lugar de f_juliana se pone f_vencimiento
--  MODIFICACIÓN: 02/12/2003  Agustín León Robles
--		 En vez de insertar en recaudacion cuando se imprimian las notificaciones ahora
--		 se hace cuando se inserta la tabla de multas
-- *****************************************************************************************
CREATE OR REPLACE TRIGGER T_C60_MULTAS
BEFORE UPDATE OF F_JULIANA ON MULTAS
FOR EACH ROW
DECLARE

	xEMISOR 		CHAR(6);
	xTRIBUTO		CHAR(3);
	xDIG_C60_M2    	CHAR(2);
	xREFERENCIA 	CHAR(10);
	xIMPCADENA     	CHAR(12);
	
	xPADRON			CHAR(6);
	xPorDescuento	float;
	xImporte		FLOAT;
	
	xFVencimiento	date;
	xNIF			CHAR(10);
	xNOMBRE			VARCHAR2(40);
BEGIN

	SELECT DESCUENTO INTO xPorDescuento	FROM SANCION WHERE ID=:NEW.ID_ARTICULO;

	IF :NEW.F_JULIANA IS NOT NULL THEN

		SELECT CONCEPTO INTO xPADRON FROM PROGRAMAS WHERE PROGRAMA='MULTAS';

		BEGIN
			SELECT EMISORA,CONCEPTO_BANCO INTO xEMISOR,xTRIBUTO FROM RELA_APLI_BANCOS
			WHERE AYTO=:NEW.MUNICIPIO AND CONCEPTO=xPADRON;
		EXCEPTION
			WHEN NO_DATA_FOUND THEN
			BEGIN
				xEMISOR:='000000';
				xTRIBUTO:='000';
			END;
		END;

		--La carta de pago se emite dependiendo del estado actual de la multa:
		-- Si es la primera notificacion se emite por el importe con descuento
		-- Si es la segundo notificación se emite por el importe total de la denuncia

		IF :NEW.ESTADO_ACTUAL IN ('P1','1N','A1','T1') THEN
			xImporte:=:NEW.IMPORTE - ROUND(:NEW.IMPORTE*(xPorDescuento/100),2);
		ELSE
			xImporte:=:NEW.IMPORTE;
		END IF;

		xFVencimiento:=:NEW.FVENCIMIENTO;

		--calcular los digitos de control del cuaderno 60 modalidad 2
		CALCULA_DC_MODALIDAD2_60(xImporte, :NEW.ID, xTRIBUTO, SUBSTR(:NEW.YEAR,3,2), '1',
				to_char(xFVencimiento,'y'), to_char(xFVencimiento,'ddd'),
				xEMISOR, xDIG_C60_M2);

		xDIG_C60_M2:=SUBSTR(xDIG_C60_M2,1,2);

		--CONVIERTE NºABONADO EN CARACTER Y RELLENO DE CEROS
		GETREFERENCIA(:NEW.ID, xREFERENCIA);

		--CONVIERTE EL IMPORTE RELLENO DE CEROS
		IMPORTEENCADENA(xImporte, xIMPCADENA);

		:NEW.EMISOR:=xEMISOR;

		:NEW.TRIBUTO:=xTRIBUTO;

		:NEW.EJER_C60:=SUBSTR(:NEW.YEAR,3,2);

		:NEW.REFERENCIA:=xREFERENCIA;

		:NEW.IMP_CADENA:=xIMPCADENA;

		:NEW.DISCRI_PERIODO:='1';

		:NEW.DIGITO_YEAR:=to_char(xFVencimiento,'y');

		:NEW.DIGITO_C60_MODALIDAD2:=xDIG_C60_M2;

		IF :NEW.IDVALOR IS NOT NULL THEN
		
			IF :NEW.DNI_TUTOR IS NULL THEN
				xNIF:=:NEW.DNI_CONDUCTOR;
				xNOMBRE:=:NEW.NOMBRE_CONDUCTOR;
			ELSE
				xNIF:=:NEW.DNI_TUTOR;
				xNOMBRE:=:NEW.NOMBRE_TUTOR;
			END IF;
		
		
			update valores set
							NIF=xNIF,
							NOMBRE=xNOMBRE
			where ID=:NEW.IDVALOR AND NIF IS NULL;
			
		END IF;
		
		
	END IF;	

END;
/



/******************************************************************************************
Acción: Modifica el estado al recibir los datos de tráfico para completar el Boletín.
MODIFICACIÓN: 08/02/2005 M. Carmen Junco Gómez. Si asociamos la imagen escaneada del boletín
	a la multa, la tupla en la tabla docmulta no ha de cambiar para la referencia 'BOLETIN'.
	Se ha de mantener el id de la multa, sin importarnos el id del estado al que pase.
MODIFICACIÓN: 11/04/2005 M. Carmen Junco Gómez. Cambiamos el where del count, incluyendo
	el DECODE (se hacía sólo REFERENCIA<>'BOLETIN', y si referencia era nulo fallaba.
MODIFICACIÓN: 28/09/2006 Lucas Fernández Pérez. Si el nuevo estado es de grabación de acuse
	de sanción o publicación de sanción, se calcula el fin del periodo voluntario de la multa
	y del valor asociado a ella como 15 dias hábiles desde la fecha del acuse.
MODIFICACIÓN: 28/11/2006 Lucas Fernández Pérez. Si el nuevo estado es de grabación de acuse
	de sanción o publicación de sanción, se calcula el fin del periodo voluntario
	con la nueva condición de que el estado anterior no fuese suspendido, o si era suspendido, no hubiese
	fin de periodo voluntario en la multa. 
	Esto es para evitar tablas mutantes al borrar un fraccionamiento, ya que al borrar un fraccionamiento pone 
	a la multa en el estado que tenía antes de fraccionarse (cambiando la fecha_estado_actual)
	y al mismo tiempo si ese estado que tenía era de grabación de acuse, se utiliza la fecha_estado_actual
	para calcular el fin de periodo voluntario, por lo que da el error de tabla mutante.
	De este modo, si una multa en estado 'SU' pasase a grabado acuse de sancion, no se calcularía su fin_pe_vol
	si ya tuviese algun fin_pe_vol grabado.

*******************************************************************************************/

CREATE OR REPLACE TRIGGER ESTADO_MOD_BOLETIN 
BEFORE UPDATE OF ESTADO_ACTUAL ON MULTAS
FOR EACH ROW
DECLARE
	xHAYDOCU 	INTEGER;
	xID_ESTADO 	INTEGER;
	xDIFERENCIA	FLOAT;
	xPADRON	CHAR(6);
BEGIN

	-- La tabla ESTADO tiene todos los estados (menos el actual) por los que pasa una Multa.
	-- La tabla ESTADO es un historico de la evolución de la multa.
	IF (:OLD.ESTADO_ACTUAL<>:NEW.ESTADO_ACTUAL) THEN

		INSERT INTO ESTADO (MUNICIPIO, EXPEDIENTE, FECHA_ESTADO, ESTADO)
			VALUES(:NEW.MUNICIPIO, :NEW.EXPEDIENTE,:OLD.FECHA_ESTADO_ACTUAL,:OLD.ESTADO_ACTUAL)
		RETURNING ID INTO xID_ESTADO;
	
		-- Si la multa tenía algun DOCUMENTO, al guardar el estado
		-- en el historico (tabla ESTADO) hay que hacer apuntar el documento a dicha tabla, 
		-- puesto que los documentos van referidos a ESTADOS de una Multa.
		SELECT COUNT(*) INTO xHAYDOCU FROM DOCMULTA WHERE ID_MULTA=:OLD.ID AND DECODE(REFERENCIA,NULL,'TRUE','BOLETIN','FALSE','TRUE')='TRUE';

		IF xHAYDOCU<>0 THEN -- Hay documentos sobre la multa.
			UPDATE DOCMULTA SET ID_MULTA=0, ID_ESTADO=xID_ESTADO WHERE ID_MULTA=:OLD.ID;
		END IF;	

		IF :NEW.ESTADO_ACTUAL IN ('A2','B2','R2','T2') THEN
		
			if ((:NEW.FIN_PE_VOL is not null) and (:OLD.ESTADO_ACTUAL='SU')) then
				return;
			end if;
			
			:NEW.FIN_PE_VOL:=TRUNC(SUMAR_DIAS_HABILES(:NEW.FECHA_ESTADO_ACTUAL,15),'DD');
			
			IF :NEW.IDVALOR IS NOT NULL THEN
				UPDATE VALORES SET FIN_PE_VOL=:NEW.FIN_PE_VOL WHERE ID=:NEW.IDVALOR; 	
			END IF;
			
		END IF;

	END IF;	

END;
/



/********************************************************************************
Acción: Insertar un boletín.
MODIFICACIÓN: 17/09/2001 M. Carmen Junco Gómez. Adaptación al euro.
MODIFICACIÓN: 31/10/2002 M. Carmen Junco Gómez. Se añade la figura del Tutor.
MODIFICACIÓN: 18/01/2005 M. Carmen Junco Gómez. Se añade la figura del Infractor, por lo que se habrá de indicar
				  el tipo del mismo: conductor, acompañante.
MODIFICACIÓN: 01/04/2005 M. Carmen Junco Gómez. El campo LEY pasa a ser de tipo entero, ya que será clave
				  foránea de la tabla LEYES_SANCIONES.
MODIFICACIÓN: 25/04/2005 M. Carmen Junco Gómez. Incluimos el tipo de denuncia.
********************************************************************************/

CREATE OR REPLACE PROCEDURE InsertaBoletin(
			xMUNICIPIO			IN  CHAR,
			xBOLETIN 			IN	CHAR,
        	xFECHA_BOLETIN 		IN	DATE,
			xAGENTE 			IN	INTEGER,
         xID_ARTICULO		IN	INTEGER,
			xCOD_ENTREGA		IN	INTEGER,
			xTIPO_DENUNCIA		IN	INTEGER,

        	xGRAVEDAD 			IN	CHAR,
        	xLEY 					IN	INTEGER,

        	xIMPORTE 			IN	FLOAT,
        	xLUGAR 				IN	VARCHAR,
        	xHECHO 				IN	VARCHAR,
        	xMATRICULA 			IN	CHAR,
        	xNUMERO 			IN	CHAR,
       	xLETRA 				IN	CHAR,
        	xMARCA 				IN	VARCHAR,
        	xTIPO 				IN	VARCHAR,      		
        	xDNI_PROPIETARIO 	IN	CHAR,
        	xNOMBRE_PROPIETARIO IN	VARCHAR,        		
        	xDNI_CONDUCTOR 		IN	CHAR,
        	xNOMBRE_CONDUCTOR 	IN	VARCHAR,
			xDNI_TUTOR			IN	CHAR,
			xNOMBRE_TUTOR		IN	VARCHAR,
			xTIPO_INFRACTOR	IN	CHAR,
			xIDAlternativo   	IN	INTEGER)
AS	
BEGIN	

   	Insert into MULTAS(MUNICIPIO, BOLETIN, FECHA_BOLETIN, AGENTE, ID_ARTICULO, COD_ENTREGA,
   		TIPO_DENUNCIA, GRAVEDAD, LEY, IMPORTE, LUGAR, HECHO, MATRICULA, NUMERO, LETRA,
        	MARCA, TIPO, DNI_PROPIETARIO,NOMBRE_PROPIETARIO, DNI_CONDUCTOR,
			NOMBRE_CONDUCTOR, DNI_TUTOR, NOMBRE_TUTOR, TIPO_INFRACTOR, IDDOMIALTER) 

	values(xMUNICIPIO, xBOLETIN, xFECHA_BOLETIN, xAGENTE, xID_ARTICULO, xCOD_ENTREGA,
			xTIPO_DENUNCIA, xGRAVEDAD, xLEY, ROUND(xIMPORTE,2), xLUGAR, xHECHO, 
			xMATRICULA, xNUMERO, xLETRA, xMARCA, xTIPO,
			xDNI_PROPIETARIO,xNOMBRE_PROPIETARIO, xDNI_CONDUCTOR,
  			xNOMBRE_CONDUCTOR, xDNI_TUTOR, xNOMBRE_TUTOR, xTIPO_INFRACTOR,
			DECODE(xIDAlternativo,0,NULL,xIDAlternativo));
END;
/

-- **********************************************************************************
-- Acción: Modificar un Boletín.
-- MODIFICACIÓN: 17/09/2001 M. Carmen Junco Gómez. Adaptación al Euro.
-- MODIFICACIÓN: 31/10/2002 M. Carmen Junco Gómez. Se introduce la figura del tutor.
-- MODIFICACIÓN: 30/01/2004 Gloria Maria Calle Hernandez. Cuando se introducen datos
-- 			  sobre el conductor si este estaba vacio o en espera del envio de los 
-- 			  datos de trafico, se pasa al estado=P1.
-- MODIFICADO: 18/02/2004. Lucas Fernández Pérez. Antes, si se ponían datos de 
--				propietario estando en estado 'FD' pasaba a 'P1'. Ahora pasa de 'FD' 
--				a 'P1' si se rellenan los datos del CONDUCTOR.
-- MODIFICADO: 28/12/2004 M. Carmen Junco Gómez. Se introduce el parámetro xCambiarEstado,
--				que indica si el boletín ha de volver al estado P1 o quedarse en el que 
--				está por cambio de titularidad (conductor o tutor)	
-- MODIFICACIÓN: 18/01/2005 M. Carmen Junco Gómez. Se añade la figura del Infractor, por lo que se habrá de indicar
--		  	   el tipo del mismo: conductor, acompañante.
-- MODIFICACIÓN: 01/04/2005 M. Carmen Junco Gómez. El campo LEY pasa a ser de tipo entero, ya que será clave
--				foránea de la tabla LEYES_SANCIONES.
-- MODIFICACIÓN: 25/04/2005 M. Carmen Junco Gómez. Incluimos el tipo de denuncia.
-- **********************************************************************************
CREATE OR REPLACE PROCEDURE ModificaBoletin(
			xID					IN 	INTEGER,
			xBOLETIN 			IN	CHAR,
        	xFECHA_BOLETIN 		IN	DATE,
			xAGENTE 			IN	INTEGER,
         xID_ARTICULO 		IN	INTEGER,
			xCOD_ENTREGA		IN	INTEGER,
			xTIPO_DENUNCIA		IN	INTEGER,

        	xGRAVEDAD 			IN	CHAR,
        	xLEY 				   IN	INTEGER,
        	xIMPORTE 			IN	FLOAT,
        	xLUGAR 				IN	VARCHAR,
        	xHECHO 				IN	VARCHAR,
        	xMATRICULA 			IN	CHAR,
        	xNUMERO 			IN	CHAR,
       	xLETRA 				IN	CHAR,
        	xMARCA 				IN	VARCHAR,
        	xTIPO 				IN	VARCHAR,

        	xDNI_PROPIETARIO 	IN	CHAR,
        	xNOMBRE_PROPIETARIO IN	VARCHAR,

        	xDNI_CONDUCTOR 		IN	CHAR,
        	xNOMBRE_CONDUCTOR 	IN	VARCHAR,

			xDNI_TUTOR			IN	CHAR,
			xNOMBRE_TUTOR		IN	VARCHAR,
			
			xTIPO_INFRACTOR	IN	CHAR,
			xIDAlternativo   	IN	INTEGER,
			xCambiarEstado		IN	CHAR)
AS
  			mESTADO				CHAR(2);
BEGIN

   	Update MULTAS Set BOLETIN=xBOLETIN, FECHA_BOLETIN=xFECHA_BOLETIN,   	
			AGENTE=xAGENTE, ID_ARTICULO=xID_ARTICULO, COD_ENTREGA=xCOD_ENTREGA,
			TIPO_DENUNCIA=xTIPO_DENUNCIA, GRAVEDAD=xGRAVEDAD, LEY=xLEY, 
			IMPORTE=ROUND(xIMPORTE,2),	LUGAR=xLUGAR, HECHO=xHECHO,
			MATRICULA=xMATRICULA, NUMERO=xNUMERO, LETRA=xLETRA,
        	MARCA=xMARCA, TIPO=xTIPO,
			DNI_PROPIETARIO=xDNI_PROPIETARIO, NOMBRE_PROPIETARIO=xNOMBRE_PROPIETARIO,
        	DNI_CONDUCTOR=xDNI_CONDUCTOR, NOMBRE_CONDUCTOR=xNOMBRE_CONDUCTOR,
			DNI_TUTOR=xDNI_TUTOR, NOMBRE_TUTOR=xNOMBRE_TUTOR,
			TIPO_INFRACTOR=xTIPO_INFRACTOR,
			IDDOMIALTER=DECODE(xIDAlternativo,0,NULL,xIDAlternativo)
	Where ID=xID
	RETURNING ESTADO_ACTUAL INTO mESTADO;
	
	if xDNI_CONDUCTOR is not null and mESTADO='FD' then
		UPDATE MULTAS SET ESTADO_ACTUAL='P1',
			FECHA_ESTADO_ACTUAL=SYSDATE
		WHERE ID=xID;
	end if;
	
	-- se vuelve el boletín al estado P1 por cambio de titularidad
	if (xCambiarEstado='S') then
		UPDATE MULTAS SET ESTADO_ACTUAL='P1',
							   FECHA_ESTADO_ACTUAL=SYSDATE,
							   EMISOR=NULL,
							   TRIBUTO=NULL,
							   EJER_C60=NULL,
							   REFERENCIA=NULL,
							   IMP_CADENA=NULL,
							   DISCRI_PERIODO=NULL,
							   DIGITO_YEAR=NULL,
							   F_JULIANA=NULL,
							   DIGITO_C60_MODALIDAD2=NULL,
							   FVENCIMIENTO=NULL
		WHERE ID=xID;
	end if;

END;
/

/*******************************************************************************
Acción: Cambiar año de trabajo.
********************************************************************************/

CREATE OR REPLACE PROCEDURE NEW_ANO(
		xMUNICIPIO IN CHAR,
		xANO 	     IN CHAR)
AS

   xEXPE    CHAR(10);
   CONTADOR INTEGER;
   CONTAWORK INTEGER;

BEGIN

   SELECT COUNT(*) INTO CONTADOR FROM MULTAS
   WHERE MUNICIPIO=xMUNICIPIO AND SUBSTR(EXPEDIENTE,1,4)=SUBSTR(xANO,1,4);   
   
   IF (CONTADOR=0) THEN
      SELECT COUNT(*) INTO CONTAWORK FROM MULTASWORK WHERE MUNICIPIO=xMUNICIPIO;
      IF (CONTAWORK=0) THEN
         INSERT INTO MULTASWORK(MUNICIPIO,YEAR_WORK,BOLETIN) VALUES (xMUNICIPIO,xANO,0);    
      ELSE
         UPDATE MULTASWORK SET YEAR_WORK=xANO,BOLETIN=0 WHERE MUNICIPIO=xMUNICIPIO;
      END IF;    
   ELSE   
      SELECT MAX(EXPEDIENTE) INTO xEXPE FROM MULTAS
      WHERE SUBSTR(EXPEDIENTE,1,4)=xANO AND MUNICIPIO=xMUNICIPIO;

      UPDATE MULTASWORK SET YEAR_WORK=xANO,BOLETIN=SUBSTR(xEXPE,6,5)
      WHERE MUNICIPIO=xMUNICIPIO;
   END IF;

END;
/

/********************************************************************************
Acción: Dar de alta las sanciones.
MODIFICACIÓN: 17/09/2001 M. Carmen Junco Gómez. Adaptación al euro.
MODIFICACIÓN: 28/11/2002 M. Carmen Junco Gómez. Se inserta el campo Apartado.
MODIFICACIÓN: 27/12/2004 M. Carmen Junco Gómez. Se incluyen la gravedad y la ley a las 
				  sanciones.
MODIFICACIÓN: 01/04/2005 M. Carmen Junco Gómez. Las Leyes serán configurables, y el campo
				  Ley es ahora el id de la tabla leyes_sanciones
********************************************************************************/

CREATE OR REPLACE PROCEDURE InsertaSancion(
			xMUNICIPIO  IN	CHAR,
			xARTICULO	IN	CHAR,
			xAPARTADO	IN	CHAR,
			xOPCION 		IN	CHAR,
        	xSANCION 	IN	VARCHAR2,
        	xGRAVEDAD	IN	CHAR,
        	xLEY			IN	INTEGER,
			xDESCUENTO 	IN	FLOAT,
        	xIMPORTE 	IN	FLOAT)
AS
BEGIN
   	Insert into SANCION(MUNICIPIO,ARTICULO,APARTADO,OPCION,
				  SANCION,GRAVEDAD,LEY,DESCUENTO,IMPORTE)
	values(xMUNICIPIO,xARTICULO,xAPARTADO,xOPCION,
				  RTRIM(xSANCION),xGRAVEDAD,xLEY,ROUND(xDESCUENTO,2),ROUND(xIMPORTE,2)); 
END;
/

/********************************************************************************
Acción: Dar de alta los agentes.
********************************************************************************/

CREATE OR REPLACE PROCEDURE InsertaAgentes(
			xAGENTE		IN	INTEGER,
			xMUNICIPIO  IN	CHAR,
			xNOMBRE 	IN	VARCHAR2,
        	xDIRECCION 	IN	CHAR,
	      	xNIF 		IN	CHAR,
            xTELEFONO 	IN	CHAR)

AS
BEGIN

   	Insert into AGENTES(AGENTE, MUNICIPIO, NOMBRE, DIRECCION, NIF, TELEFONO)
	values(xAGENTE, xMUNICIPIO, xNOMBRE, xDIRECCION, xNIF, xTELEFONO); 

END;
/


/********************************************************************************
Acción: Indica si un boletín existe
********************************************************************************/

CREATE OR REPLACE PROCEDURE MULTAS_GET_BOLETIN(
        xMUNICIPIO IN  CHAR,
		xBOLETIN   IN  CHAR,
		xYEAR      IN  CHAR,
        xSI 	   OUT CHAR)
AS
BEGIN

SELECT DECODE(COUNT(*),0,'N','S') INTO xSI
FROM MULTAS 
WHERE BOLETIN=xBOLETIN AND YEAR=xYEAR AND MUNICIPIO=xMUNICIPIO;

END;
/


/********************************************************************************
Acción: Añadir o modificar un DOCUMENTO de un expediente 
********************************************************************************/
CREATE OR REPLACE PROCEDURE ADDMOD_DOCUMULTA(
		xID_ESTADO 	IN INTEGER,
		xID_MULTA 	IN INTEGER,
		xREFERENCIA IN VARCHAR2,
		xMOTIVO 	IN VARCHAR2,
		xTIPO 	IN VARCHAR2)
AS
BEGIN
	
	IF xTIPO='A' THEN  -- AÑADIR APUNTANDO A ESTADO O A MULTA
		INSERT INTO DOCMULTA(ID_MULTA,ID_ESTADO, REFERENCIA, MOTIVO, IMAGEN) 
		VALUES(xID_MULTA,xID_ESTADO, xREFERENCIA, xMOTIVO, empty_blob());
	END IF;

	IF xTIPO='M' THEN  -- MODIFICAR APUNTANDO A ESTADO O A MULTA
		UPDATE DOCMULTA SET MOTIVO=xMOTIVO
		WHERE ID_ESTADO=xID_ESTADO AND ID_MULTA=xID_MULTA;
	END IF;

END;
/
/********************************************************************************
Acción: Poner los datos del propietario y del conductor que nos llegan de tráfico
********************************************************************************/

CREATE OR REPLACE PROCEDURE PUT_PROPIETARIO(
                  xID 		IN INTEGER,
			xDNI 		IN CHAR)
AS 
   xNombre VARCHAR(40);
BEGIN

	BEGIN

		SELECT NOMBRE INTO xNOMBRE FROM CONTRIBUYENTES WHERE NIF=xDNI;	

	EXCEPTION
		WHEN NO_DATA_FOUND THEN
			xNombre:=NULL;
	END;

	if xNombre is not null then
		UPDATE MULTAS SET ESTADO_ACTUAL='P1',
			FECHA_ESTADO_ACTUAL=SYSDATE,
			DNI_PROPIETARIO=xDNI,NOMBRE_PROPIETARIO=xNOMBRE,
			DNI_CONDUCTOR=xDNI,NOMBRE_CONDUCTOR=xNOMBRE
		WHERE ID=xID;
	end if;

END;
/


-- *******************************************************************************
-- Acción: Meter los acuses de un expediente tanto de 1ª como de 2ª Notificación.
-- Modificado: 14/11/2003. Lucas Fernández Pérez. 
--			   Se añade funcionalidad para anular los acuses
-- Modificado: 19/12/2003. Gloria María Calle Hernández
--			   Se permite añadir acuse en los casos en que ya esté ingresado.
-- Modificado: 18/02/2004. Gloria María Calle Hernández
--			   Se permite añadir acuse en los casos en que esté en estado alegado (AL).
-- Modificado: 18/02/2004. Gloria María Calle Hernández
--			   Si Estado_Actual in ('IN','IV','AL') y xEstadoActual es un acuse
--			   intentaba insertar dos veces tercero en la tabla MultasNotiTerceros.
--			   Cambiado segundo IF de primer nivel por ELSE.
-- ********************************************************************************

CREATE OR REPLACE PROCEDURE AcusesRecibo(
    xID 			IN  INTEGER,
	xEstadoActual 	IN  CHAR,
	xFecha 			IN  DATE,
	xParentesco		IN  VARCHAR,
	xNIF			IN	CHAR,
	xNombre			IN	VARCHAR)
AS 
    vMultas			MULTAS%ROWTYPE;
	vEstado			CHAR(2);
	
BEGIN

  -- Recuperamos registro de la tabla de multas para comprobar estado actual 
  SELECT * INTO vMultas FROM MULTAS WHERE ID=xID;

  -- Tratamiento distinto para los que están ya ingresados 
  IF vMultas.Estado_Actual in ('IN','IV','AL') THEN
     
	 IF (xEstadoActual is NULL) THEN --Se trata de una anulacion del acuse 

	 	 select estado into vEstado from estado 
	 	  where municipio=vMultas.MUNICIPIO and expediente=vMultas.EXPEDIENTE
		    and fecha_estado = (select min(fecha_estado) from 
  	  						    (select * from estado 
								  where municipio=vMultas.MUNICIPIO and expediente=vMultas.EXPEDIENTE
								  order by expediente,fecha_estado desc)
					   			 where rownum<3); 

     	 INSERT INTO ESTADO (MUNICIPIO, EXPEDIENTE, FECHA_ESTADO, ESTADO)
     	 VALUES(vMultas.MUNICIPIO,vMultas.EXPEDIENTE,xFecha,vEstado);
	 
	 ELSE --Se trata de una grabación del acuse 

     	 INSERT INTO ESTADO (MUNICIPIO, EXPEDIENTE, FECHA_ESTADO, ESTADO)
     	 VALUES(vMultas.MUNICIPIO,vMultas.EXPEDIENTE,xFecha,xEstadoActual);

     	 IF (xEstadoActual='T1') or (xEstadoActual='T2') THEN
	     	 INSERT INTO MultasNotiTerceros (ID,FECHA_ESTADO,PARENTESCO,NIF,NOMBRE)
    		 VALUES (xID,xFECHA,xPARENTESCO,xNIF,xNOMBRE);
     	 END IF;
	 END IF;
  
  ELSE
     -- Grabamos acuse  
     IF xEstadoActual in ('A1','T1','R1','D1','A2','T2','R2','D2')  THEN  
    
        UPDATE MULTAS SET ESTADO_ACTUAL=xEstadoActual, 
	     	               FECHA_ESTADO_ACTUAL=xFecha
	     WHERE ID=xID AND (ESTADO_ACTUAL IN ('1N','2N'));
	
        IF (xEstadoActual='T1') or (xEstadoActual='T2') THEN
	        INSERT INTO MultasNotiTerceros (ID,FECHA_ESTADO,PARENTESCO,NIF,NOMBRE)
    	    VALUES (xID,xFECHA,xPARENTESCO,xNIF,xNOMBRE);
        END IF;
		
     -- Anulamos acuse 
     ELSIF xEstadoActual in ('1N','2N') THEN 
  
        UPDATE MULTAS SET ESTADO_ACTUAL=xEstadoActual, 
	                      FECHA_ESTADO_ACTUAL=xFecha
   	     WHERE ID=xID 
	       AND (ESTADO_ACTUAL='A1' or ESTADO_ACTUAL='T1' or ESTADO_ACTUAL='R1' or ESTADO_ACTUAL='D1' OR
		  	    ESTADO_ACTUAL='A2' or ESTADO_ACTUAL='T2' or ESTADO_ACTUAL='R2' or ESTADO_ACTUAL='D2');
     END IF;
  END IF;
	
END;
/


/********************************************************************************
Acción: Los Expedientes pendientes de publicar mandarlos a publicar.
MODIFICACIÓN: 26/04/2005 M. Carmen Junco Gómez. Permitir mandar a publicar sólo 
	denuncias, sólo sanciones o ambas.
********************************************************************************/

CREATE OR REPLACE PROCEDURE PUT_MANDA_PUBLICACION(
		xMUNICIPIO IN CHAR,
		xFECHA     IN DATE,
		xESTADO	  IN CHAR)
AS
BEGIN

	IF ((xESTADO='D?') OR (xESTADO='D1')) THEN
   	UPDATE MULTAS SET ESTADO_ACTUAL='F1', FECHA_ESTADO_ACTUAL=xFECHA
   	WHERE ESTADO_ACTUAL='D1' AND MUNICIPIO=xMUNICIPIO;
   END IF;
   
   IF ((xESTADO='D?') OR (xESTADO='D2')) THEN
   	UPDATE MULTAS SET ESTADO_ACTUAL='F2', FECHA_ESTADO_ACTUAL=xFECHA
   	WHERE ESTADO_ACTUAL='D2' AND MUNICIPIO=xMUNICIPIO;
   END IF;

END;
/

-- ********************************************************************************
-- Acción: Cambiar el estado de un Expediente.
-- ********************************************************************************
-- La fecha de vencimiento tendrá datos cuando: 
--	A) haya pase automático y 
--	B) se llame desde la creación de 1ª ó 2ª Notificaciones. 
-- Si para una multa es la primera vez que se indica la fecha, se inserta una tupla 
--	en valores. En todos estos casos se reajustan campos de la multa correspondientes a
-- los datos del c60. Además, si en ese reajuste cambia el importe, se actualiza también
-- en la tabla de valores.
--
-- MODIFICACIÓN: 06/11/2003 Agustín León Robles
--	              Se añade el campo fvencimiento
-- MODIFICACIÓN: 28/12/2004 M. Carmen Junco Gómez
--					  Se pedirá fecha de vencimiento tanto si hay pase automático como si no.					  
-- MODIFICACIÓN: 10/02/2005 Agustín León Robles. Se añade los códigos de barras en las notificaciones
-- MODIFICACIÓN: 31/03/2005 M. Carmen Junco Gómez. Desde delphi se pasa fecha de vencimiento 01/01/1901, lo que hacía 
--					  que se generaran datos para el cuaderno 60, anulando la bonificación. Si se pasa esta fecha, no modificamos
--					  la fecha juliana, la fecha de vencimiento ni el código de barras.
--
CREATE OR REPLACE PROCEDURE CambiarDeEstados(
 		xMUNICIPIO	    	IN char,
		xEstadoAnterior 	IN char, 
		xEstadoActual   	IN char,
		xFVencimiento	   IN date,
		xFecha 	    	   IN date)
AS 
	xCODBARRAS_DENUNCIA	VARCHAR2(10);
	xCODBARRAS_SANCION	VARCHAR2(10);
BEGIN	

	--Se toma la parte fija del codigo de barras tanto de la denuncia como de la sancion
	SELECT CODBARRAS_FIJO_DENUNCIA,CODBARRAS_FIJO_SANCION INTO xCODBARRAS_DENUNCIA,xCODBARRAS_SANCION
   FROM MULTASWORK WHERE MUNICIPIO=xMUNICIPIO;

	--cuando se pasan a pendiente de resolución de alcaldia no se puede cambiar la 
	--fecha de vencimiento de las denuncias
	
	IF (xEstadoAnterior='PR' and xEstadoActual='P2') THEN
	
		--El codigo de barras estará formado por la parte fija  + 'S' + el ID relleno de 5 ceros + los 2 ultimos digitos del año		
		UPDATE MULTAS SET 
				ESTADO_ACTUAL=xEstadoActual, 
				FECHA_ESTADO_ACTUAL=xFecha,
				CODBARRAS_SANCION=xCODBARRAS_SANCION||'S'||lpad(ID,'5','0')||to_char(sysdate,'yy')
		WHERE ESTADO_ACTUAL=xEstadoAnterior and MUNICIPIO=xMUNICIPIO;
		
	ELSE
	
		--El codigo de barras estará formado por la parte fija  + 'C' + el ID relleno de 5 ceros + los 2 ultimos digitos del año		
		
		IF ((TO_CHAR(xFVencimiento,'dd/mm/yyyy')='01/01/1901') OR (xFVencimiento is null)) THEN
			UPDATE MULTAS SET ESTADO_ACTUAL=xEstadoActual, 
									FECHA_ESTADO_ACTUAL=xFecha
			WHERE ESTADO_ACTUAL=xEstadoAnterior and MUNICIPIO=xMUNICIPIO;
		ELSE
			UPDATE MULTAS SET ESTADO_ACTUAL=xEstadoActual, 
									FECHA_ESTADO_ACTUAL=xFecha,
									F_JULIANA=TO_CHAR(xFVencimiento,'ddd'),
									FVENCIMIENTO=xFVencimiento,
									CODBARRAS_DENUNCIA=xCODBARRAS_DENUNCIA||'C'||lpad(ID,'5','0')||to_char(sysdate,'yy')
			WHERE ESTADO_ACTUAL=xEstadoAnterior and MUNICIPIO=xMUNICIPIO;
		END IF;		
		
	END IF;
	
     
END;
/

/********************************************************************************
Acción: Repasar Expedientes.
MODIFICACIÓN: 23/10/2003  Gloria Maria calle Hernandez. 
			  Se añade un nuevo estado T1 (Notificacion de la Denuncia a un Tercero)
Modificacion: 15/12/2003. Agustín León Robles.
			  En vez de controlar por la fecha del boletin se hace ahora por la fecha de estado actual
Modificacion: 23/04/2004. Agustín León Robles. Se cambia cuando no se controlan los acuses de recibo 
Modificación: 15/03/2005. M. Carmen Junco Gómez. Se controla que al sumar días a las fechas sólo se 
			  tengan en cuenta días hábiles (los inhábiles se habrán previamente configurado a través de
			  los calendarios en la configuración de gestión tributaria).
************************************************************************************/

CREATE OR REPLACE PROCEDURE GUARDIAN(
		xMUNICIPIO IN CHAR)

AS    
	xDENUNCIA			INTEGER;
	xSANCION			INTEGER;
	xCONTROLAR_ACUSES	CHAR(1);
	
BEGIN

	SELECT DENUNCIA, SANCION, CONTROLAR_ACUSES INTO xDENUNCIA, xSANCION, xCONTROLAR_ACUSES
	FROM DATOSPER WHERE MUNICIPIO=xMUNICIPIO;

	--En municipios que no lleven control de los acuses de recibo para pasar a resolucion de alcaldia o a pendiente
	--de certificacion de descubierto, se toma el valor 1N o 2N y si llevan control A1 o A2
	IF xCONTROLAR_ACUSES='S' THEN		
		
		UPDATE MULTAS SET ESTADO_ACTUAL='PR',FECHA_ESTADO_ACTUAL=SYSDATE 
     	WHERE (	(ESTADO_ACTUAL IN ('A1','B1','R1','T1')
     				AND TRUNC(SUMAR_DIAS_HABILES(FECHA_ESTADO_ACTUAL,xDENUNCIA),'DD') <= TRUNC(SYSDATE,'DD') )
     			OR 
     			
     			(ESTADO_ACTUAL='DA') --Denegada la alegacion de la denuncia
     			
     		   )
		AND MUNICIPIO=xMUNICIPIO;
		
		
		UPDATE MULTAS SET ESTADO_ACTUAL='PC',FECHA_ESTADO_ACTUAL=SYSDATE
		WHERE ( (ESTADO_ACTUAL IN ('A2','B2','R2','T2')
					AND TRUNC(SUMAR_DIAS_HABILES(FECHA_ESTADO_ACTUAL,xSANCION),'DD') <= TRUNC(SYSDATE,'DD') )
				OR 
     			
     			(ESTADO_ACTUAL='DS') --Denegada la alegacion de la sancion
     			
     		   )	
		AND MUNICIPIO=xMUNICIPIO;
		
	ELSE
		
		-- Albolote y Maracena tienen 1 mes con descuento y 90 días (3 meses) sin descuento.

		-- El campo denuncia indicará los días que se le permite al contribuyente
		-- para que pueda haber un periodo de alegaciones ejemplo 120 días en Albolote.

     	-- UNA VEZ QUE SE HAN NOTIFICADO POR CORREO O SE HAN PUBLICADO EN EL BOP
   		UPDATE MULTAS SET ESTADO_ACTUAL='PR',FECHA_ESTADO_ACTUAL=SYSDATE      	
   		WHERE (	(ESTADO_ACTUAL IN ('1N','B1','R1','T1')
     				AND TRUNC(SUMAR_DIAS_HABILES(FECHA_BOLETIN,xDENUNCIA),'DD') <= TRUNC(SYSDATE,'DD') )
     			OR 
     			
     			(ESTADO_ACTUAL='DA') --Denegada la alegacion de la denuncia
     			
     		   )		
		AND MUNICIPIO=xMUNICIPIO;


		-- En Albolote tipicamente 180 días (6 meses)

     	--UNA VEZ QUE SE HAN NOTIFICADO POR CORREO O SE HAN PUBLICADO EN EL BOP
		UPDATE MULTAS SET ESTADO_ACTUAL='PC',FECHA_ESTADO_ACTUAL=SYSDATE		
		WHERE ( (ESTADO_ACTUAL IN ('2N','B2','R2','T2')
					AND TRUNC(SUMAR_DIAS_HABILES(FECHA_BOLETIN,xSANCION),'DD') <= TRUNC(SYSDATE,'DD') )
				OR 
     			
     			(ESTADO_ACTUAL='DS') --Denegada la alegacion de la sancion
     			
     		   )		
		AND MUNICIPIO=xMUNICIPIO;
		
	END IF;
	

END;
/

/********************************************************************************
Acción: Los que se mandaron a publicar ponerles la fecha de publicación.
MODIFICACIÓN: 26/04/2005 M. Carmen Junco Gómez. Permitir grabar fecha de 
	publicación sólo para denuncias, sólo sanciones o ambas. 
********************************************************************************/

CREATE OR REPLACE PROCEDURE PUT_FECHA_PUBLICACION(
		xMUNICIPIO IN   CHAR,
		xFECHA     IN   DATE,
        xPUBLICA   IN   DATE,
        xESTADO	   IN	CHAR)
AS
BEGIN

	IF ((xESTADO='F?') OR (xESTADO='F1')) THEN

   	UPDATE MULTAS SET ESTADO_ACTUAL='B1', FECHA_ESTADO_ACTUAL=xPUBLICA
      WHERE ESTADO_ACTUAL='F1' AND MUNICIPIO=xMUNICIPIO
		AND TO_CHAR(FECHA_ESTADO_ACTUAL,'dd/mm/yyyy')=
                TO_CHAR(xFECHA,'dd/mm/yyyy');
           
   END IF;
   
   IF ((xESTADO='F?') OR (xESTADO='F2')) THEN

   	UPDATE MULTAS SET ESTADO_ACTUAL='B2', FECHA_ESTADO_ACTUAL=xPUBLICA
		WHERE ESTADO_ACTUAL='F2' AND MUNICIPIO=xMUNICIPIO
		AND TO_CHAR(FECHA_ESTADO_ACTUAL,'dd/mm/yyyy')=
	          TO_CHAR(xFECHA,'dd/mm/yyyy');
	          
	END IF;

END;
/


/********************************************************************************
Acción: Crear, Pegar o Quitar una multa de un grupo de multas.
********************************************************************************/

CREATE OR REPLACE PROCEDURE CREA_PEGA_GRUPO_MULTAS(
       xID			IN INTEGER,
	 xTIPO		IN CHAR,
       xGRUPO 		IN OUT INTEGER)
AS
BEGIN
   if (xTipo='C') then
	ADD_COD_OPERACION(xGRUPO);
      UPDATE MULTAS SET GRUPO=xGRUPO WHERE ID=xID;
   END IF;

   if xTipo='P' then
      UPDATE MULTAS SET GRUPO=xGRUPO WHERE ID=xID;
   END IF;

   if xTipo='Q' then
      UPDATE MULTAS SET GRUPO=0 WHERE ID=xID;
   END IF;

END;
/

/********************************************************************************
Acción: Escribir en el punteo los datos de las multas.
Autor: Agustin Leon Robles.
Fecha: 27/08/2001
MODIFICACIÓN: 28/11/2002 Mª Carmen Junco Gómez. Se añade el campo APARTADO
MODIFICACIÓN: 17/06/2003 Mª Carmen Junco Gómez. Si el conductor es un menor y le ha sido
			  asociado un tutor, será este el que pase a Valores, incluyendo en el
			  objeto tributario los datos del conductor.
********************************************************************************/

CREATE OR REPLACE PROCEDURE WRITE_MULTAS_PUNTEO(
	v_Multas 		IN MULTAS%ROWTYPE,
	xCONTRAIDO		IN CHAR,
	xFECHA 		IN DATE,
	xF_FIN_PE_VOL	IN DATE,
	xN_CARGO 		IN CHAR,
	xSALTO 		IN CHAR,
	xPADRON		IN CHAR)
AS
	xOBJ_TRIBUTARIO   VARCHAR2(1024);
	xARTICULO 		CHAR(3);
	xAPARTADO		CHAR(2);
	xOPCION 		CHAR(2);
	xSANCION 		VARCHAR(160);
	xTIPO_TRIBUTO	CHAR(2);
BEGIN

	SELECT TIPO_TRIBUTO INTO xTIPO_TRIBUTO
 	FROM CONTADOR_CONCEPTOS
	WHERE MUNICIPIO=v_Multas.MUNICIPIO AND CONCEPTO=xPADRON;

	xOBJ_TRIBUTARIO:='BOLETIN Nº: '|| v_Multas.BOLETIN ||xSALTO;

	xOBJ_TRIBUTARIO:=xOBJ_TRIBUTARIO||'F. DENUNCIA: '|| 
		to_char(v_Multas.FECHA_BOLETIN,'dd-mm-yyyy')||xSALTO;

	xOBJ_TRIBUTARIO:=xOBJ_TRIBUTARIO||'MATRICULA: ' ||
		GetMatricula(v_Multas.MATRICULA,v_Multas.NUMERO,v_Multas.LETRA)||xSALTO;

	IF v_Multas.MARCA IS NOT NULL THEN
         xOBJ_TRIBUTARIO:=xOBJ_TRIBUTARIO||'MARCA: '||RTRIM(v_Multas.MARCA)||xSALTO;
	END IF;

	IF v_Multas.TIPO IS NOT NULL THEN
         xOBJ_TRIBUTARIO:=xOBJ_TRIBUTARIO || 'TIPO: '|| RTRIM(v_Multas.TIPO) || xSALTO;
	END IF;	

	SELECT ARTICULO,APARTADO,OPCION,SANCION 
	INTO xARTICULO,xAPARTADO,xOPCION,xSANCION
      FROM SANCION WHERE ID=v_Multas.Id_Articulo;
      xOBJ_TRIBUTARIO:=xOBJ_TRIBUTARIO || 'Artículo: ' ||RTRIM(xArticulo)||'.'||
			     RTRIM(xApartado)||'.'||RTRIM(xOpcion)||' '|| RTRIM(xSANCION) || xSALTO;
			     
    IF v_Multas.DNI_TUTOR IS NOT NULL THEN
	     xOBJ_TRIBUTARIO:=xOBJ_TRIBUTARIO || 'CONDUCTOR: '|| v_Multas.DNI_CONDUCTOR ||
	     				'  '|| RTRIM(v_Multas.NOMBRE_CONDUCTOR) || xSALTO;
	END IF;

	INSERT INTO PUNTEO
		(AYTO, PADRON, YEAR, RECIBO, NIF, NOMBRE, YEAR_CONTRAIDO,
		VOL_EJE, F_CARGO, N_CARGO, INI_PE_VOL, FIN_PE_VOL,
		CUOTA_INICIAL, PRINCIPAL, OBJETO_TRIBUTARIO, TIPO_DE_OBJETO,TIPO_DE_TRIBUTO)
	VALUES
		(v_Multas.MUNICIPIO,xPADRON,to_char(v_Multas.FECHA_BOLETIN,'yyyy'),v_Multas.ID, 
		DECODE(v_Multas.DNI_TUTOR,NULL,v_Multas.DNI_Conductor,v_Multas.DNI_TUTOR),
		DECODE(v_Multas.DNI_TUTOR,NULL,v_Multas.NOMBRE_CONDUCTOR,v_Multas.NOMBRE_TUTOR),
		xCONTRAIDO,'E',xFECHA,xN_CARGO, 
		v_Multas.FECHA_BOLETIN, xF_FIN_PE_VOL,
		v_Multas.IMPORTE, v_Multas.IMPORTE, xOBJ_TRIBUTARIO, 'L',xTIPO_TRIBUTO);
END;
/



/********************************************************************************
Acción: Pasar multas a Recaudación.
Autor: Agustin Leon Robles.
Fecha: 27/08/2001 
Si Grupo tiene un valor > 0 indica que se quiere pasar un grupo de multas.
********************************************************************************/

CREATE OR REPLACE PROCEDURE MULTAS_PASE_RECA(
		xGRUPO 			IN INTEGER,
		xCONTRAIDO		IN CHAR,
		xFECHA 			IN DATE,
		xF_FIN_PE_VOL	IN DATE,
		xN_CARGO 		IN CHAR)
AS
	xSALTO            CHAR(2);
	xPADRON           CHAR(6);

	--todas las multas de un determinado grupo
	CURSOR cMultasGrupo IS 
		SELECT * FROM MULTAS
		WHERE GRUPO=xGRUPO AND ESTADO_ACTUAL='PC'
		AND PASADO<>'S'
		FOR UPDATE OF PASADO,NUMERO_DE_CARGO,F_CARGO,ESTADO_ACTUAL,FECHA_ESTADO_ACTUAL;

	--todas las multas
	CURSOR cMultas IS 
		SELECT * FROM MULTAS
		WHERE ESTADO_ACTUAL='PC'
		AND PASADO<>'S'
		FOR UPDATE OF PASADO,NUMERO_DE_CARGO,F_CARGO,ESTADO_ACTUAL,FECHA_ESTADO_ACTUAL;

	v_Multas MULTAS%ROWTYPE;

BEGIN

	SELECT min(SALTO) INTO xSALTO FROM SALTO;
	SELECT CONCEPTO INTO xPADRON FROM PROGRAMAS WHERE PROGRAMA='MULTAS';

IF xGRUPO > 0 THEN 

	FOR v_Multas IN cMultasGrupo LOOP

		WRITE_MULTAS_PUNTEO(v_Multas,xCONTRAIDO,xFECHA,xF_FIN_PE_VOL,
				xN_CARGO,xSALTO,xPADRON);

		UPDATE MULTAS SET PASADO='S',NUMERO_DE_CARGO=xN_CARGO,F_CARGO=xFECHA,
				ESTADO_ACTUAL='EJ',FECHA_ESTADO_ACTUAL=sysdate
		WHERE CURRENT OF cMultasGrupo;
	
	END LOOP;

ELSE

	FOR v_Multas IN cMultas LOOP

		WRITE_MULTAS_PUNTEO(v_Multas,xCONTRAIDO,xFECHA,xF_FIN_PE_VOL,
				xN_CARGO,xSALTO,xPADRON);

		UPDATE MULTAS SET PASADO='S',NUMERO_DE_CARGO=xN_CARGO,F_CARGO=xFECHA,
				ESTADO_ACTUAL='EJ',FECHA_ESTADO_ACTUAL=sysdate
		WHERE CURRENT OF cMultas;

	END LOOP;
   
END IF;

END;
/


/********************************************************************************
Autor: 01/04/2003 Mª del Carmen Junco Gómez.
Acción: Pasa un boletín a recaudación, siempre y cuando esté activo el pase 
		automático de multas y ésta se encuentre en estado 'P1','1N', 'A1' o 'T1'
		Se llama desde la consulta de multas únicamente.
--  MODIFICACIÓN: 06/11/2003  Agustín León Robles
--		 Se añade el campo fvencimiento		
DELPHI
********************************************************************************/

CREATE OR REPLACE PROCEDURE MULTAS_PASA_RECA_BOLETIN(
				xID			IN	INTEGER,
				xF_VENCIMIENTO	IN	DATE,
				xFIN_PE_VOL		IN	DATE)
AS

	xVALOR	INT;
	
BEGIN

	UPDATE MULTAS SET F_JULIANA=to_char(xF_VENCIMIENTO,'ddd'),
					FVENCIMIENTO=xF_VENCIMIENTO,
					  FIN_PE_VOL=xFIN_PE_VOL
	WHERE ID=xID
	returning IDVALOR INTO xVALOR;

	UPDATE VALORES SET FIN_PE_VOL=xFIN_PE_VOL WHERE ID=xVALOR; 	

END;
/

/***************************************************************************************
Autor: 01/04/2003 Mª del Carmen Junco Gómez.
Acción: Recalcula los datos para el Cuaderno60 cuando se reimprimen notificaciones
        en 1ª y en 2ª Notificación.
--  MODIFICACIÓN: 06/11/2003  Agustín León Robles
--		 Se añade el campo fvencimiento		        
DELPHI
***************************************************************************************/

CREATE OR REPLACE PROCEDURE MULTAS_RECALCULAR_C60(
			xEXPEDESDE		IN	CHAR,
			xEXPEHASTA		IN	CHAR,
			xF_VENCIMIENTO	IN	DATE)

AS
	CURSOR CMULTAS IS SELECT * FROM MULTAS 
		   WHERE ESTADO_ACTUAL IN ('1N','2N')
		   AND EXPEDIENTE BETWEEN xEXPEDESDE AND xEXPEHASTA;		
BEGIN

	FOR vMULTAS IN CMULTAS
	LOOP

		UPDATE MULTAS SET F_JULIANA=to_char(xF_VENCIMIENTO,'ddd'),
						FVENCIMIENTO=xF_VENCIMIENTO
		WHERE ID=vMULTAS.ID;		
		
	END LOOP;
	    
END;
/



/******************************************************************************************
Acción: Rellena una tabla temporal para imprimir MULTAS
AUTOR: 01/12/2003 Gloria Maria Calle Hernandez
MODIFICADO:	19/01/2004. Gloria Maria Calle Hernandez. Arreglado el filtro por fechas.
			Para fechas en cursores dinámicos usar TRUNC(TO_DATE(fecha),'dd') en lugar de TO_DATE(fecha,formato).
MODIFICADO:	19/01/2004. Gloria Maria Calle Hernandez. Arreglado filtro por fechas.
			Si todos sus filtros son vacios la fecha restringida es FECHA_BOLETIN, si alguno de sus
			filtros no es vacio la fecha restringuida es FECHA_ESTADO_ACTUAL.
MODIFICADO:	26/01/2004. Gloria Maria Calle Hernandez. Añadidos campos de alegacion e informe,
			tanto las fechas como los textos para cada uno, necesarios para las impresiones 
			en las notificaciones (resoluciones).
MODIFICADO: 27/01/2004. Gloria Maria Calle Hernandez. Modificaciones para unir ambas tablas de impresión 
			temporal de listados y notificaciones sobre el modulo de multas. Añadidos campos y busquedas.
			--	Dependiendo del PaseAutomatico, las fechas que saldrán en la notificación son distintas:
			--	'N' :   xDesde1 -> FECHA_BOLETIN (1N/P1) ó FECHA_BOLETIN+xDenuncia (2N/P2)
			--  		xHasta1 -> FECHA_BOLETIN + xDescuento (1N/P1) ó FECHA_BOLETIN +xSancion (2N/P2)
			--	'S' : 	xDesde1 -> FECHA_ESTADO_ACTUAL (1N/P1/2N/P2)
			--			xHasta1 -> F_VENCIMIENTO (1N/P1/2N/P2)
MODIFICADO: 30/01/2004. Gloria Maria Calle Hernandez. Eliminada la ordenacion del select sobre multas
			para realizar el insert, pues no tiene porqué y para que no lleve a confusión. El order sobre la 
			tabla temporal se ejecuta desde Delphi, al abrir el FastReport correspondiente.
MODIFICADO: 03/02/2004. Gloria Maria Calle Hernandez. Realizada modificacion para que rellene las fechas de
			notificaciones y acuses no solo a partir de la tabla de Estado sino tambien de la tabla de 
			Multas.
MODIFICADO: 20/02/2004. Gloria Maria Calle Hernandez. No rellenaba el texto de la primera alegacion.
MODIFICADO: 27/02/2004. Gloria Maria Calle Hernandez. Añadida opcion cuando xEstado='D?' para poder
			tomar tanto los boletines que están en D1 como en D2.
MODIFICADO: 21/04/2004 M. Carmen Junco Gómez. Se incluye una nueva comprobación para montar la consulta, ya
			que no se podían reimprimir notificaciones (incluía boletines en distintos estados)
Modificado: 22/04/2004. Agustín León Robles. Se cambia la fecha del periodo de pago cuando estamos en la
			configuración de que no está activado el pase automatico a recaudación. 
Modificado: 23/04/2004. Agustín León Robles. Se añaden los campos codigo_postal,poblacion y provincia para 
			una mejor impresion de las notificaciones
Modificado: 26/04/2004. Agustín León Robles. Se añade un parametro para saber si queremos excluir los
			boletines cuyo codigos postales sean los del municipio, por ejemplo para los listados a correos
			o impresion de etiquetas nos puede interesar excluir a los del municipio
Modificado: 04/05/2004. Agustín León Robles. Se cambia la mascara de la hora de la denuncia
Modificado: 10/05/2004. Agustín León Robles. Se añade una nueva opcion para los listados el de la publicacion
						F1 o F2
MODIFICADO: 18/05/2004. Mª Carmen Junco Gómez. Al seleccionar el motivo de la tabla docmultas se seleccionaban
			más de una tupla. Ahora se recoge la asociada al mayor ID en Estados.
MODIFICADO: 09/07/2004. Mª Carmen Junco Gómez. En lugar de un parámetro xExcluir para incluir o no los boletines del municipio
		   en el listado, vamos a incluir un parámetro xQueImprimo que podrá tener tres valores: 'T' de Todos, 'M' de boletines
		   del municipio y 'F' de boletines de fuera del municipio.			
MODIFICADO: 28/12/2004. Mª Carmen Junco Gómez. Desaparecen los días de descuento de la tabla datosper (se pregunta por pantalla
			fecha límite de pago con descuento tanto para pase automático como no).
			Desaparecen los campos Desde2 y Hasta2.
MODIFICADO: 29/12/2004. Mª Carmen Junco Gómez. Se incluye el parámetro xSENTENCIA. Si ésta se pasa como parámetro, se utilizará 
		   para abrir el cursor (si es nula se montará dependiendo del resto de parámetros de entrada)
Modificado: 02/02/2005. Agustín León Robles. Se añade el campo codigo de barras de la modalidad 2
Modificado: 10/02/2005. Agustín León Robles. Se añade los codigos de barras de correos.
MODIFICADO: 04/04/2005. Mª Carmen Junco Gómez. Las leyes son configurables, por lo que la descripción de la ley se recogerá
				de la nueva tabla LEYES_SANCIONES, cuyo id coincide con el campo LEY de la tabla MULTAS.
MODIFICADO: 25/04/2005. M. Carmen Junco Gómez. Se añade el tipo de denuncia.
MODIFICADO: 28/04/2005. M. Carmen Junco Gómez. Se cambia la sentencia
				vOtroImporte:= vMultas.Importe + round(vMultas.Importe*0.05,2);
				por
				vOtroImporte:= vMultas.Importe;
MODIFICADO: 06/05/2005. Lucas Fernández Pérez. Se cambia la variable vDESC_SANCION de 120 a 160 caracteres
               porque recoge el valor de un campo de longitud 160, y daba errores.
Modificado: 27/06/2006. Agustín León Robles. Las denuncias que se encuentran en estado A1 o A2 se pueden reimprimir las denuncias
Modificado: 19/07/2006. Agustín León Robles. Se vuelve a dejar la reimpresion de las denuncias 
			a como estaban antes del ultimo cambio descrito encima. Ahora para reimprimir una denuncia en estado A1 o A2 habra que pasarlas
			manualmente a 1N o 2N
******************************************************************************************/
CREATE OR REPLACE PROCEDURE Imp_tmp_Multas (
		xMUNI			IN CHAR,
		xCARGO			IN VARCHAR2,
		xESTADO			IN VARCHAR2,
		xMATRICULA		IN CHAR,
		xNUMERO			IN CHAR,
		xLETRA			IN CHAR,
		xAGENTE			IN INTEGER,
		xARTICULO		IN INTEGER,
		xNOMBRE	 		IN VARCHAR2,
		xFDESDE			IN DATE,
		xFHASTA			IN DATE,
		xPASADO			IN VARCHAR2,
		xEXPEDesde 		IN CHAR,
		xEXPEHasta 		IN CHAR,
		xGRUPO			IN INTEGER,
		xQUEIMPRIMO 	IN CHAR,
		xSENTENCIA		IN	VARCHAR2)
AS
  	-- Variables para crear la sentencia
   TYPE tCURSOR IS REF CURSOR;  -- define REF CURSOR type
   vCURSOR    	 	tCURSOR;     -- declare cursor variable
	vMULTAS			MULTAS%ROWTYPE;
	vSENTENCIA		VARCHAR2(2000);
  	vESTADOS		VARCHAR2(150);

	--Variables para hallar campos y guardarlos en la tabla de impresion de multas temporal
   vCARGO			   	VARCHAR2(10);

  	vCONCEPTO		   	VARCHAR2(6);
	vDESC_CONCEPTO			VARCHAR2(50);

   vNOMBRE_AGENTE 		VARCHAR(40);
	vARTICULO_SANCION 	CHAR(3);
	vAPARTADO_SANCION		CHAR(2);
   vOPCION_SANCION	 	CHAR(2);
   vDESC_SANCION 			VARCHAR(160);
   vIMPORTE_SANCION		FLOAT;
	vDESCUENTO_SANCION	FLOAT;

	vMOTIVO_ENTREGA		VARCHAR(60);
  	vNOTIFICADO_ENTREGA  CHAR(1);

  	vDESC_ESTADO_ACTUAL	VARCHAR(50);

  	vDESC_LEY				VARCHAR(50);
  	vDESC_LEY_ACRO			CHAR(10);
  	
  	vDESC_TIPO_DENUNCIA	VARCHAR2(50);

  	vFECHA_1NOTIFICACION	DATE;
	vFECHA_2NOTIFICACION	DATE;
  	vFECHA_1ACUSE			DATE;
	vFECHA_2ACUSE			DATE;
	vFECHA_BOLETIN			VARCHAR2(20);
	
	vDOMIFISCAL_CONDUC	VARCHAR2(200);
	vDOMIFISCAL_PROPIE	VARCHAR2(200);

	vFECHA_1ALEGACION		DATE;
	vFECHA_1INFORME		DATE;
	vFECHA_2ALEGACION		DATE;
	vFECHA_2INFORME		DATE;
	vTEXTO_1ALEGACION		VARCHAR2(1024);
	vTEXTO_1INFORME		VARCHAR2(1024);
	vTEXTO_2ALEGACION		VARCHAR2(1024);
	vTEXTO_2INFORME		VARCHAR2(1024);

	vDENUNCIA				INTEGER;
	vSANCION					INTEGER;
	vGRAVEDAD				VARCHAR2(10);
	vDNI_NOTI				CHAR(10);
	vNOMBRE_NOTI			VARCHAR2(40);
	vDIRE_NOTI				VARCHAR2(200);
	vCODPOSTAL				CHAR(5);
	vPOBLACION				VARCHAR2(35);
	vPROVINCIA				VARCHAR2(35);
	
	vDesde1					DATE;
	vHasta1					DATE;	
	vOtroImporte			FLOAT;
	xEnMunicipio			boolean;
	
	cursor cCodigosPostales is select codigo_postal from MUNICPOSTALES where municipio=xMuni;

BEGIN

   DELETE FROM TMP_IMP_MULTAS WHERE USUARIO=USER;
   
   IF (xSENTENCIA IS NOT NULL) THEN
   	vSENTENCIA:=xSENTENCIA;
   ELSE

   	vSENTENCIA:= 'SELECT * FROM MULTAS WHERE MUNICIPIO=:xMUNI';

   	IF (RTRIM(xESTADO)='TD') THEN
			vESTADOS:= ' AND ESTADO_ACTUAL IN (''A1'',''T1'',''R1'')';
	   
   	ELSIF (RTRIM(xESTADO)='D?') THEN
			vESTADOS:= ' AND ESTADO_ACTUAL IN (''D2'',''D1'')';
		
   	ELSIF (RTRIM(xESTADO)='F?') THEN
			vESTADOS:= ' AND ESTADO_ACTUAL IN (''F2'',''F1'')';
	   
   	ELSIF (RTRIM(xESTADO)='TS') THEN
			vESTADOS:= ' AND ESTADO_ACTUAL IN (''A2'',''T2'',''R2'')';
	   
   	ELSIF (TRIM(xEXPEDesde) IS NOT NULL AND TRIM(xEXPEHasta) IS NOT NULL AND xESTADO IS NOT NULL) THEN
   	
   		vESTADOS:=' AND ESTADO_ACTUAL='''||xESTADO||'''';
		vESTADOS:=vESTADOS||' AND EXPEDIENTE BETWEEN '''||TRIM(xEXPEDesde)||''' AND '''||TRIM(xEXPEHasta)||''''; 
	   			  
   	ELSIF (TRIM(xEXPEDesde) IS NOT NULL AND TRIM(xEXPEHasta) IS NOT NULL) THEN
			vESTADOS:= ' AND ESTADO_ACTUAL IN (''P2'',''2N'',''P1'',''1N'')'||
	   			     ' AND EXPEDIENTE BETWEEN '''||TRIM(xEXPEDesde)||''' AND '''||TRIM(xEXPEHasta)||'''';
	   			  
   	ELSE 
			vESTADOS:= ' AND ESTADO_ACTUAL='''||xESTADO||'''';
   	   
   	END IF;

   	IF (TRIM(xESTADO) IS NOT NULL) THEN
   	   vSENTENCIA:= vSENTENCIA||vESTADOS;
   	END IF;

   	IF (TRIM(xPASADO) IS NOT NULL) THEN
   	   vSENTENCIA:= vSENTENCIA||' AND PASADO <> '''||xPASADO||'''';
   	END IF;

   	IF (TRIM(xMATRICULA) IS NOT NULL) THEN
   	   vSENTENCIA:= vSENTENCIA||' AND MATRICULA LIKE '''||TRIM(xMATRICULA)||'%''';
   	END IF;

   	IF (TRIM(xNUMERO) IS NOT NULL) THEN
   	   vSENTENCIA:= vSENTENCIA||' AND NUMERO LIKE '''||TRIM(xNUMERO)||'%''';
   	END IF;

   	IF (TRIM(xLETRA) IS NOT NULL) THEN
   	   vSENTENCIA:= vSENTENCIA||' AND LETRA LIKE '''||TRIM(xLETRA)||'%''';
   	END IF;

   	IF (xAGENTE<>0) THEN
   	   vSENTENCIA:= vSENTENCIA||' AND AGENTE='||xAGENTE;
   	END IF;

   	IF (xARTICULO<>0) THEN
   	   vSENTENCIA:= vSENTENCIA||' AND ID_ARTICULO='||xARTICULO;
   	END IF;

   	IF (TRIM(xNOMBRE) IS NOT NULL) THEN
   	   vSENTENCIA:= vSENTENCIA||' AND NOMBRE_CONDUCTOR LIKE '''||TRIM(xNOMBRE)||'%''';
   	END IF;

   	IF (xGRUPO<>0) THEN
   	   vSENTENCIA:= vSENTENCIA||' AND GRUPO='||xGRUPO;
   	END IF;

   	IF (TRIM(xFDESDE) IS NOT NULL AND TRIM(xFHASTA) IS NOT NULL) THEN
   
      	IF (TRIM(xESTADO) IS NULL) and (TRIM(xPASADO) IS NULL) and (TRIM(xMATRICULA) IS NULL) and
	  	 		(TRIM(xNUMERO) IS NULL) and (TRIM(xLETRA) IS NULL) and (xAGENTE=0) and (xARTICULO=0) and
		 		(TRIM(xNOMBRE) IS NULL) and (xGRUPO=0) THEN
    	  		vSENTENCIA:= vSENTENCIA||' AND TRUNC(FECHA_BOLETIN,''DD'') BETWEEN TRUNC(TO_DATE('''||xFDESDE||'''),''DD'') AND TRUNC(TO_DATE('''||xFHASTA||'''),''DD'')';
	  		ELSE
    	  		vSENTENCIA:= vSENTENCIA||' AND TRUNC(FECHA_ESTADO_ACTUAL,''DD'') BETWEEN TRUNC(TO_DATE('''||xFDESDE||'''),''DD'') AND TRUNC(TO_DATE('''||xFHASTA||'''),''DD'')';
	  		END IF;
	  
   	END IF;
   END IF;


	--Asignar consulta a cursor, abrirlo y recorrerlo
	OPEN vCURSOR FOR vSENTENCIA USING xMUNI;
	LOOP
		FETCH vCURSOR INTO vMULTAS;
		EXIT WHEN vCURSOR%NOTFOUND;

		--Encontrar y seleccionar campos para tabla temporal
		IF vMULTAS.GRAVEDAD='L' THEN
		   vGRAVEDAD:='LEVE';
		ELSIF vMULTAS.GRAVEDAD='G' THEN
		   vGRAVEDAD:='GRAVE';
		ELSE
		   vGRAVEDAD:='MUY GRAVE';
		END IF;

		
		BEGIN
			SELECT DESCRIPCION,ACRONIMO INTO vDESC_LEY,vDESC_LEY_ACRO 
			FROM LEYES_SANCIONES
			WHERE ID=vMULTAS.LEY;
			EXCEPTION
				WHEN NO_DATA_FOUND THEN
					vDESC_LEY:='';
		END;	
		
		SELECT DESCRIPCION INTO vDESC_TIPO_DENUNCIA 
		FROM TIPOS_DENUNCIAS
		WHERE ID=vMULTAS.TIPO_DENUNCIA;
		
	 	vFECHA_BOLETIN:= TO_CHAR(vMULTAS.FECHA_BOLETIN,'dd/mm/yyyy hh24:mi');

    	IF (TRIM(xCARGO) IS NOT NULL) THEN
            vCARGO:= xCARGO;
    	ELSE vCARGO:=vMULTAS.NUMERO_DE_CARGO;
    	END IF;

		SELECT CONCEPTO,DESCRIPCION INTO vCONCEPTO,vDESC_CONCEPTO
	  	  FROM CONCEPTOS
	 	 WHERE CONCEPTO IN (SELECT CONCEPTO FROM PROGRAMAS WHERE PROGRAMA='MULTAS');

    	SELECT NOMBRE INTO vNOMBRE_AGENTE
	  	  FROM AGENTES
	 	 WHERE MUNICIPIO=vMULTAS.MUNICIPIO AND AGENTE=vMULTAS.AGENTE;

		SELECT ARTICULO,APARTADO,OPCION,SANCION,IMPORTE,DESCUENTO
	  	  INTO vARTICULO_SANCION,vAPARTADO_SANCION,vOPCION_SANCION,vDESC_SANCION,vIMPORTE_SANCION,vDESCUENTO_SANCION
	      FROM SANCION
	 	 WHERE MUNICIPIO=vMULTAS.MUNICIPIO AND ID=vMULTAS.ID_ARTICULO;

		SELECT DESCRIPCION INTO vDESC_ESTADO_ACTUAL
	  	  FROM TIPOS_ESTADO
	 	 WHERE ESTADO=vMULTAS.ESTADO_ACTUAL;

		SELECT MOTIVO,NOTIFICADO
	      INTO vMOTIVO_ENTREGA,vNOTIFICADO_ENTREGA
	  	  FROM ENTREGA_DENUNCIA
	 	 WHERE MUNICIPIO=vMULTAS.MUNICIPIO AND CODIGO=vMULTAS.COD_ENTREGA;

		IF ((vMULTAS.ESTADO_ACTUAL='A1') OR
		    (vMULTAS.ESTADO_ACTUAL='R1') OR
			(vMULTAS.ESTADO_ACTUAL='T1') OR
			(vMULTAS.ESTADO_ACTUAL='B1')) THEN 
			vFECHA_1ACUSE:= TRUNC(vMULTAS.FECHA_ESTADO_ACTUAL,'dd');
		ELSE	
		BEGIN
			SELECT MAX(TRUNC(FECHA_ESTADO,'DD'))
		  	  INTO vFECHA_1ACUSE
			  FROM ESTADO
	 	     WHERE MUNICIPIO=vMULTAS.MUNICIPIO AND EXPEDIENTE=vMULTAS.EXPEDIENTE
			   AND ESTADO IN ('A1','T1','R1','B1');
		EXCEPTION
			WHEN NO_DATA_FOUND THEN
 			     vFECHA_1ACUSE:=NULL;
		END;
		END IF;

		IF (vMULTAS.ESTADO_ACTUAL='1N') THEN 
			vFECHA_1NOTIFICACION:= TRUNC(vMULTAS.FECHA_ESTADO_ACTUAL,'dd');
		ELSE	
		BEGIN
			SELECT MAX(TRUNC(FECHA_ESTADO,'DD'))
		  	  INTO vFECHA_1NOTIFICACION
			  FROM ESTADO
	 	     WHERE MUNICIPIO=vMULTAS.MUNICIPIO AND EXPEDIENTE=vMULTAS.EXPEDIENTE
			   AND ESTADO IN ('1N');
		EXCEPTION
			WHEN NO_DATA_FOUND THEN
				 vFECHA_1NOTIFICACION:= NULL;
		END;
		END IF;

		IF ((vMULTAS.ESTADO_ACTUAL='A2') OR
		    (vMULTAS.ESTADO_ACTUAL='R2') OR
			(vMULTAS.ESTADO_ACTUAL='T2') OR
			(vMULTAS.ESTADO_ACTUAL='B2')) THEN 
			vFECHA_2ACUSE:= TRUNC(vMULTAS.FECHA_ESTADO_ACTUAL,'dd');
		ELSE	
		BEGIN
			SELECT MAX(TRUNC(FECHA_ESTADO,'DD'))
		  	  INTO vFECHA_2ACUSE
			  FROM ESTADO
	 	     WHERE MUNICIPIO=vMULTAS.MUNICIPIO AND EXPEDIENTE=vMULTAS.EXPEDIENTE
			   AND ESTADO IN ('A2','T2','R2','B2');
		EXCEPTION
			WHEN NO_DATA_FOUND THEN
 			     vFECHA_2ACUSE:=NULL;
		END;
		END IF;

		IF (vMULTAS.ESTADO_ACTUAL='2N') THEN 
			vFECHA_2NOTIFICACION:= TRUNC(vMULTAS.FECHA_ESTADO_ACTUAL,'dd');
		ELSE	
		BEGIN
			SELECT MAX(TRUNC(FECHA_ESTADO,'DD'))
		  	  INTO vFECHA_2NOTIFICACION
			  FROM ESTADO
	 	     WHERE MUNICIPIO=vMULTAS.MUNICIPIO AND EXPEDIENTE=vMULTAS.EXPEDIENTE
			   AND ESTADO IN ('2N');
		EXCEPTION
			WHEN NO_DATA_FOUND THEN
				 vFECHA_2NOTIFICACION:= NULL;
		END;
		END IF;

		BEGIN
			 SELECT MOTIVO,FECHA_ESTADO
			   INTO vTEXTO_1ALEGACION,vFECHA_1ALEGACION FROM
			 (SELECT MOTIVO,TRUNC(FECHA_ESTADO,'dd') AS FECHA_ESTADO
			    FROM DOCMULTA D, ESTADO E
			   WHERE E.ID=D.ID_ESTADO AND E.EXPEDIENTE=vMULTAS.EXPEDIENTE AND ESTADO='AL'
			   ORDER BY TRUNC(FECHA_ESTADO,'dd') ASC)
			 WHERE ROWNUM=1;
		EXCEPTION
			WHEN NO_DATA_FOUND THEN
			 	 vTEXTO_1ALEGACION:= NULL;
			 	 vFECHA_1ALEGACION:= NULL;
		END;

		BEGIN
			 SELECT MOTIVO,FECHA_ESTADO
			   INTO vTEXTO_2ALEGACION,vFECHA_2ALEGACION FROM
			 (SELECT MOTIVO,TRUNC(FECHA_ESTADO,'dd') AS FECHA_ESTADO
			    FROM DOCMULTA D, ESTADO E
			   WHERE E.ID=D.ID_ESTADO AND E.EXPEDIENTE=vMULTAS.EXPEDIENTE AND ESTADO='AL'
			   ORDER BY TRUNC(FECHA_ESTADO,'dd') DESC)
			 WHERE ROWNUM=1;
		EXCEPTION
			WHEN NO_DATA_FOUND THEN
			 	 vTEXTO_2ALEGACION:= NULL;
			 	 vFECHA_2ALEGACION:= NULL;
		END;

		BEGIN
			 SELECT MOTIVO,TRUNC(FECHA_ESTADO,'dd')
			   INTO vTEXTO_1INFORME,vFECHA_1INFORME
			   FROM DOCMULTA D, ESTADO E
			  WHERE E.ID=D.ID_ESTADO AND EXPEDIENTE=vMULTAS.EXPEDIENTE AND ESTADO='DA'
			  AND E.ID IN (SELECT MAX(ID) FROM ESTADO WHERE EXPEDIENTE=vMULTAS.EXPEDIENTE AND ESTADO='DA');
		EXCEPTION
			WHEN NO_DATA_FOUND THEN
			 	 vTEXTO_1INFORME:= NULL;
			 	 vFECHA_1INFORME:= NULL;
		END;

		BEGIN
			 SELECT MOTIVO,TRUNC(FECHA_ESTADO,'dd')
			   INTO vTEXTO_2INFORME,vFECHA_2INFORME
			   FROM DOCMULTA D, ESTADO E
			  WHERE E.ID=D.ID_ESTADO AND EXPEDIENTE=vMULTAS.EXPEDIENTE AND ESTADO='DS'
			  AND E.ID IN (SELECT MAX(ID) FROM ESTADO WHERE EXPEDIENTE=vMULTAS.EXPEDIENTE AND ESTADO='DS');
		EXCEPTION
			WHEN NO_DATA_FOUND THEN
			 	 vTEXTO_2INFORME:= NULL;
			 	 vFECHA_2INFORME:= NULL;
		END;

		GetDomicilioFiscal(vMULTAS.DNI_CONDUCTOR,NULL,vDOMIFISCAL_CONDUC,vPOBLACION,vPROVINCIA,vCODPOSTAL);
		vDOMIFISCAL_CONDUC:= vDOMIFISCAL_CONDUC||' '||vCODPOSTAL||' '||vPOBLACION;
		if (vPROVINCIA is not null) then
  	   	    vDOMIFISCAL_CONDUC:= vDOMIFISCAL_CONDUC||' ('||vPROVINCIA||')';
		end if;

		GetDomicilioFiscal(vMULTAS.DNI_PROPIETARIO,NULL,vDOMIFISCAL_PROPIE,vPOBLACION,vPROVINCIA,vCODPOSTAL);
	    vDOMIFISCAL_PROPIE:= vDOMIFISCAL_PROPIE||' '||vCODPOSTAL||' '||vPOBLACION;
		if (vPROVINCIA is not null) then
  	   	    vDOMIFISCAL_PROPIE:= vDOMIFISCAL_PROPIE||' ('||vPROVINCIA||')';
		end if;

		--domicilio fiscal en funcion de si tiene un domicilio alternativo o no.
		--si hay tutor el domicilio de la notificación será el de éste, no el del conductor
		IF (vMULTAS.DNI_TUTOR is null) then
	   	    vDNI_NOTI:=vMULTAS.DNI_CONDUCTOR;
			vNOMBRE_NOTI:=vMULTAS.NOMBRE_CONDUCTOR;
		ELSE
	   		vDNI_NOTI:=vMULTAS.DNI_TUTOR;
	   		vNOMBRE_NOTI:=vMULTAS.NOMBRE_TUTOR;
		END IF;
		
		--Datos para el envio de la notificacion
		GetDomicilioFiscal(vDNI_NOTI,vMULTAS.IDDOMIALTER,vDIRE_NOTI,vPOBLACION,vPROVINCIA,vCODPOSTAL);


		--pendiente de primera notificacion
		if (xEstado IN ('P1','1N','A1','B1','R1'))  then
		    
			vOtroImporte:= vMultas.Importe - round(vMultas.Importe*(vDESCUENTO_SANCION/100),2);
			vDesde1:=vMultas.FECHA_ESTADO_ACTUAL;					   
			vHasta1:=vMultas.FVENCIMIENTO;

		--pendiente de segunda notificacion			
		elsif (xEstado IN ('P2','2N','A2','B2','R2')) then	
		
			vOtroImporte:= vMultas.Importe;
			vDesde1:=vMultas.FECHA_ESTADO_ACTUAL;					   
			vHasta1:=vMultas.FVENCIMIENTO;
			
		end if;

		
		xEnMunicipio:=False;
		
		for vCodigosPostales in cCodigosPostales loop
		
			if vCodigosPostales.Codigo_Postal = vCODPOSTAL then			
				xEnMunicipio:=True;			
			end if;
				
		end loop;
		
		SELECT DENUNCIA,SANCION INTO vDENUNCIA,vSANCION
   	FROM DATOSPER WHERE MUNICIPIO=vMULTAS.MUNICIPIO;
		
		if ( (xQueImprimo='T') or (xQueImprimo='M' and xEnMunicipio) or (xQueImprimo='F' and not xEnMunicipio) ) then

	  		-- Insertar registro
	 		INSERT INTO TMP_IMP_MULTAS (
	    	MUNICIPIO,CONCEPTO,DESCRIPCION,
			EXPEDIENTE,BOLETIN,FECHA_BOLETIN,YEAR,MES,
			MATRICULA,NUMERO,LETRA,MARCA,TIPO,
			AGENTE,NOMBRE_AGENTE,
			ID_ARTICULO,ARTICULO_SANCION,APARTADO_SANCION,OPCION_SANCION,DESC_SANCION,IMPORTE_SANCION,DESCUENTO_SANCION,
			COD_ENTREGA,MOTIVO_ENTREGA,TIPO_DENUNCIA,NOTIFICADO_ENTREGA,LUGAR,HECHO,
			DNI_CONDUCTOR,NOMBRE_CONDUCTOR,DOMIF_CONDUCTOR,
			DNI_PROPIETARIO,NOMBRE_PROPIETARIO,DOMIF_PROPIETARIO,
			DNI_TUTOR,NOMBRE_TUTOR,IDDOMIALTER,IMPORTE,
			ESTADO_ACTUAL,DESC_ESTADO_ACTUAL,FECHA_ESTADO_ACTUAL,ULTIMO_ESTADO,F_ULTIMO_ESTADO,
			GRAVEDAD,LEY,DESC_LEY,DESC_LEY_ACRO,GRUPO,
			NUMERO_DE_CARGO,F_CARGO,PASADO,IDREGISTRO,IDVALOR,FIN_PE_VOL,
			EMISOR,TRIBUTO,EJER_C60,REFERENCIA,IMP_CADENA,DISCRI_PERIODO,DIGITO_YEAR,F_JULIANA,DIGITO_C60_MODALIDAD2,
			FVENCIMIENTO,
			FECHA_1NOTIFICACION,FECHA_2NOTIFICACION,FECHA_1ACUSE,FECHA_2ACUSE,
			FECHA_1ALEGACION,TEXTO_1ALEGACION,FECHA_1INFORME,TEXTO_1INFORME,
			FECHA_2ALEGACION,TEXTO_2ALEGACION,FECHA_2INFORME,TEXTO_2INFORME,
			DENUNCIA,SANCION,DNI_NOTI,NOMBRE_NOTI,DIRE_NOTI,CODPOSTAL_NOTI,POBLACION_NOTI,PROVINCIA_NOTI,
			OtroImporte,Desde1,Hasta1,COD_BARRAS_MOD2,CODBARRAS_DENUNCIA,CODBARRAS_SANCION)

			VALUES (
	    	vMULTAS.MUNICIPIO,vCONCEPTO,vDESC_CONCEPTO,
			vMULTAS.EXPEDIENTE,vMULTAS.BOLETIN,vFECHA_BOLETIN,vMULTAS.YEAR,vMULTAS.MES,
			vMULTAS.MATRICULA,vMULTAS.NUMERO,vMULTAS.LETRA,vMULTAS.MARCA,vMULTAS.TIPO,
			vMULTAS.AGENTE,vNOMBRE_AGENTE,
			vMULTAS.ID_ARTICULO,vARTICULO_SANCION,vAPARTADO_SANCION,vOPCION_SANCION,vDESC_SANCION,vIMPORTE_SANCION,vDESCUENTO_SANCION,
			vMULTAS.COD_ENTREGA,vMOTIVO_ENTREGA,vDESC_TIPO_DENUNCIA,vNOTIFICADO_ENTREGA,vMULTAS.LUGAR,vMULTAS.HECHO,
	    	vMULTAS.DNI_CONDUCTOR,vMULTAS.NOMBRE_CONDUCTOR,vDOMIFISCAL_CONDUC,
			vMULTAS.DNI_PROPIETARIO,vMULTAS.NOMBRE_PROPIETARIO,vDOMIFISCAL_PROPIE,
			vMULTAS.DNI_TUTOR,vMULTAS.NOMBRE_TUTOR,vMULTAS.IDDOMIALTER,vMULTAS.IMPORTE,
			vMULTAS.ESTADO_ACTUAL,vDESC_ESTADO_ACTUAL,vMULTAS.FECHA_ESTADO_ACTUAL,vMULTAS.ULTIMO_ESTADO,vMULTAS.F_ULTIMO_ESTADO,
			vGRAVEDAD,vMULTAS.LEY,vDESC_LEY,vDESC_LEY_ACRO,vMULTAS.GRUPO,
			vCARGO,vMULTAS.F_CARGO,vMULTAS.PASADO,vMULTAS.IDREGISTRO,vMULTAS.IDVALOR,vMULTAS.FIN_PE_VOL,
			vMULTAS.EMISOR,vMULTAS.TRIBUTO,vMULTAS.EJER_C60,vMULTAS.REFERENCIA,lpad(to_number(vMULTAS.IMP_CADENA),12,'0'),
			vMULTAS.DISCRI_PERIODO,vMULTAS.DIGITO_YEAR,vMULTAS.F_JULIANA,vMULTAS.DIGITO_C60_MODALIDAD2,vMULTAS.FVENCIMIENTO,
			vFECHA_1NOTIFICACION,vFECHA_2NOTIFICACION,vFECHA_1ACUSE,vFECHA_2ACUSE,
			vFECHA_1ALEGACION,vTEXTO_1ALEGACION,vFECHA_1INFORME,vTEXTO_1INFORME,
			vFECHA_2ALEGACION,vTEXTO_2ALEGACION,vFECHA_2INFORME,vTEXTO_2INFORME,
			vDENUNCIA,vSANCION,vDNI_NOTI,vNOMBRE_NOTI,vDIRE_NOTI,vCODPOSTAL,vPOBLACION,vPROVINCIA,
			vOtroImporte,vDesde1,vHasta1,
			'90521'||vMULTAS.EMISOR||vMULTAS.REFERENCIA||
			vMULTAS.DIGITO_C60_MODALIDAD2||vMULTAS.DISCRI_PERIODO||
			vMULTAS.TRIBUTO||vMULTAS.EJER_C60||
			vMULTAS.DIGITO_YEAR||vMULTAS.F_JULIANA||
			LPAD(vOtroImporte*100,8,'0')||'0',
			vMULTAS.CODBARRAS_DENUNCIA,vMULTAS.CODBARRAS_SANCION);
			
		end if;
		
	END LOOP;
	CLOSE vCURSOR;

END;
/




/******************************************************************************************
Acción: Incrementa secuencia de la tabla Historico_MultasNIFs
AUTOR: 22/12/2003 Gloria Maria Calle Hernandez
******************************************************************************************/
CREATE OR REPLACE TRIGGER T_INS_HISTORICO_MultasNIFs
BEFORE INSERT ON HISTORICO_MultasNIFs
FOR EACH ROW
BEGIN
  SELECT GENHISTOMULTAS.NEXTVAL INTO :NEW.ID FROM DUAL;
END;
/



/******************************************************************************************
Acción: Inserta en el Historico de Multas cuando DNI del propietario es cambiado
AUTOR: Realizado el 22/12/2003 Gloria Maria Calle Hernandez. Copiado 18/02/2004
******************************************************************************************/
CREATE OR REPLACE TRIGGER T_UPDMULTAS_NIFs
BEFORE UPDATE OF DNI_PROPIETARIO ON MULTAS
FOR EACH ROW
BEGIN

   IF ((:OLD.DNI_PROPIETARIO IS NULL AND :NEW.DNI_PROPIETARIO IS NOT NULL) OR 
      (:OLD.DNI_PROPIETARIO<>:NEW.DNI_PROPIETARIO)) THEN
		INSERT INTO HISTORICO_MultasNIFs (ABONADO,USUARIO,FECHA_CAMBIO,NIF,COND_PROP) 
		VALUES (:OLD.ID,USER,SYSDATE,:OLD.DNI_PROPIETARIO,'P');		
   END IF;

END;
/

/******************************************************************************************
Acción: al modificar el nif del conductor se ha de modificar también el dni 
en la tabla de valores, siempre que el valor esté aún en voluntaria.
AUTOR: 24/03/2004 Mª del Carmen Junco Gómez
MODIFICADO: 04/10/2005 Gloria MAria Calle Hernandez. Se permite poner a nulo tb el valor, aunque 
			inicialmente no sea nulo, para permitir la correccion de errores de usuario.
******************************************************************************************/
CREATE OR REPLACE TRIGGER T_UPDMULTAS_CONDUCTOR
BEFORE UPDATE OF DNI_CONDUCTOR ON MULTAS
FOR EACH ROW
DECLARE
	vPaseAutomatico char(1);
BEGIN

   IF ((:OLD.DNI_CONDUCTOR IS NULL AND :NEW.DNI_CONDUCTOR IS NOT NULL) OR 
      (:OLD.DNI_CONDUCTOR<>:NEW.DNI_CONDUCTOR)) THEN
		INSERT INTO HISTORICO_MultasNIFs (ABONADO,USUARIO,FECHA_CAMBIO,NIF,COND_PROP) 
		VALUES (:OLD.ID,USER,SYSDATE,:OLD.DNI_CONDUCTOR,'C');
   END IF;
   
   SELECT PASE_AUTOMATICO_MULTAS into vPaseAutomatico FROM DATOSPERR;
   
   IF vPaseAutomatico='S' THEN      	
	  UPDATE VALORES SET NIF=:NEW.DNI_CONDUCTOR,NOMBRE=:NEW.NOMBRE_CONDUCTOR
   	   WHERE ID=:NEW.IDVALOR AND VOL_EJE='V';
   END IF;

END;
/

/******************************************************************************************
Acción: al modificar el nif del tutor se ha de modificar también el dni 
en la tabla de valores, siempre que el valor esté aún en voluntaria.
AUTOR: 24/03/2004 Mª del Carmen Junco Gómez
MODIFICADO: 04/10/2005 Gloria MAria Calle Hernandez. Se permite poner a nulo tb el valor, aunque 
			inicialmente no sea nulo, para permitir la correccion de errores de usuario.
******************************************************************************************/
CREATE OR REPLACE TRIGGER T_UPDMULTAS_TUTOR
BEFORE UPDATE OF DNI_TUTOR ON MULTAS
FOR EACH ROW
DECLARE
	vPaseAutomatico char(1);
BEGIN
   
   IF ((:OLD.DNI_TUTOR IS NULL AND :NEW.DNI_TUTOR IS NOT NULL) OR 
      (:OLD.DNI_TUTOR<>:NEW.DNI_TUTOR)) THEN
		INSERT INTO HISTORICO_MultasNIFs (ABONADO,USUARIO,FECHA_CAMBIO,NIF,COND_PROP) 
		VALUES (:OLD.ID,USER,SYSDATE,:OLD.DNI_TUTOR,'T');
   END IF;
   
   SELECT PASE_AUTOMATICO_MULTAS into vPaseAutomatico FROM DATOSPERR;
   
   IF vPaseAutomatico='S' THEN   
 	  UPDATE VALORES SET NIF=:NEW.DNI_TUTOR,NOMBRE=:NEW.NOMBRE_TUTOR WHERE ID=:NEW.IDVALOR AND VOL_EJE='V';   	   	
   END IF;

END;
/


/*******************************************************************************************
Autor: 12/04/2005 Mª del Carmen Junco Gómez.
Acción: Procedimiento que inserta una nueva tupla en e log de impresión de documentos asociados
		  a un expediente para el programa de Multas.
*******************************************************************************************/
CREATE OR REPLACE PROCEDURE INSERT_LOGDOCU_MULTAS(
			xMUNICIPIO		IN	CHAR,
			xDOCUMENTO		IN	VARCHAR2,
			xEXPEDIENTE		IN	CHAR)
AS
BEGIN
	INSERT INTO LOG_DOCUMENTOS (MUNICIPIO,PROGRAMA,DOCUMENTO,EXPEDIENTE)
	VALUES (xMUNICIPIO,'MULTAS',xDOCUMENTO,xEXPEDIENTE);
END;
/
		  
		  

/********************************************************************/
COMMIT;
/********************************************************************/
