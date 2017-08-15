/* Ricardo: consultas para obtener ficheros para la agencia */

-- select para contribuyentes con el campo CALLE vacío
SELECT RPAD(TRIM(NIF),9)||RPAD(TRIM(NOMBRE),91) FROM CONTRIBUYENTES
WHERE CALLE IS NULL AND TRIM(UPPER(NIF)) NOT LIKE 'DI%' AND LENGTH(TRIM(NIF))<10
ORDER BY TRIM(NIF);

-- select para contribuyentes que han tenido un acuse negativo por dirección incorrecta
select distinct rpad(trim(v.nif),9)||rpad(trim(c.nombre),91) from valores v,contribuyentes c
where v.nif=c.nif and v.id in (select valor from notificaciones
	  			  	  	   	   where last_acuse='0302') 
and upper(v.nif) not like 'DI%' and length(trim(v.nif))<10 and c.validado not in ('F','M')
order by rpad(trim(v.nif),9)||rpad(trim(c.nombre),91)

-- select para notificaciones en voluntaria de liquidaciones (desconocidos)
select distinct rpad(trim(v.nif),9)||rpad(trim(c.nombre),91) from valores v,contribuyentes c
where v.nif=c.nif and v.id in (select valor from Notificaciones N , valores V where 
N.Notificado='N' and N.Tipo_Noti='VOL' and V.id=N.valor and substr(N.ACUSE1,1,2)='03'
and N.F_ENVIO_BOP is null 
and V.f_ingreso is null 
and V.fecha_de_baja is null and V.f_suspension is null and V.fecha_propuesta_baja is null) 
and upper(v.nif) not like 'DI%' and length(trim(v.nif))<10 and c.validado not in ('F','M')
order by rpad(trim(v.nif),9)||rpad(trim(c.nombre),91)

-- cabecera
-- ejemplo de cabecera: INTP2814800E11822513F120156E4CA3F2A8553E
select rpad('INTP2814800E11822513F120156E4CA3F2A8553E',100) from dual


-- una vez cargado el .txt en access
create table agencia as select * from agencia@pase;
ALTER TABLE AGENCIA ADD PROVINCIA VARCHAR2(35);

DECLARE
   XPROVINCIA VARCHAR2(35);
   CURSOR C1 IS SELECT DISTINCT CODIGODH FROM AGENCIA WHERE CODIGODH IS NOT NULL; 
BEGIN
   FOR v1 IN C1
   LOOP
      begin
         SELECT PROVINCIA INTO xPROVINCIA FROM COD_PROVINCIAS WHERE CODPROV=v1.CODIGODH;
		 Exception
		    When no_data_found then
			   xPROVINCIA:=NULL;
	  end;
	  UPDATE AGENCIA SET PROVINCIA=xPROVINCIA WHERE CODIGODH=v1.CODIGODH;
   END LOOP;
END;


ALTER TABLE AGENCIA ADD CARGADO CHAR(1) DEFAULT 'N';
-- indicará si se ha de cargar o no el cambio en contribuyentes
-- si está a NULL es porque aún no tenemos información de la Agencia sobre ese nif, ni positiva ni negativa
ALTER TABLE AGENCIA ADD CARGAR CHAR(2) DEFAULT NULL 
alter table agencia add calleconletra varchar2(30);
alter table agencia add id integer;
ALTER TABLE AGENCIA ADD VALIDADOOLD CHAR(1);
ALTER TABLE AGENCIA ADD NIFCONTRI CHAR(10);

DECLARE
   xVALIDADO CHAR(1);
   xNIF CHAR(10);
   CURSOR C1 IS SELECT NIF FROM AGENCIA WHERE SUBSTR(NIF,1,1)='8' FOR UPDATE OF VALIDADOOLD;
BEGIN
   FOR v1 IN C1
   LOOP 
      BEGIN  	
         SELECT NIF,VALIDADO INTO xNIF,xVALIDADO FROM CONTRIBUYENTES WHERE trim(NIF)=trim(v1.NIF);
         EXCEPTION 
            WHEN OTHERS THEN
               NULL;
      END;
      UPDATE AGENCIA SET NIFCONTRI=xNIF,VALIDADOOLD=xVALIDADO WHERE CURRENT OF C1;
   END LOOP;
END;

update agencia set nif=trim(nif),nifaeat=trim(nifaeat),nombre=trim(nombre),nombreaeat=trim(nombreaeat);
update agencia set calleconletra=calle;
update agencia set calleconletra=trim(calle)||' le.'||trim(letra) where letra is not null;

-- procedimiento para poner un id en la tabla
DECLARE
	i INTEGER;
	CURSOR C1 IS SELECT * FROM AGENCIA ORDER BY NIF FOR UPDATE OF ID;
BEGIN
	i:=1;
	FOR v1 IN C1
	LOOP
		UPDATE AGENCIA SET ID=i WHERE CURRENT OF C1;
		i:=i+1;
	END LOOP;
END;
/


-- procedimiento para cargar los nuevos domicilios fiscales
-- primera pasada para cargar los datos en los que coincide tanto el nif como el nombre
DECLARE
	CURSOR cNIFS IS SELECT * FROM AGENCIA WHERE NIF=NIFAEAT
						 and NOMBRE=NOMBREAEAT AND CARGADO='N' AND VALIDADOOLD='N' FOR UPDATE OF CARGADO;
BEGIN
	FOR vNIFS IN CNIFS 
	LOOP
		update contribuyentes set via=vNIFS.via,
				 						  calle=vNIFS.calleconletra,
										  numero=vNIFS.numero,
										  escalera=vNIFS.escalera,
										  planta=vNIFS.piso,
										  piso=vNIFS.puerta,
										  codigo_postal=vNIFS.codigo_postal,
										  poblacion=vNIFS.poblacion,
										  validado='A'
		where NIF=vNIFS.NIFCONTRI;
		update agencia set cargado='S' where current of cNIFS;
	END LOOP;	
END;
/

-- procedimiento para cargar los nuevos domicilios fiscales y el nombre
-- segunda pasada para cargar los datos en los que coincide tanto el nif como los diez primeros caracteres del nombre.
DECLARE
	CURSOR cNIFS IS SELECT * FROM AGENCIA WHERE NIF=NIFAEAT
						 and substr(NOMBRE,1,10)=substr(NOMBREAEAT,1,10) AND CARGADO='N' AND VALIDADOOLD='N' FOR UPDATE OF CARGADO;
