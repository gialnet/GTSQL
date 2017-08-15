CREATE OR REPLACE PROCEDURE ACTUALIZACLAVEIBI AS
	xREFERENCIA CHAR(20);
	xDESCRIPCION VARCHAR2(100);
	xMAXID INTEGER;
	-- cursor para borrar registros duplicados (misma referencia y nif)
	CURSOR C2 IS SELECT NIF,CLAVE_TRIBUTO,COUNT(*) FROM TRIBUTOSCONTRI
				 WHERE PROGRAMA='IBI'
				 GROUP BY NIF,CLAVE_TRIBUTO
				 HAVING COUNT(*)>1;
	CURSOR C1 IS SELECT * FROM TRIBUTOSCONTRI
	             WHERE PROGRAMA='IBI'
			     FOR UPDATE OF CLAVE_TRIBUTO,DESCRIPCION;
BEGIN

   FOR v2 IN C2
   LOOP
      SELECT MAX(ID_CONCEPTO) INTO xMAXID FROM TRIBUTOSCONTRI
      WHERE PROGRAMA='IBI' AND NIF=v2.NIF AND CLAVE_TRIBUTO=v2.CLAVE_TRIBUTO;
      DELETE FROM TRIBUTOSCONTRI WHERE PROGRAMA='IBI' AND NIF=v2.NIF AND
      CLAVE_TRIBUTO=v2.CLAVE_TRIBUTO AND ID_CONCEPTO<>xMAXID;
   END LOOP;


   FOR v1 IN C1
   LOOP
	  xREFERENCIA:=NULL;
	  begin
	     SELECT REF_CATASTRAL||NUMERO_SECUENCIAL||PRIMER_CARACTER_CONTROL||
		        SEGUN_CARACTER_CONTROL,
		        SUBSTR('Ref.Cat: '||REF_CATASTRAL||NUMERO_SECUENCIAL||
		        PRIMER_CARACTER_CONTROL||SEGUN_CARACTER_CONTROL||'-V.Cat: '||
		        VALOR_CATASTRAL||'-D.Trib: '||RTRIM(TIPO_VIA)||' '||
		        RTRIM(NOMBRE_VIA)||' '||PRIMER_NUMERO||' '||PRIMERA_LETRA||' '||
		        ESCALERA||' '||PLANTA||' '||PUERTA,1,100) INTO xREFERENCIA,xDESCRIPCION
	     FROM IBI WHERE ID=v1.ID_CONCEPTO;
	     Exception
	        When no_data_found then
		       xREFERENCIA:=v1.CLAVE_TRIBUTO;
		       xDESCRIPCION:=v1.DESCRIPCION;
	  end;

	  UPDATE TRIBUTOSCONTRI SET CLAVE_TRIBUTO=xREFERENCIA,DESCRIPCION=xDESCRIPCION
	  WHERE CURRENT OF C1;
   END LOOP;
END;
/

EXECUTE ACTUALIZACLAVEIBI;
DROP PROCEDURE ACTUALIZACLAVEIBI;


/********************************************************************************/
-- quitar % de bonificación en los recibos de ibi que ya no están bonificados

CREATE OR REPLACE PROCEDURE ARREGLABONI AS
   CURSOR C1 IS SELECT * FROM IBI WHERE MUNICIPIO='022' AND YEAR='2002' AND BONIFICACION>0;
   xBONIFICACION FLOAT;
BEGIN
   FOR v1 IN C1
   LOOP
      IF ('2002' > v1.YEAR_BONI or v1.YEAR_BONI is null) THEN
	   xBONIFICACION:=0;
      ELSE
	   xBONIFICACION:=v1.BONIFICACION;
	END IF;

	UPDATE RECIBOS_IBI SET BONIFICACION=xBONIFICACION
	WHERE YEAR='2002' AND ABONADO=v1.ID;
   END LOOP;
END;
/








INSERT INTO PUNTEO(PADRON,YEAR,PERIODO,RECIBO,TIPO_DE_OBJETO,AYTO,YEAR_CONTRAIDO,
COTITULARES,NIF,NOMBRE,CUOTA_INICIAL,PRINCIPAL,RECARGO_O_E,RECARGOS_L,SANCIONES,
RECARGO,COSTAS,DEMORA,ENTREGAS_A_CUENTA,IMPORTE1,IMPORTE2,IMPORTE3,IMPORTE4,IMPORTE5,
IMPORTE6,IMPORTE7,VOL_EJE,N_CARGO,NOTIFICADO,DOM_TRIBUTARIO,OBJETO_TRIBUTARIO,
TIPO_DE_TRIBUTO)
SELECT '000010',YEAR,PERIODO,RECIBO,'R',AYTO,YEAR,'N',NIF,NOMBRE,CUOTA_INICIAL,PRINCIPAL,
0,0,0,0,0,0,0,0,0,0,0,0,0,0,'E',N_CARGO,'N',DOM_TRIBUTARIO,
OBJETO_TRIBUTARIO,'IM' FROM IAE7 ORDER BY N_CARGO,RECIBO


SELECT 'UPDATE IAE7_3 SET NIF='||CHR(39)||NIF||CHR(39)||' WHERE NOMBRE='||
CHR(39)||NOMBRE||CHR(39)||';' FROM CONTRIBUYENTES WHERE VALIDADO<>'F' AND NOMBRE IN (
)
ORDER BY NOMBRE

SELECT CHR(39)||NOMBRE||CHR(39)||',' FROM IAE7_3 WHERE NIF IS NULL
AND (NOMBRE LIKE 'D%' OR NOMBRE LIKE 'E%' OR NOMBRE LIKE 'F%')
ORDER BY NOMBRE

SELECT 'INSERT INTO NADA (NIF,NOMBRE) VALUES ('||CHR(39)||TRIM(NIF)||CHR(39)||','||
CHR(39)||TRIM(NOMBRE)||CHR(39)||');' FROM CONTRIBUYENTES WHERE
SUBSTR(NOMBRE,1,20) IN (
)
ORDER BY NOMBRE


*********************************************************************************************

CREATE OR REPLACE PROCEDURE PONERFECHAFIN
AS
   xF_FIN_PE_VOL DATE;
   DIA 	     CHAR(10);
   xEMISOR       CHAR(6);
   xTRIBUTO      CHAR(3);
   xDIG_C60_M2   CHAR(2);
   xREFERENCIA   CHAR(10);
   xIMPCADENA    CHAR(12);

   CURSOR C1 IS SELECT * FROM LIQUIDACIONES WHERE GRUPO=181320 AND F_FIN_PE_VOL IS NULL;

BEGIN
   FOR v1 IN C1
   LOOP
      xF_FIN_PE_VOL:=v1.F_LIQUIDACION+45;
      DIA:=TO_CHAR(xF_Fin_Pe_Vol,'day');
      IF (DIA='SÁBADO') then
         xF_Fin_Pe_Vol:=xF_Fin_Pe_Vol+2;
      ELSIF (dia='DOMINGO') then
         xF_Fin_Pe_Vol:=xF_Fin_Pe_Vol+1;
	END IF;

	BEGIN
	  select EMISORA,CONCEPTO_BANCO into xEMISOR,xTRIBUTO from RELA_APLI_BANCOS
		where AYTO=v1.MUNICIPIO and CONCEPTO=v1.CONCEPTO;
	EXCEPTION
		when no_data_found then
		BEGIN
			xEMISOR:='000000';
			xTRIBUTO:='000';
		END;
	END;

	--calcular los digitos de control del cuaderno 60 modalidad 2
	CALCULA_DC_MODALIDAD2_60(v1.IMPORTE, v1.ID, xTRIBUTO, SUBSTR(v1.YEAR,3,2), '1',
				to_char(xF_FIN_PE_VOL,'y'), to_char(xF_FIN_PE_VOL,'ddd'),
				xEMISOR, xDIG_C60_M2);

	xDIG_C60_M2:=SUBSTR(xDIG_C60_M2,1,2);

	--CONVIERTE NºABONADO EN CARACTER Y RELLENO DE CEROS
	GETREFERENCIA(v1.ID, xREFERENCIA);

	--CONVIERTE EL IMPORTE RELLENO DE CEROS
	IMPORTEENCADENA(v1.IMPORTE, xIMPCADENA);

	UPDATE LIQUIDACIONES SET F_FIN_PE_VOL=xF_FIN_PE_VOL,
					 EMISOR=xEMISOR,
					 TRIBUTO=xTRIBUTO,
					 EJER_C60=SUBSTR(v1.YEAR,3,2),
					 REFERENCIA=xREFERENCIA,
					 IMP_CADENA=xIMPCADENA,
					 DISCRI_PERIODO='1',
					 DIGITO_YEAR=to_char(xF_FIN_PE_VOL,'y'),
					 F_JULIANA=to_char(xF_FIN_PE_VOL,'ddd'),
					 DIGITO_C60_MODALIDAD2=xDIG_C60_M2
	WHERE ID=v1.ID;

	UPDATE VALORES SET FIN_PE_VOL=xF_FIN_PE_VOL
	WHERE ID=v1.IDVALOR;

   END LOOP;

END;
/


/************************************************************************************/

CREATE OR REPLACE PROCEDURE PASAR_RECARGO_PROVINCIAL AS
   xVALOR INTEGER;
   xPrincipalValor FLOAT DEFAULT 0;
   xRecargoOE	float default 0;
   CURSOR C1 IS SELECT MUNICIPIO,YEAR,PERIODO,RECIBO,RECARGO FROM RECIBOS_IAE;
   CURSOR C2 IS SELECT PRINCIPAL,ID FROM INGRESOS WHERE VALOR=xVALOR
   					   FOR UPDATE OF RECARGO_O_E;
