/********************************************************************************
Acción: Histórico de lecturas.
********************************************************************************/

CREATE OR REPLACE PROCEDURE HISTO_LECTURAS_ABONADO (
	xID		IN	INTEGER, 
	xFLACTUAL	IN	DATE, 
	xACTUAL	IN	INTEGER,
	xFLANTERIOR IN	DATE,
	xANTERIOR 	IN	INTEGER,
	xLECTURA1 	IN	INTEGER,
      xLECTURA2 	IN	INTEGER,
	xLECTURA3 	IN	INTEGER,
      xLECTURA4 	IN	INTEGER
)
AS

BEGIN
   UPDATE AGUA SET 
	F_L_ACTUAL=xFLActual,ACTUAL=xACTUAL,F_L_ANTERIOR=xFLAnterior,ANTERIOR=xANTERIOR,
	LECTURA1=xLECTURA1,LECTURA2=xLECTURA2,LECTURA3=xLECTURA3,LECTURA4=xLECTURA4
   WHERE ID=xID;

END;
/

/********************************************************************************
Acción: Poner las nuevas lecturas del abonado en la tabla de AGUA.
********************************************************************************/

CREATE OR REPLACE PROCEDURE PUT_LECTURAS_ABONADO (
	xID		IN	INTEGER,
      xFLANTERIOR IN    DATE,
	xFLACTUAL	IN	DATE,
	xINCIDENCIA IN	CHAR,
	xACTUAL 	IN	INTEGER
)
AS
BEGIN

 UPDATE AGUA SET F_L_ACTUAL=xFLActual, F_L_ANTERIOR=xFLAnterior,
	  INCIDENCIA=xINCIDENCIA,ACTUAL=xACTUAL
 WHERE ID=xID;
	
END;
/


--
-- F. Creacion: 27/01/2004. Agustín León Robles. 
--		Me devuelve el numero de dias para hacer el calculo proporcional de las cuotas fijas
--
-- Modificado: 14/03/2005. Lucas Fernández Pérez.
--   Mira una nueva variable de configuración (agua_prorrateo_altas) que indica si el periodo
--   de alta se cobra completo o prorrateado, para devolver el número de días para el calculo.
--   Si es completo, devuelve xDias=xDiasPeriodo. 
--   Si es prorrateado, calcula los días de prorrateo (como lo hacía antes de la modificacion)
--
create or replace procedure PutDatosAguaPeriodos
	(
	xMUNICIPIO		IN		CHAR,
	xYEAR			IN		CHAR,
	xPERIODO		IN		CHAR,
	xFAlta			IN		DATE,
	xDias			OUT		integer,
	xDiasPeriodo	OUT		integer
	)
as
	xPerCobro		char(1);
	xProrrateoAltas	char(1);
	xHasta			date;