BEGIN
	FOR vNIFS IN CNIFS 
	LOOP
		update contribuyentes set nombre=vNIFS.nombreaeat,
										  via=vNIFS.via,
				 						  calle=vNIFS.calleconletra,
										  numero=vNIFS.numero,
										  escalera=vNIFS.escalera,
										  planta=vNIFS.piso,
										  piso=vNIFS.puerta,
										  codigo_postal=vNIFS.codigo_postal,
										  poblacion=vNIFS.poblacion,
										  validado='A'
		where NIF=vNIFS.NIFCONTRI;
		update agencia set cargado='S' where current of cNIFS;
	END LOOP;	
END;
/

-- tercera pasada para cargar los datos en los que coincide el nif,la calle y el número.
DECLARE
	CURSOR cNIFS IS SELECT A.NOMBREAEAT,A.TIPO_VIA,A.CALLECONLETRA,A.NUMERO,A.ESCALERA,A.PISO,A.PUERTA,A.COD_POSTAL,
	A.POBLACION,A.NIFCONTRI from agencia a,contribuyentes c
									where a.nifcontri=c.nif and 
									a.cargado='N' and a.validadoold='N' and a.nif=a.nifaeat
				and a.calle=c.calle and a.numero=lpad(trim(c.numero),5,'0') FOR UPDATE OF A.CARGADO;
BEGIN
	FOR vNIFS IN CNIFS 
	LOOP
		update contribuyentes set nombre=vNIFS.nombreaeat,
										  via=vNIFS.TIPO_via,
				 						  calle=vNIFS.calleconletra,
										  numero=vNIFS.numero,
										  escalera=vNIFS.escalera,
										  planta=vNIFS.piso,
										  piso=vNIFS.puerta,
										  codigo_postal=vNIFS.cod_postal,
										  poblacion=vNIFS.poblacion,
										  validado='A'
		where NIF=vNIFS.NIFCONTRI;
		update agencia set cargado='S' where current of cNIFS;
	END LOOP;	
END;
/

-- cuarta pasada para cargar los datos en los que coincide el nif y los cinco primeros caracteres de la calle (previa inspección visual).
DECLARE
	CURSOR cNIFS IS SELECT A.NOMBREAEAT,A.TIPO_VIA,A.CALLECONLETRA,A.NUMERO,A.ESCALERA,A.PISO,A.PUERTA,A.COD_POSTAL,
								  A.POBLACION,A.NIFCONTRI FROM AGENCIA A,CONTRIBUYENTES C WHERE A.NIFCONTRI=C.NIF AND A.CARGADO='N' 
								  AND A.NIF=A.NIFAEAT AND A.VALIDADOOLD='N' AND SUBSTR(A.CALLE,1,5)=SUBSTR(C.CALLE,1,5) FOR UPDATE OF A.CARGADO;
BEGIN
	FOR vNIFS IN CNIFS 
	LOOP
		update contribuyentes set nombre=vNIFS.nombreaeat,
										  via=vNIFS.TIPO_via,
				 						  calle=vNIFS.calleconletra,
										  numero=vNIFS.numero,
										  escalera=vNIFS.escalera,
										  planta=vNIFS.piso,
										  piso=vNIFS.puerta,
										  codigo_postal=vNIFS.cod_postal,
										  poblacion=vNIFS.poblacion,
										  validado='A'
		where NIF=vNIFS.NIFCONTRI;
		update agencia set cargado='S' where ID=vNIFS.ID;
	END LOOP;	
END;
/

-- quinta pasada para cargar los datos en los que coincide el nif y los cinco primeros caracteres del nombre (previa inspección visual).
DECLARE
	CURSOR cNIFS IS SELECT A.NOMBREAEAT,A.TIPO_VIA,A.CALLECONLETRA,A.NUMERO,A.ESCALERA,A.PISO,A.PUERTA,A.COD_POSTAL,
								  A.POBLACION,A.NIFCONTRI 
								  FROM AGENCIA A,CONTRIBUYENTES C WHERE A.NIFCONTRI=C.NIF AND A.CARGADO='N' AND A.NIF=A.NIFAEAT AND A.VALIDADOOLD='N' 
								 and substr(a.nombre,1,5)=substr(a.nombreaeat,1,5) and id not in (4416,5651,6173) FOR UPDATE OF A.CARGADO;
BEGIN
	FOR vNIFS IN CNIFS 
	LOOP
		update contribuyentes set nombre=vNIFS.nombreaeat,
										  via=vNIFS.TIPO_via,
				 						  calle=vNIFS.calleconletra,
										  numero=vNIFS.numero,
										  escalera=vNIFS.escalera,
										  planta=vNIFS.piso,
										  piso=vNIFS.puerta,
										  codigo_postal=vNIFS.cod_postal,
										  poblacion=vNIFS.poblacion,
										  validado='A'
		where NIF=vNIFS.NIFCONTRI;
		update agencia set cargado='S' where current of cNIFS;
	END LOOP;	
END;
/

-- sexta pasada para cargar los datos en los que coincide el nif (inspección visual de lo que se va a cargar).
-- se incluyen en una tabla los IDs afectados de la tabla agencia
DECLARE
    xNOMBREAEAT VARCHAR2(40);
	xTIPO_VIA CHAR(2);
	xCALLECONLETRA CHAR(30);
	xNUMERO CHAR(5);
	xESCALERA CHAR(2);
	xPISO CHAR(2);
	xPUERTA CHAR(2);
	xCOD_POSTAL CHAR(5);
	xPOBLACION VARCHAR2(35);
	xNIFCONTRI CHAR(10);
    CURSOR CNIFS IS SELECT ID FROM NADA;
BEGIN
	FOR vNIFS IN CNIFS 
	LOOP
	   SELECT NOMBREAEAT,TIPO_VIA,CALLECONLETRA,NUMERO,ESCALERA,PISO,PUERTA,COD_POSTAL,POBLACION,NIFCONTRI
	   INTO xNOMBREAEAT,xTIPO_VIA,xCALLECONLETRA,xNUMERO,xESCALERA,xPISO,xPUERTA,xCOD_POSTAL,xPOBLACION,xNIFCONTRI
	   FROM AGENCIA WHERE ID=vNIFS.ID;
	   
		update contribuyentes set nombre=xnombreaeat,
										  via=xTIPO_via,
				 						  calle=xcalleconletra,
										  numero=xnumero,
										  escalera=xescalera,
										  planta=xpiso,
										  piso=xpuerta,
										  codigo_postal=xcod_postal,
										  poblacion=xpoblacion,
										  validado='A'
		where NIF=xNIFCONTRI;
		update agencia set cargado='S' where current of cNIFS;
	END LOOP;	
