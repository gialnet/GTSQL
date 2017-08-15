/* 

Listado de posibles errores a la hora de cargar los registros (tanto manual como auto):

0: REGISTRO NO CARGADO: es el estado inicial de un registro, de forma que una vez elegida su 
   carga, pasará siempre a otro estado, salvo cuando tenga una fecha de trámite inferior al 
   año actual.
1: MUNICIPIO no existe: es el estado en el que un registro no se ha cargado por no existir el 
   MUNICIPIO en la base de datos.
2: INCIDENCIA, TIPO DE VEHICULO erróneo: es el estado en el que un registro no ha sido cargado 
   por error en el tipo de vehículo al ser uno de los siguientes: vehículo articulado,
   vehículo mixto, furgoneta, furgoneta mixta, vehículo especial, ambulancia o máquina agrícola.
3: ERROR: ALTA YA EXISTE: es el estado en el que un registro ha intentado ser dado de alta 
   cuando en realidad ya lo está.
4: ERROR: EL VEHÍCULO NO EXISTE: es el estado en el que un registro ha intentado darse de baja 
   o ser rematriculado y no existía previamente.
5: ERROR: DNI NO ASOCIADO AL VEHÍCULO: es el estado en el que un registro ha intentado darse 
   de baja sin que coincida el DNI de su propietario con el que figura como tal en nuestra 
   base de datos.
6: ERROR: VEHÍCULO DADO DE BAJA: Se producirá cuando se quiera dar de baja un vehículo que ya
   lo está, o se quiera dar de alta o rematricular un vehículo dado de baja.
7: ERROR: MATRÍCULA IDÉNTICA: Si se va a rematricular un vehículo y la nueva matrícula 
   coincide con la anterior.
8: PENDIENTE SELECCIÓN CARGA MANUAL
9: NO CARGADO POR SER DE TIPO MODIT,MODIF O DUPLI
10: NO CARGADO POR HABERSE PROCESADO UN REGISTRO CON FECHA DE TRAMITE POSTERIOR
11: NO CARGADO POR NO ENCONTRAR SU TARIFA
12: REGISTRO DUPLICADO EN LA BASE DE DATOS. SE DEJA PARA SER ARREGLADO MANUALMENTE
*/

--delete trafico_new where to_char(fecha_tramite,'yyyy')='2005'

--select to_char(fecha_tramite,'yyyy'),count(*) from trafico_new group by to_char(fecha_tramite,'yyyy')

--delete trafico_new where to_char(fecha_tramite,'yyyy')='2006'


alter table trafico_new add Ciudad VARCHAR2(3)

alter table trafico_new add Numero VARCHAR2(6)

alter table trafico_new add Letra VARCHAR2(3)

alter table trafico_new add Marca VARCHAR2(25)

alter table trafico_new add Modelo VARCHAR2(25)

alter table trafico_new add Caballos_Exac Float

alter table trafico_new add CodTipoVehiculo VARCHAR2(5)
 
alter table trafico_new add Cargar CHAR(1) Default 'N'

alter table trafico_new add Anular CHAR(1) Default 'N'


/*begin
   --Actualizamos bastidor y tipo_vehiculo
   Update trafico_new set tipo_vehiculo = DECODE(TRIM(tipo_vehiculo),'FURGONETA','CAMION',
   										  DECODE(TRIM(tipo_vehiculo),'HORMIGONERA','CAMION',
   										  DECODE(TRIM(tipo_vehiculo),'CAMIONETA','CAMION',
   										  DECODE(TRIM(tipo_vehiculo),'FURGONETA MIXTA','CAMION',
   										  DECODE(TRIM(tipo_vehiculo),'VEHIC. ESPECIAL','TURISMO',
   										  DECODE(TRIM(tipo_vehiculo),'COCHE FUNEBRE','TURISMO',
   										  DECODE(TRIM(tipo_vehiculo),'VEHIC. MIXTO','CAMION',
   										  DECODE(TRIM(tipo_vehiculo),'MAQUINA AGRICOLA','TRACTOR',
   										  DECODE(TRIM(tipo_vehiculo),'VEHIC. VIVIENDA','CAMION',
   										  DECODE(TRIM(tipo_vehiculo),'VOLQUETE','CAMION',
   										  DECODE(TRIM(tipo_vehiculo),'VEH. ARTICULADO','CAMION',
   										  DECODE(TRIM(tipo_vehiculo),'TIPO NO CONOCIDO','MOTOCICLETA',
   										  DECODE(TRIM(tipo_vehiculo),'AMBULANCIA','TURISMO',TRIM(tipo_vehiculo)))))))))))))),
						   bastidor = replace (bastidor,'-','');
   --Actualizamos Bastidores (Todos, aunque tengan ya escrito bastidor, pues a veces estan mal en nuestra base de datos)
   Update vehiculos v set bastidor = (select distinct t.bastidor from trafico_new t 
   		where trim(replace(t.matricula,' ',''))=trim(replace(v.matricula,' ',''))||trim(replace(v.numero,' ',''))||trim(replace(v.letra,' ','')))
	where v.abonado in (select v.abonado from vehiculos v join trafico_new t 
		  			 on trim(replace(t.matricula,' ',''))=trim(replace(v.matricula,' ',''))||trim(replace(v.numero,' ',''))||trim(replace(v.letra,' ','')));
   --Actualizamos tipo_tramite
   Update trafico_new set codigo_tramite='TRANS' 
    WHERE codigo_tramite='DUPLI' AND matricula in (select matricula from trafico_new WHERE CODIGO_TRAMITE='DUPLI' group by matricula having count(*)=1);
   COMMIT;  
end;
***********Metido dentro del procedimiento de lectura por registro individual y CargaAuto... cuidado con las actualizaciones*/

