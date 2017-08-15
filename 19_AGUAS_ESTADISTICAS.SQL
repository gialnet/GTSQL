/*
UPDATE RECIBOS_AGUA SET BLOQUE_TA="B1" 
WHERE TARIFA_AGUA="0001" AND CONSUMO <=15;

UPDATE RECIBOS_AGUA SET BLOQUE_TA="B2" 
WHERE TARIFA_AGUA="0001" AND CONSUMO BETWEEN 16 AND 32;

UPDATE RECIBOS_AGUA SET BLOQUE_TA="B3" 
WHERE TARIFA_AGUA="0001" AND CONSUMO BETWEEN 33 AND 50;

UPDATE RECIBOS_AGUA SET BLOQUE_TA="B4" 
WHERE TARIFA_AGUA="0001" AND CONSUMO > 50;

UPDATE RECIBOS_AGUA SET BLOQUE_TA="B1" 
WHERE TARIFA_AGUA="0002" AND CONSUMO <=32;

UPDATE RECIBOS_AGUA SET BLOQUE_TA="B2" 
WHERE TARIFA_AGUA="0002" AND CONSUMO BETWEEN 33 AND 64;

UPDATE RECIBOS_AGUA SET BLOQUE_TA="B3" 
WHERE TARIFA_AGUA="0002" AND CONSUMO > 64;

UPDATE RECIBOS_AGUA SET BLOQUE_TA="B1" 
WHERE TARIFA_AGUA="0003" AND CONSUMO <=15;

UPDATE RECIBOS_AGUA SET BLOQUE_TA="B2" 
WHERE TARIFA_AGUA="0003" AND CONSUMO BETWEEN 16 AND 32;

UPDATE RECIBOS_AGUA SET BLOQUE_TA="B3" 
WHERE TARIFA_AGUA="0003" AND CONSUMO BETWEEN 33 AND 50;

UPDATE RECIBOS_AGUA SET BLOQUE_TA="B4" 
WHERE TARIFA_AGUA="0003" AND CONSUMO > 50;

UPDATE RECIBOS_AGUA SET BLOQUE_TA="B1" 
WHERE TARIFA_AGUA="0004" AND CONSUMO <=32;

UPDATE RECIBOS_AGUA SET BLOQUE_TA="B2" 
WHERE TARIFA_AGUA="0004" AND CONSUMO BETWEEN 33 AND 64;

UPDATE RECIBOS_AGUA SET BLOQUE_TA="B3" 
WHERE TARIFA_AGUA="0004" AND CONSUMO > 64;
*/

/*******************************************************************************
Acción: Sólo para poner las tarifas en todos los padrones generados antes de la realización
        de las rutinas de graficos.
*******************************************************************************/

CREATE OR REPLACE PROCEDURE Poner_Tarifas_Agua
AS
	xABONADO INTEGER;
	xTARIFA CHAR(4);
	
	CURSOR CURSOR_PONER_TARIFAS_AGUA IS
	   SELECT ID FROM AGUA;
BEGIN
   OPEN CURSOR_PONER_TARIFAS_AGUA;
   LOOP
	FETCH CURSOR_PONER_TARIFAS_AGUA INTO xABONADO;	
	EXIT WHEN CURSOR_PONER_TARIFAS_AGUA%NOTFOUND;
	xTARIFA:=NULL;

	SELECT TARIFA INTO xTARIFA FROM SERVICIOS 
	WHERE ABONADO=xABONADO AND TIPO_TARIFA='01';

	UPDATE RECIBOS_AGUA SET TARIFA_AGUA=xTARIFA
	WHERE ABONADO=xABONADO;
   END LOOP;
   CLOSE CURSOR_PONER_TARIFAS_AGUA;
END;
/

/*******************************************************************************
Acción: CONVERTIR LOS CONSUMOS EN RANGOS DE 5 EN 5 METROS CUBICOS para poder realizar
	  simulaciones de bloques con facilidad y rapidez.

	Este proceso es un poco lento pero sólo hay que realizarlo una vez.
	Cada vez que se genere un nuevo padrón estos datos se grabarán con cada
	recibo.
*******************************************************************************/

