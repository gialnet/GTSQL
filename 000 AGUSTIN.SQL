CREATE OR REPLACE PROCEDURE agustinCargarAuto(xNADA IN INTEGER)
AS
	xSALIDA 			INTEGER;
	xNombreProvincia	varchar2(35);
	xReg	 			CONTRIBUYENTES%ROWTYPE;
	xRegTrafico			TRAFICO_NEW%ROWTYPE;
	xConcepto			Char(6);
	xCOD_TARIFA			CHAR(5);
	xTARIFA				FLOAT;
	xImporte 			FLOAT;
	xNUMERO				CHAR(7);
	xID					INTEGER;
	mDNI				CHAR(9);
   
	CURSOR cLiqui IS Select * From TMP_LISTACARGOS where USUARIO=user;
	
	CURSOR cAutos IS SELECT * FROM TRAFICO_NEW 
			WHERE ID IN (SELECT id_trafico FROM TMP_INCIDENCIAS_TRAFICO WHERE marca_error='4') ORDER BY matricula
				ORDER BY FECHA_TRAMITE,HORA,tipo_registro desc;
BEGIN

	Delete from TMP_C60 where Usuario=UID;
	Delete From TMP_LISTACARGOS where USUARIO=user;
	--
	-- Intentamos cargar el resto de registros
	--		
	FOR vAUTOS IN CAUTOS LOOP
		CargarRegistroTrafico(vAUTOS.ID,xSALIDA);
	END LOOP;
	
	--
	--Por ultimo aquellos movimientos del año anterior hay que generarle una liquidacion,
	--serán los registros de la tabla temporal TMP_LISTACARGOS 
	--
	FOR vLiqui IN cLiqui LOOP
	
		Select * into xRegTrafico from Trafico_NEW where ID=vLiqui.SesionID;
	
		select liquidacion into xConcepto from programas WHERE programa='VEHICULOS';
		
		DAMETARIFAVEHICULO(xRegTrafico.Ayto,xRegTrafico.TIPO_VEHICULO,xRegTrafico.POTENCIA,xRegTrafico.CILINDRADA,
	     							xRegTrafico.CARGA,xRegTrafico.PLAZAS,xTARIFA,xCOD_TARIFA);
	     	
		Select Importe into xImporte FROM TARIFAS_VEHICULOS 
		WHERE MUNICIPIO=xRegTrafico.Ayto AND CODIGO=xCOD_TARIFA AND ANNE=TO_CHAR(SYSDATE,'YYYY');
		
		ADD_LIQUI(xRegTrafico.Ayto,xConcepto,to_char(sysdate,'yyyy'),'00',to_char(sysdate,'yyyy'),
				xRegTrafico.DNI,NULL,NULL,sysdate,GetFinPeVol(xRegTrafico.Ayto),xImporte,'LIQUIDACION CON MOTIVO DEL ALTA DEL VEHICULO MARCA: '||
				xRegTrafico.MARCA_MODELO||' BASTIDOR: '||xRegTrafico.BASTIDOR||' Y MATRICULA: '||xRegTrafico.MATRICULA||
				' PROVENIENTE DE LA INFORMACIÓN DE TRAFICO',NULL,NULL,NULL,NULL,NULL,xNUMERO,xID);
				
		Update Trafico_New set Genera_Liquidacion='S' where ID=vLiqui.SesionID;
		
	END LOOP;
	
END;
/


create or replace function agustinmatriculas(xMatricula in varchar2)
return char
as
	xABONADO 		INTEGER;
	xNIF     		CHAR(10);
	
	xCIUDAD  		CHAR(3);
	xNUMERO  		CHAR(6);
	xLETRAS  		CHAR(3);	
	xF_BAJA  		DATE;
	xSALIDA 		INTEGER; 
	xCuantos 		INTEGER;
begin
	
	-- descomponemos la matrícula en ciudad,numero y letras
	SplitMatricula(xMatricula,xCIUDAD,xNUMERO,xLETRAS);

	--SIEMPRE BUSCAMOS EL VEHICULO POR MATRICULA
	if xCiudad is null then
		select count(*),MAX(ABONADO),MAX(F_BAJA) into xCuantos,xABONADO,xF_BAJA FROM VEHICULOS
		WHERE MUNICIPIO='148' AND TRIM(MATRICULA) is null AND TRIM(NUMERO)=TRIM(xNUMERO) AND TRIM(LETRA)=TRIM(xLETRAS);	
	else	
		select count(*),MAX(ABONADO),MAX(F_BAJA) into xCuantos,xABONADO,xF_BAJA FROM VEHICULOS
		WHERE MUNICIPIO='148' AND TRIM(MATRICULA)=TRIM(xCIUDAD) AND TRIM(NUMERO)=TRIM(xNUMERO) AND TRIM(LETRA)=TRIM(xLETRAS);
	end if;
	
	IF xABONADO IS NULL THEN   			
   		xSALIDA:=0;
   	else
   		xSALIDA:=1;
	END IF;
	return 	xSALIDA;
end;


SELECT * FROM TRAFICO_NEW 
WHERE ID IN (SELECT id_trafico FROM TMP_INCIDENCIAS_TRAFICO WHERE marca_error='4') ORDER BY matricula


SELECT * FROM TMP_INCIDENCIAS_TRAFICO WHERE id_trafico=1816 

SELECT * FROM VEHICULOS WHERE numero='1009' AND letra='BNS'

SELECT * FROM VEHICULOS WHERE (matricula||numero||letra) IN (SELECT matricula||numero||letra FROM VEHICULOS WHERE f_baja IS NULL
GROUP BY matricula,numero,letra HAVING COUNT(*)>1)
--AND abonado>137094
ORDER BY matricula,numero,letra,abonado

DROP PROCEDURE agustinCargarAuto 





DELETE FROM HDOMICONTRI WHERE motivo='CAMBIO DE DOMICILIO A TRAVES DE LOS DISCOS DE TRAFICO, REGISTRO A-DUPLI Y B-DUPLI'
AND TRUNC(fecha,'dd')=TO_DATE('10/10/2006','dd/mm/yyyy')

DELETE FROM LIQUIDACIONES WHERE concepto='000003' AND YEAR='2006' AND usuario='TORREJON' 
AND TRUNC(F_LIQUIDACION,'dd')=TO_DATE('10/10/2006','dd/mm/yyyy') 

DELETE FROM VEHICULOS WHERE USUARIO='TORREJON' AND ABONADO>137094 

UPDATE VEHICULOS V SET V.NIF=(SELECT M.NIF FROM MOTIVOS_CAMBIO_TITULARIDAD M 
WHERE TRUNC(M.FECHA,'dd')=TO_DATE('10/10/2006','dd/mm/yyyy') AND M.IDCAMBIO=V.ABONADO)
WHERE V.ABONADO IN (SELECT H.IDCAMBIO FROM MOTIVOS_CAMBIO_TITULARIDAD H 
WHERE TRUNC(H.FECHA,'dd')=TO_DATE('10/10/2006','dd/mm/yyyy') )

UPDATE VEHICULOS SET F_BAJA=NULL,MOTIVO_BAJA=NULL,INCORPORADO='S',F_INCORPORACION=SYSDATE
WHERE F_BAJA IS NOT NULL AND MOTIVO_BAJA LIKE 'Baja por B-DUPLI%'

SELECT * FROM VEHICULOS WHERE MOTIVO_ALTA LIKE 'REMATRICULACIÓN MATRÍCULA ANTERIOR%'
--AND RTRIM(NIF) IN (SELECT RTRIM(DNI) FROM TRAFICO_NEW WHERE TIPO_REGISTRO='R')



Referencias catastrales para hacer pruebas: 3558009NH5135N