Update trafico_new set codigo_tramite='TRANS' 
 WHERE codigo_tramite='DUPLI' AND matricula in (select matricula from trafico_new WHERE CODIGO_TRAMITE='DUPLI' group by matricula having count(*)=1);


select * from trafico_new

select count(*) from trafico_new

select tipo_vehiculo,count(*) from trafico_new group by tipo_vehiculo --Si hay alguno a nulo lo vemos



select bastidor from trafico_new where codigo_tramite not in ('DUPLI','MODIF','MODIT') group by bastidor having count(*)=4

select bastidor from trafico_new where codigo_tramite not in ('DUPLI','MODIF','MODIT') group by bastidor having count(*)=3

select bastidor from trafico_new where codigo_tramite not in ('DUPLI','MODIF','MODIT') group by bastidor having count(*)=2
 

/***** PARA LOS ERRORES MARCA 8 CON DUPLICIDAD, es decir, REPETIDOS CUATRO VECES *****/
Hacer lo mismo que para los marcados como error 4...

/***** PARA LOS ERRORES MARCA 8 CON DUPLICIDAD, es decir, REPETIDOS SOLO TRES VECES *****/
select t1.id,t2.id,t1.dni,t1.bastidor,t1.tipo_registro,t1.fecha_tramite,t2.tipo_registro,t2.fecha_tramite 
from trafico_new t1 join trafico_new t2 on t1.bastidor=t2.bastidor and t1.dni=t2.dni and t1.tipo_registro='A' and t2.tipo_registro='B'
where t1.bastidor in (select bastidor from trafico_new where codigo_tramite not in ('DUPLI','MODIF','MODIT') group by bastidor having count(*)=3)
order by t1.dni 

select * from trafico_new where bastidor='VS6AXXWPAAVM29828    '

delete trafico_new where id in (select t1.id
from trafico_new t1 join trafico_new t2 on t1.bastidor=t2.bastidor and t1.dni=t2.dni and t1.tipo_registro='A' and t2.tipo_registro='B'
where t1.bastidor in (select bastidor from trafico_new where codigo_tramite not in ('DUPLI','MODIF','MODIT') group by bastidor having count(*)=3)
union 
select t2.id
from trafico_new t1 join trafico_new t2 on t1.bastidor=t2.bastidor and t1.dni=t2.dni and t1.tipo_registro='A' and t2.tipo_registro='B'
where t1.bastidor in (select bastidor from trafico_new where codigo_tramite not in ('DUPLI','MODIF','MODIT') group by bastidor having count(*)=3))

delete tmp_incidencias_trafico where id_trafico in (select id_trafico from tmp_incidencias_trafico minus select id from trafico_new)

/***** PARA LOS ERRORES MARCA 8 CON DUPLICIDAD, es decir, REPETIDOS SOLO DOS VECES *****/
select * from trafico_new where bastidor in (select bastidor from trafico_new where codigo_tramite not in ('DUPLI','MODIF','MODIT') group by bastidor having count(*)=4) order by bastidor

/**************************************************************
--Los carga Francisco Campos
*****************************************************************/


/*******************TRATAMOS LOS QUE QUEDAN CON TIPO DE ERROR 4 Y 8, cruzando por matricula********************/
select marca_error,count(*) from tmp_incidencias_trafico group by marca_error

select * from trafico_new where id in (select id_trafico from tmp_incidencias_trafico where marca_error in (4,8))

DECLARE
  xMatri  varchar2(3);
  xNum  varchar2(6);
  xLetra  varchar2(3);
  xModelo  varchar2(25);
  xMarca  varchar2(25);
  xCaballos_Exac	Float;
  xCodTipoVehiculo	varchar2(5);
  xExiste   Integer;
  xError    Boolean;
  xCargado  char(1);
  xAnulado  char(1);
  cursor cVehi is Select * from trafico_new
  where id in (select id_trafico from tmp_incidencias_trafico where marca_error in (4,8) and codigo_tramite not in ('DUPLI','MODIF','MODIT') )
   for update of Ciudad,Numero,Letra,Marca,Modelo,Caballos_exac;