CREATE OR REPLACE PROCEDURE RANGOS_AGUA (
	xYEAR		IN	CHAR
)
AS

	xConsumo	integer;
	xTemp		integer;
	xabonado	integer;
	xperiodo	char(2);

	CURSOR CURSOR_RANGOS_AGUA IS
	   SELECT ABONADO,PERIODO,CONSUMO FROM RECIBOS_AGUA
	   WHERE YEAR=xYEAR;
BEGIN
   OPEN CURSOR_RANGOS_AGUA;
   LOOP
	FETCH CURSOR_RANGOS_AGUA INTO xABONADO,xPERIODO,xCONSUMO;
	EXIT WHEN CURSOR_RANGOS_AGUA%NOTFOUND;
	xTEMP:=(xCONSUMO/5);
	if ((MOD(xCONSUMO,5)<2.5) and (MOD(xConsumo,5)<>0)) then 
  	   xTemp:=xTemp+1;
	END IF;
	xtemp:=xTemp*5;
	if (xTemp>=125) then
	   xTemp:=125;
      END IF;
	update recibos_agua set escalera_consumo=xTemp
	where year=xYear and periodo=xPeriodo and abonado=xAbonado;
   end LOOP;
   CLOSE CURSOR_RANGOS_AGUA;
end;
/

/*******************************************************************************
Acción: Para calcular el importe de los bloques de la tabla de estadisticas 
        es llamado por ESTADISTICAS_AGUA.
MODIFICACIÓN: 18/09/2001 Lucas Fernández Pérez. Adaptación al euro.
*******************************************************************************/

CREATE OR REPLACE PROCEDURE CALCULA_BLOQUES_ESTA (
	xYEAR		IN	CHAR
)
as
	xTarifa char(4);
	xprecio1 float;
	xprecio2 float;
	xprecio3 float;
	xprecio4 float;

	CURSOR CURSOR_CALCULA_BLOQUES_ESTA IS
	   SELECT TARIFA,PRECIO1,PRECIO2,PRECIO3,PRECIO4
	   FROM TARIFAS_AGUA WHERE TIPO_TARIFA='01';
begin
   OPEN CURSOR_CALCULA_BLOQUES_ESTA;
   LOOP
	FETCH CURSOR_CALCULA_BLOQUES_ESTA INTO xTARIFA,xPRECIO1,xPRECIO2,xPRECIO3,xPRECIO4;
      EXIT WHEN CURSOR_CALCULA_BLOQUES_ESTA%NOTFOUND;

	UPDATE ESTADISTICASGT set importe=ROUND(consumo*xPrecio1,2)
	where Year=xYear and Tarifa=xTarifa and Bloque='B1';

  	update estadisticasGT set importe=ROUND(consumo*xPrecio2,2)
	where Year=xYear and Tarifa=xTarifa and Bloque='B2';

	update estadisticasGT set importe=ROUND(consumo*xPrecio3,2)
	where Year=xYear and Tarifa=xTarifa and Bloque='B3';

	update estadisticasGT set importe=ROUND(consumo*xPrecio4,2)
	where Year=xYear and Tarifa=xTarifa and Bloque='B4';
   end LOOP;

   CLOSE CURSOR_CALCULA_BLOQUES_ESTA;
end;
/

/*******************************************************************************
Acción: Rellena la tabla de estadisticas con los datos de:
   	  Domestica Albolote
	  Industrial Albolote
	  Domestica Cubillas
	  Industrial Cubillas
*******************************************************************************/

CREATE OR REPLACE PROCEDURE ESTADISTICAS_AGUA(
	xYEAR 	IN	CHAR
)
AS
	xCONSUMO 	INTEGER;
	xPERI 	CHAR(2);
	xBLOQUE 	CHAR(2);
	xCUANTOS 	INTEGER;

	CURSOR CURSOR_ESTADISTICAS_AGUA1 IS 
	   SELECT SUM(CONSUMO),PERIODO,BLOQUE_TA FROM RECIBOS_AGUA
	   WHERE YEAR=xYEAR AND TARIFA_AGUA='0001'
	   GROUP BY PERIODO,TARIFA_AGUA,BLOQUE_TA;

	CURSOR CURSOR_ESTADISTICAS_AGUA2 IS 
	   SELECT SUM(CONSUMO),PERIODO,BLOQUE_TA FROM RECIBOS_AGUA
	   WHERE YEAR=xYEAR AND TARIFA_AGUA='0002'
	   GROUP BY PERIODO,TARIFA_AGUA,BLOQUE_TA;

	CURSOR CURSOR_ESTADISTICAS_AGUA3 IS 
	   SELECT SUM(CONSUMO),PERIODO,BLOQUE_TA FROM RECIBOS_AGUA
	   WHERE YEAR=xYEAR AND TARIFA_AGUA='0003'
	   GROUP BY PERIODO,TARIFA_AGUA,BLOQUE_TA;

	CURSOR CURSOR_ESTADISTICAS_AGUA4 IS 
	   SELECT SUM(CONSUMO),PERIODO,BLOQUE_TA FROM RECIBOS_AGUA
	   WHERE YEAR=xYEAR AND TARIFA_AGUA='0004'
	   GROUP BY PERIODO,TARIFA_AGUA,BLOQUE_TA;


