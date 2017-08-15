CREATE OR REPLACE PROCEDURE agustin_GEN_IAE(
	xMUNICIPIO 	IN CHAR,
	xYEAR 		IN CHAR,
	xDESDE 		IN DATE,
	xHASTA 		IN DATE,
	xCARGO 		IN DATE,
	xCONCEPTO 	IN CHAR,
	xLINEA1 	IN CHAR,
	xLINEA2 	IN CHAR,
	xLINEA3 	IN CHAR,
	xPERIODO 	IN CHAR)
AS
     -- domicilio fiscal
     xDomiFiscal		 varchar(50);

     xCODIGO_POSTAL      CHAR(5);
     xPOBLACION          varchar2(35);
     xPROVINCIA          varchar2(35);
     xProvincia_Tri	 	 varchar2(35);
     xIndCalleLAfecto	 CHAR(4);

     xINDICE_CALLE       FLOAT;
     xCUOTA_MINIMA       FLOAT;
     xCUOTA_BONI         FLOAT;
     xCOEFI_INCREMENTO   FLOAT;
     xCUOTA_INCRE        FLOAT;
     xCUOTA_MUNI         FLOAT;
     xRECARGO            FLOAT;
     xCUOTA_MAQUINA      FLOAT;
     xIMPORTE_MINIMO     FLOAT;
     xTOTAL              FLOAT;
     xNOMBRE_TITULAR     VARCHAR(40);
     xDCONTROL           VARCHAR(2);
     xDIG_C60_M2         CHAR(2);
     xREFERENCIA         CHAR(10);
     xIMPORTE_CAD        CHAR(12);
     xTEMP               CHAR(1);
     xCONCEPLiqui        CHAR(6);
     xANUAL              INTEGER;
     xRECIBO             INTEGER DEFAULT 0;
     xPADRON		 	 CHAR(6);
     xEMISOR 	    	 CHAR(6);
     xTRIBUTO 	    	 CHAR(3);
     xTRIMINICIO		 INTEGER;

CURSOR CRECIBO IS SELECT * FROM IAE
		WHERE MUNICIPIO=xMUNICIPIO AND YEAR='2004' AND PERIODO=xPERIODO
							AND EN_PADRON='S' and COD_EXENCION IN (5,6,7);