begin
   --Abrir Cursor para actualizacion de tabla Trafico_new
   for vVehi IN cVehi LOOP
	    xError:= False;
   		--Compobramos que existe el contriuyente, sino lo creamos
		Select count(*) into xExiste From contribuyentes Where nif = vVehi.Dni; 	
		If xExiste=0 then
		   InsertaModiContribuyente(vVehi.Dni,trim(vVehi.APELLIDO_1)||trim(vVehi.APELLIDO_2)||trim(vVehi.NOMBRE),'',
		      						vVehi.CALLE,'','','','',vVehi.PUEBLO,vVehi.PROVINCIA,vVehi.CODIGO_POSTAL,'');		
		End If;
		--separamos Marca y Modelo 
		SplitMarcaModelo(vVehi.MARCA_MODELO,xMarca,xModelo);
        --Separamos Matricula
		SplitMatricula(vVehi.MATRICULA,xMatri,xNum,xLetra);
		--Buscamos el tipo de vehiculo. y le rellenamos caballos exacciones 
		If (vVehi.tipo_vehiculo='TURISMO') or (vVehi.Tipo_Vehiculo='TRACTOR') THEN
		   xCaballos_exac := vVehi.POTENCIA;
		ElsIf vVehi.tipo_vehiculo='CAMION' THEN
			  xCaballos_exac := vVehi.CARGA;
		ElsIf vVehi.tipo_vehiculo='AUTOBUS' THEN
			  xCaballos_exac := vVehi.PLAZAS;
		ElsIf (vVehi.tipo_vehiculo='CICLOMOTOR') or (vVehi.tipo_vehiculo='MOTOCICLETA') THEN
			  xCaballos_exac := vVehi.CILINDRADA;
		ElsIf vVehi.tipo_vehiculo='REMOLQUE' THEN
			  xCaballos_exac := vVehi.CARGA;
		End IF;
		--Tomar Codigo del Tipo de Vehiculo
		begin 
		   Select codigo into xCodTipoVehiculo from tarifas_vehiculos 
		    Where VEHI_TRAFICO=vVehi.Tipo_Vehiculo and xCaballos_exac BETWEEN caballos_min and caballos_max and anne='2005';
		exception
		   When no_data_found Then
		     Begin
		      	INSERT INTO TMP_INCIDENCIAS_TRAFICO(ID_TRAFICO,MARCA_ERROR,DESC_ERROR) 
				VALUES (vVehi.ID,2,'TIPO DE VEHICULO ERRONEO');
				xError:= True;
			 End;
		End;
		--Comprobamos si existe el vehiculo en nuestra base de datos por NIF y Bastidor
		Select count(*) into xExiste from Vehiculos where trim(nif)=trim(vVehi.dni) and trim(bastidor)=trim(vVehi.bastidor);
		--Insertamos los vehiculos de alta nueva
		IF xExiste=0 THEN
		   Insert into Vehiculos (MUNICIPIO,NIF,MARCA,MODELO,TIPO_VEHICULO,BASTIDOR,MATRICULA,NUMERO,LETRA,CABALLOS_EXAC,F_ALTA,MOTIVO_ALTA)
		   Values (vVehi.ayto,vVehi.Dni,xMarca,xModelo,xCodTipoVehiculo,vVehi.bastidor,xMatri,xNum,xLetra,xCaballos_exac,vVehi.FECHA_TRAMITE,
		           'TRAFICO INFORMA DEL ALTA DEL VEHICULOS. FECHA: '||TO_CHAR(vVehi.FECHA_TRAMITE,'dd/mm/yyyy'));
		   xCargado:= 'C';
		END IF;
		--Si son bajas los damos de baja actualizando F_BAJA 
		IF (vVehi.Tipo_Registro='B') THEN
			Update VEHICULOS v set INCORPORADO='N',F_INCORPORACION=NULL,
		   	       F_BAJA=DECODE(F_BAJA,null,vVehi.FECHA_TRAMITE,F_BAJA), 
		   	       MOTIVO_BAJA=DECODE(vVehi.CODIGO_TRAMITE,'TRANS','Baja por Transferencia. Fecha: '||TO_CHAR(vVehi.FECHA_TRAMITE),
	   			   'Baja enviada por tráfico. Fecha: '||TO_CHAR(vVehi.FECHA_TRAMITE))
	 		 Where (trim(nif),trim(bastidor)) in (select trim(dni),trim(bastidor) from trafico_new where id=vVehi.id);
		    xAnulado:= 'A';
	 	END IF;
		--Actualizamos campos en trafico_New 
		Update Trafico_new set Ciudad=xMatri,Numero=xNum,Letra=xLetra,Marca=xMarca,Modelo=xModelo,Caballos_exac=xCaballos_exac,CodTipoVehiculo=xCodTipoVehiculo,
			   			   	   Cargar=xCargado,Anular=xAnulado
		Where current Of cVehi; 
	end loop;
 	--Borramos los todos registros de incidencias de los vehiculos no encontrados y ya cargados
	Delete from tmp_incidencias_trafico where id_trafico in (select id from trafico_new where codigo_tramite not in ('DUPLI','MODIF','MODIT'))
	and marca_error in (4,8);
--	COMMIT;
end;


select * from trafico_new where id in (select id_trafico from tmp_incidencias_trafico where marca_error in (4,8))

select * from vehiculos where nif='X1118700A'




/***** COMPROBOCIONES *****/
select * from vehiculos where trim(bastidor)='W0L0TGF4835030671'

delete vehiculos where abonado=56864

select * from recibos_vehi where abonado=56366 

select * from valores where padron='000003' and year='2003' and periodo='00' and recibo=56366

select * from trafico_new where trim(bastidor)='W0L0TGF4835030671'


select marca_error,count(*) from tmp_incidencias_trafico group by marca_error

delete tmp_incidencias_trafico where marca_error=0 and id_trafico not in (select id_trafico from tmp_incidencias_trafico where marca_error<>0)


select * from trafico_new where id in (select id_trafico from tmp_incidencias_trafico where marca_error='12')

select v.nif,v.bastidor,v.f_baja,t.fecha_tramite from vehiculos v join trafico_new t on trim(v.bastidor)=trim(t.bastidor) and trim(v.nif)=trim(t.dni)
where t.id in (select id_trafico from tmp_incidencias_trafico where marca_error='9')

select * from tarifas_vehiculos where anne='2005'


select * from vehiculos v join trafico_new t on trim(v.nif)=trim(t.dni) and trim(v.bastidor)=trim(t.bastidor) and t.tipo_registro='B' and codigo_tramite not in ('DUPLI')
and v.f_baja is null