END;
/


DECLARE
	CURSOR CNIFS IS SELECT * FROM AGENCIA WHERE ID IN (SELECT ID FROM CARGAR1)
						 FOR UPDATE OF CARGADO;
BEGIN
	FOR vNIFS IN CNIFS 
	LOOP
		update contribuyentes set via=vNIFS.via,
				 						  calle=vNIFS.calleconletra,
										  numero=vNIFS.numero,
										  escalera=vNIFS.escalera,
										  planta=vNIFS.piso,
										  piso=vNIFS.puerta,
										  codigo_postal=vNIFS.codigo_postal,
										  poblacion=vNIFS.poblacion,
										  validado='A'
		where TRIM(NIF)=TRIM(vNIFS.NIF);
		update agencia set cargado='S' where current of cNIFS;
	END LOOP;	
END;
/


/****************************************************************************************************************************************/
-- Para las tuplas enviadas por la agencia para las cuales coinciden nombre y calle, pero no el NIF, crearemos los contribuyentes enviados
-- por la agencia y posteriormente le asociaremos nuestro nif como MOTE.

alter table Agencia add ExisteAEAT char(1) default 'N';
ALTER TABLE AGENCIA ADD NIFAEATCONTRI CHAR(10);

declare   
   xCONTADOR INTEGER;
   CURSOR C1 IS select nifaeat from agencia where nif<>nifaeat and validadoold<>'A' FOR UPDATE OF EXISTEAEAT;
begin
   for v1 in c1
   loop
      SELECT COUNT(*) INTO xCONTADOR FROM CONTRIBUYENTES WHERE TRIM(NIF)=TRIM(v1.NIFAEAT);
      IF xCONTADOR>0 THEN
         UPDATE AGENCIA SET EXISTEAEAT='S' WHERE CURRENT OF C1;
      END IF;
   end loop;
end;

declare   
   xNIF CHAR(10);
   CURSOR C1 IS select nifaeat from agencia where EXISTEAEAT='S' FOR UPDATE OF NIFAEATCONTRI;
begin
   for v1 in c1
   loop
      SELECT NIF INTO xNIF FROM CONTRIBUYENTES WHERE TRIM(NIF)=TRIM(v1.NIFAEAT);
      UPDATE AGENCIA SET NIFAEATCONTRI=xNIF WHERE CURRENT OF C1;      
   end loop;
end;

-- select count(*) from aliasdni 2055
-- select count(*) from contribuyentes 135495

DECLARE
   xNIF CHAR(10);   
   CURSOR C1 IS SELECT A.ID,a.nif,a.nifcontri,a.nifaeat,a.nombreaeat,a.TIPO_via,a.calleconletra as calle,a.numero,a.escalera,a.piso,
   						  a.puerta,a.cod_postal,a.poblacion,a.provincia,a.existeaeat,a.nifaeatcontri,c.estado_civil,c.tipo_correo,c.pais,c.telefono,c.movil,
   						  c.email,c.conyuge,c.representante,c.personalidad   
   FROM AGENCIA A,CONTRIBUYENTES C 
			WHERE A.NIFAEATCONTRI=C.NIF AND A.VALIDADOOLD='F' AND A.CARGADO='N' AND A.ID NOT IN (303,142,719,139,3288,4009,4370,4148,4461);
BEGIN

	FOR v1 IN C1
	LOOP

   	-- si nifaeat no existe lo creamos en la B.D.
   	IF v1.EXISTEAEAT='N' THEN
	   	xNIF:=v1.NIFAEAT;   		
			INSERT INTO CONTRIBUYENTES 
   			(NIF,NOMBRE,VIA,CALLE,NUMERO,ESCALERA,PLANTA,PISO,POBLACION,PROVINCIA,CODIGO_POSTAL,ESTADO_CIVIL,TIPO_CORREO,
   			PAIS,TELEFONO,MOVIL,EMAIL,CONYUGE,REPRESENTANTE,PERSONALIDAD,BUENODEMOTE,VALIDADO) 
   		VALUES(v1.NIFAEAT,v1.NOMBREAEAT,v1.TIPO_VIA,v1.CALLE,v1.NUMERO,v1.ESCALERA,v1.PISO,v1.PUERTA,v1.POBLACION,
   			v1.PROVINCIA,v1.COD_POSTAL,v1.ESTADO_CIVIL,v1.TIPO_CORREO,
   			v1.PAIS,v1.TELEFONO,v1.MOVIL,v1.EMAIL,v1.CONYUGE,v1.REPRESENTANTE,v1.PERSONALIDAD,'N','A');
      -- si existe actualizamos sus datos a los enviados por la Agencia
   	ELSE
	   	xNIF:=v1.NIFAEATCONTRI;
   	   update contribuyentes set nombre=v1.nombreaeat,
										  via=v1.tipo_via,
				 						  calle=v1.calle,
										  numero=v1.numero,
										  escalera=v1.escalera,
										  planta=v1.piso,
										  piso=v1.puerta,
										  codigo_postal=v1.cod_postal,
										  poblacion=v1.poblacion,
										  provincia=v1.provincia,
										  validado='A'
			where NIF=v1.nifaeatcontri;   
   	END IF;   	
   	
   	-- una vez que existe creamos el mote 
   	ADDMOTES(v1.nifcontri||'/',xNIF);
   	
   	UPDATE AGENCIA SET CARGADO='S' WHERE ID=V1.ID;
   
   END LOOP;
END;

-- select count(*) from aliasdni 2058
-- select count(*) from contribuyentes 135497

DECLARE
   xNIF CHAR(10);   
   CURSOR C1 IS SELECT a.nif,a.nifaeat,a.nombreaeat,a.tipo_via,a.calleconletra as calle,a.numero,a.escalera,a.piso,
   						  a.puerta,a.cod_postal,a.poblacion,a.provincia,a.existeaeat,a.nifaeatcontri,c.estado_civil,c.tipo_correo,c.pais,c.telefono,c.movil,
   						  c.email,c.conyuge,c.representante,c.personalidad   
   FROM AGENCIA A,CONTRIBUYENTES C 
			WHERE A.NIFCONTRI=C.NIF AND A.NIF<>A.NIFAEAT AND A.VALIDADOOLD<>'A' AND A.NOMBRE=A.NOMBREAEAT AND A.CALLE=C.CALLE AND CARGADO='N';
			