BEGIN

   -- Sólo la primera vez
   SELECT CONCEPTO,LIQUIDACION INTO xPADRON,xCONCEPLiqui FROM PROGRAMAS WHERE PROGRAMA='IAE';

   -- Para ver qué hay que hacer:
   -- 0  RECIBOS Y LIQUIDACIONES
   -- 1  SOLO RECIBOS
   -- 2  SOLO LIQUIDACIONES
   SELECT IAE_CONF_PERIODOS_TRI INTO xTEMP FROM DATOSPER WHERE MUNICIPIO=xMUNICIPIO;

   --recoger los datos para el cuaderno 60
   BEGIN
	select EMISORA,CONCEPTO_BANCO into xEMISOR,xTRIBUTO from RELA_APLI_BANCOS
			where AYTO=xMUNICIPIO and CONCEPTO=xPADRON;
   EXCEPTION
		when no_data_found then
			BEGIN
			xEMISOR:='000000';
			xTRIBUTO:='000';
			END;
   END;

   FOR v_TIAE IN CRECIBO
   LOOP

 	  xCUOTA_MAQUINA:= v_TIAE.CUOTA_MAQUINA;
	  xCUOTA_MINIMA:= v_TIAE.IMPORTE_MINIMO;

	  --EL NUMERO DE RECIBO VA A SER EL ID DE LA TABLA DE REFERENCIAS_BANCOS 
      SELECT ID INTO xRECIBO FROM REFERENCIAS_BANCOS WHERE MUNICIPIO=xMUNICIPIO
			AND YEAR='2004' AND PERIODO=xPERIODO AND REFERENCIA_IAE=v_TIAE.REFERENCIA;


      IF (v_TIAE.DOMICILIADO='N') THEN
          xNOMBRE_TITULAR:=NULL;
      ELSE
	    --nombre del titular de la cuenta, para el cuaderno 19 
         SELECT NOMBRE INTO xNOMBRE_TITULAR FROM CONTRIBUYENTES WHERE NIF=v_TIAE.DNI_FACTURA;
      END IF;


	  xDomiFiscal:=v_TIAE.VIA||' '||v_TIAE.CALLE||' '||v_TIAE.NUMERO||' '||
			v_TIAE.LETRA||' '||v_TIAE.ESCALERA||' '||v_TIAE.PISO||' '||v_TIAE.PUERTA;

	  BEGIN
		--buscamos la provincia del codigo postal de la actividad
        IF RTRIM(v_TIAE.CALLE_LOCAL) IS NULL THEN
		  SELECT PROVINCIA INTO xProvincia_Tri FROM COD_PROVINCIAS
		  WHERE CODPROV=SUBSTR(v_TIAE.COD_POSTAL_ACTIVI,1,2);
		ELSE
		   SELECT PROVINCIA INTO xProvincia_Tri FROM COD_PROVINCIAS
		   WHERE CODPROV=SUBSTR(v_TIAE.COD_POSTAL_LOCAL,1,2);
		END IF;
	  EXCEPTION
		 when no_data_found then
			xProvincia_Tri:=NULL;
	  END;

	  --domicilio fiscal en funcion de si tiene un representante o no.
	  --Dentro de la funcion "GetDomicilioFiscal" se comprueba si tiene a su vez
	  --un domicilio alternativo.
	  IF v_TIAE.REPRESENTANTE IS NULL THEN

		 --En el IAE hay una variante ya que si no tiene representante y tampoco
		 --domicilios alternativos entonces se tiene que coger los datos de la propia
		 --tabla de IAE y no de contribuyentes.
		 IF v_TIAE.IDDOMIALTER IS NULL THEN
			--xDomiFiscal ya estaria con datos
			xPoblacion:=v_TIAE.MUNICIPIO_FISCAL;
			xCODIGO_POSTAL:=v_TIAE.CODIGO_POSTAL;

			BEGIN
				SELECT PROVINCIA INTO xProvincia FROM COD_PROVINCIAS
					WHERE CODPROV=SUBSTR(v_TIAE.CODIGO_POSTAL,1,2);
			EXCEPTION
				when no_data_found then
					xProvincia:=NULL;
			END;
		 ELSE
			GetDomicilioFiscal(v_TIAE.NIF,v_TIAE.IDDOMIALTER,
					xDomiFiscal,xPoblacion,xProvincia,xCODIGO_POSTAL);
		 END IF;
  	  ELSE
		 GetDomicilioFiscal(v_TIAE.REPRESENTANTE,v_TIAE.IDDOMIALTER,
				xDomiFiscal,xPoblacion,xProvincia,xCODIGO_POSTAL);
	  END IF;

      -- inicializamos valores
      xCUOTA_INCRE:=0;
      xRECARGO:=0;
      xIMPORTE_MINIMO:=0;
      xANUAL:=0;

      --Calculamos indice diferenciando si tiene calle local afecto o en su defecto calle actividad
      IF RTRIM(v_TIAE.CALLE_LOCAL) IS NULL THEN
         -- Vemos el índice de situación de la calle, y el coeficiente de incremento y recargo
         CALCULA_INDICE_CALLE(xMUNICIPIO, '2005', v_TIAE.CODIGO_VIA, v_TIAE.NUMERO_ACTIVI,
	   			              xINDICE_CALLE, xCOEFI_INCREMENTO, xRECARGO);
      ELSE
         BEGIN
		    --Buscamos codigo de la calle 
		    SELECT CODIGO_CALLE INTO xIndCalleLAfecto FROM CALLES 
			WHERE RTRIM(CALLE)=RTRIM(v_TIAE.CALLE_LOCAL) AND ROWNUM=1;
	     EXCEPTION
		    when no_data_found then
			   xIndCalleLAfecto:=NULL;
	     END;
	         
         -- Vemos el índice de situación de la calle, y el coeficiente de incremento y recargo
         CALCULA_INDICE_CALLE(xMUNICIPIO, '2005', xIndCalleLAfecto, v_TIAE.NUMERO_LOCAL,
	   			              xINDICE_CALLE, xCOEFI_INCREMENTO, xRECARGO);
	  END IF;

	  
      IF xINDICE_CALLE IS NULL THEN
     	  xINDICE_CALLE:=1;  -- Valor por defecto del índice de calle
      END IF;

      -- Se busca en los epígrafes de sólo cálculo anual
      SELECT COUNT(*) INTO xANUAL FROM IAE_EPIGRAFE
			WHERE EPIGRAFE=v_TIAE.EPIGRAFE AND SECCION=v_TIAE.SECCION;

      -- Epígrafes con W en el campo tipo de operación sólo liquidación anual según Salobreña y Torrejón.
      -- Si el Epígrafe está entonces se hace cálculo anual siempre

      IF (v_TIAE.TIPO_REGISTRO='S' OR xANUAL>0) THEN
    	   xANUAL:=1;
    	   xIMPORTE_MINIMO:=xCUOTA_MINIMA;
      END IF;

	  -- Si se ha dado de baja debemos comprobar hasta que trimestre
      --  del año en el que se da de baja la actividad se ha de pagar
      IF v_TIAE.F_BAJA IS NOT NULL THEN

         COMPRUEBA_BAJA(xPERIODO,
				v_TIAE.F_BAJA,
				v_TIAE.FECHA_INICIO_ACTI,
				xIMPORTE_MINIMO,
				xCUOTA_MINIMA,
				xCUOTA_MAQUINA);

      ELSE  -- No se ha dado de baja
      
      	-- si el año de inicio de la actividad es anterior al que estamos generando
      	-- se hará un cálculo anual.
      	-- si la fecha de inicio de la actividad no encuadra con el trimestre que estamos generando
      	-- se calculará el importe según el trimestre de la fecha de inicio

        IF (xANUAL=0) THEN -- si no es anual calculamos los importes según periodos
        
           IF ((F_YEAR(v_TIAE.FECHA_INICIO_ACTI) < '2005' ) OR (xPERIODO='00') OR (xPERIODO='01')) THEN
           		xTRIMINICIO:='00';
           ELSE
     	   		xTRIMINICIO:='0'||QUARTER(v_TIAE.FECHA_INICIO_ACTI);   	        
     	   END IF;
        
           IF (xTRIMINICIO='00') OR (xTRIMINICIO='01') THEN
              xIMPORTE_MINIMO:=xCUOTA_MINIMA;
           ELSIF (xTRIMINICIO='02') THEN
	       	  xIMPORTE_MINIMO:=(xCUOTA_MINIMA*3)/4;
	          xCUOTA_MAQUINA:=(xCUOTA_MAQUINA*3)/4;
           ELSIF (xTRIMINICIO='03') THEN
              xIMPORTE_MINIMO:=xCUOTA_MINIMA/2;
 	          xCUOTA_MAQUINA:=xCUOTA_MAQUINA/2;
           ELSIF (xTRIMINICIO='04') THEN
	          xIMPORTE_MINIMO:=xCUOTA_MINIMA/4;
   	          xCUOTA_MAQUINA:=xCUOTA_MAQUINA/4;
	       END IF;
        END IF;
      END IF;

      -- Se aplica bonificación, si procede
      IAE_BONIFICACION(TO_NUMBER(v_TIAE.BENEFICIOS_PORCEN),v_TIAE.FECHA_LIMITE_BENE,
				xIMPORTE_MINIMO,xCUOTA_MAQUINA,xCUOTA_BONI);

	  xIMPORTE_MINIMO:=Round(xIMPORTE_MINIMO,2);
	  xCUOTA_MAQUINA:=Round(xCUOTA_MAQUINA,2);
	  xCUOTA_BONI:=Round(xCUOTA_BONI,2);

	  -- Cuota incrementada: cuota de tarifa con maquina * coeficiente de incremento
      xCUOTA_INCRE:=Round((xCUOTA_BONI * v_TIAE.COEF_PONDERACION),2);

	  --Cuota municipal:
      --(Cuota tarifa sin maquina * coeficiente de ponderacion) * indice de situacion +
      --cuota maquina * coeficiente de ponderacion
	  xCUOTA_MUNI:=Round((((xCUOTA_BONI-xCUOTA_MAQUINA) * v_TIAE.COEF_PONDERACION) * 
	             xINDICE_CALLE + (xCUOTA_MAQUINA * v_TIAE.COEF_PONDERACION)),2);

	  -- Recargo 40%: la cuota tarifa que ya tiene la cuota maquina incluida * 40%
	  xRECARGO:=Round(((xCUOTA_BONI * v_TIAE.COEF_PONDERACION) * xRECARGO * 0.01),2);

	  -- Total a pagar
      xTOTAL:=Round((xRECARGO+ xCUOTA_MUNI),2);

	  -- Cálculo de los dígitos de control para la Emisora
      CALCULA_DC_60(xTotal,xRECIBO,xTRIBUTO,SUBSTR('2005',3,2),xPeriodo,xEMISOR,xDCONTROL);

	  --calcular los digitos de control del cuaderno 60 modalidad 2
	  CALCULA_DC_MODALIDAD2_60(xTotal, xRECIBO, xTRIBUTO, SUBSTR('2005',3,2), '1',
			to_char(xHASTA,'y'), to_char(xHASTA,'ddd'), xEMISOR, xDIG_C60_M2);

      -- Convierte el número de recibo a carácteres y rellena de ceros
      GETREFERENCIA(xRECIBO,xREFERENCIA);

      -- Importe a pagar expresado en caracteres
      IMPORTEENCADENA(xTotal,xIMPORTE_CAD);

	  --insertamos los cotitulares del recibo
	  

      IF (xTEMP='0' OR xTEMP='1' OR xPERIODO='00') THEN
		if xTOTAL>0 then
 		   INSERT INTO RECIBOS_IAE (Recibo,ABONADO,REFE,YEAR,PERIODO,MUNICIPIO,
 			 NIF,NOMBRE,DOMICILIO,CODIGO_POSTAL,POBLACION,PROVINCIA,
			 --DOM. TRIBUTARIO
			 CODIGO_VIA,CALLE,ESCALERA,PLANTA,PUERTA,NUMERO,
			 CODPOSTAL_TRI,POBLACION_TRI,PROVINCIA_TRI,
			 ID_EPIGRAFE,EPIGRAFE,SECCION,
			 CUOTA_PERIODO,PORCENT_BENE,CUOTA_MINIMA,
             CUOTA_BONI,CUOTA_INCRE,CUOTA_MUNI,RECARGO,CUOTA_MAQUINA,
			 TIPO_MUNICIPIO,SUPERFICIE_DECLARADA,SUPERFICIE_RECTIFICADA,
			 SUPERFICIE_COMPUTABLE,YEAR_INICIO,FECHA_LIMITE,TIPO_ACTIVIDAD,IMPORTE,TOTAL,
			 DOMICILIADO,ESTADO_BANCO,
			 ENTIDAD,SUCURSAL,DC,CUENTA,F_DOMICILIACION,TITULAR,NOMBRE_TITULAR,
			 DESDE,HASTA,F_CARGO,CONCEPTO,LINEA1,LINEA2,LINEA3,EMISOR,TRIBUTO,EJERCICIO,
			 REMESA,REFERENCIA,DIGITO_CONTROL,
			 DISCRI_PERIODO,DIGITO_YEAR,F_JULIANA,DIGITO_C60_MODALIDAD2)
      	   VALUES
             (xRecibo,v_TIAE.ID,v_TIAE.REFERENCIA,'2005',xPeriodo,xMUNICIPIO,
			  v_TIAE.NIF,v_TIAE.NOMBRE,xDomiFiscal,xCODIGO_POSTAL,xPOBLACION,xPROVINCIA,
			  --DOM. TRIBUTARIO
              DECODE(RTRIM(v_TIAE.CALLE_LOCAL),NULL,v_TIAE.CODIGO_VIA,xIndCalleLAfecto),
              DECODE(RTRIM(v_TIAE.CALLE_LOCAL),NULL,v_TIAE.CALLE_ACTIVIDAD,v_TIAE.CALLE_LOCAL),
              DECODE(RTRIM(v_TIAE.CALLE_LOCAL),NULL,v_TIAE.ESCALERA_ACTIVI,v_TIAE.ESCALERA_LOCAL),
              DECODE(RTRIM(v_TIAE.CALLE_LOCAL),NULL,v_TIAE.PISO_ACTIVI,v_TIAE.PISO_LOCAL),
              DECODE(RTRIM(v_TIAE.CALLE_LOCAL),NULL,v_TIAE.PUERTA_ACTIVI,v_TIAE.PUERTA_LOCAL),
              DECODE(RTRIM(v_TIAE.CALLE_LOCAL),NULL,v_TIAE.NUMERO_ACTIVI,v_TIAE.NUMERO_LOCAL),
              DECODE(RTRIM(v_TIAE.CALLE_LOCAL),NULL,v_TIAE.COD_POSTAL_ACTIVI,v_TIAE.COD_POSTAL_LOCAL),
              DECODE(RTRIM(v_TIAE.CALLE_LOCAL),NULL,v_TIAE.MUNICIPIO_ACTIVI,v_TIAE.MUNICIPIO_LOCAL),
			  xProvincia_Tri,v_TIAE.ID_EPIGRAFE,v_TIAE.EPIGRAFE,v_TIAE.SECCION,
			  xIMPORTE_MINIMO,TO_NUMBER(v_TIAE.BENEFICIOS_PORCEN),xCUOTA_MINIMA,
			  xCUOTA_BONI,xCUOTA_INCRE,xCUOTA_MUNI,xRECARGO,xCUOTA_MAQUINA,
			  xINDICE_CALLE,v_TIAE.SUPERFICIE_DECLARADA,v_TIAE.SUPERFICIE_RECTIFICADA,
              v_TIAE.SUPERFICIE_COMPUTABLE,v_TIAE.YEAR_INICIO_ACTI,
			  v_TIAE.FECHA_LIMITE_BENE,v_TIAE.TIPO_ACTIVIDAD,xIMPORTE_CAD,xTOTAL,
			  v_TIAE.DOMICILIADO,DECODE(v_TIAE.DOMICILIADO,'S','EB',NULL),
			  DECODE(v_TIAE.DOMICILIADO,'S',v_TIAE.ENTIDAD,NULL),
			  DECODE(v_TIAE.DOMICILIADO,'S',v_TIAE.SUCURSAL,NULL),
			  DECODE(v_TIAE.DOMICILIADO,'S',v_TIAE.DC,NULL),
			  DECODE(v_TIAE.DOMICILIADO,'S',v_TIAE.CUENTA,NULL),
			  DECODE(v_TIAE.DOMICILIADO,'S',v_TIAE.F_DOMICILIACION,NULL),
			  DECODE(v_TIAE.DOMICILIADO,'S',v_TIAE.DNI_FACTURA,NULL),
              xNOMBRE_TITULAR,xDESDE,xHASTA,xCARGO,xCONCEPTO,
     		  xLINEA1,xLINEA2,xLINEA3,xEMISOR,xTRIBUTO,SUBSTR('2005',3,2),xPeriodo,
			  xREFERENCIA,xDCONTROL,'1',to_char(xHASTA,'y'), to_char(xHASTA,'ddd'),xDIG_C60_M2);
		 end if;

	  END IF;


	  

   END LOOP;
   