Update VEHICULOS v set INCORPORADO='N',F_INCORPORACION=NULL,
F_BAJA=to_date('10/06/2004'),MOTIVO_BAJA='Baja enviada por tráfico. Fecha: 10/06/2004' Where abonado=66401


select nif,bastidor,trim(matricula),trim(numero),trim(letra) 
from vehiculos where abonado not in (select abonado from recibos_vehi)
group by NIF,bastidor,trim(matricula),trim(numero),trim(letra) having count(*)>1

select abonado,nif,marca,modelo,matricula,letra,numero,bastidor,f_alta,f_baja,incorporado 
from vehiculos where (abonado) in 
(select max(abonado) from vehiculos group by NIF,bastidor,trim(matricula),trim(numero),trim(letra) having count(*)>1)
and abonado not in (select abonado from recibos_vehi)

select * from vehiculos where trim(bastidor) in ('VF7CHRHYB38954023')

delete from vehiculos where (abonado) in 
(select max(abonado) from vehiculos group by NIF,bastidor,trim(matricula),trim(numero),trim(letra) having count(*)>1)
and abonado not in (select abonado from recibos_vehi)

delete vehiculos where abonado in (55293,55294,68524,66227)

delete 
from vehiculos where (NIF,bastidor) in (select NIF,bastidor from vehiculos group by NIF,bastidor having count(*)>1) and abonado>110000 and f_alta=f_baja
...




select * from trafico_new where trim(bastidor) in ('ZFA18600002228608','WOLOOOO34KA604182')

select trim(dni),trim(bastidor) from trafico_new
minus
select trim(nif),trim(bastidor) from vehiculos


select * from vehiculos where trim(bastidor) in ('ZFA18600002228608','WOLOOOO34KA604182')

select * from trafico_new where trim(bastidor) in ('ZFA18600002228608','WOLOOOO34KA604182')

select count(*) from tmp_incidencias_trafico where id_trafico in (160509,160442,160399,160373,161165,160356,160749,160388,160264,160262,160256,160328)



/**********************************PROCEDIMIENTOS ADAPTADOS************************************************/

CREATE OR REPLACE PROCEDURE LEER_TRAFICO(
       xFICH_TRAFICO 		IN VARCHAR2,
       xTIPO_REGISTRO 		IN CHAR,
       xCODIGO_TRAMITE 		IN CHAR,
       xMATRICULA 			IN CHAR,
       xDNI 				IN CHAR,
       xAPELLIDO_1 			IN CHAR,
       xAPELLIDO_2 			IN CHAR,
       xNOMBRE 				IN CHAR,
       xV2IND 				IN CHAR,
       xPROVINCIA 			IN CHAR,
       xCODIGO_POSTAL 		IN CHAR,
       xMUNICIPIO 			IN CHAR,
       xPUEBLO 				IN CHAR,
       xCALLE 				IN CHAR,
       xCODIGO_TIPO 		IN CHAR,
       xTIPO_VEHICULO 		IN CHAR,
       xMARCA_MODELO 		IN CHAR,
       xBASTIDOR 			IN CHAR,
       xSERVICIO 			IN CHAR,
       xCILINDRADA 			IN CHAR,
       xPOTENCIA 			IN CHAR,
       xPLAZAS 				IN CHAR,
       xCARGA 				IN CHAR,
       xFECHA_TRAMITE 		IN DATE,
       xMATRICULA_ANTERIOR 	IN CHAR,
       xHORA 				IN DATE,
       xMATRICULA_AYTO		IN CHAR
)
AS
	xID		 	 INTEGER;
	xNIF         CHAR(10);
    xNOMBREAPELL VARCHAR2(40);
	xNIFBueno    CHAR(10);
	xAYTO        CHAR(3);
	xTipoVehiculo CHAR(24);

