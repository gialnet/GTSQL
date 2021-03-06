/******************************************************************************************/
/*     	PROCESO DE INCLUSION EN EXACCIONES DE TARIFAS_CONCEPTOS				*/
/******************************************************************************************/

ALTER TABLE TARIFAS_CONCEPTOS ADD COD_TARIFA CHAR(4) DEFAULT '0000' NOT NULL;
ALTER TABLE TARIFAS_CONCEPTOS ADD TIPO_IVA FLOAT DEFAULT 0;

CREATE OR REPLACE PROCEDURE INSERTA_TARIFA_CONCEPTO(xAYTO IN CHAR)	
AS   
   xFORMULA VARCHAR2(30);
   xFORMULAB VARCHAR2(30);
   xFORMULAC VARCHAR2(30);
   xFORMULAD VARCHAR2(30);
   xTIPO1 VARCHAR2(30);
   xTIPO2 VARCHAR2(30);
   xTIPO3 VARCHAR2(30);
   xTIPO4 VARCHAR2(30);
   xEXPLICACION VARCHAR2(512);
   xMINIMO FLOAT;
   xMAXIMO FLOAT;
   xTIPO_IVA FLOAT;

   CURSOR C1 IS SELECT * FROM TARIFAS_EXACCIONES WHERE MUNICIPIO=xAYTO
				      ORDER BY COD_ORDENANZA,COD_TARIFA;
BEGIN
   FOR v1 IN C1 
   LOOP

      -- si no tiene formula damos de alta el importe en el campo formula
	IF v1.FORMULA='N' THEN
		INSERT INTO TARIFAS_CONCEPTOS (AYTO,CONCEPTO,COD_TARIFA,TARIFA,
		  FORMULA,TIPO_IVA)
		VALUES (xAYTO,v1.COD_ORDENANZA,v1.COD_TARIFA,v1.TARIFA,
		  TO_CHAR(v1.IMPORTE),v1.TIPO_IVA);
	ELSE
	-- lo metemos el importe por defecto en el importe minimo
		INSERT INTO TARIFAS_CONCEPTOS (AYTO,CONCEPTO,COD_TARIFA,TARIFA,
		  FORMULA,FORMULAB,FORMULAC,FORMULAD,TIPO1,TIPO2,TIPO3,TIPO4,EXPLICACION,
		  TIPO_IVA)
		VALUES (xAYTO,v1.COD_ORDENANZA,v1.COD_TARIFA,v1.TARIFA,v1.IMPORTE,xFORMULAB,
		  xFORMULAC,xFORMULAD,xTIPO1,xTIPO2,xTIPO3,xTIPO4,xEXPLICACION,v1.TIPO_IVA);		
	END IF;
   END LOOP;
END;
/

EXECUTE INSERTA_TARIFA_CONCEPTO('148');
DROP PROCEDURE INSERTA_TARIFA_CONCEPTO;



/* PROCEDIMIENTO QUE DA CODIGO DE TARIFA AL RESTO DE TARIFAS CONCEPTOS */

CREATE OR REPLACE PROCEDURE DA_CODIGO_TARIFA (xAYTO IN CHAR)
AS
   xCODIGO CHAR(4);
   CURSOR C1 IS SELECT * FROM TARIFAS_CONCEPTOS WHERE AYTO=xAYTO AND COD_TARIFA='0000' 
		    ORDER BY CONCEPTO,TARIFA
		    FOR UPDATE OF COD_TARIFA;
BEGIN

   FOR v1 IN C1 
   LOOP

      SELECT MAX(COD_TARIFA) INTO xCODIGO FROM TARIFAS_CONCEPTOS 
      WHERE AYTO=xAYTO AND CONCEPTO=v1.CONCEPTO;   

      IF (xCODIGO='0000') THEN
         xCODIGO:='0001';
	ELSE
	   xCODIGO:=LPAD(TO_NUMBER(xCODIGO)+1,4,'0');
	END IF;

	UPDATE TARIFAS_CONCEPTOS SET COD_TARIFA=xCODIGO
	WHERE CURRENT OF C1;

   END LOOP;

END;
/