BEGIN

  delete from estadisticasGT 
  where year=xYear;


/* CONSUMOS AGRUPADOS POR BLOQUES DE LA TARIFA DOMESTICA ALBOLOTE*/
  OPEN CURSOR_ESTADISTICAS_AGUA1;
  LOOP
	FETCH CURSOR_ESTADISTICAS_AGUA1 INTO xCONSUMO,xPERI,xBLOQUE;
	EXIT WHEN CURSOR_ESTADISTICAS_AGUA1%NOTFOUND;
      
	INSERT INTO ESTADISTICASGT
	  (Year,Consumo,TIPO,GRUPO,PERIODO,BLOQUE,TARIFA)
	VALUES
	  (xYear,xConsumo,'DOMESTICA ALBOLOTE','AGUA',xPERI,xBLOQUE,'0001');
  END LOOP;
  CLOSE CURSOR_ESTADISTICAS_AGUA1;

/* CONSUMOS AGRUPADOS POR BLOQUES DE LA TARIFA INDUSTRIAL ALBOLOTE */
  OPEN CURSOR_ESTADISTICAS_AGUA2;
  LOOP
	FETCH CURSOR_ESTADISTICAS_AGUA2 INTO xCONSUMO,xPERI,xBLOQUE;
	EXIT WHEN CURSOR_ESTADISTICAS_AGUA2%NOTFOUND;
      
	INSERT INTO ESTADISTICASGT
	  (Year,Consumo,TIPO,GRUPO,PERIODO,BLOQUE,TARIFA)
	VALUES
	  (xYear,xConsumo,'INDUSTRIAL ALBOLOTE','AGUA',xPERI,xBLOQUE,'0002');
  END LOOP;
  CLOSE CURSOR_ESTADISTICAS_AGUA2;

  OPEN CURSOR_ESTADISTICAS_AGUA3;
  LOOP
	FETCH CURSOR_ESTADISTICAS_AGUA3 INTO xCONSUMO,xPERI,xBLOQUE;
	EXIT WHEN CURSOR_ESTADISTICAS_AGUA3%NOTFOUND;
      
	INSERT INTO ESTADISTICASGT
	  (Year,Consumo,TIPO,GRUPO,PERIODO,BLOQUE,TARIFA)
	VALUES
	  (xYear,xConsumo,'DOMESTICA CUBILLAS','AGUA',xPERI,xBLOQUE,'0003');
  END LOOP;
  CLOSE CURSOR_ESTADISTICAS_AGUA3;

/* CONSUMOS AGRUPADOS POR BLOQUES DE LA TARIFA INDUSTRIAL CUBILLAS*/
  OPEN CURSOR_ESTADISTICAS_AGUA4;
  LOOP
	FETCH CURSOR_ESTADISTICAS_AGUA4 INTO xCONSUMO,xPERI,xBLOQUE;
	EXIT WHEN CURSOR_ESTADISTICAS_AGUA4%NOTFOUND;
      
	INSERT INTO ESTADISTICASGT
	  (Year,Consumo,TIPO,GRUPO,PERIODO,BLOQUE,TARIFA)
	VALUES
	  (xYear,xConsumo,'INDUSTRIAL CUBILLAS','AGUA',xPERI,xBLOQUE,'0004');
  END LOOP;
  CLOSE CURSOR_ESTADISTICAS_AGUA4;
  
  calcula_bloques_esta(xYear);