BEGIN 

   -- Calculamos el Nif a partir del DNI que viene en el fichero de tráfico y
   -- comprobamos si es mote de algún otro NIF o si existe en nuestra base de datos.   
   -- xNIFBueno valdrá: NIF VÁLIDO: si xNif era mote.
   --				    xNif: si no era mote pero está dado de alta en Contribuyentes
   --			        NULLO: Si no es mote ni está dado de alta en Contribuyentes
   xNIF:=CalNIF(xDNI);
   xNiFBueno:=GetExisteNif(xNIF);      

   -- Si xNIFBueno es nulo haremos la misma comprobación pero con el DNI
   IF (xNIFBueno IS NULL) THEN        
      xNIFBueno:=GetExisteNIF(xDNI);      
      IF (xNIFBueno IS NULL) THEN
         xNOMBREAPELL:=SUBSTR(RTRIM(LTRIM(xAPELLIDO_1))||' '||RTRIM(LTRIM(xAPELLIDO_2))||
			    ' '||RTRIM(LTRIM(xNOMBRE)), 1, 40);
         InsertaModiContribuyente(xNIF,xNOMBREAPELL,'',xCALLE,'','','','',
	      xMUNICIPIO,xPROVINCIA,xCODIGO_POSTAL,'');		
	     xNIFBueno:=xNIF; -- Para evitar que inserte en TRAFICO_NEW un DNI nulo.
      END IF;
   END IF;  
	
   -- recogemos el ayto que le corresponde para poder insertarlo en trafico_new
   begin
      SELECT MUNICIPIO INTO xAYTO FROM DATOSPER 
      WHERE EMPRESA LIKE '%'||LTRIM(RTRIM(xMUNICIPIO))||'%';
      EXCEPTION
         WHEN NO_DATA_FOUND THEN
	      xAYTO:='';
   end;
   
   If xTipo_Vehiculo='FURGONETA' Then xTipoVehiculo:='CAMION';
   ElsIf xTipo_Vehiculo='HORMIGONERA' Then xTipoVehiculo:='CAMION';
   ElsIf xTipo_Vehiculo='CAMIONETA' Then xTipoVehiculo:='CAMION';
   ElsIf xTipo_Vehiculo='FURGONETA MIXTA' Then xTipoVehiculo:='CAMION';
   ElsIf xTipo_Vehiculo='VEHIC. ESPECIAL' Then xTipoVehiculo:='TURISMO';
   ElsIf xTipo_Vehiculo='COCHE FUNEBRE' Then xTipoVehiculo:='TURISMO';
   ElsIf xTipo_Vehiculo='VEHIC. MIXTO' Then xTipoVehiculo:='CAMION';
   ElsIf xTipo_Vehiculo='MAQUINA AGRICOLA' Then xTipoVehiculo:='TRACTOR';
   ElsIf xTipo_Vehiculo='VEHIC. VIVIENDA' Then xTipoVehiculo:='CAMION';
   ElsIf xTipo_Vehiculo='VOLQUETE' Then xTipoVehiculo:='CAMION';
   ElsIf xTipo_Vehiculo='VEH. ARTICULADO' Then xTipoVehiculo:='CAMION';
   ElsIf xTipo_Vehiculo='TIPO NO CONOCIDO' Then xTipoVehiculo:='MOTOCICLETA';
   ElsIf xTipo_Vehiculo='AMBULANCIA' Then xTipoVehiculo:='TURISMO';
   Else xTipoVehiculo:= xTipo_Vehiculo;
   End If;
   
   INSERT INTO TRAFICO_NEW
     (FICH_TRAFICO, TIPO_REGISTRO, CODIGO_TRAMITE, MATRICULA, DNI,APELLIDO_1,APELLIDO_2,NOMBRE,
      V2IND, PROVINCIA,CODIGO_POSTAL, MUNICIPIO, PUEBLO, CALLE, CODIGO_TIPO,TIPO_VEHICULO,
      MARCA_MODELO, BASTIDOR, SERVICIO,CILINDRADA, POTENCIA, PLAZAS, CARGA, FECHA_TRAMITE,
	  MATRICULA_ANTERIOR, HORA, MATRICULA_AYTO, AYTO)
   VALUES
     (xFICH_TRAFICO, xTIPO_REGISTRO, xCODIGO_TRAMITE, xMATRICULA, SubStr(xNIFBueno,1,9),xAPELLIDO_1,xAPELLIDO_2,xNOMBRE, 
	 xV2IND, xPROVINCIA,xCODIGO_POSTAL, xMUNICIPIO, xPUEBLO, xCALLE, xCODIGO_TIPO, xTIPOVEHICULO, 
	 xMARCA_MODELO, REPLACE(xBASTIDOR,'-',''), xSERVICIO,xCILINDRADA, xPOTENCIA, xPLAZAS, xCARGA, xFECHA_TRAMITE,
	 xMATRICULA_ANTERIOR, xHORA, xMATRICULA_AYTO, xAYTO)
   RETURNING ID INTO xID;

   TRAFICO_INCIDENCIAS_BASICAS(xID,xMUNICIPIO,xTIPOVEHICULO);
END;
/


CREATE OR REPLACE PROCEDURE CargarAutosAuto(xNADA IN INTEGER)
AS
   xSALIDA INTEGER;
   CURSOR CAUTOS IS SELECT ID FROM TRAFICO_NEW 
			  WHERE ID IN (SELECT ID_TRAFICO FROM TMP_INCIDENCIAS_TRAFICO WHERE
				         MARCA_ERROR=0) AND
				  ID IN (SELECT ID_TRAFICO FROM TMP_INCIDENCIAS_TRAFICO
				         HAVING COUNT(*)=1 GROUP BY ID_TRAFICO)
	              ORDER BY FECHA_TRAMITE,HORA;
BEGIN
   --Actualizamos Bastidores (Todos, aunque tengan ya escrito bastidor, pues a veces estan mal en nuestra base de datos)
   Update vehiculos v set bastidor = (select distinct t.bastidor from trafico_new t 
   		where trim(replace(t.matricula,' ',''))=trim(replace(v.matricula,' ',''))||trim(replace(v.numero,' ',''))||trim(replace(v.letra,' ','')))
	where v.abonado in (select v.abonado from vehiculos v join trafico_new t 
		  			 on trim(replace(t.matricula,' ',''))=trim(replace(v.matricula,' ',''))||trim(replace(v.numero,' ',''))||trim(replace(v.letra,' ','')));

   --Actualizamos tipo_tramite 
   Update trafico_new set codigo_tramite='TRANS' 
    WHERE codigo_tramite='DUPLI' AND matricula in (select matricula from trafico_new WHERE CODIGO_TRAMITE='DUPLI' group by matricula having count(*)=1);

   FOR vAUTOS IN CAUTOS 
   LOOP
      CargarRegistroTrafico(vAUTOS.ID,xSALIDA);
   END LOOP;
END;