EXECUTE DA_CODIGO_TARIFA('148');
DROP PROCEDURE DA_CODIGO_TARIFA;

ALTER TABLE TARIFAS_CONCEPTOS DROP PRIMARY KEY;
ALTER TABLE TARIFAS_CONCEPTOS ADD PRIMARY KEY (AYTO, CONCEPTO, COD_TARIFA);

ALTER TABLE EXACCIONES DROP CONSTRAINT EXACMUNITARIFA;
ALTER TABLE EXACCIONES ADD CONSTRAINT EXACMUNITARIFA
	FOREIGN KEY (MUNICIPIO,COD_ORDENANZA,COD_TARIFA) 
	REFERENCES TARIFAS_CONCEPTOS(AYTO,CONCEPTO,COD_TARIFA);

CREATE OR REPLACE VIEW VWORDENANZAS AS 
	SELECT C.CONCEPTO,C.DESCRIPCION,
	N.FTOTAL,N.FRESULTADO,N.FORMULA,N.FORMULAB,
      N.FORMULAC,N.FORMULAD,N.TIPO1,N.TIPO2,N.TIPO3,
	N.TIPO4,N.EXPLICACION,N.RECA1,N.RECA2,
	N.RECA3,N.RECA4,N.OBJETO1,N.OBJETO2,
	N.OBJETO3,N.OBJETO4,N.EXPLICACION2,
	N.TIPO_OBJETO,N.TIPO_TRIBUTO,N.CARACTER_TRIBUTO,N.MUNICIPIO,N.MINIMO,N.MAXIMO
	FROM CONCEPTOS C, CONTADOR_CONCEPTOS N
	WHERE C.CONCEPTO=N.CONCEPTO
	AND N.CARACTER_TRIBUTO='O';


CREATE OR REPLACE VIEW VWEXACCIONES AS 
SELECT A.MUNICIPIO AS MUNICIPIO_EXACCIONES,
       A.NIF AS NIF_EXACCIONES,ABONADO,
       A.NUMERO AS NUMERO_TRIBUTARIA,A.PLANTA AS PLANTA_TRIBUTARIA,
       ESCALERA,PUERTA,COD_SITUACION,tarifa,MOTIVO,F_BAJA,
       A.COD_ORDENANZA,A.COD_TARIFA,TOTAL,DOMICILIADO,ENTIDAD,IDDOMIALTER,COTITULARES
FROM EXACCIONES A, TARIFAS_CONCEPTOS B
WHERE A.COD_TARIFA=B.COD_TARIFA
      AND A.municipio=B.ayto 
      AND A.COD_ORDENANZA=B.CONCEPTO;

DROP SEQUENCE GENTARIFAS_EXACC;
DROP TABLE TARIFAS_EXACCIONES;

CREATE OR REPLACE PROCEDURE PROC_TABLA_EXAC(xID IN INTEGER) en el archivo 13_EXACCIONES.SQL;
DROP PROCEDURE ModTarifaExacciones;
CREATE OR REPLACE PROCEDURE GENERA_PADRON_EXACCIONES en el archivo 13_EXACCIONES.SQL;
CREATE OR REPLACE PROCEDURE WriteTempExac en el archivo 13_EXACCIONES.SQL;
CREATE OR REPLACE TRIGGER EXACCIONES_ADD_TR en el archivo 13_TRIGGER_EXACCIONES.SQL;
CREATE OR REPLACE TRIGGER EXACCIONES_MOD_TR en el archivo 13_TRIGGER_EXACCIONES.SQL;
DROP TRIGGER ADD_TAR_EXACCIONES;
CREATE OR REPLACE TRIGGER ADD_TAR_CONCEPTOS en el archivo 02_TRIGGER_UTILIDADES.SQL;

CREATE OR REPLACE PROCEDURE COPIAR_CONCEPTOS en el archivo 02_UTILIDADES.SQL;
CREATE OR REPLACE PROCEDURE MODIFY_CONCEPTO en el archivo 02_UTILIDADES.SQL;
CREATE OR REPLACE PROCEDURE TipoDeObjetoCHG en el archivo 040_VARIOS.SQL DE RECA_SQL; 


    











