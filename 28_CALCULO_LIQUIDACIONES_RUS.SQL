/*******************************************************************************************/
/*******************************************************************************************/
/*********			C�LCULO DE LIQUIDACIONES DE A�OS ATRASADOS RUSTICA			     *******/
/*******************************************************************************************/
/*******************************************************************************************/

/*******************************************************************************************
autor: Gloria Maria Calle Hernandez. 02/03/2005
Funci�n: Procedimiento que inserta en una tabla temporal los datos del recibo para los a�os
         dentro del intervalo. Se utilizar� en el caso de estar liquidando recibos de RUSTICA. 
Modificacion: 29/03/2005. Gloria Maria Calle Hernandez. Se tomaba como A�o Hasta el a�o del IBI 
		 del ID dado, y a veces puede ser menor que el hasta. Ahora toma el A�o Hasta que es pasado 
		 como par�metro.
Modificacion: 31/03/2005. Gloria Maria Calle Hernandez. Se toma como a�o hasta el mayor comparandolo
		 con el a�o del registro minimo para poder realizar los calculos. Antes desde delphi se controlaba
		 que finalmente solo se realizara la liquidacion de los a�os desde - hasta. Ahora desde el 
		 procedimiento LIQUIDAR_ATRASOS se borran los a�os incluidos en los que se quiere liquidar 
		 si es que hay alguno.		 
Modificaci�n: 15/05/2006. M. Carmen Junco G�mez. Adaptaci�n al nuevo formato de RUSTICA
*******************************************************************************************/
CREATE OR REPLACE PROCEDURE RELLENAR_TMP_ATRASOS_RUS(			
			xIDPARCELA 	IN  INTEGER,
			xDESDE		IN	CHAR,
			xHASTA		IN	CHAR)
AS
   xAYTO			    	CHAR(3);
   xYEAR					CHAR(4);   
   xREF					CHAR(18);  -- no se consideran los caracteres de control al considerar ciertos clientes que pueden cambiar
   
   xGRAVAMEN		   FLOAT;
   xINCREMENTO		   FLOAT;
   xEXENCION		   FLOAT;
	
   i 				    	INTEGER;      

   CURSOR CPAR IS SELECT * FROM RUS_PARCELAS
		          WHERE MUNICIPIO=xAYTO AND RC_NUM_PARCELA||RC_NUM_SECUENCIAL=xREF 				    
				    AND YEAR BETWEEN xDESDE AND xYEAR ORDER BY YEAR DESC;
BEGIN

   DELETE FROM TMP_ATRASOS_IBI WHERE USUARIO=UID;

   SELECT MUNICIPIO,YEAR,RC_NUM_PARCELA||RC_NUM_SECUENCIAL
	INTO xAYTO,xYEAR,xREF
   FROM RUS_PARCELAS WHERE ID=xIDPARCELA;   

   IF (xYEAR<xHASTA) THEN
       xYEAR:= xHASTA;
   END IF;

   FOR i IN REVERSE TO_NUMBER(xDESDE)..TO_NUMBER(xYEAR)
   LOOP
      -- Recogemos el gravamen e incremento para cada a�o.	
      BEGIN
	     	SELECT GRAVAMEN,INCREMENTO_VC,MAX_CUOTA
         INTO xGRAVAMEN,xINCREMENTO,xEXENCION
 	      FROM GRAVAMEN_IBI_RUS
   	   WHERE MODULO='RUS' AND MUNICIPIO=xAYTO AND YEAR=TO_CHAR(i)
	      AND TRIM(CLAVE) IS NULL;
      EXCEPTION
         WHEN NO_DATA_FOUND THEN
	  			xGRAVAMEN:=0;
		   	xINCREMENTO:=0;
  		   	xEXENCION:=0;
      END;

      -- insertamos en la tabla temporal tantas tuplas como a�os desde el mayor a�o
      -- hasta el inicio del intervalo (desde).
      INSERT INTO TMP_ATRASOS_IBI (YEAR,GRAVAMEN,INCREMENTO,EXENCION) 
      VALUES (TO_CHAR(i),xGRAVAMEN,xINCREMENTO,xEXENCION);

   END LOOP;

   FOR v_PAR IN CPAR 
   LOOP
      UPDATE TMP_ATRASOS_IBI SET COEFICIENTE=v_PAR.COEFICIENTE_PROPIEDAD,
      							    VCATASTRAL=v_PAR.VALOR_CATASTRAL,
					   			    BONIFICACION=v_PAR.VC_BONIFICADO
	   WHERE USUARIO=UID AND YEAR=v_PAR.YEAR;	
   END LOOP;
   