BEGIN

	FOR v1 IN C1
	LOOP

   	-- si nifaeat no existe lo creamos en la B.D.
   	IF v1.EXISTEAEAT='N' THEN
	   	xNIF:=v1.NIFAEAT;   		
			INSERT INTO CONTRIBUYENTES 
   			(NIF,NOMBRE,VIA,CALLE,NUMERO,ESCALERA,PLANTA,PISO,POBLACION,PROVINCIA,CODIGO_POSTAL,ESTADO_CIVIL,TIPO_CORREO,
   			PAIS,TELEFONO,MOVIL,EMAIL,CONYUGE,REPRESENTANTE,PERSONALIDAD,BUENODEMOTE,VALIDADO) 
   		VALUES(v1.NIFAEAT,v1.NOMBREAEAT,v1.TIPO_VIA,v1.CALLE,v1.NUMERO,v1.ESCALERA,v1.PISO,v1.PUERTA,v1.POBLACION,
   			v1.PROVINCIA,v1.COD_POSTAL,v1.ESTADO_CIVIL,v1.TIPO_CORREO,
   			v1.PAIS,v1.TELEFONO,v1.MOVIL,v1.EMAIL,v1.CONYUGE,v1.REPRESENTANTE,v1.PERSONALIDAD,'N','A');
      -- si existe actualizamos sus datos a los enviados por la Agencia
   	ELSE
	   	xNIF:=v1.NIFAEATCONTRI;
   	   update contribuyentes set nombre=v1.nombreaeat,
										  via=v1.TIPO_via,
				 						  calle=v1.calle,
										  numero=v1.numero,
										  escalera=v1.escalera,
										  planta=v1.piso,
										  piso=v1.puerta,
										  codigo_postal=v1.cod_postal,
										  poblacion=v1.poblacion,
										  provincia=v1.provincia,
										  validado='A'
			where NIF=v1.nifaeatcontri;   
   	END IF;   	
   	
   	-- una vez que existe creamos el mote 
   	ADDMOTES(v1.nif||'/',xNIF);
   	
   	UPDATE AGENCIA SET CARGADO='S' WHERE TRIM(NIFAEAT)=TRIM(xNIF);
   
   END LOOP;
END;

-- select count(*) from aliasdni 2059
-- select count(*) from contribuyentes 135497


DECLARE
   xNIF CHAR(10);   
   CURSOR C1 IS SELECT a.nif,a.nifaeat,a.nombreaeat,a.tipo_via,a.calleconletra as calle,a.numero,a.escalera,a.piso,
   						  a.puerta,a.cod_postal,a.poblacion,a.provincia,a.existeaeat,a.nifaeatcontri,c.estado_civil,c.tipo_correo,c.pais,c.telefono,c.movil,
   						  c.email,c.conyuge,c.representante,c.personalidad   
   FROM AGENCIA A,CONTRIBUYENTES C 
			WHERE A.NIFCONTRI=C.NIF AND A.NIF<>A.NIFAEAT AND A.VALIDADOOLD<>'A' AND A.NOMBRE=A.NOMBREAEAT AND 
			SUBSTR(A.CALLE,1,10)=SUBSTR(C.CALLE,1,10) AND CARGADO='N';
			
BEGIN

	FOR v1 IN C1
	LOOP

   	-- si nifaeat no existe lo creamos en la B.D.
   	IF v1.EXISTEAEAT='N' THEN
	   	xNIF:=v1.NIFAEAT;   		
			INSERT INTO CONTRIBUYENTES 
   			(NIF,NOMBRE,VIA,CALLE,NUMERO,ESCALERA,PLANTA,PISO,POBLACION,PROVINCIA,CODIGO_POSTAL,ESTADO_CIVIL,TIPO_CORREO,
   			PAIS,TELEFONO,MOVIL,EMAIL,CONYUGE,REPRESENTANTE,PERSONALIDAD,BUENODEMOTE,VALIDADO) 
   		VALUES(v1.NIFAEAT,v1.NOMBREAEAT,v1.TIPO_VIA,v1.CALLE,v1.NUMERO,v1.ESCALERA,v1.PISO,v1.PUERTA,v1.POBLACION,
   			v1.PROVINCIA,v1.COD_POSTAL,v1.ESTADO_CIVIL,v1.TIPO_CORREO,
   			v1.PAIS,v1.TELEFONO,v1.MOVIL,v1.EMAIL,v1.CONYUGE,v1.REPRESENTANTE,v1.PERSONALIDAD,'N','A');
      -- si existe actualizamos sus datos a los enviados por la Agencia
   	ELSE
	   	xNIF:=v1.NIFAEATCONTRI;
   	   update contribuyentes set nombre=v1.nombreaeat,
										  via=v1.TIPO_via,
				 						  calle=v1.calle,
										  numero=v1.numero,
										  escalera=v1.escalera,
										  planta=v1.piso,
										  piso=v1.puerta,
										  codigo_postal=v1.cod_postal,
										  poblacion=v1.poblacion,
										  provincia=v1.provincia,
										  validado='A'
			where NIF=v1.nifaeatcontri;   
   	END IF;   	
   	
   	-- una vez que existe creamos el mote 
   	ADDMOTES(v1.nif||'/',xNIF);
   	
   	UPDATE AGENCIA SET CARGADO='S' WHERE NIFAEAT=xNIF;
   
   END LOOP;
END;

-- select count(*) from aliasdni 2064
-- select count(*) from contribuyentes 135500

DECLARE
   xNIF CHAR(10);   
   CURSOR C1 IS SELECT a.nif,a.nifaeat,a.nombreaeat,a.tipo_via,a.calleconletra as calle,a.numero,a.escalera,a.piso,
   						  a.puerta,a.cod_postal,a.poblacion,a.provincia,a.existeaeat,a.nifaeatcontri,c.estado_civil,c.tipo_correo,c.pais,c.telefono,c.movil,
   						  c.email,c.conyuge,c.representante,c.personalidad   
   FROM AGENCIA A,CONTRIBUYENTES C 
			WHERE A.NIFCONTRI=C.NIF AND A.NIF<>A.NIFAEAT AND A.VALIDADOOLD<>'A' AND substr(A.NOMBRE,1,10)=substr(A.NOMBREAEAT,1,10) AND 
			SUBSTR(A.CALLE,1,10)=SUBSTR(C.CALLE,1,10) AND CARGADO='N' for update of cargado;
			
