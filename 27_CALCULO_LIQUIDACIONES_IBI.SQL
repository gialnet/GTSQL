/*******************************************************************************************/
/*******************************************************************************************/
/***				CÁLCULO DE LIQUIDACIONES DE AÑOS ATRASADOS			     ***/
/*******************************************************************************************/
/*******************************************************************************************/

/*******************************************************************************************
autor: M. Carmen Junco Gómez. 01/02/2002
Función: Actualiza las posibles bonificaciones de los años incluidos en la tabla temporal.
*******************************************************************************************/
CREATE OR REPLACE PROCEDURE ACTUALIZAR_BONIFICACIONES(
		xDESDE	IN	CHAR,	
		xHASTA	IN	CHAR)
AS
     xYEAR	            CHAR(4);
     xBONIFICACION	FLOAT;
     xYEAR_INI_BONI	CHAR(4);
     xMES_INI_BONI	CHAR(2);	
     xYEAR_BONI		CHAR(4);
     xMES_BONI		CHAR(2);
     xMESES             INTEGER;
  
BEGIN

   SELECT trim(MAX(YEAR)) INTO xYEAR FROM TMP_ATRASOS_IBI 
   WHERE BONIFICACION>0 AND USUARIO=UID;

   WHILE ((xDESDE<=xYEAR) AND (xYEAR<=xHASTA)) 
   LOOP
      begin
         SELECT BONIFICACION,YEAR_INI_BONI,YEAR_BONI,MES_INI_BONI,MES_BONI
         INTO xBONIFICACION,xYEAR_INI_BONI,xYEAR_BONI,xMES_INI_BONI,xMES_BONI
         FROM TMP_ATRASOS_IBI 
         WHERE BONIFICACION>0 AND USUARIO=UID AND YEAR=xYEAR;

	   Exception
	      When no_data_found then
	         xBONIFICACION:=0;
	end;
	
      IF xBONIFICACION>0 THEN
	   -- ¿cuantos meses de bonificación le corresponden a este año?
	   IF (xYEAR_INI_BONI < xYEAR) AND (xYEAR < xYEAR_BONI) THEN
	      xMESES:=12;			
	   ELSIF (xYEAR_INI_BONI=xYEAR) THEN
	      xMESES:=12-xMES_INI_BONI;
	   ELSIF (xYEAR=xYEAR_BONI) THEN
	      xMESES:=xMES_BONI;
	   ELSE
		xMESES:=0;
	   END IF;			

	   UPDATE TMP_ATRASOS_IBI SET MESES_BONI=xMESES
	   WHERE USUARIO=UID AND YEAR=xYEAR;

         -- actualizamos la bonificacion de años anteriores hasta llegar
	   -- al año de inicio de la bonificación
	   UPDATE TMP_ATRASOS_IBI SET BONIFICACION=xBONIFICACION,
	  		  		      YEAR_INI_BONI=xYEAR_INI_BONI,
					      MES_INI_BONI=xMES_INI_BONI,
					      YEAR_BONI=xYEAR_BONI,
					      MES_BONI=xMES_BONI
	   WHERE USUARIO=UID AND 
		   xYEAR_INI_BONI<=YEAR AND YEAR<xYEAR;
	END IF;
	xYEAR:=xYEAR-1;

   END LOOP;
END;
/