/* Listado de posibles errores a la hora de cargar los registros (tanto manual como auto):
0: REGISTRO NO CARGADO: es el estado inicial de un registro, de forma que una vez elegida su 
   carga, pasará siempre a otro estado, salvo cuando tenga una fecha de trámite inferior al 
   año actual.
1: MUNICIPIO no existe: es el estado en el que un registro no se ha cargado por no existir el 
   MUNICIPIO en la base de datos.
2: INCIDENCIA, TIPO DE VEHICULO erróneo: es el estado en el que un registro no ha sido cargado 
   por error en el tipo de vehículo al ser uno de los siguientes: vehículo articulado,
   vehículo mixto, furgoneta, furgoneta mixta, vehículo especial, ambulancia o máquina agrícola.
3: ERROR: ALTA YA EXISTE: es el estado en el que un registro ha intentado ser dado de alta 
   cuando en realidad ya lo está.
4: ERROR: EL VEHÍCULO NO EXISTE: es el estado en el que un registro ha intentado darse de baja 
   o ser rematriculado y no existía previamente.
5: ERROR: DNI NO ASOCIADO AL VEHÍCULO: es el estado en el que un registro ha intentado darse 
   de baja sin que coincida el DNI de su propietario con el que figura como tal en nuestra 
   base de datos.
6: ERROR: VEHÍCULO DADO DE BAJA: Se producirá cuando se quiera dar de baja un vehículo que ya
   lo está, o se quiera dar de alta o rematricular un vehículo dado de baja.
7: ERROR: MATRÍCULA IDÉNTICA: Si se va a rematricular un vehículo y la nueva matrícula 
   coincide con la anterior.
8: PENDIENTE SELECCIÓN CARGA MANUAL
9: NO CARGADO POR SER DE TIPO MODIT,MODIF O DUPLI
10: NO CARGADO POR HABERSE PROCESADO UN REGISTRO CON FECHA DE TRAMITE POSTERIOR
11: NO CARGADO POR NO ENCONTRAR SU TARIFA
12: REGISTRO DUPLICADO EN LA BASE DE DATOS. SE DEJA PARA SER ARREGLADO MANUALMENTE.*/
CREATE OR REPLACE PROCEDURE CargarRegistroTrafico(
	IDTemp IN INTEGER,	
	xSALIDA OUT INTEGER)  
AS
   xREGTRAFICO TRAFICO_NEW%ROWTYPE;
   xABONADO INTEGER;
   mABONADO INTEGER;
   xNIF     CHAR(10);
   mCIUDAD  CHAR(3);
   mNUMERO  CHAR(6);
   mLETRAS  CHAR(3);
   xCIUDAD  CHAR(3);
   xNUMERO  CHAR(6);
   xLETRAS  CHAR(3);	
   xF_BAJA  DATE;
   xCONT	INTEGER;   
   xCuantos INTEGER;