BEGIN
   FOR v1 IN C1
   LOOP
      begin
         SELECT PRINCIPAL,ID INTO xPrincipalValor,xVALOR FROM VALORES
         WHERE AYTO=v1.MUNICIPIO AND
         	   PADRON='000022' AND
         	   YEAR=v1.YEAR AND PERIODO=v1.PERIODO AND
         	   RECIBO=v1.RECIBO;
         Exception
         	When no_data_found then
         		xValor:=0;
      end;

      IF (xVALOR>0) THEN

         UPDATE VALORES SET RECARGO_O_E=v1.RECARGO WHERE ID=xVALOR;

         FOR v2 IN C2
         LOOP

         	xRecargoOE:= round((v2.Principal*v1.RECARGO)/xPrincipalValor,2);

            UPDATE INGRESOS SET RECARGO_O_E=xRecargoOE
            WHERE CURRENT OF C2;

         END LOOP;

      END IF;

   END LOOP;
END;
/


/***************************************************************************************/

CREATE TABLE LISTADOCONSUMOS(
	ABONADO 	INTEGER,
	CONSUMO		INTEGER,
	TARIFA1		VARCHAR2(40),
	IMPORTE1	FLOAT,
	TARIFA2		VARCHAR2(40),
	IMPORTE2	FLOAT,
	TARIFA3		VARCHAR2(40),
	IMPORTE3	FLOAT,
	TARIFA4		VARCHAR2(40),
	IMPORTE4	FLOAT,
	TARIFA5		VARCHAR2(40),
	IMPORTE5	FLOAT,
	TARIFA6		VARCHAR2(40),
	IMPORTE6	FLOAT,
	TARIFA7		VARCHAR2(40),
	IMPORTE7	FLOAT,
	TARIFA8		VARCHAR2(40),
	IMPORTE8	FLOAT,
	TARIFA9		VARCHAR2(40),
	IMPORTE9	FLOAT,
	TARIFA10		VARCHAR2(40),
	IMPORTE10	FLOAT,
	TARIFA11		VARCHAR2(40),
	IMPORTE11	FLOAT,
	TARIFA12  	VARCHAR2(40),
	IMPORTE12	FLOAT,
	TOTAL		FLOAT);
	
CREATE OR REPLACE PROCEDURE ADDLISTADOCONSUMOS(
		xYEAR		CHAR,
		xPERIODO	CHAR)
AS
   xABONADO INTEGER;   
   i		INTEGER;
   xDESCRIP	VARCHAR2(40);
   
   CURSOR C1 IS SELECT ABONADO,CONSUMO,TOTAL FROM RECIBOS_AGUA 
   				WHERE YEAR=xYEAR AND PERIODO=xPERIODO;
   CURSOR C2 IS SELECT TARIFA,SUM(IMPORTE) AS IMPORTE 
   				FROM DESGLOSE_AGUAS 
   				WHERE ABONADO=xABONADO AND YEAR=xYEAR AND PERIODO=xPERIODO
				GROUP BY TARIFA;
BEGIN

	DELETE FROM LISTADOCONSUMOS;
	
	FOR v1 IN C1
	LOOP
	
		INSERT INTO LISTADOCONSUMOS(ABONADO,CONSUMO,TOTAL)
		VALUES (v1.ABONADO,v1.CONSUMO,v1.TOTAL);
	
		i:=1;
		xABONADO:=v1.ABONADO;
		FOR v2 IN C2 
		LOOP
			SELECT DESCRIPCION INTO xDESCRIP FROM TARIFAS_AGUA
			WHERE TARIFA=v2.TARIFA;
			IF i=1 THEN
			   UPDATE LISTADOCONSUMOS SET TARIFA1=xDESCRIP,IMPORTE1=v2.IMPORTE
			   WHERE ABONADO=xABONADO;
			ELSIF i=2 THEN
			   UPDATE LISTADOCONSUMOS SET TARIFA2=xDESCRIP,IMPORTE2=v2.IMPORTE
			   WHERE ABONADO=xABONADO;
			ELSIF i=3 THEN
			   UPDATE LISTADOCONSUMOS SET TARIFA3=xDESCRIP,IMPORTE3=v2.IMPORTE
			   WHERE ABONADO=xABONADO;
			ELSIF i=4 THEN
			   UPDATE LISTADOCONSUMOS SET TARIFA4=xDESCRIP,IMPORTE4=v2.IMPORTE
			   WHERE ABONADO=xABONADO;
			ELSIF i=5 THEN
			   UPDATE LISTADOCONSUMOS SET TARIFA5=xDESCRIP,IMPORTE5=v2.IMPORTE
			   WHERE ABONADO=xABONADO;
			ELSIF i=6 THEN
			   UPDATE LISTADOCONSUMOS SET TARIFA6=xDESCRIP,IMPORTE6=v2.IMPORTE
			   WHERE ABONADO=xABONADO;
			ELSIF i=7 THEN
			   UPDATE LISTADOCONSUMOS SET TARIFA7=xDESCRIP,IMPORTE7=v2.IMPORTE
			   WHERE ABONADO=xABONADO;
			ELSIF i=8 THEN
			   UPDATE LISTADOCONSUMOS SET TARIFA8=xDESCRIP,IMPORTE8=v2.IMPORTE
			   WHERE ABONADO=xABONADO;
			ELSIF i=9 THEN
			   UPDATE LISTADOCONSUMOS SET TARIFA9=xDESCRIP,IMPORTE9=v2.IMPORTE
			   WHERE ABONADO=xABONADO;
			ELSIF i=10 THEN
			   UPDATE LISTADOCONSUMOS SET TARIFA10=xDESCRIP,IMPORTE10=v2.IMPORTE
			   WHERE ABONADO=xABONADO;
			ELSIF i=11 THEN
			   UPDATE LISTADOCONSUMOS SET TARIFA11=xDESCRIP,IMPORTE11=v2.IMPORTE
			   WHERE ABONADO=xABONADO;
			ELSIF i=12 THEN
			   UPDATE LISTADOCONSUMOS SET TARIFA12=xDESCRIP,IMPORTE12=v2.IMPORTE
			   WHERE ABONADO=xABONADO;
			END IF;
			
			i:=i+1;
			
		END LOOP;
	END LOOP;

END;
/

/*************************************************************************************/
create or replace procedure dm 
as
   xDOMICILIADO CHAR(1);
   xENTIDAD CHAR(4);
   xSUCURSAL CHAR(4);
   xDC CHAR(4);
   xCUENTA CHAR(10);
   xF_DOMICILIACION DATE;
   xDNI_FACTURA CHAR(10);
   xNOMBRE_TITULAR VARCHAR2(40);
   
   cursor c1 is select ID,abonado from recibos_ibi where estado_banCo='DM'
   and year='2002' and periodo='01' and domiciliado='N';
   
begin
   for V1 in c1
   loop
      begin
         SELECT DOMICILIADO,ENTIDAD,SUCURSAL,DC,CUENTA,F_DOMICILIACION,DNI_FACTURA 
         INTO xDOMICILIADO,xENTIDAD,xSUCURSAL,xDC,xCUENTA,xF_DOMICILIACION,xDNI_FACTURA 
         FROM IBI WHERE ID=v1.ABONADO;
         Exception
            When no_data_found then
               xDOMICILIADO:='N';
               xENTIDAD:=NULL;
               xSUCURSAL:=NULL;
               xDC:=NULL;
               xCUENTA:=NULL;
               xF_DOMICILIACION:=NULL;
               xDNI_FACTURA:=NULL;
               xNOMBRE_TITULAR:=NULL;         
      End;
      
      IF xDNI_FACTURA IS NOT NULL THEN
         SELECT NOMBRE INTO xNOMBRE_TITULAR FROM CONTRIBUYENTES
         WHERE NIF=xDNI_FACTURA;
      END IF;
             
      UPDATE RECIBOS_IBI SET DOMICILIADO=xDOMICILIADO,
      						 ENTIDAD=xENTIDAD,
      						 SUCURSAL=xSUCURSAL,
      						 DC=xDC,
      						 CUENTA=xCUENTA,
      						 F_DOMICILIACION=xF_DOMICILIACION,
      						 TITULAR=xDNI_FACTURA,
      						 NOMBRE_TITULAR=xNOMBRE_TITULAR
      WHERE ID=v1.ID;      						 
         
   end loop;
end;
/
	
/************************************************************************************/

CREATE OR REPLACE PROCEDURE MULTAS_PASA_RECA_BOLETIN(
				XID				IN	INTEGER,
				xF_VENCIMIENTO	IN	DATE,
				xFIN_PE_VOL		IN	DATE)
AS

	xEMISOR 		CHAR(6);
	xTRIBUTO		CHAR(3);
	xDIG_C60_M2    	CHAR(2);
	xREFERENCIA 	CHAR(10);
	xIMPCADENA     	CHAR(12);

	xNIF			CHAR(10);
	xNOMBRE			VARCHAR2(40);	
	xPASE			CHAR(1);
	xNCARGO			CHAR(10);		
	xVALOR			INT;
	xPADRON			CHAR(6);
	xPorDescuento	float;
	xImporte		FLOAT;
	xSALTO			CHAR(2);
	xOBJ_TRIBUTARIO VARCHAR2(1024);
	xARTICULO 		CHAR(3);
	xAPARTADO		CHAR(2);
	xOPCION 		CHAR(2);
	xSANCION 		VARCHAR(120);
	
	vRegistro		Multas%RowType;