/*******************************************************************************************
autor: M. Carmen Junco Gómez. 01/02/2002
Función: Procedimiento que inserta en una tabla temporal los datos del recibo para los años
         dentro del intervalo. 
         Se utilizará en el caso de estar liquidando recibos de I.B.I. 
MODIFICADO: 17/05/04. Gloria Maria Calle Hernandez. Cambiado MAX_VALOR_CATASTRAL por MAX_CUOTA
			y añadido CLAVE de bien inmueble (para bienes de caracteristicas especiales).
Modificado: 29/03/2005. Gloria Maria Calle Hernandez. Se tomaba como Año Hasta el año del IBI 
		 del ID dado, y a veces puede ser menor que el hasta. Ahora toma el Año Hasta que es pasado 
		 como parámetro.
Modificacion: 31/03/2005. Gloria Maria Calle Hernandez. Se toma como año hasta el mayor comparandolo
		 con el año del registro minimo para poder realizar los calculos. Antes desde delphi se controlaba
		 que finalmente solo se realizara la liquidacion de los años desde - hasta. Ahora desde el 
		 procedimiento LIQUIDAR_ATRASOS se borran los años incluidos en la tabla tmp_Atrasos que no 
		 se quieren liquidar, si es que hay alguno. (Incluídos sólo por los cálculos).
Modificacion: 17/05/2005. Gloria Maria Calle Hernandez. Se toma como año min (desde) el menor comparandolo
		 con el año del registro y el año de prorrateo si tiene. El año max (hasta) se compara con ambos tb 
		 tomando siempre como max el mayor.
*******************************************************************************************/
CREATE OR REPLACE PROCEDURE RELLENAR_TMP_ATRASOS_IBI(
			xID		IN	INTEGER,
			xDESDE	IN	CHAR,
			xHASTA	IN	CHAR,			
			xYEARP	IN	CHAR,
			xNUMYEARS	IN	INTEGER)
AS
   xAYTO			    	CHAR(3);
   xYEAR					CHAR(4);	
   xYEARMAX					CHAR(4);	
   xYEARMIN					CHAR(4);	
   xREF_CATASTRAL	        CHAR(14);
   xNUMERO_SECUENCIAL       CHAR(4);
   xPRIMER_CARACTER_CONTROL CHAR(1);
   xSEGUN_CARACTER_CONTROL  CHAR(1);
   xNUM_FIJO		    	CHAR(8);   
   xCLAVE					CHAR(1);
   xGRAVAMEN		    	FLOAT;
   xINCREMENTO		    	FLOAT;
   xEXENCION		    	FLOAT;
	
   xVCP			    		FLOAT;
   xBLP			    		FLOAT;

   i 				    	INTEGER;
   xCONTADOR		    	INTEGER; 
   xDIFERENTES		    	CHAR(1);

   -- cursor que recoge los datos que poseamos del abonado con ID=xID para años anteriores,
   -- hasta el año inferior del intervalo de liquidación. 
   CURSOR CIBI IS SELECT * FROM IBI
		          WHERE MUNICIPIO=xAYTO AND REF_CATASTRAL=xREF_CATASTRAL
                    AND NUMERO_SECUENCIAL=xNUMERO_SECUENCIAL 
                    AND PRIMER_CARACTER_CONTROL=xPRIMER_CARACTER_CONTROL
 				    AND SEGUN_CARACTER_CONTROL=xSEGUN_CARACTER_CONTROL 
				    AND YEAR BETWEEN xDESDE AND xYEAR ORDER BY YEAR DESC;