BEGIN

	FOR v1 IN C1
	LOOP

   	-- si nifaeat no existe lo creamos en la B.D.
   	IF v1.EXISTEAEAT='N' THEN
	   	xNIF:=v1.NIFAEAT;   		
			INSERT INTO CONTRIBUYENTES 
   			(NIF,NOMBRE,VIA,CALLE,NUMERO,ESCALERA,PLANTA,PISO,POBLACION,PROVINCIA,CODIGO_POSTAL,ESTADO_CIVIL,TIPO_CORREO,
   			PAIS,TELEFONO,MOVIL,EMAIL,CONYUGE,REPRESENTANTE,PERSONALIDAD,BUENODEMOTE,VALIDADO) 
   		VALUES(v1.NIFAEAT,v1.NOMBREAEAT,v1.TIPO_VIA,v1.CALLE,v1.NUMERO,v1.ESCALERA,v1.PISO,v1.PUERTA,v1.POBLACION,
   			v1.PROVINCIA,v1.COD_POSTAL,v1.ESTADO_CIVIL,v1.TIPO_CORREO,
   			v1.PAIS,v1.TELEFONO,v1.MOVIL,v1.EMAIL,v1.CONYUGE,v1.REPRESENTANTE,v1.PERSONALIDAD,'N','A');
      -- si existe actualizamos sus datos a los enviados por la Agencia
   	ELSE
	   	xNIF:=v1.NIFAEATCONTRI;
   	   update contribuyentes set nombre=v1.nombreaeat,
										  via=v1.TIPO_via,
				 						  calle=v1.calle,
										  numero=v1.numero,
										  escalera=v1.escalera,
										  planta=v1.piso,
										  piso=v1.puerta,
										  codigo_postal=v1.cod_postal,
										  poblacion=v1.poblacion,
										  provincia=v1.provincia,
										  validado='A'
			where NIF=v1.nifaeatcontri;   
   	END IF;   	
   	
   	-- una vez que existe creamos el mote 
   	ADDMOTES(v1.nif||'/',xNIF);
   	
   	UPDATE AGENCIA SET CARGADO='S' WHERE CURRENT OF C1;
   
   END LOOP;
END;

-- select count(*) from aliasdni 2068
-- select count(*) from contribuyentes 135500

DECLARE
   xNIF CHAR(10);   
   CURSOR C1 IS SELECT a.nif,a.nifaeat,a.nombreaeat,a.tipo_via,a.calleconletra as calle,a.numero,a.escalera,a.piso,
   						  a.puerta,a.cod_postal,a.poblacion,a.provincia,a.existeaeat,a.nifaeatcontri,c.estado_civil,c.tipo_correo,c.pais,c.telefono,c.movil,
   						  c.email,c.conyuge,c.representante,c.personalidad   
   FROM AGENCIA A,CONTRIBUYENTES C 
			WHERE A.NIFCONTRI=C.NIF AND A.NIF<>A.NIFAEAT AND A.VALIDADOOLD<>'A' AND substr(A.NOMBRE,1,5)=substr(A.NOMBREAEAT,1,5) AND 
			SUBSTR(A.CALLE,1,5)=SUBSTR(C.CALLE,1,5) AND CARGADO='N' for update of cargado;
			
BEGIN

	FOR v1 IN C1
	LOOP

   	-- si nifaeat no existe lo creamos en la B.D.
   	IF v1.EXISTEAEAT='N' THEN
	   	xNIF:=v1.NIFAEAT;   		
			INSERT INTO CONTRIBUYENTES 
   			(NIF,NOMBRE,VIA,CALLE,NUMERO,ESCALERA,PLANTA,PISO,POBLACION,PROVINCIA,CODIGO_POSTAL,ESTADO_CIVIL,TIPO_CORREO,
   			PAIS,TELEFONO,MOVIL,EMAIL,CONYUGE,REPRESENTANTE,PERSONALIDAD,BUENODEMOTE,VALIDADO) 
   		VALUES(v1.NIFAEAT,v1.NOMBREAEAT,v1.TIPO_VIA,v1.CALLE,v1.NUMERO,v1.ESCALERA,v1.PISO,v1.PUERTA,v1.POBLACION,
   			v1.PROVINCIA,v1.COD_POSTAL,v1.ESTADO_CIVIL,v1.TIPO_CORREO,
   			v1.PAIS,v1.TELEFONO,v1.MOVIL,v1.EMAIL,v1.CONYUGE,v1.REPRESENTANTE,v1.PERSONALIDAD,'N','A');
      -- si existe actualizamos sus datos a los enviados por la Agencia
   	ELSE
	   	xNIF:=v1.NIFAEATCONTRI;
   	   update contribuyentes set nombre=v1.nombreaeat,
										  via=v1.TIPO_via,
				 						  calle=v1.calle,
										  numero=v1.numero,
										  escalera=v1.escalera,
										  planta=v1.piso,
										  piso=v1.puerta,
										  codigo_postal=v1.cod_postal,
										  poblacion=v1.poblacion,
										  provincia=v1.provincia,
										  validado='A'
			where NIF=v1.nifaeatcontri;   
   	END IF;   	
   	
   	-- una vez que existe creamos el mote 
   	ADDMOTES(v1.nif||'/',xNIF);
   	
   	UPDATE AGENCIA SET CARGADO='S' WHERE CURRENT OF C1;
   
   END LOOP;
END;

-- select count(*) from aliasdni 2079
-- select count(*) from contribuyentes 135506

DECLARE
   xNIF CHAR(10);   
   CURSOR C1 IS SELECT a.nif,a.nifaeat,a.nombreaeat,a.tipo_via,a.calleconletra as calle,a.numero,a.escalera,a.piso,
   						  a.puerta,a.cod_postal,a.poblacion,a.provincia,a.existeaeat,a.nifaeatcontri,c.estado_civil,c.tipo_correo,c.pais,c.telefono,c.movil,
   						  c.email,c.conyuge,c.representante,c.personalidad   
   FROM AGENCIA A,CONTRIBUYENTES C 
			WHERE A.NIFCONTRI=C.NIF AND A.NIF<>A.NIFAEAT AND A.VALIDADOOLD<>'A' AND substr(A.NOMBRE,1,5)=substr(A.NOMBREAEAT,1,5) AND 
			CARGADO='N' AND A.ID<>2024 for update of cargado;
			