begin


	SELECT agua_tipo_periodo, agua_prorrateo_altas into xPerCobro, xProrrateoAltas 
	FROM DATOSPER WHERE MUNICIPIO=xMUNICIPIO;
	
	if xPerCobro='B' then
		xDiasPeriodo:=60;
		if xPeriodo='01' then
			xHasta:=to_date('28/02/'||xYear,'dd/mm/yyyy');
		elsif xPeriodo='02' then
			xHasta:=to_date('30/04/'||xYear,'dd/mm/yyyy');
		elsif xPeriodo='03' then
			xHasta:=to_date('30/06/'||xYear,'dd/mm/yyyy');	
		elsif xPeriodo='04' then
			xHasta:=to_date('31/08/'||xYear,'dd/mm/yyyy');	
		elsif xPeriodo='05' then
			xHasta:=to_date('31/10/'||xYear,'dd/mm/yyyy');	
		elsif xPeriodo='06' then
			xHasta:=to_date('31/12/'||xYear,'dd/mm/yyyy');	
		end if;		
	elsif xPerCobro='T' then
	
		xDiasPeriodo:=90;
		if xPeriodo='01' then
			xHasta:=to_date('31/03/'||xYear,'dd/mm/yyyy');
		elsif xPeriodo='02' then
			xHasta:=to_date('30/06/'||xYear,'dd/mm/yyyy');
		elsif xPeriodo='03' then
			xHasta:=to_date('30/09/'||xYear,'dd/mm/yyyy');	
		elsif xPeriodo='04' then
			xHasta:=to_date('31/12/'||xYear,'dd/mm/yyyy');	
		end if;
				
	elsif xPerCobro='C' then
		xDiasPeriodo:=120;
		if xPeriodo='01' then
			xHasta:=to_date('30/04/'||xYear,'dd/mm/yyyy');
		elsif xPeriodo='02' then
			xHasta:=to_date('31/08/'||xYear,'dd/mm/yyyy');
		elsif xPeriodo='03' then
			xHasta:=to_date('31/12/'||xYear,'dd/mm/yyyy');	
		end if;
	elsif xPerCobro='S' then
		xDiasPeriodo:=180;
		if xPeriodo='01' then
			xHasta:=to_date('30/06/'||xYear,'dd/mm/yyyy');
		elsif xPeriodo='02' then
			xHasta:=to_date('31/12/'||xYear,'dd/mm/yyyy');
		end if;
	else	
		xDiasPeriodo:=365;
		xHasta:=to_date('31/12/'||xYear,'dd/mm/yyyy');
	end if;	
	
	if ((Trunc(xHasta,'dd') - Trunc(xFAlta,'dd')) > xDiasPeriodo) 
			or (xFAlta is null) 
			or (Trunc(xFAlta,'dd')  > Trunc(xHasta,'dd'))
			or (xProrrateoAltas='N') -- Si no hay prorrateo, el número de dias es es del periodo
	          then
		xDias:= xDiasPeriodo;
		
	else
		--numero de dias para hacer el calculo proporcional de las cuotas fijas
		xDias:= Trunc(xHasta,'dd') - Trunc(xFAlta,'dd');
	end if;

end;
/


/********************************************************************************
Acción: Emite los recibos de los abonados.
MODIFICACIÓN: 17/09/2001 Lucas Fernández Pérez. Adaptación al euro.
--
--MODIFICACIÓN: 27/01/2004 Agustín León Robles. 
--			Hace el prorrateo de la cuota fija en funcion de la fecha de alta
--
********************************************************************************/

CREATE OR REPLACE PROCEDURE CALCULA_LINEAS_RECIBO(
	xMUNICIPIO		IN		CHAR,
	xABONADO		IN		INTEGER, 
	xYEAR			IN		CHAR,
	xPERIODO		IN		CHAR,
	xNIF 			IN		CHAR,
	xCONSUMO 		IN		INTEGER, 
	SIGRABA			IN		CHAR,
	xFAlta			IN		DATE,
	xSUMA			OUT		FLOAT,
	xTARIFA_AGUA 	OUT		CHAR,
	xBL_TA 			OUT		CHAR)
AS	
	xTIPO_IVA 	FLOAT;
	xTieneIVA 	CHAR(1);
	xTIPO 		CHAR(2);
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
	
	xDias			integer;
	xDiasPeriodo	integer;
	
	CURSOR C_SERVICIOS IS SELECT * FROM SERVICIOS WHERE ABONADO=xABONADO;