END;
/


/*******************************************************************************************
autor: Gloria Maria Calle Hernandez. 02/03/2005
Funci�n: Procedimiento que calcula el total a pagar por un a�o dependiendo del gravamen
         para ese a�o y de las posibles bonificaciones.
         Par�metros: xYEAR:  a�o para el cual se quiere calcular el total a pagar.		
Modificaci�n: 15/05/2006. M. Carmen Junco G�mez. Adaptaci�n al nuevo formato de RUSTICA
*******************************************************************************************/
CREATE OR REPLACE PROCEDURE CALCULAR_TOTAL_YEAR_LIQUI_RUS
AS
   xVC			 		FLOAT;
   xTOTAL		 		FLOAT;
   xCOEFICIENTE	 	FLOAT;
   xGRAVAMEN	 		FLOAT;
   xEXENCION			FLOAT;
   xBONIFICACION 		FLOAT;
   xBASE_IMPONIBLE 	FLOAT;

   CURSOR CYEARS IS SELECT * FROM TMP_ATRASOS_IBI WHERE USUARIO=UID ORDER BY YEAR;			
BEGIN

   -- recoger el gravamen,valor de exenci�n y posibles bonificaciones para xYEAR
   FOR vYEARS IN cYEARS
   LOOP
      xBASE_IMPONIBLE:=ROUND((xVC * xCOEFICIENTE)/100,2);
		xBASE_IMPONIBLE:=xBASE_IMPONIBLE - xBONIFICACION;
		xBASE_IMPONIBLE:=ROUND((xBASE_IMPONIBLE * xGRAVAMEN)/100,2);	

		xTOTAL:=ROUND(xBASE_IMPONIBLE,2);    	            

      -- si est� exento (si su cuota es menor o igual al valor de exenci�n, 
      -- entonces el total a pagar por este a�o ser� 0
      IF (xTOTAL < xEXENCION) THEN
          xTOTAL:=0;
      END IF;
   
      UPDATE TMP_ATRASOS_IBI SET TOTAL=xTOTAL
      WHERE YEAR=vYEARS.YEAR AND USUARIO=UID;
       
   END LOOP;
END;
/


/*******************************************************************************************
autor: Gloria Maria Calle Hernandez. 02/03/2005
Funci�n: Procedimiento que calcula el VC y la BL de una a�o teniendo en cuenta el VC y la
	   BL del a�o posterior y el % de incremento definido en la tabla de grav�menes		
	   Par�metros: xYEAR: a�o para el cual se va a calcular el VC y la BL			   
*******************************************************************************************/
CREATE OR REPLACE PROCEDURE CALCULO_VC_INCREMENTO_RUS(xYEAR	IN	CHAR, xSUBIR IN BOOLEAN)
AS
   xINCREMENTO 	FLOAT;
   xVC 	   		FLOAT;
BEGIN
   
   IF (xSUBIR) THEN
       
       -- recoger el % de incremento Del a�o posterior para el calculo del VC (HACIA ABAJO)
       SELECT VCATASTRAL,INCREMENTO INTO xVC,xINCREMENTO FROM TMP_ATRASOS_IBI
        WHERE USUARIO=UID AND YEAR=xYEAR+1;
   
       UPDATE TMP_ATRASOS_IBI SET VCATASTRAL=DECODE(VCATASTRAL,0,ROUND((xVC*100)/(xINCREMENTO+100),2),VCATASTRAL),
       							  COEFICIENTE=DECODE(VCATASTRAL,0,100,COEFICIENTE)
        WHERE YEAR=xYEAR AND USUARIO=UID;
        
   ELSE 
       -- recoger el % de incremento del a�o anterior para el calculo del VC (HACIA ARRIBA)
       SELECT VCATASTRAL,INCREMENTO INTO xVC,xINCREMENTO FROM TMP_ATRASOS_IBI
        WHERE USUARIO=UID AND YEAR=xYEAR-1;
   
       UPDATE TMP_ATRASOS_IBI SET VCATASTRAL=DECODE(VCATASTRAL,0,ROUND((xVC*(xINCREMENTO+100))/100,2),VCATASTRAL),
       							  COEFICIENTE=DECODE(VCATASTRAL,0,100,COEFICIENTE)
        WHERE YEAR=xYEAR AND USUARIO=UID;

   END IF;   

END;
/

/*******************************************************************************************
autor: Gloria Maria Calle Hernandez. 02/03/2005
Modificacion: 31/03/2005. Gloria Maria Calle Hernandez. Antes desde delphi se controlaba
		 que finalmente solo se realizara la liquidacion de los a�os desde - hasta aunque para los 
		 c�lculos se incluyeran alguno m�s. Ahora desde el procedimiento LIQUIDAR_ATRASOS se borran 
		 los a�os incluidos en los que se quiere liquidar si es que hay alguno.		 
*******************************************************************************************/
CREATE OR REPLACE PROCEDURE LIQUIDAR_ATRASOS_RUS
AS
   xDESDE		CHAR(4);
   xHASTA		CHAR(4);
   xYEAR		CHAR(4);
   i			CHAR(4);
BEGIN

   -- el intervalo de a�os a tener en cuenta ser� desde el minimo a�o = DESDE 
   -- hasta el m�ximo a�o = HASTA
   BEGIN
      SELECT MAX(YEAR),MIN(YEAR) INTO xHASTA,xDESDE FROM TMP_ATRASOS_IBI 
       WHERE USUARIO=UID;
   EXCEPTION
      WHEN NO_DATA_FOUND THEN
           xHASTA:= '0';
           xDESDE:= '0';
   END;

   -- hayamos el m�ximo a�o con VALOR CATASTRAL 
   BEGIN
      SELECT MAX(YEAR) INTO xYEAR FROM TMP_ATRASOS_IBI 
       WHERE USUARIO=UID AND VCATASTRAL<>0; --siempre ser� cero por defecto
   EXCEPTION
      WHEN NO_DATA_FOUND THEN
           xYEAR:= '0';
   END;

   -- vamos calculando el VC para los distintos a�os partiendo del m�ximo a�o 
   -- para el cual conocemos el VC
   FOR i IN REVERSE TO_NUMBER(xYEAR-1)..TO_NUMBER(xDESDE) 
   LOOP
      CALCULO_VC_INCREMENTO_RUS(i,TRUE);
   END LOOP;

   FOR i IN REVERSE TO_NUMBER(xYEAR+1)..TO_NUMBER(xHASTA) 
   LOOP
      CALCULO_VC_INCREMENTO_RUS(i,FALSE);
   END LOOP;

   -- Calculamos los TOTALES a pagar por cada a�o dentro del intervalo
   CALCULAR_TOTAL_YEAR_LIQUI_RUS;

   -- Borramos los a�os introducidos para hacer los calculos   
   DELETE TMP_ATRASOS_IBI WHERE USUARIO=UID AND YEAR>xHASTA;

END;
/


/*******************************************************************************************
autor: Gloria Maria Calle Hernandez. 02/03/2005.
Funci�n: Procedimiento que verifica si los gravamenes y % est�n definidos para cada a�o 
		 y si tiene el ayuntamiento valores de ultima revision catastral, devolviendo el motivo 
		 del error o warning en su caso para poder visualizarlo desde Delphi.
*******************************************************************************************/
CREATE OR REPLACE FUNCTION VALIDAR_PARAMS_AYTO_RUS (
		xAYTO				IN	VARCHAR2,
		xMOTIVO				OUT VARCHAR2)
RETURN BOOLEAN
AS
	   vLISTA				VARCHAR2(50)	DEFAULT NULL;
	   vYEARP				VARCHAR2(4);
	   vNUMYEAR				INTEGER;
BEGIN
	xMOTIVO:= NULL;
	
	-- Si existe gravamen para cada a�o de liquidacion
	-- Maximo a�o liquidable atr�s en el tiempo = a�o actual - vNum_Year_Atras, es decir, 4 a�os atr�s
	FOR vYEARS IN (SELECT YEAR FROM TMP_ATRASOS_IBI
       			    WHERE YEAR NOT IN (SELECT distinct YEAR FROM GRAVAMEN_IBI_RUS
       								   WHERE MUNICIPIO=xAYTO AND MODULO='RUS')) LOOP
		vLISTA:= vLISTA||' '||vYEARS.YEAR;
	END LOOP;
	IF vLISTA IS NOT NULL THEN
	   xMOTIVO:= 'PARA LOS A�OS '||vLISTA||' NO SE HA ESPECIFICADO GRAVAMEN NI % DE '||
	   			 'INCREMENTO PARA EL AYTO '||xAYTO;
	   RETURN FALSE;
	END IF;

	-- Si toda toda comprobacion es correcta
	RETURN TRUE;
END VALIDAR_PARAMS_AYTO_RUS;