BEGIN

    SELECT * INTO vRegistro FROM MULTAS WHERE ID=xID;

	SELECT ARTICULO,APARTADO,OPCION,SANCION,DESCUENTO 
	INTO xARTICULO,xAPARTADO,xOPCION,xSANCION,xPorDescuento
	FROM SANCION WHERE ID=vRegistro.ID_ARTICULO;

	SELECT CONCEPTO INTO xPADRON FROM PROGRAMAS WHERE PROGRAMA='MULTAS';

	BEGIN
	   SELECT EMISORA,CONCEPTO_BANCO INTO xEMISOR,xTRIBUTO FROM RELA_APLI_BANCOS
	   WHERE AYTO=vRegistro.MUNICIPIO AND CONCEPTO=xPADRON;
	   EXCEPTION
			WHEN NO_DATA_FOUND THEN
			BEGIN
				xEMISOR:='000000';
				xTRIBUTO:='000';
			END;
	END;

	
	xImporte:=vRegistro.IMPORTE - ROUND(vRegistro.IMPORTE*(xPorDescuento/100),2);	

	--calcular los digitos de control del cuaderno 60 modalidad 2
	CALCULA_DC_MODALIDAD2_60(xImporte, xID, xTRIBUTO, SUBSTR(vRegistro.YEAR,3,2), '1',
				to_char(xF_VENCIMIENTO,'y'), to_char(xF_VENCIMIENTO,'ddd'),
				xEMISOR, xDIG_C60_M2);

	xDIG_C60_M2:=SUBSTR(xDIG_C60_M2,1,2);

	--CONVIERTE NºABONADO EN CARACTER Y RELLENO DE CEROS
	GETREFERENCIA(xID, xREFERENCIA);

	--CONVIERTE EL IMPORTE RELLENO DE CEROS
	IMPORTEENCADENA(xImporte, xIMPCADENA);	

	BEGIN
		SELECT PASE_AUTOMATICO_MULTAS,NCARGO 
		INTO xPASE,xNCARGO FROM DATOSPERR WHERE EMPRESA IS NOT NULL;
	EXCEPTION
		WHEN NO_DATA_FOUND THEN
			xPASE:='N';
	END;

	IF xPASE='S' THEN	

		SELECT min(SALTO) INTO xSALTO FROM SALTO;

		xOBJ_TRIBUTARIO:='BOLETIN Nº: '|| vRegistro.BOLETIN ||xSALTO;

		xOBJ_TRIBUTARIO:=xOBJ_TRIBUTARIO||'F. DENUNCIA: '|| 
					     to_char(vRegistro.FECHA_BOLETIN,'dd-mm-yyyy')||xSALTO;

		xOBJ_TRIBUTARIO:=xOBJ_TRIBUTARIO||'MATRICULA: ' ||
					     GetMatricula(vRegistro.MATRICULA,vRegistro.NUMERO,vRegistro.LETRA)||xSALTO;

		IF vRegistro.MARCA IS NOT NULL THEN
			xOBJ_TRIBUTARIO:=xOBJ_TRIBUTARIO||'MARCA: '||RTRIM(vRegistro.MARCA)||xSALTO;
		END IF;

		IF vRegistro.TIPO IS NOT NULL THEN
			xOBJ_TRIBUTARIO:=xOBJ_TRIBUTARIO || 'TIPO: '|| RTRIM(vRegistro.TIPO) || xSALTO;
		END IF;

		xOBJ_TRIBUTARIO:=xOBJ_TRIBUTARIO || 'Artículo: ' ||RTRIM(xArticulo)||'.'||
			     RTRIM(xApartado)||'.'||RTRIM(xOpcion)||' '|| RTRIM(xSANCION) || xSALTO;

		IF vRegistro.DNI_TUTOR IS NULL THEN
			xNIF:=vRegistro.DNI_CONDUCTOR;
			xNOMBRE:=vRegistro.NOMBRE_CONDUCTOR;
		ELSE
			xNIF:=vRegistro.DNI_TUTOR;
			xNOMBRE:=vRegistro.NOMBRE_TUTOR;
		END IF;

	    INSERTAVALORES(xPADRON,vRegistro.YEAR,'00',xID,xNIF,xNOMBRE,
			SYSDATE, xNCARGO,vRegistro.MUNICIPIO,NULL,xFIN_PE_VOL,
			NULL,NULL,NULL,NULL,NULL,'L',
			xOBJ_TRIBUTARIO,vRegistro.YEAR,vRegistro.IMPORTE,xImporte,0,0,0,'V',
			NULL,'N',vRegistro.EXPEDIENTE,xID,xVALOR);

		UPDATE valores SET POR_BONIFICACION=xPorDescuento,
						   IMPORTE_BONIFICADO=xImporte
		WHERE id=xVALOR;


	      -- Asignamos la relación unívoca entre recaudación y valores
	    UPDATE MULTAS SET IDVALOR=xVALOR,
	    				  NUMERO_DE_cARGO=xNCARGO,
	    				  F_CARGO=SYSDATE,
	    				  PASADO='S',
	    				  EMISOR=xEMISOR,
					  	  TRIBUTO=xTRIBUTO,
					      EJER_C60=SUBSTR(vRegistro.YEAR,3,2),
					      REFERENCIA=xREFERENCIA,
					      IMP_CADENA=xIMPCADENA,
					      DISCRI_PERIODO='1',				  
					      DIGITO_YEAR=to_char(xF_VENCIMIENTO,'y'),
					      F_JULIANA=to_char(xF_VENCIMIENTO,'ddd'),
					      DIGITO_C60_MODALIDAD2=xDIG_C60_M2,
					      FIN_PE_VOL=xFIN_PE_VOL
	    WHERE ID=xID;      	

	END IF;

END;
/


/*****************************************************************************************/
ALTER TABLE DOCS_IMPRESION ADD CATEGORIA VARCHAR2(40);
UPDATE DOCS_IMPRESION SET CATEGORIA='IMPRESION DE RECIBOS FORMATO VENTANILLA'
WHERE ID IN (1,2,3,4,5,6);
UPDATE DOCS_IMPRESION SET CATEGORIA='IMPRESION DE RECIBOS DOMICILIADOS'
WHERE ID IN (10,11,12,13,14,15);
UPDATE DOCS_IMPRESION SET CATEGORIA='NOTIFICACIONES'
WHERE ID IN (20,21);
UPDATE DOCS_IMPRESION SET CATEGORIA='INFORME DE DEUDAS Y CARTAS DE PAGO'
WHERE ID IN (30,40,41,45,50);
UPDATE DOCS_IMPRESION SET CATEGORIA='INFORMES PARA PROGRAMA EIS'
WHERE ID IN (60);
UPDATE DOCS_IMPRESION SET CATEGORIA='EMBARGOS DE SALARIOS'
WHERE ID BETWEEN 3001 AND 3007;
UPDATE DOCS_IMPRESION SET CATEGORIA='EMBARGOS DE INMUEBLES'
WHERE ID BETWEEN 4001 AND 4050;
UPDATE DOCS_IMPRESION SET CATEGORIA='EMBARGOS DE VEHICULOS'
WHERE ID BETWEEN 8001 AND 8038;

/***************************************************************************************/

-- Dado un procedimiento y un número de evento, el orden sólo se puede
-- repetir si el camino es diferente (para actos con resolución), y sólo
-- para un acto. Para el primer evento, al no ser resultado de ninguno 
-- anterior, el campo camino no tendrá sentido, con lo cual no se podrá
-- repetir el número de orden, y el camino será por defecto P.

-- ERROR: 0 -> NO HAY ERROR; 1 -> EL ORDEN YA EXISTE; 2 -> EXISTE ORDEN Y CAMINO

CREATE OR REPLACE FUNCTION FLW_Comprobar_Flujo(
    xID					IN	INTEGER,
	xProcedimiento		IN	INTEGER,
	xNEvento			IN	INTEGER,
	xOrden				IN	INTEGER,
	xCamino				IN  CHAR) RETURN INTEGER
AS
   xERROR INTEGER;
   xCUANTOS INTEGER;
BEGIN   

   xERROR:=0;
   
   IF xNEVENTO=1 THEN
   
        IF (xID > 0) THEN  -- si se quiere modificar un flujo 
        
        	SELECT COUNT(*) INTO xCUANTOS FROM FLWFLUJO
        	WHERE PROCEDIMIENTO=xPROCEDIMIENTO AND NEVENTO=xNEVENTO AND
        		  ORDEN=xORDEN AND ID<>xID;
        		  
        ELSE   
   
   			SELECT COUNT(*) INTO xCUANTOS FROM FLWFLUJO 
   			WHERE PROCEDIMIENTO=xPROCEDIMIENTO AND NEVENTO=xNEVENTO AND
   		      	  ORDEN=xORDEN;
   		      	  
   		END IF;
   		      
   		IF xCUANTOS=0 THEN
   		   xERROR:=0;
   		ELSE
   		   xERROR:=1; 
   		END IF;
   
   ELSIF xNEVENTO>1 THEN
   
   		IF (xID > 0) THEN
   		
   			SELECT COUNT(*) INTO xCUANTOS FROM FLWFLUJO
   			WHERE PROCEDIMIENTO=xPROCEDIMIENTO AND NEVENTO=xNEVENTO AND
   				  ORDEN=xORDEN AND CAMINO=xCAMINO AND ID<>xID;
   				  
   		ELSE
      
   			SELECT COUNT(*) INTO xCUANTOS FROM FLWFLUJO
   			WHERE PROCEDIMIENTO=xPROCEDIMIENTO AND NEVENTO=xNEVENTO AND
   			  	  ORDEN=xORDEN AND CAMINO=xCAMINO;
   			  	  
   	    END IF;
   			  
   	    IF xCUANTOS=0 THEN
   	       xERROR:=0;
   	    ELSE
   	       xERROR:=2;   	          
   	    END IF;
   
   END IF;

   RETURN xERROR;
   