END;
/

/*******************************************************************************
Acción: Rellena la tabla de config_bloques que es un resumen de los tramos de la facturación
 	  de un año de cinco en cinco metros cúbicos con un máximo de 125 metros cúbicos es
	  decir que todos los tramos superiores a 125 metros se suman con este bloque.
*******************************************************************************/

CREATE OR REPLACE PROCEDURE llena_config_bloques (
	xYear		IN	char
)
AS
	xConsumo 	integer;
	xTarifa 	char(4);
	xTramo 	integer;
	
	CURSOR CURSOR_LLENA_CONFIG_BLOQUES IS 
  	   SELECT SUM(CONSUMO),TARIFA_AGUA,ESCALERA_CONSUMO
	   FROM RECIBOS_AGUA
	   WHERE YEAR=xYEAR 
	   GROUP BY TARIFA_AGUA,ESCALERA_CONSUMO;
begin

  delete from config_bloques 
  where year=xYear;

  OPEN CURSOR_LLENA_CONFIG_BLOQUES;
  LOOP
	FETCH CURSOR_LLENA_CONFIG_BLOQUES INTO xCONSUMO,xTARIFA,xTRAMO;
	EXIT WHEN CURSOR_LLENA_CONFIG_BLOQUES%NOTFOUND;

   	insert into config_bloques 
	  (Year,Tramos,Cuantos,TARIFA)
	values 
	  (xYear,xTramo,xConsumo,xTarifa);
  END LOOP;
  CLOSE CURSOR_LLENA_CONFIG_BLOQUES;
END;
/

/*******************************************************************************
Acción: MEDIAS DE CONSUMO POR BLOQUES DE CADA TARIFA.
*******************************************************************************/

CREATE OR REPLACE PROCEDURE LEER_MEDIAS (
	xYEAR	IN	CHAR
)
AS
	xTARIFA 	CHAR(4);
	xBLOQUE 	CHAR(2);
	xCONSUMO 	INTEGER;

	CURSOR CURSOR_LEER_MEDIAS IS
         SELECT AVG(CONSUMO),TARIFA_AGUA,BLOQUE_TA FROM RECIBOS_AGUA
	   WHERE YEAR=xYEAR GROUP BY TARIFA_AGUA,BLOQUE_TA;
	
BEGIN

   DELETE FROM MEDIAS_AGUAS 
   WHERE YEAR=xYEAR;

   OPEN CURSOR_LEER_MEDIAS;
   LOOP
	FETCH CURSOR_LEER_MEDIAS INTO xCONSUMO,xTARIFA,xBLOQUE;
	EXIT WHEN CURSOR_LEER_MEDIAS%NOTFOUND;

	INSERT INTO MEDIAS_AGUAS 
	   (YEAR,TARIFA,BLOQUE,METROS)
	VALUES 
         (xYEAR,xTARIFA,xBLOQUE,xCONSUMO);
   END LOOP;
   CLOSE CURSOR_LEER_MEDIAS;
END;
/

/*******************************************************************************
Acción: Agrupa tramos en función de los bloques que le pasamos como parametros 
        a la función, teniendo en cuenta también la tarifa correspondiente.
*******************************************************************************/

CREATE OR REPLACE PROCEDURE AGRUPA_BLOQUES (
	xYear 	IN	char,
	xTarifa 	IN	char,
	xInt1 	IN	integer,
	xInt2 	IN	integer,
	xInt3 	IN	integer,
	xInt4 	IN	integer
)
AS
	xTramo	integer;
	CURSOR CURSOR_AGRUPA_BLOQUES IS 
	   SELECT TRAMOS FROM CONFIG_BLOQUES
	   WHERE YEAR=xYEAR AND TARIFA=xTARIFA;

BEGIN
  OPEN CURSOR_AGRUPA_BLOQUES;
  LOOP
	FETCH CURSOR_AGRUPA_BLOQUES INTO xTRAMO;
	EXIT WHEN CURSOR_AGRUPA_BLOQUES%NOTFOUND;
	if (xTramo >=xInt3) then 
	   update config_bloques set bloque='B4' 
	   where tramos=xTramo and year=xYear and Tarifa=xTarifa;
      elsif (xTramo >=xInt2) then
	   update config_bloques set bloque='B3' 
	   where tramos=Xtramo and year=xYear and Tarifa=xTarifa;
  	elsif (xTramo >=xInt1) then
	   update config_bloques set bloque='B2' 
	   where tramos=Xtramo and year=xYear and Tarifa=xTarifa;
  	else
   	   update config_bloques set bloque='B1'
	   where tramos=Xtramo and year=xYear and Tarifa=xTarifa;
	end if;
   end loop;
   close cursor_agrupa_bloques;