BEGIN

   DELETE FROM TMP_ATRASOS_IBI WHERE USUARIO=UID;

   SELECT MUNICIPIO,YEAR,REF_CATASTRAL,NUMERO_SECUENCIAL,PRIMER_CARACTER_CONTROL,SEGUN_CARACTER_CONTROL 
     INTO xAYTO,xYEAR,xREF_CATASTRAL,xNUMERO_SECUENCIAL,xPRIMER_CARACTER_CONTROL,xSEGUN_CARACTER_CONTROL
     FROM IBI WHERE ID=xID;

   IF (xYEARP<xDESDE) THEN
       xYEARMIN:= xYEARP;
   ELSIF (xYEAR<xDESDE) THEN
       xYEARMIN:= xYEAR;
   ELSE xYEARMIN:= xDESDE;
   END IF;
   
   IF (xHASTA<xYEARP) THEN
       xYEARMAX:= xYEARP;
   ELSIF (xHASTA<xYEAR) THEN
       xYEARMAX:= xYEAR;
   ELSE xYEARMAX:= xHASTA;
   END IF;

   FOR i IN REVERSE TO_NUMBER(xYEARMIN)..TO_NUMBER(xYEARMAX)
   LOOP
      -- Recogemos el gravamen e incremento para cada año.	
      BEGIN      
         SELECT GRAVAMEN,INCREMENTO_VC,MAX_CUOTA INTO xGRAVAMEN,xINCREMENTO,xEXENCION
 	       FROM GRAVAMEN_IBI_RUS G JOIN IBI I ON I.MUNICIPIO=G.MUNICIPIO AND I.YEAR=G.YEAR 
   	       	AND REF_CATASTRAL=xREF_CATASTRAL AND NUMERO_SECUENCIAL=xNUMERO_SECUENCIAL 
            AND PRIMER_CARACTER_CONTROL=xPRIMER_CARACTER_CONTROL AND SEGUN_CARACTER_CONTROL=xSEGUN_CARACTER_CONTROL 
          WHERE G.MODULO='IBI' AND I.MUNICIPIO=xAYTO AND I.YEAR=i
	        AND I.CLAVE_USO=G.CLAVE AND I.VALOR_CATASTRAL>G.MAX_VCATASTRAL;
	  --Si estamos en un año anterior al 2005 o si para dicha clave de uso no supera el valor catastral minimo
	  --la consulta no devolverá gravamen alguno y se buscará el gravamen general para clave nula. 
      EXCEPTION
          WHEN NO_DATA_FOUND THEN
 	         BEGIN 
                SELECT GRAVAMEN,INCREMENTO_VC,MAX_CUOTA INTO xGRAVAMEN,xINCREMENTO,xEXENCION
	              FROM GRAVAMEN_IBI_RUS
                 WHERE MODULO='IBI' AND MUNICIPIO=xAYTO AND YEAR=i AND TRIM(CLAVE) IS NULL;
		     EXCEPTION
			    WHEN NO_DATA_FOUND THEN	 
		   			xGRAVAMEN:=0;
		   			xINCREMENTO:=0;
  		   			xEXENCION:=0;
		     END;
      END;

      -- insertamos en la tabla temporal tantas tuplas como años desde el mayor año
      -- hasta el inicio del intervalo (desde).
      INSERT INTO TMP_ATRASOS_IBI (YEAR,DIFERENTES,GRAVAMEN,INCREMENTO,EXENCION) 
      VALUES (i,'N',xGRAVAMEN,xINCREMENTO,xEXENCION);
      
      -- si el año está en el intervalo (año_prorrateo,año_prorrateo+xNUMYEARS-1)
      -- el VC<>BL; si es menor o mayor supondremos que el VC=BL 
	  IF (i BETWEEN xYEARP AND XYEARP+xNUMYEARS-1) THEN
		UPDATE TMP_ATRASOS_IBI SET DIFERENTES='S' WHERE USUARIO=UID AND YEAR=i;
	  END IF;
	  
   END LOOP;

   
   FOR v_ibi IN CIBI 
   LOOP
      -- ahora actualizamos, si los datos existen en la B.D. de IBI,
      -- el Valor Catastral y la Base Liquidable de los años insertados en la tabla temporal
      UPDATE TMP_ATRASOS_IBI SET VCATASTRAL=v_ibi.VALOR_CATASTRAL,
	   			         		 BLIQUIDABLE=v_ibi.BASE_LIQUIDABLE,
					   			 BONIFICACION=v_ibi.BONIFICACION,
					   			 YEAR_INI_BONI=v_ibi.YEAR_INI_BONI,
					   			 MES_INI_BONI=v_ibi.MES_INI_BONI,
					   			 YEAR_BONI=v_ibi.YEAR_BONI,
					   			 MES_BONI=v_ibi.MES_BONI						     	   				   
	  WHERE USUARIO=UID AND YEAR=v_ibi.YEAR;	
   END LOOP;      

   -- actualizamos las bonificaciones para todos los años dentro del intervalo, ya
   -- que es muy posible que esta información sólo se encuentre en el registro
   -- más actual.
   ACTUALIZAR_BONIFICACIONES(xDESDE,xYEAR);