END;
/




--
-- Cambiar los importes de las tarifas de de un determinado concento
--

CREATE OR REPLACE PROCEDURE ExacTarifaExchg(
	xAyto IN Char,
	xConcepto IN Char)
AS

xIMPORTE 	FLOAT;
xIVA		FLOAT;
xTOTAL	FLOAT;
-- Todas las exacciones de un ayuntamiento y concepto u ordenanza

CURSOR cExac IS SELECT * FROM EXACCIONES
	WHERE MUNICIPIO=xAyto
	AND COD_ORDENANZA=xConcepto
	FOR UPDATE OF BASE,TOTAL;

BEGIN

--


FOR v_cExac IN cExac LOOP

	SELECT TO_NUMBER(FORMULA),TIPO_IVA INTO xIMPORTE,xIVA FROM TARIFAS_CONCEPTOS
		WHERE AYTO=xAyto
		AND CONCEPTO=xConcepto
		AND COD_TARIFA=v_cExac.COD_TARIFA;

	xTOTAL:=xIMPORTE-ROUND(xIMPORTE*(v_cExac.POR_BONIFICACION/100),2);
	xTOTAL:=xTOTAL+ROUND(xTOTAL*(xIVA/100),2);

	Update EXACCIONES SET BASE=xIMPORTE,TOTAL=xTOTAL
		where current of cExac;

END LOOP;

END;
/