BEGIN	

	xSUMA:=0;
	
	PutDatosAguaPeriodos(xMUNICIPIO,xYEAR,xPERIODO,xFAlta,xDias,xDiasPeriodo);	
	
	-- Selección de todos los servicios de un abonado 
	FOR v_TServicios IN C_SERVICIOS LOOP


		/* Para saber el IVA aplicado a cada de cada Tarifa */
		SELECT IVA,TIPO_IVA,TIPO INTO xTIENEIVA,xTIPO_IVA,xTIPO
		FROM TIPO_TARIFA 
		WHERE municipio=xMunicipio and TIPO=v_TServicios.TIPO_TARIFA;

		
		SELECT BLOQUE1,BLOQUE2,BLOQUE3,BLOQUE4,PRECIO1,PRECIO2,PRECIO3,PRECIO4, 
				FIJO1,FIJO2,FIJO3,FIJO4
		INTO xBLOQUE1,xBLOQUE2,xBLOQUE3,xBLOQUE4,xPRECIO1,xPRECIO2,xPRECIO3,xPRECIO4, 
				xFIJO1,xFIJO2,xFIJO3,xFIJO4
		FROM  TARIFAS_AGUA
		WHERE municipio=xMunicipio AND TARIFA=v_TServicios.TARIFA; 


		/*PARA AVERIGUAR EL CODIGO DE TARIFA DE AGUA, ESTO ES PARA LAS ESTADISTICAS*/
		IF (xTIPO='01') THEN
			xTARIFA_AGUA:=v_TServicios.TARIFA;
			
			IF (xCONSUMO<=xBLOQUE1) THEN
				xBL_TA:='B1';
			END IF;
			IF (xCONSUMO<=xBLOQUE2 AND xCONSUMO>xBLOQUE1) THEN
				xBL_TA:='B2';
			END IF;
			IF (xCONSUMO<=xBLOQUE3 AND xCONSUMO>xBLOQUE2) THEN
				xBL_TA:='B3';
			END IF;
			IF (xCONSUMO<=xBLOQUE4 AND xCONSUMO>xBLOQUE3) THEN
				xBL_TA:='B4';
			END IF;
			
		END IF;

		xIVA:=0;

		/* Importe Fijo. Sin bloques */
		IF (xBLOQUE1=0) THEN
		
			xBASE:=Round( (xFIJO1 * xDias) / xDiasPeriodo , 2);
			
		ELSE
		
			Importes_Calculo_Agua(xCONSUMO, xPRECIO1, xBLOQUE1, xFIJO1,xPRECIO2 ,xBLOQUE2,xFIJO2,
					  xPRECIO3 ,xBLOQUE3,xFIJO3,xPRECIO4 ,xBLOQUE4,xFIJO4,xDiasPeriodo,xDias,xBASE);
					  
		END IF; 

		/* Apunte de la base imponible */

		IF (SIGRABA='S') THEN
			INSERT INTO DESGLOSE_AGUAS
			(ABONADO, YEAR, PERIODO, NIF,TARIFA, IMPORTE,BASE_IVA,MUNICIPIO, TIPO_TARIFA)
			VALUES
			(xABONADO, xYEAR, xPERIODO, xNIF, v_TServicios.TARIFA, xBASE,'B',xMunicipio, xTIPO);
		END IF;

		/* Apunte del iva si tuviera */
	
		IF (xTIENEIVA='S' AND xBase >0) THEN
		
			xIVA:=xBASE*xTIPO_IVA/100;
			
			IF (SIGRABA='S') THEN
				INSERT INTO DESGLOSE_AGUAS
				(ABONADO, YEAR, PERIODO, NIF, TARIFA,IMPORTE,BASE_IVA,MUNICIPIO,TIPO_TARIFA)
				VALUES
				(xABONADO, xYEAR, xPERIODO, xNIF, v_TServicios.TARIFA, ROUND(xIVA,2), 'I',xMUNICIPIO,xTIPO);
			END IF;
			
		END IF;

		xSUMA:=ROUND(xSUMA+xBASE+xIVA,2);

	END LOOP;

END;
/


/* 
   					TIPOS DE TARIFAS PARA LAS LINEAS

   Existen cuatro posibles casos:

	1º). Importe fijo. Sin bloques. Es el caso de la Basura, alcantarillado, canalones ...
	2º). Importe fijo. Con bloques. Por ejemplo:
			Desde un consumo 0-100	 m3	se cobra:  	550  ptas. fijas.
			Desde un consumo 100-200 m3	se cobra:   1750 ptas. fijas.

	3º). Importe variable siempre con bloques.
			Desde un consumo 0-100   m3	se cobra:  25 ptas/m3.
			Desde un consumo 100-200 m3	se cobra:  35 ptas/m3.

		Si el consumo fuese de 150 m3 el resultado sería:
					100 m3 a 25 ptas/m3 = 100*25 = 2500 Ptas.
					50  m3 a 35 ptas/m3 = 50*35  = 1750 Ptas.

								     Total = 4250 Ptas.

	4º). Igual que el 3 pero además con un importe fijo
											
*/


/********************************************************************/
COMMIT;
/********************************************************************/