END;	
/


-- Un acto sincronizado en un flujo significa que este acto tiene que esperar
-- a que el resto de actos con el mismo número de evento esten realizados
--
Create or replace procedure FLW_AddFujo(
   	xID 			IN 	INTEGER,
	xProcedimiento	IN	INTEGER,
	xActo			IN	INTEGER,
	xNEvento 		IN 	Integer,
	xCamino			IN	Char,
	xOrden 			IN 	Integer,	
	xSincronizado 	IN 	Char,
	xERROR			OUT INTEGER
	)
AS
begin

    -- primero debemos comprobar si los datos dados para modificar o dar de 
    -- alta un flujo pueden entrar en conflicto con algunos ya existentes.
    xERROR:=FLW_Comprobar_Flujo(xID,xPROCEDIMIENTO,xNEVENTO,xORDEN,xCAMINO);
    
    IF xERROR=0 THEN

		-- Como un evento puede tener más de un acto, el orden nós indica el número de acto
		-- dentro de un evento

		UPDATE FLWFLUJO SET PROCEDIMIENTO=xPROCEDIMIENTO,
						ACTO=xACTO,
						NEVENTO=xNEVENTO,
						CAMINO=xCAMINO,
						ORDEN=xORDEN,
						SINCRONIZADO=xSINCRONIZADO
		WHERE ID=xID;
						
		IF SQL%NOTFOUND THEN		
			INSERT INTO FLWFLUJO
				(PROCEDIMIENTO,ACTO,NEVENTO,CAMINO,ORDEN,SINCRONIZADO)
			VALUES
				(xPROCEDIMIENTO,xACTO,xNEVENTO,xCAMINO,xORDEN,xSINCRONIZADO);
		END IF;	
		
	END IF;

end;
/

/**************************************************************************************/
/**************************************************************************************/
/*						CARGAR DOMICILIACIONES EN TORREJON PARA IBI				      */

-- Hay 17 abonados que están domiciliados y cuya domiciliación no coincide con el fichero
-- que se nos ha pasado
SELECT I.ID,I.REF_CATASTRAL,D.REF_CATASTRAL,I.NUMERO_SECUENCIAL,D.NUMERO_SECUENCIAL,
I.PRIMER_CARACTER_CONTROL,D.PRIMER_CARACTER_CONTROL,I.SEGUN_CARACTER_CONTROL,
D.SEGUN_CARACTER_CONTROL,I.NUM_FIJO,D.NUM_FIJO,I.ENTIDAD,D.ENTIDAD,I.SUCURSAL,D.SUCURSAL,
I.DC,D.DC,I.CUENTA,D.CUENTA,I.F_DOMICILIACION,D.F_DOMICILIACION,I.DNI_FACTURA,D.TITULAR,
I.USR_CHG_CUENTA,I.F_CHG_CUENTA FROM IBI I,DOM_IBI_2003 D
WHERE I.ID=D.ABONADO AND I.DOMICILIADO='S' AND
I.ENTIDAD<>D.ENTIDAD AND I.SUCURSAL<>D.SUCURSAL AND I.DC<>D.DC AND I.CUENTA<>D.CUENTA;

-- Hay 150 abonados que están domiciliados y cuya domiciliación coincide con el fichero
-- que se nos ha pasado
SELECT I.ID,I.REF_CATASTRAL,D.REF_CATASTRAL,I.NUMERO_SECUENCIAL,D.NUMERO_SECUENCIAL,
I.PRIMER_CARACTER_CONTROL,D.PRIMER_CARACTER_CONTROL,I.SEGUN_CARACTER_CONTROL,
D.SEGUN_CARACTER_CONTROL,I.NUM_FIJO,D.NUM_FIJO,I.ENTIDAD,D.ENTIDAD,I.SUCURSAL,D.SUCURSAL,
I.DC,D.DC,I.CUENTA,D.CUENTA,I.F_DOMICILIACION,D.F_DOMICILIACION,I.DNI_FACTURA,D.TITULAR,
I.USR_CHG_CUENTA,I.F_CHG_CUENTA,D.CARGAR FROM IBI I,DOM_IBI_2003 D
WHERE I.ID=D.ABONADO AND I.DOMICILIADO='S' AND
I.ENTIDAD=D.ENTIDAD AND I.SUCURSAL=D.SUCURSAL AND I.DC=D.DC AND I.CUENTA=D.CUENTA;

-- Hay 4 abonados que están domiciliados y cuya domiciliación coincide sólo en entidad
-- con el fichero que se nos ha pasado
SELECT I.ID,I.REF_CATASTRAL,D.REF_CATASTRAL,I.NUMERO_SECUENCIAL,D.NUMERO_SECUENCIAL,
I.PRIMER_CARACTER_CONTROL,D.PRIMER_CARACTER_CONTROL,I.SEGUN_CARACTER_CONTROL,
D.SEGUN_CARACTER_CONTROL,I.NUM_FIJO,D.NUM_FIJO,I.ENTIDAD,D.ENTIDAD,I.SUCURSAL,D.SUCURSAL,
I.DC,D.DC,I.CUENTA,D.CUENTA,I.F_DOMICILIACION,D.F_DOMICILIACION,I.DNI_FACTURA,D.TITULAR,
I.USR_CHG_CUENTA,I.F_CHG_CUENTA,D.CARGAR FROM IBI I,DOM_IBI_2003 D
WHERE I.ID=D.ABONADO AND I.DOMICILIADO='S' AND I.ENTIDAD=D.ENTIDAD AND I.SUCURSAL
<>D.SUCURSAL AND I.DC<>D.DC AND I.CUENTA<>D.CUENTA

-- Hay 4 abonados que están domiciliados y cuya domiciliación coincide en entidad
-- y sucursal, pero no en dc ni cuenta
SELECT I.ID,I.REF_CATASTRAL,D.REF_CATASTRAL,I.NUMERO_SECUENCIAL,D.NUMERO_SECUENCIAL,
I.PRIMER_CARACTER_CONTROL,D.PRIMER_CARACTER_CONTROL,I.SEGUN_CARACTER_CONTROL,
D.SEGUN_CARACTER_CONTROL,I.NUM_FIJO,D.NUM_FIJO,I.ENTIDAD,D.ENTIDAD,I.SUCURSAL,D.SUCURSAL,
I.DC,D.DC,I.CUENTA,D.CUENTA,I.F_DOMICILIACION,D.F_DOMICILIACION,I.DNI_FACTURA,D.TITULAR,
I.USR_CHG_CUENTA,I.F_CHG_CUENTA,D.CARGAR FROM IBI I,DOM_IBI_2003 D
WHERE I.ID=D.ABONADO AND I.DOMICILIADO='S' AND I.ENTIDAD=D.ENTIDAD AND I.SUCURSAL
=D.SUCURSAL AND I.DC<>D.DC AND I.CUENTA<>D.CUENTA

-- Hay 5 abonados que están domiciliados y cuya domiciliación coincide en entidad,
-- sucursal y cuenta, pero no en dc
SELECT I.ID,I.REF_CATASTRAL,D.REF_CATASTRAL,I.NUMERO_SECUENCIAL,D.NUMERO_SECUENCIAL,
I.PRIMER_CARACTER_CONTROL,D.PRIMER_CARACTER_CONTROL,I.SEGUN_CARACTER_CONTROL,
D.SEGUN_CARACTER_CONTROL,I.NUM_FIJO,D.NUM_FIJO,I.ENTIDAD,D.ENTIDAD,I.SUCURSAL,D.SUCURSAL,
I.DC,D.DC,I.CUENTA,D.CUENTA,I.F_DOMICILIACION,D.F_DOMICILIACION,I.DNI_FACTURA,D.TITULAR,
I.USR_CHG_CUENTA,I.F_CHG_CUENTA,D.CARGAR FROM IBI I,DOM_IBI_2003 D
WHERE I.ID=D.ABONADO AND I.DOMICILIADO='S' AND I.ENTIDAD=D.ENTIDAD AND I.SUCURSAL
=D.SUCURSAL AND I.DC<>D.DC AND I.CUENTA=D.CUENTA

-- Hay 1 abonado para el que concide la entidad, sucursal y dc, pero no la cuenta
SELECT I.ID,I.REF_CATASTRAL,D.REF_CATASTRAL,I.NUMERO_SECUENCIAL,D.NUMERO_SECUENCIAL,
I.PRIMER_CARACTER_CONTROL,D.PRIMER_CARACTER_CONTROL,I.SEGUN_CARACTER_CONTROL,
D.SEGUN_CARACTER_CONTROL,I.NUM_FIJO,D.NUM_FIJO,I.ENTIDAD,D.ENTIDAD,I.SUCURSAL,D.SUCURSAL,
I.DC,D.DC,I.CUENTA,D.CUENTA,I.F_DOMICILIACION,D.F_DOMICILIACION,I.DNI_FACTURA,D.TITULAR,
I.USR_CHG_CUENTA,I.F_CHG_CUENTA,D.CARGAR FROM IBI I,DOM_IBI_2003 D
WHERE I.ID=D.ABONADO AND I.DOMICILIADO='S' AND I.ENTIDAD=D.ENTIDAD AND I.SUCURSAL
=D.SUCURSAL AND I.DC=D.DC AND I.CUENTA<>D.CUENTA


-- Procedimiento que carga las domiciliaciones en la tabla del IBI

CREATE OR REPLACE PROCEDURE CARGAR_DOM_IBI_2003 AS
	CURSOR C1 IS SELECT * FROM DOM_IBI_2003;