BEGIN

   -- Presuponemos que el proceso va a funcionar correctamente (sin incidencias)
   xSALIDA:=1;

   SELECT * INTO xREGTRAFICO FROM TRAFICO_NEW WHERE ID=IDTEMP;

   -- Comprobamos que el vehiculo existe en nuestra base de datos
   SELECT COUNT(*) INTO xCuantos FROM VEHICULOS WHERE TRIM(BASTIDOR)=TRIM(xREGTRAFICO.BASTIDOR);
   IF (xCuantos=0) THEN
   	  INSERT INTO TMP_INCIDENCIAS_TRAFICO(ID_TRAFICO,MARCA_ERROR,DESC_ERROR)
	  VALUES (IDTEMP,4,'ERROR: EL VEHICULO NO EXISTE');
	  xSALIDA:=0;
	  RETURN;
   END IF;
	   
   --comprobamos que exista el vehículo en nuestra base de datos para dicho nif (comprobocaion por abonado) 
   SELECT count(*) into xCuantos FROM VEHICULOS
   WHERE MUNICIPIO=xREGTRAFICO.AYTO AND TRIM(BASTIDOR)=TRIM(xREGTRAFICO.BASTIDOR) AND TRIM(NIF)=TRIM(xREGTRAFICO.DNI);
   IF (xCuantos>1) THEN -- Esta repetido el bastidor para el mismo nif en vehículos
     xSALIDA:=0;
     INSERT INTO TMP_INCIDENCIAS_TRAFICO(ID_TRAFICO,MARCA_ERROR,DESC_ERROR)
     VALUES(IDTEMP,12,'ERROR: HAY MÁS DE UN VEHICULO PARA ESE DNI-BASTIDOR');
	 RETURN;
   END IF;
   	
   -- descomponemos la matrícula en ciudad,numero y letras
   SplitMatricula(xREGTRAFICO.MATRICULA,xCIUDAD,xNUMERO,xLETRAS);

   -- un alta nueva o un alta por transferencia
   IF ((xREGTRAFICO.TIPO_REGISTRO='A') AND (xREGTRAFICO.CODIGO_TRAMITE IN ('MATCI','MATRI','TRANS'))) OR	    
      ((xREGTRAFICO.TIPO_REGISTRO='B') AND (xREGTRAFICO.CODIGO_TRAMITE IN ('BAJAD','BAJAT','TRANS'))) OR
	   (xREGTRAFICO.TIPO_REGISTRO='R') THEN

       -- recogemos los datos que nos faltan (filtrando tb por mismo nif) 
	   BEGIN
	      SELECT ABONADO,MATRICULA,NUMERO,LETRA,F_BAJA INTO xABONADO,mCIUDAD,mNUMERO,mLETRAS,xF_BAJA
	        FROM VEHICULOS WHERE TRIM(BASTIDOR)=TRIM(xREGTRAFICO.BASTIDOR) AND TRIM(NIF)=TRIM(xREGTRAFICO.DNI);
	   EXCEPTION
	      WHEN NO_DATA_FOUND THEN
		  	   IF (xREGTRAFICO.TIPO_REGISTRO='B') THEN
	      	   	  INSERT INTO TMP_INCIDENCIAS_TRAFICO(ID_TRAFICO,MARCA_ERROR,DESC_ERROR)
	      		  VALUES (IDTEMP,5,'ERROR: DNI NO ASOCIADO AL VEHÍCULO');
				  xSALIDA:=0;
				  RETURN;
			   END IF;
	   END;
	   
 	   -- Si el vehículo estaba ya dado de alta y no es una transferencia se marca como ERROR 3 
	   IF ((xREGTRAFICO.TIPO_REGISTRO='A') AND (xREGTRAFICO.CODIGO_TRAMITE<>'TRANS') AND 
	      ((mCIUDAD IS NOT NULL) OR (mNUMERO IS NOT NULL) OR (mLETRAS IS NOT NULL))) THEN
	     INSERT INTO TMP_INCIDENCIAS_TRAFICO(ID_TRAFICO,MARCA_ERROR,DESC_ERROR)
	     VALUES (IDTEMP,3,'ERROR: ALTA YA EXISTE');
		  xSALIDA:=0;
	  	 RETURN;
	   END IF;

	   -- si no es una transferencia, y el vehículo está dado de baja, se anota como ERROR 6  
	   IF ((xREGTRAFICO.TIPO_REGISTRO='A') AND (xREGTRAFICO.CODIGO_TRAMITE<>'TRANS') AND (xF_BAJA IS NOT NULL)) OR
	   	  ((xREGTRAFICO.TIPO_REGISTRO IN ('B','R')) AND (xF_BAJA IS NOT NULL)) THEN
	     INSERT INTO TMP_INCIDENCIAS_TRAFICO(ID_TRAFICO,MARCA_ERROR,DESC_ERROR)
		 VALUES (IDTEMP,6,'ERROR: VEHÍCULO DADO DE BAJA');
		  xSALIDA:=0;
		 RETURN;
	   END IF;

	   -- comprobamos que la nueva matrícula y la anterior no sean las mismas
	   IF (xREGTRAFICO.TIPO_REGISTRO='R') AND ((xCIUDAD=mCIUDAD) AND (xNUMERO=mNUMERO) AND (xLETRAS=mLETRAS)) THEN		
	   	  INSERT INTO TMP_INCIDENCIAS_TRAFICO(ID_TRAFICO,MARCA_ERROR,DESC_ERROR)
   	   	  VALUES (IDTEMP,7,'ERROR: REMATRICULACION PARA MATRÍCULA IDÉNTICA');
	   	  xSALIDA:=0;
		  RETURN;
	   END IF;

	   IF (xREGTRAFICO.TIPO_REGISTRO='A') THEN
          -- Damos el alta de tráfico modificando para el abonado la matrícula que iene en el fichero
          UPDATE VEHICULOS SET MATRICULA=xCiudad,NUMERO=xNumero,LETRA=xLetras,
                 MOTIVO_ALTA='TRÁFICO INFORMA DE LA MATRÍCULA, FECHA: '||TO_CHAR(xREGTRAFICO.FECHA_TRAMITE)
	       WHERE ABONADO=xABONADO;

		  -- si se trata de una transferencia, modificaremos también los datos fiscales
		  -- puede que no sea necesario si la baja está en otro municipio, pero así 
		  -- contemplamos ambas posibilidades
		  IF xREGTRAFICO.CODIGO_TRAMITE='TRANS' THEN
		     UPDATE VEHICULOS SET NIF=ltrim(rtrim(xREGTRAFICO.DNI)),
	      			      REPRESENTANTE=NULL,
					      IDDOMIALTER=NULL,
					      COTITULARES='N',
					      DOMICILIADO='N',
					      ENTIDAD=NULL,
					      SUCURSAL=NULL,
					      DC=NULL,
					      CUENTA=NULL,
					      TITULAR=NULL,
					      F_ALTA=xREGTRAFICO.FECHA_TRAMITE,
						  F_BAJA=NULL,
					      MOTIVO_ALTA='Transferencia del NIF: '||NIF||' al NIF: '||
					      ltrim(rtrim(xREGTRAFICO.DNI))||
					      '. Fecha anterior alta: '||
					      TO_CHAR(F_ALTA,'DD/MM/YYYY'),
					      TIPO_BONI_EX=NULL,
					      ID_BONI_EX=0,
					      YEAR_BONI=NULL
	         WHERE ABONADO=xABONADO;
	         -- si había cotitulares los borramos
	         DELETE FROM COTITULARES WHERE PROGRAMA='VEHICULOS' AND ID_CONCEPTO=xABONADO;	   
		   END IF;
		  
		 ELSIF (xREGTRAFICO.TIPO_REGISTRO='B') THEN
	         UPDATE VEHICULOS SET F_BAJA=xREGTRAFICO.FECHA_TRAMITE,
	   				MOTIVO_BAJA=DECODE(xREGTRAFICO.CODIGO_TRAMITE,'TRANS','Baja por Transferencia. Fecha: ',
					'Baja enviada por tráfico. Fecha: ')||TO_CHAR(xREGTRAFICO.FECHA_TRAMITE),
					INCORPORADO='N',F_INCORPORACION=NULL
		     WHERE ABONADO=xABONADO;

		 ELSIF (xREGTRAFICO.TIPO_REGISTRO='R') THEN
		 	 -- si no se produce ninguna incidencia hacemos la rematriculación
	   		 UPDATE VEHICULOS SET MATRICULA=xCIUDAD,NUMERO=xNUMERO,LETRA=xLETRAS,
                    MOTIVO_ALTA='REMATRICULACIÓN MATRÍCULA ANTERIOR: '||mCIUDAD||mNUMERO||mLETRAS||
					' FECHA: '||TO_CHAR(xREGTRAFICO.FECHA_TRAMITE)
	   		 WHERE ABONADO=xABONADO;

		 END IF;
		 
 	     DELETE FROM TMP_INCIDENCIAS_TRAFICO WHERE ID_TRAFICO=IDTEMP;	      
	 
   ELSIF xREGTRAFICO.CODIGO_TRAMITE IN ('MODIF','MODIT','DUPLI') THEN
   	  INSERT INTO TMP_INCIDENCIAS_TRAFICO(ID_TRAFICO,MARCA_ERROR,DESC_ERROR)
	  VALUES (IDTEMP,9,'NO CARGADO POR SER DE TIPO MODIT,MODIF,O DUPLI');
	  xSALIDA:=0;
	  RETURN;
   ELSE -- El tipo de registro y el codigo de trámite son incompatibles.
	  INSERT INTO TMP_INCIDENCIAS_TRAFICO(ID_TRAFICO,MARCA_ERROR,DESC_ERROR)
	  VALUES (IDTEMP,10,'EL TIPO DE REGISTRO Y CÓDIGO DE TRAMITE SON INCOMPATIBLES');
	  xSALIDA:=0;
	  RETURN;
   END IF;
   