end;
/

/*******************************************************************************
Acción: Lee las medias de consumo por bloques de los recibos.
	  Lee del fichero de tarifas todas las de agua.
	  Lee del fichero de Estadisticas el consumo en metros cubicos de cada bloque.
	  Lee del fichero de Medias_Aguas la media de consumo por bloque, tarifa y año.
	  Inserta en precios_bloques los datos leidos anteriormente detallado.
	  ejecuta el procedimeinto agrupa_bloques.
	  Cálcula los importes de cada cada bloque en función de los datos leidos anteriormente.
MODIFICACIÓN: 18/09/2001 Lucas Fernández Pérez. Adaptación al euro.
*******************************************************************************/

CREATE OR REPLACE PROCEDURE RELLENA_PRECIO_BLOQUES (
	xYEAR		IN	char
)
as
	xTarifa 	char(4);
	xbloque1 	integer;
	xbloque2 	integer;
	xbloque3 	integer;
	xbloque4 	integer;
	xprecio1 	float;
	xprecio2 	float;
	xprecio3 	float;
	xprecio4 	float;
	xconsumo 	integer;
	xbloque 	char(2);
	ximporte 	FLOAT;
	xmetros 	integer;
	xMEDIA 	INTEGER;
	
	CURSOR CURSOR_RELLENA_PRECIO_BLOQUES IS
	   SELECT TARIFA,BLOQUE1,BLOQUE2,BLOQUE3,BLOQUE4,PRECIO1,PRECIO2,PRECIO3,PRECIO4
	   FROM TARIFAS_AGUA WHERE TIPO_TARIFA='01';

	CURSOR CURSOR_RELLENA_PRECIO_BLOQUES2 IS
	   SELECT SUM(CUANTOS),BLOQUE,TARIFA FROM CONFIG_BLOQUES
	   WHERE YEAR=xYEAR 
	   GROUP BY BLOQUE,TARIFA;