BEGIN
	FOR v1 IN C1
	LOOP
	   UPDATE IBI SET ENTIDAD=v1.ENTIDAD,
                     SUCURSAL=v1.SUCURSAL,
                     DC=v1.DC,
                     CUENTA=v1.CUENTA,
			   		 F_DOMICILIACION=SYSDATE,
                     DNI_FACTURA=v1.NIF,
                     DOMICILIADO='S'
		WHERE ID=v1.ABONADO;	
	END LOOP;
END;
/


/************************************************************************************/
CREATE OR REPLACE PROCEDURE NADA AS
	xRECIBO INTEGER;
	CURSOR C1 IS SELECT * FROM MULTAS_TOR WHERE TO_CHAR(FDENUN,'YYYY')='2001'
						 ORDER BY FDENUN
						 FOR UPDATE OF RECIBO;
BEGIN
 
   xRECIBO:=1;
   FOR v1 IN C1 
   LOOP
      UPDATE MULTAS_TOR SET RECIBO=xRECIBO 
      WHERE CURRENT OF C1;
      xRECIBO:=xRECIBO+1;
   END LOOP;

END;
/

/***********************************************************************************/

CREATE OR REPLACE PROCEDURE DOMICILIARUSTICA AS
	CURSOR C1 IS select R.ID,RR.DOMICILIADO,RR.ENTIDAD,RR.SUCURSAL,RR.DC,
				 RR.CUENTA,RR.F_DOMICILIACION,RR.DNI_FACTURA,RR.REPRESENTANTE,
				 RR.IDDOMIALTER,RR.COTITULARES
				 from rus80 r, rus80 rr where r.municipio='176' and r.year='2003'
				 and rr.municipio='176' and rr.year='2002' 
				 and r.nif=rr.nif and rr.domiciliado='S'
				 and rtrim(r.nif) is not null and rtrim(rr.nif) is not null
				 and r.nif not in ('23688281Y','23690323R','23752361P');

BEGIN
	FOR v1 IN C1 
	LOOP
		UPDATE RUS80 SET DOMICILIADO=v1.DOMICILIADO,ENTIDAD=v1.ENTIDAD,
						 SUCURSAL=v1.SUCURSAL,DC=v1.DC,CUENTA=v1.CUENTA,
						 F_DOMICILIACION=v1.F_DOMICILIACION,DNI_FACTURA=v1.DNI_FACTURA,
						 REPRESENTANTE=v1.REPRESENTANTE,IDDOMIALTER=v1.IDDOMIALTER,
						 COTITULARES=v1.COTITULARES
		WHERE ID=v1.ID;
	END LOOP;
END;
/

/*****************************************************************************************/

CREATE OR REPLACE PROCEDURE PONERACTIVIDAD
AS		
	xMOTIVO VARCHAR2(40);
	CURSOR C1 IS SELECT E.ABONADO,T.MOTIVO FROM 
				EXACCIONES E, TOREXAC T
				WHERE E.NIF=T.NIF AND E.COD_ORDENANZA='000011' AND
				E.MOTIVO LIKE 'SUPERFICIE:%' AND  
				T.ID IN 
				(1100,1111,1116,1275,1334,1366,1404,1437,1465,1494,1610,1644,1834,1838,1864,1898,1901);
BEGIN
	FOR v1 IN C1
	LOOP
	    UPDATE EXACCIONES SET MOTIVO=v1.MOTIVO WHERE ABONADO=v1.ABONADO;
	END LOOP;
END;
/


/****************************************************************************************/

/*******************************************************************************
Autor: 03/06/2002 M. Carmen Junco Gómez.
Acción: Modifica recibo/s de IBI, tanto en GT como en RECA, cuando se modifican los
	  datos de un abonado, y siempre que el recibo esté en voluntaria.
Parámetros: xABONADO: ID del abonado de la tabla de IBI que se está modificando.
MODIFICACION: 06/06/2002 Antonio Pérez Caballero
	Se añade un nuevo parametro para saber si ha de anularse la domiciliación
	esto salio de un comentario del Concejal de Hacienda de Torrejón de Ardoz
	en la presentación del producto el martes día 3 de Junio del 2002
MODIFICACION: 18/06/2002 Antonio Pérez Caballero
	Para municipios que emitan padrón más de una vez por año, en dos veces, tres, etc.
	o para quién emitan padrones complementarios
MODIFICACION: 03/07/2002 M. Carmen Junco Gómez. Se cambia la asignación mVOL_EJE:=''
		  por mVOL_EJE:=NULL.
MODIFICACIÓN: 19/07/2002 M. Carmen Junco Gómez. El domicilio tributario se compone con los
		  mismos datos que cuando se genera el padrón. Antes sobraba un caracter de los
		  50 de la variable y daba error de buffer demasiado pequeño.
MODIFICACIÓN: 29/11/2002 M. Carmen Junco Gómez. Se añaden los campos MUNICIPIO y 
		  PERIODO en la tabla LOGSPADRONES.
		  Además sólo se estaban modificando los valores del maximo(ID) del
		  recibo que estaba asociado al abonado, lo que suponía un problema
		  si el padrón tenía más de un periodo (sólo se actualizaban los datos
		  del último padrón generado en el mismo año)	
MODIFICACIÓN: 30/05/2003. Se estaba poniendo el campo Domiciliado a nulo en vez de a 'N'.
MODIFICACIÓN: 08/08/2003 M. Carmen Junco Gómez. Se están dando problemas en Torrejón para
		  poder cuadrar las domiciliaciones en valores, recibos_ibi y el soporte 19 debido
		  a la opción de Anular la domiciliación. Ésta se anula, sin avisar, a pesar de
		  estar el soporte generado. Además, se estaba insertando una incidencia en AVISOSGT 
		  tanto si se debía anular la domiciliación como si no.
		  Aparte, si el recibo estaba en el punteo, no se modificaba.
		  También se corrige el hecho de que el usuario anulase una domiciliación 
		  inexistente, no insertando el aviso en este caso.
*******************************************************************************/
CREATE OR REPLACE PROCEDURE RECIBOS_IBI_MODIFI(
	xABONADO IN INTEGER, 
	xAnulaDOMI IN char,
	xAVISO	 OUT INTEGER)
AS

	v_registro	 IBI%ROWTYPE;
	v_recibo	 RECIBOS_IBI%ROWTYPE;
	
	mPADRON	 CHAR(6);
	mVOL_EJE CHAR(1);
	mVALOR	 INTEGER;
	mPUNTEO	 INTEGER;

	xDOMI_TRIBUTARIO VARCHAR2(50);
	xDOMICILIO		 VARCHAR2(50);
	xPOBLACION		 VARCHAR2(35);
	xPROVINCIA		 VARCHAR2(35);
	xCP			 	 CHAR(5);

	xOBJETO_TRIBUTARIO  VARCHAR(1024);
	xSALTO		CHAR(2);
	xYearNow		Char(4);
	xCUANTOS 		INTEGER;
	
	xDOMI_OLD	CHAR(1);

	-- cursor que recorre los distintos periodos de los distintos recibos que 
	-- se han podido emitir para este abonado. Han de ser recibos emitidos en el
	-- año en curso.
	CURSOR CPERIODOS IS SELECT DISTINCT PERIODO,ID FROM RECIBOS_IBI
				  WHERE ABONADO=xABONADO AND YEAR=xYEARNOW;				  