CREATE TABLE IBI_FINCA_FURB(
	ID							INTEGER NOT NULL,
	DELEGACION_MEH				CHAR(2) DEFAULT '00' NOT NULL,
	GERENCIA					CHAR(1) DEFAULT '0' NOT NULL,
	MUNICIPIO					CHAR(3) DEFAULT '000' NOT NULL,	
	--IDENTIFICACION FINCA
	REF_CATASTRAL				CHAR(14) NOT NULL,
	DISTRITO_CENSAL				CHAR(2),
	--DOMICILIO TRIBUTARIO
	COD_ENTIDAD_MENOR			CHAR(2),
	COD_VIA_PUBLICA				CHAR(5),
	TIPO_VIA					CHAR(5),
	NOMBRE_VIA					CHAR(25),
	PRIMER_NUMERO				CHAR(4),
	PRIMERA_LETRA				CHAR(1),	
	SEGUNDO_NUMERO				CHAR(4),
	SEGUNDA_LETRA				CHAR(1),
	KILOMETRO					CHAR(5),	
	BLOQUE						CHAR(4),
	TEXTO_DIRECCION				CHAR(25),
	CODIGO_POSTAL				CHAR(5),	
	--DATOS FISICOS
	SUPERFICIE_SOLARES			CHAR(7),
	SUPERFICIE_FINCAS			CHAR(7),
	SUPERF_SOBRE_RASANTE		CHAR(7),
	SUPERF_BAJO_RASANTE			CHAR(7),
	SUPERF_CUBIERTA				CHAR(7),	
	--DATOS DE VALORACION
	YEAR_PONENCIA				CHAR(4),
	COD_CALCULO_VALOR_CAT		CHAR(2),
	EDIFICABILIDAD				CHAR(1),
	--Datos de la Alteracion
	EXIS_INFOR_CARTAGRAFICA		CHAR(1),
	DESCRIP_ALTER_CATASTRAL		CHAR(200),	
	--DATOS DEL MOVIMIENTO
	TIPO_MOVIMIENTO				CHAR(1),
	YEAR_EXPEDIENTE				CHAR(4),
	REF_EXPEDIENTE				CHAR(13),
	COD_ENTIDAD_ORIGEN_EXPE		CHAR(3),
	EXISTE_DECLARA_ALTERACION	CHAR(1),
	COD_MOTIVO_MOVIMIENTO		CHAR(4),
	FECHA_MOVIMIENTO			DATE,	
	HORA_MOVIMIENTO				CHAR(6),
	FECHA_ALTERA_CATASTRAL		DATE,
	--DATOS DE LA TASA DE INSCRIPCIÓN CATASTRAL
	NUM_IMPRESO_AUTOLIQUI		CHAR(13),
	IMPORTE_INGRESADO			FLOAT,
	FECHA_INGRESO				DATE,
	COD_ENTIDAD					CHAR(4),
	COD_SUCURSAL				CHAR(4),
	NIF_TITULAR_INGRESO			CHAR(9), --unimos nif y carácter de control
	NOMBRE_TITULAR_INGRESO		CHAR(60),
	PRIMARY KEY(ID),
	CONSTRAINT CLAVE_IBI_FINCA_FURB UNIQUE (REF_CATASTRAL)
) TABLESPACE GT;



CREATE TABLE IBI_SUELO_FURB (
	ID								INTEGER NOT NULL,
	DELEGACION_MEH				CHAR(2) DEFAULT '00' NOT NULL,
	GERENCIA					CHAR(1) DEFAULT '0' NOT NULL,
	MUNICIPIO						CHAR(3) NOT NULL,
	--IDENTIFICACION DEL ELEMENTO	
	REF_CATASTRAL					CHAR(14) NOT NULL,
	NUM_ORDEN_SUBPARCELA			CHAR(4),
	--DATOS FISICOS
	LONG_FACHADA					FLOAT,
	TIPO_FACHADA					CHAR(2) CHECK (TIPO_FACHADA IN ('FA','FD','DR','IZ','SI')),
	SUPERFICIE_SUELO				FLOAT,
	FONDO_SUELO						FLOAT,
	--DATOS DE VALORACION
	COD_VA_PUBLICA					CHAR(5),
	COD_TRAMO_VIA					CHAR(3),
	COD_TIPO_VALOR					CHAR(1) CHECK (COD_TIPO_VALOR IN ('0','1','2','4','5','6','7','8','9')),
	--Coeficientes correctores del valor del suelo
	NUM_FACHADAS					CHAR(1),
	APLICA_COEF_LONG_FACHADA		CHAR(1) CHECK (APLICA_COEF_LONG_FACHADA IN ('S','N')),	
	APLICA_COEF_FORMA_IRREGU		CHAR(1) CHECK (APLICA_COEF_FORMA_IRREGU IN ('S','N')),
	APLICA_COEF_DESMONTE_EXCESIVO	CHAR(1) CHECK (APLICA_COEF_DESMONTE_EXCESIVO IN ('S','N')),
	APLICA_COEF_PROFUN_FIRME		CHAR(1) CHECK (APLICA_COEF_PROFUN_FIRME IN ('S','N')),
	APLICA_COEF_FONDO_EXCESIVO		CHAR(1) CHECK (APLICA_COEF_FONDO_EXCESIVO IN ('S','N')),
	APLICA_COEF_SUPERF_NO_MIN		CHAR(1) CHECK (APLICA_COEF_SUPERF_NO_MIN IN ('S','N')),
	APLICA_COEF_INEDIFICABILIDAD	CHAR(1) CHECK (APLICA_COEF_INEDIFICABILIDAD IN ('S','N')),
	APLICA_COEF_SUELO_PROTEC_PUB	CHAR(1) CHECK (APLICA_COEF_SUELO_PROTEC_PUB IN ('S','N')),
	--coeficientes correctores conjuntos valor del suelo y construcciones
	COEF_CORRECTOR					CHAR(3),
      APLICA_COEF_DEPRECIACION		CHAR(1) CHECK (APLICA_COEF_DEPRECIACION IN ('S','N')),
	COEF_FINCA_CARGAS_SINGULARES	CHAR(3),
	APLICA_COEF_SITU_ESPECIAL     	CHAR(1) CHECK (APLICA_COEF_SITU_ESPECIAL IN ('S','N')),
	APLICA_COEF_USO_NO_LUCRATIVO	CHAR(1) CHECK (APLICA_COEF_USO_NO_LUCRATIVO IN ('S','N')),
	--coeficientes correctores del grado de urbanización
	AGUA							CHAR(1),
	ELECTRICIDAD					CHAR(1),
	ALUMBRADO						CHAR(1),
	DESMONTE						CHAR(1),
	PAVIMENTACION					CHAR(1),
	ALCANTARILLADO					CHAR(1),
	--DATOS DEL MOVIMIENTO
	TIPO_MOVIMIENTO					CHAR(1),
	YEAR_EXPEDIENTE					CHAR(4),
	REF_EXPEDIENTE					CHAR(13),
	COD_ENTIDAD_COLABORADORA		CHAR(3),
	F_ALTERACION_CATASTRAL			DATE,
	PRIMARY KEY (ID),
	CONSTRAINT IBI_FIN_REFCAT FOREIGN KEY (REF_CATASTRAL) REFERENCES IBI_FINCA_FURB(REF_CATASTRAL)	
) TABLESPACE GT;







