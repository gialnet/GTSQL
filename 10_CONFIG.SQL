/*****************************************************************************************
Acción: Da de alta o modifica los datos de un municipio
MODIFICACIÓN: 24/07/2002 Mª del Carmen Junco Gómez. Insertamos en una tabla adicional todos
		  los posibles códigos postales de un municipio. En la tabla datosper incluimos
		  uno de ellos (el primero que se da de alta en la lista desde delphi)
		  El parámetro xCODIGO contiene el código postal que se va a asociar con la 
		  dirección del ayuntamiento. Será el que aparecerá en los informes.
		  El parámetro xCODPOST contiene ahora una lista de códigos postales separados
		  por comas
*****************************************************************************************/
CREATE OR REPLACE PROCEDURE ADDMOD_MUNICIPIO(
       xMUNI 		IN CHAR,
       xGESTOR 		IN CHAR,
 	 xYEARWORK		IN CHAR,
       xEMPRESA 		IN CHAR,
       xCIF 		IN CHAR,
       xDIRECCION 	IN CHAR,
       xPOBLACION 	IN CHAR,
       xPROVINCIA 	IN CHAR,
	 xCODIGO		IN CHAR,
       xCODPOST 		IN CHAR,
       xEMAIL 		IN CHAR,
	 xAlcalde		in Char
)
AS
	xCUANTOS 	INTEGER;
	xCODPOSTAL  CHAR(5);
	I        	INTEGER;
BEGIN   

   SELECT COUNT(*) INTO xCUANTOS 
   FROM DATOSPER WHERE MUNICIPIO=xMUNI;

   IF xCUANTOS > 0 THEN
      UPDATE DATOSPER SET GESTOR=xGESTOR,
				  YEARWORK=xYEARWORK,
                          EMPRESA=xEMPRESA,
                          CIF=xCIF,
                          DIRECCION=xDIRECCION,
                          POBLACION=xPOBLACION,
                          PROVINCIA=xPROVINCIA,
                          CODIGO_POSTAL=xCODIGO,
                          EMAIL=xEMAIL,
				  Alcalde=xAlcalde
      WHERE MUNICIPIO=xMUNI;
   ELSE
      INSERT INTO DATOSPER
         (MUNICIPIO, GESTOR, YEARWORK, EMPRESA, CIF, DIRECCION,
         POBLACION, PROVINCIA, CODIGO_POSTAL, EMAIL,Alcalde)
      VALUES
         (xMUNI, xGESTOR, xYEARWORK, xEMPRESA, xCIF, xDIRECCION,
         xPOBLACION, xPROVINCIA, xCODIGO, xEMAIL,xAlcalde);
  
   INSERT INTO CONTADOR_CONCEPTOS(MUNICIPIO,CONCEPTO) SELECT  xMuni,concepto from conceptos;
   INSERT INTO MULTASWORK (MUNICIPIO,YEAR_WORK) VALUES (xMUNI,xYEARWORK);

  END IF;

   -- modificamos también la tabla de códigos postales auxiliar
   DELETE FROM MUNICPOSTALES WHERE MUNICIPIO=xMUNI;
   
   I:=1;
   
   WHILE I < LENGTH(xCODPOST) LOOP
   
		xCODPOSTAL:=SUBSTR(xCODPOST,I,5);
		
		INSERT INTO MUNICPOSTALES VALUES (xMUNI,xCODPOSTAL);
		
		I:=I+6;	
		
   END LOOP;    

END;
/

/*******************************************************************************/
-- Modificado 03/11/2003. Agustín León Robles. Nuevo atributo de la tabla de usuarios
--							para saber si es inspector o no
CREATE OR REPLACE PROCEDURE ADDMOD_USUARIO(
			xMUNICIPIO		IN	CHAR,
			xUSUARIO		IN	CHAR,
			xDNI			IN	CHAR,
			xNOMBRE			IN	CHAR,
			xINSPECTOR		IN	CHAR)
AS

xCUANTOS INTEGER;

BEGIN


	 UPDATE USUARIOSGT SET MUNICIPIO=xMUNICIPIO,
                           DNI=xDNI,
                           NOMBRE=xNOMBRE,
                           INSPECTOR=xINSPECTOR
     WHERE USUARIO=xUSUARIO;
     
     
     IF SQL%NOTFOUND THEN
     
		INSERT INTO USUARIOSGT (MUNICIPIO,USUARIO,DNI,NOMBRE,INSPECTOR)
		VALUES (xMUNICIPIO,xUSUARIO,xDNI,xNOMBRE,xINSPECTOR);
		
		INSERT INTO TMP_AYTOS VALUES (xUSUARIO,xMUNICIPIO);
		
	END IF;
  
	
END;
/


/********************************************************************/
COMMIT;
/********************************************************************/