begin

   LEER_MEDIAS(xYEAR);
   delete from precios_bloques 
   where year=xYear;
 
   OPEN CURSOR_RELLENA_PRECIO_BLOQUES;
   LOOP
	FETCH CURSOR_RELLENA_PRECIO_BLOQUES INTO xTARIFA,xBLOQUE1,xBLOQUE2,xBLOQUE3,xBLOQUE4,
							     xPRECIO1,xPRECIO2,xPRECIO3,xPRECIO4;
	EXIT WHEN CURSOR_RELLENA_PRECIO_BLOQUES%NOTFOUND;

	select sum(consumo) into xMetros from estadisticasGT 
	where year=xYear and tarifa=xTarifa and bloque='B1';

	SELECT METROS INTO  xMEDIA FROM MEDIAS_AGUAS 
	WHERE Year=xYear and Tarifa=xTarifa and Bloque='B1';

	insert into precios_bloques
	   (year,tarifa,intervalo,precio,metros,media_consumo)
      values
	   (xYear,xTarifa,xBloque1,xPrecio1,xMetros,xMEDIA);

	select sum(consumo) into xMetros from estadisticasGT 
	where Year=xYear and Tarifa=xTarifa and Bloque='B2';

  	SELECT METROS INTO xMEDIA FROM MEDIAS_AGUAS 
	WHERE Year=xYear and Tarifa=xTarifa and Bloque='B2';

  	insert into precios_bloques
	   (year,tarifa,intervalo,precio,metros,media_consumo)
      values
	   (xyear,xtarifa,xbloque2,xprecio2,xmetros,xMEDIA);

  	select sum(consumo) into xMetros from estadisticasGT 
	where Year=xYear and Tarifa=xTarifa and Bloque='B3';

	SELECT METROS INTO xMEDIA FROM MEDIAS_AGUAS 
	WHERE Year=xYear and Tarifa=xTarifa and Bloque='B3';

  	insert into precios_bloques
	   (year,tarifa,intervalo,precio,metros,media_consumo)
      values
	   (xYear,xTarifa,xBloque3,xPrecio3,xMetros,xMEDIA);

  	select sum(consumo) into xMetros from estadisticasGT 
	where Year=xYear and Tarifa=xTarifa and Bloque='B4';

	SELECT METROS INTO xMEDIA FROM MEDIAS_AGUAS 
	WHERE Year=xYear and Tarifa=xTarifa and Bloque='B4';

	insert into precios_bloques
	   (year,tarifa,intervalo,precio,metros,media_consumo)
      values
	   (xYear,xTarifa,xBloque4,xPrecio4,xMetros,xMEDIA);

	agrupa_bloques(xYear,xTarifa,xBloque1,xBloque2,xBloque3,xBloque4);

   end loop;
   close cursor_rellena_precio_bloques;

   OPEN CURSOR_RELLENA_PRECIO_BLOQUES2;
   LOOP
	FETCH CURSOR_RELLENA_PRECIO_BLOQUES2 INTO xCONSUMO,xBLOQUE,xTARIFA;
	EXIT WHEN CURSOR_RELLENA_PRECIO_BLOQUES2%NOTFOUND;
	if (xBloque='B1') then 
	   update precios_bloques set importe=ROUND(xConsumo * xPrecio1,2)
	   where Year=xYear and Tarifa=xTarifa and intervalo=xBloque1;
	elsif (xBloque='B2') then 
 	   update precios_bloques set importe=ROUND(xConsumo * xPrecio2,2)
	   where Year=xYear and Tarifa=xTarifa and intervalo=xBloque2;
	elsif (xBloque='B3') then 
 	   update precios_bloques set importe=ROUND(xConsumo * xPrecio3,2)
	   where Year=xYear and tarifa=xTarifa and intervalo=xBloque3;
	elsif (xBloque='B4') then 
 	   update precios_bloques set importe=ROUND(xConsumo * xPrecio4,2)
	   where Year=xYear and Tarifa=xTarifa and intervalo=xBloque4;
	end if;
   end loop;
   close cursor_rellena_precio_bloques2;

end;
/

/*******************************************************************************
Acción: Para calcular la simulación de agrupamiento de bloques
	  inserta tantos registros como hubiera de datos reales
	  para despues agruparlos con los nuevos bloques.
*******************************************************************************/

CREATE OR REPLACE PROCEDURE CALCULA_SIMULACION (
	xYEAR 	IN	CHAR,
	xPRE1 	IN	FLOAT,
	xPRE2 	IN	FLOAT,
	xPRE3 	IN	FLOAT,
	xPRE4 	IN	FLOAT,
	xInt1 	IN	integer,
	xInt2 	IN	integer,
	xInt3 	IN	integer,
	xInt4       IN    integer)
AS
	xTARIFA		CHAR(4);
	xINTERVALO		INTEGER;
	xMETROS		INTEGER;
	xMEDIA_CONSUMO	INTEGER;

	CURSOR CURSOR_CALCULA_SIMULACION IS
	   SELECT TARIFA,INTERVALO,METROS,MEDIA_CONSUMO FROM PRECIOS_BLOQUES
	   WHERE YEAR=xYEAR AND SIMULA='N';

BEGIN

   DELETE FROM PRECIOS_BLOQUES 
   WHERE YEAR=xYEAR AND SIMULA='S';

   OPEN CURSOR_CALCULA_SIMULACION;
   LOOP
	FETCH CURSOR_CALCULA_SIMULACION INTO xTARIFA,xINTERVALO,xMETROS,xMEDIA_CONSUMO;
	EXIT WHEN CURSOR_CALCULA_SIMULACION%NOTFOUND;
	INSERT INTO PRECIOS_BLOQUES
	   (YEAR,TARIFA,INTERVALO,SIMULA,METROS,MEDIA_CONSUMO)
	VALUES
	   (xYEAR,xTARIFA,xINTERVALO,'S',xMETROS,xMEDIA_CONSUMO);
   END LOOP;
   CLOSE CURSOR_CALCULA_SIMULACION;

END;
/


********* ESTA SIN TERMINAR ******************/

/********************************************************************/
COMMIT;
/********************************************************************/