CREATE TABLE IBI_CONSTRUCTIVA_FURB (
	ID							INTEGER NOT NULL,
	DELEGACION_MEH				CHAR(2) DEFAULT '00' NOT NULL,
	GERENCIA					CHAR(1) DEFAULT '0' NOT NULL,
	MUNICIPIO					CHAR(3) NOT NULL,
	--IDENTIFICACION DEL ELEMENTO
	REF_CATASTRAL				CHAR(14) NOT NULL,
	COD_UNIDAD_CONSTRUCTIVA		CHAR(4) NOT NULL,
	--DOMICILIO TRIBUTARIO DE LA UNIDAD CONSTRUCTIVA
	COD_ENTIDAD_MENOR			CHAR(2),
	COD_VIA_PUBLICA				CHAR(5),
	TIPO_VIA					CHAR(5),
	NOMBRE_VIA					CHAR(25),
	PRIMER_NUMERO				CHAR(4),
	PRIMERA_LETRA				CHAR(1),
	SEGUNDO_NUMERO				CHAR(4),
	SEGUNDA_LETRA				CHAR(1),
	KILOMETRO					CHAR(5),
	BLOQUE						CHAR(4),
	TEXTO_DIRECCION				CHAR(25),
	CODIGO_POSTAL				CHAR(5),
	--DATOS FISICOS
	YEAR_CONSTRUCCION			CHAR(4),
	LONG_FACHADA				FLOAT,
	USO_AGRARIO_LOCALES_ASOC	CHAR(1) CHECK (USO_AGRARIO_LOCALES_ASOC IN ('S','N')),		
	--DATOS DE VALORACION
	COD_VA_PUBLICA_PONENCIA		CHAR(5),
	COD_TRAMO_VIA				CHAR(3),
	/*Coeficientes correctores del valor del suelo aplicables en las construcciones*/	
	NUM_FACHADAS				CHAR(1),
	APLICA_COEF_LONG_FACHADA	CHAR(1),	
	/*Coeficientes correctores del valor de las construcciones*/
	COD_COEF_ESTADO_CONSERVA	CHAR(1),
	/*coeficientes correctores conjuntos valor del suelo y construcciones*/
      APLICA_COEF_DEPRECIACION	CHAR(1),	
	COEF_CORRECTOR				CHAR(3),
	APLICA_COEF_SITU_ESPECIAL   CHAR(1),
	APLICA_COEF_USO_NO_LUCRATIVO	CHAR(1),	
	/*coeficientes correctores del grado de urbanización*/
	AGUA						CHAR(1),
	ELECTRICIDAD				CHAR(1),
	ALUMBRADO					CHAR(1),
	DESMONTE					CHAR(1),
	PAVIMENTACION				CHAR(1),
	ALCANTARILLADO				CHAR(1),
	EXACTITUD_YEAR_CONSTRUCCION	CHAR(1) CHECK (EXACTITUD_YEAR_CONSTRUCCION IN ('E','+','-','C')),
	--DATOS DEL MOVIMIENTO
	TIPO_MOVIMIENTO				CHAR(1),
	YEAR_EXPEDIENTE				CHAR(4),
	REF_EXPEDIENTE				CHAR(13),
	COD_ENTIDAD_COLABORADORA	CHAR(3),
	F_ALTERACION_CATASTRAL		DATE,
	PRIMARY KEY(ID),	
	CONSTRAINT IBI_F_REFCATA FOREIGN KEY (REF_CATASTRAL) REFERENCES IBI_FINCA_FURB(REF_CATASTRAL)	
) TABLESPACE GT;




CREATE TABLE IBI_CONSTRUCCION_FURB(
	ID							INTEGER NOT NULL,
	DELEGACION_MEH				CHAR(2) DEFAULT '00' NOT NULL,
	GERENCIA					CHAR(1) DEFAULT '0' NOT NULL,
	MUNICIPIO					CHAR(3) NOT NULL,	
	--IDENTIFICACION DEL ELEMENTO	
	REF_CATASTRAL				CHAR(14) NOT NULL,
	NUM_ORDEN_CONSTRUCCION		CHAR(4) NOT NULL,
	NUM_CARGO					CHAR(4) NOT NULL,
	COD_UNIDAD_CONSTRUCTIVA		CHAR(4) NOT NULL,
	--DOMICILIO TRIBUTARIO DEL ELEMENTO
	BLOQUE						CHAR(4),
	ESCALERA					CHAR(2),
	PLANTA						CHAR(3),
	PUERTA						CHAR(3),
	--DATOS FISICOS
	COD_DESTINO					CHAR(3),
	TIPO_REFORMA				CHAR(1) CHECK (TIPO_REFORMA IN (' ','R','O','E','I')),
	YEAR_REFORMA				CHAR(4),
	LOCAL_INTERIOR				CHAR(1) CHECK (LOCAL_INTERIOR IN ('S','N')),
	SUPERFICIE_TOTAL_LOCAL		FLOAT,
	SUPERFICIE_PORCHES_TERR		FLOAT,
	SUPERFICIE_LOCAL_OTRAS_PL	FLOAT,	
	--DATOS DE VALORACION
	TIPOLOGIA_CONSTRUCTIVA		CHAR(5),
	COD_USO						CHAR(1),
	COD_CATEGORIA				CHAR(1),
	COD_MODALIDAD_REPARTO		CHAR(3),
	COD_TIPO_VALOR_APLICAR		CHAR(1),
	COEF_CORRECTOR				CHAR(3),
    APLICA_COEFICIENTE  		CHAR(1) CHECK (APLICA_COEFICIENTE IN ('S','N')),	
	--DATOS DEL MOVIMIENTO
	TIPO_MOVIMIENTO				CHAR(1),
	YEAR_EXPEDIENTE				CHAR(4),
	REF_EXPEDIENTE				CHAR(13),
	COD_ENTIDAD_COLABORADORA	CHAR(3),
	F_ALTERACION_CATASTRAL		DATE,
	--Campo para indicar cual es el local principal, que se utiliza
	--para recoger algunos datos y grabarlos en el registro 15
	PRINCIPAL					CHAR(1) DEFAULT 'N',
	PRIMARY KEY(ID),	
	CONSTRAINT IBI_F_REFCA FOREIGN KEY (REF_CATASTRAL) REFERENCES IBI_FINCA_FURB(REF_CATASTRAL)	
) TABLESPACE GT;




CREATE TABLE IBI_CARGO_FURB(
	ID							INTEGER NOT NULL,
	DELEGACION_MEH				CHAR(2) DEFAULT '00' NOT NULL,
	GERENCIA					CHAR(1) DEFAULT '0' NOT NULL,
	MUNICIPIO					CHAR(3) DEFAULT '000' NOT NULL,	
	--IDENTIFICACION DEL ELEMENTO
	REF_CATASTRAL				CHAR(14) NOT NULL,
	NUM_CARGO					CHAR(4) NOT NULL,
	PRIMER_CARACTER_CONTROL		CHAR(1) NOT NULL,
	SEGUN_CARACTER_CONTROL		CHAR(1) NOT NULL, 
	NUM_FIJO					CHAR(8) NOT NULL,
	CARACTER_CONTROL_N_FIJO		CHAR(1),
	COEF_PARTICIPACION			CHAR(5),	
	DISTRITO_CENSAL				CHAR(2),	
	--DOMICILIO TRIBUTARIO DEL ELEMENTO
	COD_ENTIDAD_MENOR			CHAR(2),
	COD_VIA_PUBLICA				CHAR(5),
	TIPO_VIA					CHAR(5),
	NOMBRE_VIA					CHAR(25),
	PRIMER_NUMERO				CHAR(4),
	PRIMERA_LETRA				CHAR(1),
	SEGUNDO_NUMERO				CHAR(4),
	SEGUNDA_LETRA				CHAR(1),
	KILOMETRO					CHAR(5),
	BLOQUE						CHAR(4),
	TEXTO_DIRECCION				CHAR(25),
	CODIGO_POSTAL				CHAR(5),
	ESCALERA					CHAR(2),
	PLANTA						CHAR(3),
	PUERTA						CHAR(3),	
	--IDENTIFICACION DEL TITULAR
	NIF							CHAR(9), --incluye caracter de control
	PERSONALIDAD				CHAR(1),
	NOMBRE						CHAR(60),
	NUM_COMPONENTES				CHAR(4),
	COMPLEMENTO_NOMBRE			CHAR(20),	
	--DOMICILIO FISCAL DEL TITULAR
	COD_DEL_MEH					CHAR(2),
	COD_MUNICIPIO_DGC			CHAR(3),
	COD_PROVI_INE_FISCAL		CHAR(2),
	COD_MUNI_INE_FISCAL			CHAR(3),
	COD_VIA_PUBLICA_FISCAL		CHAR(5),
	TIPO_VIA_FISCAL				CHAR(5),
	NOMBRE_VIA_FISCAL			CHAR(25),
	PRIMER_NUMERO_FISCAL		CHAR(4),
	PRIMERA_LETRA_FISCAL		CHAR(1),
	SEGUNDO_NUMERO_FISCAL		CHAR(4),
	SEGUNDA_LETRA_FISCAL		CHAR(1),
	KILOMETRO_FISCAL			CHAR(5),
	BLOQUE_FISCAL				CHAR(4),
	TEXTO_DIRECCION_FISCAL		CHAR(25),
	ESCALERA_FISCAL				CHAR(2),
	PLANTA_FISCAL				CHAR(3),
	PUERTA_FISCAL				CHAR(3),
	COD_POSTAL_FISCAL			CHAR(5),
	APARTADO_CORREOS			CHAR(5),
	PAIS						CHAR(25),
	PROVINCIA					CHAR(25),
	MUNICIPIO_FISCAL			CHAR(25),		
	--DATOS ECONOMICOS VALORATIVOS DEL INMUEBLE
	YEAR_VALOR_CATASTRAL		CHAR(4),
	VALOR_CATASTRAL				FLOAT,
	VALOR_SUELO					FLOAT,
	VALOR_CONSTRUCCION			FLOAT,
	BASE_LIQUIDABLE				FLOAT,
	CLAVE_USO					CHAR(1),
	YEAR_ULTIMA_REVISION		CHAR(4),
	YEAR_ULTIMA_NOTIFICACION	CHAR(4),
	NUM_ULTIMA_NOTI				CHAR(6),
	SUPERF_ELEM_CONSTRUCTIVOS	FLOAT,
	SUPERFICIE_ELEM_SUELO		FLOAT,
	COEFICIENTE_FINCA			CHAR(7),
	APLICA_PRECIO_MAX_ADMIN		CHAR(1),
	YEAR_FIN_PRECIO_MAX_ADMIN	CHAR(4),
	TIPO_PROPIEDAD_CARGO		CHAR(1),
	--DATOS DEL MOVIMIENTO
	TIPO_MOVIMIENTO				CHAR(1),
	YEAR_EXPEDIENTE				CHAR(4),
	REF_EXPEDIENTE				CHAR(13),
	EJERCICIO_ENTRADA_PADRON	CHAR(4),
	COD_ENTIDAD_COLABORADORA	CHAR(3),
	F_ALTERACION_CATASTRAL		DATE,	
	PRIMARY KEY(ID),	
	CONSTRAINT IBI_FINCA_REFCATA FOREIGN KEY (REF_CATASTRAL) REFERENCES IBI_FINCA_FURB(REF_CATASTRAL)	
) TABLESPACE GT;