BEGIN


	xAVISO:=0;  -- inicialmente sin incidencias.


	-- Averiguar el año actual
	xYearNow:=TO_CHAR(sysdate,'yyyy');

	-- Averiguar el código de padron de IBI
	SELECT CONCEPTO INTO mPADRON FROM PROGRAMAS WHERE PROGRAMA='IBI';

	-- Leer todos los datos de la ficha de un abonado
	SELECT * INTO v_registro FROM IBI WHERE ID=xABONADO;

	-- recorrer los distintos recibos que se han podido generar para este abonado
	FOR vPERIODOS IN CPERIODOS 
	LOOP
	
		-- Recogemos los datos del recibo
	    SELECT * INTO v_recibo FROM RECIBOS_IBI WHERE ID=vPERIODOS.ID;
	    
	    xDOMI_OLD:=v_recibo.DOMICILIADO;
      
	    begin
	       SELECT ID,VOL_EJE INTO mVALOR,mVOL_EJE 
	       FROM VALORES 
           WHERE AYTO=v_recibo.MUNICIPIO 
		      AND PADRON=mPADRON 
		      AND YEAR=v_recibo.YEAR 
		      AND PERIODO=v_recibo.PERIODO 
		      AND RECIBO=v_recibo.RECIBO;
	       Exception
	          When no_data_found then
	  	         mVOL_EJE:=NULL;
	    end;
	   
	    -- Si no se encuentra el valor, comprobar si está en el punteo
	    IF (mVOL_EJE IS NULL) THEN
	       begin
		      SELECT ID,VOL_EJE INTO mPUNTEO,mVOL_EJE FROM PUNTEO
			  WHERE AYTO=v_recibo.MUNICIPIO
			  	   AND PADRON=mPADRON
				   AND YEAR=v_recibo.YEAR
				   AND PERIODO=v_recibo.PERIODO
				   AND RECIBO=v_recibo.RECIBO;
			  Exception
			     When no_data_found then
			        mVOL_EJE:=NULL;
		   end;
	    END IF;


	    -- si el recibo está en Voluntaria en RECA o todavia no se ha pasado a recaudación
	    IF ((mVOL_EJE='V') or (mVOL_EJE IS NULL)) THEN

	       --domicilio tributario
	       xDOMI_TRIBUTARIO:=LTRIM(RTRIM(v_registro.TIPO_VIA))||' '||
				      LTRIM(RTRIM(v_registro.NOMBRE_VIA))||' '||
	  			      LTRIM(RTRIM(v_registro.PRIMER_NUMERO))||' '||
				      LTRIM(RTRIM(v_registro.PRIMERA_LETRA))||' '||
				      LTRIM(RTRIM(v_registro.ESCALERA))||' '||
				      LTRIM(RTRIM(v_registro.PLANTA))||' '||
				      LTRIM(RTRIM(v_registro.PUERTA));
     
	       --domicilio fiscal en funcion de si tiene un representante o no.
	       --Dentro de la funcion "GetDomicilioFiscal" se comprueba si tiene a su vez 
	       --un domicilio alternativo.

	       IF v_registro.REPRESENTANTE IS NULL THEN		

	          IF v_registro.IDDOMIALTER IS NULL THEN

		         xDOMICILIO:=v_registro.TIPO_VIA_FISCAL||' '||v_registro.NOMBRE_VIA_FISCAL||
					' '||v_registro.PRIMER_NUMERO_FISCAL||' '||
				      v_registro.ESCALERA_FISCAL||' '||v_registro.PLANTA_FISCAL||' '||
				      v_registro.PUERTA_FISCAL;
		         xCP:=v_registro.COD_POSTAL_FISCAL;
		         xPOBLACION:=v_registro.MUNICIPIO_FISCAL;
		         xPROVINCIA:=v_registro.PROVINCIA;

	          ELSE

		         GetDomicilioFiscal(v_registro.NIF,v_REGISTRO.IDDOMIALTER,
			  	             xDomicilio,xPoblacion,xProvincia,xCP);

		      END IF;
	       ELSE

		      GetDomicilioFiscal(v_Registro.REPRESENTANTE,v_Registro.IDDOMIALTER,
		 	                xDomicilio,xPoblacion,xProvincia,xCP);

	       END IF;

	       -- modificamos el recibo en gestión tributaria y recaudación
	       xDOMI_OLD:=v_recibo.DOMICILIADO;
	       
	       IF xAnulaDOMI='S' THEN

	          UPDATE RECIBOS_IBI SET  NIF=v_registro.NIF,
	  				         NOMBRE=SUBSTR(v_registro.NOMBRE,1,40),
					         DOMICILIO=xDOMICILIO,
					         DOMI_TRIBUTARIO=xDOMI_TRIBUTARIO,
					         POBLACION=xPOBLACION,
					         PROVINCIA=xPROVINCIA,
					         CODIGO_POSTAL=xCP,
					         DOMICILIADO='N',
					         ENTIDAD=NULL,
					         SUCURSAL=NULL,
					         DC=NULL,
					         CUENTA=NULL,
					         F_DOMICILIACION=NULL,
					         TITULAR=NULL,
					         NOMBRE_TITULAR=NULL,
					         ESTADO_BANCO=NULL
		      WHERE ID=vPERIODOS.ID;
	       ELSE
	          UPDATE RECIBOS_IBI SET  NIF=v_registro.NIF,
	  				         NOMBRE=SUBSTR(v_registro.NOMBRE,1,40),
					         DOMICILIO=xDOMICILIO,
					         DOMI_TRIBUTARIO=xDOMI_TRIBUTARIO,
					         POBLACION=xPOBLACION,
					         PROVINCIA=xPROVINCIA,
					         CODIGO_POSTAL=xCP
	          WHERE ID=vPERIODOS.ID;
	       END IF;

	       -- si está pasado a Recaudación, modificamos los datos del valor (o del punteo)
	       IF mVOL_EJE='V' THEN

	          -- refrescamos los datos seleccionados del recibo
	          SELECT * INTO v_recibo FROM RECIBOS_IBI WHERE ID=vPERIODOS.ID;

  	          -- para modificar el valor debemos componer de nuevo el objeto_tributario
	          -- por si se ha modificado el domicilio tributario
	          xOBJETO_TRIBUTARIO:='';
              xOBJETO_TRIBUTARIO:='ABONADO Nº: '||TO_CHAR(v_recibo.RECIBO)||' '||xSALTO;
   
	          IF v_recibo.DOMI_TRIBUTARIO IS NOT NULL THEN
      	         xOBJETO_TRIBUTARIO:=xOBJETO_TRIBUTARIO||'DOM. TRIBUTARIO: '
                                      ||v_recibo.DOMI_TRIBUTARIO||' '||xSALTO;
              END IF;

              IF v_Recibo.REF_CATASTRAL IS NOT NULL THEN
                 xOBJETO_TRIBUTARIO:=xOBJETO_TRIBUTARIO||'REF. CATASTRAL: '
                                      ||v_recibo.REF_CATASTRAL||v_Recibo.NUMERO_SECUENCIAL
				       	  ||v_Recibo.PRIMER_CARACTER_CONTROL
			  	          ||v_Recibo.SEGUN_CARACTER_CONTROL||' '||xSALTO;
              END IF;

              IF v_Recibo.NUM_FIJO IS NOT NULL THEN
                 xOBJETO_TRIBUTARIO:=xOBJETO_TRIBUTARIO||'Nº FIJO: '
                                      ||v_Recibo.NUM_FIJO||' '||xSALTO;
              END IF;

	          IF v_Recibo.BASE_LIQUIDABLE IS NOT NULL THEN
	             xOBJETO_TRIBUTARIO:=xOBJETO_TRIBUTARIO||'BASE LIQUIDABLE: '
					        ||TO_CHAR(v_Recibo.BASE_LIQUIDABLE)||' '||xSALTO;
	          END IF;   
 
              IF v_Recibo.VALOR_CATASTRAL IS NOT NULL THEN
   	             xOBJETO_TRIBUTARIO:=xOBJETO_TRIBUTARIO||'VALOR CATASTRAL: '
                                      ||TO_CHAR(v_Recibo.VALOR_CATASTRAL)||' '||xSALTO;
              END IF;

              IF v_Registro.VALOR_SUELO IS NOT NULL THEN
	             xOBJETO_TRIBUTARIO:=xOBJETO_TRIBUTARIO||'VALOR SUELO: '
                                    ||TO_CHAR(v_Registro.VALOR_SUELO)||' '||xSALTO;
              END IF;

	          IF v_recibo.BASE_IMPONIBLE IS NOT NULL THEN
	             xOBJETO_TRIBUTARIO:=xOBJETO_TRIBUTARIO||'BASE IMPONIBLE: '
					        ||TO_CHAR(v_recibo.BASE_IMPONIBLE)||' '||xSALTO;
	          END IF;

              IF v_recibo.BONIFICACION IS NOT NULL THEN
	             xOBJETO_TRIBUTARIO:=xOBJETO_TRIBUTARIO||'BONIFICACION: '
                                      ||TO_CHAR(v_recibo.BONIFICACION, '900')||' '||XSALTO;
              END IF;

	          IF v_recibo.TIPO_GRAVAMEN IS NOT NULL THEN
	             xOBJETO_TRIBUTARIO:=xOBJETO_TRIBUTARIO||'TIPO GRAVAMEN: '
					        ||TO_CHAR(v_recibo.TIPO_GRAVAMEN,'0D999')||' '||xSALTO;
	          END IF;
	         
	          IF mVALOR IS NOT NULL THEN
		         IF xAnulaDOMI='S' THEN
  	                UPDATE VALORES SET NIF=v_recibo.NIF,
               		                   NOMBRE=v_recibo.NOMBRE,
				                       DOM_TRIBUTARIO=xDOMI_TRIBUTARIO, 
				                       OBJETO_TRIBUTARIO=xOBJETO_TRIBUTARIO,
					                   ESTADO_BANCO=DECODE(ESTADO_BANCO, 'EB', NULL, ESTADO_BANCO)
	                WHERE ID=mVALOR;
		         ELSE
  	                UPDATE VALORES SET NIF=v_recibo.NIF,
               		                   NOMBRE=v_recibo.NOMBRE,
				                       DOM_TRIBUTARIO=xDOMI_TRIBUTARIO, 
				                       OBJETO_TRIBUTARIO=xOBJETO_TRIBUTARIO
	                WHERE ID=mVALOR;
		         END IF; -- xAnulaDOMI = 'S'
		      ELSE --si mVALOR IS NULL y mVOL_EJE='V' es porque está en el punteo
		         IF xAnulaDOMI='S' THEN
  	                UPDATE PUNTEO SET NIF=v_recibo.NIF,
               		                  NOMBRE=v_recibo.NOMBRE,
				                      DOM_TRIBUTARIO=xDOMI_TRIBUTARIO, 
				                      OBJETO_TRIBUTARIO=xOBJETO_TRIBUTARIO,
					                  ESTADO_BANCO=DECODE(ESTADO_BANCO, 'EB', NULL, ESTADO_BANCO)
	                WHERE ID=mPUNTEO;
		         ELSE
  	                UPDATE PUNTEO SET NIF=v_recibo.NIF,
               		                  NOMBRE=v_recibo.NOMBRE,
				                      DOM_TRIBUTARIO=xDOMI_TRIBUTARIO, 
				                      OBJETO_TRIBUTARIO=xOBJETO_TRIBUTARIO
	                WHERE ID=mPUNTEO;	
	             END IF; --xAnulaDOMI = 'S'
		      END IF; -- mVALOR IS NOT NULL
						
	       END IF; -- mVOL_EJE='V'

        END IF; -- ((mVOL_EJE='V') or (mVOL_EJE IS NULL))	 

        -- Si se ha emitido el soporte Cuaderno19
        -- y se ha de anular la domiciliación, se genera una incidencia.
        SELECT COUNT(*) INTO xCUANTOS FROM LOGSPADRONES 
	    WHERE MUNICIPIO=v_recibo.MUNICIPIO AND  
		      PROGRAMA ='IBI' AND
	          PYEAR=xYearNow AND
		      PERIODO=v_recibo.PERIODO AND
	          HECHO='Generación Cuaderno 19 (recibos domiciliados)';

        IF ((xCUANTOS > 0) AND (xAnulaDOMI='S') AND (xDOMI_OLD='S')) THEN
        -- Generar incidencia
	       INSERT INTO AVISOSGT (HECHO,PROGRAMA,PYEAR,REFERENCIA,RECIBO_PADRON)
		   VALUES ('Se cambia una domiciliación después de emitir el soporte magnético',
		   'IBI',xYearNow, vPERIODOS.ID,'R');
		   xAVISO:=1;
        END IF;
       
	 END LOOP;  