BEGIN

	FOR v1 IN C1
	LOOP

   	-- si nifaeat no existe lo creamos en la B.D.
   	IF v1.EXISTEAEAT='N' THEN
	   	xNIF:=v1.NIFAEAT;   		
			INSERT INTO CONTRIBUYENTES 
   			(NIF,NOMBRE,VIA,CALLE,NUMERO,ESCALERA,PLANTA,PISO,POBLACION,PROVINCIA,CODIGO_POSTAL,ESTADO_CIVIL,TIPO_CORREO,
   			PAIS,TELEFONO,MOVIL,EMAIL,CONYUGE,REPRESENTANTE,PERSONALIDAD,BUENODEMOTE,VALIDADO) 
   		VALUES(v1.NIFAEAT,v1.NOMBREAEAT,v1.TIPO_VIA,v1.CALLE,v1.NUMERO,v1.ESCALERA,v1.PISO,v1.PUERTA,v1.POBLACION,
   			v1.PROVINCIA,v1.COD_POSTAL,v1.ESTADO_CIVIL,v1.TIPO_CORREO,
   			v1.PAIS,v1.TELEFONO,v1.MOVIL,v1.EMAIL,v1.CONYUGE,v1.REPRESENTANTE,v1.PERSONALIDAD,'N','A');
      -- si existe actualizamos sus datos a los enviados por la Agencia
   	ELSE
	   	xNIF:=v1.NIFAEATCONTRI;
   	   update contribuyentes set nombre=v1.nombreaeat,
										  via=v1.TIPO_via,
				 						  calle=v1.calle,
										  numero=v1.numero,
										  escalera=v1.escalera,
										  planta=v1.piso,
										  piso=v1.puerta,
										  codigo_postal=v1.cod_postal,
										  poblacion=v1.poblacion,
										  provincia=v1.provincia,
										  validado='A'
			where NIF=v1.nifaeatcontri;   
   	END IF;   	
   	
   	-- una vez que existe creamos el mote 
   	ADDMOTES(v1.nif||'/',xNIF);
   	
   	UPDATE AGENCIA SET CARGADO='S' WHERE CURRENT OF C1;
   
   END LOOP;
END;

-- select count(*) from aliasdni 2138
-- select count(*) from contribuyentes 135548

DECLARE
   xNIF CHAR(10);   
   CURSOR C1 IS SELECT a.nif,a.nifaeat,a.nombreaeat,a.tipo_via,a.calleconletra as calle,a.numero,a.escalera,a.piso,
   						  a.puerta,a.cod_postal,a.poblacion,a.provincia,a.existeaeat,a.nifaeatcontri,c.estado_civil,c.tipo_correo,c.pais,c.telefono,c.movil,
   						  c.email,c.conyuge,c.representante,c.personalidad   
   FROM AGENCIA A,CONTRIBUYENTES C 
			WHERE A.ID IN (6320,4442,308,4237,1757,120) for update of cargado;
			
BEGIN

	FOR v1 IN C1
	LOOP

   	-- si nifaeat no existe lo creamos en la B.D.
   	IF v1.EXISTEAEAT='N' THEN
	   	xNIF:=v1.NIFAEAT;   		
			INSERT INTO CONTRIBUYENTES 
   			(NIF,NOMBRE,VIA,CALLE,NUMERO,ESCALERA,PLANTA,PISO,POBLACION,PROVINCIA,CODIGO_POSTAL,ESTADO_CIVIL,TIPO_CORREO,
   			PAIS,TELEFONO,MOVIL,EMAIL,CONYUGE,REPRESENTANTE,PERSONALIDAD,BUENODEMOTE,VALIDADO) 
   		VALUES(v1.NIFAEAT,v1.NOMBREAEAT,v1.TIPO_VIA,v1.CALLE,v1.NUMERO,v1.ESCALERA,v1.PISO,v1.PUERTA,v1.POBLACION,
   			v1.PROVINCIA,v1.COD_POSTAL,v1.ESTADO_CIVIL,v1.TIPO_CORREO,
   			v1.PAIS,v1.TELEFONO,v1.MOVIL,v1.EMAIL,v1.CONYUGE,v1.REPRESENTANTE,v1.PERSONALIDAD,'N','A');
      -- si existe actualizamos sus datos a los enviados por la Agencia
   	ELSE
	   	xNIF:=v1.NIFAEATCONTRI;
   	   update contribuyentes set nombre=v1.nombreaeat,
										  via=v1.TIPO_via,
				 						  calle=v1.calle,
										  numero=v1.numero,
										  escalera=v1.escalera,
										  planta=v1.piso,
										  piso=v1.puerta,
										  codigo_postal=v1.cod_postal,
										  poblacion=v1.poblacion,
										  provincia=v1.provincia,
										  validado='A'
			where NIF=v1.nifaeatcontri;   
   	END IF;   	
   	
   	-- una vez que existe creamos el mote 
   	ADDMOTES(v1.nif||'/',xNIF);
   	
   	UPDATE AGENCIA SET CARGADO='S' WHERE CURRENT OF C1;
   
   END LOOP;
END;


-- después de una revisión manual

-- select count(*) from aliasdni 2141
-- select count(*) from contribuyentes 135551

-- Hasta ahora se han validado 4031 contribuyentes
-- Había 2242 contribuyentes ya validados por antiguos envios a la Agencia
-- 2141 - 2055 = 86 nuevos motes

/*************************************************************************************************************************************************/

CREATE OR REPLACE PROCEDURE SEGUNDA_NOTI_AGENCIA
AS
	mNumero CHAR(10);
	xCuantos INTEGER;		
	xZona char(2);
	

	xNIF 			CHAR(10);
	xContador 		INTEGER;
	xN_ORDEN 		INTEGER;
	xContadorRecibos	INTEGER;
	xMaximoPermitido	INTEGER;
	xResto		INTEGER;
	xNumeroObjetos	INTEGER;
	xCodOpe		INTEGER;


	-- Selecciona todos los valores de un nif validado por la agencia que no esten enviados al bop 
	-- y tengan acuse de recibo=0302 (valores en ejecutiva)
	-- agrupandolos por nif, para poder poner varios valores en un mismo impreso.
	CURSOR CGRUPO IS
		SELECT count(*) AS CUANTOS,V.NIF 
		FROM VALORES V, CONTRIBUYENTES C
		WHERE V.NIF=C.NIF AND
				V.ID IN (select valor from notificaciones
                  	where tipo_noti<>'VOL' and last_acuse='0302' and f_envio_bop is null)
            AND C.VALIDADO='A'
	    		AND V.VOL_EJE='E'
	      	AND V.NOTIFICADO='N'
      		AND V.F_INGRESO IS NULL
	      	AND V.FECHA_DE_BAJA IS NULL
	GROUP BY V.NIF;

	-- Una vez que se tiene un nif y se sabe cuantos recibos hay del mismo, se recorren estos uno
	-- a uno para ir actualizando su n_orden y relacion de apremio.
	CURSOR cNotificacion IS
		SELECT ID FROM VALORES V
		WHERE NIF=xNIF AND 
			   ID IN (select valor from notificaciones
                   where valor=v.id and tipo_noti<>'VOL' and last_acuse='0302' and f_envio_bop is null)                   
	    		AND VOL_EJE='E'
	      	AND NOTIFICADO='N'
      		AND F_INGRESO IS NULL
	      	AND FECHA_DE_BAJA IS NULL
	FOR UPDATE OF RELACION_APREMIO,RECARGO,ORDEN_APREMIO,CODIGO_OPERACION;