CREATE TABLE IBI_REPARTO_CONSTRUCCION_FURB(
	ID							INTEGER NOT NULL,
	DELEGACION_MEH				CHAR(2) DEFAULT '00' NOT NULL,
	GERENCIA					CHAR(1) DEFAULT '0' NOT NULL,
	MUNICIPIO					CHAR(3) NOT NULL,
	--IDENTIFICACION DEL ELEMENTO A REPARTIR	
	REF_CATASTRAL				CHAR(14) NOT NULL,
	NUM_ORDEN_REGISTRO			CHAR(4) NOT NULL,
	NUM_ORDEN_CONSTRUCCION		CHAR(4) NOT NULL,	
	--DATOS DEL MOVIMIENTO
	TIPO_MOVIMIENTO				CHAR(1),
	YEAR_EXPEDIENTE				CHAR(4),
	REF_EXPEDIENTE				CHAR(13),
	COD_ENTIDAD_COLABORADORA	CHAR(3),
	F_ALTERACION_CATASTRAL		DATE,	
	PRIMARY KEY (ID),
	CONSTRAINT IBI_FINC_REFCATASTRAL FOREIGN KEY (REF_CATASTRAL) REFERENCES IBI_FINCA_FURB(REF_CATASTRAL)	
) TABLESPACE GT;




create table FURB_DESGLOSE_REPARTO
(
	ID				integer not null,
	DELEGACION_MEH				CHAR(2) DEFAULT '00' NOT NULL,
	GERENCIA					CHAR(1) DEFAULT '0' NOT NULL,
	MUNICIPIO		CHAR(3) NOT NULL,
	ID_REPARTO		integer not null,
	LOCALES_PROPIEDAD_COMPARTIDA	CHAR(4),	
	PORCEN_REPARTO					CHAR(6),
	PRIMARY KEY (ID),
	CONSTRAINT ID_REPARTO_FURB FOREIGN KEY (ID_REPARTO) REFERENCES IBI_REPARTO_CONSTRUCCION_FURB(ID)	
) tablespace GT;








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

MODIFICACIÓN: 30/10/2002. Agustín León Robles. En el update de IBI en el domicilio tributario
		  el DECODE que habia estaba incorrecto.
MODIFICACIÓN: 18/02/2003. Mª del Carmen Junco Gómez.
		  Le incluimos la fecha de alteración catastral.
MODIFICACIÓN: 04/04/2003. M. Carmen Junco Gómez. Se añade un nuevo parámetro para indicar
		  que tipo de motivo de movimiento se produce.