END;
/


/*******************************************************************************
Acción: Modifica los datos fiscales del titular de un recibo de ibi.
MODIFICACIÓN: Antonio Pérez Caballero. Permitimos cambiar algunos datos del fichero de
	        IBI por indicación del sujeto pasivo. Para evitar perder estos cambios en 
		  nuevas cargas lo indicamos en una tabla de referencia a través del campo
		  VARIACION='S'. Los procesos de carga consultarán este campo y dependiendo
		  de su valor recogerán ciertos datos de la cinta del año anterior (los datos
		  que se han corregido).
MODIFICACIÓN: 04/04/2002 M. del Carmen Junco Gómez. Actualización de la modificación anterior
		  para asemejarla a la que se hace en RUSTICA. No sólo se modifica el registro
		  que activa la modificación (ID=xID) sino que se corrigen los datos para todas
		  las tuplas del mismo municipio e igual referencia catastral, guardando los datos
		  que venían en disco en la tabla HIS_CARGOREAL_IBI.
MODIFICACIÓN: 17/05/2002 M. del Carmen Junco Gómez. Del select del cursor quitamos el 
		  municipio para dar rapidez al cursor. Se ha creado el índice
		  IBIREFERENCIA.
MODIFICACIÓN: A petición de Agustín: 20/05/2002. M. Carmen Junco Gómez. Sólamente se van 
	        a poder modificar los datos fiscales. Además se van a guardar todas las
		  variaciones (no sólo los datos que venían en disco) para poder tener un 
		  histórico.
MODIFICACIÓN: A petición de Javier Romeo: 21/05/2002 M. Carmen Junco Gómez. También se 
		  podrá modificar el domicilio tributario en IBI.
MODIFICACIÓN: A petición de Javier Romeo: 03/06/2002 M. Carmen Junco Gómez. Cuando se 
		  modifiquen los datos de un abonado de IBI, se modificarán simultáneamente los
		  datos del último recibo generado y de éste recibo en Ejecutiva. Si el recibo
		  está en ejecutiva sólo se permitirá cambiar los datos del abonado, pero no 
		  del recibo.
MODIFICACIÓN: 06/06/2002 Antonio Pérez Caballero Concejal de Hacienda de Torrejón de Ardoz
		  Se podrá anular la domiciliación de un IBI si se cambia la titularidad.
		  Se añade un nuevo parametro xAnulaDOMI que nos indica con un valor 'S' si hay que
		  anular la domiciliación.
		  los parametros del obeto tributario se pueden pasar con valores nulos y en tal 
              caso no los modifica.
		  xTipoCambio indica si modifica plusvalias P plusvalías, M motes
		  R desde el registro de entrada, I desde el IBI

MODIFICACIÓN: 30/10/2002 Agustín León Robles. En el update de IBI en el domicilio tributario
		  el DECODE que habia estaba incorrecto.
MODIFICACIÓN: 18/02/2003 Mª del Carmen Junco Gómez.
		  Le incluimos la fecha de alteración catastral.
MODIFICACIÓN: 04/04/2003 M. Carmen Junco Gómez. Se añade un nuevo parámetro para indicar
		  que tipo de motivo de movimiento se produce.
MODIFICACIÓN: 04/06/2003 M. Carmen Junco Gómez. Al haber cambiado en referencias bancos
		  VARIACION='S' donde VARIACION='I' (cambio de 15 de Mayo de 2003 de Agustín), 
		  también hay que controlar que QUIEN_VARIA='S' donde QUIEN_VARIA='I' (Al hacer
		  un cambio desde IBI se incluirá una S en quien_varia en vez de una I.
MODIFICACIÓN: 08/08/2003 M. Carmen Junco Gómez. Se incorpora un nuevo parámetro de 
		  salida: xAVISO, que avisará en delphi si se ha anulado una domiciliación
		  después de haber generado el Cuaderno 19.
*******************************************************************************/
CREATE OR REPLACE PROCEDURE IBI_MODIFICA(
   xID 		     IN INTEGER,
   xNIF 		 IN CHAR,
   xNOMBRE 		 IN CHAR,
   xVIAF 		 IN CHAR,
   xCALLEF 		 IN VARCHAR2,
   xNUMEROF 	 IN CHAR,
   xESCALERAF 	 IN CHAR,
   xPLANTAF 	 IN CHAR,
   xPISOF 		 IN CHAR,
   xCPF 		 IN CHAR,
   xPOBLACIONF 	 IN VARCHAR2,
   xPROVINCIAF 	 IN VARCHAR2,      
   xPAISF		 IN VARCHAR2,
   xTIPO_VIA	 IN CHAR,
   xNOMBRE_VIA	 IN CHAR,
   xPRIMER_NUMERO IN CHAR,
   xBLOQUE		 IN CHAR,
   xESCALERA	 IN CHAR,
   xPLANTA	     IN CHAR,
   xPUERTA		 IN CHAR,
   xAnulaDOMI	 IN Char,
   xTipoCambio   IN Char, 
   xFecha_altera IN DATE,
   xCod_Motivo	 IN CHAR,
   xCODIGO_OPERACION IN INTEGER,  --si se van a modificar más de un registro a la vez
   xAVISO		OUT INTEGER) 
AS
 
   v_registro		 IBI%ROWTYPE;   

   -- cursor que recorre todos los registros con código de operacion=xCodigo_Operacion
   -- de forma que se puedan actualizar los datos fiscales a la vez para más de un 
   -- registro de la tabla de IBI
   -- Guardaremos los datos actuales en la tabla HIS_CARGOREAL_IBI para mantener un histórico.
   
   CURSOR CIBI IS SELECT * FROM IBI WHERE CODIGO_OPERACION=xCODIGO_OPERACION
			FOR UPDATE OF NIF,NOMBRE,TIPO_VIA_FISCAL,NOMBRE_VIA_FISCAL,
					  PRIMER_NUMERO_FISCAL,ESCALERA_FISCAL,PLANTA_FISCAL,
					  PUERTA_FISCAL,COD_POSTAL_FISCAL,MUNICIPIO_FISCAL,
					  PROVINCIA,PAIS,TIPO_VIA,NOMBRE_VIA,PRIMER_NUMERO,
					  BLOQUE,ESCALERA,PLANTA,PUERTA;