BEGIN
   
   xCuantos:=0;

   select zona into xZona from usuarios where usuario=user;

   DAME_RELACION(mNumero);   

   -- Genero una nueva relacion de notificaciones.
   INSERT INTO RELACIONES_NOTI
        (RELACION,FECHA,CARGO,AYTO,USUARIO,ZONA,SUFIJO,YEAR,REMESA)
   VALUES (mNumero,sysdate,'','',USER,xZona,'000','00','00');

   -- El Flag N_RECIBOS_NOTI indica cuantos recibos cogen en un impreso de notificación
   SELECT N_RECIBOS_NOTI INTO xMaximoPermitido FROM CONFIGURACION
	WHERE ZONA=(SELECT ZONA FROM USUARIOS WHERE USUARIO=USER);

   xN_ORDEN:=1;

   FOR v_NIF IN CGRUPO LOOP

		xNIF:=v_NIF.NIF;
		xContador:=0;
		xContadorRecibos:=v_NIF.CUANTOS;
		CODIGO_OPERACION(xCodOpe); -- Obtengo un código de operación.

		-- Si hay mas recibos de los que cogen en un impreso, miro cuantos entran en el último
		-- impreso, porque en la notificación se pone el número de recibos que tiene el impreso.

		-- EJEMPLO: hay 10 recibos y en el impreso cogen 4. Los 8 primeros recibos estarán en
		-- 2 impresos distintos, indicando sus notificaciones que hay 4 recibos en el impreso.
		-- Los 2 recibos restantes estaran en un tercer impreso, y sus notificaciones indicarán
		-- que hay 2 recibos en el mismo.
		IF v_NIF.CUANTOS > xMaximoPermitido THEN
         xResto:=MOD(v_NIF.CUANTOS,xMaximoPermitido);
   	END IF;

		for v_Noti IN cNotificacion 
		loop

	   	-- Para rellenar el campo NUMERO_OBJETOS de la notificación hay que calcular
	   	-- cuantos recibos entran en el impreso en el que se encuadra el recibo actual.
	   	IF NOT ES_NIF_INDIVIDUAL(xNIF) THEN -- Si el nif agrupa a varias personas, cada una
							   							-- irá en un impreso distinto.
				xNumeroObjetos:=1;

	   	ELSIF v_NIF.CUANTOS > xMaximoPermitido THEN -- Si hay mas recibos de los permitidos
	   		xContadorRecibos:=xContadorRecibos-1;
	   		IF xContadorRecibos < xResto THEN
		   		-- Son los recibos restantes (no se completa el impreso)
		   		xNumeroObjetos:=xResto;
	   		ELSE -- El recibo estará en un impreso totalmente relleno.
		   		xNumeroObjetos:=xMaximoPermitido;
	   		END IF;
	   	ELSE
	      	xNumeroObjetos:=v_NIF.CUANTOS;
   	   END IF;

	   	IF xContador=xMaximoPermitido THEN
	  			xN_ORDEN:=xN_ORDEN+1;
				xContador:=0;
				PkCartaPagoBanco.NewCartaPago; -- Creo una nueva carta de pago y le meto
				PkCartaPagoBanco.AddReciboSeleccionados(xCodOpe,mNumero); -- los recibos del impreso
				CODIGO_OPERACION(xCodOpe); -- Obtengo un nuevo código de operación.
	   	END IF;
	   	xContador:=xContador+1;

	   	UPDATE VALORES SET RELACION_APREMIO=mNumero,
	   							 ORDEN_APREMIO=xN_ORDEN,
									 CODIGO_OPERACION=xCodOpe
	   	where current of cNotificacion;

	   	xCuantos:=xCuantos + 1;

	   	UPDATE NOTIFICACIONES SET F_2INTENTO=sysdate,
				  							  F_INTENTO=sysdate,
		              					  N_ENVIOS=N_ENVIOS + 1 ,
				  							  ID_COSTAS=NULL,
				  							  N_RELACION=mNumero,
				  							  N_ORDEN=xN_ORDEN,
				  							  NUMERO_OBJETOS=xNumeroObjetos
	   	WHERE VALOR=v_NOTI.ID and Tipo_noti<>'VOL';

	   	IF NOT ES_NIF_INDIVIDUAL(xNIF) THEN -- Si es individual aunque no lo parezca.
				xN_ORDEN:=xN_ORDEN+1;
				xContador:=0;
				PkCartaPagoBanco.NewCartaPago; -- Creo una nueva carta de pago y le meto
				PkCartaPagoBanco.AddReciboSeleccionados(xCodOpe,mNumero); -- los recibos del impreso
	   		CODIGO_OPERACION(xCodOpe); -- Obtengo un nuevo código de operación.
	   	END IF;

		end loop;

   	IF ES_NIF_INDIVIDUAL(xNIF) THEN -- Si es individual el NIF, no se imprimio la carta.
	   	-- Introduzco los últimos del impreso.
	   	PkCartaPagoBanco.NewCartaPago; -- Creo una nueva carta de pago y le meto
	   	PkCartaPagoBanco.AddReciboSeleccionados(xCodOpe,mNumero); -- los recibos del impreso
	   	CODIGO_OPERACION(xCodOpe); -- Obtengo un nuevo código de operación.
	   	xN_ORDEN:=xN_ORDEN+1;
		END IF;

	END LOOP;

   UPDATE RELACIONES_NOTI SET RECIBOS=xCuantos WHERE RELACION=mNumero;

END;
/


/********************** Consulta para Ricardo ***********************************/
--Esta consulta la necesitaremos en cada respuesta de la AEAT. 
--La consulta que necesitamos para evaluar ha de terner los siguientes campos: 
        --concepto. 
        --ejercicio. 
        --nº recibo o liquidación. 
        --los campos de identificación del deudor: nif, nombre, y el domiclio fiscal que se complete. 
        --los campos de identificación de la deuda: objeto tributario, cuota. 
        --los campos del estado: si es de voluntaria, de ejecutiva, como esta grabado el acuse 
        --(saber en que estado está el recibo en el procedimiento de recaudación).
        