MODIFICACIÓN: 04/06/2003. M. Carmen Junco Gómez. Al haber cambiado en referencias bancos
		  VARIACION='S' donde VARIACION='I' (cambio de 15 de Mayo de 2003 de Agustín), 
		  también hay que controlar que QUIEN_VARIA='S' donde QUIEN_VARIA='I' (Al hacer
		  un cambio desde IBI se incluirá una S en quien_varia en vez de una I.
MODIFICACIÓN: 08/08/2003. M. Carmen Junco Gómez. Se incorpora un nuevo parámetro de 
		  salida: xAVISO, que avisará en delphi si se ha anulado una domiciliación
		  después de haber generado el Cuaderno 19.
MODIFICACIÓN: 19/08/2003. Agustín León Robles. Al modificar un abonado de ibi no se 
		  modificará ni el último recibo generado ni el valor, bajo ninguna circustancia.
*******************************************************************************/
CREATE OR REPLACE PROCEDURE IBI_MODIFICA(
	xID					IN	INTEGER,
   	xNIF				IN	CHAR,
	xNOMBRE				IN 	CHAR,
	xVIAF				IN 	CHAR,
	xCALLEF				IN	VARCHAR2,
	xNUMEROF			IN 	CHAR,
	xESCALERAF			IN	CHAR,
	xPLANTAF			IN	CHAR,
	xPISOF				IN	CHAR,
	xCPF				IN	CHAR,
	xPOBLACIONF			IN	VARCHAR2,
	xPROVINCIAF			IN	VARCHAR2,      
	xPAISF				IN	VARCHAR2,
	xTIPO_VIA			IN	CHAR,
	xNOMBRE_VIA			IN	CHAR,
	xPRIMER_NUMERO		IN	CHAR,
	xBLOQUE				IN	CHAR,
	xESCALERA			IN	CHAR,
	xPLANTA				IN	CHAR,
	xPUERTA				IN	CHAR,
	xTipoCambio			IN	Char, 
	xFecha_altera		IN	DATE,
	xCod_Motivo			IN	CHAR,
	xCODIGO_OPERACION 	IN	INTEGER)  --si se van a modificar más de un registro a la vez 
AS
 
	v_registro		 IBI%ROWTYPE;   

	-- cursor que recorre todos los registros con código de operacion=xCodigo_Operacion
	-- de forma que se puedan actualizar los datos fiscales a la vez para más de un 
	-- registro de la tabla de IBI
	-- Guardaremos los datos actuales en la tabla HIS_CARGOREAL_IBI para mantener un histórico.
   
	CURSOR CIBI IS SELECT * FROM IBI WHERE CODIGO_OPERACION=xCODIGO_OPERACION;

BEGIN
	

	-- Si trabajamos sólo sobre un registro
	IF xCODIGO_OPERACION=0 THEN 

		-- recogemos los datos actuales que para este ID hay en la tabla IBI.
		SELECT * INTO v_registro FROM IBI WHERE ID=xID;
		
		IBI_MakeChange(v_registro,xNIF,xNOMBRE,xVIAF,xCALLEF,xNUMEROF,xESCALERAF,xPLANTAF,
   				xPISOF,xCPF,xPOBLACIONF,xPROVINCIAF,xPAISF,xTIPO_VIA,xNOMBRE_VIA,
   				xPRIMER_NUMERO,xBLOQUE,xESCALERA,xPLANTA,xPUERTA,xTipoCambio,xFecha_altera,
				xCod_Motivo,xCODIGO_OPERACION);
		
	-- si se van a modificar más de un registro a la vez
	ELSE

		Open cIBI;
		Loop
		
			Fetch cIBI into v_registro;
			EXIT WHEN cIBI%NOTFOUND;
			
			IBI_MakeChange(v_registro,xNIF,xNOMBRE,xVIAF,xCALLEF,xNUMEROF,xESCALERAF,xPLANTAF,
   				xPISOF,xCPF,xPOBLACIONF,xPROVINCIAF,xPAISF,xTIPO_VIA,xNOMBRE_VIA,
   				xPRIMER_NUMERO,xBLOQUE,xESCALERA,xPLANTA,xPUERTA,xTipoCambio,xFecha_altera,
				xCod_Motivo,xCODIGO_OPERACION);
			
		End Loop;
		Close cIBI;

	END IF; 

END;
/





CREATE OR REPLACE PROCEDURE IBI_MakeChange(
	v_registro			IN	IBI%ROWTYPE,
	xNIF				IN	CHAR,
	xNOMBRE				IN 	CHAR,
	xVIAF				IN 	CHAR,
	xCALLEF				IN	VARCHAR2,
	xNUMEROF			IN 	CHAR,
	xESCALERAF			IN	CHAR,
	xPLANTAF			IN	CHAR,
	xPISOF				IN	CHAR,
	xCPF				IN	CHAR,
	xPOBLACIONF			IN	VARCHAR2,
	xPROVINCIAF			IN	VARCHAR2,      
	xPAISF				IN	VARCHAR2,
	xTIPO_VIA			IN	CHAR,
	xNOMBRE_VIA			IN	CHAR,
	xPRIMER_NUMERO		IN	CHAR,
	xBLOQUE				IN	CHAR,
	xESCALERA			IN	CHAR,
	xPLANTA				IN	CHAR,
	xPUERTA				IN	CHAR,
	xTipoCambio			IN	Char, 
	xFecha_altera		IN	DATE,
	xCod_Motivo			IN	CHAR,
	xCODIGO_OPERACION 	IN	INTEGER) 
AS

BEGIN


		INSERT INTO HIS_CARGOREAL_IBI
			(IDIBI,AYTO,TIPO_VARIACION,NIF,NOMBRE,TIPO_VIA_FISCAL,NOMBRE_VIA_FISCAL,
			PRIMER_NUMERO_FISCAL, ESCALERA_FISCAL,PLANTA_FISCAL, PUERTA_FISCAL,
       		COD_POSTAL_FISCAL,MUNICIPIO_FISCAL,PROVINCIA,PAIS,TIPO_VIA,NOMBRE_VIA,
	    	PRIMER_NUMERO,BLOQUE,ESCALERA,PLANTA,PUERTA, QUIEN_VARIA, FECHA_ALTERACION,
			COD_MOTIVO)
		VALUES 	
			(v_registro.ID,v_registro.MUNICIPIO,'M',v_registro.NIF,v_registro.NOMBRE,
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
				
				       -- En el caso de codigo de operacion sea 0 significa que estamos 
				       -- modificando un solo registro, entonces podremos cambiar el 
				       -- domicilio tributario, si estamos modificando
				       -- más de un registro a la vez no se podrán cambiar los datos 
				       -- del domicilio tributario.
					   TIPO_VIA=DECODE(xCODIGO_OPERACION, 0, xTIPO_VIA, TIPO_VIA),
					   NOMBRE_VIA=DECODE(xCODIGO_OPERACION, 0, xNOMBRE_VIA, NOMBRE_VIA),
					   PRIMER_NUMERO=DECODE(xCODIGO_OPERACION, 0 , xPRIMER_NUMERO, PRIMER_NUMERO),
					   BLOQUE=DECODE(xCODIGO_OPERACION, 0 , xBLOQUE, BLOQUE),
					   ESCALERA=DECODE(xCODIGO_OPERACION, 0, xESCALERA, ESCALERA),
					   PLANTA=DECODE(xCODIGO_OPERACION, 0, xPLANTA, PLANTA),
					   PUERTA=DECODE(xCODIGO_OPERACION, 0, xPUERTA, PUERTA),

					   QUIEN_MODIFICA=USER
				
		WHERE ID=v_registro.ID;

	
		-- Anotamos el cambio en la tabla de referencias para que en la siguiente carga
		-- se recojan estos datos y no los que vengan en cinta.

		UPDATE REFERENCIAS_BANCOS SET VARIACION=xTipoCambio,NIF=xNIF
		WHERE MUNICIPIO=v_registro.MUNICIPIO AND
				REF_CATASTRAL=v_registro.REF_CATASTRAL||
				v_registro.NUMERO_SECUENCIAL||
				v_registro.PRIMER_CARACTER_CONTROL||
				v_registro.SEGUN_CARACTER_CONTROL;
				
END;
/

CREATE PUBLIC SYNONYM IBI_MakeChange FOR .IBI_MakeChange;


/******************************************************************************************
Autor: 15/03/2002 Antonio Pérez Caballero
Acción: Realizar el cambio de titularidad después de una transmisión en una plusvalía.
        Modificamos en IBI para que el próximo recibo de IBI salga a nombre de quién
        acaba de adquirie el bien inmueble.
        xTipo 'P' de plusvalías 'M' de motes.
	  Este cambio de titularidad lo realizaremos sólo sobre el registro del mayor año,
	  que será del que en el año siguiente se lean los datos.
MODIFICACIÓN: 04/04/2002 M. Carmen Junco Gómez. Modificamos los datos para la tupla con el
	  año más actual, ya que será de este del que se recojan en la próxima carga de datos
	  desde cinta.
MODIFICACIÓN: A petición de Agustín. 20/05/2002 M. Carmen Junco Gómez. Al modificar un 
        registro de IBI sólo se podrán modificar sus datos fiscales (no tributarios)
MODIFICACIÓN: A petición de Agustín. 06/06/2002 M. Carmen Junco Gómez. Al modificar los 
	  datos de titularidad, si estaba domiciliado, desactivamos la domiciliación.

MODIFICACIÓN: 06/06/2002 Antonio Pérez Caballero se utiliza la misma rutina de IBI_MODIFICA
	para tener el código mas centralizado y atomizado.
	En el caso de esta llamada como no modifica los valores del domicilio tributario
	se los pasamos como valores nulos y el procedimiento controla esta situación.

MODIFICACIÓN: 25/06/2002 M. Carmen Junco Gómez. Se ha restringido la longitud de la calle,
	numero,poblacion,provincia y pais, ya que las longitudes en contribuyentes son 
	mayores que en la tabla de IBI.
	
MODIFICACIÓN: 18/02/2003 M. Carmen Junco Gómez. Se añade el parámetro xFecha_Altera, 
    como la fecha de alteración catastral.
MODIFICACIÓN: 12/08/2003 M. Carmen Junco Gómez. Se añade el parámetro xAVISO de salida
	en la llamada a IBI_MODIFICA.
MODIFICACIÓN: 19/08/2003 M. Carmen Junco Gómez. Se cambian los parámetros en la llamada
    a IBI_MODIFICA.
*******************************************************************************************/

CREATE OR REPLACE PROCEDURE IBICambioTitularidad(
	xNUEVO  IN CHAR,
	xIDIBI  IN INTEGER,
	xTipo   IN Char,
	xFecha_Altera IN DATE) 
AS

xNombre	char(60);
xVIAF		CHAR(5);
xCALLEF	CHAR(25);
xNUMEROF	CHAR(4);
xESCALERAF	CHAR(2);
xPLANTAF	CHAR(3);
xPISOF	CHAR(2);
xCPF		CHAR(5);
xPOBLACIONF	CHAR(25);
xPROVINCIAF	CHAR(25);
xPAISF	CHAR(25);
xAVISO INTEGER;

BEGIN

  	-- Buscar los datos fiscales del nuevo sujeto pasivo
   	BEGIN
      	SELECT NOMBRE,VIA,SUBSTR(CALLE,1,25),
	    	DECODE(SUBSTR(NUMERO,1,1),'0',SUBSTR(NUMERO,2,4),SUBSTR(NUMERO,1,4)),
			ESCALERA,PLANTA,PISO,CODIGO_POSTAL,SUBSTR(POBLACION,1,25),SUBSTR(PROVINCIA,1,25),
			SUBSTR(PAIS,1,25)
		INTO xNOMBRE,xVIAF,xCALLEF,xNUMEROF,xESCALERAF,xPLANTAF,xPISOF,xCPF,
	     	 xPOBLACIONF,xPROVINCIAF,xPAISF
		FROM CONTRIBUYENTES WHERE NIF=xNUEVO;

	EXCEPTION
 	   when no_data_found then
			NULL;
   	END;


	-- Los últimos parametros indican que se anule la domiciliación si la hubises
	-- xTipo el tipo de cambio y 0 para una única actualización.

	IBI_MODIFICA(xIDIBI,xNUEVO,xNOMBRE,xVIAF,xCALLEF,xNUMEROF,xESCALERAF,xPLANTAF,
				 xPISOF,xCPF,xPOBLACIONF,xPROVINCIAF,xPAISF,NULL,NULL,NULL,NULL,NULL,
				 NULL,NULL,xTipo,xFECHA_ALTERA,'CV01',0);     
				 
END;
/







CREATE OR REPLACE PROCEDURE MakeVariacionesFalta
AS
	xNIF_old 				CHAR(10);
	xNOMBRE_old 			CHAR(60);
	xTIPO_VIA_FISCAL_old		CHAR(5);
	xNOMBRE_VIA_FISCAL_old		CHAR(25);
	xPRIMER_NUMERO_FISCAL_old	CHAR(4);
	xESCALERA_FISCAL_old		CHAR(2);
	xPLANTA_FISCAL_old		CHAR(3);
	xPUERTA_FISCAL_old		CHAR(3);
	xCOD_POSTAL_FISCAL_old		CHAR(5);
	xMUNICIPIO_FISCAL_old		CHAR(25);
	xPROVINCIA_old			CHAR(25);
	xPAIS_old				CHAR(25);
	xTIPO_VIA_old			CHAR(5);
	xNOMBRE_VIA_old			CHAR(25);
	xPRIMER_NUMERO_old		CHAR(4);
	xBLOQUE_old				CHAR(4);
	xESCALERA_old			CHAR(2);
	xPLANTA_old				CHAR(3);
	xPUERTA_old				CHAR(3);

	mNIF	 				CHAR(10);
	mNOMBRE	 			CHAR(60);
	mTIPO_VIA_FISCAL			CHAR(5);
	mNOMBRE_VIA_FISCAL		CHAR(25);
	mPRIMER_NUMERO_FISCAL		CHAR(4);
	mESCALERA_FISCAL			CHAR(2);
	mPLANTA_FISCAL			CHAR(3);
	mPUERTA_FISCAL			CHAR(3);
	mCOD_POSTAL_FISCAL		CHAR(5);
	mMUNICIPIO_FISCAL			CHAR(25);
	mPROVINCIA				CHAR(25);
	mPAIS					CHAR(25);
	mTIPO_VIA				CHAR(5);
	mNOMBRE_VIA				CHAR(25);
	mPRIMER_NUMERO			CHAR(4);
	mBLOQUE				CHAR(4);
      mESCALERA				CHAR(2);
	mPLANTA				CHAR(3);
	mPUERTA				CHAR(3);
	
	xVARIACION				CHAR(1);
	xID2002				INTEGER; --id del año 2002
	xID2003				integer; --id del año 2003

cursor cVariaciones is SELECT REF_CATASTRAL FROM REFERENCIAS_BANCOS
	WHERE MUNICIPIO='148' AND VARIACION='I' for update of VARIACION;

BEGIN


for vVariaciones in cVariaciones loop

	-- Datos del año 2003
	begin
		SELECT ID,NIF,NOMBRE,TIPO_VIA_FISCAL,NOMBRE_VIA_FISCAL,
			PRIMER_NUMERO_FISCAL,ESCALERA_FISCAL,PLANTA_FISCAL,
			PUERTA_FISCAL,COD_POSTAL_FISCAL,MUNICIPIO_FISCAL,
			PROVINCIA,PAIS,TIPO_VIA,NOMBRE_VIA,PRIMER_NUMERO,BLOQUE,ESCALERA,PLANTA,PUERTA

		INTO xID2003,mNIF,mNOMBRE,mTIPO_VIA_FISCAL,mNOMBRE_VIA_FISCAL,
			mPRIMER_NUMERO_FISCAL,mESCALERA_FISCAL,mPLANTA_FISCAL,
			mPUERTA_FISCAL,mCOD_POSTAL_FISCAL,mMUNICIPIO_FISCAL,
			mPROVINCIA,mPAIS,mTIPO_VIA,mNOMBRE_VIA,mPRIMER_NUMERO,
			mBLOQUE,mESCALERA,mPLANTA,mPUERTA

		FROM IBI WHERE MUNICIPIO='148' AND YEAR='2003' AND
			REF_CATASTRAL||NUMERO_SECUENCIAL||
			PRIMER_CARACTER_CONTROL||SEGUN_CARACTER_CONTROL=vVariaciones.REF_CATASTRAL;
	EXCEPTION
	   when no_data_found then
	      xID2003:=Null;      
	end;


	if (xID2003 is not null) then

		--Datos del año 2002
		begin
			SELECT ID,NIF,NOMBRE,TIPO_VIA_FISCAL,NOMBRE_VIA_FISCAL,
				PRIMER_NUMERO_FISCAL,ESCALERA_FISCAL,PLANTA_FISCAL,
				PUERTA_FISCAL,COD_POSTAL_FISCAL,MUNICIPIO_FISCAL,
				PROVINCIA,PAIS,TIPO_VIA,NOMBRE_VIA,PRIMER_NUMERO,BLOQUE,ESCALERA,PLANTA,PUERTA

			INTO xID2002,xNIF_old,xNOMBRE_old,xTIPO_VIA_FISCAL_old,xNOMBRE_VIA_FISCAL_old,
				xPRIMER_NUMERO_FISCAL_old,xESCALERA_FISCAL_old,xPLANTA_FISCAL_old,
				xPUERTA_FISCAL_old,xCOD_POSTAL_FISCAL_old,xMUNICIPIO_FISCAL_old,
				xPROVINCIA_old,xPAIS_old,xTIPO_VIA_old,xNOMBRE_VIA_old,xPRIMER_NUMERO_old,
				xBLOQUE_old,xESCALERA_old,xPLANTA_old,xPUERTA_old

			FROM IBI WHERE MUNICIPIO='148' AND YEAR='2002' AND
				REF_CATASTRAL||NUMERO_SECUENCIAL||
				PRIMER_CARACTER_CONTROL||SEGUN_CARACTER_CONTROL=vVariaciones.REF_CATASTRAL;

		EXCEPTION
			when no_data_found then
				xID2002:=Null;      
		end;


	if (xID2002 is not null) then

		-- antes de hacer el cambio comprobaremos si los datos que vienen en la Cinta de 
		-- Hacienda este año vienen ya corregidos o no.
		IF (mNIF=xNIF_old AND mNOMBRE=xNOMBRE_old AND mTIPO_VIA_FISCAL=xTIPO_VIA_FISCAL_old AND 
		    mNOMBRE_VIA_FISCAL=xNOMBRE_VIA_FISCAL_old AND 
		    mPRIMER_NUMERO_FISCAL=xPRIMER_NUMERO_FISCAL_old AND 
		    mESCALERA_FISCAL=xESCALERA_FISCAL_old AND mPLANTA_FISCAL=xPLANTA_FISCAL_old AND
	          mPUERTA_FISCAL=xPUERTA_FISCAL_old AND mCOD_POSTAL_FISCAL=xCOD_POSTAL_FISCAL_old AND 
		    mMUNICIPIO_FISCAL=xMUNICIPIO_FISCAL_old AND mPROVINCIA=xPROVINCIA_old AND 
		    mPAIS=xPAIS_old AND mTIPO_VIA=xTIPO_VIA_old AND mNOMBRE_VIA=xNOMBRE_VIA_old AND 
		    mPRIMER_NUMERO=xPRIMER_NUMERO_old AND mBLOQUE=xBLOQUE_old AND 
		    mESCALERA=xESCALERA_old AND mPLANTA=xPLANTA_old AND mPUERTA=xPUERTA_old) THEN

			-- Si los datos están corregidos lo indicamos en la tabla REFERENCIAS_BANCOS
			-- modificando el valor de VARIACION='N' para que el año siguiente no tenga que 
			-- hacer comprobaciones innecesarias.
			UPDATE REFERENCIAS_BANCOS SET VARIACION='N' WHERE CURRENT OF cVARIACIONES;
		ELSE  	   	   

			update IBI set 
				NIF=xNIF_old,
				NOMBRE=xNOMBRE_old,
				TIPO_VIA_FISCAL=xTIPO_VIA_FISCAL_old,
				NOMBRE_VIA_FISCAL=xNOMBRE_VIA_FISCAL_old,
				PRIMER_NUMERO_FISCAL=xPRIMER_NUMERO_FISCAL_old,
				ESCALERA_FISCAL=xESCALERA_FISCAL_old,
				PLANTA_FISCAL=xPLANTA_FISCAL_old,
				PUERTA_FISCAL=xPUERTA_FISCAL_old,
				COD_POSTAL_FISCAL=xCOD_POSTAL_FISCAL_old,
				MUNICIPIO_FISCAL=xMUNICIPIO_FISCAL_old,
				PROVINCIA=xPROVINCIA_old,
				PAIS=xPAIS_old,
				TIPO_VIA=xTIPO_VIA_old,
				NOMBRE_VIA=xNOMBRE_VIA_old,
				PRIMER_NUMERO=xPRIMER_NUMERO_old,
				BLOQUE=xBLOQUE_old,
				ESCALERA=xESCALERA_old,
				PLANTA=xPLANTA_old,
				PUERTA=xPUERTA_old
			where id=xID2003;

			INSERT INTO HIS_CARGOREAL_IBI
				(IDIBI,AYTO,TIPO_VARIACION,QUIEN_VARIA,FECHA_ALTERACION,NIF,NOMBRE,TIPO_VIA_FISCAL,
				NOMBRE_VIA_FISCAL,PRIMER_NUMERO_FISCAL, ESCALERA_FISCAL,PLANTA_FISCAL, PUERTA_FISCAL,
				COD_POSTAL_FISCAL,MUNICIPIO_FISCAL,PROVINCIA,PAIS,TIPO_VIA,NOMBRE_VIA,
				PRIMER_NUMERO,BLOQUE,ESCALERA,PLANTA,PUERTA,COD_MOTIVO)
			VALUES 	
				(xID2003,'148','A','I',SYSDATE,mNIF,mNOMBRE,mTIPO_VIA_FISCAL,mNOMBRE_VIA_FISCAL,
				mPRIMER_NUMERO_FISCAL,mESCALERA_FISCAL,mPLANTA_FISCAL,mPUERTA_FISCAL,
				mCOD_POSTAL_FISCAL,mMUNICIPIO_FISCAL,mPROVINCIA,mPAIS,mTIPO_VIA,
				mNOMBRE_VIA,mPRIMER_NUMERO,mBLOQUE,mESCALERA,mPLANTA,mPUERTA,'CV02');
		end if;   

	end if; --final del if (xID2002 is not null)
	
	end if; --final del if (xID2003 is not null)

end loop;	


END;
/



CREATE OR REPLACE PROCEDURE IMPRIME_RECIBOS_VEHI (
		xMUNICIPIO 	IN CHAR,
		xID 	  		IN INTEGER,
		xYEAR 		IN CHAR,
		xPERI 		IN CHAR,
		xRECIDESDE 	IN INTEGER,
		xRECIHASTA 	IN INTEGER,
		xSENTENCIA	IN	VARCHAR2)
AS 

	TYPE tCURSOR 		IS REF CURSOR;  -- define REF CURSOR type
    vCURSOR    	 		tCURSOR;     -- declare cursor variable
    v_RegistroVehi    	Recibos_vehi%ROWTYPE;
    xCONCEPTO			char(6);
    xCuantos			integer;

	I INTEGER;	   

BEGIN

   I:=0;

   DELETE FROM IMP_RECIBOS_VEHI WHERE USUARIO=UID;

   SELECT CONCEPTO INTO xCONCEPTO FROM PROGRAMAS WHERE PROGRAMA='VEHICULOS';
     
   --imprimir un solo recibo
   IF xID<>0 THEN

      SELECT * INTO v_RegistroVehi FROM RECIBOS_VEHI WHERE ID=xID;
		WriteTempVehi(v_RegistroVehi,xYear,xPeri);

	ELSE /* Si se ha de imprimir más de un recibo */
	
	
		--Asignar consulta a cursor, abrirlo y recorrerlo
		OPEN vCURSOR FOR xSENTENCIA USING xMUNICIPIO,xYEAR,xPERI;
		LOOP
			FETCH vCURSOR INTO v_RegistroVehi;
			EXIT WHEN vCURSOR%NOTFOUND;
			
			xCuantos:=0;
			
			Select Count(*) into xCuantos from valores 
			where Ayto=xMunicipio and Padron=xConcepto and Year=xYear and Periodo=xPeri and Recibo=v_RegistroVehi.Abonado
			and f_ingreso is null and fecha_de_baja is null;
			
			if xCuantos > 0 then
			
				IF (xRECIHASTA > 0) THEN
			
					I:=I+1;	      
      
					IF (I >= xRECIDESDE AND I <= xRECIHASTA) THEN
						WriteTempVehi(v_RegistroVehi,xYear,xPeri);
			      	ELSE
         				IF I > xRECIHASTA THEN
		      				EXIT;
            			END IF;
         			END IF;
         	
         		ELSE
         
         			WriteTempVehi(v_RegistroVehi,xYear,xPeri);
         	
         		END IF;

         	end if;
         	
   	END LOOP;
	   CLOSE vCURSOR;
		
   END IF; /* del IF xID<>0 THEN */

END;
/





--
---
--
CREATE OR REPLACE PROCEDURE GENERA_PADRON_VEHI (
       xMUNICIPIO 	IN CHAR,
       xYEAR 		IN CHAR,
       xDESDE 		IN DATE,	
       xHASTA 		IN DATE,
	   xCARGO		IN DATE,
       xCONCEPTO	IN CHAR,
       xLINEA1 		IN CHAR,
       xLINEA2 		IN CHAR,
       xLINEA3 		IN CHAR,
	   xPERIODO		IN CHAR)
AS
    xTARIFA           CHAR(50);
    xIMPORTE          FLOAT;
    xDCONTROL         VARCHAR(2);
    xDIG_C60_M2       CHAR(2);    
    xREFERENCIA       CHAR(10);
    xREF_DC           CHAR(2);
    xIMPORTE_CAD      CHAR(12);
    xNOMBRE           VARCHAR(40);
    xDOMICILIO        VARCHAR(50);
    xVIA              CHAR(2);
    xCALLE            VARCHAR(30);
    xNUM              CHAR(5);
    xESC              CHAR(2);
    xPLANTA           CHAR(3);
    xPISO             CHAR(2);
    xYEAR_NUM         INTEGER;
    xYEAR_BONI_NUM    INTEGER;
    xBONIFICACION     FLOAT;
    xNUM_PER	      INTEGER;
    xNOMBRE_TITULAR   VARCHAR2(40);
    xCODPOSTAL 	      CHAR(5);
    xPoblacion 	      CHAR(35);
    xPROVINCIA	      VARCHAR2(35);

    xPADRON		      CHAR(6);
    xEMISOR 	      CHAR(6);
    xTRIBUTO 	      CHAR(3);


    -- cursor con todos los vehículos incorporados al padrón y no dados de baja para 
    -- un municipio especificado.
    CURSOR CDATOSVEHI IS 
	SELECT ABONADO,NIF,MARCA,MODELO,BASTIDOR,DOMICILIADO,MATRICULA,NUMERO,LETRA,ENTIDAD,
		SUCURSAL,DC,CUENTA,F_DOMICILIACION,TITULAR,TIPO_VEHICULO,TIPO_BONI_EX,ID_BONI_EX,
		YEAR_BONI,REPRESENTANTE,IDDOMIALTER,COTITULARES
	FROM VEHICULOS 
	WHERE F_BAJA IS NOT NULL AND MUNICIPIO=xMUNICIPIO;

BEGIN

	--Para saber si se van a generar mas de un padron en un mismo año
	SELECT VEHI_NUM_PERIODOS INTO xNUM_PER FROM DATOSPER WHERE MUNICIPIO=xMUNICIPIO;

	--Averiguar que concepto es el padron de vehiculos
	SELECT CONCEPTO INTO xPADRON FROM PROGRAMAS WHERE PROGRAMA='VEHICULOS';

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


  FOR REG_CDATOSVEHI IN CDATOSVEHI LOOP

      IF (REG_CDATOSVEHI.DOMICILIADO='N') THEN
          xNOMBRE_TITULAR:=NULL;
      ELSE
          SELECT NOMBRE INTO xNOMBRE_TITULAR FROM CONTRIBUYENTES WHERE NIF=REG_CDATOSVEHI.TITULAR;

      END IF;

	--nombre del abonado, es decir, a nombre de quien saldra el recibo
	SELECT NOMBRE INTO xNOMBRE FROM CONTRIBUYENTES WHERE NIF=REG_CDATOSVEHI.NIF;

	--domicilio fiscal en funcion de si tiene un representante o no.
	--Dentro de la funcion "GetDomicilioFiscal" se comprueba si tiene a su vez un domicilio
	--alternativo.
	IF REG_CDATOSVEHI.REPRESENTANTE IS NULL THEN
		GetDomicilioFiscal(REG_CDATOSVEHI.NIF,REG_CDATOSVEHI.IDDOMIALTER,
					xDomicilio,xPoblacion,xProvincia,xCodPostal);
	ELSE
		GetDomicilioFiscal(REG_CDATOSVEHI.REPRESENTANTE,REG_CDATOSVEHI.IDDOMIALTER,
					xDomicilio,xPoblacion,xProvincia,xCodPostal);
	END IF;

      SELECT DESCRIPCION,IMPORTE INTO xTARIFA,xIMPORTE FROM TARIFAS_VEHICULOS
      WHERE MUNICIPIO=xMUNICIPIO AND CODIGO=REG_CDATOSVEHI.TIPO_VEHICULO AND ANNE=xYEAR;

      xYEAR_BONI_NUM := TO_NUMBER(REG_CDATOSVEHI.YEAR_BONI,9999);
      xYEAR_NUM:= TO_NUMBER(xYEAR,9999);

	-- comprobar si se ha de bonificar el importe del recibo.
      IF xYEAR_BONI_NUM >= xYEAR_NUM THEN

         IF REG_CDATOSVEHI.TIPO_BONI_EX='E' THEN
            xIMPORTE:=0;
         ELSE
           IF REG_CDATOSVEHI.TIPO_BONI_EX='B' THEN
              SELECT BONIFICACION INTO xBONIFICACION FROM BONIFI_VEHICULOS 
		  WHERE ID=REG_CDATOSVEHI.ID_BONI_EX;
              xIMPORTE:=xIMPORTE-((xIMPORTE*xBONIFICACION)/100);
           END IF;

         END IF;

      END IF;

      xIMPORTE:=ROUND(xIMPORTE/xNUM_PER,2);

	-- calcular dígitos de control 
      CALCULA_DC_60(xIMPORTE,REG_CDATOSVEHI.ABONADO,xTRIBUTO,SUBSTR(xYEAR,3,2),
			xPERIODO,xEMISOR,xDCONTROL);

	--calcular los digitos de control del cuaderno 60 modalidad 2
	CALCULA_DC_MODALIDAD2_60(xIMPORTE, REG_CDATOSVEHI.ABONADO, xTRIBUTO, SUBSTR(xYEAR,3,2), 
			'1',to_char(xHASTA,'y'), to_char(xHASTA,'ddd'), xEMISOR, xDIG_C60_M2);

    GETREFERENCIA(REG_CDATOSVEHI.ABONADO,xREFERENCIA);

    IMPORTEENCADENA(xIMPORTE,xIMPORTE_CAD);
	
	--insertamos los cotitulares del recibo
	IF REG_CDATOSVEHI.COTITULARES='S' THEN
		INSERT INTO COTITULARES_RECIBO(NIF,PROGRAMA,AYTO,PADRON,YEAR,PERIODO,RECIBO)
		SELECT NIF,'VEHICULOS',xMUNICIPIO,xPADRON,xYEAR,xPERIODO,REG_CDATOSVEHI.ABONADO
		FROM COTITULARES
		WHERE ID_CONCEPTO=REG_CDATOSVEHI.ABONADO AND PROGRAMA='VEHICULOS';
	END IF;

      -- insertar los recibos en la tabla de recibos de vehículos.
	INSERT INTO RECIBOS_VEHI
         (ABONADO,YEAR,MUNICIPIO,NIF,MARCA,MODELO,TARIFA,BASTIDOR,IMPORTE,TOTAL,
		  MATRICULA,NUMERO,LETRA,
		  DOMICILIADO,ESTADO_BANCO,ENTIDAD,SUCURSAL,DC,CUENTA,F_DOMICILIACION,DNI_TITULAR,
		  NOMBRE_TITULAR,
		  DESDE,HASTA,F_CARGO,CONCEPTO,LINEA1,LINEA2,LINEA3,
		  EMISOR,TRIBUTO,EJERCICIO,REMESA,
		  REFERENCIA,DIGITO_CONTROL,PERIODO,NOMBRE,DOMICILIO,
		  DISCRI_PERIODO,DIGITO_YEAR,F_JULIANA,DIGITO_C60_MODALIDAD2,
  		  POBLACION,PROVINCIA,CODIGO_POSTAL)
      VALUES 
		 (REG_CDATOSVEHI.ABONADO,xYEAR,xMUNICIPIO,REG_CDATOSVEHI.NIF,REG_CDATOSVEHI.MARCA,
		  REG_CDATOSVEHI.MODELO,xTARIFA,REG_CDATOSVEHI.BASTIDOR,
		  xIMPORTE_CAD,xIMPORTE,REG_CDATOSVEHI.MATRICULA,REG_CDATOSVEHI.NUMERO,
		  REG_CDATOSVEHI.LETRA,

		  REG_CDATOSVEHI.DOMICILIADO,DECODE(REG_CDATOSVEHI.DOMICILIADO,'S','EB',NULL),
		  DECODE(REG_CDATOSVEHI.DOMICILIADO,'S',REG_CDATOSVEHI.ENTIDAD,NULL),
		  DECODE(REG_CDATOSVEHI.DOMICILIADO,'S',REG_CDATOSVEHI.SUCURSAL,NULL),
		  DECODE(REG_CDATOSVEHI.DOMICILIADO,'S',REG_CDATOSVEHI.DC,NULL),
		  DECODE(REG_CDATOSVEHI.DOMICILIADO,'S',REG_CDATOSVEHI.CUENTA,NULL),
		  DECODE(REG_CDATOSVEHI.DOMICILIADO,'S',REG_CDATOSVEHI.F_DOMICILIACION,NULL),
		  DECODE(REG_CDATOSVEHI.DOMICILIADO,'S',REG_CDATOSVEHI.TITULAR,NULL),
		  
		  xNOMBRE_TITULAR,xDESDE,xHASTA,xCARGO,xCONCEPTO,
		  xLINEA1,xLINEA2,
		  xLINEA3,xEMISOR,xTRIBUTO,SUBSTR(xYEAR,3,2),xPERIODO,xREFERENCIA,xDCONTROL,
		  xPERIODO,xNOMBRE,xDomicilio,
		  '1',to_char(xHASTA,'y'), to_char(xHASTA,'ddd'),xDIG_C60_M2,
  		  xPoblacion,xProvincia,xCodPostal);

  END LOOP;

   -- Insertamos una tupla en LOGSPADRONES para controlar que esta acción ha sido ejecutada
   INSERT INTO LOGSPADRONES (MUNICIPIO,PROGRAMA,PYEAR,PERIODO,HECHO)
   VALUES (xMUNICIPIO,'VEHICULOS',xYEAR,xPERIODO,'Se Genera un Padrón');

END;
/