END;
/



/**********************************************************************************************/
--Comprobar los Tipos de Vehiculos cinta por cinta....
/*********************************************************************************************/
select * from trafico_new --where matricula='6963DLH'

select marca_error,count(*) from tmp_incidencias_trafico group by marca_error

select * from vehiculos where trim(bastidor)='WF0HXXGAJH5J12631'



DECLARE
  xMatri  varchar2(3);
  xNum  varchar2(6);
  xLetra  varchar2(3);
  xModelo  varchar2(25);
  xMarca  varchar2(25);
  xCaballos_Exac	Float;
  xCodTipoVehiculo	varchar2(5);
  xExiste   Integer;
  xError    Boolean;
  xCargado  char(1);
  xAnulado  char(1);
  cursor cVehi is Select * from trafico_new
   for update of Ciudad,Numero,Letra,Marca,Modelo,Caballos_exac;
begin
   --Abrir Cursor para actualizacion de tabla Trafico_new
   for vVehi IN cVehi LOOP
		--separamos Marca y Modelo 
		SplitMarcaModelo(vVehi.MARCA_MODELO,xMarca,xModelo);
        --Separamos Matricula
		SplitMatricula(vVehi.MATRICULA,xMatri,xNum,xLetra);
		--Buscamos el tipo de vehiculo. y le rellenamos caballos exacciones 
		If (vVehi.tipo_vehiculo='TURISMO') or (vVehi.Tipo_Vehiculo='TRACTOR') THEN
		   xCaballos_exac := vVehi.POTENCIA;
		ElsIf vVehi.tipo_vehiculo='CAMION' THEN
			  xCaballos_exac := vVehi.CARGA;
		ElsIf vVehi.tipo_vehiculo='AUTOBUS' THEN
			  xCaballos_exac := vVehi.PLAZAS;
		ElsIf (vVehi.tipo_vehiculo='CICLOMOTOR') or (vVehi.tipo_vehiculo='MOTOCICLETA') THEN
			  xCaballos_exac := vVehi.CILINDRADA;
		ElsIf vVehi.tipo_vehiculo='REMOLQUE' THEN
			  xCaballos_exac := vVehi.CARGA;
		End IF;
		--Tomar Codigo del Tipo de Vehiculo
		begin 
		   Select codigo into xCodTipoVehiculo from tarifas_vehiculos 
		    Where VEHI_TRAFICO=vVehi.Tipo_Vehiculo and xCaballos_exac BETWEEN caballos_min and caballos_max and anne='2005';
		exception
		   When no_data_found Then
		     Begin
		      	INSERT INTO TMP_INCIDENCIAS_TRAFICO(ID_TRAFICO,MARCA_ERROR,DESC_ERROR) 
				VALUES (vVehi.ID,2,'TIPO DE VEHICULO ERRONEO');
				xError:= True;
			 End;
		End;
		--Actualizamos campos en trafico_New 
		Update Trafico_new set Ciudad=xMatri,Numero=xNum,Letra=xLetra,Marca=xMarca,Modelo=xModelo,Caballos_exac=xCaballos_exac,CodTipoVehiculo=xCodTipoVehiculo,
			   			   	   Cargar=xCargado,Anular=xAnulado
		Where current Of cVehi; 
	end loop;
	COMMIT;
end;


create table lory_tmptrafico as 
select v.abonado,v.tipo_vehiculo,v.caballos_exac,t.codtipovehiculo,t.caballos_exac as CaballosExac 
from vehiculos v join trafico_new t on trim(v.nif)=trim(t.dni) and trim(v.bastidor)=trim(t.bastidor) 
where v.tipo_vehiculo<>t.codtipovehiculo 

update vehiculos v set (tipo_vehiculo,caballos_exac)=(select codtipoVehiculo,caballosExac from lory_tmptrafico
where v.abonado=abonado and rownum=1) where abonado in (select abonado from lory_tmptrafico)


drop table lory_tmptrafico