CREATE TABLE AGENCIA1_CONSUL(
	ID	INTEGER,
	PADRON CHAR(6),
	YEAR   CHAR(4),
	RECIBO INTEGER,
	NIF CHAR(10),
	NOMBRE VARCHAR2(40),
	DOM_FISCAL VARCHAR2(50),
	CODIGO_POSTAL CHAR(5),
	POBLACION VARCHAR2(35),
	PROVINCIA VARCHAR2(35),
	CLAVE_CONCEPTO VARCHAR2(30),
	OBJETO_TRIBUTARIO	VARCHAR2(1024),
	PRINCIPAL FLOAT,
	VOL_EJE CHAR(1),
	NOTIFICADO CHAR(1),
	F_NOTIFICACION DATE,
	LAST_ACUSE CHAR(4),
	F_INGRESO DATE,
	FECHA_DE_BAJA DATE,
	F_SUSPENSION DATE,
	FECHA_PROPUESTA_BAJA DATE
);


CREATE OR REPLACE PROCEDURE RELLENAR_CONSULTA_AGENCIA
AS
	xNIF CHAR(10);
	xLAST_ACUSE CHAR(4);
	xIDNOTI INTEGER;
	CURSOR C1 IS SELECT * FROM CONTRIBUYENTES WHERE TRIM(NIF) IN (SELECT NIF FROM AGENCIA WHERE CARGADO='S');
	CURSOR C2 IS SELECT * FROM VALORES WHERE TRIM(NIF)=TRIM(xNIF) AND F_INGRESO IS NULL AND FECHA_DE_BAJA IS NULL;
BEGIN
	FOR v1 IN C1
	LOOP
		xNIF:=v1.NIF;
		FOR v2 IN C2 
		LOOP		
			
		   SELECT DECODE(MAX(ID),NULL,0,MAX(ID)) INTO xIDNOTI FROM NOTIFICACIONES WHERE VALOR=v2.ID;			
		   
			IF xIDNOTI>0 THEN
			   SELECT LAST_ACUSE INTO xLAST_ACUSE FROM NOTIFICACIONES WHERE ID=xIDNOTI;
			ELSE
			   xLAST_ACUSE:=NULL;
			END IF;
			
		   INSERT INTO AGENCIA1_CONSUL(ID,PADRON,YEAR,RECIBO,NIF,NOMBRE,DOM_FISCAL,CODIGO_POSTAL,POBLACION,
					 PROVINCIA,CLAVE_CONCEPTO,OBJETO_TRIBUTARIO,PRINCIPAL,VOL_EJE,NOTIFICADO,F_NOTIFICACION,
					 LAST_ACUSE,F_INGRESO,FECHA_DE_BAJA,F_SUSPENSION,FECHA_PROPUESTA_BAJA)
			VALUES (v2.ID,v2.PADRON,v2.YEAR,v2.RECIBO,v2.NIF,v1.NOMBRE,
			       TRIM(v1.VIA)||' '||TRIM(v1.CALLE)||' '||TRIM(v1.NUMERO)||' '||TRIM(v1.ESCALERA)||' '||
			       TRIM(v1.PLANTA)||' '||TRIM(v1.PISO),v1.CODIGO_POSTAL,v1.POBLACION,
			       v1.PROVINCIA,v2.CLAVE_CONCEPTO,TRIM(v2.OBJETO_TRIBUTARIO),v2.PRINCIPAL,v2.VOL_EJE,
			       v2.NOTIFICADO,v2.F_NOTIFICACION,xLAST_ACUSE,v2.F_INGRESO,v2.FECHA_DE_BAJA,
			       v2.F_SUSPENSION,v2.FECHA_PROPUESTA_BAJA);
			       		   
		END LOOP;		
	END LOOP;
END;
/
















-- procedimiento para cargar los nuevos domicilios fiscales 
-- primera pasada para cargar los domicilios fiscales para las coincidencias tanto en nif como en nombre 
-- Se han cargado 2810 

-- procedimiento para cargar los nuevos domicilios fiscales y el nombre 
-- segunda pasada para cargar los datos en los que coincide tanto el nif como los diez primeros caracteres del nombre.
-- Se han cargado 620 

-- procedimiento para cargar los nuevos domicilios fiscales y el nombre 
-- tercera pasada para cargar los datos en los que coinciden tanto el nif como la calle y el número 
-- Se han cargado 89 

-- procedimiento para cargar los nuevos domicilios fiscales y el nombre 
-- cuarta pasada para cargar los datos en los que coinciden tanto el nif los 5 primeros caracteres de la calle (previa inspección visual) 
-- Se han cargado 98 

-- procedimiento para cargar los nuevos domicilios fiscales y el nombre 
-- quinta pasada para cargar los datos en los que coinciden tanto el nif los 5 primeros caracteres del nombre (previa inspección visual) 
-- Se han cargado 155 

-- procedimiento para cargar los nuevos domiclios fiscales y el nombre 
-- sexta pasada para cargar los datos en los que coincide el nif y se ha hecho una revisión visual.
-- Se han cargado 140 


4031 + 27 + 21 =  4079


-- modificamos la tabla de valores, cambiando los nifs que son mote por el correcto
DECLARE
   xMOTE CHAR(10);
   xNIF  CHAR(10);
   xNOMBRE VARCHAR2(40);
   CURSOR C1 IS SELECT NIF FROM CONTRIBUYENTES WHERE VALIDADO='M';
   CURSOR C2 IS SELECT ID FROM VALORES WHERE NIF=xMOTE;
BEGIN
   FOR v1 IN C1
   LOOP
   	xMOTE:=v1.NIF;
   	FOR v2 IN C2
   	LOOP
         SELECT NIFBUENO INTO xNIF FROM ALIASDNI WHERE ALIASNIF=xMOTE;  	
         SELECT NOMBRE INTO xNOMBRE FROM CONTRIBUYENTES WHERE NIF=xNIF;
   	   UPDATE VALORES SET NIF=xNIF,NOMBRE=xNOMBRE WHERE ID=v2.ID;
   	END LOOP;
   END LOOP;
END;

-- tabla de notificaciones
UPDATE NOTIFICACIONES SET NIF=(SELECT NIF FROM VALORES WHERE ID=NOTIFICACIONES.VALOR);