END;
/



/*******************************************************************************************
autor: M. Carmen Junco Gómez. 01/02/2002
Función: Procedimiento que calcula el total a pagar por un año dependiendo del gravamen
         para ese año y de las posibles bonificaciones.
         Parámetros: xYEAR:  año para el cual se quiere calcular el total a pagar.				         		         
MODIFICACIÓN: 11/12/2002 M. Carmen Junco Gómez. La bonificación se ha de aplicar a cada
	   año independientemente de si en el año actual ésta ha caducado o no.
MODIFICADO: 17/05/04. Gloria Maria Calle Hernandez. Cambiado MAX_VALOR_CATASTRAL por MAX_CUOTA.
*******************************************************************************************/

CREATE OR REPLACE PROCEDURE CALCULAR_TOTAL_YEAR_LIQUI_IBI(
   xYEAR	IN	CHAR)
AS
   xVC			FLOAT;
   xBL			FLOAT;
   xTOTAL		FLOAT;
   xGRAVAMEN	FLOAT;
   xEXENCION	FLOAT;
   xBONIFICACION FLOAT;
   xMESES	    INTEGER;
BEGIN

   -- recoger el gravamen,valor de exención y posibles bonificaciones para xYEAR
   SELECT VCATASTRAL,BLIQUIDABLE,GRAVAMEN,EXENCION,BONIFICACION,MESES_BONI
   INTO xVC,xBL,xGRAVAMEN,xEXENCION,xBONIFICACION,xMESES
   FROM TMP_ATRASOS_IBI
   WHERE USUARIO=UID AND YEAR=xYEAR;

   xTOTAL:=xBL * xGRAVAMEN/100;

   -- aplicar posible bonificación
   IF ((xBONIFICACIOn>0) AND (xMESES>0)) THEN                  
        xTOTAL:=((xTOTAL/12)* xMESES *
                (1-(xBONIFICACION/100))) + ((xTOTAL/12)*(12-xMESES));
   END IF;
  
   xTOTAL:=ROUND(xTOTAL,2);

   -- si está exento (si su cuota es menor o igual al valor de exención, 
   -- entonces el total a pagar por este año será 0
   IF (xTOTAL<xEXENCION) THEN
       xTOTAL:=0;
   END IF;
   
   UPDATE TMP_ATRASOS_IBI SET TOTAL=xTOTAL
   WHERE YEAR=xYEAR AND USUARIO=UID;

END;
/

/*******************************************************************************************
autor: M. Carmen Junco Gómez. 19/09/2002
Función: Procedimiento que calcula el VC y la BL de una año teniendo en cuenta el VC y la
	   BL del año posterior y el % de incremento definido en la tabla de gravámenes		
	   Parámetros: xYEAR: año para el cual se va a calcular el VC y la BL			   
Modificacion: 14/04/2005. Gloria María Calle Hernandez. Sólo actualizará el VCatastral y BLiquidable
		si y sólo si estos son valores nulos. Si tienen valor de un IBI ya cargado en nuestra base de
		datos lo respetará.
Modificacion: 10/05/2005. Gloria María Calle Hernandez. Sólo actualizará el VCatastral y BLiquidable
		si y sólo si estos son valores nulos O SON CERO.
*******************************************************************************************/

CREATE OR REPLACE PROCEDURE CALCULO_BLIQUIDABLE_INCREMENTO(xYEAR	IN	CHAR)
AS
   xVCmax	   	FLOAT;
   xBLmax	   	FLOAT;
   xINCREMENTO 	FLOAT;
   xVC 	   		FLOAT;
   xBL 	   		FLOAT;
BEGIN
   
   -- recoger el % de incremento para xYEAR+1
   SELECT VCATASTRAL,BLIQUIDABLE,INCREMENTO 
   INTO xVCmax,xBLmax,xINCREMENTO FROM TMP_ATRASOS_IBI
   WHERE USUARIO=UID AND YEAR=xYEAR+1;
   
   xVC:=ROUND((xVCmax*100)/(xINCREMENTO+100),2);	
   xBL:=ROUND((xBLmax*100)/(xINCREMENTO+100),2);

   UPDATE TMP_ATRASOS_IBI SET VCATASTRAL=xVC,
				      BLIQUIDABLE=xBL
   WHERE YEAR=xYEAR AND USUARIO=UID AND (VCATASTRAL IS NULL OR VCATASTRAL=0);

END;
/

/*******************************************************************************************
autor: M. Carmen Junco Gómez. 01/02/2002
Función: Procedimiento que calcula el incremento por año de la BL cuando se calcula por prorrateo
	   Parámetros: xYEARP: año de la última ponencia
			   xNUMYEARS: nº de años de prorrateo			   
	   la fórmula que se aplica es la siguiente: 

					   BL2002 - VC2002*(2002-YEARP+1/xNumYears)  
				BL2001= -----------------------------------
						1 - (2002-YEARP+1/xNumYears)

			donde 2000 es el año de la última ponencia, p.e.

			    xINCPRORRATEO: incremento por año
			    xBLP	     : base liquidable del año de ponencia
Modificacion: 14/04/2005. Gloria María Calle Hernandez. Sólo actualizará el VCatastral y BLiquidable
		si y sólo si estos son valores nulos. Si tienen valor de un IBI ya cargado en nuestra base de
		datos lo respetará.
Modificacion: 10/05/2005. Gloria María Calle Hernandez. Sólo actualizará el VCatastral y BLiquidable
		si y sólo si estos son valores nulos O SON CERO.
*******************************************************************************************/

CREATE OR REPLACE PROCEDURE CALCULO_INCREMENTO_PRORRATEO(		
		xYEARP			IN	CHAR,
		xNUMYEARS		IN	INTEGER,
		xINCPRORRATEO	OUT	FLOAT,
		xVCP			OUT   FLOAT,
		xBLP			OUT   FLOAT)
AS
   xYEAR	 CHAR(4);
   xBL	 FLOAT;
   xVC	 FLOAT;
   xBASE	 FLOAT; -- base liquidable de xYEAR+1
   xPARCIAL1 FLOAT;
   xPARCIAL2 FLOAT;
BEGIN

   SELECT trim(MAX(YEAR)) INTO xYEAR 
   FROM TMP_ATRASOS_IBI 
   WHERE DIFERENTES='S' AND VCATASTRAL>0 AND USUARIO=UID;

   -- este año tiene como VC el nuevo valor después de la revisión.
   IF xYEAR>0 THEN
      SELECT VCATASTRAL,BLIQUIDABLE INTO xVCP,xBL
      FROM TMP_ATRASOS_IBI
      WHERE YEAR=xYEAR AND USUARIO=UID;

      -- calculando el VC o BL del año anterior al año de la ponencia, podremos obtener
      -- el incremento anual por prorrateo

      xPARCIAL1:=xVCP * ((xYEAR - xYEARP + 1) / xNUMYEARS);
      xPARCIAL2:=xBL - xPARCIAL1;
      xBASE:=ROUND(xPARCIAL2 / (1 - ((xYEAR - xYEARP + 1) / xNUMYEARS)),2);

      -- el incremento anual será el xNUMYEARS% de la diferencia entre los valores catastrales
      xINCPRORRATEO:=ROUND(((xVCP - xBASE) * xNUMYEARS) / 100,2);

	  -- ya que hemos calculado estos importes, los introducimos en la tabla 'tmp_atrasos_ibi'
      xBLP:=xBASE+xINCPRORRATEO;
	UPDATE TMP_ATRASOS_IBI SET VCATASTRAL=xVCP,
					   BLIQUIDABLE=xBLP
	WHERE YEAR=xYEARP AND USUARIO=UID AND (VCATASTRAL IS NULL OR VCATASTRAL=0);

   ELSE
      xINCPRORRATEO:=0;
   END IF;

END;
/

/*******************************************************************************************
autor: M. Carmen Junco Gómez. 19/09/2002
Función: Procedimiento que calcula la BL de un año con prorrateo partiendo de 
	   la BL del año de ponencia y el valor de incremento anual.
	   Parámetros: xYEAR: año para el cual calculamos el VC y la BL
			   xYEARP: año de la ponencia
			   xVCP: valor catastral del año de ponencia
			   xBLP: base liquidable del año de ponencia			
			   xINCPRORRATEO: incremento anual por prorrateo		   	   
Modificacion: 14/04/2005. Gloria María Calle Hernandez. Sólo actualizará el VCatastral y BLiquidable
		si y sólo si estos son valores nulos. Si tienen valor de un IBI ya cargado en nuestra base de
		datos lo respetará.
Modificacion: 10/05/2005. Gloria María Calle Hernandez. Sólo actualizará el VCatastral y BLiquidable
		si y sólo si estos son valores nulos O SON CERO.
*******************************************************************************************/

CREATE OR REPLACE PROCEDURE CALCULO_BLIQUIDABLE_PRORRATEO(
		xYEAR 	  		IN CHAR,
		xYEARP	  		IN CHAR,
		xVCP		  	IN FLOAT,
		xBLP		  	IN FLOAT,
		xINCPRORRATEO 	IN FLOAT)
AS
BEGIN
   UPDATE TMP_ATRASOS_IBI SET VCATASTRAL=xVCP,
					BLIQUIDABLE=ROUND(xBLP+(xINCPRORRATEO*(xYEAR-xYEARP)),2)
   WHERE YEAR=xYEAR AND USUARIO=UID AND (VCATASTRAL IS NULL OR VCATASTRAL=0);
END;
/

/*******************************************************************************************
autor: M. Carmen Junco Gómez. 01/02/2002
Función: Procedimiento que calcula el valor catastral y la base liquidable para los años
         dentro del intervalo de la liquidación; actualiza los datos de la tabla temporal 
         rellenada por el procedimiento RELLENAR_TMP_ATRASOS_IBI.
         Parámetros:
		xYEARP: Año de la ponencia		
		xDESDE: Límite inferior del intervalo de años
		xANIOS: nº de años que pasan desde una ponencia a otra
 
         Se considera que la Base Liquidable y el Valor Catastral del mayor año 
	  (que es desde el que partimos como referencia) son correctos. 
         A partir de ellos se calcularán el resto de bases liquidables de los años que se van
         a liquidar.

	   Para años que no entran en el prorrateo la fórmula será:
			VC2002=(VC2003*100)/(Incremento+100);
			BL2002=(BL2003*100)/(Incremento+100);
			TOTAL=BL * GRAVAMEN/100 - BONIFICACIONES
	   Para años que entran en el prorrateo la fórmula será:
				BL2002 - VC2002*(2002-YEARP+1/xAnios)  
			BL2001=---------------------------------
						1 - (2002-YEARP+1/xAnios)

			donde 2002 es el año de la última ponencia, p.e.

			BL2003=BL2002+xINCPRORRATEO;

			TOTAL=BL * GRAVAMEN/100 - BONIFICACIONES
Modificacion: 31/03/2005. Gloria Maria Calle Hernandez. Antes desde delphi se controlaba
		 que finalmente solo se realizara la liquidacion de los años desde - hasta aunque para los 
		 cálculos se incluyeran alguno más. Ahora desde el procedimiento LIQUIDAR_ATRASOS se borran 
		 los años incluidos en los que se quiere liquidar si es que hay alguno.		 
*******************************************************************************************/
CREATE OR REPLACE PROCEDURE LIQUIDAR_ATRASOS_IBI(		
			xDESDE	IN	CHAR,
			xHASTA	IN	CHAR,
			xYEARP	IN	CHAR,			
			xANIOS	IN	INTEGER)
AS
	
   xMAX_YEAR	CHAR(4);
   xMIN_YEAR	CHAR(4);
   xBLP			FLOAT;   -- base liquidable del año de ponencia
   xVCP			FLOAT;
   i			CHAR(4);
   xINCPRORRATEO FLOAT;
   xSOLOUNAVEZ	INTEGER;
   xDIFERENTES1 CHAR(1); -- indica si el calculo para este año es por prorrateo o incremento
   xDIFERENTES2 CHAR(1);  

   CURSOR C_YEARS IS SELECT YEAR FROM TMP_ATRASOS_IBI WHERE USUARIO=UID;			

BEGIN

   xSOLOUNAVEZ:=0;

   -- el intervalo de años a tener en cuenta será desde xDESDE hasta el máximo año
   SELECT trim(MAX(YEAR)) INTO xMAX_YEAR FROM TMP_ATRASOS_IBI WHERE USUARIO=UID;
   SELECT trim(MIN(YEAR)) INTO xMIN_YEAR FROM TMP_ATRASOS_IBI WHERE USUARIO=UID;

   -- vamos calculando la BL y el VC para los distintos años partiendo del máximo año, 
   -- que es para el cual conocemos la BL y el VC
   FOR i IN REVERSE TO_NUMBER(xMIN_YEAR)..TO_NUMBER(xMAX_YEAR)-1
   LOOP
      -- tenemos que ver para el año i y el posterior, las siguientes posibles combinaciones:
 	 -- i con prorrateo; i+1 con prorrateo;
	 -- i con prorrateo; i+1 sin prorrateo;
	 -- i sin prorrateo; i+1 con prorrateo;
	 -- i sin prorrateo; i+1 sin prorrateo;
	 begin
	 	SELECT DIFERENTES INTO xDIFERENTES1 FROM TMP_ATRASOS_IBI
	 	WHERE YEAR=i AND USUARIO=UID;
	 exception
	 	when no_data_found then
	 		xDIFERENTES1:=null;
	 end;
	 
	 begin
	 	SELECT DIFERENTES INTO xDIFERENTES2 FROM TMP_ATRASOS_IBI
	 	WHERE YEAR=i+1 AND USUARIO=UID;	
	 exception
	 	when no_data_found then
	 		xDIFERENTES2:=null;
	 end;
	
	 IF ((xDIFERENTES1='S') AND (xDIFERENTES2='S')) THEN	
         IF xSOLOUNAVEZ=0 THEN
	       -- calculamos el incremento anual por prorrateo y la BL del año de ponencia
	       CALCULO_INCREMENTO_PRORRATEO(xYEARP,xANIOS,xINCPRORRATEO,xVCP,xBLP);
	  	   xSOLOUNAVEZ:=1;
	     END IF;
	     CALCULO_BLIQUIDABLE_PRORRATEO(i,xYEARP,xVCP,xBLP,xINCPRORRATEO);
   	 -- si el año i es el último en el que se aplica el prorrateo
	 ELSIF ((xDIFERENTES1='S') AND (xDIFERENTES2='N')) THEN	   
        -- calculamos la BL y el VC del año i a partir de la BL y el VC de i+1 
	    -- y el % de incremento definido en la tabla de gravamenes
	    CALCULO_BLIQUIDABLE_INCREMENTO(i);
	    -- si el año i el el anterior al de aplicación de la revisión
	 ELSIF ((xDIFERENTES1='N') AND (xDIFERENTES2='S')) THEN         
        IF xSOLOUNAVEZ=0 THEN -- calculamos el incremento anual por prorrateo y la BL del año de ponencia
	       CALCULO_INCREMENTO_PRORRATEO(xYEARP,xANIOS,xINCPRORRATEO,xVCP,xBLP);
		   xSOLOUNAVEZ:=1;
	    END IF;
        UPDATE TMP_ATRASOS_IBI SET VCATASTRAL=xBLP-xINCPRORRATEO,
        	BLIQUIDABLE=xBLP-xINCPRORRATEO
	    WHERE YEAR=i AND USUARIO=UID;
	 ELSIF ((xDIFERENTES1='N') AND (xDIFERENTES2='N')) THEN
	    CALCULO_BLIQUIDABLE_INCREMENTO(i);
	 END IF;
   END LOOP;
	

   -- Calculamos el total a pagar por cada año dentro del intervalo
   FOR vYEARS IN C_YEARS
   LOOP
      CALCULAR_TOTAL_YEAR_LIQUI_IBI(vYEARS.YEAR);
   END LOOP;

   -- Borramos los años introducidos para hacer los calculos   
   DELETE TMP_ATRASOS_IBI WHERE USUARIO=UID AND YEAR<xDESDE;
   DELETE TMP_ATRASOS_IBI WHERE USUARIO=UID AND YEAR>xHASTA;
END;
/



/*******************************************************************************************
autor: Gloria Maria Calle Hernandez. 02/03/2005.
Función: Procedimiento que verifica si los gravamenes y % están definidos para cada año 
		 y si tiene el ayuntamiento valores de ultima revision catastral, devolviendo el motivo 
		 del error o warning en su caso para poder visualizarlo desde Delphi.
*******************************************************************************************/
CREATE OR REPLACE FUNCTION VALIDAR_PARAMS_AYTO_IBI (
		xAYTO				IN	VARCHAR2,
		xMOTIVO				OUT VARCHAR2)
RETURN BOOLEAN
AS
	   vLISTA				VARCHAR2(50)	DEFAULT NULL;
	   vYEARP				VARCHAR2(4);
	   vNUMYEAR				INTEGER;
BEGIN
	xMOTIVO:= NULL;
	
	-- Si existe gravamen para cada año de liquidacion
	--Maximo año liquidable atrás en el tiempo = año actual - vNum_Year_Atras, es decir, 4 años atrás
	FOR vYEARS IN (SELECT YEAR FROM TMP_ATRASOS_IBI
       			    WHERE YEAR NOT IN (SELECT distinct YEAR FROM GRAVAMEN_IBI_RUS
       								   WHERE MUNICIPIO=xAYTO AND MODULO='IBI')) LOOP
		vLISTA:= vLISTA||' '||vYEARS.YEAR;
	END LOOP;
	IF vLISTA IS NOT NULL THEN
	   xMOTIVO:= 'PARA LOS AÑOS '||vLISTA||' NO SE HA ESPECIFICADO GRAVAMEN NI % DE '||
	   			 'INCREMENTO PARA EL AYTO '||xAYTO;
	   RETURN FALSE;
	END IF;

	--Primero tiene más peso preguntar si todo Gravamen y % está definido, pues de no ser así no se podría
	--realizar los cálculos. Y de estar bien definidos, comprobamos si el Ayto trabaja con prorrateo, pues 
	--de no trabajar, en lugar de fallar el cálculo simplemente se hace por incremento. Por ello devuelve True.
   	BEGIN
		SELECT YEAR_LAST_PONENCIA,YEARS_PRORRATEO INTO vYEARP,vNUMYEAR FROM DATOSPER
		WHERE MUNICIPIO=xAYTO;
	EXCEPTION
		WHEN NO_DATA_FOUND THEN
			 xMOTIVO:= 'DEBE INDICAR EL AÑO DE LA ULTIMA PONENCIA DE VALORES PARA EL AYTO '||xAYTO;
			 RETURN TRUE;
	END;

	-- Si toda toda comprobacion es correcta
	RETURN TRUE;
END VALIDAR_PARAMS_AYTO_IBI;