BEGIN



   -- Hay un trigger sobre IBI llamado T_UPDBEFORE_IBI que se activa cuando modificamos
   -- el atributo Domiciliado


   -- Si trabajamos sólo sobre un registro
   IF xCODIGO_OPERACION=0 THEN 

	-- recogemos los datos actuales que para este ID hay en la tabla IBI.
      SELECT * INTO v_registro FROM IBI WHERE ID=xID;

      INSERT INTO HIS_CARGOREAL_IBI
         (IDIBI,AYTO,TIPO_VARIACION,NIF,NOMBRE,TIPO_VIA_FISCAL,NOMBRE_VIA_FISCAL,
          PRIMER_NUMERO_FISCAL, ESCALERA_FISCAL,PLANTA_FISCAL, PUERTA_FISCAL,
          COD_POSTAL_FISCAL,MUNICIPIO_FISCAL,PROVINCIA,PAIS,TIPO_VIA,NOMBRE_VIA,
	    PRIMER_NUMERO,BLOQUE,ESCALERA,PLANTA,PUERTA, QUIEN_VARIA, FECHA_ALTERACION,
	    COD_MOTIVO)
	VALUES 	
	   (xID,v_registro.MUNICIPIO,'M',v_registro.NIF,v_registro.NOMBRE,
	    v_registro.TIPO_VIA_FISCAL,v_registro.NOMBRE_VIA_FISCAL,
	    v_registro.PRIMER_NUMERO_FISCAL,v_registro.ESCALERA_FISCAL,
	    v_registro.PLANTA_FISCAL,v_registro.PUERTA_FISCAL,
          v_registro.COD_POSTAL_FISCAL,v_registro.MUNICIPIO_FISCAL,
	    v_registro.PROVINCIA,v_registro.PAIS,v_registro.TIPO_VIA,
	    v_registro.NOMBRE_VIA,v_registro.PRIMER_NUMERO,v_registro.BLOQUE,
	    v_registro.ESCALERA,v_registro.PLANTA,v_registro.PUERTA, xTipoCambio, 
	    xFecha_altera,xCod_Motivo);

	-- modificamos los datos en la tabla de IBI

	UPDATE IBI SET NIF=xNIF,
                     NOMBRE=xNOMBRE,
                     TIPO_VIA_FISCAL=xVIAF,
                     NOMBRE_VIA_FISCAL=xCALLEF,
                     PRIMER_NUMERO_FISCAL=xNUMEROF,
                     ESCALERA_FISCAL=xESCALERAF,
                     PLANTA_FISCAL=xPLANTAF,
                     PUERTA_FISCAL=xPISOF,
                     COD_POSTAL_FISCAL=xCPF,
                     MUNICIPIO_FISCAL=xPOBLACIONF,
                     PROVINCIA=xPROVINCIAF,                
			   PAIS=xPAISF,
			   TIPO_VIA=xTIPO_VIA,
			-- En el caso de que las variables vengan a nulo dejamos mismos valores
			   NOMBRE_VIA=DECODE(RTRIM(xNOMBRE_VIA), NULL, NOMBRE_VIA,xNOMBRE_VIA),
			   PRIMER_NUMERO=DECODE(RTRIM(xPRIMER_NUMERO), NULL ,PRIMER_NUMERO,xPRIMER_NUMERO),
			   BLOQUE=DECODE(RTRIM(xBLOQUE), NULL ,BLOQUE, xBLOQUE),
			   ESCALERA=DECODE(RTRIM(xESCALERA), NULL,ESCALERA ,xESCALERA),
			   PLANTA=DECODE(RTRIM(xPLANTA), NULL, PLANTA ,xPLANTA),
			   PUERTA=DECODE(RTRIM(xPUERTA), NULL, PUERTA ,xPUERTA),

                     QUIEN_MODIFICA=USER,
			   DOMICILIADO=DECODE(xAnulaDOMI, 'S', 'N', DOMICILIADO)
	WHERE ID=xID;

      -- Anotamos el cambio en la tabla de referencias para que en la siguiente carga
      -- se recojan estos datos y no los que vengan en cinta.

      UPDATE REFERENCIAS_BANCOS SET VARIACION=xTipoCambio,NIF=xNIF
      WHERE MUNICIPIO=v_registro.MUNICIPIO AND
            REF_CATASTRAL=v_registro.REF_CATASTRAL||
			        v_registro.NUMERO_SECUENCIAL||
				  v_registro.PRIMER_CARACTER_CONTROL||
				  v_registro.SEGUN_CARACTER_CONTROL;

	-- se modifica (si se puede) el último recibo, tanto en GT como en RECA
      RECIBOS_IBI_MODIFI(xID, xAnulaDOMI,xAVISO);

   -- si se van a modificar más de un registro a la vez
   ELSE

      FOR vIBI IN CIBI
      LOOP	

	   -- Insertamos en el historico la información que hasta ahora poseíamos
	   -- para el registro en la tabla de IBI.

         INSERT INTO HIS_CARGOREAL_IBI
            (IDIBI,AYTO,TIPO_VARIACION,NIF,NOMBRE,TIPO_VIA_FISCAL,NOMBRE_VIA_FISCAL,
             PRIMER_NUMERO_FISCAL, ESCALERA_FISCAL,PLANTA_FISCAL, PUERTA_FISCAL,
             COD_POSTAL_FISCAL,MUNICIPIO_FISCAL,PROVINCIA,PAIS,TIPO_VIA,NOMBRE_VIA,
	    PRIMER_NUMERO,BLOQUE,ESCALERA,PLANTA,PUERTA, QUIEN_VARIA, FECHA_ALTERACION,
	    COD_MOTIVO)
	   VALUES 	
	      (vIBI.ID,vIBI.MUNICIPIO,'M',vIBI.NIF,vIBI.NOMBRE,
	       vIBI.TIPO_VIA_FISCAL,vIBI.NOMBRE_VIA_FISCAL,
	       vIBI.PRIMER_NUMERO_FISCAL,vIBI.ESCALERA_FISCAL,
	       vIBI.PLANTA_FISCAL,vIBI.PUERTA_FISCAL,
             vIBI.COD_POSTAL_FISCAL,vIBI.MUNICIPIO_FISCAL,
	       vIBI.PROVINCIA,vIBI.PAIS,vIBI.TIPO_VIA,vIBI.NOMBRE_VIA,vIBI.PRIMER_NUMERO,
		 vIBI.BLOQUE,vIBI.ESCALERA,vIBI.PLANTA,vIBI.PUERTA, 'S', xFECHA_ALTERA,
		 xCOD_MOTIVO);         

	   -- modificamos los datos en la tabla de IBI (sólo datos fiscales)

	   UPDATE IBI SET NIF=xNIF,
                        NOMBRE=xNOMBRE,
                        TIPO_VIA_FISCAL=xVIAF,
                        NOMBRE_VIA_FISCAL=xCALLEF,
                        PRIMER_NUMERO_FISCAL=xNUMEROF,
                        ESCALERA_FISCAL=xESCALERAF,
                        PLANTA_FISCAL=xPLANTAF,
                        PUERTA_FISCAL=xPISOF,
                        COD_POSTAL_FISCAL=xCPF,
                        MUNICIPIO_FISCAL=xPOBLACIONF,
                        PROVINCIA=xPROVINCIAF,                
			      PAIS=xPAISF,                     
                        QUIEN_MODIFICA=USER
	   WHERE CURRENT OF CIBI;

         -- Anotamos el cambio en la tabla de referencias para que en la siguiente carga
         -- se recojan estos datos y no los que vengan en cinta.

         UPDATE REFERENCIAS_BANCOS SET VARIACION='S',NIF=xNIF
         WHERE MUNICIPIO=vIBI.MUNICIPIO AND
               REF_CATASTRAL=vIBI.REF_CATASTRAL||
			           vIBI.NUMERO_SECUENCIAL||
				     vIBI.PRIMER_CARACTER_CONTROL||
				     vIBI.SEGUN_CARACTER_CONTROL;

	   -- se modifica (si se puede) el último recibo, tanto en GT como en RECA
         RECIBOS_IBI_MODIFI(vIBI.ID, 'N',xAVISO);

      END LOOP;

   END IF; 

END;
/


/************************************************************************************************/

UPDATE AVISOSGT SET HECHO='Se cambia una domiciliación después de emitir el soporte magnético'
WHERE PROGRAMA='IBI;

-- DEBIDO A QUE ANTES SE INSERTABA UNA AVISO SIEMPRE, SE MODIFICASE O NO LA DOMICILIACIÓN.
-- se borran de avisosGT aquellas referencias de recibos para los que al modificar el IBI
-- no se modificó la domiciliación (no se anuló).
DELETE FROM AVISOSGT WHERE PROGRAMA='IBI' AND REFERENCIA IN (
SELECT ID FROM RECIBOS_IBI WHERE DOMICILIADO='S')
AND HECHO LIKE 'Se cambia una domiciliación%'

-- se borran de avisosGT aquellas referencias de recibos que no están domiciliados y 
-- cuyo abonado nunca lo ha estado (simplemente que al modificar los datos del abonado
-- se hizo un insert en avisosgt que no correspondía)
DELETE FROM AVISOSGT WHERE PROGRAMA='IBI' AND referencia in (select id from recibos_ibi
where f_domiciliacion is null and abonado in (select id from ibi
where f_domiciliacion is null)

-- se borran de avisosGT aquellas referencias de recibos que no están domiciliados porque
-- la domiciliación del abonado se hizo posteriormente a la generación del padrón
DELETE FROM AVISOSGT a WHERE PROGRAMA='IBI' AND referencia in (select id from recibos_ibi
where domiciliado='N' and abonado in (select id from ibi
where f_domiciliacion>a.fecha))

-- se borran de avisosGT aquellas referencias de recibos que se modificaron antes de
-- haber generado el C19, lo cual no suponía ninguna incidencia.
-- !!!esta consulta se ha de montar dependiendo de los datos de cada usuario!!!
DELETE FROM AVISOSGT WHERE PROGRAMA='IBI' AND REFERENCIA IN (SELECT ID FROM RECIBOS_IBI
WHERE YEAR='2002' AND PERIODO='01') AND fecha<to_date('09/09/2002 12:29:53','dd/mm/yyyy hh24:mi:ss')

DELETE FROM AVISOSGT WHERE PROGRAMA='IBI' AND REFERENCIA IN (SELECT ID FROM RECIBOS_IBI
WHERE YEAR='2003' AND PERIODO='00') AND fecha<to_date('15/07/2003 10:20:43','dd/mm/yyyy hh24:mi:ss')

/********************************************************************************************************/

CREATE OR REPLACE PROCEDURE NADA
AS
	xVIA              CHAR(2);
    xCALLE            VARCHAR(30);
    xNUM              CHAR(5);
    xESC              CHAR(2);
    xPLANTA           CHAR(3);
    xPISO             CHAR(2);
    xCODPOSTAL 	      CHAR(5);
    xPoblacion 	      CHAR(35);
    xPROVINCIA	      VARCHAR2(35);
    xPAIS			  VARCHAR2(35);
    seguir			  boolean;
	CURSOR C1 IS SELECT * FROM CONTRI;
BEGIN

	FOR v1 IN C1
	LOOP
	
	    UPDATE CONTRIBUYENTES SET VIA=v1.VIA,CALLE=v1.CALLE,NUMERO=v1.NUMERO,ESCALERA=v1.ESCALERA,
	    PLANTA=v1.PLANTA,PISO=v1.PISO,POBLACION=v1.POBLACION,PROVINCIA=v1.PROVINCIA,
	    CODIGO_POSTAL=v1.CODIGO_POSTAL,PAIS=v1.PAIS
	    WHERE NIF=v1.NIF;			
	    
	    UPDATE RECIBOS_VEHI SET DOMICILIO=TRIM(v1.VIA)||' '||TRIM(v1.CALLE)||' '||TRIM(v1.NUMERO)||' '||
							    TRIM(v1.ESCALERA)||' '||TRIM(v1.PLANTA)||' '||TRIM(v1.PISO),
		CODIGO_POSTAL=v1.CODIGO_POSTAL,
		POBLACION=v1.POBLACION,
		PROVINCIA=v1.PROVINCIA
		WHERE NIF=v1.NIF AND YEAR='2004';
		
	END LOOP;
	
END